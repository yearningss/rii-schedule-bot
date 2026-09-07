# Обработчики настроек пользователя, фильтрации подгрупп и управления уведомлениями
import logging
from aiogram import Router, F
from aiogram.filters import Command
from aiogram.types import Message, CallbackQuery
from aiogram.exceptions import TelegramBadRequest

from database import get_user, set_user_subgroup, update_user_notifications
from keyboards import get_settings_keyboard, get_courses_keyboard
from services.api import api_client

logger = logging.getLogger("rii_schedule_bot.settings")
router = Router()

def format_settings_text(user: dict) -> str:
    subgroup = user.get("subgroup", 0)
    sg_text = "Все подгруппы" if subgroup == 0 else f"{subgroup}-я подгруппа"
    notif = "Включены" if user.get("notifications_enabled", 1) == 1 else "Отключены"
    before = user.get("notify_before_mins", 10)
    before_text = f"За {before} минут" if before > 0 else "Отключено"
    breaks = "Включены" if user.get("notify_breaks", 1) == 1 else "Отключены"
    start = "Включены" if user.get("notify_lesson_start", 1) == 1 else "Отключены"
    changes = "Включены" if user.get("notify_changes", 1) == 1 else "Отключены"
    mobile_app = "Подключено" if user.get("has_mobile_app", 0) == 1 else "Не подключено"

    return (
        f"Настройки пользователя:\n"
        f"Группа: {user.get('group_name', 'Не выбрана')}\n"
        f"Подгруппа: {sg_text}\n"
        f"Мобильное приложение: {mobile_app}\n"
        f"Главные уведомления: {notif}\n"
        f"Напоминание перед парой: {before_text}\n"
        f"Оповещение о переменах: {breaks}\n"
        f"Оповещение о начале пары: {start}\n"
        f"Оповещение о правках на завтра: {changes}\n\n"
        "Нажимай на кнопки ниже для изменения параметров:"
    )

@router.message(Command("settings", "настройки", ignore_case=True))
@router.message(F.text.casefold().in_({"настройки", "настройка", "уведомления"}))
async def show_settings(message: Message):
    user = await get_user(message.from_user.id)
    if not user or not user.get("group_name"):
        courses_map = await api_client.get_courses_map()
        await message.answer(
            "Для настройки параметров и уведомлений сначала выбери свою учебную группу:",
            reply_markup=get_courses_keyboard(list(courses_map.keys()))
        )
        return

    text = format_settings_text(user)
    await message.answer(text, reply_markup=get_settings_keyboard(user))

@router.callback_query(F.data == "toggle_notif")
async def cb_toggle_notif(callback: CallbackQuery):
    user = await get_user(callback.from_user.id)
    if not user:
        await callback.answer("Пользователь не найден.")
        return

    new_val = 0 if user.get("notifications_enabled", 1) == 1 else 1
    await update_user_notifications(callback.from_user.id, notifications_enabled=new_val)
    
    updated_user = await get_user(callback.from_user.id)
    text = format_settings_text(updated_user)
    try:
        await callback.message.edit_text(text, reply_markup=get_settings_keyboard(updated_user))
    except TelegramBadRequest:
        pass
    except Exception as e:
        logger.warning("Ошибка в cb_toggle_notif: %s", e)
    status_label = "включены" if new_val == 1 else "отключены"
    await callback.answer(f"Уведомления {status_label}")

@router.callback_query(F.data.startswith("set_before:"))
async def cb_set_before(callback: CallbackQuery):
    mins = int(callback.data.split(":")[1])
    await update_user_notifications(callback.from_user.id, notify_before_mins=mins)
    
    updated_user = await get_user(callback.from_user.id)
    text = format_settings_text(updated_user)
    try:
        await callback.message.edit_text(text, reply_markup=get_settings_keyboard(updated_user))
    except TelegramBadRequest:
        pass
    except Exception as e:
        logger.warning("Ошибка в cb_set_before: %s", e)
    label = f"За {mins} мин" if mins > 0 else "Выключено"
    await callback.answer(f"Напоминание: {label}")

@router.callback_query(F.data == "toggle_breaks")
async def cb_toggle_breaks(callback: CallbackQuery):
    user = await get_user(callback.from_user.id)
    if not user:
        await callback.answer()
        return

    new_val = 0 if user.get("notify_breaks", 1) == 1 else 1
    await update_user_notifications(callback.from_user.id, notify_breaks=new_val)
    
    updated_user = await get_user(callback.from_user.id)
    text = format_settings_text(updated_user)
    try:
        await callback.message.edit_text(text, reply_markup=get_settings_keyboard(updated_user))
    except TelegramBadRequest:
        pass
    except Exception as e:
        logger.warning("Ошибка в cb_toggle_breaks: %s", e)
    status_label = "включены" if new_val == 1 else "отключены"
    await callback.answer(f"Оповещения о переменах {status_label}")

@router.callback_query(F.data == "toggle_start")
async def cb_toggle_start(callback: CallbackQuery):
    user = await get_user(callback.from_user.id)
    if not user:
        await callback.answer()
        return

    new_val = 0 if user.get("notify_lesson_start", 1) == 1 else 1
    await update_user_notifications(callback.from_user.id, notify_lesson_start=new_val)
    
    updated_user = await get_user(callback.from_user.id)
    text = format_settings_text(updated_user)
    try:
        await callback.message.edit_text(text, reply_markup=get_settings_keyboard(updated_user))
    except TelegramBadRequest:
        pass
    except Exception as e:
        logger.warning("Ошибка в cb_toggle_start: %s", e)
    status_label = "включены" if new_val == 1 else "отключены"
    await callback.answer(f"Оповещения о начале пар {status_label}")

@router.callback_query(F.data == "toggle_changes")
async def cb_toggle_changes(callback: CallbackQuery):
    user = await get_user(callback.from_user.id)
    if not user:
        await callback.answer()
        return

    new_val = 0 if user.get("notify_changes", 1) == 1 else 1
    await update_user_notifications(callback.from_user.id, notify_changes=new_val)
    
    updated_user = await get_user(callback.from_user.id)
    text = format_settings_text(updated_user)
    try:
        await callback.message.edit_text(text, reply_markup=get_settings_keyboard(updated_user))
    except TelegramBadRequest:
        pass
    except Exception as e:
        logger.warning("Ошибка в cb_toggle_changes: %s", e)
    status_label = "включены" if new_val == 1 else "отключены"
    await callback.answer(f"Оповещения о правках {status_label}")

@router.callback_query(F.data.startswith("set_sg:"))
async def cb_set_subgroup(callback: CallbackQuery):
    subgroup = int(callback.data.split(":")[1])
    await set_user_subgroup(callback.from_user.id, subgroup)
    
    updated_user = await get_user(callback.from_user.id)
    text = format_settings_text(updated_user)
    try:
        await callback.message.edit_text(text, reply_markup=get_settings_keyboard(updated_user))
    except TelegramBadRequest:
        pass
    except Exception as e:
        logger.warning("Ошибка в cb_set_subgroup: %s", e)
    sg_label = "Все подгруппы" if subgroup == 0 else f"{subgroup}-я подгруппа"
    await callback.answer(f"Выбрано: {sg_label}")

@router.callback_query(F.data == "cancel_course_select")
async def cb_cancel_course_select(callback: CallbackQuery):
    user = await get_user(callback.from_user.id)
    if not user or not user.get("group_name"):
        await callback.answer()
        return
    text = format_settings_text(user)
    try:
        await callback.message.edit_text(text, reply_markup=get_settings_keyboard(user))
    except TelegramBadRequest:
        pass
    except Exception as e:
        logger.warning("Ошибка в cb_cancel_course_select: %s", e)
    finally:
        await callback.answer()
