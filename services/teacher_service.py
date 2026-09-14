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

def normalize_phone_display(raw_phone: str) -> str:
    # Приводит городские рубцовские 5-значные номера к полному федеральному формату +7 (38557) X-XX-XX
    if not raw_phone:
        return ""
    parts = re.split(r"[,;]+", raw_phone)
    formatted = []
    for p in parts:
        clean = p.strip()
        if not clean:
            continue
        digits = re.sub(r"\D", "", clean)
        if len(digits) == 5:
            formatted.append(f"+7 (38557) {digits[0]}-{digits[1:3]}-{digits[3:5]}")
        elif (len(digits) == 11 and (digits.startswith("738557") or digits.startswith("838557"))) or (len(digits) == 10 and digits.startswith("38557")):
            local = digits[-5:]
            formatted.append(f"+7 (38557) {local[0]}-{local[1:3]}-{local[3:5]}")
        elif len(digits) == 6:
            formatted.append(f"+7 (38557) {digits[0:2]}-{digits[2:4]}-{digits[4:6]}")
        elif len(digits) == 10:
            formatted.append(f"+7 ({digits[0:3]}) {digits[3:6]}-{digits[6:8]}-{digits[8:10]}")
        elif len(digits) == 11 and (digits.startswith("8") or digits.startswith("7")):
            formatted.append(f"+7 ({digits[1:4]}) {digits[4:7]}-{digits[7:9]}-{digits[9:11]}")
        else:
            formatted.append(clean)
    return ", ".join(formatted)

def parse_phone_items(raw_phone: str) -> List[Dict[str, str]]:
    # Возвращает структурированный список номеров с форматированием для показа и ссылкой для звонка
    if not raw_phone:
        return []
    parts = re.split(r"[,;]+", raw_phone)
    result = []
    for p in parts:
        clean = p.strip()
        if not clean:
            continue
        digits = re.sub(r"\D", "", clean)
        display = clean
        dial = ""
        if len(digits) == 5:
            display = f"+7 (38557) {digits[0]}-{digits[1:3]}-{digits[3:5]}"
            dial = f"+738557{digits}"
        elif (len(digits) == 11 and (digits.startswith("738557") or digits.startswith("838557"))) or (len(digits) == 10 and digits.startswith("38557")):
            local = digits[-5:]
            display = f"+7 (38557) {local[0]}-{local[1:3]}-{local[3:5]}"
            dial = f"+738557{local}"
        elif len(digits) == 6:
            display = f"+7 (38557) {digits[0:2]}-{digits[2:4]}-{digits[4:6]}"
            dial = f"+738557{digits}"
        elif len(digits) == 10:
            display = f"+7 ({digits[0:3]}) {digits[3:6]}-{digits[6:8]}-{digits[8:10]}"
            dial = f"+7{digits}"
        elif len(digits) == 11 and digits.startswith("8"):
            display = f"+7 ({digits[1:4]}) {digits[4:7]}-{digits[7:9]}-{digits[9:11]}"
            dial = f"+7{digits[1:]}"
        elif len(digits) == 11 and digits.startswith("7"):
            display = f"+7 ({digits[1:4]}) {digits[4:7]}-{digits[7:9]}-{digits[9:11]}"
            dial = f"+{digits}"
        elif digits:
            dial = f"+{digits}"
        result.append({"display": display, "dial": dial or clean})
    return result

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
        raw_p = res.get("phone", "")
        res["phone"] = normalize_phone_display(raw_p)
        res["phones"] = parse_phone_items(raw_p)
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
        "phones": [],
        "room": "",
        "profile_url": "https://www.rubinst.ru/structure"
    }

def get_all_teachers_list() -> List[Dict[str, Any]]:
    cache = load_teachers_cache()
    teachers = list(cache.values())
    teachers.sort(key=lambda x: x.get("full_name", ""))
    return teachers
