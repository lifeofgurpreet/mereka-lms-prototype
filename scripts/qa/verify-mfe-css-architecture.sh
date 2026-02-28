#!/usr/bin/env bash
# @spec: paragon-design-tokens-migration_spec.md
#
# Verify Phase C architecture invariants:
# 1) MFE stylesheet does not import monolithic theme.scss
# 2) Tokens file is token-only (:root + variable declarations; no style selectors)
# 3) MFE stylesheet does not leak legacy LMS/Studio selectors
# 4) No runtime wiring depends on @edx/brand SCSS in Ulmo
# 5) @edx/brand package contract is asset-only (no SCSS build/runtime surface)

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASS=0
FAIL=0
WARN=0

pass() { echo -e "${GREEN}[PASS]${NC} $1"; PASS=$((PASS + 1)); }
fail() { echo -e "${RED}[FAIL]${NC} $1"; FAIL=$((FAIL + 1)); }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; WARN=$((WARN + 1)); }

MFE_SCSS="$REPO_ROOT/infrastructure/tutor/themes/mereka/mfe/mereka.scss"
TOKENS_SCSS="$REPO_ROOT/infrastructure/tutor/themes/mereka/scss/_tokens.scss"
PLUGIN_FILE="$REPO_ROOT/infrastructure/tutor/plugins/mereka_lms.py"
PATCHES_DIR="$REPO_ROOT/infrastructure/tutor/patches"
BRAND_PACKAGE_JSON="$REPO_ROOT/infrastructure/tutor/brand-mereka/package.json"

echo "=== MFE CSS Architecture Verification ==="
echo ""

if [[ ! -f "$MFE_SCSS" ]]; then
  fail "MFE stylesheet missing: $MFE_SCSS"
fi
if [[ ! -f "$TOKENS_SCSS" ]]; then
  fail "Tokens stylesheet missing: $TOKENS_SCSS"
fi
if [[ ! -f "$PLUGIN_FILE" ]]; then
  fail "Tutor plugin missing: $PLUGIN_FILE"
fi
if [[ ! -f "$BRAND_PACKAGE_JSON" ]]; then
  fail "Brand package manifest missing: $BRAND_PACKAGE_JSON"
fi

echo "--- Check 1: MFE import boundary (no monolithic theme.scss) ---"
if grep -Eq '@import[[:space:]]+["'"'"']\./scss/theme["'"'"']' "$MFE_SCSS"; then
  fail "mereka.scss imports ./scss/theme (dead LMS/Studio CSS leakage risk)"
else
  pass "mereka.scss does not import ./scss/theme"
fi

if grep -Eq '@import[[:space:]]+["'"'"']\./scss/fonts["'"'"']' "$MFE_SCSS" \
  && grep -Eq '@import[[:space:]]+["'"'"']\./scss/tokens["'"'"']' "$MFE_SCSS"; then
  pass "mereka.scss imports explicit fonts + tokens partials"
else
  fail "mereka.scss must import ./scss/fonts and ./scss/tokens explicitly"
fi

echo "--- Check 2: _tokens.scss remains token-only ---"
if grep -q "BEGIN GENERATED — DO NOT EDIT" "$TOKENS_SCSS" \
  && grep -q "END GENERATED" "$TOKENS_SCSS"; then
  pass "_tokens.scss has generation markers"
else
  fail "_tokens.scss missing generation markers"
fi

TOKENS_STYLE_VIOLATIONS="$(python3 - "$REPO_ROOT" <<'PY'
import re, sys
from pathlib import Path

path = Path(sys.argv[1]) / "infrastructure/tutor/themes/mereka/scss/_tokens.scss"
text = path.read_text(encoding="utf-8").splitlines()
violations = []

for i, raw in enumerate(text, start=1):
    line = raw.strip()
    if not line:
        continue
    if line.startswith("//") or line.startswith("/*") or line.startswith("*"):
        continue
    if line.startswith("$") or line.startswith("--"):
        continue
    if line in ("{", "}", ");"):
        continue
    if line.startswith(":root"):
        continue
    if line.startswith("@import") or line.startswith("@use") or line.startswith("@forward"):
        continue
    if re.match(r"^[a-zA-Z0-9_-]+\s*:\s*.+;?$", line):
        # CSS property declarations inside :root and SCSS maps.
        continue
    if "{" in line:
        selector = line.split("{", 1)[0].strip()
        if selector and selector != ":root":
            violations.append((i, selector))

if violations:
    print("\n".join(f"{ln}:{sel}" for ln, sel in violations))
PY
)"

if [[ -z "$TOKENS_STYLE_VIOLATIONS" ]]; then
  pass "_tokens.scss contains only variables/properties (:root + declarations)"
else
  fail "_tokens.scss has style selectors (should be token-only):"
  while IFS= read -r line; do
    [[ -n "$line" ]] && echo "  - $line"
  done <<< "$TOKENS_STYLE_VIOLATIONS"
fi

echo "--- Check 3: No legacy LMS/Studio selectors in MFE stylesheet ---"
LEGACY_SELECTOR_HITS="$(python3 - "$REPO_ROOT" <<'PY'
import re, sys
from pathlib import Path

path = Path(sys.argv[1]) / "infrastructure/tutor/themes/mereka/mfe/mereka.scss"
patterns = (
    r"\.dashboard\b",
    r"\.listing-courses\b",
    r"\.courseware\b",
    r"\.xblock\b",
    r"\.wrapper-view\b",
    r"\.view-outline\b",
    r"\.global-header\b",
)
rx = re.compile("|".join(patterns))
hits = []
for i, raw in enumerate(path.read_text(encoding="utf-8").splitlines(), start=1):
    s = raw.strip()
    if not s or s.startswith("//") or s.startswith("/*") or s.startswith("*"):
        continue
    if rx.search(s):
        hits.append(f"{i}:{s}")

if hits:
    print("\n".join(hits))
PY
)"

if [[ -z "$LEGACY_SELECTOR_HITS" ]]; then
  pass "No legacy LMS/Studio selector leakage in mereka.scss"
else
  fail "Legacy LMS/Studio selectors detected in mereka.scss:"
  while IFS= read -r line; do
    [[ -n "$line" ]] && echo "  - $line"
  done <<< "$LEGACY_SELECTOR_HITS"
fi

echo "--- Check 4: Ulmo runtime path does not depend on @edx/brand SCSS imports ---"
BRAND_SCSS_IMPORTS="$(rg -n '@edx/brand/paragon/(fonts|_?variables|_?overrides|core)' \
  "$PLUGIN_FILE" "$PATCHES_DIR" 2>/dev/null || true)"

if [[ -z "$BRAND_SCSS_IMPORTS" ]]; then
  pass "No plugin/patch wiring relies on @edx/brand SCSS imports"
else
  fail "Found @edx/brand SCSS wiring references (asset-only brand package expected):"
  while IFS= read -r line; do
    [[ -n "$line" ]] && echo "  - $line"
  done <<< "$BRAND_SCSS_IMPORTS"
fi

echo "--- Check 5: @edx/brand package manifest is asset-only ---"
ASSET_ONLY_CONTRACT_RESULT="$(python3 - "$BRAND_PACKAGE_JSON" <<'PY'
import json
from pathlib import Path
import sys

manifest = Path(sys.argv[1])
pkg = json.loads(manifest.read_text(encoding="utf-8"))

allowed_exports = {
    ".",
    "./logo.js",
    "./logo.svg",
    "./logo.png",
    "./logo-white.svg",
    "./logo-white.png",
    "./logo_white.svg",
    "./logo_white.png",
    "./logo-trademark.svg",
    "./logo-trademark.png",
    "./favicon.ico",
    "./favicon.png",
}

errors = []

exports = pkg.get("exports")
if not isinstance(exports, dict):
    errors.append("missing/invalid exports map")
else:
    keys = set(exports.keys())
    if keys != allowed_exports:
        errors.append(f"exports keys mismatch (found {sorted(keys)})")
    if any(key.startswith("./paragon/") for key in keys):
        errors.append("paragon/* exports present (asset-only contract violated)")

if "scripts" in pkg:
    errors.append("package.json contains scripts (build contract should be asset-only)")
if "peerDependencies" in pkg:
    errors.append("package.json contains peerDependencies (asset-only contract)")
if pkg.get("dependencies") not in ({}, None):
    errors.append("dependencies must be empty/absent")

if errors:
    print("\n".join(errors))
PY
)"

if [[ -z "$ASSET_ONLY_CONTRACT_RESULT" ]]; then
  pass "@edx/brand package manifest is asset-only and explicitly exported"
else
  fail "Asset-only package contract check failed:"
  while IFS= read -r line; do
    [[ -n "$line" ]] && echo "  - $line"
  done <<< "$ASSET_ONLY_CONTRACT_RESULT"
fi

echo ""
echo "PASS: $PASS | FAIL: $FAIL | WARN: $WARN"

if [[ "$FAIL" -ne 0 ]]; then
  exit 1
fi
