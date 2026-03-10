# Aspects Analytics - Kubernetes Deployment Guide
_Audience: Platform Eng • Owner: Analytics Guild • Last verified: 2025-11-09 • Status: superseded_
superseded_by: docs/concepts/analytics/ASPECTS_TARGET_STATE.md

This document has moved to:
- `docs/concepts/analytics/ASPECTS_TARGET_STATE.md`

This guide explains how to deploy Aspects Analytics on GKE Autopilot, addressing resource constraints.

## Problem

GKE Autopilot was unable to schedule Aspects services (ClickHouse and Superset) due to insufficient CPU/memory resources, causing CrashLoopBackOff.

## Solution Options

### Option 1: Configure Resource Requests (Recommended)

Aspects services need significant resources. For GKE Autopilot, we need to configure appropriate resource requests that Autopilot can provision.

**ClickHouse Requirements:**
- Memory: 2-4 GB minimum
- CPU: 1-2 cores minimum

**Superset Requirements:**
- Memory: 1-2 GB minimum  
- CPU: 0.5-1 core minimum

### Option 2: Use Cloud SQL for Superset Database

Instead of running Superset's MySQL in-cluster, use Cloud SQL to reduce resource pressure.

### Option 3: Deploy to Separate Standard GKE Cluster

For heavy analytics workloads, consider a separate standard GKE cluster with node pools sized for analytics.

## Quick Deployment (Recommended)

Use the deployment script:

```bash
./scripts/infra/deploy-aspects-k8s.sh
```

This script will:
1. Configure Aspects with appropriate resource limits for Autopilot
2. Generate Kubernetes manifests
3. Deploy Aspects services
4. Monitor deployment status

## Manual Deployment Steps

### 1. Check Current Cluster Capacity

```bash
# Check current resource usage
kubectl top nodes -n mereka-lms
kubectl top pods -n mereka-lms

# Check Autopilot resource limits
gcloud container clusters describe mereka-lms \
  --region=asia-southeast1 \
  --format="value(autopilot.resourceLimits)"
```

### 2. Configure Aspects Resource Requests

Edit Aspects configuration to set appropriate resource requests:

```bash
source infrastructure/tutor/tutor-env.sh

# Set resource limits for Aspects services
tutor config save \
  --set ASPECTS_CLICKHOUSE_MEMORY_LIMIT=4Gi \
  --set ASPECTS_CLICKHOUSE_CPU_LIMIT=2 \
  --set ASPECTS_SUPERSET_MEMORY_LIMIT=2Gi \
  --set ASPECTS_SUPERSET_CPU_LIMIT=1 \
  --set ASPECTS_RALPH_MEMORY_LIMIT=512Mi \
  --set ASPECTS_RALPH_CPU_LIMIT=500m

# Regenerate Kubernetes manifests
tutor k8s init
```

### 3. Deploy Aspects Services

```bash
# Deploy only Aspects services
kubectl apply -k tutor_env/env/k8s \
  --selector app.kubernetes.io/name=clickhouse

kubectl apply -k tutor_env/env/k8s \
  --selector app.kubernetes.io/name=superset

kubectl apply -k tutor_env/env/k8s \
  --selector app.kubernetes.io/name=ralph

# Or deploy all Aspects-related services
kubectl apply -k tutor_env/env/k8s \
  --selector app.kubernetes.io/part-of=aspects
```

### 4. Monitor Deployment

```bash
# Watch pod status
kubectl get pods -n mereka-lms -w | grep -E "(clickhouse|superset)"

# Check events for scheduling issues
kubectl get events -n mereka-lms --sort-by='.lastTimestamp' | grep -i aspects

# Check logs if pods fail
kubectl logs -n mereka-lms deployment/clickhouse --tail=50
kubectl logs -n mereka-lms deployment/superset --tail=50
```

## Troubleshooting

### Pods Stuck in Pending

If pods remain in `Pending` state:

```bash
# Check why pods can't be scheduled
kubectl describe pod <pod-name> -n mereka-lms | grep -A 10 Events

# Common issues:
# - Insufficient resources (reduce requests)
# - Node selector mismatches
# - Taints/tolerations
```

### CrashLoopBackOff

If pods crash repeatedly:

```bash
# Check logs
kubectl logs -n mereka-lms <pod-name> --previous

# Common causes:
# - Database connection failures
# - Memory limits too low
# - Missing secrets/configmaps
```

### Resource Quota Exceeded

If Autopilot can't provision resources:

1. **Reduce resource requests** (may affect performance)
2. **Request quota increase** via GCP Console
3. **Use Cloud SQL** for Superset database (reduces in-cluster resources)

## Alternative: Use Cloud SQL for Superset

To reduce resource pressure, configure Superset to use Cloud SQL:

```bash
# Get Cloud SQL connection name
gcloud sql instances describe <instance-name> \
  --format="value(connectionName)"

# Update Tutor config
tutor config save \
  --set ASPECTS_SUPERSET_DB_HOST="<cloud-sql-connection-name>" \
  --set ASPECTS_SUPERSET_DB_ENGINE=cloudsql

# Regenerate and deploy
tutor k8s quickstart --non-interactive
kubectl apply -k tutor_env/env/k8s --selector app.kubernetes.io/name=superset
```

## Verification

Once deployed, verify Aspects is working:

```bash
# Check all Aspects pods are running
kubectl get pods -n mereka-lms | grep -E "(clickhouse|superset|ralph)"

# Port-forward to access Superset locally
kubectl port-forward -n mereka-lms svc/superset 8088:8088

# Access at http://localhost:8088
```

## Resource Recommendations

For production workloads:

| Service | Memory | CPU | Notes |
|---------|--------|-----|-------|
| ClickHouse | 4-8 GB | 2-4 cores | Data warehouse, needs more resources |
| Superset | 2-4 GB | 1-2 cores | Dashboard UI, moderate resources |
| Ralph (event routing) | 512 MB | 0.5 cores | Lightweight event processor |

Start with minimums and scale up based on usage.

## Next Steps

1. ✅ Configure resource requests appropriate for Autopilot
2. ✅ Deploy Aspects services
3. ✅ Monitor resource usage
4. ✅ Scale up if needed based on actual usage
5. ✅ Consider Cloud SQL for Superset database if resources remain tight
