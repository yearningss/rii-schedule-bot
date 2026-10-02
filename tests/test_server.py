import asyncio
import os
import tempfile
import time
import unittest
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import AsyncMock, patch

from aiohttp import web
from aiohttp.test_utils import TestClient, TestServer

# Проверки используют отдельную базу и никогда не подключаются к Telegram.
_directory = tempfile.TemporaryDirectory()
os.environ["BOT_TOKEN"] = "123456:test"
os.environ["DB_PATH"] = str(Path(_directory.name) / "test.db")

from services.api import RiiApiClient, parse_para_time_range
from services.singleflight import SingleFlight
from services import kiosk_service, web_server
from services.notifier import ScheduleNotifier
import database


class ApiTests(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        self.calls = []
        self.payload = {"schedule": {"weekNumber": 1, "scheduleData": {}}}

        async def upstream(request):
            self.calls.append(request.query.get("Group"))
            await asyncio.sleep(0.05)
            return web.json_response(self.payload)

        app = web.Application()
        app.router.add_get("/", upstream)
        self.server = TestServer(app)
        await self.server.start_server()
        self.url_patch = patch("services.api.API_BASE_URL", str(self.server.make_url("/")))
        self.url_patch.start()
        self.client = RiiApiClient()

    async def asyncTearDown(self):
        await self.client.close()
        await self.server.close()
        self.url_patch.stop()

    async def test_одновременные_запросы_не_дублируют_загрузку(self):
        started = time.perf_counter()
        results = await asyncio.gather(*(self.client.get_schedule(1) for _ in range(50)))
        self.assertEqual(self.calls, ["1"])
        self.assertTrue(all(result == self.payload["schedule"] for result in results))
        print(f"50 запросов: {len(self.calls)} обращение к источнику, {time.perf_counter() - started:.3f} с")

    async def test_разные_группы_не_смешиваются(self):
        await asyncio.gather(self.client.get_schedule(1), self.client.get_schedule(2))
        self.assertCountEqual(self.calls, ["1", "2"])

    async def test_принудительное_обновление_и_обычный_кэш(self):
        await self.client.get_schedule(1)
        await self.client.get_schedule(1)
        self.assertEqual(len(self.calls), 1)
        await self.client.get_schedule(1, force_refresh=True)
        self.assertEqual(len(self.calls), 2)

    async def test_ошибка_не_затирает_хороший_кэш(self):
        good = await self.client.get_schedule(1)
        self.payload = {"error": "Источник недоступен"}
        with self.assertRaises(ValueError):
            await self.client.get_schedule(1, force_refresh=True)
        self.assertEqual(await self.client.get_schedule(1), good)

    async def test_пустой_список_групп_тоже_кэшируется(self):
        self.payload = {"groups": []}
        self.assertEqual(await self.client.get_groups(), [])
        await self.client.get_groups()
        self.assertEqual(len(self.calls), 1)

    async def test_семестр_строкой_обрабатывается(self):
        self.payload = {"groups": [{"id": "1", "name": " ИВТ-61 ", "sem": "1"}]}
        groups = await self.client.get_groups()
        self.assertEqual(groups[0]["course"], 1)
        self.assertEqual(groups[0]["name"], "ИВТ-61")

    async def test_срок_кэша_начинается_после_загрузки(self):
        clock = SimpleNamespace(monotonic=lambda: 100)
        async def fetch(params=None):
            clock.monotonic = lambda: 200
            return self.payload
        with patch.object(self.client, "_fetch_json", side_effect=fetch):
            with patch("services.api.time", clock):
                await self.client.get_schedule(1)
        self.assertEqual(self.client._schedule_cache_time[1], 200)


class ServiceTests(unittest.IsolatedAsyncioTestCase):
    async def asyncTearDown(self):
        await kiosk_service._loads.close()
        await web_server._loads.close()

    async def test_отмена_одного_клиента_не_отменяет_общую_загрузку(self):
        flight = SingleFlight()
        ready = asyncio.Event()
        started = asyncio.Event()
        async def load():
            started.set()
            await ready.wait()
            return 42
        first = asyncio.create_task(flight.run("one", load))
        await started.wait()
        second = asyncio.create_task(flight.run("one", load))
        await asyncio.sleep(0)
        first.cancel()
        await asyncio.gather(first, return_exceptions=True)
        ready.set()
        self.assertEqual(await second, 42)
        await flight.close()

    async def test_после_ошибки_можно_загрузить_снова(self):
        flight = SingleFlight()
        with self.assertRaises(ValueError):
            await flight.run(1, AsyncMock(side_effect=ValueError("Сбой")))
        self.assertEqual(await flight.run(1, AsyncMock(return_value=2)), 2)
        await flight.close()

    async def test_погода_не_повторяет_сбой_для_каждого_запроса(self):
        with patch.dict(kiosk_service._weather_cache, timestamp=0), \
             patch.object(kiosk_service, "_weather_retry_at", 0), \
             patch("aiohttp.ClientSession", side_effect=OSError("Сбой")) as session:
            await asyncio.gather(*(kiosk_service.get_rubtsovsk_weather() for _ in range(20)))
            await kiosk_service.get_rubtsovsk_weather()
            self.assertEqual(session.call_count, 1)

    async def test_релизы_не_повторяют_сбой_для_каждого_запроса(self):
        with patch.dict(web_server._changelog_cache, timestamp=0, data=[]), \
             patch.object(web_server, "_changelog_retry_at", 0), \
             patch("aiohttp.ClientSession", side_effect=OSError("Сбой")) as session:
            await asyncio.gather(*(web_server.get_app_changelog_data() for _ in range(20)))
            await web_server.get_app_changelog_data()
            self.assertEqual(session.call_count, 1)

    async def test_табло_объединяет_загрузки_и_не_показывает_сбой_как_выходной(self):
        groups = [{"id": 1, "name": "ИВТ-61", "course": 1}]
        with patch.dict(kiosk_service._live_board_cache, timestamp=0, data=None), \
             patch.object(kiosk_service.api_client, "get_groups", AsyncMock(return_value=groups)) as load, \
             patch.object(kiosk_service.api_client, "get_schedule", AsyncMock(side_effect=OSError("Сбой"))), \
             patch.object(kiosk_service, "get_rubtsovsk_weather", AsyncMock(return_value={})):
            boards = await asyncio.gather(*(kiosk_service.get_live_board_data() for _ in range(20)))
            self.assertEqual(load.await_count, 1)
            self.assertEqual(boards[0]["groups"][0]["status"], "unavailable")

    async def test_долгая_проверка_изменений_не_блокирует_уроки(self):
        notifier = ScheduleNotifier(None)
        change_started = asyncio.Event()
        lesson_checked = asyncio.Event()
        async def changes():
            change_started.set()
            await asyncio.Event().wait()
        async def lessons():
            await change_started.wait()
            lesson_checked.set()
        with patch.object(notifier, "check_tomorrow_schedule_changes", side_effect=changes), \
             patch.object(notifier, "check_and_notify_lessons", side_effect=lessons):
            task = asyncio.create_task(notifier.start_loop())
            await asyncio.wait_for(lesson_checked.wait(), 1)
            task.cancel()
            await asyncio.gather(task, return_exceptions=True)

    async def test_некорректный_идентификатор_возвращает_400(self):
        async with TestClient(TestServer(web_server.create_web_app())) as client:
            for value in ("abc", "-1", "0"):
                response = await client.get("/api/schedule", params={"group_id": value})
                self.assertEqual(response.status, 400)

    async def test_текст_уведомления_не_разбирается_как_HTML(self):
        bot = SimpleNamespace(send_message=AsyncMock())
        notifier = ScheduleNotifier(bot)
        await notifier._send_message(1, "Предмет <дополнительно> & перенос")
        bot.send_message.assert_awaited_once_with(
            chat_id=1, text="Предмет <дополнительно> & перенос", parse_mode=None
        )

    def test_седьмая_пара_имеет_время_по_умолчанию(self):
        self.assertEqual(parse_para_time_range(None, 7), (1130, 1220, "18:50", "20:20"))


class DatabaseTests(unittest.IsolatedAsyncioTestCase):
    async def test_миграции_индексов_и_уникальные_группы(self):
        await database.init_db()
        await database.init_db()
        await database.set_user_group(1, 100, "ИВТ-61")
        await database.set_user_group(2, 100, "ивт-61")
        self.assertEqual(len(await database.get_all_active_group_ids()), 1)
        async with database.engine.connect() as connection:
            rows = (await connection.execute(database.text("PRAGMA index_list(users)"))).all()
            self.assertIn("idx_users_group_notifications", [row[1] for row in rows])
        await database.engine.dispose()


if __name__ == "__main__":
    unittest.main()
