#!/usr/bin/env bash
# Master test runner for all Tutor configuration resilience tests
# Runs all test suites and generates a summary report

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TEST_DIR="$REPO_ROOT/tests/tutor"

# Track overall results
TOTAL_SUITES=0
PASSED_SUITES=0
FAILED_SUITES=0

echo -e "${BLUE}${BOLD}====================================${NC}"
echo -e "${BLUE}${BOLD} Tutor Configuration Resilience Test Suite${NC}"
echo -e "${BLUE}${BOLD}====================================${NC}"
echo ""

# Test suites to run
TEST_SUITES=(
  "test_verify_patches.sh"
  "test_idempotency.sh"
  "test_pre_commit_hook.sh"
  "test_edge_cases.sh"
  "test_nfr_performance.sh"
)

# Run each test suite
for suite in "${TEST_SUITES[@]}"; do
  TOTAL_SUITES=$((TOTAL_SUITES + 1))
  SUITE_PATH="$TEST_DIR/$suite"

  if [[ ! -f "$SUITE_PATH" ]]; then
    echo -e "${YELLOW}⚠ SKIP: $suite not found${NC}"
    continue
  fi

  echo -e "${BLUE}Running test suite: $suite${NC}"
  echo "----------------------------------------"

  if bash "$SUITE_PATH"; then
    PASSED_SUITES=$((PASSED_SUITES + 1))
    echo -e "${GREEN}✓ $suite PASSED${NC}"
  else
    FAILED_SUITES=$((FAILED_SUITES + 1))
    echo -e "${RED}✗ $suite FAILED${NC}"
  fi

  echo ""
done

# Final summary
echo -e "${BLUE}${BOLD}====================================${NC}"
echo -e "${BLUE}${BOLD} Overall Summary${NC}"
echo -e "${BLUE}${BOLD}====================================${NC}"
echo ""
echo "Test suites run: $TOTAL_SUITES"
echo -e "${GREEN}Passed: $PASSED_SUITES${NC}"
echo -e "${RED}Failed: $FAILED_SUITES${NC}"
echo ""

if [[ $FAILED_SUITES -eq 0 ]]; then
  echo -e "${GREEN}${BOLD}✓ ALL TEST SUITES PASSED!${NC}"
  exit 0
else
  echo -e "${RED}${BOLD}✗ SOME TEST SUITES FAILED${NC}"
  exit 1
fi
