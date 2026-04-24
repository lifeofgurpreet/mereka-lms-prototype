#!/usr/bin/env bash
# @covers AC-007
# @spec: mongodb-atlas-integration_spec.md
# Safely retire the legacy in-cluster mongodb deployment after Atlas cutover verification.
#
# Safety model:
# - Non-destructive by default (verification + plan output only)
# - Optional Velero pre-op backup before any destructive action
# - Explicit confirmation token required for destructive delete
#
# Usage:
#   ./scripts/infra/retire-legacy-mongodb.sh
#   RUN_DESTRUCTIVE=1 CONFIRM_RETIRE_LEGACY_MONGODB=YES_DELETE_LEGACY_MONGODB ./scripts/infra/retire-legacy-mongodb.sh
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

K8S_CONTEXT="${K8S_CONTEXT:-rke2-prod}"
APP_NS="${APP_NS:-mereka-lms}"
LEGACY_DEPLOYMENT_NAME="${LEGACY_DEPLOYMENT_NAME:-mongodb}"
LEGACY_SERVICE_NAME="${LEGACY_SERVICE_NAME:-mongodb}"
RUN_DESTRUCTIVE="${RUN_DESTRUCTIVE:-0}"
CREATE_PREOP_BACKUP="${CREATE_PREOP_BACKUP:-1}"
DELETE_LEGACY_SERVICE="${DELETE_LEGACY_SERVICE:-0}"
CONFIRM_RETIRE_LEGACY_MONGODB="${CONFIRM_RETIRE_LEGACY_MONGODB:-}"
CONFIRM_TOKEN="YES_DELETE_LEGACY_MONGODB"

log() { echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] $*"; }

usage() {
  cat <<'USAGE'
Usage: ./scripts/infra/retire-legacy-mongodb.sh [--help]
Env:
  RUN_DESTRUCTIVE=1                      Execute legacy deployment deletion
  CREATE_PREOP_BACKUP=1                  Create Velero pre-op backup before delete
  DELETE_LEGACY_SERVICE=1                Also delete legacy mongodb Service (optional)
  CONFIRM_RETIRE_LEGACY_MONGODB=<token>  Must equal YES_DELETE_LEGACY_MONGODB
  K8S_CONTEXT=...                         Kubernetes context (default prod)
  APP_NS=mereka-lms                       Application namespace
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

require_cmd kubectl
require_cmd python3

log "Verifying Atlas modulestore runtime contract"
STRICT_RUNTIME=1 FAIL_ON_LEGACY_MONGODB=0 K8S_CONTEXT="$K8S_CONTEXT" APP_NS="$APP_NS" \
  ./scripts/qa/verify-atlas-modulestore-path.sh --mode runtime

if ! kubectl --context "$K8S_CONTEXT" -n "$APP_NS" get deploy "$LEGACY_DEPLOYMENT_NAME" >/dev/null 2>&1; then
  log "Legacy deployment ${APP_NS}/${LEGACY_DEPLOYMENT_NAME} is already absent"
  if kubectl --context "$K8S_CONTEXT" -n "$APP_NS" get svc "$LEGACY_SERVICE_NAME" >/dev/null 2>&1; then
    log "Legacy service ${APP_NS}/${LEGACY_SERVICE_NAME} still exists (expected to be removed by production overlay GitOps patch)"
  fi
  exit 0
fi

if [[ "$RUN_DESTRUCTIVE" != "1" ]]; then
  log "Dry-run mode (RUN_DESTRUCTIVE=0): no cluster resources changed"
  cat <<PLAN

Next step (destructive) requires explicit token and pre-op backup:
  RUN_DESTRUCTIVE=1 \\
  CONFIRM_RETIRE_LEGACY_MONGODB=$CONFIRM_TOKEN \\
  ./scripts/infra/retire-legacy-mongodb.sh
PLAN
  exit 0
fi

if [[ "$CONFIRM_RETIRE_LEGACY_MONGODB" != "$CONFIRM_TOKEN" ]]; then
  echo "Refusing destructive action: set CONFIRM_RETIRE_LEGACY_MONGODB=$CONFIRM_TOKEN" >&2
  exit 1
fi

if [[ "$CREATE_PREOP_BACKUP" == "1" ]]; then
  require_cmd velero
  backup_name="pre-op-${APP_NS}-$(date -u +%Y%m%d-%H%M)"
  log "Creating Velero pre-op backup: $backup_name"
  velero backup create "$backup_name" --include-namespaces "$APP_NS" --wait
fi

log "Deleting legacy deployment ${APP_NS}/${LEGACY_DEPLOYMENT_NAME}"
kubectl --context "$K8S_CONTEXT" -n "$APP_NS" delete deploy "$LEGACY_DEPLOYMENT_NAME"

if kubectl --context "$K8S_CONTEXT" -n "$APP_NS" get deploy "$LEGACY_DEPLOYMENT_NAME" >/dev/null 2>&1; then
  echo "Delete command completed but deployment still exists: ${APP_NS}/${LEGACY_DEPLOYMENT_NAME}" >&2
  exit 1
fi

log "Legacy deployment retired"

if [[ "$DELETE_LEGACY_SERVICE" == "1" ]] && kubectl --context "$K8S_CONTEXT" -n "$APP_NS" get svc "$LEGACY_SERVICE_NAME" >/dev/null 2>&1; then
  log "Deleting legacy service ${APP_NS}/${LEGACY_SERVICE_NAME}"
  kubectl --context "$K8S_CONTEXT" -n "$APP_NS" delete svc "$LEGACY_SERVICE_NAME"
  log "Legacy service deleted"
fi
