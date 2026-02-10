#!/usr/bin/env bash
# Aggregate audit for authentication surfaces + admin permissions.
#
# This is verify-only (no changes applied). It is intended to remove tribal knowledge by
# producing one report operators can paste into a ticket/Slack.
#
# Usage:
#   ./scripts/qa/audit-auth-access.sh
#   ./scripts/qa/audit-auth-access.sh --env prod
#   ./scripts/qa/audit-auth-access.sh --env dev
#   ./scripts/qa/audit-auth-access.sh --mode public
#   ./scripts/qa/audit-auth-access.sh --json
#
# Modes:
#   public:  only checks that run without kubectl (safe for CI)
#   internal: checks that require kubectl access (permissions/config drift)
#   all:     public + internal (default)
#
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

usage() {
  cat <<'EOF' >&2
Usage: ./scripts/qa/audit-auth-access.sh [--env prod|dev|both] [--mode public|internal|all] [--json]
EOF
}

ENV_SCOPE="both"
MODE="all"
JSON_OUT=0
CHECK_TIMEOUT_SECONDS="${CHECK_TIMEOUT_SECONDS:-240}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --env)
      ENV_SCOPE="${2:-}"; shift 2 ;;
    --mode)
      MODE="${2:-}"; shift 2 ;;
    --json)
      JSON_OUT=1; shift ;;
    -h|--help)
      usage; exit 0 ;;
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

json_escape() {
  local s="${1:-}"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  s="${s//$'\n'/\\n}"
  printf "%s" "$s"
}

CHECK_NAMES=()
CHECK_OK=()
CHECK_CODE=()
CHECK_MSG=()

failures=0

run_check() {
  local name="$1"; shift
  local tmp
  tmp="$(mktemp -t audit-auth-access.XXXXXX)"

  set +e
  if command -v timeout >/dev/null 2>&1; then
    timeout "$CHECK_TIMEOUT_SECONDS" "$@" >"$tmp" 2>&1
  else
    "$@" >"$tmp" 2>&1
  fi
  local code=$?
  set -e

  local ok=0
  if [[ "$code" -eq 0 ]]; then ok=1; fi

  CHECK_NAMES+=("$name")
  CHECK_OK+=("$ok")
  CHECK_CODE+=("$code")

  if [[ "$ok" -eq 1 ]]; then
    CHECK_MSG+=("")
    [[ "$JSON_OUT" -eq 0 ]] && printf "✓ %s\n" "$name"
  else
    failures=$((failures + 1))
    local tail
    tail="$(tail -n 30 "$tmp" | sed 's/\r$//')"
    CHECK_MSG+=("$tail")
    if [[ "$JSON_OUT" -eq 0 ]]; then
      printf "✗ %s (exit=%s)\n" "$name" "$code" >&2
      printf "%s\n" "$tail" | sed 's/^/  /' >&2
    fi
  fi

  rm -f "$tmp"
}

should_run_public=0
should_run_internal=0
case "$MODE" in
  public) should_run_public=1 ;;
  internal) should_run_internal=1 ;;
  all) should_run_public=1; should_run_internal=1 ;;
esac

if [[ "$JSON_OUT" -eq 0 ]]; then
  echo "Audit: auth surfaces + access"
  echo "  env:  $ENV_SCOPE"
  echo "  mode: $MODE"
  echo ""
fi

run_check "repo: OIDC cookie middleware order guard" ./scripts/qa/verify-oidc-cookie-middleware-order.sh

if [[ "$should_run_public" -eq 1 ]]; then
  if [[ "$ENV_SCOPE" == "prod" || "$ENV_SCOPE" == "both" ]]; then
    run_check "public: auth surfaces (prod)" ./scripts/qa/verify-auth-surfaces.sh prod
    run_check "public: MFE config contract (prod)" ./scripts/qa/verify-mfe-config-contract.sh --env prod
    run_check "public: cert SANs (prod)" ./scripts/infra/check-cert-sans.sh
  fi
  if [[ "$ENV_SCOPE" == "dev" || "$ENV_SCOPE" == "both" ]]; then
    run_check "public: auth surfaces (dev)" ./scripts/qa/verify-auth-surfaces.sh dev
    run_check "public: MFE config contract (dev)" ./scripts/qa/verify-mfe-config-contract.sh --env dev
  fi
fi

if [[ "$should_run_internal" -eq 1 ]]; then
  if [[ "$ENV_SCOPE" == "prod" ]]; then
    run_check "internal: platform admin perms (prod)" \
      ./scripts/infra/ensure-platform-admins.sh --context gke_bbi-k8_asia-southeast1-c_bbi-k8-cluster --verify
  elif [[ "$ENV_SCOPE" == "dev" ]]; then
    run_check "internal: platform admin perms (dev)" \
      ./scripts/infra/ensure-platform-admins.sh --context kind-dev --verify
  else
    # Run per-context so a single unreachable cluster doesn't block the entire audit.
    run_check "internal: platform admin perms (prod)" \
      ./scripts/infra/ensure-platform-admins.sh --context gke_bbi-k8_asia-southeast1-c_bbi-k8-cluster --verify
    run_check "internal: platform admin perms (dev)" \
      ./scripts/infra/ensure-platform-admins.sh --context kind-dev --verify
  fi

  run_check "internal: Authentik admin policy (prod)" ./scripts/infra/ensure-authentik-admin.sh --verify
  run_check "internal: Authentik redirect URI allowlist (prod)" ./scripts/infra/ensure-authentik-oidc-redirect-uris.sh --verify
  if [[ "$ENV_SCOPE" == "prod" ]]; then
    run_check "internal: OIDC provider configs (prod)" \
      ./scripts/qa/verify-oidc-provider-configs.sh --env prod --context gke_bbi-k8_asia-southeast1-c_bbi-k8-cluster
    run_check "internal: OIDC user password state (prod)" \
      ./scripts/qa/verify-oidc-user-password-state.sh --env prod
  elif [[ "$ENV_SCOPE" == "dev" ]]; then
    run_check "internal: OIDC provider configs (dev)" \
      ./scripts/qa/verify-oidc-provider-configs.sh --env dev --context kind-dev
    run_check "internal: OIDC user password state (dev)" \
      ./scripts/qa/verify-oidc-user-password-state.sh --env dev
  else
    run_check "internal: OIDC provider configs (prod + dev)" \
      ./scripts/qa/verify-oidc-provider-configs.sh --env auto
    run_check "internal: OIDC user password state (prod + dev)" \
      ./scripts/qa/verify-oidc-user-password-state.sh --env both
  fi
  run_check "internal: platform admin allowlist env (prod + dev)" ./scripts/qa/verify-platform-admin-env.sh --env "$ENV_SCOPE"
  run_check "internal: core service endpoints (prod + dev)" ./scripts/qa/verify-service-endpoints.sh --env "$ENV_SCOPE"
  run_check "internal: course data sanity (prod + dev)" ./scripts/qa/course-data-sanity.sh --env "$ENV_SCOPE"

  if [[ "$ENV_SCOPE" == "prod" || "$ENV_SCOPE" == "both" ]]; then
    run_check "internal: multisite config (prod)" env STRICT=1 ./scripts/qa/verify-multisite-config.sh prod
    run_check "internal: org role ownership (prod)" env STRICT=1 ./scripts/qa/verify-org-role-ownership.sh prod
  fi
  if [[ "$ENV_SCOPE" == "dev" || "$ENV_SCOPE" == "both" ]]; then
    run_check "internal: multisite config (dev)" env STRICT=1 ./scripts/qa/verify-multisite-config.sh dev
    run_check "internal: org role ownership (dev)" env STRICT=1 ./scripts/qa/verify-org-role-ownership.sh dev
  fi

  run_check "internal: hostnames registry drift ($ENV_SCOPE)" ./scripts/qa/list-openedx-hostnames.sh --env "$ENV_SCOPE"
fi

if [[ "$JSON_OUT" -eq 1 ]]; then
  printf "{"
  printf "\"env\":\"%s\"," "$(json_escape "$ENV_SCOPE")"
  printf "\"mode\":\"%s\"," "$(json_escape "$MODE")"
  printf "\"checks\":["
  for i in "${!CHECK_NAMES[@]}"; do
    [[ "$i" -gt 0 ]] && printf ","
    printf "{"
    printf "\"name\":\"%s\"," "$(json_escape "${CHECK_NAMES[$i]}")"
    printf "\"ok\":%s," "${CHECK_OK[$i]}"
    printf "\"exit_code\":%s" "${CHECK_CODE[$i]}"
    if [[ -n "${CHECK_MSG[$i]}" ]]; then
      printf ",\"message\":\"%s\"" "$(json_escape "${CHECK_MSG[$i]}")"
    fi
    printf "}"
  done
  printf "],"
  printf "\"failures\":%s" "$failures"
  printf "}\n"
else
  echo ""
  if [[ "$failures" -gt 0 ]]; then
    echo "FAILED ($failures checks failed)" >&2
  else
    echo "OK"
  fi
fi

[[ "$failures" -eq 0 ]]
