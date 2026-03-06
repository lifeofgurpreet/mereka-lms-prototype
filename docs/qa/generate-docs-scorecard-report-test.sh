#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=${1:-$(mktemp -d)}
KEEP_ROOT=0

if [ "${1-}" != "" ]; then
  KEEP_ROOT=1
fi

if [ ! -d "$ROOT_DIR" ]; then
  mkdir -p "$ROOT_DIR"
fi

cleanup() {
  if [ "$KEEP_ROOT" -eq 0 ]; then
    rm -rf "$ROOT_DIR"
  fi
}
trap cleanup EXIT

DATE=$(date -u +%Y%m%d)
OUT_FILE="$ROOT_DIR/DOCS_PROGRAM_SCORECARD_${DATE}.md"

docs/qa/generate-docs-scorecard-report.sh \
  --date "$DATE" \
  --output "$OUT_FILE" >/tmp/generate_docs_scorecard_report_test.out 2>&1

if [ ! -f "$OUT_FILE" ]; then
  echo "expected generated report at $OUT_FILE"
  cat /tmp/generate_docs_scorecard_report_test.out
  exit 1
fi

docs/qa/verify-docs-scorecard-report-consistency.sh --report-glob "$OUT_FILE" >/tmp/generate_docs_scorecard_consistency_check.out 2>&1
docs/qa/verify-docs-scorecard-report-timestamp.sh --report-glob "$OUT_FILE" >/tmp/generate_docs_scorecard_timestamp_check.out 2>&1

grep -q "^# Docs Program Scorecard ${DATE}$" "$OUT_FILE"
grep -q "Last verified (UTC):" "$OUT_FILE"

echo "generate-docs-scorecard-report self-test: OK"
