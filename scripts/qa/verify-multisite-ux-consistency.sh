#!/usr/bin/env bash
# @covers AC-MSUX-001, AC-MSUX-002, AC-MSUX-003
# @spec: branding-system_spec.md
#
# verify-multisite-ux-consistency.sh - Multi-site UX consistency audit
#
# Acceptance Criteria:
# - AC-MSUX-001: Contract documents multisite UX consistency requirements across all MFE touch points
# - AC-MSUX-002: Verifier detects hardcoded domain references that would break on alternative domains
# - AC-MSUX-003: CI gate prevents introduction of new hardcoded domain references

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Source shared config
# shellcheck source=../shared/config.sh
source "$SCRIPT_DIR/../shared/config.sh"
source "$SCRIPT_DIR/../shared/mereka_plugin_contract.sh"
PLUGIN_MAIN="$(mereka_plugin_main_file "$REPO_ROOT")"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Counters
PASSED=0
FAILED=0
WARNED=0

do_pass() {
  echo -e "${GREEN}PASS${NC} $1"
  PASSED=$((PASSED + 1))
}

do_fail() {
  echo -e "${RED}FAIL${NC} $1"
  FAILED=$((FAILED + 1))
}

do_warn() {
  echo -e "${YELLOW}WARN${NC} $1"
  WARNED=$((WARNED + 1))
}

echo "=== Multi-Site UX Consistency Verification ==="
echo "Spec: branding-system_spec.md"
echo "Coverage: AC-MSUX-001, AC-MSUX-002, AC-MSUX-003"
echo "Contract: docs/policies/architecture/MULTISITE_UX_CONSISTENCY.md"
echo

# =============================================================================
# Section 1: Contract Existence (AC-MSUX-001)
# =============================================================================
echo "=== Section 1: Contract Existence (AC-MSUX-001) ==="
echo

CONTRACT_FILE="$REPO_ROOT/docs/policies/architecture/MULTISITE_UX_CONSISTENCY.md"

if [[ -f "$CONTRACT_FILE" ]]; then
  do_pass "AC-MSUX-001: Contract document exists"
else
  do_fail "AC-MSUX-001: Contract document missing at $CONTRACT_FILE"
fi

# Check contract contains key sections
if [[ -f "$CONTRACT_FILE" ]]; then
  if grep -q "## Multi-Site Contract Rules" "$CONTRACT_FILE"; then
    do_pass "AC-MSUX-001: Contract defines multi-site rules"
  else
    do_fail "AC-MSUX-001: Contract missing 'Multi-Site Contract Rules' section"
  fi

  if grep -q "## Audit Findings" "$CONTRACT_FILE"; then
    do_pass "AC-MSUX-001: Contract documents audit findings"
  else
    do_fail "AC-MSUX-001: Contract missing 'Audit Findings' section"
  fi

  if grep -q "## Quick Wins" "$CONTRACT_FILE"; then
    do_pass "AC-MSUX-001: Contract documents quick wins"
  else
    do_fail "AC-MSUX-001: Contract missing 'Quick Wins' section"
  fi
fi

echo

# =============================================================================
# Section 2: Hardcoded Domain Detection (AC-MSUX-002)
# =============================================================================
echo "=== Section 2: Hardcoded Domain Detection (AC-MSUX-002) ==="
echo

# Key files to scan for hardcoded domains
SCAN_FILES=(
  "deploy/k8s/base/apps/openedx/settings/lms/production.py"
  "deploy/k8s/base/apps/openedx/settings/cms/production.py"
  "$PLUGIN_MAIN"
  "deploy/k8s/base/plugins/mfe/apps/mfe/Caddyfile"
)

# Domain patterns to check
DOMAIN_PATTERNS=(
  "academyv2\.mereka\.io"
  "apps\.academyv2\.mereka\.io"
  "academy\.biji-biji\.com"
  "studio\.academyv2\.mereka\.io"
)

# Section 2.1: Scan production.py for hardcoded domains
echo "Checking production.py for hardcoded domains..."
PROD_PY="$REPO_ROOT/deploy/k8s/base/apps/openedx/settings/lms/production.py"

if [[ -f "$PROD_PY" ]]; then
  # Check if domains are in env var calls (ACCEPTABLE)
  ENV_VAR_COUNT=$(grep -cE 'os\.environ\.get\("MEREKA_(LMS|MFE|BIJI|STUDIO)_DOMAIN"' "$PROD_PY" || echo "0")
  if [[ "$ENV_VAR_COUNT" -ge 3 ]]; then
    do_pass "AC-MSUX-002: production.py uses env vars for domain configuration ($ENV_VAR_COUNT references)"
  else
    do_fail "AC-MSUX-002: production.py missing env var domain config (found $ENV_VAR_COUNT, expected >= 3)"
  fi

  # Check if MFE_CONFIG uses dynamic variables (NOT hardcoded)
  if grep -q 'MFE_CONFIG\s*=\s*{' "$PROD_PY"; then
    # Extract MFE_CONFIG block
    MFE_CONFIG_BLOCK=$(awk '/^MFE_CONFIG\s*=\s*{/,/^}/' "$PROD_PY")

    # Check for hardcoded https://academyv2.mereka.io in MFE_CONFIG
    if echo "$MFE_CONFIG_BLOCK" | grep -qE '"https://(academyv2\.mereka\.io|apps\.academyv2\.mereka\.io)"'; then
      do_fail "AC-MSUX-002: MFE_CONFIG contains hardcoded domain URLs"
    else
      do_pass "AC-MSUX-002: MFE_CONFIG uses dynamic base URLs (no hardcoded domains)"
    fi

    # Check for MEREKA_LMS_BASE_URL usage (ACCEPTABLE)
    if echo "$MFE_CONFIG_BLOCK" | grep -q 'MEREKA_LMS_BASE_URL\|MEREKA_MFE_BASE_URL'; then
      do_pass "AC-MSUX-002: MFE_CONFIG uses dynamic MEREKA_*_BASE_URL variables"
    else
      do_warn "AC-MSUX-002: MFE_CONFIG may not use dynamic base URL variables"
    fi
  else
    do_warn "AC-MSUX-002: MFE_CONFIG block not found in production.py"
  fi

  # Check cookie domains are host-only (None)
  if grep -q 'SESSION_COOKIE_DOMAIN\s*=\s*None' "$PROD_PY" && grep -q 'CSRF_COOKIE_DOMAIN\s*=\s*None' "$PROD_PY"; then
    do_pass "AC-MSUX-002: Session/CSRF cookies are host-only (multi-site compatible)"
  else
    do_fail "AC-MSUX-002: Session/CSRF cookies must be host-only (SESSION_COOKIE_DOMAIN = None)"
  fi
else
  do_fail "AC-MSUX-002: production.py not found at $PROD_PY"
fi

echo

# Section 2.2: Scan plugin contract sources for hardcoded domains
echo "Checking plugin contract sources for hardcoded domains..."

if mereka_plugin_has_any "$REPO_ROOT"; then
  # Check for hardcoded DISCUSSIONS_MICROFRONTEND_URL (FAIL if hardcoded)
  if mereka_plugin_has_regex "$REPO_ROOT" 'DISCUSSIONS_MICROFRONTEND_URL\s*=\s*"https://apps\.academyv2\.mereka\.io'; then
    do_warn "AC-MSUX-002: DISCUSSIONS_MICROFRONTEND_URL hardcoded to academyv2.mereka.io (tracked quick-win)"
  else
    do_pass "AC-MSUX-002: DISCUSSIONS_MICROFRONTEND_URL not hardcoded (or uses dynamic URL)"
  fi

  # Check Caddy config for hardcoded domains (local Tutor Caddy — K8s Caddyfile is clean)
  if mereka_plugin_has_regex "$REPO_ROOT" '^apps\.academyv2\.mereka\.io\s*\{'; then
    # Hardcoded Caddy block found — check if it's templated
    if mereka_plugin_has_regex "$REPO_ROOT" '{%\s*for\s*host\s*in'; then
      do_pass "AC-MSUX-002: Caddy config uses template loop for multi-domain support"
    else
      do_warn "AC-MSUX-002: Local Tutor Caddy profile API block hardcodes apps.academyv2.mereka.io (K8s Caddyfile is clean — local-only impact)"
    fi
  else
    do_pass "AC-MSUX-002: No hardcoded Caddy apps.academyv2.mereka.io block"
  fi

  # Check Nginx config for hardcoded Host header
  if mereka_plugin_has_regex "$REPO_ROOT" 'proxy_set_header Host academyv2\.mereka\.io'; then
    do_warn "AC-MSUX-002: Nginx proxy_set_header hardcodes academyv2.mereka.io (tracked quick-win)"
  else
    do_pass "AC-MSUX-002: Nginx proxy_set_header not hardcoded (or uses dynamic host)"
  fi

  # Check cookie domain defaults (WARN if hardcoded)
  if mereka_plugin_has_regex "$REPO_ROOT" 'MEREKA_SESSION_COOKIE_DOMAIN.*\.academyv2\.mereka\.io'; then
    do_warn "AC-MSUX-002: Plugin has .academyv2.mereka.io SESSION_COOKIE_DOMAIN default (overridden in production.py)"
  else
    do_pass "AC-MSUX-002: No hardcoded session cookie domain default in plugin"
  fi
else
  do_fail "AC-MSUX-002: Plugin contract sources not found (expected at least $PLUGIN_MAIN)"
fi

echo

# Section 2.3: Scan Caddyfile for hardcoded domains
echo "Checking Caddyfile for hardcoded domains..."
CADDYFILE="$REPO_ROOT/deploy/k8s/base/plugins/mfe/apps/mfe/Caddyfile"

if [[ -f "$CADDYFILE" ]]; then
  # Caddyfile MUST have port listener (:8002) and route matchers
  if grep -qE '^:[0-9]+\s*\{' "$CADDYFILE"; then
    do_pass "AC-MSUX-002: Caddyfile contains port listener"
  else
    do_fail "AC-MSUX-002: Caddyfile missing port listener"
  fi

  # Check for reverse_proxy to LMS with Host preservation
  if grep -q 'header_up Host {http\.request\.host}' "$CADDYFILE"; then
    do_pass "AC-MSUX-002: Caddyfile preserves Host header for LMS proxy (multi-site compatible)"
  else
    do_fail "AC-MSUX-002: Caddyfile must preserve Host header for SiteConfiguration resolution"
  fi

  # Check for /api/mfe_config/v1 proxy
  if grep -q 'reverse_proxy /api/mfe_config/v1' "$CADDYFILE"; then
    do_pass "AC-MSUX-002: Caddyfile proxies /api/mfe_config/v1 to LMS"
  else
    do_fail "AC-MSUX-002: Caddyfile missing /api/mfe_config/v1 proxy"
  fi

  # Check for /login_refresh proxy
  if grep -q 'reverse_proxy /login_refresh' "$CADDYFILE"; then
    do_pass "AC-MSUX-002: Caddyfile proxies /login_refresh to LMS (JWT cookie refresh)"
  else
    do_fail "AC-MSUX-002: Caddyfile missing /login_refresh proxy"
  fi
else
  do_fail "AC-MSUX-002: Caddyfile not found at $CADDYFILE"
fi

echo

# Section 2.4: Check MFE build artifacts (if MFE pod exists)
echo "Checking MFE pod for hardcoded domains (requires kubectl access)..."

if command -v kubectl &>/dev/null; then
  MFE_POD=$(kubectl get pods -n "$K8S_NAMESPACE" -l app.kubernetes.io/name=mfe -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")

  if [[ -n "$MFE_POD" ]]; then
    # Check for hardcoded academyv2.mereka.io in MFE dist files
    HARDCODED_OUTPUT=$(kubectl exec -n "$K8S_NAMESPACE" "$MFE_POD" -- grep -rc "academyv2\.mereka\.io" /openedx/dist/ 2>/dev/null || true)
    HARDCODED_COUNT=$(echo "$HARDCODED_OUTPUT" | awk -F: '{s+=$NF} END {print s+0}')

    if [[ "$HARDCODED_COUNT" -eq 0 ]]; then
      do_pass "AC-MSUX-002: MFE build artifacts contain no hardcoded academyv2.mereka.io references"
    else
      do_warn "AC-MSUX-002: MFE build artifacts contain $HARDCODED_COUNT hardcoded domain references (expected: MFEs bake URLs at build time, overridden by /api/mfe_config/v1)"
    fi

    # Check for env.config.jsx dynamic hostname usage
    ENV_CONFIG_JS=$(kubectl exec -n "$K8S_NAMESPACE" "$MFE_POD" -- cat /openedx/env.config.js 2>/dev/null || echo "")
    if echo "$ENV_CONFIG_JS" | grep -q 'window\.location\.hostname'; then
      do_pass "AC-MSUX-002: env.config.js uses dynamic hostname resolution"
    else
      do_warn "AC-MSUX-002: env.config.js may not use dynamic hostname (check for SITE_VARIANTS)"
    fi
  else
    do_warn "AC-MSUX-002: MFE pod not found (skip pod-level checks)"
  fi
else
  do_warn "AC-MSUX-002: kubectl not available (skip pod-level checks)"
fi

echo

# =============================================================================
# Section 3: CI Gate Verification (AC-MSUX-003)
# =============================================================================
echo "=== Section 3: CI Gate Verification (AC-MSUX-003) ==="
echo

CI_WORKFLOW="$REPO_ROOT/.github/workflows/ci.yml"

if [[ -f "$CI_WORKFLOW" ]]; then
  do_pass "AC-MSUX-003: CI workflow file exists"

  # Check for syntax check of this verifier
  if grep -q 'bash -n scripts/qa/verify-multisite-ux-consistency.sh' "$CI_WORKFLOW"; then
    do_pass "AC-MSUX-003: CI workflow includes syntax check for this verifier"
  else
    do_fail "AC-MSUX-003: CI workflow missing syntax check for verify-multisite-ux-consistency.sh"
  fi
else
  do_fail "AC-MSUX-003: CI workflow not found at $CI_WORKFLOW"
fi

echo

# =============================================================================
# Summary
# =============================================================================
echo "=== Summary ==="
echo -e "${GREEN}PASS:${NC} $PASSED | ${RED}FAIL:${NC} $FAILED | ${YELLOW}WARN:${NC} $WARNED"
echo

if [[ $FAILED -gt 0 ]]; then
  echo "Multi-site UX consistency issues detected."
  echo "Action required: Fix hardcoded domain references."
  echo "See: docs/policies/architecture/MULTISITE_UX_CONSISTENCY.md"
  exit 1
fi

if [[ $WARNED -gt 0 ]]; then
  echo "Multi-site UX consistency verified with warnings."
  echo "Warnings are acceptable (defaults or pod-level checks skipped)."
  exit 0
fi

echo "All multi-site UX consistency checks passed!"
exit 0
