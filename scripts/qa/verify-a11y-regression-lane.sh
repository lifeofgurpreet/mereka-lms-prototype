#!/usr/bin/env bash
set -euo pipefail

# @covers AC-FRONT-071, AC-FRONT-072, AC-FRONT-073, AC-FRONT-074, AC-FRONT-075
# @spec: bead-2dcy.3.1
#
# Bead 2dcy.3.1 — Frontend: deliver authenticated smoke + a11y regression lane
#
# AC-FRONT-071: Confirm parent script (2dcy.3) has >= 3 authenticated smoke routes
# AC-FRONT-072: Confirm parent script (2dcy.3) has contrast validation section
# AC-FRONT-073: Source-level a11y checks for focus, labels, and landmarks on
#               login, dashboard, and profile routes
# AC-FRONT-074: Artifact capture — evidence file exists in branding evidence dir
# AC-FRONT-075: Evidence report references parent bead 2dcy.3, contains pass/fail
#               summary and follow-up blockers section

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$REPO_ROOT/scripts/shared/mereka_plugin_contract.sh"
PLUGIN_MAIN="$(mereka_plugin_main_file "$REPO_ROOT")"

PARENT_SCRIPT="$REPO_ROOT/scripts/qa/verify-authenticated-smoke-a11y.sh"
MFE_SCSS="$REPO_ROOT/infrastructure/tutor/themes/mereka/mfe/mereka.scss"
A11Y_RUNBOOK="$REPO_ROOT/docs/runbooks/operations/A11Y_REGRESSION_LANE.md"
EVIDENCE_REPORT="$REPO_ROOT/docs/operations/evidence/a11y-regression-lane-report.md"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASS=0
FAIL=0
WARN=0

pass_check() { printf "${GREEN}✅ %s${NC}\n" "$1"; PASS=$((PASS + 1)); }
fail_check() { printf "${RED}❌ %s${NC}\n" "$1"; FAIL=$((FAIL + 1)); }
warn_check() { printf "${YELLOW}⚠️  %s${NC}\n" "$1"; WARN=$((WARN + 1)); }

# ---------------------------------------------------------------------------
# AC-FRONT-071: Confirm parent script has >= 3 authenticated smoke routes
# ---------------------------------------------------------------------------
echo ""
echo "=== AC-FRONT-071: Parent Script Route Coverage ==="

if [[ -f "$PARENT_SCRIPT" ]]; then
  pass_check "AC-FRONT-071: Parent script exists at scripts/qa/verify-authenticated-smoke-a11y.sh"
else
  fail_check "AC-FRONT-071: Parent script missing at scripts/qa/verify-authenticated-smoke-a11y.sh"
fi

if [[ -f "$PARENT_SCRIPT" ]]; then
  # Count route entries in the AUTHENTICATED_ROUTES array (lines with | delimiter)
  ROUTE_COUNT=$(grep -c '"/' "$PARENT_SCRIPT" || true)
  if [[ $ROUTE_COUNT -ge 3 ]]; then
    pass_check "AC-FRONT-071: Parent script defines $ROUTE_COUNT route entries (>= 3 required)"
  else
    fail_check "AC-FRONT-071: Parent script defines only $ROUTE_COUNT route entries (need >= 3)"
  fi

  # Confirm /dashboard is covered
  if grep -q '/dashboard' "$PARENT_SCRIPT"; then
    pass_check "AC-FRONT-071: Parent script covers /dashboard route"
  else
    fail_check "AC-FRONT-071: Parent script missing /dashboard route"
  fi

  # Confirm /account or /account/settings is covered
  if grep -q '/account' "$PARENT_SCRIPT"; then
    pass_check "AC-FRONT-071: Parent script covers /account route"
  else
    fail_check "AC-FRONT-071: Parent script missing /account route"
  fi
fi

# ---------------------------------------------------------------------------
# AC-FRONT-072: Confirm parent script has contrast validation section
# ---------------------------------------------------------------------------
echo ""
echo "=== AC-FRONT-072: Parent Script Contrast Validation Section ==="

if [[ -f "$PARENT_SCRIPT" ]]; then
  if grep -q 'WCAG\|contrast_ratio\|luminance' "$PARENT_SCRIPT"; then
    pass_check "AC-FRONT-072: Parent script contains WCAG contrast validation block"
  else
    fail_check "AC-FRONT-072: Parent script missing WCAG contrast validation block"
  fi

  # Confirm Python contrast block is present (heredoc marker)
  if grep -q 'PYEOF\|python3 -' "$PARENT_SCRIPT"; then
    pass_check "AC-FRONT-072: Parent script contains Python contrast computation block"
  else
    fail_check "AC-FRONT-072: Parent script missing Python contrast computation block"
  fi

  # Confirm threshold of 4.5 is documented
  if grep -q '4\.5\|THRESHOLD' "$PARENT_SCRIPT"; then
    pass_check "AC-FRONT-072: Parent script documents WCAG AA 4.5:1 threshold"
  else
    fail_check "AC-FRONT-072: Parent script missing 4.5:1 threshold documentation"
  fi
fi

# ---------------------------------------------------------------------------
# AC-FRONT-073: Source-level a11y checks — focus, labels, landmarks
# Routes: /authn/login, /dashboard, /account/settings
# ---------------------------------------------------------------------------
echo ""
echo "=== AC-FRONT-073: Source-Level A11y Checks (Focus / Labels / Landmarks) ==="

# --- Login route (/authn/login) ---
echo ""
echo "  -- /authn/login: landmark and focus checks --"

# Check the footer plugin has role="contentinfo" (landmark) as an indicator that
# the MFE plugin injects proper landmark roles
if mereka_plugin_has_any "$REPO_ROOT"; then
  if mereka_plugin_has_fixed "$REPO_ROOT" 'role="contentinfo"'; then
    pass_check "AC-FRONT-073: plugin contract sources inject role=\"contentinfo\" landmark in footer"
  else
    fail_check "AC-FRONT-073: plugin contract sources missing role=\"contentinfo\" landmark in footer"
  fi

  # Check that injected footer has aria-label or aria-labelledby on nav element
  if mereka_plugin_has_fixed "$REPO_ROOT" "<nav "; then
    pass_check "AC-FRONT-073: plugin contract sources inject <nav> landmark element"
  else
    warn_check "AC-FRONT-073: plugin contract sources do not inject <nav> element (may be in MFE source)"
  fi
else
  fail_check "AC-FRONT-073: plugin contract sources not found (expected at least $PLUGIN_MAIN)"
fi

# --- Dashboard route (/dashboard) ---
echo ""
echo "  -- /dashboard: focus-visible styling checks --"

if [[ -f "$MFE_SCSS" ]]; then
  # Check that :focus is defined (may use :focus for older browser compat alongside :focus-visible)
  if grep -q ':focus' "$MFE_SCSS"; then
    pass_check "AC-FRONT-073: mereka.scss defines :focus styling rules for dashboard route"
  else
    fail_check "AC-FRONT-073: mereka.scss missing :focus styling rules"
  fi

  # Check for focus ring via box-shadow (Paragon pattern)
  if grep -q 'box-shadow' "$MFE_SCSS"; then
    pass_check "AC-FRONT-073: mereka.scss uses box-shadow for focus ring (Paragon pattern)"
  else
    fail_check "AC-FRONT-073: mereka.scss missing box-shadow focus ring pattern"
  fi

  # Confirm focus ring color token is defined (--mereka-mfe-focus)
  if grep -q '\-\-mereka-mfe-focus' "$MFE_SCSS"; then
    pass_check "AC-FRONT-073: mereka.scss defines --mereka-mfe-focus token for focus ring color"
  else
    fail_check "AC-FRONT-073: mereka.scss missing --mereka-mfe-focus focus ring token"
  fi

  # Confirm focus ring is NOT suppressed to transparent or none
  FOCUS_NONE_COUNT=0
  if grep -E ':focus\s*\{' "$MFE_SCSS" | grep -q 'outline:\s*none\|outline:\s*0'; then
    FOCUS_NONE_COUNT=$((FOCUS_NONE_COUNT + 1))
  fi
  if grep -E ':focus\s*\{' "$MFE_SCSS" | grep -q 'box-shadow:\s*none'; then
    FOCUS_NONE_COUNT=$((FOCUS_NONE_COUNT + 1))
  fi
  if [[ $FOCUS_NONE_COUNT -eq 0 ]]; then
    pass_check "AC-FRONT-073: No :focus rules suppress focus ring to none/transparent"
  else
    warn_check "AC-FRONT-073: One or more :focus rules may suppress focus ring — manual review needed"
  fi
else
  fail_check "AC-FRONT-073: mereka.scss not found at $MFE_SCSS"
fi

# --- Profile route (/account/settings) ---
echo ""
echo "  -- /account/settings: Paragon focus token checks --"

if [[ -f "$MFE_SCSS" ]]; then
  # Confirm pgn form controls have focus styling (profile uses form inputs)
  if grep -q 'pgn__form-control:focus\|form-control:focus' "$MFE_SCSS"; then
    pass_check "AC-FRONT-073: mereka.scss has focus styling for Paragon form controls (profile route)"
  else
    fail_check "AC-FRONT-073: mereka.scss missing Paragon form control focus styling"
  fi

  # Confirm the focus token variable is not overridden to 'transparent'
  FOCUS_TOKEN_VALUE=$(grep '\-\-mereka-mfe-focus' "$MFE_SCSS" | head -1 || true)
  if echo "$FOCUS_TOKEN_VALUE" | grep -q 'transparent'; then
    fail_check "AC-FRONT-073: --mereka-mfe-focus is set to transparent — focus ring is invisible"
  else
    pass_check "AC-FRONT-073: --mereka-mfe-focus token is not transparent"
  fi
fi

# A11y runbook doc must exist
if [[ -f "$A11Y_RUNBOOK" ]]; then
  pass_check "AC-FRONT-073: A11y regression lane runbook exists at docs/runbooks/operations/A11Y_REGRESSION_LANE.md"
else
  fail_check "AC-FRONT-073: A11y regression lane runbook missing at docs/runbooks/operations/A11Y_REGRESSION_LANE.md"
fi

# Runbook must list all 3 target routes
if [[ -f "$A11Y_RUNBOOK" ]]; then
  for route in '/authn/login' '/dashboard' '/account/settings'; do
    if grep -qF "$route" "$A11Y_RUNBOOK"; then
      pass_check "AC-FRONT-073: Runbook covers route $route"
    else
      fail_check "AC-FRONT-073: Runbook missing route $route"
    fi
  done
fi

# ---------------------------------------------------------------------------
# AC-FRONT-074: Artifact capture — evidence file in branding evidence directory
# ---------------------------------------------------------------------------
echo ""
echo "=== AC-FRONT-074: Branding Evidence Artifact Capture ==="

if [[ -f "$EVIDENCE_REPORT" ]]; then
  pass_check "AC-FRONT-074: Evidence report exists at docs/operations/evidence/a11y-regression-lane-report.md"
else
  fail_check "AC-FRONT-074: Evidence report missing at docs/operations/evidence/a11y-regression-lane-report.md"
fi

if [[ -f "$EVIDENCE_REPORT" ]]; then
  # Report must contain an a11y findings section
  if grep -qi 'a11y\|accessibility\|focus\|landmark' "$EVIDENCE_REPORT"; then
    pass_check "AC-FRONT-074: Evidence report contains a11y findings section"
  else
    fail_check "AC-FRONT-074: Evidence report missing a11y findings section"
  fi

  # Report must contain artifact paths section
  if grep -qi 'artifact\|path\|scripts/qa\|docs/operations' "$EVIDENCE_REPORT"; then
    pass_check "AC-FRONT-074: Evidence report contains artifact paths"
  else
    fail_check "AC-FRONT-074: Evidence report missing artifact paths section"
  fi
fi

# ---------------------------------------------------------------------------
# AC-FRONT-075: Evidence report references parent bead, pass/fail + blockers
# ---------------------------------------------------------------------------
echo ""
echo "=== AC-FRONT-075: Parent Bead Reference and Summary ==="

if [[ -f "$EVIDENCE_REPORT" ]]; then
  # Must reference parent bead 2dcy.3
  if grep -q '2dcy\.3\|2dcy3\|bead.*2dcy' "$EVIDENCE_REPORT"; then
    pass_check "AC-FRONT-075: Evidence report references parent bead 2dcy.3"
  else
    fail_check "AC-FRONT-075: Evidence report missing parent bead 2dcy.3 reference"
  fi

  # Must contain pass/fail summary
  if grep -qi 'pass\|fail' "$EVIDENCE_REPORT"; then
    pass_check "AC-FRONT-075: Evidence report contains pass/fail summary"
  else
    fail_check "AC-FRONT-075: Evidence report missing pass/fail summary"
  fi

  # Must contain follow-up blockers section
  if grep -qi 'blocker\|follow.up\|follow up' "$EVIDENCE_REPORT"; then
    pass_check "AC-FRONT-075: Evidence report contains follow-up blockers section"
  else
    fail_check "AC-FRONT-075: Evidence report missing follow-up blockers section"
  fi
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo "======================================="
echo "=== SUMMARY ==="
echo "PASS: $PASS"
echo "FAIL: $FAIL"
echo "WARN: $WARN"
echo "======================================="

if [[ $FAIL -gt 0 ]]; then
  echo ""
  printf "${RED}RESULT: FAIL${NC}\n"
  exit 1
fi

echo ""
printf "${GREEN}RESULT: PASS${NC}\n"
exit 0
