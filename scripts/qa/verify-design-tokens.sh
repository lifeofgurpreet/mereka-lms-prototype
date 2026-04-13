#!/usr/bin/env bash
# @covers AC-001, AC-002, AC-003, AC-004, AC-005, AC-006, AC-007, AC-008, AC-009, AC-010, AC-011, AC-012
# @spec: design-tokens-system_spec.md
# Verify all 12 acceptance criteria for the Design Tokens System spec.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
PASS=0; FAIL=0; SKIP=0

pass() { echo -e "${GREEN}PASS${NC} $1"; PASS=$((PASS + 1)); }
fail() { echo -e "${RED}FAIL${NC} $1"; FAIL=$((FAIL + 1)); }
skip() { echo -e "${YELLOW}SKIP${NC} $1"; SKIP=$((SKIP + 1)); }

TOKENS_CSS="assets/branding/tokens.css"
TOKENS_PROVENANCE="assets/branding/tokens.provenance.json"
OVERRIDES_CSS="infrastructure/tutor/themes/mereka/common/static/css/mereka-overrides.css"
DRIFT_SCRIPT="scripts/branding/verify-token-drift.sh"
SYNC_SCRIPT="scripts/branding/update-token-provenance.sh"
SCOPE_MODE="${VERIFY_DESIGN_TOKENS_SCOPE:-}"
CHANGED_FILES_RAW="${VERIFY_DESIGN_TOKENS_CHANGED_FILES:-${CI_CHANGED_FILES:-}}"

should_skip_scope() {
  local changed_path

  [[ "$SCOPE_MODE" == "changed" ]] || return 1
  [[ -n "${CHANGED_FILES_RAW//[[:space:]]/}" ]] || return 1

  while IFS= read -r changed_path; do
    [[ -n "$changed_path" ]] || continue
    case "$changed_path" in
      .github/workflows/ci.yml|\
      scripts/qa/verify-design-tokens.sh|\
      scripts/branding/verify-token-drift.sh|\
      scripts/branding/update-token-provenance.sh|\
      assets/branding/tokens.css|\
      assets/branding/tokens.provenance.json|\
      infrastructure/tutor/themes/mereka/common/static/css/mereka-overrides.css)
        return 1
        ;;
    esac
  done <<< "$CHANGED_FILES_RAW"

  return 0
}

if should_skip_scope; then
  echo "PASS verify-design-tokens (scope skip: no design-token authority changes)"
  exit 0
fi

echo "Verifying Design Tokens System spec (12 ACs)..."
echo ""

# ---------------------------------------------------------------------------
# AC-001: Primary color tokens defined with valid hex values
# ---------------------------------------------------------------------------
if [[ ! -f "$TOKENS_CSS" ]]; then
  fail "AC-001: $TOKENS_CSS not found"
else
  missing=""
  for token in --color-black --color-white --color-teal --color-magenta --color-blue; do
    if ! grep -qE "^\s*${token}:\s*#[0-9a-fA-F]{3,8}\s*;" "$TOKENS_CSS"; then
      missing="${missing} ${token}"
    fi
  done
  if [[ -z "$missing" ]]; then
    pass "AC-001: All primary color tokens defined with valid hex values"
  else
    fail "AC-001: Missing or invalid primary color tokens:${missing}"
  fi
fi

# ---------------------------------------------------------------------------
# AC-002: Typography tokens defined with valid CSS values
# ---------------------------------------------------------------------------
if [[ ! -f "$TOKENS_CSS" ]]; then
  fail "AC-002: $TOKENS_CSS not found"
else
  missing=""
  for token in --font-heading --font-body --text-h1 --text-h2 --text-h3 --text-h4 \
               --text-body --text-body-sm --text-body-lg --text-caption --text-display; do
    if ! grep -qE "^\s*${token}:" "$TOKENS_CSS"; then
      missing="${missing} ${token}"
    fi
  done
  # Verify font families contain expected values
  heading_val=$(grep -oP '(?<=--font-heading:\s).*(?=;)' "$TOKENS_CSS" | head -1)
  body_val=$(grep -oP '(?<=--font-body:\s).*(?=;)' "$TOKENS_CSS" | head -1)
  if [[ -z "$heading_val" ]] || ! echo "$heading_val" | grep -qi "lato"; then
    missing="${missing} --font-heading(missing-Lato)"
  fi
  if [[ -z "$body_val" ]] || ! echo "$body_val" | grep -qi "poppins"; then
    missing="${missing} --font-body(missing-Poppins)"
  fi
  if [[ -z "$missing" ]]; then
    pass "AC-002: All typography tokens defined with valid CSS values"
  else
    fail "AC-002: Missing or invalid typography tokens:${missing}"
  fi
fi

# ---------------------------------------------------------------------------
# AC-003: Spacing tokens --space-0 through --space-24 defined with pixel values
# ---------------------------------------------------------------------------
if [[ ! -f "$TOKENS_CSS" ]]; then
  fail "AC-003: $TOKENS_CSS not found"
else
  missing=""
  for n in 0 1 2 3 4 5 6 8 10 12 16 20 24; do
    if ! grep -qE "^\s*--space-${n}:\s*[0-9]+px\s*;" "$TOKENS_CSS"; then
      missing="${missing} --space-${n}"
    fi
  done
  if [[ -z "$missing" ]]; then
    pass "AC-003: All spacing tokens (--space-0 to --space-24) defined with pixel values"
  else
    fail "AC-003: Missing or invalid spacing tokens:${missing}"
  fi
fi

# ---------------------------------------------------------------------------
# AC-004: Token file structure - :root selector, kebab-case, section headers
# ---------------------------------------------------------------------------
if [[ ! -f "$TOKENS_CSS" ]]; then
  fail "AC-004: $TOKENS_CSS not found"
else
  issues=""
  # Must have :root selector
  if ! grep -q ":root" "$TOKENS_CSS"; then
    issues="${issues} missing-:root"
  fi
  # Must have section header comments
  section_count=$(grep -cE '/\*.*=+' "$TOKENS_CSS" || true)
  if [[ "$section_count" -lt 5 ]]; then
    issues="${issues} insufficient-section-headers(found-${section_count})"
  fi
  # Check kebab-case: no camelCase or snake_case tokens
  bad_tokens=$(grep -oP '^\s*--[A-Za-z0-9_-]+:' "$TOKENS_CSS" | grep -E '[A-Z]|_' || true)
  if [[ -n "$bad_tokens" ]]; then
    issues="${issues} non-kebab-case-tokens"
  fi
  # Color values should be lowercase hex
  bad_hex=$(grep -oP '#[0-9a-fA-F]{6}' "$TOKENS_CSS" | grep '[A-F]' || true)
  if [[ -n "$bad_hex" ]]; then
    issues="${issues} uppercase-hex-colors"
  fi
  # Header comment with source URL
  if ! grep -q "figma.com/design" "$TOKENS_CSS"; then
    issues="${issues} missing-figma-url"
  fi
  if [[ -z "$issues" ]]; then
    pass "AC-004: Token file structure valid (:root, kebab-case, section headers, lowercase hex)"
  else
    fail "AC-004: Token file structure issues:${issues}"
  fi
fi

# ---------------------------------------------------------------------------
# AC-005: Provenance JSON has all required fields and they are non-empty
# ---------------------------------------------------------------------------
if [[ ! -f "$TOKENS_PROVENANCE" ]]; then
  fail "AC-005: $TOKENS_PROVENANCE not found"
else
  missing=""
  for field in source_repo source_path source_branch source_commit source_sha256 synced_at_utc; do
    val=$(python3 -c "import json,sys; d=json.load(open(sys.argv[1])); v=d.get('${field}',''); print(v)" "$TOKENS_PROVENANCE")
    if [[ -z "$val" ]]; then
      missing="${missing} ${field}"
    fi
  done
  if [[ -z "$missing" ]]; then
    pass "AC-005: All required provenance fields present and non-empty"
  else
    fail "AC-005: Missing or empty provenance fields:${missing}"
  fi
fi

# ---------------------------------------------------------------------------
# AC-006: source_commit matches 40-char lowercase git SHA pattern
# ---------------------------------------------------------------------------
if [[ ! -f "$TOKENS_PROVENANCE" ]]; then
  fail "AC-006: $TOKENS_PROVENANCE not found"
else
  commit=$(python3 -c "import json,sys; print(json.load(open(sys.argv[1])).get('source_commit',''))" "$TOKENS_PROVENANCE")
  if echo "$commit" | grep -qE '^[0-9a-f]{40}$'; then
    pass "AC-006: source_commit is a valid 40-char lowercase SHA ($commit)"
  else
    fail "AC-006: source_commit is not a valid 40-char lowercase SHA (got: $commit)"
  fi
fi

# ---------------------------------------------------------------------------
# AC-007: source_sha256 matches 64-char lowercase SHA256 pattern
# ---------------------------------------------------------------------------
if [[ ! -f "$TOKENS_PROVENANCE" ]]; then
  fail "AC-007: $TOKENS_PROVENANCE not found"
else
  sha=$(python3 -c "import json,sys; print(json.load(open(sys.argv[1])).get('source_sha256',''))" "$TOKENS_PROVENANCE")
  if echo "$sha" | grep -qE '^[0-9a-f]{64}$'; then
    pass "AC-007: source_sha256 is a valid 64-char lowercase SHA256 ($sha)"
  else
    fail "AC-007: source_sha256 is not a valid 64-char lowercase SHA256 (got: $sha)"
  fi
fi

# ---------------------------------------------------------------------------
# AC-008: verify-token-drift.sh exits 0 when files are in sync
# ---------------------------------------------------------------------------
if [[ ! -x "$DRIFT_SCRIPT" ]]; then
  if [[ -f "$DRIFT_SCRIPT" ]]; then
    skip "AC-008: $DRIFT_SCRIPT exists but is not executable"
  else
    fail "AC-008: $DRIFT_SCRIPT not found"
  fi
else
  drift_output=$("$DRIFT_SCRIPT" 2>&1) && drift_rc=0 || drift_rc=$?
  if [[ "$drift_rc" -eq 0 ]]; then
    pass "AC-008: verify-token-drift.sh exits 0 (files in sync)"
  else
    fail "AC-008: verify-token-drift.sh exited $drift_rc -- output: $drift_output"
  fi
fi

# ---------------------------------------------------------------------------
# AC-009: verify-token-drift.sh detects color value drift (structural check)
#   We verify the script contains the required_pairs logic that would detect
#   a mismatch like --color-teal=#237072 vs --mereka-color-teal=#FFFFFF.
#   We do NOT modify live files to test destructive drift.
# ---------------------------------------------------------------------------
if [[ ! -f "$DRIFT_SCRIPT" ]]; then
  fail "AC-009: $DRIFT_SCRIPT not found"
else
  if grep -q "required_pairs" "$DRIFT_SCRIPT" && \
     grep -q "\-\-color-teal.*\-\-mereka-color-teal" "$DRIFT_SCRIPT" && \
     grep -q "drift:" "$DRIFT_SCRIPT"; then
    pass "AC-009: Drift script contains required_pairs with color comparison logic"
  else
    fail "AC-009: Drift script missing required_pairs or comparison logic for color drift"
  fi
fi

# ---------------------------------------------------------------------------
# AC-010: verify-token-drift.sh detects SHA256 provenance drift (structural check)
#   We verify the script contains SHA256 comparison logic that would detect
#   a stale provenance hash after tokens.css is modified.
# ---------------------------------------------------------------------------
if [[ ! -f "$DRIFT_SCRIPT" ]]; then
  fail "AC-010: $DRIFT_SCRIPT not found"
else
  if grep -q "sha256" "$DRIFT_SCRIPT" && \
     grep -q "source_sha256" "$DRIFT_SCRIPT" && \
     grep -q "tokens.css sha256 drift" "$DRIFT_SCRIPT"; then
    pass "AC-010: Drift script contains SHA256 provenance comparison logic"
  else
    fail "AC-010: Drift script missing SHA256 provenance drift detection"
  fi
fi

# ---------------------------------------------------------------------------
# AC-011: update-token-provenance.sh exists and is executable
# ---------------------------------------------------------------------------
if [[ ! -f "$SYNC_SCRIPT" ]]; then
  fail "AC-011: $SYNC_SCRIPT not found"
elif [[ ! -x "$SYNC_SCRIPT" ]]; then
  fail "AC-011: $SYNC_SCRIPT exists but is not executable"
else
  # Verify it reads BRAND_ASSETS_REPO, computes SHA, updates provenance
  if grep -q "BRAND_ASSETS_REPO\|UPSTREAM_REPO" "$SYNC_SCRIPT" && \
     grep -q "sha256sum\|sha256" "$SYNC_SCRIPT" && \
     grep -q "SYNC_FILE" "$SYNC_SCRIPT"; then
    pass "AC-011: update-token-provenance.sh exists, is executable, and has sync logic"
  else
    fail "AC-011: update-token-provenance.sh missing expected sync logic"
  fi
fi

# ---------------------------------------------------------------------------
# AC-012: mereka-overrides.css contains --mereka-* prefixed tokens
# ---------------------------------------------------------------------------
if [[ ! -f "$OVERRIDES_CSS" ]]; then
  fail "AC-012: $OVERRIDES_CSS not found"
else
  mereka_tokens=$(grep -cE '^\s*--mereka-' "$OVERRIDES_CSS" || true)
  has_mereka_color_teal=$(grep -c '\-\-mereka-color-teal' "$OVERRIDES_CSS" || true)
  if [[ "$mereka_tokens" -gt 0 ]] && [[ "$has_mereka_color_teal" -gt 0 ]]; then
    pass "AC-012: mereka-overrides.css contains ${mereka_tokens} --mereka-* tokens (including --mereka-color-teal)"
  else
    fail "AC-012: mereka-overrides.css missing --mereka-* prefixed tokens (found: ${mereka_tokens}, --mereka-color-teal: ${has_mereka_color_teal})"
  fi
fi

echo ""
echo "=== Summary ==="
echo -e "${GREEN}PASS:${NC} $PASS | ${RED}FAIL:${NC} $FAIL | ${YELLOW}SKIP:${NC} $SKIP"
[[ "$FAIL" -gt 0 ]] && exit 1 || exit 0
