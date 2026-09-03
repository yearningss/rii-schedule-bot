# Встроенный легковесный HTTP-сервер на aiohttp.web для обслуживания Telegram Mini App
import os
import logging
from pathlib import Path
from aiohttp import web
from services.api import api_client

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

def create_web_app() -> web.Application:
    app = web.Application()
    app.router.add_get("/", handle_index)
    app.router.add_get("/api/groups", handle_api_groups)
    app.router.add_get("/api/schedule", handle_api_schedule)
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
