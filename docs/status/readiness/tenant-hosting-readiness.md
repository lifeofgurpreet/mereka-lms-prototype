# Tenant Hosting Readiness

> **Bead**: mereka-lms-jptf
> **Date**: 2026-03-26
> **Cluster**: rke2-prod
> **Spec**: AC-OPS-201..205
>
> **Current staging truth**: staging now uses the canonical `staging.<service>.academyv2.mereka.io` host family in live runtime, but the app image is still behind merged truth until promotion catches up.

## 1. Authoritative Domain and Contract Map (AC-OPS-201)

### Active Domains by Tenant

| Tenant | Domain | Service | Cluster | Status | SSL |
|--------|--------|---------|---------|--------|-----|
| **Mereka Academy** (primary) | `academyv2.mereka.io` | LMS | GKE prod | ✅ Active | Let's Encrypt |
| Mereka Academy | `studio.academyv2.mereka.io` | CMS/Studio | GKE prod | ✅ Active | Let's Encrypt |
| Mereka Academy | `apps.academyv2.mereka.io` | MFE | GKE prod | ✅ Active | Let's Encrypt |
| Mereka Academy | `preview.academyv2.mereka.io` | LMS Preview | GKE prod | ✅ Active | Let's Encrypt |
| Mereka Academy | `discovery.academyv2.mereka.io` | Course Discovery | GKE prod | ✅ Active | Let's Encrypt |
| Mereka Academy | `notes.academyv2.mereka.io` | Notes | GKE prod | ✅ Active | Let's Encrypt |
| Mereka Academy | `credentials.academyv2.mereka.io` | Credentials | GKE prod | ✅ Active | Let's Encrypt |
| Mereka Academy | `ecommerce.academyv2.mereka.io` | Ecommerce (legacy) | GKE prod | ⚠️ Deprecated | Let's Encrypt |
| **Biji-Biji** (alt domain) | `academy.biji-biji.com` | LMS | GKE prod | ✅ Active | Let's Encrypt |
| Biji-Biji | `studio.academy.biji-biji.com` | CMS/Studio | GKE prod | ✅ Active | Let's Encrypt |
| Biji-Biji | `apps.academy.biji-biji.com` | MFE | GKE prod | ✅ Active | Let's Encrypt |
| **Skill of Future** (sub-tenant) | `skillourfuture.academy.mereka.io` | LMS | GKE prod | ✅ Active | Let's Encrypt |
| **Staging** (RKE2) | `staging.<service>.academyv2.mereka.io` | All | RKE2 nonprod | ⚠️ Live runtime, public DNS publication pending | Pending external DNS/TLS publication |
| **Dev** (Kind) | `*.localhost` | All | Kind | ✅ Active (local only) | Self-signed |

### Service Behaviour by Domain

| Domain | LMS Base URL | Studio | MFE | ALLOWED_HOSTS | CSRF Origins |
|--------|-------------|--------|-----|---------------|-------------|
| `academyv2.mereka.io` | Primary | `studio.academyv2.mereka.io` | `apps.academyv2.mereka.io` | ✅ Included | ✅ Included |
| `academy.biji-biji.com` | Alt (same LMS pod) | `studio.academy.biji-biji.com` | `apps.academy.biji-biji.com` | ✅ Included | ✅ Included |
| `skillourfuture.academy.mereka.io` | Sub-tenant (same LMS pod) | Shared Studio | Shared MFE | ✅ Included | ✅ Included |
| `staging.<service>.academyv2.mereka.io` | Live staging runtime | `staging.studio.academyv2.mereka.io` | `staging.apps.academyv2.mereka.io` | ✅ Included | ✅ Included |

### Multi-Site Architecture

```
NGINX Ingress → Caddy → LMS pod
     ↓
All domains route to same LMS pod (single-cluster multi-site):
  academyv2.mereka.io          → caddy svc → lms
  academy.biji-biji.com        → caddy svc → lms (Django SiteConfig lookup)
  skillourfuture.academy.mereka.io → caddy svc → lms (Django SiteConfig lookup)
```

Django `django.contrib.sites` + `SiteConfiguration` resolves per-domain branding.

### Current Staging Truth

- Argo revision: `d9bd9537af4ece908df3094d759ae977864f468f`
- runtime image: `d7f015d2...` is still serving the live staging deployment
- live blockers remain:
  - branded `/api/mfe_config/v1` deep-link leakage
  - tenant authn still loading default `mereka-brand*.css`
  - public `staging.discovery.academyv2.mereka.io`, `staging.notes.academyv2.mereka.io`, `staging.credentials.academyv2.mereka.io`, `staging.admin.academyv2.mereka.io`, and `staging.learner.academyv2.mereka.io` unresolved from this environment

---

## 2. Hostname Governance Gates (AC-OPS-202)

### Gate 1: list-openedx-hostnames

```bash
CTX="rke2-prod"
NS="mereka-lms"

# All active hostnames from Ingress resources
kubectl --context $CTX get ingress -n $NS \
  -o jsonpath='{range .items[*]}{range .spec.rules[*]}{.host}{"\n"}{end}{end}' | sort -u
```

**Expected output** (rke2-prod production):
```
academyv2.mereka.io
academy.biji-biji.com
apps.academyv2.mereka.io
apps.academy.biji-biji.com
auth0.mereka.io
credentials.academyv2.mereka.io
discovery.academyv2.mereka.io
ecommerce.academyv2.mereka.io
notes.academyv2.mereka.io
preview.academyv2.mereka.io
skillourfuture.academy.mereka.io
studio.academyv2.mereka.io
studio.academy.biji-biji.com
```

### Gate 2: map-openedx-host-routing

```bash
# Verify Ingress → Service → Pod routing for each core domain
for host in academyv2.mereka.io academy.biji-biji.com apps.academyv2.mereka.io studio.academyv2.mereka.io; do
  echo "=== $host ==="
  curl -sI --connect-timeout 5 "https://$host" | head -2
done
```

### Gate 3: ALLOWED_HOSTS verification

```bash
# Verify all active domains are in ALLOWED_HOSTS
kubectl --context $CTX exec -n $NS deployment/lms -- \
  python manage.py lms shell -c "
from django.conf import settings
hosts = settings.ALLOWED_HOSTS
print('ALLOWED_HOSTS count:', len(hosts))
required = [
  'academyv2.mereka.io', 'academy.biji-biji.com',
  'apps.academyv2.mereka.io', 'studio.academyv2.mereka.io',
  'skillourfuture.academy.mereka.io'
]
missing = [h for h in required if h not in hosts]
print('Missing:', missing if missing else 'NONE — all present')
"
```

### Gate 4: CSRF_TRUSTED_ORIGINS verification

```bash
kubectl --context $CTX exec -n $NS deployment/lms -- \
  python manage.py lms shell -c "
from django.conf import settings
origins = settings.CSRF_TRUSTED_ORIGINS
print('CSRF origins count:', len(origins))
required = [
  'https://academyv2.mereka.io',
  'https://academy.biji-biji.com',
  'https://apps.academyv2.mereka.io',
  'https://apps.academy.biji-biji.com',
  'https://skillourfuture.academy.mereka.io'
]
missing = [o for o in required if o not in origins]
print('Missing:', missing if missing else 'NONE — all present')
"
```

### Runbook: Hostname Mismatch Handling

| Symptom | Cause | Fix |
|---------|-------|-----|
| `DisallowedHost: <domain>` in LMS logs | Domain missing from `ALLOWED_HOSTS` | Add to `production.py` ALLOWED_HOSTS, rebuild image |
| CSRF 403 on form submit | Domain missing from `CSRF_TRUSTED_ORIGINS` | Add `https://<domain>` to `CSRF_TRUSTED_ORIGINS` in `production.py` |
| Ingress 404 for new domain | No Ingress rule | Add host to `deploy/k8s/overlays/production/ingress-openedx-lms.yaml` |
| SSL cert not issued | cert-manager missing domain | Add to Ingress TLS block; cert-manager auto-issues |
| Studio redirects to wrong LMS | `SITE_NAME` mismatch in SiteConfig | Update Django SiteConfig in admin: `/admin/sites/site/` |
| MFE shows wrong theme | `SiteTheme` not configured | Set theme in Django admin for the domain's Site record |

---

## 3. Kind → GKE Rollout Checklist (AC-OPS-203)

### Pre-Conditions (all must be GREEN before cutover)

| Check | Command | Expected | Status |
|-------|---------|----------|--------|
| GKE cluster reachable | `kubectl --context gke_bbi-k8_... get nodes` | All Ready | ✅ Active |
| Core pods Running | `kubectl get pods -n mereka-lms \| grep -vE "Running\|Completed"` | No output | Run at cutover |
| All endpoints non-empty | `kubectl get endpoints -n mereka-lms` | No `<none>` | Run at cutover |
| Secrets synced | `kubectl get externalsecret -n mereka-lms` | All Ready | ✅ Active |
| ArgoCD healthy | `kubectl get application -n argocd` | All Healthy/Synced | Run at cutover |
| DNS resolves | `dig +short academyv2.mereka.io` | GKE ingress IP | ✅ Active |
| SSL certs valid | `kubectl get certificate -n mereka-lms` | All Ready | ✅ Active |
| LMS health | `curl -sI https://academyv2.mereka.io \| head -1` | HTTP/2 200 | Run at cutover |
| Auth flow works | `curl -sI https://academyv2.mereka.io/auth/login/oidc/ \| grep Location` | → auth0.mereka.io | Run at cutover |

### Rollout Steps: Kind (dev) → GKE (prod)

```bash
# 1. Build + tag + push new image
./scripts/infra/canonical-release.sh --check-only
source infrastructure/tutor/tutor-env.sh
./infrastructure/tutor/apply-patches.sh
tutor images build openedx -a PIP_COMMAND=pip
OPENEDX_TAG="$(date +%Y%m%d)-openedx-$(git rev-parse --short HEAD)"
docker tag docker.io/overhangio/openedx:latest \
  ghcr.io/biji-biji-initiative/mereka-lms/openedx:${OPENEDX_TAG}
docker push ghcr.io/biji-biji-initiative/mereka-lms/openedx:${OPENEDX_TAG}

# 2. Dry-run GitOps update
./scripts/infra/canonical-release.sh --dry-run \
  --openedx-tag ${OPENEDX_TAG}

# 3. Apply (updates both mereka-lms + infrastructure repos)
./scripts/infra/canonical-release.sh \
  --openedx-tag ${OPENEDX_TAG} \
  --apply --commit --push --verify-runtime

# 4. Monitor ArgoCD sync
watch kubectl --context rke2-prod \
  get pods -n mereka-lms

# 5. Run smoke tests
curl -sI https://academyv2.mereka.io | head -1
curl -sI https://academy.biji-biji.com | head -1
curl -sI https://apps.academyv2.mereka.io | head -1
curl -sI https://studio.academyv2.mereka.io | head -1
```

### External Dependencies Required for Cutover

| Dependency | Current State | Gate |
|------------|--------------|------|
| GKE cluster | ✅ Running | No action needed |
| Atlas MongoDB | ✅ Running | No action needed |
| Authentik OIDC | ✅ Running | No action needed |
| GCP Secret Manager | ✅ Synced | No action needed |
| Cloudflare DNS | ✅ Active | No action needed |
| RKE2 staging cluster | ⚠️ Live staging runtime exists; public DNS/TLS publication still pending for the satellite hosts | Optional pre-prod gate |

---

## 4. Rollback and Recovery for canonical-release.sh Failures (AC-OPS-204)

### Failure Classification

| Gate | Failure Symptom | Recovery Steps | Time |
|------|----------------|----------------|------|
| `--check-only` | Wrong path/branch/worktree | `cd $REPO_ROOT && git checkout main` | <1 min |
| `--check-only` | Uncommitted changes | `git stash` or commit pending work | <2 min |
| `--check-only` | Remote divergence | `git pull --rebase origin main` | <2 min |
| Build fails (OOM) | Docker OOM during webpack | Free RAM (close apps), retry with `--max-old-space-size=6144` | 5-10 min |
| `docker push` 403 | GCP auth expired | `gcloud auth configure-docker asia-southeast1-docker.pkg.dev` | <1 min |
| `--dry-run` | Unexpected files changed | Review diff: `git diff`; revert unintended changes | 2-5 min |
| `--apply` merge conflict | Both repos had concurrent changes | Resolve: `git diff HEAD origin/main`; manual merge | 5-15 min |
| `--apply` push rejected | Branch protection or CI block | Check CI: `gh pr status`; fix failing checks | 5-30 min |
| `--verify-runtime` timeout | ArgoCD slow sync | Force sync: `argocd app sync mereka-lms-prod`; wait 10min | 2-10 min |
| Pods CrashLoopBackOff | Bad config in new image | Revert: `git revert HEAD && git push` in both repos | <5 min |

### Command Snippets

```bash
# Revert mereka-lms and infrastructure in one go
REPO_ROOT="$(git rev-parse --show-toplevel)"
INFRA_REPO="${INFRA_REPO:-../bbi-infrastructure}"

# Revert latest commit in both repos
git -C $REPO_ROOT revert HEAD --no-edit && git -C $REPO_ROOT push
git -C $INFRA_REPO revert HEAD --no-edit && git -C $INFRA_REPO push

# ArgoCD auto-syncs within ~2min. Monitor:
watch kubectl --context rke2-prod \
  get pods -n mereka-lms

# Force cache bust (when image digest mismatch suspected)
rm -rf $REPO_ROOT/var/build-cache/
./scripts/infra/canonical-release.sh --dry-run --openedx-tag <TAG>

# Fix GCP auth
gcloud auth login
gcloud auth configure-docker asia-southeast1-docker.pkg.dev

# Fix stale worktree (wrong branch after agent switch)
git stash
git checkout main
git stash pop

# Emergency pod restart (last resort — clears CrashLoop backoff)
kubectl --context rke2-prod \
  rollout restart deployment/lms -n mereka-lms
```

### Release Abort Decision Tree

```
canonical-release.sh exits non-zero
         │
         ├─ Gate 0-3 (preflight/build/tag/push)?
         │   └─ No state changed → fix and retry immediately
         │
         ├─ Gate 4 (dry-run)?
         │   └─ git checkout -- . in both repos → retry
         │
         ├─ Gate 5 (apply/commit/push)?
         │   └─ git revert HEAD && git push in both repos
         │   └─ ArgoCD auto-reverts in ~2min
         │
         └─ Gate 6-7 (verify/smoke)?
             └─ Same as Gate 5 + investigate root cause
             └─ Check: kubectl logs -n mereka-lms deploy/lms --tail=50
```

---

## 5. Checkpoint (AC-OPS-205)

### Evidence Files

| File | AC Coverage | Status |
|------|-------------|--------|
| `docs/status/readiness/tenant-hosting-readiness.md` | AC-OPS-201..205 | ✅ This file |
| `docs/reference/operations/CANONICAL_DEPLOY_CONTRACT.md` | AC-OPS-051..054, 061..063, 111..114 | ✅ Closed (36va.1/2/5) |
| `docs/ops/runbooks/DEPLOY_EVIDENCE_GATES.md` | AC-OPS-301..305 | ✅ Closed (3qy2) |
| `docs/ops/runbooks/POSTDEPLOY_SMOKE_AND_INCIDENT.md` | AC-OPS-071..073, 090..093, 131..135 | ✅ Closed (36va.3/4) |
| `docs/status/migrations/RKE2_ROLLOUT_MATRIX.md` | AC-RKE2-006..015 | ✅ Closed (2j6g.1/2) |

### Rollout Status Summary

| Environment | State | Readiness Gate |
|-------------|-------|---------------|
| Kind (dev) | ✅ Fully operational | — |
| GKE (production) | ✅ Fully operational | 7/7 gates PASS |
| RKE2 (staging) | ⚠️ Platform ready, LMS not deployed | Gates 0-2 PASS, Gate 3+ pending |

**Overall**: PASS for production. WARN for staging (RKE2 gates 3+ pending — requires platform team action in infrastructure repo).

---

## Related

- `docs/status/migrations/RKE2_ROLLOUT_MATRIX.md` — RKE2 gate-by-gate procedure
- `docs/reference/operations/CANONICAL_DEPLOY_CONTRACT.md` — Build/tag/push flow, environment deltas
- `docs/ops/runbooks/DEPLOY_EVIDENCE_GATES.md` — GKE parity proof commands
- `scripts/infra/canonical-release.sh` — Canonical release wrapper with validation
- `deploy/k8s/overlays/production/` — GKE ingress rules per domain
