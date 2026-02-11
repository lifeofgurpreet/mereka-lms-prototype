#!/usr/bin/env bash
# @covers AC-TCR-009
# @spec: tutor-configuration-resilience_spec.md
# Tests for apply-patches.sh idempotency
# Coverage: AC-TCR-009

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
APPLY_PATCHES_SCRIPT="$REPO_ROOT/infrastructure/tutor/apply-patches.sh"

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

echo "=== Test Suite: apply-patches.sh Idempotency ==="
echo ""

# Check if tutor_env exists
if [[ ! -d "$REPO_ROOT/tutor_env" ]]; then
  echo -e "${YELLOW}SKIP: tutor_env not found. Run 'tutor config save' first.${NC}"
  exit 0
fi

# TEST-TCR-020: Double apply produces byte-identical output for Python files
test_start "Double apply-patches.sh produces byte-identical Python files"

# Create checksums before first apply
TEMP_DIR=$(mktemp -d)
find "$REPO_ROOT/tutor_env/env/apps/openedx/settings" -name "*.py" -type f -exec md5sum {} \; | sort > "$TEMP_DIR/before_checksums.txt" 2>/dev/null || true

# Apply patches
"$APPLY_PATCHES_SCRIPT" >/dev/null 2>&1 || true

# Apply patches again
"$APPLY_PATCHES_SCRIPT" >/dev/null 2>&1 || true

# Create checksums after second apply
find "$REPO_ROOT/tutor_env/env/apps/openedx/settings" -name "*.py" -type f -exec md5sum {} \; | sort > "$TEMP_DIR/after_checksums.txt" 2>/dev/null || true

# Compare checksums
if diff -q "$TEMP_DIR/before_checksums.txt" "$TEMP_DIR/after_checksums.txt" >/dev/null 2>&1; then
  test_pass
else
  test_fail "Python files changed after second apply"
  echo -e "  ${YELLOW}Diff:${NC}"
  diff "$TEMP_DIR/before_checksums.txt" "$TEMP_DIR/after_checksums.txt" | head -10 || true
fi

rm -rf "$TEMP_DIR"

# TEST-TCR-021: Double apply produces byte-identical YAML files
test_start "Double apply-patches.sh produces byte-identical YAML files"

TEMP_DIR=$(mktemp -d)
find "$REPO_ROOT/tutor_env/env/local" -name "*.yml" -type f -exec md5sum {} \; | sort > "$TEMP_DIR/before_checksums.txt" 2>/dev/null || true

"$APPLY_PATCHES_SCRIPT" >/dev/null 2>&1 || true

find "$REPO_ROOT/tutor_env/env/local" -name "*.yml" -type f -exec md5sum {} \; | sort > "$TEMP_DIR/after_checksums.txt" 2>/dev/null || true

if diff -q "$TEMP_DIR/before_checksums.txt" "$TEMP_DIR/after_checksums.txt" >/dev/null 2>&1; then
  test_pass
else
  test_fail "YAML files changed after second apply"
fi

rm -rf "$TEMP_DIR"

# TEST-TCR-022: Double apply produces byte-identical Dockerfiles
test_start "Double apply-patches.sh produces byte-identical Dockerfiles"

TEMP_DIR=$(mktemp -d)
find "$REPO_ROOT/tutor_env/env/build/openedx" -name "Dockerfile" -type f -exec md5sum {} \; | sort > "$TEMP_DIR/before_checksums.txt" 2>/dev/null || true

"$APPLY_PATCHES_SCRIPT" >/dev/null 2>&1 || true

find "$REPO_ROOT/tutor_env/env/build/openedx" -name "Dockerfile" -type f -exec md5sum {} \; | sort > "$TEMP_DIR/after_checksums.txt" 2>/dev/null || true

if diff -q "$TEMP_DIR/before_checksums.txt" "$TEMP_DIR/after_checksums.txt" >/dev/null 2>&1; then
  test_pass
else
  test_fail "Dockerfiles changed after second apply"
fi

rm -rf "$TEMP_DIR"

# TEST-TCR-023: Script completes successfully on second run
test_start "apply-patches.sh exits 0 on second run"

if "$APPLY_PATCHES_SCRIPT" >/dev/null 2>&1; then
  test_pass
else
  test_fail "Script returned non-zero exit code"
fi

# Summary
echo ""
echo "=== Test Summary ==="
echo "Tests run: $TESTS_RUN"
echo -e "${GREEN}Passed: $TESTS_PASSED${NC}"
echo -e "${RED}Failed: $TESTS_FAILED${NC}"
echo ""

if [[ $TESTS_FAILED -eq 0 ]]; then
  echo -e "${GREEN}✓ All idempotency tests passed!${NC}"
  exit 0
else
  echo -e "${RED}✗ Some tests failed${NC}"
  exit 1
fi
