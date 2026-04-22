# -*- coding: utf-8 -*-
import json
import logging
import os
import importlib.util

from credentials.settings.production import *  # pylint: disable=wildcard-import,unused-wildcard-import
from credentials.settings.utils import get_logger_config


def _parse_sentry_rate(env_key, default=0.0):
    raw = (os.environ.get(env_key, "") or "").strip()
    if not raw:
        return default
    try:
        return float(raw)
    except ValueError:
        logging.getLogger(__name__).warning("Invalid %s=%r, defaulting to %.2f", env_key, raw, default)
        return default


def _parse_sentry_bool(env_key, default=False):
    raw = (os.environ.get(env_key, "") or "").strip().lower()
    if not raw:
        return default
    return raw in {"1", "true", "yes", "on"}


def _init_sentry(service_name):
    dsn = (os.environ.get("SENTRY_DSN", "") or "").strip()
    if not dsn:
        return
    try:
        import sentry_sdk
    except ImportError:
        logging.getLogger(__name__).warning(
            "SENTRY_DSN is set but sentry_sdk is not installed; skipping Sentry init for %s",
            service_name,
        )
        return

    sentry_sdk.init(
        dsn=dsn,
        environment=(os.environ.get("SENTRY_ENVIRONMENT") or os.environ.get("LOGGING_ENV") or "production"),
        release=(os.environ.get("SENTRY_RELEASE") or None),
        traces_sample_rate=_parse_sentry_rate("SENTRY_TRACES_SAMPLE_RATE", 0.0),
        profiles_sample_rate=_parse_sentry_rate("SENTRY_PROFILES_SAMPLE_RATE", 0.0),
        send_default_pii=_parse_sentry_bool("SENTRY_SEND_DEFAULT_PII", False),
    )
    sentry_sdk.set_tag("service", service_name)


MEREKA_SCHEME = os.environ.get("MEREKA_SCHEME", "https")
MEREKA_LMS_DOMAIN = os.environ.get("MEREKA_LMS_DOMAIN", "academyv2.mereka.io")
MEREKA_MFE_DOMAIN = os.environ.get("MEREKA_MFE_DOMAIN", f"apps.{MEREKA_LMS_DOMAIN}")
MEREKA_CREDENTIALS_DOMAIN = os.environ.get(
    "MEREKA_CREDENTIALS_DOMAIN",
    f"credentials.{MEREKA_LMS_DOMAIN}",
)
MEREKA_BIJI_BIJI_CREDENTIALS_DOMAIN = os.environ.get(
    "MEREKA_BIJI_BIJI_CREDENTIALS_DOMAIN",
    "credentials.academy.biji-biji.com",
)
MEREKA_SOF_CREDENTIALS_DOMAIN = os.environ.get(
    "MEREKA_SOF_CREDENTIALS_DOMAIN",
    "credentials.skillourfuture.academyv2.mereka.io",
)

LMS_BASE_URL = os.environ.get("LMS_BASE_URL", f"{MEREKA_SCHEME}://{MEREKA_LMS_DOMAIN}")
LMS_INTERNAL_URL = os.environ.get("LMS_INTERNAL_URL", "http://lms:8000")

SECRET_KEY = os.environ.get("CREDENTIALS_SECRET_KEY", "")
ALLOWED_HOSTS = [
    MEREKA_CREDENTIALS_DOMAIN,
    MEREKA_BIJI_BIJI_CREDENTIALS_DOMAIN,
    MEREKA_SOF_CREDENTIALS_DOMAIN,
    "credentials",
    "CREDENTIALS",
]
PLATFORM_NAME = os.environ.get("PLATFORM_NAME", "Mereka Academy")
PROTOCOL = MEREKA_SCHEME

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
ENABLE_VERIFIABLE_CREDENTIALS = True

# Verifiable Credentials Configuration (CRED-020)
VERIFIABLE_CREDENTIALS = {
    "ISSUER_DID": f"did:web:{MEREKA_CREDENTIALS_DOMAIN}",
    "ISSUER_NAME": PLATFORM_NAME,
    "SIGNATURE_SUITE": "Ed25519Signature2020",
    "SIGNING_KEY_ID": f"did:web:{MEREKA_CREDENTIALS_DOMAIN}#key-1",
    "DID_DOCUMENT_URL": f"{MEREKA_SCHEME}://{MEREKA_CREDENTIALS_DOMAIN}/.well-known/did.json",
    "REVOCATION_ENABLED": False,
}

# Ed25519 signing key (base64-encoded private key, synced from Infisical)
VC_SIGNING_PRIVATE_KEY = os.environ.get("VC_SIGNING_PRIVATE_KEY", "")

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
_init_sentry("credentials")

# Verifiable Credentials issuer app (DID document endpoint)
import sys
sys.path.insert(0, '/openedx')
_vc_issuer_spec = importlib.util.find_spec('credentials_vc_issuer')
if _vc_issuer_spec is not None:
    if 'credentials_vc_issuer' not in INSTALLED_APPS:
        INSTALLED_APPS.append('credentials_vc_issuer')
else:
    logging.getLogger(__name__).warning(
        "credentials_vc_issuer package is not installed; disabling verifiable credentials issuer wiring"
    )
    ENABLE_VERIFIABLE_CREDENTIALS = False

# Hardening: platform admin enforcement + /admin/login -> /login redirect.
MIDDLEWARE = list(MIDDLEWARE) + [
    "credentials.settings.tutor.mereka_platform_admin.MerekaPlatformAdminMiddleware",
]
