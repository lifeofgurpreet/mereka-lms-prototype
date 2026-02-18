# Branding & MFE Release Runbook

> Deterministic rollout path for LMS/MFE branding changes. Covers build, push, GitOps deploy,
> verify, and rollback.
>
> AC-DEP-001, AC-DEP-002, AC-DEP-003, AC-DEP-004

## Pre-Flight Checklist

- [ ] All verification scripts pass: `./scripts/qa/run-branding-evidence-pipeline.sh --env prod`
- [ ] Branch is clean: `git status` shows no uncommitted changes
- [ ] On canonical main: `git branch --show-current` → `main`
- [ ] Docker has ≥12 GB RAM and 2–4 GB swap configured (required for openedx webpack build)

---

## Step 1: Build Images

```bash
# Set environment
export TUTOR_ROOT="$(pwd)/tutor_env"
source infrastructure/tutor/tutor-env.sh

# Build LMS/CMS image (30-45 min, needs 12GB+ Docker RAM)
# -a PIP_COMMAND=pip avoids uv build isolation issues with loremipsum==1.0.5
tutor images build openedx -a PIP_COMMAND=pip

# Build MFE image (15-20 min)
tutor images build mfe

# Verify build completed
docker images | grep -E "openedx|mfe"
```

---

## Step 2: Tag and Push to Artifact Registry

```bash
# Tag with git SHA + timestamp  (AC-DEP-001: exact image tag tied to commit SHA)
TAG="$(git rev-parse --short HEAD)-$(date +%Y%m%d%H%M%S)"
GAR="asia-southeast1-docker.pkg.dev/mereka-lms/openedx"

# Tag images
docker tag docker.io/overhangio/openedx:latest "${GAR}/openedx:${TAG}"
docker tag docker.io/overhangio/openedx-mfe:latest "${GAR}/openedx-mfe:${TAG}"

# Push to Artifact Registry
docker push "${GAR}/openedx:${TAG}"
docker push "${GAR}/openedx-mfe:${TAG}"

# Record digests (AC-DEP-001: exact image digests in release notes)
OPENEDX_DIGEST="$(docker inspect --format='{{index .RepoDigests 0}}' "${GAR}/openedx:${TAG}" 2>/dev/null || docker inspect --format='{{.Id}}' "${GAR}/openedx:${TAG}")"
MFE_DIGEST="$(docker inspect --format='{{index .RepoDigests 0}}' "${GAR}/openedx-mfe:${TAG}" 2>/dev/null || docker inspect --format='{{.Id}}' "${GAR}/openedx-mfe:${TAG}")"

echo "TAG:           ${TAG}"
echo "COMMIT_SHA:    $(git rev-parse HEAD)"
echo "openedx:       ${GAR}/openedx:${TAG}"
echo "openedx digest: ${OPENEDX_DIGEST}"
echo "openedx-mfe:   ${GAR}/openedx-mfe:${TAG}"
echo "mfe digest:    ${MFE_DIGEST}"
```

---

## Step 3: GitOps Rollout via release-openedx-gitops.sh

Use the canonical release orchestrator (AC-DEP-002: exact commands for gitops rollout):

```bash
# Dry-run first (always)
./scripts/infra/release-openedx-gitops.sh \
  --target-env production \
  --openedx-tag "${TAG}" \
  --mfe-tag "${TAG}" \
  --openedx-digest "${OPENEDX_DIGEST}" \
  --mfe-digest "${MFE_DIGEST}" \
  --require-digests

# Apply, commit, push, and verify runtime convergence
./scripts/infra/release-openedx-gitops.sh \
  --target-env production \
  --openedx-tag "${TAG}" \
  --mfe-tag "${TAG}" \
  --openedx-digest "${OPENEDX_DIGEST}" \
  --mfe-digest "${MFE_DIGEST}" \
  --require-digests \
  --apply --commit --push --verify-runtime
```

### Manual GitOps update (if release-openedx-gitops.sh is unavailable)

```bash
# AC-DEP-004: update BOTH app repo overlay AND GitOps repo overlay to prevent drift
APP_KUST="deploy/k8s/overlays/production/kustomization.yaml"

# Update app repo overlay
sed -i "s/newTag: .*/newTag: ${TAG}/g" "$APP_KUST"
git add "$APP_KUST"
git commit -m "release: branding ${TAG}

Image tag: ${TAG}
Commit: $(git rev-parse HEAD)
openedx digest: ${OPENEDX_DIGEST}
mfe digest: ${MFE_DIGEST}"
git push origin main

# Update GitOps repo (bbi-infrastructure)
cd /home/gurpreet/projects/k8s/bbi-infrastructure
git checkout main && git pull
INFRA_KUST="apps/mereka-lms/overlays/prod/kustomization.yaml"
sed -i "s/newTag: .*/newTag: ${TAG}/g" "$INFRA_KUST"
git add "$INFRA_KUST"
git commit -m "release: branding ${TAG}"
git push origin main
```

---

## Step 4: Verify Deployment

```bash
# Check ArgoCD sync status (AC-DEP-002: verification commands)
kubectl -n argocd get application mereka-lms-local

# Wait for rollout convergence (up to 5 min)
kubectl -n mereka-lms rollout status deployment/lms --timeout=300s
kubectl -n mereka-lms rollout status deployment/cms --timeout=300s
kubectl -n mereka-lms rollout status deployment/mfe --timeout=300s

# Confirm running image tags match what was deployed
kubectl get deploy lms cms mfe -n mereka-lms \
  -o jsonpath='{range .items[*]}{.metadata.name}: {.spec.template.spec.containers[0].image}{"\n"}{end}'

# Run post-deploy branding gates (MANDATORY per 2026-02-10 incident — see ADR-012)
./scripts/branding/run-branding-gates.sh prod
./scripts/qa/public-health-check.sh prod

# Full branding evidence pipeline
./scripts/qa/run-branding-evidence-pipeline.sh --env prod

# Check all tenant domains return HTTP 200
for domain in academyv2.mereka.io academy.biji-biji.com; do
  echo "$domain: $(curl -s -o /dev/null -w '%{http_code}' "https://${domain}/")"
done

# Drift check: confirm source and GitOps overlays are aligned (AC-DEP-004)
./scripts/qa/verify-gitops-drift.sh
./scripts/qa/verify-gitops-image-overrides.sh
```

---

## Step 5: Rollback (if needed)

> AC-DEP-003: Rollback path validated and documented

### Option A: Re-run release orchestrator with known-good tags (preferred)

```bash
# Replace PREV_TAG with the last known-good tag (check git log for prior releases)
PREV_TAG="<previous-known-good-tag>"

./scripts/infra/release-openedx-gitops.sh \
  --target-env production \
  --openedx-tag "${PREV_TAG}" \
  --mfe-tag "${PREV_TAG}" \
  --apply --commit --push --verify-runtime
```

### Option B: Revert GitOps overlay directly

```bash
# Revert in GitOps repo (ArgoCD auto-syncs within ~3 min after push)
cd /home/gurpreet/projects/k8s/bbi-infrastructure
git log --oneline -10 apps/mereka-lms/overlays/prod/kustomization.yaml   # find prior commit
git revert HEAD --no-edit
git push origin main

# Also revert app repo overlay to keep them in sync (AC-DEP-004)
cd /home/gurpreet/projects/k8s/mereka-lms
git revert HEAD --no-edit
git push origin main
```

### Option C: Emergency kubectl rollback

> WARNING: ArgoCD will revert within ~3 min. Only use this to buy time while Option A/B is prepared.

```bash
kubectl -n mereka-lms rollout undo deployment/lms
kubectl -n mereka-lms rollout undo deployment/cms
kubectl -n mereka-lms rollout undo deployment/mfe

# Immediately verify endpoints still serving traffic
kubectl get endpoints -n mereka-lms
```

### Post-rollback verification

```bash
# Confirm pods settled
kubectl -n mereka-lms rollout status deployment/lms --timeout=120s
kubectl -n mereka-lms rollout status deployment/cms --timeout=120s

# Re-run health checks
./scripts/qa/public-health-check.sh prod
./scripts/branding/run-branding-gates.sh prod

# Document incident
# → docs/operations/postmortems/ (create new file)
```

---

## Release Notes Template

```markdown
## Release: Branding <TAG>

**Date**: YYYY-MM-DD HH:MM UTC
**Commit SHA**: <full-sha>
**Short SHA**: <short-sha>

**Images**:
- LMS/CMS: `asia-southeast1-docker.pkg.dev/mereka-lms/openedx/openedx:<tag>`
  - Digest: `sha256:<openedx-digest>`
- MFE: `asia-southeast1-docker.pkg.dev/mereka-lms/openedx/openedx-mfe:<tag>`
  - Digest: `sha256:<mfe-digest>`

**Changes**:
- <describe branding/MFE changes>

**Verification**:
- Evidence pipeline: PASS (5/5 gates)
- Tenant domains: 3/3 HTTP 200
- Post-deploy branding gates: PASS
- GitOps drift check: PASS

**Rollback tag**: `<previous-known-good-tag>`
```

---

## GitOps Drift Check (AC-DEP-004)

The canonical drift check script is `scripts/qa/verify-gitops-drift.sh`. It validates that the
GitOps overlay (bbi-infrastructure) reflects the same custom apps and middleware as the source repo.

```bash
./scripts/qa/verify-gitops-drift.sh

# Also check image override contract parity
./scripts/qa/verify-gitops-image-overrides.sh
```

Manual inspection if needed:

```bash
# Custom apps in source production.py
grep -o "'[a-z_]*'" deploy/k8s/base/apps/openedx/settings/lms/production.py \
  | sort | uniq

# Custom apps in GitOps overlay (path may vary)
grep -o "'[a-z_]*'" /home/gurpreet/projects/k8s/bbi-infrastructure/apps/mereka-lms/overlays/prod/patches/production-prod.py \
  | sort | uniq 2>/dev/null || echo "overlay not found locally"
```

---

## Reference

- Canonical release orchestrator: `scripts/infra/release-openedx-gitops.sh`
- Image override contract: `scripts/qa/verify-gitops-image-overrides.sh`
- Branding evidence pipeline: `scripts/qa/run-branding-evidence-pipeline.sh`
- ADR-012 (no runtime CSS overlay): `docs/adr/012-no-runtime-css-overlay.md`
- General release checklist: `docs/operations/RELEASE_CHECKLIST.md`
- Tenant branding QA: `docs/operations/TENANT_BRANDING_QA_RUNBOOK.md`
