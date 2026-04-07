#!/usr/bin/env bash
# @covers AC-015
# @spec: advanced-assessment-grading_spec.md
# Build a deterministic assessment evidence bundle for audits/incidents.
#
# Usage:
#   ./scripts/qa/build-assessment-evidence-bundle.sh
#   STRICT_RUNTIME=1 ./scripts/qa/build-assessment-evidence-bundle.sh --tar
#   ./scripts/qa/build-assessment-evidence-bundle.sh --out-dir var/assessment-evidence/manual-run
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

K8S_CONTEXT="${K8S_CONTEXT:-${K8S_CONTEXT_PROD:-rke2-prod}}"
STRICT_RUNTIME="${STRICT_RUNTIME:-1}"
TAR_OUTPUT=0
STAMP="$(date -u +%Y%m%d-%H%M%S)"
OUT_DIR="${OUT_DIR:-var/assessment-evidence/${STAMP}}"
SKIP_CLUSTER=""

usage() {
  cat <<'USAGE'
Usage: ./scripts/qa/build-assessment-evidence-bundle.sh [--out-dir PATH] [--tar] [--skip-cluster]
Env:
  STRICT_RUNTIME=1  Fail if runtime checks are unavailable
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --out-dir) OUT_DIR="${2:-}"; shift 2 ;;
    --tar) TAR_OUTPUT=1; shift ;;
    --skip-cluster) SKIP_CLUSTER="--skip-cluster"; shift ;;
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

echo "Build: Assessment evidence bundle"
echo "  out_dir:        $OUT_DIR"
echo "  context:        $K8S_CONTEXT"
echo "  strict_runtime: $STRICT_RUNTIME"
echo ""

run_check "verify-assessment-audit" \
  env STRICT_RUNTIME="$STRICT_RUNTIME" K8S_CONTEXT="$K8S_CONTEXT" \
  ./scripts/qa/verify-assessment-audit.sh

run_check "verify-assessment-bulk" \
  env STRICT_RUNTIME="$STRICT_RUNTIME" K8S_CONTEXT="$K8S_CONTEXT" \
  ./scripts/qa/verify-assessment-bulk.sh

run_check "verify-timed-exams" \
  env STRICT_RUNTIME="$STRICT_RUNTIME" K8S_CONTEXT="$K8S_CONTEXT" \
  ./scripts/qa/verify-timed-exams.sh

run_check "verify-advanced-xblocks" \
  env STRICT_RUNTIME="$STRICT_RUNTIME" K8S_CONTEXT="$K8S_CONTEXT" \
  ./scripts/qa/verify-advanced-xblocks.sh

run_check "verify-xqueue-graders" \
  env STRICT_RUNTIME="$STRICT_RUNTIME" K8S_CONTEXT="$K8S_CONTEXT" \
  ./scripts/qa/verify-xqueue-graders.sh

run_check "verify-xqueue-deployment" \
  env STRICT_RUNTIME="$STRICT_RUNTIME" K8S_CONTEXT="$K8S_CONTEXT" \
  ./scripts/qa/verify-xqueue-deployment.sh

run_check "verify-ora2-operations" \
  env STRICT_RUNTIME="$STRICT_RUNTIME" K8S_CONTEXT="$K8S_CONTEXT" \
  ./scripts/qa/verify-ora2-operations.sh

cat >"$OUT_DIR/manifest.txt" <<MANIFEST
generated_at_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)
git_commit=$(git rev-parse --short HEAD)
git_branch=$(git branch --show-current)
context=$K8S_CONTEXT
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
