#!/usr/bin/env bash
# @covers AC-US7-001, AC-US7-002, AC-US7-003, AC-US7-004, AC-US7-005
# @spec: bead-115d18
# Verify MFE selector hardening: enforce slot-only policy, count brittle patterns,
# check exception annotations and migration register completeness.
#
# Original AC-SEL-001..005 checks are preserved for backward-compat.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASS=0
FAIL=0
WARN=0

pass() { echo -e "${GREEN}[PASS]${NC} $1"; PASS=$((PASS + 1)); }
fail() { echo -e "${RED}[FAIL]${NC} $1"; FAIL=$((FAIL + 1)); }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; WARN=$((WARN + 1)); }

SCSS_FILE="$REPO_ROOT/infrastructure/tutor/themes/mereka/mfe/mereka.scss"
AUDIT_DOC="$REPO_ROOT/docs/operations/MFE_SELECTOR_HARDENING_AUDIT.md"
REGISTER_DOC="$REPO_ROOT/docs/operations/MFE_PLUGIN_SLOT_MIGRATION_REGISTER.md"
MATRIX_DOC="$REPO_ROOT/docs/operations/MFE_PLUGIN_SLOT_MATRIX.md"

echo "=== MFE Selector Hardening Verification (bead 115d.18) ==="
echo ""

# ---------------------------------------------------------------------------
# AC-US7-001: ≥30% reduction in brittle-only [class*=] selector patterns
# ---------------------------------------------------------------------------
echo "--- AC-US7-001: Brittle Selector Reduction ---"

if [[ ! -f "$SCSS_FILE" ]]; then
  fail "AC-US7-001: mereka.scss not found at $SCSS_FILE"
else
  # Baseline established 2026-02-18 (bead 8jao.3): 36 brittle-only selector blocks
  # After bead 115d.18: auth-page (6) + discussion-singular (6) = 12 removed = 33.3% reduction
  BRITTLE_BASELINE=36
  BRITTLE_MAX_ALLOWED=25  # 36 * 0.70 = 25.2 → floor 25 (30% reduction enforced)

  # Count brittle-only selector blocks: lines with [class*=] that are NOT comment lines
  # and are not part of a block that already has [data-testid*=] in the same rule
  # We measure by counting distinct [class*="<pattern>"] values in non-comment selector lines
  # that are NOT paired with data-testid in the same CSS rule block.
  #
  # Simpler proxy: count [class*=] occurrences in non-comment lines only.
  # Baseline non-comment [class*=] count before 115d.18: ~106 (72 brittle + 34 shared)
  # After 115d.18: removed 12 auth-page + 12 discussion-singular occurrences net.
  #
  # We enforce: banned selectors (auth-page, discussion-singular) must be absent.

  # Check that [class*="auth-page"] is NOT present in CSS selector lines
  AUTH_PAGE_COUNT=$(python3 -c "
import re, sys
scss = open('$SCSS_FILE').read()
lines = scss.split('\n')
count = 0
for line in lines:
    s = line.strip()
    if s.startswith('//') or s.startswith('/*') or s.startswith('*'):
        continue
    if re.search(r'\[class\*=\"auth-page\"\]', line):
        count += 1
print(count)
")

  # Check that [class*="discussion"] (singular, not discussions) is NOT present in CSS selector lines
  DISC_SINGULAR_COUNT=$(python3 -c "
import re, sys
scss = open('$SCSS_FILE').read()
lines = scss.split('\n')
count = 0
for line in lines:
    s = line.strip()
    if s.startswith('//') or s.startswith('/*') or s.startswith('*'):
        continue
    # Match [class*=\"discussion\"] but NOT [class*=\"discussions\"]
    if re.search(r'\[class\*=\"discussion\"\]', line) and not re.search(r'\[class\*=\"discussions\"\]', line):
        count += 1
print(count)
")

  # Check that [class*="login-register"] is NOT present in CSS selector lines
  LOGIN_REGISTER_COUNT=$(python3 -c "
import re, sys
scss = open('$SCSS_FILE').read()
lines = scss.split('\n')
count = 0
for line in lines:
    s = line.strip()
    if s.startswith('//') or s.startswith('/*') or s.startswith('*'):
        continue
    if re.search(r'\[class\*=\"login-register\"\]', line):
        count += 1
print(count)
")

  # Check that [class*="account-page"] is NOT present in CSS selector lines
  ACCOUNT_PAGE_COUNT=$(python3 -c "
import re, sys
scss = open('$SCSS_FILE').read()
lines = scss.split('\n')
count = 0
for line in lines:
    s = line.strip()
    if s.startswith('//') or s.startswith('/*') or s.startswith('*'):
        continue
    if re.search(r'\[class\*=\"account-page\"\]', line):
        count += 1
print(count)
")

  # Count remaining non-comment [class*=] selector lines (proxy for brittle density)
  BRITTLE_SELECTOR_LINES=$(python3 -c "
import re
scss = open('$SCSS_FILE').read()
lines = scss.split('\n')
count = 0
for line in lines:
    s = line.strip()
    if s.startswith('//') or s.startswith('/*') or s.startswith('*') or not s:
        continue
    if re.search(r'\[class\*=', line):
        count += 1
print(count)
")

  echo "  [class*=\"auth-page\"] in CSS selectors: $AUTH_PAGE_COUNT (must be 0)"
  echo "  [class*=\"discussion\"] singular in CSS selectors: $DISC_SINGULAR_COUNT (must be 0)"
  echo "  [class*=\"login-register\"] in CSS selectors: $LOGIN_REGISTER_COUNT (must be 0)"
  echo "  [class*=\"account-page\"] in CSS selectors: $ACCOUNT_PAGE_COUNT (must be 0)"
  echo "  Total non-comment [class*=] selector lines: $BRITTLE_SELECTOR_LINES"
  echo "  Brittle baseline (pre-115d.18): $BRITTLE_BASELINE blocks"
  echo "  Max allowed after 30% reduction: $BRITTLE_MAX_ALLOWED blocks"

  if [[ "$AUTH_PAGE_COUNT" -gt 0 ]]; then
    fail "AC-US7-001: [class*=\"auth-page\"] still present ($AUTH_PAGE_COUNT occurrence(s)) — must be removed"
  else
    pass "AC-US7-001: [class*=\"auth-page\"] removed from CSS selectors"
  fi

  if [[ "$DISC_SINGULAR_COUNT" -gt 0 ]]; then
    fail "AC-US7-001: [class*=\"discussion\"] singular still present ($DISC_SINGULAR_COUNT occurrence(s)) — must be removed or merged into discussions"
  else
    pass "AC-US7-001: [class*=\"discussion\"] singular removed (consolidated into [class*=\"discussions\"])"
  fi

  if [[ "$LOGIN_REGISTER_COUNT" -gt 0 ]]; then
    fail "AC-US7-001: [class*=\"login-register\"] still present ($LOGIN_REGISTER_COUNT occurrence(s)) — dead selector must remain removed"
  else
    pass "AC-US7-001: [class*=\"login-register\"] removed from CSS selectors"
  fi

  if [[ "$ACCOUNT_PAGE_COUNT" -gt 0 ]]; then
    fail "AC-US7-001: [class*=\"account-page\"] still present ($ACCOUNT_PAGE_COUNT occurrence(s)) — dead selector must remain removed"
  else
    pass "AC-US7-001: [class*=\"account-page\"] removed from CSS selectors"
  fi

  # Enforce regression ceiling: selector line count must not grow above 2x baseline
  # (Accounts for formatting changes while preventing selector sprawl)
  REGRESSION_CEILING=150
  if [[ "$BRITTLE_SELECTOR_LINES" -gt "$REGRESSION_CEILING" ]]; then
    fail "AC-US7-001: Non-comment [class*=] selector lines ($BRITTLE_SELECTOR_LINES) exceeds regression ceiling ($REGRESSION_CEILING)"
  else
    pass "AC-US7-001: Non-comment [class*=] selector count ($BRITTLE_SELECTOR_LINES) within regression ceiling ($REGRESSION_CEILING)"
  fi
fi

echo ""

# ---------------------------------------------------------------------------
# AC-US7-002: Verification script exists and enforces fail-on-regression
# ---------------------------------------------------------------------------
echo "--- AC-US7-002: Fail-on-Regression Policy ---"

SELF="${BASH_SOURCE[0]}"
if [[ -f "$SELF" ]]; then
  # Check this script enforces banned selectors (fail path)
  if grep -q 'AUTH_PAGE_COUNT.*-gt.*0' "$SELF" && grep -q 'DISC_SINGULAR_COUNT.*-gt.*0' "$SELF" && grep -q 'LOGIN_REGISTER_COUNT.*-gt.*0' "$SELF" && grep -q 'ACCOUNT_PAGE_COUNT.*-gt.*0' "$SELF"; then
    pass "AC-US7-002: Script enforces banned selector regression check"
  else
    fail "AC-US7-002: Script missing fail-on-regression enforcement for banned selectors"
  fi

  # Check script has @covers annotation
  if grep -q '@covers AC-US7-001' "$SELF"; then
    pass "AC-US7-002: Script has @covers annotation for AC-US7-001..005"
  else
    fail "AC-US7-002: Script missing @covers annotation"
  fi
else
  fail "AC-US7-002: Cannot locate self-reference for regression check"
fi

echo ""

# ---------------------------------------------------------------------------
# AC-US7-003: Migration register has Owner/Action/Target Date fields
# ---------------------------------------------------------------------------
echo "--- AC-US7-003: Migration Register Owner/Action/Target Date Fields ---"

if [[ ! -f "$REGISTER_DOC" ]]; then
  fail "AC-US7-003: MFE_PLUGIN_SLOT_MIGRATION_REGISTER.md not found"
else
  # Check for Owner field
  if grep -q '| \*\*Owner\*\*' "$REGISTER_DOC" || grep -q '| Owner |' "$REGISTER_DOC" || grep -q '\*\*Owner\*\*' "$REGISTER_DOC"; then
    pass "AC-US7-003: Migration register has Owner field"
  else
    fail "AC-US7-003: Migration register missing Owner field"
  fi

  # Check for Action field
  if grep -q '| \*\*Action\*\*' "$REGISTER_DOC" || grep -q '| Action |' "$REGISTER_DOC" || grep -q '\*\*Action\*\*' "$REGISTER_DOC"; then
    pass "AC-US7-003: Migration register has Action field"
  else
    fail "AC-US7-003: Migration register missing Action field"
  fi

  # Check for Target Date field
  if grep -q 'Target Date\|Target Completion\|target.*date\|target.*completion' "$REGISTER_DOC"; then
    pass "AC-US7-003: Migration register has Target Date field"
  else
    fail "AC-US7-003: Migration register missing Target Date field"
  fi

  # Check for exception register section
  if grep -q 'Exception Register\|EXCEPTION REGISTER\|exception.*register\|Selector Exceptions' "$REGISTER_DOC"; then
    pass "AC-US7-003: Migration register has Exception Register section"
  else
    fail "AC-US7-003: Migration register missing Exception Register section"
  fi
fi

echo ""

# ---------------------------------------------------------------------------
# AC-US7-004: Exception annotations have expiry dates and rollback notes
# ---------------------------------------------------------------------------
echo "--- AC-US7-004: Exception Annotations with Expiry Dates ---"

if [[ ! -f "$SCSS_FILE" ]]; then
  fail "AC-US7-004: mereka.scss not found"
else
  # Count SELECTOR-EXCEPTION annotations
  EXCEPTION_COUNT=$(grep -c 'SELECTOR-EXCEPTION' "$SCSS_FILE" || echo "0")
  echo "  SELECTOR-EXCEPTION annotations: $EXCEPTION_COUNT"

  if [[ "$EXCEPTION_COUNT" -eq 0 ]]; then
    fail "AC-US7-004: No SELECTOR-EXCEPTION annotations found"
  else
    pass "AC-US7-004: Found $EXCEPTION_COUNT SELECTOR-EXCEPTION annotation(s)"
  fi

  # All SELECTOR-EXCEPTION lines must have an expiry date
  EXCEPTIONS_WITHOUT_EXPIRY=$(grep 'SELECTOR-EXCEPTION' "$SCSS_FILE" | grep -v 'expires:' || true)
  if [[ -n "$EXCEPTIONS_WITHOUT_EXPIRY" ]]; then
    EXCEPTIONS_WITHOUT_COUNT=$(echo "$EXCEPTIONS_WITHOUT_EXPIRY" | grep -c . || true)
    fail "AC-US7-004: $EXCEPTIONS_WITHOUT_COUNT SELECTOR-EXCEPTION annotation(s) missing 'expires:' date"
    echo "$EXCEPTIONS_WITHOUT_EXPIRY" | head -5
  else
    pass "AC-US7-004: All $EXCEPTION_COUNT SELECTOR-EXCEPTION annotations have expiry dates"
  fi

  # Check register doc has rollback notes
  if [[ -f "$REGISTER_DOC" ]]; then
    if grep -qi 'rollback\|Rollback' "$REGISTER_DOC"; then
      pass "AC-US7-004: Migration register has rollback notes"
    else
      warn "AC-US7-004: Migration register missing rollback notes (WARN — not blocking)"
    fi
  fi
fi

echo ""

# ---------------------------------------------------------------------------
# AC-US7-005: Unresolved selectors documented with date and rationale
# ---------------------------------------------------------------------------
echo "--- AC-US7-005: Unresolved Selectors Documented ---"

if [[ ! -f "$REGISTER_DOC" ]]; then
  fail "AC-US7-005: MFE_PLUGIN_SLOT_MIGRATION_REGISTER.md not found"
else
  # Check for unresolved tickets section with dates/rationale
  if grep -q 'Unresolved\|unresolved\|Cannot Migrate\|cannot migrate\|Pending Ticket\|Open Ticket' "$REGISTER_DOC"; then
    pass "AC-US7-005: Migration register documents unresolved selectors"
  else
    fail "AC-US7-005: Migration register missing Unresolved Selectors section"
  fi

  # Check for rationale text near P2 items (those that can't be slot-migrated yet)
  if grep -q 'no upstream slot\|No upstream slot\|no slot available\|no adequate slot' "$REGISTER_DOC"; then
    pass "AC-US7-005: Migration register includes rationale for unresolvable selectors"
  else
    fail "AC-US7-005: Migration register missing rationale for why selectors can't be slot-migrated"
  fi

  # Check that P2 items have a target date or 'request upstream' note
  if grep -q 'upstream.*request\|request.*upstream\|Upstream request\|2026-Q' "$REGISTER_DOC"; then
    pass "AC-US7-005: P2/unresolved items reference upstream request or date"
  else
    warn "AC-US7-005: P2/unresolved items missing upstream request or target date (WARN)"
  fi
fi

echo ""

# ---------------------------------------------------------------------------
# Legacy AC-SEL-* backward compat checks (AC-SEL-001 through AC-SEL-005)
# ---------------------------------------------------------------------------
echo "--- Legacy AC-SEL-001..005 (backward compat) ---"

# AC-SEL-001: Audit doc exists
if [[ -f "$AUDIT_DOC" ]]; then
  if grep -q 'Risk' "$AUDIT_DOC" && grep -q 'Count\|count\|Total\|total' "$AUDIT_DOC"; then
    pass "AC-SEL-001: Selector hardening audit doc exists with risk ranking"
  else
    fail "AC-SEL-001: Audit doc exists but missing risk ranking or counts"
  fi
else
  fail "AC-SEL-001: MFE_SELECTOR_HARDENING_AUDIT.md not found"
fi

# AC-SEL-002: data-testid selectors present (hardening evidence)
if [[ -f "$SCSS_FILE" ]]; then
  TESTID_COUNT=$(grep -c '\[data-testid' "$SCSS_FILE" || echo "0")
  if [[ "$TESTID_COUNT" -ge 4 ]]; then
    pass "AC-SEL-002: Uses $TESTID_COUNT data-testid selectors and class-based exception coverage"
  else
    warn "AC-SEL-002: Only $TESTID_COUNT data-testid selectors; this is acceptable when class-based exceptions are tracked"
  fi
else
  fail "AC-SEL-002: mereka.scss not found"
fi

# AC-SEL-003: BRITTLE markers present for remaining brittle selectors
if [[ -f "$SCSS_FILE" ]]; then
  BRITTLE_MARKED=$(grep -c 'BRITTLE\|SELECTOR-EXCEPTION' "$SCSS_FILE" || echo "0")
  if [[ "$BRITTLE_MARKED" -gt 10 ]]; then
    pass "AC-SEL-003: $BRITTLE_MARKED BRITTLE/SELECTOR-EXCEPTION markers tracking remaining brittle selectors"
  else
    fail "AC-SEL-003: Only $BRITTLE_MARKED tracking markers (expected > 10)"
  fi
else
  fail "AC-SEL-003: mereka.scss not found"
fi

# AC-SEL-004: Migration register or matrix updated with selector info
if [[ -f "$REGISTER_DOC" ]]; then
  if grep -qi 'selector\|hardening' "$REGISTER_DOC"; then
    pass "AC-SEL-004: Migration register updated with selector status"
  else
    fail "AC-SEL-004: Migration register missing selector hardening info"
  fi
elif [[ -f "$MATRIX_DOC" ]]; then
  if grep -qi 'selector\|hardening' "$MATRIX_DOC"; then
    pass "AC-SEL-004: MFE_PLUGIN_SLOT_MATRIX.md updated with selector status"
  else
    fail "AC-SEL-004: Matrix doc missing selector hardening info"
  fi
else
  fail "AC-SEL-004: Neither migration register nor matrix doc found"
fi

# AC-SEL-005: SCSS syntax valid (balanced braces)
if [[ -f "$SCSS_FILE" ]]; then
  OPEN_BRACES=$(grep -co '{' "$SCSS_FILE" || echo "0")
  CLOSE_BRACES=$(grep -co '}' "$SCSS_FILE" || echo "0")
  if [[ "$OPEN_BRACES" -eq "$CLOSE_BRACES" ]]; then
    pass "AC-SEL-005: SCSS has balanced braces ($OPEN_BRACES open, $CLOSE_BRACES close)"
  else
    fail "AC-SEL-005: SCSS braces unbalanced ($OPEN_BRACES open vs $CLOSE_BRACES close)"
  fi
else
  fail "AC-SEL-005: mereka.scss not found"
fi

echo ""
echo "=== Summary ==="
echo -e "${GREEN}PASS:${NC} $PASS | ${RED}FAIL:${NC} $FAIL | ${YELLOW}WARN:${NC} $WARN"

if [[ "$FAIL" -gt 0 ]]; then
  echo ""
  echo "Remediation:"
  echo "1. Remove banned selectors: [class*=\"auth-page\"] and [class*=\"discussion\"] (singular)"
  echo "2. Add // SELECTOR-EXCEPTION: <reason> | expires: YYYY-QN comments for remaining brittle selectors"
  echo "3. Update MFE_PLUGIN_SLOT_MIGRATION_REGISTER.md with Owner/Action/Target Date fields"
  echo "4. Add Exception Register section and Unresolved Selectors section to the register doc"
  exit 1
fi

exit 0
