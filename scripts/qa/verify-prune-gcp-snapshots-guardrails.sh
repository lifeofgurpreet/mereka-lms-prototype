#!/usr/bin/env bash
# @covers AC-CI-014
# @spec: ci-cd-pipeline_spec.md
# Verify prune-gcp-snapshots script enforces explicit confirmation and destructive-delete safety controls.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TARGET_SCRIPT="$REPO_ROOT/scripts/infra/prune-gcp-snapshots.sh"

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

echo "=== Prune GCP Snapshots Guardrails ==="
echo

if [[ -f "$TARGET_SCRIPT" ]]; then
  pass "prune-gcp-snapshots script exists"
else
  fail "Missing script: scripts/infra/prune-gcp-snapshots.sh"
fi

if [[ -f "$TARGET_SCRIPT" ]]; then
  require_pattern "$TARGET_SCRIPT" 'set -euo pipefail' 'prune-gcp-snapshots uses strict bash mode'
  require_pattern "$TARGET_SCRIPT" 'CONFIRM_PRUNE_GCP_SNAPSHOTS' 'prune-gcp-snapshots has confirmation variable'
  require_pattern "$TARGET_SCRIPT" 'CONFIRM_TOKEN="PRUNE_GCP_SNAPSHOTS"' 'prune-gcp-snapshots has explicit confirmation token'
  require_pattern "$TARGET_SCRIPT" 'ALLOW_PROD_APPLY' 'prune-gcp-snapshots has prod apply guard variable'
  require_pattern "$TARGET_SCRIPT" 'REQUIRE_MAX_DELETE' 'prune-gcp-snapshots has max-delete safety switch'
  require_pattern "$TARGET_SCRIPT" 'Refusing --apply without explicit confirmation token' 'prune-gcp-snapshots blocks apply without confirmation token'
  require_pattern "$TARGET_SCRIPT" "Refusing --apply on prod-like project" 'prune-gcp-snapshots blocks prod-like apply without explicit override'
  require_pattern "$TARGET_SCRIPT" 'Refusing --apply with REQUIRE_MAX_DELETE=1 unless --max-delete is set to a positive integer' 'prune-gcp-snapshots enforces explicit max-delete cap'
fi

echo
echo "=== Summary ==="
echo -e "${GREEN}PASS:${NC} $PASS | ${RED}FAIL:${NC} $FAIL"

if [[ "$FAIL" -gt 0 ]]; then
  exit 1
fi

exit 0
