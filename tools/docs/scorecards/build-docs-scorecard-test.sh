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

PASS_SUMMARY="$ROOT_DIR/summary-pass.json"
FAIL_SUMMARY="$ROOT_DIR/summary-fail.json"
PASS_SCORE="$ROOT_DIR/score-pass.json"
FAIL_SCORE="$ROOT_DIR/score-fail.json"

cat > "$PASS_SUMMARY" <<'EOF_JSON'
{
  "canonical_total": 4,
  "canonical_stale": 0,
  "canonical_missing_owner": 0,
  "canonical_missing_verified": 0,
  "canonical_missing_file": 0,
  "canonical_high_risk": 0,
  "all_entries": 10,
  "failures": 0
}
EOF_JSON

cat > "$FAIL_SUMMARY" <<'EOF_JSON'
{
  "canonical_total": 4,
  "canonical_stale": 3,
  "canonical_missing_owner": 0,
  "canonical_missing_verified": 0,
  "canonical_missing_file": 0,
  "canonical_high_risk": 0,
  "all_entries": 10,
  "failures": 0
}
EOF_JSON

python3 tools/docs/scorecards/build-docs-scorecard.py --summary-file "$PASS_SUMMARY" --out "$PASS_SCORE" --min-score 80

if python3 tools/docs/scorecards/build-docs-scorecard.py --summary-file "$FAIL_SUMMARY" --out "$FAIL_SCORE" --min-score 80 --fail-on-low-score; then
  echo "expected scorecard failure, got pass"
  exit 1
fi

python3 - "$FAIL_SCORE" <<'PY'
import json
import sys

score = json.load(open(sys.argv[1], encoding="utf-8"))
if not isinstance(score, dict):
    raise SystemExit(1)
if score.get("status") != "fail":
    raise SystemExit("expected fail status")
if int(score.get("score", 0)) >= 80:
    raise SystemExit("expected low score")
PY

echo "build-docs-scorecard self-test: expected fail-on-low-score generated"
