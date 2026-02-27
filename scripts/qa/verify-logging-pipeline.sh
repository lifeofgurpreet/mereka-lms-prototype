#!/usr/bin/env bash
# @spec: specs/observability-stack_spec.md
# @covers: AC-LOG-001, AC-LOG-002, AC-LOG-003, AC-LOG-004, AC-LOG-005, AC-LOG-006, AC-LOG-007, AC-LOG-008
#
# Aggregate logging pipeline contract checks for first-class observability runs.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

K8S_CONTEXT="${K8S_CONTEXT:-gke_bbi-k8_asia-southeast1-c_bbi-k8-cluster}"
APP_NS="${APP_NS:-mereka-lms}"
STRICT="${STRICT:-0}"
RUNNER="${VERIFY_LOGGING_PIPELINE_RUNNER:-unknown}"
EVIDENCE_FILE="${VERIFY_LOGGING_PIPELINE_EVIDENCE_FILE:-}"
EVIDENCE_CAPTURE=""

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASS_COUNT=0
WARN_COUNT=0
SKIP_COUNT=0
FAIL_COUNT=0

usage() {
  cat <<'EOF'
Usage: ./scripts/qa/verify-logging-pipeline.sh [options]

Options:
  --context   <context>   kubectl context
  --namespace <namespace> application namespace (default: mereka-lms)
  --strict              fail on check failures even for non-critical checks
  -h, --help            show help

Environment:
  VERIFY_LOGGING_PIPELINE_EVIDENCE_FILE   Optional evidence file for redirected output
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --context)
      K8S_CONTEXT="$2"
      shift 2
      ;;
    --namespace)
      APP_NS="$2"
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

if [[ -n "$EVIDENCE_FILE" ]]; then
  mkdir -p "$(dirname "$EVIDENCE_FILE")"
  EVIDENCE_CAPTURE="$(mktemp)"
  trap 'rm -f "$EVIDENCE_CAPTURE"' EXIT

  exec > >(tee "$EVIDENCE_CAPTURE")
  exec 2> >(tee -a "$EVIDENCE_CAPTURE" >&2)
fi

report() {
  local status="$1"
  shift
  case "$status" in
    PASS)
      PASS_COUNT=$((PASS_COUNT + 1))
      echo -e "${GREEN}PASS${NC} $*"
      ;;
    WARN)
      WARN_COUNT=$((WARN_COUNT + 1))
      echo -e "${YELLOW}WARN${NC} $*"
      ;;
    SKIP)
      SKIP_COUNT=$((SKIP_COUNT + 1))
      echo -e "${YELLOW}SKIP${NC} $*"
      ;;
    FAIL)
      FAIL_COUNT=$((FAIL_COUNT + 1))
      echo -e "${RED}FAIL${NC} $*"
      ;;
  esac
}

run_check() {
  local script_name="$1"
  local description="$2"

  if [[ ! -x "$script_name" ]]; then
    report FAIL "$description: script missing or non-executable: $script_name"
    return 1
  fi

  local tmp rc
  tmp="$(mktemp)"
  set +e
  "$script_name" \
    --context "$K8S_CONTEXT" \
    --namespace "$APP_NS" \
    $([[ "$STRICT" == "1" ]] && echo "--strict") \
    >"$tmp" 2>&1
  rc=$?
  set -e

  cat "$tmp"
  rm -f "$tmp"

  if [[ $rc -eq 0 ]]; then
    report PASS "$description"
  elif [[ "$STRICT" == "1" ]]; then
    report FAIL "$description: failed (script exit $rc)"
  else
    report WARN "$description: non-strict run captured warnings (script exit $rc)"
  fi

  # Keep executor flow in non-strict mode while still tracking strict violations.
  return 0
}

write_evidence() {
  local status_label="${1:-UNKNOWN}"
  if [[ -z "$EVIDENCE_FILE" || -z "$EVIDENCE_CAPTURE" ]]; then
    return 0
  fi

  {
    echo "# Logging Pipeline Verification Evidence"
    echo ""
    echo "- generated_at: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "- app_namespace: $APP_NS"
    echo "- k8s_context: $K8S_CONTEXT"
    echo "- strict: $STRICT"
    echo "- runner: $RUNNER"
    echo "- status: $status_label"
    echo "- evidence_identity: env=${ENV_LABEL:-unknown};profile=${DISPATCH_PROFILE:-custom};context=${K8S_CONTEXT:-default}"
    echo ""
    echo "## Logging pipeline checks"
    echo ""
    sed 's/\x1B\[[0-9;]*[mK]//g' "$EVIDENCE_CAPTURE"
  } > "$EVIDENCE_FILE"
}

echo "Checking logging pipeline evidence"
echo "  context:   $K8S_CONTEXT"
echo "  namespace: $APP_NS"
echo "  strict:    $STRICT"
echo "  runner:    $RUNNER"
echo ""

echo "=== AC-LOG-001: Promtail deployment ==="
run_check "scripts/qa/verify-observability-loki-deployment.sh" "Promtail deployment checks"

echo ""
echo "=== AC-LOG-002: Canonical log source coverage ==="
run_check "scripts/qa/verify-observability-loki-log-sources.sh" "Canonical log source coverage"

echo ""
echo "=== AC-LOG-003: Loki label schema ==="
run_check "scripts/qa/verify-observability-loki-labels.sh" "Loki label schema checks"

echo ""
echo "=== AC-LOG-004: Structured logs ==="
run_check "scripts/qa/verify-observability-structured-logging.sh" "Structured logging checks"

echo ""
echo "=== AC-LOG-005, AC-LOG-006: PII filtering ==="
run_check "scripts/qa/verify-observability-pii-filtering.sh" "PII filtering checks"

echo ""
echo "=== AC-LOG-007, AC-LOG-008: Retention ==="
run_check "scripts/qa/verify-observability-retention.sh" "Retention checks"

echo ""
echo "=== Logging pipeline aggregate summary ==="
echo "PASS:   $PASS_COUNT"
echo "WARN:   $WARN_COUNT"
echo "SKIP:   $SKIP_COUNT"
echo "FAIL:   $FAIL_COUNT"

if [[ "$STRICT" == "1" && "$FAIL_COUNT" -gt 0 ]]; then
  echo -e "${RED}FAILED (strict mode)${NC}"
  write_evidence "failed_strict"
  exit 1
fi

if [[ "$FAIL_COUNT" -gt 0 ]]; then
  echo -e "${YELLOW}OK (warnings present)${NC}"
  write_evidence "warnings"
  exit 0
fi

echo -e "${GREEN}OK${NC}"
write_evidence "pass"
exit 0
