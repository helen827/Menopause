from pathlib import Path

from app.handlers.base import LOCAL_DEBUG_USER_ENTITY_ID, is_loopback_ip


def test_only_loopback_addresses_are_treated_as_local():
    assert is_loopback_ip("127.0.0.1")
    assert is_loopback_ip("127.12.34.56")
    assert is_loopback_ip("::1")

    assert not is_loopback_ip("124.223.158.183")
    assert not is_loopback_ip("10.0.0.16")
    assert not is_loopback_ip("")
    assert not is_loopback_ip("not-an-ip")


def test_local_debug_identity_is_a_valid_isolated_entity_id():
    assert len(LOCAL_DEBUG_USER_ENTITY_ID) == 32
    assert set(LOCAL_DEBUG_USER_ENTITY_ID) == {"1"}


def test_chat_page_does_not_ask_for_a_manual_user_id():
    page = (Path(__file__).resolve().parents[1] / "static" / "chat.html").read_text(encoding="utf-8")

    assert 'id="userIdInput"' not in page
    assert "测试 user_id" not in page
    assert "本地调试时会自动使用隔离的测试身份" in page
