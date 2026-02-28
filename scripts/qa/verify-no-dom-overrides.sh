#!/usr/bin/env bash
set -euo pipefail
# @spec: branding-system_spec.md
# @covers AC-FTR-001, AC-FTR-002, AC-FTR-003, AC-FTR-004

PASS=0
FAIL=0
WARN=0

pass() { PASS=$((PASS + 1)); echo "  PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "  FAIL: $1"; }
warn() { WARN=$((WARN + 1)); echo "  WARN: $1"; }

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
THEME_DIR="$REPO_ROOT/infrastructure/tutor/themes/mereka"
MFE_SCSS="$THEME_DIR/mfe/mereka.scss"
APPLY_PATCHES="$REPO_ROOT/infrastructure/tutor/apply-patches.sh"
MIGRATION_REGISTER="$REPO_ROOT/docs/operations/MFE_PLUGIN_SLOT_MIGRATION_REGISTER.md"
OPERATING_MODEL="$REPO_ROOT/docs/branding/BRANDING_OPERATING_MODEL.md"
CI_WORKFLOW="$REPO_ROOT/.github/workflows/ci.yml"

echo "========================================"
echo "No DOM Override Policy Verifier"
echo "========================================"
echo ""

# -----------------------------------------------------------------------
# AC-FTR-001: Scan for forbidden DOM override patterns in theme files
# -----------------------------------------------------------------------
echo "AC-FTR-001: Forbidden DOM override patterns"

# Check 1: No document.querySelector in theme SCSS/JS files
echo "  Checking for document.querySelector in theme files..."
QUERY_SELECTOR_HITS=$(grep -r "document\.querySelector" "$THEME_DIR" \
  --include="*.scss" --include="*.js" --include="*.jsx" --include="*.ts" --include="*.tsx" \
  -l 2>/dev/null || true)
if [[ -z "$QUERY_SELECTOR_HITS" ]]; then
  pass "No document.querySelector in theme SCSS/JS files"
else
  fail "document.querySelector found in theme files: $QUERY_SELECTOR_HITS"
fi

# Check 2: No innerHTML in theme files (SCSS/JS)
echo "  Checking for innerHTML in theme files..."
INNERHTML_HITS=$(grep -r "\.innerHTML" "$THEME_DIR" \
  --include="*.scss" --include="*.js" --include="*.jsx" --include="*.ts" --include="*.tsx" \
  -l 2>/dev/null || true)
if [[ -z "$INNERHTML_HITS" ]]; then
  pass "No innerHTML injection in theme files"
else
  fail "innerHTML found in theme files: $INNERHTML_HITS"
fi

# Check 3: No <script> tags in MFE theme files
# Exclude LMS/CMS/common Mako templates which legitimately use <script> tags
echo "  Checking for <script> tags in MFE theme files..."
MFE_THEME_DIR="$THEME_DIR/mfe"
if [[ -d "$MFE_THEME_DIR" ]]; then
  SCRIPT_TAG_HITS=$(grep -r "<script" "$MFE_THEME_DIR" \
    --include="*.html" --include="*.js" --include="*.jsx" --include="*.tsx" \
    -l 2>/dev/null || true)
  if [[ -z "$SCRIPT_TAG_HITS" ]]; then
    pass "No <script> tag injection in MFE theme files"
  else
    fail "<script> tags found in MFE theme files: $SCRIPT_TAG_HITS"
  fi
else
  pass "No MFE theme directory to scan (no MFE-specific HTML)"
fi

# Check 4: No raw JS injection targeting MFE DOM in apply-patches.sh
# The RenderWidget replacement at line ~1227 is ALLOWED (React component replacement)
# We look for document.querySelector or innerHTML patterns
echo "  Checking apply-patches.sh for forbidden MFE DOM patterns..."
if [[ -f "$APPLY_PATCHES" ]]; then
  PATCHES_QUERY=$(grep "document\.querySelector\|\.innerHTML" "$APPLY_PATCHES" || true)
  if [[ -z "$PATCHES_QUERY" ]]; then
    pass "No forbidden DOM patterns in apply-patches.sh"
  else
    fail "Forbidden DOM patterns found in apply-patches.sh: $PATCHES_QUERY"
  fi
else
  warn "apply-patches.sh not found at expected path"
fi

# Check 5: Wildcard selector policy + explicit account scope metadata
echo "  Checking mereka.scss wildcard selector policy..."
if [[ -f "$MFE_SCSS" ]]; then
  mapfile -t ACTIVE_CLASS_VALUES < <(python3 - "$MFE_SCSS" <<'PY'
import re
import sys
from pathlib import Path

text = Path(sys.argv[1]).read_text(encoding="utf-8")
text = re.sub(r"/\*.*?\*/", "", text, flags=re.S)
text = re.sub(r"^\s*//.*$", "", text, flags=re.M)
for value in re.findall(r'\[class\*="([^"]+)"\]', text):
    print(value)
PY
  )

  if [[ "${#ACTIVE_CLASS_VALUES[@]}" -eq 0 ]]; then
    pass "No active [class*=...] selectors in mereka.scss (wildcard cleanup complete)"
  else
    mapfile -t ACTIVE_CLASS_UNIQUE < <(printf '%s\n' "${ACTIVE_CLASS_VALUES[@]}" | sort -u)
    fail "Disallowed active wildcard selector targets in mereka.scss: ${ACTIVE_CLASS_UNIQUE[*]}"
  fi

  if grep -q 'SELECTOR-EXCEPTION: \.page__account-settings.*expires:' "$MFE_SCSS"; then
    pass "Explicit account scope selector includes SELECTOR-EXCEPTION expiry metadata"
  else
    fail "Explicit account scope selector missing SELECTOR-EXCEPTION expiry metadata"
  fi
else
  warn "mereka.scss not found at $MFE_SCSS"
fi

echo ""

# -----------------------------------------------------------------------
# AC-FTR-002: Migration plan document exists and is complete
# -----------------------------------------------------------------------
echo "AC-FTR-002: Plugin-slot migration plan completeness"

# Check 6: Migration register doc exists
if [[ -f "$MIGRATION_REGISTER" ]]; then
  pass "MFE_PLUGIN_SLOT_MIGRATION_REGISTER.md exists"
else
  fail "MFE_PLUGIN_SLOT_MIGRATION_REGISTER.md missing: $MIGRATION_REGISTER"
fi

# Check 7: No P0 items remain open in the migration register
if [[ -f "$MIGRATION_REGISTER" ]]; then
  # P0 items that are NOT done would show "P0" alongside an open status emoji
  P0_OPEN=$(grep -E "\| P0 \|" "$MIGRATION_REGISTER" | grep -v "Done\|MIGRATED\|✅" || true)
  if [[ -z "$P0_OPEN" ]]; then
    pass "No open P0 items in migration register"
  else
    fail "Open P0 items found in migration register: $P0_OPEN"
  fi
fi

# Check 8: At least 1 item is MIGRATED (footer)
if [[ -f "$MIGRATION_REGISTER" ]]; then
  MIGRATED_COUNT=$(grep -c "MIGRATED\|✅ MIGRATED" "$MIGRATION_REGISTER" || true)
  if [[ "$MIGRATED_COUNT" -ge 1 ]]; then
    pass "At least 1 MIGRATED item exists in register (count: ${MIGRATED_COUNT})"
  else
    fail "No MIGRATED items found in migration register"
  fi
fi

# Check 8b: Register has exactly 10 entries (Summary Matrix rows)
if [[ -f "$MIGRATION_REGISTER" ]]; then
  ENTRY_COUNT=$(grep -c "^| [0-9]" "$MIGRATION_REGISTER" || true)
  if [[ "$ENTRY_COUNT" -ge 10 ]]; then
    pass "Migration register has ${ENTRY_COUNT} entries (>= 10 required)"
  else
    fail "Migration register has only ${ENTRY_COUNT} entries (expected >= 10)"
  fi
fi

echo ""

# -----------------------------------------------------------------------
# AC-FTR-003: Operating model contains No DOM Override Policy
# -----------------------------------------------------------------------
echo "AC-FTR-003: BRANDING_OPERATING_MODEL.md no-DOM-override rule"

# Check 9: No DOM Override Policy section exists
if [[ -f "$OPERATING_MODEL" ]]; then
  if grep -q "No DOM Override Policy" "$OPERATING_MODEL"; then
    pass "BRANDING_OPERATING_MODEL.md contains 'No DOM Override Policy' section"
  else
    fail "BRANDING_OPERATING_MODEL.md missing 'No DOM Override Policy' section"
  fi
else
  fail "BRANDING_OPERATING_MODEL.md not found: $OPERATING_MODEL"
fi

# Check 10: Forbidden Patterns section exists
if [[ -f "$OPERATING_MODEL" ]]; then
  if grep -q "Forbidden Patterns" "$OPERATING_MODEL"; then
    pass "BRANDING_OPERATING_MODEL.md contains 'Forbidden Patterns' section"
  else
    fail "BRANDING_OPERATING_MODEL.md missing 'Forbidden Patterns' section"
  fi
fi

# Check 11: Approved Override Points section exists
if [[ -f "$OPERATING_MODEL" ]]; then
  if grep -q "Approved Override Points" "$OPERATING_MODEL"; then
    pass "BRANDING_OPERATING_MODEL.md contains 'Approved Override Points' section"
  else
    fail "BRANDING_OPERATING_MODEL.md missing 'Approved Override Points' section"
  fi
fi

echo ""

# -----------------------------------------------------------------------
# AC-FTR-004: CI gate references no-dom-overrides job
# -----------------------------------------------------------------------
echo "AC-FTR-004: CI gate validates absence of forbidden DOM overrides"

# Check 12: ci.yml contains no-dom-overrides job
if [[ -f "$CI_WORKFLOW" ]]; then
  if grep -q "no-dom-overrides" "$CI_WORKFLOW"; then
    pass ".github/workflows/ci.yml contains 'no-dom-overrides' job"
  else
    fail ".github/workflows/ci.yml missing 'no-dom-overrides' job"
  fi
else
  fail ".github/workflows/ci.yml not found: $CI_WORKFLOW"
fi

echo ""
echo "========================================"
echo "No DOM Override: $PASS PASS / $FAIL FAIL / $WARN WARN"
echo "========================================"
exit $((FAIL > 0 ? 1 : 0))
