#!/usr/bin/env bash
# @covers AC-CI-RELEASE-001
# @spec: ci-cd-pipeline_spec.md
#
# Verify release workflow can be invoked:
#   - release.yml exists with workflow_dispatch trigger
#   - canonical-release.sh exists and is executable
#   - release-openedx-gitops.sh exists and is executable
#   - create-release.sh exists and is executable as the tag helper
#   - Release process doc exists
set -euo pipefail

REPO_ROOT="${REPO_ROOT_OVERRIDE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
RELEASE_WF="$REPO_ROOT/.github/workflows/release.yml"
CANONICAL_RELEASE_SCRIPT="$REPO_ROOT/scripts/infra/canonical-release.sh"
PROMOTION_SCRIPT="$REPO_ROOT/scripts/infra/release-openedx-gitops.sh"
RELEASE_SCRIPT="$REPO_ROOT/scripts/infra/create-release.sh"
RELEASE_DOC="$REPO_ROOT/docs/reference/operations/RELEASE_PROCESS.md"

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

# Canonical release script
if [[ -f "$CANONICAL_RELEASE_SCRIPT" ]]; then
  pass "canonical-release.sh exists"
  if [[ -x "$CANONICAL_RELEASE_SCRIPT" ]]; then
    pass "canonical-release.sh is executable"
  else
    fail "canonical-release.sh is not executable"
  fi
else
  fail "canonical-release.sh not found"
fi

if [[ -f "$PROMOTION_SCRIPT" ]]; then
  pass "release-openedx-gitops.sh exists"
  if [[ -x "$PROMOTION_SCRIPT" ]]; then
    pass "release-openedx-gitops.sh is executable"
  else
    fail "release-openedx-gitops.sh is not executable"
  fi
else
  fail "release-openedx-gitops.sh not found"
fi

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
