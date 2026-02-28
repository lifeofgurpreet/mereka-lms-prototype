#!/usr/bin/env bash
# @covers AC-TKN-016, AC-TKN-017, AC-TKN-020, AC-TKN-021, AC-TKN-022, AC-TKN-023
# @spec: paragon-design-tokens-migration_spec.md
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

PLUGIN_FILE="$REPO_ROOT/infrastructure/tutor/plugins/mereka_lms.py"
TOKENS_FILE="$REPO_ROOT/infrastructure/tutor/themes/mereka/scss/_tokens.scss"
MFE_FILE="$REPO_ROOT/infrastructure/tutor/themes/mereka/mfe/mereka.scss"
CORE_THEME="$REPO_ROOT/infrastructure/tutor/themes/mereka/mfe/theme/core.min.css"
MEREKA_THEME_DIR="$REPO_ROOT/infrastructure/tutor/themes/mereka/mfe/theme"
AUDIT_DOC="$REPO_ROOT/docs/architecture/PARAGON_V22_TOKEN_AUDIT.md"
MISSING_TSV="$REPO_ROOT/docs/architecture/PARAGON_V22_TOKEN_AUDIT_CONSUMED_MISSING.tsv"
DEFINES_TSV="$REPO_ROOT/docs/architecture/PARAGON_V22_TOKEN_AUDIT_DEFINED_IGNORED.tsv"
DEFINED_TSV="$REPO_ROOT/docs/architecture/PARAGON_V22_TOKEN_AUDIT_CONSUMED_DEFINED.tsv"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PASS=0
WARN=0
FAIL=0

pass() {
  echo -e "${GREEN}PASS${NC} $1"
  PASS=$((PASS + 1))
}

warn() {
  echo -e "${YELLOW}WARN${NC} $1"
  WARN=$((WARN + 1))
}

fail() {
  echo -e "${RED}FAIL${NC} $1"
  FAIL=$((FAIL + 1))
}

check_file() {
  if [[ -f "$1" ]]; then
    pass "$2 exists"
    return 0
  fi

  fail "$2 missing"
  return 1
}

echo -e "${BLUE}=== Paragon Token Coverage Verification ===${NC}\n"

# 1) Plugin configuration checks
if [[ -f "$PLUGIN_FILE" ]]; then
  if grep -q "MEREKA_PARAGON_THEME_ENABLED" "$PLUGIN_FILE"; then
    pass "Plugin exposes MEREKA_PARAGON_THEME_ENABLED"
  else
    fail "Plugin missing MEREKA_PARAGON_THEME_ENABLED"
  fi

  if grep -q "MEREKA_PARAGON_THEME_CDN_BASE" "$PLUGIN_FILE"; then
    pass "Plugin exposes MEREKA_PARAGON_THEME_CDN_BASE"
  else
    fail "Plugin missing MEREKA_PARAGON_THEME_CDN_BASE"
  fi

  if grep -q "PARAGON_THEME_URLS" "$PLUGIN_FILE"; then
    pass "Plugin config includes PARAGON_THEME_URLS"
  else
    fail "Plugin config missing PARAGON_THEME_URLS"
  fi
else
  fail "Plugin file missing"
fi

echo -e "\n${BLUE}Theme asset checks${NC}"
check_file "$CORE_THEME" "core.min.css"
if [[ -f "$CORE_THEME" ]]; then
  CORE_SIZE=$(wc -c < "$CORE_THEME")
  if [[ "$CORE_SIZE" -gt 1024 ]]; then
    pass "core.min.css has content (${CORE_SIZE} bytes)"
  else
    fail "core.min.css is unexpectedly small (${CORE_SIZE} bytes)"
  fi
fi

if [[ -d "$MEREKA_THEME_DIR" ]]; then
  pass "Theme directory exists: infrastructure/tutor/themes/mereka/mfe/theme"
else
  fail "Theme directory missing: infrastructure/tutor/themes/mereka/mfe/theme"
fi

BRAND_THEME="$MEREKA_THEME_DIR/mereka-brand.min.css"
BRAND_LIGHT_THEME="$MEREKA_THEME_DIR/mereka-brand-light.min.css"

if [[ -f "$BRAND_THEME" ]]; then
  BRAND_SIZE=$(wc -c < "$BRAND_THEME")
  if [[ "$BRAND_SIZE" -gt 256 && "$BRAND_SIZE" -le 16384 ]]; then
    pass "mereka-brand.min.css exists (${BRAND_SIZE} bytes) and is within delta-size budget"
  elif [[ "$BRAND_SIZE" -gt 16384 ]]; then
    fail "mereka-brand.min.css is bloated (${BRAND_SIZE} bytes; expected <=16384 for delta bundle)"
  else
    fail "mereka-brand.min.css is unexpectedly small (${BRAND_SIZE} bytes)"
  fi
else
  fail "mereka-brand.min.css missing"
fi

if [[ -f "$BRAND_LIGHT_THEME" ]]; then
  BRAND_LIGHT_SIZE=$(wc -c < "$BRAND_LIGHT_THEME")
  if [[ "$BRAND_LIGHT_SIZE" -gt 256 && "$BRAND_LIGHT_SIZE" -le 16384 ]]; then
    pass "mereka-brand-light.min.css exists (${BRAND_LIGHT_SIZE} bytes) and is within delta-size budget"
  elif [[ "$BRAND_LIGHT_SIZE" -gt 16384 ]]; then
    fail "mereka-brand-light.min.css is bloated (${BRAND_LIGHT_SIZE} bytes; expected <=16384 for delta bundle)"
  else
    fail "mereka-brand-light.min.css is unexpectedly small (${BRAND_LIGHT_SIZE} bytes)"
  fi
else
  fail "mereka-brand-light.min.css missing"
fi

if [[ -f "$BRAND_THEME" && -f "$BRAND_LIGHT_THEME" ]]; then
  if cmp -s "$BRAND_THEME" "$BRAND_LIGHT_THEME"; then
    pass "Brand/min light themes are synchronized"
  else
    warn "mereka-brand-light.min.css differs from mereka-brand.min.css"
  fi
fi

# 2) MFE stylesheet token hygiene
if [[ -f "$MFE_FILE" ]]; then
  HEX_COUNT=$(python3 - "$MFE_FILE" <<'PY'
from pathlib import Path
import re

path = Path(__import__('sys').argv[1])
text = path.read_text(encoding='utf-8')

# Remove CSS comments and multiline values we keep as-is for count purposes.
text = re.sub(r'/\*.*?\*/', '', text, flags=re.S)

lines = []
for line in text.splitlines():
    stripped = line.strip()
    if stripped.startswith('//') or not stripped:
        continue
    lines.append(line)

clean = '\n'.join(lines)
matches = re.findall(r'#[0-9A-Fa-f]{3,8}\b', clean)
print(len(matches))
PY
)

  if [[ "$HEX_COUNT" -eq 0 ]]; then
    pass "mereka.scss has no raw #hex values"
  else
    fail "mereka.scss has ${HEX_COUNT} raw #hex values"
  fi

  VAR_COUNT=$(grep -o 'var(--' "$MFE_FILE" | wc -l)
  if [[ "$VAR_COUNT" -ge 30 ]]; then
    pass "mereka.scss uses ${VAR_COUNT} var() references (>=30)"
  else
    warn "mereka.scss uses only ${VAR_COUNT} var() references"
  fi
else
  fail "mereka.scss missing"
fi

# 3) Token bridge verification
if [[ -f "$TOKENS_FILE" ]]; then
  pass "Token bridge file exists"

  # Bootstrap variable bridge for LMS/CMS Sass compilation (AC-TKN-022, AC-TKN-023)
  if grep -q '^\$primary:' "$TOKENS_FILE" \
    && grep -q '^\$secondary:' "$TOKENS_FILE" \
    && grep -q '^\$font-family-sans-serif:' "$TOKENS_FILE"; then
    pass "Bootstrap SCSS variables are present (\$primary/\$secondary/\$font-family-sans-serif)"
  else
    fail "Bootstrap SCSS bridge variables missing from _tokens.scss"
  fi

  if grep -q ':root[[:space:]]*{' "$TOKENS_FILE"; then
    pass "_tokens.scss contains :root CSS custom property block"
  else
    fail "_tokens.scss missing :root CSS custom property block"
  fi

  # Ensure core semantic tokens are declared
  for token in \
    '--pgn-color-primary-base' \
    '--pgn-color-secondary-base' \
    '--pgn-typography-font-family-sans-serif' \
    '--pgn-btn-border-radius' \
    '--pgn-link-color' \
    '--pgn-link-hover-color' \
    '--pgn-body-bg' \
    '--pgn-body-color' \
    '--pgn-border-color'
  do
    if grep -qF -- "$token" "$TOKENS_FILE"; then
      pass "Token bridge defines ${token}"
    else
      fail "Token bridge missing ${token}"
    fi
  done

  # Ensure canonical Paragon v22 aliases are declared for tokens consumed by core.min.css
  for token in \
    '--pgn-color-secondary-base' \
    '--pgn-color-success-base' \
    '--pgn-color-warning-base' \
    '--pgn-color-danger-base' \
    '--pgn-typography-font-family-sans-serif' \
    '--pgn-typography-font-family-base' \
    '--pgn-typography-font-size-sm' \
    '--pgn-typography-font-size-base' \
    '--pgn-typography-font-size-lg' \
    '--pgn-typography-line-height-sm' \
    '--pgn-typography-line-height-base' \
    '--pgn-typography-line-height-lg' \
    '--pgn-size-border-radius-sm' \
    '--pgn-size-border-radius-base' \
    '--pgn-size-border-radius-lg'
  do
    if grep -qF -- "$token" "$TOKENS_FILE"; then
      pass "Token bridge defines canonical alias ${token}"
    else
      fail "Token bridge missing canonical alias ${token}"
    fi
  done

  # Keep this check practical: tokens should be declared before relying on them in compiled files.
  for token in \
    '--mereka-color-teal' \
    '--mereka-color-magenta' \
    '--mereka-color-blue' \
    '--mereka-mfe-card-shadow'
  do
    if grep -qF -- "$token" "$TOKENS_FILE"; then
      pass "Token bridge includes ${token}"
    else
      warn "Token bridge missing ${token}"
    fi
  done

  if grep -qF -- '--pgn-heading-font-family' "$TOKENS_FILE"; then
    pass "Token bridge defines --pgn-heading-font-family"
  else
    warn "Token bridge does not define --pgn-heading-font-family; Paragon defaults will be used"
  fi

  if grep -qF -- '--pgn-form-control-border-color' "$TOKENS_FILE"; then
    pass "Token bridge defines --pgn-form-control-border-color"
  else
    warn "Token bridge does not define --pgn-form-control-border-color; keeping BEM fallback in place"
  fi
else
  fail "Token bridge file missing"
fi

if [[ -f "$CORE_THEME" ]]; then
  CONSUMED_PGN=$(python3 - "$CORE_THEME" <<'PY'
from pathlib import Path
import re

text = Path(__import__('sys').argv[1]).read_text(encoding='utf-8')
without_defs = re.sub(r"--pgn-[A-Za-z0-9_-]+\s*:[^;{}]*;", "", text)
tokens = sorted(set(re.findall(r"var\(\s*(--pgn-[A-Za-z0-9_-]+)\s*(?:,|\))", without_defs)))
print(len(tokens))
print('\n'.join(tokens[:5]))
print('…')
PY
)
  CONSUMED_TOTAL=$(echo "$CONSUMED_PGN" | head -n1)
  if [[ "$CONSUMED_TOTAL" -ge 1000 ]]; then
    pass "core.min.css exposes ${CONSUMED_TOTAL} --pgn-* references"
  else
    warn "core.min.css exposes only ${CONSUMED_TOTAL} --pgn-* references"
  fi
else
  fail "Cannot analyze core.min.css"
fi

echo -e "\n${BLUE}Token audit artifact${NC}"
if [[ -f "$AUDIT_DOC" ]]; then
  if rg -q "Consumed & Defined|Consumed & Missing|Defined & Ignored" "$AUDIT_DOC"; then
    pass "PARAGON v22 token audit document found with required sections"
  else
    warn "PARAGON v22 audit doc exists but is missing one or more category sections"
  fi
else
  fail "PARAGON v22 token audit doc missing"
fi

if [[ -f "$MISSING_TSV" ]]; then
  if [[ -s "$MISSING_TSV" ]]; then
    pass "Consumed+missing token TSV is present"
  else
    warn "Consumed+missing token TSV is empty"
  fi
else
  fail "Consumed+missing token TSV missing"
fi

if [[ -f "$DEFINES_TSV" ]]; then
  if [[ -s "$DEFINES_TSV" ]]; then
    pass "Defined-only token TSV is present"
  else
    warn "Defined-only token TSV is empty"
  fi
else
  fail "Defined-only token TSV missing"
fi

if [[ -f "$DEFINED_TSV" ]]; then
  if [[ -s "$DEFINED_TSV" ]]; then
    pass "Consumed+defined token TSV is present"
  else
    warn "Consumed+defined token TSV is empty"
  fi
else
  fail "Consumed+defined token TSV missing"
fi

echo -e "\n${BLUE}Summary${NC}"
echo -e "  ${GREEN}PASS${NC}: $PASS"
echo -e "  ${YELLOW}WARN${NC}: $WARN"
echo -e "  ${RED}FAIL${NC}: $FAIL"

if [[ "$FAIL" -ne 0 ]]; then
  exit 1
fi

exit 0
