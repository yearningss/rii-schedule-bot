# Модуль работы с базой данных через SQLAlchemy ORM (asyncio)
# Архитектура базы данных и переход на SQLAlchemy ORM выполнены по рекомендациям: https://github.com/whatqt
from __future__ import annotations

import json
import logging
import os
import secrets
from datetime import datetime, timedelta
from typing import Optional, List, Dict, Any

from sqlalchemy import (
    BigInteger, Integer, String, Text, DateTime,
    func, select, update, delete, event, text, distinct
)
from sqlalchemy.ext.asyncio import (
    AsyncSession,
    async_sessionmaker,
    create_async_engine
)
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column

from config import DB_PATH

logger = logging.getLogger("rii_schedule_bot.database")

# 1. Настройка асинхронного движка SQLite через aiosqlite
raw_db_path = DB_PATH.resolve().as_posix()
DB_URL = f"sqlite+aiosqlite:///{raw_db_path}"
engine = create_async_engine(DB_URL, echo=False, future=True)

# Включение WAL-режима и нормальной синхронизации для максимальной скорости SQLite
@event.listens_for(engine.sync_engine, "connect")
def set_sqlite_pragma(dbapi_connection, connection_record):
    cursor = dbapi_connection.cursor()
    cursor.execute("PRAGMA journal_mode=WAL")
    cursor.execute("PRAGMA synchronous=NORMAL")
    cursor.close()

async_session_maker = async_sessionmaker(
    bind=engine,
    class_=AsyncSession,
    expire_on_commit=False,
    autoflush=False
)

async def get_session() -> AsyncSession:
    async with async_session_maker() as session:
        yield session


# 2. Модели декларативного сопоставления SQLAlchemy ORM
class Base(DeclarativeBase):
    pass


class User(Base):
    __tablename__ = "users"

    user_id: Mapped[int] = mapped_column(BigInteger, primary_key=True)
    group_id: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    group_name: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    subgroup: Mapped[int] = mapped_column(Integer, default=0, server_default=text("0"))
    notifications_enabled: Mapped[int] = mapped_column(Integer, default=1, server_default=text("1"))
    notify_before_mins: Mapped[int] = mapped_column(Integer, default=10, server_default=text("10"))
    notify_breaks: Mapped[int] = mapped_column(Integer, default=1, server_default=text("1"))
    notify_lesson_start: Mapped[int] = mapped_column(Integer, default=1, server_default=text("1"))
    notify_changes: Mapped[int] = mapped_column(Integer, default=1, server_default=text("1"))
    has_mobile_app: Mapped[int] = mapped_column(Integer, default=0, server_default=text("0"))
    first_name: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    last_name: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    username: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    avatar_url: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    mobile_app_installed_at: Mapped[Optional[datetime]] = mapped_column(DateTime, nullable=True)
    device_id: Mapped[Optional[str]] = mapped_column(String, nullable=True, index=True)
    client_user_id: Mapped[Optional[str]] = mapped_column(String, nullable=True, index=True)
    platform: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    last_active: Mapped[Optional[datetime]] = mapped_column(DateTime, nullable=True, server_default=func.now())
    app_version: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    yandex_id: Mapped[Optional[str]] = mapped_column(String, nullable=True, index=True)
    group_kb_mode: Mapped[str] = mapped_column(String(32), default="selective", server_default=text("'selective'"))
    has_seen_guide: Mapped[int] = mapped_column(Integer, default=0, server_default=text("0"))
    created_at: Mapped[Optional[datetime]] = mapped_column(DateTime, server_default=func.now())
    updated_at: Mapped[Optional[datetime]] = mapped_column(DateTime, server_default=func.now(), onupdate=func.now())

    def to_dict(self) -> Dict[str, Any]:
        return {
            "user_id": self.user_id,
            "group_id": self.group_id,
            "group_name": self.group_name,
            "subgroup": self.subgroup if self.subgroup is not None else 0,
            "notifications_enabled": self.notifications_enabled if self.notifications_enabled is not None else 1,
            "notify_before_mins": self.notify_before_mins if self.notify_before_mins is not None else 10,
            "notify_breaks": self.notify_breaks if self.notify_breaks is not None else 1,
            "notify_lesson_start": self.notify_lesson_start if self.notify_lesson_start is not None else 1,
            "notify_changes": self.notify_changes if self.notify_changes is not None else 1,
            "has_mobile_app": self.has_mobile_app if self.has_mobile_app is not None else 0,
            "first_name": self.first_name,
            "last_name": self.last_name,
            "username": self.username,
            "avatar_url": self.avatar_url,
            "mobile_app_installed_at": str(self.mobile_app_installed_at) if self.mobile_app_installed_at else None,
            "device_id": self.device_id,
            "client_user_id": self.client_user_id,
            "platform": self.platform,
            "last_active": str(self.last_active) if self.last_active else None,
            "app_version": self.app_version,
            "yandex_id": self.yandex_id,
            "group_kb_mode": self.group_kb_mode if self.group_kb_mode else "selective",
            "has_seen_guide": self.has_seen_guide if self.has_seen_guide is not None else 0,
            "created_at": str(self.created_at) if self.created_at else None,
            "updated_at": str(self.updated_at) if self.updated_at else None,
        }

    def __getitem__(self, item: str):
        return getattr(self, item)

    def get(self, item: str, default=None):
        return getattr(self, item, default)


class GroupSchedule(Base):
    __tablename__ = "group_schedules"

    group_id: Mapped[int] = mapped_column(Integer, primary_key=True)
    schedule_json: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    updated_at: Mapped[Optional[datetime]] = mapped_column(DateTime, server_default=func.now(), onupdate=func.now())

    def to_dict(self) -> Dict[str, Any]:
        return {
            "group_id": self.group_id,
            "schedule_json": self.schedule_json,
            "updated_at": str(self.updated_at) if self.updated_at else None,
        }


class AppAuthSession(Base):
    __tablename__ = "app_auth_sessions"

    session_token: Mapped[str] = mapped_column(String(64), primary_key=True)
    user_id: Mapped[Optional[int]] = mapped_column(BigInteger, nullable=True)
    status: Mapped[str] = mapped_column(String(32), default="pending", server_default=text("'pending'"))
    auth_token: Mapped[Optional[str]] = mapped_column(String(128), nullable=True)
    created_at: Mapped[Optional[datetime]] = mapped_column(DateTime, server_default=func.now())
    expires_at: Mapped[Optional[datetime]] = mapped_column(DateTime, nullable=True)

    def to_dict(self) -> Dict[str, Any]:
        return {
            "session_token": self.session_token,
            "user_id": self.user_id,
            "status": self.status,
            "auth_token": self.auth_token,
            "created_at": str(self.created_at) if self.created_at else None,
            "expires_at": str(self.expires_at) if self.expires_at else None,
        }


class AppUser(Base):
    __tablename__ = "app_users"

    auth_token: Mapped[str] = mapped_column(String(128), primary_key=True)
    user_id: Mapped[int] = mapped_column(BigInteger, nullable=False)
    created_at: Mapped[Optional[datetime]] = mapped_column(DateTime, server_default=func.now())
    last_active: Mapped[Optional[datetime]] = mapped_column(DateTime, server_default=func.now(), onupdate=func.now())

    def to_dict(self) -> Dict[str, Any]:
        return {
            "auth_token": self.auth_token,
            "user_id": self.user_id,
            "created_at": str(self.created_at) if self.created_at else None,
            "last_active": str(self.last_active) if self.last_active else None,
        }


# 3. Инициализация и миграция базы данных
async def init_db() -> None:
    async with engine.begin() as conn:
        # Создаем таблицы если они еще не существуют
        await conn.run_sync(Base.metadata.create_all)

        # Проверка и динамическое добавление колонок для обратной совместимости
        try:
            cursor = await conn.execute(text("PRAGMA table_info(users)"))
            columns = {row[1] for row in cursor.fetchall()}
        except Exception as e:
            logger.warning("Не удалось прочитать PRAGMA table_info(users): %s", e)
            columns = set()

        columns_to_ensure = [
            ("notifications_enabled", "INTEGER DEFAULT 1"),
            ("notify_before_mins", "INTEGER DEFAULT 10"),
            ("notify_breaks", "INTEGER DEFAULT 1"),
            ("notify_lesson_start", "INTEGER DEFAULT 1"),
            ("notify_changes", "INTEGER DEFAULT 1"),
            ("has_mobile_app", "INTEGER DEFAULT 0"),
            ("first_name", "TEXT"),
            ("last_name", "TEXT"),
            ("username", "TEXT"),
            ("avatar_url", "TEXT"),
            ("mobile_app_installed_at", "TIMESTAMP"),
            ("device_id", "TEXT"),
            ("client_user_id", "TEXT"),
            ("platform", "TEXT"),
            ("last_active", "TIMESTAMP"),
            ("app_version", "TEXT"),
            ("yandex_id", "TEXT"),
            ("group_kb_mode", "TEXT DEFAULT 'selective'"),
            ("has_seen_guide", "INTEGER DEFAULT 0"),
        ]

        for col_name, col_def in columns_to_ensure:
            if col_name not in columns:
                try:
                    await conn.execute(text(f"ALTER TABLE users ADD COLUMN {col_name} {col_def}"))
                except Exception as e:
                    logger.debug("Колонка %s уже существует или пропущена: %s", col_name, e)

        indexes_to_ensure = [
            "CREATE INDEX IF NOT EXISTS idx_users_device_id ON users(device_id)",
            "CREATE INDEX IF NOT EXISTS idx_users_client_user_id ON users(client_user_id)",
            "CREATE INDEX IF NOT EXISTS idx_users_yandex_id ON users(yandex_id)"
        ]

        for idx_sql in indexes_to_ensure:
            try:
                await conn.execute(text(idx_sql))
            except Exception as e:
                logger.debug("Индекс пропущен: %s (%s)", idx_sql, e)


# 4. Методы управления пользователями
async def get_user(user_id: int) -> Optional[Dict[str, Any]]:
    async with async_session_maker() as session:
        stmt = select(User).where(User.user_id == user_id)
        result = await session.execute(stmt)
        user = result.scalar_one_or_none()
        return user.to_dict() if user else None


async def set_user_group(user_id: int, group_id: int, group_name: str) -> None:
    async with async_session_maker() as session:
        async with session.begin():
            stmt = select(User).where(User.user_id == user_id)
            result = await session.execute(stmt)
            user = result.scalar_one_or_none()
            if user:
                user.group_id = group_id
                user.group_name = group_name
                user.updated_at = datetime.utcnow()
            else:
                user = User(
                    user_id=user_id,
                    group_id=group_id,
                    group_name=group_name
                )
                session.add(user)


async def set_user_subgroup(user_id: int, subgroup: int) -> None:
    async with async_session_maker() as session:
        async with session.begin():
            stmt = select(User).where(User.user_id == user_id)
            result = await session.execute(stmt)
            user = result.scalar_one_or_none()
            if user:
                user.subgroup = subgroup
                user.updated_at = datetime.utcnow()


async def set_group_kb_mode(user_id: int, mode: str) -> None:
    async with async_session_maker() as session:
        async with session.begin():
            stmt = select(User).where(User.user_id == user_id)
            result = await session.execute(stmt)
            user = result.scalar_one_or_none()
            if user:
                user.group_kb_mode = mode
                user.updated_at = datetime.utcnow()
            else:
                user = User(
                    user_id=user_id,
                    group_kb_mode=mode
                )
                session.add(user)


async def set_user_has_seen_guide(user_id: int, has_seen: int = 1) -> None:
    async with async_session_maker() as session:
        async with session.begin():
            stmt = select(User).where(User.user_id == user_id)
            result = await session.execute(stmt)
            user = result.scalar_one_or_none()
            if user:
                user.has_seen_guide = has_seen
                user.updated_at = datetime.utcnow()
            else:
                user = User(
                    user_id=user_id,
                    has_seen_guide=has_seen
                )
                session.add(user)




async def update_user_notifications(
    user_id: int,
    notifications_enabled: Optional[int] = None,
    notify_before_mins: Optional[int] = None,
    notify_breaks: Optional[int] = None,
    notify_lesson_start: Optional[int] = None,
    notify_changes: Optional[int] = None
) -> None:
    async with async_session_maker() as session:
        async with session.begin():
            stmt = select(User).where(User.user_id == user_id)
            result = await session.execute(stmt)
            user = result.scalar_one_or_none()
            if user:
                if notifications_enabled is not None:
                    user.notifications_enabled = notifications_enabled
                if notify_before_mins is not None:
                    user.notify_before_mins = notify_before_mins
                if notify_breaks is not None:
                    user.notify_breaks = notify_breaks
                if notify_lesson_start is not None:
                    user.notify_lesson_start = notify_lesson_start
                if notify_changes is not None:
                    user.notify_changes = notify_changes
                user.updated_at = datetime.utcnow()


async def get_active_users_for_notifications() -> List[Dict[str, Any]]:
    async with async_session_maker() as session:
        stmt = select(User).where(
            User.group_id.is_not(None),
            User.notifications_enabled == 1
        )
        result = await session.execute(stmt)
        users = result.scalars().all()
        return [u.to_dict() for u in users]


async def get_users_for_group_changes(group_id: int) -> List[Dict[str, Any]]:
    async with async_session_maker() as session:
        stmt = select(User).where(
            User.group_id == group_id,
            User.notifications_enabled == 1,
            User.notify_changes == 1
        )
        result = await session.execute(stmt)
        users = result.scalars().all()
        return [u.to_dict() for u in users]


async def get_all_active_group_ids() -> List[Dict[str, Any]]:
    async with async_session_maker() as session:
        stmt = select(User.group_id, User.group_name).where(
            User.group_id.is_not(None)
        ).distinct()
        result = await session.execute(stmt)
        rows = result.all()
        return [{"group_id": r[0], "group_name": r[1]} for r in rows if r[0] is not None]


# 5. Кэширование расписания групп
async def get_stored_group_schedule(group_id: int) -> Optional[Dict[str, Any]]:
    async with async_session_maker() as session:
        stmt = select(GroupSchedule).where(GroupSchedule.group_id == group_id)
        result = await session.execute(stmt)
        item = result.scalar_one_or_none()
        if item and item.schedule_json:
            try:
                return json.loads(item.schedule_json)
            except Exception:
                return None
        return None


async def save_group_schedule(group_id: int, schedule_data: Dict[str, Any]) -> None:
    async with async_session_maker() as session:
        async with session.begin():
            stmt = select(GroupSchedule).where(GroupSchedule.group_id == group_id)
            result = await session.execute(stmt)
            item = result.scalar_one_or_none()
            json_str = json.dumps(schedule_data, ensure_ascii=False)
            if item:
                item.schedule_json = json_str
                item.updated_at = datetime.utcnow()
            else:
                item = GroupSchedule(group_id=group_id, schedule_json=json_str)
                session.add(item)


# 6. Статистика
async def get_stats() -> Dict[str, int]:
    async with async_session_maker() as session:
        total_users = (await session.execute(select(func.count(User.user_id)))).scalar() or 0
        telegram_users = (await session.execute(select(func.count(User.user_id)).where(User.user_id > 0))).scalar() or 0
        guest_app_users = (await session.execute(select(func.count(User.user_id)).where(User.user_id < 0))).scalar() or 0
        active_users = (await session.execute(select(func.count(User.user_id)).where(User.group_id.is_not(None)))).scalar() or 0
        notif_users = (await session.execute(select(func.count(User.user_id)).where(User.notifications_enabled == 1))).scalar() or 0
        mobile_users = (await session.execute(select(func.count(User.user_id)).where(User.has_mobile_app == 1))).scalar() or 0

        return {
            "total_users": total_users,
            "telegram_users": telegram_users,
            "guest_app_users": guest_app_users,
            "active_users": active_users,
            "notif_users": notif_users,
            "mobile_users": mobile_users
        }


# 7. Авторизация приложения и токены сессий
async def create_auth_session(session_token: str, expires_in_mins: int = 15) -> bool:
    async with async_session_maker() as session:
        async with session.begin():
            expires_at = datetime.utcnow() + timedelta(minutes=expires_in_mins)
            sess = AppAuthSession(
                session_token=session_token,
                status="pending",
                expires_at=expires_at
            )
            session.add(sess)
            return True


async def confirm_auth_session(
    session_token: str,
    user_id: int,
    first_name: Optional[str] = None,
    last_name: Optional[str] = None,
    username: Optional[str] = None,
    avatar_url: Optional[str] = None,
) -> Optional[str]:
    auth_token = secrets.token_hex(32)
    async with async_session_maker() as session:
        async with session.begin():
            now = datetime.utcnow()
            stmt = select(AppAuthSession).where(
                AppAuthSession.session_token == session_token,
                AppAuthSession.expires_at > now,
                AppAuthSession.status == "pending"
            )
            result = await session.execute(stmt)
            auth_sess = result.scalar_one_or_none()
            if not auth_sess:
                return None

            auth_sess.user_id = user_id
            auth_sess.status = "confirmed"
            auth_sess.auth_token = auth_token

            # Создаем или обновляем связь токена в app_users
            app_user_stmt = select(AppUser).where(AppUser.auth_token == auth_token)
            app_user = (await session.execute(app_user_stmt)).scalar_one_or_none()
            if app_user:
                app_user.user_id = user_id
                app_user.last_active = now
            else:
                session.add(AppUser(auth_token=auth_token, user_id=user_id, last_active=now))

            # Создаем или обновляем профиль в users
            user_stmt = select(User).where(User.user_id == user_id)
            user = (await session.execute(user_stmt)).scalar_one_or_none()
            if user:
                user.has_mobile_app = 1
                if first_name is not None:
                    user.first_name = first_name
                if last_name is not None:
                    user.last_name = last_name
                if username is not None:
                    user.username = username
                if avatar_url is not None:
                    user.avatar_url = avatar_url
                if not user.mobile_app_installed_at:
                    user.mobile_app_installed_at = now
                user.updated_at = now
            else:
                user = User(
                    user_id=user_id,
                    has_mobile_app=1,
                    first_name=first_name,
                    last_name=last_name,
                    username=username,
                    avatar_url=avatar_url,
                    mobile_app_installed_at=now
                )
                session.add(user)

            return auth_token


async def update_user_custom_avatar(user_id: int, avatar_url: str) -> None:
    async with async_session_maker() as session:
        async with session.begin():
            stmt = select(User).where(User.user_id == user_id)
            user = (await session.execute(stmt)).scalar_one_or_none()
            if user:
                user.avatar_url = avatar_url
                user.updated_at = datetime.utcnow()


async def get_auth_session(session_token: str) -> Optional[Dict[str, Any]]:
    async with async_session_maker() as session:
        stmt = select(AppAuthSession).where(AppAuthSession.session_token == session_token)
        sess = (await session.execute(stmt)).scalar_one_or_none()
        if not sess:
            return None

        data = sess.to_dict()
        now = datetime.utcnow()
        is_expired = sess.expires_at is not None and sess.expires_at <= now
        data["is_expired"] = 1 if is_expired else 0
        if is_expired and data["status"] == "pending":
            data["status"] = "expired"
        return data


async def get_user_by_auth_token(auth_token: str) -> Optional[Dict[str, Any]]:
    async with async_session_maker() as session:
        stmt = (
            select(User)
            .join(AppUser, User.user_id == AppUser.user_id)
            .where(AppUser.auth_token == auth_token)
        )
        user = (await session.execute(stmt)).scalar_one_or_none()
        return user.to_dict() if user else None


# 8. Регистрация и привязка устройств мобильного приложения
async def register_or_update_device_user(
    device_id: str,
    client_user_id: Optional[str] = None,
    platform: str = "android",
    group_id: Optional[int] = None,
    group_name: Optional[str] = None,
    subgroup: Optional[int] = 0,
    notifications_enabled: Optional[int] = 1,
    notify_before_mins: Optional[int] = 10,
    notify_breaks: Optional[int] = 1,
    notify_lesson_start: Optional[int] = 1,
    notify_changes: Optional[int] = 1,
    app_version: Optional[str] = None,
    auth_token: Optional[str] = None
) -> Dict[str, Any]:
    async with async_session_maker() as session:
        async with session.begin():
            now = datetime.utcnow()
            target_user_id = None

            # 1. Если передан действующий auth_token, ищем пользователя
            if auth_token:
                app_u_stmt = select(AppUser).where(AppUser.auth_token == auth_token)
                app_u = (await session.execute(app_u_stmt)).scalar_one_or_none()
                if app_u:
                    target_user_id = app_u.user_id

            # 2. Если пользователь найден по auth_token
            if target_user_id is not None:
                # Отвязываем этот device_id и client_user_id от других пользователей
                unbind_cond = (User.device_id == device_id)
                if client_user_id:
                    unbind_cond = unbind_cond | (User.client_user_id == client_user_id)

                await session.execute(
                    update(User)
                    .where(User.user_id != target_user_id, User.user_id > 0, unbind_cond)
                    .values(device_id=None, client_user_id=None, updated_at=now)
                )

                # Удаляем временные гостевые записи (user_id < 0)
                await session.execute(
                    delete(User).where(User.user_id < 0, unbind_cond)
                )

                # Удаляем временные dev токены
                tokens_to_del = [f"dev_{device_id}"]
                if client_user_id:
                    tokens_to_del.append(f"dev_{client_user_id}")
                await session.execute(
                    delete(AppUser).where(AppUser.auth_token.in_(tokens_to_del))
                )

                # Обновляем целевого пользователя
                t_user = (await session.execute(select(User).where(User.user_id == target_user_id))).scalar_one_or_none()
                if t_user:
                    t_user.device_id = device_id
                    t_user.client_user_id = client_user_id
                    t_user.platform = platform
                    t_user.has_mobile_app = 1
                    t_user.last_active = now
                    t_user.updated_at = now

                    if group_id is not None:
                        t_user.group_id = group_id
                    if group_name is not None:
                        t_user.group_name = group_name
                    if subgroup is not None:
                        t_user.subgroup = subgroup
                    if notifications_enabled is not None:
                        t_user.notifications_enabled = notifications_enabled
                    if notify_before_mins is not None:
                        t_user.notify_before_mins = notify_before_mins
                    if notify_breaks is not None:
                        t_user.notify_breaks = notify_breaks
                    if notify_lesson_start is not None:
                        t_user.notify_lesson_start = notify_lesson_start
                    if notify_changes is not None:
                        t_user.notify_changes = notify_changes
                    if app_version is not None:
                        t_user.app_version = app_version

                    return t_user.to_dict()

            # 3. Пользователь без Telegram-авторизации (гость)
            existing_guest = None
            if client_user_id:
                stmt = select(User).where(User.user_id < 0, User.client_user_id == client_user_id).order_by(User.user_id.desc())
                existing_guest = (await session.execute(stmt)).scalars().first()

            if not existing_guest and device_id:
                stmt = select(User).where(User.user_id < 0, User.device_id == device_id).order_by(User.user_id.desc())
                existing_guest = (await session.execute(stmt)).scalars().first()

            if existing_guest:
                guest_uid = existing_guest.user_id
                effective_client_id = client_user_id or existing_guest.client_user_id

                existing_guest.device_id = device_id
                existing_guest.client_user_id = effective_client_id
                existing_guest.platform = platform
                existing_guest.has_mobile_app = 1
                existing_guest.last_active = now
                existing_guest.updated_at = now

                if group_id is not None:
                    existing_guest.group_id = group_id
                if group_name is not None:
                    existing_guest.group_name = group_name
                if subgroup is not None:
                    existing_guest.subgroup = subgroup
                if notifications_enabled is not None:
                    existing_guest.notifications_enabled = notifications_enabled
                if notify_before_mins is not None:
                    existing_guest.notify_before_mins = notify_before_mins
                if notify_breaks is not None:
                    existing_guest.notify_breaks = notify_breaks
                if notify_lesson_start is not None:
                    existing_guest.notify_lesson_start = notify_lesson_start
                if notify_changes is not None:
                    existing_guest.notify_changes = notify_changes
                if app_version is not None:
                    existing_guest.app_version = app_version

                # Удаляем старые дублирующие гостевые записи
                del_cond = (User.device_id == device_id)
                if effective_client_id:
                    del_cond = del_cond | (User.client_user_id == effective_client_id)
                await session.execute(
                    delete(User).where(User.user_id < 0, User.user_id != guest_uid, del_cond)
                )

                synthetic_token = f"dev_{effective_client_id or device_id}"
                dev_app_u = (await session.execute(select(AppUser).where(AppUser.auth_token == synthetic_token))).scalar_one_or_none()
                if dev_app_u:
                    dev_app_u.user_id = guest_uid
                    dev_app_u.last_active = now
                else:
                    session.add(AppUser(auth_token=synthetic_token, user_id=guest_uid, last_active=now))

                return existing_guest.to_dict()

            # 4. Новый гость устройства: вычисляем уникальный отрицательный ID
            min_val = (await session.execute(select(func.min(User.user_id)).where(User.user_id < 0))).scalar()
            new_user_id = min((min_val or 0) - 1, -1)

            guest_name = f"Пользователь ({platform.capitalize()})"
            new_guest = User(
                user_id=new_user_id,
                client_user_id=client_user_id,
                device_id=device_id,
                platform=platform,
                group_id=group_id,
                group_name=group_name,
                subgroup=subgroup or 0,
                notifications_enabled=notifications_enabled if notifications_enabled is not None else 1,
                notify_before_mins=notify_before_mins if notify_before_mins is not None else 10,
                notify_breaks=notify_breaks if notify_breaks is not None else 1,
                notify_lesson_start=notify_lesson_start if notify_lesson_start is not None else 1,
                notify_changes=notify_changes if notify_changes is not None else 1,
                app_version=app_version or "",
                has_mobile_app=1,
                first_name=guest_name,
                mobile_app_installed_at=now,
                created_at=now,
                updated_at=now,
                last_active=now
            )
            session.add(new_guest)

            synthetic_token = f"dev_{client_user_id or device_id}"
            session.add(AppUser(auth_token=synthetic_token, user_id=new_user_id, last_active=now))

            await session.flush()
            return new_guest.to_dict()


async def unlink_device_user(
    device_id: Optional[str] = None,
    client_user_id: Optional[str] = None,
    auth_token: Optional[str] = None
) -> bool:
    async with async_session_maker() as session:
        async with session.begin():
            user_ids = set()

            if auth_token:
                app_u = (await session.execute(select(AppUser).where(AppUser.auth_token == auth_token))).scalar_one_or_none()
                if app_u:
                    user_ids.add(app_u.user_id)
                await session.execute(delete(AppUser).where(AppUser.auth_token == auth_token))

            if device_id:
                u_res = await session.execute(select(User.user_id).where(User.device_id == device_id, User.user_id > 0))
                for r in u_res.scalars().all():
                    user_ids.add(r)

            if client_user_id:
                u_res = await session.execute(select(User.user_id).where(User.client_user_id == client_user_id, User.user_id > 0))
                for r in u_res.scalars().all():
                    user_ids.add(r)

            if user_ids:
                await session.execute(
                    update(User)
                    .where(User.user_id.in_(list(user_ids)))
                    .values(device_id=None, client_user_id=None, updated_at=datetime.utcnow())
                )

            return True


# 9. Авторизация Яндекс ID
async def register_or_login_yandex_user(
    yandex_id: str,
    first_name: Optional[str] = None,
    last_name: Optional[str] = None,
    display_name: Optional[str] = None,
    email: Optional[str] = None,
    avatar_url: Optional[str] = None,
    group_id: Optional[int] = None,
    group_name: Optional[str] = None,
    subgroup: Optional[int] = None,
) -> Dict[str, Any]:
    async with async_session_maker() as session:
        async with session.begin():
            now = datetime.utcnow()
            stmt = select(User).where(User.yandex_id == yandex_id)
            user = (await session.execute(stmt)).scalar_one_or_none()

            effective_name = first_name or display_name or "Пользователь Яндекс"
            effective_login = email or display_name or ""

            if user:
                uid = user.user_id
                user.first_name = effective_name or user.first_name
                user.last_name = last_name or user.last_name
                user.username = effective_login or user.username
                user.avatar_url = avatar_url or user.avatar_url
                user.updated_at = now
                user.last_active = now
            else:
                base_uid = (abs(hash(f"yandex_{yandex_id}")) % 1000000000) + 7000000000
                uid = base_uid
                user = User(
                    user_id=uid,
                    yandex_id=yandex_id,
                    first_name=effective_name,
                    last_name=last_name,
                    username=effective_login,
                    avatar_url=avatar_url,
                    group_id=group_id,
                    group_name=group_name,
                    subgroup=subgroup or 0,
                    has_mobile_app=1,
                    created_at=now,
                    updated_at=now,
                    last_active=now
                )
                session.add(user)

            token = f"ya_{secrets.token_hex(24)}"
            app_u = (await session.execute(select(AppUser).where(AppUser.auth_token == token))).scalar_one_or_none()
            if app_u:
                app_u.user_id = uid
                app_u.last_active = now
            else:
                session.add(AppUser(auth_token=token, user_id=uid, last_active=now))

            await session.flush()
            res = user.to_dict()
            res["auth_token"] = token
            return res
