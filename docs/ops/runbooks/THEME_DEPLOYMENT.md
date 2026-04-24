# Theme Deployment Guide
_Audience: Operators and developers • Owner: Platform Team • Last verified: 2026-03-12 • Status: active_

<!-- Last verified: 2026-02-13 -->

This guide covers deploying branding/theme changes from the Mereka brand system to the production (GKE) and dev (kind) Open edX environments.

Canonical branding workflow:
- [BRANDING_OPERATING_MODEL.md](../../guides/branding/BRANDING_OPERATING_MODEL.md)
- `./scripts/branding/run-branding-gates.sh prod`

Important:
- Production is GitOps-managed. Direct `kubectl set image` changes are non-durable and will drift.
- Production branding releases must publish images through `.github/workflows/build-tutor-images.yml` and promote them with `scripts/infra/release-openedx-gitops.sh`. Local `tutor images build ...` runs are for dev parity, local reproduction, or debugging only.

## Prerequisites

- Docker installed and running
- `gcloud` CLI authenticated (`gcloud auth login`)
- `kubectl` configured for RKE2 production cluster (`kubectl config use-context rke2-prod`)
- Python 3.10+ with venv activated
- Tutor 21.0.4 installed (via `pip install -r requirements-tutor.txt`)

## One-Command Release (Canonical)

Use this after image build + push is complete:

```bash
./scripts/infra/release-openedx-gitops.sh \
  --openedx-tag <OPENEDX_TAG> \
  --mfe-tag <MFE_TAG> \
  --openedx-digest sha256:<openedx_digest> \
  --mfe-digest sha256:<mfe_digest> \
  --require-digests \
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
│  1. Brand Assets             2. Publish via workflow                │
│  ┌──────────────────┐          ┌──────────────────┐                 │
│  │ bbbi-mereka-     │   copy   │ infrastructure/  │                 │
│  │ brand-assets/    │ ───────► │ tutor/themes/    │                 │
│  │ brands/mereka/   │          │ mereka/          │                 │
│  └──────────────────┘          └────────┬─────────┘                 │
│                                         │                            │
│                                         ▼                            │
│                                ┌──────────────────┐                 │
│                                │ build-tutor-     │                 │
│                                │ images.yml       │                 │
│                                └────────┬─────────┘                 │
│                                         │                            │
│  3. Release metadata                     ▼                            │
│  ┌──────────────────┐          ┌──────────────────┐                 │
│  │ release-bundle + │ ◄─────── │ GHCR image tags  │                 │
│  │ build-provenance │  emit    │ + digests        │                 │
│  │ artifacts        │          └──────────────────┘                 │
│  └────────┬─────────┘                                               │
│           │                                                          │
│  4. GitOps│           5. Verify                                      │
│           ▼          ┌──────────────────┐                           │
│  ┌──────────────────┐│ academyv2.mereka.io │                         │
│  │ release-openedx- ││ (production)       │                         │
│  │ gitops.sh        │└──────────────────┘                           │
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
cd <repo-root>

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

It also keeps a theme copy of canonical design tokens at:
`infrastructure/tutor/themes/mereka/common/static/css/mereka-design-tokens.css`.

If you want to refresh `assets/branding/tokens.css` from an upstream export file in the same run,
pass an explicit path:

```bash
BRAND_REPO_TOKENS=/absolute/path/to/tokens.css ./scripts/branding/sync-brand-assets.sh
```

Optional backward-compatible auto-discovery of the sibling `../bbbi-mereka-brand-assets` checkout
is available only when explicitly enabled:

```bash
AUTO_BRAND_REPO_TOKENS=1 ./scripts/branding/sync-brand-assets.sh
```

After intentional token updates, refresh and commit provenance metadata:

```bash
BRAND_ASSETS_REPO=/absolute/path/to/bbbi-mereka-brand-assets \
  ./scripts/branding/update-token-provenance.sh
./scripts/branding/verify-token-drift.sh
```

Optional compatibility mode:

```bash
AUTO_BRAND_ASSETS_REPO=1 ./scripts/branding/update-token-provenance.sh
```

Portability guard (recommended before PR):

```bash
./scripts/qa/verify-branding-script-portability.sh
```

### Step 3: Apply Tutor Patches

**CRITICAL**: Always run the governed prepare path before building:

```bash
./scripts/infra/prepare-tutor-build-context.sh --target all
```

**What the prepare path realizes** (file-system operations via the low-level patch helper):
- Mirrors rendered LMS/CMS theme asset trees from source, not just a hand-picked file list
- Clears rendered theme asset destinations first so removed source assets do not linger
- Syncs templates, CSS, and theme directory structure
- Distributes font files to MFE build context

**What the plugin does** (automatic via Tutor hooks):
- MySQL 8 authentication fix
- MFE Node build toolchain
- MFE npm retry + timeout hardening for transient network failures
- Webpack memory limits
- CSRF/CORS configuration
- Custom Mereka footer for MFEs (component injection)
- Google Fonts stripping from SCSS sources

### Step 4: Publish Images (Canonical Production Path)

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
# Publish the merged target SHA through the governed image workflow.
APP_SHA="$(git rev-parse origin/main)"
gh workflow run build-tutor-images.yml \
  --ref main \
  -f build_openedx=true \
  -f build_mfe=true \
  -f update_gitops=false \
  -f target_environment=production \
  -f image_tag="${APP_SHA}"

# Wait for the successful run and download the release artifacts.
RUN_ID="<build-tutor-images run id>"
gh run watch "${RUN_ID}"
gh run download "${RUN_ID}" --name release-bundle --dir "var/release-artifacts/${RUN_ID}"
gh run download "${RUN_ID}" --name build-provenance --dir "var/release-artifacts/${RUN_ID}"
```

**Production publish discipline:**
- Prefer the push-to-`main` `build-tutor-images.yml` run for the merged change; use `workflow_dispatch` only for deliberate rebuilds.
- Use the workflow-emitted immutable tags/digests plus the `release-bundle` and `build-provenance` artifacts as release inputs.
- Do not hand-tag or hand-push production images from a local shell as the normal path.

### Local reproduction / debugging only

Use local Tutor builds only for debugging, parity checks, or kind workflows:

```bash
source .venv/bin/activate
export TUTOR_ROOT="$(pwd)/tutor_env"
./scripts/infra/prepare-tutor-build-context.sh --target all
./scripts/infra/build-openedx-image.sh --local-defaults --build-profile fast
./scripts/qa/verify-mfe-build-prereqs.sh
./scripts/infra/build-mfe-image.sh --local-defaults --build-profile fast
./scripts/qa/verify-mfe-image-branding.sh tutor_local/openedx-mfe:latest
```

Run only one MFE image build at a time. If npm network errors occur (`ECONNRESET`, `ETIMEDOUT`), rerun the same helper command after the active run exits; do not launch parallel retries.

### Step 5: Promote via GitOps

```bash
./scripts/infra/release-openedx-gitops.sh \
  --openedx-tag "<OPENEDX_TAG>" \
  --mfe-tag "<MFE_TAG>" \
  --openedx-digest "sha256:<openedx_digest>" \
  --mfe-digest "sha256:<mfe_digest>" \
  --require-digests \
  --apply --commit --push --verify-runtime
```

This is the canonical production promotion path. It updates the app repo and GitOps repo consistently, enforces digest-aware release integrity, and verifies runtime convergence.

### Step 6: Verify Deployment

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
INFRA_REPO="${INFRA_REPO:-<path-to-bbi-infrastructure>}"
git -C "${INFRA_REPO}" log --oneline -n 5
git -C "${INFRA_REPO}" revert <bad_commit_sha>
git -C "${INFRA_REPO}" push

# 2) Confirm Argo converges back to known-good revision/images.
kubectl --context rke2-prod -n argocd get applications.argoproj.io mereka-lms-local \
  -o jsonpath='{.status.sync.status} {.status.health.status} {.status.sync.revision}{"\n"}'
kubectl --context rke2-prod -n mereka-lms get deploy mfe \
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
INFRA_REPO="${INFRA_REPO:-<path-to-bbi-infrastructure>}"
rg -n "openedx-mfe|openedx:" "${INFRA_REPO}/apps/mereka-lms/overlays/prod/kustomization.yaml"

# Contract check
./scripts/qa/verify-gitops-image-overrides.sh --check-infra
```

### Styles Not Appearing

1. Check browser cache (hard refresh: Ctrl+Shift+R)
2. Verify theme is enabled in Tutor config
3. Check that `prepare-tutor-build-context.sh --target all` or `tutor-config-save.sh` was run before build
4. Inspect element to verify CSS is loading

### Font Not Loading

1. Check font files exist in `common/static/fonts/`
2. Verify @font-face paths in `_fonts.scss`
3. Check browser network tab for 404s on font files

## Quick Reference Commands

```bash
# Canonical production deployment sequence
./scripts/branding/sync-brand-assets.sh
AUDIT_STRICT=1 ./scripts/branding/run-branding-gates.sh prod
APP_SHA="$(git rev-parse origin/main)"
gh workflow run build-tutor-images.yml --ref main -f build_openedx=true -f build_mfe=true -f update_gitops=false -f target_environment=production -f image_tag="${APP_SHA}"
RUN_ID="<build-tutor-images run id>"
gh run watch "${RUN_ID}"
gh run download "${RUN_ID}" --name release-bundle --dir "var/release-artifacts/${RUN_ID}"
gh run download "${RUN_ID}" --name build-provenance --dir "var/release-artifacts/${RUN_ID}"
./scripts/infra/release-openedx-gitops.sh --openedx-tag "${APP_SHA}" --mfe-tag "${APP_SHA}" --openedx-digest "sha256:<openedx_digest>" --mfe-digest "sha256:<mfe_digest>" --require-digests --apply --commit --push --verify-runtime

# Check Argo + live image
kubectl --context rke2-prod -n argocd get applications.argoproj.io mereka-lms-local -o jsonpath='{.status.sync.status} {.status.health.status} {.status.sync.revision}{"\n"}'
kubectl --context rke2-prod -n mereka-lms get deploy mfe -o jsonpath='{.spec.template.spec.containers[0].image}{"\n"}'
```

## Related Documentation

- [BRANDING.md](../../guides/branding/BRANDING.md) - Brand guidelines and token reference
- [TROUBLESHOOTING.md](./TROUBLESHOOTING.md) - General troubleshooting
- [Standing Orders](../../meta/standing-orders/README.md) - Canonical maintainer and agent standing orders
- [Brand Assets Repository](https://github.com/biji-biji-initiative/bbbi-mereka-brand-assets)
