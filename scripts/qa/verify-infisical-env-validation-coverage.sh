#!/usr/bin/env bash
# @covers AC-INT-003
# @spec: ci-cd-pipeline_spec.md
#
# Ensure CI validates Infisical secrets for prod/dev and conditionally staging.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WORKFLOW_FILE="$REPO_ROOT/.github/workflows/ci.yml"

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

if [[ ! -f "$WORKFLOW_FILE" ]]; then
  echo "FAIL missing workflow: $WORKFLOW_FILE"
  exit 1
fi
pass "workflow exists: .github/workflows/ci.yml"

if grep -Fq "name: Validate Infisical secrets" "$WORKFLOW_FILE"; then
  pass "ci.yml includes Validate Infisical secrets step"
else
  fail "ci.yml missing Validate Infisical secrets step"
fi

if grep -Fq "STRICT=1 INFISICAL_ENV=prod ./scripts/infra/infisical-validate-mereka-lms.sh" "$WORKFLOW_FILE"; then
  pass "prod Infisical validation command present"
else
  fail "prod Infisical validation command missing"
fi

if grep -Fq "STRICT=1 INFISICAL_ENV=dev  ./scripts/infra/infisical-validate-mereka-lms.sh" "$WORKFLOW_FILE"; then
  pass "dev Infisical validation command present"
else
  fail "dev Infisical validation command missing"
fi

if grep -Fq "ENABLE_STAGING_ENV: \${{ vars.ENABLE_STAGING_ENV }}" "$WORKFLOW_FILE"; then
  pass "ENABLE_STAGING_ENV workflow env wiring present"
else
  fail "ENABLE_STAGING_ENV workflow env wiring missing"
fi

if grep -Fq 'if [[ "${ENABLE_STAGING_ENV:-false}" == "true" ]]; then' "$WORKFLOW_FILE"; then
  pass "staging validation guard present"
else
  fail "staging validation guard missing"
fi

if grep -Fq "STRICT=1 INFISICAL_ENV=staging ./scripts/infra/infisical-validate-mereka-lms.sh" "$WORKFLOW_FILE"; then
  pass "staging Infisical validation command present"
else
  fail "staging Infisical validation command missing"
fi

echo "Summary: PASS=$PASS FAIL=$FAIL"
if [[ "$FAIL" -gt 0 ]]; then
  exit 1
fi

