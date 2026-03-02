#!/usr/bin/env bash
# @covers AC-009
# @spec: disaster-recovery-business-continuity_spec.md
# Collect Velero backup posture evidence into var/ for audits/incidents.
#
# This is read-only. It writes artifacts under var/ (gitignored).
#
# Usage:
#   ./scripts/qa/collect-velero-evidence.sh
#   ./scripts/qa/collect-velero-evidence.sh --context gke_bbi-k8_asia-southeast1-c_bbi-k8-cluster
#   OUT_DIR=var/velero-evidence/custom ./scripts/qa/collect-velero-evidence.sh
#
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

K8S_CONTEXT="${K8S_CONTEXT:-${K8S_CONTEXT_PROD:-gke_bbi-k8_asia-southeast1-c_bbi-k8-cluster}}"
VELERO_NS="${VELERO_NS:-velero}"
SCHEDULE_NAME="${SCHEDULE_NAME:-velero-local-hourly-critical-databases}"

STAMP="$(date -u +%Y%m%d-%H%M%S)"
OUT_DIR="${OUT_DIR:-var/velero-evidence/${STAMP}}"

mkdir -p "$OUT_DIR"

log() { echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] $*"; }

dump() {
  local path="$1"; shift
  kubectl --context "$K8S_CONTEXT" "$@" >"$OUT_DIR/$path" 2>"$OUT_DIR/$path.err" || true
}

log "Collecting Velero evidence -> $OUT_DIR"
log "Context=$K8S_CONTEXT velero_ns=$VELERO_NS schedule=$SCHEDULE_NAME"

dump "bsl.json" -n "$VELERO_NS" get backupstoragelocation.velero.io -o json
dump "vsl.json" -n "$VELERO_NS" get volumesnapshotlocation.velero.io -o json
dump "schedules.json" -n "$VELERO_NS" get schedule.velero.io -o json
dump "backups.json" -n "$VELERO_NS" get backup.velero.io -o json
dump "restores.json" -n "$VELERO_NS" get restore.velero.io -o json
dump "cronjobs.json" -n "$VELERO_NS" get cronjob.batch -o json
dump "jobs.json" -n "$VELERO_NS" get job.batch -o json
dump "events.txt" -n "$VELERO_NS" get events --sort-by=.lastTimestamp

# PVC inventory for critical schedule.
./scripts/qa/list-critical-backup-pvcs.sh --context "$K8S_CONTEXT" --velero-namespace "$VELERO_NS" --schedule "$SCHEDULE_NAME" \
  >"$OUT_DIR/critical-pvcs.tsv" 2>"$OUT_DIR/critical-pvcs.tsv.err" || true

./scripts/qa/audit-velero.sh --context "$K8S_CONTEXT" --velero-namespace "$VELERO_NS" --app-namespace mereka-lms --json \
  >"$OUT_DIR/audit-velero.json" 2>"$OUT_DIR/audit-velero.json.err" || true

log "Done"
log "Top-level files:"
ls -1 "$OUT_DIR" | sed 's/^/  - /'
