# Клиент для работы с API расписания РИИ, форматирование и сравнение изменений на завтра
import asyncio
import time
import re
import json
import hashlib
import aiohttp
from datetime import datetime
from zoneinfo import ZoneInfo
from typing import Dict, List, Optional, Any, Tuple
from config import API_BASE_URL, CACHE_TTL_SECONDS

RUBTSOVSK_TZ = ZoneInfo("Asia/Barnaul")

class RiiApiClient:
    def __init__(self):
        self._session: Optional[aiohttp.ClientSession] = None
        self._groups_cache: Optional[List[Dict[str, Any]]] = None
        self._groups_cache_time: float = 0
        self._schedule_cache: Dict[int, Dict[str, Any]] = {}
        self._schedule_cache_time: Dict[int, float] = {}

    async def _get_session(self) -> aiohttp.ClientSession:
        if self._session is None or self._session.closed:
            connector = aiohttp.TCPConnector(ssl=False)
            timeout = aiohttp.ClientTimeout(total=15)
            headers = {
                "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
                "Referer": "https://www.rubinst.ru/schedule"
            }
            self._session = aiohttp.ClientSession(connector=connector, timeout=timeout, headers=headers)
        return self._session

    async def close(self):
        if self._session and not self._session.closed:
            await self._session.close()

    async def _fetch_json(self, params: Optional[Dict[str, Any]] = None) -> Dict[str, Any]:
        session = await self._get_session()
        async with session.get(API_BASE_URL, params=params) as response:
            response.raise_for_status()
            return await response.json()

    async def get_groups(self, force_refresh: bool = False) -> List[Dict[str, Any]]:
        now = time.time()
        if not force_refresh and self._groups_cache and (now - self._groups_cache_time < CACHE_TTL_SECONDS):
            return self._groups_cache

        data = await self._fetch_json()
        raw_groups = data.get("groups", [])
        
        valid_groups = []
        for g in raw_groups:
            sem = g.get("sem", 0)
            if sem == 0:
                continue
            course = (sem + 1) // 2
            valid_groups.append({
                "id": int(g["id"]),
                "name": str(g["name"]).strip(),
                "sem": sem,
                "course": course
            })
        
        valid_groups.sort(key=lambda x: (x["course"], x["name"]))
        self._groups_cache = valid_groups
        self._groups_cache_time = now
        return valid_groups

    async def get_courses_map(self, force_refresh: bool = False) -> Dict[int, List[Dict[str, Any]]]:
        groups = await self.get_groups(force_refresh=force_refresh)
        courses: Dict[int, List[Dict[str, Any]]] = {}
        for g in groups:
            c = g["course"]
            if c not in courses:
                courses[c] = []
            courses[c].append(g)
        return dict(sorted(courses.items()))

    async def find_group_by_name(self, name_query: str) -> Optional[Dict[str, Any]]:
        groups = await self.get_groups()
        query_norm = re.sub(r"[\s\-_]", "", name_query.lower())
        
        for g in groups:
            g_norm = re.sub(r"[\s\-_]", "", g["name"].lower())
            if g_norm == query_norm:
                return g
        
        for g in groups:
            g_norm = re.sub(r"[\s\-_]", "", g["name"].lower())
            if query_norm in g_norm:
                return g
        return None

    async def search_groups(self, name_query: str) -> List[Dict[str, Any]]:
        groups = await self.get_groups()
        query_norm = re.sub(r"[\s\-_]", "", name_query.lower())
        results = []
        for g in groups:
            g_norm = re.sub(r"[\s\-_]", "", g["name"].lower())
            if query_norm in g_norm:
                results.append(g)
        return results

    async def get_group_by_id(self, group_id: int) -> Optional[Dict[str, Any]]:
        groups = await self.get_groups()
        for g in groups:
            if g["id"] == group_id:
                return g
        return None

    async def get_schedule(self, group_id: int, force_refresh: bool = False) -> Dict[str, Any]:
        now = time.time()
        if not force_refresh and group_id in self._schedule_cache:
            if now - self._schedule_cache_time.get(group_id, 0) < CACHE_TTL_SECONDS:
                return self._schedule_cache[group_id]

        data = await self._fetch_json(params={"Group": group_id})
        schedule_payload = data.get("schedule", {})
        self._schedule_cache[group_id] = schedule_payload
        self._schedule_cache_time[group_id] = now
        return schedule_payload

def clean_time(time_str: Optional[str]) -> str:
    if not time_str:
        return ""
    cleaned = re.sub(r"<br\s*/?>", " - ", time_str, flags=re.IGNORECASE)
    cleaned = cleaned.replace(".", ":")
    return cleaned.strip()

def parse_para_time_range(time_str: Optional[str], default_para_num: int = 1) -> Tuple[int, int, str, str]:
    default_times = {
        1: (8 * 60 + 30, 10 * 60 + 0, "08:30", "10:00"),
        2: (10 * 60 + 10, 11 * 60 + 40, "10:10", "11:40"),
        3: (12 * 60 + 10, 13 * 60 + 40, "12:10", "13:40"),
        4: (13 * 60 + 50, 15 * 60 + 20, "13:50", "15:20"),
        5: (15 * 60 + 30, 17 * 60 + 0, "15:30", "17:00"),
        6: (17 * 60 + 10, 18 * 60 + 40, "17:10", "18:40")
    }

    if not time_str:
        return default_times.get(default_para_num, (0, 0, "", ""))

    c = clean_time(time_str)
    match = re.search(r"(\d{1,2})[:.](\d{2})\s*-\s*(\d{1,2})[:.](\d{2})", c)
    if match:
        try:
            s_h, s_m = int(match.group(1)), int(match.group(2))
            e_h, e_m = int(match.group(3)), int(match.group(4))
            start_mins = s_h * 60 + s_m
            end_mins = e_h * 60 + e_m
            start_str = f"{s_h:02d}:{s_m:02d}"
            end_str = f"{e_h:02d}:{e_m:02d}"
            return start_mins, end_mins, start_str, end_str
        except Exception:
            pass

    return default_times.get(default_para_num, (0, 0, "", ""))

def format_para_item(
    p_num: str,
    p_time: str,
    item: Dict[str, Any],
    user_subgroup: int = 0,
    status_tag: str = ""
) -> str:
    lines = []
    time_display = f"[{p_time}]" if p_time else ""
    tag_display = f" [{status_tag}]" if status_tag else ""
    
    if item.get("isDouble"):
        lines.append(f"{p_num} пара {time_display}{tag_display}")
        
        # 1-я подгруппа
        if user_subgroup in (0, 1):
            s1 = item.get('subj1') or ''
            t1 = f" ({item.get('type1')})" if item.get('type1') else ""
            a1 = f"ауд. {item.get('aud1')}" if item.get('aud1') else ""
            tch1 = item.get('teacher1') or ""
            pst1 = f" ({item.get('teachPost1')})" if item.get('teachPost1') else ""
            details1 = ", ".join(filter(None, [a1, f"{tch1}{pst1}".strip()]))
            lines.append(f"  1 п/г: {s1}{t1}")
            if details1:
                lines.append(f"         {details1}")
                
        # 2-я подгруппа
        if user_subgroup in (0, 2):
            s2 = item.get('subj2') or ''
            t2 = f" ({item.get('type2')})" if item.get('type2') else ""
            a2 = f"ауд. {item.get('aud2')}" if item.get('aud2') else ""
            tch2 = item.get('teacher2') or ""
            pst2 = f" ({item.get('teachPost2')})" if item.get('teachPost2') else ""
            details2 = ", ".join(filter(None, [a2, f"{tch2}{pst2}".strip()]))
            lines.append(f"  2 п/г: {s2}{t2}")
            if details2:
                lines.append(f"         {details2}")
    else:
        subj = item.get('subj1') or ''
        type_str = f" ({item.get('type1')})" if item.get('type1') else ""
        aud = f"ауд. {item.get('aud1')}" if item.get('aud1') else ""
        tch = item.get('teacher1') or ""
        post = f" ({item.get('teachPost1')})" if item.get('teachPost1') else ""
        teacher_full = f"{tch}{post}".strip()
        details = ", ".join(filter(None, [aud, teacher_full]))
        
        lines.append(f"{p_num} пара {time_display}{tag_display}: {subj}{type_str}")
        if details:
            lines.append(f"   {details}")
            
    return "\n".join(lines)

def get_rubtsovsk_now() -> datetime:
    return datetime.now(RUBTSOVSK_TZ)

def get_tomorrow_target(schedule: Dict[str, Any]) -> Tuple[int, int, str]:
    now = get_rubtsovsk_now()
    cur_week = int(schedule.get("weekNumber", 1))
    cur_day = now.isoweekday()

    day_names = {
        1: "Понедельник", 2: "Вторник", 3: "Среда",
        4: "Четверг", 5: "Пятница", 6: "Суббота", 7: "Воскресенье"
    }

    if cur_day >= 6:
        next_day = 1
        next_week = 2 if cur_week == 1 else 1
    else:
        next_day = cur_day + 1
        next_week = cur_week

    return next_week, next_day, day_names.get(next_day, "Понедельник")

def format_day_schedule(
    group_name: str,
    schedule: Dict[str, Any],
    week_num: int,
    day_num: int,
    user_subgroup: int = 0,
    check_live_status: bool = True
) -> str:
    week_days = schedule.get("weekDays", {})
    day_name = week_days.get(str(day_num), f"День {day_num}")
    para_times = schedule.get("paraTimes", {})
    
    schedule_data = schedule.get("scheduleData", {})
    week_data = schedule_data.get(str(week_num), {})
    day_data = week_data.get(str(day_num), {})
    
    cur_week_site = int(schedule.get("weekNumber", 1))
    cur_day_site = int(schedule.get("dayNumber", 1))
    
    now = get_rubtsovsk_now()
    cur_mins = now.hour * 60 + now.minute
    time_str = now.strftime("%H:%M")
    
    is_today = (week_num == cur_week_site and day_num == cur_day_site)
    
    week_rome = "I" if week_num == 1 else "II"
    header_parts = [
        f"Расписание: {group_name}",
        f"{day_name} ({week_rome} неделя)"
    ]
    if is_today:
        header_parts.append(f"Время в Рубцовске: {time_str}")
    header = "\n".join(header_parts) + "\n" + "-" * 30
    
    if not day_data:
        return f"{header}\nПар нет"

    # Расчет статуса пар в реальном времени для сегодняшнего дня
    status_bar = ""
    next_para_num = None
    sorted_paras = sorted(day_data.keys(), key=lambda x: int(x))

    if is_today and check_live_status:
        ongoing_para = None
        for p_str in sorted_paras:
            p_n = int(p_str)
            s_m, e_m, s_s, e_s = parse_para_time_range(para_times.get(p_str), p_n)
            if s_m <= cur_mins <= e_m:
                ongoing_para = (p_n, e_s, e_m - cur_mins)
                break
            elif cur_mins < s_m and next_para_num is None:
                next_para_num = (p_n, s_s, s_m - cur_mins)

        if ongoing_para:
            p_n, end_s, rem = ongoing_para
            status_bar = f"Статус: Идет {p_n} пара (до {end_s}, осталось {rem} мин)\n"
        elif next_para_num:
            p_n, start_s, rem = next_para_num
            first_p_n = int(sorted_paras[0])
            first_s_m, _, _, _ = parse_para_time_range(para_times.get(str(first_p_n)), first_p_n)
            if cur_mins < first_s_m:
                status_bar = f"Статус: Занятия еще не начались. 1 пара начнется в {start_s} (через {rem} мин)\n"
            else:
                status_bar = f"Статус: Сейчас перемена (до {start_s}, осталось {rem} мин). Следующая: {p_n} пара\n"
        else:
            status_bar = "Статус: Все пары на сегодня завершены\n"

    pairs = []
    found_next = False
    for p_str in sorted_paras:
        p_n = int(p_str)
        p_info = day_data[p_str]
        p_time_clean = clean_time(para_times.get(p_str, ""))
        
        status_tag = ""
        if is_today and check_live_status:
            s_m, e_m, _, _ = parse_para_time_range(para_times.get(p_str), p_n)
            if cur_mins > e_m:
                status_tag = "ЗАВЕРШЕНА"
            elif s_m <= cur_mins <= e_m:
                status_tag = "ИДЕТ СЕЙЧАС"
            elif cur_mins < s_m and not found_next:
                status_tag = "СЛЕДУЮЩАЯ"
                found_next = True
            else:
                status_tag = "ПРЕДСТОИТ"
                
        pairs.append(format_para_item(p_str, p_time_clean, p_info, user_subgroup, status_tag))
        
    result_parts = [header]
    if status_bar:
        result_parts.append(status_bar)
    result_parts.append("\n\n".join(pairs))
    
    return "\n".join(result_parts)

def format_week_schedule(
    group_name: str,
    schedule: Dict[str, Any],
    week_num: int,
    user_subgroup: int = 0
) -> List[str]:
    week_days = schedule.get("weekDays", {})
    para_times = schedule.get("paraTimes", {})
    schedule_data = schedule.get("scheduleData", {})
    week_data = schedule_data.get(str(week_num), {})
    week_rome = "I" if week_num == 1 else "II"
    
    header = f"Расписание на неделю: {group_name}\nНеделя {week_rome}\n" + "=" * 30
    
    day_blocks = []
    has_any = False
    for d_num in range(1, 7):
        d_str = str(d_num)
        day_name = week_days.get(d_str, f"День {d_num}")
        day_data = week_data.get(d_str, {})
        
        day_lines = [f"\n--- {day_name} ---"]
        if not day_data:
            day_lines.append("Пар нет")
        else:
            has_any = True
            for p_str in sorted(day_data.keys(), key=lambda x: int(x)):
                p_info = day_data[p_str]
                p_time = clean_time(para_times.get(p_str, ""))
                day_lines.append(format_para_item(p_str, p_time, p_info, user_subgroup))
        day_blocks.append("\n".join(day_lines))
        
    if not has_any:
        return [f"Расписание: {group_name}\nНеделя {week_rome}\n\nНа этой неделе занятий нет."]

    # Разделяем по частям, если текст слишком длинный для Telegram (лимит 4096 символов)
    full_text = header + "\n" + "\n".join(day_blocks)
    if len(full_text) <= 3900:
        return [full_text]
    
    part1 = header + "\n" + "\n".join(day_blocks[:3])
    part2 = f"Расписание: {group_name} (продолжение)\nНеделя {week_rome}\n" + "=" * 30 + "\n" + "\n".join(day_blocks[3:])
    return [part1, part2]

def format_bells(schedule: Dict[str, Any]) -> str:
    para_times = schedule.get("paraTimes", {})
    if not para_times:
        para_times = {
            "1": "08.30 - 10.00",
            "2": "10.10 - 11.40",
            "3": "12.10 - 13.40",
            "4": "13.50 - 15.20",
            "5": "15.30 - 17.00",
            "6": "17.10 - 18.40"
        }
    lines = ["Расписание звонков (время г. Рубцовск):", "-" * 35]
    for p_num in sorted(para_times.keys(), key=lambda x: int(x)):
        t_clean = clean_time(para_times[p_num])
        lines.append(f"{p_num} пара: {t_clean}")
    return "\n".join(lines)

def format_exams(group_name: str, schedule: Dict[str, Any]) -> str:
    exams = schedule.get("exams", [])
    if not exams:
        return f"Расписание экзаменов ({group_name}):\nЭкзамены не назначены или сессия завершена."
        
    lines = [f"Расписание экзаменов: {group_name}", "-" * 30]
    for ex in exams:
        date_time = f"{ex.get('date', '')} {ex.get('time', '')}".strip()
        subj = ex.get('subj', 'Экзамен')
        aud = f"ауд. {ex.get('aud')}" if ex.get('aud') else ""
        type_str = ex.get('type', '')
        info = ", ".join(filter(None, [aud, type_str]))
        lines.append(f"{date_time} - {subj}")
        if info:
            lines.append(f"  {info}")
    return "\n".join(lines)

def format_para_short(item: Optional[Dict[str, Any]]) -> str:
    if not item:
        return "нет"
    if item.get("isDouble"):
        parts = []
        if item.get("subj1"):
            p1 = f"1 п/г: {item.get('subj1')}"
            if item.get("aud1"):
                p1 += f" (ауд. {item.get('aud1')})"
            parts.append(p1)
        if item.get("subj2"):
            p2 = f"2 п/г: {item.get('subj2')}"
            if item.get("aud2"):
                p2 += f" (ауд. {item.get('aud2')})"
            parts.append(p2)
        return ", ".join(parts) if parts else "пара с подгруппами"
    
    subj = item.get("subj1") or "предмет"
    type_str = f" ({item.get('type1')})" if item.get("type1") else ""
    aud = f", ауд. {item.get('aud1')}" if item.get("aud1") else ""
    tch = f", {item.get('teacher1')}" if item.get("teacher1") else ""
    return f"{subj}{type_str}{aud}{tch}"

def find_tomorrow_diff(
    old_sched: Dict[str, Any],
    new_sched: Dict[str, Any],
    t_week: int,
    t_day: int
) -> List[str]:
    diffs = []
    
    old_msg = old_sched.get("message")
    new_msg = new_sched.get("message")
    if old_msg != new_msg and new_msg:
        diffs.append(f"Объявление института: {new_msg}")
        
    old_day = old_sched.get("scheduleData", {}).get(str(t_week), {}).get(str(t_day), {})
    new_day = new_sched.get("scheduleData", {}).get(str(t_week), {}).get(str(t_day), {})
    
    all_paras = sorted(
        set(list(old_day.keys()) + list(new_day.keys())),
        key=lambda x: int(x) if x.isdigit() else 99
    )
    for p in all_paras:
        old_p = old_day.get(p)
        new_p = new_day.get(p)
        if old_p != new_p:
            if old_p is None and new_p is not None:
                diffs.append(f"Добавлена {p} пара:\n  -> {format_para_short(new_p)}")
            elif old_p is not None and new_p is None:
                diffs.append(f"Отменена {p} пара:\n  -> Было: {format_para_short(old_p)}")
            else:
                diffs.append(f"Изменение в {p} паре:\n  Было: {format_para_short(old_p)}\n  Стало: {format_para_short(new_p)}")
                
    return diffs

api_client = RiiApiClient()
