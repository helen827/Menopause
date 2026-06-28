import tornado.web
from datetime import datetime, timedelta, timezone

from app.handlers.chat import ChatBaseHandler
from app.services.medical_checklist import load_medical_checklist, save_medical_checklist
from app.services.trend_report import (
    ensure_trend_report_block,
    refresh_trend_report_for_chat,
    save_trend_report_range,
)


class TrendReportEnsureHandler(ChatBaseHandler):
    async def get(self):
        await self._handle()

    async def post(self):
        await self._handle()

    async def _handle(self):
        user_entity_id = self.current_user_entity_id()
        async with self.mysql.acquire() as conn:
            async with conn.cursor() as cur:
                await cur.execute("START TRANSACTION")
                try:
                    data = await ensure_trend_report_block(cur, user_entity_id)
                    await cur.execute("COMMIT")
                except Exception:
                    await cur.execute("ROLLBACK")
                    raise
        self.write_json({"success": True, "data": data}, status=201 if data["created"] else 200)


class TrendReportLoadHandler(ChatBaseHandler):
    async def get(self):
        user_entity_id = self.current_user_entity_id()
        async with self.mysql.acquire() as conn:
            async with conn.cursor() as cur:
                data = await ensure_trend_report_block(cur, user_entity_id)
                chat_id = self._extract_chat_id(data)
                if chat_id and (self._needs_trend_upgrade(data) or self._needs_date_refresh(data)):
                    data = await refresh_trend_report_for_chat(
                        cur,
                        chat_id,
                        tz_offset_minutes=480,
                        deepseek_service=self.deepseek_service,
                    )
        self.write_json({"success": True, "data": data})

    @staticmethod
    def _extract_chat_id(data):
        ranges = (((data or {}).get("body") or {}).get("ranges") or {})
        for range_data in ranges.values():
            chat_id = ((range_data or {}).get("source") or {}).get("chat_id")
            if chat_id:
                return str(chat_id).strip().lower()
        return None

    @staticmethod
    def _needs_trend_upgrade(data):
        ranges = (((data or {}).get("body") or {}).get("ranges") or {})
        for range_data in ranges.values():
            report = (range_data or {}).get("report") or {}
            trend_cards = report.get("trend_cards") or []
            if not trend_cards:
                continue
            keys = {str(item.get("key") or "") for item in trend_cards if isinstance(item, dict)}
            if "symptom_trend" not in keys and "sleep_trend" in keys:
                return True
        return False

    @staticmethod
    def _needs_date_refresh(data, tz_offset_minutes=480):
        offset = timezone(timedelta(minutes=int(tz_offset_minutes or 0)))
        today = datetime.now(offset).date().isoformat()
        ranges = (((data or {}).get("body") or {}).get("ranges") or {})
        if not ranges:
            return False
        for range_data in ranges.values():
            end_date = str(
                (range_data or {}).get("end_date")
                or ((range_data or {}).get("report") or {}).get("period", {}).get("end_date")
                or (range_data or {}).get("anchor_date")
                or ""
            ).strip()
            if end_date != today:
                return True
        return False


class TrendReportSaveHandler(ChatBaseHandler):
    async def post(self):
        user_entity_id = self.current_user_entity_id()
        range_key = str(self._param("range", "")).strip().lower()
        report = self.json_body.get("report")
        if not isinstance(report, dict):
            raise tornado.web.HTTPError(400, reason="report must be a JSON object")

        async with self.mysql.acquire() as conn:
            async with conn.cursor() as cur:
                await cur.execute("START TRANSACTION")
                try:
                    data = await save_trend_report_range(cur, user_entity_id, range_key, report)
                    await cur.execute("COMMIT")
                except ValueError as exc:
                    await cur.execute("ROLLBACK")
                    raise tornado.web.HTTPError(400, reason=str(exc)) from exc
                except Exception:
                    await cur.execute("ROLLBACK")
                    raise
        self.write_json({"success": True, "data": data})


class MedicalChecklistLoadHandler(ChatBaseHandler):
    async def get(self):
        user_entity_id = self.current_user_entity_id()
        range_key = str(self.get_argument("range", "30d")).strip().lower() or "30d"
        async with self.mysql.acquire() as conn:
            async with conn.cursor() as cur:
                try:
                    data = await load_medical_checklist(cur, user_entity_id, range_key)
                except ValueError as exc:
                    raise tornado.web.HTTPError(400, reason=str(exc)) from exc
        self.write_json({"success": True, "data": data})


class MedicalChecklistSaveHandler(ChatBaseHandler):
    async def post(self):
        user_entity_id = self.current_user_entity_id()
        range_key = str(self._param("range", "30d")).strip().lower() or "30d"
        selected_questions = self.json_body.get("selected_questions") or []
        custom_question = self.json_body.get("custom_question") or ""
        preview_text = self.json_body.get("preview_text") or ""

        if not isinstance(selected_questions, list):
            raise tornado.web.HTTPError(400, reason="selected_questions must be a JSON array")

        async with self.mysql.acquire() as conn:
            async with conn.cursor() as cur:
                await cur.execute("START TRANSACTION")
                try:
                    saved = await save_medical_checklist(
                        cur,
                        user_entity_id,
                        range_key,
                        selected_questions,
                        custom_question,
                        preview_text,
                    )
                    await cur.execute("COMMIT")
                except ValueError as exc:
                    await cur.execute("ROLLBACK")
                    raise tornado.web.HTTPError(400, reason=str(exc)) from exc
                except Exception:
                    await cur.execute("ROLLBACK")
                    raise
        self.write_json({"success": True, "data": saved})
