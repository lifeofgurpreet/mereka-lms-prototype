#!/usr/bin/env bash
# verify-mfe-customizations.sh
#
# Checks that the MFE-related patches from apply-patches.sh are present
# in the upstream tutormfe package template and (if tutor_env/ exists)
# in the generated Dockerfile.
#
# Usage:
#   ./scripts/qa/verify-mfe-customizations.sh
#
# Exit codes:
#   0 — all checks passed
#   1 — one or more checks failed

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
APPLY_PATCHES="$REPO_ROOT/infrastructure/tutor/apply-patches.sh"
TUTOR_ENV="$REPO_ROOT/tutor_env/env/plugins/mfe/build/mfe/Dockerfile"

PASS=0
FAIL=0
WARNINGS=()

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

check_pass() {
  echo "  [PASS] $1"
  PASS=$(( PASS + 1 ))
}

check_fail() {
  echo "  [FAIL] $1"
  FAIL=$(( FAIL + 1 ))
}

check_warn() {
  echo "  [WARN] $1"
  WARNINGS+=("$1")
}

section() {
  echo ""
  echo "=== $1 ==="
}

# ---------------------------------------------------------------------------
# 1. Check apply-patches.sh has MFE-related patch sections
# ---------------------------------------------------------------------------

section "apply-patches.sh MFE patch sections"

if [[ ! -f "$APPLY_PATCHES" ]]; then
  check_fail "apply-patches.sh not found at $APPLY_PATCHES"
else
  # Use fixed-string matching (grep -F) to avoid ERE special-character issues
  # with strings like g++, --max-old-space-size, etc.
  declare -A PATCH_SIGNATURES=(
    ["Node 18 toolchain lock"]="FROM docker.io/node:18-bullseye-slim"
    ["g++ python3 toolchain extension"]="gcc g++ git libgl1 libxi6 make python3 python3-distutils"
    ["NODE_OPTIONS webpack memory limit"]="max-old-space-size=6144"
    ["Mereka theme copy (indigo/mereka)"]="COPY indigo/mereka /openedx/app/mereka"
    ["NPM resilience retry loop"]="npm clean-install attempt"
    ["Cookie domain ENV injection"]="SESSION_COOKIE_DOMAIN"
    ["Frontend plugin framework install"]="frontend-plugin-framework"
    ["Indigo brand ulmo pin (2.4.3)"]="indigo-brand-openedx@^2.4.3"
    ["Admin console Redux deps"]="ensure_mfe_admin_console_redux_deps"
    ["Course-authoring symlink fix"]="ensure_mfe_course_authoring_directory_fix"
    ["Discussions webpack non-interactive"]="ensure_mfe_discussions_webpack_noninteractive"
  )

  for label in "${!PATCH_SIGNATURES[@]}"; do
    pattern="${PATCH_SIGNATURES[$label]}"
    if grep -qF "$pattern" "$APPLY_PATCHES" 2>/dev/null; then
      check_pass "$label"
    else
      check_fail "$label — pattern not found: $pattern"
    fi
  done
fi

# ---------------------------------------------------------------------------
# 2. List all MFE-related function names from apply-patches.sh
# ---------------------------------------------------------------------------

section "MFE patch function inventory (apply-patches.sh)"

if [[ -f "$APPLY_PATCHES" ]]; then
  echo "  Detected MFE-related functions:"
  grep -E "^[[:space:]]*def ensure_mfe_" "$APPLY_PATCHES" \
    | sed 's/[[:space:]]*def //; s/(.*$//' \
    | while read -r fn; do
        echo "    - $fn"
      done
fi

# ---------------------------------------------------------------------------
# 3. Scan tutor_env/ for MFE modifications (if it exists)
# ---------------------------------------------------------------------------

section "tutor_env/ MFE Dockerfile (if generated)"

if [[ ! -f "$TUTOR_ENV" ]]; then
  check_warn "tutor_env Dockerfile not found — tutor config save has not been run yet"
  check_warn "Expected: $TUTOR_ENV"
else
  echo "  Found: $TUTOR_ENV"

  # Check NODE_OPTIONS is set
  if grep -q 'NODE_OPTIONS=.*max-old-space-size=6144' "$TUTOR_ENV" 2>/dev/null; then
    check_pass "NODE_OPTIONS=--max-old-space-size=6144 present in MFE Dockerfile"
  else
    check_fail "NODE_OPTIONS not raised to 6144 in MFE Dockerfile — apply-patches.sh may not have run"
  fi

  # Check Node 18 base image
  if grep -q 'FROM docker.io/node:18-bullseye-slim' "$TUTOR_ENV" 2>/dev/null; then
    check_pass "Node 18 base image pinned in MFE Dockerfile"
  else
    NODE_LINE=$(grep '^FROM.*node:' "$TUTOR_ENV" 2>/dev/null | head -1 || true)
    if [[ -n "$NODE_LINE" ]]; then
      check_fail "Node image is not pinned to node:18-bullseye-slim — found: $NODE_LINE"
    else
      check_fail "No FROM node: line found in MFE Dockerfile"
    fi
  fi

  # Check g++ toolchain
  if grep -q 'g++' "$TUTOR_ENV" 2>/dev/null; then
    check_pass "g++ toolchain present in MFE Dockerfile"
  else
    check_fail "g++ not found in MFE Dockerfile — Node 18 toolchain patch missing"
  fi

  # Check Mereka theme copy
  if grep -q 'COPY indigo/mereka /openedx/app/mereka' "$TUTOR_ENV" 2>/dev/null; then
    check_pass "Mereka brand theme copy present in MFE Dockerfile"
  else
    check_fail "Mereka theme copy not found — custom footer branding may be broken"
  fi

  # Check SESSION_COOKIE_DOMAIN
  if grep -q 'SESSION_COOKIE_DOMAIN' "$TUTOR_ENV" 2>/dev/null; then
    check_pass "SESSION_COOKIE_DOMAIN env var present in MFE Dockerfile"
  else
    check_fail "SESSION_COOKIE_DOMAIN not found — multi-domain cookie patch missing"
  fi

  # Check npm resilience block
  if grep -q 'npm clean-install attempt' "$TUTOR_ENV" 2>/dev/null; then
    check_pass "NPM resilience retry block present in MFE Dockerfile"
  else
    check_fail "NPM resilience block not found — flaky npm installs not mitigated"
  fi

  # Check frontend-plugin-framework
  if grep -q 'frontend-plugin-framework' "$TUTOR_ENV" 2>/dev/null; then
    check_pass "frontend-plugin-framework dependency present in MFE Dockerfile"
  else
    check_fail "frontend-plugin-framework not found in MFE Dockerfile"
  fi

  # Check indigo brand ulmo pin
  if grep -qF 'indigo-brand-openedx@^2.4.3' "$TUTOR_ENV" 2>/dev/null; then
    check_pass "Indigo brand Ulmo pin (@^2.4.3) present in MFE Dockerfile"
  else
    if grep -qF 'indigo-brand-openedx' "$TUTOR_ENV" 2>/dev/null; then
      BRAND_LINE=$(grep -F 'indigo-brand-openedx' "$TUTOR_ENV" | head -1)
      check_fail "Indigo brand pin is not @^2.4.3 — found: $BRAND_LINE"
    else
      check_warn "Indigo brand package not referenced in MFE Dockerfile (may use different brand package)"
    fi
  fi
fi

# ---------------------------------------------------------------------------
# 4. Check for tutor_env/ Indigo env.config.jsx
# ---------------------------------------------------------------------------

section "tutor_env/ Indigo env.config.jsx (if generated)"

INDIGO_ENV="$REPO_ROOT/tutor_env/env/plugins/mfe/build/mfe/indigo/env.config.jsx"

if [[ ! -f "$INDIGO_ENV" ]]; then
  check_warn "indigo/env.config.jsx not found — tutor config save may not have been run"
else
  echo "  Found: $INDIGO_ENV"
  if grep -q 'mereka' "$INDIGO_ENV" 2>/dev/null; then
    check_pass "Mereka references present in env.config.jsx"
  else
    check_warn "No mereka references found in env.config.jsx — footer wiring may be incomplete"
  fi
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------

echo ""
echo "================================================"
echo "  MFE Customization Verification Summary"
echo "================================================"
echo "  Passed:   $PASS"
echo "  Failed:   $FAIL"
echo "  Warnings: ${#WARNINGS[@]}"

if [[ ${#WARNINGS[@]} -gt 0 ]]; then
  echo ""
  echo "  Warnings (non-blocking):"
  for w in "${WARNINGS[@]}"; do
    echo "    - $w"
  done
fi

echo ""

if [[ "$FAIL" -gt 0 ]]; then
  echo "  RESULT: FAIL — run ./infrastructure/tutor/apply-patches.sh to re-apply patches"
  echo "  See docs/operations/ENTERPRISE_MFE_MAINTENANCE.md for full maintenance guide."
  exit 1
else
  echo "  RESULT: PASS — all MFE customizations detected"
  exit 0
fi
