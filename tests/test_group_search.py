import os
import unittest
from types import SimpleNamespace
from unittest.mock import AsyncMock, patch

os.environ.setdefault("BOT_TOKEN", "123456:test")

from handlers.start import handle_text_group_search


class GroupSearchTests(unittest.IsolatedAsyncioTestCase):
    async def test_ответы_боту_в_беседе_не_запускают_поиск(self):
        for chat_type in ("group", "supergroup"):
            for text in ("Владос", "блять", "@rubinst_bot РУП9-61", "РУП9-61"):
                with self.subTest(chat_type=chat_type, text=text):
                    message = SimpleNamespace(
                        text=text,
                        chat=SimpleNamespace(type=chat_type),
                        reply_to_message=SimpleNamespace(from_user=SimpleNamespace(id=123456)),
                        answer=AsyncMock(),
                    )
                    with patch("handlers.start.api_client.search_groups", new_callable=AsyncMock) as search:
                        await handle_text_group_search(message)
                        search.assert_not_awaited()
                        message.answer.assert_not_awaited()

    async def test_поиск_в_личке_сохраняется(self):
        message = SimpleNamespace(
            text="РУП9-61", chat=SimpleNamespace(type="private"), answer=AsyncMock()
        )
        with patch("handlers.start.api_client.search_groups", new_callable=AsyncMock, return_value=[]) as search:
            await handle_text_group_search(message)
            search.assert_awaited_once_with("РУП9-61")
            message.answer.assert_awaited_once()
