#!/usr/bin/env bash
# @covers AC-CI-014
# @spec: ci-cd-pipeline_spec.md
# Verify release-openedx-gitops write modes enforce explicit confirmation and production safety controls.
set -euo pipefail

REPO_ROOT="${REPO_ROOT_OVERRIDE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
TARGET_SCRIPT="$REPO_ROOT/scripts/infra/release-openedx-gitops.sh"

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

echo "=== Release GitOps Guardrails ==="
echo

if [[ -f "$TARGET_SCRIPT" ]]; then
  pass "release-openedx-gitops script exists"
else
  fail "Missing script: scripts/infra/release-openedx-gitops.sh"
fi

if [[ -f "$TARGET_SCRIPT" ]]; then
  require_pattern "$TARGET_SCRIPT" 'set -euo pipefail' 'release-openedx-gitops uses strict bash mode'
  require_pattern "$TARGET_SCRIPT" 'CONFIRM_RELEASE_OPENEDX_GITOPS' 'release-openedx-gitops has apply confirmation variable'
  require_pattern "$TARGET_SCRIPT" 'CONFIRM_APPLY_TOKEN="RELEASE_OPENEDX_GITOPS"' 'release-openedx-gitops has apply confirmation token'
  require_pattern "$TARGET_SCRIPT" 'CONFIRM_PUSH_RELEASE_OPENEDX_GITOPS' 'release-openedx-gitops has push confirmation variable'
  require_pattern "$TARGET_SCRIPT" 'CONFIRM_PUSH_TOKEN="PUSH_RELEASE_OPENEDX_GITOPS"' 'release-openedx-gitops has push confirmation token'
  require_pattern "$TARGET_SCRIPT" 'ALLOW_PROD_APPLY' 'release-openedx-gitops has production apply guard variable'
  require_pattern "$TARGET_SCRIPT" 'Refusing --apply without explicit confirmation token' 'release-openedx-gitops blocks apply without confirmation token'
  require_pattern "$TARGET_SCRIPT" 'Refusing --push without explicit confirmation token' 'release-openedx-gitops blocks push without confirmation token'
  require_pattern "$TARGET_SCRIPT" 'Refusing production --apply without ALLOW_PROD_APPLY=1' 'release-openedx-gitops blocks production apply without explicit override'
  require_pattern "$TARGET_SCRIPT" 'Push rejected for \$repo; rebasing onto' 'release-openedx-gitops logs push-retry rebase path'
  require_pattern "$TARGET_SCRIPT" 'rebase --autostash' 'release-openedx-gitops uses autostash when retrying dirty push state'
fi

echo
echo "=== Summary ==="
echo -e "${GREEN}PASS:${NC} $PASS | ${RED}FAIL:${NC} $FAIL"

if [[ "$FAIL" -gt 0 ]]; then
  exit 1
fi

exit 0
