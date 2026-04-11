"""OpenEdX Docker image patches — requirements, theme assets, webpack."""

from _mereka_lms import _register_env_patch

###############################################################################
# Open edX Dockerfile Patches
###############################################################################

# Fix editable Git URLs for uv pip compatibility
# uv pip (Rust-based SOTA tool) doesn't support editable Git URLs (-e git+https://...)
# We work around this by filtering them out and installing separately with PEP 508 format.
# This lets us use uv pip for all packages while handling the edge case properly.
_register_env_patch(
    "openedx-dockerfile-pre-python-requirements",
    """
# Extract editable Git packages from requirements for separate installation
RUN --mount=type=bind,from=edx-platform,source=/requirements/edx/base.txt,target=/tmp/base.txt \\
    grep '^-e git+https://' /tmp/base.txt | sed 's|^-e git+https://github.com/\\([^/]\\+\\)/\\([^.]*\\)\\.git@\\([^#]\\+\\)#egg=\\(.*\\)$|\\4 @ git+https://github.com/\\1/\\2.git@\\3|' > /tmp/git-packages.txt || true && \\
    grep -v '^-e git+https://' /tmp/base.txt > /tmp/base-filtered.txt
""",
)

# Override the base requirements install to use filtered requirements
_register_env_patch(
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

# Node environment variables for webpack builds
_register_env_patch(
    "openedx-dockerfile-pre-assets",
    """
# Increase Node memory limit for webpack builds
ENV NODE_OPTIONS="--max-old-space-size=6144"
ENV PYTHONPATH="/openedx/edx-platform"
""",
)

# NPM install command override for lockfile drift tolerance
# NOTE: Using 'npm install' instead of 'npm ci' to handle Open edX upstream
# lockfile drift gracefully while still respecting the lockfile when possible.
_register_env_patch(
    "openedx-dockerfile-npm-install-cmd",
    """npm install --no-audit --registry=$NPM_REGISTRY""",
)

# Install custom apps and dependencies
# IMPORTANT: Every app referenced via INSTALLED_APPS in LMS/CMS settings MUST
# appear here. Run scripts/qa/verify-custom-app-drift.sh to detect mismatches.
#
# Cache policy:
# - Stable apps build first so infrequent changes stay maximally reusable.
# - High-churn apps build last so UI/tenant iteration does not invalidate the
#   whole custom-app layer stack behind them.
_STABLE_CUSTOM_APPS = [
    "credentials_vc_issuer",
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
    "openedx_timed_exams",
    "openedx_video_analytics",
    "openedx_video_pipeline",
    "openedx_video_protection",
    "openedx_xqueue_graders",
]

_HIGH_CHURN_CUSTOM_APPS = [
    "mfe_oauth_fix",
    "openedx_tenant_cache",
]

_CUSTOM_APPS = [*_STABLE_CUSTOM_APPS, *_HIGH_CHURN_CUSTOM_APPS]


def _render_copy_lines(apps: list[str]) -> str:
    return "\n".join(
        f"COPY --chown=app:app ./infrastructure/tutor/custom-apps/{app} /openedx/{app}"
        for app in apps
    )


def _render_install_lines(apps: list[str]) -> str:
    return "\n".join(f"RUN pip install -e /openedx/{app}" for app in apps)


def _render_runtime_copy_lines(apps: list[str]) -> str:
    return "\n".join(
        f"COPY --from=python-requirements --chown=app:app /openedx/{app} /openedx/{app}"
        for app in apps
    )


_stable_copy_lines = _render_copy_lines(_STABLE_CUSTOM_APPS)
_stable_install_lines = _render_install_lines(_STABLE_CUSTOM_APPS)
_high_churn_copy_lines = _render_copy_lines(_HIGH_CHURN_CUSTOM_APPS)
_high_churn_install_lines = _render_install_lines(_HIGH_CHURN_CUSTOM_APPS)
_runtime_copy_lines = _render_runtime_copy_lines(_CUSTOM_APPS)

_register_env_patch(
    "openedx-dockerfile-post-python-requirements",
    f"""
# Copy and install stable custom apps first for cache reuse.
{_stable_copy_lines}
{_stable_install_lines}
# Add repository roots to Python path via .pth file for proper module imports.
# Include /openedx because custom app packages are mounted there and should be importable
# as top-level Django apps across CMS/LMS and worker processes.
RUN python3 -c "import sysconfig; open(sysconfig.get_path('purelib') + '/mereka-plugins.pth', 'w').write('/openedx\\n/openedx/plugins\\n')"

# Install django-prometheus for metrics
RUN pip install django-prometheus==2.3.1

# Install django-ratelimit for email preferences rate limiting
RUN pip install django-ratelimit==4.1.0

# Install pymongo SRV extras for MongoDB Atlas
RUN pip install "pymongo[srv]"

# Aspects analytics: xAPI event routing + ClickHouse event sinks
# Latest published releases as of 2026-04-11:
# - edx-event-routing-backends 10.0.0 requires Python >=3.12
# - platform-plugin-aspects 1.1.3 requires Python >=3.12
# Keep the image on the newest Python 3.11-compatible pins.
RUN $PIP_COMMAND install "edx-event-routing-backends==9.3.8"
RUN $PIP_COMMAND install "platform-plugin-aspects==1.1.2"

# Copy and install high-churn custom apps last to reduce invalidation blast radius.
{_high_churn_copy_lines}
{_high_churn_install_lines}

# Copy and install mereka_tenancy multi-tenancy plugin after support deps so
# tenant/runtime iteration invalidates the smallest possible tail.
# NOTE: Installed to /openedx/plugins/ instead of /openedx/ to enable proper namespacing
COPY --chown=app:app ./infrastructure/tutor/plugins/multi-tenancy /openedx/plugins/mereka_tenancy
RUN $PIP_COMMAND install -e /openedx/plugins/mereka_tenancy
""",
)

_register_env_patch(
    "openedx-dockerfile-final",
    f"""
# Carry editable-install source trees into the final runtime image.
# The venv already contains .egg-link/.pth metadata pointing at these paths.
# Without these COPYs, the runtime image keeps editable-install metadata but
# drops the source directories those imports resolve against.
{_runtime_copy_lines}
COPY --from=python-requirements --chown=app:app /openedx/plugins/mereka_tenancy /openedx/plugins/mereka_tenancy
""",
)

# Custom theme SASS compilation (strip Google Fonts imports)
# NOTE: The Tutor template COPYs ./themes/ AFTER pre-assets hooks and BEFORE collectstatic.
# But compile-sass needs the theme present. So we COPY the theme early here.
# The later COPY ./themes/ will overwrite with the same files — safe and idempotent.
_register_env_patch(
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

# Webpack optimization (disable parallel for stability, remove compat config)
_register_env_patch(
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
