#!/usr/bin/env bash
# Verify Grafana runtime readiness in monitoring namespace and diagnose secret issues.
set -euo pipefail

K8S_CONTEXT="${K8S_CONTEXT:-gke_bbi-k8_asia-southeast1-c_bbi-k8-cluster}"
NAMESPACE="${NAMESPACE:-monitoring}"
DEPLOYMENT="${DEPLOYMENT:-monitoring-grafana}"

pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1"; }
warn() { echo "WARN: $1"; }

if ! kubectl --context "$K8S_CONTEXT" -n "$NAMESPACE" get deploy "$DEPLOYMENT" >/dev/null 2>&1; then
  fail "Deployment/${DEPLOYMENT} not found in namespace ${NAMESPACE}"
  exit 1
fi

ready_replicas="$(kubectl --context "$K8S_CONTEXT" -n "$NAMESPACE" get deploy "$DEPLOYMENT" -o jsonpath='{.status.readyReplicas}' 2>/dev/null || true)"
if [[ "${ready_replicas:-0}" =~ ^[0-9]+$ ]] && [[ "${ready_replicas:-0}" -ge 1 ]]; then
  pass "Deployment/${DEPLOYMENT} has ready replicas (${ready_replicas})"
else
  warn "Deployment/${DEPLOYMENT} has no ready replicas"
fi

pod="$(kubectl --context "$K8S_CONTEXT" -n "$NAMESPACE" get pod -l app.kubernetes.io/name=grafana -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)"
if [[ -z "$pod" ]]; then
  fail "No grafana pod found in namespace ${NAMESPACE}"
  exit 1
fi
pass "Grafana pod found: ${pod}"

pod_json="$(kubectl --context "$K8S_CONTEXT" -n "$NAMESPACE" get pod "$pod" -o json)"

if jq -e '.status.containerStatuses[]? | select(.name == "grafana" and .ready == true)' <<<"$pod_json" >/dev/null; then
  pass "Grafana app container is Ready"
  exit 0
fi

reason="$(jq -r '.status.containerStatuses[]? | select(.name == "grafana") | (.state.waiting.reason // .state.terminated.reason // "unknown")' <<<"$pod_json" | head -n1)"
message="$(jq -r '.status.containerStatuses[]? | select(.name == "grafana") | (.state.waiting.message // .state.terminated.message // "no message")' <<<"$pod_json" | head -n1)"
fail "Grafana app container not ready (${reason}): ${message}"

missing_secret="$(sed -n 's/.*secret "\([^"]\+\)".*/\1/p' <<<"$message" | head -n1)"
if [[ -n "$missing_secret" ]]; then
  if kubectl --context "$K8S_CONTEXT" -n "$NAMESPACE" get secret "$missing_secret" >/dev/null 2>&1; then
    warn "Referenced Secret/${missing_secret} exists; inspect key names and pod events"
  else
    fail "Referenced Secret/${missing_secret} is missing in namespace ${NAMESPACE}"
  fi
fi

exit 1
