# -*- coding: utf-8 -*-
import logging
import os
import sys
import importlib
from urllib.parse import urlparse
from lms.envs.production import *
from .mereka_footer import build_mereka_public_footer


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


def _is_mongodb_atlas_host(raw_value):
    value = (raw_value or "").strip().lower()
    if not value:
        return False

    if "://" in value:
        parsed = urlparse(value)
        host = (parsed.hostname or "").strip().lower()
    else:
        host = value.rsplit("@", 1)[-1]
        host = host.split("/", 1)[0].split("?", 1)[0].split("#", 1)[0]
        host = host.split(":", 1)[0].strip().lower()

    host = host.rstrip(".")
    return host == "mongodb.net" or host.endswith(".mongodb.net")


def _is_mongodb_srv_uri(raw_value):
    value = (raw_value or "").strip().lower()
    return value.startswith("mongodb+srv://")


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
COMMENTS_SERVICE_URL = "http://localhost:8000/forum"

# Shared MongoDB defaults for modulestore and forum Atlas fallback.
#
# The forum config below intentionally falls back to modulestore Atlas
# credentials when dedicated FORUM_MONGODB_* secrets are absent, so derive the
# modulestore values before the forum block uses them.
MONGODB_HOST = os.environ.get("MONGODB_HOST", "mongodb")
MONGODB_DB = os.environ.get("MONGODB_DB", "openedx")
_mongodb_is_atlas = _is_mongodb_atlas_host(MONGODB_HOST)

_mongodb_username = None
_mongodb_password = None
_mongodb_authsource = "admin"
if _mongodb_is_atlas:
    _mongodb_username = os.environ.get("MONGODB_USERNAME") or "cs_comments_user"
    _mongodb_password = os.environ.get("MONGODB_PASSWORD", "")
    _mongodb_authsource = os.environ.get("MONGODB_AUTHSOURCE", "admin")

# Forum MongoDB configuration.
# Reuses the same Atlas-detection logic as DOC_STORE_CONFIG above.
# For Atlas hosts (mongodb+srv:// or *.mongodb.net), auto-enables SSL and auth.
# For in-cluster MongoDB, uses anonymous auth with no SSL.
FORUM_MONGODB_DATABASE = "cs_comments_service"
_forum_mongo_host = os.environ.get("FORUM_MONGODB_HOST") or MONGODB_HOST or "mongodb"
_forum_mongo_host_lower = (_forum_mongo_host or "").lower()
_forum_mongo_is_atlas = _is_mongodb_atlas_host(_forum_mongo_host)
FORUM_MONGODB_CLIENT_PARAMETERS = {
    "host": _forum_mongo_host,
}
# SRV URIs resolve port via DNS; only set port for non-SRV connections.
if not _forum_mongo_host_lower.startswith("mongodb+srv://"):
    FORUM_MONGODB_CLIENT_PARAMETERS["port"] = int(
        os.environ.get("FORUM_MONGODB_PORT", "27017")
    )
# Atlas requires SSL and auth; derive from env or fall back to modulestore creds.
if _forum_mongo_is_atlas:
    FORUM_MONGODB_CLIENT_PARAMETERS["ssl"] = True
    _forum_username = os.environ.get("FORUM_MONGODB_USERNAME") or _mongodb_username
    _forum_password = os.environ.get("FORUM_MONGODB_PASSWORD") or _mongodb_password
    if _forum_username:
        FORUM_MONGODB_CLIENT_PARAMETERS["username"] = _forum_username
    if _forum_password:
        FORUM_MONGODB_CLIENT_PARAMETERS["password"] = _forum_password
    FORUM_MONGODB_CLIENT_PARAMETERS["authSource"] = os.environ.get(
        "FORUM_MONGODB_AUTH_SOURCE", "admin"
    )
else:
    _forum_ssl = os.environ.get("FORUM_MONGODB_USE_SSL", "false").lower() == "true"
    FORUM_MONGODB_CLIENT_PARAMETERS["ssl"] = _forum_ssl
    _fu = os.environ.get("FORUM_MONGODB_USERNAME") or None
    _fp = os.environ.get("FORUM_MONGODB_PASSWORD") or None
    if _fu:
        FORUM_MONGODB_CLIENT_PARAMETERS["username"] = _fu
    if _fp:
        FORUM_MONGODB_CLIENT_PARAMETERS["password"] = _fp
    _forum_auth_source = os.environ.get("FORUM_MONGODB_AUTH_SOURCE")
    if _forum_auth_source:
        FORUM_MONGODB_CLIENT_PARAMETERS["authSource"] = _forum_auth_source

# Meilisearch configuration (replaces Elasticsearch for forum search).
MEILISEARCH_ENABLED = True
MEILISEARCH_URL = "http://meilisearch:7700"
MEILISEARCH_INDEX_PREFIX = "tutor_"
# Secret managers and kubectl tooling sometimes preserve a trailing newline.
# Strip it so Meilisearch auth does not fail on otherwise-correct keys.
MEILISEARCH_API_KEY = (os.environ.get("MEILISEARCH_API_KEY", "") or "").rstrip("\r\n")
SEARCH_ENGINE = "search.meilisearch.MeilisearchEngine"

# Forum moderation and spam controls.
# The Python forum (openedx-forum v0.3.8) relies on the LMS discussions framework
# for abuse flagging, moderation roles, and structural limits. These settings
# are read by openedx.core.djangoapps.discussions and the forum package itself.
#
# Abuse flagging: learners can flag posts; staff/moderators see flagged content
# via the discussions MFE moderation queue. Flags are stored as abuse_flaggers
# arrays inside MongoDB cs_comments_service.contents documents.
FEATURES["ENABLE_DISCUSSION_EMAIL_DIGEST"] = False  # Disable legacy digest (MFE handles notifications)
FEATURES["ALLOW_HIDING_DISCUSSION_TAB"] = True      # Permit per-course discussion tab control

# Structural limits — prevent reply flooding and deep spam nesting.
# These are read by the forum package's validation layer.
FORUM_MAX_COMMENT_DEPTH = int(os.environ.get("FORUM_MAX_COMMENT_DEPTH", "2"))
FORUM_MAX_ALLOWED_THREADS = int(os.environ.get("FORUM_MAX_ALLOWED_THREADS", "0"))  # 0 = unlimited

# Rate limiting for discussion API endpoints.
# Uses Django REST framework's AnonRateThrottle / UserRateThrottle via the
# open-edx discussions REST API (openedx.core.djangoapps.discussions).
# Values: requests per minute for authenticated users posting new content.
FORUM_RATE_LIMIT_ENABLED = os.environ.get("FORUM_RATE_LIMIT_ENABLED", "true").lower() == "true"
FORUM_POST_RATE_LIMIT = os.environ.get("FORUM_POST_RATE_LIMIT", "30/min")   # threads + comments combined
FORUM_VOTE_RATE_LIMIT = os.environ.get("FORUM_VOTE_RATE_LIMIT", "60/min")   # votes (lower abuse risk)

# Spam detection.
# openedx-forum v0.3.8 does not ship a built-in ML spam classifier.
# Spam control relies on:
#   1. Abuse flagging by learners (abuse_flaggers in MongoDB, surfaced in moderation queue)
#   2. Moderator/staff actions: hide, delete, pin, close via discussions MFE
#   3. Rate limiting above (prevents bulk-posting bots)
#   4. Structural depth limits (prevents deep nested spam threads)
# Future: plug in an external spam filter via FORUM_SPAM_CHECK_BACKEND when upstream adds the hook.
FORUM_SPAM_CHECK_BACKEND = os.environ.get(
    "FORUM_SPAM_CHECK_BACKEND", ""
)  # empty string = disabled (no external classifier)

####### Settings common to LMS and CMS
import json
import os
from urllib.parse import urlparse

from xmodule.modulestore.modulestore_settings import update_module_store_settings

MEREKA_SCHEME = os.environ.get("MEREKA_SCHEME", "https")
MEREKA_LMS_DOMAIN = os.environ.get("MEREKA_LMS_DOMAIN", "academyv2.mereka.io")
MEREKA_DEV_DOMAIN = os.environ.get("MEREKA_DEV_DOMAIN", "academyv2.mereka.dev")
MEREKA_BIJI_DOMAIN = os.environ.get("MEREKA_BIJI_DOMAIN", "academy.biji-biji.com")
MEREKA_SKILLOURFUTURE_DOMAIN = os.environ.get(
    "MEREKA_SKILLOURFUTURE_DOMAIN",
    "skillourfuture.academy.mereka.io",
)

def _domain_from_base_url(raw_url: str) -> str:
    raw_url = (raw_url or "").strip()
    if not raw_url:
        return ""
    parsed = urlparse(raw_url if "://" in raw_url else f"https://{raw_url}")
    return (parsed.netloc or parsed.path or "").strip().rstrip("/")


MEREKA_STUDIO_DOMAIN = os.environ.get("MEREKA_STUDIO_DOMAIN", f"studio.{MEREKA_LMS_DOMAIN}")
_MEREKA_MFE_BASE_URL_OVERRIDE = (os.environ.get("MFE_BASE_URL") or "").strip().rstrip("/")
MEREKA_MFE_DOMAIN = (
    os.environ.get("MEREKA_MFE_DOMAIN")
    or _domain_from_base_url(_MEREKA_MFE_BASE_URL_OVERRIDE)
    or f"apps.{MEREKA_LMS_DOMAIN}"
)
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
MEREKA_MFE_BASE_URL = _MEREKA_MFE_BASE_URL_OVERRIDE or f"{MEREKA_SCHEME}://{MEREKA_MFE_DOMAIN}"
MEREKA_DISCOVERY_BASE_URL = f"{MEREKA_SCHEME}://{MEREKA_DISCOVERY_DOMAIN}"
MEREKA_ECOMMERCE_BASE_URL = f"{MEREKA_SCHEME}://{MEREKA_ECOMMERCE_DOMAIN}"
MEREKA_NOTES_BASE_URL = f"{MEREKA_SCHEME}://{MEREKA_NOTES_DOMAIN}"
MEREKA_CREDENTIALS_BASE_URL = f"{MEREKA_SCHEME}://{MEREKA_CREDENTIALS_DOMAIN}"
MEREKA_PREVIEW_BASE_URL = f"{MEREKA_SCHEME}://{MEREKA_PREVIEW_DOMAIN}"
MEREKA_AUTH_DOMAIN = os.environ.get("MEREKA_AUTH_DOMAIN", "auth0.mereka.io")
MEREKA_AUTH_BASE_URL = f"{MEREKA_SCHEME}://{MEREKA_AUTH_DOMAIN}"
MEREKA_OIDC_PROVIDER_SLUG = os.environ.get("MEREKA_OIDC_PROVIDER_SLUG", "mereka-lms")

# Keep OIDC provider routing aligned with environment domains. Base env.yml uses
# production defaults, so nonprod overlays must override via MEREKA_AUTH_DOMAIN.
SOCIAL_AUTH_OIDC_OIDC_ENDPOINT = (
    f"{MEREKA_AUTH_BASE_URL}/application/o/{MEREKA_OIDC_PROVIDER_SLUG}"
)
OAUTH_OIDC_ISSUER = f"{MEREKA_LMS_BASE_URL}/oauth2"
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

mongodb_parameters = {
    "db": MONGODB_DB,
    "host": MONGODB_HOST,
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
if not _is_mongodb_srv_uri(MONGODB_HOST):
    mongodb_parameters["port"] = int(os.environ.get("MONGODB_PORT", "27017"))
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

# Search connection parameters.
# SEARCH_ENGINE is set to MeilisearchEngine above (line ~150).
# ELASTIC_SEARCH_CONFIG is retained for any edx-search code paths that
# still reference it, but pointed at Meilisearch so connections don't
# hang against a dead Elasticsearch service.
ELASTIC_SEARCH_CONFIG = [{
  "host": "meilisearch",
  "port": 7700,
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
def _safe_add_app(app_path):
    """Add an app to INSTALLED_APPS only if importable (guards optional packages)."""
    module_name = app_path.split(".")[0] if "." in app_path else app_path
    # Skip import check for openedx.core.djangoapps (always in platform)
    if app_path.startswith("openedx.core.djangoapps.") or app_path.startswith("common.djangoapps."):
        if app_path not in INSTALLED_APPS:
            INSTALLED_APPS.append(app_path)
        return True
    try:
        __import__(module_name)
        if app_path not in INSTALLED_APPS:
            INSTALLED_APPS.append(app_path)
        return True
    except ImportError:
        return False

if "openedx.core.djangoapps.content_libraries.apps.ContentLibrariesConfig" not in INSTALLED_APPS:
    INSTALLED_APPS += ["openedx.core.djangoapps.content_libraries.apps.ContentLibrariesConfig"]
if "openedx.core.djangoapps.bookmarks.apps.BookmarksConfig" not in INSTALLED_APPS:
    INSTALLED_APPS += ["openedx.core.djangoapps.bookmarks.apps.BookmarksConfig"]
if "openedx.core.djangoapps.discussions.apps.DiscussionsConfig" not in INSTALLED_APPS:
    INSTALLED_APPS += ["openedx.core.djangoapps.discussions.apps.DiscussionsConfig"]
if "openedx.core.djangoapps.theming.apps.ThemingConfig" not in INSTALLED_APPS:
    INSTALLED_APPS += ["openedx.core.djangoapps.theming.apps.ThemingConfig"]
try:
    import openedx_advanced_xblocks  # noqa: F401
    if "openedx_advanced_xblocks.apps.AdvancedXBlocksConfig" not in INSTALLED_APPS:
        INSTALLED_APPS += ["openedx_advanced_xblocks.apps.AdvancedXBlocksConfig"]
except ImportError:
    pass

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
# JWT_PRIVATE_SIGNING_JWK: loaded from env var injected by ExternalSecret (MEREKA_LMS_JWT_PRIVATE_SIGNING_JWK).
# Never hardcode private key material here.
JWT_AUTH["JWT_PRIVATE_SIGNING_JWK"] = os.environ.get("JWT_PRIVATE_SIGNING_JWK", "")
# Derive the public JWK from the private key so they never drift.
_jwt_priv_jwk_raw = JWT_AUTH["JWT_PRIVATE_SIGNING_JWK"]
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
        "ISSUER": f"{MEREKA_LMS_BASE_URL}/oauth2",
        "AUDIENCE": "openedx",
        "SECRET_KEY": os.environ.get("JWT_SECRET_KEY_LMS", "")
    }
]

# Enable/Disable some features globally
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

# Programs & Program Certificates (requires Discovery + Credentials services)
FEATURES["ENABLE_PROGRAM_CERTIFICATES"] = os.environ.get(
    "ENABLE_PROGRAM_CERTIFICATES", "false"
).lower() in ("true", "1", "yes")

# CORS
CORS_ALLOW_CREDENTIALS = True
CORS_ORIGIN_ALLOW_ALL = False
# Production-mode settings must default to HTTPS-only browser behavior.
# Local direct-container workflows should use development.py instead of
# weakening deployed lanes here.
CORS_ALLOW_INSECURE = False
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

# Environment-owned overlays must harden this for live lanes.
# OAUTH_ENFORCE_SECURE = True ensures all OAuth redirects use HTTPS.
OAUTH_ENFORCE_SECURE = True

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
FEATURES["ENABLE_DISCUSSIONS_MFE"] = True


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
    MEREKA_DEV_NOTES_DOMAIN,
    MEREKA_DEV_CREDENTIALS_DOMAIN,
    # Multisite MFEs and Studio hosts (otherwise Django returns Bad Request (400)).
    f"apps.{MEREKA_BIJI_DOMAIN}",
    f"studio.{MEREKA_BIJI_DOMAIN}",
    f"apps.{MEREKA_SKILLOURFUTURE_DOMAIN}",
    f"studio.{MEREKA_SKILLOURFUTURE_DOMAIN}",
    # Enterprise portals
    f"admin.{MEREKA_LMS_DOMAIN}",
    f"learner.{MEREKA_LMS_DOMAIN}",
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
    f"{MEREKA_SCHEME}://learner.{MEREKA_LMS_DOMAIN}",
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
    "LOGO_URL": f"{MEREKA_LMS_BASE_URL}/theming/asset/{DEFAULT_SITE_THEME}/images/logo-horizontal.svg",
    "LOGO_WHITE_URL": f"{MEREKA_LMS_BASE_URL}/theming/asset/{DEFAULT_SITE_THEME}/images/logo-horizontal-white.svg",
    "LOGO_TRADEMARK_URL": f"{MEREKA_LMS_BASE_URL}/theming/asset/{DEFAULT_SITE_THEME}/images/logo.svg",
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
# Required for /api/discussion/v1/courses/ to return data instead of 404.
# Without this, the Discussions MFE loads but backend API calls fail because
# the discussion service routes are registered but not activated for MFE context.
DISCUSSIONS_MFE_ENABLED = True
FEATURES["ENABLE_DISCUSSION_HOME_PANEL"] = False  # Force all traffic to MFE, not legacy panel



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
    MIDDLEWARE.append("lms.envs.tutor.mereka_multisite.MerekaLoginRedirectMiddleware")
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
LEARNER_RECORD_MICROFRONTEND_URL = f"{MEREKA_MFE_BASE_URL}/learner-record"



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



# Ecommerce (legacy Oscar — deprecated, replaced by Purchase Gateway)
# Keep backend URL for Django internals that reference it.
ECOMMERCE_PUBLIC_URL_ROOT = MEREKA_ECOMMERCE_BASE_URL
ECOMMERCE_API_URL = ECOMMERCE_PUBLIC_URL_ROOT + "/api/v2"
# Do NOT advertise ecommerce URLs in MFE config — the service has no pods.
# Caddy routes /orders/* and /payment/* to payments-gateway:8080 which
# will be the replacement. Re-enable these when Purchase Gateway is live.
# MFE_CONFIG["ECOMMERCE_BASE_URL"] = ECOMMERCE_PUBLIC_URL_ROOT
# MFE_CONFIG["ORDER_HISTORY_URL"] = ORDER_HISTORY_MICROFRONTEND_URL

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
    'learner-record': f"{MEREKA_MFE_BASE_URL}/learner-record",
    'learning': f"{MEREKA_MFE_BASE_URL}/learning",
    'ora-grading': f"{MEREKA_MFE_BASE_URL}/ora-grading",
    'orders': f"{MEREKA_MFE_BASE_URL}/orders",
    'payment': f"{MEREKA_MFE_BASE_URL}/payment",
}

MEREKA_PUBLIC_FOOTER = build_mereka_public_footer()
MFE_CONFIG["MEREKA_PUBLIC_FOOTER"] = MEREKA_PUBLIC_FOOTER

EDXNOTES_PUBLIC_API = f"{MEREKA_NOTES_BASE_URL}/api/v1"
EDXNOTES_INTERNAL_API = "http://notes:8000/api/v1"

LMS_BASE = MEREKA_LMS_DOMAIN
LMS_ROOT_URL = MEREKA_LMS_BASE_URL
# LMS_INTERNAL_ROOT_URL: used by enterprise API calls within the pod.
# In K8s, localhost:80 doesn't serve LMS — use the external URL so requests
# route through the ingress (same as dev does).
LMS_INTERNAL_ROOT_URL = LMS_ROOT_URL
# Enterprise OAuth2 provider: defaults to http://127.0.0.1:8000/oauth2 which
# fails in K8s. Without this, ALL enterprise-linked users get "error loading
# course" because the consent API can't obtain an OAuth2 token.
ENTERPRISE_BACKEND_SERVICE_EDX_OAUTH2_PROVIDER_URL = f"{LMS_INTERNAL_ROOT_URL}/oauth2"
ENTERPRISE_API_URL = f"{LMS_ROOT_URL}/enterprise/api/v1/"
# Enterprise catalog internal URL: the enterprise Django package defaults to
# "enterprise.catalog.app:18160" (Tutor hostname), which doesn't resolve in K8s.
# Point to the real in-cluster service so enterprise consent checks succeed.
ENTERPRISE_CATALOG_INTERNAL_ROOT_URL = os.environ.get(
    "ENTERPRISE_CATALOG_INTERNAL_ROOT_URL", "http://enterprise-catalog:8160"
)
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
    if _module_available("openedx_prometheus") and "openedx_prometheus" not in INSTALLED_APPS:
        INSTALLED_APPS.append("openedx_prometheus")
    if "django_prometheus.middleware.PrometheusBeforeMiddleware" not in MIDDLEWARE:
        MIDDLEWARE.insert(0, "django_prometheus.middleware.PrometheusBeforeMiddleware")
    if "django_prometheus.middleware.PrometheusAfterMiddleware" not in MIDDLEWARE:
        MIDDLEWARE.append("django_prometheus.middleware.PrometheusAfterMiddleware")

    _metrics_urlconf = "openedx_prometheus.urls"
    if _module_available(_metrics_urlconf):
        ROOT_URLCONF_OVERRIDES = globals().get("ROOT_URLCONF_OVERRIDES", [])
        if _metrics_urlconf not in ROOT_URLCONF_OVERRIDES:
            ROOT_URLCONF_OVERRIDES.insert(0, _metrics_urlconf)

# Forwarded-header hardening: normalize multi-valued X-Forwarded-* headers.
# Without this, Django may treat HTTPS requests as HTTP which can break URL
# generation and callback flows in some proxy chains.
_forwarded_headers_middleware = "lms.envs.tutor.mereka_forwarded_headers.MerekaForwardedHeadersMiddleware"
if _module_available("lms.envs.tutor.mereka_forwarded_headers"):
    if _forwarded_headers_middleware not in MIDDLEWARE:
        MIDDLEWARE.insert(0, _forwarded_headers_middleware)
else:
    logging.getLogger(__name__).warning("Skipping missing middleware module: %s", _forwarded_headers_middleware)

# Cookie-domain middleware ordering: must be BEFORE both SessionMiddleware and
# CsrfViewMiddleware in the MIDDLEWARE list so that in the response phase
# (which processes in reverse order) our middleware runs AFTER they have set
# sessionid/csrftoken cookies. Without this, our middleware sees the response
# before csrftoken is set and can't rewrite its Domain attribute.
_cookie_middleware = "lms.envs.tutor.mereka_multisite.MerekaCookieDomainMiddleware"
_csrf_middleware = "django.middleware.csrf.CsrfViewMiddleware"
_session_middleware = "django.contrib.sessions.middleware.SessionMiddleware"
if _cookie_middleware in MIDDLEWARE:
    # Find the earliest of SessionMiddleware and CsrfViewMiddleware
    _targets = []
    for _mw in (_session_middleware, _csrf_middleware):
        if _mw in MIDDLEWARE:
            _targets.append(MIDDLEWARE.index(_mw))
    if _targets:
        _earliest = min(_targets)
        _cookie_idx = MIDDLEWARE.index(_cookie_middleware)
        if _cookie_idx > _earliest:
            MIDDLEWARE.insert(_earliest, MIDDLEWARE.pop(_cookie_idx))

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

# Some Open edX builds define SAMLConfiguration.KEY_FIELDS as ("site_id", "slug")
# while saml_metadata_view passes a Site object. Normalize Site -> site_id to avoid
# false-disabled checks that cause /auth/saml/metadata.xml to return 404.
try:
    from common.djangoapps.third_party_auth.models import SAMLConfiguration as _SAMLConfiguration
except Exception:
    _SAMLConfiguration = None

if _SAMLConfiguration is not None and not getattr(_SAMLConfiguration, "_mereka_is_enabled_site_fix", False):
    _saml_original_is_enabled = _SAMLConfiguration.is_enabled.__func__

    @classmethod
    def _mereka_saml_is_enabled(cls, site_or_id, *key_fields):
        if hasattr(site_or_id, "id"):
            site_or_id = site_or_id.id
        return _saml_original_is_enabled(cls, site_or_id, *key_fields)

    _SAMLConfiguration.is_enabled = _mereka_saml_is_enabled
    _SAMLConfiguration._mereka_is_enabled_site_fix = True

# Enable third-party auth + enterprise integration unconditionally.
# Some upstream defaults initialize these keys to False before this file runs;
# use direct assignment to guarantee runtime behavior.
FEATURES["ENABLE_THIRD_PARTY_AUTH"] = True
FEATURES["ENABLE_OAUTH2_PROVIDER"] = True
FEATURES["ENABLE_ENTERPRISE_INTEGRATION"] = True

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

# Register openedx_push_notifications app (only if installed in the image)
try:
    import openedx_push_notifications  # noqa: F401
    if "openedx_push_notifications" not in INSTALLED_APPS:
        INSTALLED_APPS.append("openedx_push_notifications")
except ImportError:
    pass

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

# Register openedx_email_templates app (optional)
_safe_add_app("openedx_email_templates")

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

# Register openedx_email_digests app (optional)
_safe_add_app("openedx_email_digests")

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

# Register openedx_tenant_cache app (optional)
_safe_add_app("openedx_tenant_cache")

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

# Register openedx_kajabi_sso app (optional)
_safe_add_app("openedx_kajabi_sso")

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
    LOGIN_REDIRECT_URL = os.environ.get(
        "LOGIN_REDIRECT_URL", LEARNER_HOME_MICROFRONTEND_URL
    )
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

# Register openedx_mobile_api app (optional)
_safe_add_app("openedx_mobile_api")

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

# Register Kajabi SSO app (optional, may already be registered above)
_safe_add_app("openedx_kajabi_sso")

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

# Add openedx_video_pipeline to INSTALLED_APPS (optional)
_safe_add_app("openedx_video_pipeline")

# ── Video Pipeline: Phase 2 — XBlock, Subtitles, Protection, Analytics ──
# @spec: video-pipeline-delivery_spec.md (Phase 2)
# @bead: mereka-lms-2tli

# xAPI video events to ClickHouse/Aspects pipeline
ENABLE_VIDEO_XAPI_EVENTS = os.environ.get(
    "ENABLE_VIDEO_XAPI_EVENTS", "false"
).lower() in ("true", "1", "yes")

# ============================================
# Aspects Analytics — Event Routing Backends
# ============================================
# event-routing-backends: batched xAPI event delivery
EVENT_ROUTING_BACKEND_BATCHING_ENABLED = os.environ.get(
    "EVENT_ROUTING_BACKEND_BATCHING_ENABLED", "true"
).lower() in ("true", "1", "yes")
EVENT_ROUTING_BACKEND_BATCH_SIZE = int(os.environ.get("EVENT_ROUTING_BACKEND_BATCH_SIZE", "100"))
EVENT_ROUTING_BACKEND_BATCH_INTERVAL = int(os.environ.get("EVENT_ROUTING_BACKEND_BATCH_INTERVAL", "5"))

# platform-plugin-aspects: ClickHouse event sinks for course data
EVENT_SINK_CLICKHOUSE_BACKEND_CONFIG = {
    "url": "http://" + os.environ.get("ASPECTS_CLICKHOUSE_HOST", "clickhouse") + ":" + os.environ.get("ASPECTS_CLICKHOUSE_PORT", "8123"),
    "username": os.environ.get("ASPECTS_CLICKHOUSE_USER", "openedx"),
    "password": os.environ.get("ASPECTS_CLICKHOUSE_PASSWORD", ""),
    "database": os.environ.get("ASPECTS_CLICKHOUSE_DATABASE", "openedx"),
    "timeout_secs": int(os.environ.get("ASPECTS_CLICKHOUSE_TIMEOUT", "30")),
}
EVENT_SINK_CLICKHOUSE_COURSE_OVERVIEWS_ENABLED = os.environ.get(
    "EVENT_SINK_CLICKHOUSE_COURSE_OVERVIEWS_ENABLED", "false"
).lower() in ("true", "1", "yes")
EVENT_SINK_CLICKHOUSE_COURSE_ENROLLMENT_ENABLED = os.environ.get(
    "EVENT_SINK_CLICKHOUSE_COURSE_ENROLLMENT_ENABLED", "false"
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

# Register video analytics and protection apps (optional)
_safe_add_app("openedx_video_analytics")
_safe_add_app("openedx_video_protection")

# ── Security Hardening (T119) ────────────────────────────────────────────────
# Session and CSRF cookie flags.
# SESSION_COOKIE_SECURE / CSRF_COOKIE_SECURE are already set above based on
# MEREKA_SCHEME; we enforce them unconditionally here for production safety.
SESSION_COOKIE_SECURE = True
SESSION_COOKIE_HTTPONLY = True
CSRF_COOKIE_SECURE = True
CSRF_COOKIE_HTTPONLY = False  # MFEs read the CSRF token from JS — must stay False

# Content Security Policy.
# Open edX ships django-csp (openedx/csp-middleware) but does not enable it by
# default.  We configure it here in report-only mode first so that any directive
# violations surface in browser DevTools / Sentry without blocking learners.
# To enforce, set CSP_REPORT_ONLY=false after validating the report feed.
CSP_REPORT_ONLY = os.environ.get("CSP_REPORT_ONLY", "true").lower() not in ("false", "0", "no")

# Activate CSPMiddleware — emits CSP headers (report-only by default).
if 'csp.middleware.CSPMiddleware' not in MIDDLEWARE:
    MIDDLEWARE.append('csp.middleware.CSPMiddleware')

_lms_url = MEREKA_LMS_BASE_URL
_mfe_url = MEREKA_MFE_BASE_URL
_studio_url = MEREKA_STUDIO_BASE_URL
_auth_url = MEREKA_AUTH_BASE_URL

# Allowlist sources used by Open edX + Mereka MFEs.
# 'unsafe-inline' is required for legacy Open edX inline scripts/styles;
# remove it incrementally as Waffle flags migrate pages to MFEs.
CSP_DEFAULT_SRC = ("'self'",)
CSP_SCRIPT_SRC = (
    "'self'",
    "'unsafe-inline'",  # Required by Open edX legacy courseware
    "'unsafe-eval'",    # Required by some xblocks and the Studio MFE
    _mfe_url,
    "https://cdn.jsdelivr.net",
    "https://cdnjs.cloudflare.com",
    "https://www.google-analytics.com",
    "https://www.googletagmanager.com",
)
CSP_STYLE_SRC = (
    "'self'",
    "'unsafe-inline'",  # Required by Open edX legacy theming
    _mfe_url,
    "https://fonts.googleapis.com",
    "https://cdn.jsdelivr.net",
)
CSP_FONT_SRC = (
    "'self'",
    _mfe_url,
    "https://fonts.gstatic.com",
    "data:",
)
CSP_IMG_SRC = (
    "'self'",
    "data:",
    "blob:",
    _lms_url,
    _mfe_url,
    "https://fonts.gstatic.com",
    "https://cdn.jsdelivr.net",
    "https://www.google-analytics.com",
    "https://www.googletagmanager.com",
    "https://storage.googleapis.com",  # GCS-hosted course assets
    "https://i.ytimg.com",             # YouTube video thumbnails
    "https://img.youtube.com",         # YouTube video thumbnails
    "https://www.gravatar.com",        # User avatar images
    "https://stream.mux.com",          # Mux video poster / thumbnail frames
    "https://image.mux.com",           # Mux image API (thumbnails, storyboards)
)
CSP_CONNECT_SRC = (
    "'self'",
    _lms_url,
    _mfe_url,
    _studio_url,
    _auth_url,
    "https://www.google-analytics.com",
    "https://sentry.io",
)
CSP_FRAME_SRC = (
    "'self'",
    _lms_url,
    _mfe_url,
    _studio_url,
    _auth_url,
    "https://www.youtube.com",
    "https://player.vimeo.com",
)
CSP_MEDIA_SRC = ("'self'", "blob:")
CSP_OBJECT_SRC = ("'none'",)
CSP_BASE_URI = ("'self'",)
CSP_FORM_ACTION = ("'self'",)
CSP_FRAME_ANCESTORS = ("'self'",)

# Nonce preparation — nonces coexist with 'unsafe-inline'; templates that adopt
# csp_nonce template tag will work before we remove 'unsafe-inline'.
CSP_INCLUDE_NONCE_IN = ["script-src"]

# CSP report endpoint (Phase 1 — ADR-025):
# Auto-derive from SENTRY_DSN if CSP_REPORT_URI not explicitly set.
# Works with sentry.io and self-hosted Sentry DSN hosts.
from urllib.parse import urlparse as _urlparse

def _derive_sentry_csp_report_uri(_dsn):
    if not _dsn:
        return ""
    try:
        _parsed = _urlparse(_dsn)
    except Exception:
        return ""
    _public_key = (_parsed.username or "").strip()
    _project_id = ((_parsed.path or "").rstrip("/").split("/")[-1] or "").strip()
    _netloc = (_parsed.netloc or "").split("@", 1)[-1]
    _scheme = (_parsed.scheme or "https").strip()
    if not (_public_key and _project_id.isdigit() and _netloc):
        return ""
    return "{}://{}/api/{}/security/?sentry_key={}".format(
        _scheme, _netloc, _project_id, _public_key
    )

_csp_report_uri = (os.environ.get("CSP_REPORT_URI", "") or "").strip()
if not _csp_report_uri:
    _csp_report_uri = _derive_sentry_csp_report_uri(
        (os.environ.get("SENTRY_DSN", "") or "").strip()
    )
if _csp_report_uri:
    CSP_REPORT_URI = _csp_report_uri

# Rate limiting for authentication endpoints.
# Use DRF native throttle class path for compatibility across Open edX releases.
# These rates apply to anonymous and authenticated users respectively.
REST_FRAMEWORK = dict(globals().get("REST_FRAMEWORK", {}))
REST_FRAMEWORK.setdefault("DEFAULT_THROTTLE_CLASSES", [
    "rest_framework.throttling.ScopedRateThrottle",
])
REST_FRAMEWORK.setdefault("DEFAULT_THROTTLE_RATES", {})
_throttle_rates = dict(REST_FRAMEWORK["DEFAULT_THROTTLE_RATES"])
# Auth endpoints: ~6 req/min burst for anon (≈30 per 5 min), 100/min for authenticated.
_throttle_rates.setdefault("anon_burst",         os.environ.get("THROTTLE_ANON_BURST",         "6/min"))
_throttle_rates.setdefault("user",               os.environ.get("THROTTLE_USER",               "100/min"))
# Login-specific throttle (used by openedx.core.djangoapps.user_authn).
_throttle_rates.setdefault("login_and_register",  os.environ.get("THROTTLE_LOGIN_AND_REGISTER",  "6/min"))
# Password reset throttle.
_throttle_rates.setdefault("password_reset",      os.environ.get("THROTTLE_PASSWORD_RESET",      "5/hour"))
REST_FRAMEWORK["DEFAULT_THROTTLE_RATES"] = _throttle_rates

# Open edX specific login rate limit (separate from DRF; used by login view directly).
# Limits: N failed login attempts per unit of time before lockout.
LOGIN_THROTTLE_ENABLED = os.environ.get("LOGIN_THROTTLE_ENABLED", "true").lower() not in ("false", "0", "no")
MAX_FAILED_LOGIN_ATTEMPTS_ALLOWED = int(os.environ.get("MAX_FAILED_LOGIN_ATTEMPTS_ALLOWED", "10"))
MAX_FAILED_LOGIN_ATTEMPTS_LOCKOUT_PERIOD_SECS = int(
    os.environ.get("MAX_FAILED_LOGIN_ATTEMPTS_LOCKOUT_PERIOD_SECS", "300")  # 5 minutes
)
# ── Sync MFE_CONFIG to FEATURES for the MFE config API ──────────────────────
# The MFE config API view (lms/djangoapps/mfe_config_api/views.py) reads
# from FEATURES['MFE_CONFIG'], not the top-level MFE_CONFIG dict.
# Without this sync, the API returns null for all configured MFE URLs.
FEATURES['ENABLE_MFE_CONFIG_API'] = True
FEATURES['MFE_CONFIG'] = MFE_CONFIG

# Add MICROFRONTEND_URL keys that are defined as top-level settings but
# missing from the MFE_CONFIG dict. The MFE config API only serves keys
# that are in FEATURES['MFE_CONFIG'].
MFE_CONFIG.setdefault("LEARNER_HOME_MICROFRONTEND_URL", LEARNER_HOME_MICROFRONTEND_URL)
MFE_CONFIG.setdefault("ACCOUNT_MICROFRONTEND_URL", ACCOUNT_MICROFRONTEND_URL)
MFE_CONFIG.setdefault("DISCUSSIONS_MICROFRONTEND_URL", DISCUSSIONS_MICROFRONTEND_URL)
# PROFILE_MICROFRONTEND_URL is already in MFE_CONFIG (added earlier)

# ── End Security Hardening ───────────────────────────────────────────────────
