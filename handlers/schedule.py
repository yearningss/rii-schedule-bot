# Обработчики просмотра расписания (сегодня, завтра, недели, звонки, экзамены)
from aiogram import Router, F
from aiogram.filters import Command
from aiogram.types import Message, CallbackQuery, InlineKeyboardMarkup, InlineKeyboardButton, WebAppInfo

from database import get_user
from services.api import (
    api_client,
    format_day_schedule,
    format_week_schedule,
    format_bells,
    format_exams
)
from keyboards import get_day_nav_keyboard, get_courses_keyboard
from config import WEBAPP_URL

router = Router()

async def ensure_user_group(message_or_call) -> tuple:
    user_id = message_or_call.from_user.id
    user = await get_user(user_id)
    if not user or not user.get("group_id"):
        courses_map = await api_client.get_courses_map()
        text = "Сначала выбери свою учебную группу:"
        kb = get_courses_keyboard(list(courses_map.keys()))
        if isinstance(message_or_call, Message):
            await message_or_call.answer(text, reply_markup=kb)
        else:
            await message_or_call.message.answer(text, reply_markup=kb)
            await message_or_call.answer()
        return None, None
    return user, user["group_id"]

@router.message(Command("today"))
@router.message(F.text == "Сегодня")
async def show_today(message: Message):
    user, group_id = await ensure_user_group(message)
    if not user:
        return

    sched = await api_client.get_schedule(group_id)
    if not sched:
        await message.answer("Не удалось получить данные о расписании. Попробуй позже.")
        return

    cur_week = int(sched.get("weekNumber", 1))
    cur_day = int(sched.get("dayNumber", 1))
    subgroup = user.get("subgroup", 0)

    if cur_day > 6:
        cur_day = 1
        note = "Сегодня воскресенье (пар нет). Расписание на понедельник:\n\n"
    else:
        note = ""

    text = note + format_day_schedule(user["group_name"], sched, cur_week, cur_day, subgroup)
    await message.answer(text, reply_markup=get_day_nav_keyboard(cur_week, cur_day, group_id))

@router.message(Command("tomorrow"))
@router.message(F.text == "Завтра")
async def show_tomorrow(message: Message):
    user, group_id = await ensure_user_group(message)
    if not user:
        return

    sched = await api_client.get_schedule(group_id)
    if not sched:
        await message.answer("Не удалось получить расписание. Попробуй позже.")
        return

    cur_week = int(sched.get("weekNumber", 1))
    cur_day = int(sched.get("dayNumber", 1))
    subgroup = user.get("subgroup", 0)

    if cur_day >= 6:
        next_day = 1
        next_week = 2 if cur_week == 1 else 1
    else:
        next_day = cur_day + 1
        next_week = cur_week

    text = format_day_schedule(user["group_name"], sched, next_week, next_day, subgroup)
    await message.answer(text, reply_markup=get_day_nav_keyboard(next_week, next_day, group_id))

@router.message(Command("week"))
@router.message(F.text == "Текущая неделя")
async def show_current_week(message: Message):
    user, group_id = await ensure_user_group(message)
    if not user:
        return

    sched = await api_client.get_schedule(group_id)
    if not sched:
        await message.answer("Не удалось получить расписание. Попробуй позже.")
        return

    cur_week = int(sched.get("weekNumber", 1))
    subgroup = user.get("subgroup", 0)
    parts = format_week_schedule(user["group_name"], sched, cur_week, subgroup)
    for part in parts:
        await message.answer(part)

@router.message(Command("nextweek"))
@router.message(F.text == "Следующая неделя")
async def show_next_week(message: Message):
    user, group_id = await ensure_user_group(message)
    if not user:
        return

    sched = await api_client.get_schedule(group_id)
    if not sched:
        await message.answer("Не удалось получить расписание. Попробуй позже.")
        return

    cur_week = int(sched.get("weekNumber", 1))
    next_week = 2 if cur_week == 1 else 1
    subgroup = user.get("subgroup", 0)
    parts = format_week_schedule(user["group_name"], sched, next_week, subgroup)
    for part in parts:
        await message.answer(part)

@router.message(Command("bells"))
@router.message(F.text == "Звонки")
async def show_bells(message: Message):
    user = await get_user(message.from_user.id)
    sched = {}
    if user and user.get("group_id"):
        sched = await api_client.get_schedule(user["group_id"])
    text = format_bells(sched)
    await message.answer(text)

@router.message(Command("exams"))
@router.message(F.text == "Экзамены")
async def show_exams(message: Message):
    user, group_id = await ensure_user_group(message)
    if not user:
        return

    sched = await api_client.get_schedule(group_id)
    if not sched:
        await message.answer("Не удалось получить расписание. Попробуй позже.")
        return

    text = format_exams(user["group_name"], sched)
    await message.answer(text)

@router.message(Command("about"))
@router.message(F.text == "О проекте")
async def show_about(message: Message):
    text = (
        "Телеграм-бот с расписанием Рубцовского индустриального института (РИИ АлтГТУ).\n\n"
        "Разработчик: yearningss (Влад)\n"
        "GitHub: https://github.com/yearningss/rii-schedule-bot\n"
        "Связь и обратная связь: yearwist@gmail.com / doki@dotirr.ru\n\n"
        "Проект полностью с открытым исходным кодом. Расписание и список групп подтягиваются динамически с сервера rubinst.ru."
    )
    kb = InlineKeyboardMarkup(inline_keyboard=[
        [InlineKeyboardButton(text="Открыть расписание (Mini App)", web_app=WebAppInfo(url=WEBAPP_URL))],
        [InlineKeyboardButton(text="Репозиторий на GitHub", url="https://github.com/yearningss/rii-schedule-bot")]
    ])
    await message.answer(text, reply_markup=kb)

@router.callback_query(F.data.startswith("nav_day:"))
async def cb_navigate_day(callback: CallbackQuery):
    parts = callback.data.split(":")
    week_num = int(parts[1])
    day_num = int(parts[2])

    user = await get_user(callback.from_user.id)
    if not user or not user.get("group_id"):
        await callback.answer("Группа не выбрана.", show_alert=True)
        return

    sched = await api_client.get_schedule(user["group_id"])
    subgroup = user.get("subgroup", 0)
    text = format_day_schedule(user["group_name"], sched, week_num, day_num, subgroup)

    try:
        await callback.message.edit_text(text, reply_markup=get_day_nav_keyboard(week_num, day_num, user["group_id"]))
    except Exception:
        pass
    finally:
        await callback.answer()

@router.callback_query(F.data.startswith("refresh_day:"))
async def cb_refresh_day(callback: CallbackQuery):
    parts = callback.data.split(":")
    week_num = int(parts[1])
    day_num = int(parts[2])

    user = await get_user(callback.from_user.id)
    if not user or not user.get("group_id"):
        await callback.answer("Группа не выбрана.", show_alert=True)
        return

    sched = await api_client.get_schedule(user["group_id"], force_refresh=True)
    subgroup = user.get("subgroup", 0)
    text = format_day_schedule(user["group_name"], sched, week_num, day_num, subgroup)

    try:
        await callback.message.edit_text(text, reply_markup=get_day_nav_keyboard(week_num, day_num, user["group_id"]))
    except Exception:
        pass
    finally:
        await callback.answer("Расписание обновлено")
