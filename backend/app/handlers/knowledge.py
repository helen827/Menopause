import re

import tornado.web

from app.handlers.base import BaseHandler
from app.services.knowledge import (
    create_knowledge_item,
    list_knowledge_items,
    search_knowledge,
    set_knowledge_active,
)


HEX32_RE = re.compile(r"^[0-9a-fA-F]{32}$")


class KnowledgeBaseHandler(BaseHandler):
    def _param(self, name, default=""):
        value = self.json_body.get(name)
        if value is None:
            value = self.get_argument(name, default)
        return value


class KnowledgeListHandler(KnowledgeBaseHandler):
    async def get(self):
        q = self.get_argument("q", "").strip()
        limit = self.get_argument("limit", "50")
        async with self.mysql.acquire() as conn:
            async with conn.cursor() as cur:
                items = await list_knowledge_items(cur, q, limit)
        self.write_json({"data": items if items else "none"})


class KnowledgeSearchHandler(KnowledgeBaseHandler):
    async def get(self):
        q = self.get_argument("q", "").strip()
        limit = self.get_argument("limit", "5")
        if not q:
            raise tornado.web.HTTPError(400, reason="q is required")
        async with self.mysql.acquire() as conn:
            async with conn.cursor() as cur:
                items = await search_knowledge(cur, q, limit)
        self.write_json({"data": items if items else "none"})


class KnowledgeCreateHandler(KnowledgeBaseHandler):
    async def post(self):
        title = str(self._param("title", "")).strip()
        category = str(self._param("category", "")).strip()
        tags = self._param("tags", "")
        content = str(self._param("content", "")).strip()
        is_active = self._param("is_active", True)

        if not title:
            raise tornado.web.HTTPError(400, reason="title is required")
        if not content:
            raise tornado.web.HTTPError(400, reason="content is required")
        if isinstance(is_active, str):
            is_active = is_active.lower() not in ("0", "false", "no")
        else:
            is_active = bool(is_active)

        async with self.mysql.acquire() as conn:
            async with conn.cursor() as cur:
                await cur.execute("START TRANSACTION")
                try:
                    item = await create_knowledge_item(cur, title, content, category, tags, is_active)
                    await cur.execute("COMMIT")
                except Exception:
                    await cur.execute("ROLLBACK")
                    raise
        self.write_json({"success": True, "data": item}, status=201)


class KnowledgeActiveHandler(KnowledgeBaseHandler):
    async def post(self):
        knowledge_id = str(self._param("knowledge_id", "")).strip().lower()
        is_active = self._param("is_active", True)
        if not HEX32_RE.fullmatch(knowledge_id):
            raise tornado.web.HTTPError(400, reason="knowledge_id must be a 32-character hex string")
        if isinstance(is_active, str):
            is_active = is_active.lower() not in ("0", "false", "no")
        else:
            is_active = bool(is_active)

        async with self.mysql.acquire() as conn:
            async with conn.cursor() as cur:
                await cur.execute("START TRANSACTION")
                try:
                    item = await set_knowledge_active(cur, knowledge_id, is_active)
                    await cur.execute("COMMIT")
                except ValueError as exc:
                    await cur.execute("ROLLBACK")
                    raise tornado.web.HTTPError(404, reason=str(exc)) from exc
                except Exception:
                    await cur.execute("ROLLBACK")
                    raise
        self.write_json({"success": True, "data": item})
