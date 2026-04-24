#!/usr/bin/env bash
# @covers AC-CI-014
# @spec: ci-cd-pipeline_spec.md
# Verify ensure-studio-sso-canary apply path enforces explicit confirmation and prod safety controls.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TARGET_SCRIPT="$REPO_ROOT/scripts/infra/ensure-studio-sso-canary.sh"

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

echo "=== Studio SSO Canary Guardrails ==="
echo

if [[ -f "$TARGET_SCRIPT" ]]; then
  pass "ensure-studio-sso-canary script exists"
else
  fail "Missing script: scripts/infra/ensure-studio-sso-canary.sh"
fi

if [[ -f "$TARGET_SCRIPT" ]]; then
  require_pattern "$TARGET_SCRIPT" 'set -euo pipefail' 'ensure-studio-sso-canary uses strict bash mode'
  require_pattern "$TARGET_SCRIPT" 'CONFIRM_ENSURE_STUDIO_SSO_CANARY' 'ensure-studio-sso-canary has confirmation variable'
  require_pattern "$TARGET_SCRIPT" 'CONFIRM_TOKEN="ENSURE_STUDIO_SSO_CANARY"' 'ensure-studio-sso-canary has explicit confirmation token'
  require_pattern "$TARGET_SCRIPT" 'ALLOW_PROD_APPLY' 'ensure-studio-sso-canary has prod apply guard variable'
  require_pattern "$TARGET_SCRIPT" 'CREATE_PREOP_BACKUP' 'ensure-studio-sso-canary has pre-op backup control variable'
  require_pattern "$TARGET_SCRIPT" 'Refusing --apply without explicit confirmation token' 'ensure-studio-sso-canary blocks apply without confirmation token'
  require_pattern "$TARGET_SCRIPT" 'Refusing --apply on prod-like context' 'ensure-studio-sso-canary blocks prod-like apply without explicit override'
  require_pattern "$TARGET_SCRIPT" 'velero backup create' 'ensure-studio-sso-canary includes Velero pre-op backup action'
fi

echo
echo "=== Summary ==="
echo -e "${GREEN}PASS:${NC} $PASS | ${RED}FAIL:${NC} $FAIL"

if [[ "$FAIL" -gt 0 ]]; then
  exit 1
fi

exit 0
