# GKE Autopilot Cost Estimate
_Last updated: 2025-11-12_

## Current Infrastructure

### GKE Autopilot Cluster
- **Region**: asia-southeast1 (Singapore)
- **Nodes**: 9 nodes (managed by Autopilot)
- **Profile**: Standard (default)
- **CPU Usage**: ~6.3% average
- **Memory Usage**: ~9.2% average

### Cloud SQL for MySQL
- **Instance**: `mereka-lms-mysql`
- **Tier**: `db-custom-2-7680` (2 vCPU, 7.5GB RAM)
- **Storage**: 100GB PD-SSD
- **Region**: asia-southeast1

### Cloud Memorystore for Redis
- **Instance**: `mereka-lms-redis`
- **Tier**: STANDARD_HA (High Availability)
- **Memory**: 2GB
- **Region**: asia-southeast1

### Persistent Volumes
- **Count**: 5 PVCs
- **Total Storage**: ~33GB

### Static IP
- **NAT IP**: 34.142.147.42 (asia-southeast1)

---

## Monthly Cost Estimate

### GKE Autopilot
**Pricing**: $0.10 per vCPU-hour, $0.01125 per GB-hour

Based on current usage:
- **9 nodes** × average resources per node
- Autopilot automatically scales, but we can estimate based on requests:
  - Total CPU requests: ~10.6 cores
  - Total Memory requests: ~0.04GB (calculation seems off - likely much higher)

**Estimated**: ~$700-900/month
- This is a rough estimate as Autopilot pricing depends on actual resource consumption
- With 9 nodes running, even at low utilization, base costs apply

### Cloud SQL MySQL
**Pricing**:
- **Instance**: `db-custom-2-7680`
  - 2 vCPU: ~$0.10/hour × 730 hours = **$146/month**
  - 7.5GB RAM: ~$0.01125/GB-hour × 7.5 × 730 = **$61.59/month**
  - 100GB SSD: ~$0.17/GB-month = **$17/month**
- **High Availability**: Included in STANDARD_HA tier
- **Backups**: First 100GB free, then ~$0.08/GB-month

**Subtotal**: ~$225/month

### Cloud Memorystore Redis
**Pricing**:
- **STANDARD_HA tier**: ~$0.054/GB-hour × 2GB × 730 hours = **$78.84/month**
- **High Availability**: Included

**Subtotal**: ~$79/month

### Persistent Disk Storage
- **33GB PD-SSD**: ~$0.17/GB-month = **$5.61/month**

### Static IP (NAT)
- **Reserved IP**: ~$0.004/hour × 730 = **$2.92/month**

### Network Egress
- **Data transfer**: Varies by usage
- **Estimated**: ~$10-50/month (depends on traffic)

---

## Total Monthly Estimate

### Before Optimization
| Component | Monthly Cost |
|-----------|--------------|
| GKE Autopilot (9 nodes) | $700-900 |
| Cloud SQL MySQL | $225 |
| Cloud Memorystore Redis | $79 |
| Persistent Disks | $6 |
| Static IP | $3 |
| Network Egress | $10-50 |
| **TOTAL** | **~$1,023 - $1,263/month** |

### After Optimization (Development)
| Component | Monthly Cost |
|-----------|--------------|
| GKE Autopilot (2-3 nodes, auto-scaled) | $400-600 |
| Cloud SQL MySQL (db-f1-micro) | $4 |
| Cloud Memorystore Redis | $79 (or $19 if optimized) |
| Persistent Disks | $6 |
| Static IP | $3 |
| Network Egress | $10-50 |
| **TOTAL** | **~$502 - $748/month** |
| **SAVINGS** | **~$480-580/month** |

---

## Cost Optimization Recommendations

1. **Reduce GKE Nodes**: Current 9 nodes with low utilization (6% CPU, 9% memory) suggests over-provisioning
   - Consider: Right-size node pools or reduce node count
   - Potential savings: $200-400/month

2. **Cloud SQL Optimization**: 
   - Current: 2 vCPU, 7.5GB RAM
   - If underutilized, consider: `db-custom-1-3840` (1 vCPU, 3.75GB RAM)
   - Potential savings: ~$100/month

3. **Redis Optimization**:
   - Current: 2GB STANDARD_HA
   - If underutilized, consider: 1GB or BASIC tier
   - Potential savings: ~$40/month

4. **Autopilot vs Standard**: 
   - Autopilot adds ~20-30% premium for management
   - Standard GKE with node pools might be cheaper for predictable workloads
   - Potential savings: $100-200/month

5. **Storage Optimization**:
   - Review unused PVCs
   - Use standard persistent disks instead of SSD where possible
   - Potential savings: ~$5-10/month

---

## Notes

- **Actual costs may vary** based on:
  - Actual resource consumption (Autopilot bills on usage)
  - Network egress volume
  - Backup storage
  - Regional pricing differences

- **To get exact costs**:
  ```bash
  gcloud billing accounts list
  gcloud billing projects describe mereka-lms
  # View in GCP Console: Billing > Reports
  ```

- **Monitor costs**:
  - Set up billing alerts in GCP Console
  - Review monthly billing reports
  - Use Cost Management tools in GCP

---

## Next Steps

1. Review actual GCP billing dashboard for precise costs
2. Analyze resource utilization over 7-30 days
3. Implement cost optimization recommendations
4. Set up billing alerts for budget thresholds

