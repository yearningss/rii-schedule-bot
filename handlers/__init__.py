# Регистрация и объединение всех роутеров бота
from aiogram import Router
from handlers.schedule import router as schedule_router
from handlers.settings import router as settings_router
from handlers.start import router as start_router

main_router = Router()
main_router.include_router(schedule_router)
main_router.include_router(settings_router)
main_router.include_router(start_router)
