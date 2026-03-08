#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

REPORT_GLOB="docs/guides/admin/DOCS_PROGRAM_SCORECARD_*.md"
REFERENCE_DATE=""
SUMMARY_JSON=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --report-glob)
      REPORT_GLOB="${2:?missing value}"
      shift 2
      ;;
    --reference-date)
      REFERENCE_DATE="${2:?missing value}"
      shift 2
      ;;
    --summary-json)
      SUMMARY_JSON="${2:?missing value}"
      shift 2
      ;;
    --help|-h)
      cat <<'EOF'
Usage: verify-docs-scorecard-head-freshness.sh [options]

Options:
  --report-glob <glob>      scorecard glob (default: docs/guides/admin/DOCS_PROGRAM_SCORECARD_*.md)
  --reference-date YYYYMMDD compare latest scorecard date to this date (default: HEAD commit date converted to UTC)
  --summary-json <path>     optional JSON summary output
  --help                    show this message
EOF
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      exit 1
      ;;
  esac
done

if [ -z "$REFERENCE_DATE" ]; then
  HEAD_EPOCH=$(git show -s --format=%ct HEAD)
  REFERENCE_DATE=$(date -u -d "@${HEAD_EPOCH}" +%Y%m%d)
fi

if [[ ! "$REFERENCE_DATE" =~ ^[0-9]{8}$ ]]; then
  echo "DOCS_SCORECARD_HEAD_FRESHNESS_FAIL: invalid reference date '${REFERENCE_DATE}'" >&2
  exit 1
fi

shopt -s nullglob
REPORTS=($REPORT_GLOB)
shopt -u nullglob

if [ ${#REPORTS[@]} -eq 0 ]; then
  echo "DOCS_SCORECARD_HEAD_FRESHNESS_FAIL: no scorecard reports found for glob $REPORT_GLOB" >&2
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
  echo "DOCS_SCORECARD_HEAD_FRESHNESS_FAIL: unable to derive latest scorecard date from filenames" >&2
  exit 1
fi

status="pass"
if [ "$LATEST_DATE" -lt "$REFERENCE_DATE" ]; then
  status="fail"
fi

if [ -n "$SUMMARY_JSON" ]; then
  cat > "$SUMMARY_JSON" <<EOF
{
  "status": "${status}",
  "latest_report": "${LATEST_REPORT}",
  "latest_date": "${LATEST_DATE}",
  "reference_date": "${REFERENCE_DATE}"
}
EOF
fi

if [ "$status" = "fail" ]; then
  echo "DOCS_SCORECARD_HEAD_FRESHNESS_FAIL: latest scorecard date ${LATEST_DATE} is older than reference date ${REFERENCE_DATE}" >&2
  exit 1
fi

echo "DOCS_SCORECARD_HEAD_FRESHNESS_OK latest=${LATEST_REPORT} latest_date=${LATEST_DATE} reference_date=${REFERENCE_DATE}"
