# Клавиатуры бота (главное меню, выбор курса и группы, переключение дней, настройки)
from typing import Dict, List, Any
from aiogram.types import (
    ReplyKeyboardMarkup,
    KeyboardButton,
    InlineKeyboardMarkup,
    InlineKeyboardButton
)

def get_main_keyboard() -> ReplyKeyboardMarkup:
    kb = [
        [KeyboardButton(text="Сегодня"), KeyboardButton(text="Завтра")],
        [KeyboardButton(text="Текущая неделя"), KeyboardButton(text="Следующая неделя")],
        [KeyboardButton(text="Выбрать группу"), KeyboardButton(text="Звонки")],
        [KeyboardButton(text="Экзамены"), KeyboardButton(text="Настройки")],
        [KeyboardButton(text="О проекте")]
    ]
    return ReplyKeyboardMarkup(keyboard=kb, resize_keyboard=True)

def get_courses_keyboard(courses: List[int]) -> InlineKeyboardMarkup:
    buttons = []
    row = []
    for c in courses:
        row.append(InlineKeyboardButton(text=f"{c} курс", callback_data=f"course:{c}"))
        if len(row) == 2:
            buttons.append(row)
            row = []
    if row:
        buttons.append(row)
    return InlineKeyboardMarkup(inline_keyboard=buttons)

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

def get_day_nav_keyboard(current_week: int, current_day: int) -> InlineKeyboardMarkup:
    days_short = [("Пн", 1), ("Вт", 2), ("Ср", 3), ("Чт", 4), ("Пт", 5), ("Сб", 6)]
    
    days_row = []
    for label, d_num in days_short:
        text = f"[{label}]" if d_num == current_day else label
        days_row.append(InlineKeyboardButton(
            text=text,
            callback_data=f"nav_day:{current_week}:{d_num}"
        ))
    
    other_week = 2 if current_week == 1 else 1
    other_label = "Перейти на II неделю" if current_week == 1 else "Перейти на I неделю"
    
    nav_row = [
        InlineKeyboardButton(text=other_label, callback_data=f"nav_day:{other_week}:{current_day}"),
        InlineKeyboardButton(text="Обновить", callback_data=f"refresh_day:{current_week}:{current_day}")
    ]
    
    return InlineKeyboardMarkup(inline_keyboard=[days_row, nav_row])

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
        [InlineKeyboardButton(text="Сменить учебную группу", callback_data="change_group")]
    ]
    return InlineKeyboardMarkup(inline_keyboard=buttons)
