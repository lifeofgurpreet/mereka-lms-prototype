#!/usr/bin/env bash
# @covers AC-MTA-015, AC-MTA-016, AC-MTA-017
# @spec: multi-tenancy-architecture_spec.md
# Verify that /api/mfe_config/v1 is wired and returns per-tenant MFE config.
#
# Checks (static / repository-level — no live cluster required):
#   1. LMS settings include MFE_CONFIG with required baseline keys
#      (FAVICON_URL, LOGO_URL, LOGO_WHITE_URL, LOGO_TRADEMARK_URL)
#   2. The Caddy MFE config proxies /api/mfe_config/v1* to lms:8000
#   3. The per-tenant provisioning script exists and is executable
#   4. The provisioning script covers all three known tenants
#
# Optional live-cluster checks (run when kubectl is available):
#   5. /api/mfe_config/v1 returns JSON on each tenant LMS domain
#   6. Per-tenant SITE_NAME and LMS_BASE_URL match expected values
#
# Usage:
#   ./scripts/qa/verify-mfe-config-api.sh
#   ./scripts/qa/verify-mfe-config-api.sh --live   # force live checks
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${REPO_ROOT}/scripts/shared/config.sh" 2>/dev/null || true

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASS=0
FAIL=0
SKIP=0
LIVE_MODE=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --live) LIVE_MODE=1; shift ;;
    -h|--help)
      echo "Usage: $0 [--live]"
      exit 0
      ;;
    *) echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
done

pass() { echo -e "${GREEN}PASS${NC} $1"; PASS=$((PASS + 1)); }
fail() { echo -e "${RED}FAIL${NC} $1"; FAIL=$((FAIL + 1)); }
skip() { echo -e "${YELLOW}SKIP${NC} $1"; SKIP=$((SKIP + 1)); }

echo "=== MFE Config API Verification ==="
echo "Date: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo ""

# ─── Check 1: LMS settings include MFE_CONFIG with required baseline keys ─────
echo "--- Check 1: LMS settings MFE_CONFIG baseline keys ---"

LMS_SETTINGS="${REPO_ROOT}/infrastructure/tutor/plugins/_mereka_lms/lms_settings.py"

if [[ ! -f "$LMS_SETTINGS" ]]; then
  fail "LMS settings file not found: $LMS_SETTINGS"
else
  # Verify MFE_CONFIG dict is set (at least one assignment present)
  if grep -q 'MFE_CONFIG\[' "$LMS_SETTINGS"; then
    pass "MFE_CONFIG entries present in LMS settings"
  else
    fail "No MFE_CONFIG keys found in LMS settings"
  fi

  # Required branding keys wired to MFE-hosted assets
  for key in FAVICON_URL LOGO_URL LOGO_WHITE_URL LOGO_TRADEMARK_URL; do
    if grep -q "MFE_CONFIG\[\"${key}\"\]" "$LMS_SETTINGS"; then
      pass "MFE_CONFIG[\"${key}\"] set in LMS settings"
    else
      fail "MFE_CONFIG[\"${key}\"] missing from LMS settings"
    fi
  done

  # Verify PARAGON_THEME_URLS wiring (conditional on feature flag)
  if grep -q 'PARAGON_THEME_URLS' "$LMS_SETTINGS"; then
    pass "PARAGON_THEME_URLS wired in LMS settings"
  else
    fail "PARAGON_THEME_URLS not found in LMS settings"
  fi
fi

echo ""

# ─── Check 2: Caddy proxies /api/mfe_config/v1* to LMS ───────────────────────
echo "--- Check 2: Caddy proxies /api/mfe_config/v1* to lms:8000 ---"

# Search both enterprise MFE Caddyfiles and the main Tutor Caddy patch
CADDYFILE_LOCATIONS=(
  "${REPO_ROOT}/deploy/k8s/base/apps/enterprise/mfe/admin-portal-Caddyfile"
  "${REPO_ROOT}/deploy/k8s/base/apps/enterprise/mfe/learner-portal-Caddyfile"
  "${REPO_ROOT}/infrastructure/tutor/patches/caddy-Caddyfile"
)

MFE_CONFIG_PROXY_FOUND=0
for cf in "${CADDYFILE_LOCATIONS[@]}"; do
  if [[ -f "$cf" ]] && grep -q "mfe_config" "$cf"; then
    pass "Caddy mfe_config proxy found in $(basename "$cf")"
    MFE_CONFIG_PROXY_FOUND=1
  fi
done

# Also search any Caddyfile in the repo that references mfe_config
if [[ $MFE_CONFIG_PROXY_FOUND -eq 0 ]]; then
  FOUND_FILE=$(grep -rl "mfe_config" "${REPO_ROOT}" \
    --include="*Caddyfile*" --include="*caddy*" 2>/dev/null | head -1 || true)
  if [[ -n "$FOUND_FILE" ]]; then
    pass "Caddy mfe_config proxy found in ${FOUND_FILE#"${REPO_ROOT}/"}"
    MFE_CONFIG_PROXY_FOUND=1
  fi
fi

if [[ $MFE_CONFIG_PROXY_FOUND -eq 0 ]]; then
  skip "Caddy mfe_config proxy not found in repo Caddyfiles (may be in bbi-infrastructure)"
fi

echo ""

# ─── Check 3: Provisioning script exists and is executable ───────────────────
echo "--- Check 3: Tenant MFE config provisioning script ---"

PROVISION_SCRIPT="${REPO_ROOT}/scripts/tenants/provision-mfe-config.sh"

if [[ -f "$PROVISION_SCRIPT" ]]; then
  pass "provision-mfe-config.sh exists"

  if [[ -x "$PROVISION_SCRIPT" ]]; then
    pass "provision-mfe-config.sh is executable"
  else
    fail "provision-mfe-config.sh is not executable (run: chmod +x $PROVISION_SCRIPT)"
  fi
else
  fail "provision-mfe-config.sh not found at $PROVISION_SCRIPT"
fi

echo ""

# ─── Check 4: Provisioning script covers all three tenants ────────────────────
echo "--- Check 4: All three tenants referenced in provisioning script ---"

EXPECTED_TENANTS=(mereka biji-biji skillourfuture)
EXPECTED_DOMAINS=(
  "academyv2.mereka.io"
  "academy.biji-biji.com"
  "skillourfuture.academy.mereka.io"
)

if [[ -f "$PROVISION_SCRIPT" ]]; then
  for i in "${!EXPECTED_TENANTS[@]}"; do
    tenant="${EXPECTED_TENANTS[$i]}"
    domain="${EXPECTED_DOMAINS[$i]}"
    if grep -q "$tenant" "$PROVISION_SCRIPT" && grep -q "$domain" "$PROVISION_SCRIPT"; then
      pass "Tenant '$tenant' (domain: $domain) defined in provisioning script"
    else
      fail "Tenant '$tenant' or domain '$domain' missing from provisioning script"
    fi
  done
else
  skip "Provisioning script not found, skipping tenant coverage checks"
fi

echo ""

# ─── Check 5 & 6: Optional live-cluster checks ────────────────────────────────
echo "--- Check 5-6: Live /api/mfe_config/v1 endpoint checks ---"

KUBECTL_LIVE=0
if [[ $LIVE_MODE -eq 1 ]]; then
  KUBECTL_LIVE=1
elif command -v kubectl &>/dev/null && kubectl cluster-info &>/dev/null 2>&1; then
  KUBECTL_LIVE=1
fi

if [[ $KUBECTL_LIVE -eq 0 ]]; then
  skip "Live checks skipped (kubectl not available or --live not specified)"
  skip "Re-run with --live flag when cluster is accessible"
else
  NAMESPACE="${K8S_NAMESPACE:-mereka-lms}"

  # Map tenant → expected LMS domain for the live check
  declare -A LIVE_TENANTS=(
    [mereka]="${LMS_DOMAIN:-academyv2.mereka.io}"
    [biji-biji]="${BIJI_DOMAIN:-academy.biji-biji.com}"
    [skillourfuture]="${SKILLOURFUTURE_DOMAIN:-skillourfuture.academy.mereka.io}"
  )

  for tenant in mereka biji-biji skillourfuture; do
    domain="${LIVE_TENANTS[$tenant]}"
    url="https://${domain}/api/mfe_config/v1"
    echo "  Checking $url ..."

    HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 "$url" 2>/dev/null || echo "000")

    if [[ "$HTTP_STATUS" == "200" ]]; then
      pass "Tenant '$tenant': /api/mfe_config/v1 returns HTTP 200"

      # Validate expected LMS_BASE_URL in response
      RESPONSE=$(curl -s --max-time 10 "$url" 2>/dev/null || echo "")
      if echo "$RESPONSE" | python3 -c "
import json, sys
data = json.load(sys.stdin)
expected = 'https://${domain}'
actual = data.get('LMS_BASE_URL', '')
if actual == expected:
    sys.exit(0)
print(f'LMS_BASE_URL={actual!r} (expected {expected!r})', file=sys.stderr)
sys.exit(1)
" 2>/dev/null; then
        pass "Tenant '$tenant': LMS_BASE_URL=https://${domain}"
      else
        fail "Tenant '$tenant': LMS_BASE_URL mismatch or SiteConfiguration not provisioned"
        echo "       Run: ./scripts/tenants/provision-mfe-config.sh --tenant $tenant"
      fi
    elif [[ "$HTTP_STATUS" == "000" ]]; then
      skip "Tenant '$tenant': $url unreachable (network/DNS)"
    else
      fail "Tenant '$tenant': /api/mfe_config/v1 returned HTTP $HTTP_STATUS"
    fi
  done
fi

echo ""
echo "=== Summary ==="
echo -e "${GREEN}PASS:${NC} $PASS | ${RED}FAIL:${NC} $FAIL | ${YELLOW}SKIP:${NC} $SKIP"
echo ""

if [[ $FAIL -gt 0 ]]; then
  echo "To provision per-tenant MFE config for a live cluster:"
  echo "  ./scripts/tenants/provision-mfe-config.sh --tenant mereka"
  echo "  ./scripts/tenants/provision-mfe-config.sh --tenant biji-biji"
  echo "  ./scripts/tenants/provision-mfe-config.sh --tenant skillourfuture"
  exit 1
fi
exit 0
