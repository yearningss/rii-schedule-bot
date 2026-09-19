# Клавиатуры бота (главное меню, выбор курса и группы, переключение дней, настройки, Web App)
from typing import Dict, List, Any, Optional
from aiogram.types import (
    ReplyKeyboardMarkup,
    KeyboardButton,
    InlineKeyboardMarkup,
    InlineKeyboardButton,
    WebAppInfo
)
from config import WEBAPP_URL

def get_main_keyboard(group_id: Optional[int] = None, selective: bool = False) -> ReplyKeyboardMarkup:
    kb = [
        [KeyboardButton(text="Сегодня"), KeyboardButton(text="Завтра")],
        [KeyboardButton(text="Неделя"), KeyboardButton(text="Настройки")]
    ]
    return ReplyKeyboardMarkup(keyboard=kb, resize_keyboard=True, selective=selective)

def get_app_download_keyboard(bot_username: str = "rubinst_bot", is_group: bool = False) -> InlineKeyboardMarkup:
    buttons = [
        [
            InlineKeyboardButton(
                text="Скачать APK для Android",
                url="https://github.com/yearningss/rii-schedule-bot/releases/latest/download/RiiSchedule.apk"
            ),
            InlineKeyboardButton(
                text="Скачать IPA для iOS",
                url="https://github.com/yearningss/rii-schedule-bot/releases/latest/download/RiiSchedule.ipa"
            )
        ],
        [
            InlineKeyboardButton(
                text="Все версии и история изменений",
                url="https://github.com/yearningss/rii-schedule-bot/releases"
            )
        ]
    ]
    if is_group:
        buttons.append([
            InlineKeyboardButton(
                text="Открыть расписание (Mini App)",
                url=f"https://t.me/{bot_username}/app"
            )
        ])
    else:
        buttons.append([
            InlineKeyboardButton(
                text="Открыть расписание (Mini App)",
                web_app=WebAppInfo(url=WEBAPP_URL)
            )
        ])
    return InlineKeyboardMarkup(inline_keyboard=buttons)

def get_courses_keyboard(
    courses: List[int],
    allow_cancel: bool = False,
    include_guide_button: bool = False
) -> InlineKeyboardMarkup:
    buttons = []
    row = []
    for c in courses:
        row.append(InlineKeyboardButton(text=f"{c} курс", callback_data=f"course:{c}"))
        if len(row) == 2:
            buttons.append(row)
            row = []
    if row:
        buttons.append(row)
    if include_guide_button:
        buttons.append([InlineKeyboardButton(text="Подробный гид по разделам", callback_data="guide_page:1")])
    if allow_cancel:
        buttons.append([InlineKeyboardButton(text="<< Назад", callback_data="cancel_course_select")])
    return InlineKeyboardMarkup(inline_keyboard=buttons)

def get_guide_keyboard(current_page: int = 1, total_pages: int = 4, has_group: bool = True) -> InlineKeyboardMarkup:
    nav_row = []
    if current_page > 1:
        nav_row.append(InlineKeyboardButton(text="<< Назад", callback_data=f"guide_page:{current_page - 1}"))
    else:
        nav_row.append(InlineKeyboardButton(text="<< Назад", callback_data="guide_noop"))

    nav_row.append(InlineKeyboardButton(text=f"{current_page} из {total_pages}", callback_data="guide_noop"))

    if current_page < total_pages:
        nav_row.append(InlineKeyboardButton(text="Вперед >>", callback_data=f"guide_page:{current_page + 1}"))
    else:
        nav_row.append(InlineKeyboardButton(text="Вперед >>", callback_data="guide_noop"))

    topics_row1 = [
        InlineKeyboardButton(
            text="[1] Меню" if current_page == 1 else "1. Меню",
            callback_data="guide_page:1"
        ),
        InlineKeyboardButton(
            text="[2] Mini App" if current_page == 2 else "2. Mini App",
            callback_data="guide_page:2"
        ),
    ]
    topics_row2 = [
        InlineKeyboardButton(
            text="[3] Уведомления" if current_page == 3 else "3. Уведомления",
            callback_data="guide_page:3"
        ),
        InlineKeyboardButton(
            text="[4] Поиск и чаты" if current_page == 4 else "4. Поиск и чаты",
            callback_data="guide_page:4"
        ),
    ]

    action_row = []
    if not has_group:
        action_row.append(InlineKeyboardButton(text="Выбрать группу", callback_data="change_group"))
    action_row.append(InlineKeyboardButton(text="Закрыть гид", callback_data="guide_close"))

    return InlineKeyboardMarkup(inline_keyboard=[nav_row, topics_row1, topics_row2, action_row])


def get_groups_keyboard(course: int, groups: List[Dict[str, Any]]) -> InlineKeyboardMarkup:
    buttons = []
    row = []
    for g in groups:
        row.append(InlineKeyboardButton(text=g["name"], callback_data=f"set_group:{g['id']}"))
        if len(row) == 2:
            buttons.append(row)
            row = []
    if row:
        buttons.append(row)
    
    buttons.append([InlineKeyboardButton(text="<< Назад к курсам", callback_data="back_to_courses")])
    return InlineKeyboardMarkup(inline_keyboard=buttons)

def get_day_nav_keyboard(current_week: int, current_day: int, group_id: Optional[int] = None) -> InlineKeyboardMarkup:
    days_short = [("Пн", 1), ("Вт", 2), ("Ср", 3), ("Чт", 4), ("Пт", 5), ("Сб", 6)]
    
    days_row = []
    for label, d_num in days_short:
        text = f"[{label}]" if d_num == current_day else label
        days_row.append(InlineKeyboardButton(
            text=text,
            callback_data=f"nav_day:{current_week}:{d_num}"
        ))
    
    other_week = 2 if current_week == 1 else 1
    other_label = "II неделя" if current_week == 1 else "I неделя"

    nav_row = [
        InlineKeyboardButton(text=other_label, callback_data=f"nav_day:{other_week}:{current_day}"),
        InlineKeyboardButton(text="Обновить", callback_data=f"refresh_day:{current_week}:{current_day}")
    ]
    
    return InlineKeyboardMarkup(inline_keyboard=[days_row, nav_row])

def get_week_nav_keyboard(current_week: int, group_id: Optional[int] = None) -> InlineKeyboardMarkup:
    other_week = 2 if current_week == 1 else 1
    other_label = "II неделя" if current_week == 1 else "I неделя"

    return InlineKeyboardMarkup(inline_keyboard=[
        [
            InlineKeyboardButton(text=other_label, callback_data=f"nav_week:{other_week}"),
            InlineKeyboardButton(text="Обновить", callback_data=f"refresh_week:{current_week}")
        ]
    ])

def get_now_nav_keyboard(group_id: Optional[int] = None) -> InlineKeyboardMarkup:
    return InlineKeyboardMarkup(inline_keyboard=[
        [
            InlineKeyboardButton(text="Обновить статус", callback_data="refresh_now"),
            InlineKeyboardButton(text="Расписание на день", callback_data="nav_today")
        ]
    ])

def get_settings_keyboard(user: Dict[str, Any]) -> InlineKeyboardMarkup:
    subgroup = user.get("subgroup", 0)
    notif_enabled = user.get("notifications_enabled", 1)
    before_mins = user.get("notify_before_mins", 10)
    breaks_enabled = user.get("notify_breaks", 1)
    start_enabled = user.get("notify_lesson_start", 1)
    changes_enabled = user.get("notify_changes", 1)

    sg0 = "[✓ Все п/г]" if subgroup == 0 else "Все п/г"
    sg1 = "[✓ 1 п/г]" if subgroup == 1 else "1 п/г"
    sg2 = "[✓ 2 п/г]" if subgroup == 2 else "2 п/г"

    notif_text = "Уведомления: ВКЛ" if notif_enabled == 1 else "Уведомления: ВЫКЛ"
    breaks_text = "О перемене: ВКЛ" if breaks_enabled == 1 else "О перемене: ВЫКЛ"
    start_text = "О начале: ВКЛ" if start_enabled == 1 else "О начале: ВЫКЛ"
    changes_text = "О правках: ВКЛ" if changes_enabled == 1 else "О правках: ВЫКЛ"

    b5 = "[✓ За 5м]" if before_mins == 5 else "За 5м"
    b10 = "[✓ За 10м]" if before_mins == 10 else "За 10м"
    b0 = "[✓ Выкл]" if before_mins == 0 else "Без пред."

    buttons = [
        [InlineKeyboardButton(text=notif_text, callback_data="toggle_notif")],
        [
            InlineKeyboardButton(text=b10, callback_data="set_before:10"),
            InlineKeyboardButton(text=b5, callback_data="set_before:5"),
            InlineKeyboardButton(text=b0, callback_data="set_before:0")
        ],
        [
            InlineKeyboardButton(text=breaks_text, callback_data="toggle_breaks"),
            InlineKeyboardButton(text=start_text, callback_data="toggle_start")
        ],
        [InlineKeyboardButton(text=changes_text, callback_data="toggle_changes")],
        [
            InlineKeyboardButton(text=sg0, callback_data="set_sg:0"),
            InlineKeyboardButton(text=sg1, callback_data="set_sg:1"),
            InlineKeyboardButton(text=sg2, callback_data="set_sg:2")
        ],
        [InlineKeyboardButton(text="Как пользоваться ботом (Гайд)", callback_data="guide_page:1")],
        [InlineKeyboardButton(text="Сменить учебную группу", callback_data="change_group")]
    ]
    return InlineKeyboardMarkup(inline_keyboard=buttons)

def get_group_settings_keyboard(chat_user: Dict[str, Any]) -> InlineKeyboardMarkup:
    kb_mode = chat_user.get("group_kb_mode", "selective")
    m_sel = "[✓ Вызвавшему]" if kb_mode == "selective" else "Вызвавшему"
    m_all = "[✓ Всем]" if kb_mode == "all" else "Всем"
    m_none = "[✓ Выкл]" if kb_mode == "none" else "Выкл"

    notif_enabled = chat_user.get("notifications_enabled", 1)
    notif_text = "Оповещения в чат: ВКЛ" if notif_enabled == 1 else "Оповещения в чат: ВЫКЛ"

    subgroup = chat_user.get("subgroup", 0)
    sg0 = "[✓ Все]" if subgroup == 0 else "Все"
    sg1 = "[✓ 1 п/г]" if subgroup == 1 else "1 п/г"
    sg2 = "[✓ 2 п/г]" if subgroup == 2 else "2 п/г"

    buttons = [
        [
            InlineKeyboardButton(text="Клавиатура:", callback_data="grp_kb_noop"),
            InlineKeyboardButton(text=m_sel, callback_data="grp_kb:selective"),
            InlineKeyboardButton(text=m_all, callback_data="grp_kb:all"),
            InlineKeyboardButton(text=m_none, callback_data="grp_kb:none")
        ],
        [
            InlineKeyboardButton(text=sg0, callback_data="grp_sg:0"),
            InlineKeyboardButton(text=sg1, callback_data="grp_sg:1"),
            InlineKeyboardButton(text=sg2, callback_data="grp_sg:2")
        ],
        [InlineKeyboardButton(text=notif_text, callback_data="grp_toggle_notif")],
        [InlineKeyboardButton(text="Как пользоваться ботом (Гайд)", callback_data="guide_page:1")],
        [InlineKeyboardButton(text="Сменить учебную группу чата", callback_data="change_group")]
    ]
    return InlineKeyboardMarkup(inline_keyboard=buttons)

