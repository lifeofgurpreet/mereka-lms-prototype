#!/usr/bin/env bash
# verify-rke2-dev-readiness.sh
# Checks all prerequisites for running mereka-lms on the RKE2 dev cluster.
#
# Modes:
#   --offline   Static checks only (no cluster access required)
#   --online    Live cluster checks (requires kubectl context rke2-nonprod)
#   (default)   Runs both offline and online checks
#
# Usage:
#   ./scripts/qa/verify-rke2-dev-readiness.sh [--offline|--online]
set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Counters
PASS_COUNT=0
FAIL_COUNT=0
SKIP_COUNT=0

# Paths
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BBI_INFRA_DIR="${BBI_INFRA_DIR:-/home/gurpreet/projects/k8s/bbi-infrastructure}"
PROFILES_DEV="${BBI_INFRA_DIR}/apps/mereka-lms/overlays/profiles/dev"
KUBE_CONTEXT="${KUBE_CONTEXT:-rke2-nonprod}"
NAMESPACE="mereka-lms"

# Services expected at replicas: 0 in profiles/dev workload-profile.yaml
SCALED_TO_ZERO_DEPLOYMENTS=(
  credentials
  discovery
  ecommerce
  ecommerce-worker
  notes
  xqueue
  enterprise-access
  enterprise-access-worker
  enterprise-admin-portal
  enterprise-catalog
  enterprise-learner-portal
  enterprise-subsidy
)

# Helper functions
pass() {
  echo -e "${GREEN}PASS${NC} $1"
  PASS_COUNT=$((PASS_COUNT + 1))
}

fail() {
  echo -e "${RED}FAIL${NC} $1"
  FAIL_COUNT=$((FAIL_COUNT + 1))
}

skip() {
  echo -e "${YELLOW}SKIP${NC} $1"
  SKIP_COUNT=$((SKIP_COUNT + 1))
}

# Parse arguments
MODE="both"
if [[ "${1:-}" == "--offline" ]]; then
  MODE="offline"
elif [[ "${1:-}" == "--online" ]]; then
  MODE="online"
fi

# ---------------------------------------------------------------------------
# Offline checks (no cluster access)
# ---------------------------------------------------------------------------
run_offline_checks() {
  echo ""
  echo "== Offline Checks (static analysis) =="
  echo ""

  # 1. profiles/dev kustomize builds cleanly
  echo "--- Kustomize build ---"
  if [[ ! -d "$PROFILES_DEV" ]]; then
    fail "profiles/dev directory not found: ${PROFILES_DEV}"
  elif kubectl kustomize "$PROFILES_DEV" > /dev/null 2>&1; then
    pass "profiles/dev kustomize builds cleanly"
  else
    fail "profiles/dev kustomize build failed (run: kubectl kustomize ${PROFILES_DEV})"
  fi

  # 2. runtime-secrets-placeholder.yaml exists and contains mereka-lms-runtime-secrets
  echo "--- Runtime secrets placeholder ---"
  local placeholder="${PROFILES_DEV}/runtime-secrets-placeholder.yaml"
  if [[ ! -f "$placeholder" ]]; then
    fail "runtime-secrets-placeholder.yaml missing: ${placeholder}"
  elif grep -q "mereka-lms-runtime-secrets" "$placeholder"; then
    pass "runtime-secrets-placeholder.yaml exists with mereka-lms-runtime-secrets"
  else
    fail "runtime-secrets-placeholder.yaml does not reference mereka-lms-runtime-secrets"
  fi

  # 3. workload-profile.yaml scales enterprise services to 0
  echo "--- Workload profile (scale-to-zero services) ---"
  local workload="${PROFILES_DEV}/patches/workload-profile.yaml"
  if [[ ! -f "$workload" ]]; then
    fail "workload-profile.yaml missing: ${workload}"
  else
    local all_zero=true
    for svc in "${SCALED_TO_ZERO_DEPLOYMENTS[@]}"; do
      # Check that the deployment name appears followed by replicas: 0
      # Use yq if available, otherwise fall back to grep
      if command -v yq > /dev/null 2>&1; then
        local replica_count
        replica_count=$(yq eval-all "select(.kind == \"Deployment\" and .metadata.name == \"${svc}\") | .spec.replicas" "$workload" 2>/dev/null || echo "")
        if [[ "$replica_count" == "0" ]]; then
          continue
        else
          fail "workload-profile: ${svc} replicas=${replica_count:-missing} (expected 0)"
          all_zero=false
        fi
      else
        # Fallback: grep-based check
        if grep -A3 "name: ${svc}$" "$workload" | grep -q "replicas: 0"; then
          continue
        else
          fail "workload-profile: ${svc} not scaled to 0"
          all_zero=false
        fi
      fi
    done
    if [[ "$all_zero" == true ]]; then
      pass "workload-profile scales all non-essential services to 0"
    fi
  fi

  # 4. default-serviceaccount.yaml references dev-image-puller
  echo "--- ServiceAccount imagePullSecret ---"
  local sa_file="${PROFILES_DEV}/default-serviceaccount.yaml"
  if [[ ! -f "$sa_file" ]]; then
    fail "default-serviceaccount.yaml missing: ${sa_file}"
  elif grep -q "dev-image-puller" "$sa_file"; then
    pass "default-serviceaccount.yaml references dev-image-puller imagePullSecret"
  else
    fail "default-serviceaccount.yaml does not reference dev-image-puller"
  fi

  # 5. LimitRange and ResourceQuota files exist
  echo "--- Resource governance files ---"
  local lr_file="${PROFILES_DEV}/limitrange.yaml"
  local rq_file="${PROFILES_DEV}/resourcequota.yaml"
  if [[ -f "$lr_file" && -f "$rq_file" ]]; then
    pass "LimitRange and ResourceQuota files exist"
  else
    [[ ! -f "$lr_file" ]] && fail "limitrange.yaml missing: ${lr_file}"
    [[ ! -f "$rq_file" ]] && fail "resourcequota.yaml missing: ${rq_file}"
  fi
}

# ---------------------------------------------------------------------------
# Online checks (requires cluster access)
# ---------------------------------------------------------------------------
kctl() {
  kubectl --context "$KUBE_CONTEXT" "$@"
}

run_online_checks() {
  echo ""
  echo "== Online Checks (live cluster: ${KUBE_CONTEXT}) =="
  echo ""

  # Verify cluster is reachable
  if ! kctl cluster-info > /dev/null 2>&1; then
    echo -e "${RED}ERROR${NC}: Cannot reach cluster context '${KUBE_CONTEXT}'"
    echo "  Set KUBE_CONTEXT=<context> or ensure rke2-nonprod is configured."
    # Skip all online checks
    for i in $(seq 1 9); do
      skip "Online check skipped (cluster unreachable)"
    done
    return
  fi

  # 6. ArgoCD app source path includes profiles/dev
  echo "--- ArgoCD app source path ---"
  local argo_path
  argo_path=$(kctl get application mereka-lms-dev -n argocd -o jsonpath='{.spec.source.path}' 2>/dev/null || echo "")
  if [[ -z "$argo_path" ]]; then
    # Try multi-source
    argo_path=$(kctl get application mereka-lms-dev -n argocd -o jsonpath='{.spec.sources[0].path}' 2>/dev/null || echo "")
  fi
  if [[ -z "$argo_path" ]]; then
    skip "ArgoCD app 'mereka-lms-dev' not found in argocd namespace"
  elif echo "$argo_path" | grep -q "profiles/dev"; then
    pass "ArgoCD app source path includes profiles/dev (${argo_path})"
  else
    fail "ArgoCD app source path is '${argo_path}' (expected to include profiles/dev)"
  fi

  # 7. mereka-lms-runtime-secrets secret exists
  echo "--- Runtime secrets ---"
  if kctl get secret mereka-lms-runtime-secrets -n "$NAMESPACE" > /dev/null 2>&1; then
    pass "mereka-lms-runtime-secrets secret exists in ${NAMESPACE}"
  else
    fail "mereka-lms-runtime-secrets secret missing in ${NAMESPACE}"
  fi

  # 8. database-secrets has non-empty MYSQL_ROOT_PASSWORD
  echo "--- Database secrets ---"
  local mysql_pw
  mysql_pw=$(kctl get secret database-secrets -n "$NAMESPACE" -o jsonpath='{.data.MYSQL_ROOT_PASSWORD}' 2>/dev/null || echo "")
  if [[ -z "$mysql_pw" ]]; then
    fail "database-secrets missing or MYSQL_ROOT_PASSWORD is empty"
  elif [[ "$mysql_pw" == "PLACEHOLDER" || "$mysql_pw" == "UEXBQ0VIT0xERVI=" ]]; then
    # UEXBQ0VIT0xERVI= is base64("PLACEHOLDER")
    fail "database-secrets MYSQL_ROOT_PASSWORD is still a placeholder"
  else
    pass "database-secrets has non-empty MYSQL_ROOT_PASSWORD"
  fi

  # 9. openedx-secrets exists with expected key count (>=40)
  echo "--- OpenEdx secrets key count ---"
  local key_count
  key_count=$(kctl get secret openedx-secrets -n "$NAMESPACE" -o json 2>/dev/null | python3 -c "import sys,json; d=json.load(sys.stdin); print(len(d.get('data',{})))" 2>/dev/null || echo "0")
  if [[ "$key_count" -ge 40 ]]; then
    pass "openedx-secrets has ${key_count} keys (>= 40)"
  elif [[ "$key_count" -eq 0 ]]; then
    fail "openedx-secrets missing or has 0 keys"
  else
    fail "openedx-secrets has only ${key_count} keys (expected >= 40)"
  fi

  # 10. LMS pod is Running
  echo "--- LMS pod status ---"
  local lms_phase
  lms_phase=$(kctl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=lms -o jsonpath='{.items[0].status.phase}' 2>/dev/null || echo "")
  local lms_waiting
  lms_waiting=$(kctl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=lms -o jsonpath='{.items[0].status.containerStatuses[0].state.waiting.reason}' 2>/dev/null || echo "")
  if [[ "$lms_phase" == "Running" && -z "$lms_waiting" ]]; then
    pass "LMS pod is Running"
  elif [[ -z "$lms_phase" ]]; then
    fail "LMS pod not found"
  else
    fail "LMS pod status: phase=${lms_phase} waiting=${lms_waiting:-none}"
  fi

  # 11. MySQL pod is Running
  echo "--- MySQL pod status ---"
  local mysql_phase
  mysql_phase=$(kctl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=mysql -o jsonpath='{.items[0].status.phase}' 2>/dev/null || echo "")
  local mysql_waiting
  mysql_waiting=$(kctl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=mysql -o jsonpath='{.items[0].status.containerStatuses[0].state.waiting.reason}' 2>/dev/null || echo "")
  if [[ "$mysql_phase" == "Running" && -z "$mysql_waiting" ]]; then
    pass "MySQL pod is Running"
  elif [[ -z "$mysql_phase" ]]; then
    fail "MySQL pod not found"
  else
    fail "MySQL pod status: phase=${mysql_phase} waiting=${mysql_waiting:-none}"
  fi

  # 12. Non-essential services are scaled to 0 replicas
  echo "--- Non-essential services scaled to 0 ---"
  local all_zero=true
  for svc in "${SCALED_TO_ZERO_DEPLOYMENTS[@]}"; do
    local replicas
    replicas=$(kctl get deployment "$svc" -n "$NAMESPACE" -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "missing")
    if [[ "$replicas" == "0" ]]; then
      continue
    elif [[ "$replicas" == "missing" ]]; then
      # Deployment may not exist yet, which is fine
      continue
    else
      fail "Deployment ${svc} has ${replicas} replicas (expected 0)"
      all_zero=false
    fi
  done
  if [[ "$all_zero" == true ]]; then
    pass "All non-essential services scaled to 0 (or absent)"
  fi

  # 13. No ImagePullBackOff pods
  echo "--- ImagePullBackOff check ---"
  local pullback_pods
  pullback_pods=$(kctl get pods -n "$NAMESPACE" -o json 2>/dev/null | \
    python3 -c "
import sys, json
data = json.load(sys.stdin)
bad = []
for pod in data.get('items', []):
    for cs in pod.get('status', {}).get('containerStatuses', []):
        reason = (cs.get('state', {}).get('waiting', {}) or {}).get('reason', '')
        if reason in ('ImagePullBackOff', 'ErrImagePull'):
            bad.append(pod['metadata']['name'])
            break
print('\n'.join(bad))
" 2>/dev/null || echo "")
  if [[ -z "$pullback_pods" ]]; then
    pass "No ImagePullBackOff pods in ${NAMESPACE}"
  else
    fail "ImagePullBackOff pods: ${pullback_pods//$'\n'/, }"
  fi

  # 14. ExternalSecrets all report SecretSynced
  echo "--- ExternalSecrets sync status ---"
  local es_output
  es_output=$(kctl get externalsecret -n "$NAMESPACE" -o json 2>/dev/null || echo '{"items":[]}')
  local es_count
  es_count=$(echo "$es_output" | python3 -c "import sys,json; print(len(json.load(sys.stdin).get('items',[])))" 2>/dev/null || echo "0")
  if [[ "$es_count" -eq 0 ]]; then
    skip "No ExternalSecrets found in ${NAMESPACE}"
  else
    local not_synced
    not_synced=$(echo "$es_output" | python3 -c "
import sys, json
data = json.load(sys.stdin)
bad = []
for es in data.get('items', []):
    name = es['metadata']['name']
    conditions = es.get('status', {}).get('conditions', [])
    synced = any(c.get('type') == 'Ready' and c.get('status') == 'True' for c in conditions)
    if not synced:
        bad.append(name)
print('\n'.join(bad))
" 2>/dev/null || echo "")
    if [[ -z "$not_synced" ]]; then
      pass "All ${es_count} ExternalSecrets report Ready/True"
    else
      fail "ExternalSecrets not synced: ${not_synced//$'\n'/, }"
    fi
  fi
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
echo "=== RKE2 Dev Readiness Verification ==="
echo "Mode: ${MODE}"
echo "BBI_INFRA_DIR: ${BBI_INFRA_DIR}"

if [[ "$MODE" == "offline" || "$MODE" == "both" ]]; then
  run_offline_checks
fi

if [[ "$MODE" == "online" || "$MODE" == "both" ]]; then
  run_online_checks
fi

# Summary
echo ""
echo "========================================="
echo -e "  PASS: ${GREEN}${PASS_COUNT}${NC}  FAIL: ${RED}${FAIL_COUNT}${NC}  SKIP: ${YELLOW}${SKIP_COUNT}${NC}"
echo "========================================="

if [[ "$FAIL_COUNT" -gt 0 ]]; then
  echo ""
  echo "See docs/operations/RKE2_DEV_READINESS.md for remediation steps."
  exit 1
fi
