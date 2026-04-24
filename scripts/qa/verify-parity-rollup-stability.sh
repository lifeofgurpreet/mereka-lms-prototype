#!/usr/bin/env bash
# Enforce sustained parity rollup health across consecutive scheduled workflow runs.
#
# Usage:
#   ./scripts/qa/verify-parity-rollup-stability.sh \
#     --rollup-json var/ci/observability-parity-rollup.json \
#     --required-consecutive 3 \
#     --out-json var/ci/observability-parity-stability.json

set -euo pipefail

ROLLUP_JSON=""
OUT_JSON=""
REQUIRED_CONSECUTIVE=3
WORKFLOW_FILE=".github/workflows/observability-parity-runtime.yml"
WORKFLOW_RUN_LOOKBACK=20

usage() {
  cat <<'EOF'
Usage: ./scripts/qa/verify-parity-rollup-stability.sh \
  --rollup-json <path> \
  [--required-consecutive <n>] \
  [--workflow-file <path>] \
  [--workflow-runs-lookback <n>] \
  [--out-json <path>]
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --rollup-json)
      ROLLUP_JSON="${2:-}"
      shift 2
      ;;
    --required-consecutive)
      REQUIRED_CONSECUTIVE="${2:-3}"
      shift 2
      ;;
    --workflow-file)
      WORKFLOW_FILE="${2:-}"
      shift 2
      ;;
    --workflow-runs-lookback)
      WORKFLOW_RUN_LOOKBACK="${2:-20}"
      shift 2
      ;;
    --out-json)
      OUT_JSON="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [[ -z "$ROLLUP_JSON" || ! -f "$ROLLUP_JSON" ]]; then
  echo "rollup json is required and must exist: ${ROLLUP_JSON}" >&2
  exit 1
fi

if ! [[ "$REQUIRED_CONSECUTIVE" =~ ^[0-9]+$ ]] || [[ "$REQUIRED_CONSECUTIVE" -lt 1 ]]; then
  echo "required-consecutive must be a positive integer" >&2
  exit 1
fi

if [[ -n "$WORKFLOW_RUN_LOOKBACK" ]] && (! [[ "$WORKFLOW_RUN_LOOKBACK" =~ ^[0-9]+$ ]] || [[ "$WORKFLOW_RUN_LOOKBACK" -lt 1 ]]); then
  echo "workflow-runs-lookback must be a positive integer" >&2
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "jq is required" >&2
  exit 1
fi

if ! command -v curl >/dev/null 2>&1; then
  echo "curl is required" >&2
  exit 1
fi

if [[ -z "${GITHUB_TOKEN:-}" ]]; then
  echo "GITHUB_TOKEN is required to query workflow run history" >&2
  exit 1
fi

if [[ -z "${GITHUB_REPOSITORY:-}" ]]; then
  echo "GITHUB_REPOSITORY is required" >&2
  exit 1
fi

if [[ -z "${GITHUB_RUN_ID:-}" ]]; then
  echo "GITHUB_RUN_ID is required" >&2
  exit 1
fi

if [[ -z "${GITHUB_EVENT_NAME:-}" ]] || [[ "${GITHUB_EVENT_NAME}" != "schedule" ]]; then
  STATS_STATUS="skipped"
  STATS_REASON="stability check applies only to scheduled runs"
  STREAK=0
else
  workflow_id="$(printf '%s' "$WORKFLOW_FILE" | sed 's#^.*/##')"
  api_url="https://api.github.com/repos/${GITHUB_REPOSITORY}/actions/workflows/${workflow_id}/runs?per_page=${WORKFLOW_RUN_LOOKBACK}"
  workflow_runs_json="$(curl -fsSL -H "Authorization: Bearer ${GITHUB_TOKEN}" -H "Accept: application/vnd.github+json" "$api_url")"

  if ! jq -e '.workflow_runs | type == "array"' <<<"$workflow_runs_json" >/dev/null 2>&1; then
    echo "failed to parse workflow runs response" >&2
    exit 1
  fi

  STREAK=1
  CURRENT_ID="${GITHUB_RUN_ID}"
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue

    run_id="$(awk '{print $1}' <<<"$line")"
    event="$(awk '{print $2}' <<<"$line")"
    conclusion="$(awk '{print $3}' <<<"$line")"

    if [[ "$event" != "schedule" ]]; then
      break
    fi

    if [[ "$run_id" == "$CURRENT_ID" ]]; then
      continue
    fi

    if [[ "$conclusion" == "success" ]]; then
      STREAK=$((STREAK + 1))
      if [[ "$STREAK" -ge "$REQUIRED_CONSECUTIVE" ]]; then
        break
      fi
      continue
    fi

    break
  done < <(jq -r '.workflow_runs[] | "\(.id) \(.event) \(.conclusion)"' <<<"$workflow_runs_json")

  if [[ "$STREAK" -ge "$REQUIRED_CONSECUTIVE" ]]; then
    STATS_STATUS="pass"
    STATS_REASON="Found ${STREAK}/${REQUIRED_CONSECUTIVE} consecutive scheduled successful parity rollups"
  else
    STATS_STATUS="fail"
    STATS_REASON="Only ${STREAK}/${REQUIRED_CONSECUTIVE} consecutive scheduled successful parity rollups found"
  fi
fi

stability_json=$(cat <<JSON
{
  "generated_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "status": "${STATS_STATUS}",
  "required_consecutive": ${REQUIRED_CONSECUTIVE},
  "streak": ${STREAK},
  "reason": "${STATS_REASON}",
  "rollup_json": "${ROLLUP_JSON}",
  "workflow_runs_lookback": ${WORKFLOW_RUN_LOOKBACK}
}
JSON
)

if [[ -n "$OUT_JSON" ]]; then
  mkdir -p "$(dirname "$OUT_JSON")"
  printf '%s\n' "$stability_json" > "$OUT_JSON"
  echo "Wrote stability evidence: $OUT_JSON"
else
  printf '%s\n' "$stability_json"
fi

echo "$STATS_REASON"

if [[ "$STATS_STATUS" == "pass" ]]; then
  exit 0
fi

if [[ "$STATS_STATUS" == "skipped" ]]; then
  exit 0
fi

exit 1
