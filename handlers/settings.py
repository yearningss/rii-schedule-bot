# Обработчики настроек пользователя, фильтрации подгрупп и управления уведомлениями
from aiogram import Router, F
from aiogram.filters import Command
from aiogram.types import Message, CallbackQuery

from database import get_user, set_user_subgroup, update_user_notifications
from keyboards import get_settings_keyboard

router = Router()

def format_settings_text(user: dict) -> str:
    subgroup = user.get("subgroup", 0)
    sg_text = "Все подгруппы" if subgroup == 0 else f"{subgroup}-я подгруппа"
    notif = "Включены" if user.get("notifications_enabled", 1) == 1 else "Отключены"
    before = user.get("notify_before_mins", 10)
    before_text = f"За {before} минут" if before > 0 else "Отключено"
    breaks = "Включены" if user.get("notify_breaks", 1) == 1 else "Отключены"
    start = "Включены" if user.get("notify_lesson_start", 1) == 1 else "Отключены"

    return (
        f"Настройки пользователя:\n"
        f"Группа: {user.get('group_name', 'Не выбрана')}\n"
        f"Подгруппа: {sg_text}\n"
        f"Главные уведомления: {notif}\n"
        f"Напоминание перед парой: {before_text}\n"
        f"Оповещение о переменах: {breaks}\n"
        f"Оповещение о начале пары: {start}\n\n"
        "Нажимай на кнопки ниже для изменения параметров:"
    )

@router.message(Command("settings"))
@router.message(F.text == "Настройки")
async def show_settings(message: Message):
    user = await get_user(message.from_user.id)
    if not user or not user.get("group_name"):
        await message.answer("Сначала выбери группу с помощью команды /group.")
        return

    text = format_settings_text(user)
    await message.answer(text, reply_markup=get_settings_keyboard(user))

@router.callback_query(F.data == "toggle_notif")
async def cb_toggle_notif(callback: CallbackQuery):
    user = await get_user(callback.from_user.id)
    new_val = 0 if user.get("notifications_enabled", 1) == 1 else 1
    await update_user_notifications(callback.from_user.id, notifications_enabled=new_val)
    
    updated_user = await get_user(callback.from_user.id)
    text = format_settings_text(updated_user)
    try:
        await callback.message.edit_text(text, reply_markup=get_settings_keyboard(updated_user))
    except Exception:
        pass
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
    except Exception:
        pass
    label = f"За {mins} мин" if mins > 0 else "Выключено"
    await callback.answer(f"Напоминание: {label}")

@router.callback_query(F.data == "toggle_breaks")
async def cb_toggle_breaks(callback: CallbackQuery):
    user = await get_user(callback.from_user.id)
    new_val = 0 if user.get("notify_breaks", 1) == 1 else 1
    await update_user_notifications(callback.from_user.id, notify_breaks=new_val)
    
    updated_user = await get_user(callback.from_user.id)
    text = format_settings_text(updated_user)
    try:
        await callback.message.edit_text(text, reply_markup=get_settings_keyboard(updated_user))
    except Exception:
        pass
    status_label = "включены" if new_val == 1 else "отключены"
    await callback.answer(f"Оповещения о переменах {status_label}")

@router.callback_query(F.data == "toggle_start")
async def cb_toggle_start(callback: CallbackQuery):
    user = await get_user(callback.from_user.id)
    new_val = 0 if user.get("notify_lesson_start", 1) == 1 else 1
    await update_user_notifications(callback.from_user.id, notify_lesson_start=new_val)
    
    updated_user = await get_user(callback.from_user.id)
    text = format_settings_text(updated_user)
    try:
        await callback.message.edit_text(text, reply_markup=get_settings_keyboard(updated_user))
    except Exception:
        pass
    status_label = "включены" if new_val == 1 else "отключены"
    await callback.answer(f"Оповещения о начале пар {status_label}")

@router.callback_query(F.data.startswith("set_sg:"))
async def cb_set_subgroup(callback: CallbackQuery):
    subgroup = int(callback.data.split(":")[1])
    await set_user_subgroup(callback.from_user.id, subgroup)
    
    updated_user = await get_user(callback.from_user.id)
    text = format_settings_text(updated_user)
    try:
        await callback.message.edit_text(text, reply_markup=get_settings_keyboard(updated_user))
    except Exception:
        pass
    sg_label = "Все подгруппы" if subgroup == 0 else f"{subgroup}-я подгруппа"
    await callback.answer(f"Выбрано: {sg_label}")
