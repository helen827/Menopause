import re

import tornado.web

from app.handlers.base import BaseHandler
from app.services.entities import get_or_create_mobile_entity


MOBILE_RE = re.compile(r"^\d{11}$")


class MobileEntityHandler(BaseHandler):
    async def get(self):
        await self._handle()

    async def post(self):
        await self._handle()

    def _mobile_param(self):
        mobile = self.json_body.get("mobile")
        if mobile is None:
            mobile = self.get_argument("mobile", None)
        mobile = str(mobile or "").strip()
        if not MOBILE_RE.fullmatch(mobile):
            raise tornado.web.HTTPError(400, reason="mobile must be 11 digits")
        return mobile

    async def _handle(self):
        mobile = self._mobile_param()
        login = f"mobile:+86{mobile}"

        async with self.mysql.acquire() as conn:
            async with conn.cursor() as cur:
                await cur.execute("START TRANSACTION")
                try:
                    entity = await get_or_create_mobile_entity(cur, mobile)
                    await cur.execute("COMMIT")
                except Exception:
                    await cur.execute("ROLLBACK")
                    raise

        self.write_json(
            {
                "created": entity["created"],
                "mobile": mobile,
                "login": login,
                "entity_id": entity["entity_id"],
                "database": entity["database"],
                "body": entity["body"],
            },
            status=201 if entity["created"] else 200,
        )
