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
EOF_DOC

cat > "$PASS_DIR/DOCS_QUALITY_SCORECARD_20260307.md" <<'EOF_DOC'
# Docs Quality Scorecard — 2026-03-07
## One-Week Scorecard Delta (Docs Compliance Gates)
EOF_DOC

cat > "$FAIL_DIR/DOCS_PROGRAM_SCORECARD_20260307.md" <<'EOF_DOC'
# Docs Program Scorecard 20260307
EOF_DOC

cat > "$FAIL_DIR/DOCS_QUALITY_SCORECARD_20260306.md" <<'EOF_DOC'
# Docs Quality Scorecard — 2026-03-06
## One-Week Scorecard Delta (Docs Compliance Gates)
EOF_DOC

PASS_SUMMARY="$ROOT_DIR/pass-summary.json"
docs/qa/verify-docs-scorecard-delta-artifact.sh \
  --program-glob "$PASS_DIR/DOCS_PROGRAM_SCORECARD_*.md" \
  --delta-glob "$PASS_DIR/DOCS_QUALITY_SCORECARD_*.md" \
  --summary-json "$PASS_SUMMARY" >/tmp/docs_scorecard_delta_pass.out 2>&1

python3 - "$PASS_SUMMARY" <<'PY'
import json
import sys

payload = json.load(open(sys.argv[1], encoding="utf-8"))
if payload.get("status") != "pass":
    raise SystemExit("expected status=pass")
if payload.get("date_match") is not True:
    raise SystemExit("expected date_match=true")
if payload.get("has_delta_section") is not True:
    raise SystemExit("expected has_delta_section=true")
PY

if docs/qa/verify-docs-scorecard-delta-artifact.sh \
  --program-glob "$FAIL_DIR/DOCS_PROGRAM_SCORECARD_*.md" \
  --delta-glob "$FAIL_DIR/DOCS_QUALITY_SCORECARD_*.md" >/tmp/docs_scorecard_delta_fail.out 2>&1; then
  echo "expected delta artifact failure, got success"
  exit 1
fi

grep -q "DOCS_SCORECARD_DELTA_FAIL" /tmp/docs_scorecard_delta_fail.out

echo "verify-docs-scorecard-delta-artifact self-test: OK"
