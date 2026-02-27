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
SCRIPT_TIMEOUT="${OBSERVABILITY_SCRIPT_TIMEOUT:-600}"
K8S_CMD_TIMEOUT="${OBSERVABILITY_K8S_TIMEOUT:-60}"

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

if [[ "$MODE" == "runtime" || "$MODE" == "all" ]]; then
  if [[ -z "$K8S_CONTEXT" ]]; then
    echo "Missing required OBSERVABILITY_K8S_CONTEXT for runtime/all checks." >&2
    exit 1
  fi

  if ! ./scripts/qa/verify-observability-parity-lane-contract.sh \
    --env-label "$ENV_LABEL" \
    --dispatch-profile "$DISPATCH_PROFILE" \
    --k8s-context "$K8S_CONTEXT" \
    --gcp-project "$GCP_PROJECT_VALUE"; then
    echo "Lane contract validation failed; aborting observability run." >&2
    exit 1
  fi
  echo
fi

mkdir -p "$OUT_DIR"

run_with_timeout() {
  local duration="$1"
  shift

  if command -v timeout >/dev/null 2>&1; then
    timeout "$duration" "$@"
    return $?
  fi

  if ! command -v python3 >/dev/null 2>&1; then
    "$@"
    return $?
  fi

  python3 - "$duration" "$@" <<'PY'
import subprocess
import sys

timeout_seconds = int(sys.argv[1])
cmd = sys.argv[2:]

try:
    proc = subprocess.run(cmd, check=False, capture_output=True, text=True, timeout=timeout_seconds)
    if proc.stdout:
        print(proc.stdout, end="")
    if proc.stderr:
        print(proc.stderr, end="", file=sys.stderr)
    raise SystemExit(proc.returncode)
except subprocess.TimeoutExpired as exc:
    if exc.stdout:
        print(exc.stdout, end="")
    if exc.stderr:
        print(exc.stderr, end="", file=sys.stderr)
    raise SystemExit(124)
except FileNotFoundError:
    raise SystemExit(127)
PY
}

COMPLIANCE_JSON="$OUT_DIR/observability-compliance-${MODE}.json"
COMPLIANCE_MD="$OUT_DIR/observability-compliance-${MODE}.md"
RUNTIME_TXT="$OUT_DIR/observability-runtime-verify-${MODE}.txt"
RUNTIME_MD="$OUT_DIR/observability-runtime-verify-${MODE}.md"
CORRELATION_TXT="$OUT_DIR/observability-correlation-headers-${MODE}.txt"
COVERAGE_TXT="$OUT_DIR/observability-logging-pipeline-${MODE}.txt"
TRACING_TXT="$OUT_DIR/observability-tracing-${MODE}.txt"
RUNTIME_METRICS_LMS="$OUT_DIR/observability-metrics-lms-runtime.md"
RUNTIME_METRICS_CMS="$OUT_DIR/observability-metrics-cms-runtime.md"
COVERAGE_JSON="$OUT_DIR/observability-coverage-${MODE}.json"
COVERAGE_MD="$OUT_DIR/observability-coverage-${MODE}.md"
INDEX_JSON="$OUT_DIR/observability-first-class-${MODE}-evidence-index.json"

STRICT_FLAG=""
if [[ "$STRICT" == "1" ]]; then
  STRICT_FLAG="--strict"
fi

echo "==> Running observability compliance script"
run_with_timeout "$SCRIPT_TIMEOUT" env \
  VALIDATE_OBS_APP_NAMESPACE="$APP_NAMESPACE" \
  VALIDATE_OBS_K8S_CONTEXT="$K8S_CONTEXT" \
  VALIDATE_OBS_ENV_LABEL="$ENV_LABEL" \
  VALIDATE_OBS_DISPATCH_PROFILE="$DISPATCH_PROFILE" \
  VALIDATE_OBS_EVIDENCE_FILE="$COMPLIANCE_MD" \
  GCP_PROJECT="$GCP_PROJECT_VALUE" \
  VALIDATE_OBS_RUNTIME_CMD_TIMEOUT="$K8S_CMD_TIMEOUT" \
  ./scripts/qa/validate-observability-compliance.sh --mode "$MODE" $STRICT_FLAG --json > "$COMPLIANCE_JSON"

echo "==> Building coverage matrix"
COVERAGE_STRICT_FLAG=""
if [[ "$STRICT" == "1" ]]; then
  COVERAGE_STRICT_FLAG="--strict"
fi

run_with_timeout "$SCRIPT_TIMEOUT" env \
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
  run_with_timeout "$SCRIPT_TIMEOUT" env \
  VERIFY_OBS_APP_NAMESPACE="$APP_NAMESPACE" \
  VERIFY_OBS_MONITORING_NAMESPACE="$MONITORING_NAMESPACE" \
  VERIFY_OBS_K8S_CONTEXT="$K8S_CONTEXT" \
  VERIFY_OBS_GCP_PROJECT="$GCP_PROJECT_VALUE" \
  VERIFY_OBS_ENV_LABEL="$ENV_LABEL" \
  VERIFY_OBS_DISPATCH_PROFILE="$DISPATCH_PROFILE" \
  VERIFY_OBS_EVIDENCE_FILE="$RUNTIME_MD" \
  VERIFY_OBS_EVIDENCE_DIR="$OUT_DIR" \
    ./scripts/qa/verify-observability-runtime.sh > "$RUNTIME_TXT"

  echo "==> Running correlation header propagation check"
  CORRELATION_ARGS=()
  if [[ "$STRICT" == "1" ]]; then
    CORRELATION_ARGS+=(--strict)
  fi
  run_with_timeout "$SCRIPT_TIMEOUT" env \
  STRICT="$STRICT" \
  VERIFY_CORRELATION_ENV_LABEL="$ENV_LABEL" \
  VERIFY_CORRELATION_DISPATCH_PROFILE="$DISPATCH_PROFILE" \
  VERIFY_CORRELATION_K8S_CONTEXT="$K8S_CONTEXT" \
  VERIFY_CORRELATION_GCP_PROJECT="$GCP_PROJECT_VALUE" \
  VERIFY_OBS_EVIDENCE_FILE="$RUNTIME_MD" \
  ./scripts/qa/verify-correlation-header-propagation.sh "${CORRELATION_ARGS[@]}" > "$CORRELATION_TXT"

  echo "==> Running logging pipeline verification"
  run_with_timeout "$SCRIPT_TIMEOUT" env \
  VERIFY_LOGGING_PIPELINE_RUNNER="run-observability-first-class" \
  VERIFY_LOGGING_PIPELINE_ENV_LABEL="$ENV_LABEL" \
  VERIFY_LOGGING_PIPELINE_DISPATCH_PROFILE="$DISPATCH_PROFILE" \
  APP_NS="$APP_NAMESPACE" \
  K8S_CONTEXT="$K8S_CONTEXT" \
  VERIFY_LOGGING_PIPELINE_EVIDENCE_FILE="$COVERAGE_TXT" \
  ./scripts/qa/verify-logging-pipeline.sh $STRICT_FLAG > "$COVERAGE_TXT"

  echo "==> Running tracing verification"
  TRACING_TMP="$TRACING_TXT.tmp.$$"
  run_with_timeout "$SCRIPT_TIMEOUT" env \
  APP_NS="$APP_NAMESPACE" \
  K8S_CONTEXT="$K8S_CONTEXT" \
  TEMPO_URL="${TEMPO_URL:-}" \
  ./scripts/qa/verify-observability-tracing.sh $STRICT_FLAG > "$TRACING_TMP"

  {
    echo "- evidence_identity: env=$ENV_LABEL;profile=$DISPATCH_PROFILE;context=${K8S_CONTEXT:-default};project=$GCP_PROJECT_VALUE"
    cat "$TRACING_TMP"
  } > "$TRACING_TXT"
  rm -f "$TRACING_TMP"
fi

echo "==> Building evidence index"
python3 - <<PY
import json
from datetime import datetime, timezone
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
lms_payload = Path(${RUNTIME_METRICS_LMS@Q})
cms_payload = Path(${RUNTIME_METRICS_CMS@Q})
tracing_txt = Path(${TRACING_TXT@Q})
env_label = ${ENV_LABEL@Q}.lower()

files = [str(compliance_json), str(compliance_md), str(coverage_json), str(coverage_md)]
if mode in ("runtime", "all"):
    files.extend([
        str(runtime_txt),
        str(runtime_md),
        str(lms_payload),
        str(cms_payload),
        str(correlation_txt),
        str(coverage_txt),
        str(tracing_txt),
    ])

    runtime_wiring_evidence = [
        "observability-lms-prometheus-wiring-runtime.md",
        "observability-cms-prometheus-wiring-runtime.md",
        "observability-caddy-prometheus-wiring-runtime.md",
        "observability-mfe-prometheus-wiring-runtime.md",
        "observability-forum-prometheus-wiring-runtime.md",
        "observability-discovery-prometheus-wiring-runtime.md",
        "observability-ecommerce-prometheus-wiring-runtime.md",
        "observability-credentials-prometheus-wiring-runtime.md",
        "observability-purchase-gateway-prometheus-wiring-runtime.md",
        "observability-slo-rules-prometheus-wiring-runtime.md",
        "observability-video-rules-prometheus-wiring-runtime.md",
        "observability-ora2-rules-prometheus-wiring-runtime.md",
    ]

    if env_label in ("dev", "local", "kind", "kind-dev"):
        runtime_wiring_evidence.extend([
            "observability-dev-xqueue-prometheus-wiring-runtime.md",
            "observability-dev-mux-prometheus-wiring-runtime.md",
        ])

    files.extend([str(out_dir / f) for f in runtime_wiring_evidence])

payload = {
    "generated_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
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
