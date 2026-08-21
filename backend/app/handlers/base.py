import ipaddress
import json

import tornado.web

from app.config import get_settings
from app.services.security import SecurityGuard, record_abuse_event, raise_for_abuse


LOCAL_DEBUG_USER_ENTITY_ID = "1" * 32


def is_loopback_ip(value):
    try:
        return ipaddress.ip_address(str(value or "").strip()).is_loopback
    except ValueError:
        return False


class BaseHandler(tornado.web.RequestHandler):
    @property
    def mysql(self):
        return self.application.settings["mysql_pool"]

    @property
    def security_guard(self):
        guard = self.application.settings.get("security_guard")
        if guard is None:
            guard = SecurityGuard(get_settings())
            self.application.settings["security_guard"] = guard
        return guard

    @property
    def client_ip(self):
        return self.request.remote_ip or ""

    @property
    def is_local_debug_request(self):
        return get_settings().debug and is_loopback_ip(self.client_ip)

    @property
    def local_debug_user_entity_id(self):
        return LOCAL_DEBUG_USER_ENTITY_ID

    async def prepare(self):
        decision = self.security_guard.check_request(
            ip=self.client_ip,
            method=self.request.method,
            path=self.request.path,
            body_size=len(self.request.body or b""),
        )
        if not decision.allowed:
            await self.record_abuse(decision)
            raise_for_abuse(decision)

        if self.request.body and self.request.headers.get("Content-Type", "").startswith("application/json"):
            try:
                self.json_body = json.loads(self.request.body.decode("utf-8"))
            except json.JSONDecodeError as exc:
                raise tornado.web.HTTPError(400, reason=f"Invalid JSON: {exc.msg}") from exc
        else:
            self.json_body = {}

    async def record_abuse(self, decision, *, user_id=None):
        if not get_settings().security_audit_enabled:
            return
        async with self.mysql.acquire() as conn:
            async with conn.cursor() as cur:
                await record_abuse_event(
                    cur,
                    ip=self.client_ip,
                    path=self.request.path,
                    user_id=user_id,
                    category=decision.category,
                    reason=decision.reason,
                    metadata=decision.metadata,
                )

    def write_json(self, payload, status=200):
        self.set_status(status)
        self.set_header("Content-Type", "application/json; charset=utf-8")
        self.write(json.dumps(payload, ensure_ascii=False))

    def write_error(self, status_code, **kwargs):
        reason = self._reason
        if "exc_info" in kwargs and kwargs["exc_info"]:
            exc = kwargs["exc_info"][1]
            reason = getattr(exc, "reason", reason)
        self.write_json({"error": reason, "status": status_code}, status=status_code)
