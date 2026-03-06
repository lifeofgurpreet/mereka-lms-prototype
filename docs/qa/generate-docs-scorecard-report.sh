#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd "${SCRIPT_DIR}/../.." && pwd)
cd "$REPO_ROOT"

DATE="$(date +%Y%m%d)"
BASE_REF="origin/main"
MAX_STALE_DAYS=45
REGRESSION_THRESHOLD=10
OUT_PATH=""

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
    --help|-h)
      cat <<'EOF_HELP'
Usage: generate-docs-scorecard-report.sh [options]

Options:
  --date YYYYMMDD            report date (default: today)
  --base-ref <ref>           base ref for trend comparison (default: origin/main)
  --max-stale-days <n>       stale threshold (default: 45)
  --regression-threshold <n> max allowed score drop (default: 10)
  --output <path>            report output path (default: docs/guides/admin/DOCS_PROGRAM_SCORECARD_<date>.md)
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

CATALOG_SUMMARY="$WORKDIR/docs-catalog-health-summary.json"
SCORECARD="$WORKDIR/docs-scorecard.json"
COMPARISON="$WORKDIR/docs-scorecard-comparison.json"
CMDREF_SUMMARY="$WORKDIR/docs-command-refs-summary.json"
REPORT_FILE="${OUT_PATH:-docs/guides/admin/DOCS_PROGRAM_SCORECARD_${DATE}.md}"

python3 docs/qa/verify-doc-catalog-health.py \
  --max-stale-days "$MAX_STALE_DAYS" \
  --summary-file "$CATALOG_SUMMARY"

python3 docs/qa/build-docs-scorecard.py \
  --summary-file "$CATALOG_SUMMARY" \
  --out "$SCORECARD" \
  --min-score 80

bash docs/qa/verify-doc-command-refs.sh \
  --summary-json "$CMDREF_SUMMARY"

docs/qa/compare-docs-scorecard-to-base.sh \
  --current-summary "$CATALOG_SUMMARY" \
  --base-ref "$BASE_REF" \
  --regression-threshold "$REGRESSION_THRESHOLD" \
  --out "$COMPARISON"

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
print(f"total_candidates={payload.get('total_candidates', 0)}")
print(f"missing_references={payload.get('missing_references', 0)}")
PY
)

declare -A dict
for kv in "${SCORECARD_FIELDS[@]}" "${TREND_FIELDS[@]}" "${CATALOG_FIELDS[@]}" "${CMDREF_FIELDS[@]}"; do
  key=${kv%%=*}
  value=${kv#*=}
  dict["$key"]="$value"
done

mkdir -p "$(dirname "$REPORT_FILE")"

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

## Evidence Inputs
- base_ref=${dict[base_ref]:-origin/main}
- verify-doc-catalog-health.py (summary + freshness gate)
- build-docs-scorecard.py (min-score gate)
- verify-doc-command-refs.sh (command/path references)
- compare-docs-scorecard-to-base.sh (base trend + regression threshold)

## Risk Notes
- Command references check is scoped to non-archive docs; update SKIP_PATH_PREFIXES if scope changes.
- Full scorecard pass is expected at target=80; trend fail requires governance review if score_drop > ${REGRESSION_THRESHOLD}.

## Recommendation
- Publish this report at the same cadence as governance cycles and link from the closure readiness artifact.
EOF_REPORT

echo "Generated $(basename "$REPORT_FILE")"
