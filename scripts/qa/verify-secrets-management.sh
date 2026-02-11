#!/usr/bin/env bash
# @covers AC-CCR-005
# @spec: cross-cutting-requirements_spec.md
# Umbrella script for AC-CCR-005: Secrets Management Verification
#
# Orchestrates all secrets-related verification scripts to ensure:
# - No hardcoded secrets in codebase
# - Secrets follow MEREKA_LMS_* naming convention
# - K8s secrets hygiene (no plaintext in manifests)
# - ExternalSecrets properly configured
# - Git hooks are in place
#
# Usage: ./scripts/qa/verify-secrets-management.sh

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

# Run a verification script and capture result
run_check() {
  local script_path="$1"
  local description="$2"

  echo ""
  echo -e "${BLUE}Running: $description${NC}"
  echo "Script: $script_path"
  echo ""

  if [[ ! -f "$script_path" ]]; then
    fail "$description: Script not found at $script_path"
    return 1
  fi

  if [[ ! -x "$script_path" ]]; then
    fail "$description: Script not executable at $script_path"
    return 1
  fi

  if "$script_path"; then
    pass "$description"
    return 0
  else
    fail "$description"
    return 1
  fi
}

# Main execution
section "AC-CCR-005: Secrets Management Comprehensive Verification"
echo "This script orchestrates all secrets-related verification checks."

# Check 1: No hardcoded secrets
run_check \
  "scripts/qa/verify-no-hardcoded-secrets.sh" \
  "No hardcoded secrets in codebase"

# Check 2: Secrets naming convention
run_check \
  "scripts/qa/verify-secrets-naming-convention.sh" \
  "Secrets follow MEREKA_LMS_* naming convention"

# Check 3: K8s secrets hygiene
run_check \
  "scripts/qa/verify-k8s-secrets-hygiene.sh" \
  "K8s manifests do not contain hardcoded secrets"

# Check 4: ExternalSecrets configuration
run_check \
  "scripts/qa/verify-k8s-externalsecrets.sh" \
  "ExternalSecrets properly configured"

# Check 5: Git pre-commit hook
section "Git Hook Verification"
echo "Checking .githooks/pre-commit exists and is executable..."
if [[ -f ".githooks/pre-commit" ]]; then
  if [[ -x ".githooks/pre-commit" ]]; then
    pass "Git pre-commit hook exists and is executable"
  else
    fail "Git pre-commit hook exists but is NOT executable"
  fi
else
  fail "Git pre-commit hook does not exist at .githooks/pre-commit"
fi

# Check 6: Git config includes githooks
echo "Checking git config includes .githooks path..."
if git config --local --get include.path | grep -q "\.gitconfig" 2>/dev/null; then
  pass "Git config includes .gitconfig (hooks enabled)"
else
  warn "Git config does not include .gitconfig (hooks may not be active)"
  echo "  Run: git config --local include.path ../.gitconfig"
fi

# Summary
section "Secrets Management Verification Summary"
echo ""
echo "Passed: $PASS"
echo "Failed: $FAIL"
echo ""

if [[ $FAIL -eq 0 ]]; then
  echo -e "${GREEN}✓ All AC-CCR-005 secrets management checks passed!${NC}"
  echo ""
  echo "Secrets management compliance verified:"
  echo "  • No hardcoded secrets in codebase"
  echo "  • Naming conventions followed"
  echo "  • K8s secrets hygiene maintained"
  echo "  • ExternalSecrets configured correctly"
  echo "  • Git hooks in place"
  exit 0
else
  echo -e "${RED}✗ $FAIL check(s) failed${NC}"
  echo ""
  echo "Please review the failed checks above and remediate before proceeding."
  exit 1
fi
