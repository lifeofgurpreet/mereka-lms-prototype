#!/usr/bin/env bash
set -euo pipefail

# Verify Purchase Gateway models contain required fields.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SVC_DIR="$REPO_ROOT/services/purchase-gateway"

PASS=0
FAIL=0

check_pattern() {
  local file="$1"
  local pattern="$2"
  local desc="$3"
  if grep -qP "$pattern" "$file" 2>/dev/null; then
    echo "  PASS: $desc"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $desc"
    FAIL=$((FAIL + 1))
  fi
}

echo "=== Purchase Gateway Model Verification ==="
echo ""

echo "-- Order model --"
ORDER="$SVC_DIR/app/models/order.py"
check_pattern "$ORDER" 'class Order\b' "Order class exists"
check_pattern "$ORDER" 'TenantMixin' "Order uses TenantMixin (provides tenant_id)"
check_pattern "$ORDER" 'buyer_email' "Order has buyer_email"
check_pattern "$ORDER" 'stripe_checkout_session_id' "Order has stripe_checkout_session_id"
check_pattern "$ORDER" 'stripe_payment_intent_id' "Order has stripe_payment_intent_id"
check_pattern "$ORDER" 'status.*OrderStatus' "Order has status enum"
check_pattern "$ORDER" 'total_cents' "Order has total_cents"
check_pattern "$ORDER" 'currency' "Order has currency"
check_pattern "$ORDER" 'class LineItem\b' "LineItem class exists"
check_pattern "$ORDER" 'fulfillment_status' "LineItem has fulfillment_status"
check_pattern "$ORDER" 'class OrderAuditLog\b' "OrderAuditLog class exists"
check_pattern "$ORDER" 'class OrderStatus' "OrderStatus enum exists"

echo ""
echo "-- Entitlement model --"
ENT="$SVC_DIR/app/models/entitlement.py"
check_pattern "$ENT" 'class Entitlement\b' "Entitlement class exists"
check_pattern "$ENT" 'TenantMixin' "Entitlement uses TenantMixin (provides tenant_id)"
check_pattern "$ENT" 'claim_token' "Entitlement has claim_token"
check_pattern "$ENT" 'recipient_email' "Entitlement has recipient_email"
check_pattern "$ENT" 'expires_at' "Entitlement has expires_at"
check_pattern "$ENT" 'claimed_by_user_id' "Entitlement has claimed_by_user_id"

echo ""
echo "-- StripeEvent model --"
EVT="$SVC_DIR/app/models/stripe_event.py"
check_pattern "$EVT" 'class StripeEvent\b' "StripeEvent class exists"
check_pattern "$EVT" 'stripe_event_id' "stripe_event_id field exists"
check_pattern "$EVT" 'event_type' "StripeEvent has event_type"
check_pattern "$EVT" 'payload_json' "StripeEvent has payload_json"
check_pattern "$EVT" 'processing_status' "StripeEvent has processing_status"

echo ""
echo "-- Base model --"
BASE="$SVC_DIR/app/models/base.py"
check_pattern "$BASE" 'class TenantMixin' "TenantMixin exists"
check_pattern "$BASE" 'tenant_id' "TenantMixin has tenant_id"

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
[[ $FAIL -eq 0 ]] && echo "PASS" || { echo "FAIL"; exit 1; }
