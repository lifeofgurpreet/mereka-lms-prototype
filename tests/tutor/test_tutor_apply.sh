#!/usr/bin/env bash
# @covers AC-TCR-012
# @spec: tutor-configuration-resilience_spec.md
# Test script for AC-TCR-012: make tutor-apply workflow verification
#
# Verifies that the Tutor configuration workflow components exist and are properly wired:
# - Makefile target exists
# - Required scripts are present and executable
# - Plugin has valid Python syntax
# - Scripts are chained correctly
#
# Usage: ./tests/tutor/test_tutor_apply.sh

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Repository root
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

# Counters
PASS=0
FAIL=0

# Helper functions
pass() {
  echo -e "${GREEN}✓${NC} $1"
  PASS=$((PASS + 1))
}

fail() {
  echo -e "${RED}✗${NC} $1"
  FAIL=$((FAIL + 1))
}

warn() {
  echo -e "${YELLOW}⚠${NC} $1"
}

section() {
  echo ""
  echo -e "${BLUE}=== $1 ===${NC}"
}

# Main tests
section "AC-TCR-012: Tutor Configuration Workflow Component Verification"

# Check 1: Makefile has tutor-apply target
echo "Checking Makefile for tutor-apply target..."
if grep -q "^tutor-apply:" Makefile; then
  pass "Makefile contains tutor-apply target"
else
  fail "Makefile missing tutor-apply target"
fi

# Check 2: apply-patches.sh exists and is executable
echo "Checking apply-patches.sh..."
if [[ -f "infrastructure/tutor/apply-patches.sh" ]]; then
  if [[ -x "infrastructure/tutor/apply-patches.sh" ]]; then
    pass "infrastructure/tutor/apply-patches.sh exists and is executable"
  else
    fail "infrastructure/tutor/apply-patches.sh exists but is NOT executable"
  fi
else
  fail "infrastructure/tutor/apply-patches.sh does not exist"
fi

# Check 3: Tutor plugin exists
echo "Checking Tutor plugin..."
if [[ -f "infrastructure/tutor/plugins/mereka_lms.py" ]]; then
  pass "infrastructure/tutor/plugins/mereka_lms.py exists"
else
  fail "infrastructure/tutor/plugins/mereka_lms.py does not exist"
fi

# Check 4: verify-tutor-config.sh exists and is executable
echo "Checking verify-tutor-config.sh..."
if [[ -f "scripts/infra/verify-tutor-config.sh" ]]; then
  if [[ -x "scripts/infra/verify-tutor-config.sh" ]]; then
    pass "scripts/infra/verify-tutor-config.sh exists and is executable"
  else
    fail "scripts/infra/verify-tutor-config.sh exists but is NOT executable"
  fi
else
  fail "scripts/infra/verify-tutor-config.sh does not exist"
fi

# Check 5: tutor-config-save.sh exists and is executable
echo "Checking tutor-config-save.sh..."
if [[ -f "scripts/infra/tutor-config-save.sh" ]]; then
  if [[ -x "scripts/infra/tutor-config-save.sh" ]]; then
    pass "scripts/infra/tutor-config-save.sh exists and is executable"
  else
    fail "scripts/infra/tutor-config-save.sh exists but is NOT executable"
  fi
else
  fail "scripts/infra/tutor-config-save.sh does not exist"
fi

# Check 6: Workflow orchestration - verify scripts are called in correct order
section "Workflow Orchestration Verification"

echo "Checking tutor-apply Makefile target chains commands correctly..."
if grep -A 3 "^tutor-apply:" Makefile | grep -q "./scripts/infra/tutor-config-save.sh" && \
   grep -A 3 "^tutor-apply:" Makefile | grep -q "tutor local restart"; then
  pass "tutor-apply chains: tutor-config-save front door → restart"
else
  fail "tutor-apply does not chain commands correctly (expected: tutor-config-save front door → restart)"
fi

echo "Checking tutor-config-save.sh calls prepare-tutor-build-context.sh..."
if grep -q "prepare-tutor-build-context.sh" scripts/infra/tutor-config-save.sh; then
  pass "tutor-config-save.sh calls prepare-tutor-build-context.sh"
else
  fail "tutor-config-save.sh does NOT call prepare-tutor-build-context.sh"
fi

echo "Checking tutor-config-save.sh calls verify-tutor-config.sh..."
if grep -q "verify-tutor-config.sh" scripts/infra/tutor-config-save.sh; then
  pass "tutor-config-save.sh calls verify-tutor-config.sh"
else
  warn "tutor-config-save.sh does not call verify-tutor-config.sh (recommended but not critical)"
fi

# Check 7: Plugin has valid Python syntax
section "Plugin Syntax Validation"

echo "Validating Python syntax of mereka_lms.py plugin..."
if python3 -c "import ast; ast.parse(open('infrastructure/tutor/plugins/mereka_lms.py').read())" 2>/dev/null; then
  pass "infrastructure/tutor/plugins/mereka_lms.py has valid Python syntax"
else
  fail "infrastructure/tutor/plugins/mereka_lms.py has INVALID Python syntax"
fi

# Check 8: apply-patches.sh has error handling
echo "Checking apply-patches.sh has proper error handling..."
if head -n 10 infrastructure/tutor/apply-patches.sh | grep -q "set -euo pipefail"; then
  pass "apply-patches.sh uses 'set -euo pipefail' for fail-fast behavior"
else
  fail "apply-patches.sh missing 'set -euo pipefail' (required for fail-fast)"
fi

# Summary
section "Test Summary"
echo ""
echo "Passed: $PASS"
echo "Failed: $FAIL"
echo ""

if [[ $FAIL -eq 0 ]]; then
  echo -e "${GREEN}✓ All AC-TCR-012 component verification checks passed!${NC}"
  exit 0
else
  echo -e "${RED}✗ $FAIL check(s) failed${NC}"
  exit 1
fi
