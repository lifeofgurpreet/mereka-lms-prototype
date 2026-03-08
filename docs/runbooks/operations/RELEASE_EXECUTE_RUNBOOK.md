# Release Execute Runbook (One-Page)

> **Bead**: mereka-lms-kbpu
> **Last verified**: 2026-02-18 (dry-run on main)
> **Canonical path**: `/home/gurpreet/projects/k8s/mereka-lms` on `main`

## Preflight (AC-OPS-202)

```bash
# Validate environment (hard-fails on non-canonical path, wrong branch, stale worktrees)
./scripts/infra/canonical-release.sh --check-only
```

Expected: all OK. Any HARD FAIL blocks the release.

## Command Chain (AC-OPS-201)

### Step 1: Build images (if needed)

```bash
# Check cache first — skip if digests unchanged
./scripts/infra/canonical-release.sh --dry-run --openedx-tag <TAG> --mfe-tag <MFE_TAG>

# If cache says BUILD NEEDED:
source infrastructure/tutor/tutor-env.sh
./infrastructure/tutor/apply-patches.sh
tutor images build openedx -a PIP_COMMAND=pip    # ~30min, needs 12GB+ RAM
tutor images build mfe                            # ~15min
```

**Rollback checkpoint**: If build fails, no state has changed. Fix and retry.

### Step 2: Tag and push to Artifact Registry

```bash
OPENEDX_TAG="$(date +%Y%m%d)-openedx-$(git rev-parse --short HEAD)"
MFE_TAG="$(date +%Y%m%d)-mfe-$(git rev-parse --short HEAD)"

docker tag docker.io/overhangio/openedx:latest \
  ghcr.io/biji-biji-initiative/mereka-lms/openedx:${OPENEDX_TAG}
docker tag docker.io/overhangio/openedx-mfe:latest \
  ghcr.io/biji-biji-initiative/mereka-lms/mfe:${MFE_TAG}

docker push ghcr.io/biji-biji-initiative/mereka-lms/openedx:${OPENEDX_TAG}
docker push ghcr.io/biji-biji-initiative/mereka-lms/mfe:${MFE_TAG}
```

**Rollback checkpoint**: Images are immutable once pushed. Old tags remain valid. No rollback needed.

### Step 3: Update tags + GitOps ref bump (dry-run first)

```bash
# Dry-run — shows what would change
./scripts/infra/canonical-release.sh --dry-run \
  --openedx-tag ${OPENEDX_TAG} --mfe-tag ${MFE_TAG}

# Apply + commit + push (both repos)
./scripts/infra/canonical-release.sh \
  --openedx-tag ${OPENEDX_TAG} --mfe-tag ${MFE_TAG} \
  --apply --commit --push
```

**Rollback checkpoint**: Git commits are reversible. To rollback:
```bash
# Canonical worktrees for release repos
APP_REPO="${APP_REPO:-/home/gurpreet/projects/k8s/mereka-lms}"
INFRA_REPO="${INFRA_REPO:-/home/gurpreet/projects/k8s/infrastructure}"

# Revert app repo
git -C "$APP_REPO" revert HEAD
git push

# Revert infra repo
git -C "$INFRA_REPO" revert HEAD
git push
```

### Step 4: Verify runtime convergence

```bash
# Wait for ArgoCD to sync (up to 10 minutes)
./scripts/infra/canonical-release.sh \
  --openedx-tag ${OPENEDX_TAG} --mfe-tag ${MFE_TAG} \
  --verify-runtime --wait-seconds 600

# Manual verification
kubectl --context gke_bbi-k8_asia-southeast1-c_bbi-k8-cluster \
  get pods -n mereka-lms | grep -E "lms|cms|mfe"
kubectl --context gke_bbi-k8_asia-southeast1-c_bbi-k8-cluster \
  get application -n argocd | grep mereka-lms
```

```bash
# Enterprise MFE regression guard (must be PASS for demo readiness)
./scripts/qa/verify-enterprise-mfe-nreum-clean.sh
```

**Rollback checkpoint**: If pods crash, revert commits (Step 3 rollback). ArgoCD auto-syncs to previous tags.

### Step 5: Smoke test

```bash
# Quick health check
curl -sI https://academyv2.mereka.io | head -1
curl -sI https://studio.academyv2.mereka.io | head -1
curl -sI https://apps.academyv2.mereka.io | head -1
curl -sI https://admin.academyv2.mereka.io | head -1
curl -sI https://learner.academyv2.mereka.io | head -1
```

## Rollback Summary (AC-OPS-204)

| Stage | Reversible? | Rollback Action |
|-------|-------------|-----------------|
| Build | Yes | No state changed; fix and rebuild |
| Push to AR | N/A | Old tags still work; push doesn't delete |
| Tag update (git) | Yes | `git revert HEAD && git push` in both repos |
| ArgoCD sync | Auto | Reverts when git is reverted |
| DNS/Ingress | N/A | Not touched during release |

## Failure-to-Fix Matrix (AC-OPS-205)

| Failure | Likely Cause | Fix | Owner |
|---------|-------------|-----|-------|
| Build OOM | <12GB Docker RAM | Increase Docker memory to 12GB+ | Developer |
| `apply-patches.sh` not run | Tutor regenerated templates | Run `./infrastructure/tutor/apply-patches.sh` | Developer |
| Image push 403 | AR auth expired | `gcloud auth configure-docker asia-southeast1-docker.pkg.dev` | Developer |
| ArgoCD OutOfSync | Base ref mismatch | Check `--update-base-ref` in release script | Infra |
| Pods CrashLoopBackOff | Config/secret mismatch | Check ConfigMap + ExternalSecrets | Infra |
| 502 after deploy | Ingress/Caddy routing | Check endpoints: `kubectl get endpoints -n mereka-lms` | Infra |
| Stale worktree | Non-canonical path | `git worktree prune` + re-run from canonical path | Developer |

## Dry-Run Evidence (AC-OPS-203)

```
$ ./scripts/infra/canonical-release.sh --dry-run --openedx-tag mereka-brand --mfe-tag b732a7d-20260210161437

Canonical Release Workflow
=========================

OK: Canonical path: /home/gurpreet/projects/k8s/mereka-lms
OK: Branch: main
OK: Single worktree (no drift risk)
OK: HEAD matches origin/main

Cache result: SKIP (both images unchanged)

App repo:   /home/gurpreet/projects/k8s/mereka-lms
Infra repo: /home/gurpreet/projects/k8s/infrastructure
Target env: production

Done.
```

## Related

- Script: `scripts/infra/canonical-release.sh` (environment validation + cache)
- Script: `scripts/infra/release-openedx-gitops.sh` (tag update + gitops orchestration)
- Runbook: `docs/ops/runbooks/DEPLOYMENT_RUNBOOK.md` (full infrastructure setup)
- Runbook: `docs/ops/runbooks/emergency-rollback.md` (emergency procedures)

---

## Enterprise MFE Hardening Evidence (2bq2 / AC-DEP-108..110)

> **Bead**: mereka-lms-2bq2
> **Date**: 2026-02-19
> **Branch**: feat/23ry2-spec-dedupe-normalize

### AC-DEP-108: Pre-merge CI gate (no strip-nreum workaround)

```
$ bash scripts/qa/check-enterprise-mfe-no-workaround.sh
=== Pre-merge gate: enterprise MFE must not contain runtime NREUM workaround ===

--- AC-DEP-108: No strip-nreum workaround initContainers in manifests ---
  [PASS] admin-portal-deployment.yaml: no strip-nreum / sanitize-enterprise initContainer
  [PASS] admin-portal-deployment.yaml: no undefined NR key placeholders
  [PASS] admin-portal-deployment.yaml: no Python runtime strip image
  [PASS] learner-portal-deployment.yaml: no strip-nreum / sanitize-enterprise initContainer
  [PASS] learner-portal-deployment.yaml: no undefined NR key placeholders
  [PASS] learner-portal-deployment.yaml: no Python runtime strip image

--- AC-DEP-108: Build-time clean Dockerfiles present ---
  [PASS] Build-time artifact exists: infrastructure/docker/enterprise-mfe-clean/Dockerfile.admin-portal
  [PASS] Build-time artifact exists: infrastructure/docker/enterprise-mfe-clean/Dockerfile.learner-portal
  [PASS] Build-time artifact exists: scripts/infra/build-enterprise-mfe-clean.sh

--- AC-DEP-108: Production kustomization pins enterprise MFE images ---
  [PASS] enterprise-admin-portal image pinned in production kustomization
  [PASS] enterprise-learner-portal image pinned in production kustomization
  [PASS] Production kustomization references nreum-clean tag

=== Summary ===
  PASS: 12 | FAIL: 0
  RESULT: PASS — enterprise MFE manifests are clean (no runtime workaround)
```

Script: `scripts/qa/check-enterprise-mfe-no-workaround.sh`

### AC-DEP-109: Full route smoke (pre-ArgoCD-sync)

All routes respond 200 (pre-rollout, ArgoCD sync pending):

| Route | HTTP | Status |
|-------|------|--------|
| `https://academyv2.mereka.io/` | 200 | PASS |
| `https://studio.academyv2.mereka.io/` | 200 | PASS |
| `https://apps.academyv2.mereka.io/authn/login` | 200 | PASS |
| `https://admin.academyv2.mereka.io/` | 200 | PASS |
| `https://learner.academyv2.mereka.io/` | 200 | PASS |

> **Note**: NREUM clean check will PASS post-ArgoCD-sync when clean images roll out.
> Operator action: `argocd app sync mereka-lms --resource apps:Deployment:enterprise-admin-portal`

### AC-DEP-110: Build artifacts manifest

| Artifact | Status |
|----------|--------|
| `infrastructure/docker/enterprise-mfe-clean/Dockerfile.admin-portal` | ✅ Committed |
| `infrastructure/docker/enterprise-mfe-clean/Dockerfile.learner-portal` | ✅ Committed |
| `infrastructure/docker/enterprise-mfe-clean/strip-nreum.sh` | ✅ Committed |
| `scripts/infra/build-enterprise-mfe-clean.sh` | ✅ Committed |
| `scripts/qa/check-enterprise-mfe-no-workaround.sh` | ✅ Committed |
| `scripts/qa/verify-enterprise-mfe-nreum-clean.sh` | ✅ Updated |
| Production kustomization nreum-clean pin | ✅ Committed |
| `docs/ops/runbooks/DEPLOYMENT_RUNBOOK.md` Section 9 | ✅ Committed |
| `docs/archive/evidence/operations/evidence/69qz-enterprise-mfe-clean-build.md` | ✅ Committed |

Full evidence: `docs/archive/evidence/operations/evidence/69qz-enterprise-mfe-clean-build.md`

---

## Enterprise/Ecommerce Parity Evidence (3k12 / AC-PRT-101..105)

> **Bead**: mereka-lms-3k12
> **Date**: 2026-02-19

### AC-PRT-102: Route smoke matrix (all hosts)

All service hosts confirmed HTTP 200/302 (auth redirect where expected), zero `undefined_*` key leakage:

| Host | HTTP | undefined_* | Status |
|------|------|-------------|--------|
| `academyv2.mereka.io` | 200 | 0 | PASS |
| `studio.academyv2.mereka.io` | 200 | 0 | PASS |
| `apps.academyv2.mereka.io/authn/login` | 200 | 0 | PASS |
| `admin.academyv2.mereka.io` | 200 | 0 | PASS |
| `learner.academyv2.mereka.io` | 200 | 0 | PASS |
| `ecommerce.academyv2.mereka.io` | 200 | 0 | PASS |
| `credentials.academyv2.mereka.io/health/` | 200 | 0 | PASS |
| `discovery.academyv2.mereka.io` | 200 | 0 | PASS |

### AC-PRT-104: Pre-merge gate

```
$ bash scripts/qa/check-enterprise-mfe-no-workaround.sh
PASS: 12 | FAIL: 0
RESULT: PASS — enterprise MFE manifests are clean (no runtime workaround)
```

### Pre-demo command

```bash
# One-liner full route check
for URL in \
  "https://academyv2.mereka.io/" \
  "https://studio.academyv2.mereka.io/" \
  "https://apps.academyv2.mereka.io/authn/login" \
  "https://admin.academyv2.mereka.io/" \
  "https://learner.academyv2.mereka.io/" \
  "https://ecommerce.academyv2.mereka.io/" \
  "https://credentials.academyv2.mereka.io/health/"; do
  echo "$(curl -o /dev/null -s -w '%{http_code}' --max-time 10 "$URL") $URL"
done

# NREUM regression check
bash scripts/qa/verify-enterprise-mfe-nreum-clean.sh
```

### Known non-blocking gaps

| Issue | Action |
|-------|--------|
| Enterprise portals NREUM: ArgoCD sync pending | `argocd app sync mereka-lms --resource apps:Deployment:enterprise-admin-portal` |
| Credentials `/programs/` → 502 | Credentials worker may need restart |

Full evidence: `docs/archive/evidence/operations/evidence/3k12-parity-smoke.md`
