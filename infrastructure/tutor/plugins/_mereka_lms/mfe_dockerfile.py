"""MFE Docker image patches — build toolchain, branding, plugin framework."""

from _mereka_lms import _register_env_patch

###############################################################################
# MFE Dockerfile Patches
###############################################################################

# Node 24 build toolchain
_register_env_patch(
    "mfe-dockerfile-pre-npm-install",
    """
# Update package list and install build toolchain for Node 24
RUN apt-get update && apt-get install -y \\
    gcc g++ git libgl1 libxi6 make python3 python3-distutils \\
    && rm -rf /var/lib/apt/lists/*
""",
)

# Install local OEP-48 brand package for MFEs.
# We ship the package in tutor_env/plugins/mfe/build/mfe/indigo/brand-mereka and
# alias it as @edx/brand for all frontend app builds.
_register_env_patch(
    "mfe-dockerfile-pre-npm-install",
    """
COPY indigo/brand-mereka /openedx/app/brand-mereka
RUN npm install --legacy-peer-deps @edx/brand@file:./brand-mereka
""",
)

# Copy generated runtime theme assets into the MFE container.
# PARAGON_THEME_URLS points to /theme/* on the MFE origin.
_register_env_patch(
    "mfe-dockerfile-post-npm-install",
    """
COPY indigo/theme /openedx/dist/theme
""",
)

# Cookie domain environment variables
_register_env_patch(
    "mfe-dockerfile-post-npm-install",
    """
# Set cookie domains for MFE builds
ARG SESSION_COOKIE_DOMAIN={{ MEREKA_SESSION_COOKIE_DOMAIN }}
ARG CSRF_COOKIE_DOMAIN={{ MEREKA_CSRF_COOKIE_DOMAIN }}
ENV SESSION_COOKIE_DOMAIN=${SESSION_COOKIE_DOMAIN}
ENV CSRF_COOKIE_DOMAIN=${CSRF_COOKIE_DOMAIN}
""",
)

# Install frontend-plugin-framework with legacy peer deps
_register_env_patch(
    "mfe-dockerfile-post-npm-install",
    """
# Install frontend-plugin-framework with legacy peer deps
RUN npm install --legacy-peer-deps '@openedx/frontend-plugin-framework@^1.8.0'
""",
)

# NPM install resilience (retry on failure)
# NOTE: Using 'npm install' instead of 'npm ci' to handle lockfile drift gracefully
# while still respecting the lockfile when possible. This is the SOTA approach for
# environments where upstream package-lock.json may have minor version drift.
_register_env_patch(
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

# Admin console requires react-redux and redux (not bundled by default)
_register_env_patch(
    "mfe-dockerfile-post-npm-install-admin-console",
    """
RUN npm install --legacy-peer-deps 'react-redux@^8.1.3' 'redux@^4.2.1'
""",
)

# Course authoring: webpack expects 'course-authoring' directory name,
# but the repo clones as 'frontend-app-course-authoring'
_register_env_patch(
    "mfe-dockerfile-post-npm-install-course-authoring",
    """
RUN ln -sf /openedx/app/frontend-app-course-authoring /openedx/app/course-authoring || true
""",
)

# Enforce runtime Paragon theme URLs in built MFE shells.
# We write ../theme/* (not /theme/*) because Ulmo joins fileName against the MFE
# app base path (e.g. /authn/), and a leading slash can become /authn//theme/*.
# The relative hop resolves consistently to /theme/* at runtime.
_register_env_patch(
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
