#!/usr/bin/env bash
# @covers AC-CI-014
# @spec: ci-cd-pipeline_spec.md
# Verify release orchestrator invocations propagate required confirmation/prod-apply guardrail env vars.
set -euo pipefail

REPO_ROOT="${REPO_ROOT_OVERRIDE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
CANONICAL_SCRIPT="$REPO_ROOT/scripts/infra/canonical-release.sh"
BUILD_WORKFLOW="$REPO_ROOT/.github/workflows/build-tutor-images.yml"
CREATE_RELEASE_SCRIPT="$REPO_ROOT/scripts/infra/create-release.sh"

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

echo "=== Release Invocation Guardrail Wiring ==="
echo

for file in "$CANONICAL_SCRIPT" "$BUILD_WORKFLOW" "$CREATE_RELEASE_SCRIPT"; do
  if [[ -f "$file" ]]; then
    pass "${file#$REPO_ROOT/} exists"
  else
    fail "Missing file: ${file#$REPO_ROOT/}"
  fi
done

if [[ -f "$CANONICAL_SCRIPT" ]]; then
  require_pattern "$CANONICAL_SCRIPT" 'CONFIRM_CANONICAL_RELEASE' 'canonical-release has wrapper apply confirmation variable'
  require_pattern "$CANONICAL_SCRIPT" 'CONFIRM_PUSH_CANONICAL_RELEASE' 'canonical-release has wrapper push confirmation variable'
  require_pattern "$CANONICAL_SCRIPT" 'ALLOW_PROD_APPLY' 'canonical-release has production apply guard variable'
  require_pattern "$CANONICAL_SCRIPT" 'CONFIRM_RELEASE_OPENEDX_GITOPS="RELEASE_OPENEDX_GITOPS"' 'canonical-release forwards release apply confirmation token'
  require_pattern "$CANONICAL_SCRIPT" 'CONFIRM_PUSH_RELEASE_OPENEDX_GITOPS="PUSH_RELEASE_OPENEDX_GITOPS"' 'canonical-release forwards release push confirmation token'
fi

if [[ -f "$BUILD_WORKFLOW" ]]; then
  require_pattern "$BUILD_WORKFLOW" 'CONFIRM_RELEASE_OPENEDX_GITOPS=RELEASE_OPENEDX_GITOPS' 'build workflow sets release apply confirmation token'
  require_pattern "$BUILD_WORKFLOW" 'CONFIRM_PUSH_RELEASE_OPENEDX_GITOPS=PUSH_RELEASE_OPENEDX_GITOPS' 'build workflow sets release push confirmation token'
  require_pattern "$BUILD_WORKFLOW" 'ALLOW_PROD_APPLY=' 'build workflow sets ALLOW_PROD_APPLY for release invocation'
fi

if [[ -f "$CREATE_RELEASE_SCRIPT" ]]; then
  require_pattern "$CREATE_RELEASE_SCRIPT" 'CONFIRM_RELEASE_OPENEDX_GITOPS=RELEASE_OPENEDX_GITOPS' 'create-release rollback snippet includes release apply confirmation token'
  require_pattern "$CREATE_RELEASE_SCRIPT" 'CONFIRM_PUSH_RELEASE_OPENEDX_GITOPS=PUSH_RELEASE_OPENEDX_GITOPS' 'create-release rollback snippet includes release push confirmation token'
fi

echo
echo "=== Summary ==="
echo -e "${GREEN}PASS:${NC} $PASS | ${RED}FAIL:${NC} $FAIL"

if [[ "$FAIL" -gt 0 ]]; then
  exit 1
fi

exit 0
