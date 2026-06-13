import asyncio
import logging

import tornado.httpserver
import tornado.ioloop
import tornado.web

from app.config import get_settings
from app.db import close_mysql_pool, create_mysql_pool
from app.handlers.app_blocks import DailyQuoteHandler
from app.handlers.auth import CheckLoginHandler, LoginHandler, SendCodeHandler
from app.handlers.chat import (
    ChatActivityHandler,
    ChatEnsureHandler,
    ChatLoadHandler,
    ChatPromptCreateHandler,
    ChatPromptListHandler,
    ChatPromptSelectHandler,
    ChatPromptShowoffHandler,
    ChatSubmitHandler,
    ChatWebSocketHandler,
)
from app.handlers.data_query import DataJsonHandler, LoginSearchHandler
from app.handlers.health import HealthHandler
from app.handlers.knowledge import (
    KnowledgeActiveHandler,
    KnowledgeCreateHandler,
    KnowledgeListHandler,
    KnowledgeSearchHandler,
)
from app.handlers.mobile_entity import MobileEntityHandler
from app.handlers.pages import ChatPageHandler, DailyQuotePageHandler, LoginPageHandler
from app.handlers.meditation import (
    MeditationPracticeCorrelationHandler,
    MeditationPracticeListHandler,
    MeditationPracticeRecordHandler,
    MeditationPracticeSummaryHandler,
)
from app.handlers.trend_report import (
    MedicalChecklistLoadHandler,
    MedicalChecklistSaveHandler,
    TrendReportEnsureHandler,
    TrendReportLoadHandler,
    TrendReportSaveHandler,
)
from app.handlers.users import UsersHandler


def make_app(mysql_pool):
    settings = get_settings()
    return tornado.web.Application(
        [
            (r"/health", HealthHandler),
            (r"/", LoginPageHandler),
            (r"/login", LoginPageHandler),
            (r"/chat", ChatPageHandler),
            (r"/daily_quote", DailyQuotePageHandler),
            (r"/api/users", UsersHandler),
            (r"/api/mobile/entity", MobileEntityHandler),
            (r"/api/data/json", DataJsonHandler),
            (r"/api/login_search", LoginSearchHandler),
            (r"/api/send_code", SendCodeHandler),
            (r"/api/login", LoginHandler),
            (r"/api/check_login", CheckLoginHandler),
            (r"/api/app/daily_quote", DailyQuoteHandler),
            (r"/api/chat/ensure", ChatEnsureHandler),
            (r"/api/chat/load", ChatLoadHandler),
            (r"/api/chat/activity", ChatActivityHandler),
            (r"/api/chat/submit", ChatSubmitHandler),
            (r"/api/chat/prompts/list", ChatPromptListHandler),
            (r"/api/chat/prompts/create", ChatPromptCreateHandler),
            (r"/api/chat/prompts/select", ChatPromptSelectHandler),
            (r"/api/chat/prompts/showoff", ChatPromptShowoffHandler),
            (r"/api/meditation/practice/record", MeditationPracticeRecordHandler),
            (r"/api/meditation/practice/list", MeditationPracticeListHandler),
            (r"/api/meditation/practice/summary", MeditationPracticeSummaryHandler),
            (r"/api/meditation/practice/correlation", MeditationPracticeCorrelationHandler),
            (r"/api/trend_report/ensure", TrendReportEnsureHandler),
            (r"/api/trend_report/load", TrendReportLoadHandler),
            (r"/api/trend_report/save", TrendReportSaveHandler),
            (r"/api/medical_checklist/load", MedicalChecklistLoadHandler),
            (r"/api/medical_checklist/save", MedicalChecklistSaveHandler),
            (r"/api/knowledge/list", KnowledgeListHandler),
            (r"/api/knowledge/search", KnowledgeSearchHandler),
            (r"/api/knowledge/create", KnowledgeCreateHandler),
            (r"/api/knowledge/active", KnowledgeActiveHandler),
            (r"/api/ws", ChatWebSocketHandler),
        ],
        mysql_pool=mysql_pool,
        cookie_secret=settings.cookie_secret,
        debug=settings.debug,
    )


async def main():
    settings = get_settings()
    logging.basicConfig(
        level=logging.DEBUG if settings.debug else logging.INFO,
        format="%(asctime)s %(levelname)s %(name)s: %(message)s",
    )

    mysql_pool = await create_mysql_pool(settings)
    app = make_app(mysql_pool)
    server = tornado.httpserver.HTTPServer(app)
    server.listen(settings.app_port)
    logging.info("Tornado server listening on http://127.0.0.1:%s", settings.app_port)

    shutdown_event = asyncio.Event()
    try:
        await shutdown_event.wait()
    finally:
        await close_mysql_pool(mysql_pool)


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        pass
