#!/usr/bin/env bash
# @covers AC-CI-014
# @spec: ci-cd-pipeline_spec.md
# Verify MySQL user repair scripts enforce explicit confirmation and prod safety controls.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
GKE_SCRIPT="$REPO_ROOT/scripts/infra/repair-gke-mysql-users.sh"
KIND_SCRIPT="$REPO_ROOT/scripts/infra/repair-kind-mysql-users.sh"

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

echo "=== MySQL User Repair Guardrails ==="
echo

for script in "$GKE_SCRIPT" "$KIND_SCRIPT"; do
  if [[ -f "$script" ]]; then
    pass "$(basename "$script") exists"
    require_pattern "$script" 'set -euo pipefail' "$(basename "$script") uses strict bash mode"
    require_pattern "$script" 'ALLOW_PROD_APPLY' "$(basename "$script") has prod apply guard variable"
    require_pattern "$script" 'CREATE_PREOP_BACKUP' "$(basename "$script") has pre-op backup control variable"
    require_pattern "$script" 'Refusing live mutation without explicit confirmation token' "$(basename "$script") blocks mutation without confirmation token"
    require_pattern "$script" 'Refusing live mutation on prod-like context' "$(basename "$script") blocks prod-like mutation without explicit override"
    require_pattern "$script" 'velero backup create' "$(basename "$script") includes Velero pre-op backup action"
  else
    fail "Missing script: ${script#$REPO_ROOT/}"
  fi
done

if [[ -f "$GKE_SCRIPT" ]]; then
  require_pattern "$GKE_SCRIPT" 'CONFIRM_REPAIR_GKE_MYSQL_USERS' 'gke repair script has confirmation variable'
  require_pattern "$GKE_SCRIPT" 'CONFIRM_TOKEN="REPAIR_GKE_MYSQL_USERS"' 'gke repair script has explicit confirmation token'
fi

if [[ -f "$KIND_SCRIPT" ]]; then
  require_pattern "$KIND_SCRIPT" 'CONFIRM_REPAIR_KIND_MYSQL_USERS' 'kind repair script has confirmation variable'
  require_pattern "$KIND_SCRIPT" 'CONFIRM_TOKEN="REPAIR_KIND_MYSQL_USERS"' 'kind repair script has explicit confirmation token'
fi

echo
echo "=== Summary ==="
echo -e "${GREEN}PASS:${NC} $PASS | ${RED}FAIL:${NC} $FAIL"

if [[ "$FAIL" -gt 0 ]]; then
  exit 1
fi

exit 0
