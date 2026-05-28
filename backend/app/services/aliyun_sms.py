import json

from alibabacloud_credentials.client import Client as CredentialClient
from alibabacloud_dypnsapi20170525.client import Client as DypnsapiClient
from alibabacloud_dypnsapi20170525 import models as dypns_models
from alibabacloud_tea_openapi import models as open_api_models
from alibabacloud_tea_util import models as util_models


class AliyunSmsService:
    def __init__(self, settings):
        self.settings = settings
        self._client = None

    def _create_client(self):
        credential = CredentialClient()
        config = open_api_models.Config(credential=credential)
        config.endpoint = self.settings.aliyun_dypns_endpoint
        return DypnsapiClient(config)

    @property
    def client(self):
        if self._client is None:
            self._client = self._create_client()
        return self._client

    async def send_code(self, mobile, out_id):
        if self.settings.aliyun_sms_mock:
            return {
                "success": True,
                "code": "OK",
                "message": "mock send success",
                "request_id": out_id,
                "biz_id": out_id,
                "verify_code": "123456" if self.settings.aliyun_sms_return_verify_code else None,
                "raw": {"mock": True},
            }

        request = dypns_models.SendSmsVerifyCodeRequest(
            phone_number=mobile,
            scheme_name=self._scheme_name(),
            sign_name=self.settings.aliyun_sms_sign_name or None,
            template_code=self.settings.aliyun_sms_template_code or None,
            template_param=self._template_param(),
        )
        runtime = util_models.RuntimeOptions()
        response = await self.client.send_sms_verify_code_with_options_async(request, runtime)
        body = response.body
        model = getattr(body, "model", None)
        return {
            "success": bool(getattr(body, "success", False)),
            "code": getattr(body, "code", None),
            "message": getattr(body, "message", None),
            "request_id": getattr(body, "request_id", None),
            "biz_id": getattr(model, "biz_id", None),
            "verify_code": getattr(model, "verify_code", None),
            "raw": body.to_map() if hasattr(body, "to_map") else {},
        }

    async def check_code(self, mobile, verify_code, out_id=None):
        if self.settings.aliyun_sms_mock:
            success = verify_code == "123456"
            return {
                "success": success,
                "code": "OK" if success else "InvalidVerifyCode",
                "message": "mock check success" if success else "mock check failed",
                "verify_result": success,
                "raw": {"mock": True},
            }

        request = dypns_models.CheckSmsVerifyCodeRequest(
            phone_number=mobile,
            verify_code=verify_code,
            scheme_name=self._scheme_name(),
        )
        runtime = util_models.RuntimeOptions()
        response = await self.client.check_sms_verify_code_with_options_async(request, runtime)
        body = response.body
        model = getattr(body, "model", None)
        verify_result = getattr(model, "verify_result", None)
        return {
            "success": bool(getattr(body, "success", False)) and self._verify_result_ok(verify_result),
            "code": getattr(body, "code", None),
            "message": getattr(body, "message", None),
            "verify_result": verify_result,
            "raw": body.to_map() if hasattr(body, "to_map") else {},
        }

    @staticmethod
    def _verify_result_ok(value):
        if isinstance(value, bool):
            return value
        if value is None:
            return True
        return str(value).lower() in {"true", "success", "pass", "ok", "1"}

    def _template_param(self):
        if self.settings.aliyun_sms_template_param:
            return self.settings.aliyun_sms_template_param
        minutes = max(1, self.settings.aliyun_sms_valid_time // 60)
        return json.dumps({"code": "##code##", "min": str(minutes)}, separators=(",", ":"))

    def _scheme_name(self):
        scheme_name = self.settings.aliyun_sms_scheme_name or None
        if scheme_name and len(scheme_name) > 20:
            raise ValueError("ALIYUN_SMS_SCHEME_NAME must be 20 characters or fewer")
        return scheme_name
