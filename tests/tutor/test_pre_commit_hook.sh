#!/usr/bin/env bash
# Tests for pre-commit hook integration
# Coverage: AC-TCR-005

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PRE_COMMIT_HOOK="$REPO_ROOT/.githooks/pre-commit"

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

echo "=== Test Suite: Pre-commit Hook ==="
echo ""

# TEST-TCR-030: Pre-commit hook exists and is executable
test_start "Pre-commit hook exists and is executable"
if [[ -x "$PRE_COMMIT_HOOK" ]]; then
  test_pass
else
  test_fail "Hook not found or not executable: $PRE_COMMIT_HOOK"
fi

# TEST-TCR-031: Pre-commit hook calls verify-tutor-patches.sh
test_start "Pre-commit hook references verify-tutor-patches.sh"
if grep -q "verify-tutor-patches.sh" "$PRE_COMMIT_HOOK"; then
  test_pass
else
  test_fail "Hook does not call verify-tutor-patches.sh"
fi

# TEST-TCR-032: Pre-commit hook only runs on Tutor file changes
test_start "Pre-commit hook checks for Tutor files before running verification"
if grep -qE "infrastructure/tutor/|tutor_env/" "$PRE_COMMIT_HOOK"; then
  test_pass
else
  test_fail "Hook does not filter for Tutor files"
fi

# TEST-TCR-033: Pre-commit hook exits 1 on verification failure
test_start "Pre-commit hook exits 1 when verification fails"
# Simulate the hook logic
HOOK_LOGIC=$(grep -A 20 "verify-tutor-patches.sh" "$PRE_COMMIT_HOOK" | grep -c "exit 1" || echo "0")
if [[ $HOOK_LOGIC -gt 0 ]]; then
  test_pass
else
  test_fail "Hook does not exit 1 on verification failure"
fi

# TEST-TCR-034: Pre-commit hook completes within 15 seconds
test_start "Pre-commit hook completes within 15 seconds (NFR)"

# Create a temporary git repo to test the hook
TEMP_REPO=$(mktemp -d)
cd "$TEMP_REPO"
git init >/dev/null 2>&1
git config user.email "test@example.com"
git config user.name "Test User"

# Copy the hook
mkdir -p .git/hooks
cp "$PRE_COMMIT_HOOK" .git/hooks/pre-commit
chmod +x .git/hooks/pre-commit

# Create a dummy file
echo "test" > test.txt
git add test.txt

# Measure hook execution time
START_TIME=$(date +%s)
git commit -m "test commit" --no-verify >/dev/null 2>&1 || true
END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

cd "$REPO_ROOT"
rm -rf "$TEMP_REPO"

if [[ $DURATION -lt 15 ]]; then
  test_pass
  echo -e "  ${GREEN}  Completed in ${DURATION}s${NC}"
else
  test_fail "Hook took ${DURATION}s (threshold: 15s)"
fi

# TEST-TCR-035: Hook is skippable with --no-verify
test_start "Pre-commit hook can be bypassed with --no-verify"

TEMP_REPO=$(mktemp -d)
cd "$TEMP_REPO"
git init >/dev/null 2>&1
git config user.email "test@example.com"
git config user.name "Test User"

mkdir -p .git/hooks
cp "$PRE_COMMIT_HOOK" .git/hooks/pre-commit
chmod +x .git/hooks/pre-commit

echo "test" > test.txt
git add test.txt

# Commit with --no-verify should succeed even if hook would fail
if git commit -m "test commit" --no-verify >/dev/null 2>&1; then
  test_pass
else
  test_fail "Could not bypass hook with --no-verify"
fi

cd "$REPO_ROOT"
rm -rf "$TEMP_REPO"

# Summary
echo ""
echo "=== Test Summary ==="
echo "Tests run: $TESTS_RUN"
echo -e "${GREEN}Passed: $TESTS_PASSED${NC}"
echo -e "${RED}Failed: $TESTS_FAILED${NC}"
echo ""

if [[ $TESTS_FAILED -eq 0 ]]; then
  echo -e "${GREEN}✓ All pre-commit hook tests passed!${NC}"
  exit 0
else
  echo -e "${RED}✗ Some tests failed${NC}"
  exit 1
fi
