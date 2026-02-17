#!/usr/bin/env bash
# verify-contrast-compliance.sh — WCAG 2.1 AA contrast ratio verification
#
# Checks all Mereka theme text/background color pairs against WCAG AA thresholds:
#   - Normal text: 4.5:1 minimum
#   - Large text (18px+ or 14px+ bold): 3:1 minimum
#   - UI components & graphical objects: 3:1 minimum
#
# Usage: ./scripts/qa/verify-contrast-compliance.sh
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
TOKENS="$REPO_ROOT/infrastructure/tutor/themes/mereka/scss/_tokens.scss"

PASS=0
FAIL=0
WARN=0

do_pass() { PASS=$((PASS + 1)); echo "  PASS  $1"; }
do_fail() { FAIL=$((FAIL + 1)); echo "  FAIL  $1"; }
do_warn() { WARN=$((WARN + 1)); echo "  WARN  $1"; }

echo "=== WCAG 2.1 AA Contrast Compliance Check ==="
echo ""

# 1. Verify token file exists
echo "--- Source verification ---"
if [ ! -f "$TOKENS" ]; then
  do_fail "_tokens.scss not found"
  echo ""
  echo "=== Results: $PASS PASS / $FAIL FAIL / $WARN WARN ==="
  exit 1
fi
do_pass "_tokens.scss exists"

# 2. Extract color definitions
echo ""
echo "--- Extracting color tokens ---"

# Parse SCSS variables from _tokens.scss
get_color() {
  local name="$1"
  grep -oP '(?<=\$'"$name"': )#[0-9a-fA-F]{6}' "$TOKENS" | head -1
}

INK_900=$(get_color "color-ink-900")
INK_700=$(get_color "color-ink-700")
INK_500=$(get_color "color-ink-500")
INK_300=$(get_color "color-ink-300")
NEUTRAL_100=$(get_color "color-neutral-100")
NEUTRAL_75=$(get_color "color-neutral-75")
TEAL=$(get_color "color-teal")
MAGENTA=$(get_color "color-magenta")
BLUE=$(get_color "color-blue")
WHITE="#FFFFFF"
FOREST=$(get_color "color-forest")
BURGUNDY=$(get_color "color-burgundy")
GOLD=$(get_color "color-gold")
SKY=$(get_color "color-sky")
PINK=$(get_color "color-pink")

echo "  ink-900=$INK_900 ink-700=$INK_700 ink-500=$INK_500 ink-300=$INK_300"
echo "  neutral-100=$NEUTRAL_100 neutral-75=$NEUTRAL_75"
echo "  teal=$TEAL magenta=$MAGENTA blue=$BLUE"
echo "  forest=$FOREST burgundy=$BURGUNDY gold=$GOLD sky=$SKY pink=$PINK"

# 3. WCAG contrast ratio calculator (Python)
echo ""
echo "--- Contrast ratio checks ---"

check_contrast() {
  local fg="$1"
  local bg="$2"
  local context="$3"
  local threshold="$4"  # 4.5 or 3.0
  local text_type="$5"  # "normal" or "large"

  [ -z "$fg" ] || [ -z "$bg" ] && { do_fail "$context: missing color value"; return; }

  local result
  result=$(python3 -c "
import sys

def hex_to_linear(h):
    h = h.lstrip('#')
    r, g, b = int(h[0:2], 16)/255, int(h[2:4], 16)/255, int(h[4:6], 16)/255
    def lin(c):
        return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4
    return lin(r), lin(g), lin(b)

def luminance(h):
    r, g, b = hex_to_linear(h)
    return 0.2126 * r + 0.7152 * g + 0.0722 * b

fg, bg = '$fg', '$bg'
l1 = luminance(fg)
l2 = luminance(bg)
if l1 < l2:
    l1, l2 = l2, l1
ratio = (l1 + 0.05) / (l2 + 0.05)
threshold = $threshold
status = 'PASS' if ratio >= threshold else 'FAIL'
print(f'{ratio:.1f}:{status}')
" 2>/dev/null)

  local ratio="${result%%:*}"
  local status="${result##*:}"

  if [ "$status" = "PASS" ]; then
    do_pass "$context — ${ratio}:1 (>= ${threshold}:1 for $text_type text)"
  else
    do_fail "$context — ${ratio}:1 (FAILS ${threshold}:1 for $text_type text)"
  fi
}

# ── Body text on backgrounds ──
echo ""
echo "--- Body text (normal text, 4.5:1 threshold) ---"
check_contrast "$INK_900" "$NEUTRAL_100" "ink-900 on neutral-100 (body text)" "4.5" "normal"
check_contrast "$INK_900" "$WHITE" "ink-900 on white (card text)" "4.5" "normal"
check_contrast "$INK_900" "$NEUTRAL_75" "ink-900 on neutral-75 (alt surface)" "4.5" "normal"

# ── Secondary text (ink-700, ink-500) ──
echo ""
echo "--- Secondary text (normal text, 4.5:1 threshold) ---"
check_contrast "$INK_700" "$WHITE" "ink-700 on white (footer links)" "4.5" "normal"
check_contrast "$INK_700" "$NEUTRAL_100" "ink-700 on neutral-100" "4.5" "normal"
check_contrast "$INK_500" "$WHITE" "ink-500 on white (course-code, footer copy)" "4.5" "normal"
check_contrast "$INK_500" "$NEUTRAL_100" "ink-500 on neutral-100 (secondary text)" "4.5" "normal"

# ── Tertiary text (ink-300) ──
echo ""
echo "--- Tertiary text (large text, 3:1 threshold) ---"
check_contrast "$INK_300" "$WHITE" "ink-300 on white (placeholder text)" "3.0" "large"
check_contrast "$INK_300" "$NEUTRAL_100" "ink-300 on neutral-100" "3.0" "large"

# ── Links ──
echo ""
echo "--- Link text (normal text, 4.5:1 threshold) ---"
check_contrast "$BLUE" "$WHITE" "blue on white (links)" "4.5" "normal"
check_contrast "$BLUE" "$NEUTRAL_100" "blue on neutral-100 (links)" "4.5" "normal"
check_contrast "$TEAL" "$WHITE" "teal on white (link hover)" "4.5" "normal"
check_contrast "$TEAL" "$NEUTRAL_100" "teal on neutral-100 (link hover)" "4.5" "normal"

# ── Buttons (large text — bold, typically 14px+) ──
echo ""
echo "--- Button text (large/bold text, 3:1 threshold) ---"
check_contrast "$WHITE" "$MAGENTA" "white on magenta (primary btn)" "3.0" "large"
check_contrast "$WHITE" "$TEAL" "white on teal (secondary btn)" "3.0" "large"
check_contrast "$WHITE" "$BLUE" "white on blue (info btn)" "3.0" "large"

# ── Semantic colors on white backgrounds ──
echo ""
echo "--- Semantic colors (text use, 4.5:1 threshold) ---"
check_contrast "$FOREST" "$WHITE" "forest on white (success text)" "4.5" "normal"
check_contrast "$BURGUNDY" "$WHITE" "burgundy on white (danger text)" "4.5" "normal"

# ── Soft semantic colors — background-only (text on them, not as text) ──
echo ""
echo "--- Soft semantic backgrounds (dark text on soft bg, 4.5:1 threshold) ---"
check_contrast "$INK_900" "$GOLD" "ink-900 on gold (warning badge text)" "4.5" "normal"
check_contrast "$INK_900" "$SKY" "ink-900 on sky (info-soft badge text)" "4.5" "normal"
check_contrast "$INK_900" "$PINK" "ink-900 on pink (danger-soft badge text)" "4.5" "normal"

# ── UI component borders (3:1 threshold) ──
echo ""
echo "--- UI component contrast (3:1 threshold) ---"
check_contrast "$TEAL" "$WHITE" "teal on white (focus ring)" "3.0" "large"
check_contrast "$MAGENTA" "$WHITE" "magenta on white (primary indicator)" "3.0" "large"

# ── Footer-specific checks ──
echo ""
echo "--- Footer contrast ---"
check_contrast "$INK_500" "$WHITE" "ink-500 on white (footer h6 headings)" "4.5" "normal"
check_contrast "$INK_700" "$WHITE" "ink-700 on white (footer links)" "4.5" "normal"
check_contrast "$INK_500" "$WHITE" "ink-500 on white (footer-bottom copy)" "4.5" "normal"

echo ""
echo "=== Results: $PASS PASS / $FAIL FAIL / $WARN WARN ==="

if [ "$FAIL" -gt 0 ]; then
  echo ""
  echo "NOTE: WCAG AA failures indicate color pairs that may be inaccessible to"
  echo "users with low vision. Review and adjust in _tokens.scss or theme.scss."
  echo "Decorative/non-text use of these colors is exempt."
fi

[ "$FAIL" -eq 0 ] && exit 0 || exit 1
