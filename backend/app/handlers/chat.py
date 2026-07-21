import json
import re
import uuid

import tornado.web
import tornado.websocket

from app.config import get_settings
from app.handlers.auth import SESSION_COOKIE_NAME
from app.handlers.base import BaseHandler
from app.services.chat import (
    append_chat_comment,
    build_deepseek_messages,
    create_chat_prompt,
    ensure_chat,
    get_chat_owner,
    list_chat_prompts,
    load_chat_activity,
    load_chat_comments,
    now_iso,
    select_chat_prompt,
    set_chat_prompt_showoff,
)
from app.services.deepseek import DeepSeekError, DeepSeekService
from app.services.knowledge import build_knowledge_system_message, search_knowledge
from app.services.security import raise_for_abuse
from app.services.trend_report import refresh_trend_report_for_chat


HEX32_RE = re.compile(r"^[0-9a-fA-F]{32}$")


def uuid4_hex():
    return uuid.uuid4().hex


class ChatBaseHandler(BaseHandler):
    def _param(self, name, default=""):
        value = self.json_body.get(name)
        if value is None:
            value = self.get_argument(name, default)
        return value

    def current_user_entity_id(self):
        block_id = str(self._param("user_id", "") or self._param("entity_id", "") or "").strip().lower()
        if block_id:
            if not get_settings().debug:
                raise tornado.web.HTTPError(401, reason="login required")
            if not HEX32_RE.fullmatch(block_id):
                raise tornado.web.HTTPError(400, reason="user_id must be a 32-character hex string")
            return block_id

        raw_session = self.get_signed_cookie(SESSION_COOKIE_NAME)
        if not raw_session:
            raise tornado.web.HTTPError(401, reason="login required")
        try:
            session = json.loads(raw_session.decode("utf-8") if isinstance(raw_session, bytes) else raw_session)
        except json.JSONDecodeError as exc:
            raise tornado.web.HTTPError(401, reason="invalid login session") from exc
        block_id = str(session.get("block_id", "")).strip().lower()
        if not HEX32_RE.fullmatch(block_id):
            raise tornado.web.HTTPError(401, reason="invalid login session")
        return block_id

    @property
    def deepseek_service(self):
        service = self.application.settings.get("deepseek_service")
        if service is None:
            service = DeepSeekService(get_settings())
            self.application.settings["deepseek_service"] = service
        return service

    async def require_chat_owner(self, cur, chat_id, user_entity_id):
        owner = await get_chat_owner(cur, chat_id)
        if owner is None:
            raise tornado.web.HTTPError(404, reason="chat_id not found")
        if owner != user_entity_id:
            raise tornado.web.HTTPError(403, reason="chat does not belong to current user")


class ChatEnsureHandler(ChatBaseHandler):
    async def get(self):
        await self._handle()

    async def post(self):
        await self._handle()

    async def _handle(self):
        user_entity_id = self.current_user_entity_id()
        async with self.mysql.acquire() as conn:
            async with conn.cursor() as cur:
                await cur.execute("START TRANSACTION")
                try:
                    chat = await ensure_chat(cur, user_entity_id)
                    await cur.execute("COMMIT")
                except Exception:
                    await cur.execute("ROLLBACK")
                    raise
        self.write_json(chat, status=201 if chat["created"] else 200)


class ChatLoadHandler(ChatBaseHandler):
    async def get(self):
        user_entity_id = self.current_user_entity_id()
        chat_id = str(self.get_argument("chat_id", "")).strip().lower()
        last_comment_id = str(self.get_argument("last_comment_id", "")).strip().lower() or None
        if not HEX32_RE.fullmatch(chat_id):
            raise tornado.web.HTTPError(400, reason="chat_id must be a 32-character hex string")
        if last_comment_id and not HEX32_RE.fullmatch(last_comment_id):
            raise tornado.web.HTTPError(400, reason="last_comment_id must be a 32-character hex string")

        async with self.mysql.acquire() as conn:
            async with conn.cursor() as cur:
                await self.require_chat_owner(cur, chat_id, user_entity_id)
                data = await load_chat_comments(cur, chat_id, last_comment_id)
        self.write_json({"data": data if data else "none"})


class ChatActivityHandler(ChatBaseHandler):
    async def get(self):
        user_entity_id = self.current_user_entity_id()
        try:
            year = int(self.get_argument("year", ""))
            month = int(self.get_argument("month", ""))
            tz_offset_minutes = int(self.get_argument("tz_offset_minutes", "0"))
        except ValueError as exc:
            raise tornado.web.HTTPError(400, reason="year, month and tz_offset_minutes must be integers") from exc

        if year < 2000 or year > 2100:
            raise tornado.web.HTTPError(400, reason="year is out of range")
        if month < 1 or month > 12:
            raise tornado.web.HTTPError(400, reason="month must be 1-12")

        async with self.mysql.acquire() as conn:
            async with conn.cursor() as cur:
                data = await load_chat_activity(cur, user_entity_id, year, month, tz_offset_minutes)
        self.write_json({"data": data})


class ChatSubmitHandler(ChatBaseHandler):
    async def post(self):
        chat_id = str(self._param("chat_id", "")).strip().lower()
        comment_id = str(self._param("uuid", "")).strip().lower()
        content = str(self._param("content", "")).strip()
        ws_block_ids = self._param("ws_block_ids", [])
        ask_ai = self._param("ask_ai", True)

        if not HEX32_RE.fullmatch(chat_id):
            raise tornado.web.HTTPError(400, reason="chat_id must be a 32-character hex string")
        if not HEX32_RE.fullmatch(comment_id):
            raise tornado.web.HTTPError(400, reason="uuid must be a 32-character hex string")
        if not content:
            raise tornado.web.HTTPError(400, reason="content is required")
        if not isinstance(ws_block_ids, list):
            raise tornado.web.HTTPError(400, reason="ws_block_ids must be a list")
        if isinstance(ask_ai, str):
            ask_ai = ask_ai.lower() not in ("0", "false", "no")
        else:
            ask_ai = bool(ask_ai)
        try:
            tz_offset_minutes = int(self._param("tz_offset_minutes", 480))
        except (TypeError, ValueError) as exc:
            raise tornado.web.HTTPError(400, reason="tz_offset_minutes must be an integer") from exc

        user_entity_id = self.current_user_entity_id()
        decision = self.security_guard.check_chat_submit(
            user_id=user_entity_id,
            ip=self.client_ip,
            content=content,
            ask_ai=ask_ai,
        )
        if not decision.allowed:
            await self.record_abuse(decision, user_id=user_entity_id)
            raise_for_abuse(decision)

        comment = {
            "comment_id": comment_id,
            "role": "user",
            "content": content,
            "ws_block_ids": ws_block_ids,
            "createtime": now_iso(),
        }

        trend_report = None
        async with self.mysql.acquire() as conn:
            async with conn.cursor() as cur:
                await cur.execute("START TRANSACTION")
                try:
                    await self.require_chat_owner(cur, chat_id, user_entity_id)
                    result = await append_chat_comment(cur, chat_id, comment)
                    trend_report = await refresh_trend_report_for_chat(
                        cur,
                        chat_id,
                        tz_offset_minutes,
                        deepseek_service=self.deepseek_service if ask_ai else None,
                    )
                    await cur.execute("COMMIT")
                except ValueError as exc:
                    await cur.execute("ROLLBACK")
                    raise tornado.web.HTTPError(404, reason=str(exc)) from exc
                except Exception:
                    await cur.execute("ROLLBACK")
                    raise

        event = {"type": "chat.submit", **result}
        targets = [str(item).strip() for item in ws_block_ids if str(item).strip()]
        if not targets:
            targets = [chat_id]
        ChatWebSocketHandler.broadcast(targets, event)

        assistant_result = None
        deepseek = None
        if ask_ai:
            async with self.mysql.acquire() as conn:
                async with conn.cursor() as cur:
                    try:
                        await self.require_chat_owner(cur, chat_id, user_entity_id)
                        context = await build_deepseek_messages(cur, chat_id, get_settings().deepseek_max_history)
                        knowledge_refs = await search_knowledge(cur, content, 5)
                    except ValueError as exc:
                        raise tornado.web.HTTPError(404, reason=str(exc)) from exc

            knowledge_message = build_knowledge_system_message(knowledge_refs)
            if knowledge_message:
                context["messages"].insert(1, {"role": "system", "content": knowledge_message})

            try:
                deepseek = await self.deepseek_service.complete(context["messages"])
            except DeepSeekError as exc:
                self.write_json(
                    {
                        "success": True,
                        "ai_success": False,
                        "ai_error": str(exc),
                        "trend_report": trend_report,
                        **result,
                    }
                )
                return

            assistant_comment = {
                "comment_id": uuid4_hex(),
                "role": "assistant",
                "content": deepseek["content"],
                "ws_block_ids": ws_block_ids,
                "createtime": now_iso(),
                "model": deepseek["model"],
                "usage": deepseek["usage"],
                "history_count": context["history_count"],
                "omitted_count": context["omitted_count"],
                "system_prompt": context["active_prompt"],
                "knowledge_refs": knowledge_refs,
            }
            async with self.mysql.acquire() as conn:
                async with conn.cursor() as cur:
                    await cur.execute("START TRANSACTION")
                    try:
                        assistant_result = await append_chat_comment(cur, chat_id, assistant_comment)
                        trend_report = await refresh_trend_report_for_chat(
                            cur,
                            chat_id,
                            tz_offset_minutes,
                            deepseek_service=self.deepseek_service,
                        )
                        await cur.execute("COMMIT")
                    except Exception:
                        await cur.execute("ROLLBACK")
                        raise
            ChatWebSocketHandler.broadcast(targets, {"type": "chat.submit", **assistant_result})

        self.write_json(
            {
                "success": True,
                "ai_success": assistant_result is not None,
                "assistant": assistant_result,
                "deepseek": deepseek,
                "trend_report": trend_report,
                **result,
            }
        )


class ChatPromptListHandler(ChatBaseHandler):
    async def get(self):
        user_entity_id = self.current_user_entity_id()
        chat_id = str(self.get_argument("chat_id", "")).strip().lower()
        if not HEX32_RE.fullmatch(chat_id):
            raise tornado.web.HTTPError(400, reason="chat_id must be a 32-character hex string")

        async with self.mysql.acquire() as conn:
            async with conn.cursor() as cur:
                await self.require_chat_owner(cur, chat_id, user_entity_id)
                data = await list_chat_prompts(cur, chat_id)
        self.write_json({"data": data if data else "none"})


class ChatPromptCreateHandler(ChatBaseHandler):
    async def post(self):
        chat_id = str(self._param("chat_id", "")).strip().lower()
        title = str(self._param("title", "")).strip()
        desc = str(self._param("desc", "")).strip()
        system_prompt = str(self._param("system_prompt", "")).strip()
        activate = self._param("activate", True)
        showoff = self._param("showoff", True)

        if not HEX32_RE.fullmatch(chat_id):
            raise tornado.web.HTTPError(400, reason="chat_id must be a 32-character hex string")
        if not title:
            raise tornado.web.HTTPError(400, reason="title is required")
        if not system_prompt:
            raise tornado.web.HTTPError(400, reason="system_prompt is required")
        if isinstance(activate, str):
            activate = activate.lower() not in ("0", "false", "no")
        else:
            activate = bool(activate)
        if isinstance(showoff, str):
            showoff = showoff.lower() not in ("0", "false", "no")
        else:
            showoff = bool(showoff)
        user_entity_id = self.current_user_entity_id()

        async with self.mysql.acquire() as conn:
            async with conn.cursor() as cur:
                await cur.execute("START TRANSACTION")
                try:
                    await self.require_chat_owner(cur, chat_id, user_entity_id)
                    prompt = await create_chat_prompt(
                        cur,
                        chat_id,
                        title,
                        desc,
                        system_prompt,
                        activate=activate,
                        showoff=showoff,
                    )
                    prompts = await list_chat_prompts(cur, chat_id)
                    await cur.execute("COMMIT")
                except ValueError as exc:
                    await cur.execute("ROLLBACK")
                    raise tornado.web.HTTPError(404, reason=str(exc)) from exc
                except Exception:
                    await cur.execute("ROLLBACK")
                    raise
        self.write_json({"success": True, "prompt": prompt, "data": prompts}, status=201)


class ChatPromptSelectHandler(ChatBaseHandler):
    async def post(self):
        user_entity_id = self.current_user_entity_id()
        chat_id = str(self._param("chat_id", "")).strip().lower()
        prompt_id = str(self._param("prompt_id", "")).strip().lower()
        if not HEX32_RE.fullmatch(chat_id):
            raise tornado.web.HTTPError(400, reason="chat_id must be a 32-character hex string")
        if not HEX32_RE.fullmatch(prompt_id):
            raise tornado.web.HTTPError(400, reason="prompt_id must be a 32-character hex string")

        async with self.mysql.acquire() as conn:
            async with conn.cursor() as cur:
                await cur.execute("START TRANSACTION")
                try:
                    await self.require_chat_owner(cur, chat_id, user_entity_id)
                    prompt = await select_chat_prompt(cur, chat_id, prompt_id)
                    prompts = await list_chat_prompts(cur, chat_id)
                    await cur.execute("COMMIT")
                except ValueError as exc:
                    await cur.execute("ROLLBACK")
                    raise tornado.web.HTTPError(404, reason=str(exc)) from exc
                except Exception:
                    await cur.execute("ROLLBACK")
                    raise
        self.write_json({"success": True, "prompt": prompt, "data": prompts})


class ChatPromptShowoffHandler(ChatBaseHandler):
    async def post(self):
        user_entity_id = self.current_user_entity_id()
        chat_id = str(self._param("chat_id", "")).strip().lower()
        prompt_id = str(self._param("prompt_id", "")).strip().lower()
        showoff = self._param("showoff", True)
        if not HEX32_RE.fullmatch(chat_id):
            raise tornado.web.HTTPError(400, reason="chat_id must be a 32-character hex string")
        if not HEX32_RE.fullmatch(prompt_id):
            raise tornado.web.HTTPError(400, reason="prompt_id must be a 32-character hex string")
        if isinstance(showoff, str):
            showoff = showoff.lower() not in ("0", "false", "no")
        else:
            showoff = bool(showoff)

        async with self.mysql.acquire() as conn:
            async with conn.cursor() as cur:
                await cur.execute("START TRANSACTION")
                try:
                    await self.require_chat_owner(cur, chat_id, user_entity_id)
                    prompts = await set_chat_prompt_showoff(cur, chat_id, prompt_id, showoff)
                    await cur.execute("COMMIT")
                except ValueError as exc:
                    await cur.execute("ROLLBACK")
                    raise tornado.web.HTTPError(404, reason=str(exc)) from exc
                except Exception:
                    await cur.execute("ROLLBACK")
                    raise
        self.write_json({"success": True, "data": prompts})


class ChatWebSocketHandler(tornado.websocket.WebSocketHandler):
    subscribers = {}

    def check_origin(self, origin):
        return True

    def open(self):
        block_id = self.get_argument("block_id", "").strip()
        if not block_id:
            self.close(code=4000, reason="block_id is required")
            return
        self.block_id = block_id
        self.subscribers.setdefault(block_id, set()).add(self)
        self.write_message({"type": "ws.open", "block_id": block_id})

    def on_close(self):
        block_id = getattr(self, "block_id", None)
        if not block_id:
            return
        clients = self.subscribers.get(block_id)
        if not clients:
            return
        clients.discard(self)
        if not clients:
            self.subscribers.pop(block_id, None)

    @classmethod
    def broadcast(cls, block_ids, payload):
        message = json.dumps(payload, ensure_ascii=False)
        for block_id in block_ids:
            for client in list(cls.subscribers.get(block_id, ())):
                client.write_message(message)
