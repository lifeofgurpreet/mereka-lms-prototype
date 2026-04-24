# RKE2 LMS Cross-Repo Handoff Pack

> LMS-specific migration touchpoints for the nonprod RKE2 cluster.
>
> **Bead**: mereka-lms-2j6g
> **Date**: 2026-02-18
> **RKE2 Cluster**: `rke2-nonprod` (single-node, v1.34.3+rke2r3)
> **GKE Cluster**: `gke_bbi-k8_asia-southeast1-c_bbi-k8-cluster` (production, untouched)

## 1. Current State Summary

### Cluster Topology

| Cluster | Context | Role | LMS Status |
|---------|---------|------|------------|
| GKE (`bbi-k8-cluster`) | `gke_bbi-k8_asia-southeast1-c_bbi-k8-cluster` | **PRODUCTION** — do not touch | Running (Synced/Healthy) |
| Kind VPS | `kind-dev` | Development/local | Running (OutOfSync, fixes pending sync) |
| RKE2 nonprod | `rke2-nonprod` | **Staging/nonprod target** | **NOT YET DEPLOYED** |

### RKE2 Cluster Bootstrap Status (as of 2026-02-18)

| Component | Namespace | Status | Gate |
|-----------|-----------|--------|------|
| ArgoCD | `argocd` | Synced/Healthy | Gate 1 (bootstrap) |
| cert-manager | `cert-manager` | Synced/Healthy | Gate 2 (platform essentials) |
| ingress-nginx | `ingress-nginx` | Synced/Healthy | Gate 2 |
| external-secrets | `external-secrets` | Synced/Healthy | Gate 2 |
| metrics-server | `kube-system` | Synced/Healthy | Gate 2 |
| monitoring CRDs | `monitoring` | Synced/Healthy | Gate 2 |
| monitoring stack | `monitoring` | Synced/Healthy | Gate 2 |
| velero | `velero` | Synced/Healthy | Gate 2 |
| kyverno | `kyverno` | Synced/Healthy | Gate 2 |
| nonprod-guardrails | — | Synced/Healthy | Gate 0 (lock) |
| mereka-dev-bootstrap | — | OutOfSync/Degraded | Gate 1 |

### Non-LMS Mereka Apps (already deployed to `mereka-dev` namespace)

| App | Status |
|-----|--------|
| mereka-admin | Running 1/1 |
| mereka-app | Running 1/1 |
| mereka-auth | Running 1/1 |
| mereka-checkout | Running 1/1 |
| mereka-web | Running 1/1 |

**LMS is absent from the RKE2 cluster.** The `mereka-lms` staging overlay exists in infrastructure but is disabled (empty `kustomization.yaml` with `resources: []`).

---

## 2. Data-Plane Contract (AC-RKE2-002)

### Hostnames and Domains

| Service | GKE Production | RKE2 Staging (planned) |
|---------|---------------|----------------------|
| LMS | `academyv2.mereka.io` | TBD — likely `lms.staging.mereka.dev` or similar |
| Studio (CMS) | `studio.academyv2.mereka.io` | TBD — `studio.staging.mereka.dev` |
| MFE apps | `apps.academyv2.mereka.io` | TBD — `apps.staging.mereka.dev` |
| Alt domain | `academy.biji-biji.com` | N/A (production only) |
| Authentik SSO | `auth0.mereka.io` | Shared or `auth.staging.mereka.dev` |

**DNS**: Staging domains need Cloudflare DNS records pointing to the RKE2 node IP. For `*.staging.mereka.dev`, Cloudflare Free SSL covers `*.mereka.dev` only — use DNS-only (gray cloud) + Let's Encrypt via cert-manager for deeper subdomains.

### Restore Scope

| Data Source | Restore Method | Notes |
|-------------|---------------|-------|
| MySQL (course data, users) | Velero PVC restore or `mysqldump` from GKE | Staging can use a scrubbed copy |
| MongoDB Atlas | Atlas read replica or snapshot restore | Staging should use a separate Atlas cluster/DB |
| Redis | Not restored — ephemeral cache | Staging starts fresh |
| Meilisearch | Rebuild index from LMS | No data restore needed |

### Image Promotion Source

Images are built in `mereka-lms` repo and pushed to Artifact Registry:
```
ghcr.io/biji-biji-initiative/mereka-lms/openedx:<tag>
ghcr.io/biji-biji-initiative/mereka-lms/mfe:<tag>
```

Current production tags (from infrastructure prod overlay):
- openedx: `mereka-brand`
- openedx-mfe: `b732a7d-20260210161437`

Current staging tags (from infrastructure staging overlay):
- openedx: `20260207-branding-pass7-5b26e45`
- openedx-mfe: `20260208-mfe-discussions-pass4-c17df16`

**Promotion flow**: Build in `mereka-lms` → push to Artifact Registry → update tag in infrastructure staging overlay → ArgoCD syncs to RKE2.

### Expected Guardrails

| Guardrail | Source | Status |
|-----------|--------|--------|
| Kyverno `require-non-root-security-context` | `clusters/staging/rke2/platform/70-kyverno.yaml` | Active on RKE2 |
| Kyverno `disallow-latest-image-tag` | Same | Active — no `:latest` tags allowed |
| Kyverno `require-resource-limits` | Same | Active — all pods need limits |
| Kyverno `disallow-privileged-containers` | Same | Active |
| Velero backup schedule | `clusters/staging/rke2/platform/60-velero.yaml` | Active |
| nonprod-guardrails (PVC protection, etc.) | `clusters/staging/rke2/platform/00-nonprod-guardrails.yaml` | Active |

**LMS-specific compliance**: The meilisearch security context patch (`deploy/k8s/overlays/local/patches/meilisearch-security-context.yaml`) is needed for staging too. All LMS pods need `runAsNonRoot: true` to pass Kyverno on RKE2.

---

## 3. Dependency Map (AC-RKE2-003)

### Gate Progression

| Gate | Name | Status on RKE2 | Responsible Repo | LMS Dependencies |
|------|------|----------------|-----------------|------------------|
| **0** | Lock (nonprod-guardrails) | **DONE** | `infrastructure` | None |
| **1** | Bootstrap (ArgoCD) | **DONE** | `infrastructure` | None |
| **2** | Platform essentials (cert-manager, ingress, external-secrets, monitoring, kyverno, velero) | **DONE** | `infrastructure` | None |
| **3** | Secrets provisioning | **PARTIAL** | `infrastructure` + GCP SM | LMS needs: `openedx-secrets`, `database-secrets`, `mereka-lms-runtime-secrets` provisioned in RKE2 `mereka-lms` namespace |
| **4** | App packaging/deploy | **NOT STARTED** | `mereka-lms` (base manifests) + `infrastructure` (staging overlay) | Enable staging kustomization, create ArgoCD Application for mereka-lms-staging-rke2 |
| **5** | Data migration/seed | **NOT STARTED** | `mereka-lms` (migration scripts) | MySQL + MongoDB data for staging |
| **6** | Staging cutover | **NOT STARTED** | `infrastructure` (DNS, ingress) | All gates 0-5 complete, smoke tests pass |

### Gate 3 Detail: Secrets

Secrets needed before LMS can start on RKE2:

| Secret Name | Source | Keys Needed |
|-------------|--------|------------|
| `openedx-secrets` | ExternalSecret → GCP SM (`bbi-k8` project) | `OPENEDX_SECRET_KEY`, `OPENEDX_JWT_SECRET_KEY`, `MEILISEARCH_MASTER_KEY`, `MUX_TOKEN_ID`, `MUX_TOKEN_SECRET`, etc. |
| `database-secrets` | ExternalSecret → GCP SM | `MYSQL_ROOT_PASSWORD`, `MONGODB_PASSWORD`, etc. |
| `mereka-lms-runtime-secrets` | Manual or ExternalSecret | `SECRET_KEY`, JWT keys, domain config |

**Question**: Should staging use the same GCP SM secrets (same `bbi-k8` project) with different values, or separate staging-specific secrets?

### Gate 4 Detail: App Deployment

To enable LMS on RKE2:
1. In `infrastructure`: Copy `kustomization.enabled.yaml` over `kustomization.yaml` in `clusters/staging/rke2/` (this enables `apps/mereka-lms/overlays/staging`)
2. The staging overlay already exists with 17 patches (domain bindings, secrets wiring, SSO, workload profiles, etc.)
3. Create `mereka-lms-staging-rke2` ArgoCD Application (or add to ApplicationSet)
4. Ensure images are pullable (Artifact Registry auth or pre-load)

---

## 4. How LMS-Specific RKE2 Work Starts (AC-RKE2-004)

### Starting Point

All LMS base manifests live in **this repo** (`mereka-lms`):
```
deploy/k8s/base/          # Base K8s resources (Deployments, Services, ConfigMaps)
deploy/k8s/overlays/      # Local and production overlays (this repo)
```

The staging overlay that targets RKE2 lives in **infrastructure**:
```
apps/mereka-lms/overlays/staging/    # 17 staging-specific patches
clusters/staging/rke2/               # RKE2 bootstrap + platform resources
```

### Workflow

```
mereka-lms (this repo)              infrastructure (infra repo)
─────────────────────               ────────────────────────────────
1. App code + base manifests   →    2. Staging overlay selects version
   (deploy/k8s/base/)                  (apps/mereka-lms/overlays/staging/)
                                   3. Enable staging kustomization
                                      (clusters/staging/rke2/kustomization.yaml)
                                   4. ArgoCD syncs to RKE2 cluster
```

### Evidence Location

All LMS-specific RKE2 evidence is written to:
- **This repo**: `reports/2026/closures/RKE2_LMS_HANDOFF.md` (this document)
- **infrastructure**: `apps/mereka-lms/overlays/staging/` (overlay changes)

### Sign-Off

| Gate | Sign-Off Authority | Criteria |
|------|-------------------|----------|
| Gates 0-2 (platform) | Platform team (infrastructure) | ArgoCD apps Synced/Healthy |
| Gate 3 (secrets) | Platform team + Security | ExternalSecrets synced, no PLACEHOLDER values |
| Gate 4 (app deploy) | LMS team (this repo) | LMS pods Running, health checks pass |
| Gate 5 (data) | LMS team + DBA | Migration scripts complete, data verified |
| Gate 6 (cutover) | Platform lead | DNS, SSL, smoke tests, auth flow verified |

---

## 5. Evidence Links (AC-RKE2-005)

| Deliverable | Path | Timestamp |
|-------------|------|-----------|
| Cross-repo touchpoint note | `reports/2026/closures/RKE2_LMS_HANDOFF.md` (this file) | 2026-02-18T13:50Z |
| Dependency gate map | This file, Section 3 | 2026-02-18T13:50Z |
| Repo boundaries reference | `docs/policies/operations/REPO_BOUNDARIES.md` | 2026-02-13 (last verified) |
| GitOps workflow reference | `docs/ops/runbooks/GITOPS_WORKFLOW.md` | Existing |
| Kind cluster recovery (context) | `docs/evidence/operations/KIND_CLUSTER_RECOVERY_EVIDENCE.md` | 2026-02-18T13:13Z |
| GKE workload triage (context) | `docs/evidence/operations/GKE_WORKLOAD_TRIAGE_EVIDENCE.md` | 2026-02-18T13:21Z |
| RKE2 staging overlay (infra repo) | `infrastructure:apps/mereka-lms/overlays/staging/kustomization.yaml` | Existing (17 patches) |
| RKE2 bootstrap (infra repo) | `infrastructure:clusters/staging/rke2/` | Existing (disabled) |

### Cluster Verification Commands

```bash
# RKE2 platform health
kubectl --context rke2-nonprod get nodes
kubectl --context rke2-nonprod get pods -A | grep -v Completed | grep -v Running

# ArgoCD apps on RKE2
kubectl --context rke2-nonprod get application -n argocd

# mereka-dev namespace (non-LMS apps)
kubectl --context rke2-nonprod get pods -n mereka-dev

# GKE production health (reference — do not modify)
kubectl --context gke_bbi-k8_asia-southeast1-c_bbi-k8-cluster get application -n argocd | grep mereka-lms
```

---

## Related Documents

- `docs/policies/operations/REPO_BOUNDARIES.md` — Canonical ownership matrix
- `docs/ops/runbooks/GITOPS_WORKFLOW.md` — Two-repo GitOps architecture
- `docs/evidence/operations/KIND_CLUSTER_RECOVERY_EVIDENCE.md` — Kind cluster fixes (Kyverno, CMS OOM)
- `docs/reference/operations/PRODUCTION_INFRASTRUCTURE_PLAN.md` — Current infra model
- `infrastructure:ENVIRONMENTS.md` — All environments and URLs
- `infrastructure:CLAUDE.md` — Infra repo rules (GKE protection, data protection, cost budget)
