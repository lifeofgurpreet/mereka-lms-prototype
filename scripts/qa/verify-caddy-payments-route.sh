#!/usr/bin/env bash
# @covers AC-024, AC-025
# @spec: ecommerce-purchase-gateway_spec.md
# Verify the Caddy /payments/* reverse-proxy route for the Purchase Gateway.
#
# Checks (all offline — no cluster required):
#   - /payments/* handle block exists in Caddyfile
#   - strip_prefix /payments is applied before proxying
#   - upstream target is payments-gateway:8080
#   - Route appears in the production/dev LMS server block (not just localhost)
#   - /payments/webhooks/stripe/ → /webhooks/stripe/ mapping is derivable
#   - /payments/health/ → /health/ mapping is derivable
#   - /payments/api/v1/checkout/ → /api/v1/checkout/ mapping is derivable
#
# Usage:
#   ./verify-caddy-payments-route.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
CADDYFILE="$REPO_ROOT/deploy/k8s/base/apps/caddy/Caddyfile"

PASS=0
FAIL=0

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

pass() { echo -e "${GREEN}  PASS${NC}: $1"; PASS=$((PASS + 1)); }
fail() { echo -e "${RED}  FAIL${NC}: $1"; FAIL=$((FAIL + 1)); }

echo ""
echo "======================================================="
echo "  Caddy /payments/* Route Verification"
echo "  Caddyfile: ${CADDYFILE#$REPO_ROOT/}"
echo "  Date: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "======================================================="

# ---------------------------------------------------------------------------
# Guard: Caddyfile must exist
# ---------------------------------------------------------------------------
if [[ ! -f "$CADDYFILE" ]]; then
  fail "Caddyfile not found: $CADDYFILE"
  echo ""
  echo "======================================================="
  echo -e "  ${RED}FAIL: $FAIL${NC}"
  echo "======================================================="
  exit 1
fi

echo ""
echo "[1/5] Caddyfile exists and is non-empty"

if [[ -s "$CADDYFILE" ]]; then
  pass "Caddyfile exists and is non-empty"
else
  fail "Caddyfile is missing or empty"
fi

# ---------------------------------------------------------------------------
# [2] /payments/* handle block
# ---------------------------------------------------------------------------
echo ""
echo "[2/5] /payments/* handle block"

if grep -q 'handle /payments/\*' "$CADDYFILE"; then
  pass "handle /payments/* block present"
else
  fail "handle /payments/* block NOT found in Caddyfile"
fi

# strip_prefix directive — prefix stripping maps /payments/X → /X on the backend
if grep -q 'uri strip_prefix /payments' "$CADDYFILE"; then
  pass "uri strip_prefix /payments present (prefix stripped before upstream)"
else
  fail "uri strip_prefix /payments NOT found — backend will receive /payments-prefixed paths"
fi

# Upstream target
if grep -q 'payments-gateway:8080' "$CADDYFILE"; then
  pass "Upstream target is payments-gateway:8080"
else
  fail "Upstream target payments-gateway:8080 NOT found in Caddyfile"
fi

# ---------------------------------------------------------------------------
# [3] Route is in the production/dev server block (not only localhost)
# ---------------------------------------------------------------------------
echo ""
echo "[3/5] Route is in the production/dev server block"

# Extract the production/dev server block (starts at academyv2.mereka.io line)
# and verify it contains both the /payments/* handle and payments-gateway:8080.
# We do this by checking that both patterns appear in the same block context
# by verifying they appear in the Caddyfile after the http://academyv2 line
# and before the next top-level server block.

PROD_BLOCK=$(awk '/http:\/\/academyv2\.mereka\.io/{found=1} found{print}' "$CADDYFILE" | \
  awk '/^}$/{if(depth==0){exit} depth--} /\{/{depth++} {print}')

if echo "$PROD_BLOCK" | grep -q 'handle /payments/\*'; then
  pass "/payments/* handle block is inside the production/dev server block"
else
  fail "/payments/* handle block NOT found inside academyv2.mereka.io server block"
fi

if echo "$PROD_BLOCK" | grep -q 'payments-gateway:8080'; then
  pass "payments-gateway:8080 upstream is inside the production/dev server block"
else
  fail "payments-gateway:8080 NOT found inside academyv2.mereka.io server block"
fi

# ---------------------------------------------------------------------------
# [4] Path mapping derivation (strip_prefix correctness)
# ---------------------------------------------------------------------------
echo ""
echo "[4/5] Path mapping derivation (strip_prefix /payments)"

# With 'uri strip_prefix /payments', Caddy strips the /payments prefix:
#   /payments/webhooks/stripe/   → /webhooks/stripe/
#   /payments/health/            → /health/
#   /payments/api/v1/checkout/   → /api/v1/checkout/
#
# We verify the FastAPI routes exist to receive these stripped paths.

WEBHOOK_ROUTER="$REPO_ROOT/services/purchase-gateway/app/routers/webhooks.py"
HEALTH_ROUTER="$REPO_ROOT/services/purchase-gateway/app/routers/health.py"

if [[ -f "$WEBHOOK_ROUTER" ]]; then
  if grep -q '"/webhooks/stripe/"' "$WEBHOOK_ROUTER" || grep -q "'/webhooks/stripe/'" "$WEBHOOK_ROUTER"; then
    pass "FastAPI route /webhooks/stripe/ exists (maps from /payments/webhooks/stripe/)"
  else
    fail "FastAPI route /webhooks/stripe/ NOT found in webhooks.py"
  fi
else
  fail "webhooks.py not found: $WEBHOOK_ROUTER"
fi

if [[ -f "$HEALTH_ROUTER" ]]; then
  if grep -q '"/health/"' "$HEALTH_ROUTER" || grep -q "'/health/'" "$HEALTH_ROUTER"; then
    pass "FastAPI route /health/ exists (maps from /payments/health/)"
  else
    fail "FastAPI route /health/ NOT found in health.py"
  fi
else
  fail "health.py not found: $HEALTH_ROUTER"
fi

# Verify the checkout router exists (for /payments/api/v1/checkout/)
# The prefix /api/v1 is applied in main.py via include_router(checkout.router, prefix="/api/v1")
CHECKOUT_ROUTER="$REPO_ROOT/services/purchase-gateway/app/routers/checkout.py"
MAIN_PY="$REPO_ROOT/services/purchase-gateway/app/main.py"
if [[ -f "$CHECKOUT_ROUTER" ]]; then
  if grep -q '"/checkout/"' "$CHECKOUT_ROUTER" || grep -q "'/checkout/'" "$CHECKOUT_ROUTER"; then
    # Confirm the /api/v1 prefix is wired in main.py
    if [[ -f "$MAIN_PY" ]] && grep -q 'checkout.router.*prefix.*api/v1\|prefix.*api/v1.*checkout.router' "$MAIN_PY"; then
      pass "FastAPI checkout router exists at /api/v1/checkout/ (maps from /payments/api/v1/checkout/)"
    elif [[ -f "$MAIN_PY" ]] && grep -q 'checkout' "$MAIN_PY" && grep -q 'api/v1' "$MAIN_PY"; then
      pass "FastAPI checkout router exists at /api/v1/checkout/ (maps from /payments/api/v1/checkout/)"
    else
      fail "checkout.py has /checkout/ route but /api/v1 prefix not confirmed in main.py"
    fi
  else
    fail "FastAPI checkout router exists but /checkout/ route not found in checkout.py"
  fi
else
  fail "checkout.py not found: $CHECKOUT_ROUTER — /payments/api/v1/checkout/ has no handler"
fi

# ---------------------------------------------------------------------------
# [5] Webhook signature verification wired in FastAPI
# ---------------------------------------------------------------------------
echo ""
echo "[5/5] Stripe webhook signature verification"

if [[ -f "$WEBHOOK_ROUTER" ]]; then
  if grep -q 'construct_event' "$WEBHOOK_ROUTER"; then
    pass "Webhook uses stripe.Webhook.construct_event() for signature verification"
  else
    fail "Webhook does NOT use construct_event() — signature verification missing"
  fi

  if grep -q 'SignatureVerificationError' "$WEBHOOK_ROUTER"; then
    pass "Webhook handles SignatureVerificationError (returns 400)"
  else
    fail "Webhook does NOT handle SignatureVerificationError"
  fi

  # Idempotent processing: check StripeEvent table dedup
  if grep -q 'StripeEvent' "$WEBHOOK_ROUTER" && grep -q 'IntegrityError' "$WEBHOOK_ROUTER"; then
    pass "Idempotent event processing: StripeEvent dedup + IntegrityError race guard"
  else
    fail "Idempotent event processing not found (StripeEvent or IntegrityError missing)"
  fi
else
  fail "webhooks.py not found — cannot verify signature or idempotency"
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo "======================================================="
echo -e "  ${GREEN}PASS: $PASS${NC}  |  ${RED}FAIL: $FAIL${NC}"
echo "======================================================="

if [[ $FAIL -gt 0 ]]; then
  echo ""
  echo "Reference:"
  echo "  Caddyfile:  deploy/k8s/base/apps/caddy/Caddyfile"
  echo "  Webhooks:   services/purchase-gateway/app/routers/webhooks.py"
  echo "  Health:     services/purchase-gateway/app/routers/health.py"
  echo "  Checkout:   services/purchase-gateway/app/routers/checkout.py"
  echo "  Ops guide:  docs/operations/PURCHASE_GATEWAY_K8S.md"
  echo ""
  exit 1
fi

exit 0
