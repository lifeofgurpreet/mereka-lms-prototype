#!/usr/bin/env bash
# @covers AC-CI-020
# @spec: ci-cd-pipeline_spec.md
#
# Enforce that deployment flows keep post-deploy health gate wiring intact.
set -euo pipefail

REPO_ROOT="${REPO_ROOT_OVERRIDE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

POST_DEPLOY_WORKFLOW="$REPO_ROOT/.github/workflows/post-deploy-e2e.yml"
OPERATIONS_GATES_WORKFLOW="$REPO_ROOT/.github/workflows/operations-gates-runtime.yml"
BUILD_WORKFLOW="$REPO_ROOT/.github/workflows/build-tutor-images.yml"
RUNTIME_PROOF_POLICY="$REPO_ROOT/config/runtime-proof-policy.env"

PASS=0
FAIL=0

pass() {
  echo "PASS $1"
  PASS=$((PASS + 1))
}

fail() {
  echo "FAIL $1"
  FAIL=$((FAIL + 1))
}

require_file() {
  local file="$1"
  if [[ -f "$file" ]]; then
    pass "workflow exists: ${file#$REPO_ROOT/}"
  else
    fail "missing workflow: ${file#$REPO_ROOT/}"
  fi
}

require_pattern() {
  local file="$1"
  local pattern="$2"
  local message="$3"
  if grep -Fq -- "$pattern" "$file"; then
    pass "$message"
  else
    fail "$message"
  fi
}

require_file "$POST_DEPLOY_WORKFLOW"
require_file "$OPERATIONS_GATES_WORKFLOW"
require_file "$BUILD_WORKFLOW"
require_file "$RUNTIME_PROOF_POLICY"

if [[ -f "$POST_DEPLOY_WORKFLOW" ]]; then
  require_pattern \
    "$POST_DEPLOY_WORKFLOW" \
    "scripts/qa/verify-post-deploy-gate.sh --mode offline" \
    "post-deploy workflow includes structural gate fallback"
  require_pattern \
    "$POST_DEPLOY_WORKFLOW" \
    "needs.gate-check.outputs.status_context" \
    "post-deploy workflow publishes dynamic commit status context"
  require_pattern \
    "$POST_DEPLOY_WORKFLOW" \
    "verify-prod-parked-state.sh" \
    "post-deploy workflow verifies parked production state"
fi

if [[ -f "$OPERATIONS_GATES_WORKFLOW" ]]; then
  require_pattern \
    "$OPERATIONS_GATES_WORKFLOW" \
    "./scripts/qa/run-operations-gates.sh --env" \
    "operations runtime workflow executes consolidated operations gates"
fi

if [[ -f "$BUILD_WORKFLOW" ]]; then
  require_pattern \
    "$BUILD_WORKFLOW" \
    "--verify-runtime" \
    "image release workflow keeps runtime verification flag"
fi

echo "Summary: PASS=$PASS FAIL=$FAIL"
if [[ "$FAIL" -gt 0 ]]; then
  exit 1
fi
