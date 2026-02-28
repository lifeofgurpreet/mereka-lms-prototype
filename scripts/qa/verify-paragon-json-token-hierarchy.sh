#!/usr/bin/env bash
# @covers AC-TKN-001, AC-TKN-002, AC-TKN-003, AC-TKN-004, AC-TKN-005
# @covers AC-TKN-006, AC-TKN-007, AC-TKN-008, AC-TKN-009, AC-TKN-015
# @covers AC-TKN-INT-001
# @spec: paragon-design-tokens-migration_spec.md
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

GLOBAL_JSON="$REPO_ROOT/tokens/src/core/global.json"
ALIAS_JSON="$REPO_ROOT/tokens/src/core/alias.json"
COMPONENTS_DIR="$REPO_ROOT/tokens/src/core/components"
STYLE_DICT_CFG="$REPO_ROOT/style-dictionary.config.js"
BUILD_SCRIPT="$REPO_ROOT/scripts/branding/build-tokens.sh"
SYNC_JSON_SCRIPT="$REPO_ROOT/scripts/branding/sync-tokens-to-json.sh"
OUTPUT_CSS="$REPO_ROOT/infrastructure/tutor/themes/mereka/mfe/theme/mereka-brand.min.css"
TOKENS_CSS="$REPO_ROOT/assets/branding/tokens.css"

PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); echo "PASS: $*"; }
fail() { FAIL=$((FAIL + 1)); echo "FAIL: $*"; }

require_file() {
  local path="$1"
  local label="$2"
  if [[ -f "$path" ]]; then
    pass "$label exists: ${path#$REPO_ROOT/}"
  else
    fail "$label missing: ${path#$REPO_ROOT/}"
  fi
}

echo "=== Paragon JSON Token Hierarchy Verification ==="

require_file "$GLOBAL_JSON" "AC-TKN-001 global tokens file"
require_file "$ALIAS_JSON" "AC-TKN-003 alias tokens file"
require_file "$STYLE_DICT_CFG" "AC-TKN-009 style-dictionary config"
require_file "$BUILD_SCRIPT" "AC-TKN-009 build script"
require_file "$SYNC_JSON_SCRIPT" "AC-TKN-INT-001 token css -> json sync script"

if [[ -d "$COMPONENTS_DIR" ]]; then
  pass "AC-TKN-008 components directory exists"
else
  fail "AC-TKN-008 components directory missing"
fi

if [[ -f "$GLOBAL_JSON" ]]; then
  if python3 - "$GLOBAL_JSON" <<'PY'
import json
from pathlib import Path
import sys

data = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
global_tokens = data.get("global", {})

required_categories = {
    "color": 25,
    "typography": 15,
    "spacing": 14,
    "sizing": 16,
    "shadow": 4,
    "zIndex": 7,
    "animation": 9,
    "radius": 6,
}

def count_values(node):
    if isinstance(node, dict):
        if "value" in node:
            return 1
        return sum(count_values(v) for v in node.values())
    if isinstance(node, list):
        return sum(count_values(v) for v in node)
    return 0

total = count_values(global_tokens)
if total < 100:
    raise SystemExit(f"total value count too low: {total}")

for key, minimum in required_categories.items():
    category = global_tokens.get(key)
    count = count_values(category) if category is not None else 0
    if count < minimum:
        raise SystemExit(f"category {key} has {count}, requires >= {minimum}")

teal = global_tokens.get("color", {}).get("teal", {}).get("value", "").lower()
if teal != "#237072":
    raise SystemExit(f"global.color.teal mismatch: {teal}")
PY
  then
    pass "AC-TKN-001 global token inventory has >=100 entries with required category coverage"
    pass "AC-TKN-002 global.color.teal matches #237072"
  else
    fail "AC-TKN-001/002 global token coverage or teal value check failed"
  fi

  if python3 - "$GLOBAL_JSON" "$TOKENS_CSS" <<'PY'
import json
from pathlib import Path
import re
import sys

global_json = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
tokens_css = Path(sys.argv[2]).read_text(encoding="utf-8")

css_colors = {
    key.lower(): value.lower()
    for key, value in re.findall(r"(--color-[a-z0-9-]+)\s*:\s*(#[0-9a-fA-F]{6})\s*;", tokens_css)
}

mapping = {
    "black": "--color-black",
    "white": "--color-white",
    "teal": "--color-teal",
    "magenta": "--color-magenta",
    "magentaDark": "--color-magenta-dark",
    "blue": "--color-blue",
    "burgundy": "--color-burgundy",
    "pink": "--color-pink",
    "sky": "--color-sky",
    "orange": "--color-orange",
    "gold": "--color-gold",
    "mint": "--color-mint",
    "periwinkle": "--color-periwinkle",
    "forest": "--color-forest",
    "success": "--color-success",
    "successLight": "--color-success-light",
    "warning": "--color-warning",
    "warningDark": "--color-warning-dark",
    "error": "--color-error",
    "errorLight": "--color-error-light",
    "info": "--color-info",
    "infoLight": "--color-info-light",
}

global_colors = global_json.get("global", {}).get("color", {})
for global_key, css_key in mapping.items():
    g_val = str(global_colors.get(global_key, {}).get("value", "")).lower()
    c_val = css_colors.get(css_key.lower())
    if not c_val:
        raise SystemExit(f"missing canonical css color {css_key}")
    if g_val != c_val:
        raise SystemExit(f"color mismatch {global_key}: global={g_val} css={c_val}")
PY
  then
    pass "Cross-spec color parity: global.json color tokens match canonical tokens.css"
  else
    fail "Cross-spec color parity failed between global.json and tokens.css"
  fi
fi

if [[ -f "$ALIAS_JSON" ]]; then
  if python3 - "$ALIAS_JSON" <<'PY'
import json
from pathlib import Path
import re
import sys

alias = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
color = alias.get("color", {})

if color.get("primary", {}).get("value") != "{global.color.magenta}":
    raise SystemExit("primary alias mismatch")
if color.get("secondary", {}).get("value") != "{global.color.teal}":
    raise SystemExit("secondary alias mismatch")

hex_re = re.compile(r"#[0-9a-fA-F]{3,8}")

def walk(node):
    if isinstance(node, dict):
        for k, v in node.items():
            if k == "value" and isinstance(v, str) and hex_re.search(v):
                raise SystemExit(f"hex literal found in alias value: {v}")
            walk(v)
    elif isinstance(node, list):
        for v in node:
            walk(v)

walk(alias)
PY
  then
    pass "AC-TKN-003 alias color.primary references {global.color.magenta}"
    pass "AC-TKN-004 alias color.secondary references {global.color.teal}"
    pass "AC-TKN-005 alias tokens contain no raw hex literals"
  else
    fail "AC-TKN-003/004/005 alias token validation failed"
  fi
fi

if [[ -d "$COMPONENTS_DIR" ]]; then
  if python3 - "$COMPONENTS_DIR" <<'PY'
import json
from pathlib import Path
import re
import sys

components = Path(sys.argv[1])
required = [
    "button.json",
    "card.json",
    "alert.json",
    "modal.json",
    "navbar.json",
    "form-control.json",
    "dropdown.json",
    "tabs.json",
    "badge.json",
]
for name in required:
    if not (components / name).exists():
        raise SystemExit(f"missing component file: {name}")

button = json.loads((components / "button.json").read_text(encoding="utf-8"))
card = json.loads((components / "card.json").read_text(encoding="utf-8"))

btn_radius = button.get("button", {}).get("border-radius", {}).get("value")
if btn_radius != "{global.radius.full}":
    raise SystemExit(f"button border-radius mismatch: {btn_radius}")

card_radius = card.get("card", {}).get("border-radius", {}).get("value", "")
if not re.match(r"^\{global\.radius\.[A-Za-z0-9_-]+\}$", card_radius):
    raise SystemExit(f"card border-radius is not a global radius reference: {card_radius}")
PY
  then
    pass "AC-TKN-006 button component maps border-radius to {global.radius.full}"
    pass "AC-TKN-007 card component border-radius references global radius token"
    pass "AC-TKN-008 required component token files are present"
  else
    fail "AC-TKN-006/007/008 component token validation failed"
  fi
fi

if [[ -f "$STYLE_DICT_CFG" ]]; then
  if grep -q "modify" "$STYLE_DICT_CFG" && grep -q "darken" "$STYLE_DICT_CFG"; then
    pass "AC-TKN-015 style-dictionary config declares a modify transform"
  else
    fail "AC-TKN-015 style-dictionary config missing modify/darken transform declaration"
  fi
fi

if [[ -x "$BUILD_SCRIPT" ]]; then
  "$BUILD_SCRIPT" >/dev/null
  if [[ -f "$OUTPUT_CSS" ]] && grep -q -- "--pgn-" "$OUTPUT_CSS"; then
    pass "AC-TKN-009 build script generates CSS with --pgn-* properties"
  else
    fail "AC-TKN-009 build script did not produce expected --pgn-* output"
  fi

  if [[ -f "$OUTPUT_CSS" ]] && grep -qi "#8c002f" "$OUTPUT_CSS"; then
    pass "AC-TKN-015 output CSS contains computed color value (non-reference hex)"
  else
    fail "AC-TKN-015 output CSS missing expected computed color value"
  fi
fi

if [[ -x "$SYNC_JSON_SCRIPT" ]]; then
  if "$SYNC_JSON_SCRIPT" --check >/dev/null; then
    pass "AC-TKN-INT-001 sync-tokens-to-json --check passes (no css->json drift)"
  else
    fail "AC-TKN-INT-001 sync-tokens-to-json --check failed (css->json drift detected)"
  fi
else
  fail "AC-TKN-INT-001 sync script is not executable"
fi

echo ""
echo "=== Summary: PASS=${PASS} FAIL=${FAIL} ==="
if [[ "$FAIL" -gt 0 ]]; then
  exit 1
fi
