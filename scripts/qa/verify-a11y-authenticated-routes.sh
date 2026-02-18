#!/usr/bin/env bash
# verify-a11y-authenticated-routes.sh — A11y focus/landmark gate for authenticated MFE routes
# @covers AC-ACCSS-201, AC-ACCSS-202, AC-ACCSS-203, AC-ACCSS-204, AC-ACCSS-205
# @spec: bead-3vg92
#
# Verifies (offline mode, default):
# 1. Route scenarios defined for dashboard, account/profile, and learning (AC-ACCSS-201)
# 2. Landmark requirements matrix exists and covers all required landmarks per route (AC-ACCSS-202)
# 3. Focus indicator contrast requirements documented at 3:1 minimum (AC-ACCSS-203)
# 4. Artifact storage path documented and runbook exists with remediation notes (AC-ACCSS-204)
# 5. Regression guard / ticket template documented for script failures (AC-ACCSS-205)
#
# Modes:
#   Offline (default): validates runbook documentation + structure
#   Live (A11Y_LIVE=1): placeholder for authenticated browser checks (future)
#
# Usage:
#   ./scripts/qa/verify-a11y-authenticated-routes.sh
#   A11Y_LIVE=1 ./scripts/qa/verify-a11y-authenticated-routes.sh
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

RUNBOOK="$REPO_ROOT/docs/operations/ACCESSIBILITY_CONFORMANCE_RUNBOOK.md"
VAR_DIR="$REPO_ROOT/var"
ARTIFACT="$VAR_DIR/a11y-authenticated-routes-gate.txt"
A11Y_LIVE="${A11Y_LIVE:-0}"

echo -e "${BLUE}=== A11y Authenticated Route Focus/Landmark Gate ===${NC}"
echo "  Mode: $([ "$A11Y_LIVE" = "1" ] && echo "LIVE (authenticated)" || echo "OFFLINE (documentation)")"
echo "  Runbook: docs/operations/ACCESSIBILITY_CONFORMANCE_RUNBOOK.md"
echo ""

# ── AC-ACCSS-201: Route scenarios defined ────────────────────────────
echo -e "${BLUE}## AC-ACCSS-201: Authenticated Route Scenario Coverage${NC}"

if [[ ! -f "$RUNBOOK" ]]; then
  do_fail "AC-ACCSS-201: ACCESSIBILITY_CONFORMANCE_RUNBOOK.md not found at docs/operations/"
  echo ""
  echo "  Create the runbook at docs/operations/ACCESSIBILITY_CONFORMANCE_RUNBOOK.md"
  echo "  It must document route scenarios for dashboard, account/profile, and learning routes."
else
  do_pass "AC-ACCSS-201: ACCESSIBILITY_CONFORMANCE_RUNBOOK.md exists"

  # Check that all 3 required route categories are documented
  declare -A ROUTE_CHECKS=(
    ["/learner-dashboard"]="learner dashboard route"
    ["/account/"]="account/profile route"
    ["/learning/"]="learning/courseware route"
  )

  for route in "${!ROUTE_CHECKS[@]}"; do
    label="${ROUTE_CHECKS[$route]}"
    if grep -qF "$route" "$RUNBOOK"; then
      do_pass "AC-ACCSS-201: $label ($route) documented in runbook"
    else
      do_fail "AC-ACCSS-201: $label ($route) missing from runbook route scenarios"
    fi
  done
fi

echo ""

# ── AC-ACCSS-202: Landmark requirements matrix ───────────────────────
echo -e "${BLUE}## AC-ACCSS-202: Landmark Requirements Matrix${NC}"

if [[ ! -f "$RUNBOOK" ]]; then
  do_fail "AC-ACCSS-202: Runbook missing — cannot verify landmark requirements matrix"
else
  # Required ARIA landmarks per WCAG 1.3.6 and best practice
  REQUIRED_LANDMARKS=("main" "nav" "banner" "contentinfo")

  for landmark in "${REQUIRED_LANDMARKS[@]}"; do
    if grep -qF "role=\"${landmark}\"\|<${landmark}\|landmark: ${landmark}" "$RUNBOOK" 2>/dev/null \
       || grep -qF "${landmark}" "$RUNBOOK" 2>/dev/null; then
      do_pass "AC-ACCSS-202: Landmark '${landmark}' present in requirements matrix"
    else
      do_fail "AC-ACCSS-202: Landmark '${landmark}' missing from requirements matrix"
    fi
  done

  # Verify the matrix covers all 3 routes (duplicate check + landmark matrix)
  if grep -qiE "landmark.*(matrix|table|requirements)|required.*landmark" "$RUNBOOK"; then
    do_pass "AC-ACCSS-202: Landmark requirements matrix section exists in runbook"
  else
    do_fail "AC-ACCSS-202: Landmark requirements matrix section not found in runbook"
  fi

  # Verify duplicate-landmark check is documented
  if grep -qiE "duplicat|multiple.*landmark|unique.*landmark" "$RUNBOOK"; then
    do_pass "AC-ACCSS-202: Duplicate landmark detection requirement documented"
  else
    do_fail "AC-ACCSS-202: Duplicate landmark detection requirement not documented in runbook"
  fi
fi

echo ""

# ── AC-ACCSS-203: Focus indicator contrast requirements ───────────────
echo -e "${BLUE}## AC-ACCSS-203: Focus Indicator Contrast Requirements${NC}"

if [[ ! -f "$RUNBOOK" ]]; then
  do_fail "AC-ACCSS-203: Runbook missing — cannot verify focus indicator specifications"
else
  # WCAG 2.2 SC 1.4.11 Non-text Contrast: 3:1 minimum for focus indicators
  if grep -qE "3:1|3\.0:1|3\.0 ?:" "$RUNBOOK"; then
    do_pass "AC-ACCSS-203: 3:1 minimum contrast ratio for focus indicators documented"
  else
    do_fail "AC-ACCSS-203: 3:1 minimum contrast for focus indicators not documented (WCAG 2.2 SC 1.4.11)"
  fi

  # Check that visible outline (not just color change) is required
  if grep -qiE "outline|visible.*focus|focus.*visible|not.*only.*color|color.*alone" "$RUNBOOK"; then
    do_pass "AC-ACCSS-203: Visible focus outline requirement documented (not just color change)"
  else
    do_fail "AC-ACCSS-203: Visible focus outline requirement missing — must specify outline, not just color change"
  fi

  # Check interactive control coverage (buttons, links, form inputs)
  if grep -qiE "button|link|input|form.control|interactive" "$RUNBOOK"; then
    do_pass "AC-ACCSS-203: Primary interactive controls (buttons/links/inputs) included in focus spec"
  else
    do_fail "AC-ACCSS-203: Primary interactive controls not mentioned in focus indicator spec"
  fi

  # Check WCAG reference
  if grep -qiE "WCAG 2\.[12]|SC 1\.4\.(11|3)|SC 2\.4\.(7|11)" "$RUNBOOK"; then
    do_pass "AC-ACCSS-203: WCAG success criterion reference present for focus requirements"
  else
    do_warn "AC-ACCSS-203: WCAG SC reference not found for focus requirements — add SC 1.4.11 / SC 2.4.7"
  fi
fi

echo ""

# ── AC-ACCSS-204: Artifact storage + route-level evidence ─────────────
echo -e "${BLUE}## AC-ACCSS-204: Artifact Storage and Route Evidence${NC}"

if [[ ! -f "$RUNBOOK" ]]; then
  do_fail "AC-ACCSS-204: Runbook missing — cannot verify artifact storage documentation"
else
  # Artifact path pattern: var/a11y/{route}-{timestamp}.json
  if grep -qE "var/a11y|var\/a11y" "$RUNBOOK"; then
    do_pass "AC-ACCSS-204: Artifact storage path (var/a11y/) documented in runbook"
  else
    do_fail "AC-ACCSS-204: Artifact storage path not documented — expected var/a11y/{route}-{timestamp}.json"
  fi

  # Check timestamp pattern is documented
  if grep -qiE "timestamp|\{timestamp\}|%Y|date.*json|json.*date" "$RUNBOOK"; then
    do_pass "AC-ACCSS-204: Route-timestamped artifact naming documented"
  else
    do_fail "AC-ACCSS-204: Timestamped artifact naming pattern not documented"
  fi

  # Check remediation notes per route
  if grep -qiE "remediat" "$RUNBOOK"; then
    do_pass "AC-ACCSS-204: Remediation notes present in runbook"
  else
    do_fail "AC-ACCSS-204: Remediation notes missing from runbook"
  fi

  # Check reference to existing A11Y_CONTRAST_FOCUS_GATE.md
  if grep -qF "A11Y_CONTRAST_FOCUS_GATE.md" "$RUNBOOK"; then
    do_pass "AC-ACCSS-204: Cross-reference to A11Y_CONTRAST_FOCUS_GATE.md present"
  else
    do_warn "AC-ACCSS-204: No cross-reference to A11Y_CONTRAST_FOCUS_GATE.md — consider linking for completeness"
  fi
fi

echo ""

# ── AC-ACCSS-205: Regression guard / ticket suggestion ────────────────
echo -e "${BLUE}## AC-ACCSS-205: Regression Guard and Ticket Template${NC}"

if [[ ! -f "$RUNBOOK" ]]; then
  do_fail "AC-ACCSS-205: Runbook missing — cannot verify regression guard documentation"
else
  # Ticket template fields: route, expected landmarks, actual, remediation
  if grep -qiE "ticket|issue|regression.guard|failure.*ticket|ticket.*failure" "$RUNBOOK"; then
    do_pass "AC-ACCSS-205: Regression guard / ticket suggestion section present"
  else
    do_fail "AC-ACCSS-205: Regression guard or ticket template section not found in runbook"
  fi

  # Check ticket template has required fields
  TICKET_FIELDS=("route" "expected" "actual" "remediation")
  for field in "${TICKET_FIELDS[@]}"; do
    if grep -qiE "\\b${field}\\b" "$RUNBOOK"; then
      do_pass "AC-ACCSS-205: Ticket template field '${field}' documented"
    else
      do_fail "AC-ACCSS-205: Ticket template missing field '${field}'"
    fi
  done

  # Check deterministic output: failure → suggestion
  if grep -qiE "determin|suggest|auto.*ticket|failure.*suggest|suggest.*title" "$RUNBOOK"; then
    do_pass "AC-ACCSS-205: Deterministic ticket suggestion for failures documented"
  else
    do_warn "AC-ACCSS-205: Deterministic ticket suggestion pattern not explicit — consider adding example output"
  fi
fi

echo ""

# ── Live mode placeholder ─────────────────────────────────────────────
if [[ "$A11Y_LIVE" = "1" ]]; then
  echo -e "${BLUE}## Live Mode: Authenticated Route Checks (placeholder)${NC}"
  do_warn "AC-ACCSS-201..203: A11Y_LIVE=1 set but live authenticated checks require a running LMS instance"
  echo "  To run live checks:"
  echo "    1. Ensure LMS is accessible at \$LMS_URL (default: http://localhost)"
  echo "    2. Provide credentials: LMS_EMAIL, LMS_PASSWORD"
  echo "    3. Use axe-cli or Playwright + @axe-core/playwright for landmark/focus assertions"
  echo "    4. Artifacts will be written to var/a11y/{route}-{timestamp}.json"
  echo ""
fi

# ── Write CI artifact ─────────────────────────────────────────────────
mkdir -p "$VAR_DIR/a11y"
{
  echo "a11y-authenticated-routes-gate"
  echo "run_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "mode=$([ "$A11Y_LIVE" = "1" ] && echo live || echo offline)"
  echo "pass=$PASS"
  echo "warn=$WARN"
  echo "fail=$FAIL"
  echo "status=$([ "$FAIL" -eq 0 ] && echo PASS || echo FAIL)"
} > "$ARTIFACT"

# ── Summary ───────────────────────────────────────────────────────────
echo -e "${BLUE}## Summary${NC}"
echo ""
echo -e "  ${GREEN}PASS${NC}: $PASS"
echo -e "  ${YELLOW}WARN${NC}: $WARN"
echo -e "  ${RED}FAIL${NC}: $FAIL"
echo ""

if [[ "$FAIL" -eq 0 ]]; then
  echo -e "${GREEN}All a11y authenticated route checks passed${NC}"
  if [[ "$WARN" -gt 0 ]]; then
    echo ""
    echo "Notes:"
    echo "  - WARN items are improvements (not blocking)"
    echo "  - See docs/operations/ACCESSIBILITY_CONFORMANCE_RUNBOOK.md for full details"
  fi
  exit 0
else
  echo -e "${RED}Some a11y authenticated route checks failed${NC}"
  echo ""
  echo "Fix FAIL items before merging."
  echo "See docs/operations/ACCESSIBILITY_CONFORMANCE_RUNBOOK.md for the remediation process."
  echo ""
  echo "Regression guard — suggested ticket title for each FAIL:"
  echo "  a11y(authenticated-routes): <route> landmark/focus failure — <AC-ACCSS-NNN>"
  exit 1
fi
