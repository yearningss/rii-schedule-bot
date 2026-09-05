# Обработчики команды /start, справки, выбора и поиска группы
from aiogram import Router, F
from aiogram.filters import CommandStart, Command, CommandObject
from aiogram.types import Message, CallbackQuery, InlineKeyboardMarkup, InlineKeyboardButton, WebAppInfo

from database import get_user, set_user_group, get_auth_session, confirm_auth_session
from services.api import api_client
from keyboards import get_main_keyboard, get_courses_keyboard, get_groups_keyboard
from config import WEBAPP_URL

router = Router()

DISCLAIMER = (
    "Это неофициальный бот с расписанием РИИ АлтГТУ. Сделан по приколу и для удобства.\n"
    "Исходный код полностью открыт на GitHub: https://github.com/yearningss/rii-schedule-bot"
)

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

    user = await get_user(message.from_user.id)
    if user and user.get("group_name"):
        gid = user.get("group_id")
        await message.answer(
            f"Привет, {message.from_user.first_name}!\n\n"
            f"{DISCLAIMER}\n\n"
            f"Текущая группа: {user['group_name']}\n\n"
            "Используй кнопки меню или открой приложение в Mini App.",
            reply_markup=get_main_keyboard(gid)
        )
        return

    courses_map = await api_client.get_courses_map()
    if not courses_map:
        await message.answer("Не удалось загрузить список групп с сайта РИИ. Попробуй позже.")
        return

    await message.answer(
        f"Привет, {message.from_user.first_name}!\n\n"
        f"{DISCLAIMER}\n\n"
        "Выбери свой курс, чтобы указать учебную группу:",
        reply_markup=get_courses_keyboard(list(courses_map.keys()))
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
            import os
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
                "Теперь вернитесь в приложение — вход выполнится автоматически."
            )
        else:
            await callback.message.edit_text("Не удалось подтвердить вход. Возможно, время ожидания истекло.")
    else:
        await callback.message.edit_text("Вход в мобильное приложение отклонен.")
    await callback.answer()

@router.message(Command("help"))
async def cmd_help(message: Message):
    user = await get_user(message.from_user.id)
    gid = user.get("group_id") if user else None
    text = (
        f"{DISCLAIMER}\n\n"
        "Команды бота:\n"
        "/start - Главное меню и приветствие\n"
        "/app - Открыть расписание в Mini App\n"
        "/group - Выбор или смена учебной группы\n"
        "/today - Расписание на сегодня\n"
        "/tomorrow - Расписание на завтра\n"
        "/week - Расписание на текущую неделю\n"
        "/nextweek - Расписание на следующую неделю\n"
        "/bells - Расписание звонков\n"
        "/exams - Расписание сессии/экзаменов\n"
        "/settings - Настройки и уведомления\n"
        "/about - О проекте и разработчике\n"
        "/help - Справка\n\n"
        "Также можно написать название группы в чат (например: ИВТ-61), чтобы быстро найти её."
    )
    await message.answer(text, reply_markup=get_main_keyboard(gid))

@router.message(Command("app"))
async def cmd_app(message: Message):
    user = await get_user(message.from_user.id)
    gid = user.get("group_id") if user else None
    url = f"{WEBAPP_URL}?group_id={gid}" if gid else WEBAPP_URL
    kb = InlineKeyboardMarkup(inline_keyboard=[
        [InlineKeyboardButton(text="Открыть расписание (Mini App)", web_app=WebAppInfo(url=url))]
    ])
    await message.answer("Нажми кнопку ниже, чтобы открыть интерактивное расписание в приложении:", reply_markup=kb)

@router.message(Command("group"))
@router.message(F.text == "Выбрать группу")
async def cmd_choose_group(message: Message):
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
    courses_map = await api_client.get_courses_map()
    await callback.message.edit_text(
        "Выбери курс:",
        reply_markup=get_courses_keyboard(list(courses_map.keys()))
    )
    await callback.answer()

@router.callback_query(F.data.startswith("course:"))
async def cb_select_course(callback: CallbackQuery):
    course = int(callback.data.split(":")[1])
    courses_map = await api_client.get_courses_map()
    groups = courses_map.get(course, [])

    if not groups:
        await callback.answer("Группы для данного курса не найдены.", show_alert=True)
        return

    await callback.message.edit_text(
        f"Группы {course} курса:\nВыбери свою группу из списка:",
        reply_markup=get_groups_keyboard(course, groups)
    )
    await callback.answer()

@router.callback_query(F.data.startswith("set_group:"))
async def cb_set_group(callback: CallbackQuery):
    group_id = int(callback.data.split(":")[1])
    group = await api_client.get_group_by_id(group_id)

    if not group:
        await callback.answer("Группа не найдена.", show_alert=True)
        return

    await set_user_group(callback.from_user.id, group["id"], group["name"])
    await callback.message.delete()
    await callback.message.answer(
        f"Группа сохранена: {group['name']}\n\n"
        "Теперь ты можешь смотреть расписание через кнопки или в Mini App.",
        reply_markup=get_main_keyboard(group["id"])
    )
    await callback.answer()

@router.message(F.text)
async def handle_text_group_search(message: Message):
    if not message.text or message.text.startswith("/"):
        return

    query = message.text.strip()
    if len(query) < 2:
        return

    results = await api_client.search_groups(query)

    if not results:
        user = await get_user(message.from_user.id)
        gid = user.get("group_id") if user else None
        await message.answer(
            f"По запросу '{query}' группа не найдена.\n"
            "Попробуй написать точнее или нажми 'Выбрать группу'.",
            reply_markup=get_main_keyboard(gid)
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
