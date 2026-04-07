#!/usr/bin/env bash
# verify-incident-guardrails.sh
#
# Verifies that every incident record in config/incidents/ older than 7 days
# has all 3 required guardrail artifacts: rule_ref, detector_ref, policy_ref.
#
# Implements AC-GIS-004 from specs/gitops-integrity-system_spec.md.
#
# Exit 0  -- all incidents have complete guardrails (or none are overdue)
# Exit 1  -- one or more incidents are missing guardrail artifacts
#
# Usage:
#   scripts/qa/verify-incident-guardrails.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

INCIDENTS_DIR="${REPO_ROOT}/config/incidents"
GUARDRAIL_DEADLINE_DAYS=7

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
CHECKED=0

# ---------------------------------------------------------------------------
# Directory check
# ---------------------------------------------------------------------------

check_incidents_dir() {
  if [[ -d "${INCIDENTS_DIR}" ]]; then
    pass "incidents directory exists"
  else
    fail "incidents directory not found at ${INCIDENTS_DIR}"
    FAILURES=$((FAILURES + 1))
  fi
}

# ---------------------------------------------------------------------------
# Schema check: each incident file has required fields
# ---------------------------------------------------------------------------

check_incident_schema() {
  local file="$1"
  local basename
  basename="$(basename "${file}")"
  local required_fields=("id" "date" "severity" "summary" "root_cause" "affected_layer")

  for field in "${required_fields[@]}"; do
    if ! grep -q "^${field}:" "${file}"; then
      fail "${basename}: missing required field '${field}'"
      FAILURES=$((FAILURES + 1))
    fi
  done
}

# ---------------------------------------------------------------------------
# Guardrail completeness check
# ---------------------------------------------------------------------------

check_guardrail_artifacts() {
  local file="$1"
  local basename
  basename="$(basename "${file}")"

  # Extract date from the incident file
  local incident_date
  incident_date=$(grep "^date:" "${file}" | head -1 | sed 's/^date: *"\{0,1\}//' | sed 's/"\{0,1\} *$//')

  if [[ -z "${incident_date}" ]]; then
    fail "${basename}: could not extract date"
    FAILURES=$((FAILURES + 1))
    return
  fi

  # Calculate age in days
  local incident_epoch current_epoch age_days
  incident_epoch=$(date -d "${incident_date}" +%s 2>/dev/null || echo "0")
  current_epoch=$(date +%s)

  if [[ "${incident_epoch}" -eq 0 ]]; then
    skip "${basename}: could not parse date '${incident_date}'"
    return
  fi

  age_days=$(( (current_epoch - incident_epoch) / 86400 ))

  if [[ ${age_days} -lt ${GUARDRAIL_DEADLINE_DAYS} ]]; then
    pass "${basename}: ${age_days} days old (within ${GUARDRAIL_DEADLINE_DAYS}-day grace period)"
    return
  fi

  # Incident is older than deadline — check for all 3 artifacts
  local guardrail_fields=("rule_ref" "detector_ref" "policy_ref")
  local missing=0

  for field in "${guardrail_fields[@]}"; do
    local value
    value=$(grep "^${field}:" "${file}" | head -1 | sed 's/^[^:]*: *"\{0,1\}//' | sed 's/"\{0,1\} *$//')
    if [[ -z "${value}" || "${value}" == "null" || "${value}" == "~" ]]; then
      fail "${basename}: missing guardrail artifact '${field}' (incident is ${age_days} days old)"
      missing=$((missing + 1))
    fi
  done

  if [[ ${missing} -eq 0 ]]; then
    pass "${basename}: all 3 guardrail artifacts present (${age_days} days old)"
  else
    FAILURES=$((FAILURES + missing))
  fi
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

echo "=== Incident Guardrail Verification (AC-GIS-004) ==="
echo ""

check_incidents_dir

if [[ ! -d "${INCIDENTS_DIR}" ]]; then
  echo ""
  echo -e "${RED}Cannot continue without incidents directory${RESET}"
  exit 1
fi

# Process each incident file
for incident_file in "${INCIDENTS_DIR}"/*.yaml; do
  if [[ ! -f "${incident_file}" ]]; then
    skip "no incident files found in ${INCIDENTS_DIR}"
    break
  fi
  CHECKED=$((CHECKED + 1))
  check_incident_schema "${incident_file}"
  check_guardrail_artifacts "${incident_file}"
done

echo ""
echo "Checked ${CHECKED} incident record(s)"

if [[ ${FAILURES} -gt 0 ]]; then
  echo -e "${RED}${FAILURES} check(s) failed${RESET}"
  exit 1
else
  echo -e "${GREEN}All checks passed${RESET}"
  exit 0
fi
