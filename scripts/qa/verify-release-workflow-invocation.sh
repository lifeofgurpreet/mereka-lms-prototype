#!/usr/bin/env bash
# @covers AC-CI-RELEASE-001
# @spec: ci-cd-pipeline_spec.md
#
# Verify release workflow can be invoked:
#   - release.yml exists with workflow_dispatch trigger
#   - create-release.sh exists and is executable
#   - Release process doc exists
set -euo pipefail

REPO_ROOT="${REPO_ROOT_OVERRIDE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
RELEASE_WF="$REPO_ROOT/.github/workflows/release.yml"
RELEASE_SCRIPT="$REPO_ROOT/scripts/infra/create-release.sh"
RELEASE_DOC="$REPO_ROOT/docs/operations/RELEASE_PROCESS.md"

PASS=0 FAIL=0

pass() { echo "  PASS  $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL  $1"; FAIL=$((FAIL + 1)); }

echo "=== Release Workflow Invocation Contract ==="

# Release workflow
if [[ -f "$RELEASE_WF" ]]; then
  pass "release.yml exists"
  if grep -qE "workflow_dispatch|push:" "$RELEASE_WF"; then
    pass "release.yml has trigger (workflow_dispatch or tag push)"
  else
    fail "release.yml missing trigger"
  fi
else
  fail "release.yml not found"
fi

# Release script
if [[ -f "$RELEASE_SCRIPT" ]]; then
  pass "create-release.sh exists"
  if [[ -x "$RELEASE_SCRIPT" ]]; then
    pass "create-release.sh is executable"
  else
    fail "create-release.sh is not executable"
  fi
else
  fail "create-release.sh not found"
fi

# Release documentation
if [[ -f "$RELEASE_DOC" ]]; then
  pass "RELEASE_PROCESS.md exists"
else
  fail "RELEASE_PROCESS.md not found"
fi

echo ""
echo "=== Results: $PASS PASS / $FAIL FAIL ==="
[[ $FAIL -gt 0 ]] && exit 1
exit 0
