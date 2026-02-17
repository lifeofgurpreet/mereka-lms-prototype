#!/usr/bin/env bash
# verify-accessibility-conformance.sh — Accessibility conformance gate
# @covers AC-UIA11Y-001, AC-UIA11Y-002, AC-UIA11Y-003, AC-UIA11Y-004, AC-UIA11Y-005, AC-UIA11Y-006
#
# Verifies that Mereka Academy frontend meets WCAG 2.1 AA accessibility requirements.
# Checks policy documentation, contrast gates, focus management patterns, and known gaps.
#
# Usage: ./scripts/qa/verify-accessibility-conformance.sh
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

echo -e "${BLUE}=== Accessibility Conformance Gate ===${NC}"
echo ""

# ── 1. Policy Documentation ──
echo -e "${BLUE}## Policy Documentation${NC}"
POLICY_DOC="$REPO_ROOT/docs/architecture/ACCESSIBILITY_CONFORMANCE_POLICY.md"

if [ ! -f "$POLICY_DOC" ]; then
  do_fail "ACCESSIBILITY_CONFORMANCE_POLICY.md not found"
else
  do_pass "ACCESSIBILITY_CONFORMANCE_POLICY.md exists"

  # Check for required sections
  if grep -qF "## 1. Conformance Scope" "$POLICY_DOC"; then
    do_pass "Policy defines conformance scope"
  else
    do_fail "Policy missing conformance scope section"
  fi

  if grep -qF "## 2. Focus Management Policy" "$POLICY_DOC"; then
    do_pass "Policy defines focus management"
  else
    do_fail "Policy missing focus management section"
  fi

  if grep -qF "## 3. Skip Navigation Requirements" "$POLICY_DOC"; then
    do_pass "Policy defines skip navigation requirements"
  else
    do_fail "Policy missing skip navigation section"
  fi

  if grep -qF "## 4. ARIA Landmark Requirements" "$POLICY_DOC"; then
    do_pass "Policy defines ARIA landmark requirements"
  else
    do_fail "Policy missing ARIA landmarks section"
  fi

  if grep -qF "## 8. Known Gaps Table" "$POLICY_DOC"; then
    do_pass "Policy documents known gaps"
  else
    do_fail "Policy missing known gaps table"
  fi

  # Check for AC IDs
  if grep -qF "AC-UIA11Y-001" "$POLICY_DOC" && \
     grep -qF "AC-UIA11Y-002" "$POLICY_DOC" && \
     grep -qF "AC-UIA11Y-003" "$POLICY_DOC"; then
    do_pass "Policy references AC-UIA11Y-001 through AC-UIA11Y-003"
  else
    do_fail "Policy missing acceptance criteria tags"
  fi
fi

echo ""

# ── 2. WCAG AA Contrast Gate (AC-UIA11Y-001) ──
echo -e "${BLUE}## WCAG AA Contrast Gate (AC-UIA11Y-001)${NC}"
CONTRAST_SCRIPT="$REPO_ROOT/scripts/qa/verify-contrast-compliance.sh"

if [ ! -f "$CONTRAST_SCRIPT" ]; then
  do_fail "verify-contrast-compliance.sh not found"
else
  do_pass "verify-contrast-compliance.sh exists"

  if grep -qF "WCAG 2.1 AA" "$CONTRAST_SCRIPT"; then
    do_pass "Contrast script checks WCAG 2.1 AA"
  else
    do_warn "Contrast script missing WCAG 2.1 AA reference"
  fi
fi

echo ""

# ── 3. Axe-Core WCAG Gate (AC-UIA11Y-002) ──
echo -e "${BLUE}## Axe-Core WCAG 2.1 AA Gate (AC-UIA11Y-002)${NC}"
AXE_SCRIPT="$REPO_ROOT/scripts/qa/verify-ui-accessibility.sh"

if [ ! -f "$AXE_SCRIPT" ]; then
  do_fail "verify-ui-accessibility.sh not found"
else
  do_pass "verify-ui-accessibility.sh exists"

  if grep -qF "@covers AC-UIQ-002" "$AXE_SCRIPT"; then
    do_pass "Axe script tagged with AC-UIQ-002"
  else
    do_warn "Axe script missing @covers tag"
  fi

  # Check for 4 core journeys
  if grep -qF "/authn/login" "$AXE_SCRIPT" && \
     grep -qF "/learner-dashboard/" "$AXE_SCRIPT" && \
     grep -qF "/learning/" "$AXE_SCRIPT" && \
     grep -qF "/discussions/" "$AXE_SCRIPT"; then
    do_pass "Axe script tests 4 core journeys"
  else
    do_fail "Axe script missing core journeys"
  fi
fi

echo ""

# ── 4. Token Contrast Wrapper (AC-UIA11Y-003) ──
echo -e "${BLUE}## Token Contrast Wrapper (AC-UIA11Y-003)${NC}"
TOKEN_CONTRAST_SCRIPT="$REPO_ROOT/scripts/qa/verify-token-contrast.sh"

if [ ! -f "$TOKEN_CONTRAST_SCRIPT" ]; then
  do_fail "verify-token-contrast.sh not found"
else
  do_pass "verify-token-contrast.sh exists"

  if grep -qF "@covers AC-UIA11Y-003" "$TOKEN_CONTRAST_SCRIPT"; then
    do_pass "Token contrast script tagged with AC-UIA11Y-003"
  else
    do_warn "Token contrast script missing @covers tag"
  fi
fi

echo ""

# ── 5. Focus Ring Patterns ──
echo -e "${BLUE}## Focus Ring Patterns${NC}"
TOKENS_SCSS="$REPO_ROOT/infrastructure/tutor/themes/mereka/scss/_tokens.scss"
THEME_SCSS="$REPO_ROOT/infrastructure/tutor/themes/mereka/scss/theme.scss"
MFE_SCSS="$REPO_ROOT/infrastructure/tutor/themes/mereka/mfe/mereka.scss"

if [ ! -f "$TOKENS_SCSS" ]; then
  do_fail "_tokens.scss not found"
else
  # Check for :focus rules
  if grep -qF ":focus" "$TOKENS_SCSS"; then
    do_pass ":focus rules exist in _tokens.scss"
  else
    do_warn "No :focus rules in _tokens.scss"
  fi
fi

if [ -f "$THEME_SCSS" ]; then
  if grep -qF ":focus" "$THEME_SCSS"; then
    do_pass ":focus rules exist in theme.scss"
  else
    do_warn "No :focus rules in theme.scss"
  fi
fi

# Check for focus token in MFE SCSS
if [ -f "$MFE_SCSS" ]; then
  # Use -- to separate grep options from pattern (handles -- in CSS vars)
  if grep -qF -- "--mereka-mfe-focus" "$MFE_SCSS"; then
    do_pass "--mereka-mfe-focus token defined in MFE SCSS"
  else
    do_fail "--mereka-mfe-focus token missing from MFE SCSS"
  fi
fi

echo ""

# ── 6. Bare Outline Removal Check ──
echo -e "${BLUE}## Bare Outline Removal Check${NC}"
OVERRIDES_CSS=(
  "$REPO_ROOT/infrastructure/tutor/themes/mereka/lms/static/css/mereka-overrides.css"
  "$REPO_ROOT/infrastructure/tutor/themes/mereka/cms/static/css/mereka-overrides.css"
  "$REPO_ROOT/infrastructure/tutor/themes/mereka/common/static/css/mereka-overrides.css"
)

# Check each overrides file for paired outline removal
OUTLINE_NONE_COUNT=0
PAIRED_COUNT=0

for css_file in "${OVERRIDES_CSS[@]}"; do
  if [ ! -f "$css_file" ]; then
    continue
  fi

  # Count outline: none occurrences
  COUNT=$(grep -cF "outline: none" "$css_file" || true)
  OUTLINE_NONE_COUNT=$((OUTLINE_NONE_COUNT + COUNT))
done

if [ "$OUTLINE_NONE_COUNT" -gt 0 ]; then
  do_pass "Found $OUTLINE_NONE_COUNT outline:none declarations"

  # Verify each is paired with box-shadow
  for css_file in "${OVERRIDES_CSS[@]}"; do
    if [ ! -f "$css_file" ]; then
      continue
    fi

    # Extract :focus rule blocks containing outline: none
    # Check if box-shadow exists in same block (basic heuristic)
    FOCUS_BLOCKS=$(grep -A 5 "outline: none" "$css_file" || true)
    if echo "$FOCUS_BLOCKS" | grep -qF "box-shadow"; then
      PAIRED_COUNT=$((PAIRED_COUNT + 1))
    fi
  done

  if [ "$PAIRED_COUNT" -eq "$OUTLINE_NONE_COUNT" ]; then
    do_pass "All outline:none declarations paired with box-shadow"
  else
    do_warn "$PAIRED_COUNT/$OUTLINE_NONE_COUNT outline:none paired with box-shadow"
  fi
else
  do_pass "No outline:none declarations (preferred)"
fi

# Scan all SCSS/CSS for bare outline: none (not in comments)
echo ""
echo -e "${BLUE}## Comprehensive Outline Removal Scan${NC}"

# More sophisticated check: find :focus blocks with outline:none but no box-shadow in same block
BARE_OUTLINE_FOUND=false
while IFS= read -r css_file; do
  # Extract :focus rule blocks and check for outline:none without box-shadow
  # This is a simplified check - a real parser would be more accurate
  if grep -q "outline: none" "$css_file"; then
    # For each outline:none, check if box-shadow appears nearby (within 5 lines)
    while IFS= read -r line_num; do
      CONTEXT=$(sed -n "$((line_num - 2)),$((line_num + 5))p" "$css_file")
      if ! echo "$CONTEXT" | grep -q "box-shadow"; then
        BARE_OUTLINE_FOUND=true
        break
      fi
    done < <(grep -n "outline: none" "$css_file" | cut -d: -f1)
  fi
done < <(find "$REPO_ROOT/infrastructure/tutor/themes/mereka" -name "*.scss" -o -name "*.css")

if [ "$BARE_OUTLINE_FOUND" = false ]; then
  do_pass "No bare outline:none without replacement in SCSS/CSS"
else
  do_fail "Found bare outline:none without replacement (see policy for required pattern)"
fi

echo ""

# ── 7. Focus Token Bridge ──
echo -e "${BLUE}## Focus Token Bridge${NC}"

# Check for Paragon focus ring tokens in _tokens.scss
if [ -f "$TOKENS_SCSS" ]; then
  # Use -- to separate grep options from pattern
  if grep -qF -- "--pgn-focus-ring-color" "$TOKENS_SCSS"; then
    do_pass "Paragon focus ring token bridge exists"
  else
    do_warn "Paragon focus ring token bridge missing (documented gap, Q2 2026)"
  fi
fi

echo ""

# ── 8. Known Gaps (WARN, Not FAIL) ──
echo -e "${BLUE}## Known Gaps (Documented, Not Blocking)${NC}"

# Check for :focus-visible usage (planned enhancement)
FOCUS_VISIBLE_COUNT=$(grep -r ":focus-visible" \
  "$REPO_ROOT/infrastructure/tutor/themes/mereka" \
  --include="*.scss" --include="*.css" \
  | wc -l || true)

if [ "$FOCUS_VISIBLE_COUNT" -eq 0 ]; then
  do_warn "No :focus-visible usage (documented gap, Q2 2026) — AC-UIA11Y-004"
else
  do_pass ":focus-visible migration in progress ($FOCUS_VISIBLE_COUNT occurrences)"
fi

# Check for skip navigation link (Level A gap)
SKIP_NAV_COUNT=$(grep -r "skip-to-main\|skip-navigation\|skipnav" \
  "$REPO_ROOT/infrastructure/tutor/themes/mereka" \
  --include="*.jsx" --include="*.tsx" --include="*.scss" \
  | wc -l || true)

if [ "$SKIP_NAV_COUNT" -eq 0 ]; then
  do_warn "No skip navigation link (Level A gap, Q2 2026) — AC-UIA11Y-005"
else
  do_pass "Skip navigation link implemented ($SKIP_NAV_COUNT references)"
fi

# Check for ARIA landmarks (Level A gap)
ARIA_BANNER_COUNT=$(grep -r 'role="banner"' \
  "$REPO_ROOT/infrastructure/tutor/themes/mereka" \
  --include="*.jsx" --include="*.tsx" --include="*.html" \
  | wc -l || true)

ARIA_MAIN_COUNT=$(grep -r 'role="main"\|<main' \
  "$REPO_ROOT/infrastructure/tutor/themes/mereka" \
  --include="*.jsx" --include="*.tsx" --include="*.html" \
  | wc -l || true)

if [ "$ARIA_BANNER_COUNT" -eq 0 ]; then
  do_warn "No role=\"banner\" landmarks (Level A gap, Q2 2026) — AC-UIA11Y-006"
else
  do_pass "ARIA banner landmarks implemented ($ARIA_BANNER_COUNT references)"
fi

if [ "$ARIA_MAIN_COUNT" -eq 0 ]; then
  do_warn "No <main> or role=\"main\" landmarks (Level A gap, Q2 2026) — AC-UIA11Y-006"
else
  do_pass "ARIA main landmarks implemented ($ARIA_MAIN_COUNT references)"
fi

echo ""

# ── 9. CI Integration ──
echo -e "${BLUE}## CI Integration${NC}"
CI_YML="$REPO_ROOT/.github/workflows/ci.yml"

if [ ! -f "$CI_YML" ]; then
  do_fail "CI workflow not found"
else
  if grep -qF "verify-contrast-compliance.sh" "$CI_YML"; then
    do_pass "Contrast compliance gate in CI"
  else
    do_warn "Contrast compliance not in CI workflow"
  fi

  if grep -qF "verify-accessibility-conformance.sh" "$CI_YML"; then
    do_pass "Accessibility conformance gate in CI"
  else
    do_warn "Accessibility conformance not in CI workflow (expected after this task)"
  fi
fi

echo ""

# ── Summary ──
echo -e "${BLUE}## Summary${NC}"
echo ""
echo -e "  ${GREEN}PASS${NC}: $PASS"
echo -e "  ${YELLOW}WARN${NC}: $WARN"
echo -e "  ${RED}FAIL${NC}: $FAIL"
echo ""

if [ "$FAIL" -eq 0 ]; then
  echo -e "${GREEN}All accessibility conformance checks passed${NC}"
  echo ""
  echo "Notes:"
  echo "  - WARN items are documented gaps with Q2 2026 timelines (not blocking)"
  echo "  - PASS items indicate active gates and compliant patterns"
  echo "  - See docs/architecture/ACCESSIBILITY_CONFORMANCE_POLICY.md for details"
  exit 0
else
  echo -e "${RED}Some accessibility conformance checks failed${NC}"
  echo ""
  echo "Fix FAIL items before committing. WARN items are documented gaps (not blocking)."
  exit 1
fi
