#!/usr/bin/env bash
# @covers AC-012, AC-015, AC-016, AC-017, AC-018
# @spec: ci-cd-pipeline_spec.md
# Verify build-tutor-images.yml workflow configuration for GitOps safety gates
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
PASS=0; FAIL=0; SKIP=0

pass() { echo -e "${GREEN}PASS${NC} $1"; PASS=$((PASS + 1)); }
fail() { echo -e "${RED}FAIL${NC} $1"; FAIL=$((FAIL + 1)); }
skip() { echo -e "${YELLOW}SKIP${NC} $1"; SKIP=$((SKIP + 1)); }

WORKFLOW=".github/workflows/build-tutor-images.yml"

if [[ ! -f "$WORKFLOW" ]]; then
  fail "AC-012: Workflow file $WORKFLOW not found"
  echo ""
  echo "=== Summary ==="
  echo -e "${GREEN}PASS:${NC} $PASS | ${RED}FAIL:${NC} $FAIL | ${YELLOW}SKIP:${NC} $SKIP"
  exit 1
fi

echo "Checking $WORKFLOW for GitOps safety gates..."
echo ""

# AC-012: Manual dispatch with custom image_tag tags image correctly
if grep -q "workflow_dispatch:" "$WORKFLOW" && \
   grep -A 30 "workflow_dispatch:" "$WORKFLOW" | grep -q "image_tag:"; then
  pass "AC-012: workflow_dispatch has image_tag input for custom tags"
else
  fail "AC-012: workflow_dispatch missing image_tag input"
fi

# AC-015: GitOps with target_environment=select-environment fails (requires explicit env)
if grep -q "target_environment:" "$WORKFLOW" && \
   grep -A 10 "target_environment:" "$WORKFLOW" | grep -q "select-environment"; then

  # Check for validation logic that rejects select-environment
  if grep -q 'target_environment.*==.*select-environment' "$WORKFLOW" && \
     grep -A 3 'target_environment.*==.*select-environment' "$WORKFLOW" | grep -q 'exit 1'; then
    pass "AC-015: Validation rejects target_environment=select-environment"
  else
    fail "AC-015: Missing validation to reject select-environment"
  fi
else
  fail "AC-015: target_environment input not found or missing select-environment option"
fi

# AC-016: GitOps with target_environment=staging fails unless ENABLE_STAGING_ENV=true
if grep -q 'ENABLE_STAGING_ENV' "$WORKFLOW"; then
  if grep -q 'target_environment.*staging' "$WORKFLOW" && \
     grep -A 5 'target_environment.*staging' "$WORKFLOW" | grep -q 'ENABLE_STAGING_ENV'; then
    pass "AC-016: Staging deployment guarded by ENABLE_STAGING_ENV check"
  else
    fail "AC-016: Staging guard logic incomplete"
  fi
else
  fail "AC-016: ENABLE_STAGING_ENV check not found"
fi

# AC-017: deploy_to_staging input rejected with deprecation error
if grep -q "deploy_to_staging:" "$WORKFLOW" && \
   grep -A 2 "deploy_to_staging:" "$WORKFLOW" | grep -q "DEPRECATED"; then

  # Check for validation that rejects it
  if grep -q 'deploy_to_staging.*==.*true' "$WORKFLOW" && \
     grep -A 3 'deploy_to_staging.*==.*true' "$WORKFLOW" | grep -q 'deprecated'; then
    pass "AC-017: deploy_to_staging input marked deprecated and rejected"
  else
    fail "AC-017: deploy_to_staging deprecation warning exists but no rejection logic"
  fi
else
  fail "AC-017: deploy_to_staging input not found or not marked deprecated"
fi

# AC-018: GitOps fails if build_openedx or build_mfe is false (need both for digests)
if grep -q 'build_openedx.*!=.*true.*build_mfe.*!=.*true' "$WORKFLOW" || \
   grep -q 'build_mfe.*!=.*true.*build_openedx.*!=.*true' "$WORKFLOW"; then
  pass "AC-018: Validation requires both build_openedx and build_mfe for GitOps"
else
  # Try alternate pattern checking
  if grep -q 'build_openedx' "$WORKFLOW" && grep -q 'build_mfe' "$WORKFLOW" && \
     grep -A 10 'update_gitops' "$WORKFLOW" | grep -E '(build_openedx|build_mfe).*true'; then
    pass "AC-018: Digest requirement logic found (alternate pattern)"
  else
    fail "AC-018: Missing validation that both images are required for GitOps"
  fi
fi

echo ""
echo "=== Summary ==="
echo -e "${GREEN}PASS:${NC} $PASS | ${RED}FAIL:${NC} $FAIL | ${YELLOW}SKIP:${NC} $SKIP"
[ "$FAIL" -gt 0 ] && exit 1 || exit 0
