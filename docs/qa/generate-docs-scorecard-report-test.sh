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
QUALITY_OUT_FILE="$ROOT_DIR/DOCS_QUALITY_SCORECARD_${DATE}.md"

docs/qa/generate-docs-scorecard-report.sh \
  --date "$DATE" \
  --output "$OUT_FILE" \
  --quality-output "$QUALITY_OUT_FILE" >/tmp/generate_docs_scorecard_report_test.out 2>&1

if [ ! -f "$OUT_FILE" ]; then
  echo "expected generated report at $OUT_FILE"
  cat /tmp/generate_docs_scorecard_report_test.out
  exit 1
fi

if [ ! -f "$QUALITY_OUT_FILE" ]; then
  echo "expected generated quality report at $QUALITY_OUT_FILE"
  cat /tmp/generate_docs_scorecard_report_test.out
  exit 1
fi

docs/qa/verify-docs-scorecard-report-consistency.sh --report-glob "$OUT_FILE" >/tmp/generate_docs_scorecard_consistency_check.out 2>&1
docs/qa/verify-docs-scorecard-report-timestamp.sh --report-glob "$OUT_FILE" >/tmp/generate_docs_scorecard_timestamp_check.out 2>&1
docs/qa/verify-docs-scorecard-delta-artifact.sh \
  --program-glob "$OUT_FILE" \
  --delta-glob "$QUALITY_OUT_FILE" >/tmp/generate_docs_scorecard_delta_check.out 2>&1

grep -q "^# Docs Program Scorecard ${DATE}$" "$OUT_FILE"
grep -q "Last verified (UTC):" "$OUT_FILE"
grep -q "## Compliance Gate Snapshot" "$OUT_FILE"
grep -q "Overall compliance status:" "$OUT_FILE"
grep -q "foundation_policy_range=" "$OUT_FILE"
grep -q "foundation_policy_content_consistent=" "$OUT_FILE"
grep -q "foundation_policy_content_consistency=" "$OUT_FILE"
grep -q "foundation_policy_content_alignment=" "$OUT_FILE"
grep -q "foundation_policy_content_consistency_detail=" "$OUT_FILE"
grep -q "foundation_policy_content_consistency_aligned=" "$OUT_FILE"
grep -q "Command reference checks:" "$OUT_FILE"
grep -q "Command reference source breakdown:" "$OUT_FILE"
grep -q "Link integrity checks:" "$OUT_FILE"
grep -q "delta=" "$OUT_FILE"
grep -q "drift=" "$OUT_FILE"
grep -q "^## One-Week Scorecard Delta" "$QUALITY_OUT_FILE"
grep -q "verify-docs-foundation-gates.sh" "$QUALITY_OUT_FILE"
grep -q "policy_content_alignment=" "$QUALITY_OUT_FILE"
grep -q "policy_content_consistency=" "$QUALITY_OUT_FILE"
grep -q "verify-docs-policy.sh" "$QUALITY_OUT_FILE"
grep -q "verify-doc-link-integrity.sh" "$QUALITY_OUT_FILE"
grep -q "verify-doc-command-ref-baseline.sh" "$QUALITY_OUT_FILE"
grep -q "baseline_enabled=" "$QUALITY_OUT_FILE"
grep -q "baseline_entries=" "$QUALITY_OUT_FILE"
grep -q "broken_links=" "$QUALITY_OUT_FILE"
grep -q "inline=" "$QUALITY_OUT_FILE"
grep -q "shell=" "$QUALITY_OUT_FILE"
grep -q "md_link=" "$QUALITY_OUT_FILE"
grep -q "md_autolink=" "$QUALITY_OUT_FILE"
grep -q "md_refdef=" "$QUALITY_OUT_FILE"
grep -q "foundation policy metrics" "$QUALITY_OUT_FILE"
grep -q "consistent=" "$QUALITY_OUT_FILE"
grep -q "consistency_status=" "$QUALITY_OUT_FILE"
grep -q "consistency_detail=" "$QUALITY_OUT_FILE"
grep -q "consistency_aligned=" "$QUALITY_OUT_FILE"
grep -q "missing_refs=" "$QUALITY_OUT_FILE"

echo "generate-docs-scorecard-report self-test: OK"
