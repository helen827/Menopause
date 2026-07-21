from pathlib import Path

from tornado.testing import AsyncHTTPTestCase
from tornado.web import Application

from app.handlers.pages import AiHealthDisclaimerPageHandler, DataDeletionPageHandler, PrivacyPolicyPageHandler, TermsPageHandler


class TestLegalPages(AsyncHTTPTestCase):
    def get_app(self):
        return Application([
            (r"/privacy", PrivacyPolicyPageHandler),
            (r"/terms", TermsPageHandler),
            (r"/data-deletion", DataDeletionPageHandler),
            (r"/ai-health-disclaimer", AiHealthDisclaimerPageHandler),
        ])

    def test_legal_pages_are_available_as_utf8_html(self):
        for path in ("/privacy", "/terms", "/data-deletion", "/ai-health-disclaimer"):
            response = self.fetch(path)
            assert response.code == 200
            assert response.headers["Content-Type"].startswith("text/html")
            assert "<html" in response.body.decode("utf-8").lower()


def test_all_static_pages_referenced_by_handlers_exist():
    static_dir = Path(__file__).resolve().parents[1] / "static"
    expected = {
        "login.html", "chat.html", "daily_quote.html", "mobile_chat_lookup.html", "trend_report.html",
        "privacy_policy.html", "terms.html", "data_deletion.html", "ai_health_disclaimer.html",
    }
    assert expected <= {path.name for path in static_dir.glob("*.html")}
