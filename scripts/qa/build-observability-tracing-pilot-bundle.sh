#!/usr/bin/env bash
# Build a first-class observability tracing pilot evidence bundle.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

MODE="runtime"
ENV_LABEL="${OBSERVABILITY_PILOT_ENV_LABEL:-nonprod}"
DISPATCH_PROFILE="${OBSERVABILITY_PILOT_DISPATCH_PROFILE:-nonprod}"
K8S_CONTEXT="${OBSERVABILITY_PILOT_K8S_CONTEXT:-${OBSERVABILITY_K8S_CONTEXT:-${K8S_CONTEXT:-rke2-nonprod}}}"
APP_NAMESPACE="${OBSERVABILITY_PILOT_APP_NAMESPACE:-mereka-lms}"
MONITORING_NAMESPACE="${OBSERVABILITY_PILOT_MONITORING_NAMESPACE:-monitoring}"
OUT_DIR="${OBSERVABILITY_PILOT_OUT_DIR:-docs/archive/evidence/observability}"
PILOT_HOST="${OBSERVABILITY_PILOT_HOST:-apps.academyv2.mereka.dev}"
PILOT_PATH="${OBSERVABILITY_PILOT_PATH:-/health/}"
TEMPO_URL="${OBSERVABILITY_PILOT_TEMPO_URL:-${TEMPO_URL:-}}"
STRICT="${OBSERVABILITY_PILOT_STRICT:-0}"
REQUIRE_FLOW_CAPTURE="${OBSERVABILITY_PILOT_REQUIRE_FLOW_CAPTURE:-0}"
RUN_TIMEOUT_SEC="${OBSERVABILITY_PILOT_TIMEOUT_SEC:-180}"
TRACE_QUERY_TIMEOUT_SEC="${OBSERVABILITY_PILOT_TRACE_TIMEOUT_SEC:-12}"

usage() {
  cat <<'USAGE'
Usage: ./scripts/qa/build-observability-tracing-pilot-bundle.sh [options]

Options:
  --env <env-label>            evidence env/profile label (default: nonprod)
  --mode runtime|all           runner mode (default: runtime)
  --context <k8s-context>      kubectl context override
  --host <hostname>            pilot route host (default: apps.academyv2.mereka.dev)
  --path <path>                pilot route path (default: /health/)
  --out-dir <dir>              evidence output base (default: docs/archive/evidence/observability)
  --strict                     fail on downstream strict check failures
  --require-flow-capture       require successful route capture proof
  --help                       show this help text
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --env)
      ENV_LABEL="$2"
      DISPATCH_PROFILE="${2:-nonprod}"
      shift 2
      ;;
    --mode)
      MODE="$2"
      shift 2
      ;;
    --context)
      K8S_CONTEXT="$2"
      shift 2
      ;;
    --host)
      PILOT_HOST="$2"
      shift 2
      ;;
    --path)
      PILOT_PATH="$2"
      shift 2
      ;;
    --out-dir)
      OUT_DIR="$2"
      shift 2
      ;;
    --strict)
      STRICT=1
      shift
      ;;
    --require-flow-capture)
      REQUIRE_FLOW_CAPTURE=1
      shift
      ;;
    --help|-h)
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

if [[ "$MODE" != "runtime" && "$MODE" != "all" ]]; then
  echo "Invalid mode: $MODE" >&2
  usage
  exit 1
fi

TIMESTAMP="$(date -u +%Y%m%d-%H%M%S)"
RUN_DIR="$OUT_DIR/pilot-${ENV_LABEL}-${TIMESTAMP}"
FIRST_CLASS_DIR="$RUN_DIR/first-class"
mkdir -p "$RUN_DIR" "$FIRST_CLASS_DIR"

run_with_timeout() {
  local duration="$1"
  shift
  if command -v timeout >/dev/null 2>&1; then
    timeout "$duration" "$@"
    return $?
  fi
  "$@"
}

STRICT_FLAG=""
if [[ "$STRICT" == "1" ]]; then
  STRICT_FLAG="--strict"
fi

RUN_LOG="$RUN_DIR/run-observability-first-class.log"
export OBSERVABILITY_EVIDENCE_DIR="$FIRST_CLASS_DIR"
export OBSERVABILITY_APP_NAMESPACE="$APP_NAMESPACE"
export OBSERVABILITY_MONITORING_NAMESPACE="$MONITORING_NAMESPACE"
export OBSERVABILITY_K8S_CONTEXT="$K8S_CONTEXT"
export OBSERVABILITY_ENV_LABEL="$ENV_LABEL"
export OBSERVABILITY_DISPATCH_PROFILE="$DISPATCH_PROFILE"

run_with_timeout "$RUN_TIMEOUT_SEC" \
  ./scripts/qa/run-observability-first-class.sh --mode "$MODE" $STRICT_FLAG 2>&1 | tee "$RUN_LOG"

INDEX_FILE="$FIRST_CLASS_DIR/observability-first-class-${MODE}-evidence-index.json"
if [[ ! -f "$INDEX_FILE" ]]; then
  echo "Observability evidence index missing: $INDEX_FILE" >&2
  exit 1
fi

mapfile -t evidence_files < <(jq -r '.files[]' "$INDEX_FILE" 2>/dev/null || true)
if [[ "${#evidence_files[@]}" -eq 0 ]]; then
  evidence_files=(
    "$FIRST_CLASS_DIR/observability-compliance-${MODE}.json"
    "$FIRST_CLASS_DIR/observability-compliance-${MODE}.md"
    "$FIRST_CLASS_DIR/observability-runtime-verify-${MODE}.txt"
    "$FIRST_CLASS_DIR/observability-runtime-verify-${MODE}.md"
    "$FIRST_CLASS_DIR/observability-correlation-headers-${MODE}.txt"
    "$FIRST_CLASS_DIR/observability-logging-pipeline-${MODE}.txt"
    "$FIRST_CLASS_DIR/observability-tracing-${MODE}.txt"
    "$FIRST_CLASS_DIR/observability-coverage-${MODE}.json"
    "$FIRST_CLASS_DIR/observability-coverage-${MODE}.md"
    "$INDEX_FILE"
  )
fi

for src in "${evidence_files[@]}"; do
  [[ -z "$src" ]] && continue
  [[ -f "$src" ]] && cp "$src" "$RUN_DIR/" || true
done

FLOW_CAPTURE_DIR="$RUN_DIR/pilot-route"
mkdir -p "$FLOW_CAPTURE_DIR"
ROUTE_CAPTURE_FILE="$FLOW_CAPTURE_DIR/route-capture.txt"
TRACE_QUERY_FILE="$FLOW_CAPTURE_DIR/tempo-query.txt"

FLOW_REQUEST_ID=""
FLOW_TRACEPARENT=""
FLOW_TRACE_ID=""
ROUTE_STATUS=""
FLOW_OK=0

capture_route() {
  if ! command -v kubectl >/dev/null 2>&1 || ! command -v curl >/dev/null 2>&1; then
    echo "SKIP: kubectl or curl unavailable" > "$ROUTE_CAPTURE_FILE"
    return 1
  fi

  if ! kubectl --context "$K8S_CONTEXT" -n "$APP_NAMESPACE" get svc caddy >/dev/null 2>&1; then
    echo "SKIP: svc/caddy not found" > "$ROUTE_CAPTURE_FILE"
    return 1
  fi

  local local_port="18443"
  local header_file="$FLOW_CAPTURE_DIR/route-headers.txt"
  local body_file="$FLOW_CAPTURE_DIR/route-body.txt"

  kubectl --context "$K8S_CONTEXT" -n "$APP_NAMESPACE" port-forward svc/caddy "${local_port}:443" >/tmp/obs-pilot-route-pf.log 2>&1 &
  local pf_pid=$!
  sleep 2

  ROUTE_STATUS="$(curl -ksm 12 -o "$body_file" -D "$header_file" \
    -H "Host: ${PILOT_HOST}" \
    -H "X-Request-ID: pilot-${TIMESTAMP}" \
    "https://127.0.0.1:${local_port}${PILOT_PATH}" \
    -w '%{http_code}' || echo ERROR)"

  kill "$pf_pid" >/dev/null 2>&1 || true
  wait "$pf_pid" 2>/dev/null || true

  FLOW_REQUEST_ID="$(awk 'BEGIN{IGNORECASE=1} /^x-request-id:/{sub(/^x-request-id:[[:space:]]*/, "", $0); print $0; exit}' "$header_file")"
  FLOW_TRACEPARENT="$(awk 'BEGIN{IGNORECASE=1} /^traceparent:/{sub(/^traceparent:[[:space:]]*/, "", $0); print $0; exit}' "$header_file")"
  if [[ "$FLOW_TRACEPARENT" == 00-* ]]; then
    FLOW_TRACE_ID="${FLOW_TRACEPARENT#00-}"
    FLOW_TRACE_ID="${FLOW_TRACE_ID%%-*}"
  fi

  {
    echo "Pilot host: ${PILOT_HOST}${PILOT_PATH}"
    echo "HTTP status: ${ROUTE_STATUS}"
    echo "X-Request-ID: ${FLOW_REQUEST_ID:-<missing>}"
    echo "traceparent: ${FLOW_TRACEPARENT:-<missing>}"
    echo "trace_id: ${FLOW_TRACE_ID:-<missing>}"
    echo "--- HEADERS ---"
    cat "$header_file"
    echo "--- BODY HEAD ---"
    sed -n '1,120p' "$body_file"
  } > "$ROUTE_CAPTURE_FILE"

  if [[ "$ROUTE_STATUS" == "ERROR" ]]; then
    return 1
  fi

  if [[ -n "$FLOW_REQUEST_ID" && -n "$FLOW_TRACEPARENT" ]]; then
    FLOW_OK=1
    return 0
  fi

  return 1
}

capture_route
FLOW_RESULT="$?"

if [[ -z "$TEMPO_URL" ]]; then
  tempo_svc=""
  tempo_svc="$(kubectl --context "$K8S_CONTEXT" -n "$MONITORING_NAMESPACE" get svc -l app.kubernetes.io/name=tempo -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)"
  if [[ -n "$tempo_svc" ]]; then
    TEMPO_URL="http://${tempo_svc}.${MONITORING_NAMESPACE}.svc.cluster.local:3200"
  fi
fi

if [[ "$FLOW_OK" == "1" && -n "$TEMPO_URL" && -n "$FLOW_TRACE_ID" ]]; then
  curl -ksm "$TRACE_QUERY_TIMEOUT_SEC" -o "$TRACE_QUERY_FILE" \
    "${TEMPO_URL%/}/api/search?q=%22${FLOW_TRACE_ID}%22&limit=1" -w '%{http_code}' || true
else
  echo "skip: no flow/tempo endpoint available" > "$TRACE_QUERY_FILE"
fi

BUNDLE_FILE="$RUN_DIR/$(printf 'pilot-nonprod-observability-bundle-%s.md' "$TIMESTAMP")"
cat > "$BUNDLE_FILE" <<EOF_BUNDLE
# Observability Tracing Pilot Evidence Bundle

Generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)
Mode: ${MODE}
Environment: ${ENV_LABEL}
Profile: ${DISPATCH_PROFILE}
K8S context: ${K8S_CONTEXT}
Namespace: ${APP_NAMESPACE}
Monitoring namespace: ${MONITORING_NAMESPACE}
Tempo endpoint: ${TEMPO_URL:-<not discovered>}
Pilot route: https://${PILOT_HOST}${PILOT_PATH}

## Evidence

- run log: $(realpath "$RUN_LOG")
- route capture: $(realpath "$ROUTE_CAPTURE_FILE")
- tempo query: $(realpath "$TRACE_QUERY_FILE")
- copied observability artifacts:
  - observability-compliance-${MODE}.json
  - observability-compliance-${MODE}.md
  - observability-runtime-verify-${MODE}.txt
  - observability-runtime-verify-${MODE}.md
  - observability-correlation-headers-${MODE}.txt
  - observability-logging-pipeline-${MODE}.txt
  - observability-tracing-${MODE}.txt
  - observability-coverage-${MODE}.json
  - observability-coverage-${MODE}.md
  - observability-first-class-${MODE}-evidence-index.json

## Route Capture Summary

- flow_status: ${ROUTE_STATUS}
- request_id: ${FLOW_REQUEST_ID}
- traceparent: ${FLOW_TRACEPARENT}
- trace_id: ${FLOW_TRACE_ID}

## Trace Query Proof

- flow_capture_ok: ${FLOW_OK}
- flow_result_exit_code: ${FLOW_RESULT}
- tempo_query_file: $(realpath "$TRACE_QUERY_FILE")
EOF_BUNDLE

if [[ "$FLOW_OK" == "1" ]]; then
  echo "- route_capture: PASS" >> "$BUNDLE_FILE"
else
  echo "- route_capture: FAIL" >> "$BUNDLE_FILE"
  if [[ "$REQUIRE_FLOW_CAPTURE" == "1" ]]; then
    echo "Flow capture required but unavailable; blocking pilot closeout." >> "$BUNDLE_FILE"
    exit 1
  fi
fi

echo "Pilot bundle generated: $BUNDLE_FILE"
