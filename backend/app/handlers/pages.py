from pathlib import Path

import tornado.web


class LoginPageHandler(tornado.web.RequestHandler):
    def get(self):
        page_path = Path(__file__).resolve().parents[2] / "static" / "login.html"
        self.set_header("Content-Type", "text/html; charset=utf-8")
        self.write(page_path.read_text(encoding="utf-8"))


class ChatPageHandler(tornado.web.RequestHandler):
    def get(self):
        page_path = Path(__file__).resolve().parents[2] / "static" / "chat.html"
        self.set_header("Content-Type", "text/html; charset=utf-8")
        self.write(page_path.read_text(encoding="utf-8"))


class DailyQuotePageHandler(tornado.web.RequestHandler):
    def get(self):
        page_path = Path(__file__).resolve().parents[2] / "static" / "daily_quote.html"
        self.set_header("Content-Type", "text/html; charset=utf-8")
        self.write(page_path.read_text(encoding="utf-8"))


class MobileChatLookupPageHandler(tornado.web.RequestHandler):
    def get(self):
        page_path = Path(__file__).resolve().parents[2] / "static" / "mobile_chat_lookup.html"
        self.set_header("Content-Type", "text/html; charset=utf-8")
        self.write(page_path.read_text(encoding="utf-8"))


class TrendReportPageHandler(tornado.web.RequestHandler):
    def get(self):
        page_path = Path(__file__).resolve().parents[2] / "static" / "trend_report.html"
        self.set_header("Content-Type", "text/html; charset=utf-8")
        self.write(page_path.read_text(encoding="utf-8"))


class StaticLegalPageHandler(tornado.web.RequestHandler):
    filename = ""

    def get(self):
        page_path = Path(__file__).resolve().parents[2] / "static" / self.filename
        self.set_header("Content-Type", "text/html; charset=utf-8")
        self.write(page_path.read_text(encoding="utf-8"))


class PrivacyPolicyPageHandler(StaticLegalPageHandler):
    filename = "privacy_policy.html"


class TermsPageHandler(StaticLegalPageHandler):
    filename = "terms.html"


class DataDeletionPageHandler(StaticLegalPageHandler):
    filename = "data_deletion.html"


class AiHealthDisclaimerPageHandler(StaticLegalPageHandler):
    filename = "ai_health_disclaimer.html"


class SupportPageHandler(StaticLegalPageHandler):
    filename = "support.html"
