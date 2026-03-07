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

PASS_DIR="$ROOT_DIR/pass"
FAIL_DIR="$ROOT_DIR/fail"
mkdir -p "$PASS_DIR" "$FAIL_DIR"

DATE="20260307"
docs/qa/generate-docs-scorecard-report.sh \
  --date "$DATE" \
  --output "$PASS_DIR/DOCS_PROGRAM_SCORECARD_${DATE}.md" \
  --quality-output "$PASS_DIR/DOCS_QUALITY_SCORECARD_${DATE}.md" >/tmp/docs_scorecard_drift_seed_pass.out 2>&1

cp "$PASS_DIR/DOCS_PROGRAM_SCORECARD_${DATE}.md" "$FAIL_DIR/DOCS_PROGRAM_SCORECARD_${DATE}.md"
cp "$PASS_DIR/DOCS_QUALITY_SCORECARD_${DATE}.md" "$FAIL_DIR/DOCS_QUALITY_SCORECARD_${DATE}.md"
echo "" >> "$FAIL_DIR/DOCS_QUALITY_SCORECARD_${DATE}.md"
echo "- forced drift line" >> "$FAIL_DIR/DOCS_QUALITY_SCORECARD_${DATE}.md"

PASS_SUMMARY="$ROOT_DIR/pass-summary.json"
docs/qa/verify-docs-scorecard-generation-drift.sh \
  --program-glob "$PASS_DIR/DOCS_PROGRAM_SCORECARD_*.md" \
  --quality-glob "$PASS_DIR/DOCS_QUALITY_SCORECARD_*.md" \
  --summary-json "$PASS_SUMMARY" >/tmp/docs_scorecard_drift_pass.out 2>&1

python3 - "$PASS_SUMMARY" <<'PY'
import json
import sys

payload = json.load(open(sys.argv[1], encoding="utf-8"))
if payload.get("status") != "pass":
    raise SystemExit("expected status=pass")
if payload.get("program_match") is not True:
    raise SystemExit("expected program_match=true")
if payload.get("quality_match") is not True:
    raise SystemExit("expected quality_match=true")
PY

if docs/qa/verify-docs-scorecard-generation-drift.sh \
  --program-glob "$FAIL_DIR/DOCS_PROGRAM_SCORECARD_*.md" \
  --quality-glob "$FAIL_DIR/DOCS_QUALITY_SCORECARD_*.md" >/tmp/docs_scorecard_drift_fail.out 2>&1; then
  echo "expected generation drift failure, got success"
  exit 1
fi

grep -q "DOCS_SCORECARD_DRIFT_FAIL" /tmp/docs_scorecard_drift_fail.out

echo "verify-docs-scorecard-generation-drift self-test: OK"
