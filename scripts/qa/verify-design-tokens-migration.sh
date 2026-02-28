#!/usr/bin/env bash
# verify-design-tokens-migration.sh
#
# Comprehensive check that the design tokens migration is complete.
# Verifies:
#
#   1. All required token files exist
#   2. The CI drift gate is active (design-token-validation job present in ci.yml)
#   3. The generator script exists and is executable
#   4. _tokens.scss contains the BEGIN/END GENERATED markers
#   5. mereka-overrides.css (all variants) contain the BEGIN/END GENERATED markers
#   6. mereka.scss (MFE) imports split token + base partials (no legacy theme import)
#   7. No old standalone theming paths remain (legacy patterns removed)
#   8. Token count sanity: tokens.css has >= 100 custom properties
#   9. The generated blocks in all consumers are in sync with tokens.css
#
# PASS/FAIL/SKIP pattern: exits 1 if any FAIL, 0 otherwise.
#
# Usage:
#   ./scripts/qa/verify-design-tokens-migration.sh
#
# @covers AC-TKPIPE-001, AC-TKPIPE-002, AC-TKPIPE-003, AC-TKPIPE-004, AC-TKPIPE-005
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

# File paths
CANONICAL="assets/branding/tokens.css"
PROVENANCE="assets/branding/tokens.provenance.json"
SCSS_BRIDGE="infrastructure/tutor/themes/mereka/scss/_tokens.scss"
BASE_SCSS="infrastructure/tutor/themes/mereka/scss/_base.scss"
DESIGN_TOKENS_CSS="infrastructure/tutor/themes/mereka/common/static/css/mereka-design-tokens.css"
COMMON_OVERRIDES="infrastructure/tutor/themes/mereka/common/static/css/mereka-overrides.css"
LMS_OVERRIDES="infrastructure/tutor/themes/mereka/lms/static/css/mereka-overrides.css"
CMS_OVERRIDES="infrastructure/tutor/themes/mereka/cms/static/css/mereka-overrides.css"
MFE_SCSS="infrastructure/tutor/themes/mereka/mfe/mereka.scss"
GENERATOR="scripts/branding/generate-tokens-from-canonical.sh"
CONSUMER_VALIDATOR="scripts/branding/validate-token-consumers.sh"
CI_WORKFLOW=".github/workflows/ci.yml"
MIGRATION_DOC="docs/architecture/DESIGN_TOKENS_MIGRATION.md"
PIPELINE_DOC="docs/architecture/TOKEN_GENERATION_PIPELINE.md"

echo "=== Design Tokens Migration Verification ==="
echo ""

# ---------------------------------------------------------------------------
# 1. All required token files exist
# ---------------------------------------------------------------------------
echo "--- Required files ---"

required_files=(
  "$CANONICAL"
  "$PROVENANCE"
  "$SCSS_BRIDGE"
  "$DESIGN_TOKENS_CSS"
  "$COMMON_OVERRIDES"
  "$LMS_OVERRIDES"
  "$CMS_OVERRIDES"
  "$MFE_SCSS"
  "$GENERATOR"
  "$MIGRATION_DOC"
  "$PIPELINE_DOC"
)

for f in "${required_files[@]}"; do
  if [[ -f "$f" ]]; then
    pass "File exists: $f"
  else
    fail "Missing required file: $f"
  fi
done

# ---------------------------------------------------------------------------
# 2. CI drift gate is active
# ---------------------------------------------------------------------------
echo ""
echo "--- CI gate active ---"

if [[ ! -f "$CI_WORKFLOW" ]]; then
  skip "CI workflow not found at $CI_WORKFLOW; skipping CI gate check"
else
  if grep -q "generate-tokens-from-canonical.sh --check" "$CI_WORKFLOW"; then
    pass "CI workflow contains drift gate: generate-tokens-from-canonical.sh --check"
  else
    fail "CI workflow missing drift gate: generate-tokens-from-canonical.sh --check not found in $CI_WORKFLOW"
  fi

  if grep -q "design-token-validation" "$CI_WORKFLOW"; then
    pass "CI job 'design-token-validation' is present"
  else
    fail "CI job 'design-token-validation' not found in $CI_WORKFLOW"
  fi
fi

# ---------------------------------------------------------------------------
# 3. Generator is executable
# ---------------------------------------------------------------------------
echo ""
echo "--- Generator script ---"

if [[ ! -f "$GENERATOR" ]]; then
  fail "Generator script not found: $GENERATOR"
elif [[ ! -x "$GENERATOR" ]]; then
  fail "Generator script not executable: $GENERATOR (run: chmod +x $GENERATOR)"
else
  pass "Generator script exists and is executable: $GENERATOR"
fi

# Also check the consumer validator
if [[ ! -f "$CONSUMER_VALIDATOR" ]]; then
  fail "Consumer validator not found: $CONSUMER_VALIDATOR"
elif [[ ! -x "$CONSUMER_VALIDATOR" ]]; then
  fail "Consumer validator not executable: $CONSUMER_VALIDATOR (run: chmod +x $CONSUMER_VALIDATOR)"
else
  pass "Consumer validator exists and is executable: $CONSUMER_VALIDATOR"
fi

# ---------------------------------------------------------------------------
# 4. _tokens.scss contains BEGIN/END GENERATED markers
# ---------------------------------------------------------------------------
echo ""
echo "--- SCSS bridge generation markers ---"

if [[ ! -f "$SCSS_BRIDGE" ]]; then
  skip "_tokens.scss not found; skipping marker check"
else
  if grep -q "// BEGIN GENERATED" "$SCSS_BRIDGE" && grep -q "// END GENERATED" "$SCSS_BRIDGE"; then
    pass "_tokens.scss contains BEGIN/END GENERATED markers"
  else
    fail "_tokens.scss missing generation markers (// BEGIN GENERATED / // END GENERATED)"
  fi

  # Verify Bootstrap overrides section is preserved (after END GENERATED)
  if grep -q "\$font-family-sans-serif" "$SCSS_BRIDGE"; then
    pass "_tokens.scss preserves Bootstrap overrides section (\$font-family-sans-serif present)"
  else
    fail "_tokens.scss missing Bootstrap overrides section (\$font-family-sans-serif not found)"
  fi

  # Phase C split: _tokens.scss MUST stay token-only (no structural rules)
  if grep -qE '^body([^a-zA-Z0-9_-]|$)' "$SCSS_BRIDGE"; then
    fail "_tokens.scss contains body{} rule — structural CSS must live in _base.scss"
  else
    pass "_tokens.scss is token-only (no body{} structural rule)"
  fi

  if [[ ! -f "$BASE_SCSS" ]]; then
    fail "Missing split structural partial: $BASE_SCSS"
  elif grep -qE '^body([^a-zA-Z0-9_-]|$)' "$BASE_SCSS"; then
    pass "_base.scss contains structural CSS rules (body* selector present)"
  else
    fail "_base.scss missing structural CSS rules (body* selector not found)"
  fi
fi

# ---------------------------------------------------------------------------
# 5. mereka-overrides.css files contain BEGIN/END GENERATED markers
# ---------------------------------------------------------------------------
echo ""
echo "--- Runtime overrides generation markers ---"

for f_var in COMMON_OVERRIDES LMS_OVERRIDES CMS_OVERRIDES; do
  f="${!f_var}"
  if [[ ! -f "$f" ]]; then
    skip "${f}: not found; skipping marker check"
    continue
  fi
  if grep -q "BEGIN GENERATED" "$f" && grep -q "END GENERATED" "$f"; then
    pass "${f}: contains BEGIN/END GENERATED markers"
  else
    fail "${f}: missing generation markers (BEGIN GENERATED / END GENERATED)"
  fi
done

# ---------------------------------------------------------------------------
# 6. MFE SCSS imports the token bridge
# ---------------------------------------------------------------------------
echo ""
echo "--- MFE SCSS token bridge import ---"

if [[ ! -f "$MFE_SCSS" ]]; then
  fail "MFE SCSS not found: $MFE_SCSS"
else
  if grep -qE '@import\s+["\x27]\./scss/tokens["\x27]' "$MFE_SCSS" && \
     grep -qE '@import\s+["\x27]\./scss/base["\x27]' "$MFE_SCSS"; then
    pass "mereka.scss imports split token stack (./scss/tokens + ./scss/base)"
  else
    fail "mereka.scss must import ./scss/tokens and ./scss/base for Phase C architecture"
  fi

  if grep -qE '@import\s+["\x27]\./scss/theme["\x27]' "$MFE_SCSS"; then
    fail "mereka.scss still imports legacy ./scss/theme (dead CSS risk in MFEs)"
  else
    pass "mereka.scss does not import legacy ./scss/theme"
  fi

  # Verify mereka.scss uses --mereka-* tokens (not hardcoded colors for brand values)
  mereka_var_refs=$(grep -cE 'var\(--mereka-' "$MFE_SCSS" || true)
  if [[ "$mereka_var_refs" -gt 5 ]]; then
    pass "mereka.scss uses --mereka-* custom properties (${mereka_var_refs} references)"
  else
    fail "mereka.scss has fewer than 5 --mereka-* references (found: ${mereka_var_refs}); may be using hardcoded values"
  fi
fi

# ---------------------------------------------------------------------------
# 7. No old theming paths remain
#    Old pattern: raw hex values assigned directly to CSS custom properties
#    inside the generated :root blocks. The generated :root in overrides files
#    should only have hex values that are traceable to tokens.css.
#    (The full check is in validate-token-consumers.sh; here we do a lighter check.)
# ---------------------------------------------------------------------------
echo ""
echo "--- No legacy standalone hex definitions in generated blocks ---"

if [[ ! -f "$CANONICAL" ]]; then
  skip "tokens.css not found; skipping legacy hex check"
else
  for f_var in COMMON_OVERRIDES LMS_OVERRIDES CMS_OVERRIDES; do
    f="${!f_var}"
    [[ ! -f "$f" ]] && continue

    # Count hex values inside the BEGIN/END GENERATED block
    # Compare against count of hex values in tokens.css — should be close
    gen_hex_count=$(python3 - "$f" <<'PY'
import re, sys
txt = open(sys.argv[1]).read()
start = txt.find("/* BEGIN GENERATED")
end   = txt.find("/* END GENERATED")
if start == -1 or end == -1:
    print(0)
    sys.exit(0)
block = txt[start:end]
print(len(re.findall(r'#[0-9a-fA-F]{3,8}', block)))
PY
    ) || gen_hex_count=0

    canonical_hex_count=$(python3 - "$CANONICAL" <<'PY'
import re, sys
txt = open(sys.argv[1]).read()
m = re.search(r':root\s*\{(.*?)\}', txt, re.S)
block = m.group(1) if m else ""
print(len(re.findall(r'#[0-9a-fA-F]{3,8}', block)))
PY
    ) || canonical_hex_count=0

    # Allow up to 3x canonical count (ink scale and neutral scale add extra values)
    max_allowed=$((canonical_hex_count * 3 + 10))
    if [[ "$gen_hex_count" -le "$max_allowed" ]]; then
      pass "${f}: generated block hex count (${gen_hex_count}) within expected range (canonical: ${canonical_hex_count})"
    else
      fail "${f}: generated block has ${gen_hex_count} hex values but canonical has ${canonical_hex_count} — possible manual additions"
    fi
  done
fi

# ---------------------------------------------------------------------------
# 8. Token count sanity: tokens.css has >= 100 custom properties
# ---------------------------------------------------------------------------
echo ""
echo "--- Token count sanity ---"

if [[ ! -f "$CANONICAL" ]]; then
  skip "tokens.css not found; skipping token count check"
else
  token_count=$(grep -cE '^\s*--[a-z]' "$CANONICAL" || true)
  if [[ "$token_count" -ge 100 ]]; then
    pass "tokens.css contains ${token_count} custom properties (>= 100)"
  else
    fail "tokens.css has only ${token_count} custom properties (expected >= 100) — file may be incomplete"
  fi
fi

# ---------------------------------------------------------------------------
# 9. Generator --check: all generated blocks in sync with tokens.css
# ---------------------------------------------------------------------------
echo ""
echo "--- All generated blocks in sync with tokens.css ---"

if [[ ! -x "$GENERATOR" ]]; then
  skip "Generator not executable; skipping sync check (fix issue 3 first)"
else
  gen_output=$("$GENERATOR" --check 2>&1) && gen_rc=0 || gen_rc=$?
  if [[ "$gen_rc" -eq 0 ]]; then
    pass "All generated token layers are in sync with tokens.css"
  else
    fail "Token drift detected — run: ./scripts/branding/generate-tokens-from-canonical.sh"
    # Print the generator's own output for diagnostics
    echo "$gen_output" | while IFS= read -r line; do
      echo "    $line"
    done
  fi
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo "=== Results: ${PASS} PASS / ${FAIL} FAIL / ${SKIP} SKIP ==="
if [[ "$FAIL" -gt 0 ]]; then
  echo ""
  echo "  To fix drift: ./scripts/branding/generate-tokens-from-canonical.sh"
  echo "  To validate consumers: ./scripts/branding/validate-token-consumers.sh"
  exit 1
fi
exit 0
