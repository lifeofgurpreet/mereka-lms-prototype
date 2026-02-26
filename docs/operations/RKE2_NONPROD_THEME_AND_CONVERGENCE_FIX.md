# RKE2 Nonprod: Theme Fix + Source Convergence Plan

**Date**: 2026-02-26
**Status**: In Progress
**Triggered by**: Infrastructure agent handoff + theme investigation

---

## Context

The rke2-nonprod cluster (academyv2.mereka.dev) has two categories of issues:

1. **Theme is completely broken** — the deployed image (`openedx:mereka-brand-hotfix-full-v3`) was NOT built through the Tutor plugin pipeline
2. **Source convergence gaps** — runtime patches from the infra agent need to be made durable in kustomize overlays

---

## Part A: Theme Investigation Findings

### What the user sees

| Element | Expected | Actual | Root Cause |
|---------|----------|--------|------------|
| Logo | Mereka branded (50KB) | Stock Open edX (570B) | collectstatic never collected theme logos |
| Fonts (Poppins/Lato) | Loaded | 404 | `/openedx/staticfiles/mereka/` doesn't exist |
| Brand colors (#2d898b) | In compiled CSS | Absent | SASS not compiled with `--theme mereka` |
| LMS footer | Mereka custom | HTML structure ok, but stock styling | Template resolves but CSS is stock |
| Studio footer | Mereka custom | Completely stock Open edX | Zero mereka CSS/classes on Studio |
| Studio theme | Mereka branded | Completely stock Indigo | studio-main-v1.css has zero mereka tokens |
| Django Site | domain=academyv2.mereka.dev | domain=example.com | Never configured for dev |

### Image diagnosis

Image: `asia-southeast1-docker.pkg.dev/mereka-lms/openedx/openedx:mereka-brand-hotfix-full-v3`

- Theme files EXIST at `/openedx/themes/mereka/` (80+ files, all present)
- `lms-main-v1.css` (989KB) contains ZERO mereka tokens (no Poppins, Lato, #2d898b, #295cad)
- `studio-main-v1.css` (744KB) contains ZERO mereka tokens
- `/openedx/staticfiles/mereka/` directory MISSING (collectstatic never ran with theme)
- `/openedx/staticfiles/fonts/` has no Poppins/Lato (only OpenSans, vendor)
- `/openedx/staticfiles/images/` has ZERO mereka brand images (161 stock images)
- Only `mereka-overrides.css` was manually baked into `/openedx/staticfiles/css/` (old approach)
- `mereka-overrides.css` references `/static/mereka/fonts/*.woff2` → all 404

### Plugin architecture is correct

The `mereka_lms.py` plugin is properly built:
- Sets `DEFAULT_SITE_THEME = "mereka"` via `openedx-lms-production-settings` hook
- Compiles SASS with `--theme mereka` via `openedx-dockerfile-pre-assets` hook
- Strips Google Fonts (two-pass defense)
- Registers MFE footer via Paragon slot system (`org.openedx.frontend.layout.footer.v1`)
- Uses Paragon design tokens bridge (`_tokens.scss`)

**The image just wasn't built through this pipeline.**

---

## Part B: Infrastructure Agent Handoff (Source Convergence)

The bbi-infrastructure agent made runtime fixes that need to be durable in mereka-lms source.

### Task 1: enterprise-catalog-worker Recreate strategy

**File**: `deploy/k8s/overlays/rke2-nonprod/patches/enterprise-catalog-worker-nonprod.yaml` (NEW)

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: enterprise-catalog-worker
spec:
  strategy:
    type: Recreate
```

### Task 2: enterprise-catalog-worker probe hardening

Same file as Task 1 — combine into one patch:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: enterprise-catalog-worker
spec:
  strategy:
    type: Recreate
  template:
    spec:
      containers:
        - name: enterprise-catalog-worker
          readinessProbe:
            timeoutSeconds: 30
            periodSeconds: 30
          livenessProbe:
            timeoutSeconds: 30
```

### Task 3: payments-gateway-secrets ExternalSecret store fix

**File**: `deploy/k8s/overlays/rke2-nonprod/patches/externalsecrets-infisical.yaml` (APPEND)

Add a 5th document to the existing multi-doc YAML:

```yaml
---
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: payments-gateway-secrets
  namespace: mereka-lms
spec:
  refreshInterval: 1h
  secretStoreRef:
    kind: ClusterSecretStore
    name: infisical-secret-store
  target:
    name: payments-gateway-secrets
    creationPolicy: Owner
    deletionPolicy: Retain
  data:
    - secretKey: SECRET_KEY
      remoteRef:
        key: MEREKA_LMS_PAYMENTS_GATEWAY_SECRET_KEY
    - secretKey: DATABASE_URL
      remoteRef:
        key: MEREKA_LMS_PAYMENTS_GATEWAY_DATABASE_URL
    - secretKey: STRIPE_SECRET_KEY
      remoteRef:
        key: MEREKA_LMS_STRIPE_SECRET_KEY_DEV
    - secretKey: STRIPE_WEBHOOK_SECRET
      remoteRef:
        key: MEREKA_LMS_STRIPE_WEBHOOK_SECRET_GATEWAY
    - secretKey: LMS_OAUTH_CLIENT_SECRET
      remoteRef:
        key: MEREKA_LMS_PAYMENTS_GATEWAY_OAUTH2_SECRET
    - secretKey: POSTGRESQL_PASSWORD
      remoteRef:
        key: MEREKA_LMS_PAYMENTS_GATEWAY_POSTGRESQL_PASSWORD
```

Note: Uses `MEREKA_LMS_STRIPE_SECRET_KEY_DEV` (not prod key) — matches pattern from openedx-secrets.

### Task 4: Wire patches into kustomization.yaml

Add to `patches:` section:
```yaml
  - path: patches/enterprise-catalog-worker-nonprod.yaml
```

---

## Part C: Image Rebuild with Plugin Pipeline

### Critical Bug Found and Fixed

The Tutor template structure has a timing issue:
1. `{{ patch("openedx-dockerfile-pre-assets") }}` — plugin hooks inject here (including compile-sass)
2. Standard asset compilation (compile-sass --theme mereka)
3. `COPY ./themes/ /openedx/themes` — theme files copied AFTER compile-sass
4. `collectstatic` — collects from staticfiles finders

**Problem**: `compile-sass --theme mereka` runs BEFORE the theme COPY. The mereka directory
doesn't exist when SASS compiles. Result: zero brand tokens in compiled CSS.

**Fix applied**: Added early `COPY ./themes/mereka/ /openedx/themes/mereka/` at the START of
the plugin's `openedx-dockerfile-pre-assets` hook. The later standard COPY overwrites with
the same files (safe/idempotent).

**Second fix**: `printf '/openedx\n/openedx/plugins\n'` in plugin rendered literal newlines
in the Dockerfile (Python `\n` in triple-quoted string = actual newline). Changed to `echo`
with `&&` chaining.

### Build steps
```bash
export TUTOR_ROOT="$(pwd)/tutor_env"
TUTOR=.venv/bin/tutor

# Sync plugin to Tutor plugin dir
cp infrastructure/tutor/plugins/mereka_lms.py ~/.local/share/tutor-plugins/mereka_lms.py

# Regenerate templates
$TUTOR config save  # MFE template error is pre-existing, doesn't block openedx build

# Build OpenEdX image (30-45 min)
$TUTOR images build openedx -a PIP_COMMAND=pip

# Push
docker push asia-southeast1-docker.pkg.dev/mereka-lms/openedx/openedx:mereka-brand
```

### Post-build verification
- `lms-main-v1.css` must contain "Poppins", "Lato", "#2d898b"
- `/openedx/staticfiles/mereka/` must exist with fonts/images
- `studio-main-v1.css` must contain mereka brand tokens

---

## Part D: Runtime Fixes (after image deployed)

### Fix Django Site object
```bash
kubectl -n mereka-lms exec deploy/lms -- python manage.py lms shell -c "
from django.contrib.sites.models import Site
site = Site.objects.get(id=2)
site.domain = 'academyv2.mereka.dev'
site.name = 'Mereka Academy'
site.save()
print(f'Updated: {site.domain} / {site.name}')
"
```

### Fix MFE Caddyfile redirect
The Caddyfile has `redir / https://academyv2.mereka.io` for the MFE block that includes
`apps.academyv2.mereka.dev` — this redirects dev MFE root to production.
Needs: use `{http.request.host}` or conditional redirect per domain.

---

## Verification Checklist

### Kustomize (Phase 1)
- [ ] `kubectl kustomize deploy/k8s/overlays/rke2-nonprod` succeeds
- [ ] enterprise-catalog-worker rendered with `strategy: Recreate`
- [ ] enterprise-catalog-worker probes show `timeoutSeconds: 30`, `periodSeconds: 30`
- [ ] payments-gateway-secrets rendered with `secretStoreRef.name: infisical-secret-store`
- [ ] payments-gateway-secrets uses `_DEV` Stripe keys

### Image (Phase 2)
- [ ] `lms-main-v1.css` contains Poppins, Lato, #2d898b, #295cad
- [ ] `studio-main-v1.css` contains mereka brand tokens
- [ ] `/openedx/staticfiles/mereka/` exists with fonts + images
- [ ] Mereka logo in staticfiles matches theme logo (50KB, not 570B stock)

### Runtime (Phase 3)
- [ ] Django Site domain = `academyv2.mereka.dev`
- [ ] LMS homepage shows Mereka logo
- [ ] LMS homepage loads Poppins/Lato fonts (no 404)
- [ ] LMS footer is Mereka branded
- [ ] Studio shows Mereka branding
- [ ] MFE login page loads with Mereka footer component

### Infra handoff (post-ArgoCD sync)
- [ ] `kubectl -n mereka-lms get deploy enterprise-catalog-worker -o jsonpath='{.spec.strategy.type}'` → `Recreate`
- [ ] Probes: timeoutSeconds=30, periodSeconds=30
- [ ] `kubectl -n mereka-lms get externalsecret payments-gateway-secrets -o jsonpath='{.spec.secretStoreRef.name}'` → `infisical-secret-store`
