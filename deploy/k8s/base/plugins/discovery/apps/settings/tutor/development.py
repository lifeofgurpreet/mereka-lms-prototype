from ..devstack import *

import os

SECRET_KEY = os.environ.get("DISCOVERY_SECRET_KEY", "")
ALLOWED_HOSTS = [
    "discovery",
    "discovery.localhost"
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

import json
import os
JWT_AUTH["JWT_ISSUER"] = "http://localhost/oauth2"
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
        "ISSUER": "http://localhost/oauth2",
        "AUDIENCE": "openedx",
        "SECRET_KEY": os.environ.get("JWT_SECRET_KEY_LMS", os.environ.get("JWT_SECRET_KEY_DISCOVERY", ""))
    }
]

EDX_DRF_EXTENSIONS = {
    'OAUTH2_USER_INFO_URL': 'http://localhost/oauth2/user_info',
}



BACKEND_SERVICE_EDX_OAUTH2_KEY = "discovery-dev"
BACKEND_SERVICE_EDX_OAUTH2_SECRET = os.environ.get("DISCOVERY_BACKEND_OAUTH2_SECRET", "")
BACKEND_SERVICE_EDX_OAUTH2_PROVIDER_URL = "http://lms:8000/oauth2"

SOCIAL_AUTH_EDX_OAUTH2_KEY = "discovery-sso-dev"
SOCIAL_AUTH_EDX_OAUTH2_SECRET = os.environ.get("DISCOVERY_SOCIAL_AUTH_EDX_OAUTH2_SECRET", "")
SOCIAL_AUTH_EDX_OAUTH2_ISSUER = "http://localhost:8000"
SOCIAL_AUTH_EDX_OAUTH2_URL_ROOT = SOCIAL_AUTH_EDX_OAUTH2_ISSUER
SOCIAL_AUTH_EDX_OAUTH2_PUBLIC_URL_ROOT = SOCIAL_AUTH_EDX_OAUTH2_ISSUER
SOCIAL_AUTH_EDX_OAUTH2_LOGOUT_URL = SOCIAL_AUTH_EDX_OAUTH2_ISSUER + "/logout"

# Disable API caching, which makes it a pain to troubleshoot issues
USE_API_CACHING = False

DISCOVERY_BASE_URL = "http://discovery.localhost:8381"
MEDIA_URL = DISCOVERY_BASE_URL + "/media/"
