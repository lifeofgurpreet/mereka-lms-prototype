#!/usr/bin/env bash
# @covers AC-CI-014
# @spec: ci-cd-pipeline_spec.md
# Verify provision-mysql-app-dbs script enforces explicit confirmation and prod safety controls.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TARGET_SCRIPT="$REPO_ROOT/scripts/infra/provision-mysql-app-dbs.sh"

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

echo "=== Provision MySQL App DBs Guardrails ==="
echo

if [[ -f "$TARGET_SCRIPT" ]]; then
  pass "provision-mysql-app-dbs script exists"
else
  fail "Missing script: scripts/infra/provision-mysql-app-dbs.sh"
fi

if [[ -f "$TARGET_SCRIPT" ]]; then
  require_pattern "$TARGET_SCRIPT" 'set -euo pipefail' 'provision-mysql-app-dbs uses strict bash mode'
  require_pattern "$TARGET_SCRIPT" 'CONFIRM_PROVISION_MYSQL_APP_DBS' 'provision-mysql-app-dbs has confirmation variable'
  require_pattern "$TARGET_SCRIPT" 'CONFIRM_TOKEN="PROVISION_MYSQL_APP_DBS"' 'provision-mysql-app-dbs has explicit confirmation token'
  require_pattern "$TARGET_SCRIPT" 'ALLOW_PROD_APPLY' 'provision-mysql-app-dbs has prod apply guard variable'
  require_pattern "$TARGET_SCRIPT" 'CREATE_PREOP_BACKUP' 'provision-mysql-app-dbs has pre-op backup control variable'
  require_pattern "$TARGET_SCRIPT" 'Refusing live mutation without explicit confirmation token' 'provision-mysql-app-dbs blocks mutation without confirmation token'
  require_pattern "$TARGET_SCRIPT" "Refusing live mutation on prod-like context" 'provision-mysql-app-dbs blocks prod-like mutation without explicit override'
  require_pattern "$TARGET_SCRIPT" 'velero backup create' 'provision-mysql-app-dbs includes Velero pre-op backup action'
fi

echo
echo "=== Summary ==="
echo -e "${GREEN}PASS:${NC} $PASS | ${RED}FAIL:${NC} $FAIL"

if [[ "$FAIL" -gt 0 ]]; then
  exit 1
fi

exit 0
