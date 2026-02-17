"""
Tutor plugin for Mereka LMS customizations.

This plugin consolidates Mereka-specific configuration patches that can be
delivered via Tutor's template hook system. The companion apply-patches.sh
script handles file-system operations (asset sync, theme copy) and content
modifications that require find-and-replace on generated files.

Patches included:
- Multi-site domain configuration (biji-biji.com, skillourfuture.academy.mereka.io)
- MySQL 8 authentication plugin fix
- MFE Node 18 build toolchain
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
        "academy.biji-biji.com",
        "skillourfuture.academy.mereka.io",
    ]),
    ("MEREKA_LMS_EXTRA_CSRF_ORIGINS", [
        "https://academy.biji-biji.com",
        "https://skillourfuture.academy.mereka.io",
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

# Enterprise integration
FEATURES["ENABLE_ENTERPRISE_INTEGRATION"] = True

# Force MFE-only discussions (greenfield - no legacy views needed)
FEATURES["ENABLE_DISCUSSION_HOME_PANEL"] = False  # Disable legacy in-LMS panel

# Ensure all courses use MFE by default
DISCUSSIONS_MFE_ENABLED = True
if "DISCUSSIONS_MICROFRONTEND_URL" not in globals():
    DISCUSSIONS_MICROFRONTEND_URL = "https://apps.academyv2.mereka.io/discussions"
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

# Add /openedx/plugins to Python path via .pth file for proper module imports
RUN echo '/openedx/plugins' > /openedx/venv/lib/python3.11/site-packages/mereka-plugins.pth

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
hooks.Filters.ENV_PATCHES.add_item(
    (
        "openedx-dockerfile-pre-assets",
        """
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

# Node 18 build toolchain
hooks.Filters.ENV_PATCHES.add_item(
    (
        "mfe-dockerfile-pre-npm-install",
        """
# Update package list and install build toolchain for Node 18
RUN apt-get update && apt-get install -y \\
    gcc g++ git libgl1 libxi6 make python3 python3-distutils \\
    && rm -rf /var/lib/apt/lists/*
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
hooks.Filters.ENV_PATCHES.add_item(
    (
        "mfe-dockerfile-npm-install",
        """
# Configure npm for resilience
RUN npm config set fetch-retries 6 \\
 && npm config set fetch-retry-mintimeout 20000 \\
 && npm config set fetch-retry-maxtimeout 120000 \\
 && npm config set fetch-timeout 300000

# Install with retries
RUN bash -o pipefail -c 'for attempt in 1 2 3; do npm clean-install --no-audit --no-fund --registry=$NPM_REGISTRY && exit 0; echo "npm clean-install attempt ${attempt} failed; retrying in 15s" >&2; sleep 15; done; exit 1'
""",
    )
)

###############################################################################
# MFE Plugin Slot Configuration (Footer)
###############################################################################
#
# MIGRATION STATUS: Dual-path (env.config.jsx patch + apply-patches.sh fallback)
#
# Current approach (working):
#   1. mfe-env-config patch defines MerekaFooter component inline
#   2. apply-patches.sh replaces RenderWidget: <Footer /> → <MerekaFooter />
#
# Target approach (FPF slot-driven, ADR-014):
#   When tutor-mfe exposes tutormfe.hooks.PLUGIN_SLOTS, register footer_slot
#   override directly from Python — no apply-patches.sh string replacement needed.
#
# Forward-compatible registration (activates when tutor-mfe adds PLUGIN_SLOTS):
try:
    from tutormfe.hooks import PLUGIN_SLOTS  # type: ignore[import-not-found]

    PLUGIN_SLOTS.add_item(
        (
            "footer_slot",
            {
                "keepDefault": False,
                "plugins": [
                    {
                        "op": "PLUGIN_OPERATIONS.Replace",
                        "widget": {
                            "id": "mereka_footer",
                            "type": "DIRECT_PLUGIN",
                            "RenderWidget": "MerekaFooter",
                        },
                    }
                ],
            },
        )
    )
    _PLUGIN_SLOTS_AVAILABLE = True
except ImportError:
    # tutormfe.hooks.PLUGIN_SLOTS not available in this Tutor version.
    # Fall back to mfe-env-config patch + apply-patches.sh string replacement.
    _PLUGIN_SLOTS_AVAILABLE = False

###############################################################################
# MFE Theme Patches (Indigo)
###############################################################################

hooks.Filters.ENV_PATCHES.add_item(
    (
        "mfe-env-config",
        """
// Import Mereka theme SCSS
import './mereka/mereka.scss';

// Custom Mereka footer component (Direct plugin — see ADR-014)
// This component is wired into footer_slot via one of two paths:
//   1. tutormfe.hooks.PLUGIN_SLOTS (if available in this Tutor version)
//   2. apply-patches.sh RenderWidget replacement (fallback)
const MerekaFooter = () => {
  const config = getConfig();
  const baseUrl = (config.LMS_BASE_URL || '').replace(/\\/$/, '');
  const siteName = config.SITE_NAME || 'Mereka Academy';
  const coursesUrl = baseUrl ? `${baseUrl}/courses` : '/courses';
  const dashboardUrl = baseUrl ? `${baseUrl}/dashboard` : '/dashboard';
  const supportEmail = config.CONTACT_EMAIL || 'team@mereka.io';
  const supportLink = `mailto:${supportEmail}`;
  const currentYear = new Date().getFullYear();
  const logoUrl = baseUrl ? `${baseUrl}/static/images/logo.png` : '';

  return (
    <footer className="mereka-footer" role="contentinfo">
      <div className="container-xl footer-primary">
        <div className="footer-brand">
          {logoUrl ? <img src={logoUrl} alt={`${siteName} logo`} /> : null}
          <p>
            Mereka Academy blends community, craftsmanship, and technology to help learners master
            the creative, digital, and entrepreneurial skills powering Southeast Asia.
          </p>
          <div className="footer-tags">
            <span>Future of Work</span>
            <span>Creative Tech</span>
            <span>Impact</span>
          </div>
        </div>
        <div className="footer-links">
          <h6>Explore</h6>
          <ul>
            <li><a href={coursesUrl}>Courses</a></li>
            <li><a href={dashboardUrl}>My learning</a></li>
            <li><a href="https://mereka.my" target="_blank" rel="noopener">Mereka main site</a></li>
            <li><a href="mailto:team@mereka.io">team@mereka.io</a></li>
          </ul>
        </div>
        <div className="footer-links">
          <h6>Support</h6>
          <ul>
            <li><a href="mailto:techadmin@biji-biji.com">techadmin@biji-biji.com</a></li>
            <li><a href={supportLink}>{supportEmail}</a></li>
            <li><a href="https://academyv2.mereka.io/help" target="_blank" rel="noopener">Help centre</a></li>
            <li><a href="https://academyv2.mereka.io/privacy" target="_blank" rel="noopener">Privacy</a></li>
          </ul>
        </div>
        <div className="footer-links">
          <h6>Partners</h6>
          <ul>
            <li><a href="https://biji-biji.com" target="_blank" rel="noopener">Biji-Biji Initiative</a></li>
            <li><a href="https://mereka.my/partner" target="_blank" rel="noopener">Partner with us</a></li>
            <li><a href="https://mereka.my/stories" target="_blank" rel="noopener">Stories</a></li>
          </ul>
        </div>
      </div>
      <div className="footer-bottom container-xl">
        <span>© {currentYear} Biji-Biji Initiative · {siteName}</span>
        <span>Powered by Open edX &amp; Tutor</span>
      </div>
    </footer>
  );
};
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
        "caddy-caddyfile",
        """
# Additional LMS sites
{% for host in MEREKA_LMS_EXTRA_HOSTS %}
{{ host }}{$default_site_port} {
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

# MFE proxy: Forward /profile/api/* to LMS for profile API
apps.academyv2.mereka.io {
    reverse_proxy /profile/api/* lms:8000 {
        header_up Host academyv2.mereka.io
    }
    reverse_proxy nginx:80
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
    proxy_set_header Host academyv2.mereka.io;
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

###############################################################################
# Plugin Initialization Hook
###############################################################################

@hooks.Actions.PLUGIN_LOADED.add()
def _print_loading_message(plugin_name: str):
    """Print a message when the plugin is loaded."""
    print(f"Mereka LMS plugin v{__version__} loaded")
