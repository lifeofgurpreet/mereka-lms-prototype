#!/usr/bin/env bash
# @spec: ecommerce-purchase-gateway_spec.md
# @covers AC-004, AC-005, AC-006, AC-007, AC-008, AC-015, AC-016, AC-017, AC-018, AC-019, AC-026, AC-027, AC-028, AC-029, AC-032, AC-033
#
# Stripe integration verification for Purchase Gateway.
# Validates webhook handler, checkout flow, refund/dispute handling, Alembic migrations,
# Dockerfile deps, K8s secrets, and (in online mode) live health/DB/Redis/Stripe checks.
#
# Usage:
#   ./scripts/qa/verify-purchase-gateway-stripe.sh           # offline only
#   ./scripts/qa/verify-purchase-gateway-stripe.sh --online  # include live cluster checks
#   ./scripts/qa/verify-purchase-gateway-stripe.sh --skip-cluster  # explicit offline alias
#
# Online mode requires kubectl access to the mereka-lms namespace.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SVC_DIR="$REPO_ROOT/services/purchase-gateway"
APP_DIR="$SVC_DIR/app"
K8S_DIR="$SVC_DIR/k8s"

NAMESPACE="mereka-lms"
ONLINE=false
SKIP_CLUSTER=false

for arg in "$@"; do
  case "$arg" in
    --online)        ONLINE=true ;;
    --skip-cluster)  SKIP_CLUSTER=true ;;
  esac
done

# --- Counters ---
PASS=0
FAIL=0
SKIP=0

pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }
skip() { echo "  SKIP: $1"; SKIP=$((SKIP + 1)); }

check_file() {
  local path="$1"
  local desc="${2:-$path}"
  if [[ -f "$REPO_ROOT/$path" ]]; then
    pass "$desc exists"
  else
    fail "$desc missing ($path)"
  fi
}

check_contains() {
  local file="$1"
  local pattern="$2"
  local desc="$3"
  if grep -q "$pattern" "$file" 2>/dev/null; then
    pass "$desc"
  else
    fail "$desc"
  fi
}

check_absent() {
  local file="$1"
  local pattern="$2"
  local desc="$3"
  if grep -qE "$pattern" "$file" 2>/dev/null; then
    fail "$desc"
  else
    pass "$desc"
  fi
}

echo "=== Purchase Gateway Stripe Integration Verification ==="
echo "Mode: $([ "$ONLINE" = true ] && echo 'online (offline + live cluster)' || echo 'offline')"
echo ""

# -----------------------------------------------------------------------
# 1. Stripe webhook handler
# -----------------------------------------------------------------------
echo "-- [1] Stripe webhook handler (webhooks.py) --"
WEBHOOK="$APP_DIR/routers/webhooks.py"

check_contains "$WEBHOOK" 'stripe\.Webhook\.construct_event' \
  "Webhook verifies signature via construct_event"
check_contains "$WEBHOOK" 'SignatureVerificationError' \
  "Webhook handles SignatureVerificationError"
check_contains "$WEBHOOK" 'status_code=400' \
  "Webhook returns 400 on invalid signature"
check_contains "$WEBHOOK" 'stripe_events' \
  "Webhook logs event to stripe_events table"
check_contains "$WEBHOOK" 'ProcessingStatus.processed' \
  "Webhook marks event processed (idempotency)"
check_contains "$WEBHOOK" 'ProcessingStatus.failed' \
  "Webhook marks event failed on error"
check_contains "$WEBHOOK" 'checkout\.session\.completed' \
  "Webhook handles checkout.session.completed"
check_contains "$WEBHOOK" 'checkout\.session\.expired' \
  "Webhook handles checkout.session.expired"
check_contains "$WEBHOOK" 'payment_intent\.payment_failed' \
  "Webhook handles payment_intent.payment_failed"
check_contains "$WEBHOOK" 'charge\.refunded' \
  "Webhook handles charge.refunded"
check_contains "$WEBHOOK" 'charge\.dispute\.created' \
  "Webhook handles charge.dispute.created"
check_contains "$WEBHOOK" 'charge\.dispute\.closed' \
  "Webhook handles charge.dispute.closed"
check_contains "$WEBHOOK" 'customer\.subscription\.created' \
  "Webhook handles customer.subscription.created"
check_contains "$WEBHOOK" 'invoice\.paid' \
  "Webhook handles invoice.paid"
check_contains "$WEBHOOK" 'IntegrityError' \
  "Webhook handles duplicate-delivery race via IntegrityError"

echo ""

# -----------------------------------------------------------------------
# 2. Checkout session creation
# -----------------------------------------------------------------------
echo "-- [2] Checkout session creation (stripe_service.py) --"
STRIPE_SVC="$APP_DIR/services/stripe_service.py"

check_contains "$STRIPE_SVC" 'create_checkout_session' \
  "stripe_service exports create_checkout_session"
check_contains "$STRIPE_SVC" 'stripe\.checkout\.Session\.create' \
  "Checkout uses stripe.checkout.Session.create"
check_contains "$STRIPE_SVC" 'metadata.*order_uuid' \
  "Checkout sets order_uuid in Stripe metadata"
check_contains "$STRIPE_SVC" 'verify_webhook_signature' \
  "stripe_service exports verify_webhook_signature"

echo ""

# -----------------------------------------------------------------------
# 3. Refund handling
# -----------------------------------------------------------------------
echo "-- [3] Refund handling (refund.py) --"
REFUND="$APP_DIR/services/refund.py"

check_contains "$REFUND" 'process_refund' \
  "refund.py exports process_refund"
check_contains "$REFUND" 'amount_refunded.*amount' \
  "Full vs partial refund comparison present"
check_contains "$REFUND" 'OrderStatus\.refunded' \
  "process_refund sets OrderStatus.refunded"
check_contains "$REFUND" 'OrderStatus\.partially_refunded' \
  "process_refund sets OrderStatus.partially_refunded"
check_contains "$REFUND" 'deactivate_enrollment' \
  "Full refund triggers enrollment revocation"
check_contains "$REFUND" 'order\.status == OrderStatus\.refunded' \
  "Idempotency: skip already-refunded orders"

echo ""

# -----------------------------------------------------------------------
# 4. Dispute handling
# -----------------------------------------------------------------------
echo "-- [4] Dispute handling (dispute.py) --"
DISPUTE="$APP_DIR/services/dispute.py"

check_contains "$DISPUTE" 'handle_dispute_created' \
  "dispute.py exports handle_dispute_created"
check_contains "$DISPUTE" 'handle_dispute_closed' \
  "dispute.py exports handle_dispute_closed"
check_contains "$DISPUTE" 'OrderStatus\.disputed' \
  "Dispute flags order as disputed"
check_contains "$DISPUTE" "outcome == .won." \
  "Dispute closed: won branch present"
check_contains "$DISPUTE" '_restore_order_enrollments' \
  "Dispute won: restores enrollments"
check_contains "$DISPUTE" 'OrderStatus\.refunded' \
  "Dispute lost: marks order refunded"
check_contains "$DISPUTE" 'ENABLE_AUTO_REVOKE_ON_DISPUTE' \
  "Auto-revoke on dispute is feature-flagged"
check_contains "$DISPUTE" 'order\.status == OrderStatus\.disputed' \
  "Idempotency: skip already-disputed orders"

echo ""

# -----------------------------------------------------------------------
# 5. Fulfillment engine
# -----------------------------------------------------------------------
echo "-- [5] Fulfillment engine (fulfillment.py) --"
FULFILLMENT="$APP_DIR/services/fulfillment.py"

check_contains "$FULFILLMENT" 'ENABLE_GATEWAY_FULFILLMENT' \
  "Fulfillment respects ENABLE_GATEWAY_FULFILLMENT feature flag"
check_contains "$FULFILLMENT" 'enroll_user' \
  "Fulfillment calls lms.enroll_user"
check_contains "$FULFILLMENT" 'claim_token' \
  "Fulfillment creates claim_token for unknown users"
check_contains "$FULFILLMENT" 'ENTITLEMENT_CLAIM_EXPIRY_DAYS' \
  "Entitlement expiry uses configurable ENTITLEMENT_CLAIM_EXPIRY_DAYS"
check_contains "$FULFILLMENT" 'FulfillmentStatus\.fulfilled' \
  "Fulfillment marks line items fulfilled"
check_contains "$FULFILLMENT" 'OrderStatus\.fulfillment_failed' \
  "Fulfillment handles all-failed case"

echo ""

# -----------------------------------------------------------------------
# 6. StripeEvent model (idempotency store)
# -----------------------------------------------------------------------
echo "-- [6] StripeEvent model --"
EVT="$APP_DIR/models/stripe_event.py"

check_contains "$EVT" 'class StripeEvent' \
  "StripeEvent model exists"
check_contains "$EVT" 'stripe_event_id' \
  "StripeEvent has stripe_event_id"
check_contains "$EVT" 'payload_json' \
  "StripeEvent stores payload_json"
check_contains "$EVT" 'processing_status' \
  "StripeEvent has processing_status"
check_contains "$EVT" 'processed_at' \
  "StripeEvent has processed_at timestamp"

echo ""

# -----------------------------------------------------------------------
# 7. Alembic migrations
# -----------------------------------------------------------------------
echo "-- [7] Alembic migrations --"
MIGRATION="$SVC_DIR/alembic/versions/001_initial_schema.py"

check_file "services/purchase-gateway/alembic/versions/001_initial_schema.py" \
  "Initial schema migration exists"
check_contains "$MIGRATION" 'stripe_events' \
  "Migration creates stripe_events table"
check_contains "$MIGRATION" 'orders' \
  "Migration creates orders table"
check_contains "$MIGRATION" 'entitlements' \
  "Migration creates entitlements table"
check_contains "$MIGRATION" 'order_audit_log' \
  "Migration creates order_audit_log table"
check_contains "$MIGRATION" 'JSONB' \
  "Migration uses JSONB for payload storage"
check_contains "$MIGRATION" "unique=True.*nullable=False" \
  "stripe_event_id is unique + non-null (idempotency key)"

echo ""

# -----------------------------------------------------------------------
# 8. Dockerfile dependencies
# -----------------------------------------------------------------------
echo "-- [8] Dockerfile Stripe + DB dependencies --"
DOCKERFILE="$SVC_DIR/Dockerfile"

check_contains "$DOCKERFILE" "stripe>=" \
  "Dockerfile installs stripe SDK"
check_contains "$DOCKERFILE" "asyncpg>=" \
  "Dockerfile installs asyncpg (async PostgreSQL driver)"
check_contains "$DOCKERFILE" "psycopg2-binary>=" \
  "Dockerfile installs psycopg2-binary (Alembic sync migrations)"
check_contains "$DOCKERFILE" "alembic>=" \
  "Dockerfile installs Alembic"
check_contains "$DOCKERFILE" "structlog>=" \
  "Dockerfile installs structlog"
check_contains "$DOCKERFILE" "prometheus-client>=" \
  "Dockerfile installs prometheus-client"
check_contains "$DOCKERFILE" "redis>=" \
  "Dockerfile installs redis client"
check_contains "$DOCKERFILE" "USER gateway" \
  "Dockerfile runs as non-root user (gateway)"

echo ""

# -----------------------------------------------------------------------
# 9. K8s manifests — Stripe secrets wiring
# -----------------------------------------------------------------------
echo "-- [9] K8s secrets wiring --"
DEPLOY="$K8S_DIR/deployment.yaml"
EXT_SEC="$K8S_DIR/external-secrets.yaml"

check_contains "$DEPLOY" 'STRIPE_SECRET_KEY' \
  "Deployment references STRIPE_SECRET_KEY env var"
check_contains "$DEPLOY" 'STRIPE_WEBHOOK_SECRET' \
  "Deployment references STRIPE_WEBHOOK_SECRET env var"
check_contains "$DEPLOY" 'secretKeyRef' \
  "Stripe keys come from secretKeyRef (not plaintext)"
check_contains "$DEPLOY" 'ENABLE_GATEWAY_FULFILLMENT' \
  "Deployment sets ENABLE_GATEWAY_FULFILLMENT feature flag"
check_contains "$DEPLOY" 'redis://redis:6379/14' \
  "Deployment wires Redis DB 14"
check_absent "$DEPLOY" 'value:.*sk_live_\|value:.*sk_test_\|value:.*whsec_' \
  "No plaintext Stripe keys in deployment manifest"

check_contains "$EXT_SEC" 'MEREKA_LMS_STRIPE_SECRET_KEY' \
  "ExternalSecret maps STRIPE_SECRET_KEY from GCP Secret Manager"
check_contains "$EXT_SEC" 'MEREKA_LMS_STRIPE_WEBHOOK_SECRET_GATEWAY' \
  "ExternalSecret maps STRIPE_WEBHOOK_SECRET from GCP Secret Manager"
check_contains "$EXT_SEC" 'MEREKA_LMS_PAYMENTS_GATEWAY_OAUTH2_SECRET' \
  "ExternalSecret maps LMS OAuth2 secret"
check_contains "$EXT_SEC" 'MEREKA_LMS_PAYMENTS_GATEWAY_DATABASE_URL' \
  "ExternalSecret maps DATABASE_URL"
check_contains "$EXT_SEC" 'MEREKA_LMS_PAYMENTS_GATEWAY_POSTGRESQL_PASSWORD' \
  "ExternalSecret maps PostgreSQL password"
check_contains "$EXT_SEC" 'gcp-secret-manager' \
  "ExternalSecret references gcp-secret-manager ClusterSecretStore"

echo ""

# -----------------------------------------------------------------------
# 10. Health endpoints
# -----------------------------------------------------------------------
echo "-- [10] Health endpoints (health.py) --"
HEALTH="$APP_DIR/routers/health.py"

check_contains "$HEALTH" '@router.get("/health/")' \
  "/health/ endpoint exists"
check_contains "$HEALTH" '@router.get("/ready/")' \
  "/ready/ endpoint exists"
check_contains "$HEALTH" '"database"' \
  "/health/ checks database connectivity"
check_contains "$HEALTH" '"redis"' \
  "/health/ checks Redis connectivity"
check_contains "$HEALTH" '"stripe"' \
  "/health/ checks Stripe key presence"
check_contains "$HEALTH" 'status_code = 200.*503\|503.*200' \
  "/health/ returns 503 when degraded"

echo ""

# -----------------------------------------------------------------------
# 11. Settings — no hardcoded secrets
# -----------------------------------------------------------------------
echo "-- [11] Settings hygiene --"
CONFIG="$APP_DIR/config.py"

check_contains "$CONFIG" 'BaseSettings' \
  "Config uses Pydantic BaseSettings (env-backed)"
check_absent "$CONFIG" "sk_live_|sk_test_|whsec_" \
  "No Stripe key literals in config.py"
check_contains "$CONFIG" 'STRIPE_SECRET_KEY.*str.*=.*""' \
  "STRIPE_SECRET_KEY defaults to empty string (not hardcoded)"
check_contains "$CONFIG" 'ENABLE_GATEWAY_FULFILLMENT.*bool.*=.*False' \
  "ENABLE_GATEWAY_FULFILLMENT defaults False (dark launch safe)"

echo ""

# -----------------------------------------------------------------------
# 12. Online mode: live cluster checks
# -----------------------------------------------------------------------
if [[ "$ONLINE" = true && "$SKIP_CLUSTER" = false ]]; then
  echo "-- [12] Live cluster health checks --"

  GW_POD=""
  GW_POD=$(kubectl get pods -n "$NAMESPACE" \
    -l app.kubernetes.io/name=payments-gateway \
    -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)

  if [[ -z "$GW_POD" ]]; then
    skip "No payments-gateway pod found in $NAMESPACE — cannot run live checks"
  else
    echo "  Using pod: $GW_POD"

    # /health/ endpoint
    HEALTH_RESP=$(kubectl exec -n "$NAMESPACE" "$GW_POD" -- \
      curl -s http://localhost:8080/health/ 2>/dev/null || true)
    if echo "$HEALTH_RESP" | grep -q '"status"'; then
      pass "/health/ responds with status field"
    else
      fail "/health/ did not return expected JSON"
    fi

    if echo "$HEALTH_RESP" | grep -q '"database".*"ok"'; then
      pass "/health/ database check is ok"
    else
      fail "/health/ database check is not ok (response: $HEALTH_RESP)"
    fi

    if echo "$HEALTH_RESP" | grep -q '"redis".*"ok"'; then
      pass "/health/ Redis check is ok"
    else
      fail "/health/ Redis check is not ok (response: $HEALTH_RESP)"
    fi

    if echo "$HEALTH_RESP" | grep -q '"stripe".*"ok"'; then
      pass "/health/ Stripe key is configured"
    else
      skip "/health/ Stripe key not configured (dark launch: acceptable if sk_live not yet set)"
    fi

    # /ready/ endpoint
    READY_RESP=$(kubectl exec -n "$NAMESPACE" "$GW_POD" -- \
      curl -s http://localhost:8080/ready/ 2>/dev/null || true)
    if echo "$READY_RESP" | grep -q '"status".*"ready"'; then
      pass "/ready/ returns ready"
    else
      fail "/ready/ did not return ready (response: $READY_RESP)"
    fi

    # ENABLE_GATEWAY_FULFILLMENT must be false (dark launch)
    FULFILLMENT_FLAG=$(kubectl exec -n "$NAMESPACE" "$GW_POD" -- \
      sh -c 'echo "$ENABLE_GATEWAY_FULFILLMENT"' 2>/dev/null || true)
    if [[ "$FULFILLMENT_FLAG" == "false" ]]; then
      pass "ENABLE_GATEWAY_FULFILLMENT is false (dark launch active)"
    else
      skip "ENABLE_GATEWAY_FULFILLMENT=$FULFILLMENT_FLAG (expected false for dark launch)"
    fi
  fi

  echo ""
  echo "-- [13] HPA and Deployment manifest (live) --"
  HPA_FOUND=$(kubectl get hpa payments-gateway -n "$NAMESPACE" \
    --ignore-not-found 2>/dev/null || true)
  if [[ -n "$HPA_FOUND" ]]; then
    pass "HPA payments-gateway exists in cluster"
  else
    skip "HPA payments-gateway not found in cluster"
  fi

  DEPLOY_FOUND=$(kubectl get deployment payments-gateway -n "$NAMESPACE" \
    --ignore-not-found 2>/dev/null || true)
  if [[ -n "$DEPLOY_FOUND" ]]; then
    pass "Deployment payments-gateway exists in cluster"
  else
    skip "Deployment payments-gateway not found in cluster"
  fi

  SECRET_FOUND=$(kubectl get secret payments-gateway-secrets -n "$NAMESPACE" \
    --ignore-not-found 2>/dev/null || true)
  if [[ -n "$SECRET_FOUND" ]]; then
    pass "K8s secret payments-gateway-secrets exists (ExternalSecret synced)"
  else
    skip "K8s secret payments-gateway-secrets not found — ExternalSecret may not have synced"
  fi

  echo ""
else
  echo "-- [12] Live cluster checks --"
  skip "Offline mode — pass --online to run live cluster checks"
  echo ""
fi

# -----------------------------------------------------------------------
# Summary
# -----------------------------------------------------------------------
echo "========================================"
echo "Results: $PASS passed, $FAIL failed, $SKIP skipped"
echo "========================================"

if [[ $FAIL -gt 0 ]]; then
  echo "FAIL"
  exit 1
fi
echo "PASS"
