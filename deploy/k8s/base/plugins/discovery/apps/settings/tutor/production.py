from ..production import *
import logging
import os
import json


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
LMS_BASE_URL = os.environ.get("LMS_BASE_URL", f"{MEREKA_SCHEME}://{MEREKA_LMS_DOMAIN}")
LMS_INTERNAL_URL = os.environ.get("LMS_INTERNAL_URL", "http://lms:8000")
LMS_OAUTH2_ISSUER = f"{LMS_BASE_URL}/oauth2"
DISCOVERY_DOMAIN = os.environ.get("DISCOVERY_DOMAIN", f"discovery.{MEREKA_LMS_DOMAIN}")
DISCOVERY_BASE_URL = os.environ.get("DISCOVERY_BASE_URL", f"{MEREKA_SCHEME}://{DISCOVERY_DOMAIN}")

SECRET_KEY = os.environ.get("DISCOVERY_SECRET_KEY", "")
ALLOWED_HOSTS = [
    "discovery",
    "discovery.localhost",
    DISCOVERY_DOMAIN,
]

PLATFORM_NAME = "Mereka Academy"

DATABASES = {
    "default": {
        "ENGINE": "django.db.backends.mysql",
        "NAME": "discovery",
        "USER": "discovery",
        "PASSWORD": (os.environ.get("MYSQL_DISCOVERY_PASSWORD", "") or "").rstrip("\r\n"),
        "HOST": "mysql",
        "PORT": "3306",
        "OPTIONS": {
            "init_command": "SET sql_mode='STRICT_TRANS_TABLES'",
        },
    }
}

ELASTICSEARCH_DSL['default'].update({
    'hosts': "http://elasticsearch:9200/"
})



CACHES = {
    "default": {
        "BACKEND": "django_redis.cache.RedisCache",
        "KEY_PREFIX": "discovery",
        "LOCATION": "redis://@redis:6379/1",
    }
}

# Some openedx language codes are not standard, such as zh-cn
LANGUAGE_CODE = {
    "zh-cn": "zh-hans",
    "zh-hk": "zh-hant",
    "zh-tw": "zh-hant",
}.get("en", "en")
PARLER_DEFAULT_LANGUAGE_CODE = LANGUAGE_CODE
PARLER_LANGUAGES[1][0]["code"] = LANGUAGE_CODE
PARLER_LANGUAGES["default"]["fallbacks"] = [PARLER_DEFAULT_LANGUAGE_CODE]

EMAIL_BACKEND = "django.core.mail.backends.smtp.EmailBackend"
DEFAULT_PRODUCT_SOURCE_SLUG = "edx"
EMAIL_HOST = "smtp"
EMAIL_PORT = "8025"
EMAIL_HOST_USER = ""
EMAIL_HOST_PASSWORD = ""
EMAIL_USE_TLS = False

# Get rid of the "local" handler
LOGGING["handlers"].pop("local")
for logger in LOGGING["loggers"].values():
    if "local" in logger["handlers"]:
        logger["handlers"].remove("local")
# Decrease verbosity of algolia logger
LOGGING["loggers"]["algoliasearch_django"] = {"level": "WARNING"}

OAUTH_API_TIMEOUT = 5

JWT_AUTH["JWT_ISSUER"] = LMS_OAUTH2_ISSUER
JWT_AUTH["JWT_AUDIENCE"] = "openedx"
# Discovery verifies JWT tokens signed by LMS, so it must use the LMS secret key.
JWT_AUTH["JWT_SECRET_KEY"] = os.environ.get("JWT_SECRET_KEY_LMS", os.environ.get("JWT_SECRET_KEY_DISCOVERY", ""))
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
        "ISSUER": LMS_OAUTH2_ISSUER,
        "AUDIENCE": "openedx",
        "SECRET_KEY": os.environ.get("JWT_SECRET_KEY_LMS", os.environ.get("JWT_SECRET_KEY_DISCOVERY", ""))
    }
]

EDX_DRF_EXTENSIONS = {
    'OAUTH2_USER_INFO_URL': f"{LMS_INTERNAL_URL}/oauth2/user_info",
}



BACKEND_SERVICE_EDX_OAUTH2_KEY = "discovery"
BACKEND_SERVICE_EDX_OAUTH2_SECRET = os.environ.get("DISCOVERY_BACKEND_OAUTH2_SECRET", "")
BACKEND_SERVICE_EDX_OAUTH2_PROVIDER_URL = f"{LMS_INTERNAL_URL}/oauth2"

SOCIAL_AUTH_EDX_OAUTH2_KEY = "discovery-sso"
SOCIAL_AUTH_EDX_OAUTH2_SECRET = os.environ.get("DISCOVERY_SOCIAL_AUTH_EDX_OAUTH2_SECRET", "")
SOCIAL_AUTH_EDX_OAUTH2_ISSUER = LMS_OAUTH2_ISSUER
SOCIAL_AUTH_EDX_OAUTH2_URL_ROOT = LMS_INTERNAL_URL
SOCIAL_AUTH_EDX_OAUTH2_PUBLIC_URL_ROOT = LMS_BASE_URL
SOCIAL_AUTH_EDX_OAUTH2_LOGOUT_URL = f"{LMS_BASE_URL}/logout"

SOCIAL_AUTH_REDIRECT_IS_HTTPS = MEREKA_SCHEME == "https"

MEDIA_URL = DISCOVERY_BASE_URL + "/media/"
_init_sentry("discovery")

# Hardening: platform admin enforcement + /admin/login -> /login redirect.
MIDDLEWARE = list(MIDDLEWARE) + [
    "course_discovery.settings.tutor.mereka_platform_admin.MerekaPlatformAdminMiddleware",
]
