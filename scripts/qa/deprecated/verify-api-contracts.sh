#!/usr/bin/env bash
# @covers AC-029, AC-032, AC-033
# @spec: ecommerce-purchase-gateway_spec.md
#
# Verify API contract documentation and OpenAPI configuration are present and complete.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PASS=0
FAIL=0
SKIP=0

pass() { echo "PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "FAIL: $1"; FAIL=$((FAIL + 1)); }
skip() { echo "SKIP: $1"; SKIP=$((SKIP + 1)); }

# --- 1. API_CONTRACTS.md exists ---
CONTRACTS_DOC="$REPO_ROOT/docs/architecture/API_CONTRACTS.md"
if [[ -f "$CONTRACTS_DOC" ]]; then
  pass "API_CONTRACTS.md exists"
else
  fail "API_CONTRACTS.md missing at docs/architecture/API_CONTRACTS.md"
fi

# --- 2. Required sections present ---
required_sections=(
  "Purchase Gateway"
  "HubSpot Webhook"
  "Breaking Change Policy"
  "Open edX Standard APIs"
  "Event Payload Contracts"
)

for section in "${required_sections[@]}"; do
  if grep -qF "$section" "$CONTRACTS_DOC" 2>/dev/null; then
    pass "Section present: $section"
  else
    fail "Section missing in API_CONTRACTS.md: $section"
  fi
done

# --- 3. Purchase Gateway has FastAPI app with OpenAPI configured ---
MAIN_PY="$REPO_ROOT/services/purchase-gateway/app/main.py"
if [[ -f "$MAIN_PY" ]]; then
  pass "Purchase Gateway main.py exists"
  if grep -q "FastAPI(" "$MAIN_PY"; then
    pass "FastAPI app instantiated in main.py"
  else
    fail "FastAPI() not found in main.py — OpenAPI generation may be broken"
  fi
  if grep -q "docs_url" "$MAIN_PY"; then
    pass "docs_url configured in FastAPI app"
  else
    fail "docs_url not configured in main.py"
  fi
else
  fail "services/purchase-gateway/app/main.py not found"
fi

# --- 4. All custom routers referenced in main.py ---
expected_routers=("health" "checkout" "subscriptions" "admin" "webhooks")
for r in "${expected_routers[@]}"; do
  if grep -q "include_router(${r}.router" "$MAIN_PY" 2>/dev/null; then
    pass "Router included: $r"
  else
    fail "Router not included in main.py: $r"
  fi
done

# --- 5. Admin auth implemented (X-API-Key) ---
AUTH_PY="$REPO_ROOT/services/purchase-gateway/app/auth.py"
if [[ -f "$AUTH_PY" ]]; then
  pass "auth.py exists"
  if grep -q "X-API-Key" "$AUTH_PY"; then
    pass "X-API-Key header auth implemented"
  else
    fail "X-API-Key not found in auth.py"
  fi
else
  fail "services/purchase-gateway/app/auth.py not found"
fi

# --- 6. Stripe webhook route exists ---
WEBHOOKS_PY="$REPO_ROOT/services/purchase-gateway/app/routers/webhooks.py"
if [[ -f "$WEBHOOKS_PY" ]]; then
  pass "webhooks.py exists"
  if grep -q 'POST.*webhooks/stripe' "$WEBHOOKS_PY" || grep -q '/webhooks/stripe/' "$WEBHOOKS_PY"; then
    pass "Stripe webhook endpoint defined"
  else
    fail "Stripe webhook route not found in webhooks.py"
  fi
  if grep -q "Stripe-Signature" "$WEBHOOKS_PY"; then
    pass "Stripe-Signature header verified in webhook handler"
  else
    fail "Stripe-Signature not verified in webhooks.py"
  fi
else
  fail "services/purchase-gateway/app/routers/webhooks.py not found"
fi

# --- 7. HubSpot webhook source exists ---
HUBSPOT_FUNC="$REPO_ROOT/services/hubspot-webhook/functions/index.js"
if [[ -f "$HUBSPOT_FUNC" ]]; then
  pass "HubSpot webhook source exists"
  if grep -q "createUser" "$HUBSPOT_FUNC"; then
    pass "HubSpot createUser endpoint defined"
  else
    fail "createUser endpoint not found in HubSpot webhook"
  fi
  if grep -q "x-hubspot-signature" "$HUBSPOT_FUNC"; then
    pass "HubSpot signature verification implemented"
  else
    fail "HubSpot signature verification not found"
  fi
else
  fail "services/hubspot-webhook/functions/index.js not found"
fi

# --- 8. Breaking change policy documented ---
if grep -q "30 days" "$CONTRACTS_DOC" 2>/dev/null; then
  pass "Breaking change deprecation period documented"
else
  fail "Breaking change deprecation period not documented in API_CONTRACTS.md"
fi

# --- 9. OpenAPI schema endpoint documented ---
if grep -q "/openapi.json" "$CONTRACTS_DOC" 2>/dev/null; then
  pass "OpenAPI schema endpoint documented"
else
  fail "/openapi.json endpoint not mentioned in API_CONTRACTS.md"
fi

# --- 10. Live cluster check (optional) ---
if kubectl get svc purchase-gateway -n mereka-lms &>/dev/null; then
  GATEWAY_IP=$(kubectl get svc purchase-gateway -n mereka-lms -o jsonpath='{.spec.clusterIP}' 2>/dev/null || true)
  if [[ -n "$GATEWAY_IP" ]]; then
    pass "Purchase Gateway service exists in cluster"
  else
    skip "Purchase Gateway service found but ClusterIP unavailable"
  fi
else
  skip "Cluster not accessible — skipping live purchase-gateway check"
fi

# --- Summary ---
echo ""
echo "Results: ${PASS} PASS / ${FAIL} FAIL / ${SKIP} SKIP"

if [[ "$FAIL" -gt 0 ]]; then
  exit 1
fi
exit 0
