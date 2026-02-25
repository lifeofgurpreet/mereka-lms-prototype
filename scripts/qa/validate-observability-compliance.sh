#!/usr/bin/env bash
# @spec: observability-validation-requirements_spec.md
# @covers: AC-OVR-001, AC-OVR-002, AC-OVR-003, AC-OVR-004, AC-OVR-005, AC-OVR-006, AC-OVR-007, AC-OVR-008, AC-OVR-009, AC-OVR-010, AC-OVR-011, AC-OVR-012, AC-OVR-013, AC-OVR-014, AC-OVR-015, AC-OVR-016, AC-OVR-017, AC-OVR-018, AC-OVR-019, AC-OVR-020, AC-OVR-021, AC-OVR-022, AC-OVR-023, AC-OVR-024, AC-OVR-025, AC-OVR-026, AC-OVR-027, AC-OVR-028, AC-OVR-029, AC-OVR-030, AC-OVR-031
# Validate observability compliance across local manifests and runtime dependencies.
#
# Modes:
#   local   - repo-based checks + optional local validation execution
#   runtime - live cluster + gcloud checks
#   all     - both local and runtime checks
#
# Usage:
#   ./scripts/qa/validate-observability-compliance.sh --mode local|runtime|all [--json] [--strict]

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SCRIPT_DIR="$REPO_ROOT/scripts/qa"

MODE="all"
JSON_OUT=0
STRICT=0
SCRIPT_TIMEOUT="${VALIDATE_OBS_SCRIPT_TIMEOUT:-120}"
RUNTIME_CMD_TIMEOUT="${VALIDATE_OBS_RUNTIME_CMD_TIMEOUT:-30}"
APP_NAMESPACE="${VALIDATE_OBS_APP_NAMESPACE:-mereka-lms}"
EVIDENCE_FILE="${VALIDATE_OBS_EVIDENCE_FILE:-}"
K8S_CONTEXT="${VALIDATE_OBS_K8S_CONTEXT:-}"

usage() {
  cat <<'EOF'
Usage: ./scripts/qa/validate-observability-compliance.sh --mode local|runtime|all [--json] [--strict]
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --mode)
      MODE="${2:-all}"
      shift 2
      ;;
    --json)
      JSON_OUT=1
      shift
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

VALIDATE_SCRIPT="$SCRIPT_DIR/verify-observability-validation.sh"
RUNTIME_SCRIPT="$SCRIPT_DIR/verify-observability-runtime.sh"
AUDIT_SCRIPT="$SCRIPT_DIR/audit-observability.sh"

PASS=0
FAIL=0
SKIP=0
RESULTS_FILE="$(mktemp -t observability-compliance.XXXXXX)"
trap 'rm -f "$RESULTS_FILE"' EXIT

record_result() {
  local status="$1"
  local check_id="$2"
  local msg="${3:-}"

  msg="${msg//$'\n'/ }"
  msg="${msg//$'\t'/ }"
  printf '%s\t%s\t%s\n' "$status" "$check_id" "$msg" >> "$RESULTS_FILE"

  case "$status" in
    pass) PASS=$((PASS + 1)) ;;
    fail) FAIL=$((FAIL + 1)) ;;
    skip) SKIP=$((SKIP + 1)) ;;
  esac
}

kubectl_cmd() {
  if [[ -n "$K8S_CONTEXT" ]]; then
    kubectl --context "$K8S_CONTEXT" "$@"
  else
    kubectl "$@"
  fi
}

run_script() {
  local check_id="$1"
  local script_path="$2"
  local args="${3:-}"
  local output
  local rc=0

  if [[ ! -x "$script_path" ]]; then
    record_result fail "$check_id" "Script is missing or not executable: $script_path"
    return 1
  fi

  set +e
  if command -v timeout >/dev/null 2>&1; then
    if [[ -n "$args" ]]; then
      output="$(timeout "$SCRIPT_TIMEOUT" "$script_path" $args 2>&1)"
      rc=$?
    else
      output="$(timeout "$SCRIPT_TIMEOUT" "$script_path" 2>&1)"
      rc=$?
    fi
  else
    if [[ -n "$args" ]]; then
      output="$($script_path $args 2>&1)"
      rc=$?
    else
      output="$($script_path 2>&1)"
      rc=$?
    fi
  fi
  set -e

  if [[ $rc -eq 0 ]]; then
    record_result pass "$check_id" "passed"
  else
    output="${output:0:600}"
    if [[ -z "$output" ]]; then
      output="(no command output)"
    fi
    record_result fail "$check_id" "$output"
  fi

  return 0
}

run_negative_control_check() {
  local temp_root
  local temp_monitoring_root
  local temp_kustomization
  local output
  local rc=0
  local missing_sm="servicemonitor-enterprise.yaml"

  temp_root="$(mktemp -d -t observability-negative.XXXXXX)"
  temp_monitoring_root="$temp_root/deploy/k8s/base/monitoring"

  mkdir -p "$(dirname "$temp_monitoring_root")"
  cp -a "$REPO_ROOT/deploy/k8s/base/monitoring" "$temp_root/deploy/k8s/base/"
  temp_kustomization="$temp_monitoring_root/kustomization.yaml"
  sed -i "/$missing_sm/d" "$temp_kustomization"

  set +e
  output="$(
    VERIFY_OBS_KUSTOMIZATION_PATH="$temp_kustomization" \
    VERIFY_OBS_MONITORING_DIR="$temp_monitoring_root" \
    "$VALIDATE_SCRIPT" 2>&1
  )"
  rc=$?
  set -e

  rm -rf "$temp_root"

  if [[ $rc -ne 0 ]] && echo "$output" | grep -q "${missing_sm} NOT listed in kustomization.yaml"; then
    record_result pass "AC-OVR-026" "Negative-control validation fails when required ServiceMonitor entry is removed"
  elif [[ $rc -eq 0 ]]; then
    record_result fail "AC-OVR-026" "Negative-control validation succeeded even after removing required ServiceMonitor"
  else
    record_result fail "AC-OVR-026" "Negative-control validation failed but did not flag the expected missing ServiceMonitor entry"
  fi
}

run_local_checks() {
  run_script "AC-OVR-024" "$VALIDATE_SCRIPT"

  run_script "AC-OVR-024" "$AUDIT_SCRIPT" "--mode local"

  local has_ci_invocation=1
  if command -v rg >/dev/null 2>&1; then
    if rg -q "validate-observability-compliance.sh" .github/workflows 2>/dev/null; then
      has_ci_invocation=0
    fi
  elif grep -R -q "validate-observability-compliance.sh" .github/workflows 2>/dev/null; then
    has_ci_invocation=0
  fi

  if [[ "$has_ci_invocation" -eq 0 ]]; then
    record_result pass "AC-OVR-028" "CI workflow invokes validate-observability-compliance.sh"
  else
    if [[ "$STRICT" == "1" ]]; then
      record_result fail "AC-OVR-028" "No CI workflow currently invokes validate-observability-compliance.sh"
    else
      record_result skip "AC-OVR-028" "No CI workflow currently invokes validate-observability-compliance.sh"
    fi
  fi

  local compliance_workflow=".github/workflows/observability-compliance.yml"
  if [[ -f "$compliance_workflow" ]]; then
    local has_pull_request_trigger=0
    local has_local_mode_strict=0
    local has_monitoring_path_filter=0

    if command -v rg >/dev/null 2>&1; then
      if rg -q "pull_request:" "$compliance_workflow"; then
        has_pull_request_trigger=1
      fi
      if rg -q "validate-observability-compliance.sh --mode local --strict" "$compliance_workflow"; then
        has_local_mode_strict=1
      fi
      if rg -q "deploy/k8s/base/monitoring" "$compliance_workflow" \
        && rg -q "kustomization.yaml" "$compliance_workflow"; then
        has_monitoring_path_filter=1
      fi
    else
      if grep -q "pull_request:" "$compliance_workflow"; then
        has_pull_request_trigger=1
      fi
      if grep -q "validate-observability-compliance.sh --mode local --strict" "$compliance_workflow"; then
        has_local_mode_strict=1
      fi
      if grep -q "deploy/k8s/base/monitoring" "$compliance_workflow" \
        && grep -q "kustomization.yaml" "$compliance_workflow"; then
        has_monitoring_path_filter=1
      fi
    fi

    if [[ "$has_pull_request_trigger" -eq 1 && "$has_local_mode_strict" -eq 1 && "$has_monitoring_path_filter" -eq 1 ]]; then
      record_result pass "AC-OVR-029" "Observability compliance workflow enforces PR checks on monitoring manifests"
    else
      record_result fail "AC-OVR-029" "PR-based observability compliance workflow is present but incomplete"
    fi
  else
    record_result fail "AC-OVR-029" "Observability compliance workflow (.github/workflows/observability-compliance.yml) missing"
  fi

  if [[ "$JSON_OUT" -eq 1 ]]; then
    if ! command -v jq >/dev/null 2>&1; then
      if [[ "$STRICT" == "1" ]]; then
        record_result fail "AC-OVR-025" "jq is required for JSON validation output"
      else
        record_result skip "AC-OVR-025" "jq is not installed; cannot validate JSON report structure"
      fi
    elif ! command -v python3 >/dev/null 2>&1; then
      if [[ "$STRICT" == "1" ]]; then
        record_result fail "AC-OVR-025" "python3 is required for JSON report formatting"
      else
        record_result skip "AC-OVR-025" "python3 is not installed; cannot build JSON report"
      fi
    else
      record_result pass "AC-OVR-025" "JSON reporting dependencies present"
    fi
  else
    record_result skip "AC-OVR-025" "--json flag not requested; skip strict JSON contract check"
  fi

  run_negative_control_check

  return 0
}

run_runtime_checks() {
  local missing_tools=()
  if ! command -v kubectl >/dev/null 2>&1; then
    missing_tools+=("kubectl")
  fi
  if ! command -v gcloud >/dev/null 2>&1; then
    missing_tools+=("gcloud")
  fi

  if [[ "${#missing_tools[@]}" -gt 0 ]]; then
    if [[ "$STRICT" == "1" ]]; then
      record_result fail "AC-OVR-027" "Missing runtime tools: ${missing_tools[*]}"
    else
      record_result skip "AC-OVR-027" "Missing runtime tools: ${missing_tools[*]}"
    fi
    return 0
  fi

  record_result pass "AC-OVR-027" "kubectl and gcloud are available"

  set +e
  if command -v timeout >/dev/null 2>&1; then
    timeout "$RUNTIME_CMD_TIMEOUT" kubectl_cmd cluster-info >/dev/null 2>&1
  else
    kubectl_cmd cluster-info >/dev/null 2>&1
  fi
  if [[ $? -eq 0 ]]; then
    record_result pass "AC-OVR-027" "kubectl cluster access succeeds"
  else
    if [[ "$STRICT" == "1" ]]; then
      record_result fail "AC-OVR-027" "kubectl cannot reach cluster"
    else
      record_result skip "AC-OVR-027" "kubectl cannot reach cluster"
    fi
  fi

  local active_account=""
  if command -v timeout >/dev/null 2>&1; then
    active_account="$(timeout "$RUNTIME_CMD_TIMEOUT" gcloud auth list --filter='status:ACTIVE' --format='value(account)' 2>/dev/null || true)"
  else
    active_account="$(gcloud auth list --filter='status:ACTIVE' --format='value(account)' 2>/dev/null || true)"
  fi
  if [[ -n "$active_account" ]]; then
    record_result pass "AC-OVR-027" "gcloud has an active authenticated account"
  else
    if [[ "$STRICT" == "1" ]]; then
      record_result fail "AC-OVR-027" "gcloud has no active authenticated account"
    else
      record_result skip "AC-OVR-027" "gcloud has no active authenticated account"
    fi
  fi
  set -e

  # AC-OVR-016 prerequisite: LMS/CMS metrics endpoints must be healthy.
  set +e
  local lms_metrics_code cms_metrics_code
  if command -v timeout >/dev/null 2>&1; then
    lms_metrics_code="$(timeout "$RUNTIME_CMD_TIMEOUT" kubectl_cmd exec -n "$APP_NAMESPACE" deploy/lms -- curl -s -o /dev/null -w '%{http_code}' localhost:8000/metrics 2>/dev/null || echo "000")"
    cms_metrics_code="$(timeout "$RUNTIME_CMD_TIMEOUT" kubectl_cmd exec -n "$APP_NAMESPACE" deploy/cms -- curl -s -o /dev/null -w '%{http_code}' localhost:8000/metrics 2>/dev/null || echo "000")"
  else
    lms_metrics_code="$(kubectl_cmd exec -n "$APP_NAMESPACE" deploy/lms -- curl -s -o /dev/null -w '%{http_code}' localhost:8000/metrics 2>/dev/null || echo "000")"
    cms_metrics_code="$(kubectl_cmd exec -n "$APP_NAMESPACE" deploy/cms -- curl -s -o /dev/null -w '%{http_code}' localhost:8000/metrics 2>/dev/null || echo "000")"
  fi
  set -e

  if [[ "$lms_metrics_code" == "200" ]]; then
    record_result pass "AC-OVR-016" "LMS /metrics returned 200"
  else
    record_result fail "AC-OVR-016" "LMS /metrics returned ${lms_metrics_code} (expected 200)"
  fi

  if [[ "$cms_metrics_code" == "200" ]]; then
    record_result pass "AC-OVR-016" "CMS /metrics returned 200"
  else
    record_result fail "AC-OVR-016" "CMS /metrics returned ${cms_metrics_code} (expected 200)"
  fi

  run_script "AC-OVR-026" "$AUDIT_SCRIPT" "--mode runtime"
  run_script "AC-OVR-026" "$RUNTIME_SCRIPT"
}

if [[ "$MODE" == "local" || "$MODE" == "all" ]]; then
  run_local_checks
fi

if [[ "$MODE" == "runtime" || "$MODE" == "all" ]]; then
  run_runtime_checks
fi

TOTAL=$((PASS + FAIL + SKIP))

if [[ "$JSON_OUT" -eq 1 ]]; then
  if command -v python3 >/dev/null 2>&1; then
    python3 - "$MODE" "$STRICT" "$TOTAL" "$PASS" "$FAIL" "$SKIP" < "$RESULTS_FILE" <<'PY'
import json
import sys
from datetime import datetime

mode = sys.argv[1]
strict = bool(int(sys.argv[2]))
pass_count = int(sys.argv[4])
fail_count = int(sys.argv[5])
skip_count = int(sys.argv[6])

checks = []
for line in sys.stdin:
    line = line.rstrip("\n")
    if not line.strip():
        continue
    parts = line.split("\t", 2)
    if len(parts) < 3:
        continue
    status, check_id, msg = parts
    checks.append({"id": check_id, "status": status, "message": msg})

print(json.dumps({
    "generated_at": datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ"),
    "mode": mode,
    "strict": strict,
    "summary": {
        "pass": pass_count,
        "fail": fail_count,
        "skip": skip_count,
        "total": len(checks),
    },
    "checks": checks,
}, indent=2, sort_keys=False))
PY
  else
    echo '{'
    echo '  "generated_at": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'",'
    echo '  "mode": "'$MODE'",'
    echo '  "strict": '$([[ "$STRICT" == "1" ]] && echo true || echo false)','
    echo '  "summary": {'
    echo '    "pass": '$PASS','
    echo '    "fail": '$FAIL','
    echo '    "skip": '$SKIP','
    echo '    "total": '$TOTAL
    echo '  },'
    echo '  "checks": []'
    echo '}'
  fi
else
  echo "=== Observability Compliance Report ==="
  echo "Mode  : $MODE"
  echo "Strict: $STRICT"
  echo "Pass  : $PASS"
  echo "Fail  : $FAIL"
  echo "Skip  : $SKIP"
  echo "Total : $TOTAL"
  echo
  while IFS=$'\t' read -r status check_id msg; do
    [[ -z "$status" ]] && continue
    printf '[%s] %s — %s\n' "$status" "$check_id" "$msg"
  done < "$RESULTS_FILE"
fi

if [[ -n "$EVIDENCE_FILE" ]]; then
  mkdir -p "$(dirname "$EVIDENCE_FILE")"
  {
    echo "# Observability Compliance Evidence"
    echo ""
    echo "- generated_at: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "- mode: $MODE"
    echo "- strict: $STRICT"
    echo "- app_namespace: $APP_NAMESPACE"
    echo ""
    echo "## Summary"
    echo ""
    echo "- pass: $PASS"
    echo "- fail: $FAIL"
    echo "- skip: $SKIP"
    echo "- total: $TOTAL"
    echo ""
    echo "## Failed Checks"
    echo ""
    if awk -F $'\t' '$1=="fail"{exit 0} END{exit 1}' "$RESULTS_FILE"; then
      awk -F $'\t' '$1=="fail"{printf("- %s: %s\n", $2, $3)}' "$RESULTS_FILE"
    else
      echo "- none"
    fi
  } >"$EVIDENCE_FILE"
fi

if [[ $FAIL -gt 0 ]]; then
  exit 1
fi

exit 0
