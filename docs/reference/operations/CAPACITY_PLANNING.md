# Capacity Planning — Mereka Academy
_Audience: Engineering + SRE | Owner: Engineering Lead | Last updated: 2026-02-25_

## Current Cluster

GKE single-node (cost-optimised), namespace `mereka-lms`. Target cohort: **< 1 000 active learners**.
MongoDB Atlas (off-cluster), Cloud SQL (production) or in-cluster PostgreSQL (payments).

---

## Resource Allocation Per Service

| Service | CPU Request | CPU Limit | Mem Request | Mem Limit | SLO Tier |
|---------|------------|-----------|-------------|-----------|-----------|
| lms | 10m | 2 | 128Mi | 2Gi | 1 |
| lms-worker | 10m | 1 | 128Mi | 2Gi | 1 |
| cms | 10m | 1 | 128Mi | 1.5Gi | 2 |
| cms-worker | 10m | 1 | 128Mi | 2Gi | 2 |
| caddy | 5m | 250m | 16Mi | 128Mi | 2 |
| mfe | 5m | 250m | 16Mi | 128Mi | 2 |
| mysql | 10m | 2 | 128Mi | 2Gi | 1 |
| redis | 5m | 250m | 16Mi | 128Mi | 1 |
| meilisearch | 5m | 500m | 32Mi | 512Mi | 3 |
| discovery | 5m | 500m | 64Mi | 512Mi | 3 |
| payments-gateway | — | — | — | — | 1 |
| postgresql-payments | — | — | — | — | 1 |

> Note: requests are intentionally minimal (cluster at ~99% CPU headroom). Limits provide OOM/CPU ceiling protection. Requests will be tuned upward when load-test baselines are established.

---

## HPA Configuration

| Deployment | Min | Max | Trigger | Scale-up delay | Scale-down delay |
|-----------|-----|-----|---------|---------------|-----------------|
| lms | 2 | 4 | 200m CPU (AverageValue) | 60 s | 300 s |
| cms | 1 | 3 | 100m CPU (AverageValue) | — | 300 s |
| lms-worker | 1 | 3 | 80% CPU Utilization | — | 300 s |
| cms-worker | 1 | 2 | 80% CPU Utilization | — | 300 s |
| enterprise-catalog | 1 | 3 | 70% CPU Utilization | — | 300 s |
| enterprise-access | 1 | 3 | 70% CPU Utilization | — | 300 s |
| enterprise-subsidy | 1 | 3 | 70% CPU Utilization | — | 300 s |
| license-manager | 1 | 3 | 70% CPU Utilization | — | 300 s |
| payments-gateway | 1 | 3 | 70% CPU Utilization | — | 300 s |

**Thresholds rationale:**
- LMS uses absolute `averageValue` (200m) because requests are low (10m), making `%Utilization` meaningless.
- Workers use 80% utilization — Celery tasks are CPU-burst; scaling earlier causes unnecessary churn.
- Enterprise services use 70% utilization to maintain headroom for request spikes.
- Scale-down stabilisation of 300 s prevents flapping after short traffic spikes.

---

## Load Test Baseline

Open edX standard throughput per uWSGI pod (4 workers):

| Service | Concurrent users/pod | p95 latency target | Basis |
|---------|---------------------|--------------------|-------|
| LMS | ~50 | < 1 s | Open edX community benchmark |
| CMS/Studio | ~10 | < 3 s | Authoring workload (heavy DB) |
| MFE (Caddy) | ~200 | < 500 ms | Static assets + thin proxy |
| payments-gateway | ~30 | < 1 s | FastAPI async, DB-bound |

At **LMS max replicas = 4 pods × 50 users = 200 concurrent users** supported before horizontal expansion is required. For > 200 concurrent users, raise `maxReplicas` and re-evaluate node size.

---

## Cost Model (GKE — asia-southeast1)

Approximate costs based on GKE e2-standard-4 (4 vCPU, 16 GB RAM, ~$0.13/hr spot).

| Cost Driver | Monthly (USD) | Per 1 000 learners |
|-------------|--------------|-------------------|
| GKE node (1× e2-standard-4 spot) | ~$95 | ~$95 |
| Cloud SQL (db-g1-small, 10 GB) | ~$30 | ~$30 |
| MongoDB Atlas M10 | ~$57 | ~$57 |
| Artifact Registry + egress | ~$5 | ~$5 |
| GCP Secret Manager + ESO | < $1 | < $1 |
| **Total (< 1 000 learners)** | **~$188** | **~$0.19/learner/month** |

**Scaling steps:**

| Active learners | Recommended change | Estimated monthly |
|----------------|-------------------|-------------------|
| < 1 000 | Current (1 node, spot) | ~$188 |
| 1 000–3 000 | Add 1 node OR upgrade to e2-standard-8 | ~$280 |
| 3 000–10 000 | 3-node pool, Cloud SQL upgrade, Atlas M20 | ~$550 |
| > 10 000 | Dedicated node pools (LMS vs workers), PodDisruptionBudgets | ~$1 200+ |

---

## Scaling Policy

### When to Scale Out
- LMS HPA at `maxReplicas` for > 15 minutes during business hours → increase `maxReplicas` by 2.
- p99 LMS latency > 2 s over a 30-minute window → investigate worker count and DB query performance.
- MySQL or Redis memory > 80% for > 1 hour → upgrade node or migrate to managed service.

### When to Scale In
- Average CPU across all LMS pods < 20% for 48 hours → reduce `minReplicas` by 1 (minimum 2).
- Monthly cost > 1.5× the per-learner model projection → audit idle workloads.

### Resource Request Adjustment Trigger
If actual pod CPU or memory regularly hits > 70% of the current limit, double the request for that container and re-run verification. Requests that are too low cause the scheduler to pack pods onto nodes until OOM evictions occur.

---

## Quarterly Review Checklist

Run at the start of each quarter:

- [ ] Pull actual resource usage: `kubectl top pods -n mereka-lms --sort-by=cpu`
- [ ] Compare LMS p99 latency trend (Grafana SLO dashboard) vs. the 2 s target
- [ ] Review HPA event history: `kubectl describe hpa lms -n mereka-lms`
- [ ] Check MongoDB Atlas metrics for IOPS and connection count growth
- [ ] Recalculate cost/learner from GCP billing export vs. active learner count
- [ ] Update `maxReplicas` for any service that hit its ceiling more than once
- [ ] Validate that requests/limits in `deploy/k8s/overlays/production/patches/resource-limits.yaml` match observed baselines
- [ ] Run load test if learner count has grown > 20% since last review

---

## Related Resources

- HPA configs: `deploy/k8s/base/apps/lms/hpa.yaml`, `apps/cms/hpa.yaml`, `base/operational/hpa-baselines.yaml`, `base/monitoring/hpa-enterprise.yaml`
- Resource limits: `deploy/k8s/overlays/production/patches/resource-limits.yaml`
- SLO targets: `docs/policies/operations/SLO_POLICY.md`
- Troubleshooting: `docs/runbooks/operations/TROUBLESHOOTING.md`
