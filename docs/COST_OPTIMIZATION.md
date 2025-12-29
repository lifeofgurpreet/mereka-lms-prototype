# Cost Optimization for Development Environment
_Last updated: 2025-11-12_

## Overview

This document tracks cost optimization changes made to reduce infrastructure costs during development. These optimizations are **NOT suitable for production** and should be scaled up before going live.

---

## Changes Applied

### 0. Non-Essential Services - Scaled Down ✅

**Services scaled to 0 replicas:**
- Discovery
- Ecommerce + Ecommerce Worker
- Forum
- Notes
- XQueue

**Impact:**
- ✅ Reduces resource consumption
- ✅ Allows GKE to scale down nodes
- ✅ Can be scaled back up instantly when needed
- **Savings**: ~$50-100/month

**To Restore:**
```bash
kubectl scale deployment discovery ecommerce ecommerce-worker forum notes xqueue -n mereka-lms --replicas=1
```

---

### 1. Cloud SQL MySQL - Downsized ✅

**Before:**
- Tier: `db-custom-2-7680` (2 vCPU, 7.5GB RAM)
- Disk: 100GB PD-SSD
- **Cost**: ~$225/month

**After:**
- Tier: `db-f1-micro` (shared CPU, 0.6GB RAM)
- Disk: 100GB PD-SSD (cannot shrink, but unused space costs minimal)
- **Cost**: ~$4/month
- **Savings**: ~$221/month

**Note**: Cloud SQL doesn't allow disk size reduction. The 100GB disk remains but unused space has minimal cost impact.

**Impact:**
- ⚠️ Reduced performance - suitable for dev/testing only
- ⚠️ Shared CPU may cause occasional slowdowns
- ✅ Sufficient for low-traffic development

**To Scale Up for Production:**
```bash
gcloud sql instances patch mereka-lms-mysql \
  --project=mereka-lms \
  --tier=db-custom-2-7680 \
  --storage-size=100
```

---

### 2. Cloud SQL Backup Retention - Reduced ✅

**Before:**
- Transaction log retention: 7 days
- **Cost**: Higher storage costs

**After:**
- Transaction log retention: 3 days
- **Cost**: Reduced storage costs
- **Savings**: ~$5-10/month

**Impact:**
- ⚠️ Shorter backup retention (sufficient for dev)
- ✅ Reduced storage costs
- ✅ Can be increased before production

**To Scale Up:**
```bash
gcloud sql instances patch mereka-lms-mysql \
  --project=mereka-lms \
  --retained-transaction-log-days=7
```

---

### 3. Redis - Optimized ✅

**Before:**
- Tier: STANDARD_HA (High Availability)
- Size: 2GB
- **Cost**: ~$79/month

**After:**
- Tier: BASIC
- Size: 1GB
- **Cost**: ~$19/month
- **Savings**: ~$60/month

**Impact:**
- ⚠️ No high availability (sufficient for dev)
- ⚠️ Reduced cache capacity
- ✅ Significant cost savings
- ✅ Can be upgraded before production

**To Scale Up:**
```bash
gcloud redis instances delete mereka-lms-redis \
  --region=asia-southeast1 \
  --project=mereka-lms

gcloud redis instances create mereka-lms-redis \
  --region=asia-southeast1 \
  --project=mereka-lms \
  --tier=STANDARD_HA \
  --size=2 \
  --network=projects/mereka-lms/global/networks/default
```

**Note**: Remember to update application configs with new Redis endpoint after recreation.

---

### 4. Aspects Analytics - Reduced Resource Limits ✅

**Before:**
- ClickHouse: 3Gi memory, 2 CPU
- Superset: 1.5Gi memory, 1 CPU

**After:**
- ClickHouse: 1Gi memory, 500m CPU
- Superset: 512Mi memory, 250m CPU
- **Savings**: Allows Autopilot to use fewer nodes

**Impact:**
- ⚠️ Reduced analytics processing capacity
- ✅ Sufficient for development/testing workloads
- ✅ Autopilot will scale nodes down automatically

**To Scale Up:**
```bash
tutor config save \
  --set ASPECTS_CLICKHOUSE_MEMORY_LIMIT=3Gi \
  --set ASPECTS_CLICKHOUSE_CPU_LIMIT=2 \
  --set ASPECTS_SUPERSET_MEMORY_LIMIT=1.5Gi \
  --set ASPECTS_SUPERSET_CPU_LIMIT=1
tutor k8s init
kubectl apply -f tutor_env/env/k8s/apps/clickhouse/
kubectl apply -f tutor_env/env/k8s/apps/superset/
```

---

---

### 5. GKE Autopilot Nodes

**Current:**
- Nodes: 8 (auto-managed by Autopilot)
- CPU Usage: ~7.4% average
- Memory Usage: ~9.1% average
- **Cost**: ~$700-900/month

**Optimization:**
- Autopilot automatically scales nodes based on resource requests
- By reducing pod resource requests (Aspects, etc.), nodes will scale down
- Target: 2-3 nodes for development
- **Potential Savings**: $200-400/month

**Note**: Autopilot doesn't allow manual node count control. It scales automatically based on workload requirements.

---

## Total Estimated Savings

| Component | Before | After | Monthly Savings |
|-----------|--------|-------|----------------|
| Cloud SQL MySQL | $225 | $4 | **$221** |
| Redis | $79 | $19 | **$60** |
| Cloud SQL Backups | $10 | $5 | **$5** |
| Non-Essential Services | $50-100 | $0 | **$50-100** |
| MongoDB Atlas | $87 | $0 | **$87** |
| GKE Autopilot | $700-900 | $300-500 | **$300-500** |
| **TOTAL** | **$1,151-1,401** | **$328-528** | **~$767-937/month** |

---

## Before Production Checklist

Before moving to production, ensure you:

- [ ] Scale Cloud SQL back to `db-custom-2-7680` or higher
- [ ] Increase Cloud SQL disk to 100GB+ (or based on data size)
- [ ] Scale Redis to STANDARD_HA 2GB+ if needed
- [ ] Increase Aspects resource limits
- [ ] Review and adjust all pod resource requests
- [ ] Set up monitoring and alerts
- [ ] Configure backup schedules
- [ ] Test load capacity

---

## Cost Monitoring

**View current costs:**
```bash
# GCP Console
# Navigate to: Billing > Reports

# Or via CLI
gcloud billing accounts list
gcloud billing projects describe mereka-lms
```

**Set up billing alerts:**
1. Go to GCP Console > Billing > Budgets & alerts
2. Create a budget with alerts at 50%, 75%, 90%, 100%
3. Set threshold: $500/month for dev, $2000/month for production

---

## Scripts

- **`tools/optimize-dev-costs.sh`**: Interactive script to apply cost optimizations
- **`tools/check-cluster-status.sh`**: Check current cluster status and costs

---

## Additional Optimization Opportunities

### Quick Wins (No Data Loss)

1. **Pause Aspects Analytics** (~$50-100/month savings)
   - If not actively using analytics, scale to 0 replicas:
   ```bash
   kubectl scale deployment clickhouse superset ralph superset-worker superset-worker-beat -n mereka-lms --replicas=0
   ```
   - To restore: `--replicas=1`

2. **Scale Down Non-Essential Services** (~$50-100/month)
   - Discovery, Ecommerce, Forum, Notes, XQueue can be scaled to 0-1 replicas for dev
   ```bash
   kubectl scale deployment discovery ecommerce forum notes xqueue -n mereka-lms --replicas=0
   ```

3. **Reduce Cloud SQL Backup Retention** (~$5-10/month)
   - Reduce from 7 days to 3 days for dev:
   ```bash
   gcloud sql instances patch mereka-lms-mysql \
     --project=mereka-lms \
     --retained-transaction-log-days=3
   ```

### Requiring Data Migration

4. **MongoDB Atlas - Optimized ✅** (~$87/month)
   - M10 → M0 (FREE tier)
   - **Savings**: ~$87/month
   - **Status**: Migration completed, M10 cluster deleted
   - **Impact**: 
     - ⚠️ 512MB storage limit (vs 10GB on M10)
     - ⚠️ Shared CPU/RAM (vs dedicated)
     - ⚠️ No backups (vs automatic backups)
     - ✅ FREE tier - perfect for dev/staging

### Total Additional Potential Savings

- **Applied optimizations**: ~$502-673/month
- **MongoDB Atlas**: ~$87/month ✅
- **Combined total savings**: ~$767-937/month (67-67% reduction)

---

## Notes

- All optimizations are reversible
- Monitor performance after changes
- Scale up gradually before production
- Keep backups before major changes
- Document any custom configurations
- See `tools/additional-cost-optimizations.sh` for detailed commands

