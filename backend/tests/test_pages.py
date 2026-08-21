from pathlib import Path

from tornado.testing import AsyncHTTPTestCase
from tornado.web import Application

from app.handlers.pages import (
    AiHealthDisclaimerPageHandler,
    DataDeletionPageHandler,
    PrivacyPolicyPageHandler,
    SupportPageHandler,
    TermsPageHandler,
)


class TestLegalPages(AsyncHTTPTestCase):
    def get_app(self):
        return Application([
            (r"/privacy", PrivacyPolicyPageHandler),
            (r"/terms", TermsPageHandler),
            (r"/data-deletion", DataDeletionPageHandler),
            (r"/ai-health-disclaimer", AiHealthDisclaimerPageHandler),
            (r"/support", SupportPageHandler),
        ])

    def test_legal_pages_are_available_as_utf8_html(self):
        for path in ("/privacy", "/terms", "/data-deletion", "/ai-health-disclaimer", "/support"):
            response = self.fetch(path)
            assert response.code == 200
            assert response.headers["Content-Type"].startswith("text/html")
            assert "<html" in response.body.decode("utf-8").lower()


def test_all_static_pages_referenced_by_handlers_exist():
    static_dir = Path(__file__).resolve().parents[1] / "static"
    expected = {
        "login.html", "chat.html", "daily_quote.html", "mobile_chat_lookup.html", "trend_report.html",
        "privacy_policy.html", "terms.html", "data_deletion.html", "ai_health_disclaimer.html", "support.html",
    }
    assert expected <= {path.name for path in static_dir.glob("*.html")}


def test_public_pages_display_icp_filing_link():
    static_dir = Path(__file__).resolve().parents[1] / "static"
    for filename in (
        "login.html",
        "privacy_policy.html",
        "terms.html",
        "data_deletion.html",
        "ai_health_disclaimer.html",
        "support.html",
    ):
        content = (static_dir / filename).read_text(encoding="utf-8")
        assert "沪ICP备2026034440号-1" in content
        assert "沪ICP备2026034440号-2A" not in content
        assert 'href="https://beian.miit.gov.cn/"' in content
