from ..production import *

import json
import logging
import os


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
MFE_BASE_URL = os.environ.get("MFE_BASE_URL", f"{MEREKA_SCHEME}://apps.{MEREKA_LMS_DOMAIN}")
ECOMMERCE_BACKEND_OAUTH2_KEY = os.environ.get("ECOMMERCE_BACKEND_OAUTH2_KEY", "ecommerce")
# SSO client key for the authorization-code flow used by end users.
# (Backend service auth uses ECOMMERCE_BACKEND_OAUTH2_KEY instead.)
ECOMMERCE_OAUTH2_KEY = os.environ.get("ECOMMERCE_OAUTH2_KEY", "ecommerce-sso")

SECRET_KEY = os.environ.get("ECOMMERCE_SECRET_KEY", "")
ALLOWED_HOSTS = [
    "ecommerce.localhost",
    "ecommerce",
    f"ecommerce.{MEREKA_LMS_DOMAIN}",
]
PLATFORM_NAME = "Mereka Academy"
PROTOCOL = "http"

CORS_ALLOW_CREDENTIALS = True

OSCAR_DEFAULT_CURRENCY = "USD"

EDX_API_KEY = os.environ.get("ECOMMERCE_EDX_API_KEY", "")

JWT_AUTH["JWT_ISSUER"] = LMS_OAUTH2_ISSUER
JWT_AUTH["JWT_AUDIENCE"] = "openedx"
JWT_AUTH["JWT_SECRET_KEY"] = os.environ.get("JWT_SECRET_KEY_ECOMMERCE", "")
JWT_AUTH["JWT_PUBLIC_SIGNING_JWK_SET"] = json.dumps(
    {
        "keys": [
            {
                "kid": "openedx",
                "kty": "RSA",
                "e": "AQAB",
                "n": "nyKlrWYvtK405Rrvzb9zbtdyUvKgMyhySpiRNIvkhi8AqbmhyGYobRU6oOtjWdNTPy4Lfbx1TfB4EPo1BT2HIVenhm6TtTNwiKubJELwSOZSHNgq92GPzsXO868e86GWSzI9sLu4IXs1Egz81Sp5669YYmxDostWYZgyljXt7wdjOGbl-HQUgOppQMY1zH263A2pkTZ65kunEBzZyM_RtVb6yBi4hcSmU7q6jFbBniGjxY236hp6J9kRggsM-rHIuV0qHLlkBi23wVE0r866g6TwUcTqnHRn717RN1ZfHf76A3GN3UvgOgT4mEwaLoTijL8hzhLie1pgqCb7P2L3Yw",
            }
        ]
    }
)
JWT_AUTH["JWT_ISSUERS"] = [
    {
        "ISSUER": LMS_OAUTH2_ISSUER,
        "AUDIENCE": "openedx",
        "SECRET_KEY": os.environ.get("JWT_SECRET_KEY_ECOMMERCE", "")
    }
]

SOCIAL_AUTH_REDIRECT_IS_HTTPS = LMS_BASE_URL.startswith("https://")
SOCIAL_AUTH_EDX_OAUTH2_ISSUER = LMS_OAUTH2_ISSUER
SOCIAL_AUTH_EDX_OAUTH2_URL_ROOT = LMS_INTERNAL_URL
SOCIAL_AUTH_EDX_OAUTH2_KEY = ECOMMERCE_OAUTH2_KEY
SOCIAL_AUTH_EDX_OAUTH2_SECRET = os.environ.get("ECOMMERCE_SOCIAL_AUTH_EDX_OAUTH2_SECRET", "")

BACKEND_SERVICE_EDX_OAUTH2_KEY = ECOMMERCE_BACKEND_OAUTH2_KEY
BACKEND_SERVICE_EDX_OAUTH2_SECRET = os.environ.get("ECOMMERCE_BACKEND_OAUTH2_SECRET", "")
BACKEND_SERVICE_EDX_OAUTH2_PROVIDER_URL = f"{LMS_INTERNAL_URL}/oauth2"

EDX_DRF_EXTENSIONS = {
    'OAUTH2_USER_INFO_URL': f"{LMS_INTERNAL_URL}/oauth2/user_info",
}

DATABASES = {
    "default": {
        "ENGINE": "django.db.backends.mysql",
        "NAME": "ecommerce",
        "USER": "ecommerce",
        "PASSWORD": (os.environ.get("MYSQL_ECOMMERCE_PASSWORD", "") or "").rstrip("\r\n"),
        "HOST": "mysql",
        "PORT": "3306",
        "OPTIONS": {
            "init_command": "SET sql_mode='STRICT_TRANS_TABLES'",
        },
    }
}

EMAIL_BACKEND = "django.core.mail.backends.smtp.EmailBackend"
EMAIL_HOST = "smtp"
EMAIL_PORT = "8025"
EMAIL_HOST_USER = ""
EMAIL_HOST_PASSWORD = ""
EMAIL_USE_TLS = False

ENTERPRISE_SERVICE_URL = 'http://localhost/enterprise/'
ENTERPRISE_API_URL = urljoin(ENTERPRISE_SERVICE_URL, 'api/v1/')

# Get rid of local logger
LOGGING["handlers"].pop("local")
for logger in LOGGING["loggers"].values():
    logger["handlers"].remove("local")
_init_sentry("ecommerce")

# Load payment processors
with open(
    os.path.join(os.path.dirname(__file__), "paymentprocessors.json"),
    encoding="utf8"
) as payment_processors_file:
    common_payment_processor_config = json.load(payment_processors_file)

stripe_secret_key = os.environ.get("STRIPE_SECRET_KEY", "").strip()
stripe_publishable_key = os.environ.get("STRIPE_PUBLISHABLE_KEY", "").strip()
stripe_webhook_secret = os.environ.get("STRIPE_WEBHOOK_SECRET", "").strip()
if stripe_secret_key or stripe_publishable_key or stripe_webhook_secret:
    common_payment_processor_config["stripe"] = {
        "secret_key": stripe_secret_key,
        "publishable_key": stripe_publishable_key,
        "webhook_endpoint_secret": stripe_webhook_secret,
    }

# Fix cybersource-rest configuration
if "cybersource" in common_payment_processor_config and "cybersource-rest" not in common_payment_processor_config:
    common_payment_processor_config["cybersource-rest"] = common_payment_processor_config["cybersource"]
PAYMENT_PROCESSOR_CONFIG = {
    "openedx": common_payment_processor_config,
    "dev": common_payment_processor_config,
}
# Dummy config is required to bypass a KeyError
PAYMENT_PROCESSOR_CONFIG["edx"] = {
    "stripe": {
        "secret_key": stripe_secret_key,
        "publishable_key": stripe_publishable_key,
        "webhook_endpoint_secret": stripe_webhook_secret,
    }
}
PAYMENT_PROCESSORS = list(PAYMENT_PROCESSORS) + []

CORS_ORIGIN_WHITELIST = list(CORS_ORIGIN_WHITELIST) + [
    MFE_BASE_URL,
]
CSRF_TRUSTED_ORIGINS = [MFE_BASE_URL]

SOCIAL_AUTH_EDX_OAUTH2_PUBLIC_URL_ROOT = LMS_BASE_URL
BACKEND_SERVICE_EDX_OAUTH2_KEY = ECOMMERCE_BACKEND_OAUTH2_KEY

# Hardening: platform admin enforcement + /admin/login -> /login redirect.
MIDDLEWARE = list(MIDDLEWARE) + [
    "ecommerce.settings.tutor.mereka_platform_admin.MerekaPlatformAdminMiddleware",
]
