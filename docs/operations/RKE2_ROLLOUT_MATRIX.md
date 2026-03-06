# RKE2 LMS Rollout Matrix

> **Beads**: mereka-lms-2j6g.1, mereka-lms-2j6g.2
> **Date**: 2026-02-18
> **Parent**: `docs/operations/RKE2_LMS_HANDOFF.md`

## 1. Gate-by-Gate Rollout Matrix (AC-RKE2-006, AC-RKE2-011)

### Gate 0: Lock (nonprod-guardrails)

| Step | Command | Repo | Owner |
|------|---------|------|-------|
| Verify guardrails active | `kubectl --context rke2-nonprod get clusterpolicy` | bbi-infrastructure | Platform |
| Verify PVC protection | `kubectl --context rke2-nonprod get pdb -A` | bbi-infrastructure | Platform |

**Status**: DONE | **Abort if**: Kyverno policies missing

### Gate 1: Bootstrap (ArgoCD)

| Step | Command | Repo | Owner |
|------|---------|------|-------|
| Verify ArgoCD | `kubectl --context rke2-nonprod get pods -n argocd` | bbi-infrastructure | Platform |
| Verify app access | `kubectl --context rke2-nonprod get application -n argocd` | bbi-infrastructure | Platform |

**Status**: DONE | **Abort if**: ArgoCD pods not Running

### Gate 2: Platform Essentials

| Step | Command | Repo | Owner |
|------|---------|------|-------|
| cert-manager | `kubectl --context rke2-nonprod get pods -n cert-manager` | bbi-infrastructure | Platform |
| ingress-nginx | `kubectl --context rke2-nonprod get pods -n ingress-nginx` | bbi-infrastructure | Platform |
| external-secrets | `kubectl --context rke2-nonprod get pods -n external-secrets` | bbi-infrastructure | Platform |
| monitoring | `kubectl --context rke2-nonprod get pods -n monitoring` | bbi-infrastructure | Platform |
| kyverno | `kubectl --context rke2-nonprod get pods -n kyverno` | bbi-infrastructure | Platform |

**Status**: DONE | **Abort if**: Any platform pod not Running

### Gate 3: Secrets Provisioning

| Step | Command | Repo | Owner |
|------|---------|------|-------|
| Create namespace | `kubectl --context rke2-nonprod create ns mereka-lms` | bbi-infrastructure | Platform |
| Deploy ExternalSecrets | `kubectl --context rke2-nonprod apply -f deploy/k8s/base/secrets/` | mereka-lms | LMS team |
| Verify sync | `kubectl --context rke2-nonprod get externalsecret -n mereka-lms` | — | LMS team |
| Check no PLACEHOLDER | `kubectl --context rke2-nonprod get secret openedx-secrets -n mereka-lms -o json \| jq '.data \| keys'` | — | Security |

**Status**: NOT STARTED | **Abort if**: ExternalSecrets show `SecretSyncError` or contain PLACEHOLDER values

**Rollback**: Delete the namespace: `kubectl --context rke2-nonprod delete ns mereka-lms`

### Gate 4: App Packaging and Deploy

| Step | Command | Repo | Owner |
|------|---------|------|-------|
| Enable staging kustomization | Copy `kustomization.enabled.yaml` → `kustomization.yaml` in `clusters/staging/rke2/` | bbi-infrastructure | Platform |
| Create ArgoCD Application | `kubectl --context rke2-nonprod apply -f` (ApplicationSet or manual Application) | bbi-infrastructure | Platform |
| Verify image pull | `kubectl --context rke2-nonprod get pods -n mereka-lms` | — | LMS team |
| Check core pods | All of: lms, cms, caddy, mfe, mysql, redis, meilisearch Running | — | LMS team |
| Run health check | `kubectl --context rke2-nonprod exec -n mereka-lms deploy/lms -- curl -s http://localhost:8000/heartbeat` | — | LMS team |

**Status**: NOT STARTED | **Abort if**: Core pods in CrashLoopBackOff after 3 restart cycles

**Rollback**: Disable staging kustomization (revert to `resources: []`), ArgoCD deletes resources.

### Gate 5: Data Migration/Seed

| Step | Command | Repo | Owner |
|------|---------|------|-------|
| MySQL data seed | `kubectl --context rke2-nonprod exec -n mereka-lms deploy/mysql -- mysql < dump.sql` | mereka-lms | DBA |
| MongoDB Atlas config | Configure separate staging DB in Atlas | — | DBA |
| Run migrations | `kubectl --context rke2-nonprod exec -n mereka-lms deploy/lms -- python manage.py lms migrate` | — | LMS team |
| Verify data | `kubectl --context rke2-nonprod exec -n mereka-lms deploy/lms -- python manage.py lms shell -c "from django.contrib.auth.models import User; print(User.objects.count())"` | — | LMS team |

**Status**: NOT STARTED | **Abort if**: Migration errors or data corruption detected

**Rollback**: Drop and recreate MySQL database from fresh dump.

### Gate 6: Staging Cutover

| Step | Command | Repo | Owner |
|------|---------|------|-------|
| DNS records | Create Cloudflare records for `*.staging.mereka.dev` → RKE2 IP | bbi-infrastructure | Platform |
| SSL certs | Verify cert-manager issues certs: `kubectl --context rke2-nonprod get certificate -n mereka-lms` | — | Platform |
| Smoke test | `curl -sI https://lms.staging.mereka.dev \| head -1` | — | LMS team |
| Auth flow | Verify OIDC redirect works end-to-end | — | LMS team |
| Sign-off | All gates 0-5 verified, smoke tests pass | — | Platform lead |

**Status**: NOT STARTED | **Abort if**: SSL cert not issued within 10 minutes, or auth flow fails

**Rollback**: Remove DNS records. LMS remains on GKE only.

## 2. Image Promotion Source of Truth (AC-RKE2-012)

### Registry

```
ghcr.io/biji-biji-initiative/mereka-lms/
├── openedx:<tag>           # LMS/CMS/workers
├── openedx-mfe:<tag>       # Micro-frontends
├── openedx-xqueue:<tag>    # XQueue service
└── payments-gateway:<tag>  # Purchase Gateway
```

### Current Tags

| Image | Production Tag | Staging Tag |
|-------|---------------|-------------|
| openedx | `mereka-brand` | `20260207-branding-pass7-5b26e45` |
| openedx-mfe | `b732a7d-20260210161437` | `20260208-mfe-discussions-pass4-c17df16` |

### Promotion Flow

```
Build (mereka-lms repo) → Push to AR → Update tag in bbi-infrastructure overlay → ArgoCD syncs
```

### Checksum Validation

```bash
# Get image digest from AR
gcloud artifacts docker images describe \
  ghcr.io/biji-biji-initiative/mereka-lms/openedx:mereka-brand \
  --format='value(image_summary.digest)'

# Verify running image matches
kubectl --context <ctx> get deploy lms -n mereka-lms \
  -o jsonpath='{.status.containerStatuses[0].imageID}'
```

## 3. Rollback Signals and Safe Abort (AC-RKE2-009, AC-RKE2-013)

| Gate | Rollback Signal | Safe Abort Condition | Recovery Time |
|------|----------------|---------------------|---------------|
| 0-2 | Platform pods not Running | Any component Degraded after 10min | <5 min (platform team) |
| 3 | ExternalSecret sync error | PLACEHOLDER values in secrets | <2 min (delete namespace) |
| 4 | Core pods CrashLoop × 3 | LMS not healthy after 15 min | <5 min (disable kustomization) |
| 5 | Migration SQL errors | Data mismatch after verify step | <10 min (drop + recreate DB) |
| 6 | SSL/DNS not resolving | Certs not issued in 10 min | <2 min (remove DNS records) |

## 4. Evidence Index (AC-RKE2-008, AC-RKE2-014, AC-RKE2-015)

### Evidence Folder Convention

```
docs/operations/
├── RKE2_LMS_HANDOFF.md           # Cross-repo touchpoint note (2j6g)
├── RKE2_ROLLOUT_MATRIX.md        # This file (2j6g.1 + 2j6g.2)
├── KIND_CLUSTER_RECOVERY_EVIDENCE.md  # Kind fixes (3cdw)
├── GKE_WORKLOAD_TRIAGE_EVIDENCE.md    # GKE triage (3k2i)
└── ops/runbooks/
    └── DEPLOYMENT_RUNBOOK.md      # Full deployment procedure
```

### Deliverable Checksums

| File | SHA256 (first 16) | Bead |
|------|-------------------|------|
| `RKE2_LMS_HANDOFF.md` | `5a6cd824e2fcbe82` | 2j6g |
| `RKE2_ROLLOUT_MATRIX.md` | `bb298bd2ccbad685` | 2j6g.1, 2j6g.2 |
| `CANONICAL_DEPLOY_CONTRACT.md` | `7cda29fb92fa8222` | 36va.5, 36va.2, 36va.1 |
| `POSTDEPLOY_SMOKE_AND_INCIDENT.md` | `2527b09953ae34af` | 36va.4, 36va.3, 36va.3.1 |
| `docs/ops/runbooks/RELEASE_EXECUTE_RUNBOOK.md` | `52b3b0b0871fac62` | kbpu |
| `canonical-release.sh` | `d31c2b53eb2c2966` | 36va.6 |

### Owner/Contact Matrix

| Gate | Primary Owner | Contact | Backup |
|------|--------------|---------|--------|
| 0-2 (Platform) | Platform team | bbi-infrastructure repo | Gurpreet |
| 3 (Secrets) | Security + Platform | GCP SM console | Gurpreet |
| 4 (App deploy) | LMS team | mereka-lms repo | WhiteCliff |
| 5 (Data) | DBA + LMS team | Atlas console + kubectl | Gurpreet |
| 6 (Cutover) | Platform lead | Cloudflare + kubectl | Gurpreet |

## 5. LMS Migration Runbook (AC-RKE2-007)

### Start-to-Finish from This Repo

```bash
# 1. Verify RKE2 cluster is ready (gates 0-2)
kubectl --context rke2-nonprod get nodes
kubectl --context rke2-nonprod get pods -A | grep -vE "Running|Completed"

# 2. Create namespace and deploy secrets (gate 3)
kubectl --context rke2-nonprod create ns mereka-lms
kubectl --context rke2-nonprod apply -f deploy/k8s/base/secrets/

# 3. Verify secrets synced
kubectl --context rke2-nonprod get externalsecret -n mereka-lms
kubectl --context rke2-nonprod get secret -n mereka-lms

# 4. Enable staging overlay in bbi-infrastructure (gate 4)
# (Done by platform team in bbi-infrastructure repo)
# Verify: kubectl --context rke2-nonprod get application -n argocd | grep mereka-lms

# 5. Wait for pods
kubectl --context rke2-nonprod get pods -n mereka-lms -w

# 6. Run migrations (gate 5)
kubectl --context rke2-nonprod exec -n mereka-lms deploy/lms -- \
  python manage.py lms migrate --noinput
kubectl --context rke2-nonprod exec -n mereka-lms deploy/cms -- \
  python manage.py cms migrate --noinput

# 7. Create superuser (if fresh install)
kubectl --context rke2-nonprod exec -n mereka-lms deploy/lms -- \
  python manage.py lms createsuperuser --noinput \
  --username admin --email admin@mereka.io

# 8. Smoke test (gate 6)
kubectl --context rke2-nonprod exec -n mereka-lms deploy/lms -- \
  curl -s http://localhost:8000/heartbeat
```

## Related

- `docs/operations/RKE2_LMS_HANDOFF.md` — Cross-repo touchpoint (parent doc)
- `docs/operations/CANONICAL_DEPLOY_CONTRACT.md` — Environment deltas
- `scripts/infra/canonical-release.sh` — Image promotion automation
