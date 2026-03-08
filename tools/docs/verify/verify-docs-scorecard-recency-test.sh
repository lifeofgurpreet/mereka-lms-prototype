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

TODAY=$(date -u +%Y%m%d)
YESTERDAY=$(date -u -d "yesterday" +%Y%m%d)
PASS_SUMMARY="$ROOT_DIR/pass-summary.json"

cat > "$ROOT_DIR/DOCS_PROGRAM_SCORECARD_${TODAY}.md" <<EOF_DOC
# test report today
EOF_DOC

cat > "$ROOT_DIR/DOCS_PROGRAM_SCORECARD_${YESTERDAY}.md" <<EOF_DOC
# test report yesterday
EOF_DOC

tools/docs/verify/verify-docs-scorecard-recency.sh \
  --max-age-days 1 \
  --report-glob "$ROOT_DIR/DOCS_PROGRAM_SCORECARD_*.md" \
  --summary-json "$PASS_SUMMARY" >/tmp/docs_scorecard_recency_pass.out 2>&1

python3 - "$PASS_SUMMARY" "$TODAY" <<'PY'
import json
import sys

payload = json.load(open(sys.argv[1], encoding="utf-8"))
expected_date = sys.argv[2]

if payload.get("status") != "pass":
    raise SystemExit("expected pass status")
if payload.get("latest_date") != expected_date:
    raise SystemExit("unexpected latest_date")
if int(payload.get("age_days", 999)) > int(payload.get("max_age_days", 0)):
    raise SystemExit("age should not exceed max age for pass case")
PY

if tools/docs/verify/verify-docs-scorecard-recency.sh \
  --max-age-days 0 \
  --report-glob "$ROOT_DIR/DOCS_PROGRAM_SCORECARD_${YESTERDAY}.md" >/tmp/docs_scorecard_recency_fail.out 2>&1; then
  echo "expected recency failure, got success"
  exit 1
fi

grep -q "DOCS_SCORECARD_RECENCY_FAIL" /tmp/docs_scorecard_recency_fail.out

echo "verify-docs-scorecard-recency self-test: OK"
