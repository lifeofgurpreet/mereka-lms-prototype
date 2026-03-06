#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd "${SCRIPT_DIR}/../.." && pwd)
cd "$REPO_ROOT"

WORK_DIR=$(mktemp -d)
trap 'rm -rf "$WORK_DIR"' EXIT
CATALOG_HEALTH_SUMMARY="$WORK_DIR/docs-catalog-health-summary.json"
DOCS_SCORECARD_PATH="$WORK_DIR/docs-scorecard.json"
DOCS_SCORECARD_COMPARISON_PATH="$WORK_DIR/docs-scorecard-comparison.json"
DOCS_COMMAND_REFS_SUMMARY="$WORK_DIR/docs-command-refs-summary.json"
DOCS_SCORECARD_RECENCY_SUMMARY="$WORK_DIR/docs-scorecard-recency-summary.json"
DOCS_SCORECARD_CONSISTENCY_SUMMARY="$WORK_DIR/docs-scorecard-consistency-summary.json"
DOCS_SCORECARD_HEAD_FRESHNESS_SUMMARY="$WORK_DIR/docs-scorecard-head-freshness-summary.json"
DOCS_COMPLIANCE_SUMMARY_PATH="$WORK_DIR/docs-compliance-summary.json"

MAX_AGE_SECONDS=1200
DO_SYNC=0
REQUIRE_SYNC=0
STATE_FILE=".docs-world-class-sync-state"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --sync)
      DO_SYNC=1
      shift
      ;;
    --max-age-seconds)
      MAX_AGE_SECONDS="${2:?missing value}"
      shift 2
      ;;
    --require-sync)
      REQUIRE_SYNC=1
      shift
      ;;
    --state-file)
      STATE_FILE="${2:?missing value}"
      shift 2
      ;;
    --help|-h)
      cat <<'EOF'
Usage: run-docs-world-class-gates.sh [--sync] [--max-age-seconds N] [--state-file path] [--require-sync]

Options:
  --sync                  run `git fetch origin` and `git rebase origin/main` before checks
  --max-age-seconds N     warn if last sync is older than N (default: 1200 = 20 min)
  --state-file path       path for sync-state marker (default: .docs-world-class-sync-state)
  --require-sync          fail if sync state is older than --max-age-seconds
  --help                  show this message
EOF
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

log() {
  echo "[docs-world-class] $*"
}

run_step() {
  local name=$1
  shift
  log "START ${name}"
  "$@"
  log "END ${name}"
}

check_sync_age() {
  if [ ! -f "$STATE_FILE" ]; then
    log "No sync state file found: $STATE_FILE"
    if [ "$REQUIRE_SYNC" -eq 1 ]; then
      log "FAIL: --require-sync is set but no sync state file exists."
      return 1
    fi
    return 0
  fi

  local last_epoch
  last_epoch=$(awk '{print $1}' "$STATE_FILE" 2>/dev/null || true)
  if [ -z "$last_epoch" ]; then
    log "Invalid sync state marker: $STATE_FILE"
    if [ "$REQUIRE_SYNC" -eq 1 ]; then
      log "FAIL: --require-sync is set and sync state marker is malformed."
      return 1
    fi
    return 0
  fi

  local now_epoch
  now_epoch=$(date +%s)
  local age=$((now_epoch - last_epoch))
  if [ "$age" -gt "$MAX_AGE_SECONDS" ]; then
    local msg="sync state is ${age}s old (>${MAX_AGE_SECONDS}s). Run with --sync now."
    if [ "$REQUIRE_SYNC" -eq 1 ]; then
      log "FAIL: $msg"
      return 1
    fi
    log "WARNING: $msg"
  fi
  return 0
}

update_sync_state() {
  local head
  head=$(git rev-parse --short HEAD)
  printf "%s %s\n" "$(date +%s)" "$head" > "$STATE_FILE"
}

if [ "$DO_SYNC" -eq 1 ]; then
  log "Refreshing from origin/main for docs branch safety"
  run_step "git fetch origin" git fetch origin
  run_step "git rebase origin/main" git rebase origin/main
  update_sync_state
else
  check_sync_age
fi

run_step "verify-docs-policy" ./docs/qa/verify-docs-policy.sh
run_step "verify-repo-structure" ./scripts/qa/verify-repo-structure.sh
run_step "verify-doc-command-refs" ./docs/qa/verify-doc-command-refs.sh --summary-json "$DOCS_COMMAND_REFS_SUMMARY"
run_step "verify-docs-scorecard-recency" ./docs/qa/verify-docs-scorecard-recency.sh --max-age-days 7 --summary-json "$DOCS_SCORECARD_RECENCY_SUMMARY"
run_step "verify-docs-scorecard-report-consistency" ./docs/qa/verify-docs-scorecard-report-consistency.sh --summary-json "$DOCS_SCORECARD_CONSISTENCY_SUMMARY"
run_step "verify-docs-scorecard-head-freshness" ./docs/qa/verify-docs-scorecard-head-freshness.sh --summary-json "$DOCS_SCORECARD_HEAD_FRESHNESS_SUMMARY"
run_step "verify-doc-link-integrity" ./docs/qa/verify-doc-link-integrity.sh
run_step "verify-doc-catalog-health" python3 docs/qa/verify-doc-catalog-health.py \
  --max-stale-days 45 \
  --summary-file "$CATALOG_HEALTH_SUMMARY"
run_step "build-docs-scorecard" python3 docs/qa/build-docs-scorecard.py \
  --summary-file "$CATALOG_HEALTH_SUMMARY" \
  --out "$DOCS_SCORECARD_PATH" \
  --min-score 80
run_step "compare-docs-scorecard-to-base" docs/qa/compare-docs-scorecard-to-base.sh \
  --current-summary "$CATALOG_HEALTH_SUMMARY" \
  --base-ref origin/main \
  --regression-threshold 10 \
  --out "$DOCS_SCORECARD_COMPARISON_PATH"
run_step "build-docs-compliance-summary" python3 docs/qa/build-docs-compliance-summary.py \
  --catalog-summary "$CATALOG_HEALTH_SUMMARY" \
  --cmdref-summary "$DOCS_COMMAND_REFS_SUMMARY" \
  --scorecard "$DOCS_SCORECARD_PATH" \
  --comparison "$DOCS_SCORECARD_COMPARISON_PATH" \
  --scorecard-recency-summary "$DOCS_SCORECARD_RECENCY_SUMMARY" \
  --scorecard-consistency-summary "$DOCS_SCORECARD_CONSISTENCY_SUMMARY" \
  --scorecard-head-freshness-summary "$DOCS_SCORECARD_HEAD_FRESHNESS_SUMMARY" \
  --out "$DOCS_COMPLIANCE_SUMMARY_PATH"
run_step "verify-doc-catalog-health-test" ./docs/qa/verify-doc-catalog-health-test.sh
run_step "verify-doc-link-integrity-test" ./docs/qa/verify-doc-link-integrity-test.sh
run_step "verify-doc-command-refs-test" ./docs/qa/verify-doc-command-refs-test.sh
run_step "verify-docs-scorecard-recency-test" ./docs/qa/verify-docs-scorecard-recency-test.sh
run_step "verify-docs-scorecard-report-consistency-test" ./docs/qa/verify-docs-scorecard-report-consistency-test.sh
run_step "verify-docs-scorecard-head-freshness-test" ./docs/qa/verify-docs-scorecard-head-freshness-test.sh
run_step "build-docs-scorecard-test" ./docs/qa/build-docs-scorecard-test.sh
run_step "compare-docs-scorecard-to-base-test" ./docs/qa/compare-docs-scorecard-to-base-test.sh
run_step "build-docs-compliance-summary-test" ./docs/qa/build-docs-compliance-summary-test.sh

if [ "$DO_SYNC" -eq 1 ]; then
  log "Final sync status (origin/main...HEAD): $(git rev-list --left-right --count origin/main...HEAD | tr '\t' ' ')"
fi

log "Docs world-class gate run completed successfully"
