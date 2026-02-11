#!/usr/bin/env bash
# Verify K8s ConfigMap template for tenant registry exists.
# Spec reference: multi-tenancy-architecture_spec.md
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FAILED=0

log_pass() { printf "PASS: %s\n" "$1"; }
log_fail() { printf "FAIL: %s\n" "$1"; FAILED=1; }

echo "=== Tenant ConfigMap Verification ==="
echo "Date: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo

CM_FILE="$REPO_ROOT/deploy/k8s/base/apps/multi-tenancy/configmap-tenants.yaml"

# Check 1: ConfigMap file exists
if [ -f "$CM_FILE" ]; then
  log_pass "configmap-tenants.yaml exists"
else
  log_fail "configmap-tenants.yaml not found"
  exit 1
fi

# Check 2: Contains ConfigMap kind
if grep -q "kind: ConfigMap" "$CM_FILE"; then
  log_pass "Contains kind: ConfigMap"
else
  log_fail "Missing kind: ConfigMap"
fi

# Check 3: Correct namespace
if grep -q "namespace: mereka-lms" "$CM_FILE"; then
  log_pass "Namespace is mereka-lms"
else
  log_fail "Namespace is not mereka-lms"
fi

# Check 4: Contains tenants.yaml data key
if grep -q "tenants.yaml:" "$CM_FILE"; then
  log_pass "Contains tenants.yaml data key"
else
  log_fail "Missing tenants.yaml data key"
fi

# Check 5: Contains Mereka Academy default tenant
if grep -q "mereka-academy" "$CM_FILE"; then
  log_pass "Contains mereka-academy default tenant"
else
  log_fail "Missing mereka-academy default tenant"
fi

# Check 6: Kustomization references ConfigMap
KUST_FILE="$REPO_ROOT/deploy/k8s/base/apps/multi-tenancy/kustomization.yaml"
if [ -f "$KUST_FILE" ] && grep -q "configmap-tenants.yaml" "$KUST_FILE"; then
  log_pass "kustomization.yaml references configmap-tenants.yaml"
else
  log_fail "kustomization.yaml missing or does not reference configmap-tenants.yaml"
fi

echo
if [ $FAILED -eq 0 ]; then
  echo "ALL CHECKS PASSED"
  exit 0
else
  echo "SOME CHECKS FAILED"
  exit 1
fi
