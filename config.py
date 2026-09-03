# Конфигурация и загрузка переменных окружения
import os
from pathlib import Path
from dotenv import load_dotenv

BASE_DIR = Path(__file__).resolve().parent
load_dotenv(BASE_DIR / ".env")

BOT_TOKEN = os.getenv("BOT_TOKEN", "")
if not BOT_TOKEN:
    raise ValueError("BOT_TOKEN не задан в .env файле")

DB_PATH = Path(os.getenv("DB_PATH", "data/bot.db"))
if not DB_PATH.is_absolute():
    DB_PATH = BASE_DIR / DB_PATH

DB_PATH.parent.mkdir(parents=True, exist_ok=True)

API_BASE_URL = os.getenv("API_BASE_URL", "https://www.rubinst.ru/schedule.php")
CACHE_TTL_SECONDS = int(os.getenv("CACHE_TTL_SECONDS", "300"))
CHANGE_CHECK_INTERVAL_SECONDS = int(os.getenv("CHANGE_CHECK_INTERVAL_SECONDS", "900"))

WEBAPP_URL = os.getenv("WEBAPP_URL", "https://rii-bot.yearnings.ru")
WEB_HOST = os.getenv("WEB_HOST", "127.0.0.1")
WEB_PORT = int(os.getenv("WEB_PORT", "8080"))
