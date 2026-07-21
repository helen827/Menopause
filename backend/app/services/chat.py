import uuid
from datetime import datetime, timedelta, timezone

from app.services.entities import get_entity_body, put_entity_body


CHAT_BLOCK_SIZE = 100


def now_iso():
    return datetime.now(timezone.utc).isoformat()


async def ensure_chat(cur, user_entity_id):
    await cur.execute(
        """
        SELECT chat_id, head_block_id, tail_block_id, total_comments, active_prompt_id, showoff
        FROM helen.chat_index
        WHERE user_entity_id = %s
        ORDER BY id DESC
        LIMIT 1
        """,
        (user_entity_id,),
    )
    row = await cur.fetchone()
    if row:
        return {
            "chat_id": row[0],
            "user_entity_id": user_entity_id,
            "head_block_id": row[1],
            "tail_block_id": row[2],
            "total_comments": row[3],
            "active_prompt_id": row[4],
            "showoff": bool(row[5]),
            "created": False,
        }

    chat_id = uuid.uuid4().hex
    chat_body = {
        "entity_type": "chat",
        "chat_id": chat_id,
        "user_entity_id": user_entity_id,
        "head_block_id": None,
        "tail_block_id": None,
        "total_comments": 0,
        "active_prompt_id": None,
        "showoff": True,
        "createtime": now_iso(),
    }
    await put_entity_body(cur, chat_id, chat_body)
    await cur.execute(
        """
        INSERT INTO helen.chat_index
          (chat_id, user_entity_id, title, head_block_id, tail_block_id, total_comments)
        VALUES (%s, %s, %s, NULL, NULL, 0)
        """,
        (chat_id, user_entity_id, "默认对话"),
    )
    return {
        "chat_id": chat_id,
        "user_entity_id": user_entity_id,
        "head_block_id": None,
        "tail_block_id": None,
        "total_comments": 0,
        "active_prompt_id": None,
        "showoff": True,
        "created": True,
    }


async def get_chat_owner(cur, chat_id):
    await cur.execute(
        """
        SELECT user_entity_id
        FROM helen.chat_index
        WHERE chat_id = %s
        LIMIT 1
        """,
        (chat_id,),
    )
    row = await cur.fetchone()
    return row[0] if row else None


async def append_chat_comment(cur, chat_id, comment):
    await cur.execute(
        """
        SELECT chat_id, user_entity_id, head_block_id, tail_block_id, total_comments
        FROM helen.chat_index
        WHERE chat_id = %s
        LIMIT 1
        FOR UPDATE
        """,
        (chat_id,),
    )
    chat = await cur.fetchone()
    if not chat:
        raise ValueError("chat_id not found")

    active_prompt = await get_active_prompt(cur, chat_id)
    if active_prompt:
        comment["system_prompt"] = {
            "prompt_id": active_prompt["prompt_id"],
            "title": active_prompt["title"],
            "desc": active_prompt.get("desc") or "",
            "system_prompt": active_prompt["system_prompt"],
            "showoff": active_prompt["showoff"],
            "createtime": active_prompt["createtime"],
        }
    else:
        comment["system_prompt"] = None

    head_block_id = chat[2]
    tail_block_id = chat[3]
    total_comments = int(chat[4])

    if tail_block_id:
        await cur.execute(
            """
            SELECT block_id, comment_count
            FROM helen.chat_blocks
            WHERE block_id = %s
            LIMIT 1
            FOR UPDATE
            """,
            (tail_block_id,),
        )
        tail_meta = await cur.fetchone()
    else:
        tail_meta = None

    if not tail_meta or int(tail_meta[1]) >= CHAT_BLOCK_SIZE:
        block_id = uuid.uuid4().hex
        block_body = {
            "entity_type": "chat_block",
            "chat_id": chat_id,
            "block_id": block_id,
            "prev_block_id": tail_block_id,
            "next_block_id": None,
            "comments": [],
            "createtime": now_iso(),
        }
        await cur.execute(
            """
            INSERT INTO helen.chat_blocks
              (chat_id, block_id, prev_block_id, next_block_id, comment_count)
            VALUES (%s, %s, %s, NULL, 0)
            """,
            (chat_id, block_id, tail_block_id),
        )
        if tail_block_id:
            prev_body = await get_entity_body(cur, tail_block_id)
            if prev_body:
                prev_body["next_block_id"] = block_id
                await put_entity_body(cur, tail_block_id, prev_body)
            await cur.execute(
                """
                UPDATE helen.chat_blocks
                SET next_block_id = %s
                WHERE block_id = %s
                """,
                (block_id, tail_block_id),
            )
        if not head_block_id:
            head_block_id = block_id
    else:
        block_id = tail_meta[0]
        block_body = await get_entity_body(cur, block_id)
        if not block_body:
            block_body = {
                "entity_type": "chat_block",
                "chat_id": chat_id,
                "block_id": block_id,
                "prev_block_id": None,
                "next_block_id": None,
                "comments": [],
                "createtime": now_iso(),
            }

    block_body["comments"].append(comment)
    block_body["updatetime"] = now_iso()
    await put_entity_body(cur, block_id, block_body)

    comment_count = len(block_body["comments"])
    await cur.execute(
        """
        UPDATE helen.chat_blocks
        SET start_comment_id = COALESCE(start_comment_id, %s),
            end_comment_id = %s,
            comment_count = %s
        WHERE block_id = %s
        """,
        (comment["comment_id"], comment["comment_id"], comment_count, block_id),
    )
    await cur.execute(
        """
        UPDATE helen.chat_index
        SET head_block_id = %s,
            tail_block_id = %s,
            total_comments = %s
        WHERE chat_id = %s
        """,
        (head_block_id, block_id, total_comments + 1, chat_id),
    )
    return {
        "chat_id": chat_id,
        "block_id": block_id,
        "comment": comment,
        "block_comment_count": comment_count,
        "total_comments": total_comments + 1,
    }


async def load_chat_comments(cur, chat_id, last_comment_id=None):
    await cur.execute(
        """
        SELECT chat_id, head_block_id, tail_block_id, total_comments, showoff
        FROM helen.chat_index
        WHERE chat_id = %s
        LIMIT 1
        """,
        (chat_id,),
    )
    chat = await cur.fetchone()
    if not chat:
        return None

    if last_comment_id:
        await cur.execute(
            """
            SELECT block_id
            FROM helen.chat_blocks
            WHERE chat_id = %s AND end_comment_id = %s
            LIMIT 1
            """,
            (chat_id, last_comment_id),
        )
        row = await cur.fetchone()
        block_id = row[0] if row else None
    else:
        block_id = chat[2]

    if not block_id:
        return {
            "chat_id": chat_id,
            "block_id": None,
            "prev_block_id": None,
            "next_block_id": None,
            "comments": [],
            "total_comments": chat[3],
            "showoff": bool(chat[4]),
        }

    block_body = await get_entity_body(cur, block_id)
    if not block_body:
        return None

    return {
        "chat_id": chat_id,
        "block_id": block_id,
        "prev_block_id": block_body.get("prev_block_id"),
        "next_block_id": block_body.get("next_block_id"),
        "comments": block_body.get("comments", []),
        "total_comments": chat[3],
        "showoff": bool(chat[4]),
    }


async def load_recent_chat_comments(cur, chat_id, limit=40):
    await cur.execute(
        """
        SELECT tail_block_id, total_comments
        FROM helen.chat_index
        WHERE chat_id = %s
        LIMIT 1
        """,
        (chat_id,),
    )
    chat = await cur.fetchone()
    if not chat:
        return None

    block_id = chat[0]
    comments = []
    while block_id and len(comments) < limit:
        block_body = await get_entity_body(cur, block_id)
        if not block_body:
            break
        block_comments = block_body.get("comments", [])
        needed = limit - len(comments)
        comments = block_comments[-needed:] + comments
        block_id = block_body.get("prev_block_id")

    return {
        "chat_id": chat_id,
        "total_comments": int(chat[1]),
        "comments": comments[-limit:],
    }


def _parse_comment_time(value):
    if not value:
        return None
    if isinstance(value, datetime):
        return value
    text = str(value).strip()
    if text.endswith("Z"):
        text = f"{text[:-1]}+00:00"
    try:
        return datetime.fromisoformat(text)
    except ValueError:
        return None


async def load_chat_activity(cur, user_entity_id, year, month, tz_offset_minutes=0):
    from app.services.meditation import load_meditation_activity

    meditation_activity = await load_meditation_activity(cur, user_entity_id, year, month, tz_offset_minutes)
    await cur.execute(
        """
        SELECT chat_id
        FROM helen.chat_index
        WHERE user_entity_id = %s
        """,
        (user_entity_id,),
    )
    chats = await cur.fetchall()
    if not chats:
        return {
            "year": year,
            "month": month,
            "scope_title": "本月",
            "checkin_days": [],
            "meditation_days": meditation_activity["practice_days"],
            "consecutive_days": meditation_activity["practice_streak"],
            "practice_count": meditation_activity["practice_count"],
            "tags": _meditation_tags(meditation_activity),
        }

    offset = timezone(timedelta(minutes=int(tz_offset_minutes or 0)))
    checkin_days = set()
    all_checkin_dates = set()

    for (chat_id,) in chats:
        await cur.execute(
            """
            SELECT block_id
            FROM helen.chat_blocks
            WHERE chat_id = %s
            ORDER BY id ASC
            """,
            (chat_id,),
        )
        blocks = await cur.fetchall()
        for (block_id,) in blocks:
            block_body = await get_entity_body(cur, block_id)
            if not block_body:
                continue
            for comment in block_body.get("comments", []):
                if comment.get("role") != "user":
                    continue
                created_at = _parse_comment_time(comment.get("createtime"))
                if not created_at:
                    continue
                if created_at.tzinfo is None:
                    created_at = created_at.replace(tzinfo=timezone.utc)
                local_date = created_at.astimezone(offset).date()
                all_checkin_dates.add(local_date)
                if local_date.year == year and local_date.month == month:
                    checkin_days.add(local_date.day)

    today = datetime.now(offset).date()
    streak = 0
    cursor = today
    while cursor in all_checkin_dates:
        streak += 1
        cursor -= timedelta(days=1)

    return {
        "year": year,
        "month": month,
        "scope_title": "本月",
        "checkin_days": sorted(checkin_days),
        "meditation_days": meditation_activity["practice_days"],
        "consecutive_days": max(streak, meditation_activity["practice_streak"]),
        "practice_count": meditation_activity["practice_count"],
        "tags": _meditation_tags(meditation_activity),
    }


def _meditation_tags(activity):
    tags = []
    mode_counts = activity.get("mode_counts") or {}
    mode_labels = {
        "mood": "舒缓心情",
        "sleep": "助眠安睡",
        "hot_flash": "缓解潮热",
    }
    for key, label in mode_labels.items():
        count = int(mode_counts.get(key) or 0)
        if count > 0:
            tags.append(f"{label} {count}次")
    total_minutes = int((activity.get("total_duration_seconds") or 0) / 60)
    if total_minutes > 0:
        tags.append(f"练习 {total_minutes}分钟")
    return tags


async def build_deepseek_messages(cur, chat_id, max_history=40):
    active_prompt = await get_active_prompt(cur, chat_id)
    recent = await load_recent_chat_comments(cur, chat_id, max_history)
    if recent is None:
        raise ValueError("chat_id not found")

    default_prompt = "你是潮安应用里的 AI 对话助手。请用中文、温和、清晰地回应用户。"
    system_prompt = active_prompt["system_prompt"] if active_prompt else default_prompt
    total_comments = recent["total_comments"]
    comments = recent["comments"]
    omitted = max(total_comments - len(comments), 0)

    messages = [
        {
            "role": "system",
            "content": system_prompt,
        }
    ]
    if omitted:
        messages.append(
            {
                "role": "system",
                "content": f"聊天历史较长，当前只提供最近 {len(comments)} 条消息作为上下文；此前还有 {omitted} 条较早消息。",
            }
        )

    for comment in comments:
        role = comment.get("role") or "user"
        if role not in {"user", "assistant", "system"}:
            role = "user"
        content = str(comment.get("content") or "").strip()
        if content:
            messages.append({"role": role, "content": content})

    return {
        "messages": messages,
        "active_prompt": active_prompt,
        "history_count": len(comments),
        "omitted_count": omitted,
    }


async def list_chat_prompts(cur, chat_id):
    await cur.execute(
        """
        SELECT active_prompt_id, showoff
        FROM helen.chat_index
        WHERE chat_id = %s
        LIMIT 1
        """,
        (chat_id,),
    )
    chat = await cur.fetchone()
    if not chat:
        return None

    active_prompt_id = chat[0]
    chat_showoff = bool(chat[1])
    await cur.execute(
        """
        SELECT prompt_id, title, `desc`, system_prompt, is_active, showoff, createtime, updatetime
        FROM helen.chat_prompts
        WHERE chat_id = %s
        ORDER BY id DESC
        """,
        (chat_id,),
    )
    rows = await cur.fetchall()
    prompts = [
        {
            "prompt_id": row[0],
            "title": row[1],
            "desc": row[2] or "",
            "system_prompt": row[3],
            "is_active": bool(row[4]),
            "showoff": bool(row[5]),
            "createtime": row[6].isoformat() if hasattr(row[6], "isoformat") else str(row[6]),
            "updatetime": row[7].isoformat() if hasattr(row[7], "isoformat") else str(row[7]),
        }
        for row in rows
    ]
    return {
        "chat_id": chat_id,
        "active_prompt_id": active_prompt_id,
        "showoff": chat_showoff,
        "prompts": prompts,
    }


async def create_chat_prompt(cur, chat_id, title, desc, system_prompt, activate=True, showoff=True):
    await cur.execute(
        """
        SELECT chat_id
        FROM helen.chat_index
        WHERE chat_id = %s
        LIMIT 1
        FOR UPDATE
        """,
        (chat_id,),
    )
    if not await cur.fetchone():
        raise ValueError("chat_id not found")

    prompt_id = uuid.uuid4().hex
    if activate:
        await cur.execute(
            """
            UPDATE helen.chat_prompts
            SET is_active = 0
            WHERE chat_id = %s
            """,
            (chat_id,),
        )
    await cur.execute(
        """
        INSERT INTO helen.chat_prompts
          (prompt_id, chat_id, title, `desc`, system_prompt, is_active, showoff)
        VALUES (%s, %s, %s, %s, %s, %s, %s)
        """,
        (prompt_id, chat_id, title, desc, system_prompt, 1 if activate else 0, 1 if showoff else 0),
    )
    if activate:
        await cur.execute(
            """
            UPDATE helen.chat_index
            SET active_prompt_id = %s,
                showoff = %s
            WHERE chat_id = %s
            """,
            (prompt_id, 1 if showoff else 0, chat_id),
        )

    body = {
        "entity_type": "chat_prompt",
        "prompt_id": prompt_id,
        "chat_id": chat_id,
        "title": title,
        "desc": desc,
        "system_prompt": system_prompt,
        "is_active": bool(activate),
        "showoff": bool(showoff),
        "createtime": now_iso(),
    }
    await put_entity_body(cur, prompt_id, body)
    return {
        "prompt_id": prompt_id,
        "chat_id": chat_id,
        "title": title,
        "desc": desc,
        "system_prompt": system_prompt,
        "is_active": bool(activate),
        "showoff": bool(showoff),
    }


async def select_chat_prompt(cur, chat_id, prompt_id):
    await cur.execute(
        """
        SELECT prompt_id, title, `desc`, system_prompt, showoff, createtime
        FROM helen.chat_prompts
        WHERE chat_id = %s AND prompt_id = %s
        LIMIT 1
        FOR UPDATE
        """,
        (chat_id, prompt_id),
    )
    row = await cur.fetchone()
    if not row:
        raise ValueError("prompt_id not found")

    await cur.execute(
        """
        UPDATE helen.chat_prompts
        SET is_active = 0
        WHERE chat_id = %s
        """,
        (chat_id,),
    )
    await cur.execute(
        """
        UPDATE helen.chat_prompts
        SET is_active = 1
        WHERE prompt_id = %s
        """,
        (prompt_id,),
    )
    await cur.execute(
        """
        UPDATE helen.chat_index
        SET active_prompt_id = %s,
            showoff = %s
        WHERE chat_id = %s
        """,
        (prompt_id, 1 if row[4] else 0, chat_id),
    )
    body = await get_entity_body(cur, prompt_id)
    if body:
        body["is_active"] = True
        body["updatetime"] = now_iso()
        await put_entity_body(cur, prompt_id, body)
    return {
        "prompt_id": row[0],
        "chat_id": chat_id,
        "title": row[1],
        "desc": row[2] or "",
        "system_prompt": row[3],
        "showoff": bool(row[4]),
        "is_active": True,
        "createtime": row[5].isoformat() if hasattr(row[5], "isoformat") else str(row[5]),
    }


async def set_chat_prompt_showoff(cur, chat_id, prompt_id, showoff):
    await cur.execute(
        """
        SELECT prompt_id
        FROM helen.chat_prompts
        WHERE chat_id = %s AND prompt_id = %s
        LIMIT 1
        FOR UPDATE
        """,
        (chat_id, prompt_id),
    )
    if not await cur.fetchone():
        raise ValueError("prompt_id not found")

    await cur.execute(
        """
        UPDATE helen.chat_prompts
        SET showoff = %s
        WHERE chat_id = %s AND prompt_id = %s
        """,
        (1 if showoff else 0, chat_id, prompt_id),
    )
    await cur.execute(
        """
        UPDATE helen.chat_index
        SET showoff = %s
        WHERE chat_id = %s AND active_prompt_id = %s
        """,
        (1 if showoff else 0, chat_id, prompt_id),
    )
    body = await get_entity_body(cur, prompt_id)
    if body:
        body["showoff"] = bool(showoff)
        body["updatetime"] = now_iso()
        await put_entity_body(cur, prompt_id, body)
    return await list_chat_prompts(cur, chat_id)


async def get_active_prompt(cur, chat_id):
    await cur.execute(
        """
        SELECT prompt_id, title, `desc`, system_prompt, showoff, createtime
        FROM helen.chat_prompts
        WHERE chat_id = %s AND is_active = 1
        ORDER BY id DESC
        LIMIT 1
        """,
        (chat_id,),
    )
    row = await cur.fetchone()
    if not row:
        return None
    return {
        "prompt_id": row[0],
        "title": row[1],
        "desc": row[2] or "",
        "system_prompt": row[3],
        "showoff": bool(row[4]),
        "createtime": row[5].isoformat() if hasattr(row[5], "isoformat") else str(row[5]),
    }
