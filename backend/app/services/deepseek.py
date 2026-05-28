import json

import certifi
from tornado.httpclient import AsyncHTTPClient, HTTPError, HTTPRequest


class DeepSeekError(Exception):
    pass


class DeepSeekService:
    def __init__(self, settings):
        self.api_key = settings.deepseek_api_key
        self.base_url = settings.deepseek_base_url.rstrip("/")
        self.model = settings.deepseek_model
        self.max_tokens = settings.deepseek_max_tokens

    async def complete(self, messages):
        if not self.api_key:
            raise DeepSeekError("DEEPSEEK_API_KEY is not configured")

        request = HTTPRequest(
            url=f"{self.base_url}/chat/completions",
            method="POST",
            headers={
                "Authorization": f"Bearer {self.api_key}",
                "Content-Type": "application/json",
            },
            body=json.dumps(
                {
                    "model": self.model,
                    "messages": messages,
                    "max_tokens": self.max_tokens,
                    "temperature": 0.7,
                    "stream": False,
                },
                ensure_ascii=False,
            ).encode("utf-8"),
            ca_certs=certifi.where(),
            request_timeout=60,
        )

        try:
            response = await AsyncHTTPClient().fetch(request)
        except HTTPError as exc:
            detail = exc.response.body.decode("utf-8", errors="replace") if exc.response and exc.response.body else str(exc)
            raise DeepSeekError(f"DeepSeek request failed: {detail}") from exc

        payload = json.loads(response.body.decode("utf-8"))
        choices = payload.get("choices") or []
        if not choices:
            raise DeepSeekError("DeepSeek response has no choices")
        message = choices[0].get("message") or {}
        content = str(message.get("content") or "").strip()
        if not content:
            raise DeepSeekError("DeepSeek response content is empty")
        return {
            "content": content,
            "model": payload.get("model") or self.model,
            "usage": payload.get("usage") or {},
        }
