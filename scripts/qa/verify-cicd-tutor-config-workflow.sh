#!/usr/bin/env bash
# @covers AC-031, AC-032, AC-033, AC-034
# @spec: ci-cd-pipeline_spec.md
# Verify tutor-config-verify.yml workflow for patch validation
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
PASS=0; FAIL=0; SKIP=0

pass() { echo -e "${GREEN}PASS${NC} $1"; PASS=$((PASS + 1)); }
fail() { echo -e "${RED}FAIL${NC} $1"; FAIL=$((FAIL + 1)); }
skip() { echo -e "${YELLOW}SKIP${NC} $1"; SKIP=$((SKIP + 1)); }

WORKFLOW=".github/workflows/tutor-config-verify.yml"

if [[ ! -f "$WORKFLOW" ]]; then
  fail "AC-031: Workflow file $WORKFLOW not found"
  echo ""
  echo "=== Summary ==="
  echo -e "${GREEN}PASS:${NC} $PASS | ${RED}FAIL:${NC} $FAIL | ${YELLOW}SKIP:${NC} $SKIP"
  exit 1
fi

echo "Checking $WORKFLOW for Tutor configuration verification..."
echo ""

# AC-031: Workflow succeeds when all patches applied
if grep -q "apply-patches.sh" "$WORKFLOW" || grep -q "verify-tutor-config.sh" "$WORKFLOW"; then
  if grep -Eq "Verify (MySQL|MFE|Node)" "$WORKFLOW"; then
    pass "AC-031: tutor-config-verify.yml runs apply-patches.sh and verifies patches"
  else
    fail "AC-031: Workflow runs patches but missing verification checks"
  fi
else
  fail "AC-031: Workflow missing apply-patches.sh or verify-tutor-config.sh step"
fi

# AC-032: Tutor config verification fails with specific error identifying missing patch
has_mysql_check=0
has_mfe_check=0
has_error_output=0

if grep -q "mysql_native_password" "$WORKFLOW"; then
  has_mysql_check=1
fi

if grep -q "NODE_OPTIONS.*6144" "$WORKFLOW" || grep -q "MFE.*Node" "$WORKFLOW"; then
  has_mfe_check=1
fi

if grep -E "(FAILED|exit 1)" "$WORKFLOW" | grep -q "AC-"; then
  has_error_output=1
fi

if [[ $has_mysql_check -eq 1 && $has_mfe_check -eq 1 && $has_error_output -eq 1 ]]; then
  pass "AC-032: Workflow fails with specific error identifying missing patches"
elif [[ $has_mysql_check -eq 0 || $has_mfe_check -eq 0 ]]; then
  fail "AC-032: Workflow missing patch-specific verification checks"
else
  fail "AC-032: Workflow has checks but missing error output pattern"
fi

# AC-033: Patch idempotency: applying twice produces identical checksums
if grep -q "idempotency" "$WORKFLOW" || grep -A 20 "Apply patches" "$WORKFLOW" | grep -q "sha256sum"; then
  if grep -A 30 "idempotency\|Apply patches.*time" "$WORKFLOW" | grep -q "diff.*checksums"; then
    pass "AC-033: Workflow includes idempotency test with checksums"
  else
    fail "AC-033: Workflow has checksum logic but missing diff check"
  fi
else
  fail "AC-033: Workflow missing idempotency verification"
fi

# AC-034: Tutor config failure posts comment with remediation steps
if grep -q "post.*comment\|github-script" "$WORKFLOW"; then
  # Check if comment step runs on failure
  if grep -A 5 "post.*comment\|github-script" "$WORKFLOW" | grep -q "if:.*failure()"; then
    # Check if comment includes remediation
    if grep -A 20 "github-script\|createComment" "$WORKFLOW" | grep -Eq "(apply-patches|How to Fix|validate-tutor-config)"; then
      pass "AC-034: Workflow posts remediation comment on failure"
    else
      fail "AC-034: Workflow posts comment but missing remediation steps"
    fi
  else
    fail "AC-034: Workflow has comment step but not conditional on failure"
  fi
else
  fail "AC-034: Workflow missing PR comment step"
fi

echo ""
echo "=== Summary ==="
echo -e "${GREEN}PASS:${NC} $PASS | ${RED}FAIL:${NC} $FAIL | ${YELLOW}SKIP:${NC} $SKIP"
[ "$FAIL" -gt 0 ] && exit 1 || exit 0
