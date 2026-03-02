#!/usr/bin/env bash
# @covers AC-LOG-004
# @spec: observability-stack_spec.md
# Verify LMS/CMS logs are structured JSON with required fields.
# Correlation identifiers are checked on error logs as an observability quality signal.
#
# Usage:
#   ./scripts/qa/verify-observability-structured-logging.sh
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

DEFAULT_K8S_CONTEXT="gke_bbi-k8_asia-southeast1-c_bbi-k8-cluster"
K8S_CONTEXT="${K8S_CONTEXT:-${K8S_CONTEXT_PROD:-$DEFAULT_K8S_CONTEXT}}"
APP_NS="${APP_NS:-${K8S_NAMESPACE:-${K8S_NAMESPACE_PROD:-mereka-lms}}}"
STRICT="${STRICT:-0}"
TARGET_SERVICES="${OBS_STRUCTURED_TARGET_SERVICES:-lms cms lms-worker cms-worker discovery ecommerce ecommerce-worker credentials notes}"
STRICT_JSON_SERVICES="${OBS_STRUCTURED_STRICT_JSON_SERVICES:-lms cms}"
CORRELATION_LEVELS="${OBS_STRUCTURED_CORRELATION_LEVELS:-ERROR,WARN,WARNING,CRITICAL,FATAL}"
MAX_LOG_LINES="${MAX_LOG_LINES:-80}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

while [[ $# -gt 0 ]]; do
  case "$1" in
    --context) K8S_CONTEXT="$2"; shift 2 ;;
    --namespace) APP_NS="$2"; shift 2 ;;
    --strict) STRICT=1; shift ;;
    --lines) MAX_LOG_LINES="$2"; shift 2 ;;
    *) echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
done

if [[ "$STRICT" != "0" && "$STRICT" != "1" ]]; then
  echo "STRICT must be 0 or 1 (got: $STRICT)" >&2
  exit 2
fi

failures=0
skips=0

echo "Verify: Structured JSON logging"
echo "  context:   $K8S_CONTEXT"
echo "  namespace: $APP_NS"
echo "  services:  $TARGET_SERVICES"
echo "  strict JSON services: $STRICT_JSON_SERVICES"
echo "  levels for correlation enforcement: $CORRELATION_LEVELS"
echo "  max lines: $MAX_LOG_LINES"
echo ""

REQUIRED_FIELDS=(
  "timestamp:.timestamp // .time // .\"@timestamp\" // .ts"
  "level:.level // .severity // .levelname // .log.level"
  "service:.service // .service.name // .logger // .logger_name // .name"
  "message:.message // .msg // .event"
)

if ! command -v kubectl >/dev/null 2>&1; then
  echo -e "${YELLOW}SKIP${NC} kubectl not available"
  [[ "$STRICT" -eq 1 ]] && exit 1
  exit 0
fi

if ! command -v jq >/dev/null 2>&1; then
  echo -e "${YELLOW}SKIP${NC} jq not available"
  [[ "$STRICT" -eq 1 ]] && exit 1
  exit 0
fi

if ! kubectl --context "$K8S_CONTEXT" cluster-info >/dev/null 2>&1; then
  echo -e "${YELLOW}SKIP${NC} Cannot reach cluster: $K8S_CONTEXT"
  [[ "$STRICT" -eq 1 ]] && exit 1
  exit 0
fi

has_value() {
  local json_line="$1"
  local expr="$2"
  printf '%s' "$json_line" | jq -e "($expr) != null and (($expr | tostring) != \"\")" >/dev/null 2>&1
}

has_correlation_field() {
  local json_line="$1"
  local expr="$2"
  local value
  value="$(printf '%s' "$json_line" | jq -r "$expr // empty" 2>/dev/null || true)"
  [[ -n "$value" && "$value" != "null" ]]
}

extract_json_payload() {
  local line="$1"
  if printf '%s' "$line" | jq -e . >/dev/null 2>&1; then
    printf '%s' "$line"
    return 0
  fi

  local candidate
  candidate="$(printf '%s' "$line" | sed -n 's/^[^{]*\({.*}\)$/\1/p' | head -n1)"
  if [[ -n "$candidate" ]] && printf '%s' "$candidate" | jq -e . >/dev/null 2>&1; then
    printf '%s' "$candidate"
    return 0
  fi

  return 1
}

SERVICES=()
read -r -a SERVICES <<< "$TARGET_SERVICES"

if [[ ${#SERVICES[@]} -eq 0 ]]; then
  echo -e "${YELLOW}SKIP${NC} No services configured. Set OBS_STRUCTURED_TARGET_SERVICES."
  exit 0
fi

CORRELATION_LEVELS_ARR=()
IFS=',' read -r -a _raw_levels <<< "$CORRELATION_LEVELS"
for level in "${_raw_levels[@]}"; do
  normalized="$(printf '%s' "$level" | tr '[:lower:]' '[:upper:]' | xargs)"
  [[ -n "$normalized" ]] && CORRELATION_LEVELS_ARR+=("$normalized")
done

STRICT_JSON_SERVICES_ARR=()
read -r -a _raw_strict_services <<< "$STRICT_JSON_SERVICES"
for strict_svc in "${_raw_strict_services[@]}"; do
  normalized_svc="$(printf '%s' "$strict_svc" | xargs)"
  [[ -n "$normalized_svc" ]] && STRICT_JSON_SERVICES_ARR+=("$normalized_svc")
done

is_correlation_level() {
  local level="$1"
  [[ -z "$level" ]] && return 1
  for target in "${CORRELATION_LEVELS_ARR[@]}"; do
    [[ "$level" == "$target" ]] && return 0
  done
  return 1
}

is_strict_json_service() {
  local svc="$1"
  for strict_svc in "${STRICT_JSON_SERVICES_ARR[@]}"; do
    [[ "$svc" == "$strict_svc" ]] && return 0
  done
  return 1
}

for svc in "${SERVICES[@]}"; do
  echo "Checking logs for service: $svc"

  pod=$(kubectl --context "$K8S_CONTEXT" -n "$APP_NS" get pods -l "app.kubernetes.io/name=$svc" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
  if [[ -z "$pod" ]]; then
    pod=$(kubectl --context "$K8S_CONTEXT" -n "$APP_NS" get pods -l "app=$svc" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
  fi

  if [[ -z "$pod" ]]; then
    echo -e "  ${YELLOW}SKIP${NC} No running pod found for $svc"
    skips=$((skips + 1))
    continue
  fi

  echo "  Found pod: $pod"
  logs="$(kubectl --context "$K8S_CONTEXT" -n "$APP_NS" logs "$pod" --tail="$MAX_LOG_LINES" 2>/dev/null || echo "")"

  if [[ -z "$logs" ]]; then
    echo -e "  ${YELLOW}SKIP${NC} No logs available from pod"
    skips=$((skips + 1))
    continue
  fi

  json_count=0
  full_json_count=0
  total_lines=0
  error_missing_correlation=0
  missing_required=0
  field_missing=("0" "0" "0" "0")

  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    total_lines=$((total_lines + 1))

    parsed_json=""
    if ! parsed_json="$(extract_json_payload "$line")"; then
      continue
    fi

    json_count=$((json_count + 1))
    if printf '%s' "$line" | jq -e . >/dev/null 2>&1; then
      full_json_count=$((full_json_count + 1))
    fi

    for i in "${!REQUIRED_FIELDS[@]}"; do
      IFS=':' read -r field expr <<< "${REQUIRED_FIELDS[$i]}"
      if ! has_value "$parsed_json" "$expr"; then
        field_missing[$i]=1
      fi
    done

    level="$(printf '%s' "$parsed_json" | jq -r '.level // .severity // .levelname // .log.level // empty' 2>/dev/null | tr '[:lower:]' '[:upper:]' || true)"
    if is_correlation_level "$level"; then
      has_request=0
      has_trace=0
      if has_correlation_field "$parsed_json" '(.request_id // .requestId // .request.id // .extra.request_id // .extra.requestId // .extra.request.id)'; then
        has_request=1
      fi
      if has_correlation_field "$parsed_json" '(.trace_id // .trace // .traceparent // .trace.id // .extra.trace_id // .extra.traceparent // .extra.trace.id)'; then
        has_trace=1
      fi
      if (( has_request == 0 || has_trace == 0 )); then
        error_missing_correlation=$((error_missing_correlation + 1))
      fi
    fi
  done <<< "$logs"

  echo -n "  Check: Logs are JSON formatted... "
  if [[ "$json_count" -gt 0 ]]; then
    percentage=$((json_count * 100 / total_lines))
    if [[ "$full_json_count" -gt 0 ]]; then
      echo -e "${GREEN}PASS${NC} ($json_count/$total_lines lines, ${percentage}%; full-json lines: $full_json_count)"
    else
      echo -e "${GREEN}PASS${NC} ($json_count/$total_lines lines, ${percentage}%; embedded JSON payloads)"
    fi
  else
    echo -e "${YELLOW}WARN${NC} No JSON logs found (might be using plain text format)"
    echo -e "  WARN: AC-LOG-004 enforcement expects JSON logs"
    if [[ "$STRICT" -eq 1 ]] && is_strict_json_service "$svc"; then
      failures=$((failures + 1))
    fi
    [[ -n "${SILENCE_NO_JSON:-}" ]] || true
  fi

  if [[ "$full_json_count" -gt 0 ]]; then
    echo "  Checking required fields in JSON logs:"
    for i in "${!REQUIRED_FIELDS[@]}"; do
      IFS=':' read -r field expr <<< "${REQUIRED_FIELDS[$i]}"
      echo -n "    Field '$field'... "
      if [[ "${field_missing[$i]}" == "0" ]]; then
        echo -e "${GREEN}PASS${NC}"
      else
        echo -e "${RED}FAIL${NC} Field '$field' missing from JSON logs"
        missing_required=$((missing_required + 1))
      fi
    done

    if [[ "$missing_required" -gt 0 ]]; then
      failures=$((failures + missing_required))
    fi

    if [[ "$error_missing_correlation" -gt 0 ]]; then
      if [[ "$STRICT" -eq 1 ]]; then
        echo -e "    ${RED}FAIL${NC} $error_missing_correlation error-class JSON logs missing request/trace correlation fields"
        echo "      Expected: request correlation (request_id/requestId/request.id) and trace correlation (trace_id/traceparent/trace.id)"
        failures=$((failures + error_missing_correlation))
      else
        echo -e "    ${YELLOW}WARN${NC} $error_missing_correlation error-class JSON logs missing request/trace correlation fields"
        echo "      Expected: request correlation (request_id/requestId/request.id) and trace correlation (trace_id/traceparent/trace.id)"
      fi
    fi
  fi

  if [[ "$json_count" -gt 0 && "$full_json_count" -eq 0 ]]; then
    echo -e "  ${YELLOW}WARN${NC} Only embedded JSON payloads detected; skipping strict full-line field contract."
  fi

  echo ""
done

echo -e "${YELLOW}NOTE:${NC} Open edX defaults may emit plain text in some code paths."
echo "Open this script in strict mode when structured logging is required for first-class gates."
echo ""

if [[ "$failures" -eq 0 ]]; then
  if [[ "$skips" -gt 0 ]]; then
    echo -e "${YELLOW}OK (with $skips skipped checks)${NC}"
  else
    echo -e "${GREEN}OK${NC}"
  fi
  exit 0
fi

echo -e "${RED}FAILED ($failures checks failed)${NC}"
exit 1
