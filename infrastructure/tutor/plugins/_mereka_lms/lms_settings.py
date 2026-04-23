"""LMS production settings patch — multi-site, CSP, throttling,
enterprise, Prometheus, video, assessments, tenancy, Paragon.
"""

from _mereka_lms import _register_env_patch

_register_env_patch(
    "openedx-lms-production-settings",
    """
# Safe app installer — prevents ImportError from missing optional modules
def _safe_add_app(app_name):
    if app_name not in INSTALLED_APPS:
        try:
            __import__(app_name.split('.')[0])
            INSTALLED_APPS.append(app_name)
        except ImportError:
            pass

# Mereka LMS: Multi-site and MFE-prefixed LMS route configuration.
# Caddy forwards /authn/login and related MFE-prefixed LMS routes from MFE_HOST
# to lms:8000 while preserving the incoming host. Django must therefore accept
# MFE_HOST directly; otherwise the authn route returns HTTP 400 before routing.
for _mereka_host in ["{{ MFE_HOST }}"] + {{ MEREKA_LMS_EXTRA_HOSTS }}:
    if _mereka_host and _mereka_host not in ALLOWED_HOSTS:
        ALLOWED_HOSTS.append(_mereka_host)

for _mereka_origin in [
    "http://{{ MFE_HOST }}",
    "https://{{ MFE_HOST }}",
] + {{ MEREKA_LMS_EXTRA_CSRF_ORIGINS }}:
    if _mereka_origin and _mereka_origin not in CSRF_TRUSTED_ORIGINS:
        CSRF_TRUSTED_ORIGINS.append(_mereka_origin)

# Session and CSRF cookie domains for multi-site support
SESSION_COOKIE_DOMAIN = "{{ MEREKA_SESSION_COOKIE_DOMAIN }}"
CSRF_COOKIE_DOMAIN = "{{ MEREKA_CSRF_COOKIE_DOMAIN }}"

# Set default theme for all sites
DEFAULT_SITE_THEME = "mereka"

# Security hardening.
SESSION_COOKIE_SECURE = True
SESSION_COOKIE_HTTPONLY = True
CSRF_COOKIE_SECURE = True
CSRF_COOKIE_HTTPONLY = False

CSP_REPORT_ONLY = os.environ.get("CSP_REPORT_ONLY", "true").lower() not in ("false", "0", "no")

import importlib.util as _mereka_importlib_util

_mereka_built_image_sentinel = "/openedx/.mereka-built-openedx-image"
_mereka_require_csp = os.environ.get("MEREKA_REQUIRE_CSP")
if _mereka_require_csp is None:
    _mereka_require_csp = "true" if os.path.exists(_mereka_built_image_sentinel) else "false"

# Activate CSPMiddleware when django-csp is present. Bootstrap/local readiness
# may run against upstream prebuilt Open edX images, which do not carry this
# repo-owned dependency; repo-built images install django-csp and carry the
# sentinel above, so a missing package there is a hard failure.
if _mereka_importlib_util.find_spec("csp") is not None:
    if 'csp.middleware.CSPMiddleware' not in MIDDLEWARE:
        MIDDLEWARE.append('csp.middleware.CSPMiddleware')
elif _mereka_require_csp.lower() not in ("false", "0", "no"):
    raise ImportError(
        "django-csp is required for repo-built Mereka Open edX images. "
        "Install django-csp in the build image or set MEREKA_REQUIRE_CSP=false "
        "only for non-production bootstrap images."
    )

_lms_url = globals().get("MEREKA_LMS_BASE_URL", "https://{{ LMS_HOST }}")
_mfe_url = globals().get("MEREKA_MFE_BASE_URL", "https://{{ MFE_HOST }}")
_studio_url = globals().get("MEREKA_STUDIO_BASE_URL", "https://{{ CMS_HOST }}")
_auth_url = globals().get("MEREKA_AUTH_BASE_URL", "https://auth0.mereka.io")
_mfe_static_base = _mfe_url.rstrip("/")

# Use MFE-hosted static branding assets as global defaults.
# This avoids broken themed-asset redirects on LMS hosts for logo-horizontal*.png
# and keeps Authn/Account/Profile logos consistent across environments.
MFE_CONFIG["FAVICON_URL"] = f"{_mfe_static_base}/theme/favicon.ico"
MFE_CONFIG["LOGO_URL"] = f"{_mfe_static_base}/theme/logo-horizontal.svg"
MFE_CONFIG["LOGO_WHITE_URL"] = f"{_mfe_static_base}/theme/logo-horizontal-white.svg"
MFE_CONFIG["LOGO_TRADEMARK_URL"] = f"{_mfe_static_base}/theme/logo.svg"

# Keys required by Open edX MFE footer/header components (Studio Footer,
# Help Content, Header). Missing any of these causes the MFE to crash with
# "App configuration error: X is required by Y component" and a React
# TypeError, which blanks Profile/Learner-Record/Discussions/Communications.
# Values mirror the Django footer fallbacks in themes/mereka/lms/templates/footer.html
# so the LMS-rendered footer and the MFE-rendered footer stay consistent.
MFE_CONFIG["SUPPORT_EMAIL"] = "support@mereka.io"
MFE_CONFIG["TERMS_OF_SERVICE_URL"] = "https://legal.mereka.io/"
MFE_CONFIG["PRIVACY_POLICY_URL"] = "https://legal.mereka.io/privacy-policy/"
MFE_CONFIG["ENABLE_ACCESSIBILITY_PAGE"] = False
MFE_CONFIG["ORDER_HISTORY_URL"] = f"{_lms_url}/orders"
# Authn MFE "Need help signing in?" link. Without this key the MFE
# renders an empty href and the smoke-authn-mfe synthetic (OBS-003,
# bead mereka-lms-e09t) emits WARN. Point at the shared support surface
# — same contract as SUPPORT_EMAIL above. Bead: mereka-lms-jdsx.
MFE_CONFIG["LOGIN_ISSUE_SUPPORT_LINK"] = "mailto:support@mereka.io"

# MFE bundles bake `SESSION_COOKIE_DOMAIN:"MISSING_ENV_VAR".SESSION_COOKIE_DOMAIN`
# at build time when the env var is absent, which evaluates to `undefined` at
# runtime. Surface the Django SESSION_COOKIE_DOMAIN through the MFE config API
# so getConfig() overrides the dead placeholder and
# USER_RETENTION_COOKIE/cross-MFE cookies get the correct parent domain.
MFE_CONFIG["SESSION_COOKIE_DOMAIN"] = SESSION_COOKIE_DOMAIN

# MFE client-side Sentry DSN (OBS-001, bead mereka-lms-m88z).
# The MFE bundle carries an APP_READY subscriber (see
# mfe-env-config-buildtime-imports patch) that calls Sentry.init() only
# when this key is present and non-empty. Safe default: empty string
# → Sentry is a no-op, zero runtime cost.
#
# Per-env DSN provisioning:
# - A DSN MUST be a CLIENT-SIDE (browser-exposed) Sentry key, scoped to
#   the MFE project only. DO NOT reuse MEREKA_LMS_SENTRY_DSN (backend).
# - Expected Sentry project: `mereka-lms-web` (single project; env tag
#   segments via MEREKA_MFE_SENTRY_ENVIRONMENT). Matches the Phase 4
#   canary verifier (scripts/qa/verify-obs-001-mfe-sentry-phase4.sh)
#   which queries that exact project slug.
# - Infisical key: MEREKA_MFE_SENTRY_DSN (populated per env); empty on
#   envs where the Sentry project doesn't exist yet — the SDK stays
#   dormant.
#
# Also expose the environment tag so Sentry segments releases by env.
MFE_CONFIG["SENTRY_DSN"] = os.environ.get("MEREKA_MFE_SENTRY_DSN", "") or ""
MFE_CONFIG["SENTRY_ENVIRONMENT"] = (
    os.environ.get("MEREKA_MFE_SENTRY_ENVIRONMENT", "")
    or os.environ.get("MEREKA_SENTRY_ENVIRONMENT", "")
    or ""
)

# ── Content Security Policy ────────────────────────────────────────────────
# Migration plan: docs/adr/025-csp-nonce-migration.md
#
# Phase 0 (current): 'unsafe-inline' and 'unsafe-eval' intentionally present.
#   Open edX (RequireJS bootstrap, XBlock runtime, Waffle flags) generates
#   inline scripts that cannot be trivially externalised.  MathJax / Studio
#   drag-drop require eval().  Removing these now would break the platform.
#
# Phase 1 (future): add CSP-Report-Only header with strict nonce policy.
#   Collect violation data via CSP_REPORT_URI; fix first-party violations.
#
# Phase 2 (future): remove 'unsafe-inline' once violation report shows zero
#   first-party hits.  Keep 'strict-dynamic' + nonce.
#
# Phase 3 (future): remove 'unsafe-eval' after MathJax 3 migration.
#
# DO NOT remove 'unsafe-inline' or 'unsafe-eval' without completing Phase 1.
CSP_DEFAULT_SRC = ("'self'",)
CSP_SCRIPT_SRC = (
    "'self'",
    "'unsafe-inline'",   # Phase 0: required by Open edX inline scripts — see ADR-025
    "'unsafe-eval'",     # Phase 0: required by MathJax / Studio DnD — see ADR-025
    _mfe_url,
    "https://cdn.jsdelivr.net",
    "https://cdnjs.cloudflare.com",
    "https://www.google-analytics.com",
    "https://www.googletagmanager.com",
)
CSP_STYLE_SRC = (
    "'self'",
    "'unsafe-inline'",
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
# Non-primary tenant hosts (academy.biji-biji.com, skillourfuture.academy.mereka.io,
# admin.academyv2.mereka.io, learner.academyv2.mereka.io, etc.) must be in
# connect-src / frame-src / img-src so tenant MFEs can fetch CSRF tokens, user
# APIs, theme assets, and enterprise flows from their OWN tenant hosts. Without
# these entries, the MFE served from apps.<tenant> loads with a CSP that only
# allows Mereka primary hosts — every /csrf/api/v1/token and /api/mfe_context
# call from a tenant MFE gets blocked by CSP and login hangs with a "pending"
# button (RCB-13 2026-04-11, observed on biji-biji prod first).
_tenant_extra_hosts = tuple(
    f"https://{host}" for host in {{ MEREKA_LMS_EXTRA_HOSTS }}
) + tuple(
    f"https://apps.{host}" for host in {{ MEREKA_LMS_EXTRA_HOSTS }}
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
) + _tenant_extra_hosts

CSP_CONNECT_SRC = (
    "'self'",
    _lms_url,
    _mfe_url,
    _studio_url,
    _auth_url,
    "https://www.google-analytics.com",
    "https://sentry.io",
) + _tenant_extra_hosts
CSP_FRAME_SRC = (
    "'self'",
    _lms_url,
    _mfe_url,
    _studio_url,
    _auth_url,
    "https://www.youtube.com",
    "https://player.vimeo.com",
) + _tenant_extra_hosts
CSP_MEDIA_SRC = ("'self'", "blob:")
CSP_OBJECT_SRC = ("'none'",)
CSP_BASE_URI = ("'self'",)
CSP_FORM_ACTION = ("'self'",)
CSP_FRAME_ANCESTORS = ("'self'",)

# Nonce injection scaffold (Phase 0 — ADR-025):
# Nonces coexist safely with 'unsafe-inline'.  Templates that adopt
# csp_nonce template tag will be nonce-trusted even before we remove 'unsafe-inline'.
# This is a zero-risk change: adding a nonce does not enforce anything new.
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

REST_FRAMEWORK = dict(globals().get("REST_FRAMEWORK", {}))
REST_FRAMEWORK.setdefault("DEFAULT_THROTTLE_CLASSES", [
    "rest_framework.throttling.ScopedRateThrottle",
])
REST_FRAMEWORK.setdefault("DEFAULT_THROTTLE_RATES", {})
_throttle_rates = dict(REST_FRAMEWORK["DEFAULT_THROTTLE_RATES"])
_throttle_rates.setdefault("anon_burst", os.environ.get("THROTTLE_ANON_BURST", "6/min"))
_throttle_rates.setdefault("user", os.environ.get("THROTTLE_USER", "100/min"))
_throttle_rates.setdefault("login_and_register", os.environ.get("THROTTLE_LOGIN_AND_REGISTER", "6/min"))
_throttle_rates.setdefault("password_reset", os.environ.get("THROTTLE_PASSWORD_RESET", "5/hour"))
REST_FRAMEWORK["DEFAULT_THROTTLE_RATES"] = _throttle_rates

FEATURES["ENABLE_ACCOUNT_ACTIVATION_EMAIL_LINK"] = True
LOGIN_THROTTLE_ENABLED = os.environ.get("LOGIN_THROTTLE_ENABLED", "true").lower() not in ("false", "0", "no")
MAX_FAILED_LOGIN_ATTEMPTS_ALLOWED = int(os.environ.get("MAX_FAILED_LOGIN_ATTEMPTS_ALLOWED", "10"))
MAX_FAILED_LOGIN_ATTEMPTS_LOCKOUT_PERIOD_SECS = int(
    os.environ.get("MAX_FAILED_LOGIN_ATTEMPTS_LOCKOUT_PERIOD_SECS", "300")
)

# Enterprise integration
FEATURES["ENABLE_ENTERPRISE_INTEGRATION"] = True
# Enterprise catalog internal URL: default "enterprise.catalog.app:18160" doesn't resolve
# in K8s. Override with the actual in-cluster service name.
ENTERPRISE_CATALOG_INTERNAL_ROOT_URL = os.environ.get(
    "ENTERPRISE_CATALOG_INTERNAL_ROOT_URL", "http://enterprise-catalog:8160"
)

# Force MFE-only discussions (greenfield - no legacy views needed)
FEATURES["ENABLE_DISCUSSION_HOME_PANEL"] = False  # Disable legacy in-LMS panel

# Ensure all courses use MFE by default
DISCUSSIONS_MFE_ENABLED = True
if "DISCUSSIONS_MICROFRONTEND_URL" not in globals():
    _mfe_base = globals().get("MEREKA_MFE_BASE_URL", "https://{{ MFE_HOST }}")
    DISCUSSIONS_MICROFRONTEND_URL = f"{_mfe_base}/discussions"
if "DISCUSSIONS_MFE_FEEDBACK_URL" not in globals():
    DISCUSSIONS_MFE_FEEDBACK_URL = None

# Fix JWT_ALGORITHM: the infra overlay sets JWT_AUTH["JWT_ALGORITHM"] = "RS512"
# but the symmetric JWT path (used by enterprise backend service clients via
# create_jwt_for_user) creates an 'oct' key incompatible with RS512.
# JWT_ALGORITHM must be HS256 for symmetric JWTs; JWT_SIGNING_ALGORITHM (RS512)
# is used separately for asymmetric JWTs.
JWT_AUTH["JWT_ALGORITHM"] = "HS256"

# Extracted XBlocks — use the new modular blocks from xblocks-contrib (0.6.0)
# Verified installed: all block types present in xblocks_contrib package
FEATURES['USE_EXTRACTED_VIDEO_BLOCK'] = True
FEATURES['USE_EXTRACTED_HTML_BLOCK'] = True
FEATURES['USE_EXTRACTED_PROBLEM_BLOCK'] = True
FEATURES['USE_EXTRACTED_DISCUSSION_BLOCK'] = True
FEATURES['USE_EXTRACTED_LTI_BLOCK'] = True
FEATURES['USE_EXTRACTED_WORD_CLOUD_BLOCK'] = True
FEATURES['USE_EXTRACTED_POLL_QUESTION_BLOCK'] = True
FEATURES['USE_EXTRACTED_ANNOTATABLE_BLOCK'] = True

# Aspects event routing — enable batching for performance
EVENT_ROUTING_BACKEND_BATCHING_ENABLED = True

# Certificate lifecycle events on the event bus
SEND_LEARNING_CERTIFICATE_LIFECYCLE_EVENTS_TO_BUS = True

# Programs cache API — needed for program discovery
FEATURES['EXPOSE_CACHE_PROGRAMS_ENDPOINT'] = True

# Content Libraries v2 (Learning Core)
FEATURES['ENABLE_CONTENT_LIBRARIES'] = True

# Ensure optional Redwood apps exist
if "openedx.core.djangoapps.content_libraries.apps.ContentLibrariesConfig" not in INSTALLED_APPS:
    INSTALLED_APPS += ["openedx.core.djangoapps.content_libraries.apps.ContentLibrariesConfig"]
if "openedx.core.djangoapps.bookmarks.apps.BookmarksConfig" not in INSTALLED_APPS:
    INSTALLED_APPS += ["openedx.core.djangoapps.bookmarks.apps.BookmarksConfig"]
if "openedx.core.djangoapps.discussions.apps.DiscussionsConfig" not in INSTALLED_APPS:
    INSTALLED_APPS += ["openedx.core.djangoapps.discussions.apps.DiscussionsConfig"]
if "openedx.core.djangoapps.theming.apps.ThemingConfig" not in INSTALLED_APPS:
    INSTALLED_APPS += ["openedx.core.djangoapps.theming.apps.ThemingConfig"]

# Prometheus Metrics Integration
# django_prometheus must be at the START of INSTALLED_APPS
if 'django_prometheus' not in INSTALLED_APPS:
    try:
        __import__('django_prometheus')
        INSTALLED_APPS.insert(0, 'django_prometheus')
    except ImportError:
        pass

# Add custom prometheus app for /metrics endpoint
_safe_add_app('openedx_prometheus')

# Prometheus middleware must wrap all other middleware
if 'django_prometheus' in INSTALLED_APPS:
    if 'django_prometheus.middleware.PrometheusBeforeMiddleware' not in MIDDLEWARE:
        MIDDLEWARE.insert(0, 'django_prometheus.middleware.PrometheusBeforeMiddleware')
    if 'django_prometheus.middleware.PrometheusAfterMiddleware' not in MIDDLEWARE:
        MIDDLEWARE.append('django_prometheus.middleware.PrometheusAfterMiddleware')

# NOTE: URL patterns for custom modules are registered via Open edX's plugin
# URL system (PluginURLs in each app's AppConfig.plugin_app). This uses
# get_plugin_url_patterns(ProjectType.LMS) in lms/urls.py to auto-discover
# URLs from INSTALLED_APPS.
# Keep explicit URL override to preserve /metrics even on mixed plugin-app revisions.
ROOT_URLCONF_OVERRIDES = globals().get('ROOT_URLCONF_OVERRIDES', [])
if 'openedx_prometheus.urls' not in ROOT_URLCONF_OVERRIDES:
    ROOT_URLCONF_OVERRIDES.insert(0, 'openedx_prometheus.urls')

# MFE OAuth fix integration.
try:
    __import__('mfe_oauth_fix')
except ImportError:
    pass
else:
    if 'mfe_oauth_fix' not in INSTALLED_APPS:
        INSTALLED_APPS.append('mfe_oauth_fix')
    if 'mfe_oauth_fix.urls' not in ROOT_URLCONF_OVERRIDES:
        ROOT_URLCONF_OVERRIDES.insert(0, 'mfe_oauth_fix.urls')
    if 'mfe_oauth_fix.middleware.MFEOAuthFixMiddleware' not in MIDDLEWARE:
        MIDDLEWARE.append('mfe_oauth_fix.middleware.MFEOAuthFixMiddleware')

# Mereka Multi-Tenancy — tenant model extensions + resolution middleware.
try:
    __import__('mereka_tenancy')
except ImportError:
    pass
else:
    if 'mereka_tenancy' not in INSTALLED_APPS:
        INSTALLED_APPS.append('mereka_tenancy')
    _tenant_resolution_middleware = 'mereka_tenancy.middleware.TenantResolutionMiddleware'
    if _tenant_resolution_middleware not in MIDDLEWARE:
        _site_middleware = 'django.contrib.sites.middleware.CurrentSiteMiddleware'
        if _site_middleware in MIDDLEWARE:
            _site_index = MIDDLEWARE.index(_site_middleware) + 1
            MIDDLEWARE.insert(_site_index, _tenant_resolution_middleware)
        else:
            MIDDLEWARE.append(_tenant_resolution_middleware)

# In-App Notifications (Email Phase 3)
_safe_add_app('openedx_notifications')

# Configure ACE channels for in-app notifications
ACE_ENABLED_CHANNELS = ["django_email", "in_app"]

# Feature flag for in-app notifications (enable by default)
NOTIFICATION_INAPP_ENABLED = True

# Email Preferences & GDPR Consent (Email Phase 2)
_safe_add_app('openedx_email_preferences')

# Feature flag for email preferences (enable by default)
ENABLE_EMAIL_PREFERENCES = True

# Email unsubscribe secret (uses SECRET_KEY if not set)
import os
EMAIL_UNSUBSCRIBE_SECRET_KEY = os.environ.get('EMAIL_UNSUBSCRIBE_SECRET_KEY', SECRET_KEY)

# Rate limiting for preferences API (60 requests per minute per user)
RATELIMIT_ENABLE = True
RATELIMIT_USE_CACHE = 'default'

# Mux Video Upload (Video Phase 3: Studio Upload Workflow)
_safe_add_app('openedx_mux_upload')

# Feature flag for Mux Studio upload (default: false, enable in production after testing)
ENABLE_MUX_STUDIO_UPLOAD = os.environ.get('ENABLE_MUX_STUDIO_UPLOAD', 'false').lower() == 'true'

# Mux API credentials (synced from Infisical via ExternalSecrets)
MUX_TOKEN_ID = os.environ.get('MUX_TOKEN_ID')
MUX_TOKEN_SECRET = os.environ.get('MUX_TOKEN_SECRET')
MUX_WEBHOOK_SECRET = os.environ.get('MUX_WEBHOOK_SECRET', '')  # Optional

# Video Analytics (Video Phase 4: Analytics Integration)
_safe_add_app('openedx_video_analytics')

# Feature flag for video analytics (default: false, enable after validation)
ENABLE_VIDEO_ANALYTICS = os.environ.get('ENABLE_VIDEO_ANALYTICS', 'false').lower() == 'true'

# Video Content Protection (Video Phase 5: Signed Playback)
_safe_add_app('openedx_video_protection')

# Feature flag for signed playback (default: false, enable after E2E validation)
ENABLE_MUX_SIGNED_PLAYBACK = os.environ.get('ENABLE_MUX_SIGNED_PLAYBACK', 'false').lower() == 'true'

# Mux signing credentials (synced from Infisical via ExternalSecrets)
MUX_SIGNING_KEY_ID = os.environ.get('MUX_SIGNING_KEY_ID')  # Mux signing key ID
MUX_SIGNING_PRIVATE_KEY = os.environ.get('MUX_SIGNING_PRIVATE_KEY')  # RSA private key (PEM)

# ORA2 Operations & Observability (Assessment Phase 1)
_safe_add_app('openedx_ora2_operations')

# Feature flag for ORA2 operations (default: true, enable for production monitoring)
ENABLE_ORA2_OPERATIONS = os.environ.get('ENABLE_ORA2_OPERATIONS', 'true').lower() == 'true'

# Timed Exams - Server-Side Enforcement & Accommodations (Assessment Phase 2)
_safe_add_app('openedx_timed_exams')

# Feature flag for timed exam enhancements (default: true)
ENABLE_TIMED_EXAM_ENHANCEMENTS = os.environ.get('ENABLE_TIMED_EXAM_ENHANCEMENTS', 'true').lower() == 'true'

# Add multi-device detection middleware (insert after authentication middleware)
if 'openedx_timed_exams' in INSTALLED_APPS and 'openedx_timed_exams.middleware.TimedExamEnforcementMiddleware' not in MIDDLEWARE:
    # Find authentication middleware and insert after it
    auth_middleware_index = -1
    for i, mw in enumerate(MIDDLEWARE):
        if 'AuthenticationMiddleware' in mw:
            auth_middleware_index = i
            break

    if auth_middleware_index >= 0:
        MIDDLEWARE.insert(auth_middleware_index + 1, 'openedx_timed_exams.middleware.TimedExamEnforcementMiddleware')
    else:
        # Fallback: append to end if auth middleware not found
        MIDDLEWARE.append('openedx_timed_exams.middleware.TimedExamEnforcementMiddleware')

# XQueue Graders - Python Code Sandbox (Assessment Phase 3)
_safe_add_app('openedx_xqueue_graders')

# Feature flag for XQueue graders (default: true)
ENABLE_XQUEUE_GRADERS = os.environ.get('ENABLE_XQUEUE_GRADERS', 'true').lower() == 'true'

# XQueue grader configuration
XQUEUE_GRADER_TIMEOUT_SECONDS = int(os.environ.get('XQUEUE_GRADER_TIMEOUT_SECONDS', '30'))
XQUEUE_GRADER_MEMORY_LIMIT_MB = int(os.environ.get('XQUEUE_GRADER_MEMORY_LIMIT_MB', '256'))

# Advanced XBlocks - Drag-Drop, Math, Randomization (Assessment Phase 4)
_safe_add_app('openedx_advanced_xblocks')

# Feature flag for advanced XBlocks (default: true)
ENABLE_ADVANCED_XBLOCKS = os.environ.get('ENABLE_ADVANCED_XBLOCKS', 'true').lower() == 'true'

# Advanced XBlocks configuration
# AC-ASS-024: Default randomized pool settings
RANDOMIZED_POOL_DEFAULT_SIZE = int(os.environ.get('RANDOMIZED_POOL_DEFAULT_SIZE', '20'))
RANDOMIZED_POOL_DEFAULT_SHOW = int(os.environ.get('RANDOMIZED_POOL_DEFAULT_SHOW', '10'))

# AC-ASS-027: Answer shuffling (default: enabled)
ENABLE_ANSWER_SHUFFLING = os.environ.get('ENABLE_ANSWER_SHUFFLING', 'true').lower() == 'true'

# AC-ASS-028: Keyboard accessibility (default: enabled)
ENABLE_KEYBOARD_ACCESSIBILITY = os.environ.get('ENABLE_KEYBOARD_ACCESSIBILITY', 'true').lower() == 'true'

# Math input tolerance for grading (AC-ASS-023)
MATH_INPUT_DEFAULT_TOLERANCE = float(os.environ.get('MATH_INPUT_DEFAULT_TOLERANCE', '0.01'))

# Optional: Domain restriction for playback (defaults to production domain)
MUX_PLAYBACK_AUDIENCE = os.environ.get('MUX_PLAYBACK_AUDIENCE', 'academyv2.mereka.io')

# ── Segment analytics ──────────────────────────────────────────────────
# Canonical key source for Segment.io analytics.
# Set MEREKA_SEGMENT_KEY in environment/secrets to enable.
# When empty or unset, Segment includes are skipped in footer template.
SEGMENT_KEY = os.environ.get("MEREKA_SEGMENT_KEY", "")

# Mobile API — enables /api/mobile/v1/ and /api/mobile/v3/ endpoints
_safe_add_app('openedx_mobile_api')

# Multi-tenancy runtime wiring is already owned by the base LMS production
# settings in this estate. Keep this Tutor plugin layer out of that path to
# avoid duplicate app and middleware registration in rendered local settings.

# Optional runtime Paragon theme URL wiring.
# Consumers can disable by setting MEREKA_PARAGON_THEME_ENABLED=False.
if "{{ MEREKA_PARAGON_THEME_ENABLED }}".lower() == "true":
    _theme_base = "{{ MEREKA_PARAGON_THEME_CDN_BASE }}"
    MFE_CONFIG.setdefault("PARAGON_THEME_URLS", {})
    MFE_CONFIG["PARAGON_THEME_URLS"]["core"] = {}
    MFE_CONFIG["PARAGON_THEME_URLS"]["core"]["urls"] = {}
    MFE_CONFIG["PARAGON_THEME_URLS"]["core"]["urls"]["default"] = _theme_base + "/core.min.css"
    MFE_CONFIG["PARAGON_THEME_URLS"]["core"]["urls"]["brandOverride"] = _theme_base + "/mereka-brand.min.css"
    MFE_CONFIG["PARAGON_THEME_URLS"]["variants"] = {}
    MFE_CONFIG["PARAGON_THEME_URLS"]["variants"]["light"] = {}
    MFE_CONFIG["PARAGON_THEME_URLS"]["variants"]["light"]["urls"] = {}
    MFE_CONFIG["PARAGON_THEME_URLS"]["variants"]["light"]["urls"]["default"] = _theme_base + "/light.min.css"
    MFE_CONFIG["PARAGON_THEME_URLS"]["variants"]["light"]["urls"]["brandOverride"] = _theme_base + "/mereka-brand-light.min.css"

# ── OBS-002: Structured JSON logging ──────────────────────────────────────────
# Feature-flagged behind MEREKA_JSON_LOGGING (default: false) so this ships
# dark and never breaks existing plaintext log collectors until explicitly opt-in.
# When enabled, every log record is a JSON object that Promtail's json pipeline
# stage on rke2-nonprod automatically extracts as labels.
#
# Custom fields injected by MerekaJsonFormatter:
#   request_id  — from django-log-request-id RequestIDFilter (if installed) or UUID
#   user_id     — Django request user pk (set by MerekaRequestContextFilter)
#   trace_id    — W3C traceparent / OTEL trace_id (from contextvars if available)
if os.environ.get("MEREKA_JSON_LOGGING", "false").lower() not in ("false", "0", "no", ""):
    import logging
    import uuid

    class MerekaJsonFormatter:
        # Wrapper that delegates to pythonjsonlogger and injects Mereka fields.
        # NB: docstrings here would prematurely close the outer triple-string
        # passed to _register_env_patch. Keep comments only.
        _delegate = None

        @classmethod
        def _get_delegate(cls):
            if cls._delegate is None:
                try:
                    from pythonjsonlogger.jsonlogger import JsonFormatter
                    cls._delegate = JsonFormatter(
                        fmt="%(asctime)s %(levelname)s %(name)s %(message)s",
                        datefmt="%Y-%m-%dT%H:%M:%S%z",
                        rename_fields={"asctime": "timestamp", "levelname": "level", "name": "logger"},
                    )
                except ImportError:
                    pass
            return cls._delegate

    class _MerekaJsonFormatterFull(logging.Formatter):
        # JSON formatter with request_id, user_id, trace_id injection.

        def format(self, record):
            # request_id: prefer django-log-request-id attr, else generate
            if not hasattr(record, "request_id"):
                record.request_id = str(uuid.uuid4())
            # user_id: injected by middleware into thread-local / log record if present
            if not hasattr(record, "user_id"):
                record.user_id = None
            # trace_id: from OTEL context if available
            if not hasattr(record, "trace_id"):
                try:
                    from opentelemetry import trace as _otel_trace
                    _span = _otel_trace.get_current_span()
                    _ctx = _span.get_span_context() if _span else None
                    record.trace_id = format(_ctx.trace_id, "032x") if (_ctx and _ctx.is_valid) else None
                except Exception:
                    record.trace_id = None
            delegate = MerekaJsonFormatter._get_delegate()
            if delegate is not None:
                return delegate.format(record)
            # Fallback: plain JSON via stdlib (python-json-logger not installed)
            import json
            payload = {
                "timestamp": self.formatTime(record, self.datefmt),
                "level": record.levelname,
                "logger": record.name,
                "message": record.getMessage(),
                "request_id": record.request_id,
                "user_id": record.user_id,
                "trace_id": record.trace_id,
            }
            if record.exc_info:
                payload["exc_info"] = self.formatException(record.exc_info)
            return json.dumps(payload)

    LOGGING = dict(globals().get("LOGGING", {}))
    LOGGING["version"] = 1
    LOGGING.setdefault("disable_existing_loggers", False)
    LOGGING.setdefault("filters", {})
    LOGGING["filters"]["request_id"] = {
        "()": "log_request_id.filters.RequestIDFilter",
    } if True else {}
    # Graceful degradation: if django-log-request-id not installed, skip filter
    try:
        import log_request_id  # noqa: F401
        _req_id_filter_available = True
    except ImportError:
        _req_id_filter_available = False

    LOGGING["filters"]["mereka_request_id"] = {
        "()": "log_request_id.filters.RequestIDFilter",
    } if _req_id_filter_available else {"()": "django.utils.log.CallbackFilter", "callback": lambda r: True}

    LOGGING.setdefault("formatters", {})
    LOGGING["formatters"]["mereka_json"] = {
        "()": _MerekaJsonFormatterFull,
        "datefmt": "%Y-%m-%dT%H:%M:%S%z",
    }

    LOGGING.setdefault("handlers", {})
    LOGGING["handlers"]["mereka_json_console"] = {
        "class": "logging.StreamHandler",
        "formatter": "mereka_json",
        "filters": ["mereka_request_id"] if _req_id_filter_available else [],
        "stream": "ext://sys.stdout",
    }

    # Override root logger to emit JSON; preserve existing handlers if any.
    LOGGING.setdefault("root", {})
    LOGGING["root"]["level"] = LOGGING.get("root", {}).get("level", "INFO")
    _existing_root_handlers = list(LOGGING["root"].get("handlers", []))
    if "mereka_json_console" not in _existing_root_handlers:
        _existing_root_handlers.append("mereka_json_console")
    LOGGING["root"]["handlers"] = _existing_root_handlers

    # Remove the default console handler that emits plaintext when JSON is on,
    # to avoid double-logging. Keep structured handler only.
    if "console" in LOGGING.get("handlers", {}):
        for _logger_cfg in LOGGING.get("loggers", {}).values():
            _hdlrs = _logger_cfg.get("handlers", [])
            if "console" in _hdlrs and "mereka_json_console" not in _hdlrs:
                _hdlrs.append("mereka_json_console")
""",
)
