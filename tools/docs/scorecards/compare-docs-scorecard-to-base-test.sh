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

BASE_SUMMARY="$ROOT_DIR/base-summary.json"
CURRENT_SUMMARY="$ROOT_DIR/current-summary.json"
PASS_OUT="$ROOT_DIR/compare-pass.json"
FAIL_OUT="$ROOT_DIR/compare-fail.json"

cat > "$BASE_SUMMARY" <<'EOF_JSON'
{
  "canonical_total": 10,
  "canonical_stale": 0,
  "canonical_missing_owner": 0,
  "canonical_missing_verified": 0,
  "canonical_missing_file": 0,
  "canonical_high_risk": 0,
  "all_entries": 10,
  "failures": 0
}
EOF_JSON

cat > "$CURRENT_SUMMARY" <<'EOF_JSON'
{
  "canonical_total": 10,
  "canonical_stale": 1,
  "canonical_missing_owner": 0,
  "canonical_missing_verified": 0,
  "canonical_missing_file": 0,
  "canonical_high_risk": 0,
  "all_entries": 10,
  "failures": 0
}
EOF_JSON

tools/docs/scorecards/compare-docs-scorecard-to-base.sh \
  --current-summary "$CURRENT_SUMMARY" \
  --base-summary "$BASE_SUMMARY" \
  --regression-threshold 15 \
  --out "$PASS_OUT" \
  --base-ref origin/main

if tools/docs/scorecards/compare-docs-scorecard-to-base.sh \
  --current-summary "$CURRENT_SUMMARY" \
  --base-summary "$BASE_SUMMARY" \
  --regression-threshold 1 \
  --out "$FAIL_OUT" \
  --base-ref origin/main; then
  echo "expected comparison failure, got pass"
  exit 1
fi

python3 - "$FAIL_OUT" <<'PY'
import json
import sys

payload = json.load(open(sys.argv[1], encoding="utf-8"))
if payload.get("status") != "fail":
    raise SystemExit(1)
if payload.get("score_drop", 0) <= 0:
    raise SystemExit(1)
PY

echo "compare-docs-scorecard-to-base self-test: OK"
