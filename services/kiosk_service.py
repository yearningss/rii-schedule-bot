# Сервис агрегации данных для информационного ТВ-табло и сенсорного киоска РИИ АлтГТУ
import asyncio
import time
import logging
from datetime import datetime
from zoneinfo import ZoneInfo
from typing import Dict, List, Optional, Any, Tuple

from services.api import api_client, parse_para_time_range

logger = logging.getLogger("rii_schedule_bot.kiosk")

RUBTSOVSK_TZ = ZoneInfo("Asia/Barnaul")

# Расписание звонков РИИ АлтГТУ по регламенту
BELLS_SCHEDULE = [
    {"num": 1, "start": "08:30", "end": "10:00", "start_mins": 510, "end_mins": 600, "break_mins": 10},
    {"num": 2, "start": "10:10", "end": "11:40", "start_mins": 610, "end_mins": 700, "break_mins": 30},
    {"num": 3, "start": "12:10", "end": "13:40", "start_mins": 730, "end_mins": 820, "break_mins": 10},
    {"num": 4, "start": "13:50", "end": "15:20", "start_mins": 830, "end_mins": 920, "break_mins": 10},
    {"num": 5, "start": "15:30", "end": "17:00", "start_mins": 930, "end_mins": 1020, "break_mins": 10},
    {"num": 6, "start": "17:10", "end": "18:40", "start_mins": 1030, "end_mins": 1120, "break_mins": 10},
    {"num": 7, "start": "18:50", "end": "20:20", "start_mins": 1130, "end_mins": 1220, "break_mins": 0},
]

DAY_NAMES_RU = {
    1: "Понедельник",
    2: "Вторник",
    3: "Среда",
    4: "Четверг",
    5: "Пятница",
    6: "Суббота",
    7: "Воскресенье"
}

MONTH_NAMES_RU = {
    1: "января", 2: "февраля", 3: "марта", 4: "апреля",
    5: "мая", 6: "июня", 7: "июля", 8: "августа",
    9: "сентября", 10: "октября", 11: "ноября", 12: "декабря"
}

_live_board_cache: Dict[str, Any] = {
    "timestamp": 0.0,
    "data": None
}

def get_rubtsovsk_now() -> datetime:
    return datetime.now(RUBTSOVSK_TZ)

def format_time_left(total_seconds: int) -> str:
    if total_seconds < 0:
        total_seconds = 0
    mins = total_seconds // 60
    secs = total_seconds % 60
    return f"{mins:02d}:{secs:02d}"

def calculate_bell_status(now_dt: datetime) -> Dict[str, Any]:
    day_of_week = now_dt.isoweekday() # 1 = Пн, 7 = Вс
    cur_mins = now_dt.hour * 60 + now_dt.minute
    cur_secs = now_dt.second
    now_total_secs = cur_mins * 60 + cur_secs

    if day_of_week == 7:
        return {
            "type": "day_off",
            "label": "Выходной день",
            "lesson_num": None,
            "time_range": "",
            "target_time": "",
            "remaining_seconds": 0,
            "remaining_str": "00:00",
            "message": "Воскресенье: учебных занятий нет",
            "progress_percent": 0
        }

    first_start_mins = BELLS_SCHEDULE[0]["start_mins"]
    if cur_mins < first_start_mins:
        target_secs = first_start_mins * 60
        rem_secs = max(0, target_secs - now_total_secs)
        return {
            "type": "before_start",
            "label": "До начала занятий",
            "lesson_num": 1,
            "time_range": f"{BELLS_SCHEDULE[0]['start']} - {BELLS_SCHEDULE[0]['end']}",
            "target_time": BELLS_SCHEDULE[0]["start"],
            "remaining_seconds": rem_secs,
            "remaining_str": format_time_left(rem_secs),
            "message": f"1 пара начнется в {BELLS_SCHEDULE[0]['start']} (осталось {format_time_left(rem_secs)})",
            "progress_percent": 0
        }

    for i, bell in enumerate(BELLS_SCHEDULE):
        b_num = bell["num"]
        s_mins = bell["start_mins"]
        e_mins = bell["end_mins"]

        # Идет пара
        if s_mins <= cur_mins < e_mins:
            target_secs = e_mins * 60
            rem_secs = max(0, target_secs - now_total_secs)
            total_duration_secs = (e_mins - s_mins) * 60
            elapsed_secs = total_duration_secs - rem_secs
            pct = int((elapsed_secs / total_duration_secs) * 100) if total_duration_secs > 0 else 0
            return {
                "type": "lesson",
                "label": f"Идет {b_num} пара",
                "lesson_num": b_num,
                "time_range": f"{bell['start']} - {bell['end']}",
                "target_time": bell["end"],
                "remaining_seconds": rem_secs,
                "remaining_str": format_time_left(rem_secs),
                "message": f"Идет {b_num} пара (до {bell['end']}, осталось {format_time_left(rem_secs)})",
                "progress_percent": pct
            }

        # Проверка перемены перед следующей парой
        if i + 1 < len(BELLS_SCHEDULE):
            next_bell = BELLS_SCHEDULE[i + 1]
            if e_mins <= cur_mins < next_bell["start_mins"]:
                next_start_mins = next_bell["start_mins"]
                target_secs = next_start_mins * 60
                rem_secs = max(0, target_secs - now_total_secs)
                break_duration_secs = (next_start_mins - e_mins) * 60
                elapsed_secs = break_duration_secs - rem_secs
                pct = int((elapsed_secs / break_duration_secs) * 100) if break_duration_secs > 0 else 0
                return {
                    "type": "break",
                    "label": "Перемена",
                    "lesson_num": next_bell["num"],
                    "time_range": f"Перемена {bell['break_mins']} мин",
                    "target_time": next_bell["start"],
                    "remaining_seconds": rem_secs,
                    "remaining_str": format_time_left(rem_secs),
                    "message": f"Перемена (до {next_bell['start']}, осталось {format_time_left(rem_secs)}). Следующая: {next_bell['num']} пара",
                    "progress_percent": pct
                }

    # Если время после последней пары
    return {
        "type": "ended",
        "label": "Занятия окончены",
        "lesson_num": None,
        "time_range": "",
        "target_time": "",
        "remaining_seconds": 0,
        "remaining_str": "00:00",
        "message": "Все учебные занятия на сегодня завершены",
        "progress_percent": 100
    }

def normalize_lesson_dict(raw_item: Optional[Dict[str, Any]], para_num: int, custom_time: str = "") -> Optional[Dict[str, Any]]:
    if not raw_item:
        return None

    # По умолчанию берем звонок из регламента
    bell = next((b for b in BELLS_SCHEDULE if b["num"] == para_num), None)
    default_time = f"{bell['start']} - {bell['end']}" if bell else ""
    time_str = custom_time if custom_time else default_time

    is_double = bool(raw_item.get("isDouble"))
    if not is_double:
        subj = (raw_item.get("subj") or raw_item.get("subj1") or "").strip()
        if not subj:
            return None
        return {
            "num": para_num,
            "time": time_str,
            "is_double": False,
            "subject": subj,
            "type": (raw_item.get("type") or raw_item.get("type1") or "").strip(),
            "teacher": (raw_item.get("teacher") or raw_item.get("teacher1") or "").strip(),
            "teach_post": (raw_item.get("teachPost") or raw_item.get("teachPost1") or "").strip(),
            "aud": (raw_item.get("aud") or raw_item.get("aud1") or "").strip(),
        }

    # Две подгруппы
    subj1 = (raw_item.get("subj1") or "").strip()
    subj2 = (raw_item.get("subj2") or "").strip()
    if not subj1 and not subj2:
        return None

    return {
        "num": para_num,
        "time": time_str,
        "is_double": True,
        "subgroup1": {
            "subject": subj1,
            "type": (raw_item.get("type1") or "").strip(),
            "teacher": (raw_item.get("teacher1") or "").strip(),
            "teach_post": (raw_item.get("teachPost1") or "").strip(),
            "aud": (raw_item.get("aud1") or "").strip(),
        } if subj1 else None,
        "subgroup2": {
            "subject": subj2,
            "type": (raw_item.get("type2") or "").strip(),
            "teacher": (raw_item.get("teacher2") or "").strip(),
            "teach_post": (raw_item.get("teachPost2") or "").strip(),
            "aud": (raw_item.get("aud2") or "").strip(),
        } if subj2 else None
    }

async def get_live_board_data(force_refresh: bool = False) -> Dict[str, Any]:
    global _live_board_cache
    now = time.time()
    if not force_refresh and _live_board_cache["data"] and (now - _live_board_cache["timestamp"] < 10):
        # Быстрое динамическое обновление секунд
        cached = _live_board_cache["data"].copy()
        r_now = get_rubtsovsk_now()
        cached["time"] = r_now.strftime("%H:%M:%S")
        cached["bell_status"] = calculate_bell_status(r_now)
        return cached

    now_dt = get_rubtsovsk_now()
    day_of_week = now_dt.isoweekday() # 1 = Пн ... 7 = Вс
    cur_mins = now_dt.hour * 60 + now_dt.minute

    bell_status = calculate_bell_status(now_dt)

    # 1. Получаем список всех групп
    groups = await api_client.get_groups()

    # 2. Получаем расписания всех групп параллельно
    async def fetch_sched(g_id: int):
        try:
            return await api_client.get_schedule(g_id)
        except Exception as err:
            logger.warning("Не удалось загрузить расписание группы %d: %s", g_id, err)
            return {}

    sched_tasks = [fetch_sched(g["id"]) for g in groups]
    schedules = await asyncio.gather(*sched_tasks)

    # Определяем текущую неделю института
    week_number = 1
    for s in schedules:
        if s and s.get("weekNumber"):
            try:
                week_number = int(s["weekNumber"])
                break
            except Exception:
                pass

    week_name = "Числитель" if week_number == 1 else "Знаменатель"
    date_str = f"{now_dt.day} {MONTH_NAMES_RU.get(now_dt.month, '')} {now_dt.year}"
    day_name = DAY_NAMES_RU.get(day_of_week, "")

    group_cards = []

    for group, sched_obj in zip(groups, schedules):
        g_id = group["id"]
        g_name = group["name"]
        g_course = group.get("course", 1)

        sched_data = sched_obj.get("scheduleData", {})
        para_times = sched_obj.get("paraTimes", {})
        week_data = sched_data.get(str(week_number), {})
        day_data = week_data.get(str(day_of_week), {})

        # Парсим все пары группы на сегодня
        today_lessons = []
        for p_num in range(1, 8):
            raw_item = day_data.get(str(p_num))
            if raw_item:
                raw_time = para_times.get(str(p_num), "")
                # Очистка времени если есть
                start_m, end_m, s_str, e_str = parse_para_time_range(raw_time, p_num)
                custom_time = f"{s_str} - {e_str}" if s_str and e_str else ""
                norm_item = normalize_lesson_dict(raw_item, p_num, custom_time)
                if norm_item:
                    norm_item["start_mins"] = start_m or (BELLS_SCHEDULE[p_num-1]["start_mins"] if p_num <= len(BELLS_SCHEDULE) else 0)
                    norm_item["end_mins"] = end_m or (BELLS_SCHEDULE[p_num-1]["end_mins"] if p_num <= len(BELLS_SCHEDULE) else 0)
                    today_lessons.append(norm_item)

        today_lessons.sort(key=lambda x: x["num"])

        # Определение текущей и следующей пары группы
        current_lesson = None
        next_lesson = None

        if today_lessons:
            # Ищем текущую пару
            for l in today_lessons:
                s_m = l.get("start_mins", 0)
                e_m = l.get("end_mins", 0)
                if s_m <= cur_mins < e_m:
                    current_lesson = l
                    break

            # Ищем следующую пару
            for l in today_lessons:
                s_m = l.get("start_mins", 0)
                if s_m > cur_mins:
                    next_lesson = l
                    break

        # Определение статуса группы
        card_status = "free"
        card_status_label = "Нет пар"
        card_status_badge = "gray"

        if day_of_week == 7 or not today_lessons:
            card_status = "free"
            card_status_label = "Выходной"
            card_status_badge = "gray"
        elif current_lesson:
            card_status = "in_progress"
            aud_str = ""
            if not current_lesson.get("is_double"):
                aud_str = f" в {current_lesson.get('aud')}" if current_lesson.get('aud') else ""
            card_status_label = f"Идет {current_lesson['num']} пара{aud_str}"
            card_status_badge = "green"
        elif next_lesson:
            first_l = today_lessons[0]
            if cur_mins < first_l.get("start_mins", 0):
                card_status = "waiting"
                card_status_label = f"Пара в {next_lesson['time'].split(' - ')[0]}"
                card_status_badge = "blue"
            elif bell_status["type"] == "lesson":
                card_status = "window"
                card_status_label = f"Окно (след. в {next_lesson['time'].split(' - ')[0]})"
                card_status_badge = "yellow"
            else:
                card_status = "break"
                card_status_label = f"След. в {next_lesson['time'].split(' - ')[0]}"
                card_status_badge = "amber"
        else:
            card_status = "done"
            card_status_label = "Пары окончены"
            card_status_badge = "slate"

        group_cards.append({
            "group_id": g_id,
            "group_name": g_name,
            "course": g_course,
            "status": card_status,
            "status_label": card_status_label,
            "status_badge": card_status_badge,
            "current_lesson": current_lesson,
            "next_lesson": next_lesson,
            "today_lessons_count": len(today_lessons),
            "today_lessons": today_lessons
        })

    # Сортировка карточек: сначала группы с текущими парами, затем с окнами и следующими парами, потом остальные
    status_priority = {
        "in_progress": 1,
        "break": 2,
        "window": 3,
        "waiting": 4,
        "done": 5,
        "free": 6
    }
    group_cards.sort(key=lambda x: (status_priority.get(x["status"], 99), x["course"], x["group_name"]))

    result = {
        "status": "ok",
        "date": date_str,
        "day_name": day_name,
        "day_of_week": day_of_week,
        "time": now_dt.strftime("%H:%M:%S"),
        "week_number": week_number,
        "week_name": week_name,
        "bell_status": bell_status,
        "total_groups": len(group_cards),
        "groups": group_cards
    }

    _live_board_cache["timestamp"] = now
    _live_board_cache["data"] = result
    return result

async def get_teacher_full_schedule(teacher_query: str) -> Dict[str, Any]:
    # Формирует персональное расписание преподавателя на обе недели на основе всех групп института
    norm_query = teacher_query.strip().lower()
    if not norm_query:
        return {"error": "Missing teacher name"}

    groups = await api_client.get_groups()

    async def fetch_sched(g_id: int):
        try:
            return await api_client.get_schedule(g_id)
        except Exception:
            return {}

    sched_tasks = [fetch_sched(g["id"]) for g in groups]
    schedules = await asyncio.gather(*sched_tasks)

    # Структура: {"1": {day: [items]}, "2": {day: [items]}}
    teacher_schedule = {
        "1": {str(d): [] for d in range(1, 7)},
        "2": {str(d): [] for d in range(1, 7)}
    }

    found_teacher_name = ""
    found_posts = set()

    for group, sched_obj in zip(groups, schedules):
        g_name = group["name"]
        sched_data = sched_obj.get("scheduleData", {})
        para_times = sched_obj.get("paraTimes", {})

        for w_str in ("1", "2"):
            w_data = sched_data.get(w_str, {})
            for d_str in [str(d) for d in range(1, 7)]:
                d_data = w_data.get(d_str, {})
                for p_str, item in d_data.items():
                    if not item:
                        continue
                    p_num = int(p_str)
                    raw_time = para_times.get(p_str, "")
                    s_m, e_m, s_s, e_s = parse_para_time_range(raw_time, p_num)
                    time_str = f"{s_s} - {e_s}" if s_s and e_s else ""

                    is_double = bool(item.get("isDouble"))
                    if not is_double:
                        tch = (item.get("teacher") or item.get("teacher1") or "").strip()
                        if norm_query in tch.lower():
                            if not found_teacher_name:
                                found_teacher_name = tch
                            pst = (item.get("teachPost") or item.get("teachPost1") or "").strip()
                            if pst:
                                found_posts.add(pst)
                            teacher_schedule[w_str][d_str].append({
                                "num": p_num,
                                "time": time_str,
                                "subject": (item.get("subj") or item.get("subj1") or "").strip(),
                                "type": (item.get("type") or item.get("type1") or "").strip(),
                                "aud": (item.get("aud") or item.get("aud1") or "").strip(),
                                "group": g_name,
                                "subgroup": 0
                            })
                    else:
                        tch1 = (item.get("teacher1") or "").strip()
                        tch2 = (item.get("teacher2") or "").strip()

                        if norm_query in tch1.lower():
                            if not found_teacher_name:
                                found_teacher_name = tch1
                            pst1 = (item.get("teachPost1") or "").strip()
                            if pst1:
                                found_posts.add(pst1)
                            teacher_schedule[w_str][d_str].append({
                                "num": p_num,
                                "time": time_str,
                                "subject": (item.get("subj1") or "").strip(),
                                "type": (item.get("type1") or "").strip(),
                                "aud": (item.get("aud1") or "").strip(),
                                "group": g_name,
                                "subgroup": 1
                            })

                        if norm_query in tch2.lower():
                            if not found_teacher_name:
                                found_teacher_name = tch2
                            pst2 = (item.get("teachPost2") or "").strip()
                            if pst2:
                                found_posts.add(pst2)
                            teacher_schedule[w_str][d_str].append({
                                "num": p_num,
                                "time": time_str,
                                "subject": (item.get("subj2") or "").strip(),
                                "type": (item.get("type2") or "").strip(),
                                "aud": (item.get("aud2") or "").strip(),
                                "group": g_name,
                                "subgroup": 2
                            })

    # Сортировка пар в каждом дне
    for w_str in ("1", "2"):
        for d_str in [str(d) for d in range(1, 7)]:
            teacher_schedule[w_str][d_str].sort(key=lambda x: (x["num"], x["group"]))

    return {
        "status": "ok",
        "teacher_name": found_teacher_name or teacher_query,
        "posts": list(found_posts),
        "schedule": teacher_schedule
    }
