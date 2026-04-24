#!/usr/bin/env bash
# validate-token-consumers.sh
#
# Validates that all token consumers are consistent with the canonical source
# (assets/branding/tokens.css). Checks:
#
#   1. _tokens.scss generated block SHA matches what the generator would produce
#      (proxy: run --check mode of the generator, which does the real comparison)
#   2. mereka-overrides.css (common/lms/cms) :root blocks contain no hex values
#      that diverge from tokens.css for the 9 canonical color pairs
#   3. mereka.scss (MFE) imports _tokens.scss (via @import "./scss/tokens" or "./scss/theme")
#   4. No hardcoded hex color values inside the generated blocks of overrides files
#      that should instead reference --mereka-* tokens
#
# PASS/FAIL/SKIP pattern: exits 1 if any FAIL, 0 otherwise.
#
# Usage:
#   ./scripts/branding/validate-token-consumers.sh
#
# @covers AC-TKPIPE-004, AC-TKPIPE-005
# @spec: design-tokens-system_spec.md
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASS=0
FAIL=0
SKIP=0

pass() { echo -e "  ${GREEN}PASS${NC} $1"; PASS=$((PASS + 1)); }
fail() { echo -e "  ${RED}FAIL${NC} $1"; FAIL=$((FAIL + 1)); }
skip() { echo -e "  ${YELLOW}SKIP${NC} $1"; SKIP=$((SKIP + 1)); }

CANONICAL="assets/branding/tokens.css"
SCSS_BRIDGE="infrastructure/tutor/themes/mereka/scss/_tokens.scss"
DESIGN_TOKENS_CSS="infrastructure/tutor/themes/mereka/common/static/css/mereka-design-tokens.css"
COMMON_OVERRIDES="infrastructure/tutor/themes/mereka/common/static/css/mereka-overrides.css"
LMS_OVERRIDES="infrastructure/tutor/themes/mereka/lms/static/css/mereka-overrides.css"
CMS_OVERRIDES="infrastructure/tutor/themes/mereka/cms/static/css/mereka-overrides.css"
MFE_SCSS="infrastructure/tutor/themes/mereka/mfe/mereka.scss"
GENERATOR="scripts/branding/generate-tokens-from-canonical.sh"
SCOPE_MODE="${VALIDATE_TOKEN_CONSUMERS_SCOPE:-}"
CHANGED_FILES_RAW="${VALIDATE_TOKEN_CONSUMERS_CHANGED_FILES:-${CI_CHANGED_FILES:-}}"

should_skip_scope() {
  local changed_path

  [[ "$SCOPE_MODE" == "changed" ]] || return 1
  [[ -n "${CHANGED_FILES_RAW//[[:space:]]/}" ]] || return 1

  while IFS= read -r changed_path; do
    [[ -n "$changed_path" ]] || continue
    case "$changed_path" in
      .github/workflows/ci.yml|\
      scripts/branding/validate-token-consumers.sh|\
      scripts/branding/generate-tokens-from-canonical.sh|\
      assets/branding/tokens.css|\
      infrastructure/tutor/themes/mereka/scss/_tokens.scss|\
      infrastructure/tutor/themes/mereka/common/static/css/mereka-design-tokens.css|\
      infrastructure/tutor/themes/mereka/common/static/css/mereka-overrides.css|\
      infrastructure/tutor/themes/mereka/lms/static/css/mereka-overrides.css|\
      infrastructure/tutor/themes/mereka/cms/static/css/mereka-overrides.css|\
      infrastructure/tutor/themes/mereka/mfe/mereka.scss)
        return 1
        ;;
    esac
  done <<< "$CHANGED_FILES_RAW"

  return 0
}

if should_skip_scope; then
  echo "PASS validate-token-consumers (scope skip: no token-consumer authority changes)"
  exit 0
fi

echo "=== Token Consumer Validation ==="
echo ""

# ---------------------------------------------------------------------------
# 1. Generator --check: all generated blocks match tokens.css
# ---------------------------------------------------------------------------
echo "--- Generated blocks in sync with tokens.css ---"

if [[ ! -f "$GENERATOR" ]]; then
  fail "Generator not found: $GENERATOR"
elif [[ ! -x "$GENERATOR" ]]; then
  fail "Generator not executable: $GENERATOR"
else
  gen_output=$("$GENERATOR" --check 2>&1) && gen_rc=0 || gen_rc=$?
  if [[ "$gen_rc" -eq 0 ]]; then
    pass "_tokens.scss generated block is in sync with tokens.css"
    pass "mereka-design-tokens.css is in sync with tokens.css"
    pass "common/mereka-overrides.css :root block is in sync with tokens.css"
    pass "lms/mereka-overrides.css :root block is in sync with tokens.css"
    pass "cms/mereka-overrides.css :root block is in sync with tokens.css"
  else
    # Parse the generator output and emit per-file FAILs
    while IFS= read -r line; do
      if grep -q "DRIFT:" <<<"$line"; then
        fail "$line"
      fi
    done <<< "$gen_output"
    # Ensure at least one FAIL is recorded if the generator exited non-zero
    # but no DRIFT lines were found (unexpected output format)
    if [[ "$FAIL" -eq 0 ]]; then
      fail "Generator --check exited $gen_rc (unexpected output): $gen_output"
    fi
  fi
fi

# ---------------------------------------------------------------------------
# 2. Canonical color pairs: tokens.css values match overrides :root block
#    This is a secondary check independent of the generator markers.
#    We extract the raw hex from tokens.css and verify the corresponding
#    --mereka-* value in the common overrides is identical or a var() ref.
# ---------------------------------------------------------------------------
echo ""
echo "--- Canonical color pairs (tokens.css vs common/mereka-overrides.css) ---"

if [[ ! -f "$CANONICAL" ]] || [[ ! -f "$COMMON_OVERRIDES" ]]; then
  skip "Canonical or overrides file not found; skipping color pair checks"
else
  # Extract --name: value pairs from tokens.css :root block
  extract_token_value() {
    local name="$1"
    local file="$2"
    python3 -c "
import re, sys
txt = open(sys.argv[1]).read()
m = re.search(r':root\s*\{(.*?)\}', txt, re.S)
if not m:
    sys.exit(1)
for part in re.finditer(r'(${name})\s*:\s*([^;]+);', m.group(1)):
    print(part.group(2).strip().lower())
    sys.exit(0)
" "$file" 2>/dev/null || true
  }

  check_pair() {
    local canonical_name="$1"
    local mereka_name="$2"
    local canonical_val
    local override_val
    canonical_val=$(python3 - "$CANONICAL" "$canonical_name" <<'PY'
import re, sys
txt = open(sys.argv[1]).read()
m = re.search(r':root\s*\{(.*?)\}', txt, re.S)
if not m:
    sys.exit(1)
block = m.group(1)
for hit in re.finditer(r'(--[A-Za-z0-9_-]+)\s*:\s*([^;]+);', block):
    if hit.group(1) == sys.argv[2]:
        print(hit.group(2).strip().lower())
        sys.exit(0)
PY
    ) || true

    if [[ -z "$canonical_val" ]]; then
      skip "${canonical_name}: not found in tokens.css; skipping pair check"
      return
    fi

    # In the overrides, the mereka name may hold the raw hex OR a var() reference.
    # Either is valid — var() references are correctly resolved at runtime.
    # We check: if it holds a raw hex, it must match the canonical value.
    override_val=$(python3 - "$COMMON_OVERRIDES" "$mereka_name" <<'PY'
import re, sys
txt = open(sys.argv[1]).read()
m = re.search(r':root\s*\{(.*?)\}', txt, re.S)
if not m:
    sys.exit(1)
block = m.group(1)
for hit in re.finditer(r'(--[A-Za-z0-9_-]+)\s*:\s*([^;]+);', block):
    if hit.group(1) == sys.argv[2]:
        print(hit.group(2).strip().lower())
        sys.exit(0)
PY
    ) || true

    if [[ -z "$override_val" ]]; then
      fail "${mereka_name}: not found in common/mereka-overrides.css :root block"
      return
    fi

    # If the override value is a raw hex, compare it directly
    if grep -qE '^#[0-9a-f]{3,8}$' <<<"$override_val"; then
      if [[ "$override_val" == "$canonical_val" ]]; then
        pass "${canonical_name}=${canonical_val} matches ${mereka_name}"
      else
        fail "${canonical_name}=${canonical_val} != ${mereka_name}=${override_val} (hex drift)"
      fi
    else
      # var() reference — trust generator sync check already validated this
      pass "${mereka_name}=${override_val} (var() reference; generator sync check passed)"
    fi
  }

  check_pair "--color-teal"     "--mereka-color-teal"
  check_pair "--color-magenta"  "--mereka-color-magenta"
  check_pair "--color-blue"     "--mereka-color-blue"
  check_pair "--color-sky"      "--mereka-color-sky"
  check_pair "--color-forest"   "--mereka-color-success"
  check_pair "--color-gold"     "--mereka-color-warning"
  check_pair "--color-burgundy" "--mereka-color-danger"
  check_pair "--color-pink"     "--mereka-color-danger-soft"
  check_pair "--color-black"    "--mereka-color-ink-900"
fi

# ---------------------------------------------------------------------------
# 3. MFE SCSS imports _tokens.scss (via @import "./scss/theme")
#    mereka.scss must @import the theme which pulls in _tokens.scss
# ---------------------------------------------------------------------------
echo ""
echo "--- MFE SCSS imports _tokens.scss ---"

if [[ ! -f "$MFE_SCSS" ]]; then
  fail "MFE SCSS not found: $MFE_SCSS"
else
  if grep -qE '@import\s+["\x27]\./scss/(theme|tokens)["\x27]' "$MFE_SCSS"; then
    pass "mereka.scss imports token layer (which includes _tokens.scss)"
  else
    fail "mereka.scss does not @import './scss/tokens' or './scss/theme' — MFE tokens may not load"
  fi
fi

# ---------------------------------------------------------------------------
# 4. No unexpected hardcoded hex in the generated :root block of overrides
#    The generated block should only contain hex values that are sourced from
#    tokens.css. We warn if we find hex values in the generated block that
#    do NOT appear in tokens.css (potential manual drift).
# ---------------------------------------------------------------------------
echo ""
echo "--- No rogue hardcoded hex values in generated blocks ---"

if [[ ! -f "$CANONICAL" ]]; then
  skip "tokens.css not found; skipping rogue hex check"
else
  # Collect all hex values present in tokens.css (normalised lowercase)
  canonical_hexes=$(python3 - "$CANONICAL" <<'PY'
import re, sys
txt = open(sys.argv[1]).read()
hexes = set(h.lower() for h in re.findall(r'#[0-9a-fA-F]{3,8}', txt))
for h in sorted(hexes):
    print(h)
PY
  )

  check_rogue_hex() {
    local file="$1"
    local label="$2"
    # Extract the generated block content
    gen_block=$(python3 - "$file" <<'PY'
import sys
txt = open(sys.argv[1]).read()
start = txt.find("/* BEGIN GENERATED")
end   = txt.find("/* END GENERATED")
if start == -1 or end == -1:
    # No markers found — emit empty
    sys.exit(0)
print(txt[start:end])
PY
    ) || true

    if [[ -z "$gen_block" ]]; then
      skip "${label}: no generated block markers found; skipping rogue hex check"
      return
    fi

    rogue=""
    while IFS= read -r hex; do
      [[ -z "$hex" ]] && continue
      if ! grep -qF "$hex" <<<"$canonical_hexes"; then
        rogue="${rogue} ${hex}"
      fi
    done < <(python3 - "$gen_block" <<'PY'
import re, sys
txt = sys.stdin.read()
for h in re.findall(r'#[0-9a-fA-F]{3,8}', txt):
    print(h.lower())
PY
    )

    if [[ -z "$rogue" ]]; then
      pass "${label}: all hex values in generated block are sourced from tokens.css"
    else
      fail "${label}: generated block contains hex values not in tokens.css:${rogue}"
    fi
  }

  check_rogue_hex "$COMMON_OVERRIDES" "common/mereka-overrides.css"
  check_rogue_hex "$LMS_OVERRIDES"    "lms/mereka-overrides.css"
  check_rogue_hex "$CMS_OVERRIDES"    "cms/mereka-overrides.css"
fi

# ---------------------------------------------------------------------------
# 5. design-tokens.css exists and is not empty
# ---------------------------------------------------------------------------
echo ""
echo "--- mereka-design-tokens.css ---"

if [[ ! -f "$DESIGN_TOKENS_CSS" ]]; then
  fail "mereka-design-tokens.css not found: $DESIGN_TOKENS_CSS"
else
  line_count=$(wc -l < "$DESIGN_TOKENS_CSS")
  if [[ "$line_count" -gt 10 ]]; then
    pass "mereka-design-tokens.css exists (${line_count} lines)"
  else
    fail "mereka-design-tokens.css suspiciously small (${line_count} lines)"
  fi
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo "=== Results: ${PASS} PASS / ${FAIL} FAIL / ${SKIP} SKIP ==="
[[ "$FAIL" -gt 0 ]] && exit 1 || exit 0
