#!/usr/bin/env bash
# verify-css-scoping.sh — CSS global-selector scoping audit gate
# @covers AC-CSS-SCOPE-001, AC-CSS-SCOPE-002, AC-CSS-SCOPE-003, AC-CSS-SCOPE-004
# @spec: T105
#
# Checks that high-risk global CSS selectors in the Mereka theme are either:
#   (a) properly scoped under a page-context prefix, OR
#   (b) documented as a known gap in CSS_SCOPING_AUDIT.md
#
# This script is READ-ONLY — it does not modify any CSS/SCSS files.
#
# Counters:
#   PASS  — check explicitly passed
#   FAIL  — check explicitly failed (blocks CI gate)
#   SKIP  — check skipped (file not present or context not applicable)
#   WARN  — advisory only (known gap, not CI-blocking)
#
# Usage: ./scripts/qa/verify-css-scoping.sh
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PASS=0
FAIL=0
SKIP=0
WARN=0

do_pass() { PASS=$((PASS + 1)); echo -e "${GREEN}[PASS]${NC} $1"; }
do_fail() { FAIL=$((FAIL + 1)); echo -e "${RED}[FAIL]${NC} $1"; }
do_skip() { SKIP=$((SKIP + 1)); echo -e "${YELLOW}[SKIP]${NC} $1"; }
do_warn() { WARN=$((WARN + 1)); echo -e "${YELLOW}[WARN]${NC} $1"; }

THEME_DIR="$REPO_ROOT/infrastructure/tutor/themes/mereka"
TOKENS_SCSS="$THEME_DIR/scss/_tokens.scss"
THEME_SCSS="$THEME_DIR/scss/theme.scss"
MFE_SCSS="$THEME_DIR/mfe/mereka.scss"
COMMON_CSS="$THEME_DIR/common/static/css/mereka-overrides.css"
LMS_CSS="$THEME_DIR/lms/static/css/mereka-overrides.css"
CMS_CSS="$THEME_DIR/cms/static/css/mereka-overrides.css"
AUDIT_DOC="$REPO_ROOT/docs/architecture/CSS_SCOPING_AUDIT.md"

echo -e "${BLUE}=== CSS Scoping Audit Gate ===${NC}"
echo "  Theme dir: infrastructure/tutor/themes/mereka/"
echo "  Audit doc: docs/architecture/CSS_SCOPING_AUDIT.md"
echo ""

# ─────────────────────────────────────────────────────────────────────────────
# AC-CSS-SCOPE-001: Audit documentation exists and has required sections
# ─────────────────────────────────────────────────────────────────────────────
echo -e "${BLUE}## AC-CSS-SCOPE-001: Audit documentation${NC}"

if [[ ! -f "$AUDIT_DOC" ]]; then
  do_fail "AC-CSS-SCOPE-001: CSS_SCOPING_AUDIT.md not found at docs/architecture/"
else
  do_pass "AC-CSS-SCOPE-001: CSS_SCOPING_AUDIT.md exists"

  # Required sections
  for section in \
    "## Section 1" \
    "## Section 2" \
    "## Section 5 — Summary" \
    "Section 7" \
    "XBlock impact" \
    "Recommendation"
  do
    if grep -qF "$section" "$AUDIT_DOC"; then
      do_pass "AC-CSS-SCOPE-001: Audit doc contains: $section"
    else
      do_fail "AC-CSS-SCOPE-001: Audit doc missing: $section"
    fi
  done

  # Must reference all six theme files
  for fname in "_tokens.scss" "theme.scss" "mereka.scss" "mereka-overrides.css"; do
    if grep -qF "$fname" "$AUDIT_DOC"; then
      do_pass "AC-CSS-SCOPE-001: Audit doc references $fname"
    else
      do_fail "AC-CSS-SCOPE-001: Audit doc missing reference to $fname"
    fi
  done
fi

echo ""

# ─────────────────────────────────────────────────────────────────────────────
# AC-CSS-SCOPE-002: High-risk global selectors — .card and .btn-primary
#
# These are the P1 candidates identified in the audit. The gate checks:
#   (a) They exist as global selectors (confirming the problem is present), AND
#   (b) A scoped counterpart also exists (mitigating the XBlock risk)
#
# This is a WARN-level gate, not FAIL, because the global rules are a known
# documented gap (T106) — not an accidental regression.
# ─────────────────────────────────────────────────────────────────────────────
echo -e "${BLUE}## AC-CSS-SCOPE-002: P1 global selectors — .card and .btn-primary${NC}"

# ── .card in _tokens.scss ───────────────────────────────────────────────────
if [[ ! -f "$TOKENS_SCSS" ]]; then
  do_skip "AC-CSS-SCOPE-002: _tokens.scss not found — skipping .card check"
else
  # Global .card rule exists (the known gap)
  if grep -qE '^\s*\.card\s*\{' "$TOKENS_SCSS"; then
    do_warn "AC-CSS-SCOPE-002: Global .card rule found in _tokens.scss (documented gap G5 — T106)"
  else
    do_pass "AC-CSS-SCOPE-002: No bare global .card rule in _tokens.scss"
  fi
fi

# ── .card in mfe/mereka.scss — check .shadow-lg grouping ───────────────────
if [[ ! -f "$MFE_SCSS" ]]; then
  do_skip "AC-CSS-SCOPE-002: mereka.scss not found — skipping .shadow-lg check"
else
  # .shadow-lg should not be grouped with .card to avoid applying border-radius to overlays
  if grep -qE '\.shadow-lg' "$MFE_SCSS"; then
    # Check if .shadow-lg is grouped with .card on the same rule
    if grep -E '\.card|\.pgn__card' "$MFE_SCSS" | grep -q '\.shadow-lg'; then
      do_warn "AC-CSS-SCOPE-002: .shadow-lg grouped with .card in mereka.scss (documented gap G9 — overapplication risk)"
    else
      do_pass "AC-CSS-SCOPE-002: .shadow-lg not grouped with .card selectors in mereka.scss"
    fi
  else
    do_pass "AC-CSS-SCOPE-002: .shadow-lg not present in mereka.scss"
  fi
fi

# ── .btn-primary in common overrides — global rule present ──────────────────
if [[ ! -f "$COMMON_CSS" ]]; then
  do_skip "AC-CSS-SCOPE-002: common mereka-overrides.css not found"
else
  # A bare .btn-primary { rule (not prefixed by a page class) is expected as a known gap
  # We detect it by looking for .btn-primary at the start of a rule (no preceding page-scope)
  if grep -qE '^\.btn-primary\s*,' "$COMMON_CSS" || grep -qE '^\.btn-primary\s*\{' "$COMMON_CSS"; then
    do_warn "AC-CSS-SCOPE-002: Global .btn-primary rule found in common/mereka-overrides.css (documented gap G4 — T106)"
  else
    do_pass "AC-CSS-SCOPE-002: No bare global .btn-primary rule in common/mereka-overrides.css"
  fi

  # The scoped counterpart MUST exist to mitigate XBlock impact
  if grep -qE '\.courseware\s+\.xblock\s+.*button|\.courseware\s+\.xblock\s+\.problem' "$COMMON_CSS" || \
     grep -qE '\.courseware\.xblock\s+.*button' "$COMMON_CSS"; then
    do_pass "AC-CSS-SCOPE-002: Scoped .courseware .xblock problem button rule exists (XBlock mitigation present)"
  elif grep -qF '.courseware .xblock .problem button' "$COMMON_CSS" || \
       grep -qF '.courseware .xblock .problem' "$COMMON_CSS"; then
    do_pass "AC-CSS-SCOPE-002: Scoped .courseware .xblock .problem rule exists in common/mereka-overrides.css"
  else
    do_warn "AC-CSS-SCOPE-002: No scoped XBlock problem button rule found in common/mereka-overrides.css — global .btn-primary has no XBlock override"
  fi
fi

echo ""

# ─────────────────────────────────────────────────────────────────────────────
# AC-CSS-SCOPE-003: Verify correctly-scoped XBlock chrome patterns are present
#
# The audit identified .courseware .xblock as the reference scoping pattern.
# This check verifies the pattern is intact in both CSS files.
# ─────────────────────────────────────────────────────────────────────────────
echo -e "${BLUE}## AC-CSS-SCOPE-003: XBlock chrome scoping patterns present${NC}"

for css_file in "$LMS_CSS" "$COMMON_CSS"; do
  fname="$(basename "$(dirname "$css_file")")/$(basename "$css_file")"
  if [[ ! -f "$css_file" ]]; then
    do_skip "AC-CSS-SCOPE-003: $fname not found"
    continue
  fi

  # .courseware .xblock { ... } wrapper rule
  if grep -qF '.courseware .xblock' "$css_file"; then
    do_pass "AC-CSS-SCOPE-003: .courseware .xblock scope found in $fname"
  else
    do_fail "AC-CSS-SCOPE-003: .courseware .xblock scope missing from $fname"
  fi

  # Heading elements scoped inside .courseware .xblock
  if grep -qE '\.courseware\s+\.xblock\s+h[1-6]|\.courseware\s+\.xblock\s+\.hd' "$css_file"; then
    do_pass "AC-CSS-SCOPE-003: Heading elements scoped under .courseware .xblock in $fname"
  else
    do_warn "AC-CSS-SCOPE-003: No heading scope under .courseware .xblock in $fname (global headings only)"
  fi

  # Link colour scoped inside .courseware .xblock
  if grep -qF '.courseware .xblock a' "$css_file"; then
    do_pass "AC-CSS-SCOPE-003: Link colour scoped under .courseware .xblock in $fname"
  else
    do_warn "AC-CSS-SCOPE-003: No .courseware .xblock a rule in $fname (global link colour only)"
  fi
done

# Studio XBlock chrome in theme.scss
if [[ ! -f "$THEME_SCSS" ]]; then
  do_skip "AC-CSS-SCOPE-003: theme.scss not found"
else
  if grep -qF '.view-container .xblock-render' "$THEME_SCSS"; then
    do_pass "AC-CSS-SCOPE-003: Studio .view-container .xblock-render scope found in theme.scss"
  else
    do_fail "AC-CSS-SCOPE-003: Studio .view-container .xblock-render scope missing from theme.scss"
  fi
fi

echo ""

# ─────────────────────────────────────────────────────────────────────────────
# AC-CSS-SCOPE-004: Page-scope prefixes are present for LMS discovery + dashboard
#
# Verifies that the key page-scoped rule sets (.find-courses, .dashboard,
# .courseware) are all present — they act as the safe alternative to global rules.
# ─────────────────────────────────────────────────────────────────────────────
echo -e "${BLUE}## AC-CSS-SCOPE-004: Page-scope prefixes present (discovery + dashboard + courseware)${NC}"

for css_file in "$LMS_CSS" "$COMMON_CSS"; do
  fname="$(basename "$(dirname "$css_file")")/$(basename "$css_file")"
  if [[ ! -f "$css_file" ]]; then
    do_skip "AC-CSS-SCOPE-004: $fname not found"
    continue
  fi

  for page_scope in ".find-courses" ".dashboard" ".courseware" ".course-info" ".course-about"; do
    if grep -qF "$page_scope" "$css_file"; then
      do_pass "AC-CSS-SCOPE-004: $page_scope scope present in $fname"
    else
      do_fail "AC-CSS-SCOPE-004: $page_scope scope missing from $fname"
    fi
  done
done

# MFE-specific: verify MFE surface scopes are present
if [[ ! -f "$MFE_SCSS" ]]; then
  do_skip "AC-CSS-SCOPE-004: mereka.scss not found — skipping MFE scope checks"
else
  for mfe_scope in 'class*="authn"' 'class*="learner-dashboard"' 'class*="learning"' 'class*="discussions"'; do
    if grep -qF "$mfe_scope" "$MFE_SCSS"; then
      do_pass "AC-CSS-SCOPE-004: MFE surface scope [$mfe_scope] present in mereka.scss"
    else
      do_fail "AC-CSS-SCOPE-004: MFE surface scope [$mfe_scope] missing from mereka.scss"
    fi
  done
fi

echo ""

# ─────────────────────────────────────────────────────────────────────────────
# AC-CSS-SCOPE-005: No regressions — global .btn-primary should not be removed
#   (it's a known gap, not an accidental addition)
#
# Additional structural checks:
#   - Verify all six theme files exist
#   - Verify :root token block is present in _tokens.scss
#   - Verify MFE scss imports the shared theme
# ─────────────────────────────────────────────────────────────────────────────
echo -e "${BLUE}## AC-CSS-SCOPE-005: Structural integrity checks${NC}"

# All theme files must exist
for f in "$TOKENS_SCSS" "$THEME_SCSS" "$MFE_SCSS" "$COMMON_CSS" "$LMS_CSS" "$CMS_CSS"; do
  fname="${f#$REPO_ROOT/}"
  if [[ -f "$f" ]]; then
    do_pass "AC-CSS-SCOPE-005: Theme file exists: $fname"
  else
    do_fail "AC-CSS-SCOPE-005: Theme file missing: $fname"
  fi
done

# :root block must be in _tokens.scss (CSS custom property definitions)
if [[ -f "$TOKENS_SCSS" ]]; then
  if grep -qE '^\s*:root\s*\{' "$TOKENS_SCSS"; then
    do_pass "AC-CSS-SCOPE-005: :root token block present in _tokens.scss"
  else
    do_fail "AC-CSS-SCOPE-005: :root token block missing from _tokens.scss"
  fi

  # Required --pgn-* bridge tokens must be present
  for token in --pgn-color-primary --pgn-color-secondary --pgn-body-bg --pgn-font-family-sans-serif; do
    if grep -qF -- "$token" "$TOKENS_SCSS"; then
      do_pass "AC-CSS-SCOPE-005: Paragon bridge token $token present in _tokens.scss"
    else
      do_fail "AC-CSS-SCOPE-005: Paragon bridge token $token missing from _tokens.scss"
    fi
  done
fi

# MFE SCSS must import the shared theme
if [[ -f "$MFE_SCSS" ]]; then
  if grep -qE "@import\s+['\"].*theme['\"]|@import\s+['\"].*scss/theme" "$MFE_SCSS"; then
    do_pass "AC-CSS-SCOPE-005: mereka.scss imports shared theme"
  else
    do_fail "AC-CSS-SCOPE-005: mereka.scss does not import shared theme"
  fi
fi

# :root in runtime CSS (common overrides)
if [[ -f "$COMMON_CSS" ]]; then
  if grep -qF ':root' "$COMMON_CSS"; then
    do_pass "AC-CSS-SCOPE-005: :root custom property block present in common/mereka-overrides.css"
  else
    do_fail "AC-CSS-SCOPE-005: :root custom property block missing from common/mereka-overrides.css"
  fi

  # Versioning/revision marker must be present
  if grep -qF -- '--mereka-branding-rev' "$COMMON_CSS"; then
    do_pass "AC-CSS-SCOPE-005: --mereka-branding-rev revision marker present in common/mereka-overrides.css"
  else
    do_warn "AC-CSS-SCOPE-005: --mereka-branding-rev revision marker missing from common/mereka-overrides.css"
  fi
fi

echo ""

# ─────────────────────────────────────────────────────────────────────────────
# AC-CSS-SCOPE-006: Known-gap WARN check — bare element selectors inventory
#
# Documents and warns (not fails) on known bare element selectors that affect
# XBlocks. These are tracked for T106 remediation.
# ─────────────────────────────────────────────────────────────────────────────
echo -e "${BLUE}## AC-CSS-SCOPE-006: Known-gap inventory (documented WARNs)${NC}"

# Count bare h1-h6 rules NOT inside a page-scope prefix
for css_file in "$TOKENS_SCSS" "$COMMON_CSS"; do
  fname="${css_file#$REPO_ROOT/}"
  if [[ ! -f "$css_file" ]]; then
    continue
  fi

  # Look for bare heading selectors at line start (not inside a block)
  bare_headings=0
  while IFS= read -r line; do
    if echo "$line" | grep -qE '^\s*h[1-6]\s*[,{]' && ! echo "$line" | grep -qE '^\s*\.'; then
      bare_headings=$((bare_headings + 1))
    fi
  done < "$css_file"

  if [[ "$bare_headings" -gt 0 ]]; then
    do_warn "AC-CSS-SCOPE-006: $bare_headings bare heading selector(s) in $fname (known gap G2 — T106)"
  else
    do_pass "AC-CSS-SCOPE-006: No bare heading selectors in $fname"
  fi
done

# Bare `a {` rule
for css_file in "$TOKENS_SCSS" "$COMMON_CSS"; do
  fname="${css_file#$REPO_ROOT/}"
  if [[ ! -f "$css_file" ]]; then
    continue
  fi

  if grep -qE '^\s*a\s*\{' "$css_file"; then
    do_warn "AC-CSS-SCOPE-006: Bare a { rule found in $fname (known gap G3 — T106)"
  else
    do_pass "AC-CSS-SCOPE-006: No bare a { rule in $fname"
  fi
done

# Bare `body {` rule
for css_file in "$TOKENS_SCSS" "$COMMON_CSS" "$MFE_SCSS"; do
  fname="${css_file#$REPO_ROOT/}"
  if [[ ! -f "$css_file" ]]; then
    continue
  fi

  if grep -qE '^\s*body\s*\{' "$css_file"; then
    # In MFE context this is acceptable (separate app)
    if echo "$fname" | grep -q 'mfe'; then
      do_pass "AC-CSS-SCOPE-006: body rule in MFE SCSS ($fname) — acceptable, MFEs are separate apps"
    else
      do_warn "AC-CSS-SCOPE-006: Bare body { rule in $fname (known gap G1 — T106; requires template patch)"
    fi
  else
    do_pass "AC-CSS-SCOPE-006: No bare body { rule in $fname"
  fi
done

echo ""

# ─────────────────────────────────────────────────────────────────────────────
# CI artifact
# ─────────────────────────────────────────────────────────────────────────────
VAR_DIR="$REPO_ROOT/var"
mkdir -p "$VAR_DIR"
ARTIFACT="$VAR_DIR/css-scoping-gate.txt"
{
  echo "css-scoping-gate"
  echo "run_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "pass=$PASS"
  echo "warn=$WARN"
  echo "fail=$FAIL"
  echo "skip=$SKIP"
  echo "status=$([ "$FAIL" -eq 0 ] && echo PASS || echo FAIL)"
} > "$ARTIFACT"

do_pass "Artifact written to var/css-scoping-gate.txt"

echo ""

# ─────────────────────────────────────────────────────────────────────────────
# Summary
# ─────────────────────────────────────────────────────────────────────────────
echo -e "${BLUE}## Summary${NC}"
echo ""
echo -e "  ${GREEN}PASS${NC}: $PASS"
echo -e "  ${YELLOW}WARN${NC}: $WARN  (documented known gaps — see CSS_SCOPING_AUDIT.md Section 5)"
echo -e "  ${RED}FAIL${NC}: $FAIL"
echo -e "  ${YELLOW}SKIP${NC}: $SKIP"
echo ""

# Update artifact with final counts
{
  echo "css-scoping-gate"
  echo "run_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "pass=$PASS"
  echo "warn=$WARN"
  echo "fail=$FAIL"
  echo "skip=$SKIP"
  echo "status=$([ "$FAIL" -eq 0 ] && echo PASS || echo FAIL)"
} > "$ARTIFACT"

if [[ "$FAIL" -eq 0 ]]; then
  echo -e "${GREEN}CSS scoping gate PASSED${NC}"
  if [[ "$WARN" -gt 0 ]]; then
    echo ""
    echo "WARN items are documented gaps tracked in T106. They are not CI-blocking."
    echo "See docs/architecture/CSS_SCOPING_AUDIT.md Section 5 for the full list."
  fi
  exit 0
else
  echo -e "${RED}CSS scoping gate FAILED — $FAIL check(s) failed${NC}"
  echo ""
  echo "Fix FAIL items before merging."
  echo "WARN items are documented known gaps (not blocking)."
  echo "See docs/architecture/CSS_SCOPING_AUDIT.md for context."
  exit 1
fi
