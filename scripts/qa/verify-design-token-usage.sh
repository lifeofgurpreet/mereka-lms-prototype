#!/usr/bin/env bash
# verify-design-token-usage.sh — Lint for hardcoded colors in theme sources
# @covers AC-UITOKEN-002
#
# Scans MFE/theme SCSS and CSS files for raw hex color values that should
# be token references instead.
#
# Usage:
#   ./scripts/qa/verify-design-token-usage.sh
#   ./scripts/qa/verify-design-token-usage.sh --strict
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCOPE_MODE="${VERIFY_DESIGN_TOKEN_USAGE_SCOPE:-}"
CHANGED_FILES_RAW="${VERIFY_DESIGN_TOKEN_USAGE_CHANGED_FILES:-${CI_CHANGED_FILES:-}}"

should_skip_scope() {
  [[ "$SCOPE_MODE" == "changed" ]] || return 1
  [[ -n "$CHANGED_FILES_RAW" ]] || return 1

  while IFS= read -r path; do
    [[ -n "$path" ]] || continue
    case "$path" in
      .github/workflows/ci.yml|\
      scripts/qa/verify-design-token-usage.sh|\
      assets/branding/tokens.css|\
      infrastructure/tutor/themes/mereka/*)
        return 1
        ;;
    esac
  done <<< "$CHANGED_FILES_RAW"

  return 0
}

if should_skip_scope; then
  echo "PASS verify-design-token-usage (scope skip: no design-token authority changes)"
  exit 0
fi

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PASS_COUNT=0
FAIL_COUNT=0
WARN_COUNT=0
STRICT_MODE=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --strict) STRICT_MODE=1; shift ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

echo -e "${BLUE}=== Design Token Usage Lint ===${NC}"
echo ""

pass() { echo -e "${GREEN}[PASS]${NC} $1"; ((PASS_COUNT++)) || true; }
fail() { echo -e "${RED}[FAIL]${NC} $1"; ((FAIL_COUNT++)) || true; }
warn() {
  echo -e "${YELLOW}[WARN]${NC} $1"
  ((WARN_COUNT++)) || true
  if [[ $STRICT_MODE -eq 1 ]]; then
    fail "$1 (strict mode)"
    ((WARN_COUNT--)) || true
  fi
}

# Token definition files (allowed to contain hex values)
TOKEN_FILES=(
  "assets/branding/tokens.css"
  "infrastructure/tutor/themes/mereka/scss/_tokens.scss"
)

# Theme files to lint (should use var() references, not raw hex)
THEME_FILES=(
  "infrastructure/tutor/themes/mereka/scss/theme.scss"
  "infrastructure/tutor/themes/mereka/common/static/css/mereka-overrides.css"
  "infrastructure/tutor/themes/mereka/lms/static/css/mereka-overrides.css"
  "infrastructure/tutor/themes/mereka/cms/static/css/mereka-overrides.css"
)

echo -e "${BLUE}## Token Definition Files${NC}"

for tf in "${TOKEN_FILES[@]}"; do
  if [[ -f "$REPO_ROOT/$tf" ]]; then
    pass "$tf exists"
  else
    fail "$tf missing"
  fi
done

echo ""
echo -e "${BLUE}## Hardcoded Color Lint${NC}"

# Known allowed hex values (structural, not brand colors)
ALLOWED_HEX=(
  "#fff"
  "#ffffff"
  "#000"
  "#000000"
  "#1A1623"   # footer v2 bg (structural)
  "#1a1623"   # lowercase variant
)

for theme_file in "${THEME_FILES[@]}"; do
  full_path="$REPO_ROOT/$theme_file"
  if [[ ! -f "$full_path" ]]; then
    warn "$theme_file not found — skipping"
    continue
  fi

  # Find hex colors not inside var() or CSS custom property definitions
  # Pattern: standalone hex colors like #ab3b78 that are VALUES, not DEFINITIONS
  # Exclude lines that define custom properties (--mereka-*, --pgn-*, --color-*)
  # Exclude lines that use var()
  # Exclude comment lines
  RAW_HEX_LINES=$(grep -nE '#[0-9a-fA-F]{3,8}' "$full_path" 2>/dev/null \
    | grep -vE '^\s*/\*|^\s*\*|^\s*//' 2>/dev/null \
    | grep -vE '(--mereka-|--pgn-|--color-)' 2>/dev/null \
    | grep -vE 'var\(' 2>/dev/null \
    | grep -vE 'rgba?\(' 2>/dev/null || true)

  if [[ -z "$RAW_HEX_LINES" ]]; then
    pass "$theme_file: no hardcoded brand colors found"
  else
    LINE_COUNT=$(echo "$RAW_HEX_LINES" | wc -l)
    # Filter out allowed structural values
    FILTERED=""
    while IFS= read -r line; do
      SKIP=0
      for allowed in "${ALLOWED_HEX[@]}"; do
        lower_line=$(echo "$line" | tr '[:upper:]' '[:lower:]')
        lower_allowed=$(echo "$allowed" | tr '[:upper:]' '[:lower:]')
        if grep -qiE "${lower_allowed}[^0-9a-fA-F]|${lower_allowed}$" <<<"$lower_line"; then
          SKIP=1
          break
        fi
      done
      if [[ $SKIP -eq 0 ]]; then
        FILTERED+="$line"$'\n'
      fi
    done <<< "$RAW_HEX_LINES"

    FILTERED=$(echo "$FILTERED" | sed '/^$/d')
    if [[ -z "$FILTERED" ]]; then
      pass "$theme_file: only structural hex values (allowed)"
    else
      FILTERED_COUNT=$(echo "$FILTERED" | wc -l)
      warn "$theme_file: ${FILTERED_COUNT} hardcoded hex color(s) found"
      echo "$FILTERED" | head -5 | while IFS= read -r line; do
        echo -e "    ${YELLOW}→${NC} $line"
      done
      if [[ $FILTERED_COUNT -gt 5 ]]; then
        echo -e "    ${YELLOW}... and $((FILTERED_COUNT - 5)) more${NC}"
      fi
    fi
  fi
done

echo ""
echo -e "${BLUE}## Token Reference Completeness${NC}"

# Check that key brand colors in theme files use var() references
BRAND_TOKENS=(
  "--mereka-color-teal"
  "--mereka-color-magenta"
  "--mereka-color-blue"
  "--mereka-color-ink-900"
  "--mereka-color-ink-700"
)

for token in "${BRAND_TOKENS[@]}"; do
  USAGE_COUNT=0
  for theme_file in "${THEME_FILES[@]}"; do
    full_path="$REPO_ROOT/$theme_file"
    [[ -f "$full_path" ]] || continue
    COUNT=$(grep -c "var(${token}" "$full_path" 2>/dev/null || true)
    USAGE_COUNT=$((USAGE_COUNT + COUNT))
  done
  if [[ $USAGE_COUNT -gt 0 ]]; then
    pass "${token} referenced via var() (${USAGE_COUNT} usages)"
  else
    warn "${token} not referenced via var() in any theme file"
  fi
done

echo ""
echo -e "${BLUE}## Summary${NC}"
echo ""
echo -e "  ${GREEN}PASS${NC}: $PASS_COUNT"
echo -e "  ${YELLOW}WARN${NC}: $WARN_COUNT"
echo -e "  ${RED}FAIL${NC}: $FAIL_COUNT"
echo ""

if [[ $FAIL_COUNT -eq 0 && $WARN_COUNT -eq 0 ]]; then
  echo -e "${GREEN}All checks passed${NC}"
  exit 0
elif [[ $FAIL_COUNT -eq 0 ]]; then
  echo -e "${YELLOW}Warnings exist — review hardcoded values${NC}"
  exit 0
else
  echo -e "${RED}Some checks failed${NC}"
  exit 1
fi
