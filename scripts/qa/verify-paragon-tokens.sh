#!/usr/bin/env bash
# @covers AC-TKN-010, AC-TKN-011, AC-TKN-012, AC-TKN-013, AC-TKN-014
# @covers AC-TKN-029, AC-TKN-030, AC-TKN-031
# @spec: paragon-design-tokens-migration_spec.md
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BUILD_SCRIPT="$REPO_ROOT/scripts/branding/build-tokens.sh"
OUTPUT_CSS="$REPO_ROOT/infrastructure/tutor/themes/mereka/mfe/theme/mereka-brand.min.css"
TOKENS_CSS="$REPO_ROOT/assets/branding/tokens.css"

PASS=0
FAIL=0

pass() {
  PASS=$((PASS + 1))
  echo "PASS: $*"
}

fail() {
  FAIL=$((FAIL + 1))
  echo "FAIL: $*"
}

read_expected_colors() {
  python3 - "$TOKENS_CSS" <<'PY'
from pathlib import Path
import re
import sys

text = Path(sys.argv[1]).read_text(encoding="utf-8")
for key in ("--color-magenta", "--color-teal"):
    m = re.search(rf"{re.escape(key)}:\s*(#[0-9A-Fa-f]{{6}})\s*;", text)
    if not m:
        raise SystemExit(1)
    print(m.group(1).lower())
PY
}

check_contains_token() {
  local token_name="$1"
  if grep -q -- "$token_name:" "$OUTPUT_CSS"; then
    return 0
  fi
  return 1
}

check_token_value() {
  local token_name="$1"
  local expected="$2"
  if python3 - "$OUTPUT_CSS" "$token_name" "$expected" <<'PY'
from pathlib import Path
import re
import sys

css = Path(sys.argv[1]).read_text(encoding="utf-8").lower()
token = sys.argv[2]
expected = sys.argv[3]

matches = re.findall(rf"{re.escape(token)}:\s*([^;]+);", css)
if not matches or expected not in [v.strip() for v in matches]:
    raise SystemExit(1)
PY
  then
    return 0
  fi
  return 1
}


echo "=== Paragon Token Build Verification ==="

read -r expected_primary expected_secondary <<< "$(read_expected_colors | tr "\n" " ")"

if [[ -x "$BUILD_SCRIPT" ]]; then
  "$BUILD_SCRIPT" >/dev/null
  pass "AC-TKN-029 token build script executed"
else
  fail "AC-TKN-029 missing executable build script: scripts/branding/build-tokens.sh"
fi

if [[ -f "$OUTPUT_CSS" ]]; then
  pass "AC-TKN-029 output file exists: ${OUTPUT_CSS#$REPO_ROOT/}"
else
  fail "AC-TKN-029 output file missing: ${OUTPUT_CSS#$REPO_ROOT/}"
fi

if [[ -f "$OUTPUT_CSS" ]]; then
  if check_contains_token "--pgn-color-primary"; then
    pass "AC-TKN-030 required token present: --pgn-color-primary"
  else
    fail "AC-TKN-030 missing required token: --pgn-color-primary"
  fi

  if check_contains_token "--pgn-color-secondary"; then
    pass "AC-TKN-011 required token present: --pgn-color-secondary"
  else
    fail "AC-TKN-011 missing required token: --pgn-color-secondary"
  fi

  if check_token_value "--pgn-color-primary" "$expected_primary"; then
    pass "AC-TKN-010 --pgn-color-primary resolves to canonical magenta (${expected_primary})"
  else
    fail "AC-TKN-010 --pgn-color-primary does not match canonical magenta (${expected_primary})"
  fi

  if check_token_value "--pgn-color-secondary" "$expected_secondary"; then
    pass "AC-TKN-011 --pgn-color-secondary resolves to canonical teal (${expected_secondary})"
  else
    fail "AC-TKN-011 --pgn-color-secondary does not match canonical teal (${expected_secondary})"
  fi

  if python3 - "$OUTPUT_CSS" <<'PY'
from pathlib import Path
import re
import sys

css = Path(sys.argv[1]).read_text(encoding="utf-8").lower()
matches = re.findall(r"--pgn-font-family-sans-serif:\s*([^;]+);", css)
if not matches or not any("poppins" in v for v in matches):
    raise SystemExit(1)
PY
  then
    pass "AC-TKN-012 --pgn-font-family-sans-serif contains Poppins"
  else
    fail "AC-TKN-012 --pgn-font-family-sans-serif missing or does not contain Poppins"
  fi

  token_count="$(python3 - "$OUTPUT_CSS" <<'PY'
from pathlib import Path
import re
import sys

text = Path(sys.argv[1]).read_text(encoding="utf-8")
print(len(set(re.findall(r"--pgn-[A-Za-z0-9_-]+\s*:", text))))
PY
  )"
  if [[ "$token_count" -ge 8 && "$token_count" -le 80 ]]; then
    pass "AC-TKN-029 token count is ${token_count} (delta-mode target range 8-80)"
    pass "AC-TKN-013 token count contract satisfied for delta override bundle"
  elif [[ "$token_count" -gt 80 ]]; then
    fail "AC-TKN-029 token count is ${token_count} (>80, indicates non-delta/bloated output)"
  else
    fail "AC-TKN-029 token count is ${token_count} (<8, missing required brand overrides)"
  fi

  unresolved_refs="$(python3 - "$OUTPUT_CSS" <<'PY'
from pathlib import Path
import re
import sys

text = Path(sys.argv[1]).read_text(encoding="utf-8")
print(len(re.findall(r"\{[A-Za-z0-9_.-]+\}", text)))
PY
  )"
  if [[ "$unresolved_refs" -eq 0 ]]; then
    pass "AC-TKN-029 no unresolved token references"
    pass "AC-TKN-014 no unresolved token references in generated CSS"
  else
    fail "AC-TKN-029 found ${unresolved_refs} unresolved token references"
  fi

  if python3 - "$TOKENS_CSS" "$OUTPUT_CSS" <<'PY'
from pathlib import Path
import re
import sys

required = [
    "--color-teal",
    "--color-magenta",
    "--color-blue",
    "--color-forest",
    "--color-gold",
    "--color-burgundy",
]

canonical = Path(sys.argv[1]).read_text(encoding="utf-8")
css_text = Path(sys.argv[2]).read_text(encoding="utf-8").lower()
colors = {name: value.lower() for name, value in re.findall(r"(--color-[a-z0-9-]+)\s*:\s*(#[0-9a-fA-F]{6})\s*;", canonical)}

for key in required:
    if key not in colors or colors[key] not in css_text:
        raise SystemExit(1)
PY
  then
    pass "AC-TKN-029 canonical colors from tokens.css are present in output CSS"
  else
    fail "AC-TKN-029 one or more canonical colors are missing from output CSS"
  fi
fi

if grep -qF "scripts/qa/verify-paragon-tokens.sh" "$REPO_ROOT/.github/ci-scripts-static.txt"; then
  pass "AC-TKN-031 CI static script list includes verify-paragon-tokens.sh"
else
  fail "AC-TKN-031 CI static script list missing verify-paragon-tokens.sh"
fi

echo

echo "=== Summary: PASS=${PASS} FAIL=${FAIL} ==="
if [[ "$FAIL" -gt 0 ]]; then
  exit 1
fi
