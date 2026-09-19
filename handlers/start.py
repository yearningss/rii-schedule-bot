# Обработчики команды /start, справки, выбора и поиска группы
from __future__ import annotations

import os
import logging
from typing import Optional, List, Dict, Any

from aiogram import Router, F
from aiogram.filters import CommandStart, Command, CommandObject
from aiogram.types import (
    Message, CallbackQuery, InlineKeyboardMarkup, InlineKeyboardButton,
    WebAppInfo, ReplyKeyboardMarkup
)
from aiogram.exceptions import TelegramBadRequest

from database import (
    get_user, set_user_group, set_user_has_seen_guide,
    get_auth_session, confirm_auth_session
)
from services.api import api_client
from keyboards import (
    get_main_keyboard, get_courses_keyboard, get_groups_keyboard,
    get_guide_keyboard
)
from config import WEBAPP_URL

logger = logging.getLogger("rii_schedule_bot.start")
router = Router()

DISCLAIMER = (
    "Это неофициальный бот с расписанием РИИ АлтГТУ. Сделан по приколу и для удобства.\n"
    "Исходный код полностью открыт на GitHub: https://github.com/yearningss/rii-schedule-bot"
)

GUIDE_PAGES = {
    1: (
        "Руководство пользователя: Раздел 1 из 4 (Меню и расписание)\n\n"
        "Кнопки быстрого меню внизу экрана:\n"
        "- «Сегодня»: расписание на текущий день с аудиториями, временем и именами преподавателей.\n"
        "- «Завтра»: расписание на следующий учебный день (в субботу автоматически показывает пары понедельника).\n"
        "- «Неделя»: полное расписание на текущую учебную неделю.\n"
        "- «Настройки»: переключение подгруппы (1 / 2 подгруппа), времени напоминаний и смена группы.\n\n"
        "Быстрые команды бота:\n"
        "/today - расписание на сегодня\n"
        "/tomorrow - расписание на завтра\n"
        "/now - пара, которая идет прямо сейчас, и сколько минут до конца\n"
        "/week - расписание на текущую неделю\n"
        "/nextweek - расписание на следующую неделю\n"
        "/bells - точное время звонков и перемен\n"
        "/exams - расписание сессии, консультаций и экзаменов\n"
        "/menu - вернуть клавиатуру с кнопками внизу экрана"
    ),
    2: (
        "Руководство пользователя: Раздел 2 из 4 (Mini App и подгруппы)\n\n"
        "Интерактивное веб-приложение (Mini App):\n"
        "- Нажмите кнопку «Расписание» слева от поля ввода текста или отправьте команду /app.\n"
        "- Откроется интерактивное расписание с переключением дней и недель.\n"
        "- Встроенный календарь: можно быстро выбрать любую дату.\n"
        "- Оффлайн-режим: однажды открытое расписание сохраняется на устройстве и работает даже при отсутствии интернета на паре.\n\n"
        "Фильтрация по 1 и 2 подгруппам:\n"
        "- Практические и лабораторные занятия часто делятся на подгруппы.\n"
        "- В Mini App вверху экрана есть переключатель: «Все», «1 п/г», «2 п/г».\n"
        "- В самом боте вы можете зафиксировать подгруппу в разделе «Настройки» (/settings), чтобы видеть только свои пары."
    ),
    3: (
        "Руководство пользователя: Раздел 3 из 4 (Умные уведомления)\n\n"
        "Как работают напоминания:\n"
        "- Перед началом занятий: бот присылает сообщение за 10 минут до первой пары дня с указанием аудитории и предмета.\n"
        "- На переменах: бот заранее напоминает о следующей паре и кабинете.\n"
        "- Оповещения об изменениях: если на официальном сайте института изменилось расписание на завтра, бот предупредит об этом вечером.\n\n"
        "Управление уведомлениями:\n"
        "- Откройте раздел «Настройки» или введите команду /settings.\n"
        "- Доступны опции:\n"
        "  - За сколько минут предупреждать: за 10 минут, за 5 минут или без предварительного оповещения.\n"
        "  - Включение / выключение напоминаний о переменах.\n"
        "  - Включение / выключение оповещений о начале занятий.\n"
        "  - Включение / выключение оповещений об изменениях."
    ),
    4: (
        "Руководство пользователя: Раздел 4 из 4 (Поиск и чаты)\n\n"
        "Поиск расписания преподавателей:\n"
        "- Просто напишите фамилию преподавателя в чат с ботом (например: Иванов).\n"
        "- Бот найдет преподавателя и покажет его пары на сегодня и ближайшие дни.\n\n"
        "Работа в беседах групп:\n"
        "- Добавьте бота в чат вашей группы.\n"
        "- Администратор группы закрепляет учебную группу командой /group.\n"
        "- Все студенты могут смотреть расписание через команды прямо в общей беседе.\n\n"
        "Мобильное приложение:\n"
        "- Приложение для Android и iOS с виджетами на рабочий стол: /download"
    )
}


async def is_chat_admin(bot, chat_id: int, user_id: int) -> bool:
    try:
        member = await bot.get_chat_member(chat_id, user_id)
        return member.status in ("creator", "administrator")
    except Exception:
        return True

async def get_reply_markup_for_chat(message: Message, group_id: Optional[int] = None) -> Optional[ReplyKeyboardMarkup]:
    if message.chat.type == "private":
        return get_main_keyboard(group_id, selective=False)

    chat_user = await get_user(message.chat.id)
    mode = chat_user.get("group_kb_mode", "selective") if chat_user else "selective"
    if mode == "none":
        return None
    elif mode == "all":
        return get_main_keyboard(group_id, selective=False)
    else:
        return get_main_keyboard(group_id, selective=True)

@router.message(CommandStart())
async def cmd_start(message: Message, command: CommandObject = None):
    # Проверка диплинка авторизации мобильного приложения (tg://resolve?domain=rubinst_bot&start=auth_TOKEN)
    if command and command.args and command.args.startswith("auth_"):
        session_token = command.args[5:].strip()
        session = await get_auth_session(session_token)
        if not session:
            await message.answer("Сессия авторизации не найдена или уже недействительна.")
            return
        if session.get("status") == "expired":
            await message.answer("Время действия запроса на вход истекло. Запросите новую ссылку в приложении.")
            return
        if session.get("status") == "confirmed":
            await message.answer("Этот запрос на вход уже был подтвержден ранее.")
            return

        user = await get_user(message.from_user.id)
        current_group = user.get("group_name") if user and user.get("group_name") else "не выбрана"

        kb = InlineKeyboardMarkup(inline_keyboard=[
            [
                InlineKeyboardButton(text="Подтвердить вход", callback_data=f"appauth:ok:{session_token}"),
                InlineKeyboardButton(text="Отклонить", callback_data=f"appauth:cancel:{session_token}")
            ]
        ])

        await message.answer(
            "Вход в мобильное приложение РИИ Расписание.\n\n"
            f"Текущая группа: {current_group}\n"
            f"Пользователь: {message.from_user.full_name}\n\n"
            "Подтвердить авторизацию устройства?",
            reply_markup=kb
        )
        return

    if message.chat.type in ("group", "supergroup"):
        chat_user = await get_user(message.chat.id)
        if chat_user and chat_user.get("group_name"):
            gid = chat_user.get("group_id")
            kb = await get_reply_markup_for_chat(message, gid)
            reply_to = message.message_id if kb and kb.selective else None
            await message.answer(
                f"Привет!\n\n"
                f"{DISCLAIMER}\n\n"
                f"Текущая группа чата: {chat_user['group_name']}\n\n"
                "Используйте команды /today, /tomorrow, /week, /now для просмотра расписания.\n"
                "Подробный гид по боту: /guide",
                reply_markup=kb,
                reply_to_message_id=reply_to
            )
            return

        courses_map = await api_client.get_courses_map()
        if not courses_map:
            await message.answer("Не удалось загрузить список групп с сайта РИИ. Попробуй позже.")
            return

        await message.answer(
            f"Привет!\n\n"
            f"{DISCLAIMER}\n\n"
            "Бот расписания РИИ АлтГТУ готов к работе в этой беседе.\n\n"
            "Краткий гид для бесед:\n"
            "1. Администратор чата выбирает учебную группу кнопками ниже или командой /group.\n"
            "2. Участники беседы могут смотреть расписание командами /today, /tomorrow, /week, /now.\n"
            "3. Режим клавиатуры (только вызвавшему или всем) настраивается администратором через /settings.\n\n"
            "Выберите курс, чтобы указать учебную группу для этого чата:",
            reply_markup=get_courses_keyboard(list(courses_map.keys()), include_guide_button=True)
        )
        return

    user = await get_user(message.from_user.id)
    if user and user.get("group_name"):
        gid = user.get("group_id")
        kb = await get_reply_markup_for_chat(message, gid)
        await message.answer(
            f"Привет, {message.from_user.first_name}!\n\n"
            f"{DISCLAIMER}\n\n"
            f"Текущая группа: {user['group_name']}\n\n"
            "Используй кнопки меню или открой расписание в приложении.\n"
            "Краткий гид по боту: /guide\n"
            "Также доступно нативное мобильное приложение для Android и iOS: /download",
            reply_markup=kb
        )
        return

    courses_map = await api_client.get_courses_map()
    if not courses_map:
        await message.answer("Не удалось загрузить список групп с сайта РИИ. Попробуй позже.")
        return

    first_run_text = (
        f"Привет, {message.from_user.first_name}!\n\n"
        f"{DISCLAIMER}\n\n"
        "Добро пожаловать! Это бот расписания Рубцовского индустриального института (РИИ АлтГТУ).\n\n"
        "Краткий гид: как всем пользоваться\n\n"
        "1. Выбор группы:\n"
        "Выберите свой курс на кнопках ниже или просто напишите название группы сообщением в этот чат (например: ИВТ-21 или 9-61).\n\n"
        "2. Просмотр расписания в чате:\n"
        "После выбора группы внизу появятся кнопки: «Сегодня», «Завтра», «Неделя» и «Настройки», а также команды /today, /tomorrow, /week, /now (пара прямо сейчас) и /bells (звонки).\n\n"
        "3. Интерактивное приложение (Mini App):\n"
        "Кнопка «Расписание» рядом со строкой ввода текста открывает веб-расписание с календарем и удобным фильтром по 1 и 2 подгруппам.\n\n"
        "4. Умные напоминания:\n"
        "Бот автоматически присылает уведомление за 10 минут до первой пары дня. Время и типы оповещений настраиваются в меню «Настройки».\n\n"
        "5. Поиск преподавателей:\n"
        "Отправьте фамилию преподавателя прямо в этот чат (например: Иванов), чтобы посмотреть его расписание пар.\n\n"
        "Шаг 1: Выберите свой курс:"
    )

    await message.answer(
        first_run_text,
        reply_markup=get_courses_keyboard(list(courses_map.keys()), include_guide_button=True)
    )

@router.callback_query(F.data.startswith("appauth:"))
async def cb_app_auth(callback: CallbackQuery):
    parts = callback.data.split(":")
    action = parts[1]
    session_token = parts[2]

    if action == "ok":
        from_user = callback.from_user
        avatar_url = None
        try:
            photos = await callback.bot.get_user_profile_photos(from_user.id, limit=1)
            if photos.total_count > 0:
                file_info = await callback.bot.get_file(photos.photos[0][-1].file_id)
                os.makedirs("webapp/avatars", exist_ok=True)
                avatar_path = os.path.join("webapp", "avatars", f"{from_user.id}.jpg")
                await callback.bot.download_file(file_info.file_path, avatar_path)
                avatar_url = f"/avatars/{from_user.id}.jpg"
        except Exception:
            pass

        auth_token = await confirm_auth_session(
            session_token=session_token,
            user_id=from_user.id,
            first_name=from_user.first_name,
            last_name=from_user.last_name,
            username=from_user.username,
            avatar_url=avatar_url,
        )
        if auth_token:
            user = await get_user(callback.from_user.id)
            group_text = f" Группа: {user['group_name']}." if user and user.get("group_name") else ""
            await callback.message.edit_text(
                f"Вход в мобильное приложение успешно подтвержден.{group_text}\n"
                "Теперь вернитесь в приложение: вход выполнится автоматически."
            )
        else:
            await callback.message.edit_text("Не удалось подтвердить вход. Возможно, время ожидания истекло.")
    else:
        await callback.message.edit_text("Вход в мобильное приложение отклонен.")
    await callback.answer()

@router.message(Command("stats", "статистика", ignore_case=True))
async def cmd_stats(message: Message):
    from database import get_stats
    stats = await get_stats()
    text = (
        "Статистика сервиса РИИ Расписание:\n\n"
        f"- Всего пользователей в базе: {stats['total_users']}\n"
        f"- Пользователей Telegram: {stats['telegram_users']}\n"
        f"- Пользователей мобильного приложения без входа: {stats['guest_app_users']}\n"
        f"- Всего мобильных пользователей: {stats['mobile_users']}\n"
        f"- С выбранной группой: {stats['active_users']}\n"
        f"- Включили уведомления: {stats['notif_users']}"
    )
    await message.answer(text)

@router.message(Command("help", "помощь", "справка", ignore_case=True))
@router.message(F.text.casefold().in_({"помощь", "справка", "команды", "что умеет бот"}))
async def cmd_help(message: Message):
    is_group = message.chat.type in ("group", "supergroup")
    reply_to = message.message_id if is_group else None
    text = (
        f"{DISCLAIMER}\n\n"
        "Команды бота:\n"
        "/start - Главное меню и приветствие\n"
        "/guide - Краткий гид: как пользоваться ботом\n"
        "/app - Открыть расписание в Mini App\n"
        "/today - Расписание на сегодня\n"
        "/tomorrow - Расписание на завтра\n"
        "/now - Что идет прямо сейчас\n"
        "/week - Расписание на текущую неделю\n"
        "/nextweek - Расписание на следующую неделю\n"
        "/group - Выбор или смена учебной группы\n"
        "/bells - Расписание звонков\n"
        "/exams - Расписание сессии/экзаменов\n"
        "/settings - Настройки и уведомления\n"
        "/stats - Статистика использования сервиса\n"
        "/about - О проекте и разработчике\n"
        "/download - Скачать мобильное приложение (Android / iOS)\n"
        "/pic - Сезонная иконка и темы оформления\n"
        "/help - Справка по командам\n\n"
        "Также можно написать название группы в чат (например: ИВТ-61 или 9-61), чтобы быстро найти её."
    )
    inline_kb = InlineKeyboardMarkup(inline_keyboard=[
        [InlineKeyboardButton(text="Открыть подробный гид", callback_data="guide_page:1")]
    ])
    await message.answer(text, reply_markup=inline_kb, reply_to_message_id=reply_to)


@router.message(Command("guide", "гайд", "инструкция", ignore_case=True))
@router.message(F.text.casefold().in_({"гайд", "гид", "как пользоваться", "инструкция", "руководство", "как пользоваться ботом"}))
async def cmd_guide(message: Message):
    is_group = message.chat.type in ("group", "supergroup")
    target_id = message.chat.id if is_group else message.from_user.id
    user = await get_user(target_id)
    has_group = bool(user and user.get("group_name"))

    text = GUIDE_PAGES[1]
    kb = get_guide_keyboard(current_page=1, total_pages=4, has_group=has_group)
    await message.answer(text, reply_markup=kb)


@router.callback_query(F.data.startswith("guide_page:"))
async def cb_guide_page(callback: CallbackQuery):
    try:
        page = int(callback.data.split(":")[1])
    except (ValueError, IndexError):
        page = 1
    page = max(1, min(4, page))

    is_group = callback.message.chat.type in ("group", "supergroup")
    target_id = callback.message.chat.id if is_group else callback.from_user.id
    user = await get_user(target_id)
    has_group = bool(user and user.get("group_name"))

    text = GUIDE_PAGES.get(page, GUIDE_PAGES[1])
    kb = get_guide_keyboard(current_page=page, total_pages=4, has_group=has_group)

    try:
        await callback.message.edit_text(text, reply_markup=kb)
    except TelegramBadRequest:
        pass
    except Exception as e:
        logger.warning("Ошибка в cb_guide_page: %s", e)
    finally:
        await callback.answer()


@router.callback_query(F.data == "guide_close")
async def cb_guide_close(callback: CallbackQuery):
    try:
        await callback.message.delete()
    except Exception:
        try:
            await callback.message.edit_text("Гид закрыт. Вы всегда можете открыть его снова командой /guide.")
        except Exception:
            pass
    finally:
        await callback.answer("Гид закрыт")


@router.callback_query(F.data == "guide_noop")
async def cb_guide_noop(callback: CallbackQuery):
    await callback.answer()


@router.message(Command("menu", "меню", ignore_case=True))
@router.message(F.text.casefold().in_({"меню", "главное меню", "кнопки", "старт"}))
async def cmd_menu(message: Message):
    is_group = message.chat.type in ("group", "supergroup")
    target_user = await get_user(message.chat.id) if is_group else await get_user(message.from_user.id)
    gid = target_user.get("group_id") if target_user else None
    g_name = target_user.get("group_name") if target_user else "не выбрана"
    kb = await get_reply_markup_for_chat(message, gid)
    reply_to = message.message_id if (kb and kb.selective) else None
    await message.answer(
        f"Главное меню бота.\nТекущая группа: {g_name}.\n\nИспользуй кнопки ниже:",
        reply_markup=kb,
        reply_to_message_id=reply_to
    )

@router.message(Command("group", "groups", "группа", "группы", ignore_case=True))
@router.message(F.text.casefold().in_({"выбрать группу", "сменить группу", "моя группа", "группа", "группы", "выбор группы"}))
async def cmd_choose_group(message: Message):
    is_group = message.chat.type in ("group", "supergroup")
    if is_group and not await is_chat_admin(message.bot, message.chat.id, message.from_user.id):
        await message.answer("Только администратор чата может менять учебную группу.")
        return

    courses_map = await api_client.get_courses_map(force_refresh=True)
    if not courses_map:
        await message.answer("Не удалось получить список групп. Попробуй позже.")
        return

    await message.answer(
        "Выбери курс:",
        reply_markup=get_courses_keyboard(list(courses_map.keys()))
    )

@router.callback_query(F.data == "back_to_courses")
@router.callback_query(F.data == "change_group")
async def cb_back_to_courses(callback: CallbackQuery):
    is_group = callback.message.chat.type in ("group", "supergroup")
    if is_group and not await is_chat_admin(callback.bot, callback.message.chat.id, callback.from_user.id):
        await callback.answer("Только администратор чата может менять учебную группу.", show_alert=True)
        return

    courses_map = await api_client.get_courses_map()
    target_id = callback.message.chat.id if is_group else callback.from_user.id
    user = await get_user(target_id)
    has_group = bool(user and user.get("group_name"))
    try:
        await callback.message.edit_text(
            "Выбери курс:",
            reply_markup=get_courses_keyboard(list(courses_map.keys()), allow_cancel=has_group)
        )
    except TelegramBadRequest:
        pass
    except Exception as e:
        logger.warning("Ошибка в cb_back_to_courses: %s", e)
    finally:
        await callback.answer()

@router.callback_query(F.data.startswith("course:"))
async def cb_select_course(callback: CallbackQuery):
    course = int(callback.data.split(":")[1])
    courses_map = await api_client.get_courses_map()
    groups = courses_map.get(course, [])

    if not groups:
        await callback.answer("Группы для данного курса не найдены.", show_alert=True)
        return

    try:
        await callback.message.edit_text(
            f"Группы {course} курса:\nВыбери свою группу из списка:",
            reply_markup=get_groups_keyboard(course, groups)
        )
    except TelegramBadRequest:
        pass
    except Exception as e:
        logger.warning("Ошибка в cb_select_course: %s", e)
    finally:
        await callback.answer()

@router.callback_query(F.data.startswith("set_group:"))
async def cb_set_group(callback: CallbackQuery):
    group_id = int(callback.data.split(":")[1])
    group = await api_client.get_group_by_id(group_id)

    if not group:
        await callback.answer("Группа не найдена.", show_alert=True)
        return

    is_group = callback.message.chat.type in ("group", "supergroup")
    if is_group:
        existing = await get_user(callback.message.chat.id)
        if existing and existing.get("group_id"):
            if not await is_chat_admin(callback.bot, callback.message.chat.id, callback.from_user.id):
                await callback.answer("Только администратор чата может менять учебную группу.", show_alert=True)
                return

        await set_user_group(callback.message.chat.id, group["id"], group["name"])
        try:
            await callback.message.delete()
        except Exception:
            pass

        await callback.message.answer(
            f"Для этого чата сохранена группа: {group['name']}\n\n"
            "Теперь участники могут смотреть расписание командами /today, /tomorrow, /week, /now и др.\n"
            "Справка и гид по боту: /guide"
        )
        await callback.answer(f"Выбрана {group['name']}")
    else:
        user = await get_user(callback.from_user.id)
        has_seen_guide = user.get("has_seen_guide", 0) if user else 0
        await set_user_group(callback.from_user.id, group["id"], group["name"])
        try:
            await callback.message.delete()
        except Exception:
            pass

        if not has_seen_guide:
            await set_user_has_seen_guide(callback.from_user.id, 1)
            await callback.message.answer(
                f"Группа сохранена: {group['name']}.\n\n"
                "Памятка для старта:\n"
                "- Меню внизу экрана: используйте кнопки «Сегодня», «Завтра» и «Неделя» для быстрого просмотра расписания.\n"
                "- Mini App: нажмите кнопку «Расписание» слева от поля ввода, чтобы открыть интерактивное расписание с переключением 1 и 2 подгруппы.\n"
                "- Напоминания: бот уведомит вас за 10 минут до первой пары. Время можно изменить в кнопке «Настройки».\n"
                "- Поиск преподавателей: отправьте фамилию преподавателя прямо в этот чат.\n\n"
                "Полная интерактивная инструкция доступна по команде /guide.",
                reply_markup=get_main_keyboard(group["id"])
            )
        else:
            await callback.message.answer(
                f"Группа сохранена: {group['name']}\n\n"
                "Теперь ты можешь смотреть расписание через кнопки меню или в Mini App.",
                reply_markup=get_main_keyboard(group["id"])
            )
        await callback.answer(f"Выбрана {group['name']}")

@router.message(F.text)
async def handle_text_group_search(message: Message):
    if not message.text or message.text.startswith("/"):
        return

    # В групповых чатах не перехватываем обычный разговор студентов,
    # если сообщение не является ответом боту и не содержит упоминания бота.
    if message.chat.type in ("group", "supergroup"):
        bot_user = await message.bot.get_me()
        is_reply_to_bot = bool(
            message.reply_to_message
            and message.reply_to_message.from_user
            and message.reply_to_message.from_user.id == bot_user.id
        )
        has_mention = bool(bot_user.username and f"@{bot_user.username.lower()}" in message.text.lower())
        if not (is_reply_to_bot or has_mention):
            return

    query = message.text.strip()
    lower = query.casefold()

    # Простые приветствия и вежливые фразы
    if lower in {"привет", "здравствуйте", "добрый день", "добрый вечер", "доброе утро", "хай", "ку", "салам"}:
        target_id = message.chat.id if message.chat.type in ("group", "supergroup") else message.from_user.id
        user = await get_user(target_id)
        gid = user.get("group_id") if user else None
        g_name = user.get("group_name") if user else "не выбрана"
        kb = await get_reply_markup_for_chat(message, gid)
        reply_to = message.message_id if (kb and kb.selective) else None
        await message.answer(
            f"Привет, {message.from_user.first_name}!\n"
            f"Текущая группа: {g_name}.\n"
            "Используй кнопки меню для просмотра расписания:",
            reply_markup=kb,
            reply_to_message_id=reply_to
        )
        return

    if lower in {"спасибо", "спс", "благодарю", "отлично", "супер", "класс", "топ"}:
        await message.answer("Всегда пожалуйста! Обращайся в любое время.")
        return

    if len(query) < 2:
        return

    results = await api_client.search_groups(query)

    if not results:
        await message.answer(
            f"По запросу '{query}' группа не найдена.\n"
            "Нажми кнопку ниже, чтобы выбрать группу из списка курсов:",
            reply_markup=InlineKeyboardMarkup(inline_keyboard=[
                [InlineKeyboardButton(text="Выбрать группу из списка", callback_data="change_group")]
            ])
        )
        return

    if len(results) == 1:
        group = results[0]
        buttons = [
            [
                InlineKeyboardButton(
                    text=f"Выбрать {group['name']}",
                    callback_data=f"set_group:{group['id']}"
                )
            ]
        ]
        await message.answer(
            f"Найдена группа: {group['name']} ({group['course']} курс)",
            reply_markup=InlineKeyboardMarkup(inline_keyboard=buttons)
        )
    else:
        buttons = []
        for g in results[:8]:
            buttons.append([
                InlineKeyboardButton(
                    text=f"{g['name']} ({g['course']} курс)",
                    callback_data=f"set_group:{g['id']}"
                )
            ])
        await message.answer(
            f"По запросу '{query}' найдено несколько групп. Выбери свою:",
            reply_markup=InlineKeyboardMarkup(inline_keyboard=buttons)
        )
