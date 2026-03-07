#!/usr/bin/env bash
# emit-proof-envelope.sh — Emit a GitOps-conformant evidence envelope
#
# Wraps an LMS proof artifact (release-gate, migration-proof, runtime-smoke)
# into the standard evidence envelope format (schema v1) expected by
# bbi-infrastructure's gitops-ops promote workflow.
#
# Usage:
#   scripts/release/emit-proof-envelope.sh --concern <concern> [--lane <lane>] [options]
#
# Concerns:
#   release-gate     Run release-gate.sh and wrap output
#   migration-proof  Run smoke-after-migrate.sh and wrap output
#   runtime-smoke    Run smoke-after-migrate.sh with --domain and wrap output
#   aggregate        Run all three and produce a combined envelope
#
# Options:
#   --lane <lane>      Canonical lane: dev|staging|prod (default: dev)
#   --dry-run          Mark envelope as dry-run
#   --ci-run-id <id>   GitHub Actions run ID (default: "local")
#   --output-dir <dir> Write envelopes here (default: var/proof)
#   --format json      JSON output only (no human-readable text)
#   --skip-cluster     Pass to release-gate.sh (skip live cluster checks)
#   --namespace <ns>   Kubernetes namespace for smoke checks
#   --domain <domain>  Domain for external smoke checks
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Source lane normalization
# shellcheck source=../lib/lane-normalize.sh
source "$REPO_ROOT/scripts/lib/lane-normalize.sh"

CONCERN=""
LANE="dev"
DRY_RUN=false
CI_RUN_ID="${GITHUB_RUN_ID:-local}"
OUTPUT_DIR="$REPO_ROOT/var/proof"
FORMAT="text"
SKIP_CLUSTER=false
NAMESPACE=""
DOMAIN=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --concern)      CONCERN="${2:?--concern requires a value}"; shift 2 ;;
    --lane)         LANE="$(normalize_lane_to_canonical "${2:?--lane requires a value}")"; shift 2 ;;
    --dry-run)      DRY_RUN=true; shift ;;
    --ci-run-id)    CI_RUN_ID="${2:?--ci-run-id requires a value}"; shift 2 ;;
    --output-dir)   OUTPUT_DIR="${2:?--output-dir requires a value}"; shift 2 ;;
    --format)       FORMAT="${2:?--format requires a value}"; shift 2 ;;
    --skip-cluster) SKIP_CLUSTER=true; shift ;;
    --namespace)    NAMESPACE="${2:?--namespace requires a value}"; shift 2 ;;
    --domain)       DOMAIN="${2:?--domain requires a value}"; shift 2 ;;
    -h|--help)
      sed -n '2,/^set -euo/p' "$0" | head -n -1 | sed 's/^# \?//'
      exit 0 ;;
    *) echo "Unknown flag: $1" >&2; exit 1 ;;
  esac
done

if [[ -z "$CONCERN" ]]; then
  echo "Error: --concern is required (release-gate|migration-proof|runtime-smoke|aggregate)" >&2
  exit 1
fi

# Resolve namespace from lane if not explicitly set
if [[ -z "$NAMESPACE" ]]; then
  NAMESPACE="$(normalize_lane_to_namespace "$LANE" 2>/dev/null || echo "mereka-lms")"
fi

# Resolve overlay from lane
OVERLAY_DIR="$(normalize_lane_to_overlay "$LANE" 2>/dev/null || echo "rke2-nonprod")"
OVERLAY="deploy/k8s/overlays/$OVERLAY_DIR"

mkdir -p "$OUTPUT_DIR"
COMMIT_SHA="$(git -C "$REPO_ROOT" rev-parse HEAD 2>/dev/null || echo "unknown")"
TIMESTAMP="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

# Emit a single evidence envelope
emit_envelope() {
  local concern="$1"
  local result="$2"
  local details="$3"
  local duration_ms="$4"
  local warnings="${5:-[]}"
  local error="${6:-}"
  local output_file="$OUTPUT_DIR/${concern}.json"

  local error_field=""
  if [[ -n "$error" ]]; then
    error_field="\"error\": $(python3 -c "import json; print(json.dumps('$error'))"),"
  fi

  cat > "$output_file" <<ENVELOPE
{
  "schema_version": "1",
  "concern": "$concern",
  "timestamp": "$TIMESTAMP",
  "commit_sha": "$COMMIT_SHA",
  "ci_run_id": "$CI_RUN_ID",
  "lane": "$LANE",
  "dry_run": $DRY_RUN,
  "result": "$result",
  "details": $details,
  ${error_field}
  "warnings": $warnings,
  "duration_ms": $duration_ms
}
ENVELOPE

  if [[ "$FORMAT" == "json" ]]; then
    cat "$output_file"
  else
    echo "  Wrote: $output_file ($result)"
  fi
}

# Run a script and capture its output + timing
run_and_capture() {
  local script="$1"
  shift
  local start_ms
  start_ms=$(date +%s%3N 2>/dev/null || python3 -c "import time; print(int(time.time()*1000))")

  local output exit_code
  output="$("$script" "$@" 2>&1)" && exit_code=0 || exit_code=$?

  local end_ms
  end_ms=$(date +%s%3N 2>/dev/null || python3 -c "import time; print(int(time.time()*1000))")
  local duration_ms=$((end_ms - start_ms))

  echo "$exit_code|$duration_ms|$output"
}

# ── Concern: release-gate ──────────────────────────────────────────────────
run_release_gate() {
  local args=("--overlay" "$OVERLAY")
  [[ "$SKIP_CLUSTER" == "true" ]] && args+=("--skip-cluster")

  [[ "$FORMAT" != "json" ]] && echo "Running release-gate (overlay: $OVERLAY)..."

  local raw
  raw="$(run_and_capture "$REPO_ROOT/scripts/release/release-gate.sh" "${args[@]}")"
  local exit_code="${raw%%|*}"
  raw="${raw#*|}"
  local duration_ms="${raw%%|*}"
  local output="${raw#*|}"

  local result="pass"
  [[ "$exit_code" -ne 0 ]] && result="fail"

  # Parse the proof artifact that release-gate.sh writes
  local proof_file="$REPO_ROOT/var/proof/release-gate.json"
  local details="{}"
  if [[ -f "$proof_file" ]]; then
    details="$(cat "$proof_file")"
  fi

  emit_envelope "release-gate" "$result" "$details" "$duration_ms"
}

# ── Concern: migration-proof ──────────────────────────────────────────────
run_migration_proof() {
  local args=("--namespace" "$NAMESPACE" "--json")

  [[ "$FORMAT" != "json" ]] && echo "Running migration-proof (namespace: $NAMESPACE)..."

  local raw
  raw="$(run_and_capture "$REPO_ROOT/scripts/release/smoke-after-migrate.sh" "${args[@]}")"
  local exit_code="${raw%%|*}"
  raw="${raw#*|}"
  local duration_ms="${raw%%|*}"
  local output="${raw#*|}"

  local result="pass"
  [[ "$exit_code" -ne 0 ]] && result="fail"

  # The --json output from smoke-after-migrate.sh is the details
  local details="{}"
  # Try to extract JSON from the output
  local json_line
  json_line="$(echo "$output" | grep -E '^\s*\{' | tail -1 || echo "")"
  if [[ -n "$json_line" ]] && python3 -c "import json; json.loads('''$json_line''')" 2>/dev/null; then
    details="$json_line"
  else
    details="{\"raw_output\": $(python3 -c "import json,sys; print(json.dumps(sys.stdin.read()))" <<< "$output")}"
  fi

  emit_envelope "migration-proof" "$result" "$details" "$duration_ms"
}

# ── Concern: runtime-smoke ─────────────────────────────────────────────────
run_runtime_smoke() {
  local args=("--namespace" "$NAMESPACE" "--json")
  [[ -n "$DOMAIN" ]] && args+=("--domain" "$DOMAIN")

  [[ "$FORMAT" != "json" ]] && echo "Running runtime-smoke (namespace: $NAMESPACE, domain: ${DOMAIN:-none})..."

  local raw
  raw="$(run_and_capture "$REPO_ROOT/scripts/release/smoke-after-migrate.sh" "${args[@]}")"
  local exit_code="${raw%%|*}"
  raw="${raw#*|}"
  local duration_ms="${raw%%|*}"
  local output="${raw#*|}"

  local result="pass"
  [[ "$exit_code" -ne 0 ]] && result="fail"

  local details="{}"
  local json_line
  json_line="$(echo "$output" | grep -E '^\s*\{' | tail -1 || echo "")"
  if [[ -n "$json_line" ]] && python3 -c "import json; json.loads('''$json_line''')" 2>/dev/null; then
    details="$json_line"
  else
    details="{\"raw_output\": $(python3 -c "import json,sys; print(json.dumps(sys.stdin.read()))" <<< "$output")}"
  fi

  emit_envelope "runtime-smoke" "$result" "$details" "$duration_ms"
}

# ── Concern: aggregate ─────────────────────────────────────────────────────
run_aggregate() {
  [[ "$FORMAT" != "json" ]] && echo "Running aggregate proof (all concerns)..."
  [[ "$FORMAT" != "json" ]] && echo ""

  run_release_gate
  [[ "$FORMAT" != "json" ]] && echo ""

  if [[ "$SKIP_CLUSTER" == "true" ]]; then
    [[ "$FORMAT" != "json" ]] && echo "Skipping migration-proof and runtime-smoke (--skip-cluster)"
    emit_envelope "migration-proof" "pass" '{"skipped": true, "reason": "skip-cluster"}' 0
    emit_envelope "runtime-smoke" "pass" '{"skipped": true, "reason": "skip-cluster"}' 0
  else
    run_migration_proof
    [[ "$FORMAT" != "json" ]] && echo ""
    run_runtime_smoke
  fi

  [[ "$FORMAT" != "json" ]] && echo ""

  # Build aggregate summary
  local total_result="pass"
  for f in "$OUTPUT_DIR"/release-gate.json "$OUTPUT_DIR"/migration-proof.json "$OUTPUT_DIR"/runtime-smoke.json; do
    if [[ -f "$f" ]]; then
      local r
      r="$(python3 -c "import json; print(json.load(open('$f'))['result'])" 2>/dev/null || echo "unknown")"
      if [[ "$r" == "fail" ]]; then
        total_result="fail"
      fi
    fi
  done

  local aggregate_details
  aggregate_details="$(python3 -c "
import json, os
output_dir = '$OUTPUT_DIR'
concerns = {}
for fname in ('release-gate.json', 'migration-proof.json', 'runtime-smoke.json'):
    fpath = os.path.join(output_dir, fname)
    if os.path.isfile(fpath):
        with open(fpath) as f:
            data = json.load(f)
        concerns[data['concern']] = {
            'result': data['result'],
            'duration_ms': data['duration_ms']
        }
print(json.dumps({'concerns': concerns}))
")"

  emit_envelope "aggregate" "$total_result" "$aggregate_details" 0

  if [[ "$FORMAT" != "json" ]]; then
    echo "Aggregate result: $total_result"
    echo "Proof artifacts in: $OUTPUT_DIR/"
    ls -la "$OUTPUT_DIR"/*.json 2>/dev/null
  fi
}

# ── Main dispatch ──────────────────────────────────────────────────────────
case "$CONCERN" in
  release-gate)     run_release_gate ;;
  migration-proof)  run_migration_proof ;;
  runtime-smoke)    run_runtime_smoke ;;
  aggregate)        run_aggregate ;;
  *)
    echo "Unknown concern: $CONCERN (expected: release-gate|migration-proof|runtime-smoke|aggregate)" >&2
    exit 1 ;;
esac
