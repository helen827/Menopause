from datetime import datetime, timezone

import pytest

from app.services.meditation import build_empty_meditation_block, mode_from_payload, parse_datetime


def test_parse_datetime_accepts_zulu_and_adds_timezone_to_naive_values():
    zulu = parse_datetime("2026-06-13T21:30:00Z")
    naive = parse_datetime("2026-06-13T21:30:00")
    assert zulu == datetime(2026, 6, 13, 21, 30, tzinfo=timezone.utc)
    assert naive.tzinfo == timezone.utc
    assert parse_datetime("not-a-date") is None


@pytest.mark.parametrize("payload,key", [
    ({"mode_key": "sleep"}, "sleep"),
    ({"mode": "舒缓心情"}, "mood"),
    ({"mode_key": "hotflash"}, "hot_flash"),
])
def test_mode_aliases_are_normalized(payload, key):
    assert mode_from_payload(payload)["key"] == key


def test_unknown_mode_is_rejected():
    with pytest.raises(ValueError, match="mode_key"):
        mode_from_payload({"mode_key": "unknown"})


def test_empty_block_has_stable_initial_shape():
    block = build_empty_meditation_block("user-id", "block-id")
    assert block["practice_ids"] == []
    assert block["stats"]["total_practice_count"] == 0
    assert block["stats"]["mode_counts"] == {}
