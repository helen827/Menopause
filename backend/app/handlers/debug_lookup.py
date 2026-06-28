import re

import tornado.web

from app.handlers.base import BaseHandler
from app.services.chat import load_recent_chat_comments
from app.services.entities import database_for_entity_id


MOBILE_RE = re.compile(r"^\d{11}$")


class DebugMobileChatLookupHandler(BaseHandler):
    async def get(self):
        mobile = str(self.get_argument("mobile", "")).strip()
        if not MOBILE_RE.fullmatch(mobile):
            raise tornado.web.HTTPError(400, reason="mobile must be 11 digits")

        logins = [
            f"mobile:+86{mobile}",
            f"mobile:86{mobile}",
        ]
        searches = [
            mobile,
            f"86{mobile}",
            f"+86{mobile}",
        ]

        async with self.mysql.acquire() as conn:
            async with conn.cursor() as cur:
                await cur.execute(
                    """
                    SELECT login, entity_id, createtime, search
                    FROM helen.index_login
                    WHERE login IN (%s, %s)
                       OR search IN (%s, %s, %s)
                    ORDER BY id DESC
                    LIMIT 1
                    """,
                    (logins[0], logins[1], searches[0], searches[1], searches[2]),
                )
                user_row = await cur.fetchone()
                if not user_row:
                    self.write_json({"data": "none", "message": "mobile not found"})
                    return

                login, user_entity_id, createtime, search = user_row
                database = database_for_entity_id(user_entity_id)

                await cur.execute(
                    """
                    SELECT chat_id, title, active_prompt_id, showoff, head_block_id, tail_block_id, total_comments, createtime, updatetime
                    FROM helen.chat_index
                    WHERE user_entity_id = %s
                    ORDER BY updatetime DESC, id DESC
                    """,
                    (user_entity_id,),
                )
                chat_rows = await cur.fetchall()

                chats = []
                for row in chat_rows:
                    chat_id = row[0]
                    recent = await load_recent_chat_comments(cur, chat_id, limit=20)
                    chats.append(
                        {
                            "chat_id": chat_id,
                            "title": row[1],
                            "active_prompt_id": row[2],
                            "showoff": bool(row[3]),
                            "head_block_id": row[4],
                            "tail_block_id": row[5],
                            "total_comments": int(row[6] or 0),
                            "createtime": row[7].isoformat() if row[7] else None,
                            "updatetime": row[8].isoformat() if row[8] else None,
                            "recent_comments": (recent or {}).get("comments", []),
                        }
                    )

        self.write_json(
            {
                "success": True,
                "mobile": mobile,
                "login": login,
                "user_entity_id": user_entity_id,
                "database": database,
                "search": search,
                "createtime": createtime.isoformat() if createtime else None,
                "chat_count": len(chats),
                "chats": chats,
            }
        )
