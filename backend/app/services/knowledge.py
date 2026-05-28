import re
import uuid
from datetime import datetime, timezone

from app.services.entities import put_entity_body


TOKEN_RE = re.compile(r"[0-9A-Za-z\u4e00-\u9fff]{2,}")


def now_iso():
    return datetime.now(timezone.utc).isoformat()


def normalize_tags(tags):
    if tags is None:
        return ""
    if isinstance(tags, list):
        return ",".join(str(item).strip() for item in tags if str(item).strip())
    return str(tags).strip()


def row_to_item(row):
    return {
        "knowledge_id": row[0],
        "title": row[1],
        "category": row[2] or "",
        "tags": row[3] or "",
        "content": row[4],
        "is_active": bool(row[5]),
        "createtime": row[6].isoformat() if hasattr(row[6], "isoformat") else str(row[6]),
        "updatetime": row[7].isoformat() if hasattr(row[7], "isoformat") else str(row[7]),
    }


def tokenize_query(query):
    query = str(query or "").strip()
    tokens = TOKEN_RE.findall(query)
    if query and query not in tokens:
        tokens.insert(0, query)
    seen = set()
    result = []
    for token in tokens:
        token = token.strip().lower()
        if token and token not in seen:
            seen.add(token)
            result.append(token)
    return result[:12]


def build_snippet(content, tokens, size=220):
    text = str(content or "").strip()
    if len(text) <= size:
        return text
    lower_text = text.lower()
    hit = -1
    for token in tokens:
        hit = lower_text.find(token.lower())
        if hit >= 0:
            break
    if hit < 0:
        return text[:size].strip() + "..."
    start = max(hit - size // 3, 0)
    end = min(start + size, len(text))
    prefix = "..." if start > 0 else ""
    suffix = "..." if end < len(text) else ""
    return prefix + text[start:end].strip() + suffix


def score_item(item, tokens):
    title = item["title"].lower()
    category = item["category"].lower()
    tags = item["tags"].lower()
    content = item["content"].lower()
    score = 0
    for token in tokens:
        if token in title:
            score += 8
        if token in category:
            score += 5
        if token in tags:
            score += 5
        if token in content:
            score += 2
    return score


async def create_knowledge_item(cur, title, content, category="", tags="", is_active=True):
    knowledge_id = uuid.uuid4().hex
    tags = normalize_tags(tags)
    await cur.execute(
        """
        INSERT INTO helen.knowledge_items
          (knowledge_id, title, category, tags, content, is_active)
        VALUES (%s, %s, %s, %s, %s, %s)
        """,
        (knowledge_id, title, category, tags, content, 1 if is_active else 0),
    )
    body = {
        "entity_type": "knowledge_item",
        "knowledge_id": knowledge_id,
        "title": title,
        "category": category,
        "tags": tags,
        "content": content,
        "is_active": bool(is_active),
        "createtime": now_iso(),
    }
    await put_entity_body(cur, knowledge_id, body)
    return {
        "knowledge_id": knowledge_id,
        "title": title,
        "category": category,
        "tags": tags,
        "content": content,
        "is_active": bool(is_active),
    }


async def list_knowledge_items(cur, q="", limit=50):
    limit = max(1, min(int(limit or 50), 200))
    q = str(q or "").strip()
    if q:
        like = f"%{q}%"
        await cur.execute(
            """
            SELECT knowledge_id, title, category, tags, content, is_active, createtime, updatetime
            FROM helen.knowledge_items
            WHERE title LIKE %s
               OR category LIKE %s
               OR tags LIKE %s
               OR content LIKE %s
            ORDER BY updatetime DESC
            LIMIT %s
            """,
            (like, like, like, like, limit),
        )
    else:
        await cur.execute(
            """
            SELECT knowledge_id, title, category, tags, content, is_active, createtime, updatetime
            FROM helen.knowledge_items
            ORDER BY updatetime DESC
            LIMIT %s
            """,
            (limit,),
        )
    return [row_to_item(row) for row in await cur.fetchall()]


async def set_knowledge_active(cur, knowledge_id, is_active):
    await cur.execute(
        """
        UPDATE helen.knowledge_items
        SET is_active = %s
        WHERE knowledge_id = %s
        """,
        (1 if is_active else 0, knowledge_id),
    )
    if cur.rowcount == 0:
        raise ValueError("knowledge_id not found")
    return await get_knowledge_item(cur, knowledge_id)


async def get_knowledge_item(cur, knowledge_id):
    await cur.execute(
        """
        SELECT knowledge_id, title, category, tags, content, is_active, createtime, updatetime
        FROM helen.knowledge_items
        WHERE knowledge_id = %s
        LIMIT 1
        """,
        (knowledge_id,),
    )
    row = await cur.fetchone()
    return row_to_item(row) if row else None


async def search_knowledge(cur, query, limit=5):
    tokens = tokenize_query(query)
    if not tokens:
        return []
    limit = max(1, min(int(limit or 5), 12))
    clauses = []
    args = []
    for token in tokens[:6]:
        like = f"%{token}%"
        clauses.append("(title LIKE %s OR category LIKE %s OR tags LIKE %s OR content LIKE %s)")
        args.extend([like, like, like, like])
    await cur.execute(
        f"""
        SELECT knowledge_id, title, category, tags, content, is_active, createtime, updatetime
        FROM helen.knowledge_items
        WHERE is_active = 1 AND ({' OR '.join(clauses)})
        ORDER BY updatetime DESC
        LIMIT 80
        """,
        tuple(args),
    )
    items = [row_to_item(row) for row in await cur.fetchall()]
    ranked = []
    for item in items:
        score = score_item(item, tokens)
        if score > 0:
            compact = dict(item)
            compact["score"] = score
            compact["snippet"] = build_snippet(item["content"], tokens)
            ranked.append(compact)
    ranked.sort(key=lambda item: (item["score"], item["updatetime"]), reverse=True)
    return ranked[:limit]


def build_knowledge_system_message(items):
    if not items:
        return None
    lines = [
        "以下是本地知识库检索到的参考内容。回答用户时优先依据这些内容；如果知识库和聊天历史都没有依据，请明确说明不确定，避免编造。"
    ]
    for index, item in enumerate(items, start=1):
        meta = " / ".join(part for part in [item.get("category"), item.get("tags")] if part)
        title = item.get("title") or item["knowledge_id"]
        lines.append(f"[{index}] {title}{f'（{meta}）' if meta else ''}: {item.get('snippet') or ''}")
    return "\n".join(lines)
