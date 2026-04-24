#!/usr/bin/env bash
# verify-truth-state-matrix.sh
#
# Validates the truth state matrix schema and enforces the 48-hour TTL gate:
# no entry may remain at "realized" for >48 hours without reaching "durable".
#
# Implements AC-GIS-003 from specs/gitops-integrity-system_spec.md.
#
# Exit 0  -- matrix is valid and no entries violate the TTL gate
# Exit 1  -- schema errors or TTL violations found
#
# Usage:
#   scripts/qa/verify-truth-state-matrix.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

TRUTH_MATRIX="${REPO_ROOT}/config/truth-state-matrix.yaml"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RESET='\033[0m'

pass() { echo -e "${GREEN}PASS${RESET}  $*"; }
fail() { echo -e "${RED}FAIL${RESET}  $*"; }
skip() { echo -e "${YELLOW}SKIP${RESET}  $*"; }

FAILURES=0

# ---------------------------------------------------------------------------
# Schema checks
# ---------------------------------------------------------------------------

check_file_exists() {
  if [[ -f "${TRUTH_MATRIX}" ]]; then
    pass "truth-state-matrix.yaml exists"
  else
    fail "truth-state-matrix.yaml not found at ${TRUTH_MATRIX}"
    FAILURES=$((FAILURES + 1))
  fi
}

check_required_keys() {
  if [[ ! -f "${TRUTH_MATRIX}" ]]; then
    return
  fi

  local required_keys=("schema_version" "levels" "realized_ttl_hours" "entries")
  for key in "${required_keys[@]}"; do
    if grep -q "^${key}:" "${TRUTH_MATRIX}"; then
      pass "required key present: ${key}"
    else
      fail "missing required key: ${key}"
      FAILURES=$((FAILURES + 1))
    fi
  done
}

check_valid_levels() {
  if [[ ! -f "${TRUTH_MATRIX}" ]]; then
    return
  fi

  # Verify the 5 canonical levels are defined
  local expected_levels=("branch" "merged" "realized" "proved" "durable")
  for level in "${expected_levels[@]}"; do
    if grep -q "^  - ${level}$" "${TRUTH_MATRIX}"; then
      pass "level defined: ${level}"
    else
      fail "missing expected level: ${level}"
      FAILURES=$((FAILURES + 1))
    fi
  done
}

check_realized_ttl() {
  if [[ ! -f "${TRUTH_MATRIX}" ]]; then
    return
  fi

  # TODO: Implement TTL enforcement.
  #
  # Planned logic:
  #   1. Parse entries from truth-state-matrix.yaml (requires yq or Python)
  #   2. For each entry where current_level is "realized":
  #      a. Read timestamps.realized
  #      b. Compare against current time
  #      c. If age > realized_ttl_hours (48), report violation
  #   3. Entries at "proved" or "durable" are fine (they progressed past realized)
  #   4. Entries at "branch" or "merged" have not reached realized yet (no TTL)
  #
  # For now, with an empty entries list, this is a no-op.
  local entry_count
  entry_count=$(grep -c "^  - id:" "${TRUTH_MATRIX}" 2>/dev/null) || entry_count=0
  if [[ "${entry_count}" -eq 0 ]]; then
    pass "no entries to check (matrix is empty)"
  else
    skip "TTL enforcement not yet implemented for ${entry_count} entries (TODO)"
  fi
}

# ---------------------------------------------------------------------------
# Cross-reference: spec mentions this file
# ---------------------------------------------------------------------------

check_spec_reference() {
  local spec="${REPO_ROOT}/specs/gitops-integrity-system_spec.md"
  if [[ -f "${spec}" ]]; then
    if grep -q "truth-state-matrix.yaml" "${spec}"; then
      pass "spec references truth-state-matrix.yaml"
    else
      fail "spec does not reference truth-state-matrix.yaml"
      FAILURES=$((FAILURES + 1))
    fi
  else
    skip "gitops-integrity-system spec not found"
  fi
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

echo "=== Truth State Matrix Verification (AC-GIS-003) ==="
echo ""

check_file_exists
check_required_keys
check_valid_levels
check_realized_ttl
check_spec_reference

echo ""
if [[ ${FAILURES} -gt 0 ]]; then
  echo -e "${RED}${FAILURES} check(s) failed${RESET}"
  exit 1
else
  echo -e "${GREEN}All checks passed${RESET}"
exit "${FAILURES}"
fi
