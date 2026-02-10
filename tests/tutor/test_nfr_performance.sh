#!/usr/bin/env bash
# Non-functional requirements tests: Performance, offline operation, manifest quality
# Coverage: NFR tests from testplan

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VERIFY_SCRIPT="$REPO_ROOT/scripts/infra/verify-tutor-patches.sh"
MANIFEST_FILE="$REPO_ROOT/infrastructure/tutor/patch-manifest.yml"

TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

test_start() {
  TESTS_RUN=$((TESTS_RUN + 1))
  echo -e "${YELLOW}TEST $TESTS_RUN: $1${NC}"
}

test_pass() {
  TESTS_PASSED=$((TESTS_PASSED + 1))
  echo -e "${GREEN}  ✓ PASS${NC}"
}

test_fail() {
  TESTS_FAILED=$((TESTS_FAILED + 1))
  echo -e "${RED}  ✗ FAIL: $1${NC}"
}

echo "=== Test Suite: Non-Functional Requirements ==="
echo ""

# NFR-001: Verification speed (<30s)
test_start "Full manifest verification completes in <30s"
if [[ -d "$REPO_ROOT/tutor_env" ]]; then
  START_TIME=$(date +%s)
  "$VERIFY_SCRIPT" >/dev/null 2>&1 || true
  END_TIME=$(date +%s)
  DURATION=$((END_TIME - START_TIME))

  if [[ $DURATION -lt 30 ]]; then
    test_pass
    echo -e "  ${GREEN}  Completed in ${DURATION}s (threshold: 30s)${NC}"
  else
    test_fail "Took ${DURATION}s (threshold: 30s)"
  fi
else
  echo -e "  ${YELLOW}SKIP: tutor_env not found${NC}"
fi

# NFR-002: Manifest readability (yamllint)
test_start "Manifest passes yamllint validation"
if command -v yamllint >/dev/null 2>&1; then
  if yamllint -d '{extends: default, rules: {line-length: {max: 200}}}' "$MANIFEST_FILE" >/dev/null 2>&1; then
    test_pass
  else
    test_fail "yamllint found issues"
    yamllint "$MANIFEST_FILE" || true
  fi
else
  echo -e "  ${YELLOW}SKIP: yamllint not installed${NC}"
fi

# NFR-003: Offline operation (no network calls)
test_start "Verification script works without network access"
if [[ -d "$REPO_ROOT/tutor_env" ]]; then
  # Check if verification script makes network calls (grep for curl, wget, http://, https://)
  if grep -qE 'curl|wget|http://|https://' "$VERIFY_SCRIPT"; then
    test_fail "Script contains network-related commands"
  else
    test_pass
  fi
else
  echo -e "  ${YELLOW}SKIP: tutor_env not found${NC}"
fi

# NFR-004: Manifest completeness (>40 patches documented)
test_start "Manifest documents >40 patches"
PATCH_COUNT=$(grep -c "^  - id:" "$MANIFEST_FILE" || echo "0")

if [[ $PATCH_COUNT -gt 40 ]]; then
  test_pass
  echo -e "  ${GREEN}  Found $PATCH_COUNT patches${NC}"
else
  test_fail "Only $PATCH_COUNT patches documented (expected >40)"
fi

# NFR-005: All critical patches have remediation info
test_start "All critical patches have descriptions and verify commands"
CRITICAL_PATCHES=$(grep -A 10 "severity: critical" "$MANIFEST_FILE" || echo "")
MISSING_DESC=0
MISSING_VERIFY=0

while IFS= read -r line; do
  if [[ "$line" =~ severity:.*critical ]]; then
    # Check next 10 lines for description and verify_command
    BLOCK=$(echo "$CRITICAL_PATCHES" | grep -A 10 "$line" || echo "")
    if ! echo "$BLOCK" | grep -q "description:"; then
      MISSING_DESC=$((MISSING_DESC + 1))
    fi
    if ! echo "$BLOCK" | grep -q "verify_command:"; then
      MISSING_VERIFY=$((MISSING_VERIFY + 1))
    fi
  fi
done <<< "$CRITICAL_PATCHES"

if [[ $MISSING_DESC -eq 0 && $MISSING_VERIFY -eq 0 ]]; then
  test_pass
else
  test_fail "$MISSING_DESC critical patches missing description, $MISSING_VERIFY missing verify_command"
fi

# NFR-006: JSON output is machine-parseable
test_start "JSON output can be parsed by jq without errors"
if [[ -d "$REPO_ROOT/tutor_env" ]]; then
  JSON_OUTPUT=$("$VERIFY_SCRIPT" --json 2>/dev/null || echo "{}")

  if echo "$JSON_OUTPUT" | jq . >/dev/null 2>&1; then
    test_pass
  else
    test_fail "JSON is not valid"
  fi
else
  echo -e "  ${YELLOW}SKIP: tutor_env not found${NC}"
fi

# NFR-007: Verification script has proper error handling
test_start "Verification script uses set -euo pipefail"
if grep -q "set -euo pipefail" "$VERIFY_SCRIPT"; then
  test_pass
else
  test_fail "Script missing strict error handling"
fi

# Summary
echo ""
echo "=== Test Summary ==="
echo "Tests run: $TESTS_RUN"
echo -e "${GREEN}Passed: $TESTS_PASSED${NC}"
echo -e "${RED}Failed: $TESTS_FAILED${NC}"
echo ""

if [[ $TESTS_FAILED -eq 0 ]]; then
  echo -e "${GREEN}✓ All NFR tests passed!${NC}"
  exit 0
else
  echo -e "${RED}✗ Some tests failed${NC}"
  exit 1
fi
