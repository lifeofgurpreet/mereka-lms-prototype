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

cat > "$ROOT_DIR/foundation-pass.json" <<'EOF_JSON'
{
  "status": "pass",
  "policy_status": "pass",
  "repo_structure_status": "pass"
}
EOF_JSON

cat > "$ROOT_DIR/foundation-fail.json" <<'EOF_JSON'
{
  "status": "fail",
  "policy_status": "fail",
  "repo_structure_status": "pass"
}
EOF_JSON

cat > "$ROOT_DIR/cmdref-baseline-pass.json" <<'EOF_JSON'
{
  "status": "pass",
  "baseline_file": "docs/qa/.doc-command-ref-baseline",
  "entries": 4,
  "duplicates": [],
  "missing": [],
  "invalid_non_markdown": []
}
EOF_JSON

cat > "$ROOT_DIR/cmdref-baseline-fail.json" <<'EOF_JSON'
{
  "status": "fail",
  "baseline_file": "docs/qa/.doc-command-ref-baseline",
  "entries": 4,
  "duplicates": ["docs/a.md"],
  "missing": ["docs/missing.md"],
  "invalid_non_markdown": []
}
EOF_JSON

cat > "$ROOT_DIR/link-integrity-pass.json" <<'EOF_JSON'
{
  "status": "pass",
  "files_checked": 2,
  "broken_links": 0,
  "broken": []
}
EOF_JSON

cat > "$ROOT_DIR/link-integrity-fail.json" <<'EOF_JSON'
{
  "status": "fail",
  "files_checked": 2,
  "broken_links": 1,
  "broken": ["docs/a.md: ./missing.md"]
}
EOF_JSON

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

cat > "$ROOT_DIR/scorecard-recency-pass.json" <<'EOF_JSON'
{
  "status": "pass",
  "latest_report": "docs/guides/admin/DOCS_PROGRAM_SCORECARD_20260307.md",
  "latest_date": "20260307",
  "age_days": 0,
  "max_age_days": 7
}
EOF_JSON

cat > "$ROOT_DIR/scorecard-recency-fail.json" <<'EOF_JSON'
{
  "status": "fail",
  "latest_report": "docs/guides/admin/DOCS_PROGRAM_SCORECARD_20260301.md",
  "latest_date": "20260301",
  "age_days": 6,
  "max_age_days": 1
}
EOF_JSON

cat > "$ROOT_DIR/scorecard-consistency-pass.json" <<'EOF_JSON'
{
  "status": "pass",
  "reports_checked": 1,
  "invalid_reports": 0,
  "mismatches": []
}
EOF_JSON

cat > "$ROOT_DIR/scorecard-consistency-fail.json" <<'EOF_JSON'
{
  "status": "fail",
  "reports_checked": 1,
  "invalid_reports": 1,
  "mismatches": [
    "docs/guides/admin/DOCS_PROGRAM_SCORECARD_20260308.md: filename_date=20260308 title_date=20260307"
  ]
}
EOF_JSON

cat > "$ROOT_DIR/scorecard-head-freshness-pass.json" <<'EOF_JSON'
{
  "status": "pass",
  "latest_report": "docs/guides/admin/DOCS_PROGRAM_SCORECARD_20260307.md",
  "latest_date": "20260307",
  "reference_date": "20260307"
}
EOF_JSON

cat > "$ROOT_DIR/scorecard-head-freshness-fail.json" <<'EOF_JSON'
{
  "status": "fail",
  "latest_report": "docs/guides/admin/DOCS_PROGRAM_SCORECARD_20260307.md",
  "latest_date": "20260307",
  "reference_date": "20260308"
}
EOF_JSON

cat > "$ROOT_DIR/scorecard-timestamp-pass.json" <<'EOF_JSON'
{
  "status": "pass",
  "reports_checked": 1,
  "invalid_reports": 0,
  "mismatches": []
}
EOF_JSON

cat > "$ROOT_DIR/scorecard-timestamp-fail.json" <<'EOF_JSON'
{
  "status": "fail",
  "reports_checked": 1,
  "invalid_reports": 1,
  "mismatches": [
    "docs/guides/admin/DOCS_PROGRAM_SCORECARD_20260307.md: missing/invalid Last verified (UTC) timestamp"
  ]
}
EOF_JSON

cat > "$ROOT_DIR/scorecard-delta-pass.json" <<'EOF_JSON'
{
  "status": "pass",
  "latest_program_report": "docs/guides/admin/DOCS_PROGRAM_SCORECARD_20260307.md",
  "latest_program_date": "20260307",
  "latest_delta_report": "docs/guides/admin/DOCS_QUALITY_SCORECARD_20260307.md",
  "latest_delta_date": "20260307",
  "date_match": true,
  "has_delta_section": true
}
EOF_JSON

cat > "$ROOT_DIR/scorecard-delta-fail.json" <<'EOF_JSON'
{
  "status": "fail",
  "latest_program_report": "docs/guides/admin/DOCS_PROGRAM_SCORECARD_20260307.md",
  "latest_program_date": "20260307",
  "latest_delta_report": "docs/guides/admin/DOCS_QUALITY_SCORECARD_20260306.md",
  "latest_delta_date": "20260306",
  "date_match": false,
  "has_delta_section": true
}
EOF_JSON

cat > "$ROOT_DIR/scorecard-drift-pass.json" <<'EOF_JSON'
{
  "status": "pass",
  "latest_date": "20260307",
  "program_report": "docs/guides/admin/DOCS_PROGRAM_SCORECARD_20260307.md",
  "quality_report": "docs/guides/admin/DOCS_QUALITY_SCORECARD_20260307.md",
  "program_match": true,
  "quality_match": true
}
EOF_JSON

cat > "$ROOT_DIR/scorecard-drift-fail.json" <<'EOF_JSON'
{
  "status": "fail",
  "latest_date": "20260307",
  "program_report": "docs/guides/admin/DOCS_PROGRAM_SCORECARD_20260307.md",
  "quality_report": "docs/guides/admin/DOCS_QUALITY_SCORECARD_20260307.md",
  "program_match": true,
  "quality_match": false
}
EOF_JSON

python3 docs/qa/build-docs-compliance-summary.py \
  --foundation-summary "$ROOT_DIR/foundation-pass.json" \
  --cmdref-baseline-summary "$ROOT_DIR/cmdref-baseline-pass.json" \
  --link-integrity-summary "$ROOT_DIR/link-integrity-pass.json" \
  --catalog-summary "$ROOT_DIR/catalog-pass.json" \
  --cmdref-summary "$ROOT_DIR/cmdref-pass.json" \
  --scorecard "$ROOT_DIR/scorecard-pass.json" \
  --comparison "$ROOT_DIR/trend-pass.json" \
  --scorecard-recency-summary "$ROOT_DIR/scorecard-recency-pass.json" \
  --scorecard-consistency-summary "$ROOT_DIR/scorecard-consistency-pass.json" \
  --scorecard-head-freshness-summary "$ROOT_DIR/scorecard-head-freshness-pass.json" \
  --scorecard-timestamp-summary "$ROOT_DIR/scorecard-timestamp-pass.json" \
  --scorecard-delta-summary "$ROOT_DIR/scorecard-delta-pass.json" \
  --scorecard-drift-summary "$ROOT_DIR/scorecard-drift-pass.json" \
  --out "$PASS_OUT"

python3 - "$PASS_OUT" <<'PY'
import json
import sys

payload = json.load(open(sys.argv[1], encoding="utf-8"))
if payload.get("overall_status") != "pass":
    raise SystemExit("expected overall_status=pass")
PY

python3 docs/qa/build-docs-compliance-summary.py \
  --foundation-summary "$ROOT_DIR/foundation-pass.json" \
  --cmdref-baseline-summary "$ROOT_DIR/cmdref-baseline-pass.json" \
  --link-integrity-summary "$ROOT_DIR/link-integrity-pass.json" \
  --catalog-summary "$ROOT_DIR/catalog-pass.json" \
  --cmdref-summary "$ROOT_DIR/cmdref-fail.json" \
  --scorecard "$ROOT_DIR/scorecard-pass.json" \
  --comparison "$ROOT_DIR/trend-pass.json" \
  --scorecard-recency-summary "$ROOT_DIR/scorecard-recency-pass.json" \
  --scorecard-consistency-summary "$ROOT_DIR/scorecard-consistency-pass.json" \
  --scorecard-head-freshness-summary "$ROOT_DIR/scorecard-head-freshness-pass.json" \
  --scorecard-timestamp-summary "$ROOT_DIR/scorecard-timestamp-pass.json" \
  --scorecard-delta-summary "$ROOT_DIR/scorecard-delta-pass.json" \
  --scorecard-drift-summary "$ROOT_DIR/scorecard-drift-pass.json" \
  --out "$FAIL_OUT" || true

python3 - "$FAIL_OUT" <<'PY'
import json
import sys

payload = json.load(open(sys.argv[1], encoding="utf-8"))
if payload.get("overall_status") != "fail":
    raise SystemExit("expected overall_status=fail")
PY

python3 docs/qa/build-docs-compliance-summary.py \
  --foundation-summary "$ROOT_DIR/foundation-pass.json" \
  --cmdref-baseline-summary "$ROOT_DIR/cmdref-baseline-pass.json" \
  --link-integrity-summary "$ROOT_DIR/link-integrity-pass.json" \
  --catalog-summary "$ROOT_DIR/catalog-pass.json" \
  --cmdref-summary "$ROOT_DIR/cmdref-pass.json" \
  --scorecard "$ROOT_DIR/scorecard-warn.json" \
  --comparison "$ROOT_DIR/trend-pass.json" \
  --scorecard-recency-summary "$ROOT_DIR/scorecard-recency-pass.json" \
  --scorecard-consistency-summary "$ROOT_DIR/scorecard-consistency-pass.json" \
  --scorecard-head-freshness-summary "$ROOT_DIR/scorecard-head-freshness-pass.json" \
  --scorecard-timestamp-summary "$ROOT_DIR/scorecard-timestamp-pass.json" \
  --scorecard-delta-summary "$ROOT_DIR/scorecard-delta-pass.json" \
  --scorecard-drift-summary "$ROOT_DIR/scorecard-drift-pass.json" \
  --out "$WARN_OUT"

python3 - "$WARN_OUT" <<'PY'
import json
import sys

payload = json.load(open(sys.argv[1], encoding="utf-8"))
if payload.get("overall_status") != "warn":
    raise SystemExit("expected overall_status=warn")
PY

if python3 docs/qa/build-docs-compliance-summary.py \
  --foundation-summary "$ROOT_DIR/foundation-fail.json" \
  --cmdref-baseline-summary "$ROOT_DIR/cmdref-baseline-fail.json" \
  --link-integrity-summary "$ROOT_DIR/link-integrity-fail.json" \
  --catalog-summary "$ROOT_DIR/catalog-pass.json" \
  --cmdref-summary "$ROOT_DIR/cmdref-pass.json" \
  --scorecard "$ROOT_DIR/scorecard-fail.json" \
  --comparison "$ROOT_DIR/trend-fail.json" \
  --scorecard-recency-summary "$ROOT_DIR/scorecard-recency-fail.json" \
  --scorecard-consistency-summary "$ROOT_DIR/scorecard-consistency-fail.json" \
  --scorecard-head-freshness-summary "$ROOT_DIR/scorecard-head-freshness-fail.json" \
  --scorecard-timestamp-summary "$ROOT_DIR/scorecard-timestamp-fail.json" \
  --scorecard-delta-summary "$ROOT_DIR/scorecard-delta-fail.json" \
  --scorecard-drift-summary "$ROOT_DIR/scorecard-drift-fail.json" \
  --out /tmp/does-not-exist.json >/tmp/compliance-summary-fail.out 2>&1; then
  echo "expected command to fail for terminal fail status"
  cat /tmp/compliance-summary-fail.out
  exit 1
fi

echo "build-docs-compliance-summary self-test: OK"
