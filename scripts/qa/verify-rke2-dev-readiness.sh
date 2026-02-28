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

# Deployments that must have explicit replica policy in workload-profile.yaml
REQUIRED_WORKLOAD_REPLICA_POLICIES=(
  lms
  cms
  lms-worker
  cms-worker
  enterprise-access-worker
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

extract_workload_replica_policies() {
  local workload_file="$1"
  awk '
    $1 == "apiVersion:" {
      if (in_doc) {
        if (kind == "Deployment" && name != "" && replicas != "") {
          print name "=" replicas
        }
      }
      in_doc = 1
      kind = ""
      name = ""
      replicas = ""
      next
    }
    $1 == "kind:" { kind = $2; next }
    $1 == "name:" && name == "" { name = $2; next }
    $1 == "replicas:" { replicas = $2; next }
    $1 == "---" {
      if (kind == "Deployment" && name != "" && replicas != "") {
        print name "=" replicas
      }
      in_doc = 0
      kind = ""
      name = ""
      replicas = ""
      next
    }
    END {
      if (kind == "Deployment" && name != "" && replicas != "") {
        print name "=" replicas
      }
    }
  ' "$workload_file"
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

  # 3. workload-profile.yaml contains valid explicit replica policies
  echo "--- Workload profile replica policy ---"
  local workload="${PROFILES_DEV}/patches/workload-profile.yaml"
  if [[ ! -f "$workload" ]]; then
    fail "workload-profile.yaml missing: ${workload}"
  else
    declare -A replica_policy=()
    while IFS='=' read -r name replicas; do
      [[ -z "${name}" || -z "${replicas}" ]] && continue
      replica_policy["$name"]="$replicas"
    done < <(extract_workload_replica_policies "$workload")

    if [[ "${#replica_policy[@]}" -eq 0 ]]; then
      fail "workload-profile has no explicit Deployment replica policies"
    else
      pass "workload-profile defines ${#replica_policy[@]} explicit Deployment replica policies"
    fi

    local invalid_replica=false
    for name in "${!replica_policy[@]}"; do
      if [[ ! "${replica_policy[$name]}" =~ ^[0-9]+$ ]]; then
        fail "workload-profile: ${name} has non-integer replicas='${replica_policy[$name]}'"
        invalid_replica=true
      fi
    done
    if [[ "$invalid_replica" == false ]]; then
      pass "workload-profile replica values are integer literals"
    fi

    local missing_required=false
    for svc in "${REQUIRED_WORKLOAD_REPLICA_POLICIES[@]}"; do
      if [[ -z "${replica_policy[$svc]:-}" ]]; then
        fail "workload-profile missing explicit replicas policy for required deployment: ${svc}"
        missing_required=true
      fi
    done
    if [[ "$missing_required" == false ]]; then
      pass "workload-profile includes required deployment replica policies"
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

  # 12. Live deployment replicas match workload-profile declared policy
  echo "--- Workload-profile replica parity ---"
  local workload="${PROFILES_DEV}/patches/workload-profile.yaml"
  if [[ ! -f "$workload" ]]; then
    fail "workload-profile.yaml missing: ${workload}"
  else
    declare -A expected_replica_policy=()
    while IFS='=' read -r name replicas; do
      [[ -z "${name}" || -z "${replicas}" ]] && continue
      expected_replica_policy["$name"]="$replicas"
    done < <(extract_workload_replica_policies "$workload")

    local parity_ok=true
    for svc in "${!expected_replica_policy[@]}"; do
      local expected_replicas="${expected_replica_policy[$svc]}"
      local live_replicas
      live_replicas=$(kctl get deployment "$svc" -n "$NAMESPACE" -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "missing")
      if [[ "$live_replicas" == "missing" ]]; then
        fail "Deployment ${svc} missing in cluster (expected replicas=${expected_replicas})"
        parity_ok=false
      elif [[ "$live_replicas" == "$expected_replicas" ]]; then
        continue
      else
        fail "Deployment ${svc} replicas=${live_replicas} (expected ${expected_replicas} from workload-profile)"
        parity_ok=false
      fi
    done
    if [[ "$parity_ok" == true ]]; then
      pass "All deployments with explicit workload-profile replicas match live cluster"
    fi
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
