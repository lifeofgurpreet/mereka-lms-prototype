# -*- coding: utf-8 -*-
# Environment-owned overlays must harden this for live lanes.
import logging
import os
import sys
import importlib
from urllib.parse import urlparse
from cms.envs.production import *


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


def _apply_meilisearch_runtime_contract():
    """
    Harden Meilisearch index bootstrap for CMS-owned indexing paths.

    The upstream edx-search Meilisearch backend assumes operators ran
    `search.meilisearch.create_indexes()` before the first write. If that does
    not happen, Meilisearch auto-creates indexes with no explicit primary key
    and then rejects Open edX document ids containing `:`. We repair that lazily
    the first time CMS touches a search index, but only when the broken index is
    still empty and therefore safe to recreate.
    """
    if globals().get("SEARCH_ENGINE") != "search.meilisearch.MeilisearchEngine":
        return

    try:
        import meilisearch
        import search.meilisearch as search_meilisearch
    except ImportError:
        logging.getLogger(__name__).warning(
            "Meilisearch runtime contract patch skipped; search.meilisearch is unavailable",
        )
        return

    if getattr(search_meilisearch, "_MEREKA_RUNTIME_CONTRACT_PATCHED", False):
        return

    original_get_or_create = search_meilisearch.get_or_create_meilisearch_index

    def _index_document_count(index):
        stats = index.get_stats()
        return getattr(stats, "number_of_documents", 0)

    def _get_or_repair_meilisearch_index(client, index_name):
        try:
            index = client.get_index(index_name)
        except meilisearch.errors.MeilisearchApiError as exc:
            if exc.code != "index_not_found":
                raise
            return original_get_or_create(client, index_name)

        primary_key = getattr(index, "primary_key", None)
        if primary_key in {search_meilisearch.PRIMARY_KEY_FIELD_NAME, "_pk"}:
            return index

        document_count = _index_document_count(index)
        if document_count:
            raise RuntimeError(
                f"Meilisearch index {index_name} has unsupported primary key {primary_key!r} "
                f"with {document_count} documents; refusing automatic recreation."
            )

        logging.getLogger(__name__).warning(
            "Recreating empty Meilisearch index %s with primary key %s",
            index_name,
            search_meilisearch.PRIMARY_KEY_FIELD_NAME,
        )
        task_info = client.delete_index(index_name)
        search_meilisearch.wait_for_task_to_succeed(client, task_info)
        return original_get_or_create(client, index_name)

    def _patched_meilisearch_index(self):
        if self._meilisearch_index is None:
            client = search_meilisearch.get_meilisearch_client()
            index_name = search_meilisearch.get_meilisearch_index_name(self.index_name)
            index = _get_or_repair_meilisearch_index(client, index_name)

            filterables = search_meilisearch.INDEX_FILTERABLES.get(self.index_name, [])
            search_meilisearch.update_index_filterables(client, index, filterables)

            sortables = search_meilisearch.INDEX_SORTABLES.get(self.index_name, [])
            if sortables:
                existing_sortables = set(index.get_sortable_attributes())
                if not set(sortables).issubset(existing_sortables):
                    merged_sortables = sorted(existing_sortables.union(sortables))
                    task_info = index.update_sortable_attributes(merged_sortables)
                    search_meilisearch.wait_for_task_to_succeed(client, task_info)

            self._meilisearch_index = index

        return self._meilisearch_index

    search_meilisearch.get_or_create_meilisearch_index = _get_or_repair_meilisearch_index
    search_meilisearch.MeilisearchEngine.meilisearch_index = property(_patched_meilisearch_index)
    search_meilisearch._MEREKA_RUNTIME_CONTRACT_PATCHED = True


# Override SECRET_KEY from environment variable (required for K8s deployment).
# Nonprod fallback chain prevents hard crashes when legacy secret keys drift to
# empty while JWT keys remain populated.
SECRET_KEY = (
    os.environ.get("CMS_SECRET_KEY")
    or os.environ.get("OPENEDX_SECRET_KEY")
    or os.environ.get("SECRET_KEY")
    or os.environ.get("JWT_SECRET_KEY_CMS")
    or os.environ.get("JWT_SECRET_KEY")
    or ""
)
if not SECRET_KEY:
    raise ValueError("CMS_SECRET_KEY environment variable is required")

# Comprehensive theming is enabled via env.yml; actually activate the theme.
# Without DEFAULT_SITE_THEME, Studio will keep serving stock Indigo styles/assets.
DEFAULT_SITE_THEME = os.environ.get("DEFAULT_SITE_THEME", "mereka")

# Override database password from environment variable.
# Note: secret stores and CLIs often include a trailing newline; strip it to
# avoid MySQL 1045 due to password mismatch.
_db_password = (os.environ.get("OPENEDX_MYSQL_PASSWORD", "") or "").rstrip("\r\n")
if _db_password and "default" in DATABASES:
    DATABASES["default"]["PASSWORD"] = _db_password

####### Settings common to LMS and CMS
import json
import os

from xmodule.modulestore.modulestore_settings import update_module_store_settings

MEREKA_SCHEME = os.environ.get("MEREKA_SCHEME", "https")
MEREKA_LMS_DOMAIN = os.environ.get("MEREKA_LMS_DOMAIN", "academyv2.mereka.io")
MEREKA_DEV_DOMAIN = os.environ.get("MEREKA_DEV_DOMAIN", "academyv2.mereka.dev")
MEREKA_BIJI_DOMAIN = os.environ.get("MEREKA_BIJI_DOMAIN", "academy.biji-biji.com")
MEREKA_BIJI_STUDIO_DOMAIN = os.environ.get(
    "MEREKA_BIJI_STUDIO_DOMAIN",
    "studio.academy.biji-biji.com",
)
MEREKA_SOF_STUDIO_DOMAIN = os.environ.get(
    "MEREKA_SOF_STUDIO_DOMAIN",
    "studio.skillourfuture.academy.mereka.io",
)
# SOF migration target (Stage 1 of tenant-domain-migration runbook).
# Both old and new trees accepted during dual-active window.
# See docs/status/active/TENANT_MIGRATION_SOF_2026-04.md
MEREKA_SOF_STUDIO_V2_DOMAIN = os.environ.get(
    "MEREKA_SOF_STUDIO_V2_DOMAIN",
    "studio.skillourfuture.academyv2.mereka.io",
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
MEREKA_DEV_STUDIO_DOMAIN = os.environ.get(
    "MEREKA_DEV_STUDIO_DOMAIN",
    f"studio.{MEREKA_DEV_DOMAIN}",
)
MEREKA_DEV_MFE_DOMAIN = os.environ.get("MEREKA_DEV_MFE_DOMAIN", f"apps.{MEREKA_DEV_DOMAIN}")
MEREKA_COOKIE_DOMAIN = os.environ.get("MEREKA_COOKIE_DOMAIN", f".{MEREKA_LMS_DOMAIN}")

MEREKA_LMS_BASE_URL = f"{MEREKA_SCHEME}://{MEREKA_LMS_DOMAIN}"
MEREKA_STUDIO_BASE_URL = f"{MEREKA_SCHEME}://{MEREKA_STUDIO_DOMAIN}"
MEREKA_MFE_BASE_URL = _MEREKA_MFE_BASE_URL_OVERRIDE or f"{MEREKA_SCHEME}://{MEREKA_MFE_DOMAIN}"
MEREKA_AUTH_DOMAIN = os.environ.get("MEREKA_AUTH_DOMAIN", "auth0.mereka.io")
MEREKA_AUTH_BASE_URL = f"{MEREKA_SCHEME}://{MEREKA_AUTH_DOMAIN}"
MEREKA_OIDC_PROVIDER_SLUG = os.environ.get("MEREKA_OIDC_PROVIDER_SLUG", "mereka-lms")

# Keep OIDC provider routing aligned with environment domains. Base env.yml uses
# production defaults, so nonprod overlays must override via MEREKA_AUTH_DOMAIN.
SOCIAL_AUTH_OIDC_OIDC_ENDPOINT = (
    f"{MEREKA_AUTH_BASE_URL}/application/o/{MEREKA_OIDC_PROVIDER_SLUG}"
)
OAUTH_OIDC_ISSUER = f"{MEREKA_LMS_BASE_URL}/oauth2"

# Keep canonical LMS/CMS roots aligned to domain env contract in every environment.
# Without this override, inherited cms.envs.production defaults can leak .io links
# into nonprod Studio pages even when MEREKA_* domain env vars are set to .dev.
LMS_BASE = MEREKA_LMS_DOMAIN
LMS_ROOT_URL = MEREKA_LMS_BASE_URL
LMS_INTERNAL_ROOT_URL = LMS_ROOT_URL  # Must match LMS_ROOT_URL, not http://localhost
CMS_BASE = MEREKA_STUDIO_DOMAIN
CMS_ROOT_URL = MEREKA_STUDIO_BASE_URL

# MongoDB modulestore connection.
#
# Target state is MongoDB Atlas, but we keep an explicit in-cluster fallback for
# environments where Atlas connectivity is not yet available.
#
# Atlas cluster: cluster-mereka-lms.2pjex4s.mongodb.net
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
# SEARCH_ENGINE uses MeilisearchEngine; ELASTIC_SEARCH_CONFIG is retained
# for any edx-search code paths that still reference it, but pointed at
# Meilisearch so connections don't hang against a dead Elasticsearch service.
SEARCH_ENGINE = "search.meilisearch.MeilisearchEngine"
ELASTIC_SEARCH_CONFIG = [{
  "host": "meilisearch",
  "port": 7700,
}]

# Meilisearch configuration (Content Libraries v2 search + content indexing)
MEILISEARCH_ENABLED = True
MEILISEARCH_URL = "http://meilisearch:7700"
MEILISEARCH_INDEX_PREFIX = "tutor_"
# Secret managers and kubectl tooling sometimes preserve a trailing newline.
# Strip it so Meilisearch auth does not fail on otherwise-correct keys.
MEILISEARCH_API_KEY = (os.environ.get("MEILISEARCH_API_KEY", "") or "").rstrip("\r\n")
_apply_meilisearch_runtime_contract()

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
DATABASE_ROUTERS.remove(
    "openedx.core.lib.django_courseware_routers.StudentModuleHistoryExtendedRouter"
)
# Content Libraries v2: ensure the app is installed (matches LMS production.py pattern)
def _safe_add_app(app_path):
    """Add an app to INSTALLED_APPS only if importable (guards optional packages)."""
    module_name = app_path.split(".")[0] if "." in app_path else app_path
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
_safe_add_app("openedx_advanced_xblocks.apps.AdvancedXBlocksConfig")

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
_init_sentry("cms")

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
JWT_AUTH["JWT_SECRET_KEY"] = os.environ.get("JWT_SECRET_KEY_CMS", "")
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
        "SECRET_KEY": os.environ.get("JWT_SECRET_KEY_CMS", "")
    }
]

# Enable/Disable some features globally
FEATURES["PREVENT_CONCURRENT_LOGINS"] = False
FEATURES["ENABLE_CORS_HEADERS"] = True

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

######## Common CMS settings
STUDIO_NAME = "Mereka Academy - Studio"

CACHES["staticfiles"] = {
    "KEY_PREFIX": "staticfiles_cms",
    "BACKEND": "django.core.cache.backends.locmem.LocMemCache",
    "LOCATION": "staticfiles_cms",
}

# Authentication
SOCIAL_AUTH_EDX_OAUTH2_SECRET = (os.environ.get("CMS_SOCIAL_AUTH_EDX_OAUTH2_SECRET", "") or "").strip()
SOCIAL_AUTH_EDX_OAUTH2_URL_ROOT = "http://lms:8000"
# Studio sits behind TLS termination at the ingress; force https redirect_uri so
# the OIDC provider accepts it.
SOCIAL_AUTH_REDIRECT_IS_HTTPS = MEREKA_SCHEME == "https"
# Studio must use a dedicated session cookie to avoid collisions with the LMS
# `sessionid` cookie (which has Domain=.academyv2.mereka.io via middleware).
# Using the same name causes both services to overwrite each other's sessions.
SESSION_COOKIE_NAME = "studio_session_id"

MAX_ASSET_UPLOAD_FILE_SIZE_IN_MB = 100

FRONTEND_LOGIN_URL = LMS_ROOT_URL + '/login'
FRONTEND_REGISTER_URL = LMS_ROOT_URL + '/register'

# Create folders if necessary
for folder in [LOG_DIR, MEDIA_ROOT, STATIC_ROOT, ORA2_FILEUPLOAD_ROOT]:
    if not os.path.exists(folder):
        os.makedirs(folder, exist_ok=True)



######## End of common CMS settings

ALLOWED_HOSTS = [
    ENV_TOKENS.get("CMS_BASE"),
    "cms",
    MEREKA_STUDIO_DOMAIN,
    MEREKA_BIJI_STUDIO_DOMAIN,
    MEREKA_SOF_STUDIO_DOMAIN,
    MEREKA_SOF_STUDIO_V2_DOMAIN,
    MEREKA_DEV_STUDIO_DOMAIN,
]
for origin in [
    MEREKA_STUDIO_BASE_URL,
    f"{MEREKA_SCHEME}://{MEREKA_BIJI_STUDIO_DOMAIN}",
    f"{MEREKA_SCHEME}://{MEREKA_SOF_STUDIO_DOMAIN}",
    f"{MEREKA_SCHEME}://{MEREKA_SOF_STUDIO_V2_DOMAIN}",
]:
    if origin not in CORS_ORIGIN_WHITELIST:
        CORS_ORIGIN_WHITELIST.append(origin)
    if origin not in CSRF_TRUSTED_ORIGINS:
        CSRF_TRUSTED_ORIGINS.append(origin)

# Secure cookies for HTTPS + shared auth on academyv2.mereka.io
SESSION_COOKIE_SECURE = MEREKA_SCHEME == "https"
CSRF_COOKIE_SECURE = MEREKA_SCHEME == "https"
# CMS uses an OAuth2 roundtrip to the LMS (/login/edx-oauth2 -> /complete/edx-oauth2).
# The redirect chain may traverse Authentik (auth0.mereka.io) when the user is not yet
# logged in to LMS, resulting in 6+ redirects across subdomains. SameSite=None (matching
# the upstream LMS convention from DCS_SESSION_COOKIE_SAMESITE) ensures the studio
# session cookie is always sent back on the callback regardless of redirect chain length
# or browser-specific cookie handling.  Secure=True (above) is required for SameSite=None.
SESSION_COOKIE_SAMESITE = "None"
CSRF_COOKIE_SAMESITE = "None"
# Multisite note:
# This CMS instance is served on multiple root domains (academyv2.mereka.io and
# biji-biji.com). A single static cookie domain breaks the other root. Keep
# cookies host-only here and rewrite per-request via middleware.
SESSION_COOKIE_DOMAIN = None
CSRF_COOKIE_DOMAIN = None

# Authentication
SOCIAL_AUTH_EDX_OAUTH2_KEY = "cms-sso"
SOCIAL_AUTH_EDX_OAUTH2_PUBLIC_URL_ROOT = MEREKA_LMS_BASE_URL
# Critical: if Studio's OAuth callback fails (missing/invalid state, etc) we must
# NOT return a 500. SocialAuthExceptionMiddleware will only swallow exceptions
# if LOGIN_ERROR_URL is configured.
SOCIAL_AUTH_LOGIN_ERROR_URL = "/signin"
# Be explicit: treat social-auth exceptions as user-facing auth failures, not server errors.
SOCIAL_AUTH_RAISE_EXCEPTIONS = False

# Hardening: keep platform admins as staff/superuser and ensure CourseCreator (prevents drift).
MIDDLEWARE = list(MIDDLEWARE)
_platform_admin_middleware = "cms.envs.tutor.mereka_platform_admin.MerekaPlatformAdminMiddleware"
if _module_available("cms.envs.tutor.mereka_platform_admin"):
    MIDDLEWARE.append(_platform_admin_middleware)
else:
    logging.getLogger(__name__).warning("Skipping missing middleware module: %s", _platform_admin_middleware)

_cms_multisite_module = "cms.envs.tutor.mereka_multisite"
if _module_available(_cms_multisite_module):
    MIDDLEWARE.extend(
        [
            "cms.envs.tutor.mereka_multisite.MerekaStudioSigninRedirectMiddleware",
            "cms.envs.tutor.mereka_multisite.MerekaCookieDomainMiddleware",
        ]
    )
else:
    logging.getLogger(__name__).warning("Skipping missing middleware module: %s", _cms_multisite_module)

# MFE-specific settings

COURSE_AUTHORING_MICROFRONTEND_URL = f"{MEREKA_MFE_BASE_URL}/authoring"


LOGIN_REDIRECT_WHITELIST.extend([MEREKA_MFE_DOMAIN, MEREKA_DEV_MFE_DOMAIN])
for origin in [
    MEREKA_MFE_BASE_URL,
    f"{MEREKA_SCHEME}://{MEREKA_DEV_MFE_DOMAIN}",
]:
    if origin not in CORS_ORIGIN_WHITELIST:
        CORS_ORIGIN_WHITELIST.append(origin)
    if origin not in CSRF_TRUSTED_ORIGINS:
        CSRF_TRUSTED_ORIGINS.append(origin)

# Prometheus metrics
sys.path.insert(0, "/openedx")
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
# Without this, Django may treat HTTPS requests as HTTP and Studio can generate
# `next=http://...` URLs, causing Secure cookies to be dropped and OAuth callback
# state validation to fail.
_forwarded_headers_middleware = "cms.envs.tutor.mereka_forwarded_headers.MerekaForwardedHeadersMiddleware"
if _module_available("cms.envs.tutor.mereka_forwarded_headers"):
    if _forwarded_headers_middleware not in MIDDLEWARE:
        MIDDLEWARE.insert(0, _forwarded_headers_middleware)
else:
    logging.getLogger(__name__).warning("Skipping missing middleware module: %s", _forwarded_headers_middleware)

# Cookie-domain middleware ordering: must be BEFORE both SessionMiddleware and
# CsrfViewMiddleware in the MIDDLEWARE list so that in the response phase
# (which processes in reverse order) our middleware runs AFTER they have set
# sessionid/csrftoken cookies. Without this, our middleware sees the response
# before csrftoken is set and can't rewrite its Domain attribute.
_cookie_middleware = "cms.envs.tutor.mereka_multisite.MerekaCookieDomainMiddleware"
_csrf_middleware = "django.middleware.csrf.CsrfViewMiddleware"
_session_middleware = "django.contrib.sessions.middleware.SessionMiddleware"
if _cookie_middleware in MIDDLEWARE:
    _targets = []
    for _mw in (_session_middleware, _csrf_middleware):
        if _mw in MIDDLEWARE:
            _targets.append(MIDDLEWARE.index(_mw))
    if _targets:
        _earliest = min(_targets)
        _cookie_idx = MIDDLEWARE.index(_cookie_middleware)
        if _cookie_idx > _earliest:
            MIDDLEWARE.insert(_earliest, MIDDLEWARE.pop(_cookie_idx))

# Ensure social-auth callback failures (missing/invalid state, etc.) do not surface as 500s.
# This is critical for Studio's LMS OAuth2 roundtrip (/login/edx-oauth2 -> /complete/edx-oauth2).
_social_exception_middleware = "social_django.middleware.SocialAuthExceptionMiddleware"
if _social_exception_middleware not in MIDDLEWARE:
    MIDDLEWARE.append(_social_exception_middleware)

# ── Content Libraries v2: Feature Flags ─────────────────────────────────
# @spec: content-libraries-v2 (Phase 0: Foundation Audit)
# @covers: AC-LIB-004 — Feature flags for CMS (library authoring)

# Master switch for Content Libraries v2
CONTENT_LIBRARIES_V2_ENABLED = os.environ.get(
    "CONTENT_LIBRARIES_V2_ENABLED", "false"
).lower() in ("true", "1", "yes")
FEATURES["CONTENT_LIBRARIES_V2_ENABLED"] = CONTENT_LIBRARIES_V2_ENABLED

# Meilisearch-powered library content search (CMS)
LIBRARIES_SEARCH_ENABLED = os.environ.get(
    "LIBRARIES_SEARCH_ENABLED", "false"
).lower() in ("true", "1", "yes")
FEATURES["LIBRARIES_SEARCH_ENABLED"] = LIBRARIES_SEARCH_ENABLED

# Bulk import/export of library components (CMS authoring)
LIBRARIES_BULK_IMPORT_ENABLED = os.environ.get(
    "LIBRARIES_BULK_IMPORT_ENABLED", "false"
).lower() in ("true", "1", "yes")
FEATURES["LIBRARIES_BULK_IMPORT_ENABLED"] = LIBRARIES_BULK_IMPORT_ENABLED

# GCS bucket for Blockstore
BLOCKSTORE_BUCKET_NAME = os.environ.get(
    "BLOCKSTORE_BUCKET_NAME", "lms-blockstore"
)

# ── Content Libraries v2: Phase 1 Core ──────────────────────────────────
# @spec: content-libraries-v2 (Phase 1: Platform Libraries)
# @covers: AC-LIB-007 through AC-LIB-013

# Library publish timeout (seconds)
LIBRARY_PUBLISH_TIMEOUT_SECONDS = int(os.environ.get(
    "LIBRARY_PUBLISH_TIMEOUT_SECONDS", "30"
))

# Soft-delete retention (days)
LIBRARY_SOFT_DELETE_RETENTION_DAYS = int(os.environ.get(
    "LIBRARY_SOFT_DELETE_RETENTION_DAYS", "30"
))



# ── Kajabi SSO/OAuth Integration ───────────────────────────────────────
# @spec: Kajabi SSO Migration (mereka-lms-f98)
# Register app for admin access (SSO primarily used on LMS) only when package exists.
if "openedx_kajabi_sso" not in INSTALLED_APPS:
    try:
        import importlib.util

        if importlib.util.find_spec("openedx_kajabi_sso") is not None:
            INSTALLED_APPS.append("openedx_kajabi_sso")
    except Exception:
        # CMS images may not include this package; fail safe to avoid startup crash.
        pass

# ── Mobile Backend API ──────────────────────────────────────────────────
# @spec: Mobile Backend API (mereka-lms-2gck)
# Register app for admin access (API primarily used on LMS)

_safe_add_app("openedx_mobile_api")

# ── Content Libraries v2: Phase 2 Tenant Isolation ─────────────────────
# @spec: content-libraries-v2 (Phase 2: Tenant Libraries)
# @covers: AC-LIB-014 through AC-LIB-019

# Org-scoped library filtering
LIBRARY_TENANT_ISOLATION_ENABLED = os.environ.get(
    "LIBRARY_TENANT_ISOLATION_ENABLED", "false"
).lower() in ("true", "1", "yes")

# RBAC enforcement
LIBRARY_RBAC_ENABLED = os.environ.get(
    "LIBRARY_RBAC_ENABLED", "false"
).lower() in ("true", "1", "yes")

# ── Content Libraries v2: Phase 3 Scale, Search, Analytics ─────────────
# @covers: AC-LIB-020 through AC-LIB-025

# Meilisearch for library search in Studio
LIBRARY_SEARCH_ENABLED = os.environ.get(
    "LIBRARY_SEARCH_ENABLED", "false"
).lower() in ("true", "1", "yes")

# Performance: listing pagination
LIBRARY_LIST_PAGE_SIZE = int(os.environ.get(
    "LIBRARY_LIST_PAGE_SIZE", "50"
))

# ── Content Libraries v2: Phase 3-4 Multi-Tenant Scale + Hardening ─────
# @covers: AC-LIB-026 through AC-LIB-032

# Tenant quotas in Studio
LIBRARY_QUOTAS_ENABLED = os.environ.get(
    "LIBRARY_QUOTAS_ENABLED", "false"
).lower() in ("true", "1", "yes")

# Content sanitization
LIBRARY_CONTENT_SANITIZATION_ENABLED = os.environ.get(
    "LIBRARY_CONTENT_SANITIZATION_ENABLED", "false"
).lower() in ("true", "1", "yes")

# ── Video Pipeline: Phase 1 MCT Migration Validation ─────────────────
# @covers: AC-VID-001 through AC-VID-006

# Feature flag (CMS needs to know if video pipeline is active for Studio)
VIDEO_PIPELINE_ENABLED = os.environ.get(
    "VIDEO_PIPELINE_ENABLED", "false"
).lower() in ("true", "1", "yes")

# ── Video Pipeline: Phase 2 — XBlock, Subtitles ─────────────────────
# @bead: mereka-lms-2tli

# Subtitle upload requires Mux API credentials (already in env)
ENABLE_VIDEO_XAPI_EVENTS = os.environ.get(
    "ENABLE_VIDEO_XAPI_EVENTS", "false"
).lower() in ("true", "1", "yes")

# ── Multi-Tenancy Architecture ─────────────────────────────────────────
# @spec: multi-tenancy-architecture_spec.md (Phase 0 + Phase 1)
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

ENABLE_TENANT_ANALYTICS_SCOPING = os.environ.get(
    "ENABLE_TENANT_ANALYTICS_SCOPING", "false"
).lower() in ("true", "1", "yes")

# Register tenant cache app (optional)
_safe_add_app("openedx_tenant_cache")
