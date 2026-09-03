# Точка входа для запуска бота, фоновых сервисов и Web App сервера
import asyncio
import logging
import sys
from aiogram import Bot, Dispatcher
from aiogram.types import BotCommand, MenuButtonWebApp, WebAppInfo
from aiogram.client.default import DefaultBotProperties
from aiogram.enums import ParseMode

from config import BOT_TOKEN, WEBAPP_URL, WEB_HOST, WEB_PORT
from database import init_db
from handlers import main_router
from services.api import api_client
from services.notifier import ScheduleNotifier
from services.web_server import start_web_server

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
    handlers=[
        logging.StreamHandler(sys.stdout)
    ]
)
logger = logging.getLogger("rii_schedule_bot")

async def set_bot_commands(bot: Bot):
    commands = [
        BotCommand(command="app", description="Открыть расписание (Mini App)"),
        BotCommand(command="today", description="Расписание на сегодня"),
        BotCommand(command="tomorrow", description="Расписание на завтра"),
        BotCommand(command="week", description="Расписание на текущую неделю"),
        BotCommand(command="nextweek", description="Расписание на следующую неделю"),
        BotCommand(command="group", description="Выбрать учебную группу"),
        BotCommand(command="bells", description="Расписание звонков"),
        BotCommand(command="exams", description="Расписание экзаменов"),
        BotCommand(command="settings", description="Настройки и уведомления"),
        BotCommand(command="about", description="О проекте и разработчике"),
        BotCommand(command="help", description="Справка по командам"),
    ]
    await bot.set_my_commands(commands)
    try:
        await bot.set_chat_menu_button(
            menu_button=MenuButtonWebApp(
                text="Расписание",
                web_app=WebAppInfo(url=WEBAPP_URL)
            )
        )
    except Exception as e:
        logger.warning("Не удалось установить MenuButtonWebApp: %s", e)

async def main():
    logger.info("Инициализация базы данных...")
    await init_db()

    bot = Bot(
        token=BOT_TOKEN,
        default=DefaultBotProperties(parse_mode=ParseMode.HTML)
    )
    dp = Dispatcher()
    dp.include_router(main_router)

    await set_bot_commands(bot)
    
    bot_info = await bot.get_me()
    logger.info("Бот успешно запущен: @%s", bot_info.username)

    # Запуск встроенного веб-сервера для Mini App
    web_runner = await start_web_server(WEB_HOST, WEB_PORT)

    notifier = ScheduleNotifier(bot)
    notifier_task = asyncio.create_task(notifier.start_loop())

    try:
        await dp.start_polling(bot, allowed_updates=dp.resolve_used_update_types())
    finally:
        notifier_task.cancel()
        await web_runner.cleanup()
        await api_client.close()
        await bot.session.close()

if __name__ == "__main__":
    try:
        asyncio.run(main())
    except (KeyboardInterrupt, SystemExit):
        logger.info("Бот остановлен.")
