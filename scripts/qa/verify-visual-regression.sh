#!/usr/bin/env bash
# verify-visual-regression.sh — Static meta-verification of the auth visual-regression harness.
#
# Checks:
#   1. visual-regression-auth.sh exists and is executable
#   2. Script accepts --help without error
#   3. Script exits 2 and emits an error when required args are missing
#   4. Script exits 2 for unknown arguments
#   5. Notes integration point with verify-mfe-branding.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../shared/config.sh
source "$SCRIPT_DIR/../shared/config.sh"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASSED=0
FAILED=0
SKIPPED=0

pass() { echo -e "${GREEN}PASS${NC} $1"; PASSED=$((PASSED + 1)); }
fail() { echo -e "${RED}FAIL${NC} $1"; FAILED=$((FAILED + 1)); }
skip() { echo -e "${YELLOW}SKIP${NC} $1"; SKIPPED=$((SKIPPED + 1)); }

AUTH_SCRIPT="${SCRIPT_DIR}/visual-regression-auth.sh"
MFE_BRANDING_SCRIPT="${SCRIPT_DIR}/verify-mfe-branding.sh"

echo "=== Visual Regression Harness Verification ==="
echo

# ---------------------------------------------------------------------------
# Check 1: Script exists
# ---------------------------------------------------------------------------
if [[ -f "$AUTH_SCRIPT" ]]; then
  pass "visual-regression-auth.sh exists at $AUTH_SCRIPT"
else
  fail "visual-regression-auth.sh not found at $AUTH_SCRIPT"
fi

# ---------------------------------------------------------------------------
# Check 2: Script is executable
# ---------------------------------------------------------------------------
if [[ -x "$AUTH_SCRIPT" ]]; then
  pass "visual-regression-auth.sh is executable"
else
  fail "visual-regression-auth.sh is not executable (run: chmod +x $AUTH_SCRIPT)"
fi

# ---------------------------------------------------------------------------
# Check 3: --help exits 0 and contains Usage
# ---------------------------------------------------------------------------
if [[ -f "$AUTH_SCRIPT" ]]; then
  help_output="$("$AUTH_SCRIPT" --help 2>&1 || true)"
  help_exit=$("$AUTH_SCRIPT" --help >/dev/null 2>&1; echo $?) || true

  if [[ "$help_output" == *"Usage:"* ]] || [[ "$help_output" == *"usage:"* ]]; then
    pass "--help outputs usage text"
  else
    fail "--help did not output usage text"
  fi

  # Check exit code directly
  set +e
  "$AUTH_SCRIPT" --help >/dev/null 2>&1
  help_rc=$?
  set -e
  if [[ "$help_rc" -eq 0 ]]; then
    pass "--help exits 0"
  else
    fail "--help exited $help_rc (expected 0)"
  fi
fi

# ---------------------------------------------------------------------------
# Check 4: Missing required args exits 2
# ---------------------------------------------------------------------------
if [[ -f "$AUTH_SCRIPT" && -x "$AUTH_SCRIPT" ]]; then
  set +e
  missing_output=$("$AUTH_SCRIPT" 2>&1)
  missing_rc=$?
  set -e

  if [[ "$missing_rc" -eq 2 ]]; then
    pass "No args → exits 2 (usage error)"
  else
    fail "No args → exited $missing_rc (expected 2)"
  fi

  if [[ "$missing_output" =~ [Rr]equired|[Uu]sage|[Ee]rror ]]; then
    pass "No args → error message emitted"
  else
    fail "No args → no error message in output"
  fi

  # Missing --password only
  set +e
  partial_output=$("$AUTH_SCRIPT" --base-url https://example.com --username user 2>&1)
  partial_rc=$?
  set -e

  if [[ "$partial_rc" -eq 2 ]]; then
    pass "Missing --password → exits 2"
  else
    fail "Missing --password → exited $partial_rc (expected 2)"
  fi

  if [[ "$partial_output" =~ [Pp]assword.*[Rr]equired|[Rr]equired.*[Pp]assword ]]; then
    pass "Missing --password → descriptive error emitted"
  else
    # Still acceptable if generic "required" message shown
    if [[ "$partial_output" =~ [Rr]equired|[Uu]sage ]]; then
      pass "Missing --password → usage/error message emitted"
    else
      fail "Missing --password → no descriptive error in output"
    fi
  fi
fi

# ---------------------------------------------------------------------------
# Check 5: Unknown argument exits 2
# ---------------------------------------------------------------------------
if [[ -f "$AUTH_SCRIPT" && -x "$AUTH_SCRIPT" ]]; then
  set +e
  unknown_rc=$("$AUTH_SCRIPT" --unknown-flag 2>/dev/null; echo $?)
  set -e

  # unknown_rc here captured via subshell echo — re-run cleanly
  set +e
  "$AUTH_SCRIPT" --unknown-flag >/dev/null 2>&1
  unknown_exit=$?
  set -e

  if [[ "$unknown_exit" -eq 2 ]]; then
    pass "Unknown argument → exits 2"
  else
    fail "Unknown argument → exited $unknown_exit (expected 2)"
  fi
fi

# ---------------------------------------------------------------------------
# Check 6: Script has set -euo pipefail
# ---------------------------------------------------------------------------
if [[ -f "$AUTH_SCRIPT" ]]; then
  if grep -q 'set -euo pipefail' "$AUTH_SCRIPT"; then
    pass "Script uses set -euo pipefail"
  else
    fail "Script missing set -euo pipefail"
  fi
fi

# ---------------------------------------------------------------------------
# Check 7: Script uses shared config.sh
# ---------------------------------------------------------------------------
if [[ -f "$AUTH_SCRIPT" ]]; then
  if grep -q 'source.*config.sh' "$AUTH_SCRIPT"; then
    pass "Script sources scripts/shared/config.sh"
  else
    fail "Script does not source shared config.sh"
  fi
fi

# ---------------------------------------------------------------------------
# Check 8: verify-mfe-branding.sh exists (integration note)
# ---------------------------------------------------------------------------
echo
echo "--- Integration with verify-mfe-branding.sh ---"
if [[ -f "$MFE_BRANDING_SCRIPT" ]]; then
  pass "verify-mfe-branding.sh exists (covers unauthenticated MFE routes)"
  echo "  Note: visual-regression-auth.sh covers authenticated LMS/Studio routes."
  echo "  Run both for full visual coverage:"
  echo "    $MFE_BRANDING_SCRIPT --env prod"
  echo "    $AUTH_SCRIPT --base-url <lms_url> --username <u> --password <p>"
else
  skip "verify-mfe-branding.sh not found at $MFE_BRANDING_SCRIPT (integration check skipped)"
fi

echo

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo "=== Summary ==="
echo -e "${GREEN}PASS:${NC} $PASSED  ${RED}FAIL:${NC} $FAILED  ${YELLOW}SKIP:${NC} $SKIPPED"
echo

if [[ "$FAILED" -gt 0 ]]; then
  echo "Action required: visual-regression-auth.sh harness has structural issues."
  echo "  Review the FAIL lines above and fix before running in CI."
  exit 1
fi

echo "Visual regression harness verification passed."
exit 0
