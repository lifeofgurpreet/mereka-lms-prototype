#!/usr/bin/env bash
# @covers AC-016
# @spec: auth-sso-enterprise_spec.md
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
ALLOW_PROD_APPLY="${ALLOW_PROD_APPLY:-0}"
CREATE_PREOP_BACKUP="${CREATE_PREOP_BACKUP:-1}"
CONFIRM_ENSURE_AUTHENTIK_HARDENING="${CONFIRM_ENSURE_AUTHENTIK_HARDENING:-}"
CONFIRM_TOKEN="ENSURE_AUTHENTIK_HARDENING"

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

Safety controls for --apply:
  CONFIRM_ENSURE_AUTHENTIK_HARDENING=ENSURE_AUTHENTIK_HARDENING
  ALLOW_PROD_APPLY=1        Required for prod-like contexts
  CREATE_PREOP_BACKUP=1     Default for prod-like contexts (Velero pre-op backup)
EOF
  exit 1
}

require_bool_01() {
  local var_name="$1"
  local value="$2"
  case "$value" in
    0|1) ;;
    *)
      echo "Invalid ${var_name}='${value}' (expected 0 or 1)" >&2
      exit 1
      ;;
  esac
}

require_cmd() {
  local cmd="$1"
  command -v "$cmd" >/dev/null 2>&1 || {
    echo "Missing command: $cmd" >&2
    exit 1
  }
}

is_prod_like_context() {
  local ctx="$1"
  [[ "$ctx" == *"gke_bbi-k8"* ]] || [[ "$ctx" == "prod" ]] || [[ "$ctx" == "production" ]] || [[ "$ctx" == "gke-prod" ]]
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

require_bool_01 "ALLOW_PROD_APPLY" "$ALLOW_PROD_APPLY"
require_bool_01 "CREATE_PREOP_BACKUP" "$CREATE_PREOP_BACKUP"

if [[ "$MODE" == "apply" ]]; then
  if [[ "$CONFIRM_ENSURE_AUTHENTIK_HARDENING" != "$CONFIRM_TOKEN" ]]; then
    echo "Refusing --apply without explicit confirmation token. Set CONFIRM_ENSURE_AUTHENTIK_HARDENING=${CONFIRM_TOKEN}" >&2
    exit 1
  fi

  if is_prod_like_context "$K8S_CONTEXT" && [[ "$ALLOW_PROD_APPLY" != "1" ]]; then
    echo "Refusing --apply on prod-like context '$K8S_CONTEXT' without ALLOW_PROD_APPLY=1" >&2
    exit 1
  fi

  if is_prod_like_context "$K8S_CONTEXT"; then
    if [[ "$CREATE_PREOP_BACKUP" == "1" ]]; then
      require_cmd velero
      backup_name="pre-op-${NAMESPACE}-ensure-authentik-hardening-$(date -u +%Y%m%d-%H%M)"
      echo "Creating Velero pre-op backup: $backup_name"
      velero backup create "$backup_name" --include-namespaces "$NAMESPACE" --wait
    else
      echo "WARNING: CREATE_PREOP_BACKUP=0 on prod-like context '$K8S_CONTEXT' (operator override)"
    fi
  fi
fi

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
    env CONFIRM_ENSURE_AUTHENTIK_ADMIN="ENSURE_AUTHENTIK_ADMIN" ALLOW_PROD_APPLY="$ALLOW_PROD_APPLY" CREATE_PREOP_BACKUP=0 \
      "$REPO_ROOT/scripts/infra/ensure-authentik-admin.sh" --apply "${common_args[@]}"

  run "Authentik OIDC redirect URIs" \
    env CONFIRM_ENSURE_AUTHENTIK_OIDC_REDIRECT_URIS="ENSURE_AUTHENTIK_OIDC_REDIRECT_URIS" ALLOW_PROD_APPLY="$ALLOW_PROD_APPLY" CREATE_PREOP_BACKUP=0 \
      "$REPO_ROOT/scripts/infra/ensure-authentik-oidc-redirect-uris.sh" --apply \
      "${common_args[@]}" --deploy "$AUTHENTIK_DEPLOY" --client-id "$CLIENT_ID"

  run "Authentik admin MFA required" \
    env CONFIRM_ENSURE_AUTHENTIK_ADMIN_MFA="ENSURE_AUTHENTIK_ADMIN_MFA" ALLOW_PROD_APPLY="$ALLOW_PROD_APPLY" CREATE_PREOP_BACKUP=0 \
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
