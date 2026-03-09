#!/usr/bin/env bash
set -euo pipefail

TMP_ROOT=$(mktemp -d)
trap 'rm -rf "$TMP_ROOT"' EXIT

mkdir -p \
  "$TMP_ROOT/docs/operations" \
  "$TMP_ROOT/docs/architecture" \
  "$TMP_ROOT/docs/runbooks" \
  "$TMP_ROOT/docs/onboarding" \
  "$TMP_ROOT/docs/branding"

cat > "$TMP_ROOT/docs/operations/LIVE.md" <<'EOF_DOC'
# Live Ops Doc

Real content still here.
EOF_DOC

cat > "$TMP_ROOT/docs/architecture/STUB.md" <<'EOF_DOC'
# Architecture System
_Audience: Engineering Team • Owner: Platform Team • Last verified: 2026-03-09 • Status: superseded_

_Superseded by: docs/concepts/architecture/README.md_

This root is transitional compatibility surface during Wave 2.
EOF_DOC

python3 tools/docs/verify/report-nonstub-transitional-files.py \
  --root "$TMP_ROOT" \
  --summary-file "$TMP_ROOT/summary.json" >/tmp/report_nonstub_transitional.out

grep -q "NONSTUB_TRANSITIONAL_FILES_ADVISORY total_nonstub_files=1" /tmp/report_nonstub_transitional.out
grep -q "docs/operations: markdown_files=1 stub_files=0 nonstub_files=1" /tmp/report_nonstub_transitional.out
grep -q "docs/architecture: markdown_files=1 stub_files=1 nonstub_files=0" /tmp/report_nonstub_transitional.out
grep -q '"total_nonstub_files_count": 1' "$TMP_ROOT/summary.json"

if python3 tools/docs/verify/report-nonstub-transitional-files.py \
  --root "$TMP_ROOT" \
  --fail-on-nonstub >/tmp/report_nonstub_transitional_fail.out 2>&1; then
  echo "expected nonstub transitional inventory to fail in strict mode"
  cat /tmp/report_nonstub_transitional_fail.out
  exit 1
fi

grep -q "NONSTUB_TRANSITIONAL_FILES_FAIL total_nonstub_files=1" /tmp/report_nonstub_transitional_fail.out

echo "report-nonstub-transitional-files self-test: OK"
