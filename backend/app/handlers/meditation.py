import tornado.web

from app.handlers.chat import ChatBaseHandler
from app.services.meditation import (
    build_practice_symptom_correlation,
    load_meditation_activity,
    load_meditation_records,
    record_meditation_practice,
)


class MeditationPracticeRecordHandler(ChatBaseHandler):
    async def post(self):
        user_entity_id = self.current_user_entity_id()
        async with self.mysql.acquire() as conn:
            async with conn.cursor() as cur:
                await cur.execute("START TRANSACTION")
                try:
                    data = await record_meditation_practice(cur, user_entity_id, self.json_body)
                    await cur.execute("COMMIT")
                except ValueError as exc:
                    await cur.execute("ROLLBACK")
                    raise tornado.web.HTTPError(400, reason=str(exc)) from exc
                except Exception:
                    await cur.execute("ROLLBACK")
                    raise
        self.write_json({"success": True, "data": data}, status=201)


class MeditationPracticeListHandler(ChatBaseHandler):
    async def get(self):
        user_entity_id = self.current_user_entity_id()
        try:
            limit = int(self.get_argument("limit", "50"))
        except ValueError as exc:
            raise tornado.web.HTTPError(400, reason="limit must be an integer") from exc

        async with self.mysql.acquire() as conn:
            async with conn.cursor() as cur:
                data = await load_meditation_records(cur, user_entity_id, max(1, min(limit, 200)))
        self.write_json({"data": data})


class MeditationPracticeSummaryHandler(ChatBaseHandler):
    async def get(self):
        user_entity_id = self.current_user_entity_id()
        try:
            year = int(self.get_argument("year", ""))
            month = int(self.get_argument("month", ""))
            tz_offset_minutes = int(self.get_argument("tz_offset_minutes", "0"))
        except ValueError as exc:
            raise tornado.web.HTTPError(400, reason="year, month and tz_offset_minutes must be integers") from exc

        if year < 2000 or year > 2100:
            raise tornado.web.HTTPError(400, reason="year is out of range")
        if month < 1 or month > 12:
            raise tornado.web.HTTPError(400, reason="month must be 1-12")

        async with self.mysql.acquire() as conn:
            async with conn.cursor() as cur:
                data = await load_meditation_activity(cur, user_entity_id, year, month, tz_offset_minutes)
        self.write_json({"data": data})


class MeditationPracticeCorrelationHandler(ChatBaseHandler):
    async def get(self):
        user_entity_id = self.current_user_entity_id()
        try:
            days = int(self.get_argument("days", "30"))
            tz_offset_minutes = int(self.get_argument("tz_offset_minutes", "0"))
        except ValueError as exc:
            raise tornado.web.HTTPError(400, reason="days and tz_offset_minutes must be integers") from exc

        async with self.mysql.acquire() as conn:
            async with conn.cursor() as cur:
                data = await build_practice_symptom_correlation(cur, user_entity_id, days, tz_offset_minutes)
        self.write_json({"data": data})
