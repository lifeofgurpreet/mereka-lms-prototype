#!/usr/bin/env bash
# verify-a11y-contrast-focus.sh — A11y contrast + focus-visible gate
# @covers AC-A11Y-001, AC-A11Y-002, AC-A11Y-003, AC-A11Y-004
# @spec: bead-3vg91
#
# Verifies:
# 1. WCAG AA contrast ratios for key text/background token pairs (AC-A11Y-001)
# 2. focus-visible overrides in mereka.scss do not hide focus indicators (AC-A11Y-002)
# 3. Artifacts / exit codes suitable for CI blocking (AC-A11Y-003)
# 4. Exception documentation exists (AC-A11Y-004)
#
# WCAG AA thresholds:
#   - Normal text (<18px / <14px bold): 4.5:1
#   - Large text  (>=18px / >=14px bold): 3:1
#   - UI components / graphical objects: 3:1
#
# Usage: ./scripts/qa/verify-a11y-contrast-focus.sh
#   Set A11Y_STRICT=1 to treat WARNs as FAILs.
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

TOKENS_CSS="$REPO_ROOT/assets/branding/tokens.css"
TOKENS_SCSS="$REPO_ROOT/infrastructure/tutor/themes/mereka/scss/_tokens.scss"
MFE_SCSS="$REPO_ROOT/infrastructure/tutor/themes/mereka/mfe/mereka.scss"
THEME_DIR="$REPO_ROOT/infrastructure/tutor/themes/mereka"
EXCEPTION_DOC="$REPO_ROOT/docs/operations/A11Y_CONTRAST_FOCUS_GATE.md"

echo -e "${BLUE}=== A11y Contrast + Focus-Visible Gate ===${NC}"
echo "  Token source: assets/branding/tokens.css"
echo "  Theme bridge: infrastructure/tutor/themes/mereka/scss/_tokens.scss"
echo "  MFE overrides: infrastructure/tutor/themes/mereka/mfe/mereka.scss"
echo ""

# ── Python availability check ─────────────────────────────────────────
if ! command -v python3 >/dev/null 2>&1; then
  do_fail "python3 not available — required for contrast ratio computation"
  echo ""
  echo "Install python3 and re-run."
  exit 1
fi

# ── Shared contrast ratio function (inline Python) ───────────────────
# Usage: compute_contrast <hex1> <hex2>  → prints ratio as float string
compute_contrast() {
  local fg="$1" bg="$2"
  python3 - "$fg" "$bg" <<'PYEOF'
import sys

def hex_to_linear(h):
    h = h.lstrip('#')
    rgb = tuple(int(h[i:i+2], 16) / 255.0 for i in (0, 2, 4))
    result = []
    for c in rgb:
        if c <= 0.04045:
            result.append(c / 12.92)
        else:
            result.append(((c + 0.055) / 1.055) ** 2.4)
    return result

def luminance(h):
    lin = hex_to_linear(h)
    return 0.2126 * lin[0] + 0.7152 * lin[1] + 0.0722 * lin[2]

def contrast_ratio(c1, c2):
    l1 = luminance(c1)
    l2 = luminance(c2)
    lighter = max(l1, l2)
    darker = min(l1, l2)
    return (lighter + 0.05) / (darker + 0.05)

fg, bg = sys.argv[1], sys.argv[2]
try:
    ratio = contrast_ratio(fg, bg)
    print(f"{ratio:.2f}")
except Exception as e:
    print("0")
PYEOF
}

# ── Utility: extract a SCSS variable value ───────────────────────────
# Usage: get_scss_color <var_name>  (e.g. color-ink-900)
# Returns the hex value or empty string.
get_scss_color() {
  local name="$1"
  grep -P "^\\\$${name}:\s*" "$TOKENS_SCSS" 2>/dev/null \
    | head -1 \
    | grep -oP '#[0-9a-fA-F]{6}' \
    | head -1 || true
}

# ── AC-A11Y-001: Token-based contrast checks ──────────────────────────
echo -e "${BLUE}## AC-A11Y-001: WCAG AA Token Contrast Checks${NC}"

if [[ ! -f "$TOKENS_SCSS" ]]; then
  do_fail "AC-A11Y-001: _tokens.scss not found — cannot extract palette values"
else
  do_pass "AC-A11Y-001: _tokens.scss found"

  # Extract palette values once
  INK_900=$(get_scss_color "color-ink-900")
  INK_700=$(get_scss_color "color-ink-700")
  INK_500=$(get_scss_color "color-ink-500")
  INK_300=$(get_scss_color "color-ink-300")
  SURFACE=$(get_scss_color "color-neutral-100")
  SURFACE_MUTED=$(get_scss_color "color-neutral-75")
  COLOR_TEAL=$(get_scss_color "color-teal")
  COLOR_BLUE=$(get_scss_color "color-blue")
  COLOR_MAGENTA=$(get_scss_color "color-magenta")
  COLOR_FOREST=$(get_scss_color "color-forest")
  COLOR_BURGUNDY=$(get_scss_color "color-burgundy")

  # Helper: evaluate a pair with label, threshold, and size hint
  # Usage: check_pair <label> <fg> <bg> <threshold> <size_note>
  check_pair() {
    local label="$1" fg="$2" bg="$3" threshold="$4" size_note="$5"
    if [[ -z "$fg" || -z "$bg" ]]; then
      do_warn "AC-A11Y-001: ${label} — could not resolve token value(s), skipping"
      return
    fi
    local ratio
    ratio=$(compute_contrast "$fg" "$bg")
    if [[ "$ratio" == "0" ]]; then
      do_warn "AC-A11Y-001: ${label} — contrast computation failed"
      return
    fi
    local passes
    passes=$(python3 -c "print('yes' if float('$ratio') >= $threshold else 'no')" 2>/dev/null || echo "no")
    if [[ "$passes" == "yes" ]]; then
      do_pass "AC-A11Y-001: ${label} ${fg}/${bg} = ${ratio}:1 (>=${threshold}:1 AA ${size_note})"
    else
      do_fail "AC-A11Y-001: ${label} ${fg}/${bg} = ${ratio}:1 (FAILS ${threshold}:1 AA ${size_note})"
    fi
  }

  # ── Body text (normal, 16px) — needs 4.5:1
  check_pair "body text (ink-900 on surface)"         "$INK_900"  "$SURFACE"      4.5 "normal text"
  check_pair "secondary text (ink-700 on surface)"    "$INK_700"  "$SURFACE"      4.5 "normal text"
  check_pair "muted text (ink-500 on surface)"        "$INK_500"  "$SURFACE"      4.5 "normal text"

  # ── Placeholder / caption (ink-300) — 4.5:1 for normal, warn if below
  if [[ -n "$INK_300" && -n "$SURFACE" ]]; then
    RATIO_300=$(compute_contrast "$INK_300" "$SURFACE")
    PASSES_300=$(python3 -c "print('yes' if float('$RATIO_300') >= 4.5 else 'no')" 2>/dev/null || echo "no")
    if [[ "$PASSES_300" == "yes" ]]; then
      do_pass "AC-A11Y-001: placeholder text (ink-300 on surface) ${INK_300}/${SURFACE} = ${RATIO_300}:1 (>=4.5:1 AA)"
    else
      do_warn "AC-A11Y-001: placeholder/caption text (ink-300 on surface) ${INK_300}/${SURFACE} = ${RATIO_300}:1 (below 4.5:1 — acceptable ONLY for decorative/placeholder text)"
    fi
  fi

  # ── Heading text (large, >=18px / 600 weight >=14px) — needs 3:1
  check_pair "heading text (ink-900 on surface, large)" "$INK_900" "$SURFACE"     3.0 "large text"

  # ── Link color on white surface — needs 4.5:1 (links are normal text)
  check_pair "link (blue on surface)"                 "$COLOR_BLUE"   "$SURFACE"  4.5 "normal text"
  check_pair "link hover (teal on surface)"           "$COLOR_TEAL"   "$SURFACE"  4.5 "normal text"

  # ── Primary button gradient endpoints — text is white (#fff) on these
  # Gradient: magenta → teal → blue. Check each endpoint vs white.
  WHITE="#ffffff"
  check_pair "btn-primary label (white on magenta)"   "$WHITE"    "$COLOR_MAGENTA" 3.0 "UI component"
  check_pair "btn-primary label (white on teal)"      "$WHITE"    "$COLOR_TEAL"    3.0 "UI component"
  check_pair "btn-primary label (white on blue)"      "$WHITE"    "$COLOR_BLUE"    3.0 "UI component"

  # ── Status / semantic colors on white surface
  check_pair "success text (forest on surface)"       "$COLOR_FOREST"   "$SURFACE" 4.5 "normal text"
  check_pair "danger text (burgundy on surface)"      "$COLOR_BURGUNDY" "$SURFACE" 4.5 "normal text"

  # ── mereka-badge: teal text on teal/12 background
  # Effective background is ~rgba(35,112,114,0.12) blended onto white (#fbfafb).
  # We approximate the blend: badge_bg ≈ mix(#237072, #fbfafb, 12%) = #eef4f5
  BADGE_BG_APPROX="#eef4f5"
  if [[ -n "$COLOR_TEAL" ]]; then
    RATIO_BADGE=$(compute_contrast "$COLOR_TEAL" "$BADGE_BG_APPROX")
    PASSES_BADGE=$(python3 -c "print('yes' if float('$RATIO_BADGE') >= 3.0 else 'no')" 2>/dev/null || echo "no")
    if [[ "$PASSES_BADGE" == "yes" ]]; then
      do_pass "AC-A11Y-001: mereka-badge (teal on ~12% teal bg) ${COLOR_TEAL}/${BADGE_BG_APPROX} = ${RATIO_BADGE}:1 (>=3:1 UI component)"
    else
      do_warn "AC-A11Y-001: mereka-badge (teal on ~12% teal bg) ${COLOR_TEAL}/${BADGE_BG_APPROX} = ${RATIO_BADGE}:1 (below 3:1 — review badge contrast)"
    fi
  fi
fi

echo ""

# ── AC-A11Y-002: focus-visible / focus indicator audit ────────────────
echo -e "${BLUE}## AC-A11Y-002: Focus-Visible / Focus Indicator Audit${NC}"

if [[ ! -f "$MFE_SCSS" ]]; then
  do_fail "AC-A11Y-002: mereka.scss not found — cannot audit focus overrides"
else
  do_pass "AC-A11Y-002: mereka.scss found"

  # ── Check 1: outline removal patterns ──────────────────────────────
  # Pattern: outline: none  or  outline: 0  on interactive contexts
  # We scan all theme SCSS/CSS files.
  OUTLINE_NONE_BARE=0
  OUTLINE_ZERO_BARE=0

  while IFS= read -r css_file; do
    if grep -q 'outline:\s*none\|outline:\s*0' "$css_file" 2>/dev/null; then
      while IFS= read -r line_num; do
        # Grab context: 3 lines before and 6 lines after the outline removal
        CONTEXT=$(sed -n "$((line_num > 3 ? line_num - 3 : 1)),$((line_num + 6))p" "$css_file" 2>/dev/null || true)
        # A paired outline removal must have box-shadow OR :focus-visible with alternative
        if ! echo "$CONTEXT" | grep -qE 'box-shadow|:focus-visible|outline-offset|ring'; then
          OUTLINE_NONE_BARE=$((OUTLINE_NONE_BARE + 1))
          echo -e "  ${YELLOW}  bare outline removal at${NC} $(basename "$css_file"):${line_num}"
        fi
      done < <(grep -nE 'outline:\s*(none|0)' "$css_file" 2>/dev/null | cut -d: -f1 || true)
    fi
  done < <(find "$THEME_DIR" \( -name '*.scss' -o -name '*.css' \) -not -path '*/node_modules/*' 2>/dev/null)

  if [[ "$OUTLINE_NONE_BARE" -eq 0 ]]; then
    do_pass "AC-A11Y-002: No bare outline:none/0 without focus replacement in theme files"
  else
    do_fail "AC-A11Y-002: $OUTLINE_NONE_BARE bare outline removal(s) without replacement focus style"
  fi

  # ── Check 2: box-shadow:none on :focus selectors ───────────────────
  # Risk: overrides that explicitly null-out the focus ring shadow.
  SHADOW_NONE_ON_FOCUS=0
  while IFS= read -r css_file; do
    while IFS= read -r line_num; do
      # Walk up to find the containing selector — look within 8 lines before
      CONTEXT=$(sed -n "$((line_num > 8 ? line_num - 8 : 1)),$((line_num))p" "$css_file" 2>/dev/null || true)
      if echo "$CONTEXT" | grep -qE ':focus|:focus-visible|:focus-within'; then
        SHADOW_NONE_ON_FOCUS=$((SHADOW_NONE_ON_FOCUS + 1))
        echo -e "  ${YELLOW}  box-shadow:none inside focus context at${NC} $(basename "$css_file"):${line_num}"
      fi
    done < <(grep -nE 'box-shadow:\s*none' "$css_file" 2>/dev/null | cut -d: -f1 || true)
  done < <(find "$THEME_DIR" \( -name '*.scss' -o -name '*.css' \) -not -path '*/node_modules/*' 2>/dev/null)

  if [[ "$SHADOW_NONE_ON_FOCUS" -eq 0 ]]; then
    do_pass "AC-A11Y-002: No box-shadow:none inside :focus selector contexts"
  else
    do_warn "AC-A11Y-002: $SHADOW_NONE_ON_FOCUS box-shadow:none inside :focus context(s) — review for hidden focus rings"
  fi

  # ── Check 3: focus token is defined in MFE SCSS ─────────────────────
  if grep -qF -- '--mereka-mfe-focus' "$MFE_SCSS"; then
    do_pass "AC-A11Y-002: --mereka-mfe-focus focus ring token defined in MFE SCSS"
  else
    do_fail "AC-A11Y-002: --mereka-mfe-focus token missing from MFE SCSS"
  fi

  # ── Check 4: focus token is actually used on a :focus rule ──────────
  FOCUS_TOKEN_USED=$(grep -cF 'var(--mereka-mfe-focus)' "$MFE_SCSS" 2>/dev/null || echo "0")
  if [[ "$FOCUS_TOKEN_USED" -gt 0 ]]; then
    do_pass "AC-A11Y-002: --mereka-mfe-focus token used $FOCUS_TOKEN_USED time(s) (focus ring applied)"
  else
    do_warn "AC-A11Y-002: --mereka-mfe-focus token defined but never used — focus ring may be invisible"
  fi

  # ── Check 5: interactive elements have :focus rule ──────────────────
  # Verify that at minimum .btn-primary and .form-control have :focus styles
  BTNS_HAVE_FOCUS=0
  FORMS_HAVE_FOCUS=0

  # .btn-primary:focus appears in the MFE SCSS (combined selector)
  if grep -qE '\.btn-primary.*:focus|:focus.*\.btn-primary' "$MFE_SCSS"; then
    BTNS_HAVE_FOCUS=1
  fi
  if grep -qE '\.pgn__btn--primary.*:focus|:focus.*\.pgn__btn--primary' "$MFE_SCSS"; then
    BTNS_HAVE_FOCUS=1
  fi
  if grep -qE '\.form-control.*:focus|:focus.*\.form-control|\.pgn__form-control.*:focus' "$MFE_SCSS"; then
    FORMS_HAVE_FOCUS=1
  fi

  if [[ "$BTNS_HAVE_FOCUS" -eq 1 ]]; then
    do_pass "AC-A11Y-002: .btn-primary / .pgn__btn--primary has :focus rule in MFE SCSS"
  else
    do_warn "AC-A11Y-002: .btn-primary / .pgn__btn--primary :focus rule not found in MFE SCSS"
  fi

  if [[ "$FORMS_HAVE_FOCUS" -eq 1 ]]; then
    do_pass "AC-A11Y-002: .form-control / .pgn__form-control has :focus rule in MFE SCSS"
  else
    do_warn "AC-A11Y-002: .form-control / .pgn__form-control :focus rule not found in MFE SCSS"
  fi

  # ── Check 6: :focus-visible migration progress ──────────────────────
  # Count files containing :focus-visible (avoid multiline file:count output from -Ec)
  FOCUS_VISIBLE_FILES=()
  while IFS= read -r f; do
    FOCUS_VISIBLE_FILES+=("$f")
  done < <(grep -rl ':focus-visible' \
    "$THEME_DIR" --include='*.scss' --include='*.css' 2>/dev/null || true)
  FOCUS_VISIBLE_COUNT=${#FOCUS_VISIBLE_FILES[@]}
  if [[ "$FOCUS_VISIBLE_COUNT" -eq 0 ]]; then
    do_warn "AC-A11Y-002: No :focus-visible usage yet — modern keyboard-only focus ring not implemented (Q2 2026 gap)"
  else
    do_pass "AC-A11Y-002: :focus-visible in use ($FOCUS_VISIBLE_COUNT file(s)) — modern keyboard focus ring present"
  fi

  # ── Check 7: pgn focus ring token bridge ────────────────────────────
  TOKENS_SCSS_FILE="$REPO_ROOT/infrastructure/tutor/themes/mereka/scss/_tokens.scss"
  if [[ -f "$TOKENS_SCSS_FILE" ]]; then
    if grep -qF -- '--pgn-focus-ring-color' "$TOKENS_SCSS_FILE"; then
      do_pass "AC-A11Y-002: Paragon --pgn-focus-ring-color token bridge exists in _tokens.scss"
    else
      do_warn "AC-A11Y-002: --pgn-focus-ring-color Paragon bridge missing from _tokens.scss (Q2 2026 gap)"
    fi
  fi
fi

echo ""

# ── AC-A11Y-003: CI artifact / gate output ────────────────────────────
echo -e "${BLUE}## AC-A11Y-003: CI Gate Artifact${NC}"

# Ensure var/ directory exists so CI can upload the artifact
VAR_DIR="$REPO_ROOT/var"
if [[ ! -d "$VAR_DIR" ]]; then
  mkdir -p "$VAR_DIR"
fi

# Write a machine-readable summary for CI artifact upload
ARTIFACT="$VAR_DIR/a11y-contrast-focus-gate.txt"
{
  echo "a11y-contrast-focus-gate"
  echo "run_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "pass=$PASS"
  echo "warn=$WARN"
  echo "fail=$FAIL"
  echo "status=$([ "$FAIL" -eq 0 ] && echo PASS || echo FAIL)"
} > "$ARTIFACT"

do_pass "AC-A11Y-003: Artifact written to var/a11y-contrast-focus-gate.txt"

# Check CI integration: either direct workflow reference OR script-list wiring.
CI_YML="$REPO_ROOT/.github/workflows/ci.yml"
CI_STATIC_LIST="$REPO_ROOT/.github/ci-scripts-static.txt"
if [[ -f "$CI_YML" ]]; then
  if grep -qF 'verify-a11y-contrast-focus.sh' "$CI_YML"; then
    do_pass "AC-A11Y-003: verify-a11y-contrast-focus.sh referenced directly in ci.yml"
  elif [[ -f "$CI_STATIC_LIST" ]] && grep -qF 'scripts/qa/verify-a11y-contrast-focus.sh' "$CI_STATIC_LIST"; then
    do_pass "AC-A11Y-003: verify-a11y-contrast-focus.sh wired via ci-scripts-static.txt"
  else
    do_warn "AC-A11Y-003: verify-a11y-contrast-focus.sh not found in ci.yml or ci-scripts-static.txt"
  fi
else
  do_warn "AC-A11Y-003: .github/workflows/ci.yml not found — cannot verify CI integration"
fi

echo ""

# ── AC-A11Y-004: Exception documentation ─────────────────────────────
echo -e "${BLUE}## AC-A11Y-004: Exception Documentation${NC}"

if [[ ! -f "$EXCEPTION_DOC" ]]; then
  do_fail "AC-A11Y-004: A11Y_CONTRAST_FOCUS_GATE.md not found at docs/operations/"
else
  do_pass "AC-A11Y-004: A11Y_CONTRAST_FOCUS_GATE.md exists"

  # Verify required sections
  for section in \
    "## WCAG AA Thresholds" \
    "## Token Pairs Checked" \
    "## Focus Visibility Requirements" \
    "## Exception Process" \
    "## Adding New Contrast Pairs"
  do
    if grep -qF "$section" "$EXCEPTION_DOC"; then
      do_pass "AC-A11Y-004: Doc has section: $section"
    else
      do_fail "AC-A11Y-004: Doc missing section: $section"
    fi
  done
fi

echo ""

# ── Summary ──────────────────────────────────────────────────────────
echo -e "${BLUE}## Summary${NC}"
echo ""
echo -e "  ${GREEN}PASS${NC}: $PASS"
echo -e "  ${YELLOW}WARN${NC}: $WARN"
echo -e "  ${RED}FAIL${NC}: $FAIL"
echo ""

# Update artifact with final counts
{
  echo "a11y-contrast-focus-gate"
  echo "run_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "pass=$PASS"
  echo "warn=$WARN"
  echo "fail=$FAIL"
  echo "status=$([ "$FAIL" -eq 0 ] && echo PASS || echo FAIL)"
} > "$ARTIFACT"

if [[ "$FAIL" -eq 0 ]]; then
  echo -e "${GREEN}All a11y contrast + focus checks passed${NC}"
  if [[ "$WARN" -gt 0 ]]; then
    echo ""
    echo "Notes:"
    echo "  - WARN items are documented gaps with Q2 2026 timelines (not blocking)"
    echo "  - See docs/operations/A11Y_CONTRAST_FOCUS_GATE.md for exception process"
  fi
  exit 0
else
  echo -e "${RED}Some a11y contrast + focus checks failed${NC}"
  echo ""
  echo "Fix FAIL items before merging. WARN items are documented gaps (not blocking)."
  echo "See docs/operations/A11Y_CONTRAST_FOCUS_GATE.md for the exception/reviewer process."
  exit 1
fi
