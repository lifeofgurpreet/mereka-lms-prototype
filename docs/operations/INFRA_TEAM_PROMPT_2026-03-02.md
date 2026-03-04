# Infra Team Action Items — 2026-03-02

**Context**: CI hardening work on `mereka-lms` is complete. 148/162 scripts pass. The remaining 4 failures all require infra team action in **bbi-infrastructure** and/or image rebuilds.

**Prerequisite**: PR #123 (`start/next-implementor-2026-03-01` → `main`) must be merged first. All image builds pull from `main`.

---

## Action 1: Merge PR #123 in mereka-lms

**PR**: https://github.com/Biji-Biji-Initiative/mereka-lms/pull/123
**What**: 62 commits — CI script hardening, branding fixes, runtime blocker reporting
**Why**: All downstream image builds and ArgoCD promotion work off `main`. Nothing below works until this is merged.

---

## Action 2: Rebuild and Deploy openedx Image

**Why**: Production is running `mereka-brand-hotfix-full-v3` which is missing:
- Latest Mereka theme branding (Poppins/Lato fonts, logo assets, footer white-labeling)
- Branding revision marker `2026-02-25-wcag-aa`
- Studio footer white-label (still shows "Powered by Open edX")

**Steps**:
```bash
# In mereka-lms repo (after PR #123 is merged to main)
git checkout main && git pull

# Build openedx image
source infrastructure/tutor/tutor-env.sh
export TUTOR_ROOT="$(pwd)/tutor_env"
tutor config save
./infrastructure/tutor/apply-patches.sh
tutor images build openedx

# Tag and push
IMAGE=ghcr.io/biji-biji-initiative/mereka-lms/openedx
TAG="main-$(git rev-parse --short HEAD)-$(date +%Y%m%d)"
docker tag openedx:latest "$IMAGE:$TAG"
docker push "$IMAGE:$TAG"
```

**Then in bbi-infrastructure**:
```bash
# Update production overlay image tag
# File: apps/mereka-lms/overlays/prod/kustomization.yaml
# Set openedx newTag to the new $TAG value
```

**Verification**: After ArgoCD syncs (3 min), run:
```bash
# From mereka-lms repo
bash scripts/qa/verify-public-branding.sh
# Expected: 11 previously-failing checks now PASS
```

---

## Action 3: Rebuild MFE Image (Domain Hardcoding)

**Why**: Current MFE image `900d3d9d-20260301-142349` has 24 hardcoded domain references baked into the JS bundles. These should use runtime config injection.

**Steps**:
```bash
# In mereka-lms repo (main branch)
tutor images build mfe

# Tag and push
MFE_IMAGE=ghcr.io/biji-biji-initiative/mereka-lms/mfe
MFE_TAG="main-$(git rev-parse --short HEAD)-$(date +%Y%m%d)"
docker tag mfe:latest "$MFE_IMAGE:$MFE_TAG"
docker push "$MFE_IMAGE:$MFE_TAG"
```

**Then in bbi-infrastructure**: update MFE image tag in production overlay.

**Verification**:
```bash
bash scripts/qa/verify-multisite-ux-consistency.sh
# Expected: AC-MSUX-002 now PASS (0 hardcoded domain refs)
```

---

## Action 4: Sync bbi-infrastructure Overlay

**Why**: Two drift items detected by `verify-gitops-image-overrides.sh`:

### 4a. OpenEdx Digest Mismatch
- **App repo** (production kustomization): `sha256:907951ebabff35f1843685c97c2fb0a0e5fa0c286adba54d34156ffee594dad4`
- **Infra repo** (prod overlay): `None`

After rebuilding the openedx image (Action 2), update the infra overlay with the new image digest.

### 4b. Vendored MFE Caddyfile Drift
The MFE Caddyfile in the infra repo is stale. Copy the canonical version:

```bash
# Source (app repo):
# mereka-lms/deploy/k8s/base/plugins/mfe/apps/mfe/Caddyfile

# Destination (infra repo):
# bbi-infrastructure/apps/mereka-lms/base/deploy/k8s/base/plugins/mfe/apps/mfe/Caddyfile

cp /path/to/mereka-lms/deploy/k8s/base/plugins/mfe/apps/mfe/Caddyfile \
   /path/to/bbi-infrastructure/apps/mereka-lms/base/deploy/k8s/base/plugins/mfe/apps/mfe/Caddyfile
```

**Verification**:
```bash
bash scripts/qa/verify-gitops-image-overrides.sh
bash scripts/infra/verify-release-preflight.sh
# Expected: both PASS
```

---

## Action 5: Build Custom Credentials Image (tzdata fix)

**Why**: The upstream `overhangio/openedx-credentials:21.0.0` image is missing the `tzdata` Python package, causing `ZoneInfo("UTC")` failures at runtime. This breaks the Verifiable Credentials issuer module.

**Steps**:
```bash
# In mereka-lms repo (after PR #123 is merged to main)
bash scripts/infra/build-credentials-image.sh
```

The script will:
1. Build a wrapper image that adds `tzdata>=2024.1` and `cryptography>=41.0.0`
2. Verify `ZoneInfo("UTC")` resolves correctly inside the container
3. Push to `ghcr.io/biji-biji-initiative/mereka-lms/openedx-credentials:21.0.0-tzdata`
4. Print the deployment manifest update instructions

**Then update** `deploy/k8s/base/deployments.yml` (credentials section):
```yaml
# Change:
image: docker.io/overhangio/openedx-credentials:21.0.0
# To:
image: ghcr.io/biji-biji-initiative/mereka-lms/openedx-credentials:21.0.0-tzdata
```

---

## Execution Order

1. Merge PR #123 (mereka-lms `main`)
2. Rebuild openedx image from `main`
3. Rebuild MFE image from `main`
4. Build credentials image with tzdata fix
5. Update bbi-infrastructure overlay (image tags + Caddyfile)
6. Commit and push bbi-infrastructure changes
7. Wait for ArgoCD sync (3 min)
8. Run verification scripts

---

## Expected Final State

After all 5 actions, the full CI suite should reach **155+/162 PASS**. Credentials service timezone errors resolved. Branding live in production.
