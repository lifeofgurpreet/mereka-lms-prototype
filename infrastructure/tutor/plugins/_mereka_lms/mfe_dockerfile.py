"""MFE Docker image patches — build toolchain, branding, plugin framework."""

from _mereka_lms import _register_env_patch

###############################################################################
# MFE Dockerfile Patches
###############################################################################

# Node 24 build toolchain + git HTTPS override
_register_env_patch(
    "mfe-dockerfile-pre-npm-install",
    """
# Update package list and install build toolchain for Node 24
RUN printf 'Acquire::Retries "6";\\nAcquire::http::Timeout "30";\\nAcquire::https::Timeout "30";\\nAcquire::ForceIPv4 "true";\\n' > /etc/apt/apt.conf.d/80-retries \\
 && apt-get update \\
 && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends --fix-missing \\
    gcc g++ git libgl1 libxi6 make python3 python3-distutils \\
    && rm -rf /var/lib/apt/lists/*
# Force git to use HTTPS instead of SSH for github.com — Docker builds
# have no SSH keys, so github: protocol (which resolves to SSH) fails.
# This affects tutor-indigo's @edx/brand install from edly-io/brand-openedx.
RUN git config --global --add url."https://github.com/".insteadOf "ssh://git@github.com/" \\
    && git config --global --add url."https://github.com/".insteadOf "git@github.com:"
""",
)

# Stage the local OEP-48 brand package for MFEs.
# We ship the package in tutor_env/plugins/mfe/build/mfe/indigo/brand-mereka and
# overlay it onto node_modules/@edx/brand after npm has finished mutating deps.
#
# IMPORTANT: This MUST be post-npm-install, not pre-npm-install.
# Pre-npm-install fires BEFORE the main `npm clean-install` layer. Since
# brand-mereka changes on every branding PR, placing it before npm install
# invalidates the entire dependency install cache for ALL MFE apps (~10 apps
# × 3-5 min each = 30-50 min wasted). By moving it to post-npm-install,
# the main dependency layer stays cached and only the brand overlay + webpack
# rebuild are invalidated. We avoid a second local `npm install` here because
# Arborist can hang indefinitely while reifying the file: package inside the
# heavy-builder DinD environment.
_register_env_patch(
    "mfe-dockerfile-post-npm-install",
    """
COPY indigo/brand-mereka /openedx/app/brand-mereka
""",
)

# Copy Mereka SCSS theme into the MFE container so that
# `import './mereka/mereka.scss'` in env.config.jsx resolves.
# The mereka/ directory is populated by footer-component.sh during apply-patches.
_register_env_patch(
    "mfe-dockerfile-post-npm-install",
    """
COPY indigo/mereka /openedx/app/mereka
""",
)

# Copy generated runtime theme assets into the MFE container.
# PARAGON_THEME_URLS points to /theme/* on the MFE origin.
#
# NOTE: The post-npm-install hook fires inside each per-MFE "common" stage.
# Those stages copy /openedx/dist/theme into their own filesystem, but the
# FINAL production stage (FROM caddy:2.7.4 AS production) only copies
# /openedx/app/dist from each <mfe>-prod stage via `COPY --from=<mfe>-prod`,
# which does NOT include /openedx/dist/theme. That's why the built MFE image
# has every per-MFE dir under /openedx/dist/ EXCEPT theme/.
#
# Fix: inject the same COPY into the production stage via the
# `mfe-dockerfile-production-final` hook that the base tutor-mfe template
# invokes at the end of the production stage. This guarantees the theme
# files land in /openedx/dist/theme/ in the final image regardless of what
# the per-MFE common stages do.
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

# Overlay the staged local brand package onto the already-installed
# stock @edx/brand dependency after npm mutations finish.
_register_env_patch(
    "mfe-dockerfile-post-npm-install",
    """
RUN rm -rf /openedx/app/node_modules/@edx/brand \\
 && mkdir -p /openedx/app/node_modules/@edx/brand \\
 && cp -R /openedx/app/brand-mereka/. /openedx/app/node_modules/@edx/brand/ \\
 && python3 - <<'PY'
from pathlib import Path
import json

pkg_path = Path("/openedx/app/node_modules/@edx/brand/package.json")
pkg = json.loads(pkg_path.read_text(encoding="utf-8"))
pkg["name"] = "@edx/brand"
pkg_path.write_text(json.dumps(pkg, indent=2) + "\\n", encoding="utf-8")
PY
""",
)

# Patch the account MFE source BEFORE webpack builds.
# The upstream open-release/redwood.3 source has a null-unsafe lookup:
#   data.social_links.find(...)
# which crashes when social_links is null/undefined. Apply the defensive
# check to the source BEFORE npm run build. The hook fires in account-common
# after COPY --from=account-src but before the account-prod stage builds,
# so the source change is compiled in.
_register_env_patch(
    "mfe-dockerfile-pre-npm-build-account",
    """
RUN python3 - <<'PY'
from pathlib import Path

service_path = Path("/openedx/app/src/account-settings/data/service.js")
if not service_path.exists():
    raise SystemExit(0)

original = "const platformData = data.social_links.find(({ platform }) => platform === id);"
patched = (
    "const socialLinks = Array.isArray(data.social_links) ? data.social_links : [];\\n"
    "      const platformData = socialLinks.find(({ platform }) => platform === id);"
)

content = service_path.read_text(encoding="utf-8")
if patched in content:
    raise SystemExit(0)  # already patched — idempotent
if original not in content:
    raise SystemExit("account social_links patch anchor missing — upstream may have changed")

updated = content.replace(original, patched)
service_path.write_text(updated, encoding="utf-8")
print("account social_links null-safety patch applied")
PY
""",
)

# Fail the account build if a stale compiled bundle or source map still contains the
# unguarded social_links lookup after webpack finishes.
# v2: check fix presence in SOURCE (pre-minification) not in compiled dist where
# webpack renames variables and the exact string is never found.
# The pre-npm-build-account hook above applies the patch, so source will have the fix.
_register_env_patch(
    "mfe-dockerfile-post-npm-build",
    """
RUN python3 - <<'PY'
from pathlib import Path

guard_revision = "account-social-links-guard-2026-04-04-cacheproof-v2"
source_path = Path("/openedx/app/src/account-settings/data/service.js")
if not source_path.exists():
    raise SystemExit(0)

# 1. Confirm the fix is present in the SOURCE file before minification renames variables.
required_in_source = "const socialLinks = Array.isArray(data.social_links) ? data.social_links : [];"
source_content = source_path.read_text(encoding="utf-8")
if required_in_source not in source_content:
    raise SystemExit(
        f"{guard_revision}: guarded social_links fix missing from {source_path} — patch not applied"
    )

# 2. Confirm the OLD buggy pattern is absent from compiled assets and source maps.
#    The original string is long enough to survive in .map files if the old code was compiled in.
dist_dir = Path("/openedx/app/dist")
if not dist_dir.exists():
    raise SystemExit(f"{guard_revision}: frontend-app-account dist missing after build")

forbidden = "const platformData = data.social_links.find(({ platform }) => platform === id);"
offenders = []

for asset in sorted(dist_dir.rglob("*")):
    if asset.suffix not in {".js", ".map"}:
        continue
    try:
        content = asset.read_text(encoding="utf-8")
    except UnicodeDecodeError:
        continue
    if forbidden in content:
        offenders.append(str(asset))

if offenders:
    raise SystemExit(
        f"{guard_revision}: unguarded social_links lookup survived account build in {', '.join(offenders)}"
    )
PY
""",
)

# NPM install resilience (retry on failure)
# NOTE: Prefer `npm clean-install` when the lockfile is usable, but fall back to
# `npm install` if upstream lockfile drift breaks the strict path. This matches
# the rendered MFE build authority and keeps lockfile tolerance explicit.
_register_env_patch(
    "mfe-dockerfile-npm-install",
    """
# Configure npm for resilience
RUN npm config set fetch-retries 6 \\
 && npm config set fetch-retry-mintimeout 20000 \\
 && npm config set fetch-retry-maxtimeout 120000 \\
 && npm config set fetch-timeout 300000

# Install with retries (clean-install first, npm install fallback for lockfile drift)
RUN bash -o pipefail -c 'for attempt in 1 2 3; do npm clean-install --no-audit --no-fund --registry=$NPM_REGISTRY && exit 0; echo "npm clean-install attempt ${attempt} failed; attempting npm install fallback" >&2; npm install --no-audit --no-fund --registry=$NPM_REGISTRY && exit 0; echo "npm clean-install attempt ${attempt} failed; retrying in 15s" >&2; sleep 15; done; exit 1'
""",
)

# Admin console requires react-redux and redux (not bundled by default)
_register_env_patch(
    "mfe-dockerfile-post-npm-install-admin-console",
    """
RUN npm install --legacy-peer-deps 'react-redux@^8.1.3' 'redux@^4.2.1' \\
 && rm -rf /openedx/app/node_modules/@edx/brand \\
 && mkdir -p /openedx/app/node_modules/@edx/brand \\
 && cp -R /openedx/app/brand-mereka/. /openedx/app/node_modules/@edx/brand/ \\
 && python3 - <<'PY'
from pathlib import Path
import json

pkg_path = Path("/openedx/app/node_modules/@edx/brand/package.json")
pkg = json.loads(pkg_path.read_text(encoding="utf-8"))
pkg["name"] = "@edx/brand"
pkg_path.write_text(json.dumps(pkg, indent=2) + "\\n", encoding="utf-8")
PY
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

# Fix moment.js "Invalid time value" crash in Course Authoring MFE (#1385).
# StatusBar.tsx passes endDate (which may be null/empty) directly to moment.utc(),
# causing a crash when courses have no end date set. Guard with null check.
_register_env_patch(
    "mfe-dockerfile-post-npm-install",
    """
# Fix #1385: guard null endDate in StatusBar to prevent moment.js crash
RUN find /openedx/app -path '*/course-outline/status-bar/StatusBar.tsx' \
    -exec sed -i 's/const endDateObj = moment\\.utc(endDate);/const endDateObj = endDate ? moment.utc(endDate) : moment.invalid();/' {} + \
    || true
""",
)
