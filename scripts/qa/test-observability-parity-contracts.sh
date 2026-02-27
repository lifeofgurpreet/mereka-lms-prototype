#!/usr/bin/env bash
# Contract tests for observability parity scripts (delta/review/rollup).
#
# Usage:
#   ./scripts/qa/test-observability-parity-contracts.sh
#   ./scripts/qa/test-observability-parity-contracts.sh --fixtures-root scripts/qa/fixtures/observability-parity

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
FIXTURES_ROOT="${REPO_ROOT}/scripts/qa/fixtures/observability-parity"
FAIL_COUNT=0
TOTAL_COUNT=0

usage() {
  cat <<'EOF'
Usage:
  ./scripts/qa/test-observability-parity-contracts.sh [--fixtures-root <path>]
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --fixtures-root)
      FIXTURES_ROOT="${2:-}"
      shift 2
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

if [[ ! -d "$FIXTURES_ROOT" ]]; then
  echo "Fixtures root not found: $FIXTURES_ROOT" >&2
  exit 1
fi

TMP_ROOT="$(mktemp -d -t observability-parity-contracts.XXXXXX)"
trap 'rm -rf "$TMP_ROOT"' EXIT

log_result() {
  local status="$1"
  local name="$2"
  local details="$3"

  TOTAL_COUNT=$((TOTAL_COUNT + 1))
  if [[ "$status" == "PASS" ]]; then
    echo "PASS: $name"
    return
  fi

  echo "FAIL: $name -> $details" >&2
  FAIL_COUNT=$((FAIL_COUNT + 1))
}

run_delta_case() {
  local case_name="$1"
  local env_label="$2"
  local evidence_dir="$3"
  local expect_exit_code="$4"
  local tracing_required="${5:-0}"
  local out_dir="$TMP_ROOT/delta/$case_name/$env_label"
  local out_md="$out_dir/observability-parity-delta.md"
  local out_json="$out_dir/observability-parity-delta.json"
  local observed_status=0
  mkdir -p "$out_dir"

  set +e
  if [[ "$tracing_required" == "1" ]]; then
    OBS_REQUIRE_TRACING_ARTIFACT=1 "$SCRIPT_DIR/build-observability-parity-delta.sh" \
      --env "$env_label" \
      --evidence-dir "$evidence_dir" \
      --out-md "$out_md" \
      --out-json "$out_json" \
      >"$out_dir/stdout.log" \
      2>"$out_dir/stderr.log"
  else
    "$SCRIPT_DIR/build-observability-parity-delta.sh" \
    --env "$env_label" \
    --evidence-dir "$evidence_dir" \
    --out-md "$out_md" \
    --out-json "$out_json" \
    >"$out_dir/stdout.log" \
    2>"$out_dir/stderr.log"
  fi
  observed_status=$?
  set -e

  if [[ "$observed_status" -ne "$expect_exit_code" ]]; then
    log_result FAIL "$case_name($env_label)" "exit_code=$observed_status expected=$expect_exit_code"
    return
  fi

  if [[ "$expect_exit_code" -ne 0 ]]; then
    log_result PASS "$case_name($env_label)" "expected failure observed"
    return
  fi

  if ! command -v jq >/dev/null 2>&1; then
    log_result FAIL "$case_name($env_label)" "jq missing"
    return
  fi

  if ! jq -e . "$out_json" >/dev/null 2>&1; then
    log_result FAIL "$case_name($env_label)" "invalid JSON output"
    return
  fi

  if [[ -s "$out_dir/stderr.log" ]]; then
    # The command is expected to be silent on success.
    if [[ "$case_name" == *"malformed"* ]]; then
      :
    else
      log_result FAIL "$case_name($env_label)" "unexpected stderr output"
      return
    fi
  fi

  log_result PASS "$case_name($env_label)" "ok"
}

run_review_case() {
  local case_name="$1"
  local env_label="$2"
  local delta_json="$3"
  local expect_exit_code="$4"
  local out_dir="$TMP_ROOT/review/$case_name/$env_label"
  local out_md="$out_dir/observability-parity-review.md"
  local observed_status=0
  mkdir -p "$out_dir"

  set +e
  "$SCRIPT_DIR/build-observability-parity-review.sh" \
    --env "$env_label" \
    --delta-json "$delta_json" \
    --out-md "$out_md" \
    >"$out_dir/stdout.log" \
    2>"$out_dir/stderr.log"
  observed_status=$?
  set -e

  if [[ "$observed_status" -ne "$expect_exit_code" ]]; then
    log_result FAIL "$case_name($env_label)" "exit_code=$observed_status expected=$expect_exit_code"
    return
  fi

  if [[ "$expect_exit_code" -ne 0 ]]; then
    log_result PASS "$case_name($env_label)" "expected failure observed"
    return
  fi

  if [[ ! -f "$out_md" ]]; then
    log_result FAIL "$case_name($env_label)" "expected review output missing"
    return
  fi

  if ! grep -q "^# Observability Parity Weekly Review" "$out_md"; then
    log_result FAIL "$case_name($env_label)" "unexpected review markdown format"
    return
  fi

  log_result PASS "$case_name($env_label)" "ok"
}

run_rollup_case() {
  local case_name="$1"
  local artifacts_dir="$2"
  local expect_exit_code="$3"
  local out_dir="$TMP_ROOT/rollup/$case_name"
  local out_md="$out_dir/observability-parity-rollup.md"
  local out_json="$out_dir/observability-parity-rollup.json"
  local observed_status=0
  mkdir -p "$out_dir"

  local extra_args=()
  if [[ "$case_name" == "valid-no-skip-enforced" ]]; then
    extra_args+=("--require-no-skips")
  fi

  set +e
  "$SCRIPT_DIR/build-observability-parity-rollup.sh" \
    --artifacts-dir "$artifacts_dir" \
    --out-md "$out_md" \
    --out-json "$out_json" \
    "${extra_args[@]}" \
    >"$out_dir/stdout.log" \
    2>"$out_dir/stderr.log"
  observed_status=$?
  set -e

  if [[ "$observed_status" -ne "$expect_exit_code" ]]; then
    log_result FAIL "$case_name" "exit_code=$observed_status expected=$expect_exit_code"
    return
  fi

  if [[ "$expect_exit_code" -ne 0 ]]; then
    log_result PASS "$case_name" "expected failure observed"
    return
  fi

  if ! command -v jq >/dev/null 2>&1; then
    log_result FAIL "$case_name" "jq missing"
    return
  fi

  if ! jq -e '.summary.pass >= 0' "$out_json" >/dev/null 2>&1; then
    log_result FAIL "$case_name" "invalid rollup JSON"
    return
  fi

  if ! grep -q "^# Observability Parity Rollup" "$out_md"; then
    log_result FAIL "$case_name" "unexpected rollup markdown format"
    return
  fi

  log_result PASS "$case_name" "ok"
}

run_identity_case() {
  local case_name="$1"
  local dir="$2"
  local expect_exit_code="$3"
  local tracing_required="${4:-0}"
  local observed_status=0
  local out_dir="$TMP_ROOT/identity/$case_name"
  mkdir -p "$out_dir"

  set +e
  if [[ "$tracing_required" == "1" ]]; then
    OBS_EVIDENCE_REQUIRE_TRACING_IDENTITY=1 "$SCRIPT_DIR/verify-observability-evidence-identity.sh" \
    --dir "$dir" \
    >"$out_dir/stdout.log" \
    2>"$out_dir/stderr.log"
  else
    "$SCRIPT_DIR/verify-observability-evidence-identity.sh" \
    --dir "$dir" \
    >"$out_dir/stdout.log" \
    2>"$out_dir/stderr.log"
  fi
  observed_status=$?
  set -e

  if [[ "$observed_status" -ne "$expect_exit_code" ]]; then
    log_result FAIL "$case_name(identity)" "exit_code=$observed_status expected=$expect_exit_code"
    return
  fi

  if [[ "$expect_exit_code" -ne 0 ]]; then
    log_result PASS "$case_name(identity)" "expected failure observed"
    return
  fi

  log_result PASS "$case_name(identity)" "ok"
}

run_correlation_header_case() {
  local case_name="$1"
  local expect_exit_code="$2"
  local out_dir="$TMP_ROOT/correlation-header/$case_name"
  local observed_status=0
  mkdir -p "$out_dir"

  set +e
  "$SCRIPT_DIR/test-verify-correlation-header-propagation.sh" \
    >"$out_dir/stdout.log" \
    2>"$out_dir/stderr.log"
  observed_status=$?
  set -e

  if [[ "$observed_status" -ne "$expect_exit_code" ]]; then
    log_result FAIL "$case_name(correlation-header)" "exit_code=$observed_status expected=$expect_exit_code"
    return
  fi

  log_result PASS "$case_name(correlation-header)" "ok"
}

run_lane_contract_case() {
  local case_name="$1"
  local env_label="$2"
  local dispatch_profile="$3"
  local k8s_context="$4"
  local gcp_project="$5"
  local expect_exit_code="$6"
  local out_dir="$TMP_ROOT/lane-contract/$case_name"
  local out_log="$out_dir/stdout.log"
  local err_log="$out_dir/stderr.log"
  local observed_status=0
  mkdir -p "$out_dir"

  set +e
  "$SCRIPT_DIR/verify-observability-parity-lane-contract.sh" \
    --env-label "$env_label" \
    --dispatch-profile "$dispatch_profile" \
    --k8s-context "$k8s_context" \
    --gcp-project "$gcp_project" \
    >"$out_log" 2>"$err_log"
  observed_status=$?
  set -e

  if [[ "$observed_status" -ne "$expect_exit_code" ]]; then
    log_result FAIL "$case_name(lane-contract)" "exit_code=$observed_status expected=$expect_exit_code"
    return
  fi

  if [[ "$expect_exit_code" -ne 0 && ! -s "$err_log" ]]; then
    log_result FAIL "$case_name(lane-contract)" "expected failure output"
    return
  fi

  log_result PASS "$case_name(lane-contract)" "ok"
}

run_delta_case "valid-dev" "dev" "$FIXTURES_ROOT/valid/delta/dev" 0
run_delta_case "valid-nonprod" "nonprod" "$FIXTURES_ROOT/valid/delta/nonprod" 0
run_delta_case "valid-prod" "prod" "$FIXTURES_ROOT/valid/delta/prod" 0
run_delta_case "invalid-nonprod-tracing-required-missing" "nonprod" "$FIXTURES_ROOT/valid/delta/nonprod" 1 1
run_delta_case "invalid-missing-files" "dev" "$FIXTURES_ROOT/malformed/delta-missing-files/dev" 1
run_delta_case "invalid-missing-correlation" "dev" "$FIXTURES_ROOT/malformed/delta-missing-correlation/dev" 1
run_delta_case "invalid-correlation-status" "dev" "$FIXTURES_ROOT/malformed/delta-invalid-correlation-status/dev" 1
run_delta_case "invalid-correlation-status-substring" "dev" "$FIXTURES_ROOT/malformed/delta-invalid-correlation-status-word/dev" 1
run_delta_case "invalid-correlation-empty" "dev" "$FIXTURES_ROOT/malformed/delta-invalid-correlation-empty/dev" 1
run_delta_case "invalid-correlation-lowercase" "dev" "$FIXTURES_ROOT/malformed/delta-invalid-correlation-lowercase/dev" 1
run_delta_case "invalid-correlation-missing-headers" "dev" "$FIXTURES_ROOT/malformed/delta-invalid-correlation-missing-headers/dev" 1
run_delta_case "valid-ansi" "dev" "$FIXTURES_ROOT/valid/delta-ansi/dev" 0
run_delta_case "invalid-identity-mismatch" "nonprod" "$FIXTURES_ROOT/malformed/delta-identity-mismatch/nonprod" 1

run_review_case "valid" "dev" "$FIXTURES_ROOT/valid/review/dev/observability-parity-delta.json" 0
run_review_case "valid" "nonprod" "$FIXTURES_ROOT/valid/review/nonprod/observability-parity-delta.json" 0
run_review_case "valid" "prod" "$FIXTURES_ROOT/valid/review/prod/observability-parity-delta.json" 0
run_review_case "invalid-bad-json" "dev" "$FIXTURES_ROOT/malformed/review/bad-json/dev/observability-parity-delta.json" 1

run_rollup_case "valid" "$FIXTURES_ROOT/valid/rollup" 0
run_rollup_case "valid-no-skip-enforced" "$FIXTURES_ROOT/valid/rollup" 0
run_rollup_case "invalid-missing-artifacts" "$FIXTURES_ROOT/malformed/rollup-missing-parity-dev" 1

run_identity_case "valid-dev" "$FIXTURES_ROOT/valid/delta/dev" 0
run_identity_case "valid-nonprod-tracing-required-missing" "$FIXTURES_ROOT/valid/delta/nonprod" 1 1
run_identity_case "invalid-nonprod-tracing-identity-mismatch" "$FIXTURES_ROOT/malformed/delta-tracing-identity-mismatch/nonprod" 1 1
run_identity_case "invalid-missing-correlation" "$FIXTURES_ROOT/malformed/delta-missing-correlation/dev" 1
run_identity_case "invalid-correlation-status" "$FIXTURES_ROOT/malformed/delta-invalid-correlation-status/dev" 1
run_identity_case "invalid-correlation-status-substring" "$FIXTURES_ROOT/malformed/delta-invalid-correlation-status-word/dev" 1
run_identity_case "invalid-correlation-empty" "$FIXTURES_ROOT/malformed/delta-invalid-correlation-empty/dev" 1
run_identity_case "invalid-correlation-lowercase" "$FIXTURES_ROOT/malformed/delta-invalid-correlation-lowercase/dev" 1
run_identity_case "invalid-correlation-missing-headers" "$FIXTURES_ROOT/malformed/delta-invalid-correlation-missing-headers/dev" 1
run_identity_case "invalid-correlation-missing-identity" "$FIXTURES_ROOT/malformed/delta-invalid-correlation-missing-identity/dev" 1
run_identity_case "invalid-correlation-identity-mismatch" "$FIXTURES_ROOT/malformed/delta-invalid-correlation-identity-mismatch/dev" 1

run_correlation_header_case "verify-correlation-header-propagation" 0

run_lane_contract_case "valid-dev" "dev" "nonprod" "rke2-nonprod" "mereka-lms" 0
run_lane_contract_case "valid-prod" "prod" "prod" "gke_bbi-k8_asia-southeast1-c_bbi-k8-cluster" "mereka-lms" 0
run_lane_contract_case "invalid-dev-profile" "dev" "prod" "rke2-nonprod" "mereka-lms" 1
run_lane_contract_case "invalid-missing-context" "nonprod" "nonprod" "" "mereka-lms" 1
run_lane_contract_case "invalid-missing-gcp" "nonprod" "nonprod" "rke2-nonprod" "" 1

if [[ "$FAIL_COUNT" -gt 0 ]]; then
  echo "Result: FAIL ($FAIL_COUNT of $TOTAL_COUNT checks failed)" >&2
  exit 1
fi

echo "Result: PASS ($TOTAL_COUNT checks passed)"
exit 0
