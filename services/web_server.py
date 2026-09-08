# Встроенный легковесный HTTP-сервер на aiohttp.web для обслуживания Telegram Mini App
import os
import logging
import json
import time
import re
import html
import xml.etree.ElementTree as ET
from pathlib import Path
import aiohttp
from aiohttp import web
from services.api import api_client
from database import get_user, set_user_group, set_user_subgroup, update_user_notifications

logger = logging.getLogger("rii_schedule_bot.web")

WEBAPP_DIR = Path(__file__).resolve().parent.parent / "webapp"

async def handle_index(request: web.Request) -> web.FileResponse:
    index_file = WEBAPP_DIR / "index.html"
    return web.FileResponse(index_file)

async def handle_api_groups(request: web.Request) -> web.Response:
    try:
        groups = await api_client.get_groups()
        return web.json_response(groups)
    except Exception as e:
        logger.error("Ошибка API groups: %s", e)
        return web.json_response({"error": "Failed to fetch groups"}, status=500)

async def handle_api_schedule(request: web.Request) -> web.Response:
    group_id_str = request.query.get("group_id")
    if not group_id_str:
        return web.json_response({"error": "Missing group_id"}, status=400)
    try:
        group_id = int(group_id_str)
        sched = await api_client.get_schedule(group_id)
        return web.json_response(sched)
    except Exception as e:
        logger.error("Ошибка API schedule для группы %s: %s", group_id_str, e)
        return web.json_response({"error": "Failed to fetch schedule"}, status=500)

async def handle_api_get_user(request: web.Request) -> web.Response:
    user_id_str = request.query.get("user_id")
    if not user_id_str:
        return web.json_response({"error": "Missing user_id"}, status=400)
    try:
        user_id = int(user_id_str)
        user = await get_user(user_id)
        if user:
            return web.json_response({
                "user_id": user["user_id"],
                "group_id": user.get("group_id"),
                "group_name": user.get("group_name"),
                "subgroup": user.get("subgroup", 0)
            })
        return web.json_response({"user_id": user_id, "group_id": None, "group_name": None, "subgroup": 0})
    except Exception as e:
        logger.error("Ошибка API get_user для user_id %s: %s", user_id_str, e)
        return web.json_response({"error": "Failed to get user"}, status=500)

async def handle_api_sync_user(request: web.Request) -> web.Response:
    try:
        data = await request.json()
        user_id = data.get("user_id")
        group_id = data.get("group_id")
        group_name = data.get("group_name")
        subgroup = data.get("subgroup")

        if user_id and group_id and group_name:
            await set_user_group(int(user_id), int(group_id), str(group_name))
        if user_id and subgroup is not None:
            await set_user_subgroup(int(user_id), int(subgroup))

        return web.json_response({"status": "ok"})
    except Exception as e:
        logger.error("Ошибка API sync_user: %s", e)
        return web.json_response({"error": "Failed to sync user settings"}, status=500)

async def handle_api_app_auth_session(request: web.Request) -> web.Response:
    import secrets
    session_token = secrets.token_urlsafe(16)
    from database import create_auth_session
    await create_auth_session(session_token)
    return web.json_response({
        "status": "ok",
        "session_token": session_token,
        "bot_username": "rubinst_bot",
        "auth_url": f"https://t.me/rubinst_bot?start=auth_{session_token}",
        "deep_link": f"tg://resolve?domain=rubinst_bot&start=auth_{session_token}"
    })

async def handle_api_app_auth_check(request: web.Request) -> web.Response:
    session_token = request.query.get("session_token")
    if not session_token:
        return web.json_response({"error": "Missing session_token"}, status=400)
    
    from database import get_auth_session
    session = await get_auth_session(session_token)
    if not session:
        return web.json_response({"status": "not_found"}, status=404)
    
    if session["status"] == "confirmed" and session.get("user_id"):
        user = await get_user(session["user_id"])
        return web.json_response({
            "status": "confirmed",
            "auth_token": session.get("auth_token"),
            "user": {
                "user_id": user["user_id"] if user else session["user_id"],
                "group_id": user.get("group_id") if user else None,
                "group_name": user.get("group_name") if user else None,
                "subgroup": user.get("subgroup", 0) if user else 0,
                "notifications_enabled": user.get("notifications_enabled", 1) if user else 1,
                "first_name": user.get("first_name") if user else None,
                "last_name": user.get("last_name") if user else None,
                "username": user.get("username") if user else None,
                "avatar_url": user.get("avatar_url") if user else None,
                "has_mobile_app": 1
            }
        })
    
    return web.json_response({"status": session["status"]})

async def handle_api_app_profile(request: web.Request) -> web.Response:
    auth_token = request.headers.get("Authorization", "").replace("Bearer ", "").strip()
    if not auth_token:
        auth_token = request.query.get("auth_token", "").strip()
        
    if not auth_token:
        return web.json_response({"error": "Unauthorized"}, status=401)
        
    from database import get_user_by_auth_token, update_user_custom_avatar
    user = await get_user_by_auth_token(auth_token)
    if not user:
        return web.json_response({"error": "Invalid auth token"}, status=401)
        
    if request.method == "POST":
        try:
            data = await request.json()
            gid = data.get("group_id")
            gname = data.get("group_name")
            sg = data.get("subgroup")
            avatar_url = data.get("avatar_url")
            avatar_base64 = data.get("avatar_base64")
            notifications_enabled = data.get("notifications_enabled")
            notify_before_mins = data.get("notify_before_mins")
            notify_lesson_start = data.get("notify_lesson_start")
            notify_breaks = data.get("notify_breaks")
            notify_changes = data.get("notify_changes")

            if gid and gname:
                await set_user_group(user["user_id"], int(gid), str(gname))
            if sg is not None:
                await set_user_subgroup(user["user_id"], int(sg))
            if avatar_url:
                await update_user_custom_avatar(user["user_id"], avatar_url)
            elif avatar_base64:
                import base64
                os.makedirs("webapp/avatars", exist_ok=True)
                file_name = f"{user['user_id']}_custom.png"
                file_path = os.path.join("webapp", "avatars", file_name)
                img_data = base64.b64decode(avatar_base64.split(",")[-1])
                with open(file_path, "wb") as f:
                    f.write(img_data)
                await update_user_custom_avatar(user["user_id"], f"/avatars/{file_name}")

            if any(x is not None for x in (notifications_enabled, notify_before_mins, notify_lesson_start, notify_breaks, notify_changes)):
                await update_user_notifications(
                    user_id=user["user_id"],
                    notifications_enabled=int(notifications_enabled) if notifications_enabled is not None else None,
                    notify_before_mins=int(notify_before_mins) if notify_before_mins is not None else None,
                    notify_lesson_start=int(notify_lesson_start) if notify_lesson_start is not None else None,
                    notify_breaks=int(notify_breaks) if notify_breaks is not None else None,
                    notify_changes=int(notify_changes) if notify_changes is not None else None,
                )

            user = await get_user(user["user_id"])
        except Exception as e:
            logger.error("Ошибка обновления профиля мобильного приложения: %s", e)
            return web.json_response({"error": "Failed to update profile"}, status=500)

    return web.json_response({
        "user_id": user["user_id"],
        "group_id": user.get("group_id"),
        "group_name": user.get("group_name"),
        "subgroup": user.get("subgroup", 0),
        "notifications_enabled": user.get("notifications_enabled", 1),
        "notify_before_mins": user.get("notify_before_mins", 10),
        "notify_lesson_start": user.get("notify_lesson_start", 1),
        "notify_breaks": user.get("notify_breaks", 1),
        "notify_changes": user.get("notify_changes", 1),
        "first_name": user.get("first_name"),
        "last_name": user.get("last_name"),
        "username": user.get("username"),
        "avatar_url": user.get("avatar_url"),
        "has_mobile_app": user.get("has_mobile_app", 1)
    })

async def handle_api_app_device_sync(request: web.Request) -> web.Response:
    try:
        data = await request.json()
        device_id = data.get("device_id")
        if not device_id:
            return web.json_response({"error": "Missing device_id"}, status=400)

        platform = data.get("platform", "android")
        group_id = data.get("group_id")
        group_name = data.get("group_name")
        subgroup = data.get("subgroup")
        notifications_enabled = data.get("notifications_enabled")
        notify_before_mins = data.get("notify_before_mins")
        notify_breaks = data.get("notify_breaks")
        notify_lesson_start = data.get("notify_lesson_start")
        notify_changes = data.get("notify_changes")
        app_version = data.get("app_version")
        auth_token = data.get("auth_token")

        from database import register_or_update_device_user
        user = await register_or_update_device_user(
            device_id=str(device_id),
            platform=str(platform),
            group_id=int(group_id) if group_id is not None else None,
            group_name=str(group_name) if group_name is not None else None,
            subgroup=int(subgroup) if subgroup is not None else 0,
            notifications_enabled=int(notifications_enabled) if notifications_enabled is not None else 1,
            notify_before_mins=int(notify_before_mins) if notify_before_mins is not None else 10,
            notify_breaks=int(notify_breaks) if notify_breaks is not None else 1,
            notify_lesson_start=int(notify_lesson_start) if notify_lesson_start is not None else 1,
            notify_changes=int(notify_changes) if notify_changes is not None else 1,
            app_version=str(app_version) if app_version is not None else None,
            auth_token=str(auth_token) if auth_token else None
        )

        return web.json_response({"status": "ok", "user": user})
    except Exception as e:
        logger.error("Ошибка API device sync: %s", e)
        return web.json_response({"error": "Failed to sync device user"}, status=500)

_changelog_cache = {
    "timestamp": 0.0,
    "data": []
}

async def get_app_changelog_data() -> list:
    now = time.time()
    if now - _changelog_cache["timestamp"] < 300 and _changelog_cache["data"]:
        return _changelog_cache["data"]

    # 1. Запрос через публичный Atom-фид релизов GitHub (без ограничений rate-limit)
    try:
        headers = {"User-Agent": "RiiScheduleServer/1.0"}
        async with aiohttp.ClientSession() as session:
            async with session.get(
                "https://github.com/yearningss/rii-schedule-bot/releases.atom",
                headers=headers,
                timeout=aiohttp.ClientTimeout(total=5)
            ) as resp:
                if resp.status == 200:
                    text = await resp.text()
                    root = ET.fromstring(text)
                    ns = {"atom": "http://www.w3.org/2005/Atom"}
                    parsed_releases = []
                    for entry in root.findall("atom:entry", ns):
                        title = (entry.find("atom:title", ns).text or "").strip()
                        updated = (entry.find("atom:updated", ns).text or "").strip()
                        raw_html = entry.find("atom:content", ns).text or ""

                        tag_match = re.search(r'v?(\d+\.\d+\.\d+)', title)
                        tag = tag_match.group(1) if tag_match else "1.0.0"
                        build_match = re.search(r'(?:сборка|\+)\s*(\d+)', title, re.IGNORECASE)
                        build_num = int(build_match.group(1)) if build_match else 1

                        body_text = raw_html.replace("</li>", "\n").replace("</p>", "\n\n").replace("<br>", "\n").replace("<br/>", "\n")
                        body_text = re.sub(r'<li>\s*', '* ', body_text)
                        body_text = re.sub(r'<[^>]+>', '', body_text)
                        body_text = html.unescape(body_text).strip()

                        parsed_releases.append({
                            "tag_name": tag,
                            "name": title,
                            "build": build_num,
                            "published_at": updated,
                            "body": body_text,
                            "html_url": f"https://github.com/yearningss/rii-schedule-bot/releases/tag/v{tag}",
                            "assets": [
                                {
                                    "name": "RiiSchedule.apk",
                                    "size": 55597479,
                                    "download_url": f"https://github.com/yearningss/rii-schedule-bot/releases/download/v{tag}/RiiSchedule.apk"
                                },
                                {
                                    "name": "RiiSchedule-debug.apk",
                                    "size": 153946152,
                                    "download_url": f"https://github.com/yearningss/rii-schedule-bot/releases/download/v{tag}/RiiSchedule-debug.apk"
                                },
                                {
                                    "name": "RiiSchedule.ipa",
                                    "size": 8196388,
                                    "download_url": f"https://github.com/yearningss/rii-schedule-bot/releases/download/v{tag}/RiiSchedule.ipa"
                                }
                            ]
                        })
                    if parsed_releases:
                        _changelog_cache["data"] = parsed_releases
                        _changelog_cache["timestamp"] = now
                        return _changelog_cache["data"]
    except Exception as e:
        logger.warning("Не удалось получить releases.atom: %s", e)

    return _changelog_cache["data"]

async def get_latest_app_version_data(platform: str = "android") -> dict:
    changelog = await get_app_changelog_data()
    is_ios = (platform.lower() == "ios")
    target_ext = "RiiSchedule.ipa" if is_ios else "RiiSchedule.apk"
    if changelog:
        latest = changelog[0]
        download_url = f"https://github.com/yearningss/rii-schedule-bot/releases/download/v{latest['tag_name']}/{target_ext}"
        for asset in latest.get("assets", []):
            if asset.get("name") == target_ext:
                download_url = asset.get("download_url", download_url)
                break
        return {
            "status": "ok",
            "latest_version": latest["tag_name"],
            "latest_build": latest.get("build", 13),
            "download_url": download_url,
            "release_notes": latest.get("body") or "Исправления ошибок и улучшения стабильности.",
            "is_required": False
        }

    return {
        "status": "ok",
        "latest_version": "1.0.16",
        "latest_build": 17,
        "download_url": f"https://github.com/yearningss/rii-schedule-bot/releases/download/v1.0.16/{target_ext}",
        "release_notes": "Обновление виджета, уведомлений и базы данных (v1.0.16, сборка 17):\n- Виджет рабочего стола обновляет время в реальном времени каждую минуту (iOS WidgetKit поминутный таймлайн и точный AlarmManager в Android)\n- Устранена задержка отправки уведомлений: системное планирование через точные будильники ОС\n- Динамический расчет оставшихся минут в тексте уведомлений\n- Расширен выбор времени напоминания до начала пары (5, 10, 15, 20, 30, 45, 60 минут)\n- Автоматический учет и синхронизация пользователей мобильного приложения в базе данных SQLite без обязательной авторизации в Telegram",
        "is_required": False
    }

async def handle_api_app_version(request: web.Request) -> web.Response:
    # Проверка актуальной версии мобильного приложения РИИ
    platform = request.query.get("platform", "android")
    data = await get_latest_app_version_data(platform)
    return web.json_response(data)

async def handle_api_app_changelog(request: web.Request) -> web.Response:
    # Возвращает список всех релизов и изменений напрямую из GitHub Releases
    data = await get_app_changelog_data()
    return web.json_response(data)

def create_web_app() -> web.Application:
    app = web.Application()
    app.router.add_get("/", handle_index)
    app.router.add_get("/api/groups", handle_api_groups)
    app.router.add_get("/api/schedule", handle_api_schedule)
    app.router.add_get("/api/user", handle_api_get_user)
    app.router.add_post("/api/user/sync", handle_api_sync_user)
    app.router.add_post("/api/app/auth/session", handle_api_app_auth_session)
    app.router.add_get("/api/app/auth/check", handle_api_app_auth_check)
    app.router.add_get("/api/app/profile", handle_api_app_profile)
    app.router.add_post("/api/app/profile", handle_api_app_profile)
    app.router.add_post("/api/app/device/sync", handle_api_app_device_sync)
    app.router.add_get("/api/app/version", handle_api_app_version)
    app.router.add_get("/api/app/changelog", handle_api_app_changelog)
    app.router.add_static("/", WEBAPP_DIR)
    return app

async def start_web_server(host: str, port: int) -> web.AppRunner:
    app = create_web_app()
    runner = web.AppRunner(app)
    await runner.setup()
    site = web.TCPSite(runner, host, port)
    await site.start()
    logger.info("Web App сервер запущен на http://%s:%d", host, port)
    return runner
