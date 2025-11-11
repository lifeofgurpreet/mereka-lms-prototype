#!/usr/bin/env bash
# Increase GKE Autopilot quotas for Aspects Analytics deployment
set -euo pipefail

PROJECT_ID="mereka-lms"
REGION="asia-southeast1"

echo "=== GKE Autopilot Quota Increase for Aspects Analytics ==="
echo ""
echo "Project: $PROJECT_ID"
echo "Region: $REGION"
echo ""

# Check current quotas
echo "Checking current quotas..."
CURRENT_CPU=$(gcloud compute project-info describe --project=$PROJECT_ID --format=json 2>/dev/null | \
  jq -r '.quotas[] | select(.metric == "CPUS") | .limit' || echo "0")
CURRENT_USAGE=$(gcloud compute project-info describe --project=$PROJECT_ID --format=json 2>/dev/null | \
  jq -r '.quotas[] | select(.metric == "CPUS") | .usage' || echo "0")

echo "Current CPU quota: $CURRENT_CPU cores"
echo "Current CPU usage: $CURRENT_USAGE cores"
echo ""

# Calculate new limit (add 8 CPU cores for Aspects: ClickHouse=2, Superset=1, Workers=1, Ralph=0.5, buffer=3.5)
ADDITIONAL_CPU=8
NEW_CPU_LIMIT=$((CURRENT_CPU + ADDITIONAL_CPU))

echo "Aspects services need:"
echo "  - ClickHouse: 2 CPU cores"
echo "  - Superset: 1 CPU core"
echo "  - Superset workers: 1 CPU core"
echo "  - Ralph: 0.5 CPU core"
echo "  - Buffer: 3.5 CPU cores"
echo "  Total additional: $ADDITIONAL_CPU CPU cores"
echo ""

if [ "$CURRENT_CPU" -eq 0 ]; then
  echo "⚠️  Could not determine current quota. Please check manually:"
  echo "   gcloud compute project-info describe --project=$PROJECT_ID"
  exit 1
fi

echo "Requesting quota increase to: $NEW_CPU_LIMIT CPU cores"
echo ""

# Request quota increase via Service Usage API
echo "Requesting quota increase..."
gcloud alpha service-usage quota update \
  --service=compute.googleapis.com \
  --consumer=projects/$PROJECT_ID \
  --metric=compute.googleapis.com/cpus \
  --value=$NEW_CPU_LIMIT \
  --format=json 2>&1 | tee /tmp/quota-request.json

if [ $? -eq 0 ]; then
  echo ""
  echo "✅ Quota increase requested successfully!"
  echo ""
  echo "Note: Quota increases may take a few minutes to be approved."
  echo "Check status with:"
  echo "  gcloud compute project-info describe --project=$PROJECT_ID | grep CPUS"
else
  echo ""
  echo "⚠️  Quota increase request may require manual approval via GCP Console."
  echo ""
  echo "To request manually:"
  echo "1. Go to: https://console.cloud.google.com/iam-admin/quotas?project=$PROJECT_ID"
  echo "2. Filter by: 'CPUS' and 'asia-southeast1'"
  echo "3. Select the quota and click 'Edit Quotas'"
  echo "4. Request increase to: $NEW_CPU_LIMIT CPU cores"
  echo "5. Submit request (usually approved within minutes)"
fi

echo ""
echo "After quota is increased, deploy Aspects with:"
echo "  ./tools/deploy-aspects-k8s.sh"


