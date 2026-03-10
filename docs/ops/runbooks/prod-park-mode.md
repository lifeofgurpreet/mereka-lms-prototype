# Production Park-Mode Runbook
_Audience: Platform Eng + SRE • Owner: Engineering Lead • Last updated: 2026-02-18_

**Purpose**: Safely suspend GKE prod LMS compute to reduce cost while preserving all data.
**Risk**: Site unavailable during park. Data plane stays up; no data loss.
**Reversibility**: Full — revert a single GitOps commit, ArgoCD restores in 5–10 min.

---

## What "Warm-Park" Means

| Component | Park state | Why |
|-----------|-----------|-----|
| mysql | **Running** (1/1) | Data plane — course + user data |
| redis | **Running** (1/1) | Data plane — sessions + celery broker |
| postgresql-payments | **Running** (1/1) | Data plane — purchase gateway data |
| promtail | **Running** (DaemonSet) | Log forwarding — needed for audit trail |
| mux-delivery-monitor | **Running** (1/1) | Monitoring — kept small |
| LMS / CMS / workers | **Parked** (0/0) | Stateless — restore from image |
| MFE / Caddy | **Parked** (0/0) | Stateless — restore from image |
| Enterprise services | **Parked** (0/0) | Stateless — restore from image |
| Elasticsearch / Meilisearch | **Parked** (0/0) | Search index — rebuilds on startup |
| Notes / SMTP / xqueue | **Parked** (0/0) | Stateless — restore from image |
| HPAs (lms, cms) | **Deleted** | Prevents replica-count conflicts |

**Data risk**: None. MySQL, Redis, PostgreSQL PVCs remain Bound and are backed up by Velero.

---

## Velero Backup Schedule (must be active before parking)

| Schedule | Frequency | Last backup |
|----------|-----------|-------------|
| velero-local-hourly-critical-databases | Every hour | Check before parking |
| velero-local-daily-all-apps | Daily 18:00 UTC | Check before parking |
| velero-local-weekly-full | Sunday 19:00 UTC | Weekly |

**Verify before parking:**
```bash
kubectl get backup -n velero | grep hourly-critical | tail -3
```

---

## Park Procedure

### Option A: Automated (recommended)

```bash
cd <repo-root>
./scripts/ops/park-prod.sh --dry-run  # Preview first
./scripts/ops/park-prod.sh
```

### Option B: Manual GitOps

1. Create `https://github.com/Biji-Biji-Initiative/BBI-K8/blob/main/apps/mereka-lms/overlays/prod/patches/warm-park-mode.yaml`:
   ```yaml
   # See scripts/ops/park-prod.sh for full content
   ```

2. Add to `kustomization.yaml` under `patchesStrategicMerge`:
   ```yaml
   patchesStrategicMerge:
     - patches/warm-park-mode.yaml
   ```

3. Commit and push to GitOps repo (`infrastructure`):
   ```bash
   cd <path-to-bbi-infrastructure>
   git add apps/mereka-lms/overlays/prod/
   git commit -m "ops(mereka-lms): warm-park prod for cost savings"
   git push origin main
   ```

4. ArgoCD auto-syncs within 3 minutes. Monitor:
   ```bash
   kubectl get deploy -n mereka-lms -w
   ```

### Verify parked state

```bash
# All stateless deployments show 0/0
kubectl get deploy -n mereka-lms

# Data plane still running
kubectl get pods -n mereka-lms | grep -E 'mysql|redis|postgresql'

# Site returns 503 (expected — no backend)
curl -Isk https://academyv2.mereka.io/ | head -1
```

---

## Unpark Procedure

### Option A: Automated (recommended)

```bash
cd <repo-root>
./scripts/ops/unpark-prod.sh --dry-run  # Preview first
./scripts/ops/unpark-prod.sh
```

### Option B: Manual GitOps

1. Remove `warm-park-mode.yaml` from GitOps repo overlay:
   ```bash
   rm apps/mereka-lms/overlays/prod/patches/warm-park-mode.yaml
   ```

2. Remove reference from `kustomization.yaml` (`patchesStrategicMerge` section).

3. Commit and push:
   ```bash
   git add apps/mereka-lms/overlays/prod/
   git commit -m "ops(mereka-lms): unpark prod — restore LMS workloads"
   git push origin main
   ```

4. Monitor restoration:
   ```bash
   # Watch pods come up (takes 5–10 min including image pull)
   kubectl get pods -n mereka-lms -w

   # Watch deployments go 0→1
   watch kubectl get deploy -n mereka-lms
   ```

### Post-unpark verification

```bash
# Site is up
curl -sk https://academyv2.mereka.io/ | head -c 200
curl -sk -o /dev/null -w '%{http_code}\n' https://studio.academyv2.mereka.io/
curl -sk -o /dev/null -w '%{http_code}\n' https://admin.academyv2.mereka.io/

# Forum heartbeat
curl -sk https://forum.academyv2.mereka.io/heartbeat

# LMS health
curl -sk https://academyv2.mereka.io/api/user/v1/me
# Expected: 401 (no auth) = LMS is responding

# Enterprise access health
curl -sk https://admin.academyv2.mereka.io/api/enterprise-access/health/
# Expected: {"overall_status": "OK", ...}
```

---

## Rollback (Emergency)

If unpark fails or site doesn't come up after 15 minutes:

```bash
# Check ArgoCD sync status
kubectl get application mereka-lms-prod -n argocd -o jsonpath='{.status.sync.status}'

# Force ArgoCD sync
kubectl annotate application mereka-lms-prod -n argocd \
  argocd.argoproj.io/refresh=hard --overwrite

# Check pod events
kubectl describe deploy lms -n mereka-lms | tail -20

# Restore from Velero (data loss recovery only — not needed for unpark)
velero restore create --from-backup velero-local-hourly-critical-databases-<LATEST> \
  --include-namespaces mereka-lms \
  --restore-volumes=true
```

---

## Cost Impact

| Mode | GKE Node Pool | Monthly Estimate |
|------|--------------|-----------------|
| Full operation | 3+ n2-standard-4 nodes | ~RM 3,000–4,000/mo |
| Warm-park | 1–2 n2-standard-4 nodes (data plane only) | ~RM 800–1,200/mo |
| Estimated saving | — | ~RM 1,800–2,800/mo |

*Actual savings depend on GKE autoscaler behavior and node pool configuration.*

---

## Implementation Details

**GitOps mechanism**: `warm-park-mode.yaml` is a kustomize strategic merge patch that sets
`replicas: 0` for all stateless deployments. ArgoCD applies it within 3 minutes of merge.

**HPA conflict**: The patch deletes the LMS and CMS HPAs (`$patch: delete`). Without deletion,
the HPA would immediately scale replicas back up from 0 to its `minReplicas`.

**Data integrity**: The park patch only controls replica counts; it does not touch PVCs,
ConfigMaps, Secrets, or Services. Database connections re-establish on unpark.

**Session state**: Redis (sessions) remains running during park. Sessions remain valid.
Users may experience a brief 503 during park, and a ~5-10 min outage during unpark,
but their login sessions are preserved.

---

## History

| Date | Action | Actor | Evidence |
|------|--------|-------|---------|
| 2026-02-21 | Warm-park activated (commit b26cdea) | infrastructure (another agent) | `docs/archive/evidence/operations/evidence/deploy/20260221-000000/park-mode-evidence.md` |
