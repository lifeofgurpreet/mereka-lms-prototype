# Tenant Brand Onboarding Guide
_Audience: Operators and developers • Owner: Platform Team • Last verified: 2026-03-27 • Status: active_

> Step-by-step guide for adding a new tenant brand to the Mereka Academy platform.
>
> **Bead**: mereka-lms-115d.27
> **AC**: AC-TF-004
> **Last updated**: 2026-03-27

## Overview

Adding a new tenant brand requires changes across four layers:

1. theme assets
2. tenant footer/runtime data
3. platform host / tenant config
4. verification and deployment

The current source of truth for MFE footer branding is:

- `infrastructure/tutor/plugins/_mereka_lms/mfe_runtime_definitions.js`
- specifically `MEREKA_SITE_VARIANTS` and `getMerekaVariant()`

There is no longer a dual-path `apply-patches.sh` footer fallback to keep in sync.

## Prerequisites

- Domain DNS pointing at the currently active platform ingress
- Open edX `Site` and `SiteConfiguration` created or planned for the domain
- Access to `infrastructure/tutor/plugins/_mereka_lms/mfe_runtime_definitions.js`
- Access to the normal Tutor config workflow (`./scripts/infra/tutor-config-save.sh`) if host config changes are required

---

## Step 1: Prepare Brand Assets

Create the following assets for the new tenant:

```text
infrastructure/tutor/themes/mereka/lms/static/images/
  <tenant>-logo.png
  <tenant>-logo-square.png
  <tenant>-logo-white.png
```

Sync brand assets:

```bash
./scripts/branding/sync-brand-assets.sh
```

## Step 2: Configure Design Tokens (Optional)

If the tenant needs different brand colours, add them to the token surfaces used by LMS/CMS and MFEs:

- `infrastructure/tutor/themes/mereka/scss/_tokens.scss`
- `infrastructure/tutor/themes/mereka/common/static/css/mereka-design-tokens.css`

---

## Step 3: Add Domain to `MEREKA_SITE_VARIANTS`

Edit `infrastructure/tutor/plugins/_mereka_lms/mfe_runtime_definitions.js` and add a new entry:

```javascript
const MEREKA_SITE_VARIANTS = {
  'academyv2.mereka.io': {
    ...MEREKA_BASE_VARIANT,
    brand: 'Mereka Academy',
    copyrightHolder: 'MEREKA',
    supportEmail: 'support@mereka.io',
  },
  'newdomain.example.com': {
    ...MEREKA_BASE_VARIANT,
    brand: 'Brand Name',
    copyrightHolder: 'Entity Name',
    supportEmail: 'support@example.com',
  },
};
```

### Required Fields

| Field | Description | Example |
|-------|-------------|---------|
| `brand` | Display name in footer | `'New Academy'` |
| `copyrightHolder` | Legal entity for copyright line | `'NewCo Ltd'` |
| `supportEmail` | Support mailbox exposed in the footer | `'support@example.com'` |
| `logoUrl` / `mobileLogoUrl` | Optional per-tenant asset override | `'/theme/newtenant/logo-horizontal.svg'` |

`whatsapp`, `helpUrl`, `termsUrl`, `privacyUrl`, and `cookiesUrl` are inherited from `MEREKA_BASE_VARIANT` unless you override them.

---

## Step 4: Configure Site / SiteConfiguration

In Django Admin, create or update the `SiteConfiguration` for the domain so the fallback branch has correct platform values:

```json
{
  "SITE_NAME": "Brand Name",
  "PLATFORM_NAME": "Entity Name",
  "LMS_BASE_URL": "https://newdomain.example.com"
}
```

---

## Step 5: Configure Hosts / CSRF / Tenant Resolution

If the new domain requires platform host changes, use the standard Tutor config workflow:

```bash
export TUTOR_ROOT="$(pwd)/tutor_env"
./scripts/infra/tutor-config-save.sh --set ...
```

If the domain requires explicit tenant resolution, provision a `TenantConfig` record:

```bash
./scripts/tenants/provision-tenant.sh newdomain.example.com "Brand Name"
```

---

## Step 6: Rebuild and Deploy

Because `MEREKA_SITE_VARIANTS` is embedded in the MFE bundle, a new MFE image is required:

```bash
tutor images build mfe
tutor local restart mfe
```

For shared environments:

1. build/publish through `.github/workflows/build-tutor-images.yml`
2. promote the resulting image through the reviewed GitOps path

---

## Step 7: Verify

Run the tenant/footer verification suite:

```bash
./scripts/qa/verify-footer-variant-matrix.sh
./scripts/qa/verify-tenant-branding-matrix.sh
./scripts/qa/verify-tenant-footer-variant-lane.sh
./scripts/qa/verify-mfe-footer-slot.sh
```

## Troubleshooting

### New domain shows default Open edX branding

1. check the new domain exists in `MEREKA_SITE_VARIANTS`
2. check `SiteConfiguration` / tenant config for correct `SITE_NAME` / `PLATFORM_NAME`
3. check the published MFE image actually contains the new bundle change
4. check the request hostname resolves to the intended tenant domain

### Footer shows wrong brand name

1. inspect `getMerekaVariant()` in `_mereka_lms/mfe_runtime_definitions.js`
2. verify the hostname is either a canonical LMS domain or one of the derived `apps./staging./.mereka.dev` forms
3. if the hostname is unknown, verify the fallback `SITE_NAME` / `PLATFORM_NAME` values are correct

### Footer changes do not appear after code change

1. confirm a new MFE image was built after editing `MEREKA_SITE_VARIANTS`
2. confirm the image was actually promoted to the target environment
3. rerun `verify-footer-variant-matrix.sh` against the branch and then check the deployed runtime

---

## References

- [`infrastructure/tutor/plugins/_mereka_lms/mfe_runtime_definitions.js`](../../../infrastructure/tutor/plugins/_mereka_lms/mfe_runtime_definitions.js)
- [`docs/reference/operations/FOOTER_VARIANT_MATRIX.md`](../../reference/operations/FOOTER_VARIANT_MATRIX.md)
- [`docs/reference/operations/TENANT_BRANDING_MATRIX.md`](../../reference/operations/TENANT_BRANDING_MATRIX.md)
- [`scripts/qa/verify-footer-variant-matrix.sh`](../../../scripts/qa/verify-footer-variant-matrix.sh)
- [`scripts/qa/verify-tenant-branding-matrix.sh`](../../../scripts/qa/verify-tenant-branding-matrix.sh)
