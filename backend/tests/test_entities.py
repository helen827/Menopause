import json

import pytest

from app.services.entities import build_mobile_login, database_for_entity_id, decode_entity_body, delete_entity_bodies


class FakeCursor:
    def __init__(self):
        self.calls = []
        self.rowcount = 0

    async def execute(self, sql, args):
        self.calls.append((sql, args))
        self.rowcount = len(args)


def test_entity_sharding_is_deterministic():
    assert database_for_entity_id("0" * 32) == "helen1"
    assert database_for_entity_id("0" * 31 + "1") == "helen2"


def test_entity_body_decodes_text_and_bytes():
    payload = {"message": "潮热", "count": 2}
    encoded = json.dumps(payload, ensure_ascii=False).encode()
    assert decode_entity_body(encoded) == payload
    assert decode_entity_body(encoded.decode()) == payload


def test_mobile_login_uses_expected_index_format():
    assert build_mobile_login("13800138000") == "mobile:+8613800138000"


@pytest.mark.asyncio
async def test_delete_entity_bodies_groups_valid_ids_by_database():
    cursor = FakeCursor()
    even_id = "0" * 32
    odd_id = "0" * 31 + "1"
    deleted = await delete_entity_bodies(cursor, [even_id, odd_id, "invalid", even_id])
    assert deleted == 2
    assert len(cursor.calls) == 2
    assert any("helen1.entities" in sql for sql, _ in cursor.calls)
    assert any("helen2.entities" in sql for sql, _ in cursor.calls)
