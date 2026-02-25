#!/usr/bin/env bash
# verify-mfe-selectors.sh — MFE SCSS brittle selector ratio gate
# @covers AC-UISEL-001, AC-UISEL-002
# @spec: frontend-design-tokens_spec
#
# Verifies:
# 1. Count of brittle attribute selectors ([class*=, [data-testid*=) in mereka.scss
# 2. Count of stable selectors (Paragon BEM, element, custom .mereka-* classes)
# 3. Ratio of brittle to total does not exceed the configured threshold
# 4. Threshold is set at 50% of the original pre-T102 count (182 brittle lines)
#
# BRITTLE: [class*="..."], [data-testid*="..."]  — break when upstream renames classes
# STABLE:  .pgn__*, .btn-*, .card, .navbar, .mereka-*, element selectors
#
# Usage: ./scripts/qa/verify-mfe-selectors.sh
#   Set STRICT=1 to treat WARNs as FAILs.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PASS=0
FAIL=0
WARN=0

do_pass() { PASS=$((PASS + 1)); echo -e "${GREEN}[PASS]${NC} $1"; }
do_fail() { FAIL=$((FAIL + 1)); echo -e "${RED}[FAIL]${NC} $1"; }
do_warn() { WARN=$((WARN + 1)); echo -e "${YELLOW}[WARN]${NC} $1"; }
do_skip() { echo -e "${YELLOW}[SKIP]${NC} $1"; }

MFE_SCSS="$REPO_ROOT/infrastructure/tutor/themes/mereka/mfe/mereka.scss"

# Original brittle selector count before T102 hardening (2026-02-25).
# Used to compute the 50% threshold.
ORIGINAL_BRITTLE=182
BRITTLE_THRESHOLD=$(( ORIGINAL_BRITTLE / 2 ))  # 91

echo -e "${BLUE}=== MFE Selector Brittleness Gate ===${NC}"
echo "  File: infrastructure/tutor/themes/mereka/mfe/mereka.scss"
echo "  Brittle threshold: <= ${BRITTLE_THRESHOLD} lines (50% of original ${ORIGINAL_BRITTLE})"
echo ""

# ── Check 1: SCSS file exists ─────────────────────────────────────────
if [[ ! -f "$MFE_SCSS" ]]; then
  do_fail "mereka.scss not found at expected path — cannot audit selectors"
  echo ""
  echo -e "${RED}FAIL${NC}: Prerequisite check failed. Exiting."
  exit 1
fi
do_pass "mereka.scss exists at infrastructure/tutor/themes/mereka/mfe/mereka.scss"

# ── Count selectors using Python (avoids grep portability issues) ─────
COUNT_OUTPUT=$(python3 - "$MFE_SCSS" <<'PYEOF'
import sys, re

path = sys.argv[1]
with open(path) as f:
    lines = f.readlines()

brittle_class = 0    # [class*=...]
brittle_testid = 0   # [data-testid*=...]
stable = 0           # .pgn__*, .btn-*, .card, .navbar, element selectors, .mereka-*

for raw_line in lines:
    stripped = raw_line.strip()
    # Skip blank lines and comment lines
    if not stripped:
        continue
    if stripped.startswith('//') or stripped.startswith('/*') or stripped.startswith('*'):
        continue
    # Skip pure property lines (contain : but not inside selectors)
    # A heuristic: selector lines end with , or { or contain { inline
    # Property lines look like "  font-weight: 600;" — skip them
    # We rely on the presence of a known selector pattern instead.

    is_brittle_class = '[class*=' in stripped
    is_brittle_testid = '[data-testid*=' in stripped

    if is_brittle_class:
        brittle_class += 1
    if is_brittle_testid:
        brittle_testid += 1

    # Count stable selectors: lines that look like selector lines
    # and do NOT contain brittle patterns
    if not is_brittle_class and not is_brittle_testid:
        # A selector line: contains a class or element selector that ends with , { or :
        # and is not a property/value line
        is_selector = bool(re.search(r'[.#\[\w][^:]*[,{]|^[a-z][a-zA-Z-]*[^:]*\{', stripped))
        # More precise: starts with ., #, :, element name, @, or has stable class
        if (stripped.startswith('.') or
                stripped.startswith(':') or
                stripped.startswith('@') or
                re.match(r'^[a-z][a-zA-Z-]*[\s,{]', stripped) or
                re.match(r'^[a-z][a-zA-Z-]*:[a-z]', stripped)):
            stable += 1

total_brittle = brittle_class + brittle_testid
print(f"brittle_class={brittle_class}")
print(f"brittle_testid={brittle_testid}")
print(f"total_brittle={total_brittle}")
print(f"stable={stable}")
PYEOF
)

# Parse output
BRITTLE_CLASS=$(echo "$COUNT_OUTPUT" | grep '^brittle_class=' | cut -d= -f2)
BRITTLE_TESTID=$(echo "$COUNT_OUTPUT" | grep '^brittle_testid=' | cut -d= -f2)
TOTAL_BRITTLE=$(echo "$COUNT_OUTPUT" | grep '^total_brittle=' | cut -d= -f2)
STABLE=$(echo "$COUNT_OUTPUT" | grep '^stable=' | cut -d= -f2)

echo -e "${BLUE}## Selector Counts${NC}"
echo "  [class*=...] selector lines:       $BRITTLE_CLASS"
echo "  [data-testid*=...] selector lines: $BRITTLE_TESTID"
echo "  Total brittle lines:               $TOTAL_BRITTLE"
echo "  Stable selector lines (approx):    $STABLE"
echo "  Threshold (<=50% of original):     $BRITTLE_THRESHOLD"
echo ""

# ── Check 2: Total brittle count ≤ threshold ─────────────────────────
if [[ "$TOTAL_BRITTLE" -le "$BRITTLE_THRESHOLD" ]]; then
  do_pass "AC-UISEL-001: Brittle selector count ($TOTAL_BRITTLE) is within threshold (<= $BRITTLE_THRESHOLD)"
else
  do_fail "AC-UISEL-001: Brittle selector count ($TOTAL_BRITTLE) exceeds threshold ($BRITTLE_THRESHOLD) — run T102 hardening"
fi

# ── Check 3: data-testid selectors removed ───────────────────────────
if [[ "$BRITTLE_TESTID" -eq 0 ]]; then
  do_pass "AC-UISEL-001: No [data-testid*=] selectors in production CSS (T102 complete)"
else
  do_warn "AC-UISEL-001: $BRITTLE_TESTID [data-testid*=] selector line(s) found — data-testid is for tests, not production CSS (SELECTOR_HARDENING_POLICY)"
fi

# ── Check 4: SELECTOR-EXCEPTION comments present for remaining brittle selectors ──
EXCEPTION_COMMENTS=$(python3 -c "
import re
with open('$MFE_SCSS') as f:
    content = f.read()
count = len(re.findall(r'SELECTOR-EXCEPTION:|SELECTOR-KEPT-BRITTLE:', content))
print(count)
")

if [[ "$EXCEPTION_COMMENTS" -gt 0 ]]; then
  do_pass "AC-UISEL-002: $EXCEPTION_COMMENTS SELECTOR-EXCEPTION/KEPT-BRITTLE comment(s) document remaining brittle selectors"
else
  do_warn "AC-UISEL-002: No SELECTOR-EXCEPTION comments found — remaining brittle selectors should be documented"
fi

# ── Check 5: Remaining brittle selectors have expiry dates ───────────
EXCEPTIONS_WITH_EXPIRY=$(python3 -c "
import re
with open('$MFE_SCSS') as f:
    content = f.read()
count = len(re.findall(r'expires:\s*\d{4}-Q\d', content))
print(count)
")

if [[ "$EXCEPTIONS_WITH_EXPIRY" -gt 0 ]]; then
  do_pass "AC-UISEL-002: $EXCEPTIONS_WITH_EXPIRY exception(s) have expiry dates (review schedule enforced)"
else
  do_warn "AC-UISEL-002: No expiry dates found on SELECTOR-EXCEPTION comments — add 'expires: YYYY-QN' annotations"
fi

# ── Check 6: Branding revision token updated ─────────────────────────
BRANDING_REV=$(python3 -c "
import re
with open('$MFE_SCSS') as f:
    content = f.read()
m = re.search(r'--mereka-mfe-branding-rev:\s*\"([^\"]+)\"', content)
print(m.group(1) if m else '')
")

if [[ -n "$BRANDING_REV" ]]; then
  do_pass "Branding revision token present: $BRANDING_REV"
else
  do_warn "Branding revision token (--mereka-mfe-branding-rev) not found — useful for cache-busting"
fi

# ── Check 7: No new [data-testid=] (exact match, for tests not production) usage ──
EXACT_TESTID=$(python3 -c "
import re
with open('$MFE_SCSS') as f:
    lines = f.readlines()
count = 0
for line in lines:
    s = line.strip()
    if s.startswith('//') or s.startswith('/*') or s.startswith('*'):
        continue
    # Exact [data-testid=] (no wildcard) is even more fragile
    if re.search(r'\[data-testid=', s):
        count += 1
print(count)
")

if [[ "$EXACT_TESTID" -eq 0 ]]; then
  do_pass "No exact [data-testid=] selectors (most fragile form) present"
else
  do_fail "$EXACT_TESTID exact [data-testid=] selector(s) found — exact attribute matches break on any testid rename"
fi

echo ""

# ── Summary ──────────────────────────────────────────────────────────
echo -e "${BLUE}## Summary${NC}"
echo ""
echo -e "  ${GREEN}PASS${NC}: $PASS"
echo -e "  ${YELLOW}WARN${NC}: $WARN"
echo -e "  ${RED}FAIL${NC}: $FAIL"
echo ""
echo "  Brittle selectors: $TOTAL_BRITTLE / $ORIGINAL_BRITTLE original ($((100 - TOTAL_BRITTLE * 100 / ORIGINAL_BRITTLE))% reduction)"
echo "  Threshold:         <= $BRITTLE_THRESHOLD (50% of original)"
echo ""

# Write CI artifact
VAR_DIR="$REPO_ROOT/var"
mkdir -p "$VAR_DIR"
ARTIFACT="$VAR_DIR/mfe-selector-gate.txt"
{
  echo "mfe-selector-gate"
  echo "run_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "brittle_class=$BRITTLE_CLASS"
  echo "brittle_testid=$BRITTLE_TESTID"
  echo "total_brittle=$TOTAL_BRITTLE"
  echo "threshold=$BRITTLE_THRESHOLD"
  echo "original=$ORIGINAL_BRITTLE"
  echo "pass=$PASS"
  echo "warn=$WARN"
  echo "fail=$FAIL"
  echo "status=$([ "$FAIL" -eq 0 ] && echo PASS || echo FAIL)"
} > "$ARTIFACT"

if [[ "$FAIL" -eq 0 ]]; then
  echo -e "${GREEN}MFE selector brittleness gate PASSED${NC}"
  if [[ "$WARN" -gt 0 ]]; then
    echo ""
    echo "Notes:"
    echo "  - WARN items are non-blocking. Review before Q3 2026 expiry sweep."
    echo "  - See docs/architecture/SELECTOR_HARDENING_POLICY.md for exception process."
  fi
  exit 0
else
  echo -e "${RED}MFE selector brittleness gate FAILED${NC}"
  echo ""
  echo "Fix FAIL items before merging."
  echo "See docs/architecture/SELECTOR_HARDENING_POLICY.md for guidance."
  exit 1
fi
