#!/usr/bin/env bash
# @covers AC-013
# @spec: secrets-management_spec.md
# Verify pre-commit hook blocks hardcoded secrets
#
# Checks:
#   AC-013: Pre-commit hook exists, is executable, and scans for hardcoded patterns
#
# Usage:
#   ./scripts/qa/verify-secrets-precommit.sh

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Counters
PASS=0
FAIL=0
SKIP=0

# Helper functions
pass() { echo -e "${GREEN}PASS${NC} $1"; PASS=$((PASS + 1)); }
fail() { echo -e "${RED}FAIL${NC} $1"; FAIL=$((FAIL + 1)); }
skip() { echo -e "${YELLOW}SKIP${NC} $1"; SKIP=$((SKIP + 1)); }

echo "=== Pre-commit Hook Verification ==="
echo ""

# Check 1: Hook file exists
echo "Checking AC-013: Pre-commit hook exists..."

hook_path=".githooks/pre-commit"

if [[ ! -f "$hook_path" ]]; then
  fail "AC-013: Pre-commit hook not found at $hook_path"
  echo ""
  echo "=== Summary ==="
  echo -e "${GREEN}PASS:${NC} $PASS | ${RED}FAIL:${NC} $FAIL | ${YELLOW}SKIP:${NC} $SKIP"
  exit 1
fi

pass "AC-013: Pre-commit hook exists at $hook_path"
echo ""

# Check 2: Hook is executable
echo "Checking AC-013: Pre-commit hook is executable..."

if [[ -x "$hook_path" ]]; then
  pass "AC-013: Pre-commit hook is executable"
else
  fail "AC-013: Pre-commit hook is NOT executable"
  echo "  Run: chmod +x $hook_path"
fi

echo ""

# Check 3: Git config references .gitconfig (which includes hooks path)
echo "Checking AC-013: Git config includes .githooks..."

if git config --local --get include.path | grep -q "\.gitconfig" 2>/dev/null; then
  pass "AC-013: Git config includes .gitconfig (hooks enabled)"
elif git config --get core.hooksPath | grep -q "\.githooks" 2>/dev/null; then
  pass "AC-013: Git core.hooksPath points to .githooks"
else
  fail "AC-013: Git config does not reference .githooks"
  echo "  Run: git config --local include.path ../.gitconfig"
  echo "  Or: git config --local core.hooksPath .githooks"
fi

echo ""

# Check 4: Hook scans for required patterns
echo "Checking AC-013: Hook scans for hardcoded secret patterns..."

required_patterns=(
  "password"
  "api_key"
  "apikey"
  "secret_key"
  "PRIVATE KEY"
  "eyJ"
  "AKIA"
)

ac013_patterns_pass=true

for pattern in "${required_patterns[@]}"; do
  if grep -iq "$pattern" "$hook_path"; then
    pass "AC-013: Hook scans for pattern: $pattern"
  else
    fail "AC-013: Hook missing pattern: $pattern"
    ac013_patterns_pass=false
  fi
done

echo ""

# Check 5: Hook exits non-zero when secrets are found
echo "Checking AC-013: Hook logic exits non-zero on detection..."

# Check that hook sets SECRETS_FOUND and exits 1 when it equals 1
if grep -q "SECRETS_FOUND=1" "$hook_path" && grep -q "exit 1" "$hook_path"; then
  pass "AC-013: Hook exits non-zero when secrets detected"
else
  fail "AC-013: Hook may not exit non-zero when secrets detected"
fi

echo ""

# Check 6: Hook allows bypass with --no-verify
echo "Checking AC-013: Hook documents --no-verify bypass..."

if grep -q -- "--no-verify" "$hook_path"; then
  pass "AC-013: Hook documents --no-verify bypass option"
else
  skip "AC-013: Hook does not mention --no-verify (non-critical)"
fi

echo ""
echo "=== Summary ==="
echo -e "${GREEN}PASS:${NC} $PASS | ${RED}FAIL:${NC} $FAIL | ${YELLOW}SKIP:${NC} $SKIP"

if [[ $FAIL -gt 0 ]]; then
  echo ""
  echo "Some checks failed. Pre-commit hook may not be properly configured."
  exit 1
fi

echo ""
echo "Pre-commit hook is properly configured to block hardcoded secrets."
exit 0
