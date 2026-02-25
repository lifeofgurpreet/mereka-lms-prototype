#!/usr/bin/env bash
# T143: Provision ADMIN_API_KEY for Purchase Gateway.
#
# Creates the secret in Infisical → GCP Secret Manager → ExternalSecrets.
# Required for Purchase Gateway admin authentication in production.
#
# Usage:
#   ./scripts/infra/provision-admin-api-key.sh
#
# Prerequisites:
#   - Infisical CLI authenticated
#   - gcloud CLI authenticated with bbi-k8 project access
#   - A strong API key (generated if not provided)

set -euo pipefail

INFISICAL="/home/gurpreet/projects/vps/infrastructure/scripts/infisical"
GCP_PROJECT="bbi-k8"
SECRET_NAME="MEREKA_LMS_ADMIN_API_KEY"

echo "=== Provisioning ADMIN_API_KEY for Purchase Gateway ==="

# Generate a secure key if not provided
if [[ -z "${ADMIN_API_KEY:-}" ]]; then
  ADMIN_API_KEY="$(openssl rand -base64 32 | tr -d '=/+' | head -c 48)"
  echo "  Generated new API key (48 chars)"
else
  echo "  Using provided ADMIN_API_KEY"
fi

echo

# Step 1: Infisical
echo "--- Step 1: Store in Infisical ---"
cd /home/gurpreet/projects/k8s/reka-slackbot  # has .infisical.json
${INFISICAL} secrets set "${SECRET_NAME}=${ADMIN_API_KEY}" \
  --domain https://secrets.mereka.io/api \
  --env prod --path / 2>/dev/null
echo "  ✓ Infisical: ${SECRET_NAME}"

# Step 2: GCP Secret Manager
echo "--- Step 2: Store in GCP Secret Manager ---"
if gcloud secrets describe "$SECRET_NAME" --project="$GCP_PROJECT" &>/dev/null; then
  printf '%s' "$ADMIN_API_KEY" | \
    gcloud secrets versions add "$SECRET_NAME" --project="$GCP_PROJECT" --data-file=-
  echo "  ✓ GCP SM: Added new version to ${SECRET_NAME}"
else
  printf '%s' "$ADMIN_API_KEY" | \
    gcloud secrets create "$SECRET_NAME" --project="$GCP_PROJECT" --data-file=-
  echo "  ✓ GCP SM: Created ${SECRET_NAME}"
fi

# Step 3: Verify ExternalSecret mapping
echo "--- Step 3: Verify ExternalSecret mapping ---"
ES_FILE="deploy/k8s/base/secrets/external-secrets.yaml"
if grep -q "$SECRET_NAME" "$ES_FILE" 2>/dev/null; then
  echo "  ✓ ExternalSecret mapping already present in ${ES_FILE}"
else
  echo "  ⚠ ExternalSecret mapping NOT found in ${ES_FILE}"
  echo "    Add this to the ExternalSecret spec.data[]:"
  echo "      - secretKey: ADMIN_API_KEY"
  echo "        remoteRef:"
  echo "          key: ${SECRET_NAME}"
  echo "    Then: kubectl apply -f ${ES_FILE}"
fi

echo
echo "=== Done ==="
echo "After ExternalSecrets syncs (up to 1h), the Purchase Gateway"
echo "will have ADMIN_API_KEY available as an environment variable."
echo
echo "Test: kubectl exec -n mereka-lms deploy/purchase-gateway -- printenv ADMIN_API_KEY"
