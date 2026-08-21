import os
from dataclasses import dataclass
from functools import lru_cache

from dotenv import load_dotenv


load_dotenv()


def _bool_env(name: str, default: bool = False) -> bool:
    value = os.getenv(name)
    if value is None:
        return default
    return value.strip().lower() in {"1", "true", "yes", "on"}


@dataclass(frozen=True)
class Settings:
    app_port: int = int(os.getenv("APP_PORT", "8888"))
    app_host: str = os.getenv("APP_HOST", "127.0.0.1")
    debug: bool = _bool_env("DEBUG", True)
    cookie_secret: str = os.getenv("COOKIE_SECRET", "dev-cookie-secret-change-me")
    cookie_secure: bool = _bool_env("COOKIE_SECURE", not _bool_env("DEBUG", True))

    mysql_host: str = os.getenv("MYSQL_HOST", "127.0.0.1")
    mysql_port: int = int(os.getenv("MYSQL_PORT", "3306"))
    mysql_user: str = os.getenv("MYSQL_USER", "root")
    mysql_password: str = os.getenv("MYSQL_PASSWORD", "")
    mysql_database: str = os.getenv("MYSQL_DATABASE", "menopause_xia")
    mysql_pool_min_size: int = int(os.getenv("MYSQL_POOL_MIN_SIZE", "1"))
    mysql_pool_max_size: int = int(os.getenv("MYSQL_POOL_MAX_SIZE", "5"))

    aliyun_dypns_endpoint: str = os.getenv("ALIYUN_DYPNS_ENDPOINT", "dypnsapi.aliyuncs.com")
    aliyun_sms_country_code: str = os.getenv("ALIYUN_SMS_COUNTRY_CODE", "86")
    aliyun_sms_scheme_name: str = os.getenv("ALIYUN_SMS_SCHEME_NAME", "")
    aliyun_sms_sign_name: str = os.getenv("ALIYUN_SMS_SIGN_NAME", "")
    aliyun_sms_template_code: str = os.getenv("ALIYUN_SMS_TEMPLATE_CODE", "")
    aliyun_sms_template_param: str = os.getenv("ALIYUN_SMS_TEMPLATE_PARAM", "")
    aliyun_sms_code_length: int = int(os.getenv("ALIYUN_SMS_CODE_LENGTH", "6"))
    aliyun_sms_code_type: int = int(os.getenv("ALIYUN_SMS_CODE_TYPE", "1"))
    aliyun_sms_valid_time: int = int(os.getenv("ALIYUN_SMS_VALID_TIME", "300"))
    aliyun_sms_interval: int = int(os.getenv("ALIYUN_SMS_INTERVAL", "60"))
    aliyun_sms_return_verify_code: bool = _bool_env("ALIYUN_SMS_RETURN_VERIFY_CODE", False)
    aliyun_sms_mock: bool = _bool_env("ALIYUN_SMS_MOCK", False)

    app_review_login_enabled: bool = _bool_env("APP_REVIEW_LOGIN_ENABLED", False)
    app_review_mobile: str = os.getenv("APP_REVIEW_MOBILE", "")
    app_review_code: str = os.getenv("APP_REVIEW_CODE", "")

    deepseek_api_key: str = os.getenv("DEEPSEEK_API_KEY", "")
    deepseek_base_url: str = os.getenv("DEEPSEEK_BASE_URL", "https://api.deepseek.com")
    deepseek_model: str = os.getenv("DEEPSEEK_MODEL", "deepseek-chat")
    deepseek_max_history: int = int(os.getenv("DEEPSEEK_MAX_HISTORY", "40"))
    deepseek_max_tokens: int = int(os.getenv("DEEPSEEK_MAX_TOKENS", "3000"))

    security_enabled: bool = _bool_env("SECURITY_ENABLED", True)
    security_audit_enabled: bool = _bool_env("SECURITY_AUDIT_ENABLED", True)
    security_max_json_body_bytes: int = int(os.getenv("SECURITY_MAX_JSON_BODY_BYTES", "65536"))
    security_general_window_seconds: int = int(os.getenv("SECURITY_GENERAL_WINDOW_SECONDS", "60"))
    security_general_max_requests: int = int(os.getenv("SECURITY_GENERAL_MAX_REQUESTS", "120"))
    security_sms_window_seconds: int = int(os.getenv("SECURITY_SMS_WINDOW_SECONDS", "3600"))
    security_sms_ip_max_requests: int = int(os.getenv("SECURITY_SMS_IP_MAX_REQUESTS", "10"))
    security_sms_mobile_max_requests: int = int(os.getenv("SECURITY_SMS_MOBILE_MAX_REQUESTS", "5"))
    security_login_window_seconds: int = int(os.getenv("SECURITY_LOGIN_WINDOW_SECONDS", "3600"))
    security_login_mobile_max_failures: int = int(os.getenv("SECURITY_LOGIN_MOBILE_MAX_FAILURES", "8"))
    security_chat_window_seconds: int = int(os.getenv("SECURITY_CHAT_WINDOW_SECONDS", "60"))
    security_chat_user_max_requests: int = int(os.getenv("SECURITY_CHAT_USER_MAX_REQUESTS", "20"))
    security_ai_window_seconds: int = int(os.getenv("SECURITY_AI_WINDOW_SECONDS", "86400"))
    security_ai_user_max_requests: int = int(os.getenv("SECURITY_AI_USER_MAX_REQUESTS", "30"))
    security_chat_max_content_chars: int = int(os.getenv("SECURITY_CHAT_MAX_CONTENT_CHARS", "2000"))


@lru_cache
def get_settings() -> Settings:
    return Settings()
