# Theme Deployment Guide

<!-- Last verified: 2026-02-13 -->

This guide covers deploying branding/theme changes from the Mereka brand system to the production (GKE) and dev (kind) Open edX environments.

Canonical branding workflow:
- `docs/branding/BRANDING_OPERATING_MODEL.md`
- `./scripts/branding/run-branding-gates.sh prod`

Important:
- Production is GitOps-managed. Direct `kubectl set image` changes are non-durable and will drift.

## Prerequisites

- Docker installed and running
- `gcloud` CLI authenticated (`gcloud auth login`)
- `kubectl` configured for GKE cluster (`gcloud container clusters get-credentials bbi-k8-cluster --zone asia-southeast1-c`)
- Python 3.10+ with venv activated
- Tutor 18.2.2 installed

## One-Command Release (Canonical)

Use this after image build + push is complete:

```bash
./scripts/infra/release-openedx-gitops.sh \
  --openedx-tag <OPENEDX_TAG> \
  --mfe-tag <MFE_TAG> \
  --apply --commit --push --verify-runtime
```

This updates:
- app repo image tags (`deploy/k8s/base` + `deploy/k8s/overlays/production`)
- GitOps base `?ref=` pointer
- GitOps production overlay image tags
- cross-repo tag/ref contract verification before push
- optional runtime convergence verification against Argo + live `Deployment/mfe`

## Dev (kind) Parity Rollout (Canonical)

Use this after updating local overlay tags in `deploy/k8s/overlays/local/kustomization.yaml`:

```bash
./scripts/infra/apply-kind-overlay.sh
```

This script now performs the full dev parity chain:
- loads both Open edX and MFE images into kind (`scripts/infra/kind-load-openedx-image.sh`)
- applies local overlay
- waits for LMS/CMS/worker rollouts
- runs dev public health checks
- runs dev branding checks

Important Caddy note for service-domain authn fixes:
- inside `handle /authn/*`, use explicit `reverse_proxy mfe:8002` with header passthrough
- do not use `import proxy "mfe:8002"` inside `handle` (it imports `log`, which is invalid in ordered handler chains)

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                         DEPLOYMENT FLOW                              │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  1. Brand Assets                2. Build                             │
│  ┌──────────────────┐          ┌──────────────────┐                 │
│  │ bbbi-mereka-     │   copy   │ infrastructure/  │                 │
│  │ brand-assets/    │ ───────► │ tutor/themes/    │                 │
│  │ brands/mereka/   │          │ mereka/          │                 │
│  └──────────────────┘          └────────┬─────────┘                 │
│                                         │                            │
│                                         ▼                            │
│                                ┌──────────────────┐                 │
│                                │ tutor images     │                 │
│                                │ build openedx    │                 │
│                                └────────┬─────────┘                 │
│                                         │                            │
│  3. Push                                ▼                            │
│  ┌──────────────────┐          ┌──────────────────┐                 │
│  │ asia-southeast1- │ ◄─────── │ docker tag +     │                 │
│  │ docker.pkg.dev/  │   push   │ docker push      │                 │
│  │ mereka-lms/      │          └──────────────────┘                 │
│  └────────┬─────────┘                                               │
│           │                                                          │
│  4. GitOps│           5. Verify                                      │
│           ▼          ┌──────────────────┐                           │
│  ┌──────────────────┐│ academyv2.mereka.io │                         │
│  │ commit/push      ││ (production)       │                         │
│  │ overlay+ref      │└──────────────────┘                           │
│  └──────────────────┘                                               │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

## Brand Asset Sources

Official Mereka brand assets are maintained in:
```
https://github.com/biji-biji-initiative/bbbi-mereka-brand-assets/tree/main/brands/mereka
```

### Color Palette

| Color | Hex | RGB | Usage |
|-------|-----|-----|-------|
| **Teal** | `#2d898b` | rgb(45, 137, 139) | Primary accent, hover states, secondary actions |
| **Magenta** | `#ab3b78` | rgb(171, 59, 120) | CTA buttons, highlights, special callouts |
| **Blue** | `#295cad` | rgb(41, 92, 173) | Links, info states, tertiary actions |
| **Black** | `#000000` | rgb(0, 0, 0) | Primary text, headings |
| **White** | `#ffffff` | rgb(255, 255, 255) | Backgrounds, inverse text |
| **Burgundy** | `#8c002f` | rgb(140, 0, 47) | Error states (dark) |
| **Pink** | `#cd89ae` | rgb(205, 137, 174) | Light accents |
| **Light Blue** | `#94d1e4` | rgb(148, 209, 228) | Info backgrounds |
| **Orange** | `#e18437` | rgb(225, 132, 55) | Warning states |
| **Yellow** | `#f4be48` | rgb(244, 190, 72) | Highlights, ratings |
| **Seafoam** | `#8fbec2` | rgb(143, 190, 194) | Success backgrounds |
| **Periwinkle** | `#7f9dce` | rgb(127, 157, 206) | Info accents |
| **Forest Green** | `#2c6e49` | rgb(44, 110, 73) | Success states |

### Typography

| Font | Usage |
|------|-------|
| **Lato** | Headings, navigation, UI labels |
| **Poppins** | Body text, paragraphs, longer content |

### Type Scale

| Style | Size | Line Height | Font |
|-------|------|-------------|------|
| Display | 48px | 1.2 | Lato Bold |
| H1 | 36px | 1.25 | Lato Bold |
| H2 | 28px | 1.3 | Lato Bold |
| H3 | 24px | 1.35 | Lato Bold |
| H4 | 20px | 1.4 | Lato Bold |
| Body | 16px | 1.5 | Poppins Regular |
| Body Small | 14px | 1.5 | Poppins Regular |
| Caption | 12px | 1.5 | Poppins Regular |

## Theme File Structure

```
infrastructure/tutor/themes/mereka/
├── scss/
│   ├── _fonts.scss       # @font-face declarations
│   ├── _tokens.scss      # Brand colors, typography, spacing, shadows
│   └── theme.scss        # Utility classes, component styling
├── common/
│   └── static/
│       ├── fonts/        # Lato + Poppins woff2 files
│       └── images/       # Logos, favicons
├── lms/
│   ├── static/sass/theme.scss  # LMS SCSS entry
│   └── templates/        # Template overrides (footer, header, hero)
├── cms/
│   └── static/sass/theme.scss  # Studio SCSS entry
└── mfe/
    ├── mereka.scss       # MFE-specific styling
    ├── fonts/            # Font files for MFE bundling
    └── images/           # Logo files for MFE bundling
```

## Step-by-Step Deployment

### Step 1: Update Theme Files

Edit the theme files as needed:

```bash
cd /home/gurpreet/projects/k8s/mereka-lms

# Color tokens
vim infrastructure/tutor/themes/mereka/scss/_tokens.scss

# Utility classes and component styling
vim infrastructure/tutor/themes/mereka/scss/theme.scss

# MFE-specific styling
vim infrastructure/tutor/themes/mereka/mfe/mereka.scss
```

### Step 2: Sync Brand Assets

If you've updated logos, fonts, or favicons in `assets/branding/`:

```bash
./scripts/branding/sync-brand-assets.sh
```

This copies assets to:
- `infrastructure/tutor/themes/mereka/common/static/` (LMS/Studio)
- `infrastructure/tutor/themes/mereka/mfe/` (MFE bundling)

It also refreshes the canonical design-system token export (`assets/branding/tokens.css`) from the
local `bbbi-mereka-brand-assets` repo when present, and keeps a theme copy at:
`infrastructure/tutor/themes/mereka/common/static/css/mereka-design-tokens.css`.

After intentional token updates, refresh and commit provenance metadata:

```bash
./scripts/branding/update-token-provenance.sh
./scripts/branding/verify-token-drift.sh
```

### Step 3: Apply Tutor Patches

**CRITICAL**: Always run this before building:

```bash
./infrastructure/tutor/apply-patches.sh
```

This applies:
- MySQL 8 authentication fix
- MFE Node 18 build toolchain
- MFE npm retry + timeout hardening for transient network failures
- Webpack memory limits
- CSRF/CORS configuration
- Custom Mereka footer for MFEs

### Step 4: Build Docker Images

Before building, run the branding gates (this is the source-of-truth check that prevents regressions):

```bash
AUDIT_STRICT=1 ./scripts/branding/run-branding-gates.sh prod
```

Equivalent source-only gate:

```bash
BRANDING_LEVEL=deep ./scripts/branding/verify-branding-health.sh
./scripts/qa/verify-studio-authoring-branding.sh prod --source-only
```

```bash
# Activate environment
source .venv/bin/activate
export TUTOR_ROOT="$(pwd)/tutor_env"

# Build OpenEdX image (LMS/CMS/workers)
tutor images build openedx

# Preflight MFE generated Dockerfile prerequisites
./scripts/qa/verify-mfe-build-prereqs.sh

# Build MFE image (if MFE styling changed)
tutor images build mfe

# Verify built MFE branding contract before push
./scripts/qa/verify-mfe-image-branding.sh tutor_local/openedx-mfe:latest

# Verify Kustomize image override contract (prevents transformed-name tag drift)
./scripts/qa/verify-gitops-image-overrides.sh --check-infra
```

**Build discipline:**
- Run only one `tutor images build mfe` at a time.
- If npm network errors occur (`ECONNRESET`, `ETIMEDOUT`), rerun the same command after the active run exits; do not launch parallel retries.
- If MFE build fails with `Can't resolve '@openedx/frontend-plugin-framework'`, rerun
  `./infrastructure/tutor/apply-patches.sh` before retrying; it patches generated MFE Dockerfiles
  to inject the required dependency install for Indigo `env.config.jsx`.
- If authn index points to an unbranded CSS bundle, repair deterministically before push:
  `./scripts/branding/repair-mfe-authn-branding.sh <source_image> <target_image>`

**Build Times:**
- First build (no cache): 60-90 minutes
- Subsequent builds (with cache): 10-20 minutes

### Step 5: Authenticate to Artifact Registry

```bash
gcloud auth configure-docker asia-southeast1-docker.pkg.dev
```

### Step 6: Tag Images

Choose a meaningful tag (e.g., git SHA, date, or release name):

```bash
# Current production tag (Atlas SRV fix)
TAG="20260204-dnspython"
```

```bash
# OpenEdX image
docker tag tutor_local/openedx:latest \
  asia-southeast1-docker.pkg.dev/mereka-lms/openedx/openedx:${TAG}

# MFE image (if built)
docker tag tutor_local/openedx-mfe:latest \
  asia-southeast1-docker.pkg.dev/mereka-lms/openedx/openedx-mfe:${TAG}
```

### Step 7: Push to Artifact Registry

```bash
docker push asia-southeast1-docker.pkg.dev/mereka-lms/openedx/openedx:${TAG}
docker push asia-southeast1-docker.pkg.dev/mereka-lms/openedx/openedx-mfe:${TAG}
```

### Step 8: Update GitOps Sources (Production)

Production is **GitOps-managed** by Argo app `mereka-lms-local` from:
- repo: `Biji-Biji-Initiative/BBI-K8` (older docs may still mention `bbi-infrastructure`)
- path: `apps/mereka-lms/overlays/prod`

Do not use `kubectl set image` for normal releases.

Fast path: use `scripts/infra/release-openedx-gitops.sh` (section above).

```bash
# 1) Push this repo first (mereka-lms) so the new base ref exists remotely.
git -C /home/gurpreet/projects/k8s/mereka-lms push

# 2) In GitOps repo checkout, update BOTH:
#    a) pinned base ref
#    b) production overlay image tags
git -C /home/gurpreet/projects/k8s/infrastructure pull --rebase
$EDITOR /home/gurpreet/projects/k8s/infrastructure/apps/mereka-lms/base/kustomization.yaml
$EDITOR /home/gurpreet/projects/k8s/infrastructure/apps/mereka-lms/overlays/prod/kustomization.yaml

# 3) Verify no image-tag drift between repos before push.
./scripts/qa/verify-gitops-image-overrides.sh --check-infra

# 4) Commit + push GitOps repo.
git -C /home/gurpreet/projects/k8s/infrastructure add apps/mereka-lms/base/kustomization.yaml apps/mereka-lms/overlays/prod/kustomization.yaml
git -C /home/gurpreet/projects/k8s/infrastructure commit -m "chore: rollout openedx/openedx-mfe tags ${TAG}"
git -C /home/gurpreet/projects/k8s/infrastructure push
```

### Step 9: Verify Deployment

```bash
# Watch rollout status
kubectl rollout status deployment/lms -n mereka-lms
kubectl rollout status deployment/cms -n mereka-lms
kubectl rollout status deployment/mfe -n mereka-lms

# Verify pods are using new images
kubectl get pods -n mereka-lms -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.containers[0].image}{"\n"}{end}'
```

Run the automated public checks (treat these as release gates):

```bash
CHECK_CERTS=1 CHECK_BRANDING=1 ./scripts/qa/public-health-check.sh prod
BRANDING_LEVEL=deep ./scripts/qa/verify-public-branding.sh prod
./scripts/qa/capture-branding-screenshots.sh prod
```

### Step 10: Visual Verification

Open https://academyv2.mereka.io and verify:

- [ ] **Logo**: Mereka horizontal logo appears in header
- [ ] **Primary text**: Black (#000000)
- [ ] **Accent colors**: Teal (#2d898b) on hover/active states
- [ ] **Links**: Blue (#295cad)
- [ ] **CTA buttons**: Magenta (#ab3b78) available
- [ ] **Footer**: Custom Mereka footer with Biji-Biji Initiative copyright
- [ ] **Fonts**: Lato for headings, Poppins for body (use browser DevTools)
- [ ] **Favicon**: Mereka logomark in browser tab

Also check:
- https://studio.academyv2.mereka.io (Studio branding)
- https://apps.academyv2.mereka.io (MFE branding)

## Rollback Procedure

If issues arise after deployment:

```bash
# 1) Revert GitOps commit(s) in infrastructure checkout.
git -C /home/gurpreet/projects/k8s/infrastructure log --oneline -n 5
git -C /home/gurpreet/projects/k8s/infrastructure revert <bad_commit_sha>
git -C /home/gurpreet/projects/k8s/infrastructure push

# 2) Confirm Argo converges back to known-good revision/images.
kubectl --context gke_bbi-k8_asia-southeast1-c_bbi-k8-cluster -n argocd get applications.argoproj.io mereka-lms-local \
  -o jsonpath='{.status.sync.status} {.status.health.status} {.status.sync.revision}{"\n"}'
kubectl --context gke_bbi-k8_asia-southeast1-c_bbi-k8-cluster -n mereka-lms get deploy mfe \
  -o jsonpath='{.spec.template.spec.containers[0].image}{"\n"}'
```

## Troubleshooting

### Build Fails with OOM

Ensure Docker has sufficient memory:
- Minimum: 12 GB RAM
- Recommended: 16 GB RAM with 4 GB swap

### 403 Error on Cache Pull

Docker not authenticated to Artifact Registry:
```bash
gcloud auth configure-docker asia-southeast1-docker.pkg.dev
```

### Pods Not Using New Image

Most common cause is GitOps overlay tag drift, not rollout failure.

```bash
# App repo overlay tag
rg -n "openedx-mfe|openedx:" deploy/k8s/overlays/production/kustomization.yaml

# GitOps overlay tag (active source for prod)
rg -n "openedx-mfe|openedx:" /home/gurpreet/projects/k8s/infrastructure/apps/mereka-lms/overlays/prod/kustomization.yaml

# Contract check
./scripts/qa/verify-gitops-image-overrides.sh --check-infra
```

### Styles Not Appearing

1. Check browser cache (hard refresh: Ctrl+Shift+R)
2. Verify theme is enabled in Tutor config
3. Check that `apply-patches.sh` was run before build
4. Inspect element to verify CSS is loading

### Font Not Loading

1. Check font files exist in `common/static/fonts/`
2. Verify @font-face paths in `_fonts.scss`
3. Check browser network tab for 404s on font files

## Quick Reference Commands

```bash
# Full deployment sequence
./scripts/branding/sync-brand-assets.sh
./infrastructure/tutor/apply-patches.sh
source .venv/bin/activate && export TUTOR_ROOT="$(pwd)/tutor_env"
tutor images build openedx
tutor images build mfe
./scripts/qa/verify-mfe-image-branding.sh tutor_local/openedx-mfe:latest
docker tag tutor_local/openedx:latest asia-southeast1-docker.pkg.dev/mereka-lms/openedx/openedx:TAG
docker tag tutor_local/openedx-mfe:latest asia-southeast1-docker.pkg.dev/mereka-lms/openedx/openedx-mfe:TAG
docker push asia-southeast1-docker.pkg.dev/mereka-lms/openedx/openedx:TAG
docker push asia-southeast1-docker.pkg.dev/mereka-lms/openedx/openedx-mfe:TAG
./scripts/qa/verify-gitops-image-overrides.sh --check-infra

# Check Argo + live image
kubectl --context gke_bbi-k8_asia-southeast1-c_bbi-k8-cluster -n argocd get applications.argoproj.io mereka-lms-local -o jsonpath='{.status.sync.status} {.status.health.status} {.status.sync.revision}{"\n"}'
kubectl --context gke_bbi-k8_asia-southeast1-c_bbi-k8-cluster -n mereka-lms get deploy mfe -o jsonpath='{.spec.template.spec.containers[0].image}{"\n"}'
```

## Related Documentation

- [BRANDING.md](../BRANDING.md) - Brand guidelines and token reference
- [TROUBLESHOOTING.md](./TROUBLESHOOTING.md) - General troubleshooting
- [CLAUDE.md](../../CLAUDE.md) - Repository overview and workflows
- [Brand Assets Repository](https://github.com/biji-biji-initiative/bbbi-mereka-brand-assets)
