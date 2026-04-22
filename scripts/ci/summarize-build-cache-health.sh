#!/usr/bin/env bash
# summarize-build-cache-health.sh -- turn build-metrics JSON into a truthful
# cache-health summary for Build Tutor Images.
set -euo pipefail

usage() {
  cat <<'EOF' >&2
Usage:
  scripts/ci/summarize-build-cache-health.sh \
    --image-family <openedx|mfe> \
    --metrics-file <path> \
    --l2-cache-ref <ref> \
    [--timing-env <path>] \
    [--cache-export-expected true|false]
EOF
}

IMAGE_FAMILY=""
METRICS_FILE=""
TIMING_ENV=""
L2_CACHE_REF=""
CACHE_EXPORT_EXPECTED="false"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --image-family) IMAGE_FAMILY="${2:-}"; shift 2 ;;
    --metrics-file) METRICS_FILE="${2:-}"; shift 2 ;;
    --timing-env) TIMING_ENV="${2:-}"; shift 2 ;;
    --l2-cache-ref) L2_CACHE_REF="${2:-}"; shift 2 ;;
    --cache-export-expected) CACHE_EXPORT_EXPECTED="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "::warning::summarize-build-cache-health: unknown argument: $1" >&2; shift ;;
  esac
done

if [[ -z "$IMAGE_FAMILY" || -z "$METRICS_FILE" || -z "$L2_CACHE_REF" ]]; then
  usage
  exit 2
fi

case "$CACHE_EXPORT_EXPECTED" in
  true|false) ;;
  *)
    echo "::warning::summarize-build-cache-health: invalid --cache-export-expected=${CACHE_EXPORT_EXPECTED}; using false" >&2
    CACHE_EXPORT_EXPECTED="false"
    ;;
esac

SUMMARY=""
WARNINGS=0
FAILURES=0

append() {
  SUMMARY="${SUMMARY}"$'\n'"$*"
}

ok() {
  append "OK: $*"
}

warn() {
  WARNINGS=$((WARNINGS + 1))
  append "WARN: $*"
}

fail() {
  FAILURES=$((FAILURES + 1))
  append "FAIL: $*"
}

write_summary() {
  local title="$1"
  echo
  echo "=== ${title} ==="
  printf '%s\n' "$SUMMARY"
  echo "Warnings: ${WARNINGS}; failures: ${FAILURES}"

  if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
    {
      echo "### ${title}"
      printf '%s\n' "$SUMMARY"
      echo
      echo "Warnings: ${WARNINGS}; failures: ${FAILURES}"
    } >> "$GITHUB_STEP_SUMMARY"
  fi

  if [[ "$FAILURES" -gt 0 ]]; then
    echo "::warning::${IMAGE_FAMILY} cache-health summary found ${FAILURES} hard issue(s)"
  elif [[ "$WARNINGS" -gt 0 ]]; then
    echo "::warning::${IMAGE_FAMILY} cache-health summary found ${WARNINGS} warning(s)"
  fi
}

if [[ ! -f "$METRICS_FILE" ]]; then
  warn "metrics artifact missing at ${METRICS_FILE}; cache-health summary skipped"
  write_summary "${IMAGE_FAMILY} Build Cache Health"
  exit 0
fi

if ! command -v jq >/dev/null 2>&1; then
  warn "jq is unavailable; cannot read ${METRICS_FILE}; cache-health summary skipped"
  write_summary "${IMAGE_FAMILY} Build Cache Health"
  exit 0
fi

if ! jq empty "$METRICS_FILE" >/dev/null 2>&1; then
  warn "metrics artifact is not valid JSON: ${METRICS_FILE}; cache-health summary skipped"
  write_summary "${IMAGE_FAMILY} Build Cache Health"
  exit 0
fi

registry_ref="$(jq -r 'first(.cache_sources[]? | select(.type == "registry" and (.found == true)) | .ref) // ""' "$METRICS_FILE")"
registry_digest="$(jq -r 'first(.cache_sources[]? | select(.type == "registry" and (.found == true)) | .digest) // ""' "$METRICS_FILE")"
image_ref="$(jq -r 'first(.cache_sources[]? | select(.type == "image" and (.found == true)) | .ref) // ""' "$METRICS_FILE")"
export_success="$(jq -r '.cache_export.success // "null"' "$METRICS_FILE")"
export_digest="$(jq -r '.cache_export.digest // ""' "$METRICS_FILE")"
layer_reuse="$(jq -r '.layer_reuse_count // "null"' "$METRICS_FILE")"
layer_total="$(jq -r '.layer_total_count // "null"' "$METRICS_FILE")"
build_duration="$(jq -r '.build_duration_seconds // "null"' "$METRICS_FILE")"

if [[ -n "$registry_ref" ]]; then
  if [[ "$registry_ref" == "$L2_CACHE_REF"* ]]; then
    if [[ -n "$registry_digest" && "$registry_digest" != "null" ]]; then
      ok "L2 registry cache import observed: ${registry_ref} @ ${registry_digest}"
    else
      ok "L2 registry cache import observed: ${registry_ref}"
    fi
  else
    warn "registry cache import observed, but not from expected L2 ref: ${registry_ref}; expected ${L2_CACHE_REF}"
  fi
else
  warn "no L2 registry cache import observed in ${METRICS_FILE}; this can be a first build, auth miss, or cache miss"
fi

if [[ -n "$image_ref" ]]; then
  ok "final-image fallback cache import observed: ${image_ref}"
else
  warn "no final-image fallback cache import observed"
fi

if [[ "$CACHE_EXPORT_EXPECTED" == "true" ]]; then
  if [[ "$export_success" == "true" ]]; then
    if [[ -n "$export_digest" && "$export_digest" != "null" ]]; then
      ok "shared cache export succeeded: ${export_digest}"
    else
      ok "shared cache export succeeded"
    fi
  else
    fail "shared cache export was expected for this trusted main push but was not observed"
  fi
else
  if [[ "$export_success" == "true" ]]; then
    warn "cache export observed even though this event is not expected to write shared cache"
  else
    ok "shared cache export not expected for this event"
  fi
fi

if [[ "$layer_total" =~ ^[0-9]+$ && "$layer_total" -gt 0 ]]; then
  if [[ "$layer_reuse" =~ ^[0-9]+$ ]]; then
    ok "layer reuse observed: ${layer_reuse}/${layer_total}"
  else
    warn "layer total observed (${layer_total}) but reuse count is unavailable"
  fi
else
  warn "layer counts unavailable in ${METRICS_FILE}"
fi

if [[ "$build_duration" != "null" ]]; then
  ok "build duration from metrics: ${build_duration}s"
elif [[ -n "$TIMING_ENV" && -f "$TIMING_ENV" ]]; then
  # shellcheck disable=SC1090
  source "$TIMING_ENV"
  ok "build timing env present: ${BUILD_START:-unknown} -> ${BUILD_END:-unknown}"
else
  warn "build duration unavailable"
fi

write_summary "${IMAGE_FAMILY} Build Cache Health"
exit 0
