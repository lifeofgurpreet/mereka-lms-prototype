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
INCONSISTENT_OUT="$ROOT_DIR/summary-inconsistent.json"

cat > "$ROOT_DIR/foundation-pass.json" <<'EOF_JSON'
{
  "status": "pass",
  "policy_status": "pass",
  "repo_structure_status": "pass",
  "policy_range": "origin/main...HEAD",
  "policy_root_allowlist_violations": 0,
  "policy_changed_markdown_files": 2,
  "policy_content_status": "pass",
  "policy_content_errors": []
}
EOF_JSON

cat > "$ROOT_DIR/foundation-fail.json" <<'EOF_JSON'
{
  "status": "fail",
  "policy_status": "fail",
  "repo_structure_status": "pass",
  "policy_range": "origin/main...HEAD",
  "policy_root_allowlist_violations": 1,
  "policy_changed_markdown_files": 2,
  "policy_content_status": "fail",
  "policy_content_errors": [
    "docs/example.md: canonical subtitle metadata missing `Owner`"
  ]
}
EOF_JSON

cat > "$ROOT_DIR/foundation-inconsistent.json" <<'EOF_JSON'
{
  "status": "pass",
  "policy_status": "pass",
  "repo_structure_status": "pass",
  "policy_range": "origin/main...HEAD",
  "policy_root_allowlist_violations": 0,
  "policy_changed_markdown_files": 2,
  "policy_content_status": "pass",
  "policy_content_errors": [
    "docs/example.md: canonical subtitle metadata missing `Owner`"
  ]
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
  "candidate_sources": {
    "inline_code": 1,
    "shell_block": 1,
    "markdown_link": 1,
    "markdown_autolink": 0,
    "markdown_refdef": 0
  },
  "missing_references": 0,
  "missing": []
}
EOF_JSON

cat > "$ROOT_DIR/cmdref-fail.json" <<'EOF_JSON'
{
  "status": "fail",
  "files_checked": 2,
  "total_candidates": 3,
  "candidate_sources": {
    "inline_code": 1,
    "shell_block": 2,
    "markdown_link": 0,
    "markdown_autolink": 0
  },
  "missing_references": 1,
  "missing": [
    "docs/example.md: missing /tmp/cmd"
  ]
}
EOF_JSON

cat > "$ROOT_DIR/cmdref-minimal.json" <<'EOF_JSON'
{
  "status": "pass",
  "files_checked": 0,
  "total_candidates": 0,
  "missing_references": 0,
  "missing": []
}
EOF_JSON

cat > "$ROOT_DIR/cmdref-invalid-sources.json" <<'EOF_JSON'
{
  "status": "pass",
  "files_checked": 1,
  "total_candidates": 1,
  "candidate_sources": {
    "inline_code": "2",
    "shell_block": -3,
    "markdown_link": "x",
    "markdown_autolink": null
  },
  "missing_references": 0,
  "missing": []
}
EOF_JSON

cat > "$ROOT_DIR/cmdref-invalid-shape.json" <<'EOF_JSON'
{
  "status": "pass",
  "files_checked": "7",
  "baseline_enabled": true,
  "baseline_entries": "3",
  "total_candidates": "-8",
  "candidate_sources": "not-an-object",
  "missing_references": "bad",
  "missing": []
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
foundation = payload.get("foundation_gates", {})
statuses = payload.get("statuses", {})
command_refs = payload.get("command_refs", {})
if foundation.get("policy_range") != "origin/main...HEAD":
    raise SystemExit("expected foundation policy_range to be preserved")
if foundation.get("policy_root_allowlist_violations") != 0:
    raise SystemExit("expected no root allowlist violations in pass payload")
if foundation.get("policy_content_status") != "pass":
    raise SystemExit("expected policy_content_status=pass in pass payload")
if foundation.get("policy_content_consistent") is not True:
    raise SystemExit("expected policy_content_consistent=true in pass payload")
if statuses.get("foundation_policy_content") != "pass":
    raise SystemExit("expected statuses.foundation_policy_content=pass")
if statuses.get("foundation_policy_content_consistency") != "pass":
    raise SystemExit("expected statuses.foundation_policy_content_consistency=pass")
if statuses.get("foundation_policy_content_alignment") != "pass":
    raise SystemExit("expected statuses.foundation_policy_content_alignment=pass")
if command_refs.get("candidate_sources", {}).get("inline_code") != 1:
    raise SystemExit("expected command_refs.candidate_sources.inline_code=1 in pass payload")
if command_refs.get("candidate_sources", {}).get("shell_block") != 1:
    raise SystemExit("expected command_refs.candidate_sources.shell_block=1 in pass payload")
PY

python3 docs/qa/build-docs-compliance-summary.py \
  --foundation-summary "$ROOT_DIR/foundation-pass.json" \
  --cmdref-baseline-summary "$ROOT_DIR/cmdref-baseline-pass.json" \
  --link-integrity-summary "$ROOT_DIR/link-integrity-pass.json" \
  --catalog-summary "$ROOT_DIR/catalog-pass.json" \
  --cmdref-summary "$ROOT_DIR/cmdref-minimal.json" \
  --scorecard "$ROOT_DIR/scorecard-pass.json" \
  --comparison "$ROOT_DIR/trend-pass.json" \
  --scorecard-recency-summary "$ROOT_DIR/scorecard-recency-pass.json" \
  --scorecard-consistency-summary "$ROOT_DIR/scorecard-consistency-pass.json" \
  --scorecard-head-freshness-summary "$ROOT_DIR/scorecard-head-freshness-pass.json" \
  --scorecard-timestamp-summary "$ROOT_DIR/scorecard-timestamp-pass.json" \
  --scorecard-delta-summary "$ROOT_DIR/scorecard-delta-pass.json" \
  --scorecard-drift-summary "$ROOT_DIR/scorecard-drift-pass.json" \
  --out "$ROOT_DIR/summary-minimal-cmdref.json"

python3 - "$ROOT_DIR/summary-minimal-cmdref.json" <<'PY'
import json
import sys

payload = json.load(open(sys.argv[1], encoding="utf-8"))
sources = payload.get("command_refs", {}).get("candidate_sources", {})
required = {"inline_code", "shell_block", "markdown_link", "markdown_autolink", "markdown_refdef"}
if set(sources.keys()) != required:
    raise SystemExit("expected normalized candidate_sources keys for minimal cmdref summary")
if any(sources[k] != 0 for k in required):
    raise SystemExit("expected normalized candidate_sources values to be zero for minimal cmdref summary")
PY

python3 docs/qa/build-docs-compliance-summary.py \
  --foundation-summary "$ROOT_DIR/foundation-pass.json" \
  --cmdref-baseline-summary "$ROOT_DIR/cmdref-baseline-pass.json" \
  --link-integrity-summary "$ROOT_DIR/link-integrity-pass.json" \
  --catalog-summary "$ROOT_DIR/catalog-pass.json" \
  --cmdref-summary "$ROOT_DIR/cmdref-invalid-sources.json" \
  --scorecard "$ROOT_DIR/scorecard-pass.json" \
  --comparison "$ROOT_DIR/trend-pass.json" \
  --scorecard-recency-summary "$ROOT_DIR/scorecard-recency-pass.json" \
  --scorecard-consistency-summary "$ROOT_DIR/scorecard-consistency-pass.json" \
  --scorecard-head-freshness-summary "$ROOT_DIR/scorecard-head-freshness-pass.json" \
  --scorecard-timestamp-summary "$ROOT_DIR/scorecard-timestamp-pass.json" \
  --scorecard-delta-summary "$ROOT_DIR/scorecard-delta-pass.json" \
  --scorecard-drift-summary "$ROOT_DIR/scorecard-drift-pass.json" \
  --out "$ROOT_DIR/summary-invalid-sources.json"

python3 - "$ROOT_DIR/summary-invalid-sources.json" <<'PY'
import json
import sys

payload = json.load(open(sys.argv[1], encoding="utf-8"))
sources = payload.get("command_refs", {}).get("candidate_sources", {})
if sources.get("inline_code") != 2:
    raise SystemExit("expected inline_code string to normalize to int")
if sources.get("shell_block") != 0:
    raise SystemExit("expected negative shell_block to normalize to 0")
if sources.get("markdown_link") != 0:
    raise SystemExit("expected non-numeric markdown_link to normalize to 0")
if sources.get("markdown_autolink") != 0:
    raise SystemExit("expected null markdown_autolink to normalize to 0")
if sources.get("markdown_refdef") != 0:
    raise SystemExit("expected missing markdown_refdef to normalize to 0")
PY

python3 docs/qa/build-docs-compliance-summary.py \
  --foundation-summary "$ROOT_DIR/foundation-pass.json" \
  --cmdref-baseline-summary "$ROOT_DIR/cmdref-baseline-pass.json" \
  --link-integrity-summary "$ROOT_DIR/link-integrity-pass.json" \
  --catalog-summary "$ROOT_DIR/catalog-pass.json" \
  --cmdref-summary "$ROOT_DIR/cmdref-invalid-shape.json" \
  --scorecard "$ROOT_DIR/scorecard-pass.json" \
  --comparison "$ROOT_DIR/trend-pass.json" \
  --scorecard-recency-summary "$ROOT_DIR/scorecard-recency-pass.json" \
  --scorecard-consistency-summary "$ROOT_DIR/scorecard-consistency-pass.json" \
  --scorecard-head-freshness-summary "$ROOT_DIR/scorecard-head-freshness-pass.json" \
  --scorecard-timestamp-summary "$ROOT_DIR/scorecard-timestamp-pass.json" \
  --scorecard-delta-summary "$ROOT_DIR/scorecard-delta-pass.json" \
  --scorecard-drift-summary "$ROOT_DIR/scorecard-drift-pass.json" \
  --out "$ROOT_DIR/summary-invalid-shape.json"

python3 - "$ROOT_DIR/summary-invalid-shape.json" <<'PY'
import json
import sys

payload = json.load(open(sys.argv[1], encoding="utf-8"))
command_refs = payload.get("command_refs", {})
if command_refs.get("files_checked") != 7:
    raise SystemExit("expected files_checked string to normalize to int")
if command_refs.get("baseline_entries") != 3:
    raise SystemExit("expected baseline_entries string to normalize to int")
if command_refs.get("total_candidates") != 0:
    raise SystemExit("expected negative total_candidates to normalize to 0")
if command_refs.get("missing_references") != 0:
    raise SystemExit("expected non-numeric missing_references to normalize to 0")
sources = command_refs.get("candidate_sources", {})
required = {"inline_code", "shell_block", "markdown_link", "markdown_autolink", "markdown_refdef"}
if set(sources.keys()) != required:
    raise SystemExit("expected candidate_sources non-dict input to normalize to required keys")
if any(sources[k] != 0 for k in required):
    raise SystemExit("expected candidate_sources non-dict input to normalize to zeros")
PY

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
  --out /tmp/build-docs-compliance-summary-pass-stdout.json >/tmp/build-docs-compliance-summary-pass-stdout.out 2>&1
grep -q "policy_content=pass" /tmp/build-docs-compliance-summary-pass-stdout.out
grep -q "policy_content_consistency_status=pass" /tmp/build-docs-compliance-summary-pass-stdout.out
grep -q "policy_content_consistent=true" /tmp/build-docs-compliance-summary-pass-stdout.out
grep -q "cmdref_baseline_enabled=false" /tmp/build-docs-compliance-summary-pass-stdout.out
grep -q "cmdref_baseline_entries=0" /tmp/build-docs-compliance-summary-pass-stdout.out
grep -q "cmdref_missing_refs=0" /tmp/build-docs-compliance-summary-pass-stdout.out
grep -q "cmdref_candidates_inline=1" /tmp/build-docs-compliance-summary-pass-stdout.out
grep -q "cmdref_candidates_md_link=1" /tmp/build-docs-compliance-summary-pass-stdout.out
grep -q "cmdref_candidates_md_autolink=0" /tmp/build-docs-compliance-summary-pass-stdout.out
grep -q "cmdref_candidates_md_refdef=0" /tmp/build-docs-compliance-summary-pass-stdout.out

python3 docs/qa/build-docs-compliance-summary.py \
  --foundation-summary "$ROOT_DIR/foundation-inconsistent.json" \
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
  --out "$INCONSISTENT_OUT" || true

python3 - "$INCONSISTENT_OUT" <<'PY'
import json
import sys

payload = json.load(open(sys.argv[1], encoding="utf-8"))
if payload.get("overall_status") != "fail":
    raise SystemExit("expected overall_status=fail for inconsistent foundation policy content")
foundation = payload.get("foundation_gates", {})
statuses = payload.get("statuses", {})
if foundation.get("policy_content_status") != "fail":
    raise SystemExit("expected policy_content_status=fail when content_errors are present")
if foundation.get("policy_content_consistent") is not False:
    raise SystemExit("expected policy_content_consistent=false for inconsistent input")
if statuses.get("foundation_policy_content") != "fail":
    raise SystemExit("expected statuses.foundation_policy_content=fail for inconsistent input")
if statuses.get("foundation_policy_content_consistency") != "fail":
    raise SystemExit("expected statuses.foundation_policy_content_consistency=fail for inconsistent input")
if statuses.get("foundation_policy_content_alignment") != "fail":
    raise SystemExit("expected statuses.foundation_policy_content_alignment=fail for inconsistent input")
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
if payload.get("command_refs", {}).get("candidate_sources", {}).get("shell_block") != 2:
    raise SystemExit("expected command_refs.candidate_sources.shell_block=2 in fail payload")
if payload.get("command_refs", {}).get("candidate_sources", {}).get("markdown_refdef") != 0:
    raise SystemExit("expected missing command_refs.candidate_sources.markdown_refdef to normalize to 0")
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
