# -*- coding: utf-8 -*-
import logging
import os
import sys
import importlib
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


def _module_available(module_name):
    try:
        importlib.import_module(module_name)
        return True
    except Exception:
        return False


# Override SECRET_KEY from environment variable (required for K8s deployment).
# Nonprod fallback chain prevents hard crashes when legacy secret keys drift to
# empty while JWT keys remain populated.
SECRET_KEY = (
    os.environ.get("OPENEDX_SECRET_KEY")
    or os.environ.get("SECRET_KEY")
    or os.environ.get("JWT_SECRET_KEY_LMS")
    or os.environ.get("JWT_SECRET_KEY")
    or ""
)
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

# ORA2 Operations & Observability (Assessment Phase 1)
# File upload restrictions
ORA2_FILE_UPLOAD_TYPE_WHITELIST = ['pdf', 'docx', 'xlsx', 'pptx', 'jpg', 'jpeg', 'png', 'mp4']
ORA2_MAX_FILE_SIZE = 10485760  # 10MB in bytes
ORA2_MAX_FILES_PER_SUBMISSION = 5

# Peer assessment configuration
ORA2_PEER_ASSESSMENT_MUST_GRADE = 3  # Students must grade 3 peers
ORA2_PEER_ASSESSMENT_MUST_BE_GRADED_BY = 3  # Students must be graded by 3 peers
ORA2_PEER_CALIBRATION_ENABLED = True  # Enable calibration essays

# Staff grading fallback
ORA2_PEER_GRADING_TIMEOUT_DAYS = 7  # Fallback to staff after 7 days
ORA2_FALLBACK_RETENTION_DAYS = 90  # Keep fallback records for 90 days
ORA2_METRICS_RETENTION_DAYS = 365  # Keep metrics for 1 year
ORA2_FILE_RETENTION_DAYS = 180  # Keep file records for 180 days

# Feature flag
ENABLE_ORA2_OPERATIONS = os.environ.get('ENABLE_ORA2_OPERATIONS', 'true').lower() == 'true'

# Timed Exams - Server-Side Enforcement & Accommodations (Assessment Phase 2)
# Configure edx-proctoring for timed-only exams (no proctoring provider)
PROCTORING_BACKENDS = {
    'DEFAULT': 'null',  # No-op backend for timed-only exams
}

# Enable timed exams feature
FEATURES['ENABLE_SPECIAL_EXAMS'] = True  # Timed exams + proctored exams
FEATURES['ENABLE_TIMED_EXAMS'] = True  # Specifically enable timed exams

# Server-side timer enforcement
TIMED_EXAM_ENFORCE_SERVER_SIDE = True  # Server authoritative (not client timer)
TIMED_EXAM_GRACE_PERIOD_SECONDS = 60  # 1 minute grace period after timer expires
TIMED_EXAM_AUTO_SUBMIT_ON_EXPIRY = True  # Auto-submit when timer expires

# Time extension defaults
TIMED_EXAM_DEFAULT_MULTIPLIER = 1.5  # Default 1.5x for accommodations
TIMED_EXAM_MAX_MULTIPLIER = 5.0  # Maximum 5x time extension allowed

# Multi-device detection
TIMED_EXAM_ENABLE_MULTI_DEVICE_DETECTION = True  # Block concurrent sessions
TIMED_EXAM_DEVICE_FINGERPRINT_ENABLED = True  # Track device fingerprints

# Grade release configuration
TIMED_EXAM_DEFAULT_GRADE_RELEASE_MODE = 'window_close'  # Grades pending until window closes
TIMED_EXAM_GRADE_HOLD_ENABLED = True  # Enable grade hold functionality

# Session cleanup (for expired sessions)
TIMED_EXAM_SESSION_CLEANUP_DAYS = 30  # Clean up sessions older than 30 days

# Feature flag
ENABLE_TIMED_EXAM_ENHANCEMENTS = os.environ.get('ENABLE_TIMED_EXAM_ENHANCEMENTS', 'true').lower() == 'true'

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
    # Enterprise admin portal
    f"admin.{MEREKA_LMS_DOMAIN}",
]
for origin in [
    MEREKA_LMS_BASE_URL,
    MEREKA_STUDIO_BASE_URL,
    MEREKA_MFE_BASE_URL,
    f"{MEREKA_SCHEME}://apps.{MEREKA_BIJI_DOMAIN}",
    f"{MEREKA_SCHEME}://apps.{MEREKA_SKILLOURFUTURE_DOMAIN}",
    f"{MEREKA_SCHEME}://{MEREKA_BIJI_DOMAIN}",
    f"{MEREKA_SCHEME}://{MEREKA_SKILLOURFUTURE_DOMAIN}",
    f"{MEREKA_SCHEME}://admin.{MEREKA_LMS_DOMAIN}",
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
    # Brand color tokens (consumed by MFE runtime for tenant-aware theming)
    "BRAND_PRIMARY": "#2d898b",
    "BRAND_SECONDARY": "#ab3b78",
    "BRAND_ACCENT": "#295cad",
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



MFE_CONFIG["COURSE_AUTHORING_MICROFRONTEND_URL"] = f"{MEREKA_MFE_BASE_URL}/authoring"
MFE_CONFIG["ENABLE_ASSETS_PAGE"] = "true"
MFE_CONFIG["ENABLE_HOME_PAGE_COURSE_API_V2"] = "true"
MFE_CONFIG["ENABLE_PROGRESS_GRAPH_SETTINGS"] = "true"
MFE_CONFIG["ENABLE_TAGGING_TAXONOMY_PAGES"] = "true"



DISCUSSIONS_MICROFRONTEND_URL = f"{MEREKA_MFE_BASE_URL}/discussions"
MFE_CONFIG["DISCUSSIONS_MFE_BASE_URL"] = DISCUSSIONS_MICROFRONTEND_URL
DISCUSSIONS_MFE_FEEDBACK_URL = None



WRITABLE_GRADEBOOK_URL = f"{MEREKA_MFE_BASE_URL}/gradebook"

# Hardening: keep platform admins as staff/superuser (prevents drift).
MIDDLEWARE = list(MIDDLEWARE)
_platform_admin_middleware = "lms.envs.tutor.mereka_platform_admin.MerekaPlatformAdminMiddleware"
if _module_available("lms.envs.tutor.mereka_platform_admin"):
    MIDDLEWARE.append(_platform_admin_middleware)
else:
    logging.getLogger(__name__).warning("Skipping missing middleware module: %s", _platform_admin_middleware)

_lms_multisite_module = "lms.envs.tutor.mereka_multisite"
if _module_available(_lms_multisite_module):
    MIDDLEWARE.append("lms.envs.tutor.mereka_multisite.MerekaCookieDomainMiddleware")
else:
    logging.getLogger(__name__).warning("Skipping missing middleware module: %s", _lms_multisite_module)

# Studio SSO uses LMS OAuth2 provider endpoints. MFEs authenticate via JWT
# cookies; legacy OAuth2 views still expect an authenticated request.user.
# Bridge JWT-cookie auth into request.user/session for `/oauth2/*` only when
# the optional helper module is present in this image.
_jwt_bridge_middleware = "lms.envs.tutor.mereka_jwt_session.MerekaJwtToSessionBridgeMiddleware"
if _module_available("lms.envs.tutor.mereka_jwt_session"):
    MIDDLEWARE.append(_jwt_bridge_middleware)
else:
    logging.getLogger(__name__).warning("Skipping missing middleware module: %s", _jwt_bridge_middleware)



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
    'course-authoring': f"{MEREKA_MFE_BASE_URL}/authoring",
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
if _module_available("lms.envs.tutor.mereka_forwarded_headers"):
    if _forwarded_headers_middleware not in MIDDLEWARE:
        MIDDLEWARE.insert(0, _forwarded_headers_middleware)
else:
    logging.getLogger(__name__).warning("Skipping missing middleware module: %s", _forwarded_headers_middleware)

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

# ── Push Notifications (FCM) ────────────────────────────────────────────
# @spec: email-notifications-pipeline_spec.md (Phase 4: Push Notifications)
# @covers AC-015, AC-016, AC-017, AC-018, AC-019

# Feature flag — gated globally; enable per-tenant via Django admin.
NOTIFICATION_PUSH_ENABLED = os.environ.get(
    "ENABLE_PUSH_NOTIFICATIONS", "false"
).lower() in ("true", "1", "yes")
FEATURES["ENABLE_PUSH_NOTIFICATIONS"] = NOTIFICATION_PUSH_ENABLED

# Firebase Cloud Messaging (FCM) HTTP v1 API configuration
FCM_PROJECT_ID = os.environ.get("FCM_PROJECT_ID", "")
FCM_SERVICE_ACCOUNT_KEY = os.environ.get("MEREKA_LMS_FCM_SERVICE_ACCOUNT_KEY", "")

# Push dispatch retry/backoff (spec: base 30s, max 15min, 5 retries)
PUSH_NOTIFICATION_RETRY_BACKOFF = 30
PUSH_NOTIFICATION_RETRY_BACKOFF_MAX = 900
PUSH_NOTIFICATION_RETRY_MAX = 5

# Batch size for FCM API calls (spec: up to 500 per request)
PUSH_NOTIFICATION_BATCH_SIZE = 500

# ACE channel configuration — add push channel
ACE_ENABLED_CHANNELS.append("push") if "push" not in ACE_ENABLED_CHANNELS else None

# Register openedx_push_notifications app
if "openedx_push_notifications" not in INSTALLED_APPS:
    INSTALLED_APPS.append("openedx_push_notifications")

# ── Email Templates & Bulk Campaigns ─────────────────────────────────────
# @spec: email-notifications-pipeline_spec.md (Phase 5: Templates + Bulk Campaigns)
# @covers AC-025, AC-026, AC-027, AC-028, AC-029, AC-030, AC-031, AC-032

# Feature flag — gate bulk campaigns globally
NOTIFICATION_BULK_CAMPAIGNS_ENABLED = os.environ.get(
    "NOTIFICATION_BULK_CAMPAIGNS_ENABLED", "false"
).lower() in ("true", "1", "yes")
FEATURES["ENABLE_BULK_CAMPAIGNS"] = NOTIFICATION_BULK_CAMPAIGNS_ENABLED

# Per-tenant email rate limiting (token bucket: 50 emails/sec per tenant)
EMAIL_RATE_LIMIT_PER_TENANT = int(os.environ.get("EMAIL_RATE_LIMIT_PER_TENANT", "50"))

# Campaign batch processing
CAMPAIGN_BATCH_SIZE = int(os.environ.get("CAMPAIGN_BATCH_SIZE", "100"))
CAMPAIGN_RETRY_BACKOFF = 30  # Base: 30 seconds
CAMPAIGN_RETRY_BACKOFF_MAX = 900  # Max: 15 minutes
CAMPAIGN_RETRY_MAX = 5  # Max retries

# Default branding (overridden per-tenant via TenantConfig)
DEFAULT_ORG_DISPLAY_NAME = os.environ.get("DEFAULT_ORG_DISPLAY_NAME", "Mereka Academy")
DEFAULT_ORG_LOGO_URL = os.environ.get("DEFAULT_ORG_LOGO_URL", "")
DEFAULT_ORG_PRIMARY_COLOR = os.environ.get("DEFAULT_ORG_PRIMARY_COLOR", "#1a73e8")
DEFAULT_ORG_ACCENT_COLOR = os.environ.get("DEFAULT_ORG_ACCENT_COLOR", "#4285f4")
DEFAULT_ORG_SUPPORT_EMAIL = os.environ.get("DEFAULT_ORG_SUPPORT_EMAIL", "")

# Register openedx_email_templates app
if "openedx_email_templates" not in INSTALLED_APPS:
    INSTALLED_APPS.append("openedx_email_templates")

# ── Email Digests & Analytics ────────────────────────────────────────────
# @spec: email-notifications-pipeline_spec.md (Phase 6: Digests + Analytics)
# @covers AC-037, AC-038, AC-039, AC-040, AC-041, AC-042

# Feature flags (default: off for safe rollout)
ENABLE_EMAIL_DIGESTS = os.environ.get(
    "ENABLE_EMAIL_DIGESTS", "false"
).lower() in ("true", "1", "yes")
FEATURES["ENABLE_EMAIL_DIGESTS"] = ENABLE_EMAIL_DIGESTS

ENABLE_EMAIL_ANALYTICS = os.environ.get(
    "ENABLE_EMAIL_ANALYTICS", "false"
).lower() in ("true", "1", "yes")
FEATURES["ENABLE_EMAIL_ANALYTICS"] = ENABLE_EMAIL_ANALYTICS

# Click tracking feature flag
NOTIFICATION_CLICK_TRACKING_ENABLED = os.environ.get(
    "NOTIFICATION_CLICK_TRACKING_ENABLED", "false"
).lower() in ("true", "1", "yes")

# Digest scheduling (spec: 09:00 in user's timezone)
DIGEST_DEFAULT_SEND_HOUR = int(os.environ.get("DIGEST_DEFAULT_SEND_HOUR", "9"))
DIGEST_DEFAULT_TIMEZONE = os.environ.get("DIGEST_DEFAULT_TIMEZONE", "Asia/Kuala_Lumpur")

# Engagement data retention (spec: 12 months)
EMAIL_ANALYTICS_RETENTION_MONTHS = int(os.environ.get("EMAIL_ANALYTICS_RETENTION_MONTHS", "12"))

# GDPR deletion deadline (spec: 30 days)
GDPR_DELETION_DEADLINE_DAYS = int(os.environ.get("GDPR_DELETION_DEADLINE_DAYS", "30"))

# Register openedx_email_digests app
if "openedx_email_digests" not in INSTALLED_APPS:
    INSTALLED_APPS.append("openedx_email_digests")

# ── Multi-Tenant Foundation ──────────────────────────────────────────────
# @spec: multi-tenancy-architecture_spec.md (Phase 0: Foundation)
# @covers: EnterpriseCustomer ↔ Site mapping, cache namespacing,
#          xAPI tagging, feature flags, branding, metrics

# Master feature flag for multi-tenancy (AC-MTA-001 through AC-MTA-033)
MULTI_TENANCY_ENABLED = os.environ.get(
    "MULTI_TENANCY_ENABLED", "false"
).lower() in ("true", "1", "yes")
FEATURES["MULTI_TENANCY_ENABLED"] = MULTI_TENANCY_ENABLED

# Feature flags (default: off — explicit opt-in per tenant)
ENABLE_MULTI_TENANT_BRANDING = os.environ.get(
    "ENABLE_MULTI_TENANT_BRANDING", "false"
).lower() in ("true", "1", "yes")
FEATURES["ENABLE_MULTI_TENANT_BRANDING"] = ENABLE_MULTI_TENANT_BRANDING

ENABLE_TENANT_ANALYTICS_SCOPING = os.environ.get(
    "ENABLE_TENANT_ANALYTICS_SCOPING", "false"
).lower() in ("true", "1", "yes")
FEATURES["ENABLE_TENANT_ANALYTICS_SCOPING"] = ENABLE_TENANT_ANALYTICS_SCOPING

# Redis cache namespace format: enterprise:{uuid}:{key_type}:{key_id}
TENANT_CACHE_NAMESPACE_FORMAT = "enterprise:{uuid}:{key_type}:{key_id}"

# EnterpriseCustomer ↔ Django Site mapping (site_id FK)
ENTERPRISE_SITE_MAPPING_ENABLED = os.environ.get(
    "ENTERPRISE_SITE_MAPPING_ENABLED", "false"
).lower() in ("true", "1", "yes")

# ClickHouse xAPI enterprise_customer_uuid column (nullable)
XAPI_ENTERPRISE_UUID_ENABLED = os.environ.get(
    "XAPI_ENTERPRISE_UUID_ENABLED", "false"
).lower() in ("true", "1", "yes")

# Tenant branding assets directory
TENANT_BRANDING_DIR = os.path.join(
    os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(__file__)))),
    "themes", "mereka", "tenants"
)

# SiteConfiguration per-tenant JSON overlay support
SITE_CONFIGURATION_TENANT_OVERLAYS = True

# MFE branding injection from SiteConfiguration
MFE_BRANDING_FROM_SITE_CONFIG = os.environ.get(
    "MFE_BRANDING_FROM_SITE_CONFIG", "false"
).lower() in ("true", "1", "yes")

# Register openedx_tenant_cache app
if "openedx_tenant_cache" not in INSTALLED_APPS:
    INSTALLED_APPS.append("openedx_tenant_cache")

# ── Multi-Tenant Phase 2: Cross-Tenant Isolation ────────────────────────
# @spec: multi-tenancy-architecture_spec.md (Phase 2: Pilot + Isolation)
# @covers: AC-TEN-007 through AC-TEN-013

# Cross-tenant API isolation enforcement
TENANT_ISOLATION_ENABLED = os.environ.get(
    "TENANT_ISOLATION_ENABLED", "false"
).lower() in ("true", "1", "yes")
FEATURES["TENANT_ISOLATION_ENABLED"] = TENANT_ISOLATION_ENABLED

# Superset RLS enforcement for analytics dashboards
SUPERSET_RLS_ENABLED = os.environ.get(
    "SUPERSET_RLS_ENABLED", "false"
).lower() in ("true", "1", "yes")

# Pilot tenant domains (for ALLOWED_HOSTS / CSRF_TRUSTED_ORIGINS)
PILOT_TENANT_DOMAINS = os.environ.get(
    "PILOT_TENANT_DOMAINS", ""
).split(",") if os.environ.get("PILOT_TENANT_DOMAINS") else []

for domain in PILOT_TENANT_DOMAINS:
    domain = domain.strip()
    if domain and domain not in ALLOWED_HOSTS:
        ALLOWED_HOSTS.append(domain)
    if domain:
        csrf_origin = f"https://{domain}"
        if csrf_origin not in CSRF_TRUSTED_ORIGINS:
            CSRF_TRUSTED_ORIGINS.append(csrf_origin)

# ── Multi-Tenant Phase 3: Operational Hardening ─────────────────────────
# @spec: multi-tenancy-architecture_spec.md (Phase 3: Hardening)
# @covers: AC-TEN-014 through AC-TEN-021

# Offboarding grace period (PDPA/GDPR compliance)
TENANT_OFFBOARD_GRACE_DAYS = int(os.environ.get(
    "TENANT_OFFBOARD_GRACE_DAYS", "30"
))

# Nightly isolation test CronJob
TENANT_NIGHTLY_ISOLATION_ENABLED = os.environ.get(
    "TENANT_NIGHTLY_ISOLATION_ENABLED", "false"
).lower() in ("true", "1", "yes")

# ── Content Libraries v2: Feature Flags ─────────────────────────────────
# @spec: content-libraries-v2 (Phase 0: Foundation Audit)
# @covers: AC-LIB-004 — Feature flags all default False

# Master switch for Content Libraries v2
CONTENT_LIBRARIES_V2_ENABLED = os.environ.get(
    "CONTENT_LIBRARIES_V2_ENABLED", "false"
).lower() in ("true", "1", "yes")
FEATURES["CONTENT_LIBRARIES_V2_ENABLED"] = CONTENT_LIBRARIES_V2_ENABLED

# Meilisearch-powered library content search
LIBRARIES_SEARCH_ENABLED = os.environ.get(
    "LIBRARIES_SEARCH_ENABLED", "false"
).lower() in ("true", "1", "yes")
FEATURES["LIBRARIES_SEARCH_ENABLED"] = LIBRARIES_SEARCH_ENABLED

# Library usage analytics tracking
LIBRARIES_ANALYTICS_ENABLED = os.environ.get(
    "LIBRARIES_ANALYTICS_ENABLED", "false"
).lower() in ("true", "1", "yes")
FEATURES["LIBRARIES_ANALYTICS_ENABLED"] = LIBRARIES_ANALYTICS_ENABLED

# Bulk import/export of library components
LIBRARIES_BULK_IMPORT_ENABLED = os.environ.get(
    "LIBRARIES_BULK_IMPORT_ENABLED", "false"
).lower() in ("true", "1", "yes")
FEATURES["LIBRARIES_BULK_IMPORT_ENABLED"] = LIBRARIES_BULK_IMPORT_ENABLED

# Public read access to library content (no auth required)
LIBRARIES_PUBLIC_READ_ENABLED = os.environ.get(
    "LIBRARIES_PUBLIC_READ_ENABLED", "false"
).lower() in ("true", "1", "yes")
FEATURES["LIBRARIES_PUBLIC_READ_ENABLED"] = LIBRARIES_PUBLIC_READ_ENABLED

# GCS bucket for Blockstore (Content Libraries v2 storage backend)
BLOCKSTORE_BUCKET_NAME = os.environ.get(
    "BLOCKSTORE_BUCKET_NAME", "lms-blockstore"
)

# ── Content Libraries v2: Phase 1 Core ──────────────────────────────────
# @spec: content-libraries-v2 (Phase 1: Platform Libraries)
# @covers: AC-LIB-007 through AC-LIB-013

# Library publish timeout (seconds) — AC-LIB-007 requires < 30s
LIBRARY_PUBLISH_TIMEOUT_SECONDS = int(os.environ.get(
    "LIBRARY_PUBLISH_TIMEOUT_SECONDS", "30"
))

# Soft-delete retention period (AC-LIB-009, AC-NEG-LIB-005)
LIBRARY_SOFT_DELETE_RETENTION_DAYS = int(os.environ.get(
    "LIBRARY_SOFT_DELETE_RETENTION_DAYS", "30"
))

# library_content XBlock default random pool size (AC-LIB-008)
LIBRARY_CONTENT_DEFAULT_COUNT = int(os.environ.get(
    "LIBRARY_CONTENT_DEFAULT_COUNT", "5"
))



# ── Kajabi SSO/OAuth Integration ───────────────────────────────────────
# @spec: Kajabi SSO Migration (mereka-lms-f98)
# @covers: AC-SSO-001 through AC-SSO-005

# Register openedx_kajabi_sso app
if "openedx_kajabi_sso" not in INSTALLED_APPS:
    INSTALLED_APPS.append("openedx_kajabi_sso")

# Enable Kajabi SSO
KAJABI_SSO_ENABLED = os.environ.get(
    "KAJABI_SSO_ENABLED", "false"
).lower() in ("true", "1", "yes")
FEATURES["KAJABI_SSO_ENABLED"] = KAJABI_SSO_ENABLED

# Kajabi OAuth2 credentials
KAJABI_OAUTH2_KEY = os.environ.get("KAJABI_OAUTH2_KEY", "")
KAJABI_OAUTH2_SECRET = os.environ.get("KAJABI_OAUTH2_SECRET", "")

# Configure social-auth backends for Kajabi
if KAJABI_SSO_ENABLED and KAJABI_OAUTH2_KEY and KAJABI_OAUTH2_SECRET:
    # Add Kajabi OAuth2 backend to authentication backends
    AUTHENTICATION_BACKENDS = list(AUTHENTICATION_BACKENDS) if AUTHENTICATION_BACKENDS else []

    # Insert Kajabi backends at the beginning (highest priority)
    if "openedx_kajabi_sso.backends.KajabiOAuth2Backend" not in AUTHENTICATION_BACKENDS:
        AUTHENTICATION_BACKENDS.insert(0, "openedx_kajabi_sso.backends.KajabiOAuth2Backend")

    # Add fallback backend after OAuth (AC-SSO-003)
    if "openedx_kajabi_sso.backends.KajabiSSOFallbackBackend" not in AUTHENTICATION_BACKENDS:
        AUTHENTICATION_BACKENDS.insert(1, "openedx_kajabi_sso.backends.KajabiSSOFallbackBackend")

    # Social auth pipeline for Kajabi
    SOCIAL_AUTH_KAJABI_KEY = KAJABI_OAUTH2_KEY
    SOCIAL_AUTH_KAJABI_SECRET = KAJABI_OAUTH2_SECRET
    SOCIAL_AUTH_KAJABI_SCOPE = ["read:user", "read:email"]

    # Redirect URLs
    LOGIN_REDIRECT_URL = os.environ.get("LOGIN_REDIRECT_URL", "/dashboard")
    SOCIAL_AUTH_LOGIN_REDIRECT_URL = LOGIN_REDIRECT_URL

# SSO fallback to email/password (AC-SSO-003)
KAJABI_SSO_ALLOW_FALLBACK = os.environ.get(
    "KAJABI_SSO_ALLOW_FALLBACK", "true"
).lower() in ("true", "1", "yes")

# Welcome email settings (AC-SSO-005)
KAJABI_WELCOME_EMAIL_ENABLED = os.environ.get(
    "KAJABI_WELCOME_EMAIL_ENABLED", "true"
).lower() in ("true", "1", "yes")

# ── Mobile Backend API ──────────────────────────────────────────────────
# @spec: Mobile Backend API (mereka-lms-2gck)
# @covers: AC-MOB-001 through AC-MOB-007

# Register openedx_mobile_api app
if "openedx_mobile_api" not in INSTALLED_APPS:
    INSTALLED_APPS.append("openedx_mobile_api")

# Enable mobile API
MOBILE_API_ENABLED = os.environ.get(
    "MOBILE_API_ENABLED", "false"
).lower() in ("true", "1", "yes")
FEATURES["MOBILE_API_ENABLED"] = MOBILE_API_ENABLED

# FCM (Firebase Cloud Messaging) server key (AC-MOB-006 - stored in ExternalSecrets)
FCM_SERVER_KEY = os.environ.get("FCM_SERVER_KEY", "")

# Mobile API performance settings (AC-MOB-001 - p95 <= 500ms)
MOBILE_API_CACHE_TIMEOUT = int(os.environ.get("MOBILE_API_CACHE_TIMEOUT", "300"))

# Mobile deep linking (AC-MOB-004, AC-MOB-005)
IOS_APP_ID = os.environ.get("IOS_APP_ID", "TEAM_ID.io.mereka.academy")
ANDROID_PACKAGE_NAME = os.environ.get("ANDROID_PACKAGE_NAME", "io.mereka.academy")
ANDROID_SHA256_FINGERPRINT = os.environ.get("ANDROID_SHA256_FINGERPRINT", "")

# ── Mobile Phase 2: iOS Stabilization ──────────────────────────────────
# @spec: Mobile Phase 2 - iOS Stabilization (mereka-lms-36f7)
# @covers: AC-MOB-008 through AC-MOB-015

# PKCE OAuth2 flow (AC-MOB-008)
IOS_OAUTH_PKCE_ENABLED = os.environ.get(
    "IOS_OAUTH_PKCE_ENABLED", "true"
).lower() in ("true", "1", "yes")

# Token lifecycle settings (AC-MOB-009, AC-MOB-010)
IOS_ACCESS_TOKEN_LIFETIME = int(os.environ.get("IOS_ACCESS_TOKEN_LIFETIME", "3600"))  # 1 hour
IOS_REFRESH_TOKEN_LIFETIME = int(os.environ.get("IOS_REFRESH_TOKEN_LIFETIME", "2592000"))  # 30 days
IOS_TOKEN_REFRESH_THRESHOLD = int(os.environ.get("IOS_TOKEN_REFRESH_THRESHOLD", "300"))  # 5 minutes

# APNs push notifications (AC-MOB-012)
APNS_ENABLED = os.environ.get("APNS_ENABLED", "false").lower() in ("true", "1", "yes")
APNS_CERTIFICATE_PATH = os.environ.get("APNS_CERTIFICATE_PATH", "")
APNS_KEY_ID = os.environ.get("APNS_KEY_ID", "")
APNS_TEAM_ID = os.environ.get("APNS_TEAM_ID", "")
APNS_BUNDLE_ID = os.environ.get("APNS_BUNDLE_ID", "io.mereka.academy")
APNS_USE_SANDBOX = os.environ.get("APNS_USE_SANDBOX", "true").lower() in ("true", "1", "yes")

# Security settings (AC-MOB-014, AC-MOB-015)
IOS_DISABLE_TOKEN_LOGGING = os.environ.get(
    "IOS_DISABLE_TOKEN_LOGGING", "true"
).lower() in ("true", "1", "yes")
IOS_CLEAR_SNAPSHOT_ON_BACKGROUND = os.environ.get(
    "IOS_CLEAR_SNAPSHOT_ON_BACKGROUND", "true"
).lower() in ("true", "1", "yes")

# Certificate pinning (security)
IOS_CERTIFICATE_PINNING_ENABLED = os.environ.get(
    "IOS_CERTIFICATE_PINNING_ENABLED", "true"
).lower() in ("true", "1", "yes")

# ── Content Libraries v2: Phase 2 Tenant Isolation ─────────────────────
# @spec: content-libraries-v2 (Phase 2: Tenant Libraries)
# @covers: AC-LIB-014 through AC-LIB-019

# Org-scoped library filtering (AC-LIB-014)
LIBRARY_TENANT_ISOLATION_ENABLED = os.environ.get(
    "LIBRARY_TENANT_ISOLATION_ENABLED", "false"
).lower() in ("true", "1", "yes")

# Allow platform-global libraries (AC-LIB-015)
LIBRARY_PUBLIC_READ_ENABLED = os.environ.get(
    "LIBRARY_PUBLIC_READ_ENABLED", "false"
).lower() in ("true", "1", "yes")

# RBAC enforcement for library operations (AC-LIB-016)
LIBRARY_RBAC_ENABLED = os.environ.get(
    "LIBRARY_RBAC_ENABLED", "false"
).lower() in ("true", "1", "yes")

# Security event logging for cross-tenant attempts (AC-LIB-018)
LIBRARY_ACCESS_LOGGING_ENABLED = os.environ.get(
    "LIBRARY_ACCESS_LOGGING_ENABLED", "false"
).lower() in ("true", "1", "yes")


# ── Kajabi SSO/OAuth Integration ───────────────────────────────────────
# @spec: kajabi-sso
# @covers: AC-SSO-001 through AC-SSO-005

# Enable Kajabi SSO backend (AC-SSO-001)
KAJABI_SSO_ENABLED = os.environ.get(
    "KAJABI_SSO_ENABLED", "false"
).lower() in ("true", "1", "yes")

# OAuth2 client slug for Kajabi SSO
KAJABI_SSO_CLIENT_SLUG = os.environ.get(
    "KAJABI_SSO_CLIENT_SLUG", "mereka-kajabi-sso"
)

# Welcome email settings (AC-SSO-005)
KAJABI_WELCOME_EMAIL_ENABLED = os.environ.get(
    "KAJABI_WELCOME_EMAIL_ENABLED", "false"
).lower() in ("true", "1", "yes")

KAJABI_WELCOME_EMAIL_FROM = os.environ.get(
    "KAJABI_WELCOME_EMAIL_FROM", "noreply@mereka.io"
)

KAJABI_WELCOME_EMAIL_SUPPORT = os.environ.get(
    "KAJABI_WELCOME_EMAIL_SUPPORT", "support@mereka.io"
)

# SSO fallback — always keep email/password as fallback (AC-SSO-003)
KAJABI_SSO_FALLBACK_ENABLED = True  # NEVER disable this

# Register Kajabi SSO app
if "openedx_kajabi_sso" not in INSTALLED_APPS:
    INSTALLED_APPS.append("openedx_kajabi_sso")

# Add Kajabi SSO backend to authentication backends (AC-SSO-001, AC-SSO-003)
# IMPORTANT: Placed AFTER default backends so email/password always works as fallback
if KAJABI_SSO_ENABLED:
    AUTHENTICATION_BACKENDS = list(AUTHENTICATION_BACKENDS) if isinstance(AUTHENTICATION_BACKENDS, tuple) else AUTHENTICATION_BACKENDS
    if "openedx_kajabi_sso.backend.KajabiSsoBackend" not in AUTHENTICATION_BACKENDS:
        AUTHENTICATION_BACKENDS.append("openedx_kajabi_sso.backend.KajabiSsoBackend")

# ── Content Libraries v2: Phase 3 Scale, Search, Analytics ─────────────
# @spec: content-libraries-v2 (Phase 3: Scale + Search + Analytics)
# @covers: AC-LIB-020 through AC-LIB-025

# Meilisearch integration for library search (AC-LIB-021)
LIBRARY_SEARCH_ENABLED = os.environ.get(
    "LIBRARY_SEARCH_ENABLED", "false"
).lower() in ("true", "1", "yes")

# Usage analytics tracking (AC-LIB-022)
LIBRARY_ANALYTICS_ENABLED = os.environ.get(
    "LIBRARY_ANALYTICS_ENABLED", "false"
).lower() in ("true", "1", "yes")

# GCS backup for library content (AC-LIB-023, AC-LIB-024)
LIBRARY_BACKUP_ENABLED = os.environ.get(
    "LIBRARY_BACKUP_ENABLED", "false"
).lower() in ("true", "1", "yes")

# Backup retention days (AC-NEG-LIB-011)
LIBRARY_BACKUP_RETENTION_DAYS = int(os.environ.get(
    "LIBRARY_BACKUP_RETENTION_DAYS", "90"
))

# Performance: listing API pagination (AC-LIB-020)
LIBRARY_LIST_PAGE_SIZE = int(os.environ.get(
    "LIBRARY_LIST_PAGE_SIZE", "50"
))

# Performance: select_related/prefetch_related optimization
LIBRARY_QUERY_OPTIMIZATION_ENABLED = os.environ.get(
    "LIBRARY_QUERY_OPTIMIZATION_ENABLED", "false"
).lower() in ("true", "1", "yes")

# ── Content Libraries v2: Phase 3-4 Multi-Tenant Scale + Hardening ─────
# @spec: content-libraries-v2 (Phase 3-4: Multi-Tenant Scale)
# @covers: AC-LIB-026 through AC-LIB-032

# Tenant library quotas (AC-LIB-026)
LIBRARY_QUOTAS_ENABLED = os.environ.get(
    "LIBRARY_QUOTAS_ENABLED", "false"
).lower() in ("true", "1", "yes")

LIBRARY_TENANT_MAX_LIBRARIES = int(os.environ.get(
    "LIBRARY_TENANT_MAX_LIBRARIES", "100"
))

LIBRARY_TENANT_MAX_COMPONENTS = int(os.environ.get(
    "LIBRARY_TENANT_MAX_COMPONENTS", "10000"
))

# Rate limiting per org (AC-LIB-029)
LIBRARY_RATE_LIMITING_ENABLED = os.environ.get(
    "LIBRARY_RATE_LIMITING_ENABLED", "false"
).lower() in ("true", "1", "yes")

LIBRARY_RATE_LIMIT_PER_MINUTE = int(os.environ.get(
    "LIBRARY_RATE_LIMIT_PER_MINUTE", "60"
))

# xAPI event tracking (AC-LIB-027)
LIBRARY_XAPI_ENABLED = os.environ.get(
    "LIBRARY_XAPI_ENABLED", "false"
).lower() in ("true", "1", "yes")

# Content sanitization (AC-LIB-031, AC-NEG-LIB-014)
LIBRARY_CONTENT_SANITIZATION_ENABLED = os.environ.get(
    "LIBRARY_CONTENT_SANITIZATION_ENABLED", "false"
).lower() in ("true", "1", "yes")

# Cross-tenant export/import
LIBRARY_CROSS_TENANT_EXPORT_ENABLED = os.environ.get(
    "LIBRARY_CROSS_TENANT_EXPORT_ENABLED", "false"
).lower() in ("true", "1", "yes")

# ── Video Pipeline: Phase 1 MCT Migration Validation ─────────────────
# @spec: bead mereka-lms-ho3i
# @covers: AC-VID-001 through AC-VID-006

# Feature flag for video pipeline migration validation
VIDEO_PIPELINE_ENABLED = os.environ.get(
    "VIDEO_PIPELINE_ENABLED", "false"
).lower() in ("true", "1", "yes")

# Mux playback URL base
MUX_PLAYBACK_BASE_URL = os.environ.get(
    "MUX_PLAYBACK_BASE_URL", "https://stream.mux.com"
)

# MCT migration batch identifier
MCT_MIGRATION_BATCH = os.environ.get(
    "MCT_MIGRATION_BATCH", "mct-2025-12-29"
)

# Expected total videos from MCT migration
MCT_EXPECTED_VIDEO_COUNT = int(os.environ.get(
    "MCT_EXPECTED_VIDEO_COUNT", "503"
))

# Playback health check timeout (seconds)
VIDEO_PLAYBACK_CHECK_TIMEOUT = int(os.environ.get(
    "VIDEO_PLAYBACK_CHECK_TIMEOUT", "10"
))

# Add openedx_video_pipeline to INSTALLED_APPS
INSTALLED_APPS += ['openedx_video_pipeline']

# ── Video Pipeline: Phase 2 — XBlock, Subtitles, Protection, Analytics ──
# @spec: video-pipeline-delivery_spec.md (Phase 2)
# @bead: mereka-lms-2tli

# xAPI video events to ClickHouse/Aspects pipeline
ENABLE_VIDEO_XAPI_EVENTS = os.environ.get(
    "ENABLE_VIDEO_XAPI_EVENTS", "false"
).lower() in ("true", "1", "yes")

# Video analytics event recording
ENABLE_VIDEO_ANALYTICS = os.environ.get(
    "ENABLE_VIDEO_ANALYTICS", "false"
).lower() in ("true", "1", "yes")

# Mux signed playback for restricted courses
ENABLE_MUX_SIGNED_PLAYBACK = os.environ.get(
    "ENABLE_MUX_SIGNED_PLAYBACK", "false"
).lower() in ("true", "1", "yes")

# Mux signing key credentials (from ExternalSecrets)
MUX_SIGNING_KEY_ID = os.environ.get("MUX_SIGNING_KEY_ID", "")
MUX_SIGNING_PRIVATE_KEY = os.environ.get("MUX_SIGNING_PRIVATE_KEY", "")

# Signed URL expiry (hours)
MUX_SIGNED_URL_EXPIRY_HOURS = int(os.environ.get(
    "MUX_SIGNED_URL_EXPIRY_HOURS", "12"
))

# Domain restriction for signed playback
MUX_ENABLE_DOMAIN_RESTRICTION = os.environ.get(
    "MUX_ENABLE_DOMAIN_RESTRICTION", "false"
).lower() in ("true", "1", "yes")

MUX_PLAYBACK_AUDIENCE = os.environ.get(
    "MUX_PLAYBACK_AUDIENCE", "academyv2.mereka.io"
)

# Register video analytics and protection apps
INSTALLED_APPS += ['openedx_video_analytics', 'openedx_video_protection']
