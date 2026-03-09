#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$ROOT_DIR"

PROGRAM_GLOB="docs/guides/admin/DOCS_PROGRAM_SCORECARD_*.md"
DELTA_GLOB="docs/guides/admin/DOCS_QUALITY_SCORECARD_*.md"
SUMMARY_JSON=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --program-glob)
      PROGRAM_GLOB="${2:?missing value}"
      shift 2
      ;;
    --delta-glob)
      DELTA_GLOB="${2:?missing value}"
      shift 2
      ;;
    --summary-json)
      SUMMARY_JSON="${2:?missing value}"
      shift 2
      ;;
    --help|-h)
      cat <<'EOF'
Usage: verify-docs-scorecard-delta-artifact.sh [options]

Options:
  --program-glob <glob>  program scorecard glob (default: docs/guides/admin/DOCS_PROGRAM_SCORECARD_*.md)
  --delta-glob <glob>    quality/delta scorecard glob (default: docs/guides/admin/DOCS_QUALITY_SCORECARD_*.md)
  --summary-json <path>  optional JSON summary output path
  --help                 show this message
EOF
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      exit 1
      ;;
  esac
done

latest_for_glob() {
  local glob="$1"
  local prefix="$2"
  local latest_date=""
  local latest_report=""
  local report
  shopt -s nullglob
  local reports=($glob)
  shopt -u nullglob
  for report in "${reports[@]}"; do
    local base
    base=$(basename "$report")
    local date_part="${base#${prefix}}"
    date_part="${date_part%.md}"
    if [[ ! "$date_part" =~ ^[0-9]{8}$ ]]; then
      continue
    fi
    if [ -z "$latest_date" ] || [ "$date_part" -gt "$latest_date" ]; then
      latest_date="$date_part"
      latest_report="$report"
    fi
  done
  printf '%s\n%s\n' "$latest_date" "$latest_report"
}

readarray -t PROGRAM_META < <(latest_for_glob "$PROGRAM_GLOB" "DOCS_PROGRAM_SCORECARD_")
readarray -t DELTA_META < <(latest_for_glob "$DELTA_GLOB" "DOCS_QUALITY_SCORECARD_")

PROGRAM_DATE="${PROGRAM_META[0]:-}"
PROGRAM_REPORT="${PROGRAM_META[1]:-}"
DELTA_DATE="${DELTA_META[0]:-}"
DELTA_REPORT="${DELTA_META[1]:-}"

if [ -z "$PROGRAM_DATE" ] || [ -z "$PROGRAM_REPORT" ]; then
  echo "DOCS_SCORECARD_DELTA_FAIL: no program scorecard found for glob $PROGRAM_GLOB" >&2
  exit 1
fi

if [ -z "$DELTA_DATE" ] || [ -z "$DELTA_REPORT" ]; then
  echo "DOCS_SCORECARD_DELTA_FAIL: no quality/delta scorecard found for glob $DELTA_GLOB" >&2
  exit 1
fi

status="pass"
has_delta_section="false"
if grep -q '^## One-Week Scorecard Delta' "$DELTA_REPORT"; then
  has_delta_section="true"
else
  status="fail"
fi

if [ "$PROGRAM_DATE" != "$DELTA_DATE" ]; then
  status="fail"
fi

if [ -n "$SUMMARY_JSON" ]; then
  {
    echo "{"
    echo "  \"status\": \"${status}\","
    echo "  \"latest_program_report\": \"${PROGRAM_REPORT}\","
    echo "  \"latest_program_date\": \"${PROGRAM_DATE}\","
    echo "  \"latest_delta_report\": \"${DELTA_REPORT}\","
    echo "  \"latest_delta_date\": \"${DELTA_DATE}\","
    echo "  \"date_match\": $([ "$PROGRAM_DATE" = "$DELTA_DATE" ] && echo "true" || echo "false"),"
    echo "  \"has_delta_section\": ${has_delta_section}"
    echo "}"
  } > "$SUMMARY_JSON"
fi

if [ "$status" = "fail" ]; then
  echo "DOCS_SCORECARD_DELTA_FAIL: quality delta artifact is out of contract" >&2
  echo "- latest_program=${PROGRAM_REPORT} (${PROGRAM_DATE})" >&2
  echo "- latest_delta=${DELTA_REPORT} (${DELTA_DATE})" >&2
  echo "- has_delta_section=${has_delta_section}" >&2
  exit 1
fi

echo "DOCS_SCORECARD_DELTA_OK program=${PROGRAM_REPORT} delta=${DELTA_REPORT} date=${PROGRAM_DATE}"
