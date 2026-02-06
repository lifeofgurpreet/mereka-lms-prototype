#!/usr/bin/env bash
set -euo pipefail

# Patch and verify velero/restore-test CronJob so monthly restore drills are reliable.
#
# What it changes:
# - ConfigMap/restore-test-script -> uses repo-managed script (kubectl+jq only).
# - CronJob/restore-test image -> bitnami/kubectl:latest (contains bash/jq/kubectl).
# - CronJob env -> SOURCE_NAMESPACE, APP_NAMESPACE, VELERO_NS for deterministic behavior.
#
# Usage:
#   ./scripts/infra/fix-velero-restore-test.sh
#   RUN_NOW=0 ./scripts/infra/fix-velero-restore-test.sh
#   K8S_CONTEXT=... ./scripts/infra/fix-velero-restore-test.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

K8S_CONTEXT="${K8S_CONTEXT:-gke_bbi-k8_asia-southeast1-c_bbi-k8-cluster}"
VELERO_NS="${VELERO_NS:-velero}"
APP_NAMESPACE="${APP_NAMESPACE:-mereka-lms}"
RUN_NOW="${RUN_NOW:-1}"
WAIT_TIMEOUT="${WAIT_TIMEOUT:-900s}"
LOG_DIR="${LOG_DIR:-${REPO_ROOT}/var}"
SCRIPT_SOURCE="${SCRIPT_SOURCE:-${REPO_ROOT}/infrastructure/k8s/velero/restore-test-script.sh}"

mkdir -p "$LOG_DIR"

log() { printf "[%s] %s\n" "$(date '+%Y-%m-%d %H:%M:%S')" "$*"; }

if [[ ! -f "$SCRIPT_SOURCE" ]]; then
  echo "restore-test source script not found: $SCRIPT_SOURCE" >&2
  exit 1
fi

if ! command -v kubectl >/dev/null 2>&1; then
  echo "kubectl not found" >&2
  exit 1
fi

kubectl --context "$K8S_CONTEXT" -n "$VELERO_NS" get cronjob restore-test >/dev/null
kubectl --context "$K8S_CONTEXT" -n "$VELERO_NS" get configmap restore-test-script >/dev/null

timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
backup_dir="${LOG_DIR}/velero-restore-test-fix-${timestamp}"
mkdir -p "$backup_dir"

log "Saving pre-change manifests to ${backup_dir}"
kubectl --context "$K8S_CONTEXT" -n "$VELERO_NS" get cronjob restore-test -o yaml >"${backup_dir}/cronjob-before.yaml"
kubectl --context "$K8S_CONTEXT" -n "$VELERO_NS" get configmap restore-test-script -o yaml >"${backup_dir}/configmap-before.yaml"

log "Updating ConfigMap restore-test-script from ${SCRIPT_SOURCE}"
kubectl --context "$K8S_CONTEXT" -n "$VELERO_NS" create configmap restore-test-script \
  --from-file=test-restore.sh="$SCRIPT_SOURCE" \
  --dry-run=client -o yaml \
  | kubectl --context "$K8S_CONTEXT" apply -f -

log "Patching CronJob restore-test image + command"
kubectl --context "$K8S_CONTEXT" -n "$VELERO_NS" patch cronjob restore-test --type='json' -p='[
  {
    "op":"replace",
    "path":"/spec/jobTemplate/spec/template/spec/containers/0/image",
    "value":"bitnami/kubectl:latest"
  },
  {
    "op":"replace",
    "path":"/spec/jobTemplate/spec/template/spec/containers/0/command",
    "value":["/bin/bash","/scripts/test-restore.sh"]
  }
]'

log "Setting deterministic env vars on CronJob restore-test"
kubectl --context "$K8S_CONTEXT" -n "$VELERO_NS" set env cronjob/restore-test \
  TEST_NAMESPACE=velero-restore-test \
  SOURCE_NAMESPACE="$APP_NAMESPACE" \
  APP_NAMESPACE="$APP_NAMESPACE" \
  VELERO_NS="$VELERO_NS" \
  RESTORE_TIMEOUT=600 \
  POD_READY_TIMEOUT=300 \
  MAX_PARTIAL_ERRORS=10 \
  CLEANUP_ON_SUCCESS=true \
  CLEANUP_ON_FAILURE=true \
  --containers=restore-test >/dev/null

log "Post-change sanity:"
kubectl --context "$K8S_CONTEXT" -n "$VELERO_NS" get cronjob restore-test -o json | jq -r '
  .spec.jobTemplate.spec.template.spec.containers[]
  | select(.name=="restore-test")
  | "image=\(.image) command=\(.command | join(" "))"
'

if [[ "$RUN_NOW" != "1" ]]; then
  log "RUN_NOW=${RUN_NOW}; skipping immediate restore drill run."
  exit 0
fi

manual_job="restore-test-manual-$(date +%Y%m%d%H%M%S)"
log "Creating manual verification Job: ${manual_job}"
kubectl --context "$K8S_CONTEXT" -n "$VELERO_NS" create job --from=cronjob/restore-test "$manual_job" >/dev/null

log "Waiting for ${manual_job} completion (timeout ${WAIT_TIMEOUT})"
if ! kubectl --context "$K8S_CONTEXT" -n "$VELERO_NS" wait --for=condition=complete "job/${manual_job}" --timeout="$WAIT_TIMEOUT"; then
  log "Manual restore drill failed or timed out. Collecting diagnostics."
  kubectl --context "$K8S_CONTEXT" -n "$VELERO_NS" describe "job/${manual_job}" >"${backup_dir}/manual-job-describe.txt" || true
  kubectl --context "$K8S_CONTEXT" -n "$VELERO_NS" logs "job/${manual_job}" --all-containers=true >"${backup_dir}/manual-job-logs.txt" || true
  echo "Restore drill verification failed. See ${backup_dir}" >&2
  exit 1
fi

kubectl --context "$K8S_CONTEXT" -n "$VELERO_NS" logs "job/${manual_job}" --all-containers=true >"${backup_dir}/manual-job-logs.txt" || true
kubectl --context "$K8S_CONTEXT" -n "$VELERO_NS" describe "job/${manual_job}" >"${backup_dir}/manual-job-describe.txt" || true

log "Manual restore drill succeeded."
log "Evidence saved under ${backup_dir}"
