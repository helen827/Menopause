import tornado.web

from app.handlers.base import BaseHandler
from app.services.app_blocks import get_daily_quote_block, update_daily_quote_block


class DailyQuoteHandler(BaseHandler):
    async def get(self):
        include_all = self.get_argument("manage", "") in ("1", "true", "yes")
        async with self.mysql.acquire() as conn:
            async with conn.cursor() as cur:
                await cur.execute("START TRANSACTION")
                try:
                    block = await get_daily_quote_block(cur, include_all=include_all)
                    await cur.execute("COMMIT")
                except Exception:
                    await cur.execute("ROLLBACK")
                    raise
        self.write_json(block)

    async def post(self):
        action = str(self.json_body.get("action") or "add").strip().lower()
        quote = str(self.json_body.get("quote") or "").strip()
        if action != "delete" and not quote:
            raise tornado.web.HTTPError(400, reason="quote is required")
        async with self.mysql.acquire() as conn:
            async with conn.cursor() as cur:
                await cur.execute("START TRANSACTION")
                try:
                    block = await update_daily_quote_block(cur, self.json_body)
                    await cur.execute("COMMIT")
                except ValueError as exc:
                    await cur.execute("ROLLBACK")
                    raise tornado.web.HTTPError(404, reason=str(exc)) from exc
                except Exception:
                    await cur.execute("ROLLBACK")
                    raise
        self.write_json({"success": True, **block})
