#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$ROOT_DIR"

REPORT_GLOB="docs/guides/admin/DOCS_PROGRAM_SCORECARD_*.md"
SUMMARY_JSON=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --report-glob)
      REPORT_GLOB="${2:?missing value}"
      shift 2
      ;;
    --summary-json)
      SUMMARY_JSON="${2:?missing value}"
      shift 2
      ;;
    --help|-h)
      cat <<'EOF'
Usage: verify-docs-scorecard-report-consistency.sh [options]

Options:
  --report-glob <glob>   report glob to validate (default: docs/guides/admin/DOCS_PROGRAM_SCORECARD_*.md)
  --summary-json <path>  optional JSON summary output
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

shopt -s nullglob
REPORTS=($REPORT_GLOB)
shopt -u nullglob

if [ ${#REPORTS[@]} -eq 0 ]; then
  echo "DOCS_SCORECARD_CONSISTENCY_FAIL: no scorecard reports found for glob $REPORT_GLOB" >&2
  exit 1
fi

invalid_count=0
declare -a mismatches=()

for report in "${REPORTS[@]}"; do
  base=$(basename "$report")
  file_date="${base#DOCS_PROGRAM_SCORECARD_}"
  file_date="${file_date%.md}"

  if [[ ! "$file_date" =~ ^[0-9]{8}$ ]]; then
    invalid_count=$((invalid_count + 1))
    mismatches+=("${report}: invalid filename date")
    continue
  fi

  # Title format contract:
  # # Docs Program Scorecard YYYYMMDD
  title_line=$(head -n 1 "$report" || true)
  title_date=$(sed -nE 's/^# Docs Program Scorecard ([0-9]{8})$/\1/p' <<<"$title_line")

  if [ -z "$title_date" ]; then
    invalid_count=$((invalid_count + 1))
    mismatches+=("${report}: missing or malformed title date")
    continue
  fi

  if [ "$title_date" != "$file_date" ]; then
    invalid_count=$((invalid_count + 1))
    mismatches+=("${report}: filename_date=${file_date} title_date=${title_date}")
  fi
done

status="pass"
if [ "$invalid_count" -gt 0 ]; then
  status="fail"
fi

if [ -n "$SUMMARY_JSON" ]; then
  {
    echo "{"
    echo "  \"status\": \"${status}\","
    echo "  \"reports_checked\": ${#REPORTS[@]},"
    echo "  \"invalid_reports\": ${invalid_count},"
    echo "  \"mismatches\": ["
    for i in "${!mismatches[@]}"; do
      value="${mismatches[$i]}"
      comma=""
      if [ "$i" -lt "$(( ${#mismatches[@]} - 1 ))" ]; then
        comma=","
      fi
      escaped=$(python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))' "$value")
      echo "    ${escaped}${comma}"
    done
    echo "  ]"
    echo "}"
  } > "$SUMMARY_JSON"
fi

if [ "$status" = "fail" ]; then
  printf 'DOCS_SCORECARD_CONSISTENCY_FAIL: %s invalid report(s)\n' "$invalid_count" >&2
  for item in "${mismatches[@]}"; do
    printf -- '- %s\n' "$item" >&2
  done
  exit 1
fi

echo "DOCS_SCORECARD_CONSISTENCY_OK reports_checked=${#REPORTS[@]} invalid_reports=${invalid_count}"
