#!/usr/bin/env bash
# @covers AC-010, AC-011
# @spec: k8s-deployment_spec.md
#
# verify-pod-security-policies.sh
# Verify Kyverno pod security policy manifests and deployment compliance.
#
# Modes:
#   --offline   Static checks against YAML files (default)
#   --online    Live cluster checks via kubectl
#
# Usage:
#   ./scripts/qa/verify-pod-security-policies.sh [--offline|--online]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
POLICIES_DIR="${REPO_ROOT}/deploy/k8s/base/policies"
BASE_DIR="${REPO_ROOT}/deploy/k8s/base"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Counters
PASS=0
FAIL=0
SKIP=0

pass() { echo -e "${GREEN}PASS${NC} $1"; PASS=$((PASS + 1)); }
fail() { echo -e "${RED}FAIL${NC} $1"; FAIL=$((FAIL + 1)); }
skip() { echo -e "${YELLOW}SKIP${NC} $1"; SKIP=$((SKIP + 1)); }

# ---------------------------------------------------------------------------
# Offline checks
# ---------------------------------------------------------------------------

check_policy_files_exist() {
  echo "[policies] Checking policy files exist..."

  local required_files=(
    "require-non-root.yaml"
    "disallow-privileged.yaml"
    "require-seccomp.yaml"
    "restrict-capabilities.yaml"
    "kustomization.yaml"
  )

  for f in "${required_files[@]}"; do
    if [[ -f "${POLICIES_DIR}/${f}" ]]; then
      pass "Policy file exists: ${f}"
    else
      fail "Policy file missing: ${POLICIES_DIR}/${f}"
    fi
  done
}

check_policy_yaml_valid() {
  echo "[policies] Checking policy YAML validity..."

  local policy_files=(
    "require-non-root.yaml"
    "disallow-privileged.yaml"
    "require-seccomp.yaml"
    "restrict-capabilities.yaml"
  )

  if ! command -v python3 &>/dev/null; then
    skip "python3 not available — skipping YAML validation"
    return
  fi

  for f in "${policy_files[@]}"; do
    local path="${POLICIES_DIR}/${f}"
    if [[ ! -f "$path" ]]; then
      skip "File not found, skipping YAML check: ${f}"
      continue
    fi
    if python3 -c "import yaml; list(yaml.safe_load_all(open('${path}')))" 2>/dev/null; then
      pass "Valid YAML: ${f}"
    else
      fail "Invalid YAML: ${f}"
    fi
  done
}

check_audit_mode() {
  echo "[policies] Checking policies are in Audit mode (not Enforce)..."

  local policy_files=(
    "require-non-root.yaml"
    "disallow-privileged.yaml"
    "require-seccomp.yaml"
    "restrict-capabilities.yaml"
  )

  for f in "${policy_files[@]}"; do
    local path="${POLICIES_DIR}/${f}"
    if [[ ! -f "$path" ]]; then
      skip "File not found, skipping audit mode check: ${f}"
      continue
    fi

    local action
    action=$(grep "validationFailureAction:" "${path}" | head -1 | awk '{print $2}')

    if [[ "$action" == "Audit" ]]; then
      pass "Policy in Audit mode: ${f}"
    elif [[ "$action" == "Enforce" ]]; then
      fail "Policy in Enforce mode (expected Audit for safe rollout): ${f}"
    else
      fail "Policy missing or unrecognised validationFailureAction in: ${f} (got: '${action}')"
    fi
  done
}

check_namespace_match() {
  echo "[policies] Checking policies target mereka-lms namespace..."

  local policy_files=(
    "require-non-root.yaml"
    "disallow-privileged.yaml"
    "require-seccomp.yaml"
    "restrict-capabilities.yaml"
  )

  for f in "${policy_files[@]}"; do
    local path="${POLICIES_DIR}/${f}"
    if [[ ! -f "$path" ]]; then
      skip "File not found, skipping namespace check: ${f}"
      continue
    fi

    if grep -q "mereka-lms" "${path}"; then
      pass "Policy targets mereka-lms namespace: ${f}"
    else
      fail "Policy does not reference mereka-lms namespace: ${f}"
    fi
  done
}

check_system_exclusions() {
  echo "[policies] Checking policies exclude system namespaces..."

  local required_exclusions=("kube-system" "cert-manager" "ingress-nginx" "argocd")
  local policy_files=(
    "require-non-root.yaml"
    "disallow-privileged.yaml"
    "require-seccomp.yaml"
    "restrict-capabilities.yaml"
  )

  for f in "${policy_files[@]}"; do
    local path="${POLICIES_DIR}/${f}"
    if [[ ! -f "$path" ]]; then
      skip "File not found, skipping exclusion check: ${f}"
      continue
    fi

    local all_excluded=true
    for ns in "${required_exclusions[@]}"; do
      if ! grep -q "${ns}" "${path}"; then
        fail "Policy ${f} missing exclusion for namespace: ${ns}"
        all_excluded=false
      fi
    done

    if [[ "$all_excluded" == true ]]; then
      pass "Policy excludes all required system namespaces: ${f}"
    fi
  done
}

check_deployments_security_context() {
  echo "[deployments] Checking base Deployments have securityContext..."

  local deployments_file="${BASE_DIR}/deployments.yml"

  if [[ ! -f "$deployments_file" ]]; then
    skip "Base deployments.yml not found — skipping security context checks"
    return
  fi

  # Check key application deployments have securityContext
  local app_deployments=("lms" "cms")
  for deployment in "${app_deployments[@]}"; do
    if grep -A 40 "name: ${deployment}$" "${deployments_file}" | grep -q "securityContext:"; then
      pass "Deployment '${deployment}' has securityContext defined"
    else
      fail "Deployment '${deployment}' missing securityContext in deployments.yml"
    fi
  done

  # Check all additional deployment YAML files
  local apps_dir="${BASE_DIR}/apps"
  if [[ -d "$apps_dir" ]]; then
    local found_without=0
    while IFS= read -r -d '' yaml_file; do
      if grep -q "kind: Deployment" "${yaml_file}" 2>/dev/null; then
        local deployment_name
        deployment_name=$(grep "kind: Deployment" -A 5 "${yaml_file}" | grep "name:" | head -1 | awk '{print $2}' || echo "unknown")
        if ! grep -q "securityContext:" "${yaml_file}"; then
          skip "Deployment in ${yaml_file##"${REPO_ROOT}/"} has no securityContext (may be upstream-managed)"
        fi
      fi
    done < <(find "${apps_dir}" -name "*.yaml" -print0 2>/dev/null)
  fi
}

check_no_privileged_true() {
  echo "[deployments] Checking no Deployment uses privileged: true..."

  local search_paths=("${BASE_DIR}/deployments.yml")
  if [[ -d "${BASE_DIR}/apps" ]]; then
    while IFS= read -r -d '' f; do
      search_paths+=("$f")
    done < <(find "${BASE_DIR}/apps" -name "*.yaml" -print0 2>/dev/null)
  fi

  local found_privileged=false
  for path in "${search_paths[@]}"; do
    if [[ ! -f "$path" ]]; then
      continue
    fi
    if grep -q "privileged: true" "${path}" 2>/dev/null; then
      fail "Found 'privileged: true' in: ${path##"${REPO_ROOT}/"}"
      found_privileged=true
    fi
  done

  if [[ "$found_privileged" == false ]]; then
    pass "No Deployment uses 'privileged: true'"
  fi
}

check_run_as_non_root_present() {
  echo "[deployments] Checking application deployments for runAsNonRoot..."

  local deployments_file="${BASE_DIR}/deployments.yml"

  if [[ ! -f "$deployments_file" ]]; then
    skip "Base deployments.yml not found — skipping runAsNonRoot checks"
    return
  fi

  local app_deployments=("lms" "cms")
  for deployment in "${app_deployments[@]}"; do
    if grep -A 30 "name: ${deployment}$" "${deployments_file}" | grep -q "runAsNonRoot\|runAsUser"; then
      pass "Deployment '${deployment}' has runAsNonRoot or runAsUser set"
    else
      fail "Deployment '${deployment}' missing runAsNonRoot/runAsUser in securityContext"
    fi
  done
}

check_allow_privilege_escalation_false() {
  echo "[deployments] Checking allowPrivilegeEscalation is not true..."

  local deployments_file="${BASE_DIR}/deployments.yml"

  if [[ ! -f "$deployments_file" ]]; then
    skip "Base deployments.yml not found — skipping allowPrivilegeEscalation checks"
    return
  fi

  if grep -q "allowPrivilegeEscalation: true" "${deployments_file}"; then
    fail "Found 'allowPrivilegeEscalation: true' in deployments.yml"
  else
    pass "No container sets allowPrivilegeEscalation: true in deployments.yml"
  fi
}

check_kustomization_lists_policies() {
  echo "[kustomization] Checking policies directory is listed in kustomization.yaml..."

  local base_kustomization="${BASE_DIR}/kustomization.yaml"
  local policies_kustomization="${POLICIES_DIR}/kustomization.yaml"

  if [[ ! -f "$policies_kustomization" ]]; then
    fail "Policies kustomization.yaml missing: ${POLICIES_DIR}/kustomization.yaml"
    return
  fi

  # Check the policies kustomization references all 4 policy files
  local required=(
    "require-non-root.yaml"
    "disallow-privileged.yaml"
    "require-seccomp.yaml"
    "restrict-capabilities.yaml"
  )
  for f in "${required[@]}"; do
    if grep -q "${f}" "${policies_kustomization}"; then
      pass "Policies kustomization.yaml references: ${f}"
    else
      fail "Policies kustomization.yaml missing reference to: ${f}"
    fi
  done
}

# ---------------------------------------------------------------------------
# Online checks
# ---------------------------------------------------------------------------

check_kyverno_installed() {
  echo "[online] Checking Kyverno is installed in the cluster..."

  local kyverno_ns
  if kubectl get namespace kyverno &>/dev/null 2>&1; then
    pass "Kyverno namespace exists"
  else
    fail "Kyverno namespace 'kyverno' not found — is Kyverno installed?"
    return
  fi

  local running_pods
  running_pods=$(kubectl get pods -n kyverno --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l || echo "0")
  if [[ "$running_pods" -ge 1 ]]; then
    pass "Kyverno has ${running_pods} running pod(s)"
  else
    fail "No running Kyverno pods found in namespace kyverno"
  fi
}

check_policies_applied() {
  echo "[online] Checking ClusterPolicies are applied..."

  local required_policies=(
    "require-non-root-mereka-lms"
    "disallow-privileged-mereka-lms"
    "require-seccomp-mereka-lms"
    "restrict-capabilities-mereka-lms"
  )

  for policy in "${required_policies[@]}"; do
    if kubectl get cpol "${policy}" &>/dev/null 2>&1; then
      pass "ClusterPolicy applied: ${policy}"
    else
      fail "ClusterPolicy not found: ${policy}"
    fi
  done
}

check_policy_reports() {
  echo "[online] Checking PolicyReports for violations in mereka-lms..."

  if ! kubectl get polr -n mereka-lms &>/dev/null 2>&1; then
    skip "No PolicyReports found in mereka-lms (may not have run yet)"
    return
  fi

  local fail_count
  fail_count=$(kubectl get polr -n mereka-lms -o jsonpath='{.items[*].summary.fail}' 2>/dev/null \
    | tr ' ' '\n' | awk '{s+=$1} END {print s+0}' || echo "0")

  local warn_count
  warn_count=$(kubectl get polr -n mereka-lms -o jsonpath='{.items[*].summary.warn}' 2>/dev/null \
    | tr ' ' '\n' | awk '{s+=$1} END {print s+0}' || echo "0")

  local pass_count
  pass_count=$(kubectl get polr -n mereka-lms -o jsonpath='{.items[*].summary.pass}' 2>/dev/null \
    | tr ' ' '\n' | awk '{s+=$1} END {print s+0}' || echo "0")

  echo "  PolicyReport summary — pass: ${pass_count}, fail: ${fail_count}, warn: ${warn_count}"

  if [[ "$fail_count" -eq 0 ]]; then
    pass "No PolicyReport failures in mereka-lms namespace"
  else
    fail "PolicyReport shows ${fail_count} failure(s) in mereka-lms namespace — review with: kubectl get polr -n mereka-lms -o yaml"
  fi
}

# ---------------------------------------------------------------------------
# Entrypoint
# ---------------------------------------------------------------------------

print_usage() {
  cat <<EOF
Usage: $(basename "$0") [--offline|--online]

Verify Kyverno pod security policies for the mereka-lms namespace.

OPTIONS:
  --offline   Static checks against YAML files (default, no cluster required)
  --online    Live cluster checks via kubectl (requires cluster access)
  --help      Show this help message

OFFLINE CHECKS:
  - All policy YAML files exist
  - YAML is syntactically valid
  - Policies are in Audit mode (not Enforce)
  - Policies target the mereka-lms namespace
  - Policies exclude system namespaces
  - Base Deployments have securityContext defined
  - No Deployment uses privileged: true
  - Application Deployments have runAsNonRoot/runAsUser set
  - No container sets allowPrivilegeEscalation: true
  - Policies kustomization.yaml references all policy files

ONLINE CHECKS:
  - Kyverno is installed in the cluster
  - All four ClusterPolicies are applied
  - No PolicyReport failures in mereka-lms namespace

EXAMPLES:
  $(basename "$0")                # Run offline checks
  $(basename "$0") --offline      # Explicitly run offline checks
  $(basename "$0") --online       # Run live cluster checks

EOF
}

MODE="offline"

while [[ $# -gt 0 ]]; do
  case "$1" in
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
      echo "Unknown option: $1" >&2
      print_usage
      exit 1
      ;;
  esac
done

echo "=== Pod Security Policy Verification (mode: ${MODE}) ==="
echo ""

if [[ "$MODE" == "offline" ]]; then
  check_policy_files_exist
  echo ""
  check_policy_yaml_valid
  echo ""
  check_audit_mode
  echo ""
  check_namespace_match
  echo ""
  check_system_exclusions
  echo ""
  check_deployments_security_context
  echo ""
  check_no_privileged_true
  echo ""
  check_run_as_non_root_present
  echo ""
  check_allow_privilege_escalation_false
  echo ""
  check_kustomization_lists_policies
else
  check_kyverno_installed
  echo ""
  check_policies_applied
  echo ""
  check_policy_reports
fi

echo ""
echo "================================="
echo "Results: ${PASS} passed, ${FAIL} failed, ${SKIP} skipped"
echo "================================="

if [[ $FAIL -gt 0 ]]; then
  exit 1
fi
exit 0
