#!/usr/bin/env bash
# @covers AC-BRAND-018, AC-BRAND-019, AC-BRAND-020, AC-BRAND-021, AC-BRAND-022
# @covers AC-BRAND-023, AC-BRAND-024, AC-BRAND-025, AC-BRAND-026, AC-BRAND-027, AC-BRAND-028
# @covers AC-BRAND-INT-003, AC-BRAND-INT-004
# @spec: oep48-brand-package_spec.md
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
BRAND_DIR="$REPO_ROOT/infrastructure/tutor/brand-mereka"
VARIABLES_FILE="$BRAND_DIR/paragon/_variables.scss"
TOKENS_JSON="$BRAND_DIR/paragon/tokens.json"
FONTS_SCSS="$BRAND_DIR/paragon/fonts.scss"
PLUGIN_FILE="$REPO_ROOT/infrastructure/tutor/plugins/mereka_lms.py"
CI_STATIC_LIST="$REPO_ROOT/.github/ci-scripts-static.txt"
TOKENS_CSS="$REPO_ROOT/assets/branding/tokens.css"

PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); echo "PASS: $*"; }
fail() { FAIL=$((FAIL + 1)); echo "FAIL: $*"; }

require_file() {
  local path="$1"
  local ac="$2"
  if [[ -f "$path" ]]; then
    pass "${ac} file exists: ${path#$REPO_ROOT/}"
  else
    fail "${ac} missing required file: ${path#$REPO_ROOT/}"
  fi
}

canonical_magenta="$(python3 - "$TOKENS_CSS" <<'PY'
from pathlib import Path
import re
import sys

path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8")
match = re.search(r"--color-magenta:\s*(#[0-9A-Fa-f]{6})\s*;", text)
if not match:
    raise SystemExit(1)
print(match.group(1).lower())
PY
)"

echo "=== OEP-48 Brand Package Structure Verification ==="

# AC-BRAND-026 / AC-BRAND-027: structural requirements
for file in \
  "$BRAND_DIR/package.json" \
  "$BRAND_DIR/logo.svg" \
  "$BRAND_DIR/logo-white.svg" \
  "$BRAND_DIR/logo.png" \
  "$BRAND_DIR/logo-white.png" \
  "$BRAND_DIR/favicon.ico" \
  "$BRAND_DIR/paragon/fonts.scss" \
  "$BRAND_DIR/paragon/_variables.scss" \
  "$BRAND_DIR/paragon/tokens.json"
do
  require_file "$file" "AC-BRAND-026"
done

expected_fonts=(
  "Poppins-Regular.woff2"
  "Poppins-SemiBold.woff2"
  "Poppins-Bold.woff2"
  "Lato-Regular.woff2"
  "Lato-Bold.woff2"
  "Lato-Italic.woff2"
  "Lato-BoldItalic.woff2"
  "Lato-Black.woff2"
  "Lato-BlackItalic.woff2"
)

if [[ -d "$BRAND_DIR/fonts" ]]; then
  pass "AC-BRAND-026 fonts directory exists"
else
  fail "AC-BRAND-026 missing fonts directory"
fi

for font in "${expected_fonts[@]}"; do
  require_file "$BRAND_DIR/fonts/$font" "AC-BRAND-026"
done

if [[ -f "$FONTS_SCSS" ]]; then
  font_face_count="$(grep -c '@font-face' "$FONTS_SCSS" || true)"
  if [[ "$font_face_count" -ge 9 ]]; then
    pass "AC-BRAND-026 fonts.scss has >=9 @font-face declarations"
  else
    fail "AC-BRAND-026 fonts.scss has ${font_face_count} @font-face declarations (<9)"
  fi

  swap_count="$(grep -c 'font-display:\s*swap' "$FONTS_SCSS" || true)"
  if [[ "$swap_count" -ge 9 ]]; then
    pass "AC-BRAND-026 fonts.scss uses font-display: swap"
  else
    fail "AC-BRAND-026 fonts.scss missing font-display: swap on one or more faces"
  fi

  if grep -qE "src:\s*url\('\.\./fonts/" "$FONTS_SCSS"; then
    pass "AC-BRAND-026 fonts.scss uses ../fonts relative paths"
  else
    fail "AC-BRAND-026 fonts.scss missing ../fonts relative src paths"
  fi
fi

if [[ -f "$BRAND_DIR/logo.svg" ]]; then
  if grep -qi 'viewBox=' "$BRAND_DIR/logo.svg"; then
    pass "AC-BRAND-026 logo.svg contains viewBox"
  else
    fail "AC-BRAND-026 logo.svg missing viewBox"
  fi
fi

if [[ -f "$BRAND_DIR/logo-white.svg" ]]; then
  if grep -qi 'viewBox=' "$BRAND_DIR/logo-white.svg"; then
    pass "AC-BRAND-026 logo-white.svg contains viewBox"
  else
    fail "AC-BRAND-026 logo-white.svg missing viewBox"
  fi
fi

if [[ -f "$BRAND_DIR/logo.png" ]]; then
  logo_width="$(python3 - "$BRAND_DIR/logo.png" <<'PY'
from pathlib import Path
import struct
import sys

data = Path(sys.argv[1]).read_bytes()
if data[:8] != b"\x89PNG\r\n\x1a\n":
    raise SystemExit(2)
width = struct.unpack(">I", data[16:20])[0]
print(width)
PY
)"
  if [[ "$logo_width" -ge 200 ]]; then
    pass "AC-BRAND-026 logo.png width is ${logo_width}px (>=200)"
  else
    fail "AC-BRAND-026 logo.png width is ${logo_width}px (<200)"
  fi
fi

for woff in "$BRAND_DIR"/fonts/*.woff2; do
  if file "$woff" | grep -q "Web Open Font Format"; then
    pass "AC-BRAND-026 valid woff2: ${woff##*/}"
  else
    fail "AC-BRAND-026 invalid woff2 file type: ${woff##*/}"
  fi
done

# AC-BRAND-018 / AC-BRAND-019 / AC-BRAND-INT-004
if [[ -f "$VARIABLES_FILE" ]]; then
  if grep -Eiq "^\s*\\\$primary:\s*${canonical_magenta}\s*!default;" "$VARIABLES_FILE"; then
    pass "AC-BRAND-018 _variables.scss primary matches canonical magenta (${canonical_magenta})"
  else
    fail "AC-BRAND-018 _variables.scss primary does not match canonical magenta (${canonical_magenta})"
  fi

  if grep -qi "deprecated" "$VARIABLES_FILE" && grep -qi "tokens\\.json" "$VARIABLES_FILE"; then
    pass "AC-BRAND-019 _variables.scss contains deprecation note pointing to tokens.json"
  else
    fail "AC-BRAND-019 _variables.scss missing deprecation note for tokens.json"
  fi
fi

# AC-BRAND-020 / AC-BRAND-021 / AC-BRAND-022 / AC-BRAND-INT-003
if [[ -f "$TOKENS_JSON" ]]; then
  if python3 - "$TOKENS_JSON" "$canonical_magenta" <<'PY'
import json
from pathlib import Path
import sys

tokens = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
canonical = sys.argv[2].lower()

colors = tokens.get("colors", {})
typography = tokens.get("typography", {})

if "primary" not in colors:
    raise SystemExit(2)
if colors.get("primary", "").lower() != canonical:
    raise SystemExit(3)
if "font-family-sans-serif" not in typography:
    raise SystemExit(4)
if "poppins" not in typography["font-family-sans-serif"].lower():
    raise SystemExit(5)
PY
  then
    pass "AC-BRAND-020 tokens.json is valid with required keys"
    pass "AC-BRAND-021 tokens.json colors.primary matches canonical magenta"
    pass "AC-BRAND-022 tokens.json typography font-family-sans-serif contains Poppins"
    pass "AC-BRAND-INT-003 tokens.json primary aligns with assets/branding/tokens.css"
  else
    fail "AC-BRAND-020/021/022 tokens.json validation failed"
  fi
fi

# AC-BRAND-023 / AC-BRAND-024 / AC-BRAND-025
if [[ -f "$PLUGIN_FILE" ]]; then
  if grep -q "mfe-dockerfile-pre-npm-install" "$PLUGIN_FILE" \
    && grep -q "COPY indigo/brand-mereka /openedx/app/brand-mereka" "$PLUGIN_FILE"; then
    pass "AC-BRAND-023 Tutor plugin includes brand-mereka copy pre-npm hook"
  else
    fail "AC-BRAND-023 Tutor plugin missing brand-mereka copy pre-npm hook"
  fi

  if grep -q "npm install --legacy-peer-deps @edx/brand@file:\./brand-mereka" "$PLUGIN_FILE"; then
    pass "AC-BRAND-024 Tutor plugin installs @edx/brand alias to brand-mereka"
    pass "AC-BRAND-025 Tutor plugin uses --legacy-peer-deps to avoid peer conflicts"
  else
    fail "AC-BRAND-024/025 Tutor plugin missing npm alias install with --legacy-peer-deps"
  fi
fi

# AC-BRAND-028
if [[ -f "$CI_STATIC_LIST" ]] && grep -qF "scripts/qa/verify-brand-package/verify-brand-package-structure.sh" "$CI_STATIC_LIST"; then
  pass "AC-BRAND-028 CI static script list includes brand-package structure verifier"
else
  fail "AC-BRAND-028 CI static script list missing brand-package structure verifier"
fi

echo ""
echo "=== Summary: PASS=${PASS} FAIL=${FAIL} ==="
if [[ "$FAIL" -gt 0 ]]; then
  exit 1
fi
