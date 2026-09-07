# Обработчики просмотра расписания (сегодня, завтра, недели, текущий статус, звонки, экзамены, Web App)
import logging
from aiogram import Router, F
from aiogram.filters import Command
from aiogram.types import Message, CallbackQuery, InlineKeyboardMarkup, InlineKeyboardButton, WebAppInfo
from aiogram.exceptions import TelegramBadRequest

from database import get_user
from services.api import (
    api_client,
    format_day_schedule,
    format_week_schedule,
    format_bells,
    format_exams,
    format_now_status,
    get_rubtsovsk_now
)
from keyboards import (
    get_day_nav_keyboard,
    get_week_nav_keyboard,
    get_now_nav_keyboard,
    get_courses_keyboard
)
from config import WEBAPP_URL

logger = logging.getLogger("rii_schedule_bot.schedule")
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
            try:
                await message_or_call.message.answer(text, reply_markup=kb)
            except Exception:
                pass
            await message_or_call.answer()
        return None, None
    return user, user["group_id"]

@router.message(Command("today", "сегодня", ignore_case=True))
@router.message(F.text.casefold().in_({"сегодня", "пары сегодня", "расписание на сегодня", "седня"}))
async def show_today(message: Message):
    user, group_id = await ensure_user_group(message)
    if not user:
        return

    sched = await api_client.get_schedule(group_id)
    if not sched:
        await message.answer("Не удалось получить данные о расписании. Попробуй позже.")
        return

    now = get_rubtsovsk_now()
    real_weekday = now.isoweekday()  # 1=Пн .. 6=Сб, 7=Вс
    site_week = int(sched.get("weekNumber", 1))
    subgroup = user.get("subgroup", 0)

    if real_weekday > 6:
        # Воскресенье: показываем понедельник следующей учебной недели
        cur_day = 1
        cur_week = 2 if site_week == 1 else 1
        note = "Сегодня воскресенье (выходной). Расписание на понедельник:\n\n"
    else:
        cur_day = real_weekday
        cur_week = site_week
        note = ""

    text = note + format_day_schedule(user["group_name"], sched, cur_week, cur_day, subgroup)
    await message.answer(text, reply_markup=get_day_nav_keyboard(cur_week, cur_day, group_id))

@router.message(Command("tomorrow", "завтра", ignore_case=True))
@router.message(F.text.casefold().in_({"завтра", "пары завтра", "расписание на завтра"}))
async def show_tomorrow(message: Message):
    user, group_id = await ensure_user_group(message)
    if not user:
        return

    sched = await api_client.get_schedule(group_id)
    if not sched:
        await message.answer("Не удалось получить расписание. Попробуй позже.")
        return

    now = get_rubtsovsk_now()
    real_weekday = now.isoweekday()
    site_week = int(sched.get("weekNumber", 1))
    subgroup = user.get("subgroup", 0)

    note = ""
    if real_weekday >= 6:
        # Суббота или воскресенье: завтра выходной или рабочий понедельник
        next_day = 1
        next_week = 2 if site_week == 1 else 1
        if real_weekday == 6:
            note = "Завтра воскресенье (выходной). Расписание на понедельник:\n\n"
    else:
        next_day = real_weekday + 1
        next_week = site_week

    text = note + format_day_schedule(user["group_name"], sched, next_week, next_day, subgroup)
    await message.answer(text, reply_markup=get_day_nav_keyboard(next_week, next_day, group_id))

@router.message(Command("now", "сейчас", ignore_case=True))
@router.message(F.text.casefold().in_({"сейчас", "пара сейчас", "какая пара", "что сейчас"}))
async def show_now(message: Message):
    user, group_id = await ensure_user_group(message)
    if not user:
        return

    sched = await api_client.get_schedule(group_id)
    if not sched:
        await message.answer("Не удалось получить расписание. Попробуй позже.")
        return

    subgroup = user.get("subgroup", 0)
    text = format_now_status(user["group_name"], sched, subgroup)
    await message.answer(text, reply_markup=get_now_nav_keyboard(group_id))

@router.message(Command("week", "неделя", ignore_case=True))
@router.message(F.text.casefold().in_({"текущая неделя", "неделя", "расписание на неделю", "эта неделя", "1 неделя", "i неделя"}))
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
    kb = get_week_nav_keyboard(cur_week, group_id)
    for idx, part in enumerate(parts):
        reply_kb = kb if idx == len(parts) - 1 else None
        await message.answer(part, reply_markup=reply_kb)

@router.message(Command("nextweek", "следнеделя", ignore_case=True))
@router.message(F.text.casefold().in_({"следующая неделя", "след неделя", "след. неделя", "будущая неделя", "2 неделя", "ii неделя"}))
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
    kb = get_week_nav_keyboard(next_week, group_id)
    for idx, part in enumerate(parts):
        reply_kb = kb if idx == len(parts) - 1 else None
        await message.answer(part, reply_markup=reply_kb)

@router.message(Command("bells", "звонки", ignore_case=True))
@router.message(F.text.casefold().in_({"звонки", "расписание звонков", "время пар", "звонок"}))
async def show_bells(message: Message):
    user = await get_user(message.from_user.id)
    sched = {}
    if user and user.get("group_id"):
        sched = await api_client.get_schedule(user["group_id"])
    text = format_bells(sched)
    await message.answer(text)

@router.message(Command("exams", "экзамены", "сессия", ignore_case=True))
@router.message(F.text.casefold().in_({"экзамены", "сессия", "расписание экзаменов", "зачеты"}))
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

@router.message(Command("about", "инфо", "автор", ignore_case=True))
@router.message(F.text.casefold().in_({"о проекте", "информация", "инфо", "разработчик", "автор", "github"}))
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

@router.message(Command("app", "webapp", "miniapp", "приложение", ignore_case=True))
@router.message(F.text.casefold().in_({
    "открыть расписание (web app)",
    "открыть расписание (mini app)",
    "открыть расписание",
    "расписание",
    "web app",
    "mini app",
    "приложение",
    "скачать приложение"
}))
async def show_app(message: Message):
    user = await get_user(message.from_user.id)
    gid = user.get("group_id") if user else None
    url = f"{WEBAPP_URL}?group_id={gid}" if gid else WEBAPP_URL
    kb = InlineKeyboardMarkup(inline_keyboard=[
        [InlineKeyboardButton(text="Открыть расписание (Mini App)", web_app=WebAppInfo(url=url))]
    ])
    await message.answer(
        "Нажми кнопку ниже, чтобы открыть интерактивное расписание РИИ в приложении:",
        reply_markup=kb
    )

@router.callback_query(F.data.startswith("nav_day:"))
async def cb_navigate_day(callback: CallbackQuery):
    parts = callback.data.split(":")
    week_num = int(parts[1])
    day_num = int(parts[2])

    user = await get_user(callback.from_user.id)
    if not user or not user.get("group_id"):
        await callback.answer("Группа не выбрана.", show_alert=True)
        return

    try:
        sched = await api_client.get_schedule(user["group_id"])
        subgroup = user.get("subgroup", 0)
        text = format_day_schedule(user["group_name"], sched, week_num, day_num, subgroup)
        await callback.message.edit_text(text, reply_markup=get_day_nav_keyboard(week_num, day_num, user["group_id"]))
    except TelegramBadRequest as e:
        if "message is not modified" in str(e).lower():
            pass
        else:
            logger.warning("Ошибка редактирования сообщения в cb_navigate_day: %s", e)
    except Exception as e:
        logger.exception("Непредвиденная ошибка в cb_navigate_day: %s", e)
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

    try:
        sched = await api_client.get_schedule(user["group_id"], force_refresh=True)
        subgroup = user.get("subgroup", 0)
        text = format_day_schedule(user["group_name"], sched, week_num, day_num, subgroup)
        await callback.message.edit_text(text, reply_markup=get_day_nav_keyboard(week_num, day_num, user["group_id"]))
        await callback.answer("Расписание обновлено")
    except TelegramBadRequest as e:
        if "message is not modified" in str(e).lower():
            await callback.answer("Расписание уже актуально")
        else:
            logger.warning("Ошибка обновления сообщения в cb_refresh_day: %s", e)
            await callback.answer("Ошибка при обновлении")
    except Exception as e:
        logger.exception("Непредвиденная ошибка в cb_refresh_day: %s", e)
        await callback.answer("Не удалось обновить")

@router.callback_query(F.data.startswith("nav_week:"))
async def cb_navigate_week(callback: CallbackQuery):
    week_num = int(callback.data.split(":")[1])
    user = await get_user(callback.from_user.id)
    if not user or not user.get("group_id"):
        await callback.answer("Группа не выбрана.", show_alert=True)
        return

    try:
        sched = await api_client.get_schedule(user["group_id"])
        subgroup = user.get("subgroup", 0)
        parts = format_week_schedule(user["group_name"], sched, week_num, subgroup)
        kb = get_week_nav_keyboard(week_num, user["group_id"])
        if len(parts) == 1:
            await callback.message.edit_text(parts[0], reply_markup=kb)
        else:
            try:
                await callback.message.delete()
            except Exception:
                pass
            for idx, p in enumerate(parts):
                reply_kb = kb if idx == len(parts) - 1 else None
                await callback.message.answer(p, reply_markup=reply_kb)
    except TelegramBadRequest as e:
        if "message is not modified" in str(e).lower():
            pass
        else:
            logger.warning("Ошибка переключения недели: %s", e)
    except Exception as e:
        logger.exception("Непредвиденная ошибка в cb_navigate_week: %s", e)
    finally:
        await callback.answer()

@router.callback_query(F.data.startswith("refresh_week:"))
async def cb_refresh_week(callback: CallbackQuery):
    week_num = int(callback.data.split(":")[1])
    user = await get_user(callback.from_user.id)
    if not user or not user.get("group_id"):
        await callback.answer("Группа не выбрана.", show_alert=True)
        return

    try:
        sched = await api_client.get_schedule(user["group_id"], force_refresh=True)
        subgroup = user.get("subgroup", 0)
        parts = format_week_schedule(user["group_name"], sched, week_num, subgroup)
        kb = get_week_nav_keyboard(week_num, user["group_id"])
        if len(parts) == 1:
            await callback.message.edit_text(parts[0], reply_markup=kb)
        else:
            try:
                await callback.message.delete()
            except Exception:
                pass
            for idx, p in enumerate(parts):
                reply_kb = kb if idx == len(parts) - 1 else None
                await callback.message.answer(p, reply_markup=reply_kb)
        await callback.answer("Расписание недели обновлено")
    except TelegramBadRequest as e:
        if "message is not modified" in str(e).lower():
            await callback.answer("Расписание недели уже актуально")
        else:
            await callback.answer("Ошибка при обновлении")
    except Exception as e:
        logger.exception("Ошибка обновления недели: %s", e)
        await callback.answer("Не удалось обновить")

@router.callback_query(F.data == "refresh_now")
async def cb_refresh_now(callback: CallbackQuery):
    user = await get_user(callback.from_user.id)
    if not user or not user.get("group_id"):
        await callback.answer("Группа не выбрана.", show_alert=True)
        return

    try:
        sched = await api_client.get_schedule(user["group_id"], force_refresh=True)
        subgroup = user.get("subgroup", 0)
        text = format_now_status(user["group_name"], sched, subgroup)
        await callback.message.edit_text(text, reply_markup=get_now_nav_keyboard(user["group_id"]))
        await callback.answer("Статус обновлен")
    except TelegramBadRequest as e:
        if "message is not modified" in str(e).lower():
            await callback.answer("Статус не изменился")
        else:
            await callback.answer("Ошибка при обновлении")
    except Exception as e:
        logger.exception("Ошибка обновления текущего статуса: %s", e)
        await callback.answer("Не удалось обновить")

@router.callback_query(F.data == "nav_today")
async def cb_nav_today(callback: CallbackQuery):
    user = await get_user(callback.from_user.id)
    if not user or not user.get("group_id"):
        await callback.answer("Группа не выбрана.", show_alert=True)
        return

    try:
        sched = await api_client.get_schedule(user["group_id"])
        subgroup = user.get("subgroup", 0)
        now = get_rubtsovsk_now()
        real_weekday = now.isoweekday()
        site_week = int(sched.get("weekNumber", 1))
        cur_day = 1 if real_weekday > 6 else real_weekday
        cur_week = (2 if site_week == 1 else 1) if real_weekday > 6 else site_week
        text = format_day_schedule(user["group_name"], sched, cur_week, cur_day, subgroup)
        await callback.message.edit_text(text, reply_markup=get_day_nav_keyboard(cur_week, cur_day, user["group_id"]))
    except TelegramBadRequest as e:
        if "message is not modified" in str(e).lower():
            pass
        else:
            logger.warning("Ошибка в cb_nav_today: %s", e)
    except Exception as e:
        logger.exception("Ошибка перехода к сегодняшнему расписанию: %s", e)
    finally:
        await callback.answer()
