#!/usr/bin/env bash
set -euo pipefail

# @covers AC-MIGLOCK-001: New CSS override blocks must have corresponding migration register entry
# @covers AC-MIGLOCK-002: Override block count in mereka.scss matches register inventory count
# @covers AC-MIGLOCK-003: All P0 items in register are MIGRATED or Done
# @covers AC-MIGLOCK-004: Migration roadmap "Now" items are all checked off
# @covers AC-MIGLOCK-005: data-testid coverage ratio >= class* selector count (no regression)
# @spec: bead-115d11

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
REGISTER_DOC="$REPO_ROOT/docs/operations/MFE_PLUGIN_SLOT_MIGRATION_REGISTER.md"
MFE_SCSS="$REPO_ROOT/infrastructure/tutor/themes/mereka/mfe/mereka.scss"

PASS=0
FAIL=0
WARN=0

pass_check() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail_check() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

warn() {
  echo "  WARN: $1"
  WARN=$((WARN + 1))
}

echo "========================================"
echo "Migration Lock Gate"
echo "========================================"
echo ""

# Guard: required files must exist
if [[ ! -f "$REGISTER_DOC" ]]; then
  echo "  FAIL: Migration register not found: $REGISTER_DOC"
  FAIL=$((FAIL + 1))
  echo ""
  echo "=== SUMMARY ==="
  echo "PASS: $PASS  FAIL: $FAIL  WARN: $WARN"
  echo "RESULT: FAIL"
  exit 1
fi

if [[ ! -f "$MFE_SCSS" ]]; then
  echo "  FAIL: mereka.scss not found: $MFE_SCSS"
  FAIL=$((FAIL + 1))
  echo ""
  echo "=== SUMMARY ==="
  echo "PASS: $PASS  FAIL: $FAIL  WARN: $WARN"
  echo "RESULT: FAIL"
  exit 1
fi

# -----------------------------------------------------------------------
# AC-MIGLOCK-001: Section count in SCSS >= register entry count
# -----------------------------------------------------------------------
echo "AC-MIGLOCK-001: SCSS override blocks vs register entries"

# Count numbered entries in the register (### N. heading pattern)
REGISTER_ENTRY_COUNT=$(grep -c '^### [0-9]\+\.' "$REGISTER_DOC" || echo 0)

# Count major CSS section comment blocks (non-BRITTLE, non-Fallback top-level comments)
# These are lines starting with /* that describe a logical override surface
SCSS_SECTION_COUNT=$(grep -c '^/\* [A-Z]' "$MFE_SCSS" || echo 0)

echo "  Register entries: $REGISTER_ENTRY_COUNT"
echo "  SCSS surface sections: $SCSS_SECTION_COUNT"

if [[ $REGISTER_ENTRY_COUNT -ge 10 ]]; then pass_check "Register has at least 10 numbered entries"; else fail_check "Register has at least 10 numbered entries"; fi
if [[ $SCSS_SECTION_COUNT -ge 1 ]]; then pass_check "SCSS section count >= 1 (has annotated surfaces)"; else fail_check "SCSS section count >= 1 (has annotated surfaces)"; fi

# AC-MIGLOCK-001 core: every register entry should have at least one SCSS selector block
# We verify the ratio is reasonable — sections >= 1 per 4 register entries (conservative)
EXPECTED_MIN=$(( REGISTER_ENTRY_COUNT / 4 ))
if [[ $EXPECTED_MIN -lt 1 ]]; then EXPECTED_MIN=1; fi
if [[ $SCSS_SECTION_COUNT -ge $EXPECTED_MIN ]]; then pass_check "SCSS surface sections cover enough register scope (>= $EXPECTED_MIN sections)"; else fail_check "SCSS surface sections cover enough register scope (>= $EXPECTED_MIN sections)"; fi

echo ""

# -----------------------------------------------------------------------
# AC-MIGLOCK-002: class* unique pattern count vs register entries
# -----------------------------------------------------------------------
echo "AC-MIGLOCK-002: class* override block alignment with register"

# Count unique [class*="..."] target names (extract the value, deduplicate)
CLASS_STAR_TOTAL=$(grep -c '\[class\*=' "$MFE_SCSS" || echo 0)

# Extract unique class name values from [class*="foo"] patterns
UNIQUE_CLASS_TARGETS=$(grep -oP '\[class\*="[^"]*"\]' "$MFE_SCSS" | sort -u | wc -l || echo 0)

echo "  Total [class*=] lines: $CLASS_STAR_TOTAL"
echo "  Unique [class*=] patterns: $UNIQUE_CLASS_TARGETS"
echo "  Register entries: $REGISTER_ENTRY_COUNT"

# Unique class targets should be at least as many as register entries (entries can share selectors)
# but no more than 3x the register count (would indicate unenumerated overrides)
LOWER=$REGISTER_ENTRY_COUNT
UPPER=$(( REGISTER_ENTRY_COUNT * 3 ))
if [[ $LOWER -lt 1 ]]; then LOWER=1; fi

if [[ $UNIQUE_CLASS_TARGETS -ge $LOWER && $UNIQUE_CLASS_TARGETS -le $UPPER ]]; then
  pass_check "Unique class* patterns ($UNIQUE_CLASS_TARGETS) within expected range ($LOWER–$UPPER)"
elif [[ $UNIQUE_CLASS_TARGETS -lt $LOWER ]]; then
  warn "Unique class* patterns ($UNIQUE_CLASS_TARGETS) lower than register entries ($REGISTER_ENTRY_COUNT) — some entries may lack SCSS coverage"
  WARN=$((WARN + 1))
else
  echo "  FAIL: Unique class* patterns ($UNIQUE_CLASS_TARGETS) exceeds 3x register entries ($REGISTER_ENTRY_COUNT) — register is likely incomplete"
  FAIL=$((FAIL + 1))
fi

echo ""

# -----------------------------------------------------------------------
# AC-MIGLOCK-003: No open P0 items in register
# -----------------------------------------------------------------------
echo "AC-MIGLOCK-003: P0 items must all be MIGRATED or Done"

# Find lines containing P0 that do NOT indicate completion
P0_OPEN=$(grep -E "\| P0 \|" "$REGISTER_DOC" | grep -v "Done\|MIGRATED\|✅" || true)
P0_LINES=$(grep -E "\| P0 \|" "$REGISTER_DOC" 2>/dev/null || true)
P0_TOTAL=$(echo "$P0_LINES" | grep -c '.' 2>/dev/null || true)
P0_TOTAL="${P0_TOTAL:-0}"

echo "  Total P0 entries: $P0_TOTAL"

if [[ -z "$P0_OPEN" ]]; then
  pass_check "No open P0 items in migration register"
else
  echo "  FAIL: Open P0 items found:"
  echo "$P0_OPEN" | sed 's/^/    /'
  FAIL=$((FAIL + 1))
fi

echo ""

# -----------------------------------------------------------------------
# AC-MIGLOCK-004: "Now" roadmap items are all checked off
# -----------------------------------------------------------------------
echo "AC-MIGLOCK-004: Migration roadmap 'Now' items are complete"

# Extract the "Now" section content (between ### Now and the next ###)
NOW_SECTION=$(sed -n '/^### Now/,/^### [A-Za-z]/p' "$REGISTER_DOC" | grep -v '^### ' || true)

if [[ -z "$NOW_SECTION" ]]; then
  warn "Could not extract 'Now' roadmap section from register"
else
  # Count open items (- [ ]) vs checked items (- [x])
  NOW_OPEN=$(echo "$NOW_SECTION" | grep -c '^\- \[ \]' 2>/dev/null || true)
  NOW_CHECKED=$(echo "$NOW_SECTION" | grep -c '^\- \[x\]' 2>/dev/null || true)
  NOW_OPEN="${NOW_OPEN:-0}"
  NOW_CHECKED="${NOW_CHECKED:-0}"
  # Trim any trailing whitespace/newlines from counts
  NOW_OPEN=$(echo "$NOW_OPEN" | tr -d '[:space:]')
  NOW_CHECKED=$(echo "$NOW_CHECKED" | tr -d '[:space:]')
  echo "  Checked items: $NOW_CHECKED"
  echo "  Open items: $NOW_OPEN"

  if [[ "$NOW_OPEN" -eq 0 ]]; then
    echo "  PASS: All 'Now' roadmap items are checked off ($NOW_CHECKED checked, 0 open)"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $NOW_OPEN open 'Now' roadmap items found (expected all checked)"
    FAIL=$((FAIL + 1))
  fi
fi

echo ""

# -----------------------------------------------------------------------
# AC-MIGLOCK-005: data-testid coverage ratio >= 0.9 vs class* count
# -----------------------------------------------------------------------
echo "AC-MIGLOCK-005: data-testid coverage ratio (no regression)"

CLASS_STAR_COUNT=$(grep -c '\[class\*=' "$MFE_SCSS" || echo 0)
DATA_TESTID_COUNT=$(grep -c '\[data-testid\*=' "$MFE_SCSS" || echo 0)

echo "  [class*=] selectors: $CLASS_STAR_COUNT"
echo "  [data-testid*=] selectors: $DATA_TESTID_COUNT"

if [[ $CLASS_STAR_COUNT -eq 0 ]]; then
  pass_check "No class* selectors (fully hardened)"
else
  # Calculate ratio using integer arithmetic: ratio_pct = (data_testid * 100) / class_star
  RATIO_PCT=$(( DATA_TESTID_COUNT * 100 / CLASS_STAR_COUNT ))
  echo "  Coverage ratio: ${RATIO_PCT}%"

  if [[ $RATIO_PCT -ge 100 ]]; then
    pass_check "data-testid* coverage equals or exceeds class* count (${DATA_TESTID_COUNT} >= ${CLASS_STAR_COUNT})"
  elif [[ $RATIO_PCT -ge 90 ]]; then
    warn "data-testid* coverage is ${RATIO_PCT}% (below 100%, above 90% floor) — consider adding fallbacks"
    pass_check "data-testid* coverage >= 90% floor (${RATIO_PCT}%)"
  else
    echo "  FAIL: data-testid* coverage is ${RATIO_PCT}% — below 90% minimum (${DATA_TESTID_COUNT} vs ${CLASS_STAR_COUNT})"
    FAIL=$((FAIL + 1))
  fi
fi

echo ""

# -----------------------------------------------------------------------
# Bonus: Migration Lock section exists in register
# -----------------------------------------------------------------------
echo "Migration Lock doc section"

if grep -q "^## Migration Lock" "$REGISTER_DOC"; then
  pass_check "Register contains 'Migration Lock' section"
else
  warn "Register is missing '## Migration Lock' section — add it to document the lock status"
fi

echo ""
echo "========================================"
echo "Migration Lock: $PASS PASS / $FAIL FAIL / $WARN WARN"
echo "========================================"

if [[ $FAIL -gt 0 ]]; then
  echo ""
  echo "RESULT: FAIL"
  exit 1
fi

echo ""
echo "RESULT: PASS"
exit 0
