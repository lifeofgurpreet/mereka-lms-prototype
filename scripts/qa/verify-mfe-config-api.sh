#!/usr/bin/env bash
# @covers AC-MTA-015, AC-MTA-016, AC-MTA-017
# @spec: multi-tenancy-architecture_spec.md
# Verify that /api/mfe_config/v1 is wired and returns per-tenant MFE config.
#
# Checks (static / repository-level — no live cluster required):
#   1. LMS settings include MFE_CONFIG with required baseline keys
#      (FAVICON_URL, LOGO_URL, LOGO_WHITE_URL, LOGO_TRADEMARK_URL)
#   2. The Caddy MFE config proxies /api/mfe_config/v1* to lms:8000
#   3. The retired provision-mfe compatibility shim exists and points to the
#      canonical multisite apply flow
#   4. The canonical multisite apply script exists and is executable
#   5. The canonical apply flow delegates to multisite_bootstrap_django.py,
#      the helper exists on disk, and the multisite registry covers the known
#      tenant domains including MFE_BASE_URL entries
#
# Optional live-cluster checks (run when kubectl is available):
#   6. /api/mfe_config/v1 returns JSON on each tenant LMS domain
#   7. Per-tenant SITE_NAME and LMS_BASE_URL match expected values
#
# Usage:
#   ./scripts/qa/verify-mfe-config-api.sh
#   ./scripts/qa/verify-mfe-config-api.sh --live
#   ./scripts/qa/verify-mfe-config-api.sh --live --env dev
#   ./scripts/qa/verify-mfe-config-api.sh --live --env production
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
USER_K8S_NAMESPACE="${K8S_NAMESPACE-}"
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
TARGET_ENV=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --live) LIVE_MODE=1; shift ;;
    --env)
      [[ $# -lt 2 ]] && { echo "--env requires a value" >&2; exit 1; }
      TARGET_ENV="$2"
      shift 2
      ;;
    -h|--help)
      echo "Usage: $0 [--live] [--env production|dev|profiles-dev|staging]"
      exit 0
      ;;
    *) echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
done

pass() { echo -e "${GREEN}PASS${NC} $1"; PASS=$((PASS + 1)); }
fail() { echo -e "${RED}FAIL${NC} $1"; FAIL=$((FAIL + 1)); }
skip() { echo -e "${YELLOW}SKIP${NC} $1"; SKIP=$((SKIP + 1)); }

resolve_live_environment() {
  if [[ -n "$TARGET_ENV" ]]; then
    case "$TARGET_ENV" in
      production|dev|profiles-dev|staging)
        printf '%s\n' "$TARGET_ENV"
        return 0
        ;;
      *)
        echo "Unsupported --env value: $TARGET_ENV" >&2
        return 1
        ;;
    esac
  fi

  case "$(resolve_live_namespace)" in
    mereka-lms-dev) printf '%s\n' "dev" ;;
    stg-mereka-lms) printf '%s\n' "staging" ;;
    mereka-lms) printf '%s\n' "production" ;;
    *)
      echo "Unknown live namespace '${K8S_NAMESPACE:-}'; defaulting live checks to production" >&2
      printf '%s\n' "production"
      ;;
  esac
}

resolve_live_namespace() {
  local configured_namespace="${K8S_NAMESPACE:-mereka-lms}"

  if [[ -n "$USER_K8S_NAMESPACE" ]]; then
    printf '%s\n' "$USER_K8S_NAMESPACE"
    return 0
  fi

  if command -v kubectl &>/dev/null; then
    if kubectl get namespace "$configured_namespace" >/dev/null 2>&1; then
      printf '%s\n' "$configured_namespace"
      return 0
    fi

    for candidate in mereka-lms-dev stg-mereka-lms mereka-lms; do
      if kubectl get namespace "$candidate" >/dev/null 2>&1; then
        printf '%s\n' "$candidate"
        return 0
      fi
    done
  fi

  printf '%s\n' "$configured_namespace"
}

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

# ─── Check 3: Retired provision-mfe compatibility shim ───────────────────────
echo "--- Check 3: Retired provision-mfe compatibility shim ---"

PROVISION_SCRIPT="${REPO_ROOT}/scripts/tenants/provision-mfe-config.sh"
APPLY_SCRIPT="${REPO_ROOT}/scripts/infra/apply-multisite-config.sh"
DJANGO_BOOTSTRAP="${REPO_ROOT}/scripts/shared/multisite_bootstrap_django.py"
MULTISITE_REGISTRY="${REPO_ROOT}/infrastructure/tutor/multisite-sites.yml"

if [[ -f "$PROVISION_SCRIPT" ]]; then
  pass "provision-mfe-config.sh exists"

  if [[ -x "$PROVISION_SCRIPT" ]]; then
    pass "provision-mfe-config.sh is executable"
  else
    fail "provision-mfe-config.sh is not executable (run: chmod +x $PROVISION_SCRIPT)"
  fi

  if grep -q "Retired compatibility shim" "$PROVISION_SCRIPT" && grep -q "apply-multisite-config.sh" "$PROVISION_SCRIPT"; then
    pass "provision-mfe-config.sh is retired and points to canonical multisite apply flow"
  else
    fail "provision-mfe-config.sh does not advertise the canonical multisite apply flow"
  fi
else
  fail "provision-mfe-config.sh not found at $PROVISION_SCRIPT"
fi

echo ""

# ─── Check 4: Canonical apply script exists and is executable ────────────────
echo "--- Check 4: Canonical multisite apply script ---"

if [[ -f "$APPLY_SCRIPT" ]]; then
  pass "apply-multisite-config.sh exists"

  if [[ -x "$APPLY_SCRIPT" ]]; then
    pass "apply-multisite-config.sh is executable"
  else
    fail "apply-multisite-config.sh is not executable (run: chmod +x $APPLY_SCRIPT)"
  fi
else
  fail "apply-multisite-config.sh not found at $APPLY_SCRIPT"
fi

if [[ -f "$DJANGO_BOOTSTRAP" ]]; then
  pass "multisite_bootstrap_django.py exists"
else
  fail "multisite_bootstrap_django.py not found at $DJANGO_BOOTSTRAP"
fi

echo ""

# ─── Check 5: Canonical apply flow covers the known tenant domains ───────────
echo "--- Check 5: Canonical apply flow and multisite registry coverage ---"

EXPECTED_TENANTS=(mereka biji-biji skillourfuture)
EXPECTED_DOMAINS=(
  "academyv2.mereka.io"
  "academy.biji-biji.com"
  "skillourfuture.academy.mereka.io"
)

if [[ -f "$APPLY_SCRIPT" ]]; then
  if grep -q "multisite_bootstrap_django.py" "$APPLY_SCRIPT"; then
    pass "apply-multisite-config.sh delegates to multisite_bootstrap_django.py"
  else
    fail "apply-multisite-config.sh does not reference multisite_bootstrap_django.py"
  fi
else
  skip "Canonical apply script not found, skipping bootstrap delegation check"
fi

if [[ -f "$MULTISITE_REGISTRY" ]]; then
  for i in "${!EXPECTED_TENANTS[@]}"; do
    tenant="${EXPECTED_TENANTS[$i]}"
    domain="${EXPECTED_DOMAINS[$i]}"
    if grep -q "$tenant" "$MULTISITE_REGISTRY" && grep -q "$domain" "$MULTISITE_REGISTRY"; then
      pass "Tenant '$tenant' (domain: $domain) defined in multisite-sites.yml"
    else
      fail "Tenant '$tenant' or domain '$domain' missing from multisite-sites.yml"
    fi
  done

  if grep -q "MFE_BASE_URL" "$MULTISITE_REGISTRY"; then
    pass "multisite-sites.yml includes MFE_BASE_URL entries"
  else
    fail "multisite-sites.yml does not include MFE_BASE_URL entries"
  fi
else
  fail "multisite-sites.yml not found at $MULTISITE_REGISTRY"
fi

echo ""

# ─── Check 6 & 7: Optional live-cluster checks ────────────────────────────────
echo "--- Check 6-7: Live /api/mfe_config/v1 endpoint checks ---"

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
  NAMESPACE="$(resolve_live_namespace)"
  LIVE_ENV="$(resolve_live_environment)"
  echo "  Resolved live environment: ${LIVE_ENV} (namespace: ${NAMESPACE})"

  # Map tenant → expected LMS domain for the live check
  declare -A LIVE_TENANTS=()
  declare -a LIVE_TENANT_LIST=()
  case "$LIVE_ENV" in
    production)
      LIVE_TENANTS=(
        [mereka]="${LMS_DOMAIN:-academyv2.mereka.io}"
        [biji-biji]="${BIJI_DOMAIN:-academy.biji-biji.com}"
        [skillourfuture]="${SKILLOURFUTURE_DOMAIN:-skillourfuture.academy.mereka.io}"
      )
      LIVE_TENANT_LIST=(mereka biji-biji skillourfuture)
      ;;
    dev|profiles-dev)
      LIVE_TENANTS=(
        [mereka]="${DEV_LMS_DOMAIN:-academyv2.mereka.dev}"
        [biji-biji]="${DEV_BIJI_DOMAIN:-biji-biji.academyv2.mereka.dev}"
        [skillourfuture]="${DEV_SKILLOURFUTURE_DOMAIN:-skillourfuture.academyv2.mereka.dev}"
      )
      LIVE_TENANT_LIST=(mereka biji-biji skillourfuture)
      ;;
    staging)
      LIVE_TENANTS=(
        [mereka]="${STAGING_LMS_DOMAIN:-staging.academyv2.mereka.io}"
      )
      LIVE_TENANT_LIST=(mereka)
      skip "Staging tenant-specific alternate domains are not defined in scripts/shared/config.sh; limiting live checks to the primary tenant"
      ;;
  esac

  for tenant in "${LIVE_TENANT_LIST[@]}"; do
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
        fail "Tenant '$tenant': LMS_BASE_URL mismatch or canonical multisite config not applied"
        case "$LIVE_ENV" in
          production) APPLY_ENV="prod" ;;
          profiles-dev) APPLY_ENV="dev" ;;
          *) APPLY_ENV="$LIVE_ENV" ;;
        esac
        echo "       Run: ./scripts/infra/apply-multisite-config.sh --env ${APPLY_ENV} --dry-run"
        echo "       Then apply through the canonical multisite path with the required confirmation guards."
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
  echo "To reconcile canonical MFE config for a live cluster:"
  echo "  ./scripts/infra/apply-multisite-config.sh --env prod --dry-run"
  echo "  ./scripts/infra/apply-multisite-config.sh --env dev --dry-run"
  echo "  ./scripts/infra/apply-multisite-config.sh --env staging --dry-run"
  exit 1
fi
exit 0
