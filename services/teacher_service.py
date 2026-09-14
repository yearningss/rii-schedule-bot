# Сервис информации о преподавателях РИИ: сбор данных, кэширование и поиск
import json
import logging
import re
import urllib.parse
from pathlib import Path
from typing import Dict, Any, Optional, List

logger = logging.getLogger("rii_schedule_bot.teachers")

DATA_DIR = Path(__file__).resolve().parent.parent / "data"
CACHE_FILE = DATA_DIR / "teachers_cache.json"

_teachers_cache: Dict[str, Dict[str, Any]] = {}

def get_short_name(full_name: str) -> str:
    parts = full_name.split()
    if len(parts) >= 3:
        return f"{parts[0]} {parts[1][0]}.{parts[2][0]}."
    elif len(parts) == 2:
        return f"{parts[0]} {parts[1][0]}."
    return full_name

def parse_initials(name_str: str):
    # Принимает строку вида "Попова Л.А." или "Иванов И. И." или "Сидоров"
    match = re.match(r"^([А-Яа-яЁё\-]+)(?:\s+([А-Яа-яЁё])\.?\s*(?:([А-Яа-яЁё])\.?)?)?", name_str.strip())
    if not match:
        return "", "", ""
    last, i1, i2 = match.groups()
    return (last or "").lower(), (i1 or "").lower(), (i2 or "").lower()

def load_teachers_cache() -> Dict[str, Dict[str, Any]]:
    global _teachers_cache
    if _teachers_cache:
        return _teachers_cache

    if CACHE_FILE.exists():
        try:
            with open(CACHE_FILE, "r", encoding="utf-8") as f:
                _teachers_cache = json.load(f)
                logger.info("Загружено %d преподавателей из кэша %s", len(_teachers_cache), CACHE_FILE)
                return _teachers_cache
        except Exception as e:
            logger.error("Ошибка чтения кэша преподавателей: %s", e)

    return {}

def save_teachers_cache(data: Dict[str, Dict[str, Any]]):
    global _teachers_cache
    _teachers_cache = data
    DATA_DIR.mkdir(parents=True, exist_ok=True)
    try:
        with open(CACHE_FILE, "w", encoding="utf-8") as f:
            json.dump(data, f, ensure_ascii=False, indent=2)
        logger.info("Кэш преподавателей сохранен (%d записей) в %s", len(data), CACHE_FILE)
    except Exception as e:
        logger.error("Ошибка сохранения кэша преподавателей: %s", e)

def find_teacher_info(name_query: str, post_hint: Optional[str] = None) -> Dict[str, Any]:
    # Поиск преподавателя по ФИО или инициалам
    cache = load_teachers_cache()
    clean_q = name_query.strip()
    q_last, q_i1, q_i2 = parse_initials(clean_q)

    best_match = None
    best_score = 0

    if q_last:
        for full_name, info in cache.items():
            db_last, db_i1, db_i2 = parse_initials(full_name)
            if db_last == q_last:
                score = 10
                if q_i1:
                    if db_i1 == q_i1:
                        score += 30
                        if q_i2 and db_i2 == q_i2:
                            score += 50
                    else:
                        score -= 20
                if score > best_score:
                    best_score = score
                    best_match = info

    if best_match and best_score >= 10:
        res = dict(best_match)
        res["found"] = True
        return res

    # Fallback, если не найден в подробной базе сайта
    short = get_short_name(clean_q)
    return {
        "found": False,
        "full_name": clean_q,
        "short_name": short,
        "post": post_hint or "Преподаватель",
        "degree": "",
        "title": "",
        "department": "",
        "disciplines": "",
        "photo_url": "",
        "email": "",
        "phone": "",
        "room": "",
        "profile_url": "https://www.rubinst.ru/structure"
    }

def get_all_teachers_list() -> List[Dict[str, Any]]:
    cache = load_teachers_cache()
    teachers = list(cache.values())
    teachers.sort(key=lambda x: x.get("full_name", ""))
    return teachers
