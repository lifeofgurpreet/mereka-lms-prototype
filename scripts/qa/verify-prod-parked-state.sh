#!/usr/bin/env bash
# Verify production is in the expected parked state.
# Returns 0 if parked correctly, 1 if degraded.
set -euo pipefail

CONTEXT="${K8S_CONTEXT_PROD:-gke_bbi-k8_asia-southeast1-c_bbi-k8-cluster}"
NS="${K8S_NAMESPACE_PROD:-mereka-lms}"
PASS=0
FAIL=0

check() {
  local name="$1" expected="$2" actual="$3"
  if [[ "$actual" == "$expected" ]]; then
    echo "OK   $name: $actual (expected $expected)"
    PASS=$((PASS + 1))
  else
    echo "FAIL $name: $actual (expected $expected)"
    FAIL=$((FAIL + 1))
  fi
}

echo "=== Production Parked State Verification ==="
echo "Context: $CONTEXT"
echo "Namespace: $NS"
echo ""

# Workloads that SHOULD be at 0 replicas
PARKED_WORKLOADS="lms cms lms-worker cms-worker mfe redis elasticsearch meilisearch discovery credentials notes xqueue smtp"
for w in $PARKED_WORKLOADS; do
  replicas=$(kubectl --context "$CONTEXT" get deployment "$w" -n "$NS" -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "missing")
  check "$w replicas" "0" "$replicas"
done

# Workloads that SHOULD be running
RUNNING_WORKLOADS="caddy preview-redirect"
for w in $RUNNING_WORKLOADS; do
  ready=$(kubectl --context "$CONTEXT" get deployment "$w" -n "$NS" -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
  ready="${ready:-0}"
  if [[ "$ready" -ge 1 ]]; then
    echo "OK   $w: running ($ready ready)"
    PASS=$((PASS + 1))
  else
    echo "FAIL $w: not running ($ready ready)"
    FAIL=$((FAIL + 1))
  fi
done

echo ""
echo "=== Summary: PASS=$PASS FAIL=$FAIL ==="

if [[ $FAIL -gt 0 ]]; then
  echo "Production is NOT in expected parked state."
  exit 1
fi

echo "Production is in expected parked state."
exit 0
