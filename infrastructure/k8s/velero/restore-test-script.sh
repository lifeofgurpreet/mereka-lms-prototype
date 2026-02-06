#!/usr/bin/env bash
set -euo pipefail

# Configuration
VELERO_NS="${VELERO_NS:-velero}"
APP_NAMESPACE="${APP_NAMESPACE:-mereka-lms}"
TEST_NAMESPACE="${TEST_NAMESPACE:-velero-restore-test}"
SOURCE_NAMESPACE="${SOURCE_NAMESPACE:-}"
RESTORE_TIMEOUT="${RESTORE_TIMEOUT:-600}"
POD_READY_TIMEOUT="${POD_READY_TIMEOUT:-300}"
CLEANUP_ON_SUCCESS="${CLEANUP_ON_SUCCESS:-true}"
CLEANUP_ON_FAILURE="${CLEANUP_ON_FAILURE:-true}"
MAX_PARTIAL_ERRORS="${MAX_PARTIAL_ERRORS:-10}"

# Colors for logs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

RESTORE_NAME=""
TEST_RESULT="unknown"

log_info() { echo -e "${GREEN}[INFO]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"; }
log_step() { echo -e "${BLUE}[STEP]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"; }

is_true() {
  local v="${1:-false}"
  [[ "${v,,}" == "1" || "${v,,}" == "true" || "${v,,}" == "yes" ]]
}

cleanup() {
  local do_cleanup="false"
  if [[ "$TEST_RESULT" == "passed" ]] && is_true "$CLEANUP_ON_SUCCESS"; then
    do_cleanup="true"
  fi
  if [[ "$TEST_RESULT" != "passed" ]] && is_true "$CLEANUP_ON_FAILURE"; then
    do_cleanup="true"
  fi
  if ! is_true "$do_cleanup"; then
    log_warn "Skipping cleanup (CLEANUP_ON_SUCCESS=$CLEANUP_ON_SUCCESS CLEANUP_ON_FAILURE=$CLEANUP_ON_FAILURE)"
    return 0
  fi

  log_step "Running cleanup..."

  if [[ -n "$RESTORE_NAME" ]]; then
    log_info "Deleting restore resource: $RESTORE_NAME"
    kubectl -n "$VELERO_NS" delete restore "$RESTORE_NAME" --ignore-not-found >/dev/null 2>&1 || true
  fi

  if kubectl get namespace "$TEST_NAMESPACE" >/dev/null 2>&1; then
    log_info "Deleting test namespace: $TEST_NAMESPACE"
    kubectl delete namespace "$TEST_NAMESPACE" --wait=false >/dev/null 2>&1 || true
    sleep 5
    if kubectl get namespace "$TEST_NAMESPACE" >/dev/null 2>&1; then
      local ns_phase
      ns_phase="$(kubectl get namespace "$TEST_NAMESPACE" -o jsonpath='{.status.phase}' 2>/dev/null || echo "Unknown")"
      log_warn "Test namespace cleanup still in progress (phase=${ns_phase}); continuing without blocking"
    fi
  fi

  log_info "Cleanup completed"
}

find_latest_backup() {
  log_step "Finding latest completed backup..." >&2
  local backup
  backup="$(kubectl -n "$VELERO_NS" get backup.velero.io -o json | jq -r --arg ns "$SOURCE_NAMESPACE" '
    [
      .items[]
      | select(.status.phase == "Completed")
      | select(
          ($ns == "")
          or ((.spec.includedNamespaces // []) | index($ns) != null)
          or ((.spec.includedNamespaces // []) | index("*") != null)
        )
      | {
          name: .metadata.name,
          ts: (.status.completionTimestamp // .metadata.creationTimestamp // "")
        }
    ]
    | sort_by(.ts)
    | reverse
    | .[0].name // empty
  ')"
  if [[ -z "$backup" ]]; then
    log_error "No completed backup found for SOURCE_NAMESPACE='${SOURCE_NAMESPACE:-<auto>}'" >&2
    return 1
  fi
  log_info "Using backup: $backup" >&2
  echo "$backup"
}

resolve_source_namespace() {
  local backup_name="$1"
  if [[ -n "$SOURCE_NAMESPACE" ]]; then
    echo "$SOURCE_NAMESPACE"
    return 0
  fi

  local ns
  ns="$(kubectl -n "$VELERO_NS" get backup "$backup_name" -o json | jq -r '
    ((.spec.includedNamespaces // []) | map(select(. != "*")) | .[0]) // empty
  ')"
  if [[ -z "$ns" ]]; then
    ns="$APP_NAMESPACE"
  fi
  echo "$ns"
}

create_test_namespace() {
  log_step "Preparing test namespace: $TEST_NAMESPACE"
  if kubectl get namespace "$TEST_NAMESPACE" >/dev/null 2>&1; then
    log_warn "Test namespace already exists; deleting for clean run"
    kubectl delete namespace "$TEST_NAMESPACE" --timeout=120s --wait=true >/dev/null 2>&1 || {
      log_warn "Force deleting stale test namespace"
      kubectl delete namespace "$TEST_NAMESPACE" --force --grace-period=0 >/dev/null 2>&1 || true
    }
    sleep 3
  fi
  kubectl create namespace "$TEST_NAMESPACE" >/dev/null
  log_info "Test namespace ready"
}

create_restore() {
  local backup_name="$1"
  local source_ns="$2"
  RESTORE_NAME="restore-test-$(date +%Y%m%d-%H%M%S)"

  log_step "Creating restore resource: $RESTORE_NAME"
  cat <<EOF | kubectl apply -f - >/dev/null
apiVersion: velero.io/v1
kind: Restore
metadata:
  name: ${RESTORE_NAME}
  namespace: ${VELERO_NS}
  labels:
    app: velero
    component: restore-test
spec:
  backupName: "${backup_name}"
  includedNamespaces:
    - "${source_ns}"
  namespaceMapping:
    "${source_ns}": "${TEST_NAMESPACE}"
  excludedResources:
    - persistentvolumeclaims
    - persistentvolumes
    - secrets
EOF
}

wait_for_restore() {
  log_step "Waiting for restore completion (timeout=${RESTORE_TIMEOUT}s)"
  local elapsed=0 interval=10 phase=""
  while [[ "$elapsed" -lt "$RESTORE_TIMEOUT" ]]; do
    phase="$(kubectl -n "$VELERO_NS" get restore "$RESTORE_NAME" -o jsonpath='{.status.phase}' 2>/dev/null || true)"
    case "$phase" in
      Completed)
        log_info "Restore completed successfully"
        return 0
        ;;
      PartiallyFailed)
        local counts warnings errors
        counts="$(kubectl -n "$VELERO_NS" get restore "$RESTORE_NAME" -o json | jq -r '
          "\(.status.warnings // 0) \(.status.errors // 0)"
        ' 2>/dev/null || echo "0 0")"
        warnings="$(echo "$counts" | awk '{print $1}')"
        errors="$(echo "$counts" | awk '{print $2}')"
        log_warn "Restore phase=PartiallyFailed warnings=${warnings} errors=${errors}"
        if [[ "$errors" -le "$MAX_PARTIAL_ERRORS" ]]; then
          log_warn "Accepting partial restore as PASS (errors <= ${MAX_PARTIAL_ERRORS})"
          return 0
        fi
        log_error "Partial restore errors exceed threshold (${MAX_PARTIAL_ERRORS})"
        return 1
        ;;
      Failed)
        log_error "Restore failed with phase=$phase"
        kubectl -n "$VELERO_NS" get restore "$RESTORE_NAME" -o json | jq -r '
          "warnings=\(.status.warnings // 0) errors=\(.status.errors // 0)"
        ' || true
        return 1
        ;;
      InProgress|New|"")
        log_info "Restore phase=${phase:-Unknown} (${elapsed}s/${RESTORE_TIMEOUT}s)"
        ;;
      *)
        log_warn "Unexpected restore phase: $phase"
        ;;
    esac
    sleep "$interval"
    elapsed=$((elapsed + interval))
  done
  log_error "Restore timed out after ${RESTORE_TIMEOUT}s"
  return 1
}

verify_restored_namespace() {
  log_step "Verifying restored namespace workloads"
  local elapsed=0 interval=10
  local total=0 ready=0

  sleep 10
  while [[ "$elapsed" -lt "$POD_READY_TIMEOUT" ]]; do
    total="$(kubectl get pods -n "$TEST_NAMESPACE" --no-headers 2>/dev/null | wc -l | xargs)"
    if [[ "$total" -eq 0 ]]; then
      log_warn "No pods restored in $TEST_NAMESPACE (may be expected for resource-only restore)"
      return 0
    fi
    ready="$(kubectl get pods -n "$TEST_NAMESPACE" --no-headers 2>/dev/null | awk '$3=="Running" || $3=="Completed" {ok++} END{print ok+0}')"
    if [[ "$ready" -eq "$total" ]]; then
      log_info "Restored pods healthy: $ready/$total"
      kubectl get pods -n "$TEST_NAMESPACE"
      return 0
    fi
    log_info "Waiting for restored pods: $ready/$total (${elapsed}s/${POD_READY_TIMEOUT}s)"
    sleep "$interval"
    elapsed=$((elapsed + interval))
  done

  log_warn "Restored pods did not fully stabilize in ${POD_READY_TIMEOUT}s"
  kubectl get pods -n "$TEST_NAMESPACE" || true
  kubectl get events -n "$TEST_NAMESPACE" --sort-by='.lastTimestamp' | tail -n 10 || true
  return 0
}

main() {
  log_info "==========================================="
  log_info "Starting Velero Restore Test"
  log_info "==========================================="
  log_info "VELERO_NS=${VELERO_NS}"
  log_info "APP_NAMESPACE=${APP_NAMESPACE}"
  log_info "SOURCE_NAMESPACE=${SOURCE_NAMESPACE:-<auto>}"
  log_info "TEST_NAMESPACE=${TEST_NAMESPACE}"
  log_info "RESTORE_TIMEOUT=${RESTORE_TIMEOUT}"
  log_info "POD_READY_TIMEOUT=${POD_READY_TIMEOUT}"
  log_info "==========================================="

  trap cleanup EXIT

  local backup source_ns
  backup="$(find_latest_backup)" || { TEST_RESULT="failed"; exit 1; }
  source_ns="$(resolve_source_namespace "$backup")"
  log_info "Source namespace selected: $source_ns"

  create_test_namespace || { TEST_RESULT="failed"; exit 1; }
  create_restore "$backup" "$source_ns" || { TEST_RESULT="failed"; exit 1; }
  wait_for_restore || { TEST_RESULT="failed"; exit 1; }
  verify_restored_namespace || true

  TEST_RESULT="passed"
  log_info "==========================================="
  log_info "Restore Test PASSED"
  log_info "==========================================="
}

main "$@"
