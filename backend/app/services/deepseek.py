import json
import re

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

    async def complete(self, messages, *, max_tokens=None, temperature=0.7, response_format=None):
        if not self.api_key:
            raise DeepSeekError("DEEPSEEK_API_KEY is not configured")

        payload = {
            "model": self.model,
            "messages": messages,
            "max_tokens": max_tokens or self.max_tokens,
            "temperature": temperature,
            "stream": False,
        }
        if response_format is not None:
            payload["response_format"] = response_format

        request = HTTPRequest(
            url=f"{self.base_url}/chat/completions",
            method="POST",
            headers={
                "Authorization": f"Bearer {self.api_key}",
                "Content-Type": "application/json",
            },
            body=json.dumps(payload, ensure_ascii=False).encode("utf-8"),
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
        choice = choices[0]
        message = choice.get("message") or {}
        content = str(message.get("content") or "").strip()
        if not content:
            raise DeepSeekError("DeepSeek response content is empty")
        content = _strip_markdown_bold(content)
        return {
            "content": content,
            "model": payload.get("model") or self.model,
            "usage": payload.get("usage") or {},
            "finish_reason": choice.get("finish_reason"),
        }


def _strip_markdown_bold(content):
    text = str(content or "")
    text = re.sub(r"\*\*(.*?)\*\*", r"\1", text, flags=re.DOTALL)
    text = re.sub(r"__(.*?)__", r"\1", text, flags=re.DOTALL)
    text = text.replace("**", "").replace("__", "")
    return text.strip()
