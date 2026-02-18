#!/usr/bin/env bash
# @covers AC-FRONT-061, AC-FRONT-062, AC-FRONT-063, AC-FRONT-064, AC-FRONT-065
# @spec: bead-2dcy6
#
# Verify MFE footer/slot migration from brittle selectors.
#
# AC-FRONT-061: SCSS selector blocks tagged with /* RISK: HIGH/MEDIUM/LOW */
# AC-FRONT-062: At least 3 slot-based customizations in mereka_lms.py
# AC-FRONT-063: No structural footer/layout HTML string-rewrites in apply-patches.sh
#               (only MIGRATED-TO-SLOT annotated fallbacks are allowed)
# AC-FRONT-064: BRANDING_OPERATING_MODEL.md documents slot IDs and fallback strategy
# AC-FRONT-065: Authn and learner-dashboard MFE configs referenced correctly

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
PLUGIN_FILE="$REPO_ROOT/infrastructure/tutor/plugins/mereka_lms.py"
PATCHES_FILE="$REPO_ROOT/infrastructure/tutor/apply-patches.sh"
BRANDING_DOC="$REPO_ROOT/docs/branding/BRANDING_OPERATING_MODEL.md"
OPS_DOC="$REPO_ROOT/docs/operations/MFE_FOOTER_SLOT_MIGRATION.md"

echo "=== MFE Footer/Slot Migration Verification (bead 2dcy.6) ==="
echo ""

# ---------------------------------------------------------------------------
# AC-FRONT-061: SCSS blocks tagged with risk-level comments
# ---------------------------------------------------------------------------
echo "--- AC-FRONT-061: SCSS Risk-Level Tags ---"

if [[ ! -f "$SCSS_FILE" ]]; then
  fail "AC-FRONT-061: mereka.scss not found at $SCSS_FILE"
else
  HIGH_COUNT=$(grep -c '/\* RISK: HIGH' "$SCSS_FILE" || echo "0")
  MEDIUM_COUNT=$(grep -c '/\* RISK: MEDIUM' "$SCSS_FILE" || echo "0")
  LOW_COUNT=$(grep -c '/\* RISK: LOW' "$SCSS_FILE" || echo "0")
  TOTAL_TAGGED=$((HIGH_COUNT + MEDIUM_COUNT + LOW_COUNT))

  echo "  /* RISK: HIGH */  blocks: $HIGH_COUNT"
  echo "  /* RISK: MEDIUM */ blocks: $MEDIUM_COUNT"
  echo "  /* RISK: LOW */   blocks: $LOW_COUNT"
  echo "  Total tagged blocks: $TOTAL_TAGGED"

  if [[ "$HIGH_COUNT" -ge 1 ]]; then
    pass "AC-FRONT-061: Found $HIGH_COUNT HIGH-risk tagged selector blocks"
  else
    fail "AC-FRONT-061: No HIGH-risk selector blocks tagged (expected >= 1)"
  fi

  if [[ "$TOTAL_TAGGED" -ge 10 ]]; then
    pass "AC-FRONT-061: $TOTAL_TAGGED total risk-tagged selector blocks (>= 10 required)"
  else
    fail "AC-FRONT-061: Only $TOTAL_TAGGED risk-tagged blocks found (expected >= 10)"
  fi

  # All three risk levels must be represented
  if [[ "$LOW_COUNT" -ge 1 ]] && [[ "$MEDIUM_COUNT" -ge 1 ]] && [[ "$HIGH_COUNT" -ge 1 ]]; then
    pass "AC-FRONT-061: All three risk levels (HIGH, MEDIUM, LOW) represented in mereka.scss"
  else
    fail "AC-FRONT-061: Not all risk levels present — HIGH:$HIGH_COUNT MEDIUM:$MEDIUM_COUNT LOW:$LOW_COUNT"
  fi

  # Verify SCSS still has balanced braces (regression guard)
  OPEN_BRACES=$(grep -co '{' "$SCSS_FILE" || echo "0")
  CLOSE_BRACES=$(grep -co '}' "$SCSS_FILE" || echo "0")
  if [[ "$OPEN_BRACES" -eq "$CLOSE_BRACES" ]]; then
    pass "AC-FRONT-061: SCSS has balanced braces ($OPEN_BRACES open, $CLOSE_BRACES close)"
  else
    fail "AC-FRONT-061: SCSS braces unbalanced ($OPEN_BRACES open vs $CLOSE_BRACES close)"
  fi
fi

echo ""

# ---------------------------------------------------------------------------
# AC-FRONT-062: At least 3 slot-based customizations in mereka_lms.py
# ---------------------------------------------------------------------------
echo "--- AC-FRONT-062: Slot-Based Customizations in Plugin ---"

if [[ ! -f "$PLUGIN_FILE" ]]; then
  fail "AC-FRONT-062: mereka_lms.py not found at $PLUGIN_FILE"
else
  SLOT_ITEM_COUNT=$(grep -c 'PLUGIN_SLOTS.add_item' "$PLUGIN_FILE" || echo "0")
  echo "  PLUGIN_SLOTS.add_item calls: $SLOT_ITEM_COUNT"

  if [[ "$SLOT_ITEM_COUNT" -ge 3 ]]; then
    pass "AC-FRONT-062: Found $SLOT_ITEM_COUNT slot-based customizations (>= 3 required)"
  else
    fail "AC-FRONT-062: Only $SLOT_ITEM_COUNT PLUGIN_SLOTS.add_item calls found (expected >= 3)"
  fi

  # Check for the specific required slots
  if grep -q '"footer_slot"' "$PLUGIN_FILE"; then
    pass "AC-FRONT-062: footer_slot registration present"
  else
    fail "AC-FRONT-062: footer_slot registration missing from mereka_lms.py"
  fi

  if grep -q '"header_logo_slot"' "$PLUGIN_FILE"; then
    pass "AC-FRONT-062: header_logo_slot registration present"
  else
    fail "AC-FRONT-062: header_logo_slot registration missing from mereka_lms.py"
  fi

  if grep -q 'learner_dashboard' "$PLUGIN_FILE"; then
    pass "AC-FRONT-062: learner_dashboard slot registration present"
  else
    fail "AC-FRONT-062: learner_dashboard slot registration missing from mereka_lms.py"
  fi

  # Verify forward-compatible try/except pattern
  if grep -q 'try:' "$PLUGIN_FILE" && grep -q 'except ImportError' "$PLUGIN_FILE"; then
    pass "AC-FRONT-062: Forward-compatible try/except ImportError pattern present"
  else
    fail "AC-FRONT-062: Missing try/except ImportError guard around PLUGIN_SLOTS registration"
  fi

  # Check _PLUGIN_SLOTS_AVAILABLE sentinel
  if grep -q '_PLUGIN_SLOTS_AVAILABLE' "$PLUGIN_FILE"; then
    pass "AC-FRONT-062: _PLUGIN_SLOTS_AVAILABLE sentinel defined for fallback detection"
  else
    warn "AC-FRONT-062: _PLUGIN_SLOTS_AVAILABLE sentinel not found (WARN — not blocking)"
  fi
fi

echo ""

# ---------------------------------------------------------------------------
# AC-FRONT-063: No structural footer/layout HTML string-rewrites without
#               MIGRATED-TO-SLOT annotation in apply-patches.sh
# ---------------------------------------------------------------------------
echo "--- AC-FRONT-063: No Bare Structural Footer/Layout String-Rewrites ---"

if [[ ! -f "$PATCHES_FILE" ]]; then
  fail "AC-FRONT-063: apply-patches.sh not found at $PATCHES_FILE"
else
  # Check for any sed or direct .replace() targeting footer/layout HTML structure
  # without a MIGRATED-TO-SLOT annotation nearby.
  #
  # Approach: extract all lines containing replace("RenderWidget: <Footer />")
  # or sed targeting footer HTML, then check each has a MIGRATED-TO-SLOT comment
  # within 5 lines above it.
  BARE_REWRITES=$(python3 - "$PATCHES_FILE" <<'PY'
import sys
from pathlib import Path

path = Path(sys.argv[1])
lines = path.read_text().splitlines()

violations = []
for idx, line in enumerate(lines):
    # Look for structural footer/layout string replacements
    is_structural_rewrite = (
        'RenderWidget: <Footer />' in line or
        ('sed' in line and ('footer' in line.lower() or 'Footer' in line)) or
        ('replace' in line and '<Footer' in line) or
        ('replace' in line and 'footer-container' in line) or
        ('replace' in line and 'footer-slot' in line and 'MIGRATED' not in line)
    )
    if not is_structural_rewrite:
        continue

    # Check if there's a MIGRATED-TO-SLOT comment within 10 lines above or on the same line
    context_start = max(0, idx - 10)
    context = lines[context_start:idx + 1]
    has_migration_annotation = any(
        'MIGRATED-TO-SLOT' in ctx_line or 'migrated-to-slot' in ctx_line.lower()
        for ctx_line in context
    )
    if not has_migration_annotation:
        violations.append(f"Line {idx+1}: {line.strip()[:120]}")

for v in violations:
    print(v)
PY
)

  if [[ -z "$BARE_REWRITES" ]]; then
    pass "AC-FRONT-063: No bare structural footer/layout string-rewrites found"
  else
    VIOLATION_COUNT=$(echo "$BARE_REWRITES" | grep -c . || echo "0")
    fail "AC-FRONT-063: $VIOLATION_COUNT structural footer/layout rewrite(s) without MIGRATED-TO-SLOT annotation:"
    echo "$BARE_REWRITES" | head -10
  fi

  # Verify the MIGRATED-TO-SLOT comment exists for the footer_slot fallback
  if grep -q 'MIGRATED-TO-SLOT.*footer_slot' "$PATCHES_FILE"; then
    pass "AC-FRONT-063: MIGRATED-TO-SLOT comment present for footer_slot fallback"
  else
    fail "AC-FRONT-063: MIGRATED-TO-SLOT comment for footer_slot missing from apply-patches.sh"
  fi
fi

echo ""

# ---------------------------------------------------------------------------
# AC-FRONT-064: BRANDING_OPERATING_MODEL.md documents slot IDs and fallback
# ---------------------------------------------------------------------------
echo "--- AC-FRONT-064: Slot Documentation in BRANDING_OPERATING_MODEL.md ---"

if [[ ! -f "$BRANDING_DOC" ]]; then
  fail "AC-FRONT-064: BRANDING_OPERATING_MODEL.md not found at $BRANDING_DOC"
else
  # Check for Plugin Slot Migration section
  if grep -q 'Plugin Slot Migration' "$BRANDING_DOC"; then
    pass "AC-FRONT-064: 'Plugin Slot Migration' section present in BRANDING_OPERATING_MODEL.md"
  else
    fail "AC-FRONT-064: 'Plugin Slot Migration' section missing from BRANDING_OPERATING_MODEL.md"
  fi

  # Check slot IDs documented
  if grep -q 'footer_slot' "$BRANDING_DOC"; then
    pass "AC-FRONT-064: footer_slot documented in BRANDING_OPERATING_MODEL.md"
  else
    fail "AC-FRONT-064: footer_slot not documented in BRANDING_OPERATING_MODEL.md"
  fi

  if grep -q 'header_logo_slot' "$BRANDING_DOC"; then
    pass "AC-FRONT-064: header_logo_slot documented in BRANDING_OPERATING_MODEL.md"
  else
    fail "AC-FRONT-064: header_logo_slot not documented in BRANDING_OPERATING_MODEL.md"
  fi

  # Check fallback strategy documented
  if grep -qi 'fallback' "$BRANDING_DOC"; then
    pass "AC-FRONT-064: Fallback strategy documented in BRANDING_OPERATING_MODEL.md"
  else
    fail "AC-FRONT-064: Fallback strategy missing from BRANDING_OPERATING_MODEL.md"
  fi

  # Check rollback procedure documented
  if grep -qi 'rollback' "$BRANDING_DOC"; then
    pass "AC-FRONT-064: Rollback procedure documented in BRANDING_OPERATING_MODEL.md"
  else
    fail "AC-FRONT-064: Rollback procedure missing from BRANDING_OPERATING_MODEL.md"
  fi

  # Check ops doc exists as additional evidence
  if [[ -f "$OPS_DOC" ]]; then
    pass "AC-FRONT-064: MFE_FOOTER_SLOT_MIGRATION.md operations doc exists"
  else
    warn "AC-FRONT-064: MFE_FOOTER_SLOT_MIGRATION.md ops doc not found (WARN — branding doc sufficient)"
  fi
fi

echo ""

# ---------------------------------------------------------------------------
# AC-FRONT-065: Authn and learner-dashboard route coverage verified
# ---------------------------------------------------------------------------
echo "--- AC-FRONT-065: Authn + Learner Dashboard Route Coverage ---"

if [[ ! -f "$SCSS_FILE" ]]; then
  fail "AC-FRONT-065: mereka.scss not found — cannot verify route coverage"
else
  # Check authn route selectors present
  AUTHN_SELECTORS=$(grep -c 'data-testid.*authn\|data-testid.*login-page\|data-testid.*register-page' \
    "$SCSS_FILE" || echo "0")
  echo "  Authn data-testid selectors: $AUTHN_SELECTORS"

  if [[ "$AUTHN_SELECTORS" -ge 3 ]]; then
    pass "AC-FRONT-065: Found $AUTHN_SELECTORS authn data-testid selector rules (>= 3 required)"
  else
    fail "AC-FRONT-065: Only $AUTHN_SELECTORS authn data-testid selector rules (expected >= 3)"
  fi

  # Check learner-dashboard route selectors present
  DASHBOARD_SELECTORS=$(grep -c 'data-testid.*learner-dashboard\|data-testid.*account-settings\|data-testid.*account-page' \
    "$SCSS_FILE" || echo "0")
  echo "  Learner dashboard data-testid selectors: $DASHBOARD_SELECTORS"

  if [[ "$DASHBOARD_SELECTORS" -ge 3 ]]; then
    pass "AC-FRONT-065: Found $DASHBOARD_SELECTORS dashboard data-testid selector rules (>= 3 required)"
  else
    fail "AC-FRONT-065: Only $DASHBOARD_SELECTORS dashboard data-testid selector rules (expected >= 3)"
  fi

  # Check that authn selectors have RISK tags (confirms they were reviewed).
  # Strategy: look for a /* RISK: HIGH */ comment within 30 lines before any
  # authn-related selector, or on the same comment block line.
  AUTHN_HIGH_RISK=$(python3 -c "
scss = open('$SCSS_FILE').read()
lines = scss.splitlines()
authn_keywords = ('authn', 'login-page', 'register-page', 'login-register')
count = 0
for idx, line in enumerate(lines):
    if not any(kw in line for kw in authn_keywords):
        continue
    # Look back up to 30 lines for a RISK: HIGH comment
    window = lines[max(0, idx - 30):idx + 1]
    if any('RISK: HIGH' in w for w in window):
        count += 1
        break  # at least one is enough
print(count)
" 2>/dev/null || echo "0")

  if [[ "$AUTHN_HIGH_RISK" -ge 1 ]]; then
    pass "AC-FRONT-065: Authn surfaces have HIGH-risk tags ($AUTHN_HIGH_RISK block(s))"
  else
    fail "AC-FRONT-065: No HIGH-risk tags found for authn surfaces (expected >= 1)"
  fi

  # Check dashboard surfaces have RISK tags
  DASHBOARD_HIGH_RISK=$(python3 -c "
import re
scss = open('$SCSS_FILE').read()
sections = re.split(r'/\* RISK:', scss)
count = 0
for s in sections:
    if s.startswith('HIGH') and ('learner-dashboard' in s or 'course-grid' in s or 'course-list' in s or 'course-card' in s or 'course.*img' in s):
        count += 1
# Also count structural learner-dashboard blocks
count += len(re.findall(r'RISK: HIGH[^\n]*\n.*learner-dashboard', scss))
print(min(count, 99))
" 2>/dev/null || echo "0")

  if [[ "$DASHBOARD_HIGH_RISK" -ge 1 ]]; then
    pass "AC-FRONT-065: Dashboard surfaces have HIGH-risk tags ($DASHBOARD_HIGH_RISK block(s))"
  else
    warn "AC-FRONT-065: Dashboard HIGH-risk tag count unclear ($DASHBOARD_HIGH_RISK) — manual verification recommended"
  fi

  # Verify plugin file references authn/dashboard via slot OR env-config coverage
  if [[ -f "$PLUGIN_FILE" ]]; then
    if grep -q 'mfe-env-config\|mereka.scss\|authn\|learner.dashboard' "$PLUGIN_FILE"; then
      pass "AC-FRONT-065: Plugin file references authn/dashboard surface coverage"
    else
      warn "AC-FRONT-065: Plugin file has no explicit authn/dashboard reference (coverage via SCSS)"
    fi
  fi
fi

echo ""
echo "=== Summary ==="
echo -e "${GREEN}PASS:${NC} $PASS | ${RED}FAIL:${NC} $FAIL | ${YELLOW}WARN:${NC} $WARN"

if [[ "$FAIL" -gt 0 ]]; then
  echo ""
  echo "Remediation:"
  echo "1. Tag all selector blocks in mereka.scss with /* RISK: HIGH/MEDIUM/LOW */"
  echo "2. Add >= 3 PLUGIN_SLOTS.add_item entries in infrastructure/tutor/plugins/mereka_lms.py"
  echo "3. Annotate any remaining structural footer/layout replace() in apply-patches.sh"
  echo "   with # MIGRATED-TO-SLOT: <slot-id> comments"
  echo "4. Add 'Plugin Slot Migration' section to docs/branding/BRANDING_OPERATING_MODEL.md"
  echo "   documenting slot IDs, fallback strategy, and rollback procedure"
  echo "5. Ensure authn and learner-dashboard selectors are present and RISK-tagged in mereka.scss"
  exit 1
fi

exit 0
