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
# mfe-node.sh removed in tracker #32; hooks now live in the Tutor plugin module
MFE_PLUGIN_MODULE="$REPO_ROOT/infrastructure/tutor/plugins/_mereka_lms/mfe_dockerfile.py"
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
  # Use fixed-string matching (grep -F) to avoid ERE special-character issues.
  # Signatures now checked against the Tutor plugin module (tracker #32: mfe-node.sh removed).
  declare -A PATCH_SIGNATURES=(
    ["Node 24 toolchain (pre-npm-install hook)"]="mfe-dockerfile-pre-npm-install"
    ["g++ python3 toolchain extension"]="gcc g++ git libgl1 libxi6 make python3 python3-distutils"
    ["Mereka brand package copy"]="COPY indigo/brand-mereka /openedx/app/brand-mereka"
    ["Cookie domain ENV injection"]="SESSION_COOKIE_DOMAIN"
    ["Frontend plugin framework install"]="frontend-plugin-framework@^1.8.0"
    ["Local brand alias"]="@edx/brand@file:./brand-mereka"
    ["Admin console Redux deps"]="react-redux@^8.1.3"
    ["Account social_links guard"]="unguarded social_links lookup survived account build"
  )

  for label in "${!PATCH_SIGNATURES[@]}"; do
    pattern="${PATCH_SIGNATURES[$label]}"
    if grep -qF "$pattern" "$APPLY_PATCHES" "$MFE_PLUGIN_MODULE" "$TUTOR_ENV" 2>/dev/null; then
      check_pass "$label"
    else
      check_fail "$label — pattern not found: $pattern"
    fi
  done
fi

# ---------------------------------------------------------------------------
# 2. List all MFE-related hook registrations from plugin module
# ---------------------------------------------------------------------------

section "MFE patch hook inventory (plugin module)"

if [[ -f "$MFE_PLUGIN_MODULE" ]]; then
  echo "  Detected MFE hooks in plugin module:"
  grep -E '"mfe-dockerfile-' "$MFE_PLUGIN_MODULE" \
    | sed 's/.*"\(mfe-dockerfile-[^"]*\)".*/  - \1/' \
    | sort -u
else
  check_warn "MFE plugin module not found at $MFE_PLUGIN_MODULE"
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

  # Check Node 24+ base image
  if grep -qE '^FROM docker.io/node:([2-9][0-9]|[1-9][0-9]{1,})' "$TUTOR_ENV" 2>/dev/null; then
    check_pass "Node 24+ base image present in MFE Dockerfile"
  else
    NODE_LINE=$(grep '^FROM.*node:' "$TUTOR_ENV" 2>/dev/null | head -1 || true)
    if [[ -n "$NODE_LINE" ]]; then
      check_fail "Node image is not pinned to Node 24+ — found: $NODE_LINE"
    else
      check_fail "No FROM node: line found in MFE Dockerfile"
    fi
  fi

  # Check g++ toolchain
  if grep -q 'g++' "$TUTOR_ENV" 2>/dev/null; then
    check_pass "g++ toolchain present in MFE Dockerfile"
  else
    check_fail "g++ not found in MFE Dockerfile — Node toolchain patch missing"
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
  echo "  RESULT: FAIL — run ./scripts/infra/prepare-tutor-build-context.sh --target mfe to re-prepare the MFE build context"
  echo "  See docs/ops/runbooks/architecture/ENTERPRISE_MFE_MAINTENANCE.md for full maintenance guide."
  exit 1
else
  echo "  RESULT: PASS — all MFE customizations detected"
  exit 0
fi
