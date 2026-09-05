# Встроенный легковесный HTTP-сервер на aiohttp.web для обслуживания Telegram Mini App
import os
import logging
import json
from pathlib import Path
from aiohttp import web
from services.api import api_client
from database import get_user, set_user_group, set_user_subgroup

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
        "first_name": user.get("first_name"),
        "last_name": user.get("last_name"),
        "username": user.get("username"),
        "avatar_url": user.get("avatar_url"),
        "has_mobile_app": user.get("has_mobile_app", 1)
    })

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
