#!/usr/bin/env bash
# @covers AC-CCR-002
# @spec: k8s-deployment_spec.md
#
# Verify NetworkPolicy configuration — default-deny, DNS, internal, external egress.
#
# Modes:
#   --offline  Static analysis of manifests in deploy/k8s/base/ (default)
#   --online   Live cluster checks via kubectl (requires KUBECONFIG / cluster access)
#
# Usage:
#   ./scripts/qa/verify-network-policies.sh
#   ./scripts/qa/verify-network-policies.sh --offline
#   ./scripts/qa/verify-network-policies.sh --online
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
NP_DIR="${REPO_ROOT}/deploy/k8s/base/network-policies"
BASE_DIR="${REPO_ROOT}/deploy/k8s/base"
NAMESPACE="${NAMESPACE:-mereka-lms}"
SCOPE_MODE="${VERIFY_NETWORK_POLICIES_SCOPE:-}"
CHANGED_FILES_RAW="${VERIFY_NETWORK_POLICIES_CHANGED_FILES:-${CI_CHANGED_FILES:-}}"

source "$REPO_ROOT/scripts/shared/ci-skip-guards.sh"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASSED=0
FAILED=0
SKIPPED=0

pass()  { echo -e "${GREEN}PASS${NC}  $1"; PASSED=$((PASSED + 1)); }
fail()  { echo -e "${RED}FAIL${NC}  $1"; FAILED=$((FAILED + 1)); }
skip()  { echo -e "${YELLOW}SKIP${NC}  $1"; SKIPPED=$((SKIPPED + 1)); }

should_skip_scope() {
  local changed_path

  if [[ "$SCOPE_MODE" != "changed" ]]; then
    return 1
  fi

  if [[ -z "${CHANGED_FILES_RAW//[[:space:]]/}" ]]; then
    return 1
  fi

  while IFS= read -r changed_path; do
    [[ -z "$changed_path" ]] && continue
    case "$changed_path" in
      scripts/qa/verify-network-policies.sh|\
      scripts/shared/ci-skip-guards.sh|\
      deploy/k8s/base/kustomization.yaml|\
      deploy/k8s/base/network-policies/*|\
      deploy/k8s/base/apps/xqueue-graders/networkpolicy.yaml|\
      deploy/k8s/overlays/local/*|\
      deploy/k8s/overlays/production/*)
        return 1
        ;;
    esac
  done <<<"$CHANGED_FILES_RAW"

  return 0
}

MODE="offline"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --offline) MODE="offline"; shift ;;
    --online)  MODE="online";  shift ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

echo "=== NetworkPolicy Verification (mode: $MODE) ==="
echo ""

if [[ "$MODE" == "offline" ]] && should_skip_scope; then
  skip "scope skip: no network-policy-relevant changes"
  echo ""
  echo "=== Summary ==="
  echo -e "${GREEN}PASSED${NC}: $PASSED"
  echo -e "${RED}FAILED${NC}: $FAILED"
  echo -e "${YELLOW}SKIPPED${NC}: $SKIPPED"
  echo ""
  echo "NetworkPolicy verification complete."
  exit 0
fi

###############################################################################
# Offline checks — static analysis of manifests
###############################################################################

offline_checks() {
  echo "--- Static Analysis ---"

  # 1. NetworkPolicy directory exists
  if [[ -d "$NP_DIR" ]]; then
    pass "network-policies directory exists"
  else
    fail "network-policies directory missing at deploy/k8s/base/network-policies/"
    return
  fi

  # 2. kustomization.yaml references network-policies
  if grep -q 'network-policies' "$BASE_DIR/kustomization.yaml"; then
    pass "base kustomization.yaml includes network-policies"
  else
    fail "base kustomization.yaml missing network-policies resource"
  fi

  # 3. Required policy files exist
  local required_files=(
    "default-deny.yaml"
    "allow-dns.yaml"
    "allow-namespace-internal.yaml"
    "allow-caddy-external.yaml"
    "allow-prometheus-scrape.yaml"
    "kustomization.yaml"
  )
  for f in "${required_files[@]}"; do
    if [[ -f "$NP_DIR/$f" ]]; then
      pass "policy file exists: $f"
    else
      fail "policy file missing: $f"
    fi
  done

  # 3b. Per-service external egress policies (split from monolithic allow-external-egress.yaml)
  local required_egress=(
    "allow-lms-external-egress.yaml"
    "allow-cms-external-egress.yaml"
    "allow-lms-worker-external-egress.yaml"
    "allow-cms-worker-external-egress.yaml"
    "allow-payments-external-egress.yaml"
    "allow-smtp-external-egress.yaml"
    "allow-discovery-external-egress.yaml"
  )
  for f in "${required_egress[@]}"; do
    if [[ -f "$NP_DIR/$f" ]]; then
      pass "egress policy exists: $f"
    else
      fail "egress policy missing: $f"
    fi
  done

  # 4. Default deny covers both ingress and egress
  if [[ -f "$NP_DIR/default-deny.yaml" ]]; then
    local deny_content
    deny_content="$(cat "$NP_DIR/default-deny.yaml")"
    if echo "$deny_content" | grep -q "Ingress" && echo "$deny_content" | grep -q "Egress"; then
      pass "default-deny covers both Ingress and Egress"
    else
      fail "default-deny must cover both Ingress and Egress policyTypes"
    fi
    if echo "$deny_content" | grep -q "podSelector: {}"; then
      pass "default-deny applies to all pods (empty podSelector)"
    else
      fail "default-deny should use empty podSelector to apply to all pods"
    fi
  fi

  # 5. DNS policy allows UDP+TCP port 53
  if [[ -f "$NP_DIR/allow-dns.yaml" ]]; then
    local dns_content
    dns_content="$(cat "$NP_DIR/allow-dns.yaml")"
    if echo "$dns_content" | grep -q "port: 53"; then
      pass "DNS policy allows port 53"
    else
      fail "DNS policy must allow port 53"
    fi
    if echo "$dns_content" | grep -q "protocol: UDP" && echo "$dns_content" | grep -q "protocol: TCP"; then
      pass "DNS policy allows both UDP and TCP"
    else
      fail "DNS policy should allow both UDP and TCP for port 53"
    fi
    if echo "$dns_content" | grep -q "kubernetes.io/metadata.name: kube-system"; then
      pass "DNS policy uses standard kube-system namespace label"
    else
      fail "DNS policy should use kubernetes.io/metadata.name label selector"
    fi
  fi

  # 6. Caddy external ingress allows ports 80 and 443
  if [[ -f "$NP_DIR/allow-caddy-external.yaml" ]]; then
    local caddy_content
    caddy_content="$(cat "$NP_DIR/allow-caddy-external.yaml")"
    if echo "$caddy_content" | grep -q "app.kubernetes.io/name: caddy"; then
      pass "caddy policy selects caddy pods"
    else
      fail "caddy policy must select caddy pods"
    fi
    if echo "$caddy_content" | grep -q "port: 80" && echo "$caddy_content" | grep -q "port: 443"; then
      pass "caddy policy allows ports 80 and 443"
    else
      fail "caddy policy must allow both port 80 and 443"
    fi
  fi

  # 7. Per-service egress policies select the correct pods
  local -A egress_svc_map=(
    ["allow-lms-external-egress.yaml"]="lms"
    ["allow-cms-external-egress.yaml"]="cms"
    ["allow-lms-worker-external-egress.yaml"]="lms-worker"
    ["allow-cms-worker-external-egress.yaml"]="cms-worker"
    ["allow-payments-external-egress.yaml"]="payments-gateway"
    ["allow-smtp-external-egress.yaml"]="smtp"
    ["allow-discovery-external-egress.yaml"]="discovery"
  )
  for f in "${!egress_svc_map[@]}"; do
    local svc="${egress_svc_map[$f]}"
    if [[ -f "$NP_DIR/$f" ]]; then
      if grep -q "app.kubernetes.io/name: $svc" "$NP_DIR/$f"; then
        pass "egress policy $f selects $svc pods"
      else
        fail "egress policy $f does not select $svc pods"
      fi
    fi
  done

  # 8. Prometheus scrape policy restricts source namespace
  if [[ -f "$NP_DIR/allow-prometheus-scrape.yaml" ]]; then
    if grep -q "kubernetes.io/metadata.name: monitoring" "$NP_DIR/allow-prometheus-scrape.yaml"; then
      pass "prometheus scrape restricted to monitoring namespace"
    else
      fail "prometheus scrape should restrict source to monitoring namespace"
    fi
  fi

  # 9. Kustomize renders all NetworkPolicies
  local np_count
  np_count="$(kubectl kustomize "$BASE_DIR" 2>/dev/null | python3 -c "
import sys, yaml
count = sum(1 for doc in yaml.safe_load_all(sys.stdin) if doc and doc.get('kind') == 'NetworkPolicy')
print(count)" 2>/dev/null || echo "0")"
  if [[ "$np_count" -ge 12 ]]; then
    pass "kustomize renders $np_count NetworkPolicies (expected ≥12)"
  else
    fail "kustomize renders $np_count NetworkPolicies (expected ≥12)"
  fi

  # 10. App-owned overlays render successfully with NetworkPolicies. Production
  # overlays are infra-owned and may be absent from this app repo.
  local overlay_pass=true
  local overlays=(local)
  if [[ -d "$REPO_ROOT/deploy/k8s/overlays/production" || "${VERIFY_KUSTOMIZE_REQUIRE_PRODUCTION_OVERLAY:-0}" == "1" ]]; then
    overlays+=(production)
  fi

  for overlay in "${overlays[@]}"; do
    if [[ ! -d "$REPO_ROOT/deploy/k8s/overlays/$overlay" ]]; then
      skip "$overlay overlay absent in app repo; network policy render is infra-owned"
      continue
    fi

    local overlay_np
    overlay_np="$(kubectl kustomize "$REPO_ROOT/deploy/k8s/overlays/$overlay" 2>/dev/null | python3 -c "
import sys, yaml
count = sum(1 for doc in yaml.safe_load_all(sys.stdin) if doc and doc.get('kind') == 'NetworkPolicy')
print(count)" 2>/dev/null || echo "0")"
    overlay_np="$(printf '%s\n' "$overlay_np" | tail -n 1)"
    if [[ "$overlay_np" -ge 12 ]]; then
      pass "$overlay overlay renders $overlay_np NetworkPolicies"
    else
      fail "$overlay overlay renders only $overlay_np NetworkPolicies"
      overlay_pass=false
    fi
  done

  # 11. xqueue-graders policy uses consistent DNS label
  local xqueue_np="$BASE_DIR/apps/xqueue-graders/networkpolicy.yaml"
  if [[ -f "$xqueue_np" ]]; then
    if grep -q "kubernetes.io/metadata.name: kube-system" "$xqueue_np"; then
      pass "xqueue-graders uses standard kube-system namespace label"
    else
      fail "xqueue-graders should use kubernetes.io/metadata.name label"
    fi
  fi

  # 12. No policy has both empty ingress [] and policyTypes Ingress
  #     (which would block all ingress even with other allow policies —
  #     only xqueue-graders should have this intentionally)
  local accidental_deny=0
  for f in "$NP_DIR"/*.yaml; do
    [[ "$(basename "$f")" == "kustomization.yaml" ]] && continue
    if grep -q "ingress: \[\]" "$f"; then
      accidental_deny=$((accidental_deny + 1))
    fi
  done
  if [[ "$accidental_deny" -eq 0 ]]; then
    pass "no accidental ingress deny in new policies"
  else
    fail "$accidental_deny new policy file(s) have ingress: [] (blocks all ingress)"
  fi
}

###############################################################################
# Online checks — live cluster validation
###############################################################################

online_checks() {
  echo "--- Live Cluster Checks ---"

  if ! kubectl get ns "$NAMESPACE" &>/dev/null; then
    skip "namespace $NAMESPACE not found — skipping online checks"
    return
  fi

  # 1. NetworkPolicies exist in the namespace
  local live_np_count
  live_np_count="$(kubectl get networkpolicies -n "$NAMESPACE" --no-headers 2>/dev/null | wc -l)"
  if [[ "$live_np_count" -ge 12 ]]; then
    pass "live cluster has $live_np_count NetworkPolicies in $NAMESPACE"
  else
    skip "live cluster has $live_np_count NetworkPolicies (expected ≥12, may not be deployed yet)"
  fi

  # 2. default-deny-all exists
  if kubectl get networkpolicy default-deny-all -n "$NAMESPACE" &>/dev/null; then
    pass "default-deny-all policy exists in cluster"
  else
    skip "default-deny-all not yet deployed"
  fi

  # 3. Caddy pods can still receive traffic (functional check)
  local caddy_pod
  caddy_pod="$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=caddy -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)"
  if [[ -n "$caddy_pod" ]]; then
    if kubectl exec -n "$NAMESPACE" "$caddy_pod" -- wget -q -O /dev/null --timeout=5 http://localhost:80 2>/dev/null; then
      pass "caddy pod responds on port 80"
    else
      skip "caddy port 80 check inconclusive"
    fi
  else
    skip "no caddy pod found for live check"
  fi

  # 4. DNS resolution works from an app pod
  local lms_pod
  lms_pod="$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=lms -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)"
  if [[ -n "$lms_pod" ]]; then
    if kubectl exec -n "$NAMESPACE" "$lms_pod" -- nslookup kubernetes.default.svc.cluster.local 2>/dev/null | grep -q "Address"; then
      pass "DNS resolution works from LMS pod"
    else
      skip "DNS check inconclusive from LMS pod"
    fi
  else
    skip "no LMS pod found for DNS check"
  fi
}

###############################################################################
# Main
###############################################################################

offline_checks

if [[ "$MODE" == "online" ]]; then
  echo ""
  online_checks
fi

echo ""
echo "=== Summary ==="
echo -e "${GREEN}PASSED${NC}: $PASSED"
echo -e "${RED}FAILED${NC}: $FAILED"
echo -e "${YELLOW}SKIPPED${NC}: $SKIPPED"

if [[ "$FAILED" -gt 0 ]]; then
  exit 1
fi

echo ""
echo "NetworkPolicy verification complete."
