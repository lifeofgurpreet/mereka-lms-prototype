#!/usr/bin/env bash
# @covers AC-029
# @spec: ecommerce-purchase-gateway_spec.md
set -euo pipefail

# Verify purchase-gateway emits and wires canonical operational metrics.

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
  local file="$1"
  local desc="$2"
  if [[ -f "$file" ]]; then
    pass "$desc"
  else
    fail "$desc (missing: ${file#$REPO_ROOT/})"
  fi
}

check_contains() {
  local file="$1"
  local pattern="$2"
  local desc="$3"
  if grep -qE "$pattern" "$file" 2>/dev/null; then
    pass "$desc"
  else
    fail "$desc"
  fi
}

METRICS="$SVC_DIR/app/metrics.py"
MAIN="$SVC_DIR/app/main.py"
CHECKOUT="$SVC_DIR/app/routers/checkout.py"
WEBHOOKS="$SVC_DIR/app/routers/webhooks.py"
OUTBOX="$SVC_DIR/app/services/fulfillment_outbox.py"
CHECKOUT_TEST="$SVC_DIR/tests/unit/test_checkout_route.py"
WEBHOOK_TEST="$SVC_DIR/tests/integration/test_webhook_processing.py"
OUTBOX_TEST="$SVC_DIR/tests/unit/test_fulfillment_outbox.py"

echo "=== Purchase Gateway Metrics Contract Verification ==="
echo ""

echo "-- Metric definitions --"
check_file "$METRICS" "Metrics module exists"
check_contains "$METRICS" 'purchase_gateway_checkout_total' "checkout counter metric defined"
check_contains "$METRICS" 'purchase_gateway_webhook_processing_seconds' "webhook processing histogram defined"
check_contains "$METRICS" 'purchase_gateway_fulfillment_duration_seconds' "fulfillment duration histogram defined"
check_contains "$METRICS" 'purchase_gateway_dead_letter_total' "dead-letter counter metric defined"
check_contains "$METRICS" 'purchase_gateway_reconciliation_queued_total' "reconciliation queued counter metric defined"

echo ""
echo "-- Runtime wiring --"
check_contains "$MAIN" 'app\.mount\("/metrics", metrics_app\)' "/metrics endpoint mounted"
check_contains "$CHECKOUT" 'record_checkout_created' "checkout route imports/uses checkout metric hook"
check_contains "$WEBHOOKS" 'observe_webhook_processing' "webhook route imports/uses webhook latency metric hook"
check_contains "$OUTBOX" 'observe_fulfillment_duration' "outbox worker imports/uses fulfillment duration metric hook"
check_contains "$OUTBOX" 'record_dead_letter' "outbox dead-letter path increments dead-letter metric"
check_contains "$OUTBOX" 'record_reconciliation_queued' "reconciliation path increments reconciliation metric"

echo ""
echo "-- Test coverage anchors --"
check_contains "$CHECKOUT_TEST" 'record_checkout_created' "checkout tests assert checkout metric hook behavior"
check_contains "$WEBHOOK_TEST" 'observe_webhook_processing' "webhook tests assert webhook metric hook behavior"
check_contains "$OUTBOX_TEST" 'record_reconciliation_queued' "outbox tests assert reconciliation metric hook behavior"

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
[[ $FAIL -eq 0 ]] && echo "PASS" || { echo "FAIL"; exit 1; }
