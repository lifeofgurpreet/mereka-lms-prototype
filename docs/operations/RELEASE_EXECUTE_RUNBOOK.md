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
  asia-southeast1-docker.pkg.dev/mereka-lms/openedx/openedx:${OPENEDX_TAG}
docker tag docker.io/overhangio/openedx-mfe:latest \
  asia-southeast1-docker.pkg.dev/mereka-lms/openedx/openedx-mfe:${MFE_TAG}

docker push asia-southeast1-docker.pkg.dev/mereka-lms/openedx/openedx:${OPENEDX_TAG}
docker push asia-southeast1-docker.pkg.dev/mereka-lms/openedx/openedx-mfe:${MFE_TAG}
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
# Revert app repo
git -C /home/gurpreet/projects/k8s/mereka-lms revert HEAD
git push

# Revert infra repo
git -C /home/gurpreet/projects/k8s/bbi-infrastructure revert HEAD
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

**Rollback checkpoint**: If pods crash, revert commits (Step 3 rollback). ArgoCD auto-syncs to previous tags.

### Step 5: Smoke test

```bash
# Quick health check
curl -sI https://academyv2.mereka.io | head -1
curl -sI https://studio.academyv2.mereka.io | head -1
curl -sI https://apps.academyv2.mereka.io | head -1
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
Infra repo: /home/gurpreet/projects/k8s/bbi-infrastructure
Target env: production

Done.
```

## Related

- Script: `scripts/infra/canonical-release.sh` (environment validation + cache)
- Script: `scripts/infra/release-openedx-gitops.sh` (tag update + gitops orchestration)
- Runbook: `docs/operations/runbooks/DEPLOYMENT_RUNBOOK.md` (full infrastructure setup)
- Runbook: `docs/operations/runbooks/emergency-rollback.md` (emergency procedures)
