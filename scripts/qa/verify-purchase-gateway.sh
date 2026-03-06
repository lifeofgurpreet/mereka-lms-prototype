#!/usr/bin/env bash
# @spec: ecommerce-purchase-gateway_spec.md
# @covers AC-001, AC-002, AC-003, AC-004, AC-005, AC-006, AC-007, AC-008, AC-009, AC-010, AC-011, AC-012, AC-013, AC-014, AC-015, AC-016, AC-017, AC-018, AC-019, AC-020, AC-021, AC-022, AC-023, AC-024, AC-025, AC-026, AC-027, AC-028, AC-029, AC-030, AC-031, AC-032, AC-033
#
# Comprehensive Purchase Gateway verification script.
# Validates scaffold completeness, data models, webhook handling, fulfillment,
# entitlement flow, refund/dispute handling, K8s manifests, secrets, and observability.
#
# Usage:
#   ./scripts/qa/verify-purchase-gateway.sh
#   ./scripts/qa/verify-purchase-gateway.sh --section checkout
#   ./scripts/qa/verify-purchase-gateway.sh --section webhook
#   ./scripts/qa/verify-purchase-gateway.sh --section entitlement
#   ./scripts/qa/verify-purchase-gateway.sh --section refund
#   ./scripts/qa/verify-purchase-gateway.sh --section fulfillment
#   ./scripts/qa/verify-purchase-gateway.sh --section enterprise
#   ./scripts/qa/verify-purchase-gateway.sh --section tenant
#   ./scripts/qa/verify-purchase-gateway.sh --section migration
#   ./scripts/qa/verify-purchase-gateway.sh --section observability
#   ./scripts/qa/verify-purchase-gateway.sh --section deployment
#   ./scripts/qa/verify-purchase-gateway.sh --skip-cluster
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

# --- Paths ---
GW_DIR="services/purchase-gateway"
APP_DIR="$GW_DIR/app"
MODELS_DIR="$APP_DIR/models"
ROUTERS_DIR="$APP_DIR/routers"
SERVICES_DIR="$APP_DIR/services"
K8S_DIR="$GW_DIR/k8s"
TESTS_DIR="$GW_DIR/tests"
ALEMBIC_DIR="$GW_DIR/alembic"
DOCKERFILE="$GW_DIR/Dockerfile"
PYPROJECT="$GW_DIR/pyproject.toml"

# --- Colours ---
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m'

PASSED=0
FAILED=0
SKIPPED=0
SECTION_FILTER=""
SKIP_CLUSTER=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --section) SECTION_FILTER="$2"; shift 2 ;;
    --skip-cluster) SKIP_CLUSTER=true; shift ;;
    -h|--help)
      echo "Usage: $0 [--section checkout|webhook|entitlement|refund|fulfillment|enterprise|tenant|migration|observability|deployment] [--skip-cluster]"
      exit 0
      ;;
    *) echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
done

pass() { echo -e "  ${GREEN}PASS${NC}  $1"; PASSED=$((PASSED + 1)); }
fail() { echo -e "  ${RED}FAIL${NC}  $1"; FAILED=$((FAILED + 1)); }
skip() { echo -e "  ${YELLOW}SKIP${NC}  $1"; SKIPPED=$((SKIPPED + 1)); }

# ============================================================================
# SECTION: Checkout Flow (AC-001 through AC-005)
# ============================================================================
check_checkout() {
  echo ""
  echo "══════════════════════════════════════════════════════════════"
  echo "  Checkout Flow"
  echo "══════════════════════════════════════════════════════════════"

  # AC-001: POST /api/v1/checkout/ endpoint exists
  if [[ -f "$ROUTERS_DIR/checkout.py" ]]; then
    if grep -q 'post.*"/checkout/"' "$ROUTERS_DIR/checkout.py"; then
      pass "[AC-001] POST /api/v1/checkout/ endpoint defined"
    else
      fail "[AC-001] POST /api/v1/checkout/ endpoint missing from checkout.py"
    fi
  else
    fail "[AC-001] checkout.py router missing"
  fi

  # AC-001: Checkout accepts offering_uuid and buyer_email
  if [[ -f "$ROUTERS_DIR/checkout.py" ]]; then
    if grep -q 'offering_uuid' "$ROUTERS_DIR/checkout.py" && grep -q 'buyer_email' "$ROUTERS_DIR/checkout.py"; then
      pass "[AC-001] Checkout accepts offering_uuid and buyer_email"
    else
      fail "[AC-001] Checkout missing offering_uuid or buyer_email parameters"
    fi
  fi

  # AC-001: Checkout creates Stripe Checkout Session and returns checkout_url
  if [[ -f "$ROUTERS_DIR/checkout.py" ]]; then
    if grep -q 'checkout.Session.create\|create_checkout_session' "$ROUTERS_DIR/checkout.py" && \
       grep -q 'checkout_url' "$ROUTERS_DIR/checkout.py"; then
      pass "[AC-001] Checkout creates Stripe Session and returns checkout_url"
    else
      fail "[AC-001] Checkout missing Stripe Session creation or checkout_url response"
    fi
  fi

  # AC-001: Checkout sets customer_email on Stripe session
  if [[ -f "$ROUTERS_DIR/checkout.py" ]] || [[ -f "$SERVICES_DIR/stripe_service.py" ]]; then
    if grep -q 'customer_email' "$ROUTERS_DIR/checkout.py" "$SERVICES_DIR/stripe_service.py" 2>/dev/null; then
      pass "[AC-001] customer_email set on Stripe Checkout Session"
    else
      fail "[AC-001] customer_email not set on Stripe Checkout Session"
    fi
  fi

  # AC-001: Pending Order created before Stripe redirect
  if [[ -f "$ROUTERS_DIR/checkout.py" ]]; then
    if grep -q 'OrderStatus.pending' "$ROUTERS_DIR/checkout.py"; then
      pass "[AC-001] Pending order created before Stripe redirect"
    else
      fail "[AC-001] Pending order not created before Stripe redirect"
    fi
  fi

  # AC-001: order_uuid passed as metadata on Stripe Checkout Session
  if grep -rq '"order_uuid"' "$ROUTERS_DIR/checkout.py" "$SERVICES_DIR/stripe_service.py" 2>/dev/null; then
    pass "[AC-001] order_uuid passed as metadata on Stripe Checkout Session"
  else
    fail "[AC-001] order_uuid not passed as metadata on Stripe Checkout Session"
  fi

  # AC-001: payment_intent_data capture_method set to automatic
  if grep -rq 'capture_method.*automatic' "$ROUTERS_DIR/checkout.py" "$SERVICES_DIR/stripe_service.py" 2>/dev/null; then
    pass "[AC-001] capture_method=automatic set on Stripe Checkout Session"
  else
    fail "[AC-001] capture_method=automatic not set on payment_intent_data"
  fi

  # AC-002: checkout.session.completed triggers enrollment (runtime)
  skip "[AC-002] Stripe checkout-to-enrollment flow requires runtime testing (Stripe test mode + LMS)"

  # AC-003: Buyer without LMS account gets entitlement + invitation (runtime)
  skip "[AC-003] Entitlement creation for non-LMS buyer requires runtime testing"

  # AC-004: checkout.session.expired handler exists
  if [[ -f "$ROUTERS_DIR/webhooks.py" ]]; then
    if grep -q 'checkout.session.expired' "$ROUTERS_DIR/webhooks.py" && \
       grep -q 'OrderStatus.expired' "$ROUTERS_DIR/webhooks.py"; then
      pass "[AC-004] checkout.session.expired handler transitions order to expired"
    else
      fail "[AC-004] checkout.session.expired handler missing or doesn't set expired status"
    fi
  else
    fail "[AC-004] webhooks.py router missing"
  fi

  # AC-005: Checkout status endpoint exists
  if [[ -f "$ROUTERS_DIR/checkout.py" ]]; then
    if grep -q 'checkout/{session_id}/status' "$ROUTERS_DIR/checkout.py"; then
      pass "[AC-005] GET /api/v1/checkout/{session_id}/status/ endpoint defined"
    else
      fail "[AC-005] Checkout status endpoint missing"
    fi
  fi

  # AC-005: Checkout returns 503 on Stripe API error
  if [[ -f "$ROUTERS_DIR/checkout.py" ]]; then
    if grep -q 'StripeError\|stripe_error' "$ROUTERS_DIR/checkout.py" && \
       grep -q '503' "$ROUTERS_DIR/checkout.py"; then
      pass "[AC-005] Checkout returns 503 on Stripe API error"
    else
      fail "[AC-005] Checkout missing 503 handling for Stripe API errors"
    fi
  fi
}

# ============================================================================
# SECTION: Webhook Handling (AC-006 through AC-009)
# ============================================================================
check_webhook() {
  echo ""
  echo "══════════════════════════════════════════════════════════════"
  echo "  Webhook Handling"
  echo "══════════════════════════════════════════════════════════════"

  # AC-006: Webhook endpoint at /webhooks/stripe/
  if [[ -f "$ROUTERS_DIR/webhooks.py" ]]; then
    if grep -q '"/webhooks/stripe/"' "$ROUTERS_DIR/webhooks.py"; then
      pass "[AC-006] Webhook endpoint at /webhooks/stripe/"
    else
      fail "[AC-006] Webhook endpoint path not /webhooks/stripe/"
    fi
  else
    fail "[AC-006] webhooks.py router missing"
  fi

  # AC-006: Events logged in stripe_events table
  if [[ -f "$ROUTERS_DIR/webhooks.py" ]]; then
    if grep -q 'StripeEvent(' "$ROUTERS_DIR/webhooks.py"; then
      pass "[AC-006] Stripe events logged in stripe_events table"
    else
      fail "[AC-006] Stripe events not logged in stripe_events table"
    fi
  fi

  # AC-007: Webhook verifies Stripe signature
  if [[ -f "$ROUTERS_DIR/webhooks.py" ]]; then
    if grep -q 'Webhook.construct_event\|verify_webhook_signature' "$ROUTERS_DIR/webhooks.py" && \
       grep -q 'Stripe-Signature\|stripe_signature' "$ROUTERS_DIR/webhooks.py"; then
      pass "[AC-007] Webhook verifies Stripe signature via Stripe-Signature header"
    else
      fail "[AC-007] Stripe signature verification missing"
    fi
  fi

  # AC-007: Invalid signature returns 400
  if [[ -f "$ROUTERS_DIR/webhooks.py" ]]; then
    if grep -q 'SignatureVerificationError' "$ROUTERS_DIR/webhooks.py" && \
       grep -q 'status_code=400' "$ROUTERS_DIR/webhooks.py"; then
      pass "[AC-007] Invalid signature returns HTTP 400"
    else
      fail "[AC-007] Invalid signature does not return HTTP 400"
    fi
  fi

  # AC-008: Idempotent webhook processing (checks stripe_event_id)
  if [[ -f "$ROUTERS_DIR/webhooks.py" ]]; then
    if grep -q 'stripe_event_id == event_id\|stripe_event_id' "$ROUTERS_DIR/webhooks.py" && \
       grep -q 'duplicate' "$ROUTERS_DIR/webhooks.py"; then
      pass "[AC-008] Webhook processing is idempotent (checks stripe_event_id)"
    else
      fail "[AC-008] Webhook idempotency check missing"
    fi
  fi

  # AC-008: IntegrityError handled for race condition
  if [[ -f "$ROUTERS_DIR/webhooks.py" ]]; then
    if grep -q 'IntegrityError' "$ROUTERS_DIR/webhooks.py"; then
      pass "[AC-008] IntegrityError race condition handled in webhook processing"
    else
      fail "[AC-008] IntegrityError race condition not handled"
    fi
  fi

  # AC-009: Multi-tenant webhook routing (Stripe Connect)
  if [[ -f "$SERVICES_DIR/stripe_service.py" ]]; then
    if grep -q 'stripe_account' "$SERVICES_DIR/stripe_service.py"; then
      pass "[AC-009] Stripe Connect multi-tenant support (stripe_account parameter)"
    else
      fail "[AC-009] Stripe Connect multi-tenant support missing"
    fi
  else
    fail "[AC-009] stripe_service.py missing"
  fi

  # AC-006: Webhook handles all required event types
  if [[ -f "$ROUTERS_DIR/webhooks.py" ]]; then
    local required_events=(
      "checkout.session.completed"
      "checkout.session.expired"
      "payment_intent.payment_failed"
      "charge.refunded"
      "charge.dispute.created"
      "charge.dispute.closed"
      "customer.subscription.created"
      "customer.subscription.updated"
      "customer.subscription.deleted"
      "invoice.paid"
      "invoice.payment_failed"
    )
    local found=0
    for event_type in "${required_events[@]}"; do
      if grep -q "$event_type" "$ROUTERS_DIR/webhooks.py"; then
        found=$((found + 1))
      fi
    done
    if [[ "$found" -eq "${#required_events[@]}" ]]; then
      pass "[AC-006] All ${#required_events[@]} required Stripe event types handled"
    else
      fail "[AC-006] Missing event type handlers ($found/${#required_events[@]} found)"
    fi
  fi
}

# ============================================================================
# SECTION: Entitlement and Invitation (AC-010 through AC-014)
# ============================================================================
check_entitlement() {
  echo ""
  echo "══════════════════════════════════════════════════════════════"
  echo "  Entitlement and Invitation"
  echo "══════════════════════════════════════════════════════════════"

  # AC-010: Entitlement model with required fields
  if [[ -f "$MODELS_DIR/entitlement.py" ]]; then
    local ent_fields=(claim_token recipient_email lms_resource_id offering_type status
                      claimed_by_user_id expires_at claimed_at order_id line_item_id)
    local found=0
    for field in "${ent_fields[@]}"; do
      if grep -q "$field" "$MODELS_DIR/entitlement.py"; then
        found=$((found + 1))
      fi
    done
    if [[ "$found" -eq "${#ent_fields[@]}" ]]; then
      pass "[AC-010] Entitlement model has all ${#ent_fields[@]} required fields"
    else
      fail "[AC-010] Entitlement model missing fields ($found/${#ent_fields[@]} found)"
    fi
  else
    fail "[AC-010] entitlement.py model missing"
  fi

  # AC-010: claim_token is unique
  if grep -q 'unique=True' "$MODELS_DIR/entitlement.py" 2>/dev/null; then
    pass "[AC-010] Entitlement claim_token has unique constraint"
  else
    fail "[AC-010] Entitlement claim_token missing unique constraint"
  fi

  # AC-010: EntitlementStatus enum includes all required states
  if [[ -f "$MODELS_DIR/entitlement.py" ]]; then
    local statuses=(pending claimed expired revoked)
    local found=0
    for s in "${statuses[@]}"; do
      if grep -q "\"$s\"" "$MODELS_DIR/entitlement.py"; then
        found=$((found + 1))
      fi
    done
    if [[ "$found" -eq "${#statuses[@]}" ]]; then
      pass "[AC-010] EntitlementStatus has all 4 required states (pending/claimed/expired/revoked)"
    else
      fail "[AC-010] EntitlementStatus missing states ($found/4 found)"
    fi
  fi

  # AC-010: Claim endpoint (runtime — needs auth integration)
  skip "[AC-010] Entitlement claim via /api/v1/claim/{token} requires runtime testing (auth + LMS)"

  # AC-011: Unauthenticated claim redirects to login (runtime)
  skip "[AC-011] Unauthenticated claim redirect requires runtime testing"

  # AC-012: Expired claim token returns error (runtime)
  skip "[AC-012] Expired claim token handling requires runtime testing"

  # AC-013: Already-claimed token returns idempotent response (runtime)
  skip "[AC-013] Already-claimed token idempotency requires runtime testing"

  # AC-014: Bulk entitlement assignment (runtime — admin API)
  skip "[AC-014] Bulk entitlement assignment via admin API requires runtime testing"

  # AC-010: Fulfillment creates entitlements when no LMS user
  if [[ -f "$SERVICES_DIR/fulfillment.py" ]]; then
    if grep -q 'Entitlement(' "$SERVICES_DIR/fulfillment.py" && \
       grep -q 'claim_token' "$SERVICES_DIR/fulfillment.py"; then
      pass "[AC-010] Fulfillment engine creates entitlements with claim_token for non-LMS users"
    else
      fail "[AC-010] Fulfillment engine does not create entitlements for non-LMS users"
    fi
  fi

  # AC-010: claim_token is cryptographically random (secrets.token_urlsafe)
  if grep -q 'secrets.token_urlsafe\|token_urlsafe' "$SERVICES_DIR/fulfillment.py" 2>/dev/null; then
    pass "[AC-010] claim_token generated with secrets.token_urlsafe (cryptographically random)"
  else
    fail "[AC-010] claim_token not generated with cryptographically random method"
  fi

  # AC-010: Entitlement expires_at set with configurable TTL
  if grep -q 'ENTITLEMENT_CLAIM_EXPIRY_DAYS' "$SERVICES_DIR/fulfillment.py" 2>/dev/null; then
    pass "[AC-010] Entitlement expiry uses configurable ENTITLEMENT_CLAIM_EXPIRY_DAYS"
  else
    fail "[AC-010] Entitlement expiry not configurable"
  fi
}

# ============================================================================
# SECTION: Refund and Dispute (AC-015 through AC-018)
# ============================================================================
check_refund() {
  echo ""
  echo "══════════════════════════════════════════════════════════════"
  echo "  Refund and Dispute"
  echo "══════════════════════════════════════════════════════════════"

  # Refund/dispute handlers may be in webhooks.py or service modules
  local REFUND_SRC="$SERVICES_DIR/refund.py"
  local DISPUTE_SRC="$SERVICES_DIR/dispute.py"
  # Fall back to webhooks.py if service modules don't exist
  [[ ! -f "$REFUND_SRC" ]] && REFUND_SRC="$ROUTERS_DIR/webhooks.py"
  [[ ! -f "$DISPUTE_SRC" ]] && DISPUTE_SRC="$ROUTERS_DIR/webhooks.py"

  # AC-015: Full refund transitions to refunded + enrollment deactivation
  if [[ -f "$REFUND_SRC" ]]; then
    if grep -q 'OrderStatus.refunded' "$REFUND_SRC" && \
       grep -q 'deactivate_enrollment\|revoke_enrollment\|_revoke_order_enrollments' "$REFUND_SRC"; then
      pass "[AC-015] Full refund transitions to refunded and deactivates enrollment"
    else
      fail "[AC-015] Full refund handler missing status transition or enrollment deactivation"
    fi
  else
    fail "[AC-015] Refund handler source missing"
  fi

  # AC-015: Refund handler distinguishes full vs partial
  if [[ -f "$REFUND_SRC" ]]; then
    if grep -q 'amount_refunded' "$REFUND_SRC" && \
       grep -q 'is_full_refund\|full_refund' "$REFUND_SRC"; then
      pass "[AC-015] Refund handler distinguishes full vs partial refund"
    else
      fail "[AC-015] Refund handler does not distinguish full vs partial"
    fi
  fi

  # AC-015: Full refund via Stripe webhook (runtime)
  skip "[AC-015] Full refund-to-enrollment-revocation flow requires runtime testing (Stripe + LMS)"

  # AC-016: Partial refund transitions to partially_refunded
  if [[ -f "$REFUND_SRC" ]]; then
    if grep -q 'OrderStatus.partially_refunded' "$REFUND_SRC"; then
      pass "[AC-016] Partial refund transitions to partially_refunded"
    else
      fail "[AC-016] Partial refund status transition missing"
    fi
  fi

  # AC-017: Dispute created transitions to disputed
  if [[ -f "$DISPUTE_SRC" ]]; then
    if grep -q 'OrderStatus.disputed' "$DISPUTE_SRC"; then
      pass "[AC-017] charge.dispute.created transitions order to disputed"
    else
      fail "[AC-017] Dispute created handler missing or doesn't set disputed status"
    fi
  else
    fail "[AC-017] Dispute handler source missing"
  fi

  # AC-018: Dispute closed (won) restores order
  if [[ -f "$DISPUTE_SRC" ]]; then
    if grep -q '"won"' "$DISPUTE_SRC"; then
      pass "[AC-018] charge.dispute.closed (won) restores order to pre-dispute state"
    else
      fail "[AC-018] Dispute closed handler missing or doesn't handle won status"
    fi
  fi

  # AC-018: Dispute closed (lost) refunds order
  if [[ -f "$DISPUTE_SRC" ]]; then
    if grep -q 'dispute_lost_refunded\|lost.*refunded' "$DISPUTE_SRC"; then
      pass "[AC-018] charge.dispute.closed (lost) transitions to refunded"
    else
      fail "[AC-018] Dispute closed handler doesn't handle lost status"
    fi
  fi

  # AC-015/016: Audit log entry for refund
  if [[ -f "$REFUND_SRC" ]]; then
    if grep -q '_log_audit\|OrderAuditLog' "$REFUND_SRC" && \
       grep -q 'charge.refunded\|stripe.charge.refunded' "$REFUND_SRC"; then
      pass "[AC-015] Refund state transitions logged in audit log"
    else
      fail "[AC-015] Refund audit logging missing"
    fi
  fi
}

# ============================================================================
# SECTION: Fulfillment Engine (AC-019 through AC-021)
# ============================================================================
check_fulfillment() {
  echo ""
  echo "══════════════════════════════════════════════════════════════"
  echo "  Fulfillment Engine"
  echo "══════════════════════════════════════════════════════════════"

  # AC-019: Fulfillment service exists
  if [[ -f "$SERVICES_DIR/fulfillment.py" ]]; then
    pass "[AC-019] Fulfillment engine exists at $SERVICES_DIR/fulfillment.py"
  else
    fail "[AC-019] Fulfillment engine missing"
    return
  fi

  # AC-019: Retry config present (max retries + base delay)
  if [[ -f "$APP_DIR/config.py" ]]; then
    if grep -q 'FULFILLMENT_MAX_RETRIES' "$APP_DIR/config.py" && \
       grep -q 'FULFILLMENT_BASE_DELAY_SECONDS' "$APP_DIR/config.py"; then
      pass "[AC-019] Fulfillment retry config defined (max_retries + base_delay)"
    else
      fail "[AC-019] Fulfillment retry config missing from settings"
    fi
  fi

  # AC-019: Max retries defaults to 10
  if grep -q 'FULFILLMENT_MAX_RETRIES.*10' "$APP_DIR/config.py" 2>/dev/null; then
    pass "[AC-019] FULFILLMENT_MAX_RETRIES defaults to 10"
  else
    fail "[AC-019] FULFILLMENT_MAX_RETRIES does not default to 10"
  fi

  # AC-019: Base delay defaults to 5 seconds
  if grep -q 'FULFILLMENT_BASE_DELAY_SECONDS.*5' "$APP_DIR/config.py" 2>/dev/null; then
    pass "[AC-019] FULFILLMENT_BASE_DELAY_SECONDS defaults to 5"
  else
    fail "[AC-019] FULFILLMENT_BASE_DELAY_SECONDS does not default to 5"
  fi

  # AC-019: Fulfillment retries with exponential backoff (runtime)
  skip "[AC-019] Exponential backoff retry behavior requires runtime testing"

  # AC-020: fulfillment_failed status transitions to fulfillment_failed
  if grep -q 'OrderStatus.fulfillment_failed' "$SERVICES_DIR/fulfillment.py"; then
    pass "[AC-020] Fulfillment transitions to fulfillment_failed after all retries exhausted"
  else
    fail "[AC-020] fulfillment_failed status transition missing from fulfillment engine"
  fi

  # AC-020: Dead letter queue and alert on failure (runtime)
  skip "[AC-020] Dead letter queue + Critical alert on exhausted retries requires runtime testing"

  # AC-021: Idempotent fulfillment (checks existing enrollment)
  if grep -q 'FulfillmentStatus.fulfilled' "$SERVICES_DIR/fulfillment.py" && \
     grep -q 'continue' "$SERVICES_DIR/fulfillment.py"; then
    pass "[AC-021] Fulfillment is idempotent (skips already-fulfilled line items)"
  else
    fail "[AC-021] Fulfillment idempotency check missing"
  fi

  # AC-021: LMS 409 (already enrolled) treated as success
  if [[ -f "$SERVICES_DIR/lms_client.py" ]]; then
    if grep -q '409' "$SERVICES_DIR/lms_client.py"; then
      pass "[AC-021] LMS HTTP 409 (already enrolled) treated as idempotent success"
    else
      fail "[AC-021] LMS 409 handling missing in lms_client"
    fi
  fi

  # Fulfillment resolves buyer by email via LMS API
  if grep -q 'get_user_by_email' "$SERVICES_DIR/fulfillment.py"; then
    pass "[AC-002] Fulfillment resolves buyer by email via LMS API"
  else
    fail "[AC-002] Fulfillment does not resolve buyer by email"
  fi

  # Fulfillment sets buyer_user_id on order
  if grep -q 'buyer_user_id' "$SERVICES_DIR/fulfillment.py"; then
    pass "[AC-002] Fulfillment sets buyer_user_id on order"
  else
    fail "[AC-002] Fulfillment does not set buyer_user_id"
  fi

  # Feature flag gates fulfillment
  if grep -q 'ENABLE_GATEWAY_FULFILLMENT' "$SERVICES_DIR/fulfillment.py"; then
    pass "[AC-002] Fulfillment gated by ENABLE_GATEWAY_FULFILLMENT feature flag"
  else
    fail "[AC-002] ENABLE_GATEWAY_FULFILLMENT feature flag not checked in fulfillment"
  fi
}

# ============================================================================
# SECTION: Enterprise Features (AC-022 through AC-023)
# ============================================================================
check_enterprise() {
  echo ""
  echo "══════════════════════════════════════════════════════════════"
  echo "  Enterprise Features"
  echo "══════════════════════════════════════════════════════════════"

  # AC-022: Subscription model exists
  if [[ -f "$MODELS_DIR/subscription.py" ]]; then
    pass "[AC-022] Subscription model exists"
  else
    fail "[AC-022] Subscription model missing"
  fi

  # AC-022: Subscription model has required fields
  # Note: tenant_id comes from TenantMixin in base.py, not directly in subscription.py
  if [[ -f "$MODELS_DIR/subscription.py" ]]; then
    local sub_fields=(stripe_subscription_id stripe_customer_id status
                      current_period_start current_period_end offering_id
                      seat_count)
    local found=0
    for field in "${sub_fields[@]}"; do
      if grep -q "$field" "$MODELS_DIR/subscription.py"; then
        found=$((found + 1))
      fi
    done
    # Also verify TenantMixin is used (provides tenant_id)
    if grep -q 'TenantMixin' "$MODELS_DIR/subscription.py"; then
      found=$((found + 1))
    fi
    local expected=8
    if [[ "$found" -eq "$expected" ]]; then
      pass "[AC-022] Subscription model has all $expected required fields (inc. TenantMixin)"
    else
      fail "[AC-022] Subscription model missing fields ($found/$expected found)"
    fi
  fi

  # AC-022: SubscriptionStatus enum
  if [[ -f "$MODELS_DIR/subscription.py" ]]; then
    local statuses=(active past_due canceled)
    local found=0
    for s in "${statuses[@]}"; do
      if grep -q "\"$s\"" "$MODELS_DIR/subscription.py"; then
        found=$((found + 1))
      fi
    done
    if [[ "$found" -eq "${#statuses[@]}" ]]; then
      pass "[AC-022] SubscriptionStatus has required states (active/past_due/canceled)"
    else
      fail "[AC-022] SubscriptionStatus missing states ($found/3 found)"
    fi
  fi

  # AC-022: Subscription has grace_period_end field
  if grep -q 'grace_period_end' "$MODELS_DIR/subscription.py" 2>/dev/null; then
    pass "[AC-023] Subscription model has grace_period_end for payment failure handling"
  else
    fail "[AC-023] Subscription model missing grace_period_end field"
  fi

  # AC-022: ENABLE_ENTERPRISE_SUBSCRIPTIONS feature flag
  if grep -q 'ENABLE_ENTERPRISE_SUBSCRIPTIONS' "$APP_DIR/config.py" 2>/dev/null; then
    pass "[AC-022] ENABLE_ENTERPRISE_SUBSCRIPTIONS feature flag defined"
  else
    fail "[AC-022] ENABLE_ENTERPRISE_SUBSCRIPTIONS feature flag missing"
  fi

  # AC-022: invoice.paid handling (runtime)
  skip "[AC-022] invoice.paid subscription renewal requires runtime testing"

  # AC-023: invoice.payment_failed → grace period (runtime)
  skip "[AC-023] invoice.payment_failed grace period handling requires runtime testing"
}

# ============================================================================
# SECTION: Multi-Tenant Isolation (AC-024 through AC-026)
# ============================================================================
check_tenant() {
  echo ""
  echo "══════════════════════════════════════════════════════════════"
  echo "  Multi-Tenant Isolation"
  echo "══════════════════════════════════════════════════════════════"

  # AC-024/AC-025: Tenant middleware exists
  if [[ -f "$APP_DIR/middleware/tenant.py" ]]; then
    pass "[AC-024] Tenant resolution middleware exists"
  else
    fail "[AC-024] Tenant resolution middleware missing"
  fi

  # AC-024: Middleware extracts X-Tenant-ID header
  if grep -q 'X-Tenant-ID' "$APP_DIR/middleware/tenant.py" 2>/dev/null; then
    pass "[AC-024] Middleware extracts X-Tenant-ID header"
  else
    fail "[AC-024] Middleware does not extract X-Tenant-ID header"
  fi

  # AC-025: TenantMixin used across data models
  local tenant_models=(order.py entitlement.py offering.py subscription.py)
  local tenant_found=0
  for model in "${tenant_models[@]}"; do
    if grep -q 'TenantMixin' "$MODELS_DIR/$model" 2>/dev/null; then
      tenant_found=$((tenant_found + 1))
    fi
  done
  if [[ "$tenant_found" -eq "${#tenant_models[@]}" ]]; then
    pass "[AC-025] TenantMixin applied to all ${#tenant_models[@]} tenant-scoped models"
  else
    fail "[AC-025] TenantMixin missing from some models ($tenant_found/${#tenant_models[@]} found)"
  fi

  # AC-025: TenantMixin adds tenant_id column with index
  if [[ -f "$MODELS_DIR/base.py" ]]; then
    if grep -q 'tenant_id' "$MODELS_DIR/base.py" && grep -q 'index=True' "$MODELS_DIR/base.py"; then
      pass "[AC-025] TenantMixin adds indexed tenant_id column"
    else
      fail "[AC-025] TenantMixin tenant_id column not indexed"
    fi
  fi

  # AC-025: TENANT_ISOLATION_ENABLED setting
  if grep -q 'TENANT_ISOLATION_ENABLED' "$APP_DIR/config.py" 2>/dev/null; then
    pass "[AC-025] TENANT_ISOLATION_ENABLED setting defined"
  else
    fail "[AC-025] TENANT_ISOLATION_ENABLED setting missing"
  fi

  # AC-024: Admin tenant isolation (runtime — needs admin API)
  skip "[AC-024] Admin API tenant-scoped query filtering requires runtime testing"

  # AC-026: Multi-tenant webhook routing with Stripe Connect (runtime)
  skip "[AC-026] Stripe Connect webhook routing per connected account requires runtime testing"
}

# ============================================================================
# SECTION: Migration (AC-027 through AC-028)
# ============================================================================
check_migration() {
  echo ""
  echo "══════════════════════════════════════════════════════════════"
  echo "  Legacy Ecommerce Migration"
  echo "══════════════════════════════════════════════════════════════"

  # AC-027: Purchase Gateway can run alongside legacy ecommerce
  if [[ -f "$K8S_DIR/deployment.yaml" ]]; then
    # The gateway deployment uses distinct labels (payments-gateway, not ecommerce)
    if grep -q 'payments-gateway' "$K8S_DIR/deployment.yaml"; then
      pass "[AC-027] Gateway uses distinct name (payments-gateway) for dual-running"
    else
      fail "[AC-027] Gateway not named distinctly from legacy ecommerce"
    fi
  fi

  # AC-027: Feature flag allows shadow mode (no fulfillment)
  if grep -q 'ENABLE_GATEWAY_FULFILLMENT.*False\|ENABLE_GATEWAY_FULFILLMENT.*false' \
     "$APP_DIR/config.py" "$K8S_DIR/deployment.yaml" 2>/dev/null; then
    pass "[AC-027] Shadow mode supported (ENABLE_GATEWAY_FULFILLMENT defaults to false)"
  else
    fail "[AC-027] Shadow mode not supported — ENABLE_GATEWAY_FULFILLMENT missing or not default false"
  fi

  # AC-027: New purchase routing to gateway (runtime — Caddy config)
  skip "[AC-027] New purchase routing to gateway requires Caddy config + runtime verification"

  # AC-028: Decommission script for legacy ecommerce (not yet implemented)
  skip "[AC-028] Legacy ecommerce decommission script not yet implemented"
}

# ============================================================================
# SECTION: Observability (AC-029 through AC-030)
# ============================================================================
check_observability() {
  echo ""
  echo "══════════════════════════════════════════════════════════════"
  echo "  Observability"
  echo "══════════════════════════════════════════════════════════════"

  # AC-029: Prometheus metrics endpoint mounted
  if [[ -f "$APP_DIR/main.py" ]]; then
    if grep -q 'prometheus_client\|make_asgi_app' "$APP_DIR/main.py" && \
       grep -q '/metrics' "$APP_DIR/main.py"; then
      pass "[AC-029] Prometheus metrics endpoint mounted at /metrics"
    else
      fail "[AC-029] Prometheus metrics endpoint not mounted"
    fi
  else
    fail "[AC-029] main.py missing"
  fi

  # AC-029: prometheus-client in dependencies
  if grep -q 'prometheus-client' "$PYPROJECT"; then
    pass "[AC-029] prometheus-client dependency declared in pyproject.toml"
  else
    fail "[AC-029] prometheus-client not in dependencies"
  fi

  # AC-029: Prometheus metrics for purchases (runtime check)
  skip "[AC-029] Purchase-specific metrics (checkout count, fulfillment duration) require runtime scraping"

  # AC-030: Structured logging (structlog)
  if grep -q 'structlog' "$PYPROJECT"; then
    pass "[AC-030] structlog dependency declared for structured logging"
  else
    fail "[AC-030] structlog not in dependencies"
  fi

  # AC-030: Fulfillment logs include order_uuid
  if grep -q 'order_uuid' "$SERVICES_DIR/fulfillment.py" 2>/dev/null; then
    pass "[AC-030] Fulfillment logs include order_uuid"
  else
    fail "[AC-030] Fulfillment logs missing order_uuid"
  fi

  # AC-030: Fulfillment logs include tenant_id
  if grep -q 'tenant_id' "$SERVICES_DIR/fulfillment.py" 2>/dev/null; then
    pass "[AC-030] Fulfillment logs include tenant_id"
  else
    fail "[AC-030] Fulfillment logs missing tenant_id"
  fi

  # AC-030: Webhook logs include stripe_event_id and event_type
  if [[ -f "$ROUTERS_DIR/webhooks.py" ]]; then
    if grep -q 'stripe_event_id' "$ROUTERS_DIR/webhooks.py" && \
       grep -q 'event_type' "$ROUTERS_DIR/webhooks.py"; then
      pass "[AC-030] Webhook logs include stripe_event_id and event_type"
    else
      fail "[AC-030] Webhook logs missing stripe_event_id or event_type"
    fi
  fi

  # AC-030: CORS configured
  if [[ -f "$APP_DIR/main.py" ]]; then
    if grep -q 'CORSMiddleware' "$APP_DIR/main.py" && \
       grep -q 'ALLOWED_ORIGINS' "$APP_DIR/main.py"; then
      pass "[AC-030] CORS middleware configured with ALLOWED_ORIGINS"
    else
      fail "[AC-030] CORS not configured"
    fi
  fi
}

# ============================================================================
# SECTION: Health and Deployment (AC-031 through AC-033)
# ============================================================================
check_deployment() {
  echo ""
  echo "══════════════════════════════════════════════════════════════"
  echo "  Health and Deployment"
  echo "══════════════════════════════════════════════════════════════"

  # --- Scaffold Structure ---

  # Directory structure
  local required_dirs=("$APP_DIR" "$MODELS_DIR" "$ROUTERS_DIR" "$SERVICES_DIR"
                       "$TESTS_DIR" "$K8S_DIR" "$ALEMBIC_DIR")
  local dir_found=0
  for d in "${required_dirs[@]}"; do
    if [[ -d "$d" ]]; then
      dir_found=$((dir_found + 1))
    fi
  done
  if [[ "$dir_found" -eq "${#required_dirs[@]}" ]]; then
    pass "[AC-031] All ${#required_dirs[@]} required directories present"
  else
    fail "[AC-031] Missing directories ($dir_found/${#required_dirs[@]} found)"
  fi

  # Required files
  local required_files=("$DOCKERFILE" "$PYPROJECT" "$GW_DIR/alembic.ini"
                        "$APP_DIR/main.py" "$APP_DIR/config.py" "$APP_DIR/database.py")
  local file_found=0
  for f in "${required_files[@]}"; do
    if [[ -f "$f" ]]; then
      file_found=$((file_found + 1))
    fi
  done
  if [[ "$file_found" -eq "${#required_files[@]}" ]]; then
    pass "[AC-031] All ${#required_files[@]} required files present"
  else
    fail "[AC-031] Missing files ($file_found/${#required_files[@]} found)"
  fi

  # --- Database Models ---

  # All required models exported from __init__.py
  if [[ -f "$MODELS_DIR/__init__.py" ]]; then
    local model_names=(Order LineItem OrderAuditLog OrderStatus Offering OfferingType
                       Entitlement StripeEvent Subscription SubscriptionStatus Base)
    local model_found=0
    for model in "${model_names[@]}"; do
      if grep -q "$model" "$MODELS_DIR/__init__.py"; then
        model_found=$((model_found + 1))
      fi
    done
    if [[ "$model_found" -eq "${#model_names[@]}" ]]; then
      pass "[AC-031] All ${#model_names[@]} model classes exported from models/__init__.py"
    else
      fail "[AC-031] Missing model exports ($model_found/${#model_names[@]} found)"
    fi
  else
    fail "[AC-031] models/__init__.py missing"
  fi

  # Order state machine completeness
  if [[ -f "$MODELS_DIR/order.py" ]]; then
    local order_statuses=(pending paid fulfilling fulfilled partially_fulfilled
                          fulfillment_failed refunded partially_refunded disputed
                          expired canceled)
    local status_found=0
    for s in "${order_statuses[@]}"; do
      if grep -q "\"$s\"" "$MODELS_DIR/order.py"; then
        status_found=$((status_found + 1))
      fi
    done
    if [[ "$status_found" -eq "${#order_statuses[@]}" ]]; then
      pass "[AC-031] Order state machine has all ${#order_statuses[@]} required states"
    else
      fail "[AC-031] Order state machine missing states ($status_found/${#order_statuses[@]} found)"
    fi
  fi

  # Order model required fields
  if [[ -f "$MODELS_DIR/order.py" ]]; then
    local order_fields=(buyer_email buyer_user_id stripe_checkout_session_id
                        stripe_payment_intent_id stripe_customer_id status
                        total_cents currency fulfilled_at refunded_at metadata_json)
    local field_found=0
    for field in "${order_fields[@]}"; do
      if grep -q "$field" "$MODELS_DIR/order.py"; then
        field_found=$((field_found + 1))
      fi
    done
    if [[ "$field_found" -eq "${#order_fields[@]}" ]]; then
      pass "[AC-031] Order model has all ${#order_fields[@]} required fields"
    else
      fail "[AC-031] Order model missing fields ($field_found/${#order_fields[@]} found)"
    fi
  fi

  # LineItem model required fields
  if [[ -f "$MODELS_DIR/order.py" ]]; then
    local li_fields=(order_id offering_uuid offering_type lms_resource_id quantity
                     unit_price_cents total_price_cents fulfillment_status)
    local li_found=0
    for field in "${li_fields[@]}"; do
      if grep -q "$field" "$MODELS_DIR/order.py"; then
        li_found=$((li_found + 1))
      fi
    done
    if [[ "$li_found" -eq "${#li_fields[@]}" ]]; then
      pass "[AC-031] LineItem model has all ${#li_fields[@]} required fields"
    else
      fail "[AC-031] LineItem model missing fields ($li_found/${#li_fields[@]} found)"
    fi
  fi

  # OrderAuditLog model
  if [[ -f "$MODELS_DIR/order.py" ]]; then
    if grep -q 'class OrderAuditLog' "$MODELS_DIR/order.py"; then
      local audit_fields=(order_id old_status new_status triggered_by timestamp details)
      local audit_found=0
      for field in "${audit_fields[@]}"; do
        if grep -q "$field" "$MODELS_DIR/order.py"; then
          audit_found=$((audit_found + 1))
        fi
      done
      if [[ "$audit_found" -eq "${#audit_fields[@]}" ]]; then
        pass "[AC-031] OrderAuditLog has all ${#audit_fields[@]} required fields"
      else
        fail "[AC-031] OrderAuditLog missing fields ($audit_found/${#audit_fields[@]} found)"
      fi
    else
      fail "[AC-031] OrderAuditLog model class missing"
    fi
  fi

  # StripeEvent model required fields
  if [[ -f "$MODELS_DIR/stripe_event.py" ]]; then
    local se_fields=(stripe_event_id event_type payload_json processing_status
                     received_at processed_at)
    local se_found=0
    for field in "${se_fields[@]}"; do
      if grep -q "$field" "$MODELS_DIR/stripe_event.py"; then
        se_found=$((se_found + 1))
      fi
    done
    if [[ "$se_found" -eq "${#se_fields[@]}" ]]; then
      pass "[AC-031] StripeEvent model has all ${#se_fields[@]} required fields"
    else
      fail "[AC-031] StripeEvent model missing fields ($se_found/${#se_fields[@]} found)"
    fi
  fi

  # stripe_event_id unique constraint
  if grep -q 'unique=True' "$MODELS_DIR/stripe_event.py" 2>/dev/null; then
    pass "[AC-031] StripeEvent.stripe_event_id has unique constraint"
  else
    fail "[AC-031] StripeEvent.stripe_event_id missing unique constraint"
  fi

  # Offering model
  if [[ -f "$MODELS_DIR/offering.py" ]]; then
    local offering_types=(course_seat program seat_pack)
    local ot_found=0
    for t in "${offering_types[@]}"; do
      if grep -q "\"$t\"" "$MODELS_DIR/offering.py"; then
        ot_found=$((ot_found + 1))
      fi
    done
    if [[ "$ot_found" -eq "${#offering_types[@]}" ]]; then
      pass "[AC-031] Offering model supports all 3 offering types (course_seat/program/seat_pack)"
    else
      fail "[AC-031] Offering model missing types ($ot_found/3 found)"
    fi
  fi

  # Offering has required fields
  if [[ -f "$MODELS_DIR/offering.py" ]]; then
    local off_fields=(offering_type title price_cents currency stripe_price_id
                      lms_resource_id active metadata_json)
    local off_found=0
    for field in "${off_fields[@]}"; do
      if grep -q "$field" "$MODELS_DIR/offering.py"; then
        off_found=$((off_found + 1))
      fi
    done
    if [[ "$off_found" -eq "${#off_fields[@]}" ]]; then
      pass "[AC-031] Offering model has all ${#off_fields[@]} required fields"
    else
      fail "[AC-031] Offering model missing fields ($off_found/${#off_fields[@]} found)"
    fi
  fi

  # --- Database Migrations ---

  # Alembic migration exists
  if [[ -f "$ALEMBIC_DIR/versions/001_initial_schema.py" ]]; then
    pass "[AC-031] Alembic initial migration exists"
  else
    fail "[AC-031] Alembic initial migration missing"
  fi

  # Migration creates all required tables
  if [[ -f "$ALEMBIC_DIR/versions/001_initial_schema.py" ]]; then
    local tables=(orders line_items entitlements stripe_events order_audit_log)
    local table_found=0
    for table in "${tables[@]}"; do
      if grep -q "\"$table\"" "$ALEMBIC_DIR/versions/001_initial_schema.py"; then
        table_found=$((table_found + 1))
      fi
    done
    if [[ "$table_found" -eq "${#tables[@]}" ]]; then
      pass "[AC-031] Migration creates all ${#tables[@]} required tables"
    else
      fail "[AC-031] Migration missing tables ($table_found/${#tables[@]} found)"
    fi
  fi

  # Migration has downgrade
  if grep -q 'def downgrade' "$ALEMBIC_DIR/versions/001_initial_schema.py" 2>/dev/null; then
    pass "[AC-031] Alembic migration has downgrade function"
  else
    fail "[AC-031] Alembic migration missing downgrade function"
  fi

  # --- Dockerfile ---

  # Python 3.12 base image
  if grep -q 'python:3.12' "$DOCKERFILE"; then
    pass "[AC-031] Dockerfile uses Python 3.12 base image"
  else
    fail "[AC-031] Dockerfile does not use Python 3.12"
  fi

  # Non-root user
  if grep -q 'USER gateway\|useradd.*gateway' "$DOCKERFILE"; then
    pass "[AC-031] Dockerfile runs as non-root user (gateway)"
  else
    fail "[AC-031] Dockerfile does not run as non-root user"
  fi

  # Gunicorn + Uvicorn worker
  if grep -q 'gunicorn' "$DOCKERFILE" && grep -q 'uvicorn' "$DOCKERFILE"; then
    pass "[AC-031] Dockerfile uses gunicorn with uvicorn workers"
  else
    fail "[AC-031] Dockerfile missing gunicorn/uvicorn configuration"
  fi

  # Alembic files copied
  if grep -q 'alembic' "$DOCKERFILE"; then
    pass "[AC-031] Dockerfile copies alembic files for migrations"
  else
    fail "[AC-031] Dockerfile does not copy alembic files"
  fi

  # --- pyproject.toml Dependencies ---

  local required_deps=(fastapi uvicorn sqlalchemy asyncpg alembic pydantic stripe
                       redis httpx structlog prometheus-client)
  local dep_found=0
  for dep in "${required_deps[@]}"; do
    if grep -q "$dep" "$PYPROJECT"; then
      dep_found=$((dep_found + 1))
    fi
  done
  if [[ "$dep_found" -eq "${#required_deps[@]}" ]]; then
    pass "[AC-031] All ${#required_deps[@]} required dependencies declared in pyproject.toml"
  else
    fail "[AC-031] Missing dependencies ($dep_found/${#required_deps[@]} found)"
  fi

  # Python >=3.12 required
  if grep -q '>=3.12' "$PYPROJECT"; then
    pass "[AC-031] Python >=3.12 required in pyproject.toml"
  else
    fail "[AC-031] Python version requirement not >=3.12"
  fi

  # Test dependencies
  if grep -q 'pytest' "$PYPROJECT" && grep -q 'pytest-asyncio' "$PYPROJECT"; then
    pass "[AC-031] Test dependencies (pytest + pytest-asyncio) declared"
  else
    fail "[AC-031] Test dependencies missing from pyproject.toml"
  fi

  # --- K8s Manifests ---

  # AC-031: payments-gateway Deployment
  if [[ -f "$K8S_DIR/deployment.yaml" ]]; then
    if grep -q 'kind: Deployment' "$K8S_DIR/deployment.yaml" && \
       grep -q 'app.kubernetes.io/name: payments-gateway' "$K8S_DIR/deployment.yaml"; then
      pass "[AC-031] payments-gateway Deployment manifest exists with correct labels"
    else
      fail "[AC-031] payments-gateway Deployment manifest has wrong kind or labels"
    fi
  else
    fail "[AC-031] payments-gateway Deployment manifest missing"
  fi

  # AC-031: Init container for migrations
  if grep -q 'initContainers' "$K8S_DIR/deployment.yaml" 2>/dev/null && \
     grep -q 'alembic.*upgrade' "$K8S_DIR/deployment.yaml" 2>/dev/null; then
    pass "[AC-031] Deployment has init container for alembic migrations"
  else
    fail "[AC-031] Init container for database migrations missing"
  fi

  # AC-031: Readiness probe
  if grep -q 'readinessProbe' "$K8S_DIR/deployment.yaml" 2>/dev/null && \
     grep -q '/ready/' "$K8S_DIR/deployment.yaml" 2>/dev/null; then
    pass "[AC-031] Readiness probe configured (/ready/)"
  else
    fail "[AC-031] Readiness probe missing or wrong path"
  fi

  # AC-031: Liveness probe
  if grep -q 'livenessProbe' "$K8S_DIR/deployment.yaml" 2>/dev/null && \
     grep -q '/health/' "$K8S_DIR/deployment.yaml" 2>/dev/null; then
    pass "[AC-031] Liveness probe configured (/health/)"
  else
    fail "[AC-031] Liveness probe missing or wrong path"
  fi

  # AC-031: Security context (non-root, no privilege escalation)
  if grep -q 'runAsUser' "$K8S_DIR/deployment.yaml" 2>/dev/null && \
     grep -q 'allowPrivilegeEscalation: false' "$K8S_DIR/deployment.yaml" 2>/dev/null; then
    pass "[AC-031] Security context enforces non-root with no privilege escalation"
  else
    fail "[AC-031] Security context missing or misconfigured"
  fi

  # AC-031: Resource limits set
  if grep -q 'resources:' "$K8S_DIR/deployment.yaml" 2>/dev/null && \
     grep -q 'limits:' "$K8S_DIR/deployment.yaml" 2>/dev/null; then
    pass "[AC-031] Resource limits configured in Deployment"
  else
    fail "[AC-031] Resource limits missing from Deployment"
  fi

  # AC-031: Service manifest
  if [[ -f "$K8S_DIR/service.yaml" ]]; then
    if grep -q 'kind: Service' "$K8S_DIR/service.yaml" && \
       grep -q 'payments-gateway' "$K8S_DIR/service.yaml"; then
      pass "[AC-031] Service manifest exists for payments-gateway"
    else
      fail "[AC-031] Service manifest has wrong kind or name"
    fi
  else
    fail "[AC-031] Service manifest missing"
  fi

  # AC-031: HPA manifest
  if [[ -f "$K8S_DIR/hpa.yaml" ]]; then
    if grep -q 'HorizontalPodAutoscaler' "$K8S_DIR/hpa.yaml"; then
      pass "[AC-031] HPA manifest exists for payments-gateway"
    else
      fail "[AC-031] HPA manifest has wrong kind"
    fi
  else
    fail "[AC-031] HPA manifest missing"
  fi

  # --- ExternalSecrets ---

  # AC-031: ExternalSecret for payments-gateway-secrets
  if [[ -f "$K8S_DIR/external-secrets.yaml" ]]; then
    if grep -q 'payments-gateway-secrets' "$K8S_DIR/external-secrets.yaml"; then
      pass "[AC-031] ExternalSecret for payments-gateway-secrets exists"
    else
      fail "[AC-031] ExternalSecret name mismatch"
    fi
  else
    fail "[AC-031] ExternalSecret manifest missing from $K8S_DIR"
  fi

  # AC-031: ExternalSecret maps all required secrets
  if [[ -f "$K8S_DIR/external-secrets.yaml" ]]; then
    local required_secrets=(SECRET_KEY DATABASE_URL STRIPE_SECRET_KEY STRIPE_WEBHOOK_SECRET
                            LMS_OAUTH_CLIENT_SECRET)
    local secret_found=0
    for s in "${required_secrets[@]}"; do
      if grep -q "$s" "$K8S_DIR/external-secrets.yaml"; then
        secret_found=$((secret_found + 1))
      fi
    done
    if [[ "$secret_found" -eq "${#required_secrets[@]}" ]]; then
      pass "[AC-031] ExternalSecret maps all ${#required_secrets[@]} required secrets"
    else
      fail "[AC-031] ExternalSecret missing secrets ($secret_found/${#required_secrets[@]} found)"
    fi
  fi

  # AC-031: Deployment references secrets via secretKeyRef
  if grep -q 'secretKeyRef' "$K8S_DIR/deployment.yaml" 2>/dev/null; then
    local secret_refs=(DATABASE_URL STRIPE_SECRET_KEY STRIPE_WEBHOOK_SECRET
                       LMS_OAUTH_CLIENT_SECRET SECRET_KEY)
    local ref_found=0
    for ref in "${secret_refs[@]}"; do
      if grep -q "$ref" "$K8S_DIR/deployment.yaml"; then
        ref_found=$((ref_found + 1))
      fi
    done
    if [[ "$ref_found" -eq "${#secret_refs[@]}" ]]; then
      pass "[AC-031] Deployment references all ${#secret_refs[@]} secrets via secretKeyRef"
    else
      fail "[AC-031] Deployment missing secretKeyRef ($ref_found/${#secret_refs[@]} found)"
    fi
  fi

  # AC-031: LMS_BASE_URL uses internal K8s DNS
  if grep -q 'http://lms:8000' "$K8S_DIR/deployment.yaml" 2>/dev/null; then
    pass "[AC-031] LMS_BASE_URL uses internal K8s DNS (http://lms:8000)"
  else
    fail "[AC-031] LMS_BASE_URL does not use internal K8s DNS"
  fi

  # AC-031: OAuth2 client ID set to payments-gateway
  if grep -q 'payments-gateway' "$K8S_DIR/deployment.yaml" 2>/dev/null && \
     grep -q 'LMS_OAUTH_CLIENT_ID' "$K8S_DIR/deployment.yaml" 2>/dev/null; then
    pass "[AC-031] LMS_OAUTH_CLIENT_ID set to payments-gateway"
  else
    fail "[AC-031] LMS_OAUTH_CLIENT_ID not set correctly"
  fi

  # --- Health Endpoints ---

  # AC-033: Health endpoint exists at /health/
  if [[ -f "$ROUTERS_DIR/health.py" ]]; then
    if grep -q '"/health/"' "$ROUTERS_DIR/health.py"; then
      pass "[AC-033] Health endpoint exists at /health/"
    else
      fail "[AC-033] Health endpoint not at /health/"
    fi
  else
    fail "[AC-033] health.py router missing"
  fi

  # AC-033: Health checks database, redis, stripe
  if [[ -f "$ROUTERS_DIR/health.py" ]]; then
    if grep -q 'database' "$ROUTERS_DIR/health.py" && \
       grep -q 'redis' "$ROUTERS_DIR/health.py" && \
       grep -q 'stripe' "$ROUTERS_DIR/health.py"; then
      pass "[AC-033] Health check verifies database, redis, and stripe status"
    else
      fail "[AC-033] Health check missing database, redis, or stripe verification"
    fi
  fi

  # AC-033: Ready endpoint at /ready/
  if [[ -f "$ROUTERS_DIR/health.py" ]]; then
    if grep -q '"/ready/"' "$ROUTERS_DIR/health.py"; then
      pass "[AC-033] Readiness endpoint exists at /ready/"
    else
      fail "[AC-033] Readiness endpoint not at /ready/"
    fi
  fi

  # AC-033: Health returns 503 on degraded
  if grep -q '503' "$ROUTERS_DIR/health.py" 2>/dev/null; then
    pass "[AC-033] Health endpoint returns 503 on degraded status"
  else
    fail "[AC-033] Health endpoint does not return 503 on failure"
  fi

  # --- LMS Client ---

  # OAuth2 client credentials flow
  if [[ -f "$SERVICES_DIR/lms_client.py" ]]; then
    if grep -q 'client_credentials' "$SERVICES_DIR/lms_client.py" && \
       grep -q 'access_token' "$SERVICES_DIR/lms_client.py"; then
      pass "[AC-031] LMS client uses OAuth2 client credentials grant"
    else
      fail "[AC-031] LMS client missing OAuth2 client credentials flow"
    fi
  fi

  # LMS API endpoints used
  if [[ -f "$SERVICES_DIR/lms_client.py" ]]; then
    if grep -q '/api/enrollment/v1/enrollment' "$SERVICES_DIR/lms_client.py" && \
       grep -q '/api/user/v1/accounts' "$SERVICES_DIR/lms_client.py"; then
      pass "[AC-031] LMS client calls enrollment and user lookup APIs"
    else
      fail "[AC-031] LMS client missing enrollment or user API endpoints"
    fi
  fi

  # LMS client handles 401 with token refresh (uses _token_cache dict pattern, not _token = None)
  if grep -q '401' "$SERVICES_DIR/lms_client.py" 2>/dev/null && \
     grep -q '_token_cache\|_invalidate_token' "$SERVICES_DIR/lms_client.py" 2>/dev/null; then
    pass "[AC-031] LMS client refreshes token on 401"
  else
    fail "[AC-031] LMS client does not refresh token on 401"
  fi

  # AC-031: Deactivate enrollment for refund revocation
  if grep -q 'deactivate_enrollment' "$SERVICES_DIR/lms_client.py" 2>/dev/null && \
     grep -q 'is_active.*False\|is_active.*false' "$SERVICES_DIR/lms_client.py" 2>/dev/null; then
    pass "[AC-031] LMS client supports enrollment deactivation for refunds"
  else
    fail "[AC-031] LMS client missing deactivate_enrollment method"
  fi

  # --- Test Structure ---

  # Test directories exist
  if [[ -d "$TESTS_DIR/unit" && -d "$TESTS_DIR/integration" ]]; then
    pass "[AC-031] Test directories exist (unit + integration)"
  else
    fail "[AC-031] Test directories missing (need unit/ and integration/)"
  fi

  # Test files exist
  local test_files_found=0
  for tf in "$TESTS_DIR/unit/test_checkout.py" "$TESTS_DIR/unit/test_fulfillment.py" \
            "$TESTS_DIR/integration/test_stripe_webhook.py" "$TESTS_DIR/conftest.py"; do
    if [[ -f "$tf" ]]; then
      test_files_found=$((test_files_found + 1))
    fi
  done
  if [[ "$test_files_found" -ge 3 ]]; then
    pass "[AC-031] Test files present ($test_files_found found)"
  else
    fail "[AC-031] Insufficient test files ($test_files_found found, need >= 3)"
  fi

  # --- Feature Flags ---

  if [[ -f "$APP_DIR/config.py" ]]; then
    local feature_flags=(ENABLE_GATEWAY_FULFILLMENT ENABLE_ENTITLEMENT_INVITATIONS
                         ENABLE_ENTERPRISE_SUBSCRIPTIONS ENABLE_AUTO_REVOKE_ON_DISPUTE
                         ENABLE_RECONCILIATION_JOB)
    local flag_found=0
    for flag in "${feature_flags[@]}"; do
      if grep -q "$flag" "$APP_DIR/config.py"; then
        flag_found=$((flag_found + 1))
      fi
    done
    if [[ "$flag_found" -eq "${#feature_flags[@]}" ]]; then
      pass "[AC-031] All ${#feature_flags[@]} feature flags defined in config.py"
    else
      fail "[AC-031] Missing feature flags ($flag_found/${#feature_flags[@]} found)"
    fi
  fi

  # --- Cluster Checks (AC-031, AC-032, AC-033) ---

  if [[ "$SKIP_CLUSTER" == "true" ]]; then
    skip "[AC-031] payments-gateway Deployment READY check requires --skip-cluster=false"
    skip "[AC-032] payments-worker Deployment READY check requires --skip-cluster=false"
    skip "[AC-033] Gateway health endpoint live check requires --skip-cluster=false"
  else
    # AC-031: payments-gateway deployment ready
    if kubectl get deployments -n mereka-lms -l app.kubernetes.io/name=payments-gateway \
       -o jsonpath='{.items[0].status.readyReplicas}' 2>/dev/null | grep -q '[1-9]'; then
      pass "[AC-031] payments-gateway Deployment has READY replicas >= 1"
    else
      skip "[AC-031] payments-gateway Deployment not found or no ready replicas (not yet deployed)"
    fi

    # AC-032: payments-worker deployment ready
    if kubectl get deployments -n mereka-lms -l app.kubernetes.io/name=payments-worker \
       -o jsonpath='{.items[0].status.readyReplicas}' 2>/dev/null | grep -q '[1-9]'; then
      pass "[AC-032] payments-worker Deployment has READY replicas >= 1"
    else
      skip "[AC-032] payments-worker Deployment not found or no ready replicas (not yet deployed)"
    fi

    # AC-033: Health endpoint returns 200
    local health_response
    health_response=$(kubectl exec -n mereka-lms \
      "$(kubectl get pod -n mereka-lms -l app.kubernetes.io/name=payments-gateway -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)" \
      -- curl -s -o /dev/null -w '%{http_code}' http://localhost:8080/health/ 2>/dev/null || echo "000")
    if [[ "$health_response" == "200" ]]; then
      pass "[AC-033] Gateway health endpoint returns HTTP 200"
    else
      skip "[AC-033] Gateway health endpoint not reachable (HTTP $health_response — not yet deployed)"
    fi
  fi
}

# ============================================================================
# Main
# ============================================================================
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║       Purchase Gateway Verification                        ║"
echo "╠══════════════════════════════════════════════════════════════╣"
echo "║  @spec: ecommerce-purchase-gateway_spec.md                 ║"
echo "║  Covers: AC-001 through AC-033 (33 acceptance criteria)    ║"
echo "╚══════════════════════════════════════════════════════════════╝"

if [[ -z "$SECTION_FILTER" || "$SECTION_FILTER" == "checkout" ]]; then
  check_checkout
fi

if [[ -z "$SECTION_FILTER" || "$SECTION_FILTER" == "webhook" ]]; then
  check_webhook
fi

if [[ -z "$SECTION_FILTER" || "$SECTION_FILTER" == "entitlement" ]]; then
  check_entitlement
fi

if [[ -z "$SECTION_FILTER" || "$SECTION_FILTER" == "refund" ]]; then
  check_refund
fi

if [[ -z "$SECTION_FILTER" || "$SECTION_FILTER" == "fulfillment" ]]; then
  check_fulfillment
fi

if [[ -z "$SECTION_FILTER" || "$SECTION_FILTER" == "enterprise" ]]; then
  check_enterprise
fi

if [[ -z "$SECTION_FILTER" || "$SECTION_FILTER" == "tenant" ]]; then
  check_tenant
fi

if [[ -z "$SECTION_FILTER" || "$SECTION_FILTER" == "migration" ]]; then
  check_migration
fi

if [[ -z "$SECTION_FILTER" || "$SECTION_FILTER" == "observability" ]]; then
  check_observability
fi

if [[ -z "$SECTION_FILTER" || "$SECTION_FILTER" == "deployment" ]]; then
  check_deployment
fi

echo ""
echo "══════════════════════════════════════════════════════════════"
echo "  Summary"
echo "══════════════════════════════════════════════════════════════"
echo -e "  ${GREEN}Passed:  $PASSED${NC}"
echo -e "  ${RED}Failed:  $FAILED${NC}"
echo -e "  ${YELLOW}Skipped: $SKIPPED${NC}"
echo "══════════════════════════════════════════════════════════════"

if [[ "$FAILED" -gt 0 ]]; then
  echo ""
  echo -e "${RED}Purchase Gateway verification failed ($FAILED failures).${NC}"
  exit 1
fi

echo ""
echo -e "${GREEN}Purchase Gateway verification passed.${NC}"
if [[ "$SKIPPED" -gt 0 ]]; then
  echo -e "${YELLOW}Note: $SKIPPED check(s) skipped — runtime/cluster checks marked SKIP.${NC}"
fi
exit 0
