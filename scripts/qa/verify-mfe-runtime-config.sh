#!/usr/bin/env bash
# Verify MFE runtime configuration structural contract.
#
# Checks:
#   1. env.config.jsx template (generated) exists and exports a setConfig function
#   2. Indigo env.config.jsx source exists
#   3. Runtime config API endpoint is proxied in the MFE Caddyfile
#   4. MFE Caddyfile routes exist for each known MFE
#   5. Cookie domain values are not hardcoded in the MFE Dockerfile
#      (they should come from the mfe_config runtime API)
#   6. No hardcoded production LMS URLs in MFE SCSS files
#
# Usage:
#   ./scripts/qa/verify-mfe-runtime-config.sh
#
# Exit codes:
#   0  all checks PASS (SKIPs are acceptable)
#   1  one or more checks FAIL
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

pass=0
fail=0
skip=0

_pass() { echo "PASS $*"; pass=$((pass + 1)); }
_fail() { echo "FAIL $*" >&2; fail=$((fail + 1)); }
_skip() { echo "SKIP $*"; skip=$((skip + 1)); }

# ---------------------------------------------------------------------------
# 1. Generated env.config.jsx template exists and is not empty
# ---------------------------------------------------------------------------
GENERATED_ENV_CONFIG="$REPO_ROOT/tutor_env/env/plugins/mfe/build/mfe/env.config.jsx"
if [[ ! -f "$GENERATED_ENV_CONFIG" ]]; then
  _skip "Generated env.config.jsx not found (tutor config save not run): $GENERATED_ENV_CONFIG"
else
  # Must export a setConfig function or a default config object
  if grep -qE 'export default (setConfig|config)' "$GENERATED_ENV_CONFIG"; then
    _pass "env.config.jsx exports default (setConfig or config)"
  else
    _fail "env.config.jsx does not export 'default setConfig' or 'default config': $GENERATED_ENV_CONFIG"
  fi
fi

# ---------------------------------------------------------------------------
# 2. Indigo/Mereka env.config.jsx source exists
# ---------------------------------------------------------------------------
INDIGO_ENV_CONFIG="$REPO_ROOT/tutor_env/env/plugins/mfe/build/mfe/indigo/env.config.jsx"
if [[ ! -f "$INDIGO_ENV_CONFIG" ]]; then
  _skip "Indigo env.config.jsx source not found (tutor config save not run): $INDIGO_ENV_CONFIG"
else
  _pass "Indigo env.config.jsx source exists: $INDIGO_ENV_CONFIG"
fi

# ---------------------------------------------------------------------------
# 3. mfe_config API proxy is present in MFE Caddyfile
# ---------------------------------------------------------------------------
MFE_CADDYFILE="$REPO_ROOT/deploy/k8s/base/plugins/mfe/apps/mfe/Caddyfile"
if [[ ! -f "$MFE_CADDYFILE" ]]; then
  _fail "MFE Caddyfile not found: $MFE_CADDYFILE"
else
  if grep -q 'reverse_proxy /api/mfe_config/v1' "$MFE_CADDYFILE"; then
    _pass "MFE Caddyfile proxies /api/mfe_config/v1 to LMS"
  else
    _fail "MFE Caddyfile missing reverse_proxy for /api/mfe_config/v1: $MFE_CADDYFILE"
  fi

  # login_refresh proxy is required for JWT refresh on the MFE origin
  if grep -q 'reverse_proxy /login_refresh' "$MFE_CADDYFILE"; then
    _pass "MFE Caddyfile proxies /login_refresh to LMS"
  else
    _fail "MFE Caddyfile missing reverse_proxy for /login_refresh: $MFE_CADDYFILE"
  fi

  # Host header must be forwarded for multisite SiteConfiguration resolution
  if grep -q 'header_up Host' "$MFE_CADDYFILE"; then
    _pass "MFE Caddyfile forwards Host header on mfe_config proxy"
  else
    _fail "MFE Caddyfile does not forward Host header on mfe_config proxy: $MFE_CADDYFILE"
  fi
fi

# ---------------------------------------------------------------------------
# 4. MFE Caddyfile has routes for each expected MFE
# ---------------------------------------------------------------------------
EXPECTED_MFES=(
  authn
  account
  learning
  authoring
  discussions
  gradebook
  learner-dashboard
  profile
  ora-grading
  learner-record
)

if [[ ! -f "$MFE_CADDYFILE" ]]; then
  _skip "MFE Caddyfile not found; skipping per-MFE route checks"
else
  for mfe in "${EXPECTED_MFES[@]}"; do
    if grep -q "path /${mfe}" "$MFE_CADDYFILE"; then
      _pass "MFE route exists for: ${mfe}"
    else
      _fail "MFE route missing for: ${mfe} in $MFE_CADDYFILE"
    fi
  done
fi

# ---------------------------------------------------------------------------
# 5. MFE Dockerfile does not hardcode cookie domain values
#    (these should come from the mfe_config runtime API, not build args)
# ---------------------------------------------------------------------------
MFE_DOCKERFILE="$REPO_ROOT/infrastructure/tutor/mfe-build/Dockerfile"
if [[ ! -f "$MFE_DOCKERFILE" ]]; then
  _skip "MFE Dockerfile not found: $MFE_DOCKERFILE"
else
  # SESSION_COOKIE_DOMAIN with a hardcoded default is a build-time coupling.
  # The default value .academyv2.mereka.io prevents image reuse across environments.
  if grep -qE 'SESSION_COOKIE_DOMAIN=\.' "$MFE_DOCKERFILE"; then
    _fail "MFE Dockerfile hardcodes SESSION_COOKIE_DOMAIN (phase 1 migration pending): $MFE_DOCKERFILE"
  else
    _pass "MFE Dockerfile does not hardcode SESSION_COOKIE_DOMAIN"
  fi

  if grep -qE 'CSRF_COOKIE_DOMAIN=\.' "$MFE_DOCKERFILE"; then
    _fail "MFE Dockerfile hardcodes CSRF_COOKIE_DOMAIN (phase 1 migration pending): $MFE_DOCKERFILE"
  else
    _pass "MFE Dockerfile does not hardcode CSRF_COOKIE_DOMAIN"
  fi

  # MFE_CONFIG_API_URL must be a relative path so the bundle works on any origin
  if grep -q 'MFE_CONFIG_API_URL=/api/mfe_config/v1' "$MFE_DOCKERFILE"; then
    _pass "MFE Dockerfile uses relative MFE_CONFIG_API_URL"
  else
    _fail "MFE Dockerfile MFE_CONFIG_API_URL is missing or not relative: $MFE_DOCKERFILE"
  fi
fi

# ---------------------------------------------------------------------------
# 6. No hardcoded production LMS URLs in MFE SCSS
#    SCSS variables and CSS custom properties are fine; raw https:// URLs are not.
# ---------------------------------------------------------------------------
MFE_SCSS="$REPO_ROOT/infrastructure/tutor/themes/mereka/mfe/mereka.scss"
if [[ ! -f "$MFE_SCSS" ]]; then
  _skip "Mereka MFE SCSS not found: $MFE_SCSS"
else
  # url() references in SCSS are legitimate (fonts, images). Skip those.
  # Flag any https:// that is NOT inside a url() call.
  if grep -v 'url(' "$MFE_SCSS" | grep -qE 'https?://academyv2\.mereka\.(io|dev)'; then
    _fail "Mereka MFE SCSS contains hardcoded production URLs (should use CSS variables): $MFE_SCSS"
  else
    _pass "Mereka MFE SCSS has no hardcoded production LMS URLs"
  fi
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo "Results: PASS=${pass} FAIL=${fail} SKIP=${skip}"

if [[ "$fail" -gt 0 ]]; then
  exit 1
fi
