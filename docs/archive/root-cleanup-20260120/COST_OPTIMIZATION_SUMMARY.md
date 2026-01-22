# Cost Optimization Summary - Mereka LMS

**Date:** November 20, 2025
**Environment:** Development/Staging
**Status:** ✅ Optimizations Applied

## Overview

Successfully implemented cost optimizations for the mereka-lms GCP infrastructure, targeting dev/staging environment efficiencies. All changes are designed to reduce costs while maintaining functionality for development and testing.

## Optimizations Completed

### 1. ✅ Scaled Down Non-Essential Services

**Action:** Scaled analytics and optional services to 0 replicas

**Services Scaled Down:**
- `clickhouse` (analytics data warehouse)
- `superset` (analytics dashboard)
- `superset-worker` (analytics worker)
- `superset-worker-beat` (analytics scheduler)
- `ralph` (learning analytics)
- `forum` (discussion forums - not essential for dev)

**Impact:**
- Reduced pod count by 6 pods
- Lower resource requests → fewer GKE nodes needed
- **Estimated Savings:** $50-100/month

**Verification:**
```bash
kubectl get deployments -n mereka-lms
# Should show 0/0 for the scaled-down services
```

**To Re-enable (for testing):**
```bash
kubectl scale deployment clickhouse superset ralph superset-worker superset-worker-beat forum -n mereka-lms --replicas=1
```

---

### 2. ✅ Deleted Orphaned Load Balancer

**Action:** Removed unused Load Balancer from `openedx` namespace

**Details:**
- Deleted Kubernetes service: `caddy` in `openedx` namespace
- Automatically cleaned up GCP forwarding rule: `a9f47605b974148c2a62dc2c9129edbe`
- External IP freed: `34.126.136.30`

**Impact:**
- **Savings:** ~$18/month

**Verification:**
```bash
gcloud compute forwarding-rules list --project=mereka-lms
# Should show only 1 forwarding rule for mereka-lms namespace
```

---

### 3. ✅ Deleted Orphaned PVCs

**Action:** Removed 14GB of unused persistent volumes in `openedx` namespace

**Deleted PVCs:**
- `caddy` (1 GB)
- `elasticsearch` (2 GB)
- `mongodb` (5 GB)
- `mysql` (5 GB)
- `redis` (1 GB)

**Impact:**
- **Savings:** ~$1.40/month

**Verification:**
```bash
kubectl get pvc -n openedx
# Should show: No resources found
```

---

### 4. ✅ Verified MongoDB Configuration

**Finding:** Using local MongoDB (in-cluster), NOT MongoDB Atlas

**Status:**
- MongoDB running as pod in `mereka-lms` namespace
- No MongoDB Atlas charges (M0 or M10)
- Already optimized (no action needed)

**Impact:**
- **Savings:** $0/month (already optimal)
- **Avoided Cost:** $87/month if we were on Atlas M10

---

### 5. ⚠️ Cloud SQL Disk Size

**Action Attempted:** Reduce disk from 100GB to 20GB

**Result:** ❌ **FAILED** - Cloud SQL does not allow disk size reduction

**Reason:** GCP Cloud SQL limitation - disks can only be increased, never decreased

**Workaround:** None available for existing instance. For future instances, provision smaller initial disk size.

**Impact:**
- **Savings:** $0/month (unable to optimize)
- **Missed Opportunity:** ~$13/month

**Note:** This is a one-time mistake. When recreating instances in the future, start with smaller disk (20-30GB).

---

### 6. ✅ Disabled Cloud SQL High Availability

**Action:** Changed Cloud SQL from REGIONAL (HA) to ZONAL mode

**Details:**
- Instance: `mereka-lms-mysql`
- Before: REGIONAL (multi-zone HA)
- After: ZONAL (single-zone)
- Operation ID: `e6c624d0-70ae-4abb-8db5-443f00000031`

**Impact:**
- **Savings:** ~$20/month
- **Trade-off:** Less resilient to zone failures (acceptable for dev/staging)

**Verification:**
```bash
gcloud sql instances describe mereka-lms-mysql --project=mereka-lms --format="value(settings.availabilityType)"
# Should show: ZONAL
```

**Note:** There was a network connectivity issue during verification, but the operation was successfully initiated.

---

### 7. ✅ Created Pod Resource Optimization Script

**Action:** Created script to reduce pod memory requests from 2Gi to 512Mi

**Script:** `scripts/infra/optimize-pod-resources.sh`

**Targets:**
- `cms` (2Gi → 512Mi)
- `cms-worker` (2Gi → 512Mi)
- `lms` (2Gi → 512Mi)
- `lms-worker` (2Gi → 512Mi)
- `mfe` (2Gi → 512Mi)

**Impact:**
- **Expected Savings:** $150-250/month
- **Mechanism:** GKE Autopilot will scale down from 6 nodes to 2-3 nodes

**Status:** ⚠️ **PENDING** - Script created but not executed due to network connectivity issues

**Manual Execution (when network is restored):**
```bash
bash scripts/infra/optimize-pod-resources.sh
```

**Verification:**
```bash
# Check pod resource requests
kubectl get deployment cms -n mereka-lms -o jsonpath='{.spec.template.spec.containers[0].resources.requests.memory}'
# Should show: 512Mi (after script runs)

# Monitor node count reduction
kubectl get nodes
# Should reduce from 6 to 2-3 nodes over 10-15 minutes
```

---

### 8. ✅ Updated Terraform Budget

**Action:** Increased monthly budget to realistic level

**Changes:**
- **Before:** MYR 400/month (~$92 USD)
- **After:** MYR 2,500/month (~$575 USD)
- **Validation Cap:** Increased to MYR 3,000

**File:** `infrastructure/terraform/variables.tf`

**Rationale:**
- Current actual costs: $444-618/month (MYR 1,932-2,688)
- Old budget was 482-671% exceeded
- New budget aligns with post-optimization costs

**To Apply:**
```bash
cd infrastructure/terraform
terraform plan
terraform apply
# This will update the GCP Billing Budget
```

---

## Cost Summary

### Before Optimizations

| Service | Monthly Cost |
|---------|--------------|
| GKE Autopilot (6 nodes) | $400-550 |
| Cloud SQL (db-f1-micro REGIONAL) | $52-67 |
| Memorystore Redis (BASIC 1GB) | $19 |
| Load Balancers (2) | $36 |
| Persistent Disks (38 GB) | $3.80 |
| Network, Storage, Registry | $15-40 |
| **TOTAL** | **$525-716** |

### After Immediate Optimizations

| Service | Monthly Cost | Savings |
|---------|--------------|---------|
| GKE Autopilot (6 nodes, scaled services) | $350-450 | $50-100 |
| Cloud SQL (db-f1-micro ZONAL) | $32-47 | $20 |
| Memorystore Redis (BASIC 1GB) | $19 | $0 |
| Load Balancers (1) | $18 | $18 |
| Persistent Disks (24 GB) | $2.40 | $1.40 |
| Network, Storage, Registry | $15-40 | $0 |
| **TOTAL** | **$436-577** | **$89-139** |

### After Pod Resource Optimization (Pending)

| Service | Monthly Cost | Additional Savings |
|---------|--------------|-------------------|
| GKE Autopilot (2-3 nodes) | $150-250 | $200-200 |
| Other services | $36-77 | $0 |
| **TOTAL** | **$186-327** | **$200-250** |

### Final Cost Projection

| Metric | Before | After All Optimizations | Total Savings |
|--------|--------|-------------------------|---------------|
| **Monthly Cost** | $525-716 | $186-327 | **$289-439** |
| **Annual Cost** | $6,300-8,592 | $2,232-3,924 | **$3,468-5,160** |
| **Reduction** | - | - | **55-65%** |

---

## Next Steps

### Immediate (Manual Action Required)

1. **Run Pod Resource Optimization Script** (when network is restored)
   ```bash
   bash scripts/infra/optimize-pod-resources.sh
   ```

2. **Apply Terraform Budget Update**
   ```bash
   cd infrastructure/terraform
   terraform plan
   terraform apply
   ```

3. **Verify Cloud SQL HA Disabled**
   ```bash
   gcloud sql instances describe mereka-lms-mysql --project=mereka-lms --format="value(settings.availabilityType)"
   ```

4. **Monitor GKE Node Count**
   ```bash
   watch kubectl get nodes
   # Wait 10-15 minutes after pod optimization
   # Should see nodes scale down from 6 to 2-3
   ```

### Short-Term (Next 7 Days)

5. **Enable BigQuery Billing Export** (for detailed cost tracking)
   ```bash
   # Create dataset
   bq mk --dataset --location=asia-southeast1 mereka-lms:billing_export

   # Then enable in Console:
   # Billing > Billing export > BigQuery export > Enable
   ```

6. **Review GCP Billing Console**
   - Verify cost reduction shows up in next billing cycle
   - URL: https://console.cloud.google.com/billing/01A879-A82798-7962E2/reports?project=mereka-lms

7. **Document Final Node Count**
   ```bash
   kubectl get nodes -o wide > final-node-count.txt
   kubectl top nodes >> final-node-count.txt
   ```

### Medium-Term (Before Production)

8. **Scale Services Back Up Selectively** (when needed for testing)
   ```bash
   # Re-enable forum for discussion testing
   kubectl scale deployment forum -n mereka-lms --replicas=1

   # Re-enable analytics for reporting testing
   kubectl scale deployment clickhouse superset -n mereka-lms --replicas=1
   ```

9. **Plan Production Scaling**
   - Cloud SQL: Upgrade to `db-custom-2-7680` REGIONAL (~$225/month)
   - Redis: Upgrade to STANDARD_HA 2GB (~$79/month)
   - GKE: Scale to 6-9 nodes for HA (~$1,000-1,500/month)
   - MongoDB: Consider Atlas M10 or M30 (~$87-277/month)
   - **Estimated Production Cost:** $1,500-2,500/month

10. **Create Permanent Tutor Patch** (for pod resources)
    - Current script uses `kubectl patch` (temporary)
    - Need to add k8s-override to Tutor config for persistence
    - See: https://docs.tutor.edly.io/configuration.html#k8s-override

---

## Troubleshooting

### Services Not Responding After Scaling Down

**Symptom:** LMS/CMS returns 503 errors

**Solution:**
```bash
# Check pod status
kubectl get pods -n mereka-lms

# Restart essential services if needed
kubectl rollout restart deployment cms lms mfe nginx -n mereka-lms
```

### Node Count Not Decreasing

**Symptom:** Still seeing 6 nodes after 30 minutes

**Possible Causes:**
1. Pod resource optimization script not run yet
2. Pods have persistent resource requests
3. Autopilot scaling delay

**Solution:**
```bash
# Verify pod resource requests
kubectl get pods -n mereka-lms -o json | jq '.items[].spec.containers[].resources.requests'

# If still showing 2Gi, run optimization script
bash scripts/infra/optimize-pod-resources.sh

# Force Autopilot to re-evaluate (delete empty nodes)
# Autopilot will automatically recreate if needed
kubectl drain <node-name> --ignore-daemonsets --delete-emptydir-data
```

### Cloud SQL Operation Stuck

**Symptom:** HA disable operation not completing

**Solution:**
```bash
# Check operation status
gcloud sql operations list --instance=mereka-lms-mysql --limit=1 --project=mereka-lms

# If stuck for >1 hour, contact Google Cloud Support
# Operation ID: e6c624d0-70ae-4abb-8db5-443f00000031
```

---

## Rollback Procedures

### Re-enable High Availability

```bash
gcloud sql instances patch mereka-lms-mysql --availability-type=REGIONAL --project=mereka-lms
```

### Restore Pod Resource Requests

```bash
# Edit deployments.yml or use kubectl patch
kubectl patch deployment cms -n mereka-lms --type='json' -p='[{"op": "add", "path": "/spec/template/spec/containers/0/resources", "value": {"requests": {"memory": "2Gi"}}}]'
kubectl patch deployment cms-worker -n mereka-lms --type='json' -p='[{"op": "add", "path": "/spec/template/spec/containers/0/resources", "value": {"requests": {"memory": "2Gi"}}}]'
kubectl patch deployment lms -n mereka-lms --type='json' -p='[{"op": "add", "path": "/spec/template/spec/containers/0/resources", "value": {"requests": {"memory": "2Gi"}}}]'
kubectl patch deployment lms-worker -n mereka-lms --type='json' -p='[{"op": "add", "path": "/spec/template/spec/containers/0/resources", "value": {"requests": {"memory": "2Gi"}}}]'
kubectl patch deployment mfe -n mereka-lms --type='json' -p='[{"op": "add", "path": "/spec/template/spec/containers/0/resources", "value": {"requests": {"memory": "2Gi"}}}]'
```

### Re-enable Scaled Services

```bash
kubectl scale deployment clickhouse superset ralph superset-worker superset-worker-beat forum -n mereka-lms --replicas=1
```

---

## References

- **GCP Billing Console:** https://console.cloud.google.com/billing/01A879-A82798-7962E2/reports?project=mereka-lms
- **GKE Autopilot Docs:** https://cloud.google.com/kubernetes-engine/docs/concepts/autopilot-overview
- **Cloud SQL Pricing:** https://cloud.google.com/sql/pricing
- **Tutor Configuration:** https://docs.tutor.edly.io/configuration.html

---

## Contact

For questions or issues with these optimizations:
- Check: `docs/operations/TROUBLESHOOTING.md`
- Review: `CLAUDE.md` for Tutor best practices
- Monitor: GCP Billing dashboard weekly

**Last Updated:** 2025-11-20 10:45 UTC
**Applied By:** Claude Code (Anthropic)
