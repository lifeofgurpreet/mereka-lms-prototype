#!/usr/bin/env bash
# @covers AC-041, AC-044
# @spec: auth-sso-enterprise_spec.md
# Audit Authentik policy execution exceptions that can break SSO flows.
#
# Why: Authentik policy exceptions can surface as:
# - "Request has been denied" / "Unknown error" on the login UI
# - intermittent OIDC authorization failures
#
# This check is runtime-only (requires kubectl access) and intentionally does not
# print secrets. It filters for policy_exception events and (optionally) for
# OIDC authorize flows.
#
# Usage:
#   ./scripts/qa/audit-authentik-policy-exceptions.sh
#   ./scripts/qa/audit-authentik-policy-exceptions.sh --since 2h
#
set -euo pipefail

SINCE="${SINCE:-6h}"
CONTEXT="${K8S_CONTEXT_PROD:-${K8S_CONTEXT:-gke_bbi-k8_asia-southeast1-c_bbi-k8-cluster}}"
NAMESPACE="${AUTHENTIK_NAMESPACE:-authentik}"
DEPLOYMENT="${AUTHENTIK_DEPLOYMENT:-authentik-server}"
FILTER_OIDC_ONLY="${FILTER_OIDC_ONLY:-1}"

case "$FILTER_OIDC_ONLY" in
  0|1) ;;
  *)
    echo "Invalid FILTER_OIDC_ONLY='$FILTER_OIDC_ONLY' (expected 0 or 1)" >&2
    exit 1
    ;;
esac

usage() {
  cat <<'USAGE' >&2
Usage: ./scripts/qa/audit-authentik-policy-exceptions.sh [--since 6h]

Env:
  K8S_CONTEXT                kubectl context (default: gke_bbi-k8_asia-southeast1-c_bbi-k8-cluster)
  AUTHENTIK_NAMESPACE        namespace (default: authentik)
  AUTHENTIK_DEPLOYMENT       deployment name (default: authentik-server)
  FILTER_OIDC_ONLY=1         only flag exceptions observed during /application/o/authorize flows
  SINCE=6h                   time window (default: 6h)
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --since)
      SINCE="${2:-}"; shift 2 ;;
    -h|--help)
      usage
      exit 0 ;;
    *)
      echo "Unknown arg: $1" >&2
      usage
      exit 1 ;;
  esac
done

if [[ -z "$SINCE" ]]; then
  echo "--since is required" >&2
  exit 1
fi

if ! command -v kubectl >/dev/null 2>&1; then
  echo "[SKIP] kubectl not available — skipping cluster checks"
  exit 0
fi
if ! kubectl --context "$CONTEXT" cluster-info &>/dev/null; then
  echo "[SKIP] No reachable cluster at context '$CONTEXT' — skipping"
  exit 0
fi

log_json="$(kubectl --context "$CONTEXT" -n "$NAMESPACE" logs deploy/"$DEPLOYMENT" --since="$SINCE" 2>/dev/null || true)"
if [[ -z "$log_json" ]]; then
  echo "FAIL: no logs returned (ctx=$CONTEXT ns=$NAMESPACE deploy=$DEPLOYMENT since=$SINCE)" >&2
  exit 1
fi

# Authentik emits JSON logs; match the policy_exception action.
if [[ "$FILTER_OIDC_ONLY" == "1" ]]; then
  matches="$(rg -n '"action":\s*"policy_exception"' <<<"$log_json" | rg -n '/application/o/authorize|client_id=mereka-lms' || true)"
else
  matches="$(rg -n '"action":\s*"policy_exception"' <<<"$log_json" || true)"
fi

count="$(printf "%s\n" "$matches" | awk 'NF{c++} END{print c+0}')"
if [[ "$count" -gt 0 ]]; then
  echo "FAIL: Authentik policy_exception events detected (count=$count, since=$SINCE, oidc_only=$FILTER_OIDC_ONLY)" >&2
  echo "--- sample (last 5) ---" >&2
  # Redact any embedded emails to avoid leaking PII in CI logs.
  printf "%s\n" "$matches" | tail -n 5 | sed -E 's/"email":[[:space:]]*"[^"]+"/"email":"<redacted>"/g' >&2
  exit 1
fi

echo "OK: no Authentik policy_exception events detected (since=$SINCE, oidc_only=$FILTER_OIDC_ONLY)"
