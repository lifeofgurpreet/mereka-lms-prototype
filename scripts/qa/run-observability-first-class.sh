#!/usr/bin/env bash
# Run first-class observability gates with deterministic evidence outputs.
#
# Usage:
#   ./scripts/qa/run-observability-first-class.sh --mode local|runtime|all [--strict]

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$REPO_ROOT"

MODE="all"
STRICT=0
OUT_DIR="${OBSERVABILITY_EVIDENCE_DIR:-var/ci}"
APP_NAMESPACE="${OBSERVABILITY_APP_NAMESPACE:-mereka-lms}"
MONITORING_NAMESPACE="${OBSERVABILITY_MONITORING_NAMESPACE:-monitoring}"
K8S_CONTEXT="${OBSERVABILITY_K8S_CONTEXT:-}"
ENV_LABEL="${OBSERVABILITY_ENV_LABEL:-unknown}"
DISPATCH_PROFILE="${OBSERVABILITY_DISPATCH_PROFILE:-custom}"
GCP_PROJECT_VALUE="${OBSERVABILITY_GCP_PROJECT:-${GCP_PROJECT:-mereka-lms}}"

usage() {
  cat <<'EOF'
Usage: ./scripts/qa/run-observability-first-class.sh --mode local|runtime|all [--strict]

Environment overrides:
  OBSERVABILITY_EVIDENCE_DIR         Output directory (default: var/ci)
  OBSERVABILITY_APP_NAMESPACE        App namespace (default: mereka-lms)
  OBSERVABILITY_MONITORING_NAMESPACE Monitoring namespace (default: monitoring)
  OBSERVABILITY_K8S_CONTEXT          Optional kubectl context
  OBSERVABILITY_ENV_LABEL            Evidence env label (dev/nonprod/prod/custom)
  OBSERVABILITY_DISPATCH_PROFILE     Evidence profile (nonprod/prod/custom)
  OBSERVABILITY_GCP_PROJECT          Override GCP project label
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --mode)
      MODE="${2:-all}"
      shift 2
      ;;
    --strict)
      STRICT=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown arg: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [[ "$MODE" != "local" && "$MODE" != "runtime" && "$MODE" != "all" ]]; then
  echo "Invalid mode: $MODE" >&2
  usage
  exit 1
fi

mkdir -p "$OUT_DIR"

COMPLIANCE_JSON="$OUT_DIR/observability-compliance-${MODE}.json"
COMPLIANCE_MD="$OUT_DIR/observability-compliance-${MODE}.md"
RUNTIME_TXT="$OUT_DIR/observability-runtime-verify-${MODE}.txt"
RUNTIME_MD="$OUT_DIR/observability-runtime-verify-${MODE}.md"
CORRELATION_TXT="$OUT_DIR/observability-correlation-headers-${MODE}.txt"
COVERAGE_JSON="$OUT_DIR/observability-coverage-${MODE}.json"
COVERAGE_MD="$OUT_DIR/observability-coverage-${MODE}.md"
INDEX_JSON="$OUT_DIR/observability-first-class-${MODE}-evidence-index.json"

STRICT_FLAG=""
if [[ "$STRICT" == "1" ]]; then
  STRICT_FLAG="--strict"
fi

echo "==> Running observability compliance script"
VALIDATE_OBS_APP_NAMESPACE="$APP_NAMESPACE" \
VALIDATE_OBS_K8S_CONTEXT="$K8S_CONTEXT" \
VALIDATE_OBS_ENV_LABEL="$ENV_LABEL" \
VALIDATE_OBS_DISPATCH_PROFILE="$DISPATCH_PROFILE" \
VALIDATE_OBS_EVIDENCE_FILE="$COMPLIANCE_MD" \
GCP_PROJECT="$GCP_PROJECT_VALUE" \
./scripts/qa/validate-observability-compliance.sh --mode "$MODE" $STRICT_FLAG --json > "$COMPLIANCE_JSON"

echo "==> Building coverage matrix"
COVERAGE_STRICT_FLAG=""
if [[ "$STRICT" == "1" ]]; then
  COVERAGE_STRICT_FLAG="--strict"
fi

COVERAGE_MONITORING_NAMESPACE="$MONITORING_NAMESPACE" \
COVERAGE_APP_NAMESPACE="$APP_NAMESPACE" \
COVERAGE_K8S_CONTEXT="$K8S_CONTEXT" \
COVERAGE_ENV_LABEL="$ENV_LABEL" \
COVERAGE_DISPATCH_PROFILE="$DISPATCH_PROFILE" \
./scripts/qa/build-observability-coverage-matrix.sh \
  --mode "$MODE" \
  --out-json "$COVERAGE_JSON" \
  --out-md "$COVERAGE_MD" \
  $COVERAGE_STRICT_FLAG

if [[ "$MODE" == "runtime" || "$MODE" == "all" ]]; then
  echo "==> Running runtime observability verification"
  VERIFY_OBS_APP_NAMESPACE="$APP_NAMESPACE" \
  VERIFY_OBS_MONITORING_NAMESPACE="$MONITORING_NAMESPACE" \
  VERIFY_OBS_K8S_CONTEXT="$K8S_CONTEXT" \
  VERIFY_OBS_GCP_PROJECT="$GCP_PROJECT_VALUE" \
  VERIFY_OBS_ENV_LABEL="$ENV_LABEL" \
  VERIFY_OBS_DISPATCH_PROFILE="$DISPATCH_PROFILE" \
  VERIFY_OBS_EVIDENCE_FILE="$RUNTIME_MD" \
  ./scripts/qa/verify-observability-runtime.sh > "$RUNTIME_TXT"

  echo "==> Running correlation header propagation check"
  CORRELATION_ARGS=()
  if [[ "$STRICT" == "1" ]]; then
    CORRELATION_ARGS+=(--strict)
  fi
  STRICT="$STRICT" \
  VERIFY_CORRELATION_ENV_LABEL="$ENV_LABEL" \
  VERIFY_CORRELATION_DISPATCH_PROFILE="$DISPATCH_PROFILE" \
  VERIFY_CORRELATION_K8S_CONTEXT="$K8S_CONTEXT" \
  VERIFY_CORRELATION_GCP_PROJECT="$GCP_PROJECT_VALUE" \
  VERIFY_OBS_EVIDENCE_FILE="$RUNTIME_MD" \
  ./scripts/qa/verify-correlation-header-propagation.sh "${CORRELATION_ARGS[@]}" > "$CORRELATION_TXT"
fi

echo "==> Building evidence index"
python3 - <<PY
import json
from datetime import datetime
from pathlib import Path

mode = ${MODE@Q}
out_dir = Path(${OUT_DIR@Q})
compliance_json = Path(${COMPLIANCE_JSON@Q})
compliance_md = Path(${COMPLIANCE_MD@Q})
runtime_txt = Path(${RUNTIME_TXT@Q})
runtime_md = Path(${RUNTIME_MD@Q})
correlation_txt = Path(${CORRELATION_TXT@Q})
coverage_json = Path(${COVERAGE_JSON@Q})
coverage_md = Path(${COVERAGE_MD@Q})

files = [str(compliance_json), str(compliance_md), str(coverage_json), str(coverage_md)]
if mode in ("runtime", "all"):
    files.extend([str(runtime_txt), str(runtime_md), str(correlation_txt)])

payload = {
    "generated_at": datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ"),
    "mode": mode,
    "strict": bool(int("${STRICT}")),
    "identity": (
        "env=${ENV_LABEL};"
        "profile=${DISPATCH_PROFILE};"
        "context=${K8S_CONTEXT:-default};"
        "project=${GCP_PROJECT_VALUE}"
    ),
    "files": files,
}

Path(${INDEX_JSON@Q}).write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
PY

echo "==> Observability first-class run complete"
echo "evidence_index=$INDEX_JSON"
