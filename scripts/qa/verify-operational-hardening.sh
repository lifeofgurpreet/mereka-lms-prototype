#!/usr/bin/env bash
# @covers AC-004, AC-005, AC-006, AC-007, AC-008, AC-009, AC-010, AC-011
# @spec: k8s-deployment_spec.md
# verify-operational-hardening.sh
# Verify PDBs, HPA baselines, resource requests, and progressDeadlineSeconds
# for all critical workloads.
#
# Usage:
#   ./verify-operational-hardening.sh            # offline (manifest checks)
#   ./verify-operational-hardening.sh --online   # online (live cluster checks)
#   ./verify-operational-hardening.sh --offline  # explicit offline
set -euo pipefail

# ── Colours ─────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# ── Counters ─────────────────────────────────────────────────────────────────
PASS_COUNT=0
FAIL_COUNT=0
SKIP_COUNT=0

# ── Paths ────────────────────────────────────────────────────────────────────
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BASE_DIR="${REPO_ROOT}/deploy/k8s/base"
OPERATIONAL_DIR="${BASE_DIR}/operational"
YQ="${HOME}/.local/bin/yq"

# ── Helpers ──────────────────────────────────────────────────────────────────
pass() {
  echo -e "${GREEN}✓ PASS${NC}: $1"
  PASS_COUNT=$((PASS_COUNT + 1))
}

fail() {
  echo -e "${RED}✗ FAIL${NC}: $1"
  FAIL_COUNT=$((FAIL_COUNT + 1))
}

skip() {
  echo -e "${YELLOW}~ SKIP${NC}: $1"
  SKIP_COUNT=$((SKIP_COUNT + 1))
}

require_yq() {
  if [[ ! -x "$YQ" ]]; then
    echo -e "${RED}Error: yq not found at $YQ${NC}"
    exit 1
  fi
}

# ── Offline checks ───────────────────────────────────────────────────────────

check_pdb_manifests_exist() {
  echo "Checking PDB manifest file exists"

  local pdb_file="${OPERATIONAL_DIR}/pdb.yaml"
  if [[ ! -f "$pdb_file" ]]; then
    fail "PDB manifest not found: $pdb_file"
    return
  fi
  pass "PDB manifest exists at deploy/k8s/base/operational/pdb.yaml"
}

check_pdbs_for_critical_services() {
  echo "Checking PDBs defined for critical services"

  local pdb_file="${OPERATIONAL_DIR}/pdb.yaml"
  if [[ ! -f "$pdb_file" ]]; then
    fail "PDB manifest not found: $pdb_file — skipping service checks"
    return
  fi

  local critical_services=("lms" "cms" "caddy" "redis" "mysql")
  local all_found=true

  for svc in "${critical_services[@]}"; do
    # Capture yq output to avoid SIGPIPE with grep -q
    local names
    names=$("$YQ" eval 'select(.kind == "PodDisruptionBudget") | .metadata.name' "$pdb_file" 2>/dev/null || echo "")
    if echo "$names" | grep -q "^${svc}$"; then
      pass "PDB defined for: $svc"
    else
      fail "PDB missing for critical service: $svc"
      all_found=false
    fi
  done
}

check_pdb_min_available() {
  echo "Checking PDB minAvailable values"

  local pdb_file="${OPERATIONAL_DIR}/pdb.yaml"
  if [[ ! -f "$pdb_file" ]]; then
    fail "PDB manifest not found: $pdb_file"
    return
  fi

  local pdbs
  pdbs=$("$YQ" eval 'select(.kind == "PodDisruptionBudget") | .metadata.name' "$pdb_file" 2>/dev/null | grep -v "^---$" || echo "")

  while IFS= read -r pdb_name; do
    [[ -z "$pdb_name" ]] && continue
    [[ "$pdb_name" == "---" ]] && continue
    local min_avail
    min_avail=$("$YQ" eval "select(.kind == \"PodDisruptionBudget\" and .metadata.name == \"$pdb_name\") | .spec.minAvailable" "$pdb_file" 2>/dev/null | head -1 || echo "")
    if [[ "$min_avail" == "1" ]]; then
      pass "PDB $pdb_name: minAvailable=1"
    else
      fail "PDB $pdb_name: minAvailable=$min_avail (expected 1)"
    fi
  done <<< "$pdbs"
}

check_hpa_manifests_exist() {
  echo "Checking HPA manifest file exists"

  local hpa_file="${OPERATIONAL_DIR}/hpa-baselines.yaml"
  if [[ ! -f "$hpa_file" ]]; then
    fail "HPA manifest not found: $hpa_file"
    return
  fi
  pass "HPA manifest exists at deploy/k8s/base/operational/hpa-baselines.yaml"
}

check_hpa_baselines_reasonable() {
  echo "Checking HPA baseline values are reasonable"

  # HPA manifests are spread across multiple files:
  #   lms, cms         → apps/lms/hpa.yaml, apps/cms/hpa.yaml
  #   lms-worker, cms-worker → operational/hpa-baselines.yaml
  # We check each file for the relevant HPAs, verifying minReplicas and maxReplicas
  # are set and non-zero. Metric type (Utilization vs AverageValue) is not enforced
  # here since both are valid and the per-workload files may evolve independently.

  # File → expected HPA names in that file
  local -a checks=(
    "${BASE_DIR}/apps/lms/hpa.yaml:lms"
    "${BASE_DIR}/apps/cms/hpa.yaml:cms"
    "${OPERATIONAL_DIR}/hpa-baselines.yaml:lms-worker"
    "${OPERATIONAL_DIR}/hpa-baselines.yaml:cms-worker"
  )

  for entry in "${checks[@]}"; do
    local hpa_file="${entry%%:*}"
    local name="${entry##*:}"

    if [[ ! -f "$hpa_file" ]]; then
      fail "HPA manifest not found: $hpa_file (expected HPA for $name)"
      continue
    fi

    local actual_min actual_max
    actual_min=$("$YQ" eval "select(.kind == \"HorizontalPodAutoscaler\" and .metadata.name == \"$name\") | .spec.minReplicas" "$hpa_file" 2>/dev/null | head -1 || echo "")
    actual_max=$("$YQ" eval "select(.kind == \"HorizontalPodAutoscaler\" and .metadata.name == \"$name\") | .spec.maxReplicas" "$hpa_file" 2>/dev/null | head -1 || echo "")

    if [[ -n "$actual_min" && "$actual_min" != "null" && -n "$actual_max" && "$actual_max" != "null" ]]; then
      pass "HPA $name: min=$actual_min max=$actual_max (in $(basename "$hpa_file"))"
    else
      fail "HPA $name: minReplicas or maxReplicas missing in $hpa_file (got min=$actual_min max=$actual_max)"
    fi
  done
}

check_deployments_have_resource_requests() {
  echo "Checking Deployments have resource requests"

  local deployments_file="${BASE_DIR}/deployments.yml"
  if [[ ! -f "$deployments_file" ]]; then
    fail "Deployments file not found: $deployments_file"
    return
  fi

  # LMS and CMS are the primary web workloads; they must have memory requests at minimum.
  local -a web_workloads=("lms" "cms")

  for workload in "${web_workloads[@]}"; do
    local has_requests
    has_requests=$("$YQ" eval "select(.kind == \"Deployment\" and .metadata.name == \"$workload\") | .spec.template.spec.containers[0].resources.requests" "$deployments_file" 2>/dev/null | head -1 || echo "")
    if [[ -n "$has_requests" && "$has_requests" != "null" ]]; then
      pass "Deployment $workload has resource requests"
    else
      fail "Deployment $workload missing resource requests"
    fi
  done
}

check_progress_deadline() {
  echo "Checking progressDeadlineSeconds on critical Deployments"

  local deployments_file="${BASE_DIR}/deployments.yml"
  if [[ ! -f "$deployments_file" ]]; then
    fail "Deployments file not found: $deployments_file"
    return
  fi

  # progressDeadlineSeconds defaults to 600s in Kubernetes if unset.
  # We accept the default as sufficient — just verify the field is not
  # set to an unreasonably low value (< 60) that could cause false rollout failures.
  local -a critical=("lms" "cms")

  for workload in "${critical[@]}"; do
    local deadline
    deadline=$("$YQ" eval "select(.kind == \"Deployment\" and .metadata.name == \"$workload\") | .spec.progressDeadlineSeconds" "$deployments_file" 2>/dev/null | head -1 || echo "")
    if [[ -z "$deadline" || "$deadline" == "null" ]]; then
      # Kubernetes default of 600s applies — acceptable
      pass "Deployment $workload: progressDeadlineSeconds uses K8s default (600s)"
    elif [[ "$deadline" -ge 60 ]]; then
      pass "Deployment $workload: progressDeadlineSeconds=$deadline (≥60s)"
    else
      fail "Deployment $workload: progressDeadlineSeconds=$deadline is too low (<60s)"
    fi
  done
}

check_stateful_services_have_pdbs() {
  echo "Checking stateful services have PDBs"

  local pdb_file="${OPERATIONAL_DIR}/pdb.yaml"
  if [[ ! -f "$pdb_file" ]]; then
    fail "PDB manifest not found: $pdb_file"
    return
  fi

  # Stateful services that persist data — they need PDBs most urgently
  local -a stateful=("redis" "mysql")

  for svc in "${stateful[@]}"; do
    local names
    names=$("$YQ" eval 'select(.kind == "PodDisruptionBudget") | .metadata.name' "$pdb_file" 2>/dev/null || echo "")
    if echo "$names" | grep -q "^${svc}$"; then
      pass "Stateful service $svc has a PDB"
    else
      fail "Stateful service $svc is missing a PDB"
    fi
  done
}

check_operational_kustomization_wired() {
  echo "Checking operational/ is wired into base kustomization"

  local base_kustomization="${BASE_DIR}/kustomization.yaml"
  if [[ ! -f "$base_kustomization" ]]; then
    fail "Base kustomization not found: $base_kustomization"
    return
  fi

  local resources
  resources=$("$YQ" eval '.resources[]' "$base_kustomization" 2>/dev/null || echo "")
  if echo "$resources" | grep -q "^operational$"; then
    pass "operational/ is listed in base kustomization resources"
  else
    fail "operational/ is NOT listed in base kustomization resources"
  fi
}

# ── Online checks ─────────────────────────────────────────────────────────────

check_pdbs_applied_in_cluster() {
  echo "Checking PDBs are applied in cluster"

  if ! kubectl get pdb -n mereka-lms &>/dev/null; then
    skip "Cannot connect to cluster — skipping live PDB check"
    return
  fi

  local -a critical_services=("lms" "cms" "caddy" "redis" "mysql")
  for svc in "${critical_services[@]}"; do
    if kubectl get pdb "$svc" -n mereka-lms &>/dev/null; then
      pass "PDB $svc exists in cluster (namespace mereka-lms)"
    else
      fail "PDB $svc NOT found in cluster (namespace mereka-lms)"
    fi
  done
}

check_hpas_active() {
  echo "Checking HPAs are active in cluster"

  if ! kubectl get hpa -n mereka-lms &>/dev/null; then
    skip "Cannot connect to cluster — skipping live HPA check"
    return
  fi

  local -a hpa_names=("lms" "cms" "lms-worker" "cms-worker")
  for hpa in "${hpa_names[@]}"; do
    if kubectl get hpa "$hpa" -n mereka-lms &>/dev/null; then
      local current_replicas
      current_replicas=$(kubectl get hpa "$hpa" -n mereka-lms -o jsonpath='{.status.currentReplicas}' 2>/dev/null || echo "")
      if [[ -n "$current_replicas" && "$current_replicas" -ge 1 ]]; then
        pass "HPA $hpa is active (currentReplicas=$current_replicas)"
      else
        fail "HPA $hpa exists but currentReplicas is missing or 0"
      fi
    else
      fail "HPA $hpa NOT found in cluster (namespace mereka-lms)"
    fi
  done
}

check_resource_utilization_vs_limits() {
  echo "Checking resource utilization vs limits (informational)"

  if ! kubectl top pods -n mereka-lms &>/dev/null 2>&1; then
    skip "kubectl top not available or metrics-server not running — skipping utilization check"
    return
  fi

  local output
  output=$(kubectl top pods -n mereka-lms --no-headers 2>/dev/null || echo "")
  if [[ -z "$output" ]]; then
    skip "No pod metrics returned from kubectl top — skipping"
    return
  fi

  pass "kubectl top pods returned metrics (review output manually for limit breaches)"
  echo "$output"
}

# ── Usage ─────────────────────────────────────────────────────────────────────

print_usage() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Verify PDBs, HPA baselines, resource requests, and progressDeadlineSeconds
for critical Open edX workloads.

OPTIONS:
    --offline   Manifest-only checks (default)
    --online    Live cluster checks (requires kubectl access)
    --help      Show this message

EOF
}

# ── Main ──────────────────────────────────────────────────────────────────────

MODE="offline"

while [[ $# -gt 0 ]]; do
  case $1 in
    --offline)
      MODE="offline"
      shift
      ;;
    --online)
      MODE="online"
      shift
      ;;
    --help)
      print_usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      print_usage
      exit 1
      ;;
  esac
done

require_yq

echo "Operational Hardening Verification"
echo "==================================="
echo "Mode: $MODE"
echo ""

if [[ "$MODE" == "offline" || "$MODE" == "both" ]]; then
  echo "── Offline checks ──────────────────────────────────────────────────────────"
  echo ""

  check_pdb_manifests_exist
  echo ""
  check_pdbs_for_critical_services
  echo ""
  check_pdb_min_available
  echo ""
  check_hpa_manifests_exist
  echo ""
  check_hpa_baselines_reasonable
  echo ""
  check_deployments_have_resource_requests
  echo ""
  check_progress_deadline
  echo ""
  check_stateful_services_have_pdbs
  echo ""
  check_operational_kustomization_wired
  echo ""
fi

if [[ "$MODE" == "online" ]]; then
  echo "── Online checks ───────────────────────────────────────────────────────────"
  echo ""

  check_pdbs_applied_in_cluster
  echo ""
  check_hpas_active
  echo ""
  check_resource_utilization_vs_limits
  echo ""
fi

# ── Summary ───────────────────────────────────────────────────────────────────
echo "==================================="
echo "Summary"
echo "==================================="
echo -e "${GREEN}Passed: $PASS_COUNT${NC}"
echo -e "${RED}Failed: $FAIL_COUNT${NC}"
echo -e "${YELLOW}Skipped: $SKIP_COUNT${NC}"

if [[ $FAIL_COUNT -gt 0 ]]; then
  exit 1
else
  exit 0
fi
