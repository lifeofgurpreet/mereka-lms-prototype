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

cat > "$PASS_DIR/DOCS_PROGRAM_SCORECARD_20260308.md" <<'EOF_DOC'
# Docs Program Scorecard 20260308
EOF_DOC

cat > "$FAIL_DIR/DOCS_PROGRAM_SCORECARD_20260307.md" <<'EOF_DOC'
# Docs Program Scorecard 20260307
EOF_DOC

PASS_SUMMARY="$ROOT_DIR/head-fresh-pass-summary.json"
tools/docs/verify/verify-docs-scorecard-head-freshness.sh \
  --report-glob "$PASS_DIR/DOCS_PROGRAM_SCORECARD_*.md" \
  --reference-date 20260308 \
  --summary-json "$PASS_SUMMARY" >/tmp/docs_scorecard_head_freshness_pass.out 2>&1

python3 - "$PASS_SUMMARY" <<'PY'
import json
import sys
payload = json.load(open(sys.argv[1], encoding="utf-8"))
if payload.get("status") != "pass":
    raise SystemExit("expected pass")
if payload.get("latest_date") != "20260308":
    raise SystemExit("unexpected latest date")
if payload.get("reference_date") != "20260308":
    raise SystemExit("unexpected reference date")
PY

if tools/docs/verify/verify-docs-scorecard-head-freshness.sh \
  --report-glob "$FAIL_DIR/DOCS_PROGRAM_SCORECARD_*.md" \
  --reference-date 20260308 >/tmp/docs_scorecard_head_freshness_fail.out 2>&1; then
  echo "expected head freshness failure, got success"
  exit 1
fi

grep -q "DOCS_SCORECARD_HEAD_FRESHNESS_FAIL" /tmp/docs_scorecard_head_freshness_fail.out

echo "verify-docs-scorecard-head-freshness self-test: OK"
