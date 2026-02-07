# Theme Deployment Guide

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
│  4. Deploy│           5. Verify                                      │
│           ▼          ┌──────────────────┐                           │
│  ┌──────────────────┐│ academyv2.mereka.io │                         │
│  │ kubectl set      ││ (production)       │                         │
│  │ image deployment │└──────────────────┘                           │
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
./scripts/branding/run-branding-gates.sh prod
```

Equivalent source-only gate:

```bash
BRANDING_LEVEL=deep ./scripts/branding/verify-branding-health.sh
```

```bash
# Activate environment
source .venv/bin/activate
export TUTOR_ROOT="$(pwd)/tutor_env"

# Build OpenEdX image (LMS/CMS/workers)
tutor images build openedx

# Build MFE image (if MFE styling changed)
tutor images build mfe

# Verify built MFE branding contract before push
./scripts/qa/verify-mfe-image-branding.sh tutor_local/openedx-mfe:latest
```

**Build discipline:**
- Run only one `tutor images build mfe` at a time.
- If npm network errors occur (`ECONNRESET`, `ETIMEDOUT`), rerun the same command after the active run exits; do not launch parallel retries.
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

### Step 8: Update Kubernetes Deployments

Production is **GitOps-managed**. Prefer updating the pinned `?ref=<git_sha>` in `bbi-infrastructure`
so ArgoCD rolls the change and the system converges without drift. Direct `kubectl set image` is for
emergencies only (it will be reverted by ArgoCD if GitOps still points at the old ref).

```bash
# LMS
kubectl set image deployment/lms \
  lms=asia-southeast1-docker.pkg.dev/mereka-lms/openedx/openedx:${TAG} \
  -n mereka-lms

# CMS (Studio)
kubectl set image deployment/cms \
  cms=asia-southeast1-docker.pkg.dev/mereka-lms/openedx/openedx:${TAG} \
  -n mereka-lms

# LMS Worker
kubectl set image deployment/lms-worker \
  lms-worker=asia-southeast1-docker.pkg.dev/mereka-lms/openedx/openedx:${TAG} \
  -n mereka-lms

# CMS Worker
kubectl set image deployment/cms-worker \
  cms-worker=asia-southeast1-docker.pkg.dev/mereka-lms/openedx/openedx:${TAG} \
  -n mereka-lms

# MFE (if built)
kubectl set image deployment/mfe \
  mfe=asia-southeast1-docker.pkg.dev/mereka-lms/openedx/openedx-mfe:mereka-brand \
  -n mereka-lms
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
# Rollback to stock images
kubectl set image deployment/lms \
  lms=docker.io/overhangio/openedx:18.2.2-indigo \
  -n mereka-lms

kubectl set image deployment/cms \
  cms=docker.io/overhangio/openedx:18.2.2-indigo \
  -n mereka-lms

kubectl set image deployment/lms-worker \
  lms-worker=docker.io/overhangio/openedx:18.2.2-indigo \
  -n mereka-lms

kubectl set image deployment/cms-worker \
  cms-worker=docker.io/overhangio/openedx:18.2.2-indigo \
  -n mereka-lms

kubectl set image deployment/mfe \
  mfe=docker.io/overhangio/openedx-mfe:18.1.0-indigo \
  -n mereka-lms
```

Or rollback to a previous custom image:
```bash
kubectl set image deployment/lms \
  lms=asia-southeast1-docker.pkg.dev/mereka-lms/openedx/openedx:PREVIOUS_TAG \
  -n mereka-lms
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

Check if image tag is correct:
```bash
kubectl get deployment lms -n mereka-lms -o jsonpath='{.spec.template.spec.containers[0].image}'
```

Force pod restart if needed:
```bash
kubectl rollout restart deployment/lms -n mereka-lms
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
docker tag tutor_local/openedx:latest asia-southeast1-docker.pkg.dev/mereka-lms/openedx/openedx:TAG
docker push asia-southeast1-docker.pkg.dev/mereka-lms/openedx/openedx:TAG
kubectl set image deployment/lms lms=asia-southeast1-docker.pkg.dev/mereka-lms/openedx/openedx:TAG -n mereka-lms
kubectl set image deployment/cms cms=asia-southeast1-docker.pkg.dev/mereka-lms/openedx/openedx:TAG -n mereka-lms

# Check current images
kubectl get pods -n mereka-lms -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.containers[0].image}{"\n"}{end}'

# Watch logs during deployment
kubectl logs -f deployment/lms -n mereka-lms
```

## Related Documentation

- [BRANDING.md](../BRANDING.md) - Brand guidelines and token reference
- [TROUBLESHOOTING.md](./TROUBLESHOOTING.md) - General troubleshooting
- [CLAUDE.md](../../CLAUDE.md) - Repository overview and workflows
- [Brand Assets Repository](https://github.com/biji-biji-initiative/bbbi-mereka-brand-assets)
