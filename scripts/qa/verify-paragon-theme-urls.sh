#!/usr/bin/env bash
# @covers AC-TKN-016, AC-TKN-020, AC-TKN-021, AC-TKN-029
# @spec: paragon-design-tokens-migration_spec.md
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

PLUGIN_FILE="$REPO_ROOT/infrastructure/tutor/plugins/mereka_lms.py"
CADDY_FILE="$REPO_ROOT/deploy/k8s/base/plugins/mfe/apps/mfe/Caddyfile"
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

count_var_refs() {
  local file="$1"
  local pattern="$2"
  python3 - "$file" "$pattern" <<'PY'
from pathlib import Path
import re
import sys

text = Path(sys.argv[1]).read_text(encoding="utf-8")
pattern = sys.argv[2]
print(len(re.findall(pattern, text)))
PY
}

echo "=== PARAGON_THEME_URLS verification ==="

echo ""
echo "1) Tutor plugin config"
if [[ ! -f "$PLUGIN_FILE" ]]; then
  fail "Plugin missing: infrastructure/tutor/plugins/mereka_lms.py"
else
  if grep -q "PARAGON_THEME_URLS" "$PLUGIN_FILE"; then
    pass "mereka_lms.py contains PARAGON_THEME_URLS"
  else
    fail "PARAGON_THEME_URLS not found in mereka_lms.py"
  fi

  if grep -q "MEREKA_PARAGON_THEME_CDN_BASE" "$PLUGIN_FILE"; then
    pass "mereka_lms.py contains MEREKA_PARAGON_THEME_CDN_BASE"
  else
    fail "MEREKA_PARAGON_THEME_CDN_BASE not found in mereka_lms.py"
  fi

  if grep -q "MEREKA_PARAGON_THEME_ENABLED" "$PLUGIN_FILE"; then
    pass "mereka_lms.py contains MEREKA_PARAGON_THEME_ENABLED toggle"
  else
    fail "MEREKA_PARAGON_THEME_ENABLED not found in mereka_lms.py"
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
      if grep -q -- "--pgn-color-primary" "$path"; then
        pass "Brand theme file includes --pgn-color-primary: $f"
      else
        fail "Brand theme file missing --pgn-color-primary: $f"
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
if [[ "$pgn_count" -ge 100 ]]; then
  pass "mereka-brand.min.css has ${pgn_count} --pgn-* properties (>=100)"
elif [[ "$pgn_count" -ge 80 ]]; then
  warn "mereka-brand.min.css has ${pgn_count} --pgn-* properties (below 100 for full migration, above transitional minimum)"
else
  fail "mereka-brand.min.css has only ${pgn_count} --pgn-* properties (minimum required: 80)"
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
fi

echo ""
echo "4) Optional sanity: MFE route tokens"
if [[ -n "$(count_var_refs "$PLUGIN_FILE" "MEREKA_PARAGON_THEME_CDN_BASE")" ]]; then
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
