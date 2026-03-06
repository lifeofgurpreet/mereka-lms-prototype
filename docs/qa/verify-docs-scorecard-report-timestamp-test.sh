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

cat > "$PASS_DIR/DOCS_PROGRAM_SCORECARD_20260307.md" <<'EOF_DOC'
# Docs Program Scorecard 20260307
_Audience: Docs Lead + Domain Owners • Owner: Platform Team • Last verified (UTC): 2026-03-07T00:00:00Z • Status: supporting_
EOF_DOC

cat > "$FAIL_DIR/DOCS_PROGRAM_SCORECARD_20260307.md" <<'EOF_DOC'
# Docs Program Scorecard 20260307
_Audience: Docs Lead + Domain Owners • Owner: Platform Team • Last verified (UTC): 2026-03-07 00:00:00 • Status: supporting_
EOF_DOC

PASS_SUMMARY="$ROOT_DIR/timestamp-pass-summary.json"
docs/qa/verify-docs-scorecard-report-timestamp.sh \
  --report-glob "$PASS_DIR/DOCS_PROGRAM_SCORECARD_*.md" \
  --summary-json "$PASS_SUMMARY" >/tmp/docs_scorecard_timestamp_pass.out 2>&1

python3 - "$PASS_SUMMARY" <<'PY'
import json
import sys
payload = json.load(open(sys.argv[1], encoding="utf-8"))
if payload.get("status") != "pass":
    raise SystemExit("expected pass")
if int(payload.get("invalid_reports", 1)) != 0:
    raise SystemExit("expected 0 invalid reports")
PY

if docs/qa/verify-docs-scorecard-report-timestamp.sh \
  --report-glob "$FAIL_DIR/DOCS_PROGRAM_SCORECARD_*.md" >/tmp/docs_scorecard_timestamp_fail.out 2>&1; then
  echo "expected timestamp format failure, got success"
  exit 1
fi

grep -q "DOCS_SCORECARD_TIMESTAMP_FAIL" /tmp/docs_scorecard_timestamp_fail.out

echo "verify-docs-scorecard-report-timestamp self-test: OK"
