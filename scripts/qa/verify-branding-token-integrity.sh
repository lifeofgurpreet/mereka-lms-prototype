#!/usr/bin/env bash
# @covers AC-TOK-001, AC-TOK-002, AC-TOK-003, AC-TOK-004, AC-TOK-005
# @spec: ui-ux-hardening-s6_spec.md
# Verify branding token integrity: canonical source cross-check + contrast gate.
#
# Validates:
# 1. All --mereka-* token references resolve to canonical definitions
# 2. No undefined token gaps (ink-600 check)
# 3. CI-ready PASS/FAIL with file:line for first missing token
# 4. Body-text contrast quick-check (AA floor: 4.5:1 for normal text)
# 5. References DR1 gap findings

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

CANONICAL="$REPO_ROOT/assets/branding/tokens.css"
TOKENS_SCSS="$REPO_ROOT/infrastructure/tutor/themes/mereka/scss/_tokens.scss"
THEME_DIR="$REPO_ROOT/infrastructure/tutor/themes/mereka"

echo "=== Branding Token Integrity Verification ==="
echo "  Canonical source: assets/branding/tokens.css"
echo "  Theme bridge: infrastructure/tutor/themes/mereka/scss/_tokens.scss"
echo ""

# ── AC-TOK-001: Token references resolve ──────────────────────────────
echo "--- AC-TOK-001: Token reference resolution ---"

if [[ ! -f "$CANONICAL" ]]; then
  fail "AC-TOK-001: Canonical token file not found: assets/branding/tokens.css"
else
  # Extract canonical token names from tokens.css
  CANONICAL_TOKENS=$(grep -oP '(?<=  )--[a-z0-9_-]+(?=\s*:)' "$CANONICAL" | sort -u)
  CANONICAL_COUNT=$(echo "$CANONICAL_TOKENS" | wc -l)

  if [[ "$CANONICAL_COUNT" -ge 80 ]]; then
    pass "AC-TOK-001: Canonical source has $CANONICAL_COUNT token definitions (>=80)"
  else
    fail "AC-TOK-001: Canonical source only has $CANONICAL_COUNT tokens (expected >=80)"
  fi
fi

if [[ ! -f "$TOKENS_SCSS" ]]; then
  fail "AC-TOK-001: Token bridge not found: _tokens.scss"
else
  # Extract --mereka-* definitions from _tokens.scss
  BRIDGE_TOKENS=$(grep -oP '(?<=  )--mereka-[a-z0-9_-]+(?=:)' "$TOKENS_SCSS" | sort -u)
  BRIDGE_COUNT=$(echo "$BRIDGE_TOKENS" | wc -l)

  if [[ "$BRIDGE_COUNT" -ge 15 ]]; then
    pass "AC-TOK-001: Token bridge has $BRIDGE_COUNT --mereka-* definitions (>=15)"
  else
    fail "AC-TOK-001: Token bridge only has $BRIDGE_COUNT --mereka-* definitions (expected >=15)"
  fi

  # Check all --mereka-* references in theme files resolve to definitions
  UNDEFINED=0
  CHECKED=0
  FIRST_UNDEFINED=""

  while IFS= read -r file; do
    while IFS= read -r line; do
      token=$(echo "$line" | grep -oP '(?<=var\()--mereka-[a-z0-9_-]+' | head -1)
      [[ -z "$token" ]] && continue
      CHECKED=$((CHECKED + 1))

      # Check if defined in _tokens.scss or any overrides CSS
      if ! grep -q "^[[:space:]]*${token}:" "$TOKENS_SCSS" 2>/dev/null; then
        # Check runtime overrides
        found=0
        for override in "$THEME_DIR"/*/static/css/mereka-overrides.css; do
          if [[ -f "$override" ]] && grep -q "^[[:space:]]*${token}:" "$override" 2>/dev/null; then
            found=1
            break
          fi
        done
        # Check if defined in same file
        if [[ "$found" -eq 0 ]] && grep -q "^[[:space:]]*${token}:" "$file" 2>/dev/null; then
          found=1
        fi
        if [[ "$found" -eq 0 ]]; then
          UNDEFINED=$((UNDEFINED + 1))
          if [[ -z "$FIRST_UNDEFINED" ]]; then
            line_num=$(grep -n "var(${token}" "$file" | head -1 | cut -d: -f1)
            FIRST_UNDEFINED="$token in $(basename "$file"):${line_num:-?}"
          fi
        fi
      fi
    done < <(grep 'var(--mereka-' "$file" 2>/dev/null || true)
  done < <(find "$THEME_DIR" \( -name '*.scss' -o -name '*.css' \) -not -path '*/node_modules/*' 2>/dev/null)

  if [[ "$UNDEFINED" -eq 0 ]]; then
    pass "AC-TOK-001: All $CHECKED var(--mereka-*) references resolve"
  else
    fail "AC-TOK-001: $UNDEFINED undefined token(s) — first: $FIRST_UNDEFINED"
  fi
fi

# ── AC-TOK-002: ink-600 gap check ─────────────────────────────────────
echo ""
echo "--- AC-TOK-002: Undefined token gap (ink-600) ---"

INK600_REFS=$(grep -rl 'mereka-color-ink-600' "$THEME_DIR" 2>/dev/null || true)
if [[ -z "$INK600_REFS" ]]; then
  pass "AC-TOK-002: No references to --mereka-color-ink-600 (gap confirmed absent)"
else
  fail "AC-TOK-002: Found ink-600 references in: $INK600_REFS"
fi

# Check all defined ink tokens are used
for ink_level in 900 700 500 300; do
  if grep -rq "mereka-color-ink-${ink_level}" "$THEME_DIR" 2>/dev/null; then
    pass "AC-TOK-002: --mereka-color-ink-${ink_level} defined and referenced"
  else
    warn "AC-TOK-002: --mereka-color-ink-${ink_level} defined but not referenced"
  fi
done

# ── AC-TOK-003: CI gate output ────────────────────────────────────────
echo ""
echo "--- AC-TOK-003: CI gate summary ---"
# This script IS the CI gate. Report format for CI consumption.
if [[ "$FAIL" -eq 0 ]]; then
  pass "AC-TOK-003: Token integrity CI gate: PASS (no undefined tokens)"
else
  fail "AC-TOK-003: Token integrity CI gate: FAIL ($FAIL issue(s) found)"
  if [[ -n "${FIRST_UNDEFINED:-}" ]]; then
    echo "  First undefined: $FIRST_UNDEFINED"
  fi
fi

# ── AC-TOK-004: Body-text contrast quick-check ────────────────────────
echo ""
echo "--- AC-TOK-004: Body-text contrast (AA floor) ---"

# Extract hex values for critical pairs from _tokens.scss
# ink-900 on surface-primary is the primary body text pair
INK_900=$(grep 'color-ink-900:' "$TOKENS_SCSS" 2>/dev/null | head -1 | grep -oP '#[0-9a-fA-F]{6}' | head -1)
SURFACE_PRIMARY=$(grep 'color-neutral-100:' "$TOKENS_SCSS" 2>/dev/null | head -1 | grep -oP '#[0-9a-fA-F]{6}' | head -1)

if [[ -n "$INK_900" && -n "$SURFACE_PRIMARY" ]]; then
  # Calculate relative luminance and contrast ratio using Python
  CONTRAST=$(python3 -c "
import sys

def hex_to_rgb(h):
    h = h.lstrip('#')
    return tuple(int(h[i:i+2], 16) / 255.0 for i in (0, 2, 4))

def luminance(rgb):
    channels = []
    for c in rgb:
        if c <= 0.04045:
            channels.append(c / 12.92)
        else:
            channels.append(((c + 0.055) / 1.055) ** 2.4)
    return 0.2126 * channels[0] + 0.7152 * channels[1] + 0.0722 * channels[2]

def contrast_ratio(c1, c2):
    l1 = luminance(hex_to_rgb(c1))
    l2 = luminance(hex_to_rgb(c2))
    lighter = max(l1, l2)
    darker = min(l1, l2)
    return (lighter + 0.05) / (darker + 0.05)

fg = '$INK_900'
bg = '$SURFACE_PRIMARY'
ratio = contrast_ratio(fg, bg)
print(f'{ratio:.2f}')
" 2>/dev/null || echo "0")

  if [[ "$CONTRAST" != "0" ]]; then
    # WCAG AA requires 4.5:1 for normal text
    MEETS_AA=$(python3 -c "print('yes' if float('$CONTRAST') >= 4.5 else 'no')" 2>/dev/null || echo "no")
    if [[ "$MEETS_AA" == "yes" ]]; then
      pass "AC-TOK-004: ink-900 ($INK_900) on surface-primary ($SURFACE_PRIMARY) = ${CONTRAST}:1 (>=4.5:1 AA)"
    else
      fail "AC-TOK-004: ink-900 on surface-primary = ${CONTRAST}:1 (FAILS 4.5:1 AA threshold)"
    fi
  else
    warn "AC-TOK-004: Could not compute contrast ratio (Python3 required)"
  fi

  # Also check ink-700 on surface-primary (secondary text)
  INK_700=$(grep 'color-ink-700:' "$TOKENS_SCSS" 2>/dev/null | head -1 | grep -oP '#[0-9a-fA-F]{6}' | head -1)
  if [[ -n "$INK_700" ]]; then
    CONTRAST_700=$(python3 -c "
import sys
def hex_to_rgb(h):
    h = h.lstrip('#')
    return tuple(int(h[i:i+2], 16) / 255.0 for i in (0, 2, 4))
def luminance(rgb):
    channels = []
    for c in rgb:
        if c <= 0.04045:
            channels.append(c / 12.92)
        else:
            channels.append(((c + 0.055) / 1.055) ** 2.4)
    return 0.2126 * channels[0] + 0.7152 * channels[1] + 0.0722 * channels[2]
def contrast_ratio(c1, c2):
    l1 = luminance(hex_to_rgb(c1))
    l2 = luminance(hex_to_rgb(c2))
    lighter = max(l1, l2)
    darker = min(l1, l2)
    return (lighter + 0.05) / (darker + 0.05)
ratio = contrast_ratio('$INK_700', '$SURFACE_PRIMARY')
print(f'{ratio:.2f}')
" 2>/dev/null || echo "0")

    if [[ "$CONTRAST_700" != "0" ]]; then
      MEETS_AA_700=$(python3 -c "print('yes' if float('$CONTRAST_700') >= 4.5 else 'no')" 2>/dev/null || echo "no")
      if [[ "$MEETS_AA_700" == "yes" ]]; then
        pass "AC-TOK-004: ink-700 ($INK_700) on surface-primary ($SURFACE_PRIMARY) = ${CONTRAST_700}:1 (>=4.5:1 AA)"
      else
        warn "AC-TOK-004: ink-700 on surface-primary = ${CONTRAST_700}:1 (below 4.5:1 AA — acceptable for large text >=3:1)"
      fi
    fi
  fi
else
  warn "AC-TOK-004: Could not extract ink/surface values from _tokens.scss"
fi

# ── AC-TOK-005: Documentation reference ───────────────────────────────
echo ""
echo "--- AC-TOK-005: Documentation ---"

# Check for token-related docs
DOCS_FOUND=0
for doc in "$REPO_ROOT/docs/ops/runbooks/architecture/TOKEN_INTEGRITY_REMEDIATION.md" \
           "$REPO_ROOT/docs/reference/architecture/TOKEN_REFERENCE_INTEGRITY.md" \
           "$REPO_ROOT/docs/guides/branding/TOKEN_INTEGRITY.md"; do
  if [[ -f "$doc" ]]; then
    DOCS_FOUND=1
    pass "AC-TOK-005: Token integrity docs found: $(basename "$doc")"
    break
  fi
done

if [[ "$DOCS_FOUND" -eq 0 ]]; then
  warn "AC-TOK-005: No token integrity remediation doc found (will create)"
fi

# Summary
echo ""
echo "=== Summary ==="
echo -e "${GREEN}PASS:${NC} $PASS | ${RED}FAIL:${NC} $FAIL | ${YELLOW}WARN:${NC} $WARN"

if [[ "$FAIL" -gt 0 ]]; then
  echo ""
  echo "Remediation (DR1 gap reference):"
  echo "1. Define missing tokens in _tokens.scss :root block"
  echo "2. Mirror values in mereka-overrides.css for all targets (common, lms, cms)"
  echo "3. Verify contrast ratios meet WCAG AA (4.5:1 normal text, 3:1 large text)"
  echo "4. See docs/reference/architecture/TOKEN_REFERENCE_INTEGRITY.md for full inventory"
  exit 1
fi

exit 0
