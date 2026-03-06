# GitOps Workflow for Image Tag Management
_Audience: Platform Eng + DevOps • Owner: Engineering Lead • Last updated: 2026-03-06_

> **Deployment boundary**: For the authoritative classification of what belongs in this repo
> vs `BBI-K8` (`/home/gurpreet/projects/k8s/infrastructure`, previously known as `infrastructure`), see [DEPLOYMENT_BOUNDARY.md](../../concepts/architecture/DEPLOYMENT_BOUNDARY.md)
> and [DEPLOYMENT_CONTRACT.md](../../concepts/architecture/DEPLOYMENT_CONTRACT.md).
> Note: `deploy/k8s/overlays/production/` and `overlays/rke2-nonprod/` are classified
> ENVIRONMENT_SPECIFIC and are managed by the active GitOps repo in this environment.

## Overview

Mereka LMS uses a **two-repository GitOps architecture**:

1. **Application Repository** (`mereka-lms`): Source code, base K8s manifests, CI/CD pipeline
2. **Infrastructure Repository** (`BBI-K8`, previously `infrastructure`): Production overlay, ArgoCD configuration

**CRITICAL**: ArgoCD syncs from `BBI-K8` (`/home/gurpreet/projects/k8s/infrastructure`), NOT from `mereka-lms`. Any `kubectl patch` commands targeting production will be reverted on the next ArgoCD sync cycle.

```bash
# Optional defaults used by the examples below
APP_REPO="${APP_REPO:-/home/gurpreet/projects/k8s/mereka-lms}"
INFRA_REPO="${INFRA_REPO:-/home/gurpreet/projects/k8s/infrastructure}"
```

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                   mereka-lms (App Repo)                         │
│  - Source code                                                  │
│  - Base K8s manifests (deploy/k8s/base/)                        │
│  - Production overlay (deploy/k8s/overlays/production/)         │
│  - CI pipeline builds images → pushes to Artifact Registry      │
└─────────────────────────────────────────────────────────────────┘
                              │
                              │ Image tags defined here
                              │ (but NOT used directly by ArgoCD)
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│              BBI-K8 / infrastructure (Infra Repo)           │
│  - Production overlay (apps/mereka-lms/overlays/prod/)          │
│  - ArgoCD Application manifest                                 │
│  - Production-specific patches (settings, ingress, secrets)     │
└─────────────────────────────────────────────────────────────────┘
                              │
                              │ ArgoCD watches this repo
                              │ and syncs to GKE cluster
                              ▼
                       GKE Production Cluster
```

## Why Drift Happens

Image tags can diverge between repositories when:

1. **CI/CD builds new images** in `mereka-lms` repo
   - Updates `deploy/k8s/overlays/production/kustomization.yaml` with new tag
   - But the active infra repo still references old tag

2. **Manual tag updates** in `mereka-lms` for local testing
   - Developer updates app repo overlay for Kind/local testing
   - Forgets to sync tag to infra repo

3. **Hotfixes applied directly to infra repo**
   - Emergency rollback changes tag in the infra repo
   - App repo never updated to match

## Current Image Tag Drift (2026-02-12)

As of commit `[TBD]`, the following drift exists:

| Image | App Repo Tag | Infra Repo Tag | Status |
|-------|--------------|----------------|--------|
| `openedx` | `20260210-v21-mfe-only-b988d63` | `91125f2-20260210164818` | **DRIFT** |
| `openedx-mfe` | `20260208-mfe-discussions-pass4-c17df16` | `b732a7d-20260210161437` | **DRIFT** |

**Impact**: Production cluster runs images defined in infra repo, NOT app repo.

## Verification Commands

### Quick Check
```bash
# From app repo root
./scripts/qa/verify-gitops-image-overrides.sh

# Expected output when drift exists:
# ✗ prod openedx tag drift: app overlay '20260210-v21-mfe-only-b988d63' != infra overlay '91125f2-20260210164818'
# ✗ prod openedx-mfe tag drift: app overlay '20260208-mfe-discussions-pass4-c17df16' != infra overlay 'b732a7d-20260210161437'
```

### Manual Comparison
```bash
# App repo production tags
yq eval '.images[] | "\(.name): \(.newTag)"' \
  deploy/k8s/overlays/production/kustomization.yaml

# Infra repo production tags
yq eval '.images[] | "\(.name): \(.newTag)"' \
  ${INFRA_REPO}/apps/mereka-lms/overlays/prod/kustomization.yaml
```

### Check Live Cluster Images
```bash
kubectl get pods -n mereka-lms -o json | \
  jq -r '.items[] | .spec.containers[] | "\(.name): \(.image)"' | \
  grep -E "(openedx|mfe)" | sort -u
```

## Syncing Tags (Manual Process)

**IMPORTANT**: Always commit to the GitOps infra repo for production changes. Do NOT use `kubectl patch`.

### Step 1: Determine Source of Truth

**When to sync FROM app repo TO infra repo:**
- After CI/CD builds new images
- After QA approval in staging
- When promoting tested local builds

**When to sync FROM infra repo TO app repo:**
- After emergency hotfix/rollback in production
- When documenting current production state

### Step 2: Sync Tags

#### Option A: Sync from App Repo to Infra Repo (Typical)

```bash
# 1. Get tags from app repo
APP_OPENEDX_TAG=$(yq eval '.images[] | select(.name == "docker.io/overhangio/openedx") | .newTag' \
  deploy/k8s/overlays/production/kustomization.yaml)

APP_MFE_TAG=$(yq eval '.images[] | select(.name == "docker.io/overhangio/openedx-mfe") | .newTag' \
  deploy/k8s/overlays/production/kustomization.yaml)

echo "App repo tags:"
echo "  openedx: $APP_OPENEDX_TAG"
echo "  openedx-mfe: $APP_MFE_TAG"

# 2. Update infra repo
cd "$INFRA_REPO"

# Update openedx tag
yq eval -i "(.images[] | select(.name == \"docker.io/overhangio/openedx\") | .newTag) = \"$APP_OPENEDX_TAG\"" \
  apps/mereka-lms/overlays/prod/kustomization.yaml

# Update openedx-mfe tag (both entries)
yq eval -i "(.images[] | select(.name == \"docker.io/overhangio/openedx-mfe\") | .newTag) = \"$APP_MFE_TAG\"" \
  apps/mereka-lms/overlays/prod/kustomization.yaml

yq eval -i "(.images[] | select(.name == \"ghcr.io/biji-biji-initiative/mereka-lms/mfe\") | .newTag) = \"$APP_MFE_TAG\"" \
  apps/mereka-lms/overlays/prod/kustomization.yaml

# 3. Verify changes
git diff apps/mereka-lms/overlays/prod/kustomization.yaml

# 4. Commit to infra repo
git add apps/mereka-lms/overlays/prod/kustomization.yaml
git commit -m "feat(mereka-lms): sync image tags from app repo

- openedx: $APP_OPENEDX_TAG
- openedx-mfe: $APP_MFE_TAG

Source: ${APP_REPO}/deploy/k8s/overlays/production/kustomization.yaml"

git push origin main

# 5. Wait for ArgoCD to sync (auto-sync every 3 minutes, or manual sync via UI)
```

#### Option B: Sync from Infra Repo to App Repo (After Hotfix)

```bash
# 1. Get tags from infra repo
cd "$INFRA_REPO"

INFRA_OPENEDX_TAG=$(yq eval '.images[] | select(.name == "docker.io/overhangio/openedx") | .newTag' \
  apps/mereka-lms/overlays/prod/kustomization.yaml)

INFRA_MFE_TAG=$(yq eval '.images[] | select(.name == "docker.io/overhangio/openedx-mfe") | .newTag' \
  apps/mereka-lms/overlays/prod/kustomization.yaml)

echo "Infra repo tags:"
echo "  openedx: $INFRA_OPENEDX_TAG"
echo "  openedx-mfe: $INFRA_MFE_TAG"

# 2. Update app repo
cd "$APP_REPO"

# Update openedx tag
yq eval -i "(.images[] | select(.name == \"docker.io/overhangio/openedx\") | .newTag) = \"$INFRA_OPENEDX_TAG\"" \
  deploy/k8s/overlays/production/kustomization.yaml

# Update openedx-mfe tag (both entries)
yq eval -i "(.images[] | select(.name == \"docker.io/overhangio/openedx-mfe\") | .newTag) = \"$INFRA_MFE_TAG\"" \
  deploy/k8s/overlays/production/kustomization.yaml

yq eval -i "(.images[] | select(.name == \"ghcr.io/biji-biji-initiative/mereka-lms/mfe\") | .newTag) = \"$INFRA_MFE_TAG\"" \
  deploy/k8s/overlays/production/kustomization.yaml

# 3. Verify changes
git diff deploy/k8s/overlays/production/kustomization.yaml

# 4. Commit to app repo
git add deploy/k8s/overlays/production/kustomization.yaml
git commit -m "docs(k8s): sync production image tags from infra repo

- openedx: $INFRA_OPENEDX_TAG
- openedx-mfe: $INFRA_MFE_TAG

Source: ${INFRA_REPO}/apps/mereka-lms/overlays/prod/kustomization.yaml"

git push origin main
```

### Step 3: Verify Sync

```bash
# From app repo root
./scripts/qa/verify-gitops-image-overrides.sh

# Expected output when synced:
# ✓ GitOps image override contract checks passed
#   base: deploy/k8s/base/kustomization.yaml
#   prod overlay: deploy/k8s/overlays/production/kustomization.yaml
#   staging overlay: deploy/k8s/overlays/staging/kustomization.yaml
#   infra overlay: ${INFRA_REPO}/apps/mereka-lms/overlays/prod/kustomization.yaml
```

### Step 4: Verify Deployment

```bash
# Wait for ArgoCD to sync (or trigger manual sync via UI)
# Check pod images match expected tags
kubectl get pods -n mereka-lms -o json | \
  jq -r '.items[] | select(.metadata.name | startswith("lms-")) | .spec.containers[] | "\(.name): \(.image)"'

# Verify pods are running
kubectl get pods -n mereka-lms -l app.kubernetes.io/name=lms
```

## Semi-Automated Sync Script (Future Enhancement)

```bash
#!/usr/bin/env bash
# scripts/infra/sync-production-tags.sh
set -euo pipefail

APP_REPO="${APP_REPO:-/home/gurpreet/projects/k8s/mereka-lms}"
INFRA_REPO="${INFRA_REPO:-/home/gurpreet/projects/k8s/infrastructure}"

# Get tags from app repo
cd "$APP_REPO"
APP_OPENEDX=$(yq eval '.images[] | select(.name == "docker.io/overhangio/openedx") | .newTag' \
  deploy/k8s/overlays/production/kustomization.yaml)
APP_MFE=$(yq eval '.images[] | select(.name == "docker.io/overhangio/openedx-mfe") | .newTag' \
  deploy/k8s/overlays/production/kustomization.yaml)

# Get tags from infra repo
cd "$INFRA_REPO"
INFRA_OPENEDX=$(yq eval '.images[] | select(.name == "docker.io/overhangio/openedx") | .newTag' \
  apps/mereka-lms/overlays/prod/kustomization.yaml)
INFRA_MFE=$(yq eval '.images[] | select(.name == "docker.io/overhangio/openedx-mfe") | .newTag' \
  apps/mereka-lms/overlays/prod/kustomization.yaml)

# Compare
echo "Tag comparison:"
echo "  openedx:     app=$APP_OPENEDX, infra=$INFRA_OPENEDX"
echo "  openedx-mfe: app=$APP_MFE, infra=$INFRA_MFE"

if [[ "$APP_OPENEDX" == "$INFRA_OPENEDX" && "$APP_MFE" == "$INFRA_MFE" ]]; then
  echo "✓ Tags are in sync"
  exit 0
fi

echo ""
echo "⚠️  Drift detected. Update infra repo? (y/N)"
read -r confirm
if [[ "$confirm" != "y" ]]; then
  echo "Aborted."
  exit 1
fi

# Apply updates
yq eval -i "(.images[] | select(.name == \"docker.io/overhangio/openedx\") | .newTag) = \"$APP_OPENEDX\"" \
  apps/mereka-lms/overlays/prod/kustomization.yaml
yq eval -i "(.images[] | select(.name == \"docker.io/overhangio/openedx-mfe\") | .newTag) = \"$APP_MFE\"" \
  apps/mereka-lms/overlays/prod/kustomization.yaml
yq eval -i "(.images[] | select(.name == \"ghcr.io/biji-biji-initiative/mereka-lms/mfe\") | .newTag) = \"$APP_MFE\"" \
  apps/mereka-lms/overlays/prod/kustomization.yaml

git diff apps/mereka-lms/overlays/prod/kustomization.yaml
echo ""
echo "Commit these changes? (y/N)"
read -r confirm_commit
if [[ "$confirm_commit" != "y" ]]; then
  git restore apps/mereka-lms/overlays/prod/kustomization.yaml
  echo "Changes discarded."
  exit 1
fi

git add apps/mereka-lms/overlays/prod/kustomization.yaml
git commit -m "feat(mereka-lms): sync image tags from app repo

- openedx: $APP_OPENEDX
- openedx-mfe: $APP_MFE"

echo "✓ Changes committed. Push with: git push origin main"
```

## Best Practices

### 1. Always Verify Before Committing
```bash
# From app repo
./scripts/qa/verify-gitops-image-overrides.sh
```

### 2. Document Tag Changes in Commit Messages
```
feat(mereka-lms): sync image tags from app repo

- openedx: 20260210-v21-mfe-only-b988d63
- openedx-mfe: 20260208-mfe-discussions-pass4-c17df16

Source: ${APP_REPO}/deploy/k8s/overlays/production/kustomization.yaml
Reason: Promoting QA-approved build to production
```

### 3. Never Use kubectl patch for Production
ArgoCD will revert any manual changes on the next sync cycle (every 3 minutes).

**WRONG:**
```bash
kubectl patch deployment lms -n mereka-lms --type='json' \
  -p='[{"op": "replace", "path": "/spec/template/spec/containers/0/image", "value": "new-image:tag"}]'
```

**RIGHT:**
```bash
# Update ${INFRA_REPO}/apps/mereka-lms/overlays/prod/kustomization.yaml
# Commit and push
# ArgoCD will sync automatically
```

### 4. Use Pre-Commit Hooks
Add `verify-gitops-image-overrides.sh` to pre-commit:

```yaml
# .pre-commit-config.yaml (app repo)
- repo: local
  hooks:
    - id: verify-gitops-tags
      name: Verify GitOps image tags
      entry: scripts/qa/verify-gitops-image-overrides.sh
      language: script
      pass_filenames: false
      files: deploy/k8s/overlays/production/kustomization\.yaml$
```

### 5. Keep Image Tag Format Consistent

**Preferred format:** `{git-sha}-{date}-{build-id}`
- Example: `b988d63-20260210164818`

**Semantic tags:** `{date}-{description}-{git-sha}`
- Example: `20260210-v21-mfe-only-b988d63`

**Avoid:** `latest`, `stable`, `prod` (non-deterministic)

## Rollback Process

### Emergency Rollback (Production Down)

```bash
# 1. Identify last working tag
kubectl get events -n mereka-lms --sort-by='.lastTimestamp' | grep -i "image pull"

# 2. Update infra repo to previous tag
cd "$INFRA_REPO"
yq eval -i '(.images[] | select(.name == "docker.io/overhangio/openedx") | .newTag) = "PREVIOUS_TAG"' \
  apps/mereka-lms/overlays/prod/kustomization.yaml

# 3. Commit and push
git add apps/mereka-lms/overlays/prod/kustomization.yaml
git commit -m "fix(mereka-lms): emergency rollback to PREVIOUS_TAG"
git push origin main

# 4. Force ArgoCD sync (don't wait 3 minutes)
kubectl patch app mereka-lms -n argocd --type merge -p '{"operation": {"initiatedBy": {"username": "admin"}, "sync": {}}}'

# 5. Monitor rollout
kubectl rollout status deployment/lms -n mereka-lms
```

### Planned Rollback (Testing Failed)

Same process but with more deliberate commit message:

```bash
git commit -m "chore(mereka-lms): rollback to stable tag

Rolling back from FAILED_TAG to PREVIOUS_TAG due to:
- [Issue 1]
- [Issue 2]

Previous tag verified stable in production on 2026-02-XX."
```

## Troubleshooting

### Issue: ArgoCD Shows "OutOfSync" But Tags Match

**Cause**: ConfigMap hash suffix changed, or other overlay differences.

**Solution:**
```bash
# Check full diff
argocd app diff mereka-lms

# If only hash suffixes differ, sync
argocd app sync mereka-lms
```

### Issue: Pods Still Running Old Image After Sync

**Cause**: Deployment didn't rollout (tag was already set).

**Solution:**
```bash
# Force rollout by adding annotation
kubectl patch deployment lms -n mereka-lms -p \
  "{\"spec\":{\"template\":{\"metadata\":{\"annotations\":{\"rollout-trigger\":\"$(date +%s)\"}}}}}"
```

### Issue: Image Pull Errors After Tag Update

**Cause**: Tag doesn't exist in Artifact Registry.

**Solution:**
```bash
# List available tags
gcloud artifacts docker tags list \
  ghcr.io/biji-biji-initiative/mereka-lms/openedx \
  --limit 20 --sort-by=~UPDATE_TIME

# Verify tag exists before updating kustomization.yaml
```

## Related Documentation

- **CI/CD Pipeline**: `docs/ops/ci-cd/CI_CD_SETUP.md`
- **ArgoCD Setup**: `docs/operations/ARGOCD_HEALTH_TROUBLESHOOTING.md`
- **K8s Deployment Guide**: `docs/guides/admin/K8S_OPERATIONS_GUIDE.md`
- **Troubleshooting**: `docs/operations/TROUBLESHOOTING.md`
- **Spec**: `specs/ci-cd-pipeline_spec.md` (AC-014: GitOps image override verification)

## Future Improvements

1. **Automated Tag Sync in CI/CD**
   - GitHub Action to auto-sync tags from app repo to infra repo after CI build
   - Requires PAT with write access to `BBI-K8` (`/home/gurpreet/projects/k8s/infrastructure`)

2. **Slack Notifications on Drift**
   - Daily cron job runs `verify-gitops-image-overrides.sh`
   - Sends Slack alert if drift detected

3. **Tag Provenance in ArgoCD**
   - Annotate Deployment with source commit SHA from app repo
   - Enables tracing image tag back to source code change

4. **Multi-Environment Tag Management**
   - Extend workflow to staging/dev environments
   - Use different tag naming conventions per environment
