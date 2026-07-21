import json
import logging
import re
import threading
import time
from collections import defaultdict, deque
from dataclasses import dataclass, field

import tornado.web


LOGGER = logging.getLogger(__name__)


@dataclass(frozen=True)
class AbuseDecision:
    allowed: bool
    reason: str = ""
    status: int = 403
    category: str = "abuse"
    metadata: dict = field(default_factory=dict)


class SlidingWindowLimiter:
    def __init__(self):
        self._events = defaultdict(deque)
        self._lock = threading.Lock()

    def hit(self, key, *, limit, window_seconds):
        now = time.monotonic()
        cutoff = now - window_seconds
        with self._lock:
            bucket = self._events[key]
            while bucket and bucket[0] <= cutoff:
                bucket.popleft()
            if len(bucket) >= limit:
                retry_after = max(1, int(window_seconds - (now - bucket[0])))
                return False, retry_after
            bucket.append(now)
            return True, 0


class SecurityGuard:
    PROMPT_ATTACK_PATTERNS = [
        re.compile(pattern, re.IGNORECASE)
        for pattern in [
            r"\b(ignore|bypass|override)\b.{0,80}\b(previous|prior|system|developer)\b.{0,80}\b(instruction|prompt|rule)s?\b",
            r"\b(system|developer)\s+prompt\b",
            r"\breveal\b.{0,80}\b(prompt|instruction|secret|api[_ -]?key|token)\b",
            r"\bjailbreak\b",
            r"DAN\s+mode",
            r"忽略.{0,40}(以上|之前|系统|开发者).{0,40}(指令|规则|提示词)",
            r"(泄露|透露|输出|展示).{0,40}(系统提示词|开发者指令|密钥|token|api key)",
            r"越狱",
        ]
    ]
    AUTOMATION_SPAM_PATTERNS = [
        re.compile(pattern, re.IGNORECASE)
        for pattern in [
            r"(.)\1{80,}",
            r"https?://\S+(\s+https?://\S+){4,}",
            r"[\w.+-]+@[\w.-]+(\s*,?\s*[\w.+-]+@[\w.-]+){5,}",
        ]
    ]

    def __init__(self, settings):
        self.settings = settings
        self.general_limiter = SlidingWindowLimiter()
        self.sms_ip_limiter = SlidingWindowLimiter()
        self.sms_mobile_limiter = SlidingWindowLimiter()
        self.login_mobile_failure_limiter = SlidingWindowLimiter()
        self.chat_user_limiter = SlidingWindowLimiter()
        self.ai_user_limiter = SlidingWindowLimiter()

    def check_request(self, *, ip, method, path, body_size):
        if not self.settings.security_enabled:
            return AbuseDecision(True)
        if body_size > self.settings.security_max_json_body_bytes:
            return AbuseDecision(
                False,
                "request body too large",
                status=413,
                category="request_body_too_large",
                metadata={"body_size": body_size, "limit": self.settings.security_max_json_body_bytes},
            )
        if not path.startswith("/api/"):
            return AbuseDecision(True)
        allowed, retry_after = self.general_limiter.hit(
            f"general:{ip}",
            limit=self.settings.security_general_max_requests,
            window_seconds=self.settings.security_general_window_seconds,
        )
        if not allowed:
            return AbuseDecision(
                False,
                "too many requests",
                status=429,
                category="rate_limit",
                metadata={"retry_after": retry_after, "scope": "general", "method": method, "path": path},
            )
        return AbuseDecision(True)

    def check_sms_send(self, *, ip, mobile):
        if not self.settings.security_enabled:
            return AbuseDecision(True)
        ip_allowed, ip_retry_after = self.sms_ip_limiter.hit(
            f"sms-ip:{ip}",
            limit=self.settings.security_sms_ip_max_requests,
            window_seconds=self.settings.security_sms_window_seconds,
        )
        if not ip_allowed:
            return AbuseDecision(
                False,
                "too many verification code requests",
                status=429,
                category="sms_rate_limit_ip",
                metadata={"retry_after": ip_retry_after},
            )

        mobile_allowed, mobile_retry_after = self.sms_mobile_limiter.hit(
            f"sms-mobile:{mobile}",
            limit=self.settings.security_sms_mobile_max_requests,
            window_seconds=self.settings.security_sms_window_seconds,
        )
        if not mobile_allowed:
            return AbuseDecision(
                False,
                "too many verification code requests for this mobile",
                status=429,
                category="sms_rate_limit_mobile",
                metadata={"retry_after": mobile_retry_after},
            )
        return AbuseDecision(True)

    def record_login_failure(self, *, mobile):
        if not self.settings.security_enabled:
            return AbuseDecision(True)
        allowed, retry_after = self.login_mobile_failure_limiter.hit(
            f"login-fail:{mobile}",
            limit=self.settings.security_login_mobile_max_failures,
            window_seconds=self.settings.security_login_window_seconds,
        )
        if not allowed:
            return AbuseDecision(
                False,
                "too many failed login attempts",
                status=429,
                category="login_failure_limit",
                metadata={"retry_after": retry_after},
            )
        return AbuseDecision(True)

    def check_chat_submit(self, *, user_id, ip, content, ask_ai):
        if not self.settings.security_enabled:
            return AbuseDecision(True)
        content = content or ""
        if len(content) > self.settings.security_chat_max_content_chars:
            return AbuseDecision(
                False,
                "message is too long",
                status=413,
                category="chat_content_too_long",
                metadata={"length": len(content), "limit": self.settings.security_chat_max_content_chars},
            )
        text_decision = self.inspect_text(content)
        if not text_decision.allowed:
            return text_decision

        allowed, retry_after = self.chat_user_limiter.hit(
            f"chat:{user_id or ip}",
            limit=self.settings.security_chat_user_max_requests,
            window_seconds=self.settings.security_chat_window_seconds,
        )
        if not allowed:
            return AbuseDecision(
                False,
                "too many chat messages",
                status=429,
                category="chat_rate_limit",
                metadata={"retry_after": retry_after},
            )

        if ask_ai:
            ai_allowed, ai_retry_after = self.ai_user_limiter.hit(
                f"ai:{user_id or ip}",
                limit=self.settings.security_ai_user_max_requests,
                window_seconds=self.settings.security_ai_window_seconds,
            )
            if not ai_allowed:
                return AbuseDecision(
                    False,
                    "daily AI usage limit reached",
                    status=429,
                    category="ai_daily_limit",
                    metadata={"retry_after": ai_retry_after},
                )

        return AbuseDecision(True)

    def inspect_text(self, text):
        for pattern in self.PROMPT_ATTACK_PATTERNS:
            if pattern.search(text):
                return AbuseDecision(
                    False,
                    "message looks like prompt-injection abuse",
                    status=403,
                    category="prompt_injection",
                    metadata={"pattern": pattern.pattern},
                )
        for pattern in self.AUTOMATION_SPAM_PATTERNS:
            if pattern.search(text):
                return AbuseDecision(
                    False,
                    "message looks like automated spam",
                    status=403,
                    category="automation_spam",
                    metadata={"pattern": pattern.pattern},
                )
        return AbuseDecision(True)


async def record_abuse_event(cur, *, ip, path, user_id, category, reason, metadata=None):
    try:
        await cur.execute(
            """
            INSERT INTO helen.abuse_events
              (client_ip, path, user_entity_id, category, reason, metadata_json)
            VALUES (%s, %s, %s, %s, %s, %s)
            """,
            (
                ip,
                path,
                user_id,
                category,
                reason,
                None if metadata is None else json.dumps(metadata, ensure_ascii=False),
            ),
        )
    except Exception:
        LOGGER.exception("failed to record abuse event")


def raise_for_abuse(decision):
    if decision.allowed:
        return
    error = tornado.web.HTTPError(decision.status, reason=decision.reason)
    error.abuse_decision = decision
    raise error
