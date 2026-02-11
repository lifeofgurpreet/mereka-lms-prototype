#!/usr/bin/env bash
# @covers AC-009
# @spec: disaster-recovery-business-continuity_spec.md
# Build a deterministic DR evidence bundle for audits/incidents.
#
# Usage:
#   ./scripts/qa/build-dr-evidence-bundle.sh
#   STRICT_RUNTIME=1 ./scripts/qa/build-dr-evidence-bundle.sh --tar
#   ./scripts/qa/build-dr-evidence-bundle.sh --out-dir var/dr-evidence/manual-run
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

K8S_CONTEXT="${K8S_CONTEXT:-gke_bbi-k8_asia-southeast1-c_bbi-k8-cluster}"
VELERO_NS="${VELERO_NS:-velero}"
STRICT_RUNTIME="${STRICT_RUNTIME:-1}"
TAR_OUTPUT=0
STAMP="$(date -u +%Y%m%d-%H%M%S)"
OUT_DIR="${OUT_DIR:-var/dr-evidence/${STAMP}}"

usage() {
  cat <<'USAGE'
Usage: ./scripts/qa/build-dr-evidence-bundle.sh [--out-dir PATH] [--tar]
Env:
  STRICT_RUNTIME=1  Fail if runtime checks are unavailable
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --out-dir) OUT_DIR="${2:-}"; shift 2 ;;
    --tar) TAR_OUTPUT=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *)
      echo "Unknown arg: $1" >&2
      usage
      exit 1
      ;;
  esac
done

mkdir -p "$OUT_DIR"

failures=0

run_check() {
  local name="$1"; shift
  local log_file="$OUT_DIR/${name// /-}.log"
  local rc

  set +e
  "$@" >"$log_file" 2>&1
  rc=$?
  set -e

  if [[ "$rc" -eq 0 ]]; then
    echo "OK   $name"
  else
    failures=$((failures + 1))
    echo "FAIL $name"
    tail -n 40 "$log_file" | sed 's/^/  /'
  fi
}

echo "Build: DR evidence bundle"
echo "  out_dir:        $OUT_DIR"
echo "  context:        $K8S_CONTEXT"
echo "  velero_ns:      $VELERO_NS"
echo "  strict_runtime: $STRICT_RUNTIME"
echo ""

run_check "audit-velero-json" \
  env STRICT_RUNTIME="$STRICT_RUNTIME" K8S_CONTEXT="$K8S_CONTEXT" VELERO_NS="$VELERO_NS" \
  ./scripts/qa/audit-velero.sh --context "$K8S_CONTEXT" --velero-namespace "$VELERO_NS" --app-namespace mereka-lms --json

run_check "audit-velero-alert-pipeline-json" \
  env STRICT_RUNTIME="$STRICT_RUNTIME" K8S_CONTEXT="$K8S_CONTEXT" VELERO_NS="$VELERO_NS" \
  ./scripts/qa/audit-velero-alert-pipeline.sh --json

run_check "audit-observability-runtime-json" \
  env STRICT_RUNTIME="$STRICT_RUNTIME" K8S_CONTEXT="$K8S_CONTEXT" VELERO_NS="$VELERO_NS" \
  ./scripts/qa/audit-observability.sh --mode runtime --json

run_check "collect-velero-evidence" \
  env K8S_CONTEXT="$K8S_CONTEXT" VELERO_NS="$VELERO_NS" OUT_DIR="$OUT_DIR/velero" \
  ./scripts/qa/collect-velero-evidence.sh

run_check "critical-backup-pvc-inventory" \
  env K8S_CONTEXT="$K8S_CONTEXT" VELERO_NS="$VELERO_NS" \
  ./scripts/qa/list-critical-backup-pvcs.sh --context "$K8S_CONTEXT" --velero-namespace "$VELERO_NS"

cat >"$OUT_DIR/manifest.txt" <<MANIFEST
generated_at_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)
git_commit=$(git rev-parse --short HEAD)
git_branch=$(git branch --show-current)
context=$K8S_CONTEXT
velero_namespace=$VELERO_NS
strict_runtime=$STRICT_RUNTIME
failures=$failures
MANIFEST

tarball=""
if [[ "$TAR_OUTPUT" -eq 1 ]]; then
  tarball="${OUT_DIR}.tar.gz"
  tar -czf "$tarball" -C "$(dirname "$OUT_DIR")" "$(basename "$OUT_DIR")"
fi

echo ""
if [[ "$failures" -eq 0 ]]; then
  echo "OK"
else
  echo "FAILED ($failures checks failed)"
fi

echo "Evidence directory: $OUT_DIR"
if [[ -n "$tarball" ]]; then
  echo "Evidence tarball:  $tarball"
fi

[[ "$failures" -eq 0 ]]
