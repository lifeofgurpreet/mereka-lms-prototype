#!/usr/bin/env bash
# Build a weekly parity review markdown from parity delta JSON.
#
# Usage:
#   ./scripts/qa/build-observability-parity-review.sh \
#     --env prod \
#     --delta-json var/ci/parity-prod/observability-parity-delta.json \
#     --out-md var/ci/parity-prod/observability-parity-review.md

set -euo pipefail

ENV_LABEL=""
DELTA_JSON=""
OUT_MD=""
OWNER="${PARITY_REVIEW_OWNER:-Mereka LMS platform team}"

usage() {
  cat <<'EOF'
Usage: ./scripts/qa/build-observability-parity-review.sh --env <dev|nonprod|prod|custom> --delta-json <path> --out-md <path>
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --env)
      ENV_LABEL="${2:-}"
      shift 2
      ;;
    --delta-json)
      DELTA_JSON="${2:-}"
      shift 2
      ;;
    --out-md)
      OUT_MD="${2:-}"
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

if [[ -z "$ENV_LABEL" || -z "$DELTA_JSON" || -z "$OUT_MD" ]]; then
  usage
  exit 1
fi

if [[ ! -f "$DELTA_JSON" ]]; then
  echo "Delta JSON not found: $DELTA_JSON" >&2
  exit 1
fi

if ! jq -e . "$DELTA_JSON" >/dev/null 2>&1; then
  echo "Malformed delta JSON: $DELTA_JSON" >&2
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "jq is required for parity review generation." >&2
  exit 1
fi

mkdir -p "$(dirname "$OUT_MD")"

generated_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
week_of="$(date -u +%Y-%m-%d)"

status="$(jq -r '.status // empty' "$DELTA_JSON")"
if [[ -n "$status" ]]; then
  review_status="$status"
else
  fail_count="$(jq -r '.summary.fail // 0' "$DELTA_JSON")"
  if [[ "$fail_count" == "0" ]]; then
    review_status="pass"
  else
    review_status="fail"
  fi
fi

identity="n/a"
if [[ -f "$(dirname "$DELTA_JSON")/observability-first-class-runtime-evidence-index.json" ]]; then
  identity="$(jq -r '.identity // "n/a"' "$(dirname "$DELTA_JSON")/observability-first-class-runtime-evidence-index.json")"
fi

top_failures="- none"
if [[ "$review_status" == "skipped" ]]; then
  reason="$(jq -r '.reason // "no reason provided"' "$DELTA_JSON")"
  top_failures="- skipped: $reason"
elif [[ "$review_status" == "fail" ]]; then
  failures_list="$(jq -r '.checks[]? | select(.status=="fail") | "- \(.id): \(.message)"' "$DELTA_JSON" | head -n 5)"
  if [[ -n "$failures_list" ]]; then
    top_failures="$failures_list"
  fi
fi

target_fix_date="-"
if [[ "$review_status" == "fail" || "$review_status" == "skipped" ]]; then
  target_fix_date="$(date -u -d '+7 days' +%Y-%m-%d 2>/dev/null || date -u +%Y-%m-%d)"
fi

{
  echo "# Observability Parity Weekly Review"
  echo ""
  echo "- generated_at: $generated_at"
  echo "- week_of: $week_of"
  echo "- environment: $ENV_LABEL"
  echo "- status: $review_status"
  echo "- identity: $identity"
  echo "- owner: $OWNER"
  echo "- target_fix_date: $target_fix_date"
  echo ""
  echo "## Top failures"
  echo ""
  echo "$top_failures"
  echo ""
  echo "## Action notes"
  echo ""
  echo "- Add owner-level action items here."
} > "$OUT_MD"

echo "OK: wrote parity review template -> $OUT_MD"
