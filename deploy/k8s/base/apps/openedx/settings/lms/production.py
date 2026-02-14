# -*- coding: utf-8 -*-
import logging
import os
import sys
from lms.envs.production import *


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


# Override SECRET_KEY from environment variable (required for K8s deployment)
SECRET_KEY = os.environ.get("OPENEDX_SECRET_KEY", "")
if not SECRET_KEY:
    raise ValueError("OPENEDX_SECRET_KEY environment variable is required")

# Comprehensive theming is enabled via env.yml; actually activate the theme.
# Without DEFAULT_SITE_THEME, Open edX will keep serving stock Indigo styles/assets.
DEFAULT_SITE_THEME = os.environ.get("DEFAULT_SITE_THEME", "mereka")

# Override database password from environment variable.
# Note: secret stores and CLIs often include a trailing newline; strip it to
# avoid MySQL 1045 due to password mismatch.
_db_password = (os.environ.get("OPENEDX_MYSQL_PASSWORD", "") or "").rstrip("\r\n")
if _db_password and "default" in DATABASES:
    DATABASES["default"]["PASSWORD"] = _db_password

# Inject Authentik OIDC secret from environment (avoid storing in DB or YAML).
# Keep backward compatibility across env var names used by different overlays.
_oidc_secret = (
    os.environ.get("OIDC_CLIENT_SECRET")
    or os.environ.get("SOCIAL_AUTH_OIDC_SECRET")
    or ""
)
if _oidc_secret:
    SOCIAL_AUTH_OAUTH_SECRETS = dict(globals().get("SOCIAL_AUTH_OAUTH_SECRETS", {}))
    SOCIAL_AUTH_OAUTH_SECRETS.setdefault("oidc", _oidc_secret)

# Forum v2 (Python) - integrated into LMS as of Tutor v19+/Sumac.
# Forum runs in-process; no separate COMMENTS_SERVICE_URL needed.
FORUM_SEARCH_BACKEND = "forum.search.meilisearch.MeilisearchBackend"
FEATURES["ENABLE_DISCUSSION_SERVICE"] = True

# Forum MongoDB configuration (for platforms still using MongoDB backend).
# MongoDB Atlas connection is configured via environment variables.
FORUM_MONGODB_DATABASE = "cs_comments_service"
FORUM_MONGODB_CLIENT_PARAMETERS = {
    "host": os.environ.get("FORUM_MONGODB_HOST", "mongodb"),
    "port": int(os.environ.get("FORUM_MONGODB_PORT", "27017")),
    "username": os.environ.get("FORUM_MONGODB_USERNAME") or None,
    "password": os.environ.get("FORUM_MONGODB_PASSWORD") or None,
    "ssl": os.environ.get("FORUM_MONGODB_USE_SSL", "false").lower() == "true",
}
_forum_auth_source = os.environ.get("FORUM_MONGODB_AUTH_SOURCE")
if _forum_auth_source:
    FORUM_MONGODB_CLIENT_PARAMETERS["authSource"] = _forum_auth_source

# Meilisearch configuration (replaces Elasticsearch for forum search).
MEILISEARCH_ENABLED = True
MEILISEARCH_URL = "http://meilisearch:7700"
MEILISEARCH_INDEX_PREFIX = "tutor_"
MEILISEARCH_API_KEY = os.environ.get("MEILISEARCH_API_KEY", "")
SEARCH_ENGINE = "search.meilisearch.MeilisearchEngine"

####### Settings common to LMS and CMS
import json
import os

from xmodule.modulestore.modulestore_settings import update_module_store_settings

MEREKA_SCHEME = os.environ.get("MEREKA_SCHEME", "https")
MEREKA_LMS_DOMAIN = os.environ.get("MEREKA_LMS_DOMAIN", "academyv2.mereka.io")
MEREKA_DEV_DOMAIN = os.environ.get("MEREKA_DEV_DOMAIN", "academyv2.mereka.dev")
MEREKA_BIJI_DOMAIN = os.environ.get("MEREKA_BIJI_DOMAIN", "academy.biji-biji.com")
MEREKA_SKILLOURFUTURE_DOMAIN = os.environ.get(
    "MEREKA_SKILLOURFUTURE_DOMAIN",
    "skillourfuture.academy.mereka.io",
)

MEREKA_STUDIO_DOMAIN = os.environ.get("MEREKA_STUDIO_DOMAIN", f"studio.{MEREKA_LMS_DOMAIN}")
MEREKA_MFE_DOMAIN = os.environ.get("MEREKA_MFE_DOMAIN", f"apps.{MEREKA_LMS_DOMAIN}")
MEREKA_DISCOVERY_DOMAIN = os.environ.get(
    "MEREKA_DISCOVERY_DOMAIN",
    f"discovery.{MEREKA_LMS_DOMAIN}",
)
MEREKA_ECOMMERCE_DOMAIN = os.environ.get(
    "MEREKA_ECOMMERCE_DOMAIN",
    f"ecommerce.{MEREKA_LMS_DOMAIN}",
)
MEREKA_NOTES_DOMAIN = os.environ.get("MEREKA_NOTES_DOMAIN", f"notes.{MEREKA_LMS_DOMAIN}")
MEREKA_CREDENTIALS_DOMAIN = os.environ.get(
    "MEREKA_CREDENTIALS_DOMAIN",
    f"credentials.{MEREKA_LMS_DOMAIN}",
)
MEREKA_PREVIEW_DOMAIN = os.environ.get("MEREKA_PREVIEW_DOMAIN", f"preview.{MEREKA_LMS_DOMAIN}")

MEREKA_DEV_STUDIO_DOMAIN = os.environ.get(
    "MEREKA_DEV_STUDIO_DOMAIN",
    f"studio.{MEREKA_DEV_DOMAIN}",
)
MEREKA_DEV_MFE_DOMAIN = os.environ.get("MEREKA_DEV_MFE_DOMAIN", f"apps.{MEREKA_DEV_DOMAIN}")
MEREKA_DEV_DISCOVERY_DOMAIN = os.environ.get(
    "MEREKA_DEV_DISCOVERY_DOMAIN",
    f"discovery.{MEREKA_DEV_DOMAIN}",
)
MEREKA_DEV_ECOMMERCE_DOMAIN = os.environ.get(
    "MEREKA_DEV_ECOMMERCE_DOMAIN",
    f"ecommerce.{MEREKA_DEV_DOMAIN}",
)
MEREKA_DEV_NOTES_DOMAIN = os.environ.get(
    "MEREKA_DEV_NOTES_DOMAIN",
    f"notes.{MEREKA_DEV_DOMAIN}",
)
MEREKA_DEV_CREDENTIALS_DOMAIN = os.environ.get(
    "MEREKA_DEV_CREDENTIALS_DOMAIN",
    f"credentials.{MEREKA_DEV_DOMAIN}",
)
MEREKA_DEV_PREVIEW_DOMAIN = os.environ.get(
    "MEREKA_DEV_PREVIEW_DOMAIN",
    f"preview.{MEREKA_DEV_DOMAIN}",
)
MEREKA_COOKIE_DOMAIN = os.environ.get("MEREKA_COOKIE_DOMAIN", f".{MEREKA_LMS_DOMAIN}")

MEREKA_LMS_BASE_URL = f"{MEREKA_SCHEME}://{MEREKA_LMS_DOMAIN}"
MEREKA_STUDIO_BASE_URL = f"{MEREKA_SCHEME}://{MEREKA_STUDIO_DOMAIN}"
MEREKA_MFE_BASE_URL = f"{MEREKA_SCHEME}://{MEREKA_MFE_DOMAIN}"
MEREKA_DISCOVERY_BASE_URL = f"{MEREKA_SCHEME}://{MEREKA_DISCOVERY_DOMAIN}"
MEREKA_ECOMMERCE_BASE_URL = f"{MEREKA_SCHEME}://{MEREKA_ECOMMERCE_DOMAIN}"
MEREKA_NOTES_BASE_URL = f"{MEREKA_SCHEME}://{MEREKA_NOTES_DOMAIN}"
MEREKA_CREDENTIALS_BASE_URL = f"{MEREKA_SCHEME}://{MEREKA_CREDENTIALS_DOMAIN}"
MEREKA_PREVIEW_BASE_URL = f"{MEREKA_SCHEME}://{MEREKA_PREVIEW_DOMAIN}"
CREDENTIALS_INTERNAL_SERVICE_URL = os.environ.get(
    "CREDENTIALS_INTERNAL_SERVICE_URL",
    MEREKA_CREDENTIALS_BASE_URL,
)
CREDENTIALS_PUBLIC_SERVICE_URL = os.environ.get(
    "CREDENTIALS_PUBLIC_SERVICE_URL",
    MEREKA_CREDENTIALS_BASE_URL,
)
CREDENTIALS_SERVICE_USERNAME = os.environ.get("CREDENTIALS_SERVICE_USERNAME", "credentials")

# MongoDB modulestore connection.
#
# Target state is MongoDB Atlas, but we keep an explicit in-cluster fallback for
# environments where Atlas connectivity is not yet available.
#
# Atlas cluster: cluster-mereka-lms.2pjex4s.mongodb.net
MONGODB_HOST = os.environ.get("MONGODB_HOST", "mongodb")
MONGODB_DB = os.environ.get("MONGODB_DB", "openedx")
_mongodb_host_lower = (MONGODB_HOST or "").lower()
_mongodb_is_atlas = _mongodb_host_lower.startswith("mongodb+srv://") or ".mongodb.net" in _mongodb_host_lower

_mongodb_username = None
_mongodb_password = None
_mongodb_authsource = "admin"
if _mongodb_is_atlas:
    _mongodb_username = os.environ.get("MONGODB_USERNAME") or "cs_comments_user"
    _mongodb_password = os.environ.get("MONGODB_PASSWORD", "")
    _mongodb_authsource = os.environ.get("MONGODB_AUTHSOURCE", "admin")

mongodb_parameters = {
    "db": MONGODB_DB,
    "host": MONGODB_HOST,
    "port": 27017,
    "user": _mongodb_username,
    # IMPORTANT: For non-Atlas hosts (e.g. in-cluster mongodb), ignore any injected
    # MONGODB_USERNAME/MONGODB_PASSWORD to avoid failing auth against unauthenticated
    # dev/test mongo containers.
    "password": _mongodb_password if _mongodb_username else None,
    # Connection/Authentication
    "connect": False,
    "ssl": bool(_mongodb_is_atlas),
    "authsource": _mongodb_authsource,
    "replicaSet": None,
}
DOC_STORE_CONFIG = mongodb_parameters
CONTENTSTORE = {
    "ENGINE": "xmodule.contentstore.mongo.MongoContentStore",
    "ADDITIONAL_OPTIONS": {},
    "DOC_STORE_CONFIG": DOC_STORE_CONFIG
}
# Load module store settings from config files
update_module_store_settings(MODULESTORE, doc_store_settings=DOC_STORE_CONFIG)
DATA_DIR = "/openedx/data/modulestore"

for store in MODULESTORE["default"]["OPTIONS"]["stores"]:
   store["OPTIONS"]["fs_root"] = DATA_DIR

# Behave like memcache when it comes to connection errors
DJANGO_REDIS_IGNORE_EXCEPTIONS = True

# Elasticsearch connection parameters
ELASTIC_SEARCH_CONFIG = [{
  
  "host": "elasticsearch",
  "port": 9200,
}]

# Common cache config
CACHES = {
    "default": {
        "KEY_PREFIX": "default",
        "VERSION": "1",
        "BACKEND": "django_redis.cache.RedisCache",
        "LOCATION": "redis://@redis:6379/1",
    },
    "general": {
        "KEY_PREFIX": "general",
        "BACKEND": "django_redis.cache.RedisCache",
        "LOCATION": "redis://@redis:6379/1",
    },
    "mongo_metadata_inheritance": {
        "KEY_PREFIX": "mongo_metadata_inheritance",
        "TIMEOUT": 300,
        "BACKEND": "django_redis.cache.RedisCache",
        "LOCATION": "redis://@redis:6379/1",
    },
    "configuration": {
        "KEY_PREFIX": "configuration",
        "BACKEND": "django_redis.cache.RedisCache",
        "LOCATION": "redis://@redis:6379/1",
    },
    "celery": {
        "KEY_PREFIX": "celery",
        "TIMEOUT": 7200,
        "BACKEND": "django_redis.cache.RedisCache",
        "LOCATION": "redis://@redis:6379/1",
    },
    "course_structure_cache": {
        "KEY_PREFIX": "course_structure",
        "TIMEOUT": 604800, # 1 week
        "BACKEND": "django_redis.cache.RedisCache",
        "LOCATION": "redis://@redis:6379/1",
    },
    "ora2-storage": {
        "KEY_PREFIX": "ora2-storage",
        "BACKEND": "django_redis.cache.RedisCache",
        "LOCATION": "redis://@redis:6379/1",
    }
}

# Keep SITE_ID configurable to avoid hardcoded DB-id coupling across restores.
# Request paths use host-based site resolution via mereka_multisite middleware.
SITE_ID = int(os.environ.get("DJANGO_SITE_ID", "1"))

# Contact addresses
CONTACT_MAILING_ADDRESS = f"Mereka Academy - {MEREKA_LMS_BASE_URL}"
DEFAULT_FROM_EMAIL = ENV_TOKENS.get("DEFAULT_FROM_EMAIL", ENV_TOKENS["CONTACT_EMAIL"])
DEFAULT_FEEDBACK_EMAIL = ENV_TOKENS.get("DEFAULT_FEEDBACK_EMAIL", ENV_TOKENS["CONTACT_EMAIL"])
SERVER_EMAIL = ENV_TOKENS.get("SERVER_EMAIL", ENV_TOKENS["CONTACT_EMAIL"])
TECH_SUPPORT_EMAIL = ENV_TOKENS.get("TECH_SUPPORT_EMAIL", ENV_TOKENS["CONTACT_EMAIL"])
CONTACT_EMAIL = ENV_TOKENS.get("CONTACT_EMAIL", ENV_TOKENS["CONTACT_EMAIL"])
BUGS_EMAIL = ENV_TOKENS.get("BUGS_EMAIL", ENV_TOKENS["CONTACT_EMAIL"])
UNIVERSITY_EMAIL = ENV_TOKENS.get("UNIVERSITY_EMAIL", ENV_TOKENS["CONTACT_EMAIL"])
PRESS_EMAIL = ENV_TOKENS.get("PRESS_EMAIL", ENV_TOKENS["CONTACT_EMAIL"])
PAYMENT_SUPPORT_EMAIL = ENV_TOKENS.get("PAYMENT_SUPPORT_EMAIL", ENV_TOKENS["CONTACT_EMAIL"])
BULK_EMAIL_DEFAULT_FROM_EMAIL = ENV_TOKENS.get("BULK_EMAIL_DEFAULT_FROM_EMAIL", ENV_TOKENS["CONTACT_EMAIL"])
API_ACCESS_MANAGER_EMAIL = ENV_TOKENS.get("API_ACCESS_MANAGER_EMAIL", ENV_TOKENS["CONTACT_EMAIL"])
API_ACCESS_FROM_EMAIL = ENV_TOKENS.get("API_ACCESS_FROM_EMAIL", ENV_TOKENS["CONTACT_EMAIL"])

# Get rid completely of coursewarehistoryextended, as we do not use the CSMH database
INSTALLED_APPS.remove("lms.djangoapps.coursewarehistoryextended")
# Mereka adjustments keep Redwood optional apps enabled
DATABASE_ROUTERS.remove(
    "openedx.core.lib.django_courseware_routers.StudentModuleHistoryExtendedRouter"
)
if "openedx.core.djangoapps.content_libraries.apps.ContentLibrariesConfig" not in INSTALLED_APPS:
    INSTALLED_APPS += ["openedx.core.djangoapps.content_libraries.apps.ContentLibrariesConfig"]
if "openedx.core.djangoapps.bookmarks.apps.BookmarksConfig" not in INSTALLED_APPS:
    INSTALLED_APPS += ["openedx.core.djangoapps.bookmarks.apps.BookmarksConfig"]
if "openedx.core.djangoapps.discussions.apps.DiscussionsConfig" not in INSTALLED_APPS:
    INSTALLED_APPS += ["openedx.core.djangoapps.discussions.apps.DiscussionsConfig"]
if "openedx.core.djangoapps.theming.apps.ThemingConfig" not in INSTALLED_APPS:
    INSTALLED_APPS += ["openedx.core.djangoapps.theming.apps.ThemingConfig"]

# Set uploaded media file path
MEDIA_ROOT = "/openedx/media/"

# Video settings
VIDEO_IMAGE_SETTINGS["STORAGE_KWARGS"]["location"] = MEDIA_ROOT
VIDEO_TRANSCRIPTS_SETTINGS["STORAGE_KWARGS"]["location"] = MEDIA_ROOT

GRADES_DOWNLOAD = {
    "STORAGE_TYPE": "",
    "STORAGE_KWARGS": {
        "base_url": "/media/grades/",
        "location": "/openedx/media/grades",
    },
}

# ORA2
ORA2_FILEUPLOAD_BACKEND = "filesystem"
ORA2_FILEUPLOAD_ROOT = "/openedx/data/ora2"
FILE_UPLOAD_STORAGE_BUCKET_NAME = "openedxuploads"
ORA2_FILEUPLOAD_CACHE_NAME = "ora2-storage"

# Change syslog-based loggers which don't work inside docker containers
LOGGING["handlers"]["local"] = {
    "class": "logging.handlers.WatchedFileHandler",
    "filename": os.path.join(LOG_DIR, "all.log"),
    "formatter": "standard",
}
LOGGING["handlers"]["tracking"] = {
    "level": "DEBUG",
    "class": "logging.handlers.WatchedFileHandler",
    "filename": os.path.join(LOG_DIR, "tracking.log"),
    "formatter": "standard",
}
LOGGING["loggers"]["tracking"]["handlers"] = ["console", "local", "tracking"]
_init_sentry("lms")

# Silence some loggers (note: we must attempt to get rid of these when upgrading from one release to the next)
LOGGING["loggers"]["blockstore.apps.bundles.storage"] = {"handlers": ["console"], "level": "WARNING"}

# These warnings are visible in simple commands and init tasks
import warnings

try:
    from django.utils.deprecation import RemovedInDjango50Warning, RemovedInDjango51Warning
    warnings.filterwarnings("ignore", category=RemovedInDjango50Warning)
    warnings.filterwarnings("ignore", category=RemovedInDjango51Warning)
except ImportError:
    # REMOVE-AFTER-V18:
    # In Quince, edx-platform uses Django 5. But on master, edx-platform still uses Django 3.
    # So, Tutor v17 needs to silence these warnings, whereas Tutor v17-nightly fails to import them.
    # Once edx-platform master is upgraded to Django 5, the try-except wrapper can be removed.
    pass

warnings.filterwarnings("ignore", category=DeprecationWarning, module="wiki.plugins.links.wiki_plugin")
warnings.filterwarnings("ignore", category=DeprecationWarning, module="boto.plugin")
warnings.filterwarnings("ignore", category=DeprecationWarning, module="botocore.vendored.requests.packages.urllib3._collections")
warnings.filterwarnings("ignore", category=DeprecationWarning, module="pkg_resources")
warnings.filterwarnings("ignore", category=DeprecationWarning, module="fs")
warnings.filterwarnings("ignore", category=DeprecationWarning, module="fs.opener")
SILENCED_SYSTEM_CHECKS = ["2_0.W001", "fields.W903"]

# Email
EMAIL_USE_SSL = False
# Forward all emails from edX's Automated Communication Engine (ACE) to django.
ACE_ENABLED_CHANNELS = ["django_email"]
ACE_CHANNEL_DEFAULT_EMAIL = "django_email"
ACE_CHANNEL_TRANSACTIONAL_EMAIL = "django_email"
EMAIL_FILE_PATH = "/tmp/openedx/emails"

# Language/locales
LANGUAGE_COOKIE_NAME = "openedx-language-preference"

# Allow the platform to include itself in an iframe
X_FRAME_OPTIONS = "SAMEORIGIN"


JWT_AUTH["JWT_ISSUER"] = f"{MEREKA_LMS_BASE_URL}/oauth2"
JWT_AUTH["JWT_AUDIENCE"] = "openedx"
JWT_AUTH["JWT_SECRET_KEY"] = os.environ.get("JWT_SECRET_KEY_LMS", "")
JWT_AUTH["JWT_PRIVATE_SIGNING_JWK"] = json.dumps(
    {
        "kid": "openedx",
        "kty": "RSA",
        "e": "AQAB",
        "d": "ETfA9ZrIT5lyV1WLm6x6vgPpNoinhPwmfY62AJmgOf_M57rngmoXNqePhoi2tlR96H3quAnTfAF9eYIbiXvHlU0exECjklKZ-uzs-3E9_qKOQNkHW75pE7C6_F-2uW_YIJOzhrM7hW0yEp1oH7JEVcKiN_1JxiE6W-iJP0-0yjdL3J65HSCC57G4pmwGJnNv11_m_EXV7ChiH0G9XkZ8tRm6FX3ytyBimVSVVva2evma2ykLAOmxEERyx-ggs-K-ypQNpPzz96uadqw79l5UyWDW-Vss24qmDO1MrYIiLPaVv9pWzrURS4AY6j99zPrnc1diBA_AZ_s2MTqsXLtlrQ",
        "n": "nyKlrWYvtK405Rrvzb9zbtdyUvKgMyhySpiRNIvkhi8AqbmhyGYobRU6oOtjWdNTPy4Lfbx1TfB4EPo1BT2HIVenhm6TtTNwiKubJELwSOZSHNgq92GPzsXO868e86GWSzI9sLu4IXs1Egz81Sp5669YYmxDostWYZgyljXt7wdjOGbl-HQUgOppQMY1zH263A2pkTZ65kunEBzZyM_RtVb6yBi4hcSmU7q6jFbBniGjxY236hp6J9kRggsM-rHIuV0qHLlkBi23wVE0r866g6TwUcTqnHRn717RN1ZfHf76A3GN3UvgOgT4mEwaLoTijL8hzhLie1pgqCb7P2L3Yw",
        "p": "waacG-oc-c9kSltIyVr2kZgMJ2yD0pPEaIwY8PTvAJLMmf06uGG6AFf28WSC-Vp44-O2OPovaqt6FX5VDwKCfdsK7XFO_9EsIkWcJyOHVM3_OLWqSF38E1O8H6j7dAXkHnfZbBLy-4nN3ScspVBG8OcKhUBii2J2oMJ1txYjKf0",
        "q": "0l8mD6ZdgV_2eQEVmE2uPPRfPiGQOe6MVi6f75cj5Ay5hZqBkcuiRcqZGAnwKtADKEznF6kHbqeZDeWOY6KISS2Pj9TMT2zkGFKH2_NqF7g5YKqzyWuAkhg1SSvcb-IiNXrgGnvhyiNgIp6zQRRYzQ9kEKN0jIPh643JX6tCNN8",
        "dq": "v6DwmLzg3CK_74WvWCcamme4Am6sZDkKGM8r3SF-DhQRQsR1Vot5670bK6yR203UMneq4gCUxpVgdCoxRE0ffBlGdqxO1-LG--jh3NekQqsLiSS11LpaSbpHf7m2eSwyISkmzrkd-fWzcpXBj3yrT0-_xPBAEGdp-hoT31OvYV0",
        "dp": "MT-I9gRtCA75R3u9oA-1I0PS23facoRH7_qpISZ5XeD3jbX76AZaglncoHlaYcXjdrljj0v5IRyo-KxfP2j4_L7nIYmueJqeqbygQMflU-jrnmV8_9h_Ef86maalBFW3NRRvw-9xwgzCwRqEXSp0UDHB2C-OoDoTR0ENJNnJaZU",
        "qi": "OsRjvkqA4XTl_NcTr66U8yniSXSiNC1PU_4FhV8eBpNVIQQ2ePv6_VhKrdnrATQEFXnGnLBNn6ytVTyAsq1xG8o3Y_opXLqcC-mZxvI21Z1meczrl79KtaUMMlcaOklVZV00KtSKu7K39nSvlJL3WB-uycWGsNI-efunJS-F0O0",
    }
)
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
        "ISSUER": f"{MEREKA_LMS_BASE_URL}/oauth2",
        "AUDIENCE": "openedx",
        "SECRET_KEY": os.environ.get("JWT_SECRET_KEY_LMS", "")
    }
]

# Enable/Disable some features globally
FEATURES["ENABLE_DISCUSSION_SERVICE"] = False
FEATURES["PREVENT_CONCURRENT_LOGINS"] = False
FEATURES["ENABLE_CORS_HEADERS"] = True

# Verifiable Credentials (W3C VC 2.0 + Open Badges v3.0)
# @spec: specs/verifiable-credentials-types_spec.md (CRED-010)
FEATURES["ENABLE_VERIFIABLE_CREDENTIALS"] = os.environ.get(
    "ENABLE_VERIFIABLE_CREDENTIALS", "false"
).lower() in ("true", "1", "yes")
FEATURES["ENABLE_LEARNER_CREDENTIAL_WALLET"] = os.environ.get(
    "ENABLE_LEARNER_CREDENTIAL_WALLET", "false"
).lower() in ("true", "1", "yes")

# CORS
CORS_ALLOW_CREDENTIALS = True
CORS_ORIGIN_ALLOW_ALL = False
CORS_ALLOW_INSECURE = True
# Note: CORS_ALLOW_HEADERS is intentionally not defined here, because it should
# be consistent across deployments, and is therefore set in edx-platform.

# Add your MFE and third-party app domains here
CORS_ORIGIN_WHITELIST = []

# Disable codejail support
# explicitely configuring python is necessary to prevent unsafe calls
import codejail.jail_code
codejail.jail_code.configure("python", "nonexistingpythonbinary", user=None)
# another configuration entry is required to override prod/dev settings
CODE_JAIL = {
    "python_bin": "nonexistingpythonbinary",
    "user": None,
}

FEATURES["ENABLE_DISCUSSION_SERVICE"] = True
# Student notes
FEATURES["ENABLE_EDXNOTES"] = True
XQUEUE_INTERFACE = {
  "django_auth": {
    "username": "lms",
    "password": os.environ.get("XQUEUE_LMS_PASSWORD", "")
  },
  "url": "http://xqueue:8000",
  "callback_url": "http://lms:8000"
}
######## End of settings common to LMS and CMS

######## Common LMS settings
LOGIN_REDIRECT_WHITELIST = [MEREKA_STUDIO_DOMAIN]

# Better layout of honor code/tos links during registration
REGISTRATION_EXTRA_FIELDS["terms_of_service"] = "hidden"
REGISTRATION_EXTRA_FIELDS["honor_code"] = "hidden"

# Fix media files paths
PROFILE_IMAGE_BACKEND["options"]["location"] = os.path.join(
    MEDIA_ROOT, "profile-images/"
)

COURSE_CATALOG_VISIBILITY_PERMISSION = "see_in_catalog"
COURSE_ABOUT_VISIBILITY_PERMISSION = "see_about_page"

# Allow insecure oauth2 for local interaction with local containers
OAUTH_ENFORCE_SECURE = False

# Email settings
DEFAULT_EMAIL_LOGO_URL = LMS_ROOT_URL + f"/theming/asset/{DEFAULT_SITE_THEME}/images/logo.png"
BULK_EMAIL_SEND_USING_EDX_ACE = True
FEATURES["ENABLE_FOOTER_MOBILE_APP_LINKS"] = False

# Branding
MOBILE_STORE_ACE_URLS = {}
SOCIAL_MEDIA_FOOTER_ACE_URLS = {}

# Make it possible to hide courses by default from the studio
SEARCH_SKIP_SHOW_IN_CATALOG_FILTERING = False

# Caching
CACHES["staticfiles"] = {
    "KEY_PREFIX": "staticfiles_lms",
    "BACKEND": "django.core.cache.backends.locmem.LocMemCache",
    "LOCATION": "staticfiles_lms",
}

# Create folders if necessary
for folder in [DATA_DIR, LOG_DIR, MEDIA_ROOT, STATIC_ROOT, ORA2_FILEUPLOAD_ROOT]:
    if not os.path.exists(folder):
        os.makedirs(folder, exist_ok=True)

FEATURES["ENABLE_COURSE_DISCOVERY"] = True
EDX_API_KEY = os.environ.get("EDX_API_KEY", "")
ECOMMERCE_API_SIGNING_KEY = os.environ.get("ECOMMERCE_API_SIGNING_KEY", "")
ECOMMERCE_API_TIMEOUT = 5
from babel.numbers import get_currency_symbol
PAID_COURSE_REGISTRATION_CURRENCY = ["USD", get_currency_symbol("USD")]
COURSE_MODE_DEFAULTS["currency"] = "USD"
FEATURES["AUTOMATIC_VERIFY_STUDENT_IDENTITY_FOR_TESTING"] = False
# MFE: enable API and set a low cache timeout for the settings. otherwise, weird
# configuration bugs occur. Also, the view is not costly at all, and it's also cached on
# the frontend. (5 minutes, hardcoded)
ENABLE_MFE_CONFIG_API = True
MFE_CONFIG_API_CACHE_TIMEOUT = 1

# MFE-specific settings

FEATURES['ENABLE_AUTHN_MICROFRONTEND'] = True

FEATURES["ENABLE_ACCOUNT_MICROFRONTEND"] = True
FEATURES["ENABLE_PROFILE_MICROFRONTEND"] = True


FEATURES['ENABLE_NEW_BULK_EMAIL_EXPERIENCE'] = True


LEARNER_HOME_MFE_REDIRECT_PERCENTAGE = 100

# Student notes
EDXNOTES_CLIENT_NAME = "notes"

######## End of common LMS settings

ALLOWED_HOSTS = [
    ENV_TOKENS.get("LMS_BASE"),
    FEATURES["PREVIEW_LMS_BASE"],
    "lms",
    MEREKA_BIJI_DOMAIN,
    MEREKA_LMS_DOMAIN,
    MEREKA_STUDIO_DOMAIN,
    MEREKA_MFE_DOMAIN,
    MEREKA_PREVIEW_DOMAIN,
    MEREKA_SKILLOURFUTURE_DOMAIN,
    MEREKA_DEV_DOMAIN,
    MEREKA_DEV_STUDIO_DOMAIN,
    MEREKA_DEV_MFE_DOMAIN,
    MEREKA_DEV_PREVIEW_DOMAIN,
    MEREKA_DEV_DISCOVERY_DOMAIN,
    MEREKA_DEV_ECOMMERCE_DOMAIN,
    MEREKA_DEV_NOTES_DOMAIN,
    MEREKA_DEV_CREDENTIALS_DOMAIN,
    # Multisite MFEs and Studio hosts (otherwise Django returns Bad Request (400)).
    f"apps.{MEREKA_BIJI_DOMAIN}",
    f"studio.{MEREKA_BIJI_DOMAIN}",
    f"apps.{MEREKA_SKILLOURFUTURE_DOMAIN}",
    f"studio.{MEREKA_SKILLOURFUTURE_DOMAIN}",
]
for origin in [
    MEREKA_LMS_BASE_URL,
    MEREKA_STUDIO_BASE_URL,
    MEREKA_MFE_BASE_URL,
    f"{MEREKA_SCHEME}://apps.{MEREKA_BIJI_DOMAIN}",
    f"{MEREKA_SCHEME}://apps.{MEREKA_SKILLOURFUTURE_DOMAIN}",
    f"{MEREKA_SCHEME}://{MEREKA_BIJI_DOMAIN}",
    f"{MEREKA_SCHEME}://{MEREKA_SKILLOURFUTURE_DOMAIN}",
]:
    if origin not in CORS_ORIGIN_WHITELIST:
        CORS_ORIGIN_WHITELIST.append(origin)


# Secure cookies for HTTPS + OIDC login flow
SESSION_COOKIE_SECURE = MEREKA_SCHEME == "https"
CSRF_COOKIE_SECURE = MEREKA_SCHEME == "https"
SESSION_COOKIE_SAMESITE = "None"
CSRF_COOKIE_SAMESITE = "None"

# Multisite note:
# We serve multiple *root* domains (academyv2.mereka.io, academy.biji-biji.com, ...).
# A single static SESSION/CSRF cookie domain would be invalid on other roots and
# browsers will drop it. Keep cookies host-only here and rewrite per-request via
# middleware (`MerekaCookieDomainMiddleware`).
SESSION_COOKIE_DOMAIN = None
CSRF_COOKIE_DOMAIN = None


# CMS authentication
IDA_LOGOUT_URI_LIST.append(f"{MEREKA_STUDIO_BASE_URL}/logout/")

# Required to display all courses on start page
SEARCH_SKIP_ENROLLMENT_START_DATE_FILTERING = True

# Dynamic config API settings
# https://openedx.github.io/frontend-platform/module-Config.html
MFE_CONFIG = {
    "BASE_URL": MEREKA_MFE_DOMAIN,
    "CSRF_TOKEN_API_PATH": "/csrf/api/v1/token",
    "CREDENTIALS_BASE_URL": MEREKA_CREDENTIALS_BASE_URL,
    "DISCOVERY_API_BASE_URL": MEREKA_DISCOVERY_BASE_URL,
    "FAVICON_URL": f"{MEREKA_LMS_BASE_URL}/favicon.ico",
    "INFO_EMAIL": "contact@localhost",
    "LANGUAGE_PREFERENCE_COOKIE_NAME": "openedx-language-preference",
    "LMS_BASE_URL": MEREKA_LMS_BASE_URL,
    "LOGIN_URL": f"{MEREKA_LMS_BASE_URL}/login",
    "LOGO_URL": f"{MEREKA_LMS_BASE_URL}/theming/asset/{DEFAULT_SITE_THEME}/images/logo-horizontal.png",
    "LOGO_WHITE_URL": f"{MEREKA_LMS_BASE_URL}/theming/asset/{DEFAULT_SITE_THEME}/images/logo-horizontal-white.png",
    "LOGO_TRADEMARK_URL": f"{MEREKA_LMS_BASE_URL}/theming/asset/{DEFAULT_SITE_THEME}/images/logo.png",
    "LOGOUT_URL": f"{MEREKA_LMS_BASE_URL}/logout",
    "MARKETING_SITE_BASE_URL": MEREKA_LMS_BASE_URL,
    "PASSWORD_RESET_SUPPORT_LINK": "mailto:contact@localhost",
    # IMPORTANT: MFEs call this via browser fetch. Many stacks default to `credentials: "same-origin"`,
    # which will NOT send LMS session cookies to a different origin. Point this at the MFE origin
    # and reverse-proxy it back to the LMS (see deploy/k8s/base/plugins/mfe/apps/mfe/Caddyfile).
    # Use a relative path so this remains same-origin across multiple MFE hostnames
    # (e.g. apps.academyv2.mereka.io and apps.academy.biji-biji.com).
    "REFRESH_ACCESS_TOKEN_ENDPOINT": "/login_refresh",
    "SITE_NAME": "Mereka Academy",
    "STUDIO_BASE_URL": MEREKA_STUDIO_BASE_URL,
    "USER_INFO_COOKIE_NAME": "user-info",
    "ACCESS_TOKEN_COOKIE_NAME": "edx-jwt-cookie-header-payload",
    "SUPPORT_URL_LEARNER_RECORDS": "",
    "ENABLE_VERIFIABLE_CREDENTIALS": FEATURES.get("ENABLE_VERIFIABLE_CREDENTIALS", False),
    "SUPPORT_URL_VERIFIABLE_CREDENTIALS": "",
}

# MFE-specific settings


AUTHN_MICROFRONTEND_URL = f"{MEREKA_MFE_BASE_URL}/authn"
AUTHN_MICROFRONTEND_DOMAIN = f"{MEREKA_MFE_DOMAIN}/authn"
# Enterprise login: disabled by default; enable when per-tenant IdPs are configured.
# Set MEREKA_ENABLE_ENTERPRISE_LOGIN=true in env to show enterprise SSO on login page.
MFE_CONFIG["DISABLE_ENTERPRISE_LOGIN"] = os.environ.get(
    "MEREKA_ENABLE_ENTERPRISE_LOGIN", ""
).lower() not in ("true", "1", "yes")
MFE_CONFIG["AUTHN_MICROFRONTEND_URL"] = AUTHN_MICROFRONTEND_URL
MFE_CONFIG["AUTHN_MICROFRONTEND_DOMAIN"] = AUTHN_MICROFRONTEND_DOMAIN
if SESSION_COOKIE_DOMAIN:
    MFE_CONFIG["SESSION_COOKIE_DOMAIN"] = SESSION_COOKIE_DOMAIN
if CSRF_COOKIE_DOMAIN:
    MFE_CONFIG["CSRF_COOKIE_DOMAIN"] = CSRF_COOKIE_DOMAIN
MFE_CONFIG["SESSION_COOKIE_SAMESITE"] = SESSION_COOKIE_SAMESITE
MFE_CONFIG["CSRF_COOKIE_SAMESITE"] = CSRF_COOKIE_SAMESITE
MFE_CONFIG["SUPPORT_EMAIL"] = CONTACT_EMAIL
MFE_CONFIG["TERMS_OF_SERVICE_URL"] = f"{MEREKA_LMS_BASE_URL}/terms"
MFE_CONFIG["PRIVACY_POLICY_URL"] = f"{MEREKA_LMS_BASE_URL}/privacy"
MFE_CONFIG["ENABLE_ACCESSIBILITY_PAGE"] = False



ACCOUNT_MICROFRONTEND_URL = f"{MEREKA_MFE_BASE_URL}/account/"
MFE_CONFIG["ACCOUNT_SETTINGS_URL"] = ACCOUNT_MICROFRONTEND_URL



MFE_CONFIG["COURSE_AUTHORING_MICROFRONTEND_URL"] = f"{MEREKA_MFE_BASE_URL}/course-authoring"
MFE_CONFIG["ENABLE_ASSETS_PAGE"] = "true"
MFE_CONFIG["ENABLE_HOME_PAGE_COURSE_API_V2"] = "true"
MFE_CONFIG["ENABLE_PROGRESS_GRAPH_SETTINGS"] = "true"
MFE_CONFIG["ENABLE_TAGGING_TAXONOMY_PAGES"] = "true"



DISCUSSIONS_MICROFRONTEND_URL = f"{MEREKA_MFE_BASE_URL}/discussions"
MFE_CONFIG["DISCUSSIONS_MFE_BASE_URL"] = DISCUSSIONS_MICROFRONTEND_URL
DISCUSSIONS_MFE_FEEDBACK_URL = None



WRITABLE_GRADEBOOK_URL = f"{MEREKA_MFE_BASE_URL}/gradebook"

# Hardening: keep platform admins as staff/superuser (prevents drift).
MIDDLEWARE = list(MIDDLEWARE) + [
    "lms.envs.tutor.mereka_platform_admin.MerekaPlatformAdminMiddleware",
    "lms.envs.tutor.mereka_multisite.MerekaCookieDomainMiddleware",
    # Studio SSO uses LMS OAuth2 provider endpoints. MFEs authenticate via JWT
    # cookies; legacy OAuth2 views still expect an authenticated request.user.
    # Bridge JWT-cookie auth into request.user/session for `/oauth2/*` only.
    "lms.envs.tutor.mereka_jwt_session.MerekaJwtToSessionBridgeMiddleware",
]



LEARNER_HOME_MICROFRONTEND_URL = f"{MEREKA_MFE_BASE_URL}/learner-dashboard/"



LEARNING_MICROFRONTEND_URL = f"{MEREKA_MFE_BASE_URL}/learning"
MFE_CONFIG["LEARNING_BASE_URL"] = f"{MEREKA_MFE_BASE_URL}/learning"



ORA_GRADING_MICROFRONTEND_URL = f"{MEREKA_MFE_BASE_URL}/ora-grading"



# Profile MFE does not use a "/profile" basename in routing; it expects "/u/:username".
# We serve the SPA at `apps.<domain>/u/<username>` and keep `/profile/*` for static assets.
PROFILE_MICROFRONTEND_URL = f"{MEREKA_MFE_BASE_URL}/u/"
MFE_CONFIG["ACCOUNT_PROFILE_URL"] = PROFILE_MICROFRONTEND_URL
MFE_CONFIG["PROFILE_MICROFRONTEND_URL"] = PROFILE_MICROFRONTEND_URL



COMMUNICATIONS_MICROFRONTEND_URL = f"{MEREKA_MFE_BASE_URL}/communications"
MFE_CONFIG["SCHEDULE_EMAIL_SECTION"] = True


LOGIN_REDIRECT_WHITELIST.extend([MEREKA_MFE_DOMAIN, MEREKA_DEV_MFE_DOMAIN])
for origin in [
    MEREKA_MFE_BASE_URL,
    f"{MEREKA_SCHEME}://{MEREKA_DEV_MFE_DOMAIN}",
]:
    if origin not in CORS_ORIGIN_WHITELIST:
        CORS_ORIGIN_WHITELIST.append(origin)
    if origin not in CSRF_TRUSTED_ORIGINS:
        CSRF_TRUSTED_ORIGINS.append(origin)



# Ecommerce
ECOMMERCE_PUBLIC_URL_ROOT = MEREKA_ECOMMERCE_BASE_URL
ECOMMERCE_API_URL = ECOMMERCE_PUBLIC_URL_ROOT + "/api/v2"
ORDER_HISTORY_MICROFRONTEND_URL = f"{MEREKA_MFE_BASE_URL}/orders/orders"
MFE_CONFIG["ECOMMERCE_BASE_URL"] = ECOMMERCE_PUBLIC_URL_ROOT
MFE_CONFIG["ORDER_HISTORY_URL"] = ORDER_HISTORY_MICROFRONTEND_URL

MFE_CONFIG['INDIGO_ENABLE_DARK_TOGGLE'] = True

# MFE Config API URLs - maps MFE names to their base URLs
MFE_CONFIG_API_URLS = {
    'authn': f"{MEREKA_MFE_BASE_URL}/authn",
    'account': f"{MEREKA_MFE_BASE_URL}/account",
    'gradebook': f"{MEREKA_MFE_BASE_URL}/gradebook",
    'profile': f"{MEREKA_MFE_BASE_URL}/u",
    'course-authoring': f"{MEREKA_MFE_BASE_URL}/course-authoring",
    'communications': f"{MEREKA_MFE_BASE_URL}/communications",
    'discussions': f"{MEREKA_MFE_BASE_URL}/discussions",
    'learner-dashboard': f"{MEREKA_MFE_BASE_URL}/learner-dashboard",
    'learning': f"{MEREKA_MFE_BASE_URL}/learning",
    'ora-grading': f"{MEREKA_MFE_BASE_URL}/ora-grading",
    'orders': f"{MEREKA_MFE_BASE_URL}/orders",
    'payment': f"{MEREKA_MFE_BASE_URL}/payment",
}

EDXNOTES_PUBLIC_API = f"{MEREKA_NOTES_BASE_URL}/api/v1"
EDXNOTES_INTERNAL_API = "http://notes:8000/api/v1"

LMS_BASE = MEREKA_LMS_DOMAIN
LMS_ROOT_URL = MEREKA_LMS_BASE_URL
CMS_BASE = MEREKA_STUDIO_DOMAIN
CMS_ROOT_URL = MEREKA_STUDIO_BASE_URL

for origin in [
    MEREKA_LMS_BASE_URL,
    MEREKA_STUDIO_BASE_URL,
    f"{MEREKA_SCHEME}://apps.{MEREKA_BIJI_DOMAIN}",
    f"{MEREKA_SCHEME}://apps.{MEREKA_SKILLOURFUTURE_DOMAIN}",
    f"{MEREKA_SCHEME}://{MEREKA_BIJI_DOMAIN}",
    f"{MEREKA_SCHEME}://{MEREKA_SKILLOURFUTURE_DOMAIN}",
]:
    if origin not in CSRF_TRUSTED_ORIGINS:
        CSRF_TRUSTED_ORIGINS.append(origin)

# MFE OAuth fix + Prometheus metrics
sys.path.insert(0, "/openedx")
try:
    import mfe_oauth_fix  # noqa: F401
except Exception:
    # Some images/environments don't include this custom patch app.
    # Skip it rather than crashing the whole service.
    pass
else:
    if "mfe_oauth_fix" not in INSTALLED_APPS:
        INSTALLED_APPS.append("mfe_oauth_fix")
    ROOT_URLCONF_OVERRIDES = globals().get("ROOT_URLCONF_OVERRIDES", [])
    if "mfe_oauth_fix.urls" not in ROOT_URLCONF_OVERRIDES:
        ROOT_URLCONF_OVERRIDES.insert(0, "mfe_oauth_fix.urls")
    if "mfe_oauth_fix.middleware.MFEOAuthFixMiddleware" not in MIDDLEWARE:
        MIDDLEWARE.append("mfe_oauth_fix.middleware.MFEOAuthFixMiddleware")

try:
    import django_prometheus  # noqa: F401
except Exception:
    # Some images/environments don't ship with django_prometheus installed.
    # Skip metrics wiring instead of crashing the whole service.
    pass
else:
    if "django_prometheus" not in INSTALLED_APPS:
        INSTALLED_APPS.insert(0, "django_prometheus")
    if "openedx_prometheus" not in INSTALLED_APPS:
        INSTALLED_APPS.append("openedx_prometheus")
    if "django_prometheus.middleware.PrometheusBeforeMiddleware" not in MIDDLEWARE:
        MIDDLEWARE.insert(0, "django_prometheus.middleware.PrometheusBeforeMiddleware")
    if "django_prometheus.middleware.PrometheusAfterMiddleware" not in MIDDLEWARE:
        MIDDLEWARE.append("django_prometheus.middleware.PrometheusAfterMiddleware")

# Forwarded-header hardening: normalize multi-valued X-Forwarded-* headers.
# Without this, Django may treat HTTPS requests as HTTP which can break URL
# generation and callback flows in some proxy chains.
_forwarded_headers_middleware = "lms.envs.tutor.mereka_forwarded_headers.MerekaForwardedHeadersMiddleware"
if _forwarded_headers_middleware not in MIDDLEWARE:
    MIDDLEWARE.insert(0, _forwarded_headers_middleware)

# OIDC hardening: the cookie-domain middleware must run after SessionMiddleware
# has set session/csrf cookies on the response, otherwise OIDC state cookies
# can remain host-only and fail on callback ("Session value state missing").
_cookie_middleware = "lms.envs.tutor.mereka_multisite.MerekaCookieDomainMiddleware"
_session_middleware = "django.contrib.sessions.middleware.SessionMiddleware"
if _cookie_middleware in MIDDLEWARE and _session_middleware in MIDDLEWARE:
    cookie_index = MIDDLEWARE.index(_cookie_middleware)
    session_index = MIDDLEWARE.index(_session_middleware)
    if cookie_index > session_index:
        MIDDLEWARE.insert(session_index, MIDDLEWARE.pop(cookie_index))

# Enterprise Integrated Channels (Degreed, CSOD, etc.)
try:
    from lms.envs.tutor.mereka_enterprise_channels import *  # noqa: F401,F403
except ImportError:
    pass

# ── Enterprise SSO Foundation ────────────────────────────────────────────
# @covers AC-004, AC-005
# @spec: auth-sso-enterprise_spec.md
# Per-tenant SAML/OIDC authentication via Open edX third_party_auth.
# Phase 0: inject SP cert/key from environment; IdPs configured via Django admin.

# Ensure third_party_auth is in INSTALLED_APPS (should be in base Open edX).
# Use full dotted path — edx-platform registers it as 'common.djangoapps.third_party_auth'.
if not any("third_party_auth" in app for app in INSTALLED_APPS):
    INSTALLED_APPS.append("common.djangoapps.third_party_auth")

# Enable third-party auth feature flag (required for enterprise login routing).
FEATURES.setdefault("ENABLE_THIRD_PARTY_AUTH", True)
FEATURES.setdefault("ENABLE_ENTERPRISE_INTEGRATION", True)

# SAML SP certificate and private key — injected from ExternalSecrets.
# These override the SAMLConfiguration model values, allowing key rotation
# without Django admin access.
_saml_sp_cert = os.environ.get("SAML_SP_PUBLIC_CERT", "")
_saml_sp_key = os.environ.get("SAML_SP_PRIVATE_KEY", "")
if _saml_sp_cert and _saml_sp_key:
    SOCIAL_AUTH_SAML_SP_PUBLIC_CERT = _saml_sp_cert
    SOCIAL_AUTH_SAML_SP_PRIVATE_KEY = _saml_sp_key

# SAML SP entity ID — defaults to LMS URL (standard for Open edX).
SOCIAL_AUTH_SAML_SP_ENTITY_ID = os.environ.get(
    "SAML_SP_ENTITY_ID", MEREKA_LMS_BASE_URL
)

# SAML technical and support contacts (required by SAML spec).
SOCIAL_AUTH_SAML_TECHNICAL_CONTACT = {
    "givenName": os.environ.get("SAML_CONTACT_NAME", "Mereka Tech"),
    "emailAddress": os.environ.get("SAML_CONTACT_EMAIL", "tech@mereka.io"),
}
SOCIAL_AUTH_SAML_SUPPORT_CONTACT = SOCIAL_AUTH_SAML_TECHNICAL_CONTACT

# ── SAML Backend Configuration ──────────────────────────────────────────
# @covers AC-027, AC-028, AC-029, AC-030 (enterprise-microservices_spec.md Phase 4)
# Configure python-social-auth SAML backend for enterprise SSO.
# Per-tenant IdP configurations are managed via Django admin (SAMLProviderConfig).

# SAML backend pipeline — controls auto-provisioning and JIT attribute mapping.
SOCIAL_AUTH_SAML_PIPELINE = [
    # Extract SAML assertion attributes into kwargs
    "common.djangoapps.third_party_auth.pipeline.parse_saml_attributes",
    # Get or create user based on SAML NameID or email
    "social_core.pipeline.social_auth.social_details",
    "social_core.pipeline.social_auth.social_uid",
    "social_core.pipeline.social_auth.auth_allowed",
    "social_core.pipeline.social_auth.social_user",
    # Auto-provision: create user if not exists (JIT provisioning)
    "social_core.pipeline.user.get_username",
    "social_core.pipeline.user.create_user",
    # Link user to enterprise customer
    "common.djangoapps.third_party_auth.pipeline.associate_by_email_if_login_api",
    "social_core.pipeline.social_auth.associate_user",
    "social_core.pipeline.social_auth.load_extra_data",
    # Update user profile from SAML attributes (JIT attribute sync)
    "common.djangoapps.third_party_auth.pipeline.set_logged_in_cookies",
    "common.djangoapps.third_party_auth.pipeline.login_analytics",
]

# SAML security settings
SOCIAL_AUTH_SAML_SECURITY_CONFIG = {
    "authnRequestsSigned": True,  # Sign authentication requests
    "wantAssertionsSigned": True,  # Require signed assertions
    "wantMessagesSigned": False,  # Optional: require signed messages
    "signatureAlgorithm": "http://www.w3.org/2001/04/xmldsig-more#rsa-sha256",
    "digestAlgorithm": "http://www.w3.org/2001/04/xmlenc#sha256",
}

# SAML clock skew tolerance: 120 seconds (per edge case spec)
SOCIAL_AUTH_SAML_ASSERTION_EXPIRATION = 120

# SAML retry/backoff configuration for IdP metadata refresh failures
SOCIAL_AUTH_SAML_METADATA_RETRY_BACKOFF = 30  # Base: 30 seconds
SOCIAL_AUTH_SAML_METADATA_RETRY_BACKOFF_MAX = 900  # Max: 15 minutes
SOCIAL_AUTH_SAML_METADATA_RETRY_MAX = 5  # Max retries: 5

# SAML organization info (displayed in SP metadata)
SOCIAL_AUTH_SAML_ORG_INFO = {
    "en-US": {
        "name": "Mereka Academy",
        "displayname": "Mereka Academy",
        "url": MEREKA_LMS_BASE_URL,
    }
}

# ── Integrated Channel Connectors ───────────────────────────────────────
# @covers AC-031, AC-032, AC-033 (enterprise-microservices_spec.md Phase 4)
# Configure Degreed and Cornerstone channel connectors with env var patterns.
# Per-client credentials are stored encrypted in the database (not here).

# Degreed API configuration (v2 API)
DEGREED_API_BASE_URL = os.environ.get("DEGREED_API_BASE_URL", "https://api.degreed.com/api/v2")
DEGREED_OAUTH_TOKEN_URL = os.environ.get("DEGREED_OAUTH_TOKEN_URL", "https://api.degreed.com/oauth/token")
DEGREED_COMPLETION_PROVIDER_ID = os.environ.get("DEGREED_COMPLETION_PROVIDER_ID", "Mereka Academy")

# Degreed sync configuration
DEGREED_SYNC_RETRY_BACKOFF = 30  # Base: 30 seconds
DEGREED_SYNC_RETRY_BACKOFF_MAX = 900  # Max: 15 minutes
DEGREED_SYNC_RETRY_MAX = 5  # Max retries: 5
DEGREED_SYNC_BATCH_SIZE = int(os.environ.get("DEGREED_SYNC_BATCH_SIZE", "500"))  # Paginate large learner sets
DEGREED_SYNC_TIMEOUT = int(os.environ.get("DEGREED_SYNC_TIMEOUT", "300"))  # 5 minutes per API call

# Cornerstone OnDemand (CSOD) API configuration
CORNERSTONE_API_BASE_URL = os.environ.get("CORNERSTONE_API_BASE_URL", "")  # Client-specific
CORNERSTONE_OAUTH_TOKEN_URL = os.environ.get("CORNERSTONE_OAUTH_TOKEN_URL", "")  # Client-specific

# Cornerstone sync configuration
CORNERSTONE_SYNC_RETRY_BACKOFF = 30  # Base: 30 seconds
CORNERSTONE_SYNC_RETRY_BACKOFF_MAX = 900  # Max: 15 minutes
CORNERSTONE_SYNC_RETRY_MAX = 5  # Max retries: 5
CORNERSTONE_SYNC_BATCH_SIZE = int(os.environ.get("CORNERSTONE_SYNC_BATCH_SIZE", "500"))
CORNERSTONE_SYNC_TIMEOUT = int(os.environ.get("CORNERSTONE_SYNC_TIMEOUT", "300"))

# Integrated channels global configuration
INTEGRATED_CHANNELS_API_CHUNK_SIZE = 500  # Max learners per sync batch (edge case: large enterprises)
INTEGRATED_CHANNELS_TRANSMISSION_CHUNK_SIZE = 100  # Max records per API call to external system
INTEGRATED_CHANNELS_LOG_PII = False  # Do NOT log learner emails (GDPR/PDPA compliance)
