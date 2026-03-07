#!/usr/bin/env bash
# @covers AC-020, AC-021
# @spec: ci-cd-pipeline_spec.md
#
# Verify that release.yml is wired to call the GitOps promotion script
# after a successful GitHub Release is created, with required safety gates:
#   - promote-to-production job exists and runs after create-github-release
#   - Uses a production environment for manual approval gating
#   - Verifies images exist in registry before promoting (image existence gate)
#   - Calls release-openedx-gitops.sh with --target-env production
#   - Passes --require-digests to enforce immutable image pins
#   - Passes --apply --commit --push flags
#   - Permissions are scoped (contents: write for GitOps commit)
set -euo pipefail

REPO_ROOT="${REPO_ROOT_OVERRIDE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
RELEASE_WF="$REPO_ROOT/.github/workflows/release.yml"

PASS=0
FAIL=0

pass() { echo "  PASS  $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL  $1"; FAIL=$((FAIL + 1)); }

echo "=== Release Promotion Wiring Contract ==="
echo ""

if [[ ! -f "$RELEASE_WF" ]]; then
  fail "release.yml not found"
  echo ""
  echo "=== Results: $PASS PASS / $FAIL FAIL ==="
  exit 1
fi
pass "release.yml exists"

# Promotion job exists
if grep -qE "promote-to-production|promote_to_production" "$RELEASE_WF"; then
  pass "release.yml has promote-to-production job"
else
  fail "release.yml missing promote-to-production job"
fi

# Job runs after create-github-release
if grep -qE "needs:.*create-github-release|needs:.*create_github_release" "$RELEASE_WF"; then
  pass "promote-to-production depends on create-github-release"
else
  fail "promote-to-production missing needs: create-github-release"
fi

# Uses production environment for manual approval
if grep -qE "environment:.*production" "$RELEASE_WF"; then
  pass "release.yml promotion job uses production environment"
else
  fail "release.yml promotion job missing environment: production (required for manual approval gate)"
fi

# Image existence gate before promoting
if grep -q "image.*exist\|verify.*image\|registry.*check\|docker.*manifest\|resolve.*digest\|resolve-image-digest" "$RELEASE_WF"; then
  pass "release.yml has image existence verification gate"
else
  fail "release.yml missing image existence gate before promotion"
fi

# Calls the GitOps script
if grep -q "release-openedx-gitops.sh" "$RELEASE_WF"; then
  pass "release.yml calls release-openedx-gitops.sh"
else
  fail "release.yml does not call release-openedx-gitops.sh"
fi

# Passes --target-env production
if grep -q -- '--target-env.*production\|target-env.*production' "$RELEASE_WF"; then
  pass "release.yml passes --target-env production to release orchestrator"
else
  fail "release.yml missing --target-env production in release orchestrator call"
fi

# Passes --require-digests for immutability
if grep -q -- '--require-digests' "$RELEASE_WF"; then
  pass "release.yml passes --require-digests to enforce immutable image pins"
else
  fail "release.yml missing --require-digests (production promotion must pin digest)"
fi

# Passes --apply --commit --push
if grep -q -- '--apply' "$RELEASE_WF" && grep -q -- '--commit' "$RELEASE_WF" && grep -q -- '--push' "$RELEASE_WF"; then
  pass "release.yml passes --apply --commit --push to release orchestrator"
else
  fail "release.yml missing --apply, --commit, or --push in release orchestrator call"
fi

# Checks out bbi-infrastructure (GitOps repo)
if grep -q "bbi-infrastructure" "$RELEASE_WF"; then
  pass "release.yml checks out bbi-infrastructure GitOps repo"
else
  fail "release.yml missing bbi-infrastructure checkout (GitOps repo required for promotion)"
fi

# GITOPS_PAT secret used for cross-repo write
if grep -q "GITOPS_PAT" "$RELEASE_WF"; then
  pass "release.yml uses GITOPS_PAT secret for cross-repo write"
else
  fail "release.yml missing GITOPS_PAT secret (required for bbi-infrastructure write access)"
fi

# contents: write permission in promotion job scope
if grep -q "contents: write" "$RELEASE_WF"; then
  pass "release.yml has contents: write permission"
else
  fail "release.yml missing contents: write permission"
fi

echo ""
echo "=== Results: $PASS PASS / $FAIL FAIL ==="
[[ $FAIL -gt 0 ]] && exit 1
exit 0
