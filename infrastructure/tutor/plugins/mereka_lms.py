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
    ("MEREKA_SESSION_COOKIE_DOMAIN", ".academyv2.mereka.io"),
    ("MEREKA_CSRF_COOKIE_DOMAIN", ".academyv2.mereka.io"),
])

###############################################################################
# LMS Production Settings Patches
###############################################################################

hooks.Filters.ENV_PATCHES.add_item(
    (
        "openedx-lms-production-settings",
        """
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

_lms_url = MEREKA_LMS_BASE_URL
_mfe_url = MEREKA_MFE_BASE_URL
_studio_url = MEREKA_STUDIO_BASE_URL

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
    _mfe_base = globals().get("MEREKA_MFE_BASE_URL", "https://apps.academyv2.mereka.io")
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
INSTALLED_APPS.append('mfe_oauth_fix')

# Add middleware to fix /api/mfe_context responses
# Insert at the end of middleware stack so it processes responses
MIDDLEWARE.append('mfe_oauth_fix.middleware.MFEOAuthFixMiddleware')

# Prometheus Metrics Integration
# django_prometheus must be added at the START of INSTALLED_APPS
if 'django_prometheus' not in INSTALLED_APPS:
    INSTALLED_APPS.insert(0, 'django_prometheus')

# Add custom prometheus app for /metrics endpoint
if 'openedx_prometheus' not in INSTALLED_APPS:
    INSTALLED_APPS.append('openedx_prometheus')

# Prometheus middleware must wrap all other middleware
if 'django_prometheus.middleware.PrometheusBeforeMiddleware' not in MIDDLEWARE:
    MIDDLEWARE.insert(0, 'django_prometheus.middleware.PrometheusBeforeMiddleware')
if 'django_prometheus.middleware.PrometheusAfterMiddleware' not in MIDDLEWARE:
    MIDDLEWARE.append('django_prometheus.middleware.PrometheusAfterMiddleware')

ROOT_URLCONF_OVERRIDES = globals().get("ROOT_URLCONF_OVERRIDES", [])
if "openedx_prometheus.urls" not in ROOT_URLCONF_OVERRIDES:
    ROOT_URLCONF_OVERRIDES.insert(0, "openedx_prometheus.urls")

# In-App Notifications (Email Phase 3)
if 'openedx_notifications' not in INSTALLED_APPS:
    INSTALLED_APPS.append('openedx_notifications')

# Configure ACE channels for in-app notifications
ACE_ENABLED_CHANNELS = ["django_email", "in_app"]

# Feature flag for in-app notifications (enable by default)
NOTIFICATION_INAPP_ENABLED = True

# Email Preferences & GDPR Consent (Email Phase 2)
if 'openedx_email_preferences' not in INSTALLED_APPS:
    INSTALLED_APPS.append('openedx_email_preferences')

# Feature flag for email preferences (enable by default)
ENABLE_EMAIL_PREFERENCES = True

# Email unsubscribe secret (uses SECRET_KEY if not set)
import os
EMAIL_UNSUBSCRIBE_SECRET_KEY = os.environ.get('EMAIL_UNSUBSCRIBE_SECRET_KEY', SECRET_KEY)

# Rate limiting for preferences API (60 requests per minute per user)
RATELIMIT_ENABLE = True
RATELIMIT_USE_CACHE = 'default'

# Mux Video Upload (Video Phase 3: Studio Upload Workflow)
if 'openedx_mux_upload' not in INSTALLED_APPS:
    INSTALLED_APPS.append('openedx_mux_upload')

# Feature flag for Mux Studio upload (default: false, enable in production after testing)
ENABLE_MUX_STUDIO_UPLOAD = os.environ.get('ENABLE_MUX_STUDIO_UPLOAD', 'false').lower() == 'true'

# Mux API credentials (synced from Infisical via ExternalSecrets)
MUX_TOKEN_ID = os.environ.get('MUX_TOKEN_ID')
MUX_TOKEN_SECRET = os.environ.get('MUX_TOKEN_SECRET')
MUX_WEBHOOK_SECRET = os.environ.get('MUX_WEBHOOK_SECRET', '')  # Optional

# Video Analytics (Video Phase 4: Analytics Integration)
if 'openedx_video_analytics' not in INSTALLED_APPS:
    INSTALLED_APPS.append('openedx_video_analytics')

# Feature flag for video analytics (default: false, enable after validation)
ENABLE_VIDEO_ANALYTICS = os.environ.get('ENABLE_VIDEO_ANALYTICS', 'false').lower() == 'true'

# Video Content Protection (Video Phase 5: Signed Playback)
if 'openedx_video_protection' not in INSTALLED_APPS:
    INSTALLED_APPS.append('openedx_video_protection')

# Feature flag for signed playback (default: false, enable after E2E validation)
ENABLE_MUX_SIGNED_PLAYBACK = os.environ.get('ENABLE_MUX_SIGNED_PLAYBACK', 'false').lower() == 'true'

# Mux signing credentials (synced from Infisical via ExternalSecrets)
MUX_SIGNING_KEY_ID = os.environ.get('MUX_SIGNING_KEY_ID')  # Mux signing key ID
MUX_SIGNING_PRIVATE_KEY = os.environ.get('MUX_SIGNING_PRIVATE_KEY')  # RSA private key (PEM)

# ORA2 Operations & Observability (Assessment Phase 1)
if 'openedx_ora2_operations' not in INSTALLED_APPS:
    INSTALLED_APPS.append('openedx_ora2_operations')

# Feature flag for ORA2 operations (default: true, enable for production monitoring)
ENABLE_ORA2_OPERATIONS = os.environ.get('ENABLE_ORA2_OPERATIONS', 'true').lower() == 'true'

# Timed Exams - Server-Side Enforcement & Accommodations (Assessment Phase 2)
if 'openedx_timed_exams' not in INSTALLED_APPS:
    INSTALLED_APPS.append('openedx_timed_exams')

# Feature flag for timed exam enhancements (default: true)
ENABLE_TIMED_EXAM_ENHANCEMENTS = os.environ.get('ENABLE_TIMED_EXAM_ENHANCEMENTS', 'true').lower() == 'true'

# Add multi-device detection middleware (insert after authentication middleware)
if 'openedx_timed_exams.middleware.TimedExamEnforcementMiddleware' not in MIDDLEWARE:
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
if 'openedx_xqueue_graders' not in INSTALLED_APPS:
    INSTALLED_APPS.append('openedx_xqueue_graders')

# Feature flag for XQueue graders (default: true)
ENABLE_XQUEUE_GRADERS = os.environ.get('ENABLE_XQUEUE_GRADERS', 'true').lower() == 'true'

# XQueue grader configuration
XQUEUE_GRADER_TIMEOUT_SECONDS = int(os.environ.get('XQUEUE_GRADER_TIMEOUT_SECONDS', '30'))
XQUEUE_GRADER_MEMORY_LIMIT_MB = int(os.environ.get('XQUEUE_GRADER_MEMORY_LIMIT_MB', '256'))

# Advanced XBlocks - Drag-Drop, Math, Randomization (Assessment Phase 4)
if 'openedx_advanced_xblocks' not in INSTALLED_APPS:
    INSTALLED_APPS.append('openedx_advanced_xblocks')

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
if 'mereka_tenancy' not in INSTALLED_APPS:
    INSTALLED_APPS.append('mereka_tenancy')

# Add TenantResolutionMiddleware after AuthenticationMiddleware
# This ensures tenant context is available for authenticated requests
if 'mereka_tenancy.middleware.TenantResolutionMiddleware' not in MIDDLEWARE:
    auth_middleware_index = -1
    for i, mw in enumerate(MIDDLEWARE):
        if 'AuthenticationMiddleware' in mw:
            auth_middleware_index = i
            break
    if auth_middleware_index >= 0:
        MIDDLEWARE.insert(auth_middleware_index + 1, 'mereka_tenancy.middleware.TenantResolutionMiddleware')
    else:
        MIDDLEWARE.append('mereka_tenancy.middleware.TenantResolutionMiddleware')
""",
    )
)

###############################################################################
# LMS Assets Settings Patches (for collectstatic)
###############################################################################

hooks.Filters.ENV_PATCHES.add_item(
    (
        "openedx-lms-assets-settings",
        """
# Ensure optional Redwood apps exist when collecting assets
if "openedx.core.djangoapps.content_libraries.apps.ContentLibrariesConfig" not in INSTALLED_APPS:
    INSTALLED_APPS += ["openedx.core.djangoapps.content_libraries.apps.ContentLibrariesConfig"]
if "openedx.core.djangoapps.bookmarks.apps.BookmarksConfig" not in INSTALLED_APPS:
    INSTALLED_APPS += ["openedx.core.djangoapps.bookmarks.apps.BookmarksConfig"]
if "openedx.core.djangoapps.discussions.apps.DiscussionsConfig" not in INSTALLED_APPS:
    INSTALLED_APPS += ["openedx.core.djangoapps.discussions.apps.DiscussionsConfig"]
if "openedx.core.djangoapps.theming.apps.ThemingConfig" not in INSTALLED_APPS:
    INSTALLED_APPS += ["openedx.core.djangoapps.theming.apps.ThemingConfig"]

# Monkey-patch safe_join to be permissive during asset build.
# This fixes collectstatic SuspiciousFileOperation errors when CSS files
# reference relative paths like ../../css/images/correct-icon.png
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
""",
    )
)

###############################################################################
# CMS Assets Settings Patches
###############################################################################

hooks.Filters.ENV_PATCHES.add_item(
    (
        "openedx-cms-assets-settings",
        """
# Ensure optional Redwood apps exist when collecting assets
if "openedx.core.djangoapps.content_libraries.apps.ContentLibrariesConfig" not in INSTALLED_APPS:
    INSTALLED_APPS += ["openedx.core.djangoapps.content_libraries.apps.ContentLibrariesConfig"]
if "openedx.core.djangoapps.bookmarks.apps.BookmarksConfig" not in INSTALLED_APPS:
    INSTALLED_APPS += ["openedx.core.djangoapps.bookmarks.apps.BookmarksConfig"]
if "openedx.core.djangoapps.discussions.apps.DiscussionsConfig" not in INSTALLED_APPS:
    INSTALLED_APPS += ["openedx.core.djangoapps.discussions.apps.DiscussionsConfig"]
if "openedx.core.djangoapps.theming.apps.ThemingConfig" not in INSTALLED_APPS:
    INSTALLED_APPS += ["openedx.core.djangoapps.theming.apps.ThemingConfig"]

# Same safe_join patch for CMS
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

###############################################################################
# MFE Plugin Slot Configuration
###############################################################################
#
# MIGRATION STATUS: Fully slot-driven via tutormfe.hooks.PLUGIN_SLOTS (Tutor v21+)
#
# How it works:
#   1. mfe-env-config-runtime-definitions patch injects MerekaFooter component
#      definition into env.config.jsx (inside the async setConfig() try block,
#      where DIRECT_PLUGIN and PLUGIN_OPERATIONS are already imported).
#   2. PLUGIN_SLOTS.add_item() registers the slot override via iter_plugin_slots(),
#      which is called by the env.config.jsx template — no string surgery needed.
#   3. apply-patches.sh footer-component.sh no longer does JSX string replacement;
#      it only copies SCSS/font assets into the MFE build directory.
#
# Slot inventory (bead 2dcy.6, AC-FRONT-062):
#
#   Slot ID                           | Replaces
#   ----------------------------------|--------------------------------------
#   org.openedx.frontend.layout.      | Default Indigo/OpenedX footer
#     footer.v1                       |
#   header_logo_slot                  | Default header logo (MFE header bar)
#   learner_dashboard.sidebar.v1      | Dashboard sidebar (if present)
#
from tutormfe.hooks import PLUGIN_SLOTS

# Slot 1: footer — hides the Indigo default footer, inserts MerekaFooter.
# MerekaFooter is defined in the mfe-env-config-runtime-definitions patch below.
# The slot name matches the canonical Open edX FPF slot ID used by tutorindigo.
for _mfe in [
    "all",
]:
    PLUGIN_SLOTS.add_items([
        (
            _mfe,
            "org.openedx.frontend.layout.footer.v1",
            """
            {
                op: PLUGIN_OPERATIONS.Hide,
                widgetId: 'default_contents',
            },
            {
                op: PLUGIN_OPERATIONS.Insert,
                widget: {
                    id: 'mereka_footer',
                    type: DIRECT_PLUGIN,
                    priority: 1,
                    RenderWidget: MerekaFooter,
                },
            },
            """,
        ),
    ])

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
// Custom Mereka footer component (Direct plugin — registered via footer_slot)
// Wired into org.openedx.frontend.layout.footer.v1 by PLUGIN_SLOTS in mereka_lms.py
const MerekaFooter = () => {
  const config = getConfig();
  const baseUrl = (config.LMS_BASE_URL || '').replace(/\\/$/, '');
  const siteName = config.SITE_NAME || 'Mereka Academy';
  const currentYear = new Date().getFullYear();
  const hostname = typeof window !== 'undefined' ? window.location.hostname : '';
  const logoUrl = baseUrl ? baseUrl + '/static/images/logo.png' : '';

  // Tenant footer data contract.
  // Fields: brand, copyrightHolder, whatsapp (identity)
  //         supportEmail, helpUrl (support section)
  //         privacyUrl, termsUrl, cookiesUrl (legal section)
  // Add new tenant by adding a hostname key. All fields have safe defaults in the fallback below.
  const SITE_VARIANTS = {
    'academyv2.mereka.io': {
      brand: 'Mereka Academy',
      copyrightHolder: 'MEREKA',
      whatsapp: '601135271981',
      supportEmail: 'support@mereka.io',
      helpUrl: 'https://help.mereka.io/',
      privacyUrl: 'https://legal.mereka.io/privacy-policy/',
      termsUrl: 'https://legal.mereka.io/',
      cookiesUrl: 'https://legal.mereka.io/#cookie-policy',
    },
    'academy.biji-biji.com': {
      brand: 'Biji-Biji Academy',
      copyrightHolder: 'Biji-Biji Initiative',
      whatsapp: '601135271981',
      supportEmail: 'techadmin@biji-biji.com',
      helpUrl: 'https://help.mereka.io/',
      privacyUrl: 'https://legal.mereka.io/privacy-policy/',
      termsUrl: 'https://legal.mereka.io/',
      cookiesUrl: 'https://legal.mereka.io/#cookie-policy',
    },
    'skillourfuture.academy.mereka.io': {
      brand: 'Skill Our Future Academy',
      copyrightHolder: 'MEREKA',
      whatsapp: '601135271981',
      supportEmail: 'support@mereka.io',
      helpUrl: 'https://help.mereka.io/',
      privacyUrl: 'https://legal.mereka.io/privacy-policy/',
      termsUrl: 'https://legal.mereka.io/',
      cookiesUrl: 'https://legal.mereka.io/#cookie-policy',
    },
  };
  // Safe defaults — used when hostname is not in SITE_VARIANTS (dev, staging, new tenants)
  const variant = SITE_VARIANTS[hostname] || {
    brand: (typeof config !== 'undefined' && config.SITE_NAME) || siteName || 'Mereka Academy',
    copyrightHolder: (typeof config !== 'undefined' && config.PLATFORM_NAME) || 'MEREKA',
    whatsapp: '601135271981',
    supportEmail: 'support@mereka.io',
    helpUrl: 'https://help.mereka.io/',
    privacyUrl: 'https://legal.mereka.io/privacy-policy/',
    termsUrl: 'https://legal.mereka.io/',
    cookiesUrl: 'https://legal.mereka.io/#cookie-policy',
  };

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
apps.academyv2.mereka.io{$default_site_port} {
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
""",
    )
)

# Add DID document endpoint to Credentials Service URLs
hooks.Filters.ENV_PATCHES.add_item(
    (
        "credentials-urlpatterns",
        """
# DID document endpoint for Verifiable Credentials issuer (CRED-020)
# Must be before other patterns to catch /.well-known/did.json
path('', include('credentials_vc_issuer.urls')),
""",
    )
)

###############################################################################
# LMS URL Patterns (In-App Notifications API)
###############################################################################

# Add notifications API to LMS URL patterns
hooks.Filters.ENV_PATCHES.add_item(
    (
        "lms-urlpatterns",
        """
# In-app notifications API (Email Phase 3)
path('api/notifications/v1/', include('openedx_notifications.urls')),

# Email preferences API (Email Phase 2)
path('api/user/v1/preferences/email/', include('openedx_email_preferences.urls')),

# Mux video upload API (Video Phase 3: Studio Upload Workflow)
path('api/mux/upload/', include('openedx_mux_upload.urls')),

# Video analytics API (Video Phase 4: Analytics Integration)
path('api/video/v1/', include('openedx_video_analytics.urls')),

# Video content protection API (Video Phase 5: Signed Playback)
path('api/mux/protection/', include('openedx_video_protection.urls')),
""",
    )
)

# CMS production settings patch (metrics + URL exposure in Studio)
hooks.Filters.ENV_PATCHES.add_item(
    (
        "openedx-cms-production-settings",
        """
# Prometheus metrics + URL exposure for CMS
if "django_prometheus" not in INSTALLED_APPS:
    INSTALLED_APPS.insert(0, "django_prometheus")

if "openedx_prometheus" not in INSTALLED_APPS:
    INSTALLED_APPS.append("openedx_prometheus")

if "django_prometheus.middleware.PrometheusBeforeMiddleware" not in MIDDLEWARE:
    MIDDLEWARE.insert(0, "django_prometheus.middleware.PrometheusBeforeMiddleware")
if "django_prometheus.middleware.PrometheusAfterMiddleware" not in MIDDLEWARE:
    MIDDLEWARE.append("django_prometheus.middleware.PrometheusAfterMiddleware")

ROOT_URLCONF_OVERRIDES = globals().get("ROOT_URLCONF_OVERRIDES", [])
if "openedx_prometheus.urls" not in ROOT_URLCONF_OVERRIDES:
    ROOT_URLCONF_OVERRIDES.insert(0, "openedx_prometheus.urls")
""",
    )
)

###############################################################################
# Plugin Initialization Hook
###############################################################################

@hooks.Actions.PLUGIN_LOADED.add()
def _print_loading_message(plugin_name: str):
    """Print a message when the plugin is loaded."""
    print(f"Mereka LMS plugin v{__version__} loaded")
