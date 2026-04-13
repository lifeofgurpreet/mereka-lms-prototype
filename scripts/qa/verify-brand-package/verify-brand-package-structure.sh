#!/usr/bin/env bash
# @covers AC-BRAND-001, AC-BRAND-002, AC-BRAND-003, AC-BRAND-004, AC-BRAND-005
# @covers AC-BRAND-006, AC-BRAND-007, AC-BRAND-008, AC-BRAND-009, AC-BRAND-010
# @covers AC-BRAND-011, AC-BRAND-012, AC-BRAND-013, AC-BRAND-014, AC-BRAND-015
# @covers AC-BRAND-016, AC-BRAND-017, AC-BRAND-018, AC-BRAND-019, AC-BRAND-020
# @covers AC-BRAND-021, AC-BRAND-022
# @covers AC-BRAND-023, AC-BRAND-026, AC-BRAND-027, AC-BRAND-028
# @spec: oep48-brand-package_spec.md
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
source "$REPO_ROOT/scripts/shared/mereka_plugin_contract.sh"
PLUGIN_MAIN="$(mereka_plugin_main_file "$REPO_ROOT")"
BRAND_DIR="$REPO_ROOT/infrastructure/tutor/brand-mereka"
VARIABLES_FILE="$BRAND_DIR/paragon/_variables.scss"
TOKENS_JSON="$BRAND_DIR/paragon/tokens.json"
FONTS_SCSS="$BRAND_DIR/paragon/_fonts.scss"
PACKAGE_JSON="$BRAND_DIR/package.json"
PLUGIN_FILE="$PLUGIN_MAIN"
CI_STATIC_LIST="$REPO_ROOT/.github/ci-scripts-static.txt"
TOKENS_CSS="$REPO_ROOT/assets/branding/tokens.css"
THEME_IMAGES_DIR="$REPO_ROOT/infrastructure/tutor/themes/mereka/lms/static/images"
THEME_FONTS_DIR="$REPO_ROOT/infrastructure/tutor/themes/mereka/lms/static/fonts"

PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); echo "PASS: $*"; }
fail() { FAIL=$((FAIL + 1)); echo "FAIL: $*"; }

required_files=(
  "$BRAND_DIR/package.json"
  "$BRAND_DIR/logo.js"
  "$BRAND_DIR/logo.svg"
  "$BRAND_DIR/logo-white.svg"
  "$BRAND_DIR/logo_white.svg"
  "$BRAND_DIR/logo-trademark.svg"
  "$BRAND_DIR/logo.png"
  "$BRAND_DIR/logo-white.png"
  "$BRAND_DIR/logo_white.png"
  "$BRAND_DIR/logo-trademark.png"
  "$BRAND_DIR/favicon.ico"
  "$BRAND_DIR/favicon.png"
  "$BRAND_DIR/paragon/_fonts.scss"
  "$BRAND_DIR/paragon/core.scss"
  "$BRAND_DIR/paragon/_overrides.scss"
  "$BRAND_DIR/paragon/_variables.scss"
  "$BRAND_DIR/paragon/tokens.json"
  "$BRAND_DIR/paragon/images/card-imagecap-fallback.png"
)

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

canonical_magenta="$(python3 - "$TOKENS_CSS" <<'PY'
from pathlib import Path
import re
import sys
text = Path(sys.argv[1]).read_text(encoding='utf-8')
m = re.search(r"--color-magenta:\s*(#[0-9A-Fa-f]{6})\s*;", text)
if not m:
    raise SystemExit(1)
print(m.group(1).lower())
PY
)"

canonical_teal="$(python3 - "$TOKENS_CSS" <<'PY'
from pathlib import Path
import re
import sys
text = Path(sys.argv[1]).read_text(encoding='utf-8')
m = re.search(r"--color-teal:\s*(#[0-9A-Fa-f]{6})\s*;", text)
if not m:
    raise SystemExit(1)
print(m.group(1).lower())
PY
)"

echo "=== OEP-48 Brand Package Structure Verification ==="

# AC-BRAND-NFR-001 package size
if [[ -d "$BRAND_DIR" ]]; then
  package_kb="$(du -sk "$BRAND_DIR" | awk '{print $1}')"
  if [[ "$package_kb" -lt 3072 ]]; then
    pass "AC-BRAND-NFR-001 package size is ${package_kb}KB (<3072KB)"
  else
    fail "AC-BRAND-NFR-001 package size is ${package_kb}KB (>=3072KB)"
  fi
fi

# AC-BRAND-026 and AC-BRAND-027: required file presence + non-zero failure behavior
missing_required=0
for file in "${required_files[@]}"; do
  if [[ -f "$file" ]]; then
    pass "AC-BRAND-026 required file exists: ${file#$REPO_ROOT/}"
  else
    missing_required=1
    fail "AC-BRAND-026 missing required file: ${file#$REPO_ROOT/}"
  fi
done
if [[ "$missing_required" -eq 0 ]]; then
  pass "AC-BRAND-027 verifier remains green when required files exist"
else
  fail "AC-BRAND-027 verifier will fail non-zero on missing required files"
fi

# AC-BRAND-001: exact package structure
if [[ -d "$BRAND_DIR" ]]; then
  actual_files="$(find "$BRAND_DIR" -type f | sed "s#^$BRAND_DIR/##" | LC_ALL=C sort)"
  expected_files="$( (cat <<'LIST'
dist/css/.gitkeep
dist/tokens/.gitkeep
favicon.ico
favicon.png
fonts/Lato-Black.woff2
fonts/Lato-BlackItalic.woff2
fonts/Lato-Bold.woff2
fonts/Lato-BoldItalic.woff2
fonts/Lato-Italic.woff2
fonts/Lato-Regular.woff2
fonts/Poppins-Bold.woff2
fonts/Poppins-Regular.woff2
fonts/Poppins-SemiBold.woff2
logo-white.png
logo-white.svg
logo.js
logo-trademark.png
logo-trademark.svg
logo.png
logo.svg
logo_white.png
logo_white.svg
package.json
paragon/_fonts.scss
paragon/_overrides.scss
paragon/_variables.scss
paragon/core.scss
paragon/images/card-imagecap-fallback.png
paragon/tokens.json
tokens/src/core/global/color.json
tokens/src/core/global/typography.json
tokens/src/themes/light/global/color.json
LIST
) | LC_ALL=C sort)"
  if [[ "$actual_files" == "$expected_files" ]]; then
    pass "AC-BRAND-001 exact expected file structure present"
  else
    fail "AC-BRAND-001 file structure mismatch (missing/extra files)"
  fi
else
  fail "AC-BRAND-001 brand directory missing"
fi

# AC-BRAND-002 and AC-BRAND-003: package.json metadata
if [[ -f "$PACKAGE_JSON" ]]; then
  if python3 - "$PACKAGE_JSON" <<'PY'
import json
from pathlib import Path
import re
import sys
pkg = json.loads(Path(sys.argv[1]).read_text(encoding='utf-8'))
if pkg.get('name') != '@edx/brand-mereka':
    raise SystemExit(2)
if not re.match(r'^\d+\.\d+\.\d+$', str(pkg.get('version', ''))):
    raise SystemExit(3)
deps = pkg.get('dependencies')
if deps not in (None, {}):
    raise SystemExit(4)
desc = str(pkg.get('description', '')).strip().lower()
if not desc or ('mereka' not in desc and 'oep-48' not in desc):
    raise SystemExit(5)
PY
  then
    pass "AC-BRAND-002 package.json name/version/dependencies contract passes"
    pass "AC-BRAND-003 package.json description contract passes"
    pass "AC-BRAND-NFR-003 package has no runtime JS dependencies"
  else
    fail "AC-BRAND-002/003 package.json metadata contract failed"
  fi
fi

# AC-BRAND-004 / 005: SVG validity constraints
if [[ -f "$BRAND_DIR/logo.svg" ]]; then
  if grep -qi 'viewBox=' "$BRAND_DIR/logo.svg"; then
    pass "AC-BRAND-004 logo.svg contains viewBox"
  else
    fail "AC-BRAND-004 logo.svg missing viewBox"
  fi
  if grep -qi '<image' "$BRAND_DIR/logo.svg" && grep -qi 'base64,' "$BRAND_DIR/logo.svg"; then
    fail "AC-BRAND-004 logo.svg contains embedded base64 image"
  else
    pass "AC-BRAND-004 logo.svg has no embedded base64 image"
  fi
fi

if [[ -f "$BRAND_DIR/logo-white.svg" ]]; then
  if grep -qi 'viewBox=' "$BRAND_DIR/logo-white.svg"; then
    pass "AC-BRAND-005 logo-white.svg contains viewBox"
  else
    fail "AC-BRAND-005 logo-white.svg missing viewBox"
  fi
fi

# AC-BRAND-006 / 007 / 008 image/icon type checks
# Use magic bytes via python3 as primary check — ARC runner `file` may lack
# full magic db and grep on binary data is unreliable across implementations.
is_png() { python3 -c "import sys; sys.exit(0 if open(sys.argv[1],'rb').read(8)[:4]==b'\\x89PNG' else 1)" "$1" 2>/dev/null || file "$1" | grep -qi 'PNG image data'; }
is_ico() { python3 -c "import sys; sys.exit(0 if open(sys.argv[1],'rb').read(4)==b'\\x00\\x00\\x01\\x00' else 1)" "$1" 2>/dev/null || file "$1" | grep -Eqi 'icon|MS Windows icon'; }

if [[ -f "$BRAND_DIR/logo.png" ]]; then
  if is_png "$BRAND_DIR/logo.png"; then
    pass "AC-BRAND-006 logo.png is valid PNG"
  else
    fail "AC-BRAND-006 logo.png is not valid PNG"
  fi
  width="$(python3 - "$BRAND_DIR/logo.png" <<'PY'
from pathlib import Path
import struct
import sys
b = Path(sys.argv[1]).read_bytes()
if b[:8] != b'\x89PNG\r\n\x1a\n':
    raise SystemExit(2)
print(struct.unpack('>I', b[16:20])[0])
PY
)"
  if [[ "$width" -ge 200 ]]; then
    pass "AC-BRAND-006 logo.png width >= 200px (${width}px)"
  else
    fail "AC-BRAND-006 logo.png width < 200px (${width}px)"
  fi
fi

if [[ -f "$BRAND_DIR/logo-white.png" ]]; then
  if is_png "$BRAND_DIR/logo-white.png"; then
    pass "AC-BRAND-007 logo-white.png is valid PNG"
  else
    fail "AC-BRAND-007 logo-white.png is not valid PNG"
  fi
fi

if [[ -f "$BRAND_DIR/favicon.ico" ]]; then
  if is_ico "$BRAND_DIR/favicon.ico"; then
    pass "AC-BRAND-008 favicon.ico is valid icon resource"
  else
    fail "AC-BRAND-008 favicon.ico is not recognized as icon resource"
  fi
fi

# AC-BRAND-009 / AC-BRAND-INT-001 logo parity with LMS theme source
logo_parity_ok=1
for asset in logo.svg logo-white.svg logo.png logo-white.png favicon.ico; do
  src="$THEME_IMAGES_DIR/$asset"
  dst="$BRAND_DIR/$asset"
  if [[ ! -f "$src" || ! -f "$dst" ]]; then
    logo_parity_ok=0
    fail "AC-BRAND-009 missing source/target for parity: $asset"
    continue
  fi
  ssha="$(sha256sum "$src" | awk '{print $1}')"
  dsha="$(sha256sum "$dst" | awk '{print $1}')"
  if [[ "$ssha" != "$dsha" ]]; then
    logo_parity_ok=0
    fail "AC-BRAND-009 sha mismatch: $asset"
  fi
done
if [[ "$logo_parity_ok" -eq 1 ]]; then
  pass "AC-BRAND-009 brand logos/icons are byte-identical to LMS theme sources"
  pass "AC-BRAND-INT-001 brand package logo copies are consistent with LMS theme"
fi

# AC-BRAND-009 alias parity checks (underscore and favicon.png aliases)
if [[ -f "$BRAND_DIR/logo-white.png" && -f "$BRAND_DIR/logo_white.png" ]]; then
  if cmp -s "$BRAND_DIR/logo-white.png" "$BRAND_DIR/logo_white.png"; then
    pass "AC-BRAND-009 logo_white.png alias matches logo-white.png"
  else
    fail "AC-BRAND-009 logo_white.png alias does not match logo-white.png"
  fi
fi
if [[ -f "$BRAND_DIR/logo-white.svg" && -f "$BRAND_DIR/logo_white.svg" ]]; then
  if cmp -s "$BRAND_DIR/logo-white.svg" "$BRAND_DIR/logo_white.svg"; then
    pass "AC-BRAND-009 logo_white.svg alias matches logo-white.svg"
  else
    fail "AC-BRAND-009 logo_white.svg alias does not match logo-white.svg"
  fi
fi
if [[ -f "$THEME_IMAGES_DIR/favicon-256x256.png" && -f "$BRAND_DIR/favicon.png" ]]; then
  if cmp -s "$THEME_IMAGES_DIR/favicon-256x256.png" "$BRAND_DIR/favicon.png"; then
    pass "AC-BRAND-009 favicon.png alias matches theme favicon-256x256.png"
  else
    fail "AC-BRAND-009 favicon.png alias does not match theme favicon-256x256.png"
  fi
fi

# AC-BRAND-003/compat: logo.js exports canonical assets for @edx/brand consumers
if [[ -f "$BRAND_DIR/logo.js" ]]; then
  if grep -q "logo_white.png" "$BRAND_DIR/logo.js" \
    && grep -q "logo-trademark.png" "$BRAND_DIR/logo.js" \
    && grep -q "favicon.png" "$BRAND_DIR/logo.js"; then
    pass "AC-BRAND-003 logo.js exports canonical logo/favicons"
  else
    fail "AC-BRAND-003 logo.js missing one or more canonical exports"
  fi
fi

# AC-BRAND-010 exact font inventory
if [[ -d "$BRAND_DIR/fonts" ]]; then
  actual_fonts="$(find "$BRAND_DIR/fonts" -maxdepth 1 -type f -name '*.woff2' -printf '%f\n' | LC_ALL=C sort)"
  expected_fonts_sorted="$(printf '%s\n' "${expected_fonts[@]}" | LC_ALL=C sort)"
  if [[ "$actual_fonts" == "$expected_fonts_sorted" ]]; then
    pass "AC-BRAND-010 fonts directory contains exact expected 9-file set"
  else
    fail "AC-BRAND-010 fonts directory differs from expected 9-file set"
  fi
fi

# AC-BRAND-011: woff2 file type verification
# Use magic bytes (wOF2) as primary check — `file` on minimal CI runners may
# lack the WOFF2 magic database entry.
for font in "${expected_fonts[@]}"; do
  f="$BRAND_DIR/fonts/$font"
  if [[ ! -f "$f" ]]; then
    fail "AC-BRAND-011 missing WOFF2 file: $font"
  elif python3 -c "import sys; sys.exit(0 if open(sys.argv[1],'rb').read(4)==b'wOF2' else 1)" "$f" 2>/dev/null \
       || file "$f" | grep -qi 'Web Open Font Format'; then
    pass "AC-BRAND-011 valid WOFF2 file: $font"
  else
    fail "AC-BRAND-011 invalid WOFF2 file: $font (no wOF2 magic)"
  fi
done

# AC-BRAND-012 / AC-BRAND-INT-002 font parity with LMS theme source
font_parity_ok=1
for font in "${expected_fonts[@]}"; do
  src="$THEME_FONTS_DIR/$font"
  dst="$BRAND_DIR/fonts/$font"
  if [[ ! -f "$src" || ! -f "$dst" ]]; then
    font_parity_ok=0
    fail "AC-BRAND-012 missing source/target for font parity: $font"
    continue
  fi
  ssha="$(sha256sum "$src" | awk '{print $1}')"
  dsha="$(sha256sum "$dst" | awk '{print $1}')"
  if [[ "$ssha" != "$dsha" ]]; then
    font_parity_ok=0
    fail "AC-BRAND-012 sha mismatch: $font"
  fi
done
if [[ "$font_parity_ok" -eq 1 ]]; then
  pass "AC-BRAND-012 brand fonts are byte-identical to LMS theme sources"
  pass "AC-BRAND-INT-002 brand package font copies are consistent with LMS theme"
fi

# AC-BRAND-013 / 014 / 015 / 016 _fonts.scss contracts
if [[ -f "$FONTS_SCSS" ]]; then
  ff_count="$(grep -c '@font-face' "$FONTS_SCSS" || true)"
  if [[ "$ff_count" -ge 9 ]]; then
    pass "AC-BRAND-013 _fonts.scss has >=9 @font-face declarations"
  else
    fail "AC-BRAND-013 _fonts.scss has <9 @font-face declarations (${ff_count})"
  fi

  swap_count="$(grep -c 'font-display:\s*swap' "$FONTS_SCSS" || true)"
  if [[ "$swap_count" -ge 9 ]]; then
    pass "AC-BRAND-014 _fonts.scss applies font-display: swap"
  else
    fail "AC-BRAND-014 _fonts.scss missing font-display: swap in one or more faces"
  fi

  src_ok=1
  for font in "${expected_fonts[@]}"; do
    if ! grep -qF "../fonts/$font" "$FONTS_SCSS"; then
      src_ok=0
      fail "AC-BRAND-015 _fonts.scss missing src for ../fonts/$font"
    fi
  done
  if [[ "$src_ok" -eq 1 ]]; then
    pass "AC-BRAND-015 _fonts.scss src paths map to existing ../fonts assets"
  fi

  if grep -Eqi 'googleapis\.com|gstatic\.com|typekit\.net|https?://' "$FONTS_SCSS"; then
    fail "AC-BRAND-016 _fonts.scss contains external URL/CDN reference"
  else
    pass "AC-BRAND-016 _fonts.scss has no external font CDN references"
  fi
fi

# AC-BRAND-017 / 018 / 019 / INT-004 variable contracts
# Note: _variables.scss may use either:
#   - Old format: literal hex values (e.g. $primary: #ab3b78 !default)
#   - New format: CSS custom property references (e.g. $primary: var(--pgn-color-primary-base) !default)
# Both formats are valid. New format delegates token values to tokens.json / tokens.css.
if [[ -f "$VARIABLES_FILE" ]]; then
  # AC-BRAND-017: font-family-sans-serif references Poppins literally OR delegates to pgn token
  if grep -Eiq '^\s*\$font-family-sans-serif:.*poppins' "$VARIABLES_FILE" \
    || grep -Eiq '^\s*\$font-family-sans-serif:.*var\(--pgn-' "$VARIABLES_FILE"; then
    pass "AC-BRAND-017 _variables.scss font-family-sans-serif contains Poppins or pgn token reference"
  else
    fail "AC-BRAND-017 _variables.scss font-family-sans-serif missing Poppins or pgn token reference"
  fi

  # AC-BRAND-018: $primary either matches canonical hex OR delegates to pgn primary token
  if grep -Eiq "^\s*\\\$primary:\s*${canonical_magenta}\s*!default;" "$VARIABLES_FILE" \
    || grep -Eiq '^\s*\$primary:\s*var\(--pgn-color-primary' "$VARIABLES_FILE"; then
    pass "AC-BRAND-018 _variables.scss primary matches canonical magenta or pgn token (${canonical_magenta})"
  else
    fail "AC-BRAND-018 _variables.scss primary mismatch (expected ${canonical_magenta} or var(--pgn-color-primary-*))"
  fi

  # AC-BRAND-019: deprecation note present OR file uses var() token references (new format)
  if { grep -qi 'deprecated' "$VARIABLES_FILE" && grep -qi 'tokens\.json' "$VARIABLES_FILE"; } \
    || grep -qi 'var(--pgn-' "$VARIABLES_FILE"; then
    pass "AC-BRAND-019 _variables.scss contains deprecation note or pgn token references"
  else
    fail "AC-BRAND-019 _variables.scss missing deprecation note or pgn token references"
  fi

  # AC-BRAND-INT-004: $primary traces back to canonical magenta (hex or pgn token)
  if grep -Eiq "^\s*\\\$primary:\s*${canonical_magenta}\s*!default;" "$VARIABLES_FILE" \
    || grep -Eiq '^\s*\$primary:\s*var\(--pgn-color-primary' "$VARIABLES_FILE"; then
    pass "AC-BRAND-INT-004 _variables primary aligns with assets/branding --color-magenta or pgn token"
  else
    fail "AC-BRAND-INT-004 _variables primary does not align with assets/branding --color-magenta"
  fi
fi

# AC-BRAND-020 / 021 / 022 / INT-003 tokens.json contracts
# Supports two formats:
#   Legacy format:  { "colors": { "primary": "#ab3b78" }, "typography": { "font-family-sans-serif": "Poppins, ..." } }
#   DTCG format:    { "color": { "primary": { "$value": "#ab3b78" } }, "fontFamily": { "sans-serif": { "$value": "..." } } }
if [[ -f "$TOKENS_JSON" ]]; then
  if python3 - "$TOKENS_JSON" "$canonical_magenta" <<'PY'
import json
from pathlib import Path
import sys

tokens = json.loads(Path(sys.argv[1]).read_text(encoding='utf-8'))
canonical = sys.argv[2].lower()

def extract_value(node):
    """Return the string value from a DTCG token node or a plain string."""
    if isinstance(node, dict):
        return str(node.get('$value', '')).lower()
    return str(node).lower()

# Locate primary color — support legacy 'colors' and DTCG 'color' keys
primary_val = None
if 'colors' in tokens and 'primary' in tokens['colors']:
    primary_val = extract_value(tokens['colors']['primary'])
elif 'color' in tokens and 'primary' in tokens['color']:
    primary_val = extract_value(tokens['color']['primary'])

if primary_val is None:
    raise SystemExit(2)
if primary_val != canonical:
    raise SystemExit(3)

# Locate font-family — support legacy 'typography' and DTCG 'fontFamily' keys
font_val = None
if 'typography' in tokens and 'font-family-sans-serif' in tokens['typography']:
    font_val = extract_value(tokens['typography']['font-family-sans-serif'])
elif 'fontFamily' in tokens and 'sans-serif' in tokens['fontFamily']:
    font_val = extract_value(tokens['fontFamily']['sans-serif'])

if font_val is None:
    raise SystemExit(4)
if 'poppins' not in font_val:
    raise SystemExit(5)
PY
  then
    pass "AC-BRAND-020 tokens.json is valid and contains primary color"
    pass "AC-BRAND-021 tokens.json primary color matches canonical magenta"
    pass "AC-BRAND-022 tokens.json font-family-sans-serif contains Poppins"
    pass "AC-BRAND-INT-003 tokens.json primary aligns with canonical tokens.css"
  else
    fail "AC-BRAND-020/021/022 tokens.json contract failed"
  fi
fi

# AC-BRAND-023 Tutor build integration contract
# Brand COPY + npm alias are handled by the Tutor plugin module.
# Search both the main plugin file and the MFE Dockerfile submodule.
PLUGIN_DIR="$(dirname "$PLUGIN_FILE")"
BRAND_SEARCH_FILES=("$PLUGIN_FILE")
[[ -f "$PLUGIN_DIR/_mereka_lms/mfe_dockerfile.py" ]] && BRAND_SEARCH_FILES+=("$PLUGIN_DIR/_mereka_lms/mfe_dockerfile.py")

BRAND_COPY_FOUND=0
BRAND_ALIAS_FOUND=0
for f in "${BRAND_SEARCH_FILES[@]}"; do
  [[ -f "$f" ]] || continue
  if grep -q 'brand-mereka' "$f" && grep -q 'COPY' "$f"; then
    BRAND_COPY_FOUND=1
  fi
  if grep -q '@edx/brand@file:./brand-mereka' "$f"; then
    BRAND_ALIAS_FOUND=1
  fi
done

if [[ $BRAND_COPY_FOUND -eq 1 ]]; then
  pass "AC-BRAND-023 build pipeline copies brand package into MFE image"
else
  fail "AC-BRAND-023 plugin/patches missing brand COPY hook"
fi

if [[ $BRAND_ALIAS_FOUND -eq 1 ]]; then
  pass "AC-BRAND-023 build pipeline installs the local brand package via @edx/brand alias"
else
  fail "AC-BRAND-023 plugin/patches missing @edx/brand alias install command"
fi

# AC-BRAND-028 CI wiring
if [[ -f "$CI_STATIC_LIST" ]] && grep -qF 'scripts/qa/verify-brand-package/verify-brand-package-structure.sh' "$CI_STATIC_LIST"; then
  pass "AC-BRAND-028 CI static script list includes brand-package structure verifier"
else
  fail "AC-BRAND-028 CI static script list missing brand-package structure verifier"
fi

echo
echo "=== Summary: PASS=${PASS} FAIL=${FAIL} ==="
if [[ "$FAIL" -gt 0 ]]; then
  exit 1
fi
