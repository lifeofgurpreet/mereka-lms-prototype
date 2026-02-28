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

  required_slots=(
    "org.openedx.frontend.layout.footer.v1"
    "org.openedx.frontend.layout.header_logo.v1"
    "org.openedx.frontend.layout.studio_footer.v1"
    "org.openedx.frontend.authoring.course_unit_sidebar.v1"
    "org.openedx.frontend.authn.login_component.v1"
    "org.openedx.frontend.learner_dashboard.widget_sidebar.v1"
    "org.openedx.frontend.learner_dashboard.no_courses_view.v1"
    "org.openedx.frontend.learner_dashboard.dashboard_header.v1"
    "org.openedx.frontend.learner_dashboard.course_card.v1"
    "org.openedx.frontend.learner_dashboard.course_card_action.v1"
    "org.openedx.frontend.layout.header_desktop_main_menu.v1"
    "org.openedx.frontend.layout.header_mobile_main_menu.v1"
    "org.openedx.frontend.learning.course_outline_sidebar.v1"
    "org.openedx.frontend.learning.progress_certificate_status.v1"
    "org.openedx.frontend.layout.header_learning.v1"
    "org.openedx.frontend.learning.course_tab_links.v1"
    "org.openedx.frontend.catalog.catalog_header.v1"
    "org.openedx.frontend.catalog.catalog_card.v1"
    "org.openedx.frontend.catalog.catalog_filters.v1"
    "org.openedx.frontend.account.id_verification_page.v1"
    "org.openedx.frontend.account.additional_profile_fields.v1"
    "org.openedx.frontend.profile.additional_profile_fields.v1"
  )
  for slot in "${required_slots[@]}"; do
    if grep -q "$slot" "$PLUGIN_FILE"; then
      pass "AC-FRONT-062: Required slot registered (${slot})"
    else
      fail "AC-FRONT-062: Required slot missing in mereka_lms.py (${slot})"
    fi
  done

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
# AC-FRONT-065: Authn + learner-dashboard coverage uses slots; dead selectors stay removed
# ---------------------------------------------------------------------------
echo "--- AC-FRONT-065: Authn + Learner Dashboard Coverage Contract ---"

if [[ ! -f "$SCSS_FILE" ]]; then
  fail "AC-FRONT-065: mereka.scss not found — cannot verify coverage contract"
else
  ACTIVE_AUTHN_WILDCARDS=$(python3 - "$SCSS_FILE" <<'PY'
import re, sys
lines = open(sys.argv[1]).read().splitlines()
count = 0
for line in lines:
    s = line.strip()
    if s.startswith('//') or s.startswith('/*') or s.startswith('*') or not s:
        continue
    if re.search(r'class\*=\"(authn|login-register)\"', line):
        count += 1
print(count)
PY
)
  echo "  Active authn wildcard selector lines: $ACTIVE_AUTHN_WILDCARDS"
  if [[ "$ACTIVE_AUTHN_WILDCARDS" -eq 0 ]]; then
    pass "AC-FRONT-065: Authn wildcard selectors are absent from active CSS (dead-selector cleanup preserved)"
  else
    fail "AC-FRONT-065: Authn wildcard selectors regressed into active CSS ($ACTIVE_AUTHN_WILDCARDS)"
  fi

  ACTIVE_DASH_WILDCARDS=$(python3 - "$SCSS_FILE" <<'PY'
import re, sys
lines = open(sys.argv[1]).read().splitlines()
count = 0
for line in lines:
    s = line.strip()
    if s.startswith('//') or s.startswith('/*') or s.startswith('*') or not s:
        continue
    if re.search(r'class\*=\"learner-dashboard\"', line):
        count += 1
print(count)
PY
)
  echo "  Active learner-dashboard wildcard selector lines: $ACTIVE_DASH_WILDCARDS"
  if [[ "$ACTIVE_DASH_WILDCARDS" -eq 0 ]]; then
    pass "AC-FRONT-065: Learner-dashboard wildcard selectors are absent from active CSS"
  else
    fail "AC-FRONT-065: Learner-dashboard wildcard selectors regressed into active CSS ($ACTIVE_DASH_WILDCARDS)"
  fi

  ACCOUNT_SCOPE_LINES=$(python3 - "$SCSS_FILE" <<'PY'
import re, sys
lines = open(sys.argv[1]).read().splitlines()
count = 0
for line in lines:
    s = line.strip()
    if s.startswith('//') or s.startswith('/*') or s.startswith('*') or not s:
        continue
    if re.search(r'class\*=\"account-settings\"|\.page__account-settings', line):
        count += 1
print(count)
PY
)
  echo "  Active account-settings scope lines: $ACCOUNT_SCOPE_LINES"
  if [[ "$ACCOUNT_SCOPE_LINES" -eq 0 ]]; then
    pass "AC-FRONT-065: Legacy account settings wrapper scope removed from active CSS"
  else
    fail "AC-FRONT-065: Legacy account settings wrapper scope still active in CSS"
  fi

  if [[ -f "$PLUGIN_FILE" ]]; then
    if grep -q 'org.openedx.frontend.authn.login_component.v1' "$PLUGIN_FILE"; then
      pass "AC-FRONT-065: Authn login component slot is registered"
    else
      fail "AC-FRONT-065: Authn login component slot not registered"
    fi

    if grep -q 'org.openedx.frontend.account.id_verification_page.v1' "$PLUGIN_FILE"; then
      pass "AC-FRONT-065: Account ID verification slot is registered"
    else
      fail "AC-FRONT-065: Account ID verification slot not registered"
    fi

    if grep -q 'org.openedx.frontend.account.additional_profile_fields.v1' "$PLUGIN_FILE"; then
      pass "AC-FRONT-065: Account additional profile fields slot is registered"
    else
      fail "AC-FRONT-065: Account additional profile fields slot not registered"
    fi

    if grep -q 'org.openedx.frontend.learner_dashboard.widget_sidebar.v1' "$PLUGIN_FILE" && \
       grep -q 'org.openedx.frontend.learner_dashboard.no_courses_view.v1' "$PLUGIN_FILE" && \
       grep -q 'org.openedx.frontend.learner_dashboard.dashboard_header.v1' "$PLUGIN_FILE" && \
       grep -q 'org.openedx.frontend.learner_dashboard.course_card.v1' "$PLUGIN_FILE" && \
       grep -q 'org.openedx.frontend.learner_dashboard.course_card_action.v1' "$PLUGIN_FILE"; then
      pass "AC-FRONT-065: Learner dashboard slots are registered (sidebar + no-courses + header + course-card + course-card-action)"
    else
      fail "AC-FRONT-065: Learner dashboard slot coverage incomplete in plugin"
    fi
  else
    fail "AC-FRONT-065: mereka_lms.py not found — cannot verify slot coverage"
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
  echo "5. Keep dead authn/dashboard wildcard selectors removed; enforce slot coverage in mereka_lms.py"
  exit 1
fi

exit 0
