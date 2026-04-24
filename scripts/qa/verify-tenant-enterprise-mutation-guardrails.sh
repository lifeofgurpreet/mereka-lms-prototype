#!/usr/bin/env bash
# @covers AC-CI-014
# @spec: ci-cd-pipeline_spec.md
# Verify enterprise tenant mutation scripts enforce explicit apply confirmation and prod safety controls.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SYNC_SCRIPT="$REPO_ROOT/scripts/tenants/sync-tenant-enterprise-mapping.sh"
IDP_SCRIPT="$REPO_ROOT/scripts/tenants/configure-tenant-idp.sh"
ONBOARD_SCRIPT="$REPO_ROOT/scripts/tenants/onboard-enterprise-tenant.sh"

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

PASS=0
FAIL=0

pass() {
  echo -e "${GREEN}PASS${NC} $1"
  PASS=$((PASS + 1))
}

fail() {
  echo -e "${RED}FAIL${NC} $1"
  FAIL=$((FAIL + 1))
}

require_pattern() {
  local file="$1"
  local pattern="$2"
  local message="$3"
  if grep -qE "$pattern" "$file"; then
    pass "$message"
  else
    fail "$message"
  fi
}

reject_pattern() {
  local file="$1"
  local pattern="$2"
  local message="$3"
  if grep -qE "$pattern" "$file"; then
    fail "$message"
  else
    pass "$message"
  fi
}

echo "=== Enterprise Mutation Guardrails ==="
echo

for script in "$SYNC_SCRIPT" "$IDP_SCRIPT" "$ONBOARD_SCRIPT"; do
  if [[ -f "$script" ]]; then
    pass "$(basename "$script") exists"
    require_pattern "$script" 'set -euo pipefail' "$(basename "$script") uses strict bash mode"
  else
    fail "Missing script: ${script#$REPO_ROOT/}"
  fi
done

if [[ -f "$SYNC_SCRIPT" ]]; then
  require_pattern "$SYNC_SCRIPT" 'CONFIRM_SYNC_TENANT_ENTERPRISE_MAPPING' 'sync mapping has confirmation variable'
  require_pattern "$SYNC_SCRIPT" 'CONFIRM_TOKEN="SYNC_TENANT_ENTERPRISE_MAPPING"' 'sync mapping has explicit confirmation token'
  require_pattern "$SYNC_SCRIPT" 'ALLOW_PROD_APPLY' 'sync mapping has prod apply guard variable'
  require_pattern "$SYNC_SCRIPT" 'CREATE_PREOP_BACKUP' 'sync mapping has pre-op backup control variable'
  require_pattern "$SYNC_SCRIPT" 'ENTERPRISE_CUSTOMER_UUID' 'sync mapping owns ENTERPRISE_CUSTOMER_UUID reconciliation'
  require_pattern "$SYNC_SCRIPT" 'Refusing --apply without explicit confirmation token' 'sync mapping blocks apply without confirmation token'
  require_pattern "$SYNC_SCRIPT" 'Refusing --apply on prod-like context' 'sync mapping blocks prod-like apply without override'
  require_pattern "$SYNC_SCRIPT" 'velero backup create' 'sync mapping includes Velero pre-op backup action'
fi

if [[ -f "$IDP_SCRIPT" ]]; then
  require_pattern "$IDP_SCRIPT" 'CONFIRM_CONFIGURE_TENANT_IDP' 'configure tenant idp has confirmation variable'
  require_pattern "$IDP_SCRIPT" 'CONFIRM_TOKEN="CONFIGURE_TENANT_IDP"' 'configure tenant idp has explicit confirmation token'
  require_pattern "$IDP_SCRIPT" 'ALLOW_PROD_APPLY' 'configure tenant idp has prod apply guard variable'
  require_pattern "$IDP_SCRIPT" 'CREATE_PREOP_BACKUP' 'configure tenant idp has pre-op backup control variable'
  require_pattern "$IDP_SCRIPT" 'sync-tenant-enterprise-mapping\.sh' 'configure tenant idp points operators to canonical mapping sync'
  require_pattern "$IDP_SCRIPT" 'Refusing --apply without explicit confirmation token' 'configure tenant idp blocks apply without confirmation token'
  require_pattern "$IDP_SCRIPT" 'Refusing --apply on prod-like context' 'configure tenant idp blocks prod-like apply without override'
  require_pattern "$IDP_SCRIPT" 'velero backup create' 'configure tenant idp includes Velero pre-op backup action'
  reject_pattern "$IDP_SCRIPT" 'SiteConfiguration\.objects\.(get_or_create|update_or_create)' 'configure tenant idp does not directly mutate SiteConfiguration'
  reject_pattern "$IDP_SCRIPT" "site_values\\[[\"']ENTERPRISE_CUSTOMER_UUID[\"']\\]\\s*=" 'configure tenant idp does not own ENTERPRISE_CUSTOMER_UUID writes'
  reject_pattern "$IDP_SCRIPT" "site_values\\[[\"']ENABLE_ENTERPRISE_INTEGRATION[\"']\\]\\s*=" 'configure tenant idp does not own ENABLE_ENTERPRISE_INTEGRATION writes'
fi

if [[ -f "$ONBOARD_SCRIPT" ]]; then
  require_pattern "$ONBOARD_SCRIPT" 'CONFIRM_ONBOARD_ENTERPRISE_TENANT' 'onboard workflow has top-level confirmation variable'
  require_pattern "$ONBOARD_SCRIPT" 'CONFIRM_TOKEN="ONBOARD_ENTERPRISE_TENANT"' 'onboard workflow has explicit confirmation token'
  require_pattern "$ONBOARD_SCRIPT" 'ALLOW_PROD_APPLY' 'onboard workflow has prod apply guard variable'
  require_pattern "$ONBOARD_SCRIPT" 'CREATE_PREOP_BACKUP' 'onboard workflow has pre-op backup control variable'
  require_pattern "$ONBOARD_SCRIPT" 'Refusing --apply without explicit confirmation token' 'onboard workflow blocks apply without confirmation token'
  require_pattern "$ONBOARD_SCRIPT" 'Refusing --apply on prod-like context' 'onboard workflow blocks prod-like apply without override'
  require_pattern "$ONBOARD_SCRIPT" 'velero backup create' 'onboard workflow includes Velero pre-op backup action'
  require_pattern "$ONBOARD_SCRIPT" 'CONFIRM_SYNC_TENANT_ENTERPRISE_MAPPING="SYNC_TENANT_ENTERPRISE_MAPPING"' 'onboard workflow passes sync mapping confirmation token'
  require_pattern "$ONBOARD_SCRIPT" 'CONFIRM_CONFIGURE_TENANT_IDP="CONFIGURE_TENANT_IDP"' 'onboard workflow passes configure idp confirmation token'
fi

echo
echo "=== Summary ==="
echo -e "${GREEN}PASS:${NC} $PASS | ${RED}FAIL:${NC} $FAIL"

if [[ "$FAIL" -gt 0 ]]; then
  exit 1
fi

exit 0
