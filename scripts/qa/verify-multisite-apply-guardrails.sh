#!/usr/bin/env bash
# @covers AC-CI-014
# @spec: ci-cd-pipeline_spec.md
# Verify apply-multisite-config script enforces explicit confirmation and prod safety controls.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TARGET_SCRIPT="$REPO_ROOT/scripts/infra/apply-multisite-config.sh"

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

echo "=== Multisite Apply Guardrails ==="
echo

if [[ -f "$TARGET_SCRIPT" ]]; then
  pass "apply-multisite-config script exists"
else
  fail "Missing script: scripts/infra/apply-multisite-config.sh"
fi

if [[ -f "$TARGET_SCRIPT" ]]; then
  require_pattern "$TARGET_SCRIPT" 'set -euo pipefail' 'apply-multisite-config uses strict bash mode'
  require_pattern "$TARGET_SCRIPT" 'CONFIRM_APPLY_MULTISITE_CONFIG' 'apply-multisite-config has confirmation variable'
  require_pattern "$TARGET_SCRIPT" 'CONFIRM_TOKEN="APPLY_MULTISITE_CONFIG"' 'apply-multisite-config has explicit confirmation token'
  require_pattern "$TARGET_SCRIPT" 'ALLOW_PROD_APPLY' 'apply-multisite-config has prod apply guard variable'
  require_pattern "$TARGET_SCRIPT" 'CREATE_PREOP_BACKUP' 'apply-multisite-config has pre-op backup control variable'
  require_pattern "$TARGET_SCRIPT" 'require_bool_01 "ALLOW_PROD_APPLY"' 'apply-multisite-config validates ALLOW_PROD_APPLY'
  require_pattern "$TARGET_SCRIPT" 'require_bool_01 "CREATE_PREOP_BACKUP"' 'apply-multisite-config validates CREATE_PREOP_BACKUP'
  require_pattern "$TARGET_SCRIPT" 'is_prod_like_context' 'apply-multisite-config detects prod-like contexts'
  require_pattern "$TARGET_SCRIPT" 'Refusing --apply without explicit confirmation token' 'apply-multisite-config blocks apply without confirmation token'
  require_pattern "$TARGET_SCRIPT" 'Refusing --apply on prod-like context' 'apply-multisite-config blocks prod-like apply without explicit override'
  require_pattern "$TARGET_SCRIPT" 'velero backup create' 'apply-multisite-config includes Velero pre-op backup action'
  require_pattern "$TARGET_SCRIPT" 'require_cmd velero' 'apply-multisite-config checks Velero availability for prod-like apply'
  require_pattern "$TARGET_SCRIPT" 'Creating Velero pre-op backup' 'apply-multisite-config logs pre-op backup creation'
fi

echo
echo "=== Summary ==="
echo -e "${GREEN}PASS:${NC} $PASS | ${RED}FAIL:${NC} $FAIL"

if [[ "$FAIL" -gt 0 ]]; then
  exit 1
fi

exit 0
