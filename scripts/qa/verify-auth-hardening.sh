#!/usr/bin/env bash
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

usage() {
  cat <<EOF
Usage: $0 [--env prod|dev|both] [--mode public|internal|all]

Env:
  CHECK_TIMEOUT_SECONDS=300  Per-check timeout in seconds (default: 300)
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

if [[ "$run_public" -eq 1 ]]; then
  run_check "repo: OIDC cookie middleware order guard" "$REPO_ROOT/scripts/qa/verify-oidc-cookie-middleware-order.sh"
  if [[ "$ENV_SCOPE" == "prod" || "$ENV_SCOPE" == "both" ]]; then
    run_check "public auth surfaces (prod)" env STRICT_ADMIN_LOGIN_REDIRECT=1 "$REPO_ROOT/scripts/qa/verify-auth-surfaces.sh" prod
  fi
  if [[ "$ENV_SCOPE" == "dev" || "$ENV_SCOPE" == "both" ]]; then
    run_check "public auth surfaces (dev)" env STRICT_ADMIN_LOGIN_REDIRECT=1 "$REPO_ROOT/scripts/qa/verify-auth-surfaces.sh" dev
  fi
fi

if [[ "$run_internal" -eq 1 ]]; then
  if [[ "$ENV_SCOPE" == "prod" || "$ENV_SCOPE" == "both" ]]; then
    run_check "multisite config (prod)" env STRICT=1 "$REPO_ROOT/scripts/qa/verify-multisite-config.sh" prod
    run_check "org role ownership (prod)" env STRICT=1 "$REPO_ROOT/scripts/qa/verify-org-role-ownership.sh" prod
    run_check "platform admin perms (prod)" "$REPO_ROOT/scripts/infra/ensure-platform-admins.sh" --context gke_bbi-k8_asia-southeast1-c_bbi-k8-cluster --verify
    run_check "Authentik admin policy (prod)" "$REPO_ROOT/scripts/infra/ensure-authentik-admin.sh" --verify
    run_check "Authentik OIDC redirect URI allowlist (prod)" "$REPO_ROOT/scripts/infra/ensure-authentik-oidc-redirect-uris.sh" --verify
    run_check "OIDC provider configs (prod)" "$REPO_ROOT/scripts/qa/verify-oidc-provider-configs.sh" --env prod --context gke_bbi-k8_asia-southeast1-c_bbi-k8-cluster
  fi
  if [[ "$ENV_SCOPE" == "dev" || "$ENV_SCOPE" == "both" ]]; then
    run_check "multisite config (dev)" env STRICT=1 "$REPO_ROOT/scripts/qa/verify-multisite-config.sh" dev
    run_check "org role ownership (dev)" env STRICT=1 "$REPO_ROOT/scripts/qa/verify-org-role-ownership.sh" dev
    run_check "platform admin perms (dev)" "$REPO_ROOT/scripts/infra/ensure-platform-admins.sh" --context kind-dev --verify
    run_check "OIDC provider configs (dev)" "$REPO_ROOT/scripts/qa/verify-oidc-provider-configs.sh" --env dev --context kind-dev
  fi
  run_check "hostname registry vs ingresses ($ENV_SCOPE)" "$REPO_ROOT/scripts/qa/list-openedx-hostnames.sh" --env "$ENV_SCOPE"
fi

if [[ "$failures" -gt 0 ]]; then
  log "FAILED ($failures checks failed)"
  exit 1
fi

log "OK"
