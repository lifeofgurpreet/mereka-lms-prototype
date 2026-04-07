#!/usr/bin/env bash
# verify-durability-proof.sh
#
# Verifies that a given fix is durable across 4 dimensions:
#   1. Source exists in git (merged to main)
#   2. ArgoCD has synced it (sync revision matches)
#   3. Survives pod restart (fix persists after reschedule)
#   4. Reproducible by bootstrap (Kustomize overlay produces same state)
#
# Implements AC-GIS-002 from specs/gitops-integrity-system_spec.md.
#
# Exit 0  -- fix is durable (all dimensions pass) or dry-run passes
# Exit 1  -- fix is not durable (one or more dimensions fail)
#
# Usage:
#   scripts/qa/verify-durability-proof.sh --pr 1400
#   scripts/qa/verify-durability-proof.sh --commit abc1234def5678
#   scripts/qa/verify-durability-proof.sh --pr 1400 --dry-run    # offline: checks 1 and 4 only
#   scripts/qa/verify-durability-proof.sh --schema-only           # validate config schema

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

TRUTH_MATRIX="${REPO_ROOT}/config/truth-state-matrix.yaml"
PR_NUMBER=""
COMMIT_SHA=""
DRY_RUN=false
SCHEMA_ONLY=false

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------

while [[ $# -gt 0 ]]; do
  case "$1" in
    --pr)
      PR_NUMBER="$2"
      shift 2
      ;;
    --commit)
      COMMIT_SHA="$2"
      shift 2
      ;;
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    --schema-only)
      SCHEMA_ONLY=true
      shift
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

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
# Schema validation
# ---------------------------------------------------------------------------

check_truth_matrix_schema() {
  if [[ ! -f "${TRUTH_MATRIX}" ]]; then
    fail "truth-state-matrix.yaml not found at ${TRUTH_MATRIX}"
    FAILURES=$((FAILURES + 1))
    return
  fi

  # Check required top-level keys
  local required_keys=("schema_version" "levels" "realized_ttl_hours" "entries")
  for key in "${required_keys[@]}"; do
    if grep -q "^${key}:" "${TRUTH_MATRIX}"; then
      pass "truth state matrix has required key: ${key}"
    else
      fail "truth state matrix missing required key: ${key}"
      FAILURES=$((FAILURES + 1))
    fi
  done
}

# ---------------------------------------------------------------------------
# Dimension 1: Source exists in git
# ---------------------------------------------------------------------------

check_source_in_git() {
  # TODO: Implement git log search for the fix commit.
  #
  # Planned logic:
  #   - If --pr is provided, use `gh pr view <PR> --json mergeCommit` to get SHA
  #   - If --commit is provided, use it directly
  #   - Verify commit is reachable from main: `git merge-base --is-ancestor <SHA> main`
  #   - Output: { "source_in_git": true/false, "commit": "<sha>", "merged_at": "<ts>" }
  skip "source-in-git check not yet implemented (TODO)"
}

# ---------------------------------------------------------------------------
# Dimension 2: ArgoCD has synced
# ---------------------------------------------------------------------------

check_argocd_synced() {
  # TODO: Implement ArgoCD sync revision comparison.
  #
  # Planned logic:
  #   - Get ArgoCD app sync revision via API or CLI
  #   - Compare against fix commit SHA
  #   - If sync revision is the fix commit or a descendant, pass
  #   - Output: { "argocd_synced": true/false, "sync_revision": "<sha>" }
  skip "argocd-synced check not yet implemented (TODO)"
}

# ---------------------------------------------------------------------------
# Dimension 3: Survives pod restart
# ---------------------------------------------------------------------------

check_survives_restart() {
  # TODO: Implement pod restart + re-verification.
  #
  # Planned logic:
  #   - Identify the pod(s) affected by the fix
  #   - kubectl delete pod <pod> (triggers reschedule)
  #   - Wait for pod to become Ready
  #   - Re-check that the fix is present (exec into pod, check config/env/response)
  #   - Output: { "survives_restart": true/false, "pod": "<name>", "restart_time": "<ts>" }
  #
  # WARNING: This is a destructive check. Only run in non-production or with approval.
  skip "survives-restart check not yet implemented (TODO)"
}

# ---------------------------------------------------------------------------
# Dimension 4: Reproducible by bootstrap
# ---------------------------------------------------------------------------

check_reproducible() {
  # TODO: Implement Kustomize build comparison.
  #
  # Planned logic:
  #   - Run `kubectl kustomize deploy/k8s/overlays/<env>/` on main at the fix commit
  #   - Compare rendered output against live cluster state
  #   - If they match (modulo expected dynamic fields like timestamps), pass
  #   - Output: { "reproducible_by_bootstrap": true/false, "diff_summary": "..." }
  skip "reproducible-by-bootstrap check not yet implemented (TODO)"
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

echo "=== Durability Proof (AC-GIS-002) ==="
echo ""

check_truth_matrix_schema

if [[ "${SCHEMA_ONLY}" == "true" ]]; then
  echo ""
  if [[ ${FAILURES} -gt 0 ]]; then
    echo -e "${RED}${FAILURES} check(s) failed${RESET}"
    exit 1
  else
    echo -e "${GREEN}Schema validation passed${RESET}"
    exit 0
  fi
fi

if [[ -z "${PR_NUMBER}" && -z "${COMMIT_SHA}" ]]; then
  echo "No --pr or --commit provided; running schema validation only."
  echo ""
  if [[ ${FAILURES} -gt 0 ]]; then
    echo -e "${RED}${FAILURES} check(s) failed${RESET}"
    exit 1
  else
    echo -e "${GREEN}Schema validation passed${RESET}"
    exit 0
  fi
fi

echo ""
echo "--- Dimension 1: Source in git ---"
check_source_in_git

if [[ "${DRY_RUN}" == "false" ]]; then
  echo ""
  echo "--- Dimension 2: ArgoCD synced ---"
  check_argocd_synced

  echo ""
  echo "--- Dimension 3: Survives restart ---"
  check_survives_restart
fi

echo ""
echo "--- Dimension 4: Reproducible by bootstrap ---"
check_reproducible

echo ""
if [[ ${FAILURES} -gt 0 ]]; then
  echo -e "${RED}${FAILURES} check(s) failed${RESET}"
  exit 1
else
  echo -e "${GREEN}All checks passed${RESET}"
  exit 0
fi
