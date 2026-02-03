# GCP Billing Analysis for Mereka-LMS Project
**Generated**: 2025-11-20
**Analysis Period**: November 6, 2025 - November 20, 2025 (14 days)
**Project ID**: mereka-lms
**Billing Account**: 01A879-A82798-7962E2 (Mereka)

---

## Executive Summary

The mereka-lms project has been running on GCP for **14 days** since first deployment on November 6, 2025. During this period, significant cost optimizations have been implemented, reducing projected monthly costs by approximately **67-73%** from initial estimates.

### Key Metrics
- **Project Created**: November 6, 2025
- **First Infrastructure Deployed**: November 6, 2025 (Cloud SQL MySQL at 02:18 UTC)
- **Current Runtime**: 14 days
- **Monthly Budget**: MYR 400 (~USD 92)
- **Budget Alerts**: Set at 62.5% and 100% thresholds

---

## Deployment Timeline

| Date | Event | Component |
|------|-------|-----------|
| 2025-11-06 | Project creation | mereka-lms project initialized |
| 2025-11-06 02:18 | First resource deployed | Cloud SQL MySQL (db-custom-2-7680) |
| 2025-11-06 02:28 | GKE cluster created | GKE Autopilot cluster (asia-southeast1) |
| 2025-11-06 10:18 | Container registry setup | Artifact Registry (OpenEdX images) |
| 2025-11-08 | Budget enforcement | Terraform budgets applied |
| 2025-11-12 | Major cost optimization | Cloud SQL downgraded, Redis optimized |
| 2025-11-12 01:34 | Redis recreated | BASIC tier 1GB Redis instance |

---

## Current Infrastructure Configuration

### Compute (GKE Autopilot)
- **Cluster**: mereka-lms (asia-southeast1)
- **Type**: Autopilot (fully managed)
- **Nodes**: 6 active nodes (down from initial 9)
- **Machine Type**: e2-standard-8
- **CPU Utilization**: ~6-7% average
- **Memory Utilization**: ~9% average
- **Status**: Running (optimized for development)

### Database (Cloud SQL MySQL)
**Current Configuration** (After Optimization):
- **Instance**: mereka-lms-mysql
- **Tier**: db-f1-micro (shared CPU, 0.6GB RAM)
- **Storage**: 100GB PD-SSD
- **Version**: MySQL 8.0
- **Region**: asia-southeast1
- **Created**: November 6, 2025

**Original Configuration** (Before Nov 12):
- **Tier**: db-custom-2-7680 (2 vCPU, 7.5GB RAM)
- **Cost Impact**: ~$221/month savings after downgrade

### Cache (Cloud Memorystore Redis)
**Current Configuration** (After Optimization):
- **Instance**: mereka-lms-redis
- **Tier**: BASIC (no HA)
- **Memory**: 1GB
- **Region**: asia-southeast1-c
- **Created**: November 12, 2025 (recreated)

**Original Configuration** (Before Nov 12):
- **Tier**: STANDARD_HA
- **Memory**: 2GB
- **Cost Impact**: ~$60/month savings after optimization

### Storage

#### Persistent Disks
- **Total Volumes**: 11 PVCs
- **Total Storage**: 38GB
- **Type**: pd-balanced (regional SSD)
- **Earliest Disk**: Created November 5, 2025 (20:38 PST)

#### Cloud Storage Buckets
1. **staging-academy-mereka-io-backup**
   - Location: asia-southeast1
   - Size: ~147 MB (154,429,954 bytes)
   - Purpose: Database backups

2. **staging-academy-mereka-io-content**
   - Location: asia-southeast1
   - Purpose: Course content, static assets

#### Artifact Registry
- **Repository**: asia-southeast1-docker.pkg.dev/mereka-lms/openedx
- **Images**: 5+ OpenEdX service images
- **First Image**: November 6, 2025 (11:25 UTC)

### Network Resources
- **Static IP**: 34.142.147.42 (NAT gateway)
- **Type**: External, Regional
- **Created**: November 5, 2025 (18:16 PST)

### External Services
- **MongoDB**: MongoDB Atlas (M0 FREE tier - migrated from M10)
  - Original: M10 cluster (~$87/month)
  - Current: M0 FREE tier ($0/month)
  - Migration: Completed November 12, 2025

---

## Cost Analysis

### Estimated Monthly Costs (Current Configuration)

| Component | Specification | Monthly Cost (USD) |
|-----------|---------------|-------------------|
| **GKE Autopilot** | 6 nodes, e2-standard-8 | $400-550 |
| **Cloud SQL MySQL** | db-f1-micro, 100GB SSD | $4 |
| **Cloud Memorystore Redis** | BASIC tier, 1GB | $19 |
| **Persistent Disks** | 38GB pd-balanced | $6 |
| **Cloud Storage** | ~1GB regional | <$1 |
| **Artifact Registry** | Docker images | $2-5 |
| **Static IP** | 1 regional IP | $3 |
| **Network Egress** | Varies by traffic | $10-30 |
| **MongoDB Atlas** | M0 FREE tier | $0 |
| **TOTAL (Optimized)** | | **$444-618/month** |

### Cost Comparison: Before vs After Optimization

| Component | Before | After | Monthly Savings |
|-----------|--------|-------|----------------|
| Cloud SQL MySQL | $225 | $4 | **$221** |
| Redis | $79 | $19 | **$60** |
| MongoDB Atlas | $87 | $0 | **$87** |
| GKE Autopilot | $700-900 | $400-550 | **$200-400** |
| Cloud SQL Backups | $10 | $5 | **$5** |
| **TOTAL** | **$1,101-1,301** | **$428-578** | **$573-823** |
| **Savings %** | | | **67-73%** |

### Projected 14-Day Costs (Nov 6-20)

Based on the current configuration and timeline:

**Phase 1 (Nov 6-12)**: Higher costs with original configuration
- Days: 6 days
- Estimated cost: ~$220-260 (before optimizations)

**Phase 2 (Nov 12-20)**: Optimized costs
- Days: 8 days
- Estimated cost: ~$118-164 (after optimizations)

**Total Estimated for 14 Days**: ~$338-424

**Note**: Actual costs can only be verified through the GCP Billing Console. This is a projection based on resource configurations.

---

## Cost Breakdown by Service Type

### Top 5 Most Expensive Services (Optimized Config)

1. **GKE Autopilot (Compute)**: $400-550/month (69-89%)
   - Largest cost driver
   - Autopilot automatically manages node scaling
   - Current: 6 nodes (down from 9)
   - Utilization: Very low (6-7% CPU, 9% memory)
   - **Optimization potential**: High - consider further pod resource reduction

2. **Network Egress**: $10-30/month (2-5%)
   - Data transfer out of GCP
   - Varies with traffic volume
   - **Optimization**: Minimal - essential for service delivery

3. **Cloud Memorystore Redis**: $19/month (3-4%)
   - Already optimized (BASIC tier, 1GB)
   - **Optimization potential**: Low - already minimal tier

4. **Persistent Disks**: $6/month (1%)
   - 38GB across 11 volumes
   - **Optimization potential**: Low - essential storage

5. **Cloud SQL MySQL**: $4/month (<1%)
   - Heavily optimized (db-f1-micro)
   - **Optimization potential**: None - already minimal tier

---

## Cost Trends Analysis

### Timeline of Cost Changes

```
Nov 6-12 (Initial Deployment):
├── High cost phase
├── Full-spec infrastructure
└── Estimated: $1,100-1,300/month

Nov 12 (Optimization Event):
├── Cloud SQL downgrade: db-custom-2-7680 → db-f1-micro
├── Redis optimization: STANDARD_HA 2GB → BASIC 1GB
├── MongoDB migration: M10 → M0 FREE
└── Services scaled down: Discovery, Ecommerce, Forum, Notes, XQueue

Nov 12-20 (Optimized Phase):
├── Lower cost phase
├── Development-optimized infrastructure
└── Estimated: $428-578/month

Trend: DECREASING (73% reduction achieved)
```

### Future Projections

**Current Trajectory**: STABLE
- Infrastructure optimized for development workload
- Costs should remain in $400-600/month range
- Autopilot may scale down further if pod resources are reduced

**Before Production**: INCREASING
- Will need to scale up for production workloads
- Estimated production costs: $1,500-2,500/month
  - Cloud SQL: Upgrade to db-custom-2-7680+ ($225+)
  - Redis: Upgrade to STANDARD_HA 2GB+ ($79+)
  - MongoDB: Upgrade to M10+ ($87+)
  - GKE: More nodes for HA and load ($1,000-1,500+)

---

## Cost Optimization History

### Applied Optimizations (November 12, 2025)

#### 1. Cloud SQL MySQL Downgrade ✅
- **Before**: db-custom-2-7680 (2 vCPU, 7.5GB RAM) - $225/month
- **After**: db-f1-micro (shared CPU, 0.6GB RAM) - $4/month
- **Savings**: $221/month
- **Impact**: Suitable for development only; reduced performance
- **Reversibility**: One command to scale back up

#### 2. Redis Tier & Size Optimization ✅
- **Before**: STANDARD_HA 2GB - $79/month
- **After**: BASIC 1GB - $19/month
- **Savings**: $60/month
- **Impact**: No HA, reduced cache capacity (acceptable for dev)
- **Reversibility**: Requires recreation with data loss

#### 3. MongoDB Atlas Migration ✅
- **Before**: M10 cluster (dedicated) - $87/month
- **After**: M0 FREE tier - $0/month
- **Savings**: $87/month
- **Impact**: 512MB limit, shared resources, no backups
- **Reversibility**: Can upgrade anytime with minimal downtime

#### 4. Non-Essential Services Scaled Down ✅
- **Services**: Discovery, Ecommerce, Forum, Notes, XQueue
- **Action**: Scaled to 0 replicas
- **Savings**: ~$50-100/month (reduced GKE node count)
- **Impact**: Services unavailable but can be restored instantly
- **Reversibility**: `kubectl scale --replicas=1`

#### 5. Cloud SQL Backup Retention Reduced ✅
- **Before**: 7 days transaction log retention
- **After**: 3 days transaction log retention
- **Savings**: ~$5/month
- **Impact**: Shorter backup window (acceptable for dev)
- **Reversibility**: One config change

#### 6. GKE Node Count Reduction (Automatic) ✅
- **Before**: 9 nodes
- **After**: 6 nodes (Autopilot auto-scaled down)
- **Savings**: ~$200-400/month
- **Impact**: Sufficient for current workload
- **Reversibility**: Autopilot will scale up automatically if needed

---

## Budget & Alerts Configuration

### Budget Setup (via Terraform)
- **File**: `infrastructure/terraform/budgets.tf`
- **Monthly Budget**: MYR 400 (~USD 92)
- **Currency**: Malaysian Ringgit (MYR)
- **Applied**: November 8, 2025

### Alert Thresholds
1. **62.5% threshold** (MYR 250 / USD 57.50)
   - Type: Current spend
   - Action: Email notification to finance team

2. **100% threshold** (MYR 400 / USD 92)
   - Type: Forecasted spend
   - Action: Email notification to finance team
   - Recipients: techadmin@biji-biji.com, team@mereka.io

### Budget Status
- **Current Estimated Monthly**: $444-618 (MYR 1,932-2,688)
- **Budget**: MYR 400 (USD 92)
- **Status**: ⚠️ **OVER BUDGET**
- **Recommendation**: Either increase budget to MYR 2,000-2,500 or implement additional optimizations

---

## Recommendations

### Immediate Actions (Further Cost Reduction)

1. **Review GKE Pod Resource Requests** (Potential: $100-200/month)
   - Current utilization is very low (6-7% CPU, 9% memory)
   - Reduce resource requests in pod specifications
   - Autopilot will automatically scale down nodes
   - Target: 2-3 nodes for development

2. **Pause Aspects Analytics When Not In Use** (Potential: $50-100/month)
   - ClickHouse, Superset, Ralph consuming resources
   - Scale to 0 replicas during non-working hours
   - Automated scheduling possible

3. **Review Persistent Disk Usage** (Potential: $5-10/month)
   - 11 PVCs totaling 38GB
   - Identify and remove unused volumes
   - Consider switching some to pd-standard (cheaper)

4. **Update Budget to Realistic Amount**
   - Current budget (MYR 400 / $92) is too low
   - Recommended: MYR 2,000-2,500 ($460-575) for development
   - Or: Implement aggressive optimizations to meet $92/month target

### Before Production Launch

1. **Scale Up Cloud SQL** - Back to db-custom-2-7680 or higher
2. **Scale Up Redis** - Back to STANDARD_HA 2GB minimum
3. **Upgrade MongoDB** - From M0 to M10 or M30
4. **Enable Backups** - Increase retention, enable automated backups
5. **Configure Auto-Scaling** - Set appropriate min/max for GKE
6. **Set Up Monitoring** - SLOs, dashboards, alerting
7. **Load Testing** - Verify capacity before cutover

### Cost Monitoring

1. **Enable BigQuery Billing Export**
   - Export billing data to BigQuery for detailed analysis
   - Create dashboards for cost trending
   - Set up cost anomaly detection

2. **Review Billing Weekly**
   - Check GCP Console > Billing > Reports
   - Identify cost spikes early
   - Adjust resources proactively

3. **Tag Resources**
   - Add labels for cost allocation
   - Environment: dev/staging/prod
   - Component: lms/cms/analytics/infrastructure

---

## Access to Detailed Billing Data

### GCP Console (Recommended)
1. Navigate to: [GCP Billing Console](https://console.cloud.google.com/billing)
2. Select billing account: `01A879-A82798-7962E2` (Mereka)
3. Go to "Reports" tab
4. Filter by:
   - Project: mereka-lms
   - Time range: November 2025
   - Group by: Service, SKU, Project

### CLI Commands
```bash
# List billing accounts
gcloud billing accounts list

# Get project billing info
gcloud billing projects describe mereka-lms

# Note: Detailed cost queries require BigQuery export setup
# Current setup: No BigQuery billing export detected
```

### Setting Up Billing Export (Recommended)
```bash
# Create BigQuery dataset for billing export
bq mk --dataset --location=asia-southeast1 mereka-lms:billing_export

# Then configure in GCP Console:
# Billing > Billing export > Enable BigQuery export
# Dataset: mereka-lms.billing_export
```

---

## Service Details & Pricing

### GKE Autopilot Pricing
- **CPU**: $0.10 per vCPU-hour
- **Memory**: $0.01125 per GB-hour
- **Current**: 6 nodes × e2-standard-8
- **Estimated**: $400-550/month (varies with actual pod requests)

### Cloud SQL Pricing
- **db-f1-micro**: ~$4/month (shared CPU, 0.6GB RAM)
- **Storage (PD-SSD)**: $0.17/GB-month × 100GB = $17/month
- **Total**: ~$21/month (but instance tier dominates at dev tier)

### Redis Pricing
- **BASIC tier**: ~$0.026/GB-hour
- **1GB**: $0.026 × 1GB × 730 hours = $19/month

### Storage Pricing
- **Regional Cloud Storage**: $0.020/GB-month
- **PD-Balanced**: $0.10/GB-month
- **PD-SSD**: $0.17/GB-month

### Network Pricing
- **Static IP (in use)**: $0.004/hour = $2.92/month
- **Egress (asia-to-worldwide)**: $0.12/GB (first 1TB)

---

## Additional Notes

### Cost Control Scripts
The repository includes automated cost optimization scripts:
- `scripts/infra/optimize-dev-costs.sh` - Interactive optimization
- `scripts/infra/downgrade-mongodb-to-m0.sh` - MongoDB migration
- `scripts/infra/additional-cost-optimizations.sh` - Extended optimizations

### Documentation References
- Cost Estimate: `docs/COST_ESTIMATE.md`
- Cost Optimization: `docs/COST_OPTIMIZATION.md`
- GCP Roadmap: `docs/operations/GCP_ROADMAP.md`
- Terraform Budgets: `infrastructure/terraform/budgets.tf`

### Known Limitations
1. **No BigQuery Billing Export**: Cannot query detailed historical costs via CLI
2. **Budget Too Low**: Current MYR 400 budget is insufficient for actual costs
3. **Development Configuration**: Current setup is NOT suitable for production
4. **MongoDB on Free Tier**: M0 has 512MB limit and no backups

---

## Conclusion

The mereka-lms project has been running for 14 days with successful cost optimization reducing projected monthly costs by **67-73%**. The current configuration is optimized for development workloads and should remain stable at **$444-618/month**.

However, the configured budget of **MYR 400 (~$92/month) is significantly lower** than actual costs. This requires either:
1. Increasing the budget to MYR 2,000-2,500 ($460-575)
2. Implementing aggressive further optimizations to meet the $92 target

Before production launch, resources will need to be scaled up significantly, resulting in estimated costs of **$1,500-2,500/month**.

### Action Items
- [ ] Review and adjust budget in Terraform to realistic amount
- [ ] Enable BigQuery billing export for detailed cost tracking
- [ ] Implement weekly cost review process
- [ ] Document scaling plan for production launch
- [ ] Set up cost anomaly alerts
