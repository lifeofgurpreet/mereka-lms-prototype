"""
Tutor plugin for Mereka LMS customizations.

This plugin consolidates Mereka-specific configuration patches that can be
delivered via Tutor's template hook system. The companion apply-patches.sh
script handles file-system operations (asset sync, theme copy) and content
modifications that require find-and-replace on generated files.

Patches included:
- Multi-site domain configuration (biji-biji.com, skillourfuture.academy.mereka.io)
- MySQL 8 authentication plugin fix
- MFE Node 24 build toolchain
- Forum MongoDB SRV connection support
- Caddy multi-domain configuration
- LMS/CMS settings (CSRF, sessions, enterprise integration)
- Prometheus metrics integration
- MFE OAuth fix integration
- Custom branding and theme support

Usage:
    tutor plugins enable mereka_lms
    tutor config save
    tutor images build openedx mfe
"""

from __future__ import annotations

from mereka_lms_mfe_slots import register_mfe_plugin_slots
from tutor import hooks

# Plugin metadata
__version__ = "1.0.0"

###############################################################################
# Configuration Defaults
###############################################################################

hooks.Filters.CONFIG_DEFAULTS.add_items([
    ("MEREKA_LMS_VERSION", __version__),
    ("MEREKA_LMS_EXTRA_HOSTS", [
        "admin.academyv2.mereka.io",
        "academy.biji-biji.com",
        "enterprise.academyv2.mereka.io",
        "skillourfuture.academy.mereka.io",
    ]),
    ("MEREKA_LMS_EXTRA_CSRF_ORIGINS", [
        "https://admin.academyv2.mereka.io",
        "https://academy.biji-biji.com",
        "https://enterprise.academyv2.mereka.io",
        "https://skillourfuture.academy.mereka.io",
        "https://apps.academy.biji-biji.com",
    ]),
    ("MEREKA_PARAGON_THEME_ENABLED", True),
    ("MEREKA_PARAGON_THEME_CDN_BASE", "/theme"),
    ("MEREKA_SESSION_COOKIE_DOMAIN", ".academyv2.mereka.io"),
    ("MEREKA_CSRF_COOKIE_DOMAIN", ".academyv2.mereka.io"),
])

# Shared patch snippets to reduce duplication in ENV_PATCHES payloads.
_REDWOOD_OPTIONAL_APPS_SNIPPET = """
# Ensure optional Redwood apps exist when collecting assets
if "openedx.core.djangoapps.content_libraries.apps.ContentLibrariesConfig" not in INSTALLED_APPS:
    INSTALLED_APPS += ["openedx.core.djangoapps.content_libraries.apps.ContentLibrariesConfig"]
if "openedx.core.djangoapps.bookmarks.apps.BookmarksConfig" not in INSTALLED_APPS:
    INSTALLED_APPS += ["openedx.core.djangoapps.bookmarks.apps.BookmarksConfig"]
if "openedx.core.djangoapps.discussions.apps.DiscussionsConfig" not in INSTALLED_APPS:
    INSTALLED_APPS += ["openedx.core.djangoapps.discussions.apps.DiscussionsConfig"]
if "openedx.core.djangoapps.theming.apps.ThemingConfig" not in INSTALLED_APPS:
    INSTALLED_APPS += ["openedx.core.djangoapps.theming.apps.ThemingConfig"]
""".strip()

_SAFE_JOIN_MONKEYPATCH_SNIPPET = """
import sys as _sys
import os.path as _osp
import django.utils._os as _os_mod
_orig_safe_join = _os_mod.safe_join
def _build_safe_join(base, *paths):
    return _osp.abspath(_osp.join(base, *paths))
_os_mod.safe_join = _build_safe_join
for _m in list(_sys.modules.values()):
    try:
        if getattr(_m, 'safe_join', None) is _orig_safe_join:
            _m.safe_join = _build_safe_join
    except Exception:
        pass
""".strip()

_CMS_PROMETHEUS_METRICS_SNIPPET = """
# Safe module loading helper for CMS
def _safe_add_app(app_name):
    if app_name not in INSTALLED_APPS:
        try:
            __import__(app_name.split('.')[0])
            INSTALLED_APPS.append(app_name)
        except ImportError:
            pass

# Prometheus metrics + URL exposure for CMS
try:
    __import__('django_prometheus')
    if "django_prometheus" not in INSTALLED_APPS:
        INSTALLED_APPS.insert(0, "django_prometheus")
except ImportError:
    pass

_safe_add_app("openedx_prometheus")

if "django_prometheus" in INSTALLED_APPS:
    if "django_prometheus.middleware.PrometheusBeforeMiddleware" not in MIDDLEWARE:
        MIDDLEWARE.insert(0, "django_prometheus.middleware.PrometheusBeforeMiddleware")
    if "django_prometheus.middleware.PrometheusAfterMiddleware" not in MIDDLEWARE:
        MIDDLEWARE.append("django_prometheus.middleware.PrometheusAfterMiddleware")

# Ensure /metrics URL wiring even when PluginURLs auto-discovery is unavailable.
ROOT_URLCONF_OVERRIDES = globals().get("ROOT_URLCONF_OVERRIDES", [])
if "openedx_prometheus.urls" not in ROOT_URLCONF_OVERRIDES:
    ROOT_URLCONF_OVERRIDES.insert(0, "openedx_prometheus.urls")
""".strip()

###############################################################################
# LMS Production Settings Patches
###############################################################################

hooks.Filters.ENV_PATCHES.add_item(
    (
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

# Mereka LMS: Multi-site domain configuration
ALLOWED_HOSTS += {{ MEREKA_LMS_EXTRA_HOSTS }}

{% for origin in MEREKA_LMS_EXTRA_CSRF_ORIGINS %}
CSRF_TRUSTED_ORIGINS.append("{{ origin }}")
{% endfor %}

# Session and CSRF cookie domains for multi-site support
SESSION_COOKIE_DOMAIN = "{{ MEREKA_SESSION_COOKIE_DOMAIN }}"
CSRF_COOKIE_DOMAIN = "{{ MEREKA_CSRF_COOKIE_DOMAIN }}"

# Security hardening.
SESSION_COOKIE_SECURE = True
SESSION_COOKIE_HTTPONLY = True
CSRF_COOKIE_SECURE = True
CSRF_COOKIE_HTTPONLY = False

CSP_REPORT_ONLY = os.environ.get("CSP_REPORT_ONLY", "true").lower() not in ("false", "0", "no")

_lms_url = globals().get("MEREKA_LMS_BASE_URL", "https://{{ LMS_HOST }}")
_mfe_url = globals().get("MEREKA_MFE_BASE_URL", "https://{{ MFE_HOST }}")
_studio_url = globals().get("MEREKA_STUDIO_BASE_URL", "https://{{ CMS_HOST }}")
_mfe_static_base = _mfe_url.rstrip("/")

# Use MFE-hosted static branding assets as global defaults.
# This avoids broken themed-asset redirects on LMS hosts for logo-horizontal*.png
# and keeps Authn/Account/Profile logos consistent across environments.
MFE_CONFIG["FAVICON_URL"] = f"{_mfe_static_base}/theme/favicon.ico"
MFE_CONFIG["LOGO_URL"] = f"{_mfe_static_base}/theme/logo-horizontal.png"
MFE_CONFIG["LOGO_WHITE_URL"] = f"{_mfe_static_base}/theme/logo-horizontal-white.png"
MFE_CONFIG["LOGO_TRADEMARK_URL"] = f"{_mfe_static_base}/theme/logo.png"

CSP_DEFAULT_SRC = ("'self'",)
CSP_SCRIPT_SRC = (
    "'self'",
    "'unsafe-inline'",
    "'unsafe-eval'",
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
CSP_IMG_SRC = (
    "'self'",
    "data:",
    "blob:",
    _lms_url,
    _mfe_url,
    "https:",
)
CSP_CONNECT_SRC = (
    "'self'",
    _lms_url,
    _mfe_url,
    _studio_url,
    "https://www.google-analytics.com",
    "https://sentry.io",
)
CSP_FRAME_SRC = (
    "'self'",
    _lms_url,
    _mfe_url,
    _studio_url,
    "https://www.youtube.com",
    "https://player.vimeo.com",
)
CSP_MEDIA_SRC = ("'self'", "blob:", "https:")
CSP_OBJECT_SRC = ("'none'",)
CSP_BASE_URI = ("'self'",)
CSP_FRAME_ANCESTORS = ("'self'",)

_csp_report_uri = os.environ.get("CSP_REPORT_URI", "")
if _csp_report_uri:
    CSP_REPORT_URI = _csp_report_uri

REST_FRAMEWORK = dict(globals().get("REST_FRAMEWORK", {}))
REST_FRAMEWORK.setdefault("DEFAULT_THROTTLE_CLASSES", [
    "openedx.core.lib.api.throttle.ScopedRateThrottle",
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

# Force MFE-only discussions (greenfield - no legacy views needed)
FEATURES["ENABLE_DISCUSSION_HOME_PANEL"] = False  # Disable legacy in-LMS panel

# Ensure all courses use MFE by default
DISCUSSIONS_MFE_ENABLED = True
if "DISCUSSIONS_MICROFRONTEND_URL" not in globals():
    _mfe_base = globals().get("MEREKA_MFE_BASE_URL", "https://{{ MFE_HOST }}")
    DISCUSSIONS_MICROFRONTEND_URL = f"{_mfe_base}/discussions"
if "DISCUSSIONS_MFE_FEEDBACK_URL" not in globals():
    DISCUSSIONS_MFE_FEEDBACK_URL = None

# Set default theme for all sites
DEFAULT_SITE_THEME = "mereka"

# Ensure optional Redwood apps exist
if "openedx.core.djangoapps.content_libraries.apps.ContentLibrariesConfig" not in INSTALLED_APPS:
    INSTALLED_APPS += ["openedx.core.djangoapps.content_libraries.apps.ContentLibrariesConfig"]
if "openedx.core.djangoapps.bookmarks.apps.BookmarksConfig" not in INSTALLED_APPS:
    INSTALLED_APPS += ["openedx.core.djangoapps.bookmarks.apps.BookmarksConfig"]
if "openedx.core.djangoapps.discussions.apps.DiscussionsConfig" not in INSTALLED_APPS:
    INSTALLED_APPS += ["openedx.core.djangoapps.discussions.apps.DiscussionsConfig"]
if "openedx.core.djangoapps.theming.apps.ThemingConfig" not in INSTALLED_APPS:
    INSTALLED_APPS += ["openedx.core.djangoapps.theming.apps.ThemingConfig"]

# MFE OAuth Fix - Custom app to fix OAuth provider visibility
import sys
sys.path.insert(0, '/openedx')
_safe_add_app('mfe_oauth_fix')

# Add middleware to fix /api/mfe_context responses
# Insert at the end of middleware stack so it processes responses
if 'mfe_oauth_fix' in INSTALLED_APPS:
    MIDDLEWARE.append('mfe_oauth_fix.middleware.MFEOAuthFixMiddleware')

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

# Multi-Tenancy Integration (Tenancy Epic Phase 1)
_safe_add_app('mereka_tenancy')

# Add TenantResolutionMiddleware after AuthenticationMiddleware
# This ensures tenant context is available for authenticated requests
if 'mereka_tenancy' in INSTALLED_APPS and 'mereka_tenancy.middleware.TenantResolutionMiddleware' not in MIDDLEWARE:
    auth_middleware_index = -1
    for i, mw in enumerate(MIDDLEWARE):
        if 'AuthenticationMiddleware' in mw:
            auth_middleware_index = i
            break
    if auth_middleware_index >= 0:
        MIDDLEWARE.insert(auth_middleware_index + 1, 'mereka_tenancy.middleware.TenantResolutionMiddleware')
    else:
        MIDDLEWARE.append('mereka_tenancy.middleware.TenantResolutionMiddleware')

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
""",
    )
)

###############################################################################
# LMS Assets Settings Patches (for collectstatic)
###############################################################################

hooks.Filters.ENV_PATCHES.add_item(
    (
        "openedx-lms-assets-settings",
        f"""
{_REDWOOD_OPTIONAL_APPS_SNIPPET}

# Monkey-patch safe_join to be permissive during asset build.
# This fixes collectstatic SuspiciousFileOperation errors when CSS files
# reference relative paths like ../../css/images/correct-icon.png
{_SAFE_JOIN_MONKEYPATCH_SNIPPET}
""",
    )
)

###############################################################################
# CMS Assets Settings Patches
###############################################################################

hooks.Filters.ENV_PATCHES.add_item(
    (
        "openedx-cms-assets-settings",
        f"""
{_REDWOOD_OPTIONAL_APPS_SNIPPET}

# Same safe_join patch for CMS
{_SAFE_JOIN_MONKEYPATCH_SNIPPET}
""",
    )
)

###############################################################################
# Open edX Dockerfile Patches
###############################################################################

# Fix editable Git URLs for uv pip compatibility
# uv pip (Rust-based SOTA tool) doesn't support editable Git URLs (-e git+https://...)
# We work around this by filtering them out and installing separately with PEP 508 format.
# This lets us use uv pip for all packages while handling the edge case properly.
hooks.Filters.ENV_PATCHES.add_item(
    (
        "openedx-dockerfile-pre-python-requirements",
        """
# Extract editable Git packages from requirements for separate installation
RUN --mount=type=bind,from=edx-platform,source=/requirements/edx/base.txt,target=/tmp/base.txt \\
    grep '^-e git+https://' /tmp/base.txt | sed 's|^-e git+https://github.com/\\([^/]\\+\\)/\\([^.]*\\)\\.git@\\([^#]\\+\\)#egg=\\(.*\\)$|\\4 @ git+https://github.com/\\1/\\2.git@\\3|' > /tmp/git-packages.txt || true && \\
    grep -v '^-e git+https://' /tmp/base.txt > /tmp/base-filtered.txt
""",
    )
)

# Override the base requirements install to use filtered requirements
hooks.Filters.ENV_PATCHES.add_item(
    (
        "openedx-dockerfile-python-requirements",
        """
# Install main requirements (with editable Git URLs filtered out)
RUN --mount=type=bind,from=edx-platform,source=/requirements/edx/assets.txt,target=/tmp/assets.txt \\
    --mount=type=cache,target=/openedx/.cache/pip,sharing=shared \\
    [ -s /tmp/base-filtered.txt ] && $PIP_COMMAND install -r /tmp/base-filtered.txt -r /tmp/assets.txt || $PIP_COMMAND install -r /tmp/assets.txt

# Install editable Git packages separately with PEP 508 format (uv pip compatible)
RUN --mount=type=cache,target=/openedx/.cache/pip,sharing=shared \\
    [ -s /tmp/git-packages.txt ] && xargs -r -a /tmp/git-packages.txt $PIP_COMMAND install || true
""",
    )
)

# Node environment variables for webpack builds
hooks.Filters.ENV_PATCHES.add_item(
    (
        "openedx-dockerfile-pre-assets",
        """
# Increase Node memory limit for webpack builds
ENV NODE_OPTIONS="--max-old-space-size=6144"
ENV PYTHONPATH="/openedx/edx-platform"
""",
    )
)

# NPM install command override for lockfile drift tolerance
# NOTE: Using 'npm install' instead of 'npm ci' to handle Open edX upstream
# lockfile drift gracefully while still respecting the lockfile when possible.
hooks.Filters.ENV_PATCHES.add_item(
    (
        "openedx-dockerfile-npm-install-cmd",
        """npm install --no-audit --registry=$NPM_REGISTRY""",
    )
)

# Install custom apps and dependencies
# IMPORTANT: Every app referenced via INSTALLED_APPS in LMS/CMS settings MUST
# appear here. Run scripts/qa/verify-custom-app-drift.sh to detect mismatches.
_CUSTOM_APPS = [
    "credentials_vc_issuer",
    "mfe_oauth_fix",
    "openedx_advanced_xblocks",
    "openedx_assessment_bulk",
    "openedx_content_libraries",
    "openedx_email_digests",
    "openedx_email_preferences",
    "openedx_email_templates",
    "openedx_kajabi_sso",
    "openedx_mobile_api",
    "openedx_mux_upload",
    "openedx_notifications",
    "openedx_ora2_operations",
    "openedx_prometheus",
    "openedx_push_notifications",
    "openedx_tenant_cache",
    "openedx_timed_exams",
    "openedx_video_analytics",
    "openedx_video_pipeline",
    "openedx_video_protection",
    "openedx_xqueue_graders",
]

_copy_lines = "\n".join(
    f"COPY --chown=app:app ./infrastructure/tutor/custom-apps/{app} /openedx/{app}"
    for app in _CUSTOM_APPS
)
_install_lines = "\n".join(
    f"RUN pip install -e /openedx/{app}" for app in _CUSTOM_APPS
)

hooks.Filters.ENV_PATCHES.add_item(
    (
        "openedx-dockerfile-post-python-requirements",
        f"""
# Copy and install ALL custom apps (keep in sync with settings and custom-apps/)
{_copy_lines}
{_install_lines}

# Copy and install mereka_tenancy multi-tenancy plugin
# NOTE: Installed to /openedx/plugins/ instead of /openedx/ to enable proper namespacing
COPY --chown=app:app ./infrastructure/tutor/plugins/multi-tenancy /openedx/plugins/mereka_tenancy
RUN pip install -e /openedx/plugins/mereka_tenancy

# Add repository roots to Python path via .pth file for proper module imports.
# Include /openedx because custom app packages are mounted there and should be importable
# as top-level Django apps across CMS/LMS and worker processes.
RUN echo '/openedx' > /openedx/venv/lib/python3.11/site-packages/mereka-plugins.pth && echo '/openedx/plugins' >> /openedx/venv/lib/python3.11/site-packages/mereka-plugins.pth

# Install django-prometheus for metrics
RUN pip install django-prometheus==2.3.1

# Install django-ratelimit for email preferences rate limiting
RUN pip install django-ratelimit==4.1.0

# Install pymongo SRV extras for MongoDB Atlas
RUN pip install "pymongo[srv]"
""",
    )
)

# Custom theme SASS compilation (strip Google Fonts imports)
# NOTE: The Tutor template COPYs ./themes/ AFTER pre-assets hooks and BEFORE collectstatic.
# But compile-sass needs the theme present. So we COPY the theme early here.
# The later COPY ./themes/ will overwrite with the same files — safe and idempotent.
hooks.Filters.ENV_PATCHES.add_item(
    (
        "openedx-dockerfile-pre-assets",
        """
# Early-copy the mereka theme so it exists when compile-sass runs.
# Tutor's standard COPY ./themes/ happens AFTER pre-assets hooks, but we need
# the theme present for SASS compilation. The later COPY overwrites with same files.
COPY --chown=app:app ./themes/mereka/ /openedx/themes/mereka/

# Ensure LMS SASS entry points exist (mirrors CMS pattern with studio-main-v1.scss).
# Without these, compile-sass --theme mereka skips LMS entirely.
RUN test -f /openedx/themes/mereka/lms/static/sass/lms-main-v1.scss || { \
      echo '// LMS V1 entrypoint with Mereka branding overlays.' > /openedx/themes/mereka/lms/static/sass/lms-main-v1.scss && \
      echo "@import '"'"'build-base-v1'"'"';" >> /openedx/themes/mereka/lms/static/sass/lms-main-v1.scss && \
      echo "@import '"'"'build-lms-v1'"'"';" >> /openedx/themes/mereka/lms/static/sass/lms-main-v1.scss && \
      echo '@import "../../../scss/theme";' >> /openedx/themes/mereka/lms/static/sass/lms-main-v1.scss && \
      echo "Created lms-main-v1.scss entry point"; } && \
    test -f /openedx/themes/mereka/lms/static/sass/lms-main-v1-rtl.scss || { \
      echo '// LMS V1 RTL entrypoint with Mereka branding overlays.' > /openedx/themes/mereka/lms/static/sass/lms-main-v1-rtl.scss && \
      echo "@import '"'"'build-base-v1-rtl'"'"';" >> /openedx/themes/mereka/lms/static/sass/lms-main-v1-rtl.scss && \
      echo "@import '"'"'build-lms-v1'"'"';" >> /openedx/themes/mereka/lms/static/sass/lms-main-v1-rtl.scss && \
      echo '@import "../../../scss/theme";' >> /openedx/themes/mereka/lms/static/sass/lms-main-v1-rtl.scss && \
      echo "Created lms-main-v1-rtl.scss entry point"; }

# Strip Google font imports from SCSS files before compilation
RUN python - <<'PY'
from pathlib import Path
import re

# Studio (CMS) still tries to import Open Sans from Google fonts by default.
# We strip those imports at the SASS source so built CSS stays offline-friendly.
root = Path('/openedx/edx-platform')
patterns = [
    re.compile(r'@import\\s+url\\([\\"\\'\\']?https?://fonts[.]googleapis[.]com[^\\)]*\\)\\s*;?', re.I),
    re.compile(r'@import\\s+url\\([\\"\\'\\']?//fonts[.]googleapis[.]com[^\\)]*\\)\\s*;?', re.I),
    re.compile(r'@import\\s+[\\"\\'\\']https?://fonts[.]googleapis[.]com[^\\\"\\']*[\\"\\'\\']\\s*;?', re.I),
    re.compile(r'@import\\s+[\\"\\'\\']//fonts[.]googleapis[.]com[^\\\"\\']*[\\"\\'\\']\\s*;?', re.I),
]
changed = 0
for path in root.rglob('*.scss'):
    try:
        text = path.read_text(encoding='utf-8', errors='ignore')
    except Exception:
        continue
    updated = text
    for pat in patterns:
        updated = pat.sub('', updated)
    if updated != text:
        path.write_text(updated, encoding='utf-8')
        changed += 1
print(f'Stripped google font imports from {changed} scss files')
PY

# Compile SASS with theme support
RUN npm run compile-sass -- --skip-default --theme-dir /openedx/themes --theme mereka && npm run compile-sass -- --skip-themes

# Defense-in-depth: remove any residual Google font imports from compiled Studio CSS
RUN python - <<'PY'
from pathlib import Path
import re

root = Path('/openedx/edx-platform')
patterns = [
    re.compile(r'@import\\s+url\\([\\"\\'\\']?https?://fonts[.]googleapis[.]com[^\\)]*\\)\\s*;?', re.I),
    re.compile(r'@import\\s+url\\([\\"\\'\\']?//fonts[.]googleapis[.]com[^\\)]*\\)\\s*;?', re.I),
    re.compile(r'@import\\s+[\\"\\'\\']https?://fonts[.]googleapis[.]com[^\\\"\\']*[\\"\\'\\']\\s*;?', re.I),
    re.compile(r'@import\\s+[\\"\\'\\']//fonts[.]googleapis[.]com[^\\\"\\']*[\\"\\'\\']\\s*;?', re.I),
]
changed = 0
for path in root.rglob('studio-main-v1*.css'):
    try:
        text = path.read_text(encoding='utf-8', errors='ignore')
    except Exception:
        continue
    updated = text
    for pat in patterns:
        updated = pat.sub('', updated)
    if updated != text:
        path.write_text(updated, encoding='utf-8')
        changed += 1
print(f'Stripped google font imports from {changed} compiled studio css files')
PY
""",
    )
)

# Webpack optimization (disable parallel for stability, remove compat config)
hooks.Filters.ENV_PATCHES.add_item(
    (
        "webpack-prod-config",
        """
// Mereka LMS: Disable parallel processing in Terser for build stability
optimization: {
    minimizer: [
        new TerserPlugin({ parallel: false }),
    ],
}
""",
    )
)

###############################################################################
# MFE Dockerfile Patches
###############################################################################

# Node 24 build toolchain
hooks.Filters.ENV_PATCHES.add_item(
    (
        "mfe-dockerfile-pre-npm-install",
        """
# Update package list and install build toolchain for Node 24
RUN apt-get update && apt-get install -y \\
    gcc g++ git libgl1 libxi6 make python3 python3-distutils \\
    && rm -rf /var/lib/apt/lists/*
""",
    )
)

# Install local OEP-48 brand package for MFEs.
# We ship the package in tutor_env/plugins/mfe/build/mfe/indigo/brand-mereka and
# alias it as @edx/brand for all frontend app builds.
hooks.Filters.ENV_PATCHES.add_item(
    (
        "mfe-dockerfile-pre-npm-install",
        """
COPY indigo/brand-mereka /openedx/app/brand-mereka
RUN npm install --legacy-peer-deps @edx/brand@file:./brand-mereka
""",
    )
)

# Copy generated runtime theme assets into the MFE container.
# PARAGON_THEME_URLS points to /theme/* on the MFE origin.
hooks.Filters.ENV_PATCHES.add_item(
    (
        "mfe-dockerfile-post-npm-install",
        """
COPY indigo/theme /openedx/dist/theme
""",
    )
)

# Cookie domain environment variables
hooks.Filters.ENV_PATCHES.add_item(
    (
        "mfe-dockerfile-post-npm-install",
        """
# Set cookie domains for MFE builds
ARG SESSION_COOKIE_DOMAIN={{ MEREKA_SESSION_COOKIE_DOMAIN }}
ARG CSRF_COOKIE_DOMAIN={{ MEREKA_CSRF_COOKIE_DOMAIN }}
ENV SESSION_COOKIE_DOMAIN=${SESSION_COOKIE_DOMAIN}
ENV CSRF_COOKIE_DOMAIN=${CSRF_COOKIE_DOMAIN}
""",
    )
)

# Install frontend-plugin-framework with legacy peer deps
hooks.Filters.ENV_PATCHES.add_item(
    (
        "mfe-dockerfile-post-npm-install",
        """
# Install frontend-plugin-framework with legacy peer deps
RUN npm install --legacy-peer-deps '@openedx/frontend-plugin-framework@^1.8.0'
""",
    )
)

# NPM install resilience (retry on failure)
# NOTE: Using 'npm install' instead of 'npm ci' to handle lockfile drift gracefully
# while still respecting the lockfile when possible. This is the SOTA approach for
# environments where upstream package-lock.json may have minor version drift.
hooks.Filters.ENV_PATCHES.add_item(
    (
        "mfe-dockerfile-npm-install",
        """
# Configure npm for resilience
RUN npm config set fetch-retries 6 \\
 && npm config set fetch-retry-mintimeout 20000 \\
 && npm config set fetch-retry-maxtimeout 120000 \\
 && npm config set fetch-timeout 300000

# Install with retries (using npm install for lockfile drift tolerance)
RUN bash -o pipefail -c 'for attempt in 1 2 3; do npm install --no-audit --no-fund --registry=$NPM_REGISTRY && exit 0; echo "npm install attempt ${attempt} failed; retrying in 15s" >&2; sleep 15; done; exit 1'
""",
    )
)

# Enforce runtime Paragon theme URLs in built MFE shells.
# We write ../theme/* (not /theme/*) because Ulmo joins fileName against the MFE
# app base path (e.g. /authn/), and a leading slash can become /authn//theme/*.
# The relative hop resolves consistently to /theme/* at runtime.
hooks.Filters.ENV_PATCHES.add_item(
    (
        "mfe-dockerfile-post-npm-build",
        """
RUN python3 - <<'PY'
from pathlib import Path
import json
import re

index_path = Path("/openedx/app/dist/index.html")
if not index_path.exists():
    raise SystemExit(0)

content = index_path.read_text(encoding="utf-8")
match = re.search(r"var PARAGON_THEME = (\\{.*?\\});", content)
if not match:
    raise SystemExit(0)

theme = json.loads(match.group(1))

theme.setdefault("paragon", {}).setdefault("themeUrls", {}).setdefault("core", {})["fileName"] = "../theme/core.min.css"
theme["paragon"]["themeUrls"].setdefault("variants", {}).setdefault("light", {})["fileName"] = "../theme/light.min.css"
theme.setdefault("brand", {}).setdefault("themeUrls", {}).setdefault("core", {})["fileName"] = "../theme/mereka-brand.min.css"
theme["brand"]["themeUrls"].setdefault("variants", {}).setdefault("light", {})["fileName"] = "../theme/mereka-brand-light.min.css"
theme["brand"]["themeUrls"]["variants"].pop("dark", None)
theme["brand"]["themeUrls"].setdefault("defaults", {})["light"] = "light"

updated = content[:match.start(1)] + json.dumps(theme, separators=(", ", ": ")) + content[match.end(1):]
index_path.write_text(updated, encoding="utf-8")
PY
""",
    )
)

###############################################################################
# MFE Plugin Slot Configuration
###############################################################################

register_mfe_plugin_slots()

###############################################################################
# MFE Theme Patches (Indigo)
###############################################################################

hooks.Filters.ENV_PATCHES.add_item(
    (
        "mfe-env-config-buildtime-imports",
        """
// Import Mereka theme SCSS
import './mereka/mereka.scss';
""",
    )
)

hooks.Filters.ENV_PATCHES.add_item(
    (
        "mfe-env-config-runtime-definitions",
        """
{% raw %}
const normalizeHostname = (hostname) => {
  return (typeof hostname === 'string' ? hostname.toLowerCase() : '').replace(/^www\\./, '');
};

// Tenant branding + footer data contract.
// Base config shared by all tenants; per-tenant overrides below.
const MEREKA_BASE_VARIANT = {
  logoUrl: '/theme/logo-horizontal.svg',
  mobileLogoUrl: '/theme/logo.svg',
  helpUrl: 'https://help.mereka.io/',
  whatsapp: '601135271981',
  privacyUrl: 'https://legal.mereka.io/privacy-policy/',
  termsUrl: 'https://legal.mereka.io/',
  cookiesUrl: 'https://legal.mereka.io/#cookie-policy',
};

const MEREKA_SITE_VARIANTS = {
  'academyv2.mereka.io': {
    ...MEREKA_BASE_VARIANT,
    brand: 'Mereka Academy',
    copyrightHolder: 'MEREKA',
    supportEmail: 'support@mereka.io',
  },
  'academy.biji-biji.com': {
    ...MEREKA_BASE_VARIANT,
    brand: 'Biji-Biji Academy',
    copyrightHolder: 'Biji-Biji Initiative',
    supportEmail: 'techadmin@biji-biji.com',
  },
  'skillourfuture.academy.mereka.io': {
    ...MEREKA_BASE_VARIANT,
    brand: 'Skill Our Future Academy',
    copyrightHolder: 'MEREKA',
    supportEmail: 'support@mereka.io',
  },
};

const getMerekaVariant = (hostname, config) => {
  const normalizedHostname = normalizeHostname(hostname);
  const fallbackBrand = (typeof config !== 'undefined' && config.SITE_NAME) || 'Mereka Academy';
  const fallbackPlatform = (typeof config !== 'undefined' && config.PLATFORM_NAME) || 'MEREKA';
  const knownVariant = MEREKA_SITE_VARIANTS[normalizedHostname];

  if (knownVariant) {
    return knownVariant;
  }

  // Unknown host fallback: keep shell rendering deterministic for dev/staging/new tenants.
  return {
    ...MEREKA_BASE_VARIANT,
    brand: fallbackBrand,
    copyrightHolder: fallbackPlatform,
    supportEmail: 'support@mereka.io',
  };
};

const getLogoHref = (baseUrl) => {
  return baseUrl ? `${baseUrl}/dashboard` : '/dashboard';
};

const withMerekaMenuItems = (widget, menuItems = []) => {
  const widgetProps = (widget && widget.RenderWidget && widget.RenderWidget.props) || {};
  const defaultMenu = widgetProps.menu;
  const config = getConfig();
  const hostname = typeof window !== 'undefined' ? window.location.hostname : '';
  const variant = getMerekaVariant(hostname, config);
  const menuItemsWithSupport = [
    ...menuItems,
    ...(typeof variant?.helpUrl === 'string' && variant.helpUrl
      ? [{ type: 'item', href: variant.helpUrl, content: 'Support' }]
      : []),
  ];

  if (!Array.isArray(defaultMenu) || !Array.isArray(menuItems)) {
    return widget;
  }

  if (defaultMenu.length === 0) {
    return {
      ...widget,
      content: {
        ...(widget.content || {}),
        menu: menuItemsWithSupport,
      },
    };
  }

  const existingHrefs = new Set(defaultMenu.map((item) => (item && item.href ? item.href : item)));
  const sanitizedMenuItems = menuItemsWithSupport.filter((item) => item && item.href && !existingHrefs.has(item.href));
  if (sanitizedMenuItems.length === 0) {
    return widget;
  }

  return {
    ...widget,
    content: {
      ...(widget.content || {}),
      menu: [...defaultMenu, ...sanitizedMenuItems],
    },
  };
};

const withMerekaLearningLoggedOutItems = (widget) => {
  const widgetContent = (widget && widget.content) || {};
  const defaultButtons = Array.isArray(widgetContent.buttonsInfo) ? widgetContent.buttonsInfo : null;
  if (!Array.isArray(defaultButtons)) {
    return widget;
  }

  const config = getConfig();
  const hostname = typeof window !== 'undefined' ? window.location.hostname : '';
  const variant = getMerekaVariant(hostname, config);
  const existingHrefs = new Set(defaultButtons.map((item) => (item && item.href ? item.href : '')));
  const nextButtons = [...defaultButtons];

  if (!existingHrefs.has('/dashboard/courses')) {
    nextButtons.push({
      href: '/dashboard/courses',
      message: 'Discover Courses',
    });
  }

  if (typeof variant?.helpUrl === 'string' && variant.helpUrl && !existingHrefs.has(variant.helpUrl)) {
    nextButtons.push({
      href: variant.helpUrl,
      message: 'Support',
    });
  }

  return {
    ...widget,
    content: {
      ...widgetContent,
      buttonsInfo: nextButtons,
    },
  };
};

const withMerekaHeaderUserMenuSupport = (widget) => {
  const widgetContent = (widget && widget.content) || {};
  const defaultMenuGroups = Array.isArray(widgetContent.menu) ? widgetContent.menu : null;
  if (!Array.isArray(defaultMenuGroups)) {
    return widget;
  }

  const config = getConfig();
  const hostname = typeof window !== 'undefined' ? window.location.hostname : '';
  const variant = getMerekaVariant(hostname, config);
  const helpUrl = (typeof variant?.helpUrl === 'string' && variant.helpUrl) ? variant.helpUrl : '';
  if (!helpUrl) {
    return widget;
  }

  const supportItem = { type: 'item', href: helpUrl, content: 'Support' };
  const existingHrefs = new Set(
    defaultMenuGroups.flatMap((group) =>
      Array.isArray(group?.items)
        ? group.items.map((item) => (item && item.href ? item.href : ''))
        : []
    )
  );
  if (existingHrefs.has(helpUrl)) {
    return widget;
  }

  const nextGroups = [...defaultMenuGroups];
  const lastIndex = nextGroups.length - 1;
  if (lastIndex >= 0 && Array.isArray(nextGroups[lastIndex]?.items)) {
    nextGroups[lastIndex] = {
      ...nextGroups[lastIndex],
      items: [...nextGroups[lastIndex].items, supportItem],
    };
  } else {
    nextGroups.push({ items: [supportItem] });
  }

  return {
    ...widget,
    content: {
      ...widgetContent,
      menu: nextGroups,
    },
  };
};

const withMerekaLearningUserMenuSupport = (widget) => {
  const widgetContent = (widget && widget.content) || {};
  const defaultItems = Array.isArray(widgetContent.items) ? widgetContent.items : null;
  if (!Array.isArray(defaultItems)) {
    return widget;
  }

  const config = getConfig();
  const hostname = typeof window !== 'undefined' ? window.location.hostname : '';
  const variant = getMerekaVariant(hostname, config);
  const helpUrl = (typeof variant?.helpUrl === 'string' && variant.helpUrl) ? variant.helpUrl : '';
  if (!helpUrl) {
    return widget;
  }

  const existingHrefs = new Set(defaultItems.map((item) => (item && item.href ? item.href : '')));
  if (existingHrefs.has(helpUrl)) {
    return widget;
  }

  return {
    ...widget,
    content: {
      ...widgetContent,
      items: [
        ...defaultItems,
        {
          href: helpUrl,
          message: 'Support',
        },
      ],
    },
  };
};

const appendClassName = (baseValue, classNameToAppend) => {
  const baseTokens = typeof baseValue === 'string' ? baseValue.split(/\\s+/).filter(Boolean) : [];
  const appendTokens = typeof classNameToAppend === 'string' ? classNameToAppend.split(/\\s+/).filter(Boolean) : [];
  const merged = [...new Set([...baseTokens, ...appendTokens])];
  return merged.join(' ');
};

const withMerekaHeaderShellClass = (widget, classNameToAppend) => {
  const widgetContent = (widget && widget.content) || {};
  if (!widgetContent || typeof widgetContent !== 'object') {
    return widget;
  }

  const nextClassName = appendClassName(widgetContent.className, classNameToAppend);
  if (!nextClassName || nextClassName === widgetContent.className) {
    return widget;
  }

  return {
    ...widget,
    content: {
      ...widgetContent,
      className: nextClassName,
    },
  };
};

const withMerekaUserMenuToggleClass = (widget, classNameToAppend) => {
  const widgetContent = (widget && widget.content) || {};
  if (!widgetContent || typeof widgetContent !== 'object') {
    return widget;
  }

  let touched = false;
  const nextContent = { ...widgetContent };
  const nextClassName = appendClassName(nextContent.className, classNameToAppend);
  if (nextClassName && nextClassName !== nextContent.className) {
    nextContent.className = nextClassName;
    touched = true;
  }

  if (nextContent.buttonProps && typeof nextContent.buttonProps === 'object') {
    const nextButtonProps = { ...nextContent.buttonProps };
    const nextButtonClassName = appendClassName(nextButtonProps.className, classNameToAppend);
    if (nextButtonClassName && nextButtonClassName !== nextButtonProps.className) {
      nextButtonProps.className = nextButtonClassName;
      touched = true;
    }
    if (touched) {
      nextContent.buttonProps = nextButtonProps;
    }
  }

  if (!touched) {
    return widget;
  }

  return {
    ...widget,
    content: nextContent,
  };
};

const withMerekaHeaderUserMenuToggle = (widget) => {
  return withMerekaUserMenuToggleClass(widget, 'mereka-header-user-menu-toggle');
};

const withMerekaMobileUserMenuTrigger = (widget) => {
  return withMerekaUserMenuToggleClass(widget, 'mereka-mobile-user-menu-trigger');
};

const withMerekaLearningUserMenuToggle = (widget) => {
  return withMerekaUserMenuToggleClass(widget, 'mereka-learning-user-menu-toggle');
};

const withMerekaHeaderDesktopShell = (widget) => {
  return withMerekaHeaderShellClass(widget, 'mereka-header-desktop-shell');
};

const withMerekaHeaderMobileShell = (widget) => {
  return withMerekaHeaderShellClass(widget, 'mereka-header-mobile-shell');
};

const withMerekaHeaderLearningCourseInfo = (widget) => {
  return withMerekaHeaderShellClass(widget, 'mereka-header-learning-course-info');
};

const withMerekaStudioHeaderSearchButton = (widget) => {
  return withMerekaUserMenuToggleClass(widget, 'mereka-studio-header-search-button');
};

// Custom Mereka header-logo component (Direct plugin — registered via header_logo slot)
// Wired into org.openedx.frontend.layout.header_logo.v1 by PLUGIN_SLOTS in mereka_lms.py
const MerekaHeaderLogo = () => {
  const config = getConfig();
  const baseUrl = (typeof config !== 'undefined' && typeof config.LMS_BASE_URL === 'string' ? config.LMS_BASE_URL : '').replace(/\\/$/, '');
  const hostname = typeof window !== 'undefined' ? window.location.hostname : '';
  const variant = getMerekaVariant(hostname, config);
  const isMobileViewport = typeof window !== 'undefined' ? window.matchMedia('(max-width: 767px)').matches : false;
  const selectedLogo = isMobileViewport && variant.mobileLogoUrl ? variant.mobileLogoUrl : variant.logoUrl;

  return (
    <a href={getLogoHref(baseUrl)} aria-label={`${variant.brand} dashboard`} className="mereka-header-logo">
      <img src={baseUrl ? `${baseUrl}${selectedLogo}` : selectedLogo} alt={`${variant.brand} logo`} />
    </a>
  );
};

// Learning-header help link replacement for org.openedx.frontend.layout.header_learning_help.v1.
const MerekaLearningHelpLink = () => {
  const config = getConfig();
  const hostname = typeof window !== 'undefined' ? window.location.hostname : '';
  const variant = getMerekaVariant(hostname, config);
  const helpUrl = (typeof variant?.helpUrl === 'string' && variant.helpUrl) ? variant.helpUrl : 'https://help.mereka.io/';
  return (
    <a href={helpUrl} className="mereka-learning-help-link" target="_blank" rel="noopener noreferrer">
      Support
    </a>
  );
};

const MerekaAuthnLoginBranding = () => {
  const config = getConfig();
  const hostname = typeof window !== 'undefined' ? window.location.hostname : '';
  const variant = getMerekaVariant(hostname, config);

  return (
    <div className="mereka-authn-login-branding">
      <a href="/" className="mereka-authn-login-branding__logo">
        <img
          src={variant.logoUrl}
          alt={`${variant.brand} logo`}
          className="mereka-authn-login-branding__logo-img"
        />
      </a>
      <h2 className="mereka-authn-login-branding__title">Welcome back</h2>
      <p className="mereka-authn-login-branding__subtitle">
        Sign in to continue with your {variant.brand} workspace.
      </p>
    </div>
  );
};

const MerekaStudioFooter = () => {
  const config = getConfig();
  const baseUrl = (config.LMS_BASE_URL || '').replace(/\\/$/, '');
  const siteName = config.SITE_NAME || 'Mereka Studio';

  return (
    <footer className="mereka-studio-footer" role="contentinfo">
      <div className="mereka-studio-footer__inner">
        <a href={baseUrl || '/'} className="mereka-studio-footer__logo-link">
          <img
            src="/theme/logo-horizontal.svg"
            alt={`${siteName} logo`}
            className="mereka-studio-footer__logo"
          />
        </a>
        <p className="mereka-studio-footer__tagline">
          Built for creators. Built for teams. Built for growth.
        </p>
      </div>
    </footer>
  );
};

// Studio authoring course-unit sidebar helper.
// Wired into org.openedx.frontend.authoring.course_unit_sidebar.v1.
const MerekaAuthoringCourseUnitSidebarHint = () => {
  return (
    <aside className="mereka-authoring-course-unit-sidebar-hint p-3 rounded">
      <p className="mereka-badge mb-2">Studio Unit</p>
      <p className="mb-0 small text-muted">Use this sidebar to keep activities and outcomes aligned with your learning goals.</p>
    </aside>
  );
};

// Studio authoring course-outline sidebar helper.
// Wired into org.openedx.frontend.authoring.course_outline_sidebar.v1.
const MerekaAuthoringCourseOutlineSidebarHint = () => {
  return (
    <aside className="mereka-authoring-course-outline-sidebar-hint p-3 rounded">
      <p className="mereka-badge mb-2">Outline Guide</p>
      <p className="mb-0 small text-muted">Use this panel to keep weekly objectives and sequencing decisions aligned.</p>
    </aside>
  );
};

// Studio outline header actions helper.
// Wired into org.openedx.frontend.authoring.course_outline_header_actions.v1.
const MerekaAuthoringCourseOutlineHeaderActionsHint = () => {
  return (
    <div className="mereka-authoring-course-outline-header-actions-hint">
      <span className="mereka-badge">Mereka Studio</span>
    </div>
  );
};

// Studio unit header actions helper.
// Wired into org.openedx.frontend.authoring.course_unit_header_actions.v1.
const MerekaAuthoringCourseUnitHeaderActionsHint = () => {
  return (
    <div className="mereka-authoring-course-unit-header-actions-hint">
      <span className="small">Keep unit activities outcomes-focused for your learner path.</span>
    </div>
  );
};

// Studio outline page alerts helper.
// Wired into org.openedx.frontend.authoring.course_outline_page_alerts.v1.
const MerekaAuthoringCourseOutlinePageAlertsHint = () => {
  return (
    <div className="mereka-authoring-course-outline-page-alerts-hint">
      <span className="mereka-badge me-2">Quality Check</span>
      <span className="small">Review pacing and prerequisites before publishing this outline.</span>
    </div>
  );
};

// Studio video editor alerts helper.
// Wired into org.openedx.frontend.authoring.edit_video_alerts.v1.
const MerekaAuthoringEditVideoAlertsHint = () => {
  return (
    <div className="mereka-authoring-edit-video-alerts-hint">
      <span className="mereka-badge me-2">Video Ready</span>
      <span className="small">Confirm captions and transcript quality for accessibility.</span>
    </div>
  );
};

// Studio file editor alerts helper.
// Wired into org.openedx.frontend.authoring.edit_file_alerts.v1.
const MerekaAuthoringEditFileAlertsHint = () => {
  return (
    <div className="mereka-authoring-edit-file-alerts-hint">
      <span className="mereka-badge me-2">File Review</span>
      <span className="small">Check filename clarity and learner-facing download labels.</span>
    </div>
  );
};

// Studio additional course plugin helper.
// Wired into org.openedx.frontend.authoring.additional_course_plugin.v1.
const MerekaAuthoringAdditionalCoursePluginHint = () => {
  return (
    <div className="mereka-authoring-additional-course-plugin-hint">
      <span className="mereka-badge me-2">Course Plugin</span>
      <span className="small">Add external tools that match your program outcomes.</span>
    </div>
  );
};

// Studio additional course content plugin helper.
// Wired into org.openedx.frontend.authoring.additional_course_content_plugin.v1.
const MerekaAuthoringAdditionalCourseContentPluginHint = () => {
  return (
    <div className="mereka-authoring-additional-course-content-plugin-hint">
      <span className="mereka-badge me-2">Content Plugin</span>
      <span className="small">Use reusable content blocks to keep experiences consistent.</span>
    </div>
  );
};

// Studio outline subsection extra-actions helper.
// Wired into org.openedx.frontend.authoring.course_outline_subsection_card_extra_actions.v1.
const MerekaAuthoringOutlineSubsectionExtraActionsHint = () => {
  return (
    <div className="mereka-authoring-outline-subsection-extra-actions-hint">
      <span className="small">Subsection actions are available for sequencing and visibility controls.</span>
    </div>
  );
};

// Studio outline unit-card extra-actions helper.
// Wired into org.openedx.frontend.authoring.course_outline_unit_card_extra_actions.v1.
const MerekaAuthoringOutlineUnitExtraActionsHint = () => {
  return (
    <div className="mereka-authoring-outline-unit-extra-actions-hint">
      <span className="small">Unit-level actions help you align assessments with outcomes.</span>
    </div>
  );
};

// Studio course-unit sidebar v2 helper.
// Wired into org.openedx.frontend.authoring.course_unit_sidebar.v2.
const MerekaAuthoringCourseUnitSidebarV2Hint = () => {
  return (
    <div className="mereka-authoring-course-unit-sidebar-v2-hint">
      <span className="mereka-badge me-2">Studio Unit v2</span>
      <span className="small">Use quick controls to refine component flow and accessibility.</span>
    </div>
  );
};

// Studio files-upload page table helper.
// Wired into org.openedx.frontend.authoring.files_upload_page_table.v1.
const MerekaAuthoringFilesUploadPageTableHint = () => {
  return (
    <div className="mereka-authoring-files-upload-page-table-hint">
      <span className="small">Label files clearly so learners can discover the right assets fast.</span>
    </div>
  );
};

// Studio videos-upload page table helper.
// Wired into org.openedx.frontend.authoring.videos_upload_page_table.v1.
const MerekaAuthoringVideosUploadPageTableHint = () => {
  return (
    <div className="mereka-authoring-videos-upload-page-table-hint">
      <span className="small">Prioritize transcripts and descriptive titles for each uploaded video.</span>
    </div>
  );
};

// Studio video transcript translations helper.
// Wired into org.openedx.frontend.authoring.video_transcript_additional_translations_component.v1.
const MerekaAuthoringVideoTranscriptTranslationsHint = () => {
  return (
    <div className="mereka-authoring-video-transcript-translations-hint">
      <span className="small">Add multilingual transcript tracks to improve inclusivity and completion.</span>
    </div>
  );
};

// Custom learner-dashboard sidebar widget for branded links and support prompts.
// Registered via org.openedx.frontend.learner_dashboard.widget_sidebar.v1.
const MerekaLearnerSidebarWidget = () => {
  const config = getConfig();
  const baseUrl = (config.LMS_BASE_URL || '').replace(/\\/$/, '');
  const variant = getMerekaVariant(typeof window !== 'undefined' ? window.location.hostname : '', config);
  const dashboardPath = baseUrl ? `${baseUrl}/dashboard` : '/dashboard';
  const coursesPath = baseUrl ? `${baseUrl}/dashboard/courses` : '/dashboard/courses';
  const helpPath = variant.helpUrl || '/help/';

  return (
    <div className="mereka-learner-sidebar-widget">
      <p className="h5 mb-2">{variant.brand} quick links</p>
      <a href={dashboardPath} className="d-block mb-1">Dashboard</a>
      <a href={coursesPath} className="d-block mb-1">My Courses</a>
      <a href={helpPath} className="d-block">Support</a>
    </div>
  );
};

// Learner-dashboard empty-state override for no enrolled courses.
// Wired into org.openedx.frontend.learner_dashboard.no_courses_view.v1.
const MerekaNoCoursesView = () => {
  const config = getConfig();
  const baseUrl = (config.LMS_BASE_URL || '').replace(/\\/$/, '');
  const dashboardPath = baseUrl ? `${baseUrl}/dashboard` : '/dashboard';
  const discoverPath = baseUrl ? `${baseUrl}/dashboard/courses` : '/dashboard/courses';

  return (
    <div className="mereka-no-courses-view p-4 text-center">
      <h2 className="h4 mb-3">Welcome to your learner dashboard</h2>
      <p className="mereka-no-courses-view__message mb-3">
        Your dashboard is ready, but you are not enrolled in any courses yet.
      </p>
      <div className="mereka-no-courses-view__actions">
        <a href={discoverPath} className="btn btn-brand me-2 mb-2">Discover courses</a>
        <a href={dashboardPath} className="btn btn-outline-primary mb-2">Back to dashboard</a>
      </div>
    </div>
  );
};

// Learner-dashboard course-list slot surface (high-visibility post-login branding).
// Wired into org.openedx.frontend.learner_dashboard.course_list.v1.
const MerekaDashboardHeader = () => {
  const config = getConfig();
  const variant = getMerekaVariant(typeof window !== 'undefined' ? window.location.hostname : '', config);

  return (
    <section className="mereka-dashboard-header-slot mb-3">
      <p className="mereka-badge mb-2">Mereka Learning</p>
      <h2 className="h4 mb-1">Welcome back to {variant.brand}</h2>
      <p className="mb-0 small text-muted">Pick up where you left off and keep your momentum.</p>
    </section>
  );
};

// Learner-dashboard course-card banner accent slot.
// Wired into org.openedx.frontend.learner_dashboard.course_card_banner.v1.
const MerekaCourseCardAccent = ({ cardId }) => {
  const safeCardId = typeof cardId === 'string' ? cardId : '';
  return (
    <div className="mereka-course-card-accent">
      <span className="mereka-badge">Mereka Curated</span>
      {safeCardId ? <span className="mereka-course-card-accent__meta">{safeCardId}</span> : null}
    </div>
  );
};

// Learner-dashboard course-card action slot helper.
// Wired into org.openedx.frontend.learner_dashboard.course_card_action.v1.
const MerekaCourseCardActionHint = () => {
  return (
    <div className="mereka-course-card-action-hint">
      <span>Keep your weekly learning streak active.</span>
    </div>
  );
};

// Learner-dashboard modal helper slot.
// Wired into org.openedx.frontend.learner_dashboard.dashboard_modal.v1.
const MerekaDashboardModalHint = () => {
  return (
    <div className="mereka-dashboard-modal-hint">
      <p className="mereka-badge mb-2">Mereka update</p>
      <p className="small mb-0">New curated pathways are available for your active learning goals.</p>
    </div>
  );
};

// Learning course-outline sidebar branding card inserted into course-outline-sidebar slot.
// Wired into org.openedx.frontend.learning.course_outline_sidebar.v1.
const MerekaCourseOutlineSidebar = () => {
  const config = getConfig();
  const variant = getMerekaVariant(typeof window !== 'undefined' ? window.location.hostname : '', config);
  const helpPath = variant.helpUrl || '/help/';

  return (
    <aside className="mereka-course-outline-sidebar mb-3 border rounded p-3">
      <h3 className="h6 mb-2">{variant.brand} Course Hub</h3>
      <p className="small text-muted mb-3">
        Use this area to find support resources while learning.
      </p>
      <a href={helpPath} className="d-inline-block">Help centre</a>
    </aside>
  );
};

// Learning header slot for branded in-course context.
// Wired into org.openedx.frontend.layout.header_learning.v1.
const MerekaLearningCourseHeader = () => {
  const config = getConfig();
  const variant = getMerekaVariant(typeof window !== 'undefined' ? window.location.hostname : '', config);

  return (
    <div className="mereka-learning-course-header mb-3">
      <span className="mereka-badge">Learning</span>
      <p className="mereka-learning-course-header__text mb-0">
        You are learning with {variant.brand}.
      </p>
    </div>
  );
};

// Learning tabs slot helper strip.
// Wired into org.openedx.frontend.learning.course_tab_links.v1.
const MerekaLearningCourseTabsHint = () => {
  return (
    <div className="mereka-learning-course-tabs-hint mb-2">
      <span>Track your progress, discussions, and key dates in one place.</span>
    </div>
  );
};

// Learning course breadcrumbs slot helper.
// Wired into org.openedx.frontend.learning.course_breadcrumbs.v1.
const MerekaLearningCourseBreadcrumbsHint = ({ courseId }) => {
  const safeCourseId = typeof courseId === 'string' ? courseId : '';
  return (
    <div className="mereka-learning-course-breadcrumbs-hint mb-2">
      <span className="mereka-badge me-2">Course</span>
      <span className="small text-muted">
        {safeCourseId ? `ID: ${safeCourseId}` : 'Track your pathway and continue with confidence.'}
      </span>
    </div>
  );
};

// Learning learner-tools slot helper.
// Wired into org.openedx.frontend.learning.learner_tools.v1.
const MerekaLearningLearnerToolsHint = ({ enrollmentMode, isStaff }) => {
  const mode = typeof enrollmentMode === 'string' && enrollmentMode ? enrollmentMode : 'audit';
  return (
    <div className="mereka-learning-learner-tools-hint mb-2">
      <span className="mereka-badge me-2">Learner tools</span>
      <span className="small text-muted">
        Mode: {mode}{isStaff ? ' · Staff utilities enabled' : ''}
      </span>
    </div>
  );
};

// Learning progress course-grade slot helper.
// Wired into org.openedx.frontend.learning.progress_tab_course_grade.v1.
const MerekaProgressCourseGradeHint = ({ courseId }) => {
  const safeCourseId = typeof courseId === 'string' ? courseId : '';
  return (
    <div className="mereka-progress-course-grade-hint mb-2">
      <span className="mereka-badge me-2">Grade</span>
      <span className="small text-muted">
        Keep progressing in {safeCourseId || 'your active course'} to strengthen outcomes.
      </span>
    </div>
  );
};

// Learning progress related-links slot helper.
// Wired into org.openedx.frontend.learning.progress_tab_related_links.v1.
const MerekaProgressRelatedLinksHint = () => {
  const config = getConfig();
  const variant = getMerekaVariant(typeof window !== 'undefined' ? window.location.hostname : '', config);
  const helpPath = variant.helpUrl || '/help/';
  return (
    <div className="mereka-progress-related-links-hint mb-2">
      <span className="mereka-badge me-2">Resources</span>
      <a href={helpPath} className="small">Need support? Visit the help centre.</a>
    </div>
  );
};

// Learning progress grade-breakdown slot helper.
// Wired into org.openedx.frontend.learning.progress_tab_grade_breakdown.v1.
const MerekaProgressGradeBreakdownHint = ({ courseId }) => {
  const safeCourseId = typeof courseId === 'string' ? courseId : '';
  return (
    <div className="mereka-progress-grade-breakdown-hint mb-2">
      <span className="mereka-badge me-2">Grade details</span>
      <span className="small text-muted">
        {safeCourseId ? `Review assessment trends for ${safeCourseId}.` : 'Review assessment trends and retry weak areas.'}
      </span>
    </div>
  );
};

// Learning unit-title slot helper.
// Wired into org.openedx.frontend.learning.unit_title.v1.
const MerekaLearningUnitTitleHint = ({ unit }) => {
  const title = unit && typeof unit.title === 'string' ? unit.title : '';
  return (
    <div className="mereka-learning-unit-title-hint mb-2">
      <span className="mereka-badge me-2">Unit</span>
      {title ? <span className="small text-muted">{title}</span> : null}
    </div>
  );
};

// Learning sequence-navigation slot helper.
// Wired into org.openedx.frontend.learning.sequence_navigation.v1.
const MerekaLearningSequenceNavigationHint = ({ unitId }) => {
  const safeUnitId = typeof unitId === 'string' ? unitId : '';
  return (
    <div className="mereka-learning-sequence-navigation-hint mb-2">
      <span className="mereka-badge me-2">Navigation</span>
      <span className="small text-muted">
        {safeUnitId ? `Current unit: ${safeUnitId}` : 'Move through each unit step by step.'}
      </span>
    </div>
  );
};

// Learning desktop outline-trigger slot helper.
// Wired into org.openedx.frontend.learning.course_outline_sidebar_trigger.v1.
const MerekaLearningOutlineSidebarTriggerHint = () => {
  return (
    <span className="mereka-learning-outline-sidebar-trigger-hint mereka-badge d-none d-xl-inline-block">
      Outline
    </span>
  );
};

// Learning mobile outline-trigger slot helper.
// Wired into org.openedx.frontend.learning.course_outline_mobile_sidebar_trigger.v1.
const MerekaLearningOutlineMobileSidebarTriggerHint = () => {
  return (
    <span className="mereka-learning-outline-mobile-sidebar-trigger-hint mereka-badge d-xl-none">
      Outline
    </span>
  );
};

// Learning course-home section-outline slot helper.
// Wired into org.openedx.frontend.learning.course_home_section_outline.v1.
const MerekaLearningCourseHomeSectionOutlineHint = () => {
  return (
    <div className="mereka-learning-course-home-section-outline-hint mb-2">
      <span className="mereka-badge me-2">Course home</span>
      <span className="small text-muted">Follow each section in sequence for best outcomes.</span>
    </div>
  );
};

// Learning course-recommendations slot helper.
// Wired into org.openedx.frontend.learning.course_recommendations.v1.
const MerekaLearningCourseRecommendationsHint = ({ variant }) => {
  const safeVariant = typeof variant === 'string' && variant ? variant : 'default';
  return (
    <div className="mereka-learning-course-recommendations-hint mb-2">
      <span className="mereka-badge me-2">Next step</span>
      <span className="small text-muted">Explore recommended pathways ({safeVariant}).</span>
    </div>
  );
};

// Learning iframe-loader slot helper.
// Wired into org.openedx.frontend.learning.content_iframe_loader.v1.
const MerekaLearningContentIFrameLoaderHint = () => {
  return (
    <div className="mereka-learning-content-iframe-loader-hint mb-2">
      <span className="mereka-badge me-2">Loading</span>
      <span className="small text-muted">Preparing learning content.</span>
    </div>
  );
};

// Learning iframe-error slot helper.
// Wired into org.openedx.frontend.learning.content_iframe_error.v1.
const MerekaLearningContentIFrameErrorHint = ({ errorMessage }) => {
  const message = typeof errorMessage === 'string' && errorMessage ? errorMessage : 'If this persists, contact support.';
  return (
    <div className="mereka-learning-content-iframe-error-hint mb-2">
      <span className="mereka-badge me-2">Content issue</span>
      <span className="small text-muted">{message}</span>
    </div>
  );
};

// Learning sequence-container slot helper.
// Wired into org.openedx.frontend.learning.sequence_container.v1.
const MerekaLearningSequenceContainerHint = () => {
  return (
    <div className="mereka-learning-sequence-container-hint mb-2">
      <span className="mereka-badge me-2">Sequence</span>
      <span className="small text-muted">Continue through the next unit to maintain momentum.</span>
    </div>
  );
};

// Learning gated-unit message slot helper.
// Wired into org.openedx.frontend.learning.gated_unit_content_message.v1.
const MerekaLearningGatedUnitContentMessageHint = () => {
  return (
    <div className="mereka-learning-gated-unit-content-message-hint mb-2">
      <span className="mereka-badge me-2">Access</span>
      <span className="small text-muted">Unlock this unit by completing the required prerequisites.</span>
    </div>
  );
};

// Learning next-unit top-nav trigger slot helper.
// Wired into org.openedx.frontend.learning.next_unit_top_nav_trigger.v1.
const MerekaLearningNextUnitTopNavTriggerHint = () => {
  return (
    <span className="mereka-learning-next-unit-top-nav-trigger-hint mereka-badge d-none d-lg-inline-block">
      Next unit
    </span>
  );
};

// Learning course-outline tab notifications slot helper.
// Wired into org.openedx.frontend.learning.course_outline_tab_notifications.v1.
const MerekaLearningCourseOutlineTabNotificationsHint = () => {
  return (
    <div className="mereka-learning-course-outline-tab-notifications-hint mb-2">
      <span className="mereka-badge me-2">Updates</span>
      <span className="small text-muted">Review announcements and due dates before you continue.</span>
    </div>
  );
};

// Learning notification-widget slot helper.
// Wired into org.openedx.frontend.learning.notification_widget.v1.
const MerekaLearningNotificationWidgetHint = () => {
  return (
    <div className="mereka-learning-notification-widget-hint mb-2">
      <span className="mereka-badge me-2">Alert</span>
      <span className="small text-muted">Stay on top of important learning notifications.</span>
    </div>
  );
};

// Learning notification-tray slot helper.
// Wired into org.openedx.frontend.learning.notification_tray.v1.
const MerekaLearningNotificationTrayHint = () => {
  return (
    <div className="mereka-learning-notification-tray-hint mb-2">
      <span className="mereka-badge me-2">Notification tray</span>
      <span className="small text-muted">Your recent course updates are grouped here.</span>
    </div>
  );
};

// Learning discussions/sidebar trigger slot helper.
// Wired into org.openedx.frontend.learning.notifications_discussions_sidebar_trigger.v1.
const MerekaLearningNotificationsDiscussionsSidebarTriggerHint = () => {
  return (
    <span className="mereka-learning-notifications-discussions-sidebar-trigger-hint mereka-badge">
      Discussions
    </span>
  );
};

// Learning discussions/sidebar slot helper.
// Wired into org.openedx.frontend.learning.notifications_discussions_sidebar.v1.
const MerekaLearningNotificationsDiscussionsSidebarHint = () => {
  return (
    <div className="mereka-learning-notifications-discussions-sidebar-hint mb-2">
      <span className="mereka-badge me-2">Community</span>
      <span className="small text-muted">Join discussions and track replies in one panel.</span>
    </div>
  );
};

// Learning course-exit view-courses slot helper.
// Wired into org.openedx.frontend.learning.course_exit_view_courses.v1.
const MerekaLearningCourseExitViewCoursesHint = () => {
  const config = getConfig();
  const variant = getMerekaVariant(typeof window !== 'undefined' ? window.location.hostname : '', config);
  return (
    <div className="mereka-learning-course-exit-view-courses-hint mb-2">
      <a href="/dashboard/courses" className="small">Browse more courses from {variant.brand}.</a>
    </div>
  );
};

// Learning course-exit dashboard-footnote slot helper.
// Wired into org.openedx.frontend.learning.course_exit_dashboard_footnote_link.v1.
const MerekaLearningCourseExitDashboardFootnoteLinkHint = () => {
  return (
    <div className="mereka-learning-course-exit-dashboard-footnote-link-hint mb-2">
      <a href="/dashboard" className="small">Return to your dashboard for next actions.</a>
    </div>
  );
};

// Learning progress certificate status branding and context card.
// Wired into org.openedx.frontend.learning.progress_certificate_status.v1.
const MerekaProgressCertificateStatus = ({ courseId }) => {
  const config = getConfig();
  const variant = getMerekaVariant(typeof window !== 'undefined' ? window.location.hostname : '', config);
  const safeCourseId = typeof courseId === 'string' ? courseId : '';

  return (
    <div className="mereka-progress-certificate-status my-3 p-3 rounded">
      <p className="mb-1 fw-semibold">Progress snapshot</p>
      <p className="mb-0 small text-muted">
        {variant.brand} Learning —{safeCourseId ? ` course ${safeCourseId}` : ''} is active. Keep completing units to unlock your certificate.
      </p>
    </div>
  );
};

// Account ID verification helper slot.
// Wired into org.openedx.frontend.account.id_verification_page.v1.
const MerekaAccountIdVerificationHint = () => {
  return (
    <p className="mereka-account-id-verification-hint mb-2">
      ID verification details are reviewed by your learning administrator for secure certificate issuance.
    </p>
  );
};

// Enterprise profile section for account/profile additional profile field slots.
// Wired into org.openedx.frontend.account.additional_profile_fields.v1 and
// org.openedx.frontend.profile.additional_profile_fields.v1.
const MerekaAdditionalProfileFields = () => {
  const config = getConfig();
  const variant = getMerekaVariant(typeof window !== 'undefined' ? window.location.hostname : '', config);

  return (
    <section className="mereka-additional-profile-fields mb-3">
      <h2 className="h5 mb-2">Enterprise profile details</h2>
      <p className="small mb-3">For {variant.brand} workplace setups, these fields are preconfigured by your admin team.</p>
      <ul className="mereka-additional-profile-fields__list list-unstyled mb-0">
        <li className="mb-2">Organization: <strong>{variant.brand}</strong></li>
        <li className="mb-2">Job title: <strong>—</strong></li>
        <li className="mb-2">Department: <strong>—</strong></li>
      </ul>
    </section>
  );
};

// Custom Mereka footer component (Direct plugin — registered via footer_slot)
// Wired into org.openedx.frontend.layout.footer.v1 by PLUGIN_SLOTS in mereka_lms.py
const MerekaFooter = () => {
  const config = getConfig();
  const baseUrl = (config.LMS_BASE_URL || '').replace(/\\/$/, '');
  const currentYear = new Date().getFullYear();
  const hostname = typeof window !== 'undefined' ? window.location.hostname : '';
  const variant = getMerekaVariant(hostname, config);
  const logoPath = variant.logoUrl || '/theme/logo-horizontal.svg';
  const logoUrl = baseUrl ? `${baseUrl}${logoPath}` : logoPath;

  const socialLinks = [
    { name: 'TikTok', url: 'https://www.tiktok.com/@mereka.io', icon: 'M19.59 6.69a4.83 4.83 0 0 1-3.77-4.25V2h-3.45v13.67a2.89 2.89 0 0 1-5.2 1.74 2.89 2.89 0 0 1 2.31-4.64 2.93 2.93 0 0 1 .88.13V9.4a6.84 6.84 0 0 0-1-.05A6.33 6.33 0 0 0 5 20.1a6.34 6.34 0 0 0 10.86-4.43v-7a8.16 8.16 0 0 0 4.77 1.52v-3.4a4.85 4.85 0 0 1-1-.1z' },
    { name: 'Instagram', url: 'https://www.instagram.com/mereka.io/', icon: 'M12 2.163c3.204 0 3.584.012 4.85.07 3.252.148 4.771 1.691 4.919 4.919.058 1.265.069 1.645.069 4.849 0 3.205-.012 3.584-.069 4.849-.149 3.225-1.664 4.771-4.919 4.919-1.266.058-1.644.07-4.85.07-3.204 0-3.584-.012-4.849-.07-3.26-.149-4.771-1.699-4.919-4.92-.058-1.265-.07-1.644-.07-4.849 0-3.204.013-3.583.07-4.849.149-3.227 1.664-4.771 4.919-4.919 1.266-.057 1.645-.069 4.849-.069zm0-2.163c-3.259 0-3.667.014-4.947.072-4.358.2-6.78 2.618-6.98 6.98-.059 1.281-.073 1.689-.073 4.948 0 3.259.014 3.668.072 4.948.2 4.358 2.618 6.78 6.98 6.98 1.281.058 1.689.072 4.948.072 3.259 0 3.668-.014 4.948-.072 4.354-.2 6.782-2.618 6.979-6.98.059-1.28.073-1.689.073-4.948 0-3.259-.014-3.667-.072-4.947-.196-4.354-2.617-6.78-6.979-6.98-1.281-.059-1.69-.073-4.949-.073zm0 5.838c-3.403 0-6.162 2.759-6.162 6.162s2.759 6.163 6.162 6.163 6.162-2.759 6.162-6.163c0-3.403-2.759-6.162-6.162-6.162zm0 10.162c-2.209 0-4-1.79-4-4 0-2.209 1.791-4 4-4s4 1.791 4 4c0 2.21-1.791 4-4 4zm6.406-11.845c-.796 0-1.441.645-1.441 1.44s.645 1.44 1.441 1.44c.795 0 1.439-.645 1.439-1.44s-.644-1.44-1.439-1.44z' },
    { name: 'Facebook', url: 'https://www.facebook.com/mereka.io', icon: 'M24 12.073c0-6.627-5.373-12-12-12s-12 5.373-12 12c0 5.99 4.388 10.954 10.125 11.854v-8.385H7.078v-3.47h3.047V9.43c0-3.007 1.792-4.669 4.533-4.669 1.312 0 2.686.235 2.686.235v2.953H15.83c-1.491 0-1.956.925-1.956 1.874v2.25h3.328l-.532 3.47h-2.796v8.385C19.612 23.027 24 18.062 24 12.073z' },
    { name: 'LinkedIn', url: 'https://www.linkedin.com/company/mereka/', icon: 'M20.447 20.452h-3.554v-5.569c0-1.328-.027-3.037-1.852-3.037-1.853 0-2.136 1.445-2.136 2.939v5.667H9.351V9h3.414v1.561h.046c.477-.9 1.637-1.85 3.37-1.85 3.601 0 4.267 2.37 4.267 5.455v6.286zM5.337 7.433c-1.144 0-2.063-.926-2.063-2.065 0-1.138.92-2.063 2.063-2.063 1.14 0 2.064.925 2.064 2.063 0 1.139-.925 2.065-2.064 2.065zm1.782 13.019H3.555V9h3.564v11.452zM22.225 0H1.771C.792 0 0 .774 0 1.729v20.542C0 23.227.792 24 1.771 24h20.451C23.2 24 24 23.227 24 22.271V1.729C24 .774 23.2 0 22.222 0h.003z' },
    { name: 'YouTube', url: 'https://www.youtube.com/channel/UCCyMH5KIZeCMchjMKl7RWxg', icon: 'M23.498 6.186a3.016 3.016 0 0 0-2.122-2.136C19.505 3.545 12 3.545 12 3.545s-7.505 0-9.377.505A3.017 3.017 0 0 0 .502 6.186C0 8.07 0 12 0 12s0 3.93.502 5.814a3.016 3.016 0 0 0 2.122 2.136c1.871.505 9.376.505 9.376.505s7.505 0 9.377-.505a3.015 3.015 0 0 0 2.122-2.136C24 15.93 24 12 24 12s0-3.93-.502-5.814zM9.545 15.568V8.432L15.818 12l-6.273 3.568z' },
  ];

  // navLinks: corporate-global links are the same for all tenants.
  // Help Centre and Support email are resolved from the tenant data contract (variant).
  const navLinks = [
    { label: 'About', url: 'https://corporate.mereka.io/about-us' },
    { label: 'Andragogy', url: 'https://corporate.mereka.io/andragogy' },
    { label: 'Portfolio', url: 'https://corporate.mereka.io/portfolio' },
    { label: 'Team', url: 'https://corporate.mereka.io/our-team' },
    { label: 'Careers', url: 'https://corporate.mereka.io/work-with-us' },
    { label: 'Ecosystem', url: 'https://corporate.mereka.io/ecosystem' },
    { label: 'Blog', url: 'https://corporate.mereka.io/blog' },
    { label: 'Help Centre', url: variant.helpUrl },
    { label: 'Contact Support', url: 'mailto:' + variant.supportEmail },
  ];

  const corporateLinks = [
    { label: 'Accelerate Talent', url: 'https://corporate.mereka.io/academy/funders' },
    { label: 'Create Online Course', url: 'https://corporate.mereka.io/academy/create-online-courses' },
    { label: 'Build a Makerspace', url: 'https://corporate.mereka.io/academy/makerspace' },
  ];

  const marketplaceUserLinks = [
    { label: 'Experiences', url: 'https://mereka.io/experiences' },
    { label: 'Experts', url: 'https://mereka.io/experts' },
    { label: 'Expertise', url: 'https://mereka.io/expertise' },
    { label: 'Hubs', url: 'https://mereka.io/hubs' },
    { label: 'Spaces', url: 'https://corporate.mereka.io/space' },
  ];

  const marketplaceBusinessLinks = [
    { label: 'Pricing', url: 'https://hubs.mereka.io/pricing' },
    { label: 'Solutions', url: 'https://hubs.mereka.io/howitworks' },
  ];

  const academyLinks = [
    { label: 'Future of Work', url: 'https://corporate.mereka.io/academy/future-of-work' },
    { label: 'Digital Entrepreneur', url: 'https://corporate.mereka.io/academy/digital-entrepreneur' },
    { label: 'All Courses', url: 'https://corporate.mereka.io/academy/all-courses' },
  ];

  const spaceLinks = [
    { label: 'Mereka @ Publika', url: 'https://corporate.mereka.io/publika' },
    { label: 'Our Labs', url: 'https://corporate.mereka.io/space#labs' },
    { label: 'Bespoke Design', url: 'https://corporate.mereka.io/space/innovate#products' },
    { label: 'Host Events', url: 'https://corporate.mereka.io/space#event-cta' },
  ];

  const SocialIcon = ({ d }) => (
    <svg
      className="mereka-footer__social-icon"
      style={socialIconStyle}
      fill="currentColor"
      viewBox="0 0 24 24"
    >
      <path d={d} />
    </svg>
  );

  const WhatsAppIcon = () => (
    <svg
      className="mereka-footer__social-icon"
      style={whatsappIconStyle}
      fill="currentColor"
      viewBox="0 0 24 24"
    >
      <path d="M.057 24l1.687-6.163c-1.041-1.804-1.588-3.849-1.587-5.946.003-6.556 5.338-11.891 11.893-11.891 3.181.001 6.167 1.24 8.413 3.488 2.245 2.248 3.481 5.236 3.48 8.414-.003 6.557-5.338 11.892-11.893 11.892-1.99-.001-3.951-.5-5.688-1.448l-6.305 1.654zm6.597-3.807c1.676.995 3.276 1.591 5.392 1.592 5.448 0 9.886-4.434 9.889-9.885.002-5.462-4.415-9.89-9.881-9.892-5.452 0-9.887 4.434-9.889 9.884-.001 2.225.651 3.891 1.746 5.634l-.999 3.648 3.742-.981zm11.387-5.464c-.074-.124-.272-.198-.57-.347-.297-.149-1.758-.868-2.031-.967-.272-.099-.47-.149-.669.149-.198.297-.768.967-.941 1.165-.173.198-.347.223-.644.074-.297-.149-1.255-.462-2.39-1.475-.883-.788-1.48-1.761-1.653-2.059-.173-.297-.018-.458.13-.606.134-.133.297-.347.446-.521.151-.172.2-.296.3-.495.099-.198.05-.372-.025-.521-.075-.148-.669-1.611-.916-2.206-.242-.579-.487-.501-.669-.51l-.57-.01c-.198 0-.52.074-.792.372s-1.04 1.016-1.04 2.479 1.065 2.876 1.213 3.074c.149.198 2.095 3.2 5.076 4.487.709.306 1.263.489 1.694.626.712.226 1.36.194 1.872.118.571-.085 1.758-.719 2.006-1.413.248-.695.248-1.29.173-1.414z" />
    </svg>
  );

  const socialIconStyle = {
    width: '20px',
    height: '20px',
  };

  const whatsappIconStyle = {
    width: '20px',
    height: '20px',
    color: '#25D366',
  };

  return (
    <footer className="mereka-footer mereka-footer--v2" role="contentinfo">
      {/* Zone 1: Social Row */}
      <div className="footer-social">
        <div className="footer-container">
          <a href={baseUrl || '/'} className="footer-logo-link">
            {logoUrl ? <img src={logoUrl} alt={variant.brand + ' logo'} className="footer-logo-img" /> : null}
            <span className="footer-brand-name">mereka</span>
          </a>
          <div className="footer-social-icons">
            {socialLinks.map(s => (
              <a key={s.name} href={s.url} target="_blank" rel="noopener noreferrer" aria-label={s.name} className="footer-social-link">
                <SocialIcon d={s.icon} />
              </a>
            ))}
          </div>
        </div>
      </div>

      {/* Zone 2: Nav Strip */}
      <div className="footer-nav">
        <div className="footer-container">
          <nav className="footer-nav-links">
            {navLinks.map(l => (
              <a key={l.label} href={l.url} target="_blank" rel="noopener noreferrer">{l.label}</a>
            ))}
          </nav>
          <a href={'https://wa.me/' + variant.whatsapp} target="_blank" rel="noopener noreferrer" className="footer-whatsapp-btn">
            <WhatsAppIcon /> Contact Us
          </a>
        </div>
      </div>

      {/* Zone 3: 4-Column Body */}
      <div className="footer-body">
        <div className="footer-container footer-columns">
          <div className="footer-column">
            <h4 className="footer-column-title">Corporate</h4>
            <ul>{corporateLinks.map(l => <li key={l.label}><a href={l.url} target="_blank" rel="noopener noreferrer">{l.label}</a></li>)}</ul>
          </div>
          <div className="footer-column footer-column--wide">
            <h4 className="footer-column-title">Marketplace</h4>
            <div className="footer-marketplace-grid">
              <div>
                <p className="footer-sub-heading">USERS</p>
                <ul>{marketplaceUserLinks.map(l => <li key={l.label}><a href={l.url} target="_blank" rel="noopener noreferrer">{l.label}</a></li>)}</ul>
              </div>
              <div>
                <p className="footer-sub-heading">BUSINESS</p>
                <ul>{marketplaceBusinessLinks.map(l => <li key={l.label}><a href={l.url} target="_blank" rel="noopener noreferrer">{l.label}</a></li>)}</ul>
                <p className="footer-app-label">Manage your bookings</p>
                <div className="footer-app-badges">
                  <a href="https://apps.apple.com/id/app/mereka-hubs/id6473277964" target="_blank" rel="noopener noreferrer" className="footer-badge">App Store</a>
                  <a href="https://play.google.com/store/apps/details?id=io.mereka.hubs" target="_blank" rel="noopener noreferrer" className="footer-badge">Google Play</a>
                </div>
                <a href="https://mereka.io/welcome/hub" target="_blank" rel="noopener noreferrer" className="footer-cta-btn">Become a Hub</a>
              </div>
            </div>
          </div>
          <div className="footer-column">
            <h4 className="footer-column-title">Academy</h4>
            <ul>{academyLinks.map(l => <li key={l.label}><a href={l.url} target="_blank" rel="noopener noreferrer">{l.label}</a></li>)}</ul>
          </div>
          <div className="footer-column">
            <h4 className="footer-column-title">Space</h4>
            <ul>{spaceLinks.map(l => <li key={l.label}><a href={l.url} target="_blank" rel="noopener noreferrer">{l.label}</a></li>)}</ul>
          </div>
        </div>
      </div>

      {/* Zone 4: Legal Bottom — URLs resolved from tenant data contract (variant) */}
      <div className="footer-legal">
        <div className="footer-container footer-legal-row">
          <span className="footer-copyright">&copy; {currentYear} {variant.copyrightHolder}</span>
          <a href={variant.termsUrl} target="_blank" rel="noopener noreferrer">TERMS OF USE</a>
          <a href={variant.privacyUrl} target="_blank" rel="noopener noreferrer">PRIVACY POLICY</a>
          <a href={variant.cookiesUrl} target="_blank" rel="noopener noreferrer">COOKIES POLICY</a>
        </div>
      </div>
    </footer>
  );
};
{% endraw %}
""",
    )
)

###############################################################################
# MySQL Dockerfile Patches
###############################################################################

hooks.Filters.ENV_PATCHES.add_item(
    (
        "mysql-docker-compose",
        """
# MySQL 8 authentication plugin fix
environment:
  MYSQL_ROOT_HOST: "%"
command: mysqld --default-authentication-plugin=mysql_native_password
""",
    )
)

###############################################################################
# Caddy Configuration Patches
###############################################################################

# Add extra LMS host blocks to Caddyfile
hooks.Filters.ENV_PATCHES.add_item(
    (
        "caddyfile",
        """
(security_headers) {
    header {
        Strict-Transport-Security "max-age=31536000; includeSubDomains"
        X-Content-Type-Options "nosniff"
        X-Frame-Options "DENY"
        Referrer-Policy "strict-origin-when-cross-origin"
        Permissions-Policy "camera=(), microphone=(), geolocation=()"
        X-XSS-Protection "0"
    }
}

# Additional LMS sites
{% for host in MEREKA_LMS_EXTRA_HOSTS %}
{{ host }}{$default_site_port} {
    import security_headers

    @favicon_matcher {
        path_regexp ^/favicon.ico$
    }
    rewrite @favicon_matcher /theming/asset/images/favicon.ico

    # Limit profile image upload size
    handle_path /api/profile_images/*/*/upload {
        request_body {
            max_size 1MB
        }
    }

    import proxy "lms:8000"

    handle_path /* {
        request_body {
            max_size 4MB
        }
    }
}
{% endfor %}

# MFE proxy: Forward selected MFE API paths to LMS for correct host context
{{ MFE_HOST }}{$default_site_port} {
    import security_headers

    reverse_proxy /profile/api/* lms:8000 {
        # Preserve incoming host for tenant-aware SiteConfiguration resolution
        header_up Host {http.request.host}
    }

    reverse_proxy /api/mfe_config/v1* lms:8000 {
        header_up Host {http.request.host}
    }
}
""",
    )
)

###############################################################################
# Nginx Configuration Patches
###############################################################################

hooks.Filters.ENV_PATCHES.add_item(
    (
        "nginx-lms-config",
        """
# Additional server names for multi-site support
{% for host in MEREKA_LMS_EXTRA_HOSTS %}
{{ host }}{% if not loop.last %} {% endif %}
{% endfor %}

# Health check endpoint
location = /health {
    default_type text/plain;
    return 200 "ok\\n";
}

# Prometheus metrics endpoint (internal access only)
location = /metrics {
    proxy_set_header Host $http_host;
    proxy_redirect off;
    proxy_pass http://lms-backend;
}

# MFE profile API proxy
location ^~ /profile/api/ {
    proxy_set_header Host $http_host;
    proxy_redirect off;
    proxy_pass http://lms-backend;
}
""",
    )
)

###############################################################################
# Credentials Service Patches (Verifiable Credentials)
###############################################################################

# Install credentials_vc_issuer custom app
hooks.Filters.ENV_PATCHES.add_item(
    (
        "credentials-dockerfile-post-python-requirements",
        """
# Copy and install credentials_vc_issuer custom app
COPY --chown=app:app ./infrastructure/tutor/custom-apps/credentials_vc_issuer /openedx/credentials_vc_issuer
RUN pip install -e /openedx/credentials_vc_issuer

# Install cryptography for Ed25519 key operations
RUN pip install cryptography>=41.0.0

# Ensure ZoneInfo("UTC") works even when OS tzdata files are absent
RUN pip install tzdata>=2024.1
""",
    )
)

# NOTE: credentials-urlpatterns is NOT a standard Tutor patch. The VC issuer
# URLs must be wired via the credentials_vc_issuer AppConfig or by providing
# a custom urls.py template via ENV_TEMPLATE_TARGETS when the credentials
# service is deployed.  See: credentials_vc_issuer/apps.py

# CMS production settings patch (metrics + URL exposure in Studio)
hooks.Filters.ENV_PATCHES.add_item(
    (
        "openedx-cms-production-settings",
        f"""
{_CMS_PROMETHEUS_METRICS_SNIPPET}
# Explicit ROOT_URLCONF_OVERRIDES keeps /metrics stable across plugin API variations.
""",
    )
)

# CMS development settings patch (metrics parity with production).
# Keep this in sync with production CMS metrics wiring so nonprod/dev also has /metrics.
hooks.Filters.ENV_PATCHES.add_item(
    (
        "openedx-cms-development-settings",
        _CMS_PROMETHEUS_METRICS_SNIPPET,
    )
)

###############################################################################
# Plugin Initialization Hook
###############################################################################

@hooks.Actions.PLUGIN_LOADED.add()
def _print_loading_message(plugin_name: str):
    """Print a message when the plugin is loaded."""
    if plugin_name == "mereka_lms":
        print(f"Mereka LMS plugin v{__version__} loaded")
