#!/usr/bin/env bash
# pre-deploy-checklist.sh — Validate manifests, secrets, and resources before deploying
# Usage: ./scripts/qa/validation-pack/pre-deploy-checklist.sh [--namespace mereka-lms]
# Exit: 0 = all pass, 1 = failures detected
set -euo pipefail

NAMESPACE="mereka-lms"
if [[ "${1:-}" == "--namespace" ]]; then
  NAMESPACE="${2:-mereka-lms}"
fi

# Colors
readonly GREEN='\033[0;32m'
readonly RED='\033[0;31m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m'

TOTAL=0
PASSED=0
FAILED=0
SKIPPED=0

pass() { TOTAL=$((TOTAL+1)); PASSED=$((PASSED+1)); echo -e "${GREEN}PASS${NC} $*"; }
fail() { TOTAL=$((TOTAL+1)); FAILED=$((FAILED+1)); echo -e "${RED}FAIL${NC} $*"; }
skip() { TOTAL=$((TOTAL+1)); SKIPPED=$((SKIPPED+1)); echo -e "${YELLOW}SKIP${NC} $*"; }

echo "=== Pre-Deploy Checklist ==="
echo "Namespace: $NAMESPACE"
echo ""

# 1. Required secrets exist
echo "--- Required Secrets ---"
REQUIRED_SECRETS=(
  "openedx-secrets"
  "database-secrets"
  "enterprise-secrets"
)
for secret in "${REQUIRED_SECRETS[@]}"; do
  if kubectl get secret "$secret" -n "$NAMESPACE" &>/dev/null; then
    pass "Secret: $secret"
  else
    fail "Secret: $secret MISSING"
  fi
done

# 2. Required configmaps exist
echo ""
echo "--- Required ConfigMaps ---"
REQUIRED_CMS=(
  "caddy-config"
)
for cm in "${REQUIRED_CMS[@]}"; do
  if kubectl get configmap "$cm" -n "$NAMESPACE" &>/dev/null; then
    pass "ConfigMap: $cm"
  else
    # Check for kustomize-generated names (hash suffix)
    if kubectl get configmap -n "$NAMESPACE" -o name 2>/dev/null | grep -q "$cm"; then
      pass "ConfigMap: $cm (kustomize hash)"
    else
      fail "ConfigMap: $cm MISSING"
    fi
  fi
done

# 3. Namespace exists
echo ""
echo "--- Namespace ---"
if kubectl get namespace "$NAMESPACE" &>/dev/null; then
  pass "Namespace $NAMESPACE exists"
else
  fail "Namespace $NAMESPACE MISSING"
fi

# 4. Resource limits on deployments
echo ""
echo "--- Resource Limits ---"
deployments=$(kubectl get deploy -n "$NAMESPACE" -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || echo "")
for deploy in $deployments; do
  limits=$(kubectl get deploy "$deploy" -n "$NAMESPACE" -o jsonpath='{.spec.template.spec.containers[0].resources.limits}' 2>/dev/null || echo "")
  if [[ -n "$limits" && "$limits" != "{}" ]]; then
    pass "Resource limits: $deploy"
  else
    skip "Resource limits: $deploy (no limits set)"
  fi
done

# 5. PVC storage
echo ""
echo "--- Persistent Volumes ---"
pvcs=$(kubectl get pvc -n "$NAMESPACE" --no-headers 2>/dev/null || echo "")
if [[ -n "$pvcs" ]]; then
  while IFS= read -r line; do
    name=$(echo "$line" | awk '{print $1}')
    status=$(echo "$line" | awk '{print $2}')
    if [[ "$status" == "Bound" ]]; then
      pass "PVC: $name ($status)"
    else
      fail "PVC: $name ($status)"
    fi
  done <<< "$pvcs"
else
  skip "No PVCs found"
fi

# 6. ExternalSecrets sync status
echo ""
echo "--- ExternalSecrets ---"
if kubectl get externalsecrets -n "$NAMESPACE" &>/dev/null; then
  es_list=$(kubectl get externalsecrets -n "$NAMESPACE" --no-headers 2>/dev/null || echo "")
  if [[ -n "$es_list" ]]; then
    while IFS= read -r line; do
      name=$(echo "$line" | awk '{print $1}')
      # ExternalSecrets output: NAME STORE-KIND STORE-NAME INTERVAL STATUS READY
      # Check READY column ($NF) for "True" or STATUS column ($(NF-1)) for "SecretSynced"
      ready=$(echo "$line" | awk '{print $NF}')
      if [[ "$ready" == "True" ]]; then
        pass "ExternalSecret: $name"
      else
        fail "ExternalSecret: $name (Ready=$ready)"
      fi
    done <<< "$es_list"
  else
    skip "No ExternalSecrets"
  fi
else
  skip "ExternalSecrets CRD not installed"
fi

# 7. Kustomize build validation
echo ""
echo "--- Manifest Validation ---"
REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
if [[ -f "$REPO_ROOT/deploy/k8s/overlays/production/kustomization.yaml" ]]; then
  if kubectl kustomize "$REPO_ROOT/deploy/k8s/overlays/production/" > /dev/null 2>&1; then
    pass "Kustomize build: production overlay"
  else
    fail "Kustomize build: production overlay FAILED"
  fi
else
  skip "No production kustomization.yaml found"
fi

echo ""
echo "=== Summary ==="
echo "Total: $TOTAL | Passed: $PASSED | Failed: $FAILED | Skipped: $SKIPPED"

if [[ $FAILED -gt 0 ]]; then
  echo -e "${RED}RESULT: FAIL${NC}"
  exit 1
else
  echo -e "${GREEN}RESULT: PASS${NC}"
  exit 0
fi
