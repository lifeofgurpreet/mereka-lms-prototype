#!/usr/bin/env bash
# @covers AC-009
# @spec: disaster-recovery-business-continuity_spec.md
# Build a deterministic DR evidence bundle for audits/incidents.
#
# Usage:
#   ./scripts/qa/build-dr-evidence-bundle.sh
#   STRICT_RUNTIME=1 ./scripts/qa/build-dr-evidence-bundle.sh --tar
#   ./scripts/qa/build-dr-evidence-bundle.sh --out-dir var/dr-evidence/manual-run
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

K8S_CONTEXT="${K8S_CONTEXT:-${K8S_CONTEXT_PROD:-rke2-prod}}"
VELERO_NS="${VELERO_NS:-velero}"
STRICT_RUNTIME="${STRICT_RUNTIME:-1}"
TAR_OUTPUT=0
STAMP="$(date -u +%Y%m%d-%H%M%S)"
OUT_DIR="${OUT_DIR:-var/dr-evidence/${STAMP}}"

usage() {
  cat <<'USAGE'
Usage: ./scripts/qa/build-dr-evidence-bundle.sh [--out-dir PATH] [--tar]
Env:
  STRICT_RUNTIME=1  Fail if runtime checks are unavailable
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --out-dir) OUT_DIR="${2:-}"; shift 2 ;;
    --tar) TAR_OUTPUT=1; shift ;;
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
manifest_files=()

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Missing required command: $1" >&2
    exit 2
  }
}

record_manifest_artifact() {
  local path="$1"
  local required="$2"
  local purpose="$3"
  local file_path
  local rel_path
  local missing=false
  local sha=""
  local size=0

  file_path="$REPO_ROOT/$path"
  [[ -e "$path" ]] && file_path="$path"
  if [[ -f "$file_path" ]]; then
    sha="$(sha256sum "$file_path" | awk '{print $1}')"
    size="$(wc -c <"$file_path")"
  else
    missing=true
    if [[ "$required" == "true" ]]; then
      failures=$((failures + 1))
    fi
  fi

  rel_path="${path#${REPO_ROOT}/}"
  rel_path="${rel_path#./}"

  manifest_files+=("$(jq -n \
    --arg path "$rel_path" \
    --argjson required "$required" \
    --arg purpose "$purpose" \
    --arg json_size "$size" \
    --arg sha256 "$sha" \
    --argjson missing "$missing" \
    '{path: $path, required: $required, purpose: $purpose, size_bytes: ($json_size | tonumber), sha256: $sha256, missing: $missing}')")

  if [[ "$missing" == "true" ]]; then
    if [[ "$required" == "true" ]]; then
      echo "DR manifest: missing required artifact $path"
    else
      echo "DR manifest: missing optional artifact $path"
    fi
  fi
}

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

run_json_check() {
  local name="$1"; shift
  local json_file="$1"; shift
  local log_file="$OUT_DIR/${name// /-}.log"
  local rc

  set +e
  "$@" >"$json_file" 2>"$log_file"
  rc=$?
  set -e

  if [[ "$rc" -eq 0 ]]; then
    if command -v jq >/dev/null 2>&1; then
      if jq -e . "$json_file" >/dev/null 2>&1; then
        echo "OK   $name"
      else
        failures=$((failures + 1))
        echo "FAIL $name"
        echo "  Captured JSON is invalid: $json_file"
      fi
    else
      echo "OK   $name"
    fi
  else
    failures=$((failures + 1))
    echo "FAIL $name"
    tail -n 40 "$log_file" | sed 's/^/  /'
  fi
}

require_cmd jq
require_cmd sha256sum
require_cmd awk

echo "Build: DR evidence bundle"
echo "  out_dir:        $OUT_DIR"
echo "  context:        $K8S_CONTEXT"
echo "  velero_ns:      $VELERO_NS"
echo "  strict_runtime: $STRICT_RUNTIME"
echo ""

run_json_check "audit-velero-json" "$OUT_DIR/audit-velero.json" \
  env STRICT_RUNTIME="$STRICT_RUNTIME" K8S_CONTEXT="$K8S_CONTEXT" VELERO_NS="$VELERO_NS" \
  ./scripts/qa/audit-velero.sh --context "$K8S_CONTEXT" --velero-namespace "$VELERO_NS" --app-namespace mereka-lms --json
record_manifest_artifact "$OUT_DIR/audit-velero.json" true "Velero runtime audit output"
record_manifest_artifact "$OUT_DIR/audit-velero-json.log" false "Command log: audit-velero"

run_json_check "audit-velero-alert-pipeline-json" "$OUT_DIR/audit-velero-alert-pipeline.json" \
  env STRICT_RUNTIME="$STRICT_RUNTIME" K8S_CONTEXT="$K8S_CONTEXT" VELERO_NS="$VELERO_NS" \
  ./scripts/qa/audit-velero-alert-pipeline.sh --json
record_manifest_artifact "$OUT_DIR/audit-velero-alert-pipeline.json" true "Velero alert pipeline audit output"
record_manifest_artifact "$OUT_DIR/audit-velero-alert-pipeline-json.log" false "Command log: audit-velero-alert-pipeline"

run_check "observability-first-class-runtime" \
  env OBSERVABILITY_EVIDENCE_DIR="$OUT_DIR/observability-runtime" \
  OBSERVABILITY_K8S_CONTEXT="$K8S_CONTEXT" \
  OBSERVABILITY_GCP_PROJECT="${GCP_PROJECT:-mereka-lms}" \
  OBSERVABILITY_ENV_LABEL="${OBSERVABILITY_ENV_LABEL:-prod}" \
  OBSERVABILITY_DISPATCH_PROFILE="${OBSERVABILITY_DISPATCH_PROFILE:-prod}" \
  ./scripts/qa/run-observability-first-class.sh --mode runtime --strict
record_manifest_artifact "$OUT_DIR/observability-first-class-runtime.log" false "Command log: run-observability-first-class"

if [[ -f "$OUT_DIR/observability-runtime/observability-compliance-runtime.json" ]]; then
  cp "$OUT_DIR/observability-runtime/observability-compliance-runtime.json" \
    "$OUT_DIR/observability-compliance-runtime.json"
  cp "$OUT_DIR/observability-runtime/observability-compliance-runtime.json" \
    "$OUT_DIR/audit-observability-runtime.json"
else
  echo "FAIL observability-first-class-runtime: missing observability-compliance-runtime.json output"
fi
record_manifest_artifact "$OUT_DIR/observability-compliance-runtime.json" true "Runtime observability compliance output"
record_manifest_artifact "$OUT_DIR/audit-observability-runtime.json" true "Runtime observability compliance copy"

if [[ -f "$OUT_DIR/observability-runtime/observability-first-class-runtime-evidence-index.json" ]]; then
  cp "$OUT_DIR/observability-runtime/observability-first-class-runtime-evidence-index.json" \
    "$OUT_DIR/observability-first-class-runtime-evidence-index.json"
else
  echo "FAIL observability-first-class-runtime: missing observability-first-class-runtime-evidence-index.json output"
fi
record_manifest_artifact "$OUT_DIR/observability-first-class-runtime-evidence-index.json" true "Observability runtime evidence index"

if [[ -f "$OUT_DIR/observability-runtime/observability-correlation-headers-runtime.txt" ]]; then
  cp "$OUT_DIR/observability-runtime/observability-correlation-headers-runtime.txt" \
    "$OUT_DIR/observability-correlation-headers-runtime.txt"
else
  echo "FAIL observability-first-class-runtime: missing observability-correlation-headers-runtime.txt output"
fi
record_manifest_artifact "$OUT_DIR/observability-correlation-headers-runtime.txt" true "Observability runtime correlation header propagation output"

run_check "verify-observability-evidence-identity" \
  ./scripts/qa/verify-observability-evidence-identity.sh --dir "$OUT_DIR/observability-runtime"
record_manifest_artifact "$OUT_DIR/verify-observability-evidence-identity.log" false "Command log: observability evidence identity"

run_check "collect-velero-evidence" \
  env K8S_CONTEXT="$K8S_CONTEXT" VELERO_NS="$VELERO_NS" OUT_DIR="$OUT_DIR/velero" \
  ./scripts/qa/collect-velero-evidence.sh
record_manifest_artifact "$OUT_DIR/collect-velero-evidence.log" false "Command log: collect-velero-evidence"
record_manifest_artifact "$OUT_DIR/velero/collect-velero-evidence.json" false "Velero evidence output"

run_check "critical-backup-pvc-inventory" \
  env K8S_CONTEXT="$K8S_CONTEXT" VELERO_NS="$VELERO_NS" \
  ./scripts/qa/list-critical-backup-pvcs.sh --context "$K8S_CONTEXT" --velero-namespace "$VELERO_NS"
record_manifest_artifact "$OUT_DIR/critical-backup-pvc-inventory.log" false "Command log: critical-backup-pvcs"

cat >"$OUT_DIR/manifest.txt" <<MANIFEST
generated_at_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)
git_commit=$(git rev-parse --short HEAD)
git_branch=$(git branch --show-current)
context=$K8S_CONTEXT
velero_namespace=$VELERO_NS
strict_runtime=$STRICT_RUNTIME
failures=$failures
MANIFEST

artifacts_json="$(printf '%s\n' "${manifest_files[@]}" | jq -s '.')"
cat >"$OUT_DIR/manifest.json" <<MANIFEST
{
  "generated_at_utc": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "git_commit": "$(git rev-parse --short HEAD)",
  "git_branch": "$(git branch --show-current)",
  "context": "$K8S_CONTEXT",
  "velero_namespace": "$VELERO_NS",
  "strict_runtime": "$STRICT_RUNTIME",
  "failures": $failures,
  "artifacts": ${artifacts_json}
}
MANIFEST
record_manifest_artifact "$OUT_DIR/manifest.txt" false "Legacy text manifest"
record_manifest_artifact "$OUT_DIR/manifest.json" true "Structured DR evidence manifest"

# Manifest file itself is included above; if it fails JSON generation, jq above would fail first.

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
