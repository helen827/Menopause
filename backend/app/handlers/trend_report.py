import tornado.web

from app.handlers.chat import ChatBaseHandler
from app.services.medical_checklist import load_medical_checklist, save_medical_checklist
from app.services.trend_report import ensure_trend_report_block, save_trend_report_range


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
        self.write_json({"success": True, "data": data})


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
