from datetime import datetime, timezone

import pytest

from app.services import chat as chat_service


class FakeCursor:
    def __init__(self, *, one=None, rows=None):
        self.one = one
        self.rows = rows or []
        self.calls = []

    async def execute(self, sql, args):
        self.calls.append((" ".join(sql.split()), args))

    async def fetchone(self):
        return self.one

    async def fetchall(self):
        return self.rows


@pytest.mark.asyncio
async def test_active_prompt_is_loaded_from_global_scope():
    created = datetime(2026, 7, 27, tzinfo=timezone.utc)
    cursor = FakeCursor(one=("a" * 32, "v2", "global", "prompt text", 1, created))

    prompt = await chat_service.get_active_prompt(cursor, "f" * 32)

    assert prompt["prompt_id"] == "a" * 32
    assert prompt["title"] == "v2"
    assert cursor.calls[0][1] == (chat_service.GLOBAL_PROMPT_CHAT_ID,)
    assert "WHERE chat_id = %s AND is_active = 1" in cursor.calls[0][0]


@pytest.mark.asyncio
async def test_prompt_list_is_shared_by_every_chat():
    created = datetime(2026, 7, 27, tzinfo=timezone.utc)
    row = ("b" * 32, "v1", "shared", "prompt text", 1, 1, created, created)
    cursor = FakeCursor(rows=[row])

    result = await chat_service.list_chat_prompts(cursor, "c" * 32)

    assert result["scope"] == "global"
    assert result["active_prompt_id"] == "b" * 32
    assert result["chat_id"] == "c" * 32
    assert cursor.calls[0][1] == (chat_service.GLOBAL_PROMPT_CHAT_ID,)


@pytest.mark.asyncio
async def test_creating_prompt_writes_global_scope(monkeypatch):
    saved = {}

    async def fake_put_entity_body(cur, entity_id, body):
        saved.update({"entity_id": entity_id, "body": body})

    monkeypatch.setattr(chat_service, "put_entity_body", fake_put_entity_body)
    cursor = FakeCursor()

    result = await chat_service.create_chat_prompt(
        cursor,
        "d" * 32,
        "v3",
        "new version",
        "global prompt",
        activate=True,
    )

    insert_args = cursor.calls[1][1]
    assert insert_args[1] == chat_service.GLOBAL_PROMPT_CHAT_ID
    assert result["scope"] == "global"
    assert saved["body"]["scope"] == "global"
    assert saved["body"]["created_from_chat_id"] == "d" * 32
