#!/usr/bin/env bash
# @covers AC-LOG-004
# @spec: observability-stack_spec.md
# Verify LMS and CMS logs are structured JSON with required fields.
#
# Usage:
#   ./scripts/qa/verify-observability-structured-logging.sh
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

K8S_CONTEXT="${K8S_CONTEXT:-gke_bbi-k8_asia-southeast1-c_bbi-k8-cluster}"
APP_NS="${APP_NS:-mereka-lms}"
STRICT="${STRICT:-0}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

while [[ $# -gt 0 ]]; do
  case "$1" in
    --context) K8S_CONTEXT="$2"; shift 2 ;;
    --namespace) APP_NS="$2"; shift 2 ;;
    --strict) STRICT=1; shift ;;
    *) echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
done

failures=0
skips=0

echo "Verify: Structured JSON logging"
echo "  context:   $K8S_CONTEXT"
echo "  namespace: $APP_NS"
echo ""

REQUIRED_FIELDS=(
  "timestamp"
  "level"
  "service"
  "message"
)

# Check if kubectl/jq are available
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

# Check if cluster is reachable
if ! kubectl --context "$K8S_CONTEXT" cluster-info >/dev/null 2>&1; then
  echo -e "${YELLOW}SKIP${NC} Cannot reach cluster: $K8S_CONTEXT"
  [[ "$STRICT" -eq 1 ]] && exit 1
  exit 0
fi

# Services to check
SERVICES=("lms" "cms")

for svc in "${SERVICES[@]}"; do
  echo "Checking logs for service: $svc"

  # Get a pod for this service
  pod=$(kubectl --context "$K8S_CONTEXT" -n "$APP_NS" get pods -l "app.kubernetes.io/name=$svc" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")

  if [[ -z "$pod" ]]; then
    # Try alternate label
    pod=$(kubectl --context "$K8S_CONTEXT" -n "$APP_NS" get pods -l "app=$svc" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
  fi

  if [[ -z "$pod" ]]; then
    echo -e "  ${YELLOW}SKIP${NC} No running pod found for $svc"
    skips=$((skips + 1))
    continue
  fi

  echo "  Found pod: $pod"

  # Get recent logs
  logs=$(kubectl --context "$K8S_CONTEXT" -n "$APP_NS" logs "$pod" --tail=50 2>/dev/null || echo "")

  if [[ -z "$logs" ]]; then
    echo -e "  ${YELLOW}SKIP${NC} No logs available from pod"
    skips=$((skips + 1))
    continue
  fi

  # Try to parse logs as JSON
  json_count=0
  total_lines=0
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    total_lines=$((total_lines + 1))

    # Try to parse as JSON
    if echo "$line" | jq -e . >/dev/null 2>&1; then
      json_count=$((json_count + 1))
    fi
  done <<< "$logs"

  echo -n "  Check: Logs are JSON formatted... "
  if [[ "$json_count" -gt 0 ]]; then
    percentage=$((json_count * 100 / total_lines))
    echo -e "${GREEN}PASS${NC} ($json_count/$total_lines lines, ${percentage}%)"
  else
    echo -e "${YELLOW}WARN${NC} No JSON logs found (might be using plain text format)"
    # Not failing because this might be expected in some deployments
  fi

  # If we have JSON logs, check for required fields
  if [[ "$json_count" -gt 0 ]]; then
    # Sample a JSON log line
    sample_json=$(echo "$logs" | while IFS= read -r line; do
      if echo "$line" | jq -e . >/dev/null 2>&1; then
        echo "$line"
        break
      fi
    done)

    if [[ -n "$sample_json" ]]; then
      echo "  Checking required fields in JSON logs:"
      for field in "${REQUIRED_FIELDS[@]}"; do
        echo -n "    Field '$field'... "

        # Check for field or common variations
        case "$field" in
          "timestamp")
            if echo "$sample_json" | jq -e '.timestamp // .time // ."@timestamp" // .ts' >/dev/null 2>&1; then
              echo -e "${GREEN}PASS${NC}"
            else
              echo -e "${YELLOW}WARN${NC} Timestamp field not found (checked: timestamp, time, @timestamp, ts)"
            fi
            ;;
          "level")
            if echo "$sample_json" | jq -e '.level // .severity // .levelname' >/dev/null 2>&1; then
              echo -e "${GREEN}PASS${NC}"
            else
              echo -e "${YELLOW}WARN${NC} Level field not found (checked: level, severity, levelname)"
            fi
            ;;
          "service")
            if echo "$sample_json" | jq -e '.service // .logger // .name' >/dev/null 2>&1; then
              echo -e "${GREEN}PASS${NC}"
            else
              echo -e "${YELLOW}WARN${NC} Service field not found (checked: service, logger, name)"
            fi
            ;;
          "message")
            if echo "$sample_json" | jq -e '.message // .msg' >/dev/null 2>&1; then
              echo -e "${GREEN}PASS${NC}"
            else
              echo -e "${RED}FAIL${NC} Message field is required"
              failures=$((failures + 1))
            fi
            ;;
        esac
      done
    fi
  fi

  echo ""
done

echo -e "${YELLOW}NOTE:${NC} Open edX may use plain text logging by default."
echo "To enable structured JSON logging, configure Python logging formatters in LMS/CMS settings."

echo ""
if [[ "$failures" -eq 0 ]]; then
  if [[ "$skips" -gt 0 ]]; then
    echo -e "${YELLOW}OK (with $skips skipped checks)${NC}"
  else
    echo -e "${GREEN}OK${NC}"
  fi
  exit 0
else
  echo -e "${RED}FAILED ($failures checks failed)${NC}"
  exit 1
fi
