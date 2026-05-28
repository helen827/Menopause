import tornado.web

from app.handlers.base import BaseHandler


class UsersHandler(BaseHandler):
    async def get(self):
        async with self.mysql.acquire() as conn:
            async with conn.cursor() as cur:
                await cur.execute(
                    """
                    SELECT id, name, email, created_at
                    FROM users
                    ORDER BY id DESC
                    LIMIT 100
                    """
                )
                rows = await cur.fetchall()

        users = [
            {
                "id": row[0],
                "name": row[1],
                "email": row[2],
                "created_at": row[3].isoformat() if row[3] else None,
            }
            for row in rows
        ]
        self.write_json({"users": users})

    async def post(self):
        name = str(self.json_body.get("name", "")).strip()
        email = str(self.json_body.get("email", "")).strip().lower()
        if not name or not email:
            raise tornado.web.HTTPError(400, reason="Both name and email are required")

        async with self.mysql.acquire() as conn:
            async with conn.cursor() as cur:
                await cur.execute(
                    "INSERT INTO users (name, email) VALUES (%s, %s)",
                    (name, email),
                )
                user_id = cur.lastrowid

        self.write_json({"id": user_id, "name": name, "email": email}, status=201)
