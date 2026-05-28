import re

import tornado.web

from app.handlers.base import BaseHandler
from app.services.entities import database_for_entity_id, decode_entity_body


BLOCK_ID_RE = re.compile(r"^[0-9a-fA-F]{32}$")


class DataJsonHandler(BaseHandler):
    async def get(self):
        block_id = self.get_argument("block_id", "").strip().lower()
        if not BLOCK_ID_RE.fullmatch(block_id):
            raise tornado.web.HTTPError(400, reason="block_id must be a 32-character hex string")

        database = database_for_entity_id(block_id)
        async with self.mysql.acquire() as conn:
            async with conn.cursor() as cur:
                await cur.execute(
                    f"""
                    SELECT body
                    FROM {database}.entities
                    WHERE entity_id = %s
                    LIMIT 1
                    """,
                    (block_id,),
                )
                row = await cur.fetchone()

        if not row:
            self.write_json({"data": "none"})
            return

        self.write_json({"data": decode_entity_body(row[0])})


class LoginSearchHandler(BaseHandler):
    async def get(self):
        login = self.get_argument("login", "").strip()
        if not login:
            raise tornado.web.HTTPError(400, reason="login is required")

        async with self.mysql.acquire() as conn:
            async with conn.cursor() as cur:
                await cur.execute(
                    """
                    SELECT entity_id
                    FROM helen.index_login
                    WHERE login = %s
                    LIMIT 1
                    """,
                    (login,),
                )
                row = await cur.fetchone()

                if not row and login.startswith("mobile:86"):
                    normalized_login = "mobile:+86" + login.removeprefix("mobile:86")
                    await cur.execute(
                        """
                        SELECT entity_id
                        FROM helen.index_login
                        WHERE login = %s
                        LIMIT 1
                        """,
                        (normalized_login,),
                    )
                    row = await cur.fetchone()
                    if row:
                        login = normalized_login

                if not row:
                    self.write_json({"data": "none"})
                    return

                entity_id = row[0]
                database = database_for_entity_id(entity_id)
                await cur.execute(
                    f"""
                    SELECT body
                    FROM {database}.entities
                    WHERE entity_id = %s
                    LIMIT 1
                    """,
                    (entity_id,),
                )
                body_row = await cur.fetchone()

        if not body_row:
            self.write_json({"data": "none"})
            return

        self.write_json(
            {
                "data": decode_entity_body(body_row[0]),
                "login": login,
                "block_id": entity_id,
            }
        )
