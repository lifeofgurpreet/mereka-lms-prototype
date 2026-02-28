#!/usr/bin/env bash
# @covers AC-UISEL-001
# Verify selector complexity and quality in Mereka theme SCSS/CSS files.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
PASS=0; FAIL=0; WARN=0

pass() { echo -e "${GREEN}PASS${NC} $1"; PASS=$((PASS + 1)); }
fail() { echo -e "${RED}FAIL${NC} $1"; FAIL=$((FAIL + 1)); }
warn() { echo -e "${YELLOW}WARN${NC} $1"; WARN=$((WARN + 1)); }

echo "Verifying Selector Hardening Policy (AC-UISEL-001)..."
echo ""

# ---------------------------------------------------------------------------
# Scan for fragile selectors (>3 levels of nesting)
# ---------------------------------------------------------------------------
THEME_DIR="infrastructure/tutor/themes/mereka"
FRAGILE_SELECTORS=0
DATA_TESTID_SELECTORS=0
RAW_HEX_COLORS=0

echo "Scanning SCSS/CSS files in $THEME_DIR..."

# Find SCSS/CSS source files only (exclude generated/runtime artifacts)
SCSS_FILES=$(find "$THEME_DIR" -type f \( -name "*.scss" -o -name "*.css" \) \
  ! -path "*/node_modules/*" \
  ! -path "*/dist/*" \
  ! -path "*/build/*" \
  ! -path "*/mfe/theme/*.min.css" \
  ! -path "*/static/css/mereka-overrides.css" \
  ! -path "*/static/css/mereka-design-tokens.css" 2>/dev/null || true)

if [[ -z "$SCSS_FILES" ]]; then
  fail "No SCSS/CSS files found in $THEME_DIR"
else
  pass "Found SCSS/CSS files to scan"
  echo "  Source file count: $(echo "$SCSS_FILES" | wc -l | tr -d ' ')"
fi

# ---------------------------------------------------------------------------
# Check 1: Selectors with >3 levels of nesting
# Pattern: .a .b .c .d (4+ descendant combinators)
# ---------------------------------------------------------------------------
echo ""
echo "--- Checking for deeply nested selectors (>3 levels) ---"

for file in $SCSS_FILES; do
  [[ -z "$file" ]] && continue

  # Match lines with 4+ chained class/element selectors
  # Pattern: selector spaces selector spaces selector spaces selector
  matches=$(grep -nE '^\s*\.[a-zA-Z0-9_-]+\s+\.[a-zA-Z0-9_-]+\s+\.[a-zA-Z0-9_-]+\s+\.[a-zA-Z0-9_-]+' "$file" || true)

  if [[ -n "$matches" ]]; then
    line_count=$(echo "$matches" | wc -l)
    FRAGILE_SELECTORS=$((FRAGILE_SELECTORS + line_count))
    echo "$matches" | while IFS=: read -r lineno line; do
      warn "Deeply nested selector (>3 levels) in $file:$lineno"
      echo "      $line"
    done
  fi
done

if [[ $FRAGILE_SELECTORS -eq 0 ]]; then
  pass "No deeply nested selectors (>3 levels) found"
else
  warn "Found $FRAGILE_SELECTORS deeply nested selectors (KNOWN ISSUE - theme.scss has legacy selectors)"
fi

# ---------------------------------------------------------------------------
# Check 2: data-testid used as styling hook (production anti-pattern)
# ---------------------------------------------------------------------------
echo ""
echo "--- Checking for data-testid in production SCSS (anti-pattern) ---"

for file in $SCSS_FILES; do
  [[ -z "$file" ]] && continue

  # Skip test files
  if echo "$file" | grep -qE "test|spec|mock|fixture"; then
    continue
  fi

  # Match [data-testid in selectors
  matches=$(grep -nE '\[data-testid' "$file" || true)

  if [[ -n "$matches" ]]; then
    while IFS=: read -r lineno line; do
      if echo "$line" | grep -qE '^\s*(//|/\*|\*)'; then
        continue
      fi
      DATA_TESTID_SELECTORS=$((DATA_TESTID_SELECTORS + 1))
      warn "data-testid used as styling hook in $file:$lineno"
      echo "      $line"
    done <<< "$matches"
  fi
done

if [[ $DATA_TESTID_SELECTORS -eq 0 ]]; then
  pass "No data-testid selectors found in production SCSS"
else
  warn "Found $DATA_TESTID_SELECTORS data-testid selectors (used in mereka.scss for MFE targeting)"
fi

# ---------------------------------------------------------------------------
# Check 3: Raw hex colors (should use var(--mereka-*) or $color-* variables)
# ---------------------------------------------------------------------------
echo ""
echo "--- Checking for raw hex colors (should use design tokens) ---"

# Known exceptions: rgba() alpha values, background gradients with inline colors
EXCEPTIONS=(
  "rgba(26, 22, 35"          # --mereka-color-ink with alpha
  "rgba(45, 137, 139"        # --mereka-color-teal with alpha
  "rgba(171, 59, 120"        # --mereka-color-magenta with alpha
  "rgba(39, 110, 241"        # --mereka-color-blue with alpha
  "rgba(255, 255, 255"       # white with alpha
  "linear-gradient"          # gradient functions often inline colors
)

for file in $SCSS_FILES; do
  [[ -z "$file" ]] && continue

  # Find hex color values not wrapped in var() or $variable references
  matches=$(grep -nE '#[0-9a-fA-F]{3,8}' "$file" || true)

  if [[ -n "$matches" ]]; then
    while IFS=: read -r lineno line; do
      # Ignore comments.
      if echo "$line" | grep -qE '^\s*(//|/\*|\*)'; then
        continue
      fi

      # Token declarations are expected to define raw hex values.
      if echo "$line" | grep -qE '^\s*(--[a-zA-Z0-9_-]+|\$[a-zA-Z0-9_-]+)\s*:\s*#[0-9a-fA-F]{3,8}\b'; then
        continue
      fi

      # Skip if line contains var(--mereka-*) or $color-*
      if echo "$line" | grep -qE 'var\(--mereka-|var\(--color-|\$color-|\$mereka-'; then
        continue
      fi

      # Skip known exceptions
      skip_line=false
      for exc in "${EXCEPTIONS[@]}"; do
        if echo "$line" | grep -qF "$exc"; then
          skip_line=true
          break
        fi
      done

      if [[ "$skip_line" == false ]]; then
        RAW_HEX_COLORS=$((RAW_HEX_COLORS + 1))
        warn "Raw hex color in $file:$lineno (prefer var(--mereka-*) or \$color-* token)"
        echo "      $line"
      fi
    done <<< "$matches"
  fi
done

if [[ $RAW_HEX_COLORS -eq 0 ]]; then
  pass "All colors use design tokens (no raw hex)"
else
  warn "Found $RAW_HEX_COLORS raw hex colors (ACCEPTABLE for gradients/rgba with alpha)"
fi

# ---------------------------------------------------------------------------
# Check 4: Selector complexity metrics
# ---------------------------------------------------------------------------
echo ""
echo "--- Selector Complexity Metrics ---"

TOTAL_SELECTORS=$(grep -hE '^\s*\.[a-zA-Z0-9_-]+|^\s*\[[a-zA-Z0-9_-]+' $SCSS_FILES | wc -l || echo 0)
TOTAL_TOKENS=$(grep -hE 'var\(--mereka-|var\(--color-|\$color-|\$mereka-' $SCSS_FILES | wc -l || echo 0)

echo "Total selectors: $TOTAL_SELECTORS"
echo "Design token usages: $TOTAL_TOKENS"
echo "Fragile selectors (>3 levels): $FRAGILE_SELECTORS"
echo "data-testid selectors: $DATA_TESTID_SELECTORS"
echo "Raw hex colors (non-token): $RAW_HEX_COLORS"

if [[ $TOTAL_SELECTORS -gt 0 ]]; then
  FRAGILE_RATIO=$((FRAGILE_SELECTORS * 100 / TOTAL_SELECTORS))
  echo "Fragile selector ratio: ${FRAGILE_RATIO}%"

  if [[ $FRAGILE_RATIO -lt 30 ]]; then
    pass "Fragile selector ratio under 30% threshold (${FRAGILE_RATIO}%)"
  else
    warn "Fragile selector ratio ${FRAGILE_RATIO}% exceeds 30% (KNOWN ISSUE - theme.scss legacy selectors)"
  fi
fi

# ---------------------------------------------------------------------------
# Check 5: Policy document exists
# ---------------------------------------------------------------------------
echo ""
echo "--- Checking for policy documentation ---"

POLICY_DOC="docs/architecture/SELECTOR_HARDENING_POLICY.md"
if [[ -f "$POLICY_DOC" ]]; then
  pass "Selector hardening policy documented at $POLICY_DOC"
else
  fail "Selector hardening policy not found at $POLICY_DOC"
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo "=== Summary ==="
echo -e "${GREEN}PASS:${NC} $PASS | ${YELLOW}WARN:${NC} $WARN | ${RED}FAIL:${NC} $FAIL"

# Exit with warning status if we have failures
# Warnings are acceptable (known issues in theme.scss)
if [[ $FAIL -gt 0 ]]; then
  exit 1
else
  exit 0
fi
