# Локальный запуск Web App сервера (Telegram Mini App и PWA)
import asyncio
import logging
import sys
from database import init_db
from services.web_server import start_web_server

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
    handlers=[logging.StreamHandler(sys.stdout)]
)
logger = logging.getLogger("rii_web")

async def main():
    logger.info("Инициализация базы данных...")
    await init_db()

    host = "127.0.0.1"
    port = 8082
    runner = await start_web_server(host, port)
    logger.info("Локальный веб-сервер успешно запущен: http://%s:%d", host, port)

    try:
        while True:
            await asyncio.sleep(3600)
    finally:
        await runner.cleanup()

if __name__ == "__main__":
    try:
        asyncio.run(main())
    except (KeyboardInterrupt, SystemExit):
        logger.info("Веб-сервер остановлен.")
