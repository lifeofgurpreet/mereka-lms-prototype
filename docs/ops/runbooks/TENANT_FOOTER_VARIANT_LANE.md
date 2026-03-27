# Tenant Footer Variant Lane
_Audience: Operators and developers • Owner: Platform Team • Last verified: 2026-03-27 • Status: active_

> Operational guide for the tenant-first footer variant selection lane.
>
> **Bead**: mereka-lms-115d.27
> **Last updated**: 2026-03-27
> **Canonical code**: `infrastructure/tutor/plugins/_mereka_lms/mfe_runtime_definitions.js` — `MEREKA_SITE_VARIANTS` + `getMerekaVariant()`
> **Spec coverage**: AC-TF-001, AC-TF-002, AC-TF-003, AC-TF-004

---

## Overview

The **footer variant lane** is the mechanism by which `MerekaFooter` selects the correct
brand name, copyright holder, support links, and theme assets based on the request hostname.

The selection is deterministic:

1. exact canonical LMS hostname match
2. derived candidate lookup for `apps.*`, `staging.*`, and `.mereka.dev`
3. explicit fallback built from `config.SITE_NAME` / `config.PLATFORM_NAME`

No runtime API call is required for the variant map itself.

---

## Section 1: Active Domain-Variant Mapping

| Domain | Brand Name | Copyright Holder | WhatsApp | Footer Variant Enum | Status |
|--------|-----------|-----------------|----------|---------------------|--------|
| `academyv2.mereka.io` | Mereka Academy | MEREKA | `601135271981` | `mereka-v2` | Active |
| `academy.biji-biji.com` | Biji-Biji Academy | Biji-Biji Initiative | `601135271981` | `bijibiji` | Active |
| `skillourfuture.academy.mereka.io` | Skill Our Future Academy | MEREKA | `601135271981` | `skillourfuture` | Active |
| *(default / unknown host)* | *(reads fallback config)* | *(reads fallback config)* | `601135271981` | fallback | Active |

---

## Section 2: Variant Selection Architecture

### How Domain → Variant Selection Works

```text
Browser loads MFE (for example apps.academyv2.mereka.io)
  └── MerekaFooter mounts
  └── getConfig() loads MFE config
  └── getMerekaVariant(window.location.hostname, config)
      ├── exact canonical LMS match?
      ├── derived candidate match?
      └── fallback object from config.SITE_NAME / config.PLATFORM_NAME
  └── MerekaFooter renders with tenant-specific values
```

### Runtime Helper Shape

```js
const exactVariant = MEREKA_SITE_VARIANTS[normalizedHostname];
if (exactVariant) return exactVariant;

for (const candidate of deriveVariantCandidates(normalizedHostname)) {
  const variant = MEREKA_SITE_VARIANTS[candidate];
  if (variant) return variant;
}

return {
  ...MEREKA_BASE_VARIANT,
  brand: fallbackBrand === 'My Open edX' ? 'Mereka Academy' : fallbackBrand,
  copyrightHolder: fallbackPlatform === 'My Open edX' ? 'MEREKA' : fallbackPlatform,
  supportEmail: 'support@mereka.io',
};
```

**Why this is deterministic**:
- `MEREKA_SITE_VARIANTS` is a static object literal in the bundle
- candidate derivation is pure string transformation
- fallback is an explicit object, not an implicit null path

---

## Section 3: Config Traceability

| Layer | File | What It Controls |
|-------|------|-----------------|
| Source of truth | `infrastructure/tutor/plugins/_mereka_lms/mfe_runtime_definitions.js` | `MEREKA_SITE_VARIANTS`, `getMerekaVariant`, `MerekaFooter` |
| Slot wiring | `infrastructure/tutor/plugins/mereka_lms_mfe_slots.py` | Hide default footer + insert `MerekaFooter` |
| Documentation | `docs/reference/operations/FOOTER_VARIANT_MATRIX.md` | Per-domain matrix table |
| Runtime config | `/api/mfe_config/v1` | Provides fallback `SITE_NAME`, `PLATFORM_NAME`, `LMS_BASE_URL` |

### How to Inspect the Active Variant at Runtime

**Offline**:
```bash
grep -n "const MEREKA_SITE_VARIANTS\\|const getMerekaVariant" \
  infrastructure/tutor/plugins/_mereka_lms/mfe_runtime_definitions.js
```

**Live fallback inputs**:
```bash
curl -s "https://academyv2.mereka.io/api/mfe_config/v1" | python3 -m json.tool | grep -E "SITE_NAME|PLATFORM_NAME|LMS_BASE_URL"
```

**Browser**:
1. open the site for the target domain
2. inspect the footer
3. verify the legal row and brand name match the expected tenant

---

## Section 4: Regression Check Matrix

### Offline Checks

| Check | Script | What It Verifies |
|-------|--------|-----------------|
| Variant map completeness | `verify-footer-variant-matrix.sh` | All production domains present, required fields non-null |
| Lane documentation | `verify-tenant-footer-variant-lane.sh` | This doc covers the required operational sections |
| Tenant registry sync | `verify-tenant-branding-matrix.sh` | Tenant matrix and footer matrix align |
| Slot wiring | `verify-mfe-footer-slot.sh` | Footer slot hides default and inserts `MerekaFooter` |

### Brand Visibility Markers

After any footer variant change, confirm these markers are visible or derivable for each domain:

| Domain | Expected brand | Expected copyrightHolder | Expected whatsapp |
|--------|----------------|--------------------------|-------------------|
| `academyv2.mereka.io` | Mereka Academy | MEREKA | `601135271981` |
| `academy.biji-biji.com` | Biji-Biji Academy | Biji-Biji Initiative | `601135271981` |
| `skillourfuture.academy.mereka.io` | Skill Our Future Academy | MEREKA | `601135271981` |

### Running the Regression Suite

```bash
./scripts/qa/verify-tenant-footer-variant-lane.sh
./scripts/qa/verify-footer-variant-matrix.sh
./scripts/qa/verify-tenant-branding-matrix.sh
./scripts/qa/verify-mfe-footer-slot.sh
```

---

## Section 5: Adding a New Tenant Brand

### Step 0: Assets and Design Tokens

Prepare the tenant assets before changing the runtime map:

- primary logo
- mobile logo / square logo
- favicon
- any tenant-specific color token or palette adjustments

If the tenant requires brand token divergence, update the global token surfaces or introduce a tenant-scoped token override deliberately rather than mixing footer data and theme data in one change.

### Step 1: Update `MEREKA_SITE_VARIANTS`

Edit `infrastructure/tutor/plugins/_mereka_lms/mfe_runtime_definitions.js`:

```js
'newdomain.example.com': {
  ...MEREKA_BASE_VARIANT,
  brand: 'New Brand Name',
  copyrightHolder: 'Legal Entity Name',
  supportEmail: 'support@example.com',
},
```

### Step 2: Verify the Helper Still Resolves Correctly

```bash
./scripts/qa/verify-footer-variant-matrix.sh
```

### Step 3: Update Tenant / Host Config if Required

If the domain requires host or tenant changes:

```bash
./scripts/infra/tutor-config-save.sh --set ...
./scripts/tenants/provision-tenant.sh newdomain.example.com "New Brand Name"
```

### Step 4: Rebuild and Publish the MFE

`MEREKA_SITE_VARIANTS` is embedded in the MFE bundle, so a new image is required.

### Step 5: Smoke Test

Verify the footer shows the right brand and legal row on the target domain.

---

## Section 6: Failure Modes

### Unknown Host

If `window.location.hostname` does not match a configured tenant:

1. `getMerekaVariant()` falls back to config-driven branding
2. stock `My Open edX` values are coerced back to Mereka defaults
3. the site stays rendered, but tenant-specific branding is incomplete

### Wrong Brand on an MFE Host

Check whether the hostname is one of:
- `apps.<domain>`
- `staging.<domain>`
- `apps.staging.<domain>`
- `<domain>.mereka.dev`

The helper should derive back to the canonical LMS domain. If not, update `deriveVariantCandidates()`.

---

## References

- [`infrastructure/tutor/plugins/_mereka_lms/mfe_runtime_definitions.js`](../../../infrastructure/tutor/plugins/_mereka_lms/mfe_runtime_definitions.js)
- [`infrastructure/tutor/plugins/mereka_lms_mfe_slots.py`](../../../infrastructure/tutor/plugins/mereka_lms_mfe_slots.py)
- [`docs/reference/operations/FOOTER_VARIANT_MATRIX.md`](../../reference/operations/FOOTER_VARIANT_MATRIX.md)
- [`docs/reference/operations/TENANT_BRANDING_MATRIX.md`](../../reference/operations/TENANT_BRANDING_MATRIX.md)
- [`scripts/qa/verify-footer-variant-matrix.sh`](../../../scripts/qa/verify-footer-variant-matrix.sh)
- [`scripts/qa/verify-tenant-footer-variant-lane.sh`](../../../scripts/qa/verify-tenant-footer-variant-lane.sh)
