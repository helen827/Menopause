import json

import tornado.web


class BaseHandler(tornado.web.RequestHandler):
    @property
    def mysql(self):
        return self.application.settings["mysql_pool"]

    def prepare(self):
        if self.request.body and self.request.headers.get("Content-Type", "").startswith("application/json"):
            try:
                self.json_body = json.loads(self.request.body.decode("utf-8"))
            except json.JSONDecodeError as exc:
                raise tornado.web.HTTPError(400, reason=f"Invalid JSON: {exc.msg}") from exc
        else:
            self.json_body = {}

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
