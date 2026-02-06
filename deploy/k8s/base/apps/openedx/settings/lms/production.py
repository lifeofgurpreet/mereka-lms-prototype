# -*- coding: utf-8 -*-
import os
import sys
from lms.envs.production import *

# Override SECRET_KEY from environment variable (required for K8s deployment)
SECRET_KEY = os.environ.get("OPENEDX_SECRET_KEY", "")
if not SECRET_KEY:
    raise ValueError("OPENEDX_SECRET_KEY environment variable is required")

# Override database password from environment variable.
# Note: secrets may arrive with a trailing newline from secret stores; strip it
# to avoid MySQL 1045 due to password mismatch.
_db_password = (os.environ.get("OPENEDX_MYSQL_PASSWORD", "") or "").rstrip("\r\n")
if _db_password and "default" in DATABASES:
    DATABASES["default"]["PASSWORD"] = _db_password

# Inject Authentik OIDC secret from environment (avoid storing in DB or YAML)
_oidc_secret = os.environ.get("OIDC_CLIENT_SECRET", "")
if _oidc_secret:
    SOCIAL_AUTH_OAUTH_SECRETS = dict(globals().get("SOCIAL_AUTH_OAUTH_SECRETS", {}))
    SOCIAL_AUTH_OAUTH_SECRETS.setdefault("oidc", _oidc_secret)

# Allow the forum API key to be injected via env var (ExternalSecret), so we
# don't have to commit it into configmaps.
#
# The forum service expects `API_KEY`; LMS expects `COMMENTS_SERVICE_KEY`. We
# support either env var and override the LMS setting if present.
_forum_api_key = os.environ.get("COMMENTS_SERVICE_KEY") or os.environ.get("FORUM_API_KEY") or ""
if _forum_api_key:
    COMMENTS_SERVICE_KEY = _forum_api_key

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

# Mongodb connection parameters: MongoDB Atlas (cluster-mereka-lms)
# IMPORTANT: Using MongoDB Atlas instead of in-cluster MongoDB
# Atlas cluster: cluster-mereka-lms.2pjex4s.mongodb.net
MONGODB_HOST = os.environ.get(
    "MONGODB_HOST",
    "mongodb+srv://cluster-mereka-lms.2pjex4s.mongodb.net",
)
MONGODB_DB = os.environ.get("MONGODB_DB", "openedx")
MONGODB_USERNAME = os.environ.get("MONGODB_USERNAME", "cs_comments_user")
mongodb_parameters = {
    "db": MONGODB_DB,
    "host": MONGODB_HOST,
    "port": 27017,
    "user": MONGODB_USERNAME,
    "password": os.environ.get("MONGODB_PASSWORD", ""),
    # Connection/Authentication
    "connect": False,
    "ssl": True,
    "authsource": "admin",
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

# The default Django contrib site is the one associated to the LMS domain name. 1 is
# usually "example.com", so it's the next available integer.
SITE_ID = 6

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
DEFAULT_EMAIL_LOGO_URL = LMS_ROOT_URL + "/theming/asset/images/logo.png"
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
]
for origin in [
    MEREKA_LMS_BASE_URL,
    MEREKA_STUDIO_BASE_URL,
    MEREKA_MFE_BASE_URL,
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

# Share session cookies with the MFE subdomain for academyv2.mereka.io
# If other root domains need MFEs, they should use a dedicated deployment.
SESSION_COOKIE_DOMAIN = f".{MEREKA_LMS_DOMAIN}"
CSRF_COOKIE_DOMAIN = f".{MEREKA_LMS_DOMAIN}"


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
    "LOGO_URL": f"{MEREKA_LMS_BASE_URL}/theming/asset/images/logo-horizontal.png",
    "LOGO_WHITE_URL": f"{MEREKA_LMS_BASE_URL}/theming/asset/images/logo-horizontal-white.png",
    "LOGO_TRADEMARK_URL": f"{MEREKA_LMS_BASE_URL}/theming/asset/images/logo-horizontal.png",
    "LOGOUT_URL": f"{MEREKA_LMS_BASE_URL}/logout",
    "MARKETING_SITE_BASE_URL": MEREKA_LMS_BASE_URL,
    "PASSWORD_RESET_SUPPORT_LINK": "mailto:contact@localhost",
    "REFRESH_ACCESS_TOKEN_ENDPOINT": f"{MEREKA_LMS_BASE_URL}/login_refresh",
    "SITE_NAME": "Mereka",
    "STUDIO_BASE_URL": MEREKA_STUDIO_BASE_URL,
    "USER_INFO_COOKIE_NAME": "user-info",
    "ACCESS_TOKEN_COOKIE_NAME": "edx-jwt-cookie-header-payload",
    "SUPPORT_URL_LEARNER_RECORDS": "",
    "ENABLE_VERIFIABLE_CREDENTIALS": False,
    "SUPPORT_URL_VERIFIABLE_CREDENTIALS": "",
}

# MFE-specific settings


AUTHN_MICROFRONTEND_URL = f"{MEREKA_MFE_BASE_URL}/authn"
AUTHN_MICROFRONTEND_DOMAIN = f"{MEREKA_MFE_DOMAIN}/authn"
MFE_CONFIG["DISABLE_ENTERPRISE_LOGIN"] = True
MFE_CONFIG["AUTHN_MICROFRONTEND_URL"] = AUTHN_MICROFRONTEND_URL
MFE_CONFIG["AUTHN_MICROFRONTEND_DOMAIN"] = AUTHN_MICROFRONTEND_DOMAIN
MFE_CONFIG["SESSION_COOKIE_DOMAIN"] = SESSION_COOKIE_DOMAIN
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
]



LEARNER_HOME_MICROFRONTEND_URL = f"{MEREKA_MFE_BASE_URL}/learner-dashboard/"



LEARNING_MICROFRONTEND_URL = f"{MEREKA_MFE_BASE_URL}/learning"
MFE_CONFIG["LEARNING_BASE_URL"] = f"{MEREKA_MFE_BASE_URL}/learning"



ORA_GRADING_MICROFRONTEND_URL = f"{MEREKA_MFE_BASE_URL}/ora-grading"



PROFILE_MICROFRONTEND_URL = f"{MEREKA_MFE_BASE_URL}/profile/u/"
MFE_CONFIG["ACCOUNT_PROFILE_URL"] = f"{MEREKA_MFE_BASE_URL}/profile"



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
    'profile': f"{MEREKA_MFE_BASE_URL}/profile",
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
    f"{MEREKA_SCHEME}://{MEREKA_BIJI_DOMAIN}",
    f"{MEREKA_SCHEME}://{MEREKA_SKILLOURFUTURE_DOMAIN}",
]:
    if origin not in CSRF_TRUSTED_ORIGINS:
        CSRF_TRUSTED_ORIGINS.append(origin)

# MFE OAuth fix + Prometheus metrics
sys.path.insert(0, "/openedx")
if "mfe_oauth_fix" not in INSTALLED_APPS:
    INSTALLED_APPS.append("mfe_oauth_fix")
ROOT_URLCONF_OVERRIDES = globals().get("ROOT_URLCONF_OVERRIDES", [])
if "mfe_oauth_fix.urls" not in ROOT_URLCONF_OVERRIDES:
    ROOT_URLCONF_OVERRIDES.insert(0, "mfe_oauth_fix.urls")
if "mfe_oauth_fix.middleware.MFEOAuthFixMiddleware" not in MIDDLEWARE:
    MIDDLEWARE.append("mfe_oauth_fix.middleware.MFEOAuthFixMiddleware")

if "django_prometheus" not in INSTALLED_APPS:
    INSTALLED_APPS.insert(0, "django_prometheus")
if "openedx_prometheus" not in INSTALLED_APPS:
    INSTALLED_APPS.append("openedx_prometheus")
if "django_prometheus.middleware.PrometheusBeforeMiddleware" not in MIDDLEWARE:
    MIDDLEWARE.insert(0, "django_prometheus.middleware.PrometheusBeforeMiddleware")
if "django_prometheus.middleware.PrometheusAfterMiddleware" not in MIDDLEWARE:
    MIDDLEWARE.append("django_prometheus.middleware.PrometheusAfterMiddleware")
