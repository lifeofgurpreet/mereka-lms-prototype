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
#
# IMPORTANT: This MUST be post-npm-install, not pre-npm-install.
# Pre-npm-install fires BEFORE the main `npm clean-install` layer. Since
# brand-mereka changes on every branding PR, placing it before npm install
# invalidates the entire dependency install cache for ALL MFE apps (~10 apps
# × 3-5 min each = 30-50 min wasted). By moving it to post-npm-install,
# the main dependency layer stays cached and only the brand overlay + webpack
# rebuild are invalidated.
_register_env_patch(
    "mfe-dockerfile-post-npm-install",
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

# Fail the account build if a stale compiled bundle or source map still contains the
# unguarded social_links lookup after webpack finishes.
_register_env_patch(
    "mfe-dockerfile-post-npm-build",
    """
RUN python3 - <<'PY'
from pathlib import Path

guard_revision = "account-social-links-guard-2026-04-04-cacheproof-v1"
source_path = Path("/openedx/app/src/account-settings/data/service.js")
if not source_path.exists():
    raise SystemExit(0)

dist_dir = Path("/openedx/app/dist")
if not dist_dir.exists():
    raise SystemExit(f"{guard_revision}: frontend-app-account dist missing after build")

forbidden = "const platformData = data.social_links.find(({ platform }) => platform === id);"
required = "const socialLinks = Array.isArray(data.social_links) ? data.social_links : [];"
offenders = []
required_found = False

for asset in sorted(dist_dir.rglob("*")):
    if asset.suffix not in {".js", ".map"}:
        continue
    try:
        content = asset.read_text(encoding="utf-8")
    except UnicodeDecodeError:
        continue
    if forbidden in content:
        offenders.append(str(asset))
    if required in content:
        required_found = True

if offenders:
    raise SystemExit(
        f"{guard_revision}: unguarded social_links lookup survived account build in {', '.join(offenders)}"
    )
if not required_found:
    raise SystemExit(f"{guard_revision}: guarded social_links source missing from compiled account assets")
PY
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

variant_theme_map = {
    "academy.biji-biji.com": {
        "core": "../theme/biji-biji-brand.min.css",
        "light": "../theme/biji-biji-brand-light.min.css",
    },
    "biji-biji.academyv2.mereka.dev": {
        "core": "../theme/biji-biji-brand.min.css",
        "light": "../theme/biji-biji-brand-light.min.css",
    },
    "skillourfuture.academy.mereka.io": {
        "core": "../theme/sof-brand.min.css",
        "light": "../theme/sof-brand-light.min.css",
    },
    "skillourfuture.academyv2.mereka.io": {
        "core": "../theme/sof-brand.min.css",
        "light": "../theme/sof-brand-light.min.css",
    },
    "skillourfuture.academyv2.mereka.dev": {
        "core": "../theme/sof-brand.min.css",
        "light": "../theme/sof-brand-light.min.css",
    },
}

runtime_theme = '''(() => {
  const theme = __THEME_JSON__;
  const normalizeHostname = (value) => (typeof value === "string" ? value.toLowerCase() : "").replace(/^www\\./, "");
  const deriveVariantCandidates = (hostname) => {
    const normalizedHostname = normalizeHostname(hostname);
    if (!normalizedHostname) {
      return [];
    }
    const candidates = [];
    const queue = [normalizedHostname];
    const enqueue = (candidate) => {
      if (candidate && !candidates.includes(candidate)) {
        candidates.push(candidate);
        queue.push(candidate);
      }
    };
    while (queue.length > 0) {
      const candidate = queue.shift();
      if (!candidate) {
        continue;
      }
      enqueue(candidate.replace(/^(?:staging\\.)?apps\\./, ""));
      enqueue(candidate.replace(/^apps\\./, ""));
      enqueue(candidate.replace(/^staging\\./, ""));
      enqueue(candidate.replace(/\\.mereka\\.dev$/, ".mereka.io"));
    }
    return candidates;
  };
  const hostname = typeof window !== "undefined" && window.location ? normalizeHostname(window.location.hostname) : "";
  const variantThemeMap = __VARIANT_THEME_MAP__;
  const candidates = deriveVariantCandidates(hostname);
  const selected = candidates.map((candidate) => variantThemeMap[candidate]).find(Boolean);
  if (selected) {
    theme.brand.themeUrls.core.fileName = selected.core;
    theme.brand.themeUrls.variants.light.fileName = selected.light;
  }
  return theme;
})()'''
runtime_theme = runtime_theme.replace("__THEME_JSON__", json.dumps(theme, separators=(", ", ": ")))
runtime_theme = runtime_theme.replace("__VARIANT_THEME_MAP__", json.dumps(variant_theme_map, separators=(", ", ": ")))

updated = content[:match.start(1)] + runtime_theme + content[match.end(1):]
index_path.write_text(updated, encoding="utf-8")
PY
""",
)
