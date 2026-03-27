# Tenant Brand Onboarding Guide
_Audience: Operators and developers • Owner: Platform Team • Last verified: 2026-03-27 • Status: active_

> Step-by-step guide for adding a new tenant brand to the Mereka Academy platform.
>
> **Bead**: mereka-lms-115d.27
> **AC**: AC-TF-004
> **Last updated**: 2026-03-27

## Overview

Adding a new tenant brand spans repo-owned brand inputs, runtime
multisite reconciliation, and post-deploy verification. This guide
covers the canonical path from "we have a new domain" to "tenant is
live with correct branding" without falling back to manual
`SiteConfiguration` edits or ad-hoc image pushes.

The current source of truth for MFE footer branding is:

- `infrastructure/tutor/plugins/_mereka_lms/mfe_runtime_definitions.js`
- specifically `MEREKA_SITE_VARIANTS` and `getMerekaVariant()`

There is no longer a dual-path `apply-patches.sh` footer fallback to keep in sync.

## Prerequisites

- Domain DNS planned and routed through the platform domain/GitOps
  contract
- Access to `infrastructure/tutor/multisite-sites*.yml`
- Access to `infrastructure/tutor/plugins/_mereka_lms/mfe_runtime_definitions.js`
- Access to `scripts/tenants/provision-tenant.sh` and
  `scripts/infra/apply-multisite-config.sh`

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

## Step 4: Bootstrap tenant records and reconcile multisite config

Preview the tenant bootstrap first:

```bash
./scripts/tenants/provision-tenant.sh \
  --slug <tenant-slug> \
  --name "<Brand Name>" \
  --domain <new-domain> \
  --contact-email <ops@tenant.example> \
  --country MY \
  --dry-run
```

Preview the authoritative multisite reconciliation:

```bash
./scripts/infra/apply-multisite-config.sh --env prod --dry-run
```

Apply the bootstrap when the preview is clean:

```bash
CONFIRM_PROVISION_TENANT=PROVISION_TENANT \
./scripts/tenants/provision-tenant.sh \
  --slug <tenant-slug> \
  --name "<Brand Name>" \
  --domain <new-domain> \
  --contact-email <ops@tenant.example> \
  --country MY
```

Then reconcile the canonical `Site` + `SiteConfiguration` state from the
multisite registry:

```bash
CONFIRM_APPLY_MULTISITE_CONFIG=APPLY_MULTISITE_CONFIG \
ALLOW_PROD_APPLY=1 \
./scripts/infra/apply-multisite-config.sh --env prod --apply
```

If the tenant needs enterprise SSO, keep that as a separate concern:

```bash
./scripts/tenants/sync-tenant-enterprise-mapping.sh --env prod --dry-run
CONFIRM_SYNC_TENANT_ENTERPRISE_MAPPING=SYNC_TENANT_ENTERPRISE_MAPPING \
ALLOW_PROD_APPLY=1 \
./scripts/tenants/sync-tenant-enterprise-mapping.sh --env prod --apply

./scripts/tenants/configure-tenant-idp.sh \
  --tenant-slug <tenant-slug> \
  --idp-type saml \
  --metadata-url https://idp.example.com/metadata \
  --dry-run
```

Do **not** create or repair tenant `SiteConfiguration` rows by hand in
Django admin. The canonical repair path is always
`apply-multisite-config.sh`.

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

## Step 6: Ship through the governed build + release path

For repo-owned brand changes, use the normal image/release flow:

```bash
# Merge the brand/runtime source changes
# Run the governed build workflow for the required image(s)
gh workflow run build-tutor-images.yml \
  -f build_openedx=true \
  -f build_mfe=true

# Promote via the release/GitOps checklist once artifacts are ready
# ArgoCD then applies the new image tag and manifests
```

Do **not** run local `tutor images build`, hand-push Docker tags, or use
`kubectl set image` as the normal production path.

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

1. re-run `./scripts/infra/apply-multisite-config.sh --env prod --dry-run`
2. check `infrastructure/tutor/multisite-sites*.yml` has the expected
   `site_values`
3. verify `/api/mfe_config/v1` returns the expected tenant values
4. check `MEREKA_SITE_VARIANTS` has the domain entry when the footer/runtime
   shell needs a tenant-specific variant

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
- [`docs/guides/branding/MULTI_TENANT_BRANDING_OPS.md`](../../guides/branding/MULTI_TENANT_BRANDING_OPS.md)
- [`docs/reference/operations/FOOTER_VARIANT_MATRIX.md`](../../reference/operations/FOOTER_VARIANT_MATRIX.md)
- [`docs/reference/operations/TENANT_BRANDING_MATRIX.md`](../../reference/operations/TENANT_BRANDING_MATRIX.md)
- [`scripts/qa/verify-footer-variant-matrix.sh`](../../../scripts/qa/verify-footer-variant-matrix.sh)
- [`scripts/qa/verify-tenant-branding-matrix.sh`](../../../scripts/qa/verify-tenant-branding-matrix.sh)
