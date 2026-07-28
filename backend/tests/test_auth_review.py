import unittest
from types import SimpleNamespace

from app.handlers.auth import _is_app_review_mobile, _is_valid_app_review_code


class TestAppReviewLogin(unittest.TestCase):
    def settings(self, *, enabled=True, mobile="13800138000", code="246810"):
        return SimpleNamespace(
            app_review_login_enabled=enabled,
            app_review_mobile=mobile,
            app_review_code=code,
        )

    def test_accepts_only_configured_mobile_and_code(self):
        settings = self.settings()

        self.assertTrue(_is_app_review_mobile(settings, "13800138000"))
        self.assertTrue(_is_valid_app_review_code(settings, "13800138000", "246810"))
        self.assertFalse(_is_valid_app_review_code(settings, "13800138000", "111111"))
        self.assertFalse(_is_valid_app_review_code(settings, "13900000000", "246810"))

    def test_disabled_or_invalid_configuration_never_bypasses_sms(self):
        self.assertFalse(_is_app_review_mobile(self.settings(enabled=False), "13800138000"))
        self.assertFalse(_is_app_review_mobile(self.settings(mobile="invalid"), "13800138000"))
        self.assertFalse(_is_app_review_mobile(self.settings(code="abc"), "13800138000"))
