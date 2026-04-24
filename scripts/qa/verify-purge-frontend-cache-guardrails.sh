#!/usr/bin/env bash
# @covers AC-CI-014
# @spec: ci-cd-pipeline_spec.md
# Verify frontend cache purge script enforces explicit confirmation and prod safety controls.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TARGET_SCRIPT="$REPO_ROOT/scripts/infra/purge-frontend-theme-cache.sh"

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

echo "=== Purge Frontend Cache Guardrails ==="
echo

if [[ -f "$TARGET_SCRIPT" ]]; then
  pass "purge-frontend-theme-cache script exists"
else
  fail "Missing script: scripts/infra/purge-frontend-theme-cache.sh"
fi

if [[ -f "$TARGET_SCRIPT" ]]; then
  require_pattern "$TARGET_SCRIPT" 'set -euo pipefail' 'purge-frontend-theme-cache uses strict bash mode'
  require_pattern "$TARGET_SCRIPT" 'CONFIRM_PURGE_FRONTEND_THEME_CACHE' 'purge-frontend-theme-cache has apply confirmation variable'
  require_pattern "$TARGET_SCRIPT" 'CONFIRM_APPLY_TOKEN="PURGE_FRONTEND_THEME_CACHE"' 'purge-frontend-theme-cache has apply confirmation token'
  require_pattern "$TARGET_SCRIPT" 'ALLOW_PROD_APPLY' 'purge-frontend-theme-cache has prod apply guard variable'
  require_pattern "$TARGET_SCRIPT" 'CONFIRM_PURGE_EVERYTHING' 'purge-frontend-theme-cache has purge-everything confirmation variable'
  require_pattern "$TARGET_SCRIPT" 'CONFIRM_PURGE_EVERYTHING_TOKEN="PURGE_EVERYTHING"' 'purge-frontend-theme-cache has purge-everything token'
  require_pattern "$TARGET_SCRIPT" 'Refusing --apply without explicit confirmation token' 'purge-frontend-theme-cache blocks apply without confirmation token'
  require_pattern "$TARGET_SCRIPT" 'Refusing --apply on prod environment without ALLOW_PROD_APPLY=1' 'purge-frontend-theme-cache blocks prod apply without explicit override'
  require_pattern "$TARGET_SCRIPT" 'Refusing --purge-everything without explicit token' 'purge-frontend-theme-cache blocks full-zone purge without explicit token'
fi

echo
echo "=== Summary ==="
echo -e "${GREEN}PASS:${NC} $PASS | ${RED}FAIL:${NC} $FAIL"

if [[ "$FAIL" -gt 0 ]]; then
  exit 1
fi

exit 0
