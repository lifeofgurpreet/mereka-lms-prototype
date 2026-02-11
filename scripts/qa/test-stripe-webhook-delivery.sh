#!/usr/bin/env bash
# @covers AC-031
# @spec: ecommerce-purchase-gateway_spec.md
# Send a locally-signed Stripe webhook payload to ecommerce and confirm 200.
#
# Why this exists:
# - Stripe CLI is great, but agents may not be logged in.
# - This verifies the entire K8s wiring: Infisical -> GCP SM -> ESO -> openedx-secrets -> ecommerce env.
# - Does NOT print secret values.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../shared/config.sh"

ENVIRONMENT="${1:-prod}" # prod|dev

if [[ "$ENVIRONMENT" != "prod" && "$ENVIRONMENT" != "dev" ]]; then
  echo "Usage: $0 [prod|dev]" >&2
  exit 1
fi

BASE_DOMAIN="$LMS_DOMAIN"
KCTX_ARGS=()
if [[ "$ENVIRONMENT" == "dev" ]]; then
  BASE_DOMAIN="$DEV_LMS_DOMAIN"
  if [[ -n "${K8S_CONTEXT:-}" ]]; then
    KCTX_ARGS+=(--context "${K8S_CONTEXT}")
  else
    KCTX_ARGS+=(--context kind-dev)
  fi
fi

NAMESPACE="${K8S_NAMESPACE:-mereka-lms}"
URL="https://ecommerce.${BASE_DOMAIN}/api/v2/webhooks/stripe/"

# Pull the webhook secret from the running ecommerce container env.
# This avoids touching the underlying Secret directly and stays aligned with runtime.
SECRET="$(
  kubectl "${KCTX_ARGS[@]}" exec -n "${NAMESPACE}" deploy/ecommerce -- sh -lc 'printf "%s" "${STRIPE_WEBHOOK_SECRET-}"'
)"

if [[ -z "${SECRET}" ]]; then
  echo "STRIPE_WEBHOOK_SECRET is empty in ecommerce env. Fix secrets + restart ecommerce." >&2
  exit 1
fi

payload='{"id":"evt_test_signed","type":"payment_intent.succeeded","data":{"object":{"id":"pi_test_signed","amount":1234}}}'

sig_header="$(
  STRIPE_WEBHOOK_SECRET="$SECRET" STRIPE_WEBHOOK_PAYLOAD="$payload" python3 - <<'PY'
import hmac
import hashlib
import os
import time

secret = os.environ["STRIPE_WEBHOOK_SECRET"]
payload = os.environ["STRIPE_WEBHOOK_PAYLOAD"].encode("utf-8")
t = str(int(time.time()))
signed_payload = (t + ".").encode("utf-8") + payload
sig = hmac.new(secret.encode("utf-8"), signed_payload, hashlib.sha256).hexdigest()
print(f"t={t},v1={sig}")
PY
)"

code="$(curl -sS -o /dev/null -w "%{http_code}" \
  -X POST \
  -H "Content-Type: application/json" \
  -H "Stripe-Signature: ${sig_header}" \
  --data-binary "${payload}" \
  "${URL}" || echo "000")"

if [[ "$code" != "200" ]]; then
  echo "Webhook delivery failed: ${URL} (HTTP ${code})" >&2
  exit 1
fi

echo "OK: webhook delivery accepted (HTTP 200) -> ${URL}"
