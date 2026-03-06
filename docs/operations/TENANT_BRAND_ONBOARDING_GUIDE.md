# Tenant Brand Onboarding Guide

> Step-by-step guide for adding a new tenant brand to the Mereka Academy platform.
>
> **Bead**: mereka-lms-115d.27
> **AC**: AC-TF-004
> **Last updated**: 2026-02-18

## Overview

Adding a new tenant brand requires changes across 4 layers: assets, tokens, config, and verification. This guide covers all steps needed to go from "we have a new domain" to "tenant is live with correct branding."

## Prerequisites

- Domain DNS pointing to the GKE cluster (via Cloudflare or direct)
- Open edX `Site` and `SiteConfiguration` created for the domain
- Access to `infrastructure/tutor/plugins/mereka_lms.py` (plugin config)
- Access to `infrastructure/tutor/apply-patches.sh` (dual-path fallback)

---

## Step 1: Prepare Brand Assets

Create the following assets for the new tenant:

```
infrastructure/tutor/themes/mereka/lms/static/images/
  <tenant>-logo.png           # Horizontal logo (300x80px recommended)
  <tenant>-logo-square.png    # Square logo (80x80px, for favicon/mobile)
  <tenant>-logo-white.png     # White version for dark backgrounds
```

Copy assets to theme structure:

```bash
# Sync brand assets
./scripts/branding/sync-brand-assets.sh
```

### Asset Requirements

| Asset | Format | Size | Purpose |
|-------|--------|------|---------|
| Logo (horizontal) | PNG/SVG | 300x80px | Header, MFE navbar |
| Logo (square) | PNG/SVG | 80x80px | Favicon, mobile |
| Logo (white) | PNG/SVG | 300x80px | Footer dark background |
| Favicon | ICO/PNG | 32x32px | Browser tab |

---

## Step 2: Configure Design Tokens (Optional)

If the tenant uses different brand colors, add to the token file:

```scss
// infrastructure/tutor/themes/mereka/scss/_tokens.scss

// <Tenant Name> brand tokens
$tenant-<name>-primary: #XXXXXX;
$tenant-<name>-secondary: #XXXXXX;
```

And add CSS custom properties:

```css
/* infrastructure/tutor/themes/mereka/common/static/css/mereka-design-tokens.css */

/* <Tenant Name> */
--mereka-tenant-<name>-primary: #XXXXXX;
--mereka-tenant-<name>-secondary: #XXXXXX;
```

---

## Step 3: Add Domain to SITE_VARIANTS (Plugin)

Edit `infrastructure/tutor/plugins/mereka_lms.py` — locate the `SITE_VARIANTS` map in the `MerekaFooter` component:

```javascript
const SITE_VARIANTS = {
  'academyv2.mereka.io':               { brand: 'Mereka Academy',           copyrightHolder: 'MEREKA',               whatsapp: '601135271981' },
  'academy.biji-biji.com':             { brand: 'Biji-Biji Academy',        copyrightHolder: 'Biji-Biji Initiative', whatsapp: '601135271981' },
  'skillourfuture.academy.mereka.io':  { brand: 'Skill Our Future Academy', copyrightHolder: 'MEREKA',               whatsapp: '601135271981' },
  // ADD NEW TENANT:
  '<new-domain>':                      { brand: '<Brand Name>',             copyrightHolder: '<Copyright Holder>',    whatsapp: '<WhatsApp Number>' },
};
```

### Required Fields

| Field | Description | Example |
|-------|-------------|---------|
| `brand` | Display name in footer | `'New Academy'` |
| `copyrightHolder` | Legal entity for copyright line | `'NewCo Ltd'` |
| `whatsapp` | WhatsApp number (digits only, with country code) | `'601135271981'` |

---

## Step 4: Add Domain to apply-patches.sh (Dual-Path)

The same `SITE_VARIANTS` entry must be added to `infrastructure/tutor/apply-patches.sh` for dual-path safety:

1. Search for `SITE_VARIANTS` in `apply-patches.sh`
2. Add the same domain entry as in Step 3
3. Run `./infrastructure/tutor/apply-patches.sh` to apply

---

## Step 5: Configure SiteConfiguration

In Django Admin (`https://academyv2.mereka.io/admin/site_configuration/siteconfiguration/`):

1. Create or edit the SiteConfiguration for the new domain
2. Set required fields:

```json
{
  "SITE_NAME": "<Brand Name>",
  "PLATFORM_NAME": "<Brand Name>",
  "LMS_BASE_URL": "https://<new-domain>",
  "LOGO_URL": "/theming/asset/mereka/images/<tenant>-logo.png",
  "FAVICON_URL": "/theming/asset/mereka/images/<tenant>-favicon.ico"
}
```

---

## Step 6: Add Domain to Caddy/CSRF/Hosts Config

In `mereka_lms.py`, ensure the domain is in:
- `ALLOWED_HOSTS`
- `CSRF_TRUSTED_ORIGINS`
- Caddy multi-domain block

These are typically in the `openedx-lms-production-settings` and `caddy-caddyfile` hooks.

---

## Step 7: Add to Tenant Registry (K8s)

Update the tenant registry ConfigMap:

```yaml
# deploy/k8s/base/apps/lms/tenant-registry-configmap.yaml
data:
  tenants.json: |
    [
      {"domain": "academyv2.mereka.io", "brand": "mereka"},
      {"domain": "academy.biji-biji.com", "brand": "bijibiji"},
      {"domain": "skillourfuture.academy.mereka.io", "brand": "skillourfuture"},
      {"domain": "<new-domain>", "brand": "<brand-key>"}
    ]
```

---

## Step 8: Rebuild and Deploy

```bash
# Rebuild OpenedX image (includes theme changes)
tutor images build openedx -a PIP_COMMAND=pip

# Tag and push
docker tag ... ghcr.io/biji-biji-initiative/mereka-lms/openedx:<tag>
docker push ...

# Update kustomization.yaml with new tag
# Merge to main → ArgoCD auto-syncs
```

---

## Step 9: Verify

Run the full verification suite for the new tenant:

```bash
# 1. Tenant branding runtime (all domains)
./scripts/qa/verify-tenant-branding-runtime.sh

# 2. Footer variant matrix (deterministic variant selection)
./scripts/qa/verify-footer-variant-matrix.sh

# 3. Tenant visual contract (HTTP + content assertions)
./scripts/qa/verify-tenant-visual-contract.sh --env prod

# 4. Post-deploy smoke (full matrix)
./scripts/qa/verify-post-deploy-smoke.sh --env prod

# 5. MFE footer fallbacks (exception compliance)
./scripts/qa/verify-mfe-footer-fallbacks.sh

# 6. Full plugin-surface matrix
./scripts/qa/verify-plugin-surface-matrix.sh
```

### Expected Results

| Gate | Expected | Acceptable |
|------|----------|------------|
| Tenant branding runtime | 0 FAIL | WARN on color tokens (Phase 2) |
| Footer variant matrix | 0 FAIL | — |
| Tenant visual contract | 0 FAIL | WARN on auth-gated assets |
| Post-deploy smoke | 0 FAIL | WARN on kubectl checks (if no cluster access) |
| Footer fallbacks | 0 FAIL | WARN on enterprise MFE exceptions |
| Plugin-surface matrix | 0 FAIL (new gates) | 1 pre-existing FAIL on slot wiring |

---

## Troubleshooting

### New domain shows default Open edX branding

1. Check `SiteConfiguration` exists for the domain
2. Check `SITE_NAME` and `LOGO_URL` are set
3. Verify `/api/mfe_config/v1` returns correct values
4. Check MFE `env.config.jsx` has the domain in `SITE_VARIANTS`

### Footer shows wrong brand name

1. Check `SITE_VARIANTS` in `mereka_lms.py` has correct `brand` value
2. Check `apply-patches.sh` has the same entry (dual-path sync)
3. Run `./scripts/qa/verify-footer-variant-matrix.sh`

### MFE routes return 403/405

1. Check `CSRF_TRUSTED_ORIGINS` includes the new domain
2. Check `ALLOWED_HOSTS` includes the new domain
3. Check `SESSION_COOKIE_SAMESITE = "None"` in LMS settings
4. See `docs/operations/FRONTEND_REGRESSION_CHECKLIST.md` for full triage

### Domain not reachable

1. Check DNS: `dig +short <new-domain>`
2. Check Caddy config: domain must be in multi-domain Caddy block
3. Check TLS: Cloudflare Free SSL covers `*.mereka.io` only — use Let's Encrypt for deeper subdomains

---

## Checklist Summary

- [ ] Brand assets created and synced
- [ ] Design tokens added (if custom colors)
- [ ] `SITE_VARIANTS` entry in `mereka_lms.py`
- [ ] `SITE_VARIANTS` entry in `apply-patches.sh` (dual-path)
- [ ] `SiteConfiguration` created with SITE_NAME, LOGO_URL
- [ ] Domain in `ALLOWED_HOSTS` + `CSRF_TRUSTED_ORIGINS`
- [ ] Domain in Caddy multi-domain block
- [ ] Tenant registry ConfigMap updated
- [ ] Image rebuilt and deployed
- [ ] All 6 verification gates pass

---

## Related Documents

- `docs/operations/TENANT_ONBOARDING_PLAYBOOK.md` — Full tenant provisioning flow
- `docs/operations/MFE_PLUGIN_SLOT_MIGRATION_REGISTER.md` — Plugin slot inventory
- `docs/operations/footer-slot-exceptions.md` — Footer exception register
- `docs/guides/branding/PLUGIN_MIGRATION_SURVEY.md` — Override inventory
- `docs/guides/branding/BRANDING_OPERATING_MODEL.md` — Exception policy
