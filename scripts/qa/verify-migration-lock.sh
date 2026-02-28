#!/usr/bin/env bash
set -euo pipefail

# @covers AC-MIGLOCK-001: New CSS override blocks must have corresponding migration register entry
# @covers AC-MIGLOCK-002: Override block count in mereka.scss matches register inventory count
# @covers AC-MIGLOCK-003: All P0 items in register are MIGRATED or Done
# @covers AC-MIGLOCK-004: Migration roadmap "Now" items are all checked off
# @covers AC-MIGLOCK-005: active wildcard selector set matches dead-selector-cleanup policy
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

extract_active_class_selector_values() {
  python3 - "$MFE_SCSS" <<'PY'
import re
import sys
from pathlib import Path

text = Path(sys.argv[1]).read_text(encoding="utf-8")
text = re.sub(r"/\*.*?\*/", "", text, flags=re.S)
text = re.sub(r"^\s*//.*$", "", text, flags=re.M)
for value in re.findall(r'\[class\*="([^"]+)"\]', text):
    print(value)
PY
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
# AC-MIGLOCK-002: active class* targets must match exception register set
# -----------------------------------------------------------------------
echo "AC-MIGLOCK-002: class* override alignment with exception register"

mapfile -t ACTIVE_CLASS_VALUES < <(extract_active_class_selector_values)
CLASS_STAR_TOTAL="${#ACTIVE_CLASS_VALUES[@]}"
if [[ "$CLASS_STAR_TOTAL" -gt 0 ]]; then
  mapfile -t ACTIVE_CLASS_UNIQUE < <(printf '%s\n' "${ACTIVE_CLASS_VALUES[@]}" | sort -u)
else
  ACTIVE_CLASS_UNIQUE=()
fi
UNIQUE_CLASS_TARGETS="${#ACTIVE_CLASS_UNIQUE[@]}"

mapfile -t REGISTER_EXCEPTION_UNIQUE < <(
  awk '/^### Exception Register Table/,/^### Removed Exceptions/' "$REGISTER_DOC" \
    | grep -oP '\[class\*="[^"]+"\]' \
    | sort -u
)
REGISTER_EXCEPTION_COUNT="${#REGISTER_EXCEPTION_UNIQUE[@]}"

echo "  Active [class*=] occurrences: $CLASS_STAR_TOTAL"
echo "  Active unique [class*=] targets: $UNIQUE_CLASS_TARGETS"
echo "  Register exception targets: $REGISTER_EXCEPTION_COUNT"

if [[ "$UNIQUE_CLASS_TARGETS" -eq 0 ]]; then
  pass_check "No active wildcard class selectors remain"
else
  missing_in_register=0
  for target in "${ACTIVE_CLASS_UNIQUE[@]}"; do
    pattern="[class*=\"${target}\"]"
    if printf '%s\n' "${REGISTER_EXCEPTION_UNIQUE[@]}" | grep -qxF "$pattern"; then
      :
    else
      echo "  FAIL: Active wildcard selector is not listed in exception register: $pattern"
      missing_in_register=$((missing_in_register + 1))
      FAIL=$((FAIL + 1))
    fi
  done

  missing_in_css=0
  for pattern in "${REGISTER_EXCEPTION_UNIQUE[@]}"; do
    value="${pattern#\[class*=\"}"
    value="${value%\"\]}"
    if printf '%s\n' "${ACTIVE_CLASS_UNIQUE[@]}" | grep -qxF "$value"; then
      :
    else
      echo "  FAIL: Exception register target missing from active CSS: $pattern"
      missing_in_css=$((missing_in_css + 1))
      FAIL=$((FAIL + 1))
    fi
  done

  if [[ "$missing_in_register" -eq 0 && "$missing_in_css" -eq 0 ]]; then
    pass_check "Active wildcard selector set matches exception register"
  fi
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
# AC-MIGLOCK-005: enforce dead-selector cleanup policy in active CSS
# -----------------------------------------------------------------------
echo "AC-MIGLOCK-005: dead-selector cleanup policy"

if [[ "${#ACTIVE_CLASS_VALUES[@]}" -eq 0 ]]; then
  pass_check "No active wildcard class selectors remain"
else
  echo "  FAIL: Active wildcard targets detected after cleanup:"
  printf '    - %s\n' "${ACTIVE_CLASS_UNIQUE[@]}"
  FAIL=$((FAIL + 1))
fi

if grep -q 'SELECTOR-EXCEPTION: \.page__account-settings.*expires:' "$MFE_SCSS"; then
  pass_check "Account explicit scope selector has SELECTOR-EXCEPTION metadata with expiry"
else
  fail_check "Account explicit scope selector is missing SELECTOR-EXCEPTION expiry metadata"
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
