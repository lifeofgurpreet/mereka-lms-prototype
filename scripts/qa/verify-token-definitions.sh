#!/usr/bin/env bash
# verify-token-definitions.sh — Verify all referenced CSS tokens are defined
#
# Checks that every var(--mereka-*) reference in theme SCSS/CSS files resolves
# to a definition somewhere in the token chain (tokens.css, _tokens.scss,
# mereka-overrides.css, or self-defined in the same file).
#
# Usage: ./scripts/qa/verify-token-definitions.sh
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
THEME_DIR="$REPO_ROOT/infrastructure/tutor/themes/mereka"
TOKENS_CSS="$REPO_ROOT/assets/branding/tokens.css"
COMMON_DESIGN_TOKENS="$THEME_DIR/common/static/css/mereka-design-tokens.css"
COMMON_OVERRIDES="$THEME_DIR/common/static/css/mereka-overrides.css"

PASS=0
FAIL=0
WARN=0

do_pass() { PASS=$((PASS + 1)); echo "  PASS  $1"; }
do_fail() { FAIL=$((FAIL + 1)); echo "  FAIL  $1"; }
do_warn() { WARN=$((WARN + 1)); echo "  WARN  $1"; }

echo "=== Token Definition Correctness Check ==="
echo ""

# 1. Collect all defined --mereka-* tokens from definition sources
echo "--- Collecting token definitions ---"
DEFINED_TOKENS=$(mktemp)

# From _tokens.scss (the main mereka token bridge)
grep -oP '(?<=  )--mereka-[a-z0-9_-]+(?=:)' "$THEME_DIR/scss/_tokens.scss" 2>/dev/null >> "$DEFINED_TOKENS" || true

# From mereka-overrides.css (runtime override definitions)
grep -oP '(?<=  )--mereka-[a-z0-9_-]+(?=:)' "$COMMON_OVERRIDES" 2>/dev/null >> "$DEFINED_TOKENS" || true

# From generated design tokens file (canonical runtime token source)
grep -oP '(?<=  )--mereka-[a-z0-9_-]+(?=:)' "$COMMON_DESIGN_TOKENS" 2>/dev/null >> "$DEFINED_TOKENS" || true

# From theme.scss (self-defined tokens like gradients, radii)
grep -oP '(?<=  )--mereka-[a-z0-9_-]+(?=:)' "$THEME_DIR/scss/theme.scss" 2>/dev/null >> "$DEFINED_TOKENS" || true

# From mfe/mereka.scss (self-defined MFE tokens)
grep -oP '(?<=  )--mereka-[a-z0-9_-]+(?=:)' "$THEME_DIR/mfe/mereka.scss" 2>/dev/null >> "$DEFINED_TOKENS" || true

# Sort and deduplicate
sort -u "$DEFINED_TOKENS" -o "$DEFINED_TOKENS"
DEF_COUNT=$(wc -l < "$DEFINED_TOKENS")
echo "  Found $DEF_COUNT unique --mereka-* token definitions"

# 2. Collect all referenced var(--mereka-*) tokens
echo ""
echo "--- Checking token references ---"
UNDEFINED_FOUND=0

# Search all SCSS and CSS files in theme directory
while IFS= read -r file; do
  while IFS= read -r token; do
    [ -z "$token" ] && continue

    if grep -qxF -- "$token" "$DEFINED_TOKENS"; then
      continue
    fi

    if grep -q -- "^[[:space:]]*${token}:" "$file" 2>/dev/null; then
      continue
    fi

    line_num="$(grep -n -m1 -F "var(${token}" "$file" 2>/dev/null | cut -d: -f1 || true)"
    line_num="${line_num:-?}"
    do_fail "Undefined token $token in $(basename "$file"):$line_num"
    UNDEFINED_FOUND=$((UNDEFINED_FOUND + 1))
  done < <(grep -oP 'var\(--mereka-[a-z0-9_-]+' "$file" 2>/dev/null | sed 's/^var(//' | sort -u)
done < <(find "$THEME_DIR" \
  \( -name '*.scss' -o -name '*.css' \) \
  -not -path '*/node_modules/*' \
  -not -path '*/mfe/theme/*' \
  2>/dev/null)

if [ "$UNDEFINED_FOUND" -eq 0 ]; then
  do_pass "All --mereka-* token references resolve to definitions"
fi

# 3. Check tokens.css is valid (basic structural checks)
echo ""
echo "--- tokens.css structural checks ---"
if [ -f "$TOKENS_CSS" ]; then
  do_pass "tokens.css exists"

  if grep -q ':root' "$TOKENS_CSS"; then
    do_pass "tokens.css has :root selector"
  else
    do_fail "tokens.css missing :root selector"
  fi

  # Count defined properties
  PROP_COUNT=$(grep -cP '^\s+--[a-z]' "$TOKENS_CSS" || true)
  if [ "$PROP_COUNT" -ge 80 ]; then
    do_pass "tokens.css has $PROP_COUNT properties (>= 80 required)"
  else
    do_fail "tokens.css only has $PROP_COUNT properties (expected >= 80)"
  fi

  # Check balanced braces
  OPEN=$(grep -o '{' "$TOKENS_CSS" | wc -l)
  CLOSE=$(grep -o '}' "$TOKENS_CSS" | wc -l)
  if [ "$OPEN" -eq "$CLOSE" ]; then
    do_pass "tokens.css has balanced braces"
  else
    do_fail "tokens.css has unbalanced braces ($OPEN open, $CLOSE close)"
  fi
else
  do_fail "tokens.css not found at assets/branding/tokens.css"
fi

# 4. Check _tokens.scss bridges key colors from tokens.css
echo ""
echo "--- Token bridge checks ---"
TOKENS_SCSS="$THEME_DIR/scss/_tokens.scss"
if [ -f "$TOKENS_SCSS" ]; then
  do_pass "_tokens.scss exists"

  # Key colors that must be bridged
  for color in teal magenta blue; do
    if grep -q "color-$color" "$TOKENS_SCSS"; then
      do_pass "$color color bridged in _tokens.scss"
    else
      do_fail "$color color missing from _tokens.scss bridge"
    fi
  done
else
  do_fail "_tokens.scss not found"
fi

# 5. Check no --pgn-* references without definitions
echo ""
echo "--- Paragon token bridge ---"
PGN_UNDEFINED=0
while IFS= read -r file; do
  while IFS= read -r token; do
    [ -z "$token" ] && continue
    if grep -q -- "^[[:space:]]*${token}:" "$file" 2>/dev/null; then
      : # Self-defined
    elif grep -q -- "^[[:space:]]*${token}:" "$COMMON_OVERRIDES" 2>/dev/null; then
      : # Defined in overrides
    elif grep -q -- "^[[:space:]]*${token}:" "$COMMON_DESIGN_TOKENS" 2>/dev/null; then
      : # Defined in generated design tokens
    else
      line_num="$(grep -n -m1 -F "var(${token}" "$file" 2>/dev/null | cut -d: -f1 || true)"
      line_num="${line_num:-?}"
      do_warn "Paragon token $token referenced but not bridged ($(basename "$file"):$line_num)"
      PGN_UNDEFINED=$((PGN_UNDEFINED + 1))
    fi
  done < <(grep -oP 'var\(--pgn-[a-z0-9_-]+' "$file" 2>/dev/null | sed 's/^var(//' | sort -u)
done < <(find "$THEME_DIR" \
  \( -name '*.scss' -o -name '*.css' \) \
  -not -path '*/node_modules/*' \
  -not -path '*/mfe/theme/*' \
  2>/dev/null)

if [ "$PGN_UNDEFINED" -eq 0 ]; then
  do_pass "All --pgn-* references are bridged"
fi

# Cleanup
rm -f "$DEFINED_TOKENS"

echo ""
echo "=== Results: $PASS PASS / $FAIL FAIL / $WARN WARN ==="

[ "$FAIL" -eq 0 ] && exit 0 || exit 1
