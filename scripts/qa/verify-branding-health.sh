#!/usr/bin/env bash
# @covers AC-007
# @spec: branding-system_spec.md
set -euo pipefail

# verify-branding-health.sh - Verify branding health check exits 0
#
# AC-007: scripts/branding/verify-branding-health.sh exits 0
#
# This script wraps the comprehensive branding health check from the branding
# scripts directory and reports results in the standard qa verification format.

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BRANDING_HEALTH_SCRIPT="${REPO_ROOT}/scripts/branding/verify-branding-health.sh"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASS=0
FAIL=0
SKIP=0

pass() {
  echo -e "${GREEN}PASS${NC} $1"
  PASS=$((PASS + 1))
}

fail() {
  echo -e "${RED}FAIL${NC} $1"
  FAIL=$((FAIL + 1))
}

skip() {
  echo -e "${YELLOW}SKIP${NC} $1"
  SKIP=$((SKIP + 1))
}

echo "=== Branding System: Health Check Verification ==="
echo "Spec: branding-system_spec.md | AC-007"
echo

# Check 1: Branding health script exists
if [[ ! -f "$BRANDING_HEALTH_SCRIPT" ]]; then
  fail "Branding health script not found at $BRANDING_HEALTH_SCRIPT"
  echo
  echo "=== Summary ==="
  echo -e "${GREEN}PASS:${NC} $PASS | ${RED}FAIL:${NC} $FAIL | ${YELLOW}SKIP:${NC} $SKIP"
  exit 1
fi

pass "Branding health script exists"

# Check 2: Script is executable
if [[ ! -x "$BRANDING_HEALTH_SCRIPT" ]]; then
  fail "Branding health script is not executable"
  echo
  echo "=== Summary ==="
  echo -e "${GREEN}PASS:${NC} $PASS | ${RED}FAIL:${NC} $FAIL | ${YELLOW}SKIP:${NC} $SKIP"
  exit 1
fi

pass "Branding health script is executable"

# Check 3: Run the branding health check (AC-007 requirement)
echo
echo "Running comprehensive branding health check..."
echo "---"

if "$BRANDING_HEALTH_SCRIPT"; then
  echo "---"
  pass "AC-007: verify-branding-health.sh exits 0 (all branding checks passed)"
else
  exit_code=$?
  echo "---"
  fail "AC-007: verify-branding-health.sh exited with code $exit_code"
fi

# Summary
echo
echo "=== Summary ==="
echo -e "${GREEN}PASS:${NC} $PASS | ${RED}FAIL:${NC} $FAIL | ${YELLOW}SKIP:${NC} $SKIP"

if [[ $FAIL -gt 0 ]]; then
  echo
  echo "Action required: Fix branding assets or configuration."
  echo "  Run: ./scripts/branding/sync-brand-assets.sh"
  echo "  Then retry: ./scripts/branding/verify-branding-health.sh"
  exit 1
fi

exit 0
