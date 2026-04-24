# -*- coding: utf-8 -*-
import json
import os

from credentials.settings.devstack import *  # pylint: disable=wildcard-import,unused-wildcard-import
from credentials.settings.utils import get_logger_config

MEREKA_SCHEME = os.environ.get("MEREKA_SCHEME", "https")
MEREKA_LMS_DOMAIN = os.environ.get("MEREKA_LMS_DOMAIN", "academyv2.mereka.io")
MEREKA_MFE_DOMAIN = os.environ.get("MEREKA_MFE_DOMAIN", f"apps.{MEREKA_LMS_DOMAIN}")
MEREKA_CREDENTIALS_DOMAIN = os.environ.get(
    "MEREKA_CREDENTIALS_DOMAIN",
    f"credentials.{MEREKA_LMS_DOMAIN}",
)

LMS_BASE_URL = os.environ.get("LMS_BASE_URL", f"{MEREKA_SCHEME}://{MEREKA_LMS_DOMAIN}")
LMS_INTERNAL_URL = os.environ.get("LMS_INTERNAL_URL", "http://lms:8000")

SECRET_KEY = os.environ.get("CREDENTIALS_SECRET_KEY", "")
ALLOWED_HOSTS = [
    MEREKA_CREDENTIALS_DOMAIN,
    "credentials",
    "CREDENTIALS",
]
PLATFORM_NAME = os.environ.get("PLATFORM_NAME", "Mereka Academy")
PROTOCOL = MEREKA_SCHEME
FAVICON_URL = f"{LMS_BASE_URL}/favicon.ico"

CORS_ALLOW_CREDENTIALS = True
CORS_ORIGIN_WHITELIST = list(CORS_ORIGIN_WHITELIST) + [
    f"{MEREKA_SCHEME}://{MEREKA_MFE_DOMAIN}",
]
CSRF_TRUSTED_ORIGINS = [f"{MEREKA_SCHEME}://{MEREKA_MFE_DOMAIN}"]

LEARNER_RECORD_MFE_RECORDS_PAGE_URL = (
    f"{MEREKA_SCHEME}://{MEREKA_MFE_DOMAIN}/learner-record/"
)

SOCIAL_AUTH_REDIRECT_IS_HTTPS = MEREKA_SCHEME == "https"
SOCIAL_AUTH_EDX_OAUTH2_ISSUER = LMS_BASE_URL
SOCIAL_AUTH_EDX_OAUTH2_URL_ROOT = LMS_INTERNAL_URL
SOCIAL_AUTH_EDX_OAUTH2_PUBLIC_URL_ROOT = LMS_BASE_URL
SOCIAL_AUTH_EDX_OAUTH2_LOGOUT_URL = f"{LMS_BASE_URL}/logout"
SOCIAL_AUTH_EDX_OAUTH2_KEY = os.environ.get(
    "CREDENTIALS_OAUTH2_KEY_SSO",
    "credentials-key-sso",
)
SOCIAL_AUTH_EDX_OAUTH2_SECRET = os.environ.get(
    "CREDENTIALS_SSO_OAUTH2_SECRET",
    "",
)

BACKEND_SERVICE_EDX_OAUTH2_KEY = os.environ.get(
    "CREDENTIALS_OAUTH2_KEY",
    "credentials-key",
)
BACKEND_SERVICE_EDX_OAUTH2_SECRET = os.environ.get(
    "CREDENTIALS_BACKEND_OAUTH2_SECRET",
    "",
)
BACKEND_SERVICE_EDX_OAUTH2_PROVIDER_URL = f"{LMS_INTERNAL_URL}/oauth2"

EDX_DRF_EXTENSIONS = {
    "OAUTH2_USER_INFO_URL": f"{LMS_INTERNAL_URL}/oauth2/user_info",
}

DATABASES = {
    "default": {
        "ENGINE": "django.db.backends.mysql",
        "NAME": "credentials",
        "USER": "credentials",
        "PASSWORD": (os.environ.get("MYSQL_CREDENTIALS_PASSWORD", "") or "").rstrip("\r\n"),
        "HOST": "mysql",
        "PORT": "3306",
        "OPTIONS": {
            "init_command": "SET sql_mode='STRICT_TRANS_TABLES'",
        },
    }
}

EMAIL_BACKEND = "django.core.mail.backends.smtp.EmailBackend"
EMAIL_HOST = os.environ.get("SMTP_HOST", "smtp")
EMAIL_PORT = os.environ.get("SMTP_PORT", "8025")
EMAIL_HOST_USER = os.environ.get("SMTP_USERNAME", "")
EMAIL_HOST_PASSWORD = os.environ.get("SMTP_PASSWORD", "")
EMAIL_USE_TLS = os.environ.get("SMTP_USE_TLS", "false").lower() == "true"

USE_LEARNER_RECORD_MFE = True
ENABLE_VERIFIABLE_CREDENTIALS = False
USE_API_CACHING = False

JWT_AUTH["JWT_ISSUER"] = f"{LMS_BASE_URL}/oauth2"
JWT_AUTH["JWT_AUDIENCE"] = "openedx"
# Credentials verifies JWT tokens signed by LMS, so it must use the LMS secret key.
JWT_AUTH["JWT_SECRET_KEY"] = os.environ.get("JWT_SECRET_KEY_LMS", os.environ.get("JWT_SECRET_KEY_CREDENTIALS", ""))
# Derive the public JWK from the LMS private key so they never drift.
_jwt_priv_jwk_raw = os.environ.get("JWT_PRIVATE_SIGNING_JWK", "")
if _jwt_priv_jwk_raw:
    try:
        _priv_jwk = json.loads(_jwt_priv_jwk_raw) if isinstance(_jwt_priv_jwk_raw, str) else _jwt_priv_jwk_raw
        _pub_jwk = {
            "kid": _priv_jwk.get("kid", "openedx"),
            "kty": "RSA",
            "e": _priv_jwk["e"],
            "n": _priv_jwk["n"],
        }
        JWT_AUTH["JWT_PUBLIC_SIGNING_JWK_SET"] = json.dumps({"keys": [_pub_jwk]})
    except Exception:
        JWT_AUTH["JWT_PUBLIC_SIGNING_JWK_SET"] = json.dumps({"keys": []})
else:
    JWT_AUTH["JWT_PUBLIC_SIGNING_JWK_SET"] = json.dumps({"keys": []})
JWT_AUTH["JWT_ISSUERS"] = [
    {
        "ISSUER": f"{LMS_BASE_URL}/oauth2",
        "AUDIENCE": "openedx",
        "SECRET_KEY": os.environ.get("JWT_SECRET_KEY_LMS", os.environ.get("JWT_SECRET_KEY_CREDENTIALS", "")),
    }
]

LOGGING = get_logger_config(debug=False, dev_env=True, local_loglevel="INFO")
LOGGING["handlers"].pop("local", None)
for logger in LOGGING["loggers"].values():
    if "local" in logger["handlers"]:
        logger["handlers"].remove("local")
