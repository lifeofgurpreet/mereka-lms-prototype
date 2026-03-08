#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

MAX_AGE_DAYS=7
REPORT_GLOB="docs/guides/admin/DOCS_PROGRAM_SCORECARD_*.md"
SUMMARY_JSON=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --max-age-days)
      MAX_AGE_DAYS="${2:?missing value}"
      shift 2
      ;;
    --summary-json)
      SUMMARY_JSON="${2:?missing value}"
      shift 2
      ;;
    --report-glob)
      REPORT_GLOB="${2:?missing value}"
      shift 2
      ;;
    --help|-h)
      cat <<'EOF'
Usage: verify-docs-scorecard-recency.sh [options]

Options:
  --max-age-days <n>    maximum allowed age in days (default: 7)
  --summary-json <path> optional JSON summary output path
  --report-glob <glob>  override report glob (default: docs/guides/admin/DOCS_PROGRAM_SCORECARD_*.md)
  --help                show this message
EOF
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      exit 1
      ;;
  esac
done

shopt -s nullglob
REPORTS=($REPORT_GLOB)
shopt -u nullglob

if [ ${#REPORTS[@]} -eq 0 ]; then
  echo "DOCS_SCORECARD_RECENCY_FAIL: no tracked scorecard reports found at $REPORT_GLOB" >&2
  exit 1
fi

LATEST_REPORT=""
LATEST_DATE=""
for report in "${REPORTS[@]}"; do
  base=$(basename "$report")
  date_part="${base#DOCS_PROGRAM_SCORECARD_}"
  date_part="${date_part%.md}"
  if [[ ! "$date_part" =~ ^[0-9]{8}$ ]]; then
    continue
  fi
  if [ -z "$LATEST_DATE" ] || [ "$date_part" -gt "$LATEST_DATE" ]; then
    LATEST_DATE="$date_part"
    LATEST_REPORT="$report"
  fi
done

if [ -z "$LATEST_DATE" ] || [ -z "$LATEST_REPORT" ]; then
  echo "DOCS_SCORECARD_RECENCY_FAIL: unable to resolve latest scorecard date from filenames" >&2
  exit 1
fi

latest_epoch=$(date -u -d "${LATEST_DATE:0:4}-${LATEST_DATE:4:2}-${LATEST_DATE:6:2}T00:00:00Z" +%s)
now_epoch=$(date -u +%s)
age_days=$(( (now_epoch - latest_epoch) / 86400 ))

if [ "$age_days" -gt "$MAX_AGE_DAYS" ]; then
  echo "DOCS_SCORECARD_RECENCY_FAIL: latest scorecard is ${age_days}d old (max ${MAX_AGE_DAYS}d): ${LATEST_REPORT}" >&2
  exit 1
fi

if [ -n "$SUMMARY_JSON" ]; then
  cat > "$SUMMARY_JSON" <<EOF
{
  "status": "pass",
  "latest_report": "${LATEST_REPORT}",
  "latest_date": "${LATEST_DATE}",
  "age_days": ${age_days},
  "max_age_days": ${MAX_AGE_DAYS}
}
EOF
fi

echo "DOCS_SCORECARD_RECENCY_OK latest=${LATEST_REPORT} date=${LATEST_DATE} age_days=${age_days} max_age_days=${MAX_AGE_DAYS}"
