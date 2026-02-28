#!/usr/bin/env bash
# verify-interaction-state-contract.sh — @covers AC-UISTATE-001..004
#
# Verifies the interaction-state quality contract:
# - Contract documentation exists with required sections
# - MFE coverage matrix is present with all 11 MFEs
# - Paragon interaction components documented
# - Design token bridge includes feedback colors
# - No hardcoded feedback colors in MFE SCSS
# - Token definitions include all 4 semantic states
#
# Usage: ./scripts/qa/verify-interaction-state-contract.sh
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
CONTRACT="$REPO_ROOT/docs/architecture/INTERACTION_STATE_CONTRACT.md"
TOKENS="$REPO_ROOT/infrastructure/tutor/themes/mereka/scss/_tokens.scss"
MFE_SCSS_DIR="$REPO_ROOT/infrastructure/tutor/themes/mereka/mfe"

PASS=0
FAIL=0
WARN=0

do_pass() { PASS=$((PASS + 1)); echo "  PASS  $1"; }
do_fail() { FAIL=$((FAIL + 1)); echo "  FAIL  $1"; }
do_warn() { WARN=$((WARN + 1)); echo "  WARN  $1"; }

echo "=== AC-UISTATE-001..004: Interaction State Contract Verification ==="
echo ""

# 1. Contract documentation exists
echo "--- Contract Documentation ---"
if [ -f "$CONTRACT" ]; then
  do_pass "INTERACTION_STATE_CONTRACT.md exists"
else
  do_fail "INTERACTION_STATE_CONTRACT.md not found"
  echo ""
  echo "=== Results: $PASS PASS / $FAIL FAIL / $WARN WARN ==="
  exit 1
fi

# 2. Required sections present
echo ""
echo "--- Required Sections ---"
required_sections=(
  "Loading State"
  "Empty State"
  "Error State"
  "Success State"
  "MFE Coverage Matrix"
  "Design Token Requirements"
  "XBlock Feedback Gap"
)

for section in "${required_sections[@]}"; do
  if grep -qi "$section" "$CONTRACT"; then
    do_pass "Section present: $section"
  else
    do_fail "Section missing: $section"
  fi
done

# 3. MFE coverage matrix includes all 11 MFEs
echo ""
echo "--- MFE Coverage Matrix ---"
if grep -q "MFE Coverage Matrix" "$CONTRACT"; then
  do_pass "MFE Coverage Matrix section exists"

  mfes=(
    "authn"
    "account"
    "learning"
    "profile"
    "discussions"
    "gradebook"
    "learner-dashboard"
    "communications"
    "ora-grading"
    "authoring"
    "course-authoring"
  )

  for mfe in "${mfes[@]}"; do
    if grep -qi "$mfe" "$CONTRACT"; then
      do_pass "MFE listed in matrix: $mfe"
    else
      do_warn "MFE not found in matrix: $mfe"
    fi
  done
else
  do_fail "MFE Coverage Matrix section not found"
fi

# 4. Paragon components documented
echo ""
echo "--- Paragon Interaction Components ---"
paragon_components=(
  "Spinner"
  "Skeleton"
  "Alert"
  "Toast"
)

for component in "${paragon_components[@]}"; do
  if grep -q "$component" "$CONTRACT"; then
    do_pass "Paragon component documented: $component"
  else
    do_warn "Paragon component not documented: $component"
  fi
done

# 5. Design token bridge includes feedback colors
echo ""
echo "--- Design Token Bridge ---"
if [ -f "$TOKENS" ]; then
  do_pass "_tokens.scss exists"

  semantic_colors=(
    "color-success"
    "color-warning"
    "color-danger"
    "color-info"
  )

  for color in "${semantic_colors[@]}"; do
    if grep -q "\$$color:" "$TOKENS"; then
      do_pass "Token defined: $color"
    else
      do_fail "Token missing: $color"
    fi
  done

  # Check CSS custom properties
  echo ""
  echo "--- CSS Custom Properties ---"
  css_vars=(
    "--mereka-color-success"
    "--mereka-color-warning"
    "--mereka-color-danger"
    "--mereka-color-info"
    "--pgn-color-success"
    "--pgn-color-warning"
    "--pgn-color-danger"
    "--pgn-color-info"
  )

  for var in "${css_vars[@]}"; do
    if grep -qF -- "$var:" "$TOKENS"; then
      do_pass "CSS custom property: $var"
    else
      do_warn "CSS custom property missing: $var"
    fi
  done
else
  do_fail "_tokens.scss not found"
fi

# 6. No hardcoded feedback colors in MFE SCSS
echo ""
echo "--- Hardcoded Color Check (MFE SCSS) ---"
if [ -d "$MFE_SCSS_DIR" ]; then
  do_pass "MFE SCSS directory exists"

  # Known hardcoded colors in feedback contexts
  hardcoded_patterns=(
    "#d4edda"  # Bootstrap success background
    "#f8d7da"  # Bootstrap danger background
    "#d1ecf1"  # Bootstrap info background
    "#fff3cd"  # Bootstrap warning background
  )

  hardcoded_found=0
  for pattern in "${hardcoded_patterns[@]}"; do
    if grep -ri "$pattern" "$MFE_SCSS_DIR" 2>/dev/null | grep -v "\.git" | grep -qv "node_modules"; then
      do_warn "Hardcoded feedback color found in MFE SCSS: $pattern"
      hardcoded_found=1
    fi
  done

  if [ "$hardcoded_found" -eq 0 ]; then
    do_pass "No hardcoded feedback colors in MFE SCSS"
  fi
else
  do_warn "MFE SCSS directory not found (may not have custom MFE styles yet)"
fi

# 7. XBlock feedback gap documented
echo ""
echo "--- XBlock Feedback Gap ---"
if grep -qi "XBlock Feedback Gap" "$CONTRACT"; then
  do_pass "XBlock feedback gap documented"
  if grep -qi "hardcoded" "$CONTRACT" && grep -qi "custom-apps" "$CONTRACT"; then
    do_pass "Gap explains hardcoded colors in custom-apps"
  else
    do_warn "Gap documentation may be incomplete"
  fi
else
  do_warn "XBlock feedback gap not documented"
fi

# 8. Acceptance criteria tagged
echo ""
echo "--- Acceptance Criteria ---"
ac_tags=(
  "AC-UISTATE-001"
  "AC-UISTATE-002"
  "AC-UISTATE-003"
  "AC-UISTATE-004"
)

for tag in "${ac_tags[@]}"; do
  if grep -q "$tag" "$CONTRACT"; then
    do_pass "AC tagged: $tag"
  else
    do_warn "AC not tagged: $tag"
  fi
done

echo ""
echo "=== Results: $PASS PASS / $FAIL FAIL / $WARN WARN ==="

[ "$FAIL" -eq 0 ] && exit 0 || exit 1
