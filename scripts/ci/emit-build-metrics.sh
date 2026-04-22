#!/usr/bin/env bash
# emit-build-metrics.sh — Parse buildx metadata + log for cache and layer metrics.
#
# Reads buildx metadata JSON and/or a buildx build log and extracts:
#   - Cache source facts (which types were found, what digests were imported)
#   - Cache export result (success flag, exported digest)
#   - Layer reuse count vs total count
#   - Build duration in seconds
#
# Outputs:
#   - Appends a markdown table to $GITHUB_STEP_SUMMARY (when set)
#   - Writes build-metrics-<image-family>.json in the working directory
#
# Usage:
#   emit-build-metrics.sh \
#     --metadata-file <path> \
#     --log-file <path> \
#     --image-family openedx \
#     --release-unit-id <sha> \
#     --workflow-run-id <id>
#
# All inputs are optional; graceful degradation on missing files.
#
# Bead: mereka-lms-jj97.5
# See: docs/ops/ci-cd/CI_METRICS.md for metric naming contract
# Wire-in comment for build-tutor-images.yml (do not uncomment here — jj97.6 PR):
#   - uses: ./.github/actions/emit-build-metrics
#     with:
#       metadata-file: ${{ steps.build.outputs.metadata-file }}
#       log-file: /tmp/buildx-openedx.log
#       image-family: openedx
#       release-unit-id: ${{ github.sha }}

set -euo pipefail

# ── Defaults ──────────────────────────────────────────────────────────────────
METADATA_FILE="${BUILDX_METADATA_FILE:-}"
LOG_FILE="${BUILDX_LOG_FILE:-}"
IMAGE_FAMILY=""
RELEASE_UNIT_ID=""
WORKFLOW_RUN_ID="${GITHUB_RUN_ID:-}"

# ── Argument parsing ──────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --metadata-file) METADATA_FILE="$2"; shift 2 ;;
    --log-file)      LOG_FILE="$2";      shift 2 ;;
    --image-family)  IMAGE_FAMILY="$2";  shift 2 ;;
    --release-unit-id) RELEASE_UNIT_ID="$2"; shift 2 ;;
    --workflow-run-id) WORKFLOW_RUN_ID="$2"; shift 2 ;;
    *) echo "::warning::emit-build-metrics: unknown argument: $1" >&2; shift ;;
  esac
done

# ── Validation / defaults ─────────────────────────────────────────────────────
IMAGE_FAMILY="${IMAGE_FAMILY:-unknown}"
RELEASE_UNIT_ID="${RELEASE_UNIT_ID:-unknown}"
WORKFLOW_RUN_ID="${WORKFLOW_RUN_ID:-unknown}"
OUTPUT_FILE="build-metrics-${IMAGE_FAMILY}.json"
COLLECTED_AT="$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || echo "unknown")"

# ── Dependency check ──────────────────────────────────────────────────────────
if ! command -v jq &>/dev/null; then
  echo "::warning::emit-build-metrics: jq not found — JSON extraction from metadata disabled"
  JQ_AVAILABLE=0
else
  JQ_AVAILABLE=1
fi

# ── Sentinel for graceful degradation ────────────────────────────────────────
HAS_METADATA=0
HAS_LOG=0

if [[ -n "$METADATA_FILE" && -f "$METADATA_FILE" ]]; then
  HAS_METADATA=1
else
  [[ -n "$METADATA_FILE" ]] && \
    echo "::warning::emit-build-metrics: metadata file not found: ${METADATA_FILE}" >&2
fi

if [[ -n "$LOG_FILE" && -f "$LOG_FILE" ]]; then
  HAS_LOG=1
else
  [[ -n "$LOG_FILE" ]] && \
    echo "::warning::emit-build-metrics: log file not found: ${LOG_FILE}" >&2
fi

if [[ "$HAS_METADATA" -eq 0 && "$HAS_LOG" -eq 0 ]]; then
  echo "::warning::emit-build-metrics: both metadata and log file unavailable — emitting empty artifact"
  cat > "$OUTPUT_FILE" <<EOF
{
  "release_unit_id": "${RELEASE_UNIT_ID}",
  "workflow_run_id": "${WORKFLOW_RUN_ID}",
  "image_family": "${IMAGE_FAMILY}",
  "cache_sources": [],
  "cache_export": null,
  "layer_reuse_count": null,
  "layer_total_count": null,
  "build_duration_seconds": null,
  "collected_at": "${COLLECTED_AT}",
  "_warning": "no input files available"
}
EOF
  exit 0
fi

# ── Extract from buildx metadata JSON ────────────────────────────────────────
BUILD_DURATION_SECONDS=""
IMAGE_DIGEST=""

if [[ "$HAS_METADATA" -eq 1 && "$JQ_AVAILABLE" -eq 1 ]]; then
  # Build duration: prefer buildx.build.duration (integer seconds), fall back
  # to provenance metadata timestamps
  raw_duration="$(jq -r '."buildx.build.duration" // empty' "$METADATA_FILE" 2>/dev/null || true)"
  if [[ -n "$raw_duration" && "$raw_duration" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
    BUILD_DURATION_SECONDS="$raw_duration"
  else
    # Try to compute from provenance start/finish timestamps
    started="$(jq -r '."buildx.build.provenance".metadata.buildStartedOn // empty' \
      "$METADATA_FILE" 2>/dev/null || true)"
    finished="$(jq -r '."buildx.build.provenance".metadata.buildFinishedOn // empty' \
      "$METADATA_FILE" 2>/dev/null || true)"
    if [[ -n "$started" && -n "$finished" ]]; then
      # date -d is GNU coreutils; fallback to empty on failure
      start_epoch="$(date -d "$started" +%s 2>/dev/null || true)"
      end_epoch="$(date -d "$finished" +%s 2>/dev/null || true)"
      if [[ -n "$start_epoch" && -n "$end_epoch" ]]; then
        BUILD_DURATION_SECONDS="$(( end_epoch - start_epoch ))"
      fi
    fi
  fi

  IMAGE_DIGEST="$(jq -r '."containerimage.digest" // empty' "$METADATA_FILE" 2>/dev/null || true)"
fi

# ── Extract from buildx log ───────────────────────────────────────────────────
# Cache source facts — parse "importing cache manifest from <ref>@<digest>" lines.
# Recognized source types: registry, image, gha, local
# A line may appear multiple times (multiple cache sources are tried in order).

# Track every cache source in order. Multiple registry cache imports are
# meaningful: Bake imports L0 platform caches before the app L2 cache.
SOURCE_TYPES=()
SOURCE_REFS=()
SOURCE_DIGESTS=()

if [[ "$HAS_LOG" -eq 1 ]]; then
  # Each "importing cache manifest from" line is one source import attempt.
  # ref format: type:// or plain registry ref (ghcr.io/...) or gha ref
  while IFS= read -r line; do
    # Extract ref after "from " — handles both "from ref@digest" and "from ref"
    ref_full="$(echo "$line" | sed -n 's/.*importing cache manifest from //p' | awk '{print $1}')"
    [[ -z "$ref_full" ]] && continue

    # Determine source type from the ref
    src_type="registry"
    if [[ "$ref_full" == *"type=gha"* ]]; then
      src_type="gha"
    elif [[ "$ref_full" == *"type=local"* ]]; then
      src_type="local"
    fi
    # Distinguish registry vs image by checking if ref matches known cache namespace
    # Both registry and image types appear as plain registry refs in the log.
    # We use a heuristic: /cache/ in the path → registry cache; otherwise → image cache.
    if [[ "$src_type" == "registry" ]]; then
      if echo "$ref_full" | grep -qv '/cache/'; then
        src_type="image"
      fi
    fi

    # Extract digest if present (ref@sha256:...)
    digest_part=""
    if [[ "$ref_full" == *"@sha256:"* ]]; then
      digest_part="sha256:${ref_full##*@sha256:}"
      # strip any trailing chars that aren't hex
      digest_part="$(echo "$digest_part" | grep -oE 'sha256:[0-9a-f]{64}' || true)"
    fi

    SOURCE_TYPES+=("$src_type")
    SOURCE_REFS+=("${ref_full%%@*}")
    SOURCE_DIGESTS+=("${digest_part:-}")
  done < <(grep 'importing cache manifest from' "$LOG_FILE" 2>/dev/null || true)

  # Cache export success — look for "exporting cache" and "writing manifest" without error
  CACHE_EXPORT_SUCCESS=0
  CACHE_EXPORT_DIGEST=""
  if grep -q 'exporting cache' "$LOG_FILE" 2>/dev/null; then
    # Check no export error line follows
    if ! grep -qiE 'error.*export|export.*error|failed.*export' "$LOG_FILE" 2>/dev/null; then
      CACHE_EXPORT_SUCCESS=1
    fi
    # Extract exported manifest digest from "writing manifest sha256:..."
    raw_manifest="$(grep 'writing manifest sha256:' "$LOG_FILE" 2>/dev/null | \
      tail -1 | grep -oE 'sha256:[0-9a-f]{64}' || true)"
    [[ -n "$raw_manifest" ]] && CACHE_EXPORT_DIGEST="$raw_manifest"
  fi

  # Layer counts — CACHED steps and total numbered steps (#N [...])
  LAYER_REUSE_COUNT="$(grep -c ' CACHED$' "$LOG_FILE" 2>/dev/null || echo 0)"
  # Total layer steps: lines matching "#N [stage X/Y]" or "#N [internal]"
  LAYER_TOTAL_COUNT="$(grep -cE '^#[0-9]+ \[' "$LOG_FILE" 2>/dev/null || echo 0)"
fi

# ── Build JSON cache_sources array ───────────────────────────────────────────
build_cache_sources_json() {
  local first=1
  local idx
  echo "["
  for idx in "${!SOURCE_TYPES[@]}"; do
    local src_type="${SOURCE_TYPES[$idx]:-}"
    local digest="${SOURCE_DIGESTS[$idx]:-}"
    local ref="${SOURCE_REFS[$idx]:-}"
    [[ -z "$src_type" || -z "$ref" ]] && continue
    [[ "$first" -eq 0 ]] && echo ","
    first=0
    if [[ -n "$digest" ]]; then
      printf '    {"type": "%s", "ref": "%s", "found": %s, "digest": "%s"}' \
        "$src_type" "$ref" true "$digest"
    else
      printf '    {"type": "%s", "ref": "%s", "found": %s, "digest": null}' \
        "$src_type" "$ref" true
    fi
  done
  echo ""
  echo "  ]"
}

# ── Build cache_export object ─────────────────────────────────────────────────
build_cache_export_json() {
  if [[ "$HAS_LOG" -eq 0 ]]; then
    echo "null"
    return
  fi
  local success_bool
  success_bool="$([ "${CACHE_EXPORT_SUCCESS:-0}" -eq 1 ] && echo true || echo false)"
  if [[ -n "${CACHE_EXPORT_DIGEST:-}" ]]; then
    printf '{"success": %s, "digest": "%s"}' "$success_bool" "$CACHE_EXPORT_DIGEST"
  else
    printf '{"success": %s, "digest": null}' "$success_bool"
  fi
}

# ── Assemble JSON artifact ────────────────────────────────────────────────────
{
  printf '{\n'
  printf '  "release_unit_id": "%s",\n' "$RELEASE_UNIT_ID"
  printf '  "workflow_run_id": "%s",\n' "$WORKFLOW_RUN_ID"
  printf '  "image_family": "%s",\n' "$IMAGE_FAMILY"
  printf '  "cache_sources": '
  _n_sources="${#SOURCE_TYPES[@]}"
  if [[ "${_n_sources}" -gt 0 ]] || [[ "$HAS_LOG" -eq 1 ]]; then
    build_cache_sources_json
  else
    printf '[]\n'
  fi
  printf '  ,\n'
  printf '  "cache_export": %s,\n' "$(build_cache_export_json)"

  if [[ "$HAS_LOG" -eq 1 ]]; then
    printf '  "layer_reuse_count": %s,\n' "${LAYER_REUSE_COUNT:-0}"
    printf '  "layer_total_count": %s,\n' "${LAYER_TOTAL_COUNT:-0}"
  else
    printf '  "layer_reuse_count": null,\n'
    printf '  "layer_total_count": null,\n'
  fi

  if [[ -n "${BUILD_DURATION_SECONDS:-}" ]]; then
    printf '  "build_duration_seconds": %s,\n' "$BUILD_DURATION_SECONDS"
  else
    printf '  "build_duration_seconds": null,\n'
  fi

  printf '  "collected_at": "%s"\n' "$COLLECTED_AT"
  printf '}\n'
} > "$OUTPUT_FILE"

# ── Validate the JSON we just wrote ──────────────────────────────────────────
if [[ "$JQ_AVAILABLE" -eq 1 ]]; then
  if ! jq empty "$OUTPUT_FILE" 2>/dev/null; then
    echo "::error::emit-build-metrics: produced invalid JSON — see ${OUTPUT_FILE}" >&2
    # Don't exit 1 (graceful degradation: artifact is best-effort, must not break build)
  fi
fi

# ── GitHub Step Summary ───────────────────────────────────────────────────────
if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
  {
    echo ""
    echo "### Build Metrics — ${IMAGE_FAMILY}"
    echo ""
    echo "| Metric | Value |"
    echo "|--------|-------|"

    # Cache sources
    for idx in "${!SOURCE_TYPES[@]}"; do
      src_type="${SOURCE_TYPES[$idx]:-}"
      [[ -z "$src_type" ]] && continue
      digest="${SOURCE_DIGESTS[$idx]:-}"
      icon="✅"
      if [[ -n "$digest" ]]; then
        echo "| cache_source_found (${src_type}) | ${icon} \`${digest}\` |"
      else
        echo "| cache_source_found (${src_type}) | ${icon} |"
      fi
    done

    if [[ "$HAS_LOG" -eq 1 ]]; then
      # Cache export
      if [[ "${CACHE_EXPORT_SUCCESS:-0}" -eq 1 ]]; then
        echo "| cache_export_success | ✅ \`${CACHE_EXPORT_DIGEST:-unknown}\` |"
      else
        echo "| cache_export_success | ❌ |"
      fi

      # Layer counts
      total="${LAYER_TOTAL_COUNT:-0}"
      reuse="${LAYER_REUSE_COUNT:-0}"
      if [[ "$total" -gt 0 ]]; then
        pct=$(( reuse * 100 / total ))
        echo "| layer_reuse_count | ${reuse} / ${total} total (${pct}%) |"
      else
        echo "| layer_reuse_count | ${reuse} / ${total} total |"
      fi
    fi

    # Duration
    if [[ -n "${BUILD_DURATION_SECONDS:-}" ]]; then
      echo "| build_duration_seconds | ${BUILD_DURATION_SECONDS}s |"
    fi

    echo "| artifact | \`${OUTPUT_FILE}\` |"
  } >> "$GITHUB_STEP_SUMMARY"
fi

echo "PASS emit-build-metrics: wrote ${OUTPUT_FILE}"
if [[ "$JQ_AVAILABLE" -eq 1 ]]; then
  jq -C . "$OUTPUT_FILE"
fi
