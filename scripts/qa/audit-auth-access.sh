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

if [[ "$should_run_public" -eq 1 ]]; then
  if [[ "$ENV_SCOPE" == "prod" || "$ENV_SCOPE" == "both" ]]; then
    run_check "public: auth surfaces (prod)" ./scripts/qa/verify-auth-surfaces.sh prod
  fi
  if [[ "$ENV_SCOPE" == "dev" || "$ENV_SCOPE" == "both" ]]; then
    run_check "public: auth surfaces (dev)" ./scripts/qa/verify-auth-surfaces.sh dev
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
  run_check "internal: OIDC provider configs (prod + dev)" ./scripts/qa/verify-oidc-provider-configs.sh

  if [[ "$ENV_SCOPE" == "prod" || "$ENV_SCOPE" == "both" ]]; then
    run_check "internal: multisite config (prod)" ./scripts/qa/verify-multisite-config.sh prod
  fi
  if [[ "$ENV_SCOPE" == "dev" || "$ENV_SCOPE" == "both" ]]; then
    run_check "internal: multisite config (dev)" ./scripts/qa/verify-multisite-config.sh dev
  fi

  run_check "internal: hostnames registry drift (prod + dev)" ./scripts/qa/list-openedx-hostnames.sh
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
