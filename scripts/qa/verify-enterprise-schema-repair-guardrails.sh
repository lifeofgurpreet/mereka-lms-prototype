#!/usr/bin/env bash
# Verify repair-enterprise-schema.sh keeps destructive apply guardrails.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT_PATH="$REPO_ROOT/scripts/tenants/repair-enterprise-schema.sh"

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
  local pattern="$1"
  local message="$2"
  if grep -qE "$pattern" "$SCRIPT_PATH"; then
    pass "$message"
  else
    fail "$message"
  fi
}

echo "=== Enterprise Schema Repair Guardrails ==="
echo

if [[ ! -f "$SCRIPT_PATH" ]]; then
  fail "Missing script: scripts/tenants/repair-enterprise-schema.sh"
  echo
  echo "=== Summary ==="
  echo -e "${GREEN}PASS:${NC} $PASS | ${RED}FAIL:${NC} $FAIL"
  exit 1
fi

if [[ -x "$SCRIPT_PATH" ]]; then
  pass "Script is executable"
else
  fail "Script is not executable"
fi

require_pattern 'set -euo pipefail' 'Script uses strict bash mode'
require_pattern 'CONFIRM_REPAIR_ENTERPRISE_SCHEMA' 'Script requires explicit confirmation variable'
require_pattern 'CONFIRM_TOKEN="REPAIR_ENTERPRISE_SCHEMA"' 'Script uses explicit confirmation token'
require_pattern 'ALLOW_PROD_APPLY' 'Script has production apply guard variable'
require_pattern 'CREATE_PREOP_BACKUP' 'Script has pre-op backup control variable'
require_pattern 'velero backup create' 'Script includes Velero pre-op backup action'
require_pattern 'Refusing production --apply without ALLOW_PROD_APPLY=1' 'Script blocks prod apply without explicit override'
require_pattern 'Refusing --apply: set CONFIRM_REPAIR_ENTERPRISE_SCHEMA' 'Script blocks apply without confirmation token'

echo
echo "=== Summary ==="
echo -e "${GREEN}PASS:${NC} $PASS | ${RED}FAIL:${NC} $FAIL"

if [[ "$FAIL" -gt 0 ]]; then
  exit 1
fi

exit 0
