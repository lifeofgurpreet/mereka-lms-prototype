#!/usr/bin/env bash
# decommission-legacy-ecommerce.sh
# Safe preflight + checklist generator for Oscar ecommerce decommission.
#
# This script is intentionally non-destructive:
# - It does NOT run kubectl delete.
# - It does NOT mutate repository files automatically.
# - It prints precondition status and a GitOps checklist to execute manually.
#
# @spec: ecommerce-purchase-gateway_spec.md
# @covers AC-028

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

NAMESPACE="${K8S_NAMESPACE:-mereka-lms}"
CHECK_CLUSTER=true
CONTEXT_ARGS=()

PASS=0
FAIL=0
SKIP=0

pass() { printf "[PASS] %s\n" "$*"; PASS=$((PASS + 1)); }
fail() { printf "[FAIL] %s\n" "$*"; FAIL=$((FAIL + 1)); }
skip() { printf "[SKIP] %s\n" "$*"; SKIP=$((SKIP + 1)); }
info() { printf "[INFO] %s\n" "$*"; }

usage() {
  cat <<'EOF'
Usage:
  scripts/infra/decommission-legacy-ecommerce.sh [--namespace <name>] [--context <kubectl-context>] [--skip-cluster] [--help]

Purpose:
  Run precondition checks and print a GitOps decommission checklist for legacy Oscar ecommerce.
  This script is non-destructive by design.

Options:
  --namespace <name>  Kubernetes namespace (default: mereka-lms)
  --context <name>    Optional kubectl context
  --skip-cluster      Skip live kubectl checks
  --help              Show this help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --namespace)
      NAMESPACE="$2"
      shift 2
      ;;
    --context)
      CONTEXT_ARGS=(--context "$2")
      shift 2
      ;;
    --skip-cluster)
      CHECK_CLUSTER=false
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      printf "Unknown argument: %s\n" "$1" >&2
      usage
      exit 1
      ;;
  esac
done

check_repo_preconditions() {
  local pg_deploy="$REPO_ROOT/deploy/k8s/base/apps/purchase-gateway/deployment.yaml"
  local adr="$REPO_ROOT/docs/adr/018-purchase-gateway-replaces-oscar-ecommerce.md"

  echo ""
  echo "== Repo Preconditions =="

  if [[ -f "$pg_deploy" ]]; then
    pass "Purchase Gateway deployment manifest exists"
  else
    fail "Missing deploy/k8s/base/apps/purchase-gateway/deployment.yaml"
  fi

  if [[ -f "$pg_deploy" ]]; then
    flag_value="$(
      awk '
        /name:[[:space:]]*ENABLE_GATEWAY_FULFILLMENT/ {
          if (getline) {
            gsub(/"/, "", $0)
            if ($1 == "value:") {
              print tolower($2)
              exit
            }
          }
        }
      ' "$pg_deploy"
    )"
    if [[ "$flag_value" == "true" ]]; then
      pass "ENABLE_GATEWAY_FULFILLMENT=true in purchase-gateway base manifest"
    elif [[ -n "$flag_value" ]]; then
      fail "ENABLE_GATEWAY_FULFILLMENT is ${flag_value} in base manifest (expected true before decommission)"
    else
      fail "ENABLE_GATEWAY_FULFILLMENT flag missing from purchase-gateway deployment manifest"
    fi
  else
    fail "Cannot verify ENABLE_GATEWAY_FULFILLMENT without purchase-gateway deployment manifest"
  fi

  if [[ -f "$adr" ]]; then
    pass "ADR-018 exists"
  else
    fail "ADR-018 missing at docs/adr/018-purchase-gateway-replaces-oscar-ecommerce.md"
  fi
}

check_cluster_preconditions() {
  echo ""
  echo "== Cluster Preconditions =="

  if [[ "$CHECK_CLUSTER" != "true" ]]; then
    skip "Cluster checks skipped (--skip-cluster)"
    return
  fi

  if ! command -v kubectl >/dev/null 2>&1; then
    skip "kubectl not available"
    return
  fi

  if ! kubectl "${CONTEXT_ARGS[@]}" get namespace "$NAMESPACE" >/dev/null 2>&1; then
    skip "Namespace $NAMESPACE not reachable"
    return
  fi
  pass "Namespace $NAMESPACE reachable"

  if kubectl "${CONTEXT_ARGS[@]}" get deploy payments-gateway -n "$NAMESPACE" >/dev/null 2>&1; then
    pass "payments-gateway deployment exists in cluster"
  else
    fail "payments-gateway deployment missing in cluster"
  fi

  if kubectl "${CONTEXT_ARGS[@]}" get deploy ecommerce -n "$NAMESPACE" >/dev/null 2>&1; then
    info "Legacy ecommerce deployment still present; checking open orders precondition"
    if kubectl "${CONTEXT_ARGS[@]}" exec -n "$NAMESPACE" deploy/ecommerce -- \
      python manage.py shell -c "from oscar.apps.order.models import Order; print(Order.objects.filter(status='Open').count())" >/tmp/oscar-open-orders-count.txt 2>/tmp/oscar-open-orders.err; then
      open_orders="$(tr -d '[:space:]' </tmp/oscar-open-orders-count.txt)"
      if [[ "$open_orders" == "0" ]]; then
        pass "Oscar open orders precondition satisfied (0 open orders)"
      else
        fail "Oscar open orders precondition failed (open orders: ${open_orders})"
      fi
    else
      fail "Could not query Oscar open orders (see /tmp/oscar-open-orders.err)"
    fi
  else
    skip "Legacy ecommerce deployment not present in cluster; open-order precheck not applicable"
  fi
}

print_gitops_checklist() {
  cat <<'EOF'

== GitOps Decommission Checklist (Manual, Reviewed, and Committed) ==
1. Create Velero backup before any destructive change:
   velero backup create pre-op-mereka-lms-$(date +%Y%m%d-%H%M) --include-namespaces mereka-lms --wait

2. Remove legacy ecommerce resources from Git manifests (no direct kubectl delete):
   - deploy/k8s/base/apps/* (legacy ecommerce artifacts, if present)
   - deploy/k8s/base/kustomization.yaml (legacy ecommerce references)
   - deploy/k8s/overlays/production/patches/resource-limits.yaml (legacy ecommerce patches)

3. Remove ecommerce host routing:
   - deploy/k8s/base/apps/caddy/Caddyfile
   - deploy/k8s/overlays/*/ingress-openedx-lms.yaml

4. Remove ecommerce DNS records:
   - infrastructure/cloudflare/records.json
   - infrastructure/cloudflare/records.mereka-dev.json

5. Remove residual LMS ecommerce settings after gateway is sole path:
   - deploy/k8s/base/apps/openedx/settings/lms/production.py

6. Remove legacy ecommerce secrets only after workloads are removed:
   - deploy/k8s/base/secrets/external-secrets.yaml
   - deploy/k8s/base/secrets/openedx-secrets.yaml

7. Remove ecommerce monitoring surfaces:
   - infrastructure/monitoring/uptime/prod-ecommerce-https.json
   - infrastructure/monitoring/alerts/https-cert-expiry.json
   - infrastructure/monitoring/dashboards/public-endpoints.json
   - infrastructure/k8s/cronjobs/cert-verify-prod.yaml
   - infrastructure/k8s/cronjobs/auth-verify-prod.yaml

8. Commit + push and let ArgoCD apply. Verify rollout and endpoint contracts.
EOF
}

echo "=== Legacy Ecommerce Decommission Preflight ==="
echo "namespace=${NAMESPACE}"
if [[ ${#CONTEXT_ARGS[@]} -gt 0 ]]; then
  echo "kubectl_context=${CONTEXT_ARGS[1]}"
else
  echo "kubectl_context=current"
fi

check_repo_preconditions
check_cluster_preconditions
print_gitops_checklist

echo ""
echo "=== Summary ==="
printf "PASS=%d FAIL=%d SKIP=%d\n" "$PASS" "$FAIL" "$SKIP"

if [[ "$FAIL" -gt 0 ]]; then
  echo "RESULT: FAIL"
  exit 1
fi

echo "RESULT: PASS"
