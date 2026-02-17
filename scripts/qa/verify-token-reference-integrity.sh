#!/usr/bin/env bash
# verify-token-reference-integrity.sh — Token reference integrity gate
# @covers AC-UITKN-001..004
#
# Checks:
#   AC-UITKN-001: All var(--mereka-*) references resolve to definitions
#   AC-UITKN-002: All SCSS $variable references resolve to declarations
#   AC-UITKN-003: Cross-file token value consistency (no hex drift)
#   AC-UITKN-004: CI gate blocks undefined token references
#
# Usage: ./scripts/qa/verify-token-reference-integrity.sh
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
THEME_DIR="$REPO_ROOT/infrastructure/tutor/themes/mereka"
CONTRACT_DOC="$REPO_ROOT/docs/architecture/TOKEN_REFERENCE_INTEGRITY.md"

PASS=0
FAIL=0
WARN=0

do_pass() { PASS=$((PASS + 1)); echo "  PASS  $1"; }
do_fail() { FAIL=$((FAIL + 1)); echo "  FAIL  $1"; }
do_warn() { WARN=$((WARN + 1)); echo "  WARN  $1"; }

echo "=== Token Reference Integrity Check ==="
echo ""

# 1. Verify contract document exists
echo "--- Contract documentation ---"
if [ -f "$CONTRACT_DOC" ]; then
  do_pass "Contract document exists"

  if grep -q "## Scope" "$CONTRACT_DOC" && \
     grep -q "## Token Definition Sources" "$CONTRACT_DOC" && \
     grep -q "## Reference Integrity Rules" "$CONTRACT_DOC" && \
     grep -q "## Token Inventory" "$CONTRACT_DOC"; then
    do_pass "Contract has all required sections"
  else
    do_fail "Contract missing required sections"
  fi

  if grep -q "AC-UITKN-001" "$CONTRACT_DOC" && \
     grep -q "AC-UITKN-002" "$CONTRACT_DOC" && \
     grep -q "AC-UITKN-003" "$CONTRACT_DOC" && \
     grep -q "AC-UITKN-004" "$CONTRACT_DOC"; then
    do_pass "Contract documents all 4 ACs"
  else
    do_fail "Contract missing AC tags"
  fi
else
  do_fail "Contract document not found"
fi

# 2. Collect --mereka-* token definitions
echo ""
echo "--- Token definitions (--mereka-*) ---"
MEREKA_TOKENS=$(mktemp)

grep -oP '(?<=  )--mereka-[a-z0-9_-]+(?=:)' "$THEME_DIR/scss/_tokens.scss" 2>/dev/null | sort -u >> "$MEREKA_TOKENS" || true
grep -oP '(?<=  )--mereka-[a-z0-9_-]+(?=:)' "$THEME_DIR/lms/static/css/mereka-overrides.css" 2>/dev/null | sort -u >> "$MEREKA_TOKENS" || true
grep -oP '(?<=  )--mereka-[a-z0-9_-]+(?=:)' "$THEME_DIR/cms/static/css/mereka-overrides.css" 2>/dev/null | sort -u >> "$MEREKA_TOKENS" || true

sort -u "$MEREKA_TOKENS" -o "$MEREKA_TOKENS"
MEREKA_DEF_COUNT=$(wc -l < "$MEREKA_TOKENS")
echo "  Found $MEREKA_DEF_COUNT unique --mereka-* token definitions"

# 3. Collect --pgn-* token definitions
echo ""
echo "--- Token definitions (--pgn-*) ---"
PGN_TOKENS=$(mktemp)

grep -oP '(?<=  )--pgn-[a-z0-9_-]+(?=:)' "$THEME_DIR/scss/_tokens.scss" 2>/dev/null | sort -u >> "$PGN_TOKENS" || true
grep -oP '(?<=  )--pgn-[a-z0-9_-]+(?=:)' "$THEME_DIR/lms/static/css/mereka-overrides.css" 2>/dev/null | sort -u >> "$PGN_TOKENS" || true
grep -oP '(?<=  )--pgn-[a-z0-9_-]+(?=:)' "$THEME_DIR/cms/static/css/mereka-overrides.css" 2>/dev/null | sort -u >> "$PGN_TOKENS" || true

sort -u "$PGN_TOKENS" -o "$PGN_TOKENS"
PGN_DEF_COUNT=$(wc -l < "$PGN_TOKENS")
echo "  Found $PGN_DEF_COUNT unique --pgn-* token definitions"

# 4. Collect SCSS variable declarations
echo ""
echo "--- SCSS variable declarations ---"
SCSS_VARS=$(mktemp)

grep -oP '(?<=^\$)[a-z0-9_-]+(?=:)' "$THEME_DIR/scss/_tokens.scss" 2>/dev/null | sort -u >> "$SCSS_VARS" || true
SCSS_VAR_COUNT=$(wc -l < "$SCSS_VARS")
echo "  Found $SCSS_VAR_COUNT unique SCSS variable declarations"

if [ "$SCSS_VAR_COUNT" -ge 20 ]; then
  do_pass "SCSS variable count >= 20 (found $SCSS_VAR_COUNT)"
else
  do_fail "SCSS variable count < 20 (found $SCSS_VAR_COUNT)"
fi

# 5. Check all var(--mereka-*) references resolve (AC-UITKN-001)
echo ""
echo "--- AC-UITKN-001: var(--mereka-*) references ---"
UNDEFINED_MEREKA=0
CHECKED_MEREKA=0

while IFS= read -r file; do
  while IFS=: read -r line_num match; do
    token=$(echo "$match" | grep -oP '(?<=var\()--mereka-[a-z0-9_-]+' | head -1)
    test -z "$token" && continue

    CHECKED_MEREKA=$((CHECKED_MEREKA + 1))

    if grep -qxF -- "$token" "$MEREKA_TOKENS"; then
      continue
    fi

    if grep -q -- "^[[:space:]]*${token}:" "$file" 2>/dev/null; then
      continue
    fi

    do_fail "Undefined --mereka-* token: $token in $(basename "$file"):$line_num"
    UNDEFINED_MEREKA=$((UNDEFINED_MEREKA + 1))
  done < <(grep -n 'var(--mereka-' "$file" 2>/dev/null || true)
done < <(find "$THEME_DIR" \( -name '*.scss' -o -name '*.css' \) -not -path '*/node_modules/*' 2>/dev/null)

if [ "$UNDEFINED_MEREKA" -eq 0 ]; then
  do_pass "All $CHECKED_MEREKA var(--mereka-*) references resolve (AC-UITKN-001)"
fi

# 6. Check all var(--pgn-*) references resolve
echo ""
echo "--- Paragon bridge: var(--pgn-*) references ---"
UNDEFINED_PGN=0
CHECKED_PGN=0

while IFS= read -r file; do
  while IFS=: read -r line_num match; do
    token=$(echo "$match" | grep -oP '(?<=var\()--pgn-[a-z0-9_-]+' | head -1)
    test -z "$token" && continue

    CHECKED_PGN=$((CHECKED_PGN + 1))

    if grep -qxF -- "$token" "$PGN_TOKENS"; then
      continue
    fi

    if grep -q -- "^[[:space:]]*${token}:" "$file" 2>/dev/null; then
      continue
    fi

    do_warn "Paragon token not bridged: $token in $(basename "$file"):$line_num"
    UNDEFINED_PGN=$((UNDEFINED_PGN + 1))
  done < <(grep -n 'var(--pgn-' "$file" 2>/dev/null || true)
done < <(find "$THEME_DIR" \( -name '*.scss' -o -name '*.css' \) -not -path '*/node_modules/*' 2>/dev/null)

if [ "$UNDEFINED_PGN" -eq 0 ]; then
  do_pass "All $CHECKED_PGN var(--pgn-*) references resolve"
fi

# 7. Check all SCSS $variable references resolve (AC-UITKN-002)
echo ""
echo "--- AC-UITKN-002: SCSS variable references ---"
UNDEFINED_SCSS=0
CHECKED_SCSS=0

while IFS= read -r file; do
  while IFS=: read -r line_num match; do
    var=$(echo "$match" | grep -oP '(?<=\$)(color-|mereka-)[a-z0-9_-]+' | head -1)
    test -z "$var" && continue

    if echo "$match" | grep -qP '\$'"$var"'\s*:'; then
      continue
    fi

    CHECKED_SCSS=$((CHECKED_SCSS + 1))

    if grep -qxF -- "$var" "$SCSS_VARS"; then
      continue
    fi

    # Check if self-declared in same file (e.g., $mereka-font-path: ... !default;)
    if grep -qP '^\$'"$var"'\s*:' "$file" 2>/dev/null; then
      continue
    fi

    do_fail "Undefined SCSS variable: \$$var in $(basename "$file"):$line_num"
    UNDEFINED_SCSS=$((UNDEFINED_SCSS + 1))
  done < <(grep -n '\$\(color-\|mereka-\)' "$file" 2>/dev/null || true)
done < <(find "$THEME_DIR" -name '*.scss' -not -path '*/node_modules/*' 2>/dev/null)

if [ "$UNDEFINED_SCSS" -eq 0 ]; then
  do_pass "All $CHECKED_SCSS SCSS variable references resolve (AC-UITKN-002)"
fi

# 8. Check cross-file token value consistency (AC-UITKN-003)
echo ""
echo "--- AC-UITKN-003: Cross-file token value consistency ---"
VALUE_DRIFT=0

TOKENS_VALUES=$(mktemp)
grep -oP '(?<=  )--mereka-[a-z0-9_-]+:\s*#[0-9a-fA-F]{3,6}' "$THEME_DIR/scss/_tokens.scss" 2>/dev/null >> "$TOKENS_VALUES" || true
grep -oP '(?<=  )--mereka-[a-z0-9_-]+:\s*#[0-9a-fA-F]{3,6}' "$THEME_DIR/lms/static/css/mereka-overrides.css" 2>/dev/null >> "$TOKENS_VALUES" || true
grep -oP '(?<=  )--mereka-[a-z0-9_-]+:\s*#[0-9a-fA-F]{3,6}' "$THEME_DIR/cms/static/css/mereka-overrides.css" 2>/dev/null >> "$TOKENS_VALUES" || true

sed -i 's/#\([0-9a-fA-F]\+\)/#\L\1/' "$TOKENS_VALUES"

while IFS= read -r token; do
  values=$(grep "^$token:" "$TOKENS_VALUES" | cut -d: -f2 | tr -d ' ' | sort -u)
  value_count=$(echo "$values" | wc -l)

  if [ "$value_count" -gt 1 ]; then
    do_fail "Token value drift: $token has $value_count values: $(echo "$values" | tr '\n' ' ')"
    VALUE_DRIFT=$((VALUE_DRIFT + 1))
  fi
done < <(cut -d: -f1 "$TOKENS_VALUES" | sort -u)

if [ "$VALUE_DRIFT" -eq 0 ]; then
  do_pass "No token value drift across files (AC-UITKN-003)"
fi

# 9. Check for duplicate definitions within files
echo ""
echo "--- Duplicate token definitions ---"
DUPLICATES_FOUND=0

for file in "$THEME_DIR/scss/_tokens.scss" \
            "$THEME_DIR/lms/static/css/mereka-overrides.css" \
            "$THEME_DIR/cms/static/css/mereka-overrides.css"; do
  test -f "$file" || continue

  tokens=$(grep -oP '(?<=  )--mereka-[a-z0-9_-]+(?=:)' "$file" 2>/dev/null | sort)
  duplicates=$(echo "$tokens" | uniq -d)

  if [ -n "$duplicates" ]; then
    while IFS= read -r dup_token; do
      do_fail "Duplicate token in $(basename "$file"): $dup_token"
      DUPLICATES_FOUND=$((DUPLICATES_FOUND + 1))
    done <<< "$duplicates"
  fi
done

if [ "$DUPLICATES_FOUND" -eq 0 ]; then
  do_pass "No duplicate token definitions"
fi

# 10. Token count sanity
echo ""
echo "--- Token count sanity ---"
if [ "$MEREKA_DEF_COUNT" -ge 15 ]; then
  do_pass "--mereka-* tokens >= 15 (found $MEREKA_DEF_COUNT)"
else
  do_fail "--mereka-* tokens < 15 (found $MEREKA_DEF_COUNT)"
fi

if [ "$PGN_DEF_COUNT" -ge 10 ]; then
  do_pass "--pgn-* tokens >= 10 (found $PGN_DEF_COUNT)"
else
  do_fail "--pgn-* tokens < 10 (found $PGN_DEF_COUNT)"
fi

rm -f "$MEREKA_TOKENS" "$PGN_TOKENS" "$SCSS_VARS" "$TOKENS_VALUES"

echo ""
echo "=== Results: $PASS PASS / $FAIL FAIL / $WARN WARN ==="

test "$FAIL" -eq 0 && exit 0 || exit 1
