# Модуль работы с базой данных SQLite через aiosqlite
import json
import aiosqlite
from config import DB_PATH

async def init_db():
    async with aiosqlite.connect(DB_PATH) as db:
        await db.execute("PRAGMA journal_mode=WAL;")
        await db.execute("PRAGMA synchronous=NORMAL;")
        await db.execute(
            """
            CREATE TABLE IF NOT EXISTS users (
                user_id INTEGER PRIMARY KEY,
                group_id INTEGER,
                group_name TEXT,
                subgroup INTEGER DEFAULT 0,
                notifications_enabled INTEGER DEFAULT 1,
                notify_before_mins INTEGER DEFAULT 10,
                notify_breaks INTEGER DEFAULT 1,
                notify_lesson_start INTEGER DEFAULT 1,
                notify_changes INTEGER DEFAULT 1,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
            """
        )
        await db.execute(
            """
            CREATE TABLE IF NOT EXISTS group_schedules (
                group_id INTEGER PRIMARY KEY,
                schedule_json TEXT,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
            """
        )
        # Проверяем и добавляем новые колонки при обновлении существующей базы данных
        cursor = await db.execute("PRAGMA table_info(users)")
        columns = [row[1] for row in await cursor.fetchall()]
        
        if "notifications_enabled" not in columns:
            await db.execute("ALTER TABLE users ADD COLUMN notifications_enabled INTEGER DEFAULT 1")
        if "notify_before_mins" not in columns:
            await db.execute("ALTER TABLE users ADD COLUMN notify_before_mins INTEGER DEFAULT 10")
        if "notify_breaks" not in columns:
            await db.execute("ALTER TABLE users ADD COLUMN notify_breaks INTEGER DEFAULT 1")
        if "notify_lesson_start" not in columns:
            await db.execute("ALTER TABLE users ADD COLUMN notify_lesson_start INTEGER DEFAULT 1")
        if "notify_changes" not in columns:
            await db.execute("ALTER TABLE users ADD COLUMN notify_changes INTEGER DEFAULT 1")

        await db.commit()

async def get_user(user_id: int):
    async with aiosqlite.connect(DB_PATH) as db:
        db.row_factory = aiosqlite.Row
        async with db.execute(
            """
            SELECT user_id, group_id, group_name, subgroup,
                   notifications_enabled, notify_before_mins, notify_breaks,
                   notify_lesson_start, notify_changes
            FROM users WHERE user_id = ?
            """,
            (user_id,),
        ) as cursor:
            row = await cursor.fetchone()
            if row:
                return dict(row)
            return None

async def set_user_group(user_id: int, group_id: int, group_name: str):
    async with aiosqlite.connect(DB_PATH) as db:
        await db.execute(
            """
            INSERT INTO users (user_id, group_id, group_name, updated_at)
            VALUES (?, ?, ?, CURRENT_TIMESTAMP)
            ON CONFLICT(user_id) DO UPDATE SET
                group_id = excluded.group_id,
                group_name = excluded.group_name,
                updated_at = CURRENT_TIMESTAMP
            """,
            (user_id, group_id, group_name),
        )
        await db.commit()

async def set_user_subgroup(user_id: int, subgroup: int):
    async with aiosqlite.connect(DB_PATH) as db:
        await db.execute(
            """
            UPDATE users
            SET subgroup = ?, updated_at = CURRENT_TIMESTAMP
            WHERE user_id = ?
            """,
            (subgroup, user_id),
        )
        await db.commit()

async def update_user_notifications(
    user_id: int,
    notifications_enabled: int = None,
    notify_before_mins: int = None,
    notify_breaks: int = None,
    notify_lesson_start: int = None,
    notify_changes: int = None
):
    updates = []
    params = []
    if notifications_enabled is not None:
        updates.append("notifications_enabled = ?")
        params.append(notifications_enabled)
    if notify_before_mins is not None:
        updates.append("notify_before_mins = ?")
        params.append(notify_before_mins)
    if notify_breaks is not None:
        updates.append("notify_breaks = ?")
        params.append(notify_breaks)
    if notify_lesson_start is not None:
        updates.append("notify_lesson_start = ?")
        params.append(notify_lesson_start)
    if notify_changes is not None:
        updates.append("notify_changes = ?")
        params.append(notify_changes)

    if not updates:
        return

    updates.append("updated_at = CURRENT_TIMESTAMP")
    params.append(user_id)
    query = f"UPDATE users SET {', '.join(updates)} WHERE user_id = ?"

    async with aiosqlite.connect(DB_PATH) as db:
        await db.execute(query, tuple(params))
        await db.commit()

async def get_active_users_for_notifications():
    async with aiosqlite.connect(DB_PATH) as db:
        db.row_factory = aiosqlite.Row
        async with db.execute(
            """
            SELECT user_id, group_id, group_name, subgroup,
                   notifications_enabled, notify_before_mins, notify_breaks,
                   notify_lesson_start, notify_changes
            FROM users
            WHERE group_id IS NOT NULL AND notifications_enabled = 1
            """
        ) as cursor:
            rows = await cursor.fetchall()
            return [dict(r) for r in rows]

async def get_users_for_group_changes(group_id: int):
    async with aiosqlite.connect(DB_PATH) as db:
        db.row_factory = aiosqlite.Row
        async with db.execute(
            """
            SELECT user_id, group_id, group_name, subgroup
            FROM users
            WHERE group_id = ? AND notifications_enabled = 1 AND notify_changes = 1
            """,
            (group_id,),
        ) as cursor:
            rows = await cursor.fetchall()
            return [dict(r) for r in rows]

async def get_all_active_group_ids():
    async with aiosqlite.connect(DB_PATH) as db:
        async with db.execute(
            "SELECT DISTINCT group_id, group_name FROM users WHERE group_id IS NOT NULL"
        ) as cursor:
            rows = await cursor.fetchall()
            return [{"group_id": r[0], "group_name": r[1]} for r in rows]

async def get_stored_group_schedule(group_id: int):
    async with aiosqlite.connect(DB_PATH) as db:
        async with db.execute(
            "SELECT schedule_json FROM group_schedules WHERE group_id = ?",
            (group_id,),
        ) as cursor:
            row = await cursor.fetchone()
            if row and row[0]:
                try:
                    return json.loads(row[0])
                except Exception:
                    return None
            return None

async def save_group_schedule(group_id: int, schedule_data: dict):
    async with aiosqlite.connect(DB_PATH) as db:
        await db.execute(
            """
            INSERT INTO group_schedules (group_id, schedule_json, updated_at)
            VALUES (?, ?, CURRENT_TIMESTAMP)
            ON CONFLICT(group_id) DO UPDATE SET
                schedule_json = excluded.schedule_json,
                updated_at = CURRENT_TIMESTAMP
            """,
            (group_id, json.dumps(schedule_data, ensure_ascii=False)),
        )
        await db.commit()

async def get_stats():
    async with aiosqlite.connect(DB_PATH) as db:
        async with db.execute("SELECT COUNT(*) FROM users") as cursor:
            total_users = (await cursor.fetchone())[0]
        async with db.execute("SELECT COUNT(*) FROM users WHERE group_id IS NOT NULL") as cursor:
            active_users = (await cursor.fetchone())[0]
        async with db.execute("SELECT COUNT(*) FROM users WHERE notifications_enabled = 1") as cursor:
            notif_users = (await cursor.fetchone())[0]
        return {
            "total_users": total_users,
            "active_users": active_users,
            "notif_users": notif_users
        }
