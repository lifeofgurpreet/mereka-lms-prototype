from ..production import *
import os
import json

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
        "PASSWORD": os.environ.get("MYSQL_DISCOVERY_PASSWORD", ""),
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
JWT_AUTH["JWT_SECRET_KEY"] = os.environ.get("JWT_SECRET_KEY_DISCOVERY", "")
# TODO assign a discovery-specific public key
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
        "SECRET_KEY": os.environ.get("JWT_SECRET_KEY_DISCOVERY", "")
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

# Hardening: platform admin enforcement + /admin/login -> /login redirect.
MIDDLEWARE = list(MIDDLEWARE) + [
    "course_discovery.settings.tutor.mereka_platform_admin.MerekaPlatformAdminMiddleware",
]
