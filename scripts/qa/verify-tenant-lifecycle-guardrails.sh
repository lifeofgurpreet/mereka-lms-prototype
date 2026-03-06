#!/usr/bin/env bash
# Verify tenant lifecycle scripts enforce explicit confirmation and prod safety guardrails.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PROVISION_SCRIPT="$REPO_ROOT/scripts/tenants/provision-tenant.sh"
OFFBOARD_SCRIPT="$REPO_ROOT/scripts/tenants/offboard-tenant.sh"

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

echo "=== Tenant Lifecycle Guardrails ==="
echo

if [[ -f "$PROVISION_SCRIPT" ]]; then
  pass "provision-tenant script exists"
else
  fail "Missing script: scripts/tenants/provision-tenant.sh"
fi

if [[ -f "$OFFBOARD_SCRIPT" ]]; then
  pass "offboard-tenant script exists"
else
  fail "Missing script: scripts/tenants/offboard-tenant.sh"
fi

if [[ -f "$PROVISION_SCRIPT" ]]; then
  require_pattern "$PROVISION_SCRIPT" 'set -euo pipefail' 'provision-tenant uses strict bash mode'
  require_pattern "$PROVISION_SCRIPT" 'CONFIRM_PROVISION_TENANT' 'provision-tenant has confirmation variable'
  require_pattern "$PROVISION_SCRIPT" 'CONFIRM_TOKEN="PROVISION_TENANT"' 'provision-tenant has explicit confirmation token'
  require_pattern "$PROVISION_SCRIPT" 'Refusing live provisioning without explicit confirmation token' 'provision-tenant blocks non-dry-run without token'
fi

if [[ -f "$OFFBOARD_SCRIPT" ]]; then
  require_pattern "$OFFBOARD_SCRIPT" 'set -euo pipefail' 'offboard-tenant uses strict bash mode'
  require_pattern "$OFFBOARD_SCRIPT" 'CONFIRM_OFFBOARD_TENANT' 'offboard-tenant has offboard confirmation variable'
  require_pattern "$OFFBOARD_SCRIPT" 'CONFIRM_FORCE_DELETE_TENANT' 'offboard-tenant has force-delete confirmation variable'
  require_pattern "$OFFBOARD_SCRIPT" 'OFFBOARD_CONFIRM_TOKEN="OFFBOARD_TENANT"' 'offboard-tenant has offboard confirmation token'
  require_pattern "$OFFBOARD_SCRIPT" 'FORCE_DELETE_CONFIRM_TOKEN="FORCE_DELETE_TENANT"' 'offboard-tenant has force-delete confirmation token'
  require_pattern "$OFFBOARD_SCRIPT" 'ALLOW_PROD_OFFBOARD' 'offboard-tenant has prod apply guard variable'
  require_pattern "$OFFBOARD_SCRIPT" 'CREATE_PREOP_BACKUP' 'offboard-tenant has pre-op backup control variable'
  require_pattern "$OFFBOARD_SCRIPT" 'velero backup create' 'offboard-tenant includes Velero pre-op backup action'
  require_pattern "$OFFBOARD_SCRIPT" 'Refusing non-dry-run offboarding on prod-like context' 'offboard-tenant blocks prod-like offboarding without override'
  require_pattern "$OFFBOARD_SCRIPT" 'Refusing force-delete without explicit confirmation token' 'offboard-tenant blocks force-delete without token'
fi

echo
echo "=== Summary ==="
echo -e "${GREEN}PASS:${NC} $PASS | ${RED}FAIL:${NC} $FAIL"

if [[ "$FAIL" -gt 0 ]]; then
  exit 1
fi

exit 0
