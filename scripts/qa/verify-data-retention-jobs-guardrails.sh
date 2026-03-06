#!/usr/bin/env bash
# @covers AC-CI-014
# @spec: ci-cd-pipeline_spec.md
# Verify data-retention-jobs apply path enforces explicit confirmation and prod safety controls.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TARGET_SCRIPT="$REPO_ROOT/scripts/infra/data-retention-jobs.sh"

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

echo "=== Data Retention Jobs Guardrails ==="
echo

if [[ -f "$TARGET_SCRIPT" ]]; then
  pass "data-retention-jobs script exists"
else
  fail "Missing script: scripts/infra/data-retention-jobs.sh"
fi

if [[ -f "$TARGET_SCRIPT" ]]; then
  require_pattern "$TARGET_SCRIPT" 'set -euo pipefail' 'data-retention-jobs uses strict bash mode'
  require_pattern "$TARGET_SCRIPT" 'CONFIRM_APPLY_DATA_RETENTION_JOBS' 'data-retention-jobs has confirmation variable'
  require_pattern "$TARGET_SCRIPT" 'CONFIRM_TOKEN="APPLY_DATA_RETENTION_JOBS"' 'data-retention-jobs has explicit confirmation token'
  require_pattern "$TARGET_SCRIPT" 'ALLOW_PROD_APPLY' 'data-retention-jobs has prod apply guard variable'
  require_pattern "$TARGET_SCRIPT" 'CREATE_PREOP_BACKUP' 'data-retention-jobs has pre-op backup control variable'
  require_pattern "$TARGET_SCRIPT" 'Refusing --apply without explicit confirmation token' 'data-retention-jobs blocks apply without confirmation token'
  require_pattern "$TARGET_SCRIPT" 'Refusing --apply on prod-like context' 'data-retention-jobs blocks prod-like apply without explicit override'
  require_pattern "$TARGET_SCRIPT" 'velero backup create' 'data-retention-jobs includes Velero pre-op backup action'
fi

echo
echo "=== Summary ==="
echo -e "${GREEN}PASS:${NC} $PASS | ${RED}FAIL:${NC} $FAIL"

if [[ "$FAIL" -gt 0 ]]; then
  exit 1
fi

exit 0
