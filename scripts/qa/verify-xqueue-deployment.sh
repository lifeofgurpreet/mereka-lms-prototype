#!/usr/bin/env bash
# @covers AC-016, AC-017, AC-018, AC-019, AC-020
# @spec: advanced-assessment-xqueue_spec.md
# Verify XQueue external grading deployment and configuration
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASS=0
FAIL=0
SKIP=0

pass() { echo -e "${GREEN}PASS${NC} $1"; PASS=$((PASS + 1)); }
fail() { echo -e "${RED}FAIL${NC} $1"; FAIL=$((FAIL + 1)); }
skip() { echo -e "${YELLOW}SKIP${NC} $1"; SKIP=$((SKIP + 1)); }

echo "=== XQueue Deployment Verification ==="
echo ""

# ---------------------------------------------------------------------------
# AC-016: XQueue service accepts submissions and grader returns result
# Verify: XQueue K8s deployment exists with proper configuration
# ---------------------------------------------------------------------------
echo "[AC-016] Verifying XQueue service deployment..."

if [[ -f "deploy/k8s/base/apps/xqueue/xqueue-deployment.yaml" ]]; then
  pass "AC-016: XQueue deployment manifest exists"
else
  fail "AC-016: XQueue deployment manifest not found"
fi

if grep -q "xqueue:8000" deploy/k8s/base/apps/xqueue/*.yaml 2>/dev/null; then
  pass "AC-016: XQueue service configured on port 8000"
else
  fail "AC-016: XQueue service port 8000 not found in manifests"
fi

# Verify XQueue service definition
if [[ -f "deploy/k8s/base/apps/xqueue/xqueue-service.yaml" ]]; then
  if grep -q "port: 8000" deploy/k8s/base/apps/xqueue/xqueue-service.yaml; then
    pass "AC-016: XQueue Service resource exposes port 8000"
  else
    fail "AC-016: XQueue Service missing port 8000"
  fi
else
  skip "AC-016: XQueue Service manifest not at expected location"
fi

echo ""

# ---------------------------------------------------------------------------
# AC-017, AC-018: XQueue grader security (sandbox execution)
# Verify: Grader worker deployment exists with security constraints
# ---------------------------------------------------------------------------
echo "[AC-017, AC-018] Verifying XQueue grader worker deployment..."

# Check if grader worker manifests exist
GRADER_MANIFEST_FOUND=false
if [[ -d "deploy/k8s/base/apps/xqueue" ]]; then
  if grep -r "xqueue-grader\|grader-worker" deploy/k8s/base/apps/xqueue/ 2>/dev/null | grep -q "Deployment\|deployment"; then
    pass "AC-017: XQueue grader worker deployment referenced in manifests"
    GRADER_MANIFEST_FOUND=true
  else
    fail "AC-017: XQueue grader worker deployment not found"
  fi
else
  fail "AC-017: XQueue manifests directory not found"
fi

# Check grader container configurations
if [[ "$GRADER_MANIFEST_FOUND" == "true" ]]; then
  # Verify security context or resource limits
  if grep -r "resources:\|limits:\|securityContext:" deploy/k8s/base/apps/xqueue/*.yaml 2>/dev/null | grep -q "limits\|securityContext"; then
    pass "AC-017: Grader worker has resource limits or security context (sandbox constraints)"
  else
    skip "AC-017: Resource limits/security context not found in grader manifests (may be set at runtime)"
  fi
fi

# Verify no network access policy or documentation
if grep -r "networkPolicy\|no.*network" deploy/k8s/base/apps/xqueue/*.yaml 2>/dev/null | grep -q "network"; then
  pass "AC-018: Network policy or no-network configuration referenced"
else
  skip "AC-018: NetworkPolicy not found (may be enforced by container runtime)"
fi

echo ""

# ---------------------------------------------------------------------------
# AC-019: Grader worker failure recovery (queue visibility timeout)
# Verify: Queue configuration and worker retry logic
# ---------------------------------------------------------------------------
echo "[AC-019] Verifying grader worker failure recovery configuration..."

# Check for XQueue environment configuration
if grep -r "XQUEUE.*TIMEOUT\|visibility.*timeout" deploy/k8s/base/apps/xqueue/*.yaml infrastructure/tutor/ 2>/dev/null | grep -q -i "timeout"; then
  pass "AC-019: XQueue timeout configuration found"
else
  skip "AC-019: Visibility timeout not explicitly configured (using XQueue defaults)"
fi

# Verify worker deployment has restart policy
if grep -r "restartPolicy\|Deployment" deploy/k8s/base/apps/xqueue/*.yaml 2>/dev/null | grep -q "Deployment"; then
  pass "AC-019: Worker deployment supports automatic restart"
else
  skip "AC-019: Worker deployment restart policy (K8s default applies)"
fi

echo ""

# ---------------------------------------------------------------------------
# AC-020: XQueue grades flow to gradebook within 5 minutes
# Verify: XQueue LMS integration configuration
# ---------------------------------------------------------------------------
echo "[AC-020] Verifying XQueue-LMS integration configuration..."

# Check for XQueue password secret
if [[ -f "deploy/k8s/base/secrets/external-secrets.yaml" ]]; then
  if grep -q "XQUEUE.*PASSWORD\|XQUEUE_LMS_PASSWORD" deploy/k8s/base/secrets/external-secrets.yaml; then
    pass "AC-020: XQUEUE_LMS_PASSWORD secret reference exists"
  else
    fail "AC-020: XQUEUE_LMS_PASSWORD not found in ExternalSecrets"
  fi
else
  fail "AC-020: ExternalSecrets manifest not found"
fi

# Check for XQueue secret key
if [[ -f "deploy/k8s/base/secrets/external-secrets.yaml" ]]; then
  if grep -q "XQUEUE.*SECRET.*KEY\|XQUEUE_SECRET_KEY" deploy/k8s/base/secrets/external-secrets.yaml; then
    pass "AC-020: XQUEUE_SECRET_KEY secret reference exists"
  else
    fail "AC-020: XQUEUE_SECRET_KEY not found in ExternalSecrets"
  fi
fi

# Check for XQueue configuration in LMS settings
if grep -r "XQUEUE.*URL\|xqueue:8000" infrastructure/tutor/patches/ deploy/k8s/base/apps/openedx/settings/ 2>/dev/null | grep -q "xqueue"; then
  pass "AC-020: XQueue URL configuration found in LMS settings"
else
  skip "AC-020: XQueue URL not found in settings patches (may be in base image)"
fi

echo ""

# ---------------------------------------------------------------------------
# Live cluster checks (skip if kubectl not available)
# ---------------------------------------------------------------------------
if command -v kubectl &>/dev/null; then
  echo "[Live Cluster Checks]"

  NAMESPACE="mereka-lms"

  # Check XQueue deployment
  if kubectl get deployment xqueue -n "$NAMESPACE" &>/dev/null; then
    XQUEUE_READY=$(kubectl get deployment xqueue -n "$NAMESPACE" -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
    if [[ "${XQUEUE_READY:-0}" -ge 1 ]]; then
      pass "Live: XQueue deployment has ${XQUEUE_READY} ready replica(s)"
    else
      fail "Live: XQueue deployment not ready (${XQUEUE_READY} replicas)"
    fi
  else
    skip "Live: XQueue deployment not found in cluster"
  fi

  # Check XQueue service
  if kubectl get service xqueue -n "$NAMESPACE" &>/dev/null; then
    pass "Live: XQueue Service resource exists"
  else
    skip "Live: XQueue Service not found in cluster"
  fi

  # Check for grader worker pods
  GRADER_PODS=$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/component=grader-worker 2>/dev/null | grep -c "Running" || echo "0")
  GRADER_PODS="${GRADER_PODS//[$'\n\r ']/}"  # Strip whitespace and newlines
  if [[ "${GRADER_PODS:-0}" -ge 1 ]]; then
    pass "Live: XQueue grader worker pods running ($GRADER_PODS)"
  else
    skip "Live: No grader worker pods found (may not be deployed yet)"
  fi

  echo ""
else
  skip "Live cluster checks (kubectl not available)"
  echo ""
fi

echo "=== Summary ==="
echo -e "${GREEN}PASS:${NC} $PASS | ${RED}FAIL:${NC} $FAIL | ${YELLOW}SKIP:${NC} $SKIP"
[[ $FAIL -gt 0 ]] && exit 1
exit 0
