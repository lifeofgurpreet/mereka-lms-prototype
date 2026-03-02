#!/usr/bin/env bash
# @covers AC-042
# @spec: auth-sso-enterprise_spec.md
# One-shot "world-class" verification for auth + permissions hardening.
#
# This aggregates both public and internal checks:
# - Public checks: run without credentials
# - Internal checks: require kubectl (but no secrets)
#
# Usage:
#   ./scripts/qa/verify-auth-hardening.sh
#   ./scripts/qa/verify-auth-hardening.sh --env prod --mode all
#   CHECK_TIMEOUT_SECONDS=180 ./scripts/qa/verify-auth-hardening.sh --env dev --mode internal
#
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$REPO_ROOT/scripts/shared/config.sh"

ENV_SCOPE="both" # prod|dev|both
MODE="all"       # public|internal|all
CHECK_TIMEOUT_SECONDS="${CHECK_TIMEOUT_SECONDS:-300}"
RUN_AUTHENTICATED_SSO_CANARY="${RUN_AUTHENTICATED_SSO_CANARY:-0}"
AUTHENTICATED_SSO_CANARY_REQUIRE_SECRETS="${AUTHENTICATED_SSO_CANARY_REQUIRE_SECRETS:-1}"
CONTEXT_PROD="${CONTEXT_PROD:-${K8S_CONTEXT_PROD:-${K8S_CONTEXT:-gke_bbi-k8_asia-southeast1-c_bbi-k8-cluster}}}"
CONTEXT_DEV="${CONTEXT_DEV:-${K8S_CONTEXT_DEV:-${K8S_CONTEXT:-kind-dev}}}"
NAMESPACE_PROD="${NAMESPACE_PROD:-${K8S_NAMESPACE_PROD:-${K8S_NAMESPACE:-mereka-lms}}}"
NAMESPACE_DEV="${NAMESPACE_DEV:-${K8S_NAMESPACE_DEV:-${K8S_NAMESPACE:-mereka-lms}}}"

usage() {
  cat <<EOF
Usage: $0 [--env prod|dev|both] [--mode public|internal|all]

Env:
  CHECK_TIMEOUT_SECONDS=300  Per-check timeout in seconds (default: 300)
  RUN_AUTHENTICATED_SSO_CANARY=1  Run credentialed browser SSO canary
  AUTHENTICATED_SSO_CANARY_REQUIRE_SECRETS=1  Fail if canary creds are missing
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --env)
      ENV_SCOPE="${2:-}"; shift 2 ;;
    --mode)
      MODE="${2:-}"; shift 2 ;;
    -h|--help)
      usage
      exit 0 ;;
    *)
      echo "Unknown arg: $1" >&2
      usage
      exit 1 ;;
  esac
done

if [[ "$ENV_SCOPE" != "prod" && "$ENV_SCOPE" != "dev" && "$ENV_SCOPE" != "both" ]]; then
  echo "Invalid --env: $ENV_SCOPE" >&2
  usage
  exit 1
fi

if [[ "$MODE" != "public" && "$MODE" != "internal" && "$MODE" != "all" ]]; then
  echo "Invalid --mode: $MODE" >&2
  usage
  exit 1
fi

require_bool_01() {
  local var_name="$1"
  local value="$2"
  case "$value" in
    0|1) ;;
    *)
      echo "Invalid $var_name='$value' (expected 0 or 1)" >&2
      exit 1
      ;;
  esac
}

require_bool_01 "RUN_AUTHENTICATED_SSO_CANARY" "$RUN_AUTHENTICATED_SSO_CANARY"
require_bool_01 "AUTHENTICATED_SSO_CANARY_REQUIRE_SECRETS" "$AUTHENTICATED_SSO_CANARY_REQUIRE_SECRETS"

log() { echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] $*"; }

failures=0

run_check() {
  local name="$1"; shift
  local tmp rc tail
  tmp="$(mktemp -t verify-auth-hardening.XXXXXX)"

  set +e
  if command -v timeout >/dev/null 2>&1; then
    timeout "${CHECK_TIMEOUT_SECONDS}s" "$@" >"$tmp" 2>&1
  else
    "$@" >"$tmp" 2>&1
  fi
  rc=$?
  set -e

  if [[ "$rc" -eq 0 ]]; then
    log "OK: $name"
  else
    failures=$((failures + 1))
    log "FAIL: $name (exit=$rc)"
    tail="$(tail -n 30 "$tmp" | sed 's/\r$//')"
    if [[ -n "$tail" ]]; then
      printf "%s\n" "$tail" | sed 's/^/  /'
    fi
  fi

  rm -f "$tmp"
}

run_public=0
run_internal=0
case "$MODE" in
  public) run_public=1 ;;
  internal) run_internal=1 ;;
  all) run_public=1; run_internal=1 ;;
esac

log "verify-auth-hardening: env=$ENV_SCOPE mode=$MODE timeout=${CHECK_TIMEOUT_SECONDS}s"
log "verify-auth-hardening: run_authenticated_sso_canary=$RUN_AUTHENTICATED_SSO_CANARY require_secrets=$AUTHENTICATED_SSO_CANARY_REQUIRE_SECRETS"
log "verify-auth-hardening: context_prod=$CONTEXT_PROD context_dev=$CONTEXT_DEV"
log "verify-auth-hardening: namespace_prod=$NAMESPACE_PROD namespace_dev=$NAMESPACE_DEV"

if [[ "$run_public" -eq 1 ]]; then
  run_check "repo: OIDC cookie middleware order guard" "$REPO_ROOT/scripts/qa/verify-oidc-cookie-middleware-order.sh"
  if [[ "$ENV_SCOPE" == "prod" || "$ENV_SCOPE" == "both" ]]; then
    run_check "public auth surfaces (prod)" env STRICT_ADMIN_LOGIN_REDIRECT=1 "$REPO_ROOT/scripts/qa/verify-auth-surfaces.sh" prod
  fi
  if [[ "$ENV_SCOPE" == "dev" || "$ENV_SCOPE" == "both" ]]; then
    run_check "public auth surfaces (dev)" env STRICT_ADMIN_LOGIN_REDIRECT=1 "$REPO_ROOT/scripts/qa/verify-auth-surfaces.sh" dev
  fi
  if [[ "$RUN_AUTHENTICATED_SSO_CANARY" == "1" ]]; then
    run_check "authenticated SSO canary ($ENV_SCOPE)" \
      env REQUIRE_SECRETS="$AUTHENTICATED_SSO_CANARY_REQUIRE_SECRETS" \
      "$REPO_ROOT/scripts/qa/verify-authenticated-sso-canary.sh" --env "$ENV_SCOPE"
  fi
fi

if [[ "$run_internal" -eq 1 ]]; then
  if [[ "$ENV_SCOPE" == "prod" || "$ENV_SCOPE" == "both" ]]; then
    run_check "multisite config (prod)" env STRICT=1 "$REPO_ROOT/scripts/qa/verify-multisite-config.sh" prod --context "$CONTEXT_PROD" --namespace "$NAMESPACE_PROD"
    run_check "org role ownership (prod)" env STRICT=1 "$REPO_ROOT/scripts/qa/verify-org-role-ownership.sh" prod --context "$CONTEXT_PROD" --namespace "$NAMESPACE_PROD"
    run_check "platform admin perms (prod)" "$REPO_ROOT/scripts/infra/ensure-platform-admins.sh" --context "$CONTEXT_PROD" --verify
    run_check "Authentik admin policy (prod)" "$REPO_ROOT/scripts/infra/ensure-authentik-admin.sh" --verify
    run_check "Authentik OIDC redirect URI allowlist (prod)" "$REPO_ROOT/scripts/infra/ensure-authentik-oidc-redirect-uris.sh" --verify
    run_check "OIDC provider configs (prod)" "$REPO_ROOT/scripts/qa/verify-oidc-provider-configs.sh" --env prod --context "$CONTEXT_PROD"
    run_check "CMS oauth secret present (prod)" "$REPO_ROOT/scripts/qa/verify-cms-oauth2-secret-present.sh" --context "$CONTEXT_PROD"
    run_check "OIDC user password state (prod)" "$REPO_ROOT/scripts/qa/verify-oidc-user-password-state.sh" --env prod
  fi
  if [[ "$ENV_SCOPE" == "dev" || "$ENV_SCOPE" == "both" ]]; then
    run_check "multisite config (dev)" env STRICT=1 "$REPO_ROOT/scripts/qa/verify-multisite-config.sh" dev --context "$CONTEXT_DEV" --namespace "$NAMESPACE_DEV"
    run_check "org role ownership (dev)" env STRICT=1 "$REPO_ROOT/scripts/qa/verify-org-role-ownership.sh" dev --context "$CONTEXT_DEV" --namespace "$NAMESPACE_DEV"
    run_check "platform admin perms (dev)" "$REPO_ROOT/scripts/infra/ensure-platform-admins.sh" --context "$CONTEXT_DEV" --verify
    run_check "OIDC provider configs (dev)" "$REPO_ROOT/scripts/qa/verify-oidc-provider-configs.sh" --env dev --context "$CONTEXT_DEV"
    run_check "CMS oauth secret present (dev)" "$REPO_ROOT/scripts/qa/verify-cms-oauth2-secret-present.sh" --context "$CONTEXT_DEV"
    run_check "OIDC user password state (dev)" "$REPO_ROOT/scripts/qa/verify-oidc-user-password-state.sh" --env dev
  fi
  if [[ "$ENV_SCOPE" == "prod" || "$ENV_SCOPE" == "both" ]]; then
    run_check "hostname registry vs ingresses (prod)" \
      env STRICT=1 NAMESPACE="$NAMESPACE_PROD" CONTEXT_PROD="$CONTEXT_PROD" \
      "$REPO_ROOT/scripts/qa/list-openedx-hostnames.sh" --env prod
  fi
  if [[ "$ENV_SCOPE" == "dev" || "$ENV_SCOPE" == "both" ]]; then
    run_check "hostname registry vs ingresses (dev)" \
      env STRICT=1 NAMESPACE="$NAMESPACE_DEV" CONTEXT_DEV="$CONTEXT_DEV" \
      "$REPO_ROOT/scripts/qa/list-openedx-hostnames.sh" --env dev
  fi
fi

if [[ "$failures" -gt 0 ]]; then
  log "FAILED ($failures checks failed)"
  exit 1
fi

log "OK"
