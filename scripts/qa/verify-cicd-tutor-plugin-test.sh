#!/usr/bin/env bash
# @covers AC-035, AC-036, AC-037, AC-038, AC-039
# @spec: ci-cd-pipeline_spec.md
# Verify tutor-plugin-test.yml workflow for plugin lifecycle testing
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
PASS=0; FAIL=0; SKIP=0

pass() { echo -e "${GREEN}PASS${NC} $1"; PASS=$((PASS + 1)); }
fail() { echo -e "${RED}FAIL${NC} $1"; FAIL=$((FAIL + 1)); }
skip() { echo -e "${YELLOW}SKIP${NC} $1"; SKIP=$((SKIP + 1)); }

WORKFLOW=".github/workflows/tutor-plugin-test.yml"

if [[ ! -f "$WORKFLOW" ]]; then
  fail "AC-035: Workflow file $WORKFLOW not found"
  echo ""
  echo "=== Summary ==="
  echo -e "${GREEN}PASS:${NC} $PASS | ${RED}FAIL:${NC} $FAIL | ${YELLOW}SKIP:${NC} $SKIP"
  exit 1
fi

echo "Checking $WORKFLOW for Tutor plugin testing..."
echo ""

# AC-035: Workflow runs plugin syntax and lifecycle tests
has_syntax_test=0
has_lifecycle_test=0

if grep -q "py_compile.*mfe_oauth_fix.py" "$WORKFLOW" || grep -q "Verify plugin syntax" "$WORKFLOW"; then
  has_syntax_test=1
fi

if grep -q "test-plugin-lifecycle:" "$WORKFLOW"; then
  has_lifecycle_test=1
fi

if [[ $has_syntax_test -eq 1 && $has_lifecycle_test -eq 1 ]]; then
  pass "AC-035: tutor-plugin-test.yml runs syntax and lifecycle tests"
elif [[ $has_syntax_test -eq 0 ]]; then
  fail "AC-035: Workflow missing plugin syntax test"
else
  fail "AC-035: Workflow missing plugin lifecycle test"
fi

# AC-036: Plugin tests verify mfe_oauth_fix installed in LMS settings
if grep -q "mfe_oauth_fix.*production.py" "$WORKFLOW" || \
   grep -A 10 "Verify plugin" "$WORKFLOW" | grep -q "mfe_oauth_fix"; then
  pass "AC-036: Workflow verifies mfe_oauth_fix in LMS settings"
else
  fail "AC-036: Workflow missing verification of mfe_oauth_fix installation"
fi

# AC-037: Plugin enable/disable/re-enable lifecycle succeeds
enable_count=$(grep -c "tutor plugins enable" "$WORKFLOW" || echo 0)
disable_count=$(grep -c "tutor plugins disable" "$WORKFLOW" || echo 0)

if [[ $enable_count -ge 2 && $disable_count -ge 1 ]]; then
  pass "AC-037: Workflow tests enable → disable → re-enable lifecycle"
else
  fail "AC-037: Workflow missing complete enable/disable/re-enable test (enable:$enable_count disable:$disable_count)"
fi

# AC-038: Plugin + apply-patches.sh integration test validates both patches present
if grep -q "integration-test:" "$WORKFLOW" && grep -q "apply-patches.sh" "$WORKFLOW"; then
  # Check if it verifies both plugin and apply-patches results
  if grep -A 20 "Verify both plugin and patches" "$WORKFLOW" | grep -q "mfe_oauth_fix" && \
     grep -A 20 "Verify both plugin and patches" "$WORKFLOW" | grep -q "academy.biji-biji.com"; then
    pass "AC-038: Workflow includes integration test validating plugin + patches"
  else
    fail "AC-038: Workflow has integration test but missing dual validation"
  fi
else
  fail "AC-038: Workflow missing plugin + apply-patches.sh integration test"
fi

# AC-039: Plugin test failure posts plugin-specific troubleshooting comment
if grep -q "post.*comment\|github-script" "$WORKFLOW"; then
  # Check if runs on failure
  if grep -A 5 "post.*comment\|github-script" "$WORKFLOW" | grep -q "failure()"; then
    # Check for plugin-specific guidance
    if grep -A 30 "github-script\|createComment" "$WORKFLOW" | grep -Eq "(Plugin.*[Ff]ailed|plugin.*syntax|ENV_PATCHES|mfe_oauth_fix)"; then
      pass "AC-039: Workflow posts plugin-specific troubleshooting on failure"
    else
      fail "AC-039: Workflow posts comment but missing plugin-specific guidance"
    fi
  else
    fail "AC-039: Workflow has comment step but not conditional on failure"
  fi
else
  fail "AC-039: Workflow missing failure comment step"
fi

echo ""
echo "=== Summary ==="
echo -e "${GREEN}PASS:${NC} $PASS | ${RED}FAIL:${NC} $FAIL | ${YELLOW}SKIP:${NC} $SKIP"
[ "$FAIL" -gt 0 ] && exit 1 || exit 0
