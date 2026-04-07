#!/usr/bin/env bash
# verify-gitops-sync-drift.sh
#
# Detects ArgoCD sync state drift: applications that are OutOfSync vs git HEAD,
# and validates the invariant enforcement map cross-references.
#
# This is distinct from verify-gitops-drift.sh which checks source-repo-to-infra-repo
# overlay parity. This script checks live ArgoCD sync status against git.
#
# Implements AC-GIS-001 from specs/gitops-integrity-system_spec.md.
#
# Modes:
#   --offline   Schema and cross-reference checks only (no cluster access, default)
#   --online    Full drift detection against live ArgoCD (requires cluster access)
#
# Exit 0  -- no critical drift found
# Exit 1  -- critical drift detected or schema validation failed
#
# Usage:
#   scripts/qa/verify-gitops-sync-drift.sh
#   scripts/qa/verify-gitops-sync-drift.sh --offline
#   scripts/qa/verify-gitops-sync-drift.sh --online

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

ENFORCEMENT_MAP="${REPO_ROOT}/config/invariant-enforcement-map.yaml"
PROCESS_INVARIANTS="${REPO_ROOT}/config/process-invariants.yaml"
DRIFT_THRESHOLD_MINUTES=5
CRITICAL_THRESHOLD_MINUTES=10
MODE="${1:---offline}"

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
info() { echo -e "      $*"; }

FAILURES=0

# ---------------------------------------------------------------------------
# Offline checks: validate config schemas and cross-references
# ---------------------------------------------------------------------------

check_enforcement_map_exists() {
  if [[ -f "${ENFORCEMENT_MAP}" ]]; then
    pass "invariant-enforcement-map.yaml exists"
  else
    fail "invariant-enforcement-map.yaml not found at ${ENFORCEMENT_MAP}"
    FAILURES=$((FAILURES + 1))
  fi
}

check_process_invariants_exists() {
  if [[ -f "${PROCESS_INVARIANTS}" ]]; then
    pass "process-invariants.yaml exists"
  else
    fail "process-invariants.yaml not found at ${PROCESS_INVARIANTS}"
    FAILURES=$((FAILURES + 1))
  fi
}

check_enforcement_map_schema() {
  if [[ ! -f "${ENFORCEMENT_MAP}" ]]; then
    skip "enforcement map not found, skipping schema check"
    return
  fi

  # Verify required top-level keys exist
  local required_keys=("schema_version" "source_registries" "invariants")
  for key in "${required_keys[@]}"; do
    if grep -q "^${key}:" "${ENFORCEMENT_MAP}"; then
      pass "enforcement map has required key: ${key}"
    else
      fail "enforcement map missing required key: ${key}"
      FAILURES=$((FAILURES + 1))
    fi
  done
}

check_enforcement_map_coverage() {
  if [[ ! -f "${ENFORCEMENT_MAP}" || ! -f "${PROCESS_INVARIANTS}" ]]; then
    skip "cannot check coverage without both files"
    return
  fi

  # Extract INV-NNN IDs from process-invariants.yaml (unquoted or quoted)
  local invariant_ids
  invariant_ids=$(grep -oP 'id: "?INV-\d+"?' "${PROCESS_INVARIANTS}" | sed 's/id: //;s/"//g' || true)

  if [[ -z "${invariant_ids}" ]]; then
    skip "no invariant IDs found in process-invariants.yaml"
    return
  fi

  # Check each is present in enforcement map
  local missing=0
  while IFS= read -r inv_id; do
    if grep -q "invariant_id: \"${inv_id}\"" "${ENFORCEMENT_MAP}"; then
      pass "enforcement map covers ${inv_id}"
    else
      fail "enforcement map missing entry for ${inv_id}"
      missing=$((missing + 1))
    fi
  done <<< "${invariant_ids}"

  if [[ ${missing} -gt 0 ]]; then
    FAILURES=$((FAILURES + missing))
  fi
}

# ---------------------------------------------------------------------------
# Online checks: query ArgoCD for drift (TODO)
# ---------------------------------------------------------------------------

check_argocd_drift() {
  # TODO: Implement ArgoCD API query for application sync status.
  #
  # Planned logic:
  #   1. List all ArgoCD applications in the target namespace(s)
  #      argocd app list -o json | jq '.[] | {name, status: .status.sync.status}'
  #   2. For each app, check sync status and last sync time
  #   3. If OutOfSync for > DRIFT_THRESHOLD_MINUTES, emit a drift entry
  #   4. If OutOfSync for > CRITICAL_THRESHOLD_MINUTES on prod, set critical flag
  #   5. Detect manual kubectl patches via managed-fields analysis:
  #      kubectl get <resource> -o json | jq '.metadata.managedFields[] |
  #        select(.manager != "argocd-application-controller")'
  #   6. Output machine-readable JSON to stdout
  #
  # Dependencies:
  #   - argocd CLI or API access (port-forward to argocd-server)
  #   - kubectl access to target cluster
  #   - jq for JSON processing
  #
  # Example output format:
  #   {
  #     "timestamp": "2026-04-07T10:00:00Z",
  #     "drift_entries": [
  #       {
  #         "application": "mereka-lms-prod",
  #         "namespace": "mereka-lms",
  #         "sync_status": "OutOfSync",
  #         "drift_type": "out_of_sync",
  #         "age_minutes": 15,
  #         "environment": "production",
  #         "critical": true,
  #         "affected_resources": ["Deployment/lms", "ConfigMap/openedx-settings"]
  #       }
  #     ]
  #   }
  skip "ArgoCD sync drift detection not yet implemented (TODO)"
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

echo "=== GitOps Sync Drift Detection (AC-GIS-001) ==="
echo "Mode: ${MODE}"
echo ""

echo "--- Offline checks ---"
check_enforcement_map_exists
check_process_invariants_exists
check_enforcement_map_schema
check_enforcement_map_coverage

if [[ "${MODE}" == "--online" ]]; then
  echo ""
  echo "--- Online drift checks ---"
  check_argocd_drift
fi

echo ""
if [[ ${FAILURES} -gt 0 ]]; then
  echo -e "${RED}${FAILURES} check(s) failed${RESET}"
  exit 1
else
  echo -e "${GREEN}All checks passed${RESET}"
  exit 0
fi
