#!/usr/bin/env bash
# @covers AC-FRONT-061, AC-FRONT-062, AC-FRONT-063, AC-FRONT-064, AC-FRONT-065
# @spec: bead-2dcy6
#
# Verify MFE footer/slot migration from brittle selectors.
#
# AC-FRONT-061: SCSS selector blocks tagged with /* RISK: HIGH/MEDIUM/LOW */
# AC-FRONT-062: Slot-based customizations in mereka_lms.py
# AC-FRONT-063: No structural footer/layout HTML string-rewrites in apply-patches.sh
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
# AC-FRONT-062: Slot-based customizations in mereka_lms.py
# ---------------------------------------------------------------------------
echo "--- AC-FRONT-062: Slot-Based Customizations in Plugin ---"

if [[ ! -f "$PLUGIN_FILE" ]]; then
  fail "AC-FRONT-062: mereka_lms.py not found at $PLUGIN_FILE"
else
  SLOT_ITEM_COUNT=$(grep -Eo 'PLUGIN_SLOTS\.add_items|PLUGIN_SLOTS\.add_item' "$PLUGIN_FILE" | wc -l | tr -d ' ' || true)
  SLOT_ITEM_COUNT=${SLOT_ITEM_COUNT:-0}
  echo "  PLUGIN_SLOTS registration calls: $SLOT_ITEM_COUNT"

  if [[ "$SLOT_ITEM_COUNT" -ge 1 ]]; then
    pass "AC-FRONT-062: Found slot registration call(s) in mereka_lms.py ($SLOT_ITEM_COUNT)"
  else
    fail "AC-FRONT-062: No PLUGIN_SLOTS registration calls found in mereka_lms.py"
  fi

  # Check for the required canonical slots
  if grep -q 'org.openedx.frontend.layout.footer.v1' "$PLUGIN_FILE"; then
    pass "AC-FRONT-062: Footer canonical slot registered"
  else
    fail "AC-FRONT-062: Footer canonical slot not registered in mereka_lms.py"
  fi

  if grep -q 'org.openedx.frontend.layout.header_logo.v1' "$PLUGIN_FILE"; then
    pass "AC-FRONT-062: Header logo canonical slot registered"
  else
    fail "AC-FRONT-062: Header logo canonical slot not registered in mereka_lms.py"
  fi

  if grep -q 'org.openedx.frontend.learner_dashboard.widget_sidebar.v1' "$PLUGIN_FILE"; then
    pass "AC-FRONT-062: learner-dashboard sidebar slot registered"
  else
    warn "AC-FRONT-062: learner-dashboard sidebar slot not yet registered (CSS fallback path active)"
  fi

fi

echo ""

# ---------------------------------------------------------------------------
# AC-FRONT-063: No structural footer/layout HTML string-rewrites in apply-patches.sh
# ---------------------------------------------------------------------------
echo "--- AC-FRONT-063: No Bare Structural Footer/Layout String-Rewrites ---"

if [[ ! -f "$PATCHES_FILE" ]]; then
  fail "AC-FRONT-063: apply-patches.sh not found at $PATCHES_FILE"
else
  # Check for any sed or direct .replace()/string surgery targeting footer/layout
  # HTML structure.
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
        ('sed' in line and 'footer' in line.lower()) or
        ('replace' in line and '<Footer' in line) or
        ('replace' in line and 'footer-container' in line) or
        ('replace' in line and 'footer-slot' in line)
    )
    if not is_structural_rewrite:
        continue

    violations.append(f"Line {idx+1}: {line.strip()[:120]}")

for v in violations:
    print(v)
PY
)

  if [[ -z "$BARE_REWRITES" ]]; then
    pass "AC-FRONT-063: No bare structural footer/layout string-rewrites found"
  else
    VIOLATION_COUNT=$(echo "$BARE_REWRITES" | grep -c . || echo "0")
    fail "AC-FRONT-063: $VIOLATION_COUNT structural footer/layout rewrite(s) found:"
    echo "$BARE_REWRITES" | head -10
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

  # Check slot IDs documented (canonical or legacy names, for transition period)
  if grep -q 'org.openedx.frontend.layout.footer.v1\|footer_slot' "$BRANDING_DOC"; then
    pass "AC-FRONT-064: Footer slot is documented in BRANDING_OPERATING_MODEL.md"
  else
    fail "AC-FRONT-064: Footer slot ID not documented in BRANDING_OPERATING_MODEL.md"
  fi

  if grep -q 'org.openedx.frontend.layout.header_logo.v1\|header_logo_slot' "$BRANDING_DOC"; then
    pass "AC-FRONT-064: Header logo slot is documented in BRANDING_OPERATING_MODEL.md"
  else
    fail "AC-FRONT-064: Header logo slot ID not documented in BRANDING_OPERATING_MODEL.md"
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
  AUTHN_SELECTORS=$(grep -E 'class\*="authn"|class\*="login-register"|authn\"|login-register\"' \
    "$SCSS_FILE" | wc -l | tr -d ' ' || true)
  echo "  Authn selector coverage lines: $AUTHN_SELECTORS"

  if [[ "$AUTHN_SELECTORS" -ge 2 ]]; then
    pass "AC-FRONT-065: Found authn selector coverage in mereka.scss ($AUTHN_SELECTORS line(s))"
  else
    fail "AC-FRONT-065: Insufficient authn selector coverage in mereka.scss ($AUTHN_SELECTORS)"
  fi

  # Check learner-dashboard route selectors present
  DASHBOARD_SELECTORS=$(grep -E 'class\*="account-settings"|class\*="account-page"|class\*="learner-dashboard"' \
    "$SCSS_FILE" | wc -l | tr -d ' ' || true)
  echo "  Learner dashboard selector coverage lines: $DASHBOARD_SELECTORS"

  if [[ "$DASHBOARD_SELECTORS" -ge 3 ]]; then
    pass "AC-FRONT-065: Found learner-dashboard selector coverage in mereka.scss ($DASHBOARD_SELECTORS line(s))"
  else
    fail "AC-FRONT-065: Insufficient learner-dashboard selector coverage in mereka.scss ($DASHBOARD_SELECTORS)"
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
  echo "2. Register canonical slots in infrastructure/tutor/plugins/mereka_lms.py"
  echo "   (org.openedx.frontend.layout.footer.v1 and org.openedx.frontend.layout.header_logo.v1)"
  echo "3. Keep apply-patches.sh free of structural footer/layout string rewrites"
  echo "4. Add 'Plugin Slot Migration' section to docs/branding/BRANDING_OPERATING_MODEL.md"
  echo "   documenting canonical slot IDs, fallback/exception paths, and rollback procedure"
  echo "5. Ensure authn and learner-dashboard selectors are present and RISK-tagged in mereka.scss"
  exit 1
fi

exit 0
