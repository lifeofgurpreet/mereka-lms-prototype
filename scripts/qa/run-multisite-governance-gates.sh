#!/usr/bin/env bash
# @covers AC-001, AC-TBR-104
# @spec: multi-site-domains_spec.md
# Unified multisite governance gate for domain/site config + org ownership.
#
# Usage:
#   ./scripts/qa/run-multisite-governance-gates.sh
#   ./scripts/qa/run-multisite-governance-gates.sh --env prod
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

ENV_SCOPE="${ENV_SCOPE:-both}"
STRICT="${STRICT:-1}"
CHECK_TIMEOUT_SECONDS="${CHECK_TIMEOUT_SECONDS:-900}"
SKIP_DEV_ON_BOTH="${SKIP_DEV_ON_BOTH:-0}"
ALLOW_SHARED_HOSTS_FILE="${ALLOW_SHARED_HOSTS_FILE:-infrastructure/tutor/multisite-shared-host-allowlist.txt}"
PROD_CONTEXT="${PROD_CONTEXT:-${K8S_CONTEXT_PROD:-}}"
DEV_CONTEXT="${DEV_CONTEXT:-${K8S_CONTEXT_DEV:-}}"
STAGING_CONTEXT="${STAGING_CONTEXT:-${K8S_CONTEXT_STAGING:-rke2-nonprod}}"
PROD_NAMESPACE="${PROD_NAMESPACE:-${K8S_NAMESPACE_PROD:-${K8S_NAMESPACE:-mereka-lms}}}"
DEV_NAMESPACE="${DEV_NAMESPACE:-${K8S_NAMESPACE_DEV:-${K8S_NAMESPACE:-mereka-lms}}}"
STAGING_NAMESPACE="${STAGING_NAMESPACE:-${K8S_NAMESPACE_STAGING:-stg-mereka-lms}}"
PROD_ALLOW_CREDENTIALS_500="${PROD_ALLOW_CREDENTIALS_500:-0}"
DEV_ALLOW_CREDENTIALS_500="${DEV_ALLOW_CREDENTIALS_500:-0}"
STAGING_ALLOW_CREDENTIALS_500="${STAGING_ALLOW_CREDENTIALS_500:-0}"
PROD_NOTES_BANNER_NEEDLE="${PROD_NOTES_BANNER_NEEDLE:-edX Notes API}"
DEV_NOTES_BANNER_NEEDLE="${DEV_NOTES_BANNER_NEEDLE:-edX Notes API}"
STAGING_NOTES_BANNER_NEEDLE="${STAGING_NOTES_BANNER_NEEDLE:-edX Notes API}"
PROD_ALLOW_FORUM_HEARTBEAT_404="${PROD_ALLOW_FORUM_HEARTBEAT_404:-0}"
DEV_ALLOW_FORUM_HEARTBEAT_404="${DEV_ALLOW_FORUM_HEARTBEAT_404:-0}"
STAGING_ALLOW_FORUM_HEARTBEAT_404="${STAGING_ALLOW_FORUM_HEARTBEAT_404:-0}"
# Explicit ack required before any prod auth-surface relaxation is allowed.
ALLOW_PROD_AUTH_SURFACE_TOLERANCES="${ALLOW_PROD_AUTH_SURFACE_TOLERANCES:-0}"
# Short timeout (seconds) for cluster reachability probes.  Prevents hangs when
# a kubectl context exists in kubeconfig but the cluster is offline.
CLUSTER_CHECK_TIMEOUT="${CLUSTER_CHECK_TIMEOUT:-20}"
# Skip dev OIDC checks when the entrypoint returns non-redirect (Authentik not configured).
DEV_SKIP_OIDC_ON_NON_REDIRECT="${DEV_SKIP_OIDC_ON_NON_REDIRECT:-1}"
STAMP="$(date -u +%Y%m%d-%H%M%S)"
ARTIFACT_DIR="${ARTIFACT_DIR:-var/multisite-governance-gates/${STAMP}}"
mkdir -p "$ARTIFACT_DIR"

usage() {
  cat <<'EOF'
Usage: ./scripts/qa/run-multisite-governance-gates.sh [--env prod|dev|staging|both|all]
Env:
  STRICT=1                  Enforce strict validation mode
  CHECK_TIMEOUT_SECONDS=900 Per-check timeout in seconds
  ARTIFACT_DIR=var/...      Directory for per-check logs
  ALLOW_SHARED_HOSTS=...    Comma-separated temporary host allowlist for tenant safety audit
  ALLOW_SHARED_HOSTS_FILE=... Optional newline allowlist file for temporary shared hosts
  PROD_CONTEXT=...          Optional kubectl context override for prod checks
  DEV_CONTEXT=...           Optional kubectl context override for dev checks
  STAGING_CONTEXT=...       Optional kubectl context override for staging checks
  PROD_NAMESPACE=...        Optional namespace override for prod checks (default: mereka-lms)
  DEV_NAMESPACE=...         Optional namespace override for dev checks (default: mereka-lms)
  STAGING_NAMESPACE=...     Optional namespace override for staging checks (default: stg-mereka-lms)
  PROD_ALLOW_CREDENTIALS_500=0|1   Optional auth-surface tolerance for prod credentials /login
  DEV_ALLOW_CREDENTIALS_500=0|1    Optional auth-surface tolerance for dev credentials /login
  STAGING_ALLOW_CREDENTIALS_500=0|1 Optional auth-surface tolerance for staging credentials /login
  PROD_NOTES_BANNER_NEEDLE=...     Optional expected notes root banner text for prod
  DEV_NOTES_BANNER_NEEDLE=...      Optional expected notes root banner text for dev
  STAGING_NOTES_BANNER_NEEDLE=...  Optional expected notes root banner text for staging
  PROD_ALLOW_FORUM_HEARTBEAT_404=0|1 Optional auth-surface tolerance for prod forum heartbeat
  DEV_ALLOW_FORUM_HEARTBEAT_404=0|1  Optional auth-surface tolerance for dev forum heartbeat
  STAGING_ALLOW_FORUM_HEARTBEAT_404=0|1 Optional auth-surface tolerance for staging forum heartbeat
  ALLOW_PROD_AUTH_SURFACE_TOLERANCES=1 Required to permit any prod auth-surface relaxations
  CLUSTER_CHECK_TIMEOUT=20          Seconds to wait for cluster reachability probe (default: 20)
  DEV_SKIP_OIDC_ON_NON_REDIRECT=1   Skip dev OIDC checks when endpoint returns non-302 (default: 1)
EOF
}

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

while [[ $# -gt 0 ]]; do
  case "$1" in
    --env)
      ENV_SCOPE="${2:-}"; shift 2 ;;
    -h|--help)
      usage; exit 0 ;;
    *)
      echo "Unknown arg: $1" >&2
      usage
      exit 1 ;;
  esac
done

if [[ "$ENV_SCOPE" != "prod" && "$ENV_SCOPE" != "dev" && "$ENV_SCOPE" != "staging" && "$ENV_SCOPE" != "both" && "$ENV_SCOPE" != "all" ]]; then
  echo "Invalid --env: $ENV_SCOPE" >&2
  usage
  exit 1
fi

require_bool_01 "PROD_ALLOW_CREDENTIALS_500" "$PROD_ALLOW_CREDENTIALS_500"
require_bool_01 "DEV_ALLOW_CREDENTIALS_500" "$DEV_ALLOW_CREDENTIALS_500"
require_bool_01 "STAGING_ALLOW_CREDENTIALS_500" "$STAGING_ALLOW_CREDENTIALS_500"
require_bool_01 "PROD_ALLOW_FORUM_HEARTBEAT_404" "$PROD_ALLOW_FORUM_HEARTBEAT_404"
require_bool_01 "DEV_ALLOW_FORUM_HEARTBEAT_404" "$DEV_ALLOW_FORUM_HEARTBEAT_404"
require_bool_01 "STAGING_ALLOW_FORUM_HEARTBEAT_404" "$STAGING_ALLOW_FORUM_HEARTBEAT_404"
require_bool_01 "ALLOW_PROD_AUTH_SURFACE_TOLERANCES" "$ALLOW_PROD_AUTH_SURFACE_TOLERANCES"
require_bool_01 "STRICT" "$STRICT"
require_bool_01 "SKIP_DEV_ON_BOTH" "$SKIP_DEV_ON_BOTH"

if [[ "$ENV_SCOPE" == "prod" || "$ENV_SCOPE" == "both" ]]; then
  if [[ "$PROD_ALLOW_CREDENTIALS_500" == "1" || "$PROD_ALLOW_FORUM_HEARTBEAT_404" == "1" || "$PROD_NOTES_BANNER_NEEDLE" != "edX Notes API" ]]; then
    if [[ "$ALLOW_PROD_AUTH_SURFACE_TOLERANCES" != "1" ]]; then
      echo "Refusing prod auth-surface relaxation: set ALLOW_PROD_AUTH_SURFACE_TOLERANCES=1 to proceed." >&2
      exit 1
    fi
  fi
fi

failures=0

run_check() {
  local name="$1"; shift
  local out_file rc out slug timed_out
  slug="$(echo "$name" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//')"
  out_file="${ARTIFACT_DIR}/${slug}.log"
  timed_out=0

  set +e
  if command -v timeout >/dev/null 2>&1; then
    timeout "${CHECK_TIMEOUT_SECONDS}s" "$@" >"$out_file" 2>&1
  else
    "$@" >"$out_file" 2>&1
  fi
  rc=$?
  set -e
  out="$(cat "$out_file")"

  if [[ "$rc" -eq 124 ]]; then
    timed_out=1
  fi

  if [[ "$rc" -eq 0 ]]; then
    echo "OK   $name"
  else
    local is_dev_check=0
    if [[ "$name" == *"(dev)"* ]] && [[ "$ENV_SCOPE" == "both" ]] && [[ "$SKIP_DEV_ON_BOTH" == "1" ]]; then
      is_dev_check=1
    fi

    if [[ "$is_dev_check" -eq 1 ]]; then
      echo "WARN  $name (skipped in --env both scope with SKIP_DEV_ON_BOTH=1)"
    else
      failures=$((failures + 1))
    fi

    if [[ "$timed_out" -eq 1 ]]; then
      [[ "$is_dev_check" -eq 1 ]] && echo "  skip reason: timed out after ${CHECK_TIMEOUT_SECONDS}s" || echo "FAIL $name (timed out after ${CHECK_TIMEOUT_SECONDS}s)"
    else
      [[ "$is_dev_check" -eq 1 ]] && echo "  skip reason:" || echo "FAIL $name"
    fi
    if [[ -n "$out" ]]; then
      echo "$out" | sed 's/^/  /'
    fi
    echo "  log: $out_file"
  fi
}

echo "Multisite governance gates"
echo "  env: $ENV_SCOPE"
echo "  strict: $STRICT"
echo "  check_timeout_seconds: $CHECK_TIMEOUT_SECONDS"
echo "  skip_dev_on_both: $SKIP_DEV_ON_BOTH"
echo "  prod_context: ${PROD_CONTEXT:-default}"
echo "  dev_context: ${DEV_CONTEXT:-default}"
echo "  staging_context: ${STAGING_CONTEXT:-default}"
echo "  prod_namespace: ${PROD_NAMESPACE:-mereka-lms}"
echo "  dev_namespace: ${DEV_NAMESPACE:-mereka-lms}"
echo "  staging_namespace: ${STAGING_NAMESPACE:-stg-mereka-lms}"
echo "  allow_shared_hosts: ${ALLOW_SHARED_HOSTS:-}"
echo "  allow_shared_hosts_file: ${ALLOW_SHARED_HOSTS_FILE:-}"
echo "  prod_allow_credentials_500: ${PROD_ALLOW_CREDENTIALS_500}"
echo "  dev_allow_credentials_500: ${DEV_ALLOW_CREDENTIALS_500}"
echo "  staging_allow_credentials_500: ${STAGING_ALLOW_CREDENTIALS_500}"
echo "  prod_notes_banner_needle: ${PROD_NOTES_BANNER_NEEDLE}"
echo "  dev_notes_banner_needle: ${DEV_NOTES_BANNER_NEEDLE}"
echo "  staging_notes_banner_needle: ${STAGING_NOTES_BANNER_NEEDLE}"
echo "  prod_allow_forum_heartbeat_404: ${PROD_ALLOW_FORUM_HEARTBEAT_404}"
echo "  dev_allow_forum_heartbeat_404: ${DEV_ALLOW_FORUM_HEARTBEAT_404}"
echo "  staging_allow_forum_heartbeat_404: ${STAGING_ALLOW_FORUM_HEARTBEAT_404}"
echo "  allow_prod_auth_surface_tolerances: ${ALLOW_PROD_AUTH_SURFACE_TOLERANCES}"
echo "  artifact_dir: $ARTIFACT_DIR"
echo ""

if [[ -n "${ALLOW_SHARED_HOSTS_FILE:-}" && ! -f "${ALLOW_SHARED_HOSTS_FILE}" ]]; then
  echo "FAIL tenant allowlist file missing: ${ALLOW_SHARED_HOSTS_FILE}"
  failures=$((failures + 1))
fi

run_check "tenant config safety audit (repo)" \
  env STRICT="$STRICT" ALLOW_SHARED_HOSTS="${ALLOW_SHARED_HOSTS:-}" ALLOW_SHARED_HOSTS_FILE="${ALLOW_SHARED_HOSTS_FILE:-}" \
    ./scripts/qa/audit-tenant-config-safety.sh

run_check "tenant override schema (repo)" \
  env STRICT="$STRICT" ./scripts/qa/verify-tenant-override-schema.sh

if [[ "$ENV_SCOPE" == "prod" || "$ENV_SCOPE" == "both" || "$ENV_SCOPE" == "all" ]]; then
  prod_args=()
  [[ -n "${PROD_CONTEXT:-}" ]] && prod_args+=(--context "$PROD_CONTEXT")
  [[ -n "${PROD_NAMESPACE:-}" ]] && prod_args+=(--namespace "$PROD_NAMESPACE")
  run_check "multisite config (prod)" \
    env STRICT="$STRICT" ./scripts/qa/verify-multisite-config.sh prod "${prod_args[@]}"
  run_check "org role ownership (prod)" \
    env STRICT="$STRICT" ./scripts/qa/verify-org-role-ownership.sh prod "${prod_args[@]}"
  run_check "auth surfaces (prod)" \
    env \
      ALLOW_CREDENTIALS_500="$PROD_ALLOW_CREDENTIALS_500" \
      NOTES_BANNER_NEEDLE="$PROD_NOTES_BANNER_NEEDLE" \
      ALLOW_FORUM_HEARTBEAT_404="$PROD_ALLOW_FORUM_HEARTBEAT_404" \
      ./scripts/qa/verify-auth-surfaces.sh prod
fi

if [[ "$ENV_SCOPE" == "dev" || "$ENV_SCOPE" == "both" || "$ENV_SCOPE" == "all" ]]; then
  dev_args=()
  [[ -n "${DEV_CONTEXT:-}" ]] && dev_args+=(--context "$DEV_CONTEXT")
  [[ -n "${DEV_NAMESPACE:-}" ]] && dev_args+=(--namespace "$DEV_NAMESPACE")
  run_check "multisite config (dev)" \
    env STRICT="$STRICT" CLUSTER_CHECK_TIMEOUT="$CLUSTER_CHECK_TIMEOUT" \
      ./scripts/qa/verify-multisite-config.sh dev "${dev_args[@]}"
  run_check "org role ownership (dev)" \
    env STRICT="$STRICT" CLUSTER_CHECK_TIMEOUT="$CLUSTER_CHECK_TIMEOUT" \
      ./scripts/qa/verify-org-role-ownership.sh dev "${dev_args[@]}"
  run_check "auth surfaces (dev)" \
    env \
      ALLOW_CREDENTIALS_500="$DEV_ALLOW_CREDENTIALS_500" \
      NOTES_BANNER_NEEDLE="$DEV_NOTES_BANNER_NEEDLE" \
      ALLOW_FORUM_HEARTBEAT_404="$DEV_ALLOW_FORUM_HEARTBEAT_404" \
      DEV_SKIP_OIDC_ON_NON_REDIRECT="$DEV_SKIP_OIDC_ON_NON_REDIRECT" \
      ./scripts/qa/verify-auth-surfaces.sh dev
fi

if [[ "$ENV_SCOPE" == "staging" || "$ENV_SCOPE" == "all" ]]; then
  staging_args=()
  [[ -n "${STAGING_CONTEXT:-}" ]] && staging_args+=(--context "$STAGING_CONTEXT")
  [[ -n "${STAGING_NAMESPACE:-}" ]] && staging_args+=(--namespace "$STAGING_NAMESPACE")
  run_check "multisite config (staging)" \
    env STRICT="$STRICT" CLUSTER_CHECK_TIMEOUT="$CLUSTER_CHECK_TIMEOUT" \
      ./scripts/qa/verify-multisite-config.sh staging "${staging_args[@]}"
  run_check "org role ownership (staging)" \
    env STRICT="$STRICT" CLUSTER_CHECK_TIMEOUT="$CLUSTER_CHECK_TIMEOUT" \
      ./scripts/qa/verify-org-role-ownership.sh staging "${staging_args[@]}"
  run_check "auth surfaces (staging)" \
    env \
      ALLOW_CREDENTIALS_500="$STAGING_ALLOW_CREDENTIALS_500" \
      NOTES_BANNER_NEEDLE="$STAGING_NOTES_BANNER_NEEDLE" \
      ALLOW_FORUM_HEARTBEAT_404="$STAGING_ALLOW_FORUM_HEARTBEAT_404" \
      ./scripts/qa/verify-auth-surfaces.sh staging
fi

if [[ "$ENV_SCOPE" == "prod" || "$ENV_SCOPE" == "both" || "$ENV_SCOPE" == "all" ]]; then
  run_check "hostname registry drift (prod)" \
    env \
      STRICT="$STRICT" \
      NAMESPACE="$PROD_NAMESPACE" \
      CONTEXT_PROD="$PROD_CONTEXT" \
      ./scripts/qa/list-openedx-hostnames.sh --env prod
fi

if [[ "$ENV_SCOPE" == "dev" || "$ENV_SCOPE" == "both" || "$ENV_SCOPE" == "all" ]]; then
  run_check "hostname registry drift (dev)" \
    env \
      STRICT="$STRICT" \
      NAMESPACE="$DEV_NAMESPACE" \
      CONTEXT_DEV="$DEV_CONTEXT" \
      ./scripts/qa/list-openedx-hostnames.sh --env dev
fi

if [[ "$ENV_SCOPE" == "staging" || "$ENV_SCOPE" == "all" ]]; then
  run_check "hostname registry drift (staging)" \
    env \
      STRICT="$STRICT" \
      NAMESPACE="$STAGING_NAMESPACE" \
      CONTEXT_STAGING="$STAGING_CONTEXT" \
      ./scripts/qa/list-openedx-hostnames.sh --env staging
fi

# AC-TBR-104: Runtime tenant branding verification
# This check requires live endpoints and is expected to SKIP when
# ENABLE_MULTI_TENANT_BRANDING=False. Only fails if actual runtime
# errors are detected (not just unavailability).
if [[ "$ENV_SCOPE" == "both" ]]; then
  run_check "tenant branding runtime (prod)" \
    ./scripts/qa/verify-tenant-branding-runtime.sh --env prod
  run_check "tenant branding runtime (dev/local)" \
    ./scripts/qa/verify-tenant-branding-runtime.sh --env local
else
  runtime_env="$ENV_SCOPE"
  runtime_label="$ENV_SCOPE"
  if [[ "$ENV_SCOPE" == "dev" ]]; then
    runtime_env="local"
    runtime_label="dev/local"
  fi
  run_check "tenant branding runtime ($runtime_label)" \
    ./scripts/qa/verify-tenant-branding-runtime.sh --env "$runtime_env"
fi

echo ""
if [[ "$failures" -eq 0 ]]; then
  echo "OK"
else
  echo "FAILED ($failures checks failed)"
fi
echo "Logs: $ARTIFACT_DIR"

[[ "$failures" -eq 0 ]]
