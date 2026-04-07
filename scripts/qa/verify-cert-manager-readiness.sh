#!/usr/bin/env bash
# Verify required cert-manager Certificates are Ready and materialized as Secrets.
# Usage:
#   ./scripts/qa/verify-cert-manager-readiness.sh [prod]
set -euo pipefail

ENVIRONMENT="${1:-prod}"
NAMESPACE="${K8S_NAMESPACE_PROD:-${K8S_NAMESPACE:-mereka-lms}}"
KCTX="${K8S_CONTEXT_PROD:-${K8S_CONTEXT:-rke2-prod}}"

if [[ "$ENVIRONMENT" != "prod" ]]; then
  echo "Usage: $0 [prod]" >&2
  exit 1
fi

required_certs=(
  "openedx-lms-tls"
  "openedx-studio-tls"
  "openedx-mfe-tls"
  "openedx-forum-tls"
  "enterprise-mfe-tls"
)

failures=0

ok() { printf "✓ %s\n" "$*"; }
bad() { printf "✗ %s\n" "$*" >&2; failures=$((failures + 1)); }

for cert in "${required_certs[@]}"; do
  if ! kubectl --context "$KCTX" -n "$NAMESPACE" get certificate "$cert" >/dev/null 2>&1; then
    bad "certificate/${cert} missing in namespace ${NAMESPACE}"
    continue
  fi

  ready="$(kubectl --context "$KCTX" -n "$NAMESPACE" get certificate "$cert" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || true)"
  reason="$(kubectl --context "$KCTX" -n "$NAMESPACE" get certificate "$cert" -o jsonpath='{.status.conditions[?(@.type=="Ready")].reason}' 2>/dev/null || true)"
  secret_name="$(kubectl --context "$KCTX" -n "$NAMESPACE" get certificate "$cert" -o jsonpath='{.spec.secretName}' 2>/dev/null || true)"

  if [[ "$ready" != "True" ]]; then
    bad "certificate/${cert} not Ready (status=${ready:-unknown} reason=${reason:-unknown})"
    continue
  fi

  if [[ -z "$secret_name" ]]; then
    bad "certificate/${cert} has empty spec.secretName"
    continue
  fi

  if ! kubectl --context "$KCTX" -n "$NAMESPACE" get secret "$secret_name" >/dev/null 2>&1; then
    bad "certificate/${cert} Ready but secret/${secret_name} missing"
    continue
  fi

  ok "certificate/${cert} Ready with secret/${secret_name}"
done

if [[ "$failures" -gt 0 ]]; then
  echo ""
  echo "FAILED (${failures} certificate readiness checks failed)" >&2
  exit 1
fi

echo ""
echo "OK"
