from app.handlers.base import BaseHandler


class HealthHandler(BaseHandler):
    async def get(self):
        async with self.mysql.acquire() as conn:
            async with conn.cursor() as cur:
                await cur.execute("SELECT 1")
                row = await cur.fetchone()
        self.write_json({"status": "ok", "mysql": row[0] == 1})
