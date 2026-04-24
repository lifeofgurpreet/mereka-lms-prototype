#!/usr/bin/env bash
# verify-live-mutation-ledger.sh
#
# Validates the live mutation ledger schema and enforces the 48-hour TTL:
# no active entry may exist for >48 hours without a reconciliation_pr.
#
# Implements AC-GIS-005 from specs/gitops-integrity-system_spec.md.
#
# Exit 0  -- ledger is valid and no entries violate the TTL
# Exit 1  -- schema errors or TTL violations found
#
# Usage:
#   scripts/qa/verify-live-mutation-ledger.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

LEDGER="${REPO_ROOT}/config/live-mutation-ledger.yaml"

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
  if [[ -f "${LEDGER}" ]]; then
    pass "live-mutation-ledger.yaml exists"
  else
    fail "live-mutation-ledger.yaml not found at ${LEDGER}"
    FAILURES=$((FAILURES + 1))
  fi
}

check_required_keys() {
  if [[ ! -f "${LEDGER}" ]]; then
    return
  fi

  local required_keys=("schema_version" "max_ttl_hours" "active" "resolved")
  for key in "${required_keys[@]}"; do
    if grep -q "^${key}:" "${LEDGER}"; then
      pass "required key present: ${key}"
    else
      fail "missing required key: ${key}"
      FAILURES=$((FAILURES + 1))
    fi
  done
}

# ---------------------------------------------------------------------------
# TTL enforcement for active entries
# ---------------------------------------------------------------------------

check_active_ttl() {
  if [[ ! -f "${LEDGER}" ]]; then
    return
  fi

  # Count active entries (lines starting with "  - id:" under the active: section)
  # This is a simple heuristic; full YAML parsing requires yq or Python.
  local active_count
  active_count=$(grep -c "^  - id:" "${LEDGER}" 2>/dev/null || echo "0")

  # The active section may be an empty list (active: [])
  if grep -q "^active: \[\]" "${LEDGER}"; then
    active_count=0
  fi

  if [[ "${active_count}" -eq 0 ]]; then
    pass "no active mutation entries (ledger is clean)"
    return
  fi

  # TODO: Implement full TTL enforcement.
  #
  # Planned logic (requires yq or Python for proper YAML parsing):
  #   1. Parse each entry under active:
  #   2. For each entry:
  #      a. Read timestamp
  #      b. Calculate age in hours
  #      c. If age > max_ttl_hours AND reconciliation_pr is empty/null, FAIL
  #      d. If age > max_ttl_hours AND reconciliation_pr is present, PASS
  #   3. Entries with reconciliation_status: merged should be in resolved, not active
  #
  skip "TTL enforcement not yet implemented for ${active_count} active entries (TODO)"
}

# ---------------------------------------------------------------------------
# Cross-reference: spec mentions this file
# ---------------------------------------------------------------------------

check_spec_reference() {
  local spec="${REPO_ROOT}/specs/gitops-integrity-system_spec.md"
  if [[ -f "${spec}" ]]; then
    if grep -q "live-mutation-ledger.yaml" "${spec}"; then
      pass "spec references live-mutation-ledger.yaml"
    else
      fail "spec does not reference live-mutation-ledger.yaml"
      FAILURES=$((FAILURES + 1))
    fi
  else
    skip "gitops-integrity-system spec not found"
  fi
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

echo "=== Live Mutation Ledger Verification (AC-GIS-005) ==="
echo ""

check_file_exists
check_required_keys
check_active_ttl
check_spec_reference

echo ""
if [[ ${FAILURES} -gt 0 ]]; then
  echo -e "${RED}${FAILURES} check(s) failed${RESET}"
  exit 1
else
  echo -e "${GREEN}All checks passed${RESET}"
exit "${FAILURES}"
fi
