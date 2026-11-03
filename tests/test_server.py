import asyncio
import hashlib
import hmac
import json
from urllib.parse import urlencode
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

    async def test_домен_авторизации_разрешает_запросы_только_с_нашего_сайта(self):
        async with TestClient(TestServer(web_server.create_web_app())) as client:
            response = await client.options("/api/user/sync", headers={
                "Origin": "https://myrii.ru",
                "Access-Control-Request-Method": "POST",
                "Access-Control-Request-Headers": "content-type",
            })
            self.assertEqual(response.status, 204)
            self.assertEqual(response.headers["Access-Control-Allow-Origin"], "https://myrii.ru")
            self.assertIn("no-store", response.headers["Cache-Control"])
            response = await client.options("/api/user/sync", headers={"Origin": "https://example.com"})
            self.assertEqual(response.status, 403)
            self.assertNotIn("Access-Control-Allow-Origin", response.headers)

    async def test_личный_профиль_не_кешируется_даже_при_ошибке(self):
        async with TestClient(TestServer(web_server.create_web_app())) as client:
            response = await client.get("/api/app/profile", headers={"Origin": "https://myrii.ru"})
            self.assertEqual(response.status, 401)
            self.assertIn("no-store", response.headers["Cache-Control"])
            self.assertEqual(response.headers["Access-Control-Allow-Origin"], "https://myrii.ru")

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


class SecurityTests(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        await database.init_db()
        self.client = TestClient(TestServer(web_server.create_web_app()))
        await self.client.start_server()

    async def asyncTearDown(self):
        await self.client.close()
        await database.engine.dispose()

    def telegram_headers(self, user_id, age=0):
        fields = {"auth_date": str(int(time.time()) - age), "user": json.dumps({"id": user_id})}
        key = hmac.digest(b"WebAppData", web_server.BOT_TOKEN.encode(), "sha256")
        fields["hash"] = hmac.new(key, "\n".join(
            f"{k}={v}" for k, v in sorted(fields.items())
        ).encode(), hashlib.sha256).hexdigest()
        return {"X-Telegram-Init-Data": urlencode(fields)}

    async def test_профиль_только_из_проверенной_подписи(self):
        path = "/api/user?user_id=88202"
        self.assertEqual((await self.client.get(path)).status, 401)
        self.assertEqual((await self.client.post("/api/user/sync", json={"user_id": 88202})).status, 401)
        self.assertEqual((await self.client.get(path, headers=self.telegram_headers(88201, 3700))).status, 401)
        headers = self.telegram_headers(88201)
        self.assertEqual((await self.client.get(path, headers={
            "X-Telegram-Init-Data": headers["X-Telegram-Init-Data"].replace("88201", "88202")
        })).status, 401)
        result = await self.client.get(path, headers=headers)
        self.assertEqual((await result.json())["user_id"], 88201)
        with patch.object(web_server.api_client, "get_group_by_id", AsyncMock(return_value={"name": "ИВТ-61"})):
            result = await self.client.post("/api/user/sync", headers=headers, json={
                "user_id": 88202, "group_id": 1041, "group_name": "Подмена", "subgroup": 1,
            })
        self.assertEqual(result.status, 200)
        self.assertIsNone(await database.get_user(88202))
        self.assertEqual((await database.get_user(88201))["group_name"], "ИВТ-61")

    async def test_яндекс_проверяет_токен_и_приложение(self):
        path = "/api/app/auth/yandex"
        self.assertEqual((await self.client.post(path, json={"yandex_id": "чужой"})).status, 400)
        with patch.object(web_server, "fetch_yandex_identity", AsyncMock(return_value={
            "client_id": "чужое приложение", "id": "123",
        })):
            self.assertEqual((await self.client.post(path, json={"access_token": "test"})).status, 401)
        with patch.object(web_server, "fetch_yandex_identity", AsyncMock(return_value={
            "client_id": web_server.YANDEX_CLIENT_ID, "id": "123456", "first_name": "Проверенное имя",
        })):
            res = await self.client.post(path, json={"access_token": "test", "yandex_id": "765",
                                                    "first_name": "Подмена"})
        self.assertEqual(res.status, 200)
        payload = await res.json()
        self.assertEqual(payload["user"]["first_name"], "Проверенное имя")
        self.assertEqual(payload["user"]["yandex_id"], "123456")
        self.assertTrue(payload["auth_token"].startswith("ya2_"))

    async def test_код_входа_необходим_и_одноразовый(self):
        start = await self.client.post("/api/app/auth/session")
        token = (await start.json())["session_token"]
        secret = await database.confirm_auth_session(token, 88203)
        check = "/api/app/auth/check"
        legacy = await self.client.get(check, params={"session_token": token})
        self.assertNotIn("auth_token", await legacy.json())
        invalid = await self.client.post(check, json={"session_token": token, "code": "f" * 12})
        self.assertEqual((await invalid.json())["status"], "invalid_code")
        body = {"session_token": token, "code": database.auth_verification_code(secret)}
        results = await asyncio.gather(*(self.client.post(check, json=body) for _ in range(5)))
        payloads = [await response.json() for response in results]
        self.assertEqual(sum("auth_token" in item for item in payloads), 1)
        auth = next(item["auth_token"] for item in payloads if "auth_token" in item)
        self.assertEqual((await database.get_user_by_auth_token(auth))["user_id"], 88203)
        self.assertIsNone(await database.get_user_by_auth_token(secret))

    async def test_просроченный_подтверждённый_вход_не_выдаёт_токен(self):
        from datetime import datetime, timedelta
        token = "a" * 22
        await database.create_auth_session(token)
        secret = await database.confirm_auth_session(token, 88204)
        async with database.async_session_maker.begin() as db:
            await db.execute(database.update(database.AppAuthSession).where(
                database.AppAuthSession.session_token == token
            ).values(expires_at=datetime.utcnow() - timedelta(seconds=1)))
        res = await self.client.post("/api/app/auth/check", json={
            "session_token": token, "code": database.auth_verification_code(secret)
        })
        self.assertEqual(await res.json(), {"status": "expired"})

    async def test_чужое_устройство_не_отвязывается(self):
        token = "tg2_" + "c" * 64
        async with database.async_session_maker.begin() as db:
            db.add_all([
                database.User(user_id=88205, device_id="своё"),
                database.User(user_id=88206, device_id="чужое"),
                database.AppUser(auth_token=database.app_token_digest(token), user_id=88205),
            ])
        path = "/api/app/device/unlink"
        self.assertEqual((await self.client.post(path, json={"device_id": "чужое"})).status, 401)
        self.assertEqual((await self.client.post(path, json={"device_id": "чужое", "auth_token": token})).status, 200)
        self.assertEqual((await database.get_user(88206))["device_id"], "чужое")
        self.assertIsNone((await database.get_user(88205))["device_id"])


if __name__ == "__main__":
    unittest.main()
