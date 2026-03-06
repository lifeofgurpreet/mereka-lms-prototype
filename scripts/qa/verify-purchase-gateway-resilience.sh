#!/usr/bin/env bash
# @covers AC-008, AC-019, AC-020, AC-021
# @spec: ecommerce-purchase-gateway_spec.md
set -euo pipefail

# Verify durable webhook -> outbox -> worker fulfillment contracts remain intact.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SVC_DIR="$REPO_ROOT/services/purchase-gateway"

PASS=0
FAIL=0

pass() {
  echo "  PASS: $1"
  PASS=$((PASS + 1))
}

fail() {
  echo "  FAIL: $1"
  FAIL=$((FAIL + 1))
}

check_file() {
  local path="$1"
  local desc="$2"
  if [[ -f "$path" ]]; then
    pass "$desc"
  else
    fail "$desc (missing: ${path#$REPO_ROOT/})"
  fi
}

check_contains() {
  local path="$1"
  local pattern="$2"
  local desc="$3"
  if grep -qE "$pattern" "$path" 2>/dev/null; then
    pass "$desc"
  else
    fail "$desc"
  fi
}

check_not_contains() {
  local path="$1"
  local pattern="$2"
  local desc="$3"
  if grep -qE "$pattern" "$path" 2>/dev/null; then
    fail "$desc"
  else
    pass "$desc"
  fi
}

echo "=== Purchase Gateway Resilience Verification ==="
echo ""

FULFILLMENT_OUTBOX="$SVC_DIR/app/services/fulfillment_outbox.py"
WEBHOOKS="$SVC_DIR/app/routers/webhooks.py"
MODEL="$SVC_DIR/app/models/fulfillment_job.py"
MAIN="$SVC_DIR/app/main.py"
CONFIG="$SVC_DIR/app/config.py"
MIGRATION="$SVC_DIR/alembic/versions/002_fulfillment_outbox_jobs.py"
OUTBOX_TEST="$SVC_DIR/tests/unit/test_fulfillment_outbox.py"
WEBHOOK_TEST="$SVC_DIR/tests/unit/test_webhook_handler.py"

echo "-- Contract files --"
check_file "$FULFILLMENT_OUTBOX" "Outbox service exists"
check_file "$WEBHOOKS" "Webhook router exists"
check_file "$MODEL" "FulfillmentJob model exists"
check_file "$MIGRATION" "Fulfillment outbox migration exists"
check_file "$OUTBOX_TEST" "Outbox unit tests exist"
check_file "$WEBHOOK_TEST" "Webhook handler tests exist"

echo ""
echo "-- Outbox model + migration --"
check_contains "$MODEL" 'class FulfillmentJobStatus' "FulfillmentJobStatus enum defined"
check_contains "$MODEL" 'class FulfillmentJob' "FulfillmentJob model defined"
check_contains "$MODEL" 'order_id' "FulfillmentJob includes order_id"
check_contains "$MODEL" 'unique=True' "FulfillmentJob enforces one job per order"
check_contains "$MODEL" 'dead_letter' "FulfillmentJob supports dead_letter status"
check_contains "$MIGRATION" 'op\.create_table' "Migration uses create_table operation"
check_contains "$MIGRATION" 'fulfillment_jobs' "Migration references fulfillment_jobs table"
check_contains "$MIGRATION" 'ix_fulfillment_jobs_status_next_attempt' "Migration adds status/next_attempt index"

echo ""
echo "-- Webhook decoupling contract --"
check_contains "$WEBHOOKS" 'from app\.services\.fulfillment_outbox import enqueue_fulfillment_job' \
  "Webhook imports outbox enqueue helper"
check_contains "$WEBHOOKS" 'await enqueue_fulfillment_job\(' \
  "Webhook enqueues fulfillment job on checkout completion"
check_not_contains "$WEBHOOKS" 'from app\.services\.fulfillment import fulfill_order' \
  "Webhook does not directly import synchronous fulfill_order path"
check_contains "$WEBHOOK_TEST" 'enqueue_fulfillment_job' \
  "Webhook tests assert enqueue behavior"

echo ""
echo "-- Worker/reconciliation runtime contract --"
check_contains "$FULFILLMENT_OUTBOX" 'with_for_update\(skip_locked=True\)' \
  "Outbox worker claims jobs with skip_locked row locking"
check_contains "$FULFILLMENT_OUTBOX" 'attempts < FulfillmentJob\.max_attempts' \
  "Outbox claim path enforces max attempts"
check_contains "$FULFILLMENT_OUTBOX" 'async def reconcile_paid_orders' \
  "Reconciliation function exists"
check_contains "$FULFILLMENT_OUTBOX" 'ENABLE_RECONCILIATION_JOB' \
  "Worker loop gates reconciliation on feature flag"
check_contains "$FULFILLMENT_OUTBOX" 'FULFILLMENT_RECONCILE_INTERVAL_SECONDS' \
  "Worker loop uses configured reconciliation interval"
check_contains "$OUTBOX_TEST" 'test_reconcile_paid_orders_enqueues_jobs_and_commits' \
  "Outbox tests cover reconciliation enqueue flow"

echo ""
echo "-- Application config wiring --"
check_contains "$CONFIG" 'FULFILLMENT_WORKER_ENABLED' "Config exposes worker enable flag"
check_contains "$CONFIG" 'ENABLE_GATEWAY_FULFILLMENT' "Config exposes fulfillment feature flag"
check_contains "$CONFIG" 'ENABLE_RECONCILIATION_JOB' "Config exposes reconciliation feature flag"
check_contains "$CONFIG" 'FULFILLMENT_MAX_RETRIES' "Config exposes max retries"
check_contains "$CONFIG" 'FULFILLMENT_BASE_DELAY_SECONDS' "Config exposes retry base delay"
check_contains "$MAIN" 'run_fulfillment_worker' "App imports fulfillment worker loop"
check_contains "$MAIN" 'FULFILLMENT_WORKER_ENABLED and settings\.ENABLE_GATEWAY_FULFILLMENT' \
  "Worker starts only when both worker + fulfillment flags are enabled"

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
[[ $FAIL -eq 0 ]] && echo "PASS" || { echo "FAIL"; exit 1; }
