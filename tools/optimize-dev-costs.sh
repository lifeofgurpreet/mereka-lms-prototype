#!/usr/bin/env bash
# Cost optimization script for development environment
# Reduces infrastructure costs by downsizing resources

set -euo pipefail

PROJECT_ID="mereka-lms"
REGION="asia-southeast1"

echo "=== Cost Optimization for Development Environment ==="
echo ""

# 1. Downsize Cloud SQL MySQL
echo "📊 Current Cloud SQL: db-custom-2-7680 (2 vCPU, 7.5GB RAM)"
echo "   → Downsizing to db-f1-micro (shared CPU, 0.6GB RAM) for dev"
echo ""
read -p "Continue with Cloud SQL downsizing? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
  echo "⚠️  WARNING: This will cause downtime. Ensure backups are taken."
  read -p "Are you sure? Type 'yes' to continue: " confirm
  if [ "$confirm" = "yes" ]; then
    gcloud sql instances patch mereka-lms-mysql \
      --project="$PROJECT_ID" \
      --tier=db-f1-micro \
      --quiet
    echo "✅ Cloud SQL downsized to db-f1-micro"
  else
    echo "⏭️  Skipped Cloud SQL downsizing"
  fi
fi
echo ""

# 2. Reduce Redis size and tier
echo "📊 Current Redis: STANDARD_HA 2GB"
echo "   → Reducing to BASIC 1GB for dev (saves ~$60/month)"
echo ""
read -p "Continue with Redis optimization? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
  echo "⚠️  WARNING: This requires deleting and recreating Redis instance."
  echo "   Data will be lost. Ensure you have backups if needed."
  read -p "Are you sure? Type 'yes' to continue: " confirm
  if [ "$confirm" = "yes" ]; then
    # Delete old instance
    gcloud redis instances delete mereka-lms-redis \
      --region="$REGION" \
      --project="$PROJECT_ID" \
      --quiet || echo "Instance may not exist or already deleted"
    
    # Create new smaller instance
    gcloud redis instances create mereka-lms-redis \
      --region="$REGION" \
      --project="$PROJECT_ID" \
      --tier=BASIC \
      --size=1 \
      --network=projects/$PROJECT_ID/global/networks/default \
      --quiet
    
    echo "✅ Redis optimized to BASIC 1GB"
    echo "⚠️  Remember to update application configs to use new Redis endpoint"
  else
    echo "⏭️  Skipped Redis optimization"
  fi
fi
echo ""

# 3. Reduce Cloud SQL disk size
echo "📊 Current Cloud SQL disk: 100GB"
echo "   → Reducing to 20GB for dev (saves ~$13/month)"
echo ""
read -p "Continue with disk size reduction? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
  gcloud sql instances patch mereka-lms-mysql \
    --project="$PROJECT_ID" \
    --storage-size=20 \
    --quiet
  echo "✅ Cloud SQL disk reduced to 20GB"
else
  echo "⏭️  Skipped disk size reduction"
fi
echo ""

# 4. Review and reduce pod resource requests
echo "📊 GKE Autopilot nodes: 8 nodes (auto-managed)"
echo "   → Autopilot will automatically scale down if we reduce resource requests"
echo "   → Current utilization: ~7% CPU, ~9% Memory"
echo ""
echo "To reduce node count, we need to reduce pod resource requests."
echo "This can be done via Tutor config or by editing deployments."
echo ""
echo "💡 Recommendation:"
echo "   - Reduce Aspects resource limits (already configured conservatively)"
echo "   - Consider pausing non-essential services during off-hours"
echo "   - Use 'tutor config save' to adjust resource requests"
echo ""

# 5. Summary
echo "=== Estimated Monthly Savings ==="
echo ""
echo "Cloud SQL (db-custom-2-7680 → db-f1-micro):"
echo "  - CPU: 2 vCPU → shared CPU: ~\$146/month saved"
echo "  - RAM: 7.5GB → 0.6GB: ~\$62/month saved"
echo "  - Disk: 100GB → 20GB: ~\$13/month saved"
echo "  Total Cloud SQL savings: ~\$221/month"
echo ""
echo "Redis (STANDARD_HA 2GB → BASIC 1GB):"
echo "  - Tier: STANDARD_HA → BASIC: ~\$40/month saved"
echo "  - Size: 2GB → 1GB: ~\$20/month saved"
echo "  Total Redis savings: ~\$60/month"
echo ""
echo "GKE Autopilot:"
echo "  - Nodes will scale down automatically as resource requests decrease"
echo "  - Potential savings: \$100-300/month (depends on actual usage)"
echo ""
echo "TOTAL ESTIMATED SAVINGS: ~\$380-580/month"
echo ""
echo "⚠️  Note: These changes are optimized for DEVELOPMENT."
echo "   Scale up resources before moving to production!"




