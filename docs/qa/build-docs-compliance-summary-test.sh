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

PASS_OUT="$ROOT_DIR/summary-pass.json"
FAIL_OUT="$ROOT_DIR/summary-fail.json"
WARN_OUT="$ROOT_DIR/summary-warn.json"

cat > "$ROOT_DIR/catalog-pass.json" <<'EOF_JSON'
{
  "failed": false,
  "canonical_total": 10,
  "canonical_stale": 0,
  "canonical_missing_owner": 0,
  "canonical_missing_verified": 0,
  "canonical_missing_file": 0,
  "canonical_high_risk": 0
}
EOF_JSON

cat > "$ROOT_DIR/cmdref-pass.json" <<'EOF_JSON'
{
  "status": "pass",
  "files_checked": 2,
  "total_candidates": 3,
  "missing_references": 0,
  "missing": []
}
EOF_JSON

cat > "$ROOT_DIR/cmdref-fail.json" <<'EOF_JSON'
{
  "status": "fail",
  "files_checked": 2,
  "total_candidates": 3,
  "missing_references": 1,
  "missing": [
    "docs/example.md: missing /tmp/cmd"
  ]
}
EOF_JSON

cat > "$ROOT_DIR/scorecard-pass.json" <<'EOF_JSON'
{
  "status": "pass",
  "score": 88,
  "threshold": {"min_score": 80},
  "catalog_metrics": {}
}
EOF_JSON

cat > "$ROOT_DIR/scorecard-warn.json" <<'EOF_JSON'
{
  "status": "warn",
  "score": 72,
  "threshold": {"min_score": 80},
  "catalog_metrics": {}
}
EOF_JSON

cat > "$ROOT_DIR/scorecard-fail.json" <<'EOF_JSON'
{
  "status": "fail",
  "score": 52,
  "threshold": {"min_score": 80},
  "catalog_metrics": {}
}
EOF_JSON

cat > "$ROOT_DIR/trend-pass.json" <<'EOF_JSON'
{
  "base_ref": "origin/main",
  "base_score": 90,
  "current_score": 88,
  "score_drop": 2,
  "max_allowed_drop": 10,
  "status": "pass"
}
EOF_JSON

cat > "$ROOT_DIR/trend-fail.json" <<'EOF_JSON'
{
  "base_ref": "origin/main",
  "base_score": 90,
  "current_score": 70,
  "score_drop": 20,
  "max_allowed_drop": 10,
  "status": "fail"
}
EOF_JSON

python3 docs/qa/build-docs-compliance-summary.py \
  --catalog-summary "$ROOT_DIR/catalog-pass.json" \
  --cmdref-summary "$ROOT_DIR/cmdref-pass.json" \
  --scorecard "$ROOT_DIR/scorecard-pass.json" \
  --comparison "$ROOT_DIR/trend-pass.json" \
  --out "$PASS_OUT"

python3 - "$PASS_OUT" <<'PY'
import json
import sys

payload = json.load(open(sys.argv[1], encoding="utf-8"))
if payload.get("overall_status") != "pass":
    raise SystemExit("expected overall_status=pass")
PY

python3 docs/qa/build-docs-compliance-summary.py \
  --catalog-summary "$ROOT_DIR/catalog-pass.json" \
  --cmdref-summary "$ROOT_DIR/cmdref-fail.json" \
  --scorecard "$ROOT_DIR/scorecard-pass.json" \
  --comparison "$ROOT_DIR/trend-pass.json" \
  --out "$FAIL_OUT" || true

python3 - "$FAIL_OUT" <<'PY'
import json
import sys

payload = json.load(open(sys.argv[1], encoding="utf-8"))
if payload.get("overall_status") != "fail":
    raise SystemExit("expected overall_status=fail")
PY

python3 docs/qa/build-docs-compliance-summary.py \
  --catalog-summary "$ROOT_DIR/catalog-pass.json" \
  --cmdref-summary "$ROOT_DIR/cmdref-pass.json" \
  --scorecard "$ROOT_DIR/scorecard-warn.json" \
  --comparison "$ROOT_DIR/trend-pass.json" \
  --out "$WARN_OUT"

python3 - "$WARN_OUT" <<'PY'
import json
import sys

payload = json.load(open(sys.argv[1], encoding="utf-8"))
if payload.get("overall_status") != "warn":
    raise SystemExit("expected overall_status=warn")
PY

if python3 docs/qa/build-docs-compliance-summary.py \
  --catalog-summary "$ROOT_DIR/catalog-pass.json" \
  --cmdref-summary "$ROOT_DIR/cmdref-pass.json" \
  --scorecard "$ROOT_DIR/scorecard-fail.json" \
  --comparison "$ROOT_DIR/trend-fail.json" \
  --out /tmp/does-not-exist.json >/tmp/compliance-summary-fail.out 2>&1; then
  echo "expected command to fail for terminal fail status"
  cat /tmp/compliance-summary-fail.out
  exit 1
fi

echo "build-docs-compliance-summary self-test: OK"
