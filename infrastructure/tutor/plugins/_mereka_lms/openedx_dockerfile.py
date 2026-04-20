"""OpenEdX Docker image patches — requirements, theme assets, webpack."""

from _mereka_lms import _register_env_patch

###############################################################################
# Open edX Dockerfile Patches
###############################################################################

# Fix editable Git URLs for uv pip compatibility.
# Tutor 21's installed Open edX Dockerfile template already owns the filtered
# base-requirements block; there is no live pre-python hook point for that seam.
# The generator-level normalization to `$PIP_COMMAND --no-build-isolation` is
# therefore enforced in `patches/build-optimizations.sh`.
# This source module keeps the canonical filtered-requirements contract so the
# intended uv behavior remains explicit in repo truth.
_register_env_patch(
    "openedx-dockerfile-pre-python-requirements",
    """
# Extract editable Git packages from requirements for separate installation
RUN --mount=type=bind,from=edx-platform,source=/requirements/edx/base.txt,target=/tmp/base.txt \\
    grep '^-e git+https://' /tmp/base.txt | sed 's|^-e git+https://github.com/\\([^/]\\+\\)/\\([^.]*\\)\\.git@\\([^#]\\+\\)#egg=\\(.*\\)$|\\4 @ git+https://github.com/\\1/\\2.git@\\3|' > /tmp/git-packages.txt || true && \\
    grep -v '^-e git+https://' /tmp/base.txt > /tmp/base-filtered.txt
""",
)

# Canonical filtered requirements contract for the Tutor template-owned base
# requirements step. See build-optimizations.sh for the live render owner.
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


def _render_install_block(apps: list[str], *, editable_when_requested: bool) -> str:
    editable_args = " \\\n        ".join(f"-e /openedx/{app}" for app in apps)
    noneditable_args = " \\\n        ".join(f"/openedx/{app}" for app in apps)
    if not editable_when_requested:
        return "RUN $PIP_COMMAND install \\\n" f"        {noneditable_args}"
    return (
        'RUN if [ "$MEREKA_CUSTOM_APP_INSTALL_MODE" = "editable" ]; then \\\n'
        "      $PIP_COMMAND install \\\n"
        f"        {editable_args}; \\\n"
        "    else \\\n"
        "      $PIP_COMMAND install \\\n"
        f"        {noneditable_args}; \\\n"
        "    fi"
    )


def _render_runtime_copy_lines(apps: list[str]) -> str:
    return "\n      ".join(
        f"cp -a /tmp/python-requirements-openedx/{app} /openedx/{app} && \\" for app in apps
    )


_stable_copy_lines = _render_copy_lines(_STABLE_CUSTOM_APPS)
_stable_install_block = _render_install_block(
    _STABLE_CUSTOM_APPS,
    editable_when_requested=False,
)
_high_churn_copy_lines = _render_copy_lines(_HIGH_CHURN_CUSTOM_APPS)
_high_churn_install_block = _render_install_block(
    _HIGH_CHURN_CUSTOM_APPS,
    editable_when_requested=True,
)
_runtime_copy_lines = _render_runtime_copy_lines(_HIGH_CHURN_CUSTOM_APPS)

_register_env_patch(
    "openedx-dockerfile-post-python-requirements",
    f"""
ARG MEREKA_BUILD_PROFILE=proof
ARG MEREKA_CUSTOM_APP_INSTALL_MODE=editable

# Install support dependencies needed for metrics, translation settings, Atlas,
# enterprise, and Python 3.11-compatible Aspects in one resolver invocation.
# Keep this above all custom-app COPY layers so app iteration does not invalidate it.
RUN $PIP_COMMAND install     django-prometheus==2.3.1     django-ratelimit==4.1.0     django-cors-headers==4.3.1     "path==16.16.0"     "pymongo[srv]"     "defusedxml==0.7.1"     "edx-enterprise==6.6.9"     "lazy==1.6"     "lxml_html_clean==0.4.4"     "edx-event-routing-backends==9.3.8"     "platform-plugin-aspects==1.1.2"     "python-json-logger==2.0.7"

# Add repository roots to Python path via .pth file for proper module imports.
# Include /openedx because custom app packages are mounted there and should be importable
# as top-level Django apps across CMS/LMS and worker processes.
RUN PTH_DIR=$(python3 -c 'import sysconfig; print(sysconfig.get_path("purelib"))') && \
    printf '/openedx\\n/openedx/plugins\\n' > "$PTH_DIR/mereka-plugins.pth"

# Copy and install stable custom apps after the support dependency layer so
# stable-app iteration only invalidates the grouped install tail. Even in fast
# builds, keep these non-editable so the runtime image does not carry source
# trees for low-churn packages.
{_stable_copy_lines}
{_stable_install_block}

# Copy and install high-churn custom apps last to reduce invalidation blast radius.
{_high_churn_copy_lines}
{_high_churn_install_block}

# Copy and install mereka_tenancy multi-tenancy plugin after support deps so
# tenant/runtime iteration invalidates the smallest possible tail.
# NOTE: Installed to /openedx/plugins/ instead of /openedx/ to enable proper namespacing
COPY --chown=app:app ./infrastructure/tutor/plugins/multi-tenancy /openedx/plugins/mereka_tenancy
RUN if [ "$MEREKA_CUSTOM_APP_INSTALL_MODE" = "editable" ]; then \\
      $PIP_COMMAND install -e /openedx/plugins/mereka_tenancy; \\
    else \\
      $PIP_COMMAND install /openedx/plugins/mereka_tenancy; \\
    fi
""",
)

_register_env_patch(
    "openedx-dockerfile-final",
    f"""
ARG MEREKA_CUSTOM_APP_INSTALL_MODE=editable

# Fast builds keep only the high-churn app sources plus the tenant plugin in
# the final runtime image. Stable apps stay non-editable even in fast builds so
# the runtime image does not cargo-ship their source trees. Proof and producer
# builds install everything non-editably in python-requirements and therefore
# skip this runtime source carry entirely.
RUN --mount=type=bind,from=python-requirements,source=/openedx,target=/tmp/python-requirements-openedx,ro \\
    if [ "$MEREKA_CUSTOM_APP_INSTALL_MODE" = "editable" ]; then \\
      mkdir -p /openedx/plugins && \\
      {_runtime_copy_lines}
      cp -a /tmp/python-requirements-openedx/plugins/mereka_tenancy /openedx/plugins/mereka_tenancy; \\
    else \\
      echo "Skipping final runtime custom-app source carry (noneditable mode)"; \\
    fi
""",
)

# Pre-assets normalization for webpack and custom theme SASS compilation
# NOTE: The Tutor template COPYs ./themes/ AFTER pre-assets hooks and BEFORE collectstatic.
# But compile-sass needs the theme present. So we COPY the theme early here.
# The later COPY ./themes/ will overwrite with the same files — safe and idempotent.
_register_env_patch(
    "openedx-dockerfile-pre-assets",
    """
# Increase Node memory limit for webpack builds
ENV NODE_OPTIONS="--max-old-space-size=6144"
ENV PYTHONPATH="/openedx/edx-platform"

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
