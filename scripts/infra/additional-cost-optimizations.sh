#!/usr/bin/env bash
# Additional cost optimization opportunities for development
set -euo pipefail

PROJECT_ID="mereka-lms"
REGION="asia-southeast1"

echo "=== Additional Cost Optimization Opportunities ==="
echo ""

# 1. Redis Optimization
echo "1️⃣  REDIS OPTIMIZATION"
echo "   Current: STANDARD_HA 2GB (~\$79/month)"
echo "   Optimize: BASIC 1GB (~\$19/month)"
echo "   Savings: ~\$60/month"
echo "   ⚠️  Requires deleting and recreating (data loss)"
echo ""

# 2. Pause Aspects Analytics (if not actively used)
echo "2️⃣  PAUSE ASPECTS ANALYTICS"
echo "   Services: ClickHouse, Superset, Ralph"
echo "   Current cost: ~\$50-100/month (via GKE resources)"
echo "   Action: Scale to 0 replicas when not needed"
echo "   Command:"
echo "     kubectl scale deployment clickhouse superset ralph -n mereka-lms --replicas=0"
echo "   To restore:"
echo "     kubectl scale deployment clickhouse superset ralph -n mereka-lms --replicas=1"
echo ""

# 3. Scale down non-essential services
echo "3️⃣  SCALE DOWN NON-ESSENTIAL SERVICES"
echo "   Services that can be scaled to 0-1 replicas for dev:"
echo "   - Discovery (if not actively searching)"
echo "   - Ecommerce (if not processing payments)"
echo "   - Forum (if not actively used)"
echo "   - Notes (if not actively used)"
echo "   - XQueue (if not processing submissions)"
echo ""
echo "   Example:"
echo "     kubectl scale deployment discovery ecommerce forum notes xqueue -n mereka-lms --replicas=0"
echo ""

# 4. Reduce Cloud SQL backup retention
echo "4️⃣  REDUCE CLOUD SQL BACKUP RETENTION"
echo "   Current: 7 days transaction log retention"
echo "   Optimize: 3 days for dev (saves storage costs)"
echo "   Command:"
echo "     gcloud sql instances patch mereka-lms-mysql \\"
echo "       --project=$PROJECT_ID \\"
echo "       --backup-start-time=03:00 \\"
echo "       --enable-bin-log \\"
echo "       --transaction-log-retention-days=3"
echo ""

# 5. MongoDB Atlas optimization (from NEXT10_TASKS.md)
echo "5️⃣  MONGODB ATLAS OPTIMIZATION"
echo "   Current: M10 tier (~\$87/month)"
echo "   Optimize: M0 tier (FREE for dev/staging)"
echo "   ⚠️  See: ./scripts/infra/downgrade-mongodb-to-m0.sh"
echo "   Savings: ~\$87/month"
echo ""

# 6. Review and reduce persistent volumes
echo "6️⃣  PERSISTENT VOLUMES"
echo "   Current: 33GB total across 10 volumes"
echo "   Review unused PVCs and reduce sizes where possible"
echo "   Command to check:"
echo "     kubectl get pvc -n mereka-lms"
echo "     kubectl describe pvc <name> -n mereka-lms"
echo ""

# 7. Load Balancer optimization
echo "7️⃣  LOAD BALANCER"
echo "   Current: Caddy using LoadBalancer (~\$18/month base + traffic)"
echo "   Note: Required for external access, but costs ~\$18/month minimum"
echo "   Consider: Using Ingress instead if possible (cheaper)"
echo ""

# 8. Elasticsearch optimization
echo "8️⃣  ELASTICSEARCH"
echo "   Current: 2Gi persistent volume"
echo "   Review: Can size be reduced for dev?"
echo "   Check usage:"
echo "     kubectl exec -n mereka-lms deployment/elasticsearch -- curl -s localhost:9200/_cat/indices"
echo ""

echo "=== QUICK WINS SUMMARY ==="
echo ""
echo "Immediate actions (no data loss):"
echo "  ✅ Pause Aspects: ~\$50-100/month"
echo "  ✅ Scale down non-essential services: ~\$50-100/month"
echo "  ✅ Reduce backup retention: ~\$5-10/month"
echo ""
echo "Actions requiring data migration:"
echo "  ⚠️  Redis: BASIC 1GB: ~\$60/month"
echo "  ⚠️  MongoDB M0: ~\$87/month"
echo ""
echo "TOTAL POTENTIAL ADDITIONAL SAVINGS: ~\$200-350/month"
echo ""
echo "Combined with previous optimizations:"
echo "  Previous savings: ~\$480-580/month"
echo "  Additional savings: ~\$200-350/month"
echo "  TOTAL SAVINGS: ~\$680-930/month"
echo "  New monthly cost: ~\$93-583/month (down from \$1,023-1,263)"


