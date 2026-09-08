# Сервис определения активной сезонной темы оформления и иконки
import os
from pathlib import Path
from datetime import datetime, timezone, timedelta

BASE_DIR = Path(__file__).resolve().parent.parent
ICONS_DIR = BASE_DIR / "webapp" / "icons"

ALL_THEMES = {
    "default": {
        "id": "default",
        "title": "Классический РИИ",
        "subtitle": "Стандартный фирменный стиль института",
        "filename": "logo_app.png",
        "color": "#2563EB",
    },
    "city_day": {
        "id": "city_day",
        "title": "День города Рубцовска",
        "subtitle": "10 - 20 сентября (основан в 1892 г.)",
        "filename": "logo_app_dengoroda.png",
        "color": "#059669",
    },
    "machinist_day": {
        "id": "machinist_day",
        "title": "День машиностроителя (АТЗ)",
        "subtitle": "21 - 30 сентября (проф. праздник РИИ)",
        "filename": "logo_app_ATZ.png",
        "color": "#1E3A8A",
    },
    "autumn": {
        "id": "autumn",
        "title": "Золотая осень",
        "subtitle": "Октябрь - ноябрь",
        "filename": "logo_app_osen.png",
        "color": "#D97706",
    },
    "new_year": {
        "id": "new_year",
        "title": "С Новым Годом!",
        "subtitle": "20 декабря - 10 января",
        "filename": "logo_app_zima.png",
        "color": "#0284C7",
    },
    "student_day": {
        "id": "student_day",
        "title": "День студента",
        "subtitle": "25 января (Татьянин день)",
        "filename": "logo_app_denisydenta.png",
        "color": "#7C3AED",
    },
    "defender_day": {
        "id": "defender_day",
        "title": "День защитника Отечества",
        "subtitle": "21 - 24 февраля (23 февраля)",
        "filename": "logo_app_23fevrala.png",
        "color": "#15803D",
    },
    "women_day": {
        "id": "women_day",
        "title": "Международный женский день",
        "subtitle": "7 - 9 марта (8 марта)",
        "filename": "logo_app_8marta.png",
        "color": "#DB2777",
    },
    "spring": {
        "id": "spring",
        "title": "Весенний сезон",
        "subtitle": "Март - апрель",
        "filename": "logo_app_vesna.png",
        "color": "#10B981",
    },
    "victory_day": {
        "id": "victory_day",
        "title": "День Победы",
        "subtitle": "1 - 10 мая (9 мая)",
        "filename": "logo_app_denpobed.png",
        "color": "#B91C1C",
    },
    "graduation": {
        "id": "graduation",
        "title": "Выпускной и День молодежи",
        "subtitle": "20 - 30 июня",
        "filename": "logo_app_vipsk.png",
        "color": "#6366F1",
    },
    "summer": {
        "id": "summer",
        "title": "Летний сезон",
        "subtitle": "Июнь - август",
        "filename": "logo_app_leto.png",
        "color": "#EAB308",
    },
}

def get_rubtsovsk_now() -> datetime:
    return datetime.now(timezone.utc) + timedelta(hours=7)

def get_theme_by_id(theme_id: str) -> dict:
    return ALL_THEMES.get(theme_id, ALL_THEMES["default"])

def resolve_auto_theme(dt: datetime = None) -> dict:
    if dt is None:
        dt = get_rubtsovsk_now()
    m = dt.month
    d = dt.day

    # 1. Точечные праздничные периоды
    if (m == 12 and d >= 20) or (m == 1 and d <= 10):
        return get_theme_by_id("new_year")
    if m == 1 and d == 25:
        return get_theme_by_id("student_day")
    if m == 2 and 21 <= d <= 24:
        return get_theme_by_id("defender_day")
    if m == 3 and 7 <= d <= 9:
        return get_theme_by_id("women_day")
    if m == 5 and d <= 10:
        return get_theme_by_id("victory_day")
    if m == 6 and d >= 20:
        return get_theme_by_id("graduation")
    if m == 9 and 10 <= d <= 20:
        return get_theme_by_id("city_day")
    if m == 9 and 21 <= d <= 30:
        return get_theme_by_id("machinist_day")

    # 2. Сезоны года
    if m in (3, 4, 5):
        return get_theme_by_id("spring")
    if m in (6, 7, 8):
        return get_theme_by_id("summer")
    if m in (10, 11):
        return get_theme_by_id("autumn")

    return get_theme_by_id("default")

def get_icon_path(filename: str) -> Path:
    return ICONS_DIR / filename
