# -*- coding: utf-8 -*-
import os
from lms.envs.devstack import *

####### Settings common to LMS and CMS
import json
import os

from xmodule.modulestore.modulestore_settings import update_module_store_settings

# Mongodb connection parameters: simply modify `mongodb_parameters` to affect all connections to MongoDb.
mongodb_parameters = {
    "db": "openedx",
    "host": "mongodb",
    "port": 27017,
    "user": None,
    "password": None,
    # Connection/Authentication
    "connect": False,
    "ssl": False,
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
SITE_ID = 2

# Contact addresses
CONTACT_MAILING_ADDRESS = "My Open edX - http://localhost"
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


JWT_AUTH["JWT_ISSUER"] = "http://localhost/oauth2"
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
        "ISSUER": "http://localhost/oauth2",
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
LOGIN_REDIRECT_WHITELIST = ["studio.localhost"]

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

# Setup correct webpack configuration file for development
WEBPACK_CONFIG_PATH = "webpack.dev.config.js"

LMS_BASE = "localhost:8000"
LMS_ROOT_URL = "http://{}".format(LMS_BASE)
LMS_INTERNAL_ROOT_URL = LMS_ROOT_URL
SITE_NAME = LMS_BASE
CMS_BASE = "studio.localhost:8001"
CMS_ROOT_URL = "http://{}".format(CMS_BASE)
LOGIN_REDIRECT_WHITELIST.append(CMS_BASE)

# Session cookie
SESSION_COOKIE_DOMAIN = "localhost"
SESSION_COOKIE_SECURE = False
CSRF_COOKIE_SECURE = False
SESSION_COOKIE_SAMESITE = "Lax"

# CMS authentication
IDA_LOGOUT_URI_LIST.append("http://studio.localhost:8001/logout/")

FEATURES["ENABLE_COURSEWARE_MICROFRONTEND"] = False

# Disable enterprise integration
FEATURES["ENABLE_ENTERPRISE_INTEGRATION"] = False
SYSTEM_WIDE_ROLE_CLASSES.remove("enterprise.SystemWideEnterpriseUserRoleAssignment")

LOGGING["loggers"]["oauth2_provider"] = {
    "handlers": ["console"],
    "level": "DEBUG"
}


# Dynamic config API settings
# https://openedx.github.io/frontend-platform/module-Config.html
MFE_CONFIG = {
    "BASE_URL": "apps.localhost",
    "CSRF_TOKEN_API_PATH": "/csrf/api/v1/token",
    "CREDENTIALS_BASE_URL": "",
    "DISCOVERY_API_BASE_URL": "http://discovery.localhost:8381",
    "FAVICON_URL": "http://localhost/favicon.ico",
    "INFO_EMAIL": "contact@localhost",
    "LANGUAGE_PREFERENCE_COOKIE_NAME": "openedx-language-preference",
    "LMS_BASE_URL": "http://localhost:8000",
    "LOGIN_URL": "http://localhost:8000/login",
    "LOGO_URL": f"http://localhost:8000/theming/asset/{DEFAULT_SITE_THEME}/images/logo-horizontal.png",
    "LOGO_WHITE_URL": f"http://localhost:8000/theming/asset/{DEFAULT_SITE_THEME}/images/logo-horizontal-white.png",
    "LOGO_TRADEMARK_URL": f"http://localhost:8000/theming/asset/{DEFAULT_SITE_THEME}/images/logo.png",
    "LOGOUT_URL": "http://localhost:8000/logout",
    "MARKETING_SITE_BASE_URL": "http://localhost:8000",
    "PASSWORD_RESET_SUPPORT_LINK": "mailto:contact@localhost",
    "REFRESH_ACCESS_TOKEN_ENDPOINT": "http://localhost:8000/login_refresh",
    "SITE_NAME": "Mereka Academy",
    "STUDIO_BASE_URL": "http://studio.localhost:8001",
    "USER_INFO_COOKIE_NAME": "user-info",
    "ACCESS_TOKEN_COOKIE_NAME": "edx-jwt-cookie-header-payload",
}

# MFE-specific settings

AUTHN_MICROFRONTEND_URL = "http://apps.localhost:1999/authn"
AUTHN_MICROFRONTEND_DOMAIN  = "apps.localhost/authn"
MFE_CONFIG["DISABLE_ENTERPRISE_LOGIN"] = True



ACCOUNT_MICROFRONTEND_URL = "http://apps.localhost:1997/account/"
MFE_CONFIG["ACCOUNT_SETTINGS_URL"] = ACCOUNT_MICROFRONTEND_URL



MFE_CONFIG["COURSE_AUTHORING_MICROFRONTEND_URL"] = "http://apps.localhost:2001/authoring"
MFE_CONFIG["ENABLE_ASSETS_PAGE"] = "true"
MFE_CONFIG["ENABLE_HOME_PAGE_COURSE_API_V2"] = "true"
MFE_CONFIG["ENABLE_PROGRESS_GRAPH_SETTINGS"] = "true"
MFE_CONFIG["ENABLE_TAGGING_TAXONOMY_PAGES"] = "true"



DISCUSSIONS_MICROFRONTEND_URL = "http://apps.localhost:2002/discussions"
MFE_CONFIG["DISCUSSIONS_MFE_BASE_URL"] = DISCUSSIONS_MICROFRONTEND_URL
DISCUSSIONS_MFE_FEEDBACK_URL = None



WRITABLE_GRADEBOOK_URL = "http://apps.localhost:1994/gradebook"



LEARNER_HOME_MICROFRONTEND_URL = "http://apps.localhost:1996/learner-dashboard/"



LEARNING_MICROFRONTEND_URL = "http://apps.localhost:2000/learning"
MFE_CONFIG["LEARNING_BASE_URL"] = "http://apps.localhost:2000"



ORA_GRADING_MICROFRONTEND_URL = "http://apps.localhost:1993/ora-grading"



# Profile MFE routes are mounted at /u/:username (no /profile basename).
PROFILE_MICROFRONTEND_URL = "http://apps.localhost:1995/u/"
MFE_CONFIG["ACCOUNT_PROFILE_URL"] = PROFILE_MICROFRONTEND_URL
MFE_CONFIG["PROFILE_MICROFRONTEND_URL"] = PROFILE_MICROFRONTEND_URL



COMMUNICATIONS_MICROFRONTEND_URL = "http://apps.localhost:1984/communications"
MFE_CONFIG["SCHEDULE_EMAIL_SECTION"] = True


# Cors configuration

# authn MFE
CORS_ORIGIN_WHITELIST.append("http://apps.localhost:1999")
LOGIN_REDIRECT_WHITELIST.append("apps.localhost:1999")
CSRF_TRUSTED_ORIGINS.append("http://apps.localhost:1999")

# account MFE
CORS_ORIGIN_WHITELIST.append("http://apps.localhost:1997")
LOGIN_REDIRECT_WHITELIST.append("apps.localhost:1997")
CSRF_TRUSTED_ORIGINS.append("http://apps.localhost:1997")

# communications MFE
CORS_ORIGIN_WHITELIST.append("http://apps.localhost:1984")
LOGIN_REDIRECT_WHITELIST.append("apps.localhost:1984")
CSRF_TRUSTED_ORIGINS.append("http://apps.localhost:1984")

# course-authoring MFE
CORS_ORIGIN_WHITELIST.append("http://apps.localhost:2001")
LOGIN_REDIRECT_WHITELIST.append("apps.localhost:2001")
CSRF_TRUSTED_ORIGINS.append("http://apps.localhost:2001")

# discussions MFE
CORS_ORIGIN_WHITELIST.append("http://apps.localhost:2002")
LOGIN_REDIRECT_WHITELIST.append("apps.localhost:2002")
CSRF_TRUSTED_ORIGINS.append("http://apps.localhost:2002")

# gradebook MFE
CORS_ORIGIN_WHITELIST.append("http://apps.localhost:1994")
LOGIN_REDIRECT_WHITELIST.append("apps.localhost:1994")
CSRF_TRUSTED_ORIGINS.append("http://apps.localhost:1994")

# learner-dashboard MFE
CORS_ORIGIN_WHITELIST.append("http://apps.localhost:1996")
LOGIN_REDIRECT_WHITELIST.append("apps.localhost:1996")
CSRF_TRUSTED_ORIGINS.append("http://apps.localhost:1996")

# learning MFE
CORS_ORIGIN_WHITELIST.append("http://apps.localhost:2000")
LOGIN_REDIRECT_WHITELIST.append("apps.localhost:2000")
CSRF_TRUSTED_ORIGINS.append("http://apps.localhost:2000")

# ora-grading MFE
CORS_ORIGIN_WHITELIST.append("http://apps.localhost:1993")
LOGIN_REDIRECT_WHITELIST.append("apps.localhost:1993")
CSRF_TRUSTED_ORIGINS.append("http://apps.localhost:1993")

# profile MFE
CORS_ORIGIN_WHITELIST.append("http://apps.localhost:1995")
LOGIN_REDIRECT_WHITELIST.append("apps.localhost:1995")
CSRF_TRUSTED_ORIGINS.append("http://apps.localhost:1995")

# orders MFE
CORS_ORIGIN_WHITELIST.append("http://apps.localhost:7296")
LOGIN_REDIRECT_WHITELIST.append("apps.localhost:7296")
CSRF_TRUSTED_ORIGINS.append("http://apps.localhost:7296")

# payment MFE
CORS_ORIGIN_WHITELIST.append("http://apps.localhost:1998")
LOGIN_REDIRECT_WHITELIST.append("apps.localhost:1998")
CSRF_TRUSTED_ORIGINS.append("http://apps.localhost:1998")




# Ecommerce






















ECOMMERCE_PUBLIC_URL_ROOT = "http://ecommerce.localhost:8130"
ECOMMERCE_API_URL = ECOMMERCE_PUBLIC_URL_ROOT + "/api/v2"
ORDER_HISTORY_MICROFRONTEND_URL = "http://apps.localhost:7296/orders/orders"
MFE_CONFIG["ECOMMERCE_BASE_URL"] = ECOMMERCE_PUBLIC_URL_ROOT
MFE_CONFIG["ORDER_HISTORY_URL"] = ORDER_HISTORY_MICROFRONTEND_URL




# Forum v2 (Python) runs in-process within LMS - no external service URL needed.

javascript_files = ['base_application', 'application', 'certificates_wv']
dark_theme_filepath = ['indigo/js/dark-theme.js']

for filename in javascript_files:
    if filename in PIPELINE['JAVASCRIPT']:
        PIPELINE['JAVASCRIPT'][filename]['source_filenames'] += dark_theme_filepath

MFE_CONFIG['INDIGO_ENABLE_DARK_TOGGLE'] = True
EDXNOTES_PUBLIC_API = "http://notes.localhost:8120/api/v1"
EDXNOTES_INTERNAL_API = "http://notes:8120/api/v1"
