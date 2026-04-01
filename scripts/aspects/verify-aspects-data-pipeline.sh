#!/usr/bin/env bash
# verify-aspects-data-pipeline.sh — Verify ClickHouse has data and the sync pipeline works.
#
# Checks ClickHouse pod health, queries row counts for key tables
# (xAPI events, enrollments, completions, courses), and reports the last
# successful CronJob sync time.
#
# Usage:
#   ./scripts/aspects/verify-aspects-data-pipeline.sh --env dev
#   ./scripts/aspects/verify-aspects-data-pipeline.sh --env staging

set -euo pipefail

# ---------------------------------------------------------------------------
# Colors and counters
# ---------------------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

PASS_COUNT=0
FAIL_COUNT=0
WARN_COUNT=0

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# shellcheck source=../shared/config.sh
source "${REPO_ROOT}/scripts/shared/config.sh"

# ---------------------------------------------------------------------------
# Helper functions
# ---------------------------------------------------------------------------
pass() {
  echo -e "  ${GREEN}PASS${NC} $1"
  PASS_COUNT=$((PASS_COUNT + 1))
}

fail() {
  echo -e "  ${RED}FAIL${NC} $1"
  FAIL_COUNT=$((FAIL_COUNT + 1))
}

warn() {
  echo -e "  ${YELLOW}WARN${NC} $1"
  WARN_COUNT=$((WARN_COUNT + 1))
}

section() {
  echo ""
  echo -e "${CYAN}--- $1 ---${NC}"
}

usage() {
  echo "Usage: $0 --env <dev|staging>"
  echo ""
  echo "  --env dev|staging   Target environment (no prod — ADR-017)"
  exit 1
}

# kctl — kubectl with fixed context and namespace
kctl() {
  kubectl --context "$K8S_CTX" -n "$NS" "$@"
}

# ch_query — run a ClickHouse query via kubectl exec
# Returns the raw output or empty string on failure.
ch_query() {
  local query="$1"
  kctl exec "$CH_POD" -- clickhouse-client --query="$query" 2>/dev/null || true
}

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------
ENV=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --env)
      ENV="$2"
      shift 2
      ;;
    -h|--help)
      usage
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage
      ;;
  esac
done

if [[ -z "$ENV" ]]; then
  echo "ERROR: --env is required" >&2
  usage
fi

case "$ENV" in
  dev|staging) ;;
  prod|production)
    echo "ERROR: Production Aspects is deferred (ADR-017). Use --env dev or --env staging." >&2
    exit 1
    ;;
  *)
    echo "ERROR: Unsupported environment: $ENV" >&2
    usage
    ;;
esac

# ---------------------------------------------------------------------------
# Resolve K8s context and namespace
# ---------------------------------------------------------------------------
K8S_CTX="$(mereka_lms_default_context_for_env "$ENV")"
NS="$(mereka_lms_default_namespace_for_env "$ENV")"

echo "========================================================"
echo "  Aspects Data Pipeline Verification — env=${ENV}"
echo "  context=${K8S_CTX}  namespace=${NS}"
echo "========================================================"

# ---------------------------------------------------------------------------
# Step 1: ClickHouse pod health
# ---------------------------------------------------------------------------
section "[1/4] ClickHouse Pod"

CH_POD="$(kctl get pod -l app.kubernetes.io/name=clickhouse -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)"
if [[ -z "$CH_POD" ]]; then
  CH_POD="$(kctl get pod -l app=clickhouse -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)"
fi

if [[ -z "$CH_POD" ]]; then
  fail "ClickHouse pod not found in ${NS}"
  echo ""
  echo "Cannot proceed without ClickHouse. Aborting."
  echo ""
  echo "========================================================"
  echo -e "  PASS: ${GREEN}${PASS_COUNT}${NC}  FAIL: ${RED}${FAIL_COUNT}${NC}  WARN: ${YELLOW}${WARN_COUNT}${NC}"
  echo "========================================================"
  exit 1
fi

phase="$(kctl get pod "$CH_POD" -o jsonpath='{.status.phase}' 2>/dev/null || true)"
if [[ "$phase" == "Running" ]]; then
  pass "ClickHouse pod is Running (${CH_POD})"
else
  fail "ClickHouse pod is ${phase:-unknown} (expected Running) — ${CH_POD}"
  echo ""
  echo "Cannot query ClickHouse in non-Running state. Aborting."
  echo ""
  echo "========================================================"
  echo -e "  PASS: ${GREEN}${PASS_COUNT}${NC}  FAIL: ${RED}${FAIL_COUNT}${NC}  WARN: ${YELLOW}${WARN_COUNT}${NC}"
  echo "========================================================"
  exit 1
fi

# Quick health check — can we run a query at all?
ch_version="$(ch_query "SELECT version()")"
if [[ -n "$ch_version" ]]; then
  pass "ClickHouse responds to queries (version: ${ch_version})"
else
  fail "ClickHouse pod is Running but not responding to queries"
  echo ""
  echo "========================================================"
  echo -e "  PASS: ${GREEN}${PASS_COUNT}${NC}  FAIL: ${RED}${FAIL_COUNT}${NC}  WARN: ${YELLOW}${WARN_COUNT}${NC}"
  echo "========================================================"
  exit 1
fi

# ---------------------------------------------------------------------------
# Step 2: Row counts
# ---------------------------------------------------------------------------
section "[2/4] ClickHouse Row Counts"

# Track counts for the final verdict
xapi_count=0
enrollments_count=0
completions_count=0
courses_count=0

# xAPI events (real-time pipeline)
raw_xapi="$(ch_query "SELECT count() FROM xapi.xapi_events_all" 2>/dev/null || true)"
if [[ -n "$raw_xapi" && "$raw_xapi" =~ ^[0-9]+$ ]]; then
  xapi_count="$raw_xapi"
  if [[ "$xapi_count" -gt 0 ]]; then
    pass "xapi.xapi_events_all: ${xapi_count} rows"
  else
    warn "xapi.xapi_events_all: 0 rows (xAPI event pipeline may not be active yet)"
  fi
else
  warn "xapi.xapi_events_all: query failed or table does not exist"
fi

# Enrollments (batch sync)
raw_enrollments="$(ch_query "SELECT count() FROM openedx.enrollments" 2>/dev/null || true)"
if [[ -n "$raw_enrollments" && "$raw_enrollments" =~ ^[0-9]+$ ]]; then
  enrollments_count="$raw_enrollments"
  if [[ "$enrollments_count" -gt 0 ]]; then
    pass "openedx.enrollments: ${enrollments_count} rows"
  else
    warn "openedx.enrollments: 0 rows"
  fi
else
  warn "openedx.enrollments: query failed or table does not exist"
fi

# Completions (batch sync)
raw_completions="$(ch_query "SELECT count() FROM openedx.completions" 2>/dev/null || true)"
if [[ -n "$raw_completions" && "$raw_completions" =~ ^[0-9]+$ ]]; then
  completions_count="$raw_completions"
  if [[ "$completions_count" -gt 0 ]]; then
    pass "openedx.completions: ${completions_count} rows"
  else
    warn "openedx.completions: 0 rows"
  fi
else
  warn "openedx.completions: query failed or table does not exist"
fi

# Courses (batch sync)
raw_courses="$(ch_query "SELECT count() FROM openedx.courses" 2>/dev/null || true)"
if [[ -n "$raw_courses" && "$raw_courses" =~ ^[0-9]+$ ]]; then
  courses_count="$raw_courses"
  if [[ "$courses_count" -gt 0 ]]; then
    pass "openedx.courses: ${courses_count} rows"
  else
    warn "openedx.courses: 0 rows"
  fi
else
  warn "openedx.courses: query failed or table does not exist"
fi

# ---------------------------------------------------------------------------
# Step 3: CronJob last sync time
# ---------------------------------------------------------------------------
section "[3/4] CronJob Sync Status"

CRONJOB_NAME="clickhouse-data-sync-daily"

cj_exists="$(kctl get cronjob "$CRONJOB_NAME" -o name 2>/dev/null || true)"
if [[ -z "$cj_exists" ]]; then
  warn "CronJob '${CRONJOB_NAME}' not found in ${NS} — batch sync may use a different name or not be configured"
else
  last_success="$(kctl get cronjob "$CRONJOB_NAME" -o jsonpath='{.status.lastSuccessfulTime}' 2>/dev/null || true)"
  last_schedule="$(kctl get cronjob "$CRONJOB_NAME" -o jsonpath='{.status.lastScheduleTime}' 2>/dev/null || true)"
  schedule="$(kctl get cronjob "$CRONJOB_NAME" -o jsonpath='{.spec.schedule}' 2>/dev/null || true)"

  if [[ -n "$last_success" ]]; then
    pass "CronJob '${CRONJOB_NAME}' last successful run: ${last_success}"
  elif [[ -n "$last_schedule" ]]; then
    warn "CronJob '${CRONJOB_NAME}' last scheduled: ${last_schedule} (but no recorded success)"
  else
    warn "CronJob '${CRONJOB_NAME}' has never run"
  fi

  if [[ -n "$schedule" ]]; then
    echo "    Schedule: ${schedule}"
  fi
fi

# Check for active sync jobs
active_jobs="$(kctl get jobs -l "cronjob-name=${CRONJOB_NAME}" --sort-by=.metadata.creationTimestamp -o jsonpath='{.items[-1].metadata.name}' 2>/dev/null || true)"
if [[ -n "$active_jobs" ]]; then
  job_status="$(kctl get job "$active_jobs" -o jsonpath='{.status.succeeded}' 2>/dev/null || true)"
  if [[ "${job_status:-0}" -ge 1 ]]; then
    pass "Latest sync job '${active_jobs}' succeeded"
  else
    job_failed="$(kctl get job "$active_jobs" -o jsonpath='{.status.failed}' 2>/dev/null || true)"
    if [[ "${job_failed:-0}" -ge 1 ]]; then
      fail "Latest sync job '${active_jobs}' failed"
    else
      warn "Latest sync job '${active_jobs}' status: pending/running"
    fi
  fi
fi

# ---------------------------------------------------------------------------
# Step 4: Verdict
# ---------------------------------------------------------------------------
section "[4/4] Data Pipeline Verdict"

echo ""
echo "  Row count summary:"
echo "    xapi_events_all : ${xapi_count}"
echo "    enrollments     : ${enrollments_count}"
echo "    completions     : ${completions_count}"
echo "    courses         : ${courses_count}"
echo ""

if [[ "$enrollments_count" -gt 0 && "$courses_count" -gt 0 ]]; then
  pass "Core data present (enrollments > 0 AND courses > 0)"
elif [[ "$enrollments_count" -eq 0 && "$courses_count" -eq 0 && "$xapi_count" -eq 0 && "$completions_count" -eq 0 ]]; then
  fail "All tables are empty — data pipeline is not delivering data"
else
  warn "Partial data: enrollments=${enrollments_count}, courses=${courses_count}"
fi

if [[ "$xapi_count" -eq 0 ]]; then
  warn "xAPI events count is 0 — real-time event pipeline may not be active"
fi

# ============================================================================
# Summary
# ============================================================================
echo ""
echo "========================================================"
echo -e "  PASS: ${GREEN}${PASS_COUNT}${NC}  FAIL: ${RED}${FAIL_COUNT}${NC}  WARN: ${YELLOW}${WARN_COUNT}${NC}"
echo "========================================================"

if [[ "$FAIL_COUNT" -gt 0 ]]; then
  echo ""
  echo "Data pipeline check FAILED. Debug commands:"
  echo ""
  echo "  Pod:      kubectl --context ${K8S_CTX} -n ${NS} get pods -l app.kubernetes.io/name=clickhouse"
  echo "  Logs:     kubectl --context ${K8S_CTX} -n ${NS} logs -l app.kubernetes.io/name=clickhouse --tail=50"
  echo "  CronJobs: kubectl --context ${K8S_CTX} -n ${NS} get cronjobs"
  echo "  Jobs:     kubectl --context ${K8S_CTX} -n ${NS} get jobs --sort-by=.metadata.creationTimestamp"
  echo "  Tables:   kubectl --context ${K8S_CTX} -n ${NS} exec ${CH_POD} -- clickhouse-client --query='SHOW TABLES FROM xapi'"
  echo "            kubectl --context ${K8S_CTX} -n ${NS} exec ${CH_POD} -- clickhouse-client --query='SHOW TABLES FROM openedx'"
  echo ""
  exit 1
fi

echo ""
echo "RESULT: PASS — Aspects data pipeline verification complete"
exit 0
