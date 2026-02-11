#!/usr/bin/env bash
set -euo pipefail

# Verify Purchase Gateway has no hardcoded secrets and proper security patterns.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SVC_DIR="$REPO_ROOT/services/purchase-gateway"

PASS=0
FAIL=0

echo "=== Purchase Gateway Security Verification ==="
echo ""

# Check no hardcoded secrets in Python source
echo "-- No hardcoded secrets --"
SECRETS_FOUND=$(grep -rn \
  -e 'sk_live_' \
  -e 'sk_test_' \
  -e 'whsec_' \
  -e 'STRIPE_SECRET_KEY\s*=\s*"[^"]\{10,\}"' \
  "$SVC_DIR/app/" 2>/dev/null || true)

if [[ -z "$SECRETS_FOUND" ]]; then
  echo "  PASS: No hardcoded Stripe keys in app/"
  PASS=$((PASS + 1))
else
  echo "  FAIL: Hardcoded secrets found:"
  echo "$SECRETS_FOUND"
  FAIL=$((FAIL + 1))
fi

# Check settings come from env vars
echo ""
echo "-- Settings from environment --"
CONFIG="$SVC_DIR/app/config.py"
if grep -q 'BaseSettings' "$CONFIG"; then
  echo "  PASS: Config uses Pydantic BaseSettings (env-backed)"
  PASS=$((PASS + 1))
else
  echo "  FAIL: Config does not use BaseSettings"
  FAIL=$((FAIL + 1))
fi

for var in STRIPE_SECRET_KEY STRIPE_WEBHOOK_SECRET DATABASE_URL SECRET_KEY; do
  if grep -q "$var" "$CONFIG"; then
    echo "  PASS: $var declared in Settings"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $var not in Settings"
    FAIL=$((FAIL + 1))
  fi
done

# Check webhook signature verification
echo ""
echo "-- Stripe webhook signature verification --"
WEBHOOK="$SVC_DIR/app/routers/webhooks.py"
if grep -q 'construct_event' "$WEBHOOK"; then
  echo "  PASS: Webhook uses stripe.Webhook.construct_event()"
  PASS=$((PASS + 1))
else
  echo "  FAIL: Webhook does not verify signatures"
  FAIL=$((FAIL + 1))
fi

if grep -q 'SignatureVerificationError' "$WEBHOOK"; then
  echo "  PASS: Webhook handles SignatureVerificationError"
  PASS=$((PASS + 1))
else
  echo "  FAIL: Webhook does not handle SignatureVerificationError"
  FAIL=$((FAIL + 1))
fi

if grep -q '400' "$WEBHOOK"; then
  echo "  PASS: Webhook returns 400 on invalid signature"
  PASS=$((PASS + 1))
else
  echo "  FAIL: Webhook does not return 400 on invalid signature"
  FAIL=$((FAIL + 1))
fi

# Check Dockerfile runs as non-root
echo ""
echo "-- Container security --"
DOCKERFILE="$SVC_DIR/Dockerfile"
if grep -q 'USER gateway' "$DOCKERFILE" || grep -q 'USER [^r]' "$DOCKERFILE"; then
  echo "  PASS: Dockerfile runs as non-root user"
  PASS=$((PASS + 1))
else
  echo "  FAIL: Dockerfile may run as root"
  FAIL=$((FAIL + 1))
fi

# Check K8s deployment uses securityContext
echo ""
echo "-- K8s security context --"
K8S_DEPLOY="$SVC_DIR/k8s/deployment.yaml"
if grep -q 'allowPrivilegeEscalation: false' "$K8S_DEPLOY"; then
  echo "  PASS: K8s deployment disables privilege escalation"
  PASS=$((PASS + 1))
else
  echo "  FAIL: K8s deployment does not disable privilege escalation"
  FAIL=$((FAIL + 1))
fi

if grep -q 'runAsUser: 1000' "$K8S_DEPLOY"; then
  echo "  PASS: K8s deployment runs as non-root UID"
  PASS=$((PASS + 1))
else
  echo "  FAIL: K8s deployment does not set runAsUser"
  FAIL=$((FAIL + 1))
fi

# Check ExternalSecrets (no plaintext secrets in manifests)
echo ""
echo "-- ExternalSecrets usage --"
EXT_SEC="$SVC_DIR/k8s/external-secrets.yaml"
if grep -q 'ExternalSecret' "$EXT_SEC"; then
  echo "  PASS: ExternalSecrets manifest exists"
  PASS=$((PASS + 1))
else
  echo "  FAIL: ExternalSecrets manifest missing"
  FAIL=$((FAIL + 1))
fi

PLAIN_SECRETS=$(grep -n 'value:.*sk_' "$K8S_DEPLOY" 2>/dev/null || true)
if [[ -z "$PLAIN_SECRETS" ]]; then
  echo "  PASS: No plaintext secrets in K8s deployment"
  PASS=$((PASS + 1))
else
  echo "  FAIL: Plaintext secrets in K8s deployment"
  FAIL=$((FAIL + 1))
fi

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
[[ $FAIL -eq 0 ]] && echo "PASS" || { echo "FAIL"; exit 1; }
