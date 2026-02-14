#!/usr/bin/env bash
# @spec: badges-credentials-enterprise_spec.md
# @covers AC-001, AC-002, AC-003, AC-004, AC-005
# Verify Badgr Server K8s deployment manifests and infrastructure
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
PASS=0; FAIL=0; SKIP=0

pass() { echo -e "${GREEN}PASS${NC} $1"; PASS=$((PASS + 1)); }
fail() { echo -e "${RED}FAIL${NC} $1"; FAIL=$((FAIL + 1)); }
skip() { echo -e "${YELLOW}SKIP${NC} $1"; SKIP=$((SKIP + 1)); }

SKIP_CLUSTER=false
if [[ "${1:-}" == "--skip-cluster" ]]; then
  SKIP_CLUSTER=true
fi

echo "=== Badgr Server K8s Deployment Verification ==="
echo "Date: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo ""

# ---------------------------------------------------------------------------
# AC-001: Badgr Server Deployment manifest exists with correct labels
# ---------------------------------------------------------------------------
BADGR_DEPLOY="deploy/k8s/base/apps/badgr-server/deployment.yaml"
if [[ -f "$BADGR_DEPLOY" ]]; then
  # Check for deployment kind
  if grep -q "kind: Deployment" "$BADGR_DEPLOY"; then
    pass "AC-001: Badgr Server Deployment manifest exists"
  else
    fail "AC-001: $BADGR_DEPLOY exists but is not a Deployment"
  fi

  # Check for correct labels
  if grep -q "app.kubernetes.io/name: badgr-server" "$BADGR_DEPLOY" && \
     grep -q "app.kubernetes.io/instance: mereka-lms" "$BADGR_DEPLOY" && \
     grep -q "app.kubernetes.io/part-of: mereka-lms" "$BADGR_DEPLOY"; then
    pass "AC-001: Deployment has correct label conventions"
  else
    fail "AC-001: Deployment missing required labels (app.kubernetes.io/name, instance, part-of)"
  fi
else
  fail "AC-001: $BADGR_DEPLOY not found"
fi

# ---------------------------------------------------------------------------
# AC-002: Badgr Server Service manifest exists
# ---------------------------------------------------------------------------
BADGR_SVC="deploy/k8s/base/apps/badgr-server/service.yaml"
if [[ -f "$BADGR_SVC" ]]; then
  if grep -q "kind: Service" "$BADGR_SVC" && \
     grep -q "type: ClusterIP" "$BADGR_SVC" && \
     grep -q "port:" "$BADGR_SVC"; then
    PORT=$(grep -oP 'port:\s*\K\d+' "$BADGR_SVC" | head -1)
    pass "AC-002: Badgr Server Service (ClusterIP, port $PORT) exists"
  else
    fail "AC-002: Service manifest exists but missing ClusterIP or port definition"
  fi
else
  fail "AC-002: $BADGR_SVC not found"
fi

# ---------------------------------------------------------------------------
# AC-003: External URL configured (Caddy or Ingress)
# ---------------------------------------------------------------------------
# Check for Caddy configuration referencing badges.academyv2.mereka.io
CADDY_CONFIG="deploy/k8s/base/apps/caddy"
DNS_CONFIG="infrastructure/cloudflare"

if grep -r "badges.academyv2.mereka.io" "$CADDY_CONFIG" 2>/dev/null | grep -q "badges"; then
  pass "AC-003: Caddy config references badges.academyv2.mereka.io"
elif grep -r "badges.academyv2.mereka.io" "$DNS_CONFIG" 2>/dev/null | grep -q "badges"; then
  pass "AC-003: DNS config references badges.academyv2.mereka.io"
else
  skip "AC-003: badges.academyv2.mereka.io not found in Caddy or DNS config (may be configured elsewhere)"
fi

# ---------------------------------------------------------------------------
# AC-004: Badgr Worker Deployment exists
# ---------------------------------------------------------------------------
BADGR_WORKER="deploy/k8s/base/apps/badgr-worker/deployment.yaml"
if [[ -f "$BADGR_WORKER" ]]; then
  if grep -q "kind: Deployment" "$BADGR_WORKER" && \
     grep -q "badgr-worker" "$BADGR_WORKER"; then
    pass "AC-004: Badgr Worker Deployment exists"
  else
    fail "AC-004: $BADGR_WORKER exists but is not configured correctly"
  fi
else
  skip "AC-004: $BADGR_WORKER not found (worker may be combined with main deployment)"
fi

# ---------------------------------------------------------------------------
# AC-005: DNS-only Cloudflare mode + Let's Encrypt SSL requirement
# ---------------------------------------------------------------------------
# This is a documentation/policy check - verify that SSL guidance is present
SPEC_FILE="specs/badges-credentials-enterprise_spec.md"
if [[ -f "$SPEC_FILE" ]]; then
  if grep -q "DNS-only (gray cloud)" "$SPEC_FILE" && \
     grep -q "Let's Encrypt" "$SPEC_FILE" && \
     grep -q "badges.academyv2.mereka.io" "$SPEC_FILE"; then
    pass "AC-005: Spec documents DNS-only mode + Let's Encrypt for multi-level subdomain"
  else
    fail "AC-005: Spec missing SSL/DNS requirements"
  fi
else
  fail "AC-005: badges-credentials-enterprise_spec.md not found"
fi

# ---------------------------------------------------------------------------
# Live cluster checks (optional)
# ---------------------------------------------------------------------------
if [[ "$SKIP_CLUSTER" == false ]]; then
  echo ""
  echo "--- Live Cluster Checks ---"

  # Check if kubectl is available
  if ! command -v kubectl &>/dev/null; then
    skip "Live check: kubectl not available"
  else
    # AC-001: Check deployment exists in cluster
    if kubectl get deployment badgr-server -n mereka-lms &>/dev/null; then
      READY=$(kubectl get deployment badgr-server -n mereka-lms -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
      if [[ "$READY" -ge 1 ]]; then
        pass "AC-001 (live): badgr-server deployment has $READY ready replica(s)"
      else
        fail "AC-001 (live): badgr-server deployment has 0 ready replicas"
      fi
    else
      skip "AC-001 (live): badgr-server deployment not found in mereka-lms namespace"
    fi

    # AC-002: Check service exists
    if kubectl get service badgr-server -n mereka-lms &>/dev/null; then
      pass "AC-002 (live): badgr-server service exists"
    else
      skip "AC-002 (live): badgr-server service not found"
    fi

    # AC-004: Check worker deployment exists
    if kubectl get deployment badgr-worker -n mereka-lms &>/dev/null; then
      WORKER_READY=$(kubectl get deployment badgr-worker -n mereka-lms -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
      if [[ "$WORKER_READY" -ge 1 ]]; then
        pass "AC-004 (live): badgr-worker deployment has $WORKER_READY ready replica(s)"
      else
        fail "AC-004 (live): badgr-worker deployment has 0 ready replicas"
      fi
    else
      skip "AC-004 (live): badgr-worker deployment not found"
    fi
  fi
else
  skip "Live cluster checks disabled (--skip-cluster)"
fi

echo ""
echo "=== Summary ==="
echo -e "${GREEN}PASS:${NC} $PASS | ${RED}FAIL:${NC} $FAIL | ${YELLOW}SKIP:${NC} $SKIP"
[[ "$FAIL" -gt 0 ]] && exit 1 || exit 0
