import hmac
import json
import re
import uuid

import tornado.web

from app.config import get_settings
from app.handlers.base import BaseHandler
from app.services.account import delete_mobile_account
from app.services.aliyun_sms import AliyunSmsService
from app.services.entities import get_or_create_mobile_entity
from app.services.security import raise_for_abuse


MOBILE_RE = re.compile(r"^\d{11}$")
CODE_RE = re.compile(r"^\d{4,8}$")
SESSION_COOKIE_NAME = "user_session"
SMS_LOG_MESSAGE_LIMIT = 4000


def _sms_log_message(message):
    if message is None:
        return None
    text = str(message)
    if len(text) <= SMS_LOG_MESSAGE_LIMIT:
        return text
    return text[:SMS_LOG_MESSAGE_LIMIT] + "...[truncated]"


def _is_app_review_mobile(settings, mobile):
    return (
        settings.app_review_login_enabled
        and MOBILE_RE.fullmatch(settings.app_review_mobile or "") is not None
        and CODE_RE.fullmatch(settings.app_review_code or "") is not None
        and hmac.compare_digest(mobile, settings.app_review_mobile)
    )


def _is_valid_app_review_code(settings, mobile, verify_code):
    return _is_app_review_mobile(settings, mobile) and hmac.compare_digest(
        verify_code,
        settings.app_review_code,
    )


class AuthBaseHandler(BaseHandler):
    def _param(self, name):
        value = self.json_body.get(name)
        if value is None:
            value = self.get_argument(name, None)
        return str(value or "").strip()

    def _mobile_param(self):
        mobile = self._param("mobile")
        if not MOBILE_RE.fullmatch(mobile):
            raise tornado.web.HTTPError(400, reason="mobile must be 11 digits")
        return mobile

    @property
    def sms_service(self):
        service = self.application.settings.get("aliyun_sms_service")
        if service is None:
            service = AliyunSmsService(get_settings())
            self.application.settings["aliyun_sms_service"] = service
        return service

    def _current_session(self):
        raw_session = self.get_signed_cookie(SESSION_COOKIE_NAME)
        if not raw_session:
            return None

        try:
            session = json.loads(raw_session.decode("utf-8") if isinstance(raw_session, bytes) else raw_session)
        except json.JSONDecodeError:
            self.clear_cookie(SESSION_COOKIE_NAME)
            return None

        block_id = str(session.get("block_id", ""))
        mobile = str(session.get("mobile", ""))
        login = str(session.get("login", ""))
        database = str(session.get("database", ""))
        if not block_id or not mobile or not login:
            self.clear_cookie(SESSION_COOKIE_NAME)
            return None

        return {
            "block_id": block_id,
            "mobile": mobile,
            "login": login,
            "database": database,
        }

    def _current_session_required(self):
        session = self._current_session()
        if not session:
            raise tornado.web.HTTPError(401, reason="login required")
        return session


class SendCodeHandler(AuthBaseHandler):
    async def post(self):
        mobile = self._mobile_param()
        decision = self.security_guard.check_sms_send(ip=self.client_ip, mobile=mobile)
        if not decision.allowed:
            await self.record_abuse(decision, user_id=f"mobile:{mobile}")
            raise_for_abuse(decision)

        out_id = uuid.uuid4().hex

        if _is_app_review_mobile(get_settings(), mobile):
            await self._record_send(mobile, out_id, True, "app review verification code requested", None)
            self.write_json(
                {
                    "success": True,
                    "mobile": mobile,
                    "out_id": out_id,
                    "request_id": None,
                }
            )
            return

        try:
            result = await self.sms_service.send_code(mobile, out_id)
        except Exception as exc:
            message = getattr(exc, "message", str(exc))
            await self._record_send(mobile, out_id, False, message, None)
            raise tornado.web.HTTPError(502, reason=f"aliyun send failed: {message}") from exc

        await self._record_send(
            mobile,
            out_id,
            result["success"],
            result.get("message"),
            result.get("request_id"),
        )
        if not result["success"]:
            raise tornado.web.HTTPError(502, reason=result.get("message") or "aliyun send failed")

        payload = {
            "success": True,
            "mobile": mobile,
            "out_id": out_id,
            "request_id": result.get("request_id"),
        }
        if result.get("verify_code"):
            payload["verify_code"] = result["verify_code"]
        self.write_json(payload)

    async def _record_send(self, mobile, out_id, success, message, request_id):
        async with self.mysql.acquire() as conn:
            async with conn.cursor() as cur:
                await cur.execute(
                    """
                    INSERT INTO helen.sms_verify_logs
                      (mobile, out_id, action, success, request_id, message)
                    VALUES (%s, %s, 'send', %s, %s, %s)
                    """,
                    (mobile, out_id, 1 if success else 0, request_id, _sms_log_message(message)),
                )


class LoginHandler(AuthBaseHandler):
    async def post(self):
        mobile = self._mobile_param()
        verify_code = self._param("code") or self._param("verify_code")
        if not CODE_RE.fullmatch(verify_code):
            raise tornado.web.HTTPError(400, reason="code must be 4-8 digits")

        out_id = self._param("out_id") or None
        settings = get_settings()
        if _is_app_review_mobile(settings, mobile):
            review_code_valid = _is_valid_app_review_code(settings, mobile, verify_code)
            check_result = {
                "success": review_code_valid,
                "message": "app review code accepted" if review_code_valid else "app review code invalid",
                "verify_result": "PASS" if review_code_valid else "FAIL",
            }
        else:
            try:
                check_result = await self.sms_service.check_code(mobile, verify_code, out_id)
            except Exception as exc:
                message = getattr(exc, "message", str(exc))
                await self._record_check(mobile, out_id, False, message, None)
                raise tornado.web.HTTPError(502, reason=f"aliyun check failed: {message}") from exc

        await self._record_check(
            mobile,
            out_id,
            check_result["success"],
            check_result.get("message"),
            check_result.get("verify_result"),
        )
        if not check_result["success"]:
            decision = self.security_guard.record_login_failure(mobile=mobile)
            if not decision.allowed:
                await self.record_abuse(decision, user_id=f"mobile:{mobile}")
                raise_for_abuse(decision)
            self.write_json({"data": "none", "message": check_result.get("message") or "verify code invalid"}, status=401)
            return

        async with self.mysql.acquire() as conn:
            async with conn.cursor() as cur:
                await cur.execute("START TRANSACTION")
                try:
                    entity = await get_or_create_mobile_entity(cur, mobile)
                    await cur.execute("COMMIT")
                except Exception:
                    await cur.execute("ROLLBACK")
                    raise

        payload = {
            "success": True,
            "mobile": mobile,
            "login": entity["login"],
            "block_id": entity["entity_id"],
            "database": entity["database"],
            "created": entity["created"],
            "data": entity["body"],
        }
        self._set_session_cookie(payload)
        self.write_json(payload)

    def _set_session_cookie(self, payload):
        cookie_payload = {
            "mobile": payload["mobile"],
            "login": payload["login"],
            "block_id": payload["block_id"],
            "database": payload["database"],
        }
        self.set_signed_cookie(
            SESSION_COOKIE_NAME,
            json.dumps(cookie_payload, separators=(",", ":")),
            expires_days=30,
            httponly=True,
            secure=get_settings().cookie_secure,
            samesite="Lax",
        )

    async def _record_check(self, mobile, out_id, success, message, verify_result):
        async with self.mysql.acquire() as conn:
            async with conn.cursor() as cur:
                await cur.execute(
                    """
                    INSERT INTO helen.sms_verify_logs
                      (mobile, out_id, action, success, message, verify_result)
                    VALUES (%s, %s, 'check', %s, %s, %s)
                    """,
                    (
                        mobile,
                        out_id,
                        1 if success else 0,
                        _sms_log_message(message),
                        None if verify_result is None else str(verify_result),
                    ),
                )


class CheckLoginHandler(AuthBaseHandler):
    async def get(self):
        await self._handle()

    async def post(self):
        await self._handle()

    async def _handle(self):
        session = self._current_session()
        if not session:
            self.write_json({"logged_in": False, "data": "none"})
            return

        self.write_json(
            {
                "logged_in": True,
                "mobile": session["mobile"],
                "login": session["login"],
                "block_id": session["block_id"],
                "database": session["database"],
            }
        )


class AccountDeletionHandler(AuthBaseHandler):
    async def delete(self):
        session = self._current_session_required()
        async with self.mysql.acquire() as conn:
            async with conn.cursor() as cur:
                await cur.execute("START TRANSACTION")
                try:
                    result = await delete_mobile_account(cur, session["mobile"], session["block_id"])
                    await cur.execute("COMMIT")
                except Exception:
                    await cur.execute("ROLLBACK")
                    raise

        self.clear_cookie(SESSION_COOKIE_NAME)
        self.write_json(result)
