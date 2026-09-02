# Фоновый процесс отправки уведомлений о парах, переменах и срочных правках на завтра
import asyncio
import logging
import time
from typing import Set, Dict, Any, List
from aiogram import Bot
from aiogram.exceptions import TelegramForbiddenError, TelegramBadRequest

from config import CHANGE_CHECK_INTERVAL_SECONDS
from database import (
    get_active_users_for_notifications,
    get_all_active_group_ids,
    get_stored_group_schedule,
    save_group_schedule,
    get_users_for_group_changes
)
from services.api import (
    api_client,
    get_rubtsovsk_now,
    get_tomorrow_target,
    parse_para_time_range,
    clean_time,
    format_para_item,
    hash_tomorrow_payload,
    find_tomorrow_diff
)

logger = logging.getLogger("rii_schedule_bot.notifier")

class ScheduleNotifier:
    def __init__(self, bot: Bot):
        self.bot = bot
        self._sent_keys: Set[str] = set()
        self._last_day_cleaned: str = ""
        self._last_change_check_time: float = 0

    def _cleanup_keys_if_new_day(self, current_day_str: str):
        if self._last_day_cleaned != current_day_str:
            self._sent_keys.clear()
            self._last_day_cleaned = current_day_str

    async def check_and_notify_lessons(self):
        now = get_rubtsovsk_now()
        today_str = now.strftime("%Y-%m-%d")
        self._cleanup_keys_if_new_day(today_str)

        weekday = now.isoweekday()
        if weekday > 6:
            return

        users = await get_active_users_for_notifications()
        if not users:
            return

        cur_mins = now.hour * 60 + now.minute

        # Группируем пользователей по group_id, чтобы не делать лишних запросов к расписанию
        users_by_group: Dict[int, List[Dict[str, Any]]] = {}
        for u in users:
            gid = u.get("group_id")
            if gid:
                users_by_group.setdefault(gid, []).append(u)

        for group_id, group_users in users_by_group.items():
            try:
                sched = await api_client.get_schedule(group_id)
            except Exception as e:
                logger.warning("Ошибка получения расписания для группы %s: %s", group_id, e)
                continue

            if not sched:
                continue

            week_num = int(sched.get("weekNumber", 1))
            schedule_data = sched.get("scheduleData", {})
            day_data = schedule_data.get(str(week_num), {}).get(str(weekday), {})
            if not day_data:
                continue

            para_times = sched.get("paraTimes", {})
            sorted_paras = sorted(day_data.keys(), key=lambda x: int(x))

            for idx, p_str in enumerate(sorted_paras):
                p_n = int(p_str)
                p_info = day_data[p_str]
                s_m, e_m, s_str, e_str = parse_para_time_range(para_times.get(p_str), p_n)
                p_time_clean = clean_time(para_times.get(p_str))

                for u in group_users:
                    user_id = u["user_id"]
                    subgroup = u.get("subgroup", 0)
                    notify_before = u.get("notify_before_mins", 10)
                    notify_breaks = u.get("notify_breaks", 1)
                    notify_start = u.get("notify_lesson_start", 1)

                    # 1. Напоминание перед началом пары / на перемене
                    if notify_before > 0 and cur_mins == (s_m - notify_before):
                        key = f"{user_id}:{today_str}:{p_n}:before:{notify_before}"
                        if key not in self._sent_keys:
                            self._sent_keys.add(key)
                            item_text = format_para_item(p_str, p_time_clean, p_info, subgroup)
                            msg = (
                                f"Напоминание о паре (время в Рубцовске: {now.strftime('%H:%M')}):\n"
                                f"Через {notify_before} мин начнется {p_n} пара ({s_str} - {e_str})\n\n"
                                f"{item_text}"
                            )
                            await self._send_message(user_id, msg)

                    # 2. Оповещение о начале пары
                    if notify_start == 1 and cur_mins == s_m:
                        key = f"{user_id}:{today_str}:{p_n}:start"
                        if key not in self._sent_keys:
                            self._sent_keys.add(key)
                            item_text = format_para_item(p_str, p_time_clean, p_info, subgroup)
                            msg = (
                                f"Началась {p_n} пара ({s_str} - {e_str}):\n\n"
                                f"{item_text}"
                            )
                            await self._send_message(user_id, msg)

                    # 3. Окончание пары и объявление о перемене
                    if notify_breaks == 1 and cur_mins == e_m:
                        key = f"{user_id}:{today_str}:{p_n}:ended"
                        if key not in self._sent_keys:
                            self._sent_keys.add(key)
                            if idx + 1 < len(sorted_paras):
                                next_p_str = sorted_paras[idx + 1]
                                next_p_n = int(next_p_str)
                                next_info = day_data[next_p_str]
                                next_s_m, _, next_s_str, _ = parse_para_time_range(para_times.get(next_p_str), next_p_n)
                                break_len = max(0, next_s_m - e_m)
                                next_time_clean = clean_time(para_times.get(next_p_str))
                                next_item_text = format_para_item(next_p_str, next_time_clean, next_info, subgroup)
                                
                                msg = (
                                    f"Закончилась {p_n} пара. Сейчас перемена {break_len} мин (до {next_s_str}).\n\n"
                                    f"Следующая ({next_p_n} пара в {next_s_str}):\n"
                                    f"{next_item_text}"
                                )
                            else:
                                msg = f"Закончилась {p_n} пара. На сегодня пары завершены!"
                            
                            await self._send_message(user_id, msg)

    async def check_tomorrow_schedule_changes(self):
        active_groups = await get_all_active_group_ids()
        if not active_groups:
            return

        for g in active_groups:
            gid = g["group_id"]
            gname = g["group_name"]

            try:
                fresh_sched = await api_client.get_schedule(gid, force_refresh=True)
            except Exception as e:
                logger.warning("Не удалось проверить правки на завтра для группы %s: %s", gid, e)
                continue

            if not fresh_sched:
                continue

            t_week, t_day, t_day_name = get_tomorrow_target(fresh_sched)
            t_week_rome = "I" if t_week == 1 else "II"
            new_hash = hash_tomorrow_payload(fresh_sched, t_week, t_day)
            
            old_hash, old_sched = await get_stored_group_schedule(gid)

            if old_hash is None:
                # Первичная инициализация состояния расписания на завтра
                await save_group_schedule(gid, new_hash, fresh_sched)
                continue

            if old_hash != new_hash:
                diffs = find_tomorrow_diff(old_sched or {}, fresh_sched, t_week, t_day)
                await save_group_schedule(gid, new_hash, fresh_sched)

                users_to_notify = await get_users_for_group_changes(gid)
                if not users_to_notify:
                    continue

                if diffs:
                    diff_text = "\n\n".join(diffs[:8])
                    msg = (
                        f"Срочно! Изменилось расписание на завтра для группы {gname} ({t_day_name}, {t_week_rome} неделя):\n\n"
                        f"{diff_text}\n\n"
                        "Нажми кнопку «Завтра» для просмотра обновленного расписания."
                    )
                else:
                    msg = (
                        f"Внимание! В расписание на завтра для группы {gname} ({t_day_name}, {t_week_rome} неделя) внесены изменения на сайте института.\n\n"
                        "Нажми кнопку «Завтра» для просмотра актуального расписания."
                    )

                for u in users_to_notify:
                    await self._send_message(u["user_id"], msg)
                
                logger.info("Отправлено срочное оповещение об изменении на завтра для группы %s (%d пользователей)", gname, len(users_to_notify))

    async def _send_message(self, user_id: int, text: str):
        try:
            await self.bot.send_message(chat_id=user_id, text=text)
        except (TelegramForbiddenError, TelegramBadRequest):
            pass
        except Exception as e:
            logger.warning("Ошибка отправки уведомления пользователю %s: %s", user_id, e)

    async def start_loop(self):
        logger.info("Фоновый процесс уведомлений запущен")
        while True:
            now_ts = time.time()
            try:
                await self.check_and_notify_lessons()
            except Exception as e:
                logger.error("Ошибка при проверке уроков: %s", e, exc_info=True)

            if now_ts - self._last_change_check_time >= CHANGE_CHECK_INTERVAL_SECONDS:
                try:
                    await self.check_tomorrow_schedule_changes()
                    self._last_change_check_time = now_ts
                except Exception as e:
                    logger.error("Ошибка при отслеживании правок на завтра: %s", e, exc_info=True)

            await asyncio.sleep(20)
