#!/usr/bin/env bash
# @covers AC-TOKEN-001, AC-TOKEN-002, AC-TOKEN-003, AC-TOKEN-004
# @spec: bead-115d16
# Verify CSS token drift: scan all theme CSS/SCSS for var(--mereka-*) references,
# check each resolves to a definition in the canonical source or theme files,
# and enforce canonical source-of-truth discipline.
#
# Drift-check flow:
# 1. Extract all defined --mereka-* tokens from canonical source + theme files
# 2. Scan all theme CSS/SCSS for var(--mereka-*) references
# 3. Flag any reference with no matching definition (undefined token drift)
# 4. Specifically check for known gap: ink-600 (never defined in the Mereka scale)
# 5. Verify canonical source (assets/branding/tokens.css) is present and non-empty
#
# Canonical token source: assets/branding/tokens.css
# Design system: https://www.figma.com/design/jBO2FrTslM4wocrRzwQaPo/mereka.io-Design-System
#
# Usage: ./scripts/qa/verify-token-drift.sh
# CI:    runs on PRs touching assets/branding/** or infrastructure/tutor/themes/**

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

source "$REPO_ROOT/scripts/shared/ci-skip-guards.sh"
require_file "assets/branding/tokens.css" "canonical token source" || exit 0

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASS=0
FAIL=0
WARN=0

pass() { echo -e "${GREEN}[PASS]${NC} $1"; PASS=$((PASS + 1)); }
fail() { echo -e "${RED}[FAIL]${NC} $1"; FAIL=$((FAIL + 1)); }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; WARN=$((WARN + 1)); }

CANONICAL="$REPO_ROOT/assets/branding/tokens.css"
THEME_DIR="$REPO_ROOT/infrastructure/tutor/themes/mereka"
TOKENS_SCSS="$REPO_ROOT/infrastructure/tutor/themes/mereka/scss/_tokens.scss"

echo "=== CSS Token Drift Verification ==="
echo "  Canonical source : assets/branding/tokens.css"
echo "  Token bridge (SCSS): infrastructure/tutor/themes/mereka/scss/_tokens.scss"
echo "  Theme scan root  : infrastructure/tutor/themes/mereka/"
echo ""

# ── AC-TOKEN-003: Canonical source present + non-empty ────────────────────────
echo "--- AC-TOKEN-003: Canonical source of truth ---"

if [[ ! -f "$CANONICAL" ]]; then
  fail "AC-TOKEN-003: Canonical source not found: assets/branding/tokens.css"
  echo ""
  echo "Remediation: Create assets/branding/tokens.css with :root { --<token>: <value>; } blocks."
  echo "See docs/runbooks/architecture/TOKEN_DRIFT_REMEDIATION.md for the full authoring guide."
else
  CANONICAL_COUNT=$(grep -cP '^\s+--[a-z0-9_-]+\s*:' "$CANONICAL" || true)
  if [[ "$CANONICAL_COUNT" -ge 80 ]]; then
    pass "AC-TOKEN-003: Canonical source present with $CANONICAL_COUNT token definitions (>=80)"
  else
    fail "AC-TOKEN-003: Canonical source has only $CANONICAL_COUNT token definitions (expected >=80)"
  fi

  # Verify :root block is present (required for browser inheritance)
  if grep -q ':root' "$CANONICAL"; then
    pass "AC-TOKEN-003: :root selector present in canonical source"
  else
    fail "AC-TOKEN-003: :root selector missing from canonical source — tokens will not inherit"
  fi
fi

# Check token bridge SCSS
if [[ ! -f "$TOKENS_SCSS" ]]; then
  warn "AC-TOKEN-003: Token bridge _tokens.scss not found — MFE drift possible"
else
  BRIDGE_COUNT=$(grep -cP '^\s+--mereka-[a-z0-9_-]+\s*:' "$TOKENS_SCSS" || true)
  if [[ "$BRIDGE_COUNT" -ge 15 ]]; then
    pass "AC-TOKEN-003: Token bridge has $BRIDGE_COUNT --mereka-* definitions (>=15)"
  else
    warn "AC-TOKEN-003: Token bridge has only $BRIDGE_COUNT --mereka-* definitions (expected >=15)"
  fi
fi

# ── AC-TOKEN-001: Collect all definitions (all theme files + SCSS) ─────────────
echo ""
echo "--- AC-TOKEN-001: Collect defined --mereka-* tokens ---"

# Build a complete set of defined --mereka-* token names from all definition sites:
# 1. scss/_tokens.scss  (Paragon bridge, compiled into MFEs)
# 2. */static/css/mereka-overrides.css  (runtime CSS, LMS/Studio/common)
# 3. mfe/mereka.scss  (:root block at the top of the file)
# 4. scss/theme.scss  (:root block)
DEFINED_TOKENS_FILE="$(mktemp)"
trap 'rm -f "$DEFINED_TOKENS_FILE"' EXIT

while IFS= read -r src_file; do
  # Extract --mereka-* token definitions (e.g. "  --mereka-color-blue: #295cad;")
  # Avoid variable-length lookbehind which fails on PCRE1 (some CI runners).
  grep -oP '^\s{0,8}\K--mereka-[a-z0-9_-]+(?=\s*:)' "$src_file" 2>/dev/null >> "$DEFINED_TOKENS_FILE" || true
done < <(find "$THEME_DIR" \( -name '*.scss' -o -name '*.css' \) -not -path '*/node_modules/*' 2>/dev/null)

DEFINED_COUNT=$(sort -u "$DEFINED_TOKENS_FILE" | wc -l)
if [[ "$DEFINED_COUNT" -ge 15 ]]; then
  pass "AC-TOKEN-001: $DEFINED_COUNT distinct --mereka-* token definitions found across theme files"
else
  fail "AC-TOKEN-001: Only $DEFINED_COUNT --mereka-* token definitions found (expected >=15)"
fi

# ── AC-TOKEN-001 + AC-TOKEN-002: Scan all var(--mereka-*) references ──────────
echo ""
echo "--- AC-TOKEN-001 / AC-TOKEN-002: Scan var(--mereka-*) references ---"

UNDEFINED_COUNT=0
TOTAL_REFS=0
FIRST_UNDEFINED_TOKEN=""
FIRST_UNDEFINED_LOCATION=""

while IFS= read -r src_file; do
  rel_file="${src_file#"$REPO_ROOT/"}"
  while IFS= read -r ref_token; do
    [[ -z "$ref_token" ]] && continue
    TOTAL_REFS=$((TOTAL_REFS + 1))

    # Check if this token name appears as a definition in our collected set
    if ! grep -qxF -- "$ref_token" "$DEFINED_TOKENS_FILE"; then
      UNDEFINED_COUNT=$((UNDEFINED_COUNT + 1))
      if [[ -z "$FIRST_UNDEFINED_TOKEN" ]]; then
        FIRST_UNDEFINED_TOKEN="$ref_token"
        line_no=$(grep -n "var($ref_token" "$src_file" 2>/dev/null | head -1 | cut -d: -f1)
        FIRST_UNDEFINED_LOCATION="${rel_file}:${line_no:-?}"
      fi
    fi
  done < <(grep -oP 'var\(\K--mereka-[a-z0-9_-]+(?=[\s,)])' "$src_file" 2>/dev/null | sort -u || true)
done < <(find "$THEME_DIR" \( -name '*.scss' -o -name '*.css' \) -not -path '*/node_modules/*' 2>/dev/null)

if [[ "$TOTAL_REFS" -eq 0 ]]; then
  warn "AC-TOKEN-001: No var(--mereka-*) references found — is the theme empty?"
elif [[ "$UNDEFINED_COUNT" -eq 0 ]]; then
  pass "AC-TOKEN-001: All $TOTAL_REFS var(--mereka-*) references resolve to definitions"
else
  fail "AC-TOKEN-001: $UNDEFINED_COUNT of $TOTAL_REFS var(--mereka-*) references are UNDEFINED"
  echo "  First undefined : $FIRST_UNDEFINED_TOKEN"
  echo "  First location  : $FIRST_UNDEFINED_LOCATION"
  echo ""
  echo "  Remediation:"
  echo "  1. Add missing token to infrastructure/tutor/themes/mereka/scss/_tokens.scss :root block"
  echo "  2. Mirror the definition in */static/css/mereka-overrides.css (common/lms/cms)"
  echo "  3. Run this script again to confirm PASS"
  echo "  4. See docs/runbooks/architecture/TOKEN_DRIFT_REMEDIATION.md for canonical procedure"
fi

# ── AC-TOKEN-002: Explicit ink-600 gap check ──────────────────────────────────
echo ""
echo "--- AC-TOKEN-002: Undefined token gap (ink-600 check) ---"

INK600_DEFINED=$(grep -r 'mereka-color-ink-600' "$THEME_DIR" 2>/dev/null | grep -v 'var(' | grep ':' || true)
INK600_REFS=$(grep -rl 'var(--mereka-color-ink-600' "$THEME_DIR" 2>/dev/null || true)

if [[ -n "$INK600_REFS" ]]; then
  fail "AC-TOKEN-002: var(--mereka-color-ink-600) is REFERENCED but NEVER DEFINED"
  echo "  References in  : $(echo "$INK600_REFS" | tr '\n' ' ')"
  echo "  Note: The Mereka ink scale is: ink-300, ink-500, ink-700, ink-900 — ink-600 does not exist."
  echo "  Fix : Replace var(--mereka-color-ink-600) with var(--mereka-color-ink-700) (closest defined shade)"
else
  pass "AC-TOKEN-002: No references to undefined --mereka-color-ink-600 (gap is absent)"
fi

if [[ -n "$INK600_DEFINED" ]]; then
  warn "AC-TOKEN-002: --mereka-color-ink-600 is defined in theme files (unexpected — ink scale is 300/500/700/900)"
  echo "  Defined in: $INK600_DEFINED"
fi

# Confirm the canonical ink levels ARE defined
echo ""
echo "  Checking canonical ink scale (300/500/700/900)..."
for ink_level in 300 500 700 900; do
  token="--mereka-color-ink-${ink_level}"
  if grep -qxF -- "$token" "$DEFINED_TOKENS_FILE"; then
    pass "AC-TOKEN-002: $token is defined"
  else
    fail "AC-TOKEN-002: $token is MISSING from theme definitions"
  fi
done

# ── AC-TOKEN-002: Additional undefined-reference audit for known gap tokens ───
echo ""
echo "--- AC-TOKEN-002: Known-gap token audit (ink-600, ink-400, ink-200, ink-100) ---"
KNOWN_GAPS=("mereka-color-ink-600" "mereka-color-ink-400" "mereka-color-ink-200" "mereka-color-ink-100")
GAP_HITS=0
for gap_token in "${KNOWN_GAPS[@]}"; do
  refs=$(grep -rl "var(--${gap_token}" "$THEME_DIR" 2>/dev/null || true)
  if [[ -n "$refs" ]]; then
    fail "AC-TOKEN-002: var(--${gap_token}) referenced but not in Mereka ink scale: $refs"
    GAP_HITS=$((GAP_HITS + 1))
  fi
done
if [[ "$GAP_HITS" -eq 0 ]]; then
  pass "AC-TOKEN-002: No references to off-scale ink tokens (ink-100/200/400/600)"
fi

# ── AC-TOKEN-004: CI coverage verification ────────────────────────────────────
echo ""
echo "--- AC-TOKEN-004: CI coverage for token generation/artifact sync ---"

CI_FILE="$REPO_ROOT/.github/workflows/ci.yml"

if [[ ! -f "$CI_FILE" ]]; then
  warn "AC-TOKEN-004: .github/workflows/ci.yml not found — CI coverage unverifiable"
else
  # Check for this script's syntax check in monitoring-guardrails
  if grep -q 'verify-token-drift.sh' "$CI_FILE"; then
    pass "AC-TOKEN-004: verify-token-drift.sh is referenced in CI workflow"
  else
    fail "AC-TOKEN-004: verify-token-drift.sh is NOT referenced in CI workflow"
    echo "  Fix: Add 'bash -n scripts/qa/verify-token-drift.sh' to monitoring-guardrails job"
    echo "       and a 'token-drift' job that runs './scripts/qa/verify-token-drift.sh'"
  fi

  # Check for design-token-validation job (broader artifact sync coverage)
  if grep -q 'design-token-validation' "$CI_FILE"; then
    pass "AC-TOKEN-004: design-token-validation job present in CI"
  else
    warn "AC-TOKEN-004: design-token-validation job not found in CI"
  fi

  # Check for tokens.provenance.json validation (artifact sync evidence)
  if grep -q 'tokens.provenance.json' "$CI_FILE"; then
    pass "AC-TOKEN-004: tokens.provenance.json validation present in CI (artifact sync gate)"
  else
    warn "AC-TOKEN-004: tokens.provenance.json not validated in CI — drift from upstream brand assets repo undetected"
  fi

  # Check for branding-token-integrity job (existing cross-check)
  if grep -q 'branding-token-integrity' "$CI_FILE"; then
    pass "AC-TOKEN-004: branding-token-integrity job present in CI"
  else
    warn "AC-TOKEN-004: branding-token-integrity job not found in CI"
  fi
fi

# Check for TOKEN_DRIFT_REMEDIATION doc (drift-check documentation)
DOC_PATH="$REPO_ROOT/docs/runbooks/architecture/TOKEN_DRIFT_REMEDIATION.md"
if [[ -f "$DOC_PATH" ]]; then
  pass "AC-TOKEN-004: TOKEN_DRIFT_REMEDIATION.md present (drift-check flow documented)"
else
  warn "AC-TOKEN-004: docs/runbooks/architecture/TOKEN_DRIFT_REMEDIATION.md not found — create it to document drift-check flow"
fi

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo "=== Summary ==="
echo -e "${GREEN}PASS:${NC} $PASS | ${RED}FAIL:${NC} $FAIL | ${YELLOW}WARN:${NC} $WARN"

if [[ "$FAIL" -gt 0 ]]; then
  echo ""
  echo "Drift remediation steps:"
  echo "  1. Identify each undefined token in the output above"
  echo "  2. Decide: define it in _tokens.scss :root, OR replace the reference with a defined token"
  echo "  3. Mirror any new definitions in all three mereka-overrides.css targets (common/lms/cms)"
  echo "  4. Re-run this script to confirm PASS"
  echo "  5. See docs/runbooks/architecture/TOKEN_DRIFT_REMEDIATION.md for the full canonical procedure"
  exit 1
fi

exit 0
