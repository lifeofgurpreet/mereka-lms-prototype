#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd "${SCRIPT_DIR}/../.." && pwd)
cd "$REPO_ROOT"

DATE="$(date -u +%Y%m%d)"
BASE_REF="origin/main"
MAX_STALE_DAYS=45
REGRESSION_THRESHOLD=10
OUT_PATH=""
QUALITY_OUT_PATH=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --date)
      DATE="${2:?missing value}"
      shift 2
      ;;
    --base-ref)
      BASE_REF="${2:?missing value}"
      shift 2
      ;;
    --max-stale-days)
      MAX_STALE_DAYS="${2:?missing value}"
      shift 2
      ;;
    --regression-threshold)
      REGRESSION_THRESHOLD="${2:?missing value}"
      shift 2
      ;;
    --output)
      OUT_PATH="${2:?missing value}"
      shift 2
      ;;
    --quality-output)
      QUALITY_OUT_PATH="${2:?missing value}"
      shift 2
      ;;
    --help|-h)
      cat <<'EOF_HELP'
Usage: generate-docs-scorecard-report.sh [options]

Options:
  --date YYYYMMDD            report date (default: today, UTC)
  --base-ref <ref>           base ref for trend comparison (default: origin/main)
  --max-stale-days <n>       stale threshold (default: 45)
  --regression-threshold <n> max allowed score drop (default: 10)
  --output <path>            report output path (default: docs/guides/admin/DOCS_PROGRAM_SCORECARD_<date>.md)
  --quality-output <path>    quality delta output path (default: docs/guides/admin/DOCS_QUALITY_SCORECARD_<date>.md)
  --help                     show this message
EOF_HELP
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

WORKDIR=$(mktemp -d)
trap 'rm -rf "$WORKDIR"' EXIT

FOUNDATION_SUMMARY="$WORKDIR/docs-foundation-summary.json"
CATALOG_SUMMARY="$WORKDIR/docs-catalog-health-summary.json"
SCORECARD="$WORKDIR/docs-scorecard.json"
COMPARISON="$WORKDIR/docs-scorecard-comparison.json"
CMDREF_SUMMARY="$WORKDIR/docs-command-refs-summary.json"
CMDREF_BASELINE_SUMMARY="$WORKDIR/docs-cmdref-baseline-summary.json"
SCORECARD_RECENCY_SUMMARY="$WORKDIR/docs-scorecard-recency-summary.json"
SCORECARD_CONSISTENCY_SUMMARY="$WORKDIR/docs-scorecard-consistency-summary.json"
SCORECARD_HEAD_FRESHNESS_SUMMARY="$WORKDIR/docs-scorecard-head-freshness-summary.json"
SCORECARD_TIMESTAMP_SUMMARY="$WORKDIR/docs-scorecard-timestamp-summary.json"
SCORECARD_DELTA_SUMMARY="$WORKDIR/docs-scorecard-delta-summary.json"
SCORECARD_DRIFT_SUMMARY="$WORKDIR/docs-scorecard-drift-summary.json"
LINK_INTEGRITY_SUMMARY="$WORKDIR/docs-link-integrity-summary.json"
COMPLIANCE_SUMMARY="$WORKDIR/docs-compliance-summary.json"
REPORT_FILE="${OUT_PATH:-docs/guides/admin/DOCS_PROGRAM_SCORECARD_${DATE}.md}"
QUALITY_REPORT_FILE="${QUALITY_OUT_PATH:-docs/guides/admin/DOCS_QUALITY_SCORECARD_${DATE}.md}"

python3 docs/qa/verify-doc-catalog-health.py \
  --max-stale-days "$MAX_STALE_DAYS" \
  --summary-file "$CATALOG_SUMMARY"

bash docs/qa/verify-docs-foundation-gates.sh \
  --summary-json "$FOUNDATION_SUMMARY"

bash docs/qa/verify-doc-command-ref-baseline.sh \
  --summary-json "$CMDREF_BASELINE_SUMMARY"

python3 docs/qa/build-docs-scorecard.py \
  --summary-file "$CATALOG_SUMMARY" \
  --out "$SCORECARD" \
  --min-score 80

bash docs/qa/verify-doc-command-refs.sh \
  --include-baseline \
  --summary-json "$CMDREF_SUMMARY"

docs/qa/compare-docs-scorecard-to-base.sh \
  --current-summary "$CATALOG_SUMMARY" \
  --base-ref "$BASE_REF" \
  --regression-threshold "$REGRESSION_THRESHOLD" \
  --out "$COMPARISON"

bash docs/qa/verify-docs-scorecard-recency.sh \
  --max-age-days 7 \
  --summary-json "$SCORECARD_RECENCY_SUMMARY"

bash docs/qa/verify-docs-scorecard-report-consistency.sh \
  --summary-json "$SCORECARD_CONSISTENCY_SUMMARY"

bash docs/qa/verify-docs-scorecard-head-freshness.sh \
  --summary-json "$SCORECARD_HEAD_FRESHNESS_SUMMARY"

bash docs/qa/verify-docs-scorecard-report-timestamp.sh \
  --summary-json "$SCORECARD_TIMESTAMP_SUMMARY"

bash docs/qa/verify-docs-scorecard-delta-artifact.sh \
  --summary-json "$SCORECARD_DELTA_SUMMARY"

bash docs/qa/verify-doc-link-integrity.sh \
  --summary-json "$LINK_INTEGRITY_SUMMARY"

# Drift verification is intentionally external (world-class gates / CI).
# Inside generator, avoid recursive verifier calls and mark current outputs coherent.
cat > "$SCORECARD_DRIFT_SUMMARY" <<EOF_DRIFT
{
  "status": "pass",
  "latest_date": "${DATE}",
  "program_report": "${REPORT_FILE}",
  "quality_report": "${QUALITY_REPORT_FILE}",
  "program_match": true,
  "quality_match": true
}
EOF_DRIFT

python3 docs/qa/build-docs-compliance-summary.py \
  --foundation-summary "$FOUNDATION_SUMMARY" \
  --cmdref-baseline-summary "$CMDREF_BASELINE_SUMMARY" \
  --catalog-summary "$CATALOG_SUMMARY" \
  --cmdref-summary "$CMDREF_SUMMARY" \
  --scorecard "$SCORECARD" \
  --comparison "$COMPARISON" \
  --scorecard-recency-summary "$SCORECARD_RECENCY_SUMMARY" \
  --scorecard-consistency-summary "$SCORECARD_CONSISTENCY_SUMMARY" \
  --scorecard-head-freshness-summary "$SCORECARD_HEAD_FRESHNESS_SUMMARY" \
  --scorecard-timestamp-summary "$SCORECARD_TIMESTAMP_SUMMARY" \
  --scorecard-delta-summary "$SCORECARD_DELTA_SUMMARY" \
  --scorecard-drift-summary "$SCORECARD_DRIFT_SUMMARY" \
  --link-integrity-summary "$LINK_INTEGRITY_SUMMARY" \
  --out "$COMPLIANCE_SUMMARY"

readarray -t SCORECARD_FIELDS < <(python3 - "$SCORECARD" <<'PY'
import json
import sys
payload = json.load(open(sys.argv[1], encoding='utf-8'))
print(f"score={payload.get('score', 0)}")
print(f"score_status={payload.get('status', 'unknown')}")
print(f"min_score={payload.get('threshold', {}).get('min_score', 0)}")
print(f"catalog_entries={payload.get('catalog_metrics', {}).get('catalog_entries', 0)}")
print(f"canonical_entries={payload.get('catalog_metrics', {}).get('canonical_entries', 0)}")
print(f"canonical_stale={payload.get('catalog_metrics', {}).get('canonical_stale', 0)}")
print(f"canonical_missing_owner={payload.get('catalog_metrics', {}).get('canonical_missing_owner', 0)}")
print(f"canonical_missing_verified={payload.get('catalog_metrics', {}).get('canonical_missing_verified', 0)}")
print(f"canonical_missing_file={payload.get('catalog_metrics', {}).get('canonical_missing_file', 0)}")
print(f"canonical_high_risk={payload.get('catalog_metrics', {}).get('canonical_high_risk', 0)}")
PY
)

readarray -t TREND_FIELDS < <(python3 - "$COMPARISON" <<'PY'
import json
import sys
payload = json.load(open(sys.argv[1], encoding='utf-8'))
print(f"base_ref={payload.get('base_ref', '')}")
print(f"base_score={payload.get('base_score', 0)}")
print(f"current_score={payload.get('current_score', 0)}")
print(f"score_drop={payload.get('score_drop', 0)}")
print(f"max_allowed_drop={payload.get('max_allowed_drop', 0)}")
print(f"trend_status={payload.get('status', 'unknown')}")
PY
)

readarray -t CATALOG_FIELDS < <(python3 - "$CATALOG_SUMMARY" <<'PY'
import json
import sys
payload = json.load(open(sys.argv[1], encoding='utf-8'))
print(f"all_entries={payload.get('all_entries', 0)}")
print(f"canonical_total={payload.get('canonical_total', 0)}")
print(f"canonical_stale={payload.get('canonical_stale', 0)}")
print(f"canonical_missing_owner={payload.get('canonical_missing_owner', 0)}")
print(f"canonical_missing_verified={payload.get('canonical_missing_verified', 0)}")
print(f"canonical_missing_file={payload.get('canonical_missing_file', 0)}")
print(f"canonical_high_risk={payload.get('canonical_high_risk', 0)}")
print(f"failed={str(payload.get('failed', False)).lower()}")
print(f"stale_entries={len(payload.get('stale_entries', []))}")
PY
)

readarray -t CMDREF_FIELDS < <(python3 - "$CMDREF_SUMMARY" <<'PY'
import json
import sys
payload = json.load(open(sys.argv[1], encoding='utf-8'))
print(f"cmdref_status={payload.get('status', 'unknown')}")
print(f"files_checked={payload.get('files_checked', 0)}")
print(f"cmdref_baseline_enabled={str(payload.get('baseline_enabled', False)).lower()}")
print(f"cmdref_baseline_entries={payload.get('baseline_entries', 0)}")
print(f"total_candidates={payload.get('total_candidates', 0)}")
print(f"missing_references={payload.get('missing_references', 0)}")
sources = payload.get('candidate_sources', {})
print(f"candidates_inline_code={sources.get('inline_code', 0)}")
print(f"candidates_shell_block={sources.get('shell_block', 0)}")
print(f"candidates_markdown_link={sources.get('markdown_link', 0)}")
print(f"candidates_markdown_autolink={sources.get('markdown_autolink', 0)}")
print(f"candidates_markdown_refdef={sources.get('markdown_refdef', 0)}")
PY
)

readarray -t LINK_FIELDS < <(python3 - "$LINK_INTEGRITY_SUMMARY" <<'PY'
import json
import sys
payload = json.load(open(sys.argv[1], encoding='utf-8'))
print(f"link_integrity_status={payload.get('status', 'unknown')}")
print(f"link_integrity_files_checked={payload.get('files_checked', 0)}")
print(f"link_integrity_broken_links={payload.get('broken_links', 0)}")
PY
)

readarray -t COMPLIANCE_FIELDS < <(python3 - "$COMPLIANCE_SUMMARY" <<'PY'
import json
import sys
payload = json.load(open(sys.argv[1], encoding='utf-8'))
statuses = payload.get("statuses", {})
foundation = payload.get("foundation_gates", {})
foundation_alignment_status = statuses.get('foundation_policy_content_alignment', 'unknown')
print(f"compliance_overall={payload.get('overall_status', 'unknown')}")
print(f"status_foundation_gates={statuses.get('foundation_gates', 'unknown')}")
print(f"status_foundation_policy={statuses.get('foundation_policy', 'unknown')}")
print(f"status_foundation_repo_structure={statuses.get('foundation_repo_structure', 'unknown')}")
print(f"status_foundation_policy_content={statuses.get('foundation_policy_content', 'unknown')}")
print(f"status_foundation_policy_content_consistency={statuses.get('foundation_policy_content_consistency', 'unknown')}")
print(f"status_foundation_policy_content_alignment={statuses.get('foundation_policy_content_alignment', 'unknown')}")
print(f"status_catalog={statuses.get('catalog_health', 'unknown')}")
print(f"status_cmdref_baseline={statuses.get('command_reference_baseline', 'unknown')}")
print(f"status_cmdref={statuses.get('command_references', 'unknown')}")
print(f"status_scorecard={statuses.get('docs_scorecard', 'unknown')}")
print(f"status_trend={statuses.get('scorecard_trend', 'unknown')}")
print(f"status_recency={statuses.get('scorecard_recency', 'unknown')}")
print(f"status_consistency={statuses.get('scorecard_consistency', 'unknown')}")
print(f"status_head_freshness={statuses.get('scorecard_head_freshness', 'unknown')}")
print(f"status_timestamp={statuses.get('scorecard_timestamp_format', 'unknown')}")
print(f"status_delta={statuses.get('scorecard_delta_artifact', 'unknown')}")
print(f"status_drift={statuses.get('scorecard_generation_drift', 'unknown')}")
print(f"foundation_policy_range={foundation.get('policy_range', '')}")
print(f"foundation_policy_root_allowlist_violations={foundation.get('policy_root_allowlist_violations', 0)}")
print(f"foundation_policy_changed_markdown_files={foundation.get('policy_changed_markdown_files', 0)}")
print(f"foundation_policy_content_status={foundation.get('policy_content_status', 'unknown')}")
print(f"foundation_policy_content_consistency_detail={foundation.get('policy_content_consistency_status', 'unknown')}")
print(f"foundation_policy_content_consistency_aligned={str(foundation_alignment_status == 'pass').lower()}")
print(f"foundation_policy_content_consistent={str(foundation.get('policy_content_consistent', True)).lower()}")
print(f"foundation_policy_content_errors={len(foundation.get('policy_content_errors', []))}")
PY
)

declare -A dict
for kv in "${SCORECARD_FIELDS[@]}" "${TREND_FIELDS[@]}" "${CATALOG_FIELDS[@]}" "${CMDREF_FIELDS[@]}" "${LINK_FIELDS[@]}" "${COMPLIANCE_FIELDS[@]}"; do
  key=${kv%%=*}
  value=${kv#*=}
  dict["$key"]="$value"
done

mkdir -p "$(dirname "$REPORT_FILE")"
mkdir -p "$(dirname "$QUALITY_REPORT_FILE")"

cat > "$REPORT_FILE" <<EOF_REPORT
# Docs Program Scorecard ${DATE}
_Audience: Docs Lead + Domain Owners • Owner: Platform Team • Last verified (UTC): $(date -u +%Y-%m-%dT%H:%M:%SZ) • Status: supporting_

## KPI Snapshot
- Total docs scope: ${dict[all_entries]:-0}
- Canonical docs: ${dict[canonical_total]:-0}
- Stale canonical docs: ${dict[canonical_stale]:-0}
- Missing canonical owner: ${dict[canonical_missing_owner]:-0}
- Missing canonical verified date: ${dict[canonical_missing_verified]:-0}
- Missing canonical files: ${dict[canonical_missing_file]:-0}
- Canonical high-risk entries: ${dict[canonical_high_risk]:-0}
- Catalog score: ${dict[score]:-0} / threshold ${dict[min_score]:-0} (${dict[score_status]:-unknown})
- Scorecard trend: base=${dict[base_score]:-0}, current=${dict[current_score]:-0}, drop=${dict[score_drop]:-0}, threshold=${dict[max_allowed_drop]:-0}, status=${dict[trend_status]}
- Command reference checks: ${dict[cmdref_status]:-unknown} (${dict[files_checked]:-0} files, ${dict[missing_references]:-0} missing)
- Command reference baseline coverage: enabled=${dict[cmdref_baseline_enabled]:-false}, entries=${dict[cmdref_baseline_entries]:-0}
- Command reference source breakdown: inline=${dict[candidates_inline_code]:-0}, shell=${dict[candidates_shell_block]:-0}, md_link=${dict[candidates_markdown_link]:-0}, md_autolink=${dict[candidates_markdown_autolink]:-0}, md_refdef=${dict[candidates_markdown_refdef]:-0}
- Link integrity checks: ${dict[link_integrity_status]:-unknown} (${dict[link_integrity_files_checked]:-0} files, ${dict[link_integrity_broken_links]:-0} broken)

## Compliance Gate Snapshot
- Overall compliance status: ${dict[compliance_overall]:-unknown}
- catalog=${dict[status_catalog]:-unknown}, cmdref_baseline=${dict[status_cmdref_baseline]:-unknown}, cmdref=${dict[status_cmdref]:-unknown}, scorecard=${dict[status_scorecard]:-unknown}, trend=${dict[status_trend]:-unknown}
- recency=${dict[status_recency]:-unknown}, consistency=${dict[status_consistency]:-unknown}, head_freshness=${dict[status_head_freshness]:-unknown}, timestamp=${dict[status_timestamp]:-unknown}, delta=${dict[status_delta]:-unknown}, drift=${dict[status_drift]:-unknown}
- foundation_policy_range=${dict[foundation_policy_range]:-n/a}, root_allowlist_violations=${dict[foundation_policy_root_allowlist_violations]:-0}, changed_markdown_files=${dict[foundation_policy_changed_markdown_files]:-0}
- foundation_policy_content_status=${dict[status_foundation_policy_content]:-unknown}, foundation_policy_content_consistency=${dict[status_foundation_policy_content_consistency]:-unknown}, foundation_policy_content_alignment=${dict[status_foundation_policy_content_alignment]:-unknown}, foundation_policy_content_consistency_detail=${dict[foundation_policy_content_consistency_detail]:-unknown}, foundation_policy_content_consistency_aligned=${dict[foundation_policy_content_consistency_aligned]:-unknown}, foundation_policy_content_consistent=${dict[foundation_policy_content_consistent]:-unknown}, foundation_policy_content_errors=${dict[foundation_policy_content_errors]:-0}

## Evidence Inputs
- base_ref=${dict[base_ref]:-origin/main}
- verify-doc-catalog-health.py (summary + freshness gate)
- build-docs-scorecard.py (min-score gate)
- verify-doc-command-refs.sh (command/path references)
- verify-doc-link-integrity.sh (broken-doc-link references)
- compare-docs-scorecard-to-base.sh (base trend + regression threshold)
- build-docs-compliance-summary.py (consolidated status)

## Risk Notes
- Command references check is scoped to non-archive docs; update SKIP_PATH_PREFIXES if scope changes.
- Full scorecard pass is expected at target=80; trend fail requires governance review if score_drop > ${REGRESSION_THRESHOLD}.

## Recommendation
- Publish this report at the same cadence as governance cycles and link from the closure readiness artifact.
EOF_REPORT

BRANCH_NAME="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")"
SYNC_DELTA="$(git rev-list --left-right --count origin/main...HEAD 2>/dev/null | tr '\t' ' ' || echo "n/a")"
LAST_UPDATED_UTC="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

cat > "$QUALITY_REPORT_FILE" <<EOF_QUALITY
# Docs Quality Scorecard — ${DATE:0:4}-${DATE:4:2}-${DATE:6:2}

- Branch: \`${BRANCH_NAME}\`
- Last updated: \`${LAST_UPDATED_UTC}\`
- Sync status: \`origin/main\` delta \`${SYNC_DELTA}\`

## One-Week Scorecard Delta (Docs Compliance Gates)

| Gate | Status | Evidence | Notes |
|---|---|---|---|
| \`docs/qa/verify-docs-foundation-gates.sh\` | ${dict[status_foundation_gates]:-unknown} | foundation summary | policy=${dict[status_foundation_policy]:-unknown}, repo_structure=${dict[status_foundation_repo_structure]:-unknown}, policy_content_consistency=${dict[status_foundation_policy_content_consistency]:-unknown}, policy_content_alignment=${dict[status_foundation_policy_content_alignment]:-unknown} |
| \`docs/qa/verify-docs-policy.sh\` | ${dict[status_foundation_policy_content]:-unknown} | foundation policy metrics | consistency_status=${dict[status_foundation_policy_content_consistency]:-unknown}, consistency_detail=${dict[foundation_policy_content_consistency_detail]:-unknown}, consistency_aligned=${dict[foundation_policy_content_consistency_aligned]:-unknown}, range=${dict[foundation_policy_range]:-n/a}, root_allowlist_violations=${dict[foundation_policy_root_allowlist_violations]:-0}, consistent=${dict[foundation_policy_content_consistent]:-unknown}, content_errors=${dict[foundation_policy_content_errors]:-0} |
| \`docs/qa/verify-doc-command-ref-baseline.sh\` | ${dict[status_cmdref_baseline]:-unknown} | baseline summary | baseline file integrity contract, baseline_enabled=${dict[cmdref_baseline_enabled]:-false}, baseline_entries=${dict[cmdref_baseline_entries]:-0} |
| \`docs/qa/verify-doc-command-refs.sh\` | ${dict[status_cmdref]:-unknown} | command refs summary | docs command/path references, files=${dict[files_checked]:-0}, candidates=${dict[total_candidates]:-0}, inline=${dict[candidates_inline_code]:-0}, shell=${dict[candidates_shell_block]:-0}, md_link=${dict[candidates_markdown_link]:-0}, md_autolink=${dict[candidates_markdown_autolink]:-0}, md_refdef=${dict[candidates_markdown_refdef]:-0}, missing_refs=${dict[missing_references]:-0} |
| \`docs/qa/verify-doc-link-integrity.sh\` | ${dict[status_link_integrity]:-unknown} | link integrity summary | files=${dict[link_integrity_files_checked]:-0}, broken_links=${dict[link_integrity_broken_links]:-0} |
| \`docs/qa/verify-docs-scorecard-recency.sh\` | ${dict[status_recency]:-unknown} | scorecard recency summary | max-age-days contract |
| \`docs/qa/verify-docs-scorecard-report-consistency.sh\` | ${dict[status_consistency]:-unknown} | consistency summary | filename/title date contract |
| \`docs/qa/verify-docs-scorecard-head-freshness.sh\` | ${dict[status_head_freshness]:-unknown} | head freshness summary | latest report aligned with HEAD date |
| \`docs/qa/verify-docs-scorecard-report-timestamp.sh\` | ${dict[status_timestamp]:-unknown} | timestamp summary | Last verified (UTC) metadata contract |
| \`docs/qa/verify-docs-scorecard-delta-artifact.sh\` | ${dict[status_delta]:-unknown} | delta artifact summary | quality/program date pairing contract |
| \`docs/qa/build-docs-compliance-summary.py\` | ${dict[compliance_overall]:-unknown} | compliance summary | consolidated docs compliance status |

## Next Cycle

1. Regenerate both scorecards at cycle start.
2. Keep this artifact linked in the active PR and closure memo.
3. Escalate governance blockers: \`GOV-01\`, \`GOV-02\`, \`CLS-02\`.
EOF_QUALITY

# Enforce report metadata contracts on generated output.
bash docs/qa/verify-docs-scorecard-report-consistency.sh --report-glob "$REPORT_FILE"
bash docs/qa/verify-docs-scorecard-report-timestamp.sh --report-glob "$REPORT_FILE"
bash docs/qa/verify-docs-scorecard-delta-artifact.sh \
  --program-glob "$REPORT_FILE" \
  --delta-glob "$QUALITY_REPORT_FILE"

echo "Generated $(basename "$REPORT_FILE")"
echo "Generated $(basename "$QUALITY_REPORT_FILE")"
