import json
import random
import uuid
from pathlib import Path

from app.services.chat import now_iso
from app.services.entities import get_entity_body, put_entity_body


CONTENT_DIR = Path(__file__).resolve().parents[2] / "content"
DAILY_QUOTE_FILE = CONTENT_DIR / "daily_quote.json"


DEFAULT_DAILY_QUOTE = {
    "quote": "更年期是一个充满机会的阶段，就仿佛是第二个青春期。",
    "source": "《更年期不是忍忍就好》",
    "speaker": "辛西娅・尼克松",
    "source_url": "",
    "speaker_url": "",
    "citation_enabled": False,
}


def load_daily_quote_json():
    if not DAILY_QUOTE_FILE.exists():
        return {"quotes": [dict(DEFAULT_DAILY_QUOTE)]}
    with DAILY_QUOTE_FILE.open("r", encoding="utf-8") as file:
        data = json.load(file)
    return normalize_daily_quote_collection(data)


def save_daily_quote_json(data):
    CONTENT_DIR.mkdir(parents=True, exist_ok=True)
    DAILY_QUOTE_FILE.write_text(
        json.dumps(normalize_daily_quote_collection(data), ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )


def normalize_daily_quote(data):
    data = data or {}
    return {
        "quote": str(data.get("quote") or "").strip() or DEFAULT_DAILY_QUOTE["quote"],
        "source": str(data.get("source") or "").strip() or DEFAULT_DAILY_QUOTE["source"],
        "speaker": str(data.get("speaker") or data.get("author") or "").strip()
        or DEFAULT_DAILY_QUOTE["speaker"],
        "source_url": str(data.get("source_url") or data.get("sourceUrl") or "").strip(),
        "speaker_url": str(data.get("speaker_url") or data.get("speakerUrl") or "").strip(),
        "citation_enabled": bool(data.get("citation_enabled") or data.get("citationEnabled")),
    }


def normalize_daily_quote_collection(data):
    if isinstance(data, list):
        raw_quotes = data
    elif isinstance(data, dict) and isinstance(data.get("quotes"), list):
        raw_quotes = data["quotes"]
    elif isinstance(data, dict):
        raw_quotes = [data]
    else:
        raw_quotes = [DEFAULT_DAILY_QUOTE]

    quotes = []
    for item in raw_quotes:
        if isinstance(item, dict):
            quotes.append(normalize_daily_quote(item))
    if not quotes:
        quotes.append(dict(DEFAULT_DAILY_QUOTE))
    return {"quotes": quotes}


def pick_daily_quote(collection):
    quotes = normalize_daily_quote_collection(collection)["quotes"]
    return random.choice(quotes)


async def ensure_app_block(cur, block_key, title, default_body):
    await cur.execute(
        """
        SELECT block_id
        FROM helen.app_blocks
        WHERE block_key = %s
        LIMIT 1
        """,
        (block_key,),
    )
    row = await cur.fetchone()
    if row:
        block_id = row[0]
        body = await get_entity_body(cur, block_id)
        if body:
            return block_id, body, False
    else:
        block_id = uuid.uuid4().hex
        await cur.execute(
            """
            INSERT INTO helen.app_blocks (block_key, block_id, title)
            VALUES (%s, %s, %s)
            """,
            (block_key, block_id, title),
        )

    body = {
        "entity_type": "app_block",
        "block_key": block_key,
        "block_id": block_id,
        "title": title,
        "data": default_body,
        "createtime": now_iso(),
        "updatetime": now_iso(),
    }
    await put_entity_body(cur, block_id, body)
    return block_id, body, True


async def get_daily_quote_block(cur, include_all=False):
    collection = load_daily_quote_json()
    block_id, body, created = await ensure_app_block(cur, "daily_quote", "每日一言", collection)
    current = body.get("data") or {}
    normalized = normalize_daily_quote_collection(current)
    if normalized != current:
        body["data"] = normalized
        body["updatetime"] = now_iso()
        await put_entity_body(cur, block_id, body)
    result = {
        "block_id": block_id,
        "block_key": "daily_quote",
        "title": "每日一言",
        "data": pick_daily_quote(normalized),
        "count": len(normalized["quotes"]),
        "created": created,
        "json_file": str(DAILY_QUOTE_FILE),
    }
    if include_all:
        result["quotes"] = normalized["quotes"]
    return result


async def update_daily_quote_block(cur, data):
    collection = load_daily_quote_json()
    block_id, body, _ = await ensure_app_block(cur, "daily_quote", "每日一言", collection)
    current = normalize_daily_quote_collection(body.get("data") or collection)
    quotes = current["quotes"]
    action = str(data.get("action") or "add").strip().lower()

    if action == "delete":
        index = int(data.get("index", -1))
        if index < 0 or index >= len(quotes):
            raise ValueError("quote index not found")
        del quotes[index]
        if not quotes:
            quotes.append(dict(DEFAULT_DAILY_QUOTE))
    else:
        quote = normalize_daily_quote(data)
        index_value = data.get("index")
        if action == "update" or index_value not in (None, ""):
            index = int(index_value)
            if index < 0 or index >= len(quotes):
                raise ValueError("quote index not found")
            quotes[index] = quote
        else:
            quotes.append(quote)

    next_collection = {"quotes": quotes}
    save_daily_quote_json(next_collection)
    body["data"] = next_collection
    body["updatetime"] = now_iso()
    await put_entity_body(cur, block_id, body)
    return {
        "block_id": block_id,
        "block_key": "daily_quote",
        "title": "每日一言",
        "data": pick_daily_quote(next_collection),
        "quotes": quotes,
        "count": len(quotes),
        "json_file": str(DAILY_QUOTE_FILE),
    }
