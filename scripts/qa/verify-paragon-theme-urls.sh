#!/usr/bin/env bash
# @covers AC-TKN-016, AC-TKN-020, AC-TKN-021, AC-TKN-029, AC-TKN-033, AC-TKN-034
# @spec: paragon-design-tokens-migration_spec.md
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$REPO_ROOT/scripts/shared/ci-skip-guards.sh"
require_command rg || exit 0
source "$REPO_ROOT/scripts/shared/mereka_plugin_contract.sh"

CADDY_FILE="$REPO_ROOT/deploy/k8s/base/plugins/mfe/apps/mfe/Caddyfile"
APPLY_PATCHES="$REPO_ROOT/infrastructure/tutor/apply-patches.sh"
BUILD_TOKENS_SCRIPT="$REPO_ROOT/scripts/branding/build-tokens.sh"
THEME_DIR="$REPO_ROOT/infrastructure/tutor/themes/mereka/mfe/theme"
THEME_FILES=(
  "core.min.css"
  "light.min.css"
  "mereka-brand.min.css"
  "mereka-brand-light.min.css"
)

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASS=0
WARN=0
FAIL=0

pass() { echo -e "${GREEN}PASS${NC} $1"; PASS=$((PASS + 1)); }
warn() { echo -e "${YELLOW}WARN${NC} $1"; WARN=$((WARN + 1)); }
fail() { echo -e "${RED}FAIL${NC} $1"; FAIL=$((FAIL + 1)); }

count_pgn_tokens() {
  local file="$1"
  python3 - "$file" <<'PY'
from pathlib import Path
import re
import sys

text = Path(sys.argv[1]).read_text(encoding="utf-8")
print(len(re.findall(r"^\s*--pgn-", text, flags=re.M)))
PY
}

echo "=== PARAGON_THEME_URLS verification ==="

echo ""
echo "1) Tutor plugin config"
if ! mereka_plugin_has_any "$REPO_ROOT"; then
  fail "Plugin contract sources missing (expected at least one main plugin contract file)"
else
  if mereka_plugin_has_regex "$REPO_ROOT" "PARAGON_THEME_URLS"; then
    pass "Plugin contract sources contain PARAGON_THEME_URLS"
  else
    fail "PARAGON_THEME_URLS not found in plugin contract sources"
  fi

  if mereka_plugin_has_regex "$REPO_ROOT" "MEREKA_PARAGON_THEME_CDN_BASE"; then
    pass "Plugin contract sources contain MEREKA_PARAGON_THEME_CDN_BASE"
  else
    fail "MEREKA_PARAGON_THEME_CDN_BASE not found in plugin contract sources"
  fi

  if mereka_plugin_has_regex "$REPO_ROOT" "MEREKA_PARAGON_THEME_ENABLED"; then
    pass "Plugin contract sources contain MEREKA_PARAGON_THEME_ENABLED toggle"
  else
    fail "MEREKA_PARAGON_THEME_ENABLED not found in plugin contract sources"
  fi

  if mereka_plugin_has_regex "$REPO_ROOT" '\("MEREKA_PARAGON_THEME_ENABLED",[[:space:]]*True\)'; then
    pass "MEREKA_PARAGON_THEME_ENABLED defaults to True (runtime theme active by default)"
  else
    fail "MEREKA_PARAGON_THEME_ENABLED is not defaulted to True"
  fi

  if mereka_plugin_has_regex "$REPO_ROOT" "MEREKA_PARAGON_THEME_CDN_BASE" \
    && mereka_plugin_has_regex "$REPO_ROOT" "PARAGON_THEME_URLS"; then
    pass "AC-TKN-034 plugin source contains PARAGON_THEME_URLS render inputs"
  else
    fail "AC-TKN-034 plugin source missing PARAGON_THEME_URLS render inputs"
  fi
fi

echo ""
echo "2) Compiled MFE theme assets"
if [[ ! -d "$THEME_DIR" ]]; then
  fail "Theme directory missing: infrastructure/tutor/themes/mereka/mfe/theme"
else
  pass "Theme directory exists: infrastructure/tutor/themes/mereka/mfe/theme"
fi

for f in "${THEME_FILES[@]}"; do
  path="$THEME_DIR/$f"
  if [[ ! -f "$path" ]]; then
    fail "Theme file missing: $f"
    continue
  fi

  pass "Theme file exists: $f"

  # Keep runtime theme payload checks focused on override files.
  case "$f" in
    mereka-brand.min.css|mereka-brand-light.min.css)
      if grep -q -- "--pgn-color-primary-base" "$path"; then
        pass "Brand theme file includes canonical --pgn-color-primary-base: $f"
      else
        fail "Brand theme file missing canonical --pgn-color-primary-base: $f"
      fi

      if [[ ! -s "$path" ]]; then
        fail "Brand theme file is empty: $f"
      fi
      ;;
    core.min.css|light.min.css)
      if [[ -s "$path" ]]; then
        pass "Core theme file is non-empty: $f"
      else
        fail "Core theme file is empty: $f"
      fi
      ;;
  esac
done

pgn_count=$(count_pgn_tokens "$THEME_DIR/mereka-brand.min.css")
if [[ "$pgn_count" -ge 8 && "$pgn_count" -le 80 ]]; then
  pass "mereka-brand.min.css has ${pgn_count} --pgn-* properties (delta-mode target range 8-80)"
elif [[ "$pgn_count" -gt 80 ]]; then
  warn "mereka-brand.min.css has ${pgn_count} --pgn-* properties (likely bloated; expected delta overrides only)"
else
  fail "mereka-brand.min.css has only ${pgn_count} --pgn-* properties (minimum required for brand delta: 8)"
fi

brand_size=$(wc -c < "$THEME_DIR/mereka-brand.min.css")
if [[ "$brand_size" -le 16384 ]]; then
  pass "mereka-brand.min.css size is ${brand_size} bytes (delta-size budget <=16384)"
else
  warn "mereka-brand.min.css size is ${brand_size} bytes (exceeds delta-size budget; investigate token bloat)"
fi

light_size=$(wc -c < "$THEME_DIR/light.min.css")
if [[ "$light_size" -gt 64 && "$light_size" -le 8192 ]]; then
  pass "light.min.css size is ${light_size} bytes (light-delta budget <=8192)"
elif [[ "$light_size" -gt 8192 ]]; then
  fail "light.min.css is bloated (${light_size} bytes; expected <=8192 for light delta)"
else
  fail "light.min.css is unexpectedly small (${light_size} bytes)"
fi

if cmp -s "$THEME_DIR/core.min.css" "$THEME_DIR/light.min.css"; then
  fail "light.min.css must differ from core.min.css (core/light payload collapse detected)"
else
  pass "light.min.css differs from core.min.css (delta contract preserved)"
fi

if cmp -s "$THEME_DIR/mereka-brand.min.css" "$THEME_DIR/mereka-brand-light.min.css"; then
  pass "mereka-brand-light.min.css is byte-identical to mereka-brand.min.css"
else
  fail "mereka-brand-light.min.css differs from mereka-brand.min.css (unexpected drift)"
fi

echo ""
echo "2b) Token compilation hook presence"
if [[ -x "$BUILD_TOKENS_SCRIPT" ]]; then
  pass "AC-TKN-033 build token script exists and is executable"
else
  fail "AC-TKN-033 missing executable token build script: scripts/branding/build-tokens.sh"
fi

if [[ -f "$APPLY_PATCHES" ]]; then
  if grep -q "apply_brand_package_patch" "$APPLY_PATCHES"; then
    pass "AC-TKN-034 apply-patches includes branding patch execution"
  else
    fail "AC-TKN-034 apply-patches missing brand patch execution"
  fi
else
  fail "AC-TKN-034 missing infrastructure/tutor/apply-patches.sh"
fi

echo ""
echo "3) Caddy route for /theme/*"
if [[ ! -f "$CADDY_FILE" ]]; then
  fail "Caddyfile missing: deploy/k8s/base/plugins/mfe/apps/mfe/Caddyfile"
else
  if rg -n -e "@mfe_theme_assets" -e "path /theme/\\*" "$CADDY_FILE" >/dev/null; then
    pass "Caddyfile has /theme/* static route"
  else
    fail "Caddyfile missing /theme/* static route for runtime theme assets"
  fi

  if rg -n "try_files .*/authn\\{path\\}" "$CADDY_FILE" >/dev/null; then
    pass "Caddy /theme/* handler uses cross-MFE try_files fallback"
  else
    fail "Caddy /theme/* handler missing cross-MFE try_files fallback"
  fi

  if rg -n "try_files /theme\\{path\\}" "$CADDY_FILE" >/dev/null; then
    pass "Caddy /theme/* handler checks /theme{path} first (runtime min.css root)"
  else
    fail "Caddy /theme/* handler missing /theme{path} first-hop check"
  fi

  if rg -n 'header Content-Type "text/css; charset=utf-8"' "$CADDY_FILE" >/dev/null; then
    pass "Caddy /theme/* handler sets CSS content-type header"
  else
    fail "Caddy /theme/* handler missing explicit CSS content-type header"
  fi

  if rg -n 'header Cache-Control "public, max-age=' "$CADDY_FILE" >/dev/null; then
    pass "Caddy /theme/* handler sets explicit cache-control header"
  else
    fail "Caddy /theme/* handler missing explicit cache-control header"
  fi
fi

echo ""
echo "4) Optional sanity: MFE route tokens"
if [[ "$(mereka_plugin_count_regex "$REPO_ROOT" "MEREKA_PARAGON_THEME_CDN_BASE")" -gt 0 ]]; then
  pass "Token base variable referenced in plugin: MEREKA_PARAGON_THEME_CDN_BASE"
else
  fail "MEREKA_PARAGON_THEME_CDN_BASE not referenced in plugin"
fi

echo ""
echo "=== Summary ==="
echo "PASS=$PASS WARN=$WARN FAIL=$FAIL"

if [[ "$FAIL" -ne 0 ]]; then
  exit 1
fi

exit 0
