# GKE Workload Evidence Triage (3k2i)

> Non-core pod failure analysis and remediation for GKE production cluster.
>
> **Bead**: mereka-lms-3k2i
> **Date**: 2026-02-18
> **Cluster**: gke_bbi-k8_asia-southeast1-c_bbi-k8-cluster
> **ArgoCD App**: mereka-lms-prod (Synced / Healthy)

## Pod Status Summary

### Core Services (all healthy)

| Pod | Status | Restarts | Age |
|-----|--------|----------|-----|
| lms (x2) | Running 1/1 | 0 | 16h |
| lms-worker | Running 1/1 | 0 | 16h |
| cms | Running 1/1 | 0 | 16h |
| cms-worker | Running 1/1 | 0 | 16h |
| caddy | Running 1/1 | 0 | 15h |
| mfe | Running 1/1 | 0 | 35h |
| mysql | Running 2/2 | 0 | 2d7h |
| redis | Running 2/2 | 0 | 2d7h |
| smtp | Running 1/1 | 0 | 2d8h |
| meilisearch | Running 1/1 | 0 | 2d8h |
| elasticsearch | Running 1/1 | 0 | 2d8h |
| discovery | Running 1/1 | 0 | 2d8h |
| ecommerce | Running 1/1 | 0 | 2d8h |
| ecommerce-worker | Running 1/1 | 0 | 2d8h |
| credentials | Running 1/1 | 0 | 35h |
| notes | Running 1/1 | 0 | 2d8h |
| xqueue | Running 2/2 | 0 | 2d8h |
| payments-gateway | Running 1/1 | 1 | 4d10h |
| postgresql-payments | Running 1/1 | 0 | 4d22h |
| license-manager | Running 1/1 | 1 | 4d10h |
| promtail (x3) | Running 1/1 | 0-1 | 5d |

### Enterprise Services (all healthy)

| Pod | Status | Restarts | Age |
|-----|--------|----------|-----|
| enterprise-access | Running 1/1 | 5 | 5d10h |
| enterprise-access-worker | Running 1/1 | 0 | 5d10h |
| enterprise-admin-portal | Running 1/1 | 0 | 5d10h |
| enterprise-catalog | Running 1/1 | 5 | 5d9h |
| enterprise-catalog-worker | Running 1/1 | 0 | 5d9h |
| enterprise-learner-portal | Running 1/1 | 0 | 5d10h |
| enterprise-subsidy | Running 1/1 | 5 | 5d10h |

### Non-Core Failures (investigated)

| Pod | Status | Root Cause | Category |
|-----|--------|-----------|----------|
| **mux-delivery-monitor** | **CreateContainerConfigError** | Secret name mismatch: references `mereka-lms-runtime-secrets` but MUX tokens are in `openedx-secrets` | Monitoring |
| **auth-verify-prod** (3 old pods) | **Error** | Transient 502s during pod rollout window (Feb 17) — latest run all OK | CronJob |
| cert-verify-prod | Completed | Working correctly | CronJob |

## Root Cause Analysis

### RC-1: mux-delivery-monitor — Secret name mismatch (AC-BEADS-011)

**Cause**: The mux-delivery-monitor deployment references `mereka-lms-runtime-secrets` for `MUX_TOKEN_ID` and `MUX_TOKEN_SECRET`. However:
- `mereka-lms-runtime-secrets` only contains a `PLACEHOLDER` key (no actual data)
- The MUX tokens are provisioned via ExternalSecret into `openedx-secrets`
- The deployment was created referencing the wrong secret name

**Error**: `couldn't find key MUX_TOKEN_ID in Secret mereka-lms/mereka-lms-runtime-secrets`

**Fix applied**: Updated `deploy/k8s/base/monitoring/mux-exporter.yaml` to reference `openedx-secrets` instead of `mereka-lms-runtime-secrets`.

### RC-2: auth-verify-prod CronJob — Transient errors (AC-BEADS-010)

**Cause**: The auth-verify CronJob runs every 15 minutes, checking OIDC redirects, MFE config APIs, and service OAuth2 flows. Three pods from Feb 17 show `Error` status with 9 failed checks:

```
BAD https://academyv2.mereka.io/auth/login/oidc/ (expected 302, got 502)
BAD https://apps.academyv2.mereka.io/api/mfe_config/v1 (expected 200, got 502)
BAD https://credentials.academyv2.mereka.io/login/ (expected 302, got 500)
BAD https://forum.academyv2.mereka.io/ (expected 200, got 503)
```

These 502/503 errors correlate with the pod rollout that happened ~16h ago (all core pods show 16h age). The latest run (Feb 18 13:15) is **all OK (15/15 checks pass)**.

**Expected-state policy**: CronJob errors during pod rollouts are **expected transient behavior**, not regressions. The CronJob's `successfulJobsHistoryLimit` and `failedJobsHistoryLimit` control how many old pods are retained. Old Error pods will be garbage-collected automatically.

**No fix needed**: The CronJob is working as designed — it surfaces transient downtime during deployments.

### RC-3: cert-verify-prod — Working correctly

The cert-verify CronJob runs every 6 hours and last completed successfully. No issues found.

## ArgoCD Status (AC-BEADS-012)

```
mereka-lms-prod  Synced  Healthy
```

The mux-delivery-monitor `CreateContainerConfigError` does not block ArgoCD health status. After the secret reference fix is deployed, the pod will start successfully.

## Resolution Summary

| Root Cause | Fix | Status | Priority |
|-----------|-----|--------|----------|
| RC-1: mux-delivery-monitor secret mismatch | Change secret ref from `mereka-lms-runtime-secrets` to `openedx-secrets` | **FIXED** (commit pending) | P2 |
| RC-2: auth-verify transient errors | Expected during rollouts — no fix needed, documented as policy | **DOCUMENTED** | P3 |
| RC-3: cert-verify | Working correctly | **OK** | — |

## Expected-State Policies

### CronJob Error Pods

**Policy**: CronJob pods showing `Error` status during or shortly after pod rollouts are **expected transient behavior**. Only investigate if:
1. Errors persist across 3+ consecutive runs (45+ minutes after rollout completes)
2. The latest run also shows errors
3. Error patterns don't correlate with a recent deployment

### mux-delivery-monitor

**Policy**: This pod monitors Mux video delivery health. If Mux credentials are not yet provisioned in GCP Secret Manager (`MEREKA_LMS_MUX_TOKEN_ID` / `MEREKA_LMS_MUX_TOKEN_SECRET`), the pod will fail with `CreateContainerConfigError`. This is acceptable if Mux video integration is not yet active.

## Verification Commands

```bash
# Check all pods
kubectl --context gke_bbi-k8_asia-southeast1-c_bbi-k8-cluster get pods -n mereka-lms

# Check auth-verify CronJob history
kubectl --context gke_bbi-k8_asia-southeast1-c_bbi-k8-cluster get pods -n mereka-lms | grep auth-verify

# Check latest auth-verify logs
kubectl --context gke_bbi-k8_asia-southeast1-c_bbi-k8-cluster logs -n mereka-lms $(kubectl --context gke_bbi-k8_asia-southeast1-c_bbi-k8-cluster get pods -n mereka-lms -l job-name --sort-by='.metadata.creationTimestamp' -o name | grep auth-verify | tail -1) --tail=20

# Check mux-delivery-monitor
kubectl --context gke_bbi-k8_asia-southeast1-c_bbi-k8-cluster describe pod -n mereka-lms -l app.kubernetes.io/name=mux-delivery-monitor

# ArgoCD status
kubectl --context gke_bbi-k8_asia-southeast1-c_bbi-k8-cluster get application -n argocd -o custom-columns='NAME:.metadata.name,SYNC:.status.sync.status,HEALTH:.status.health.status' | grep mereka-lms
```
