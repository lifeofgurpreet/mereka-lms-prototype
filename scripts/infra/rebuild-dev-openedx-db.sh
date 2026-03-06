#!/usr/bin/env bash
# Canonical guarded dev Open edX database rebuild flow for Kubernetes/Tutor deployments.
#
# Safety model:
# - Dry-run by default (no cluster mutations)
# - Velero pre-op backup before destructive actions
# - Explicit confirmation token required for destructive mode
# - Refuses production-like contexts unless explicitly overridden
#
# Usage:
#   ./scripts/infra/rebuild-dev-openedx-db.sh
#   RUN_DESTRUCTIVE=1 CONFIRM_REBUILD_DEV_DB=REBUILD_DEV_DB ./scripts/infra/rebuild-dev-openedx-db.sh

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

K8S_CONTEXT="${K8S_CONTEXT:-rke2-nonprod}"
APP_NS="${APP_NS:-mereka-lms}"
MYSQL_DEPLOYMENT="${MYSQL_DEPLOYMENT:-mysql}"
ROLLOUT_TIMEOUT="${ROLLOUT_TIMEOUT:-900s}"
RUN_DESTRUCTIVE="${RUN_DESTRUCTIVE:-0}"
CREATE_PREOP_BACKUP="${CREATE_PREOP_BACKUP:-1}"
ALLOW_PROD_CONTEXT="${ALLOW_PROD_CONTEXT:-0}"
CONFIRM_REBUILD_DEV_DB="${CONFIRM_REBUILD_DEV_DB:-}"
CONFIRM_TOKEN="REBUILD_DEV_DB"

RESTART_DEPLOYMENTS=(
  lms
  cms
  lms-worker
  cms-worker
  discovery
  credentials
  enterprise-catalog
  enterprise-access
  enterprise-subsidy
  license-manager
)

log() {
  echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] $*"
}

usage() {
  cat <<'USAGE'
Usage: ./scripts/infra/rebuild-dev-openedx-db.sh [--help]

Env:
  K8S_CONTEXT=rke2-nonprod                 Kubernetes context to target
  APP_NS=mereka-lms                        Application namespace
  MYSQL_DEPLOYMENT=mysql                   MySQL deployment name
  ROLLOUT_TIMEOUT=900s                     Rollout timeout for restart verification
  RUN_DESTRUCTIVE=0|1                      0=dry-run (default), 1=execute destructive actions
  CREATE_PREOP_BACKUP=0|1                  Create Velero pre-op backup (default: 1)
  CONFIRM_REBUILD_DEV_DB=<token>           Must equal REBUILD_DEV_DB in destructive mode
  ALLOW_PROD_CONTEXT=0|1                   Set to 1 to bypass prod-context guard (default: 0)

Examples:
  ./scripts/infra/rebuild-dev-openedx-db.sh
  RUN_DESTRUCTIVE=1 CONFIRM_REBUILD_DEV_DB=REBUILD_DEV_DB \
    ./scripts/infra/rebuild-dev-openedx-db.sh
USAGE
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

require_cmd() {
  local cmd="$1"
  command -v "$cmd" >/dev/null 2>&1 || {
    echo "Missing command: $cmd" >&2
    exit 1
  }
}

require_bool() {
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

is_prod_like_context() {
  local ctx="$1"
  [[ "$ctx" == *"gke_bbi-k8"* ]] || [[ "$ctx" == "prod" ]] || [[ "$ctx" == "production" ]] || [[ "$ctx" == "gke-prod" ]]
}

collect_mysql_pvcs() {
  kubectl --context "$K8S_CONTEXT" -n "$APP_NS" get pvc -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' \
    | awk '/mysql/{print $1}'
}

deployment_exists() {
  local dep="$1"
  kubectl --context "$K8S_CONTEXT" -n "$APP_NS" get deploy "$dep" >/dev/null 2>&1
}

require_cmd kubectl
require_cmd awk
require_bool "RUN_DESTRUCTIVE" "$RUN_DESTRUCTIVE"
require_bool "CREATE_PREOP_BACKUP" "$CREATE_PREOP_BACKUP"
require_bool "ALLOW_PROD_CONTEXT" "$ALLOW_PROD_CONTEXT"

if is_prod_like_context "$K8S_CONTEXT" && [[ "$ALLOW_PROD_CONTEXT" != "1" ]]; then
  echo "Refusing to run on production-like context '$K8S_CONTEXT'." >&2
  echo "If this is intentional, set ALLOW_PROD_CONTEXT=1 explicitly." >&2
  exit 1
fi

if ! kubectl --context "$K8S_CONTEXT" get ns "$APP_NS" >/dev/null 2>&1; then
  echo "Namespace not found: ${APP_NS} (context: ${K8S_CONTEXT})" >&2
  exit 1
fi

if [[ "$RUN_DESTRUCTIVE" == "1" && "$CONFIRM_REBUILD_DEV_DB" != "$CONFIRM_TOKEN" ]]; then
  echo "Refusing destructive run: set CONFIRM_REBUILD_DEV_DB=${CONFIRM_TOKEN}" >&2
  exit 1
fi

mapfile -t MYSQL_PVCS < <(collect_mysql_pvcs)
if [[ "${#MYSQL_PVCS[@]}" -eq 0 ]]; then
  echo "No MySQL PVCs found in ${APP_NS}; expected at least one PVC containing 'mysql'." >&2
  exit 1
fi

log "Context=${K8S_CONTEXT} namespace=${APP_NS} deployment=${MYSQL_DEPLOYMENT}"
log "MySQL PVC candidates: ${MYSQL_PVCS[*]}"

if [[ "$RUN_DESTRUCTIVE" != "1" ]]; then
  cat <<PLAN

Dry-run only. No cluster mutations were performed.

Destructive run (guarded):
  RUN_DESTRUCTIVE=1 \\
  CONFIRM_REBUILD_DEV_DB=${CONFIRM_TOKEN} \\
  ./scripts/infra/rebuild-dev-openedx-db.sh

What destructive mode will do:
  1) Create Velero pre-op backup (unless CREATE_PREOP_BACKUP=0)
  2) Scale MySQL deployment to 0
  3) Delete MySQL PVC(s): ${MYSQL_PVCS[*]}
  4) Scale MySQL deployment back to 1 and wait
  5) Restart Open edX service deployments so init/migration paths re-run
PLAN
  exit 0
fi

if [[ "$CREATE_PREOP_BACKUP" == "1" ]]; then
  require_cmd velero
  BACKUP_NAME="pre-op-${APP_NS}-dev-db-rebuild-$(date -u +%Y%m%d-%H%M)"
  log "Creating Velero pre-op backup: ${BACKUP_NAME}"
  velero backup create "$BACKUP_NAME" --include-namespaces "$APP_NS" --wait
else
  log "WARNING: CREATE_PREOP_BACKUP=0 (skipping Velero backup by explicit operator override)"
fi

if ! deployment_exists "$MYSQL_DEPLOYMENT"; then
  echo "MySQL deployment not found: deploy/${MYSQL_DEPLOYMENT} in ${APP_NS}" >&2
  exit 1
fi

log "Scaling ${MYSQL_DEPLOYMENT} to 0"
kubectl --context "$K8S_CONTEXT" -n "$APP_NS" scale deploy "$MYSQL_DEPLOYMENT" --replicas=0

log "Deleting MySQL PVC(s)"
for pvc in "${MYSQL_PVCS[@]}"; do
  kubectl --context "$K8S_CONTEXT" -n "$APP_NS" delete pvc "$pvc"
done

log "Scaling ${MYSQL_DEPLOYMENT} to 1"
kubectl --context "$K8S_CONTEXT" -n "$APP_NS" scale deploy "$MYSQL_DEPLOYMENT" --replicas=1
log "Waiting for MySQL rollout"
kubectl --context "$K8S_CONTEXT" -n "$APP_NS" rollout status deploy "$MYSQL_DEPLOYMENT" --timeout="$ROLLOUT_TIMEOUT"

log "Restarting Open edX service deployments to re-trigger canonical init/migrate paths"
for dep in "${RESTART_DEPLOYMENTS[@]}"; do
  if deployment_exists "$dep"; then
    kubectl --context "$K8S_CONTEXT" -n "$APP_NS" rollout restart deploy "$dep"
  else
    log "Skipping missing deployment: ${dep}"
  fi
done

log "Waiting for rollout completion of present deployments"
for dep in "${RESTART_DEPLOYMENTS[@]}"; do
  if deployment_exists "$dep"; then
    kubectl --context "$K8S_CONTEXT" -n "$APP_NS" rollout status deploy "$dep" --timeout="$ROLLOUT_TIMEOUT"
  fi
done

cat <<POST

Completed destructive dev DB rebuild flow.

Suggested post-checks:
  KUBE_CONTEXT=${K8S_CONTEXT} ./scripts/qa/verify-rke2-dev-readiness.sh --online
  kubectl --context ${K8S_CONTEXT} -n ${APP_NS} get pods
  kubectl --context ${K8S_CONTEXT} -n ${APP_NS} get jobs

If init/migrations fail after rebuild, restore from the pre-op backup created above.
See docs/operations/runbooks/DEV_DB_REBUILD_CANONICAL.md for rollback procedure.
POST
