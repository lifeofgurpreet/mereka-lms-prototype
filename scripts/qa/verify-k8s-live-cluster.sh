#!/usr/bin/env bash
# @covers AC-003, AC-013, AC-020, AC-021, AC-029, AC-031
# @spec: k8s-deployment_spec.md
set -euo pipefail

# verify-k8s-live-cluster.sh
# Verifies live GKE cluster state for mereka-lms namespace
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../shared/config.sh"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
CLUSTER_CONTEXT="${CLUSTER_CONTEXT:-${K8S_CONTEXT_PROD:-${K8S_CONTEXT:-rke2-prod}}}"
NAMESPACE="${NAMESPACE:-${K8S_NAMESPACE_PROD:-${K8S_NAMESPACE:-mereka-lms}}}"

# Counters
PASS_COUNT=0
FAIL_COUNT=0
WARN_COUNT=0

# Print functions
print_header() {
  echo -e "${BLUE}=== $1 ===${NC}"
}

print_pass() {
  echo -e "${GREEN}✓${NC} $1"
  PASS_COUNT=$((PASS_COUNT + 1))
}

print_fail() {
  echo -e "${RED}✗${NC} $1"
  FAIL_COUNT=$((FAIL_COUNT + 1))
}

print_warn() {
  echo -e "${YELLOW}⚠${NC} $1"
  WARN_COUNT=$((WARN_COUNT + 1))
}

print_info() {
  echo -e "${BLUE}ℹ${NC} $1"
}

usage() {
  cat <<EOF
Usage: $0 [--context <kube-context>] [--namespace <namespace>]

Env:
  CLUSTER_CONTEXT / K8S_CONTEXT_PROD / K8S_CONTEXT
  NAMESPACE / K8S_NAMESPACE_PROD / K8S_NAMESPACE
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --context)
      CLUSTER_CONTEXT="${2:-}"
      shift 2
      ;;
    --namespace)
      NAMESPACE="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown arg: $1" >&2
      usage
      exit 1
      ;;
  esac
done

# Verify kubectl connectivity
verify_connectivity() {
  print_header "Cluster Connectivity"

  if ! kubectl cluster-info --context="$CLUSTER_CONTEXT" --request-timeout=5s &>/dev/null; then
    print_fail "Cannot connect to cluster context: $CLUSTER_CONTEXT"
    echo "Available contexts:"
    kubectl config get-contexts
    exit 1
  fi

  print_pass "Connected to cluster: $CLUSTER_CONTEXT"

  if ! kubectl get namespace "$NAMESPACE" --context="$CLUSTER_CONTEXT" &>/dev/null; then
    print_fail "Namespace $NAMESPACE does not exist"
    exit 1
  fi

  print_pass "Namespace $NAMESPACE exists"
  echo ""
}

# Check 1: Deployments
check_deployments() {
  print_header "Deployments Status"

  local deployments
  deployments=$(kubectl get deployments -n "$NAMESPACE" --context="$CLUSTER_CONTEXT" -o json 2>/dev/null || echo '{"items":[]}')

  local count
  count=$(echo "$deployments" | jq -r '.items | length')

  if [[ "$count" -eq 0 ]]; then
    print_warn "No deployments found in namespace $NAMESPACE"
    echo ""
    return
  fi

  print_info "Found $count deployments"

  local all_available=true

  while IFS= read -r deployment; do
    local name
    name=$(echo "$deployment" | jq -r '.metadata.name')

    local available
    available=$(echo "$deployment" | jq -r '.status.conditions[] | select(.type=="Available") | .status')

    local replicas
    replicas=$(echo "$deployment" | jq -r '.status.replicas // 0')

    local ready_replicas
    ready_replicas=$(echo "$deployment" | jq -r '.status.readyReplicas // 0')

    if [[ "$available" == "True" ]] && [[ "$ready_replicas" -eq "$replicas" ]]; then
      print_pass "$name ($ready_replicas/$replicas replicas ready)"
    else
      print_fail "$name (Available: $available, Ready: $ready_replicas/$replicas)"
      all_available=false
    fi
  done < <(echo "$deployments" | jq -c '.items[]')

  echo ""
}

# Check 2: Service Endpoints
check_endpoints() {
  print_header "Service Endpoints"

  local services
  services=$(kubectl get services -n "$NAMESPACE" --context="$CLUSTER_CONTEXT" -o json 2>/dev/null || echo '{"items":[]}')

  local count
  count=$(echo "$services" | jq -r '.items | length')

  if [[ "$count" -eq 0 ]]; then
    print_warn "No services found in namespace $NAMESPACE"
    echo ""
    return
  fi

  print_info "Found $count services"

  local empty_endpoints=()

  while IFS= read -r service_name; do
    # Skip headless services (clusterIP: None)
    local cluster_ip
    cluster_ip=$(echo "$services" | jq -r ".items[] | select(.metadata.name==\"$service_name\") | .spec.clusterIP")

    if [[ "$cluster_ip" == "None" ]]; then
      print_info "$service_name (headless service, skipped)"
      continue
    fi

    # MongoDB uses Atlas (no local pod), so empty endpoints are expected
    if [[ "$service_name" == "mongodb" ]]; then
      print_info "$service_name (Atlas-managed, no local pod expected)"
      continue
    fi

    local endpoints
    endpoints=$(kubectl get endpoints "$service_name" -n "$NAMESPACE" --context="$CLUSTER_CONTEXT" -o json 2>/dev/null || echo '{}')

    local has_addresses
    has_addresses=$(echo "$endpoints" | jq -r '.subsets // [] | map(.addresses // []) | flatten | length')

    if [[ "$has_addresses" -eq 0 ]]; then
      print_fail "$service_name (EMPTY ENDPOINTS - cannot route traffic)"
      empty_endpoints+=("$service_name")
    else
      print_pass "$service_name ($has_addresses endpoints)"
    fi
  done < <(echo "$services" | jq -r '.items[].metadata.name')

  if [[ ${#empty_endpoints[@]} -gt 0 ]]; then
    echo ""
    print_info "Services with empty endpoints can't route traffic. Check pod selectors with:"
    for svc in "${empty_endpoints[@]}"; do
      echo "  kubectl describe service $svc -n $NAMESPACE"
    done
  fi

  echo ""
}

# Check 3: TLS Certificates
check_tls_certs() {
  print_header "TLS Certificates"

  # Check if cert-manager is installed
  if ! kubectl api-resources --context="$CLUSTER_CONTEXT" | grep -q "certificates.cert-manager.io"; then
    print_warn "cert-manager CRDs not found (Certificate resource not available)"
    echo ""
    return
  fi

  # Check Certificates
  local certificates
  certificates=$(kubectl get certificates -n "$NAMESPACE" --context="$CLUSTER_CONTEXT" -o json 2>/dev/null || echo '{"items":[]}')

  local cert_count
  cert_count=$(echo "$certificates" | jq -r '.items | length')

  if [[ "$cert_count" -eq 0 ]]; then
    print_warn "No cert-manager Certificates found in namespace $NAMESPACE"
  else
    print_info "Found $cert_count cert-manager Certificates"

    while IFS= read -r cert; do
      local name
      name=$(echo "$cert" | jq -r '.metadata.name')

      local ready
      ready=$(echo "$cert" | jq -r '.status.conditions[] | select(.type=="Ready") | .status')

      local secret_name
      secret_name=$(echo "$cert" | jq -r '.spec.secretName')

      if [[ "$ready" == "True" ]]; then
        print_pass "Certificate $name → $secret_name"
      else
        print_fail "Certificate $name (Ready: $ready)"
      fi
    done < <(echo "$certificates" | jq -c '.items[]')
  fi

  # Check Ingress TLS secrets exist
  local ingresses
  ingresses=$(kubectl get ingress -n "$NAMESPACE" --context="$CLUSTER_CONTEXT" -o json 2>/dev/null || echo '{"items":[]}')

  local ingress_count
  ingress_count=$(echo "$ingresses" | jq -r '.items | length')

  if [[ "$ingress_count" -eq 0 ]]; then
    print_warn "No Ingresses found in namespace $NAMESPACE"
  else
    print_info "Checking Ingress TLS secrets ($ingress_count ingresses)"

    while IFS= read -r ingress; do
      local ingress_name
      ingress_name=$(echo "$ingress" | jq -r '.metadata.name')

      local tls_secrets
      tls_secrets=$(echo "$ingress" | jq -r '.spec.tls[]?.secretName // empty')

      if [[ -z "$tls_secrets" ]]; then
        print_warn "Ingress $ingress_name has no TLS configuration"
        continue
      fi

      while IFS= read -r secret_name; do
        if kubectl get secret "$secret_name" -n "$NAMESPACE" --context="$CLUSTER_CONTEXT" &>/dev/null; then
          print_pass "Ingress $ingress_name TLS secret exists: $secret_name"
        else
          print_fail "Ingress $ingress_name TLS secret MISSING: $secret_name"
        fi
      done <<< "$tls_secrets"
    done < <(echo "$ingresses" | jq -c '.items[]')
  fi

  echo ""
}

# Check 4: ExternalSecrets
check_externalsecrets() {
  print_header "ExternalSecrets Status"

  # Check if external-secrets CRD exists
  if ! kubectl api-resources --context="$CLUSTER_CONTEXT" | grep -q "externalsecrets.external-secrets.io"; then
    print_warn "external-secrets CRDs not found (ExternalSecret resource not available)"
    echo ""
    return
  fi

  local externalsecrets
  externalsecrets=$(kubectl get externalsecrets -n "$NAMESPACE" --context="$CLUSTER_CONTEXT" -o json 2>/dev/null || echo '{"items":[]}')

  local count
  count=$(echo "$externalsecrets" | jq -r '.items | length')

  if [[ "$count" -eq 0 ]]; then
    print_warn "No ExternalSecrets found in namespace $NAMESPACE"
    echo ""
    return
  fi

  print_info "Found $count ExternalSecrets"

  while IFS= read -r es; do
    local name
    name=$(echo "$es" | jq -r '.metadata.name')

    local status
    status=$(echo "$es" | jq -r '.status.conditions[] | select(.type=="Ready") | .status')

    local sync_status
    sync_status=$(echo "$es" | jq -r '.status.syncedResourceVersion // "unknown"')

    if [[ "$status" == "True" ]]; then
      print_pass "$name (synced: $sync_status)"
    else
      print_fail "$name (Ready: $status)"
    fi
  done < <(echo "$externalsecrets" | jq -c '.items[]')

  echo ""
}

# Check 5: Promtail DaemonSet
check_promtail() {
  print_header "Promtail DaemonSet"

  local daemonsets
  daemonsets=$(kubectl get daemonsets -n "$NAMESPACE" --context="$CLUSTER_CONTEXT" -o json 2>/dev/null || echo '{"items":[]}')

  local promtail
  promtail=$(echo "$daemonsets" | jq '.items[] | select(.metadata.name | test("promtail"))')

  if [[ -z "$promtail" ]]; then
    print_warn "Promtail DaemonSet not found in namespace $NAMESPACE"
    echo ""
    return
  fi

  local name
  name=$(echo "$promtail" | jq -r '.metadata.name')

  local desired
  desired=$(echo "$promtail" | jq -r '.status.desiredNumberScheduled // 0')

  local ready
  ready=$(echo "$promtail" | jq -r '.status.numberReady // 0')

  if [[ "$ready" -eq "$desired" ]] && [[ "$desired" -gt 0 ]]; then
    print_pass "$name ($ready/$desired pods ready)"
  else
    print_fail "$name ($ready/$desired pods ready)"
  fi

  echo ""
}

# Check 6: CronJobs
check_cronjobs() {
  print_header "CronJobs"

  local cronjobs
  cronjobs=$(kubectl get cronjobs -n "$NAMESPACE" --context="$CLUSTER_CONTEXT" -o json 2>/dev/null || echo '{"items":[]}')

  local count
  count=$(echo "$cronjobs" | jq -r '.items | length')

  if [[ "$count" -eq 0 ]]; then
    print_warn "No CronJobs found in namespace $NAMESPACE"
    echo ""
    return
  fi

  print_info "Found $count CronJobs"

  while IFS= read -r cronjob; do
    local name
    name=$(echo "$cronjob" | jq -r '.metadata.name')

    local schedule
    schedule=$(echo "$cronjob" | jq -r '.spec.schedule')

    local suspended
    suspended=$(echo "$cronjob" | jq -r '.spec.suspend // false')

    local last_schedule
    last_schedule=$(echo "$cronjob" | jq -r '.status.lastScheduleTime // "never"')

    if [[ "$suspended" == "true" ]]; then
      print_warn "$name (SUSPENDED, schedule: $schedule)"
    else
      print_pass "$name (schedule: $schedule, last run: $last_schedule)"
    fi
  done < <(echo "$cronjobs" | jq -c '.items[]')

  echo ""
}

# Print summary
print_summary() {
  print_header "Summary"

  local total=$((PASS_COUNT + FAIL_COUNT + WARN_COUNT))

  echo -e "Total checks: $total"
  echo -e "${GREEN}Passed: $PASS_COUNT${NC}"
  echo -e "${RED}Failed: $FAIL_COUNT${NC}"
  echo -e "${YELLOW}Warnings: $WARN_COUNT${NC}"

  if [[ $FAIL_COUNT -gt 0 ]]; then
    echo ""
    echo -e "${RED}❌ Cluster verification FAILED${NC}"
    return 1
  else
    echo ""
    echo -e "${GREEN}✓ Cluster verification PASSED${NC}"
    return 0
  fi
}

# Main
main() {
  local check="${1:-all}"

  echo "Verifying live Kubernetes cluster: $CLUSTER_CONTEXT"
  echo "Namespace: $NAMESPACE"
  echo ""

  verify_connectivity

  case "$check" in
    all)
      check_deployments
      check_endpoints
      check_tls_certs
      check_externalsecrets
      check_promtail
      check_cronjobs
      ;;
    deployments)
      check_deployments
      ;;
    endpoints)
      check_endpoints
      ;;
    tls-certs)
      check_tls_certs
      ;;
    externalsecrets)
      check_externalsecrets
      ;;
    promtail)
      check_promtail
      ;;
    cronjobs)
      check_cronjobs
      ;;
    *)
      echo "Usage: $0 [--check <check_name>]"
      echo ""
      echo "Available checks:"
      echo "  all              Run all checks (default)"
      echo "  deployments      Check Deployment availability"
      echo "  endpoints        Check Service endpoints (empty = traffic cannot route)"
      echo "  tls-certs        Check TLS certificates and secrets"
      echo "  externalsecrets  Check ExternalSecret sync status"
      echo "  promtail         Check Promtail DaemonSet"
      echo "  cronjobs         Check CronJob schedules"
      exit 1
      ;;
  esac

  print_summary
}

# Parse arguments
if [[ $# -eq 0 ]]; then
  main "all"
elif [[ "$1" == "--check" ]] && [[ $# -eq 2 ]]; then
  main "$2"
else
  main "$@"
fi
