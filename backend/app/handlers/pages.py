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
