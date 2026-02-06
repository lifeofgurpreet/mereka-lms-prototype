#!/usr/bin/env bash
# One entrypoint to verify/apply Authentik hardening configuration.
#
# This is the "config as code" surface for Authentik in this repo:
# - Admin group membership (Gurpreet only)
# - OIDC redirect URI allowlist (all LMS hostnames we serve)
# - MFA required for Authentik admins (gated policy + validate stage)
#
# Usage:
#   ./scripts/infra/ensure-authentik-hardening.sh --verify
#   ./scripts/infra/ensure-authentik-hardening.sh --apply
#
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

K8S_CONTEXT="${K8S_CONTEXT:-gke_bbi-k8_asia-southeast1-c_bbi-k8-cluster}"
NAMESPACE="${NAMESPACE:-authentik}"
AUTHENTIK_DEPLOY="${AUTHENTIK_DEPLOY:-authentik-server}"
CLIENT_ID="${CLIENT_ID:-mereka-lms}"

MODE="verify" # verify | apply

usage() {
  cat <<EOF
Usage: $0 [OPTIONS]

OPTIONS:
  --verify                  Verify only (default)
  --apply                   Apply changes (idempotent)
  --context K8S_CONTEXT     Kube context (default: $K8S_CONTEXT)
  --namespace NAMESPACE     Namespace (default: $NAMESPACE)
  --deploy DEPLOYMENT       Authentik server deployment name (default: $AUTHENTIK_DEPLOY)
  --client-id CLIENT_ID     OAuth2 client_id (default: $CLIENT_ID)
  -h, --help                Show help
EOF
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --verify) MODE="verify"; shift ;;
    --apply) MODE="apply"; shift ;;
    --context) K8S_CONTEXT="$2"; shift 2 ;;
    --namespace) NAMESPACE="$2"; shift 2 ;;
    --deploy) AUTHENTIK_DEPLOY="$2"; shift 2 ;;
    --client-id) CLIENT_ID="$2"; shift 2 ;;
    -h|--help) usage ;;
    *) echo "Unknown option: $1" >&2; usage ;;
  esac
done

failures=0

run() {
  local label="$1"
  shift
  echo ""
  echo "==> $label"
  if ! "$@"; then
    failures=$((failures + 1))
  fi
}

common_args=(--context "$K8S_CONTEXT" --namespace "$NAMESPACE")

if [[ "$MODE" == "apply" ]]; then
  run "Authentik admin policy" \
    "$REPO_ROOT/scripts/infra/ensure-authentik-admin.sh" --apply "${common_args[@]}"

  run "Authentik OIDC redirect URIs" \
    "$REPO_ROOT/scripts/infra/ensure-authentik-oidc-redirect-uris.sh" --apply \
      "${common_args[@]}" --deploy "$AUTHENTIK_DEPLOY" --client-id "$CLIENT_ID"

  run "Authentik admin MFA required" \
    "$REPO_ROOT/scripts/infra/ensure-authentik-admin-mfa.sh" --apply \
      "${common_args[@]}" --deploy "$AUTHENTIK_DEPLOY"
else
  run "Authentik admin policy" \
    "$REPO_ROOT/scripts/infra/ensure-authentik-admin.sh" --verify "${common_args[@]}"

  run "Authentik OIDC redirect URIs" \
    "$REPO_ROOT/scripts/infra/ensure-authentik-oidc-redirect-uris.sh" --verify \
      "${common_args[@]}" --deploy "$AUTHENTIK_DEPLOY" --client-id "$CLIENT_ID"

  run "Authentik admin MFA required" \
    "$REPO_ROOT/scripts/infra/ensure-authentik-admin-mfa.sh" --verify \
      "${common_args[@]}" --deploy "$AUTHENTIK_DEPLOY"
fi

echo ""
if [[ "$failures" -gt 0 ]]; then
  echo "FAILED ($failures checks failed)" >&2
  exit 1
fi

echo "OK"

