#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

PROGRAM_GLOB="docs/guides/admin/DOCS_PROGRAM_SCORECARD_*.md"
QUALITY_GLOB="docs/guides/admin/DOCS_QUALITY_SCORECARD_*.md"
SUMMARY_JSON=""
POLICY_RANGE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --program-glob)
      PROGRAM_GLOB="${2:?missing value}"
      shift 2
      ;;
    --quality-glob)
      QUALITY_GLOB="${2:?missing value}"
      shift 2
      ;;
    --summary-json)
      SUMMARY_JSON="${2:?missing value}"
      shift 2
      ;;
    --policy-range)
      POLICY_RANGE="${2:?missing value}"
      shift 2
      ;;
    --help|-h)
      cat <<'EOF'
Usage: verify-docs-scorecard-generation-drift.sh [options]

Options:
  --program-glob <glob>  program scorecard glob (default: docs/guides/admin/DOCS_PROGRAM_SCORECARD_*.md)
  --quality-glob <glob>  quality scorecard glob (default: docs/guides/admin/DOCS_QUALITY_SCORECARD_*.md)
  --summary-json <path>  optional JSON summary output path
  --policy-range <range> policy ref-range for regenerating command references
  --help                 show this message
EOF
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      exit 1
      ;;
  esac
done

latest_program_meta() {
  local glob="$1"
  local latest_date=""
  local latest_report=""
  shopt -s nullglob
  local reports=($glob)
  shopt -u nullglob
  local report
  for report in "${reports[@]}"; do
    local base
    base=$(basename "$report")
    local date_part="${base#DOCS_PROGRAM_SCORECARD_}"
    date_part="${date_part%.md}"
    if [[ ! "$date_part" =~ ^[0-9]{8}$ ]]; then
      continue
    fi
    if [ -z "$latest_date" ] || [ "$date_part" -gt "$latest_date" ]; then
      latest_date="$date_part"
      latest_report="$report"
    fi
  done
  printf '%s\n%s\n' "$latest_date" "$latest_report"
}

readarray -t PROGRAM_META < <(latest_program_meta "$PROGRAM_GLOB")
LATEST_DATE="${PROGRAM_META[0]:-}"
LATEST_PROGRAM_REPORT="${PROGRAM_META[1]:-}"

if [ -z "$LATEST_DATE" ] || [ -z "$LATEST_PROGRAM_REPORT" ]; then
  echo "DOCS_SCORECARD_DRIFT_FAIL: no program scorecard found for glob $PROGRAM_GLOB" >&2
  exit 1
fi

shopt -s nullglob
QUALITY_REPORTS=($QUALITY_GLOB)
shopt -u nullglob
LATEST_QUALITY_REPORT=""
for report in "${QUALITY_REPORTS[@]}"; do
  if [[ "$report" == *"DOCS_QUALITY_SCORECARD_${LATEST_DATE}.md" ]]; then
    LATEST_QUALITY_REPORT="$report"
    break
  fi
done

if [ -z "$LATEST_QUALITY_REPORT" ]; then
  echo "DOCS_SCORECARD_DRIFT_FAIL: missing quality scorecard for date ${LATEST_DATE}" >&2
  exit 1
fi

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT
TMP_PROGRAM="$TMP_DIR/DOCS_PROGRAM_SCORECARD_${LATEST_DATE}.md"
TMP_QUALITY="$TMP_DIR/DOCS_QUALITY_SCORECARD_${LATEST_DATE}.md"

tools/docs/scorecards/generate-docs-scorecard-report.sh \
  --date "$LATEST_DATE" \
  --output "$TMP_PROGRAM" \
  --quality-output "$TMP_QUALITY" \
  ${POLICY_RANGE:+--policy-range "$POLICY_RANGE"} >/tmp/docs_scorecard_generation_drift.out 2>&1

program_match="false"
quality_match="false"

normalize_report() {
  local src="$1"
  local dst="$2"
  # Strip genuinely volatile metadata that changes every run or per-environment.
  # All semantic content — command refs, link integrity, policy rows —
  # must match. Drift in those rows signals a real regression.
  sed \
    -e '/Last verified (UTC):/d' \
    -e '/^- Last updated: `/d' \
    -e '/^- Sync status: `/d' \
    -e '/^- Branch: `/d' \
    -e '/^- foundation_policy_range=/d' \
    -e '/^- foundation_policy_content_status=/d' \
    -e '/^- base_ref=/d' \
    -e '/verify-docs-foundation-gates\.sh/d' \
    -e '/verify-docs-policy\.sh/d' \
    "$src" > "$dst"
}

NORM_TRACKED_PROGRAM="$TMP_DIR/tracked-program.norm.md"
NORM_GENERATED_PROGRAM="$TMP_DIR/generated-program.norm.md"
NORM_TRACKED_QUALITY="$TMP_DIR/tracked-quality.norm.md"
NORM_GENERATED_QUALITY="$TMP_DIR/generated-quality.norm.md"

normalize_report "$LATEST_PROGRAM_REPORT" "$NORM_TRACKED_PROGRAM"
normalize_report "$TMP_PROGRAM" "$NORM_GENERATED_PROGRAM"
normalize_report "$LATEST_QUALITY_REPORT" "$NORM_TRACKED_QUALITY"
normalize_report "$TMP_QUALITY" "$NORM_GENERATED_QUALITY"

if cmp -s "$NORM_TRACKED_PROGRAM" "$NORM_GENERATED_PROGRAM"; then
  program_match="true"
fi
if cmp -s "$NORM_TRACKED_QUALITY" "$NORM_GENERATED_QUALITY"; then
  quality_match="true"
fi

status="pass"
if [ "$program_match" != "true" ] || [ "$quality_match" != "true" ]; then
  status="fail"
fi

if [ -n "$SUMMARY_JSON" ]; then
  {
    echo "{"
    echo "  \"status\": \"${status}\","
    echo "  \"latest_date\": \"${LATEST_DATE}\","
    echo "  \"program_report\": \"${LATEST_PROGRAM_REPORT}\","
    echo "  \"quality_report\": \"${LATEST_QUALITY_REPORT}\","
    echo "  \"program_match\": ${program_match},"
    echo "  \"quality_match\": ${quality_match}"
    echo "}"
  } > "$SUMMARY_JSON"
fi

if [ "$status" = "fail" ]; then
  echo "DOCS_SCORECARD_DRIFT_FAIL: generated outputs differ from tracked artifacts for ${LATEST_DATE}" >&2
  echo "- program_match=${program_match} (${LATEST_PROGRAM_REPORT})" >&2
  echo "- quality_match=${quality_match} (${LATEST_QUALITY_REPORT})" >&2
  exit 1
fi

echo "DOCS_SCORECARD_DRIFT_OK date=${LATEST_DATE} program=${LATEST_PROGRAM_REPORT} quality=${LATEST_QUALITY_REPORT}"
