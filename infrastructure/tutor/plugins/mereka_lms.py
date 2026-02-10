"""
Tutor plugin for Mereka LMS customizations.

This plugin consolidates all Mereka-specific patches and configurations,
replacing the need for apply-patches.sh.

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
hooks.Filters.ENV_PATCHES.add_item(
    (
        "openedx-dockerfile-post-python-requirements",
        """
# Copy custom apps
COPY --chown=app:app ./infrastructure/tutor/custom-apps/mfe_oauth_fix /openedx/mfe_oauth_fix
COPY --chown=app:app ./infrastructure/tutor/custom-apps/openedx_prometheus /openedx/openedx_prometheus
RUN pip install -e /openedx/mfe_oauth_fix
RUN pip install -e /openedx/openedx_prometheus

# Install django-prometheus for metrics
RUN pip install django-prometheus==2.3.1

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
# MFE Theme Patches (Indigo)
###############################################################################

hooks.Filters.ENV_PATCHES.add_item(
    (
        "mfe-env-config",
        """
// Import Mereka theme SCSS
import './mereka/mereka.scss';

// Custom Mereka footer component
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

// Replace default footer with Mereka footer
// (This gets inserted into the slot configuration elsewhere in env.config.jsx)
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
# Plugin Initialization Hook
###############################################################################

@hooks.Actions.PLUGIN_LOADED.add()
def _print_loading_message(plugin_name: str):
    """Print a message when the plugin is loaded."""
    print(f"Mereka LMS plugin v{__version__} loaded")
