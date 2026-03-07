# Tenant Footer Variant Lane

> Operational guide for the tenant-first UI/UX footer variant selection lane.
>
> **Bead**: mereka-lms-115d.27
> **Last updated**: 2026-02-18
> **Canonical code**: `infrastructure/tutor/plugins/mereka_lms.py` — `SITE_VARIANTS` map
> **Spec coverage**: AC-TF-001, AC-TF-002, AC-TF-003, AC-TF-004

---

## Overview

The **footer variant lane** is the mechanism by which the `MerekaFooter` React component
selects the correct brand name, copyright holder, and WhatsApp number based on the
visitor's domain (`window.location.hostname`).

The selection is **fully deterministic**: each production domain maps to a fixed variant
object defined at build time in `infrastructure/tutor/plugins/mereka_lms.py`. No runtime
database lookup or API call is needed for the variant selection itself.

---

## Section 1: Active Domain-Variant Mapping

| Domain | Brand Name | Copyright Holder | WhatsApp | Footer Variant Enum | Status |
|--------|-----------|-----------------|----------|---------------------|--------|
| `academyv2.mereka.io` | Mereka Academy | MEREKA | `601135271981` | `mereka-v2` | Active |
| `academy.biji-biji.com` | Biji-Biji Academy | Biji-Biji Initiative | `601135271981` | `bijibiji` | Active |
| `skillourfuture.academy.mereka.io` | Skill Our Future Academy | MEREKA | `601135271981` | `skillourfuture` | Active |
| *(default / unknown host)* | *(reads `config.SITE_NAME`)* | *(reads `config.PLATFORM_NAME` or `MEREKA`)* | `601135271981` | — | Fallback |

The fallback row applies when `window.location.hostname` does not match any key in `SITE_VARIANTS`.

---

## Section 2: Variant Selection Architecture

### How Domain → Variant Selection Works

```
Browser loads MFE (e.g., apps.academyv2.mereka.io)
  └── MerekaFooter component mounts
  └── Reads window.location.hostname → "academyv2.mereka.io"
  └── Looks up SITE_VARIANTS["academyv2.mereka.io"]
      → { brand: "Mereka Academy", copyrightHolder: "MEREKA", whatsapp: "601135271981" }
  └── Renders footer with tenant-specific values

Hostname not in SITE_VARIANTS (e.g., localhost, staging):
  └── Fallback: { brand: config.SITE_NAME, copyrightHolder: config.PLATFORM_NAME, ... }
  └── config comes from MFE build-time env.config.jsx
```

### Variant Selection Logic (SITE_VARIANTS)

The variant lookup is a single expression in `MerekaFooter`:

```js
// infrastructure/tutor/plugins/mereka_lms.py (inside MerekaFooter component)
const SITE_VARIANTS = {
  'academyv2.mereka.io':              { brand: 'Mereka Academy', copyrightHolder: 'MEREKA', whatsapp: '601135271981' },
  'academy.biji-biji.com':            { brand: 'Biji-Biji Academy', copyrightHolder: 'Biji-Biji Initiative', whatsapp: '601135271981' },
  'skillourfuture.academy.mereka.io': { brand: 'Skill Our Future Academy', copyrightHolder: 'MEREKA', whatsapp: '601135271981' },
};
const variant = SITE_VARIANTS[hostname] || {
  brand: (typeof config !== 'undefined' && config.SITE_NAME) || siteName || 'Mereka Academy',
  copyrightHolder: (typeof config !== 'undefined' && config.PLATFORM_NAME) || 'MEREKA',
  whatsapp: '601135271981',
};
```

**Why this approach is deterministic**: `SITE_VARIANTS` is a plain JS object literal —
there is no async operation, no cache, no external API. The variant is resolved synchronously
on component mount using the browser's own hostname.

---

## Section 3: Config Traceability

### Where Variant Selection Lives

| Layer | File | What It Controls |
|-------|------|-----------------|
| Source of truth | `infrastructure/tutor/plugins/mereka_lms.py` | `SITE_VARIANTS` map — domain → brand values |
| Schema | `infrastructure/tutor/plugins/multi-tenancy/brand-config-schema.json` | Defines `footer.variant` enum (`mereka-v2`, `bijibiji`, `skillourfuture`, `custom`) |
| Documentation | `docs/operations/FOOTER_VARIANT_MATRIX.md` | Per-domain matrix table |
| Runtime config | `/api/mfe_config/v1` endpoint | Exposes `SITE_NAME`, `PLATFORM_NAME` used by the fallback variant |

### How to Inspect the Active Variant at Runtime

**Offline (source check)**:
```bash
grep -A5 "const SITE_VARIANTS" infrastructure/tutor/plugins/mereka_lms.py
```

**Live MFE config endpoint** (shows what the fallback reads):
```bash
# Primary domain
curl -s "https://academyv2.mereka.io/api/mfe_config/v1" | python3 -m json.tool | grep -E "SITE_NAME|PLATFORM_NAME"

# BijiBiji domain
curl -s "https://academy.biji-biji.com/api/mfe_config/v1" | python3 -m json.tool | grep -E "SITE_NAME|PLATFORM_NAME"

# SkillOurFuture domain
curl -s "https://skillourfuture.academy.mereka.io/api/mfe_config/v1" | python3 -m json.tool | grep -E "SITE_NAME|PLATFORM_NAME"
```

**Browser DevTools** (verify active variant directly):
1. Open the site in the browser for the target domain.
2. Open DevTools → Console.
3. The `MerekaFooter` renders `variant.brand` in the footer element.
   Inspect `document.querySelector('.footer-copyright')` to see the active copyright holder.

### Multi-Tenancy Middleware Traceability

The `TenantResolutionMiddleware` in `infrastructure/tutor/plugins/multi-tenancy/` resolves
the domain to a `TenantConfig` record and injects `SITE_NAME` into the Django request.
This value then flows into the MFE via `/api/mfe_config/v1`. The footer's **fallback**
variant reads `config.SITE_NAME` from this endpoint — so even for unknown hostnames,
the platform name is traceable through the tenant config.

---

## Section 4: Regression Check Matrix

The following checks must pass after any change to tenant footer configuration:

### Offline Checks (always run in CI)

| Check | Script | What It Verifies |
|-------|--------|-----------------|
| SITE_VARIANTS completeness | `verify-footer-variant-matrix.sh` | All 3 domains present, required fields non-null |
| Variant selection logic | `verify-footer-variant-matrix.sh` | `||` fallback exists, DRY (no domain duplication) |
| Brand visibility markers | `verify-footer-variant-matrix.sh` | Per-domain `brand`, `copyrightHolder`, `whatsapp` values |
| Schema footer.variant field | `verify-tenant-footer-variant-lane.sh` | `brand-config-schema.json` defines variant enum |
| Lane documentation | `verify-tenant-footer-variant-lane.sh` | This doc covers all required sections |

### Live Checks (optional, run with `TENANT_FOOTER_LIVE=1`)

| Domain | HTTP Status | Path | Expected |
|--------|------------|------|---------|
| `academyv2.mereka.io` | 200 or 302 | `/` | LMS home loads |
| `academyv2.mereka.io` | 200 | `/health/` | Platform healthy |
| `academy.biji-biji.com` | 200 or 302 | `/` | LMS home loads |
| `academy.biji-biji.com` | 200 | `/health/` | Platform healthy |
| `skillourfuture.academy.mereka.io` | 200 or 302 | `/` | LMS home loads |
| `skillourfuture.academy.mereka.io` | 200 | `/health/` | Platform healthy |

### Brand Visibility Markers (per domain)

After any footer change, confirm the following markers are visible in the browser:

| Domain | Expected `brand` | Expected `copyrightHolder` | Footer Copyright Line |
|--------|-----------------|--------------------------|----------------------|
| `academyv2.mereka.io` | Mereka Academy | MEREKA | `© YYYY MEREKA` |
| `academy.biji-biji.com` | Biji-Biji Academy | Biji-Biji Initiative | `© YYYY Biji-Biji Initiative` |
| `skillourfuture.academy.mereka.io` | Skill Our Future Academy | MEREKA | `© YYYY MEREKA` |

### Running the Regression Suite

```bash
# Full offline regression (fast, no network needed)
./scripts/qa/verify-tenant-footer-variant-lane.sh
./scripts/qa/verify-footer-variant-matrix.sh
./scripts/qa/verify-tenant-branding-runtime.sh   # skips gracefully if cluster down

# With live HTTP probes (requires cluster access)
TENANT_FOOTER_LIVE=1 ./scripts/qa/verify-tenant-footer-variant-lane.sh
```

---

## Section 5: Adding a New Tenant Brand

Follow this checklist when onboarding a new branded domain.

### Step 1: Define Brand Assets

Gather or create the following assets for the new tenant:

- [ ] **Primary logo** (PNG or SVG, min 200 px wide, full colour)
- [ ] **White/reversed logo** (for dark backgrounds)
- [ ] **Favicon** (32×32 or 64×64 ICO/PNG)
- [ ] **Footer logo** (smaller variant, white or colour as needed)
- [ ] **Brand colour palette**:
  - `primary` — main button/link colour (6-digit hex, e.g. `#1a3c6e`)
  - `secondary` — hover/accent colour
  - `accent` — CTA highlight colour
  - `background` — default page background (usually `#ffffff`)
  - `text` — body text colour (must achieve WCAG AA contrast against `background`)
- [ ] **Typography**:
  - `font_family` — CSS font-family for body text
  - `heading_font` — font-family for headings (may be same as body)
  - `font_source_url` — Google Fonts or self-hosted URL

Validate colours pass WCAG AA contrast:
```bash
./scripts/qa/verify-contrast-compliance.sh
```

### Step 2: Update SITE_VARIANTS in the Plugin

Edit `infrastructure/tutor/plugins/mereka_lms.py` and add an entry to `SITE_VARIANTS`:

```js
// Inside MerekaFooter, add to SITE_VARIANTS object:
'newdomain.example.com': {
  brand: 'New Brand Name',
  copyrightHolder: 'Legal Entity Name',
  whatsapp: '601XXXXXXXXX',  // E.164 format without leading +
},
```

Run the verification to confirm:
```bash
./scripts/qa/verify-footer-variant-matrix.sh
```

### Step 3: Configure Design Tokens

If the new tenant needs per-domain colour overrides, update `assets/branding/tokens.css`
or create a tenant-scoped override. Validate tokens:

```bash
./scripts/branding/verify-token-drift.sh
./scripts/qa/verify-branding-token-integrity.sh
```

### Step 4: Update Tutor Multi-Site Config

Add the domain to Tutor's allowed-hosts and CSRF trusted origins:

```bash
# Using the safe wrapper (applies patches automatically):
export TUTOR_ROOT="$(pwd)/tutor_env"
./scripts/infra/tutor-config-save.sh \
  --set MEREKA_LMS_EXTRA_HOSTS='["academy.biji-biji.com", "skillourfuture.academy.mereka.io", "newdomain.example.com"]' \
  --set MEREKA_LMS_EXTRA_CSRF_ORIGINS='["https://academy.biji-biji.com", "https://skillourfuture.academy.mereka.io", "https://newdomain.example.com"]'
```

Always run `apply-patches.sh` after any `tutor config save`:
```bash
./infrastructure/tutor/apply-patches.sh
```

### Step 5: Provision Tenant Config

Create the `TenantConfig` record in the multi-tenancy plugin:

```bash
./scripts/tenants/provision-tenant.sh newdomain.example.com "New Brand Name"
```

### Step 6: Update brand-config-schema.json (if adding a new variant enum)

If the new tenant requires a new named footer variant (not just data differences),
add it to the `footer.variant` enum in `infrastructure/tutor/plugins/multi-tenancy/brand-config-schema.json`:

```json
"variant": {
  "type": "string",
  "enum": ["mereka-v2", "bijibiji", "skillourfuture", "custom", "newbrand"]
}
```

### Step 7: Update this Document

Add the new domain to the Active Domain-Variant Mapping table in Section 1 and
the Regression Check Matrix in Section 4.

Also update `docs/operations/FOOTER_VARIANT_MATRIX.md` — add a row to the Per-Domain Matrix.

### Step 8: SSL Certificate

For multi-level subdomains (e.g. `x.y.mereka.io`), Cloudflare Free SSL does not apply.
Use DNS-only (gray cloud) mode in Cloudflare + Let's Encrypt:

```
See: docs/operations/DOMAIN_MANAGEMENT.md
```

### Step 9: Rebuild and Redeploy MFE

The `SITE_VARIANTS` map is embedded in the MFE build. A rebuild is required:

```bash
tutor images build mfe
tutor local restart mfe
# Or for K8s:
# kubectl rollout restart deployment/mfe -n mereka-lms
```

### Step 10: Run Verification Suite

```bash
# Offline checks (always pass before committing):
./scripts/qa/verify-tenant-footer-variant-lane.sh
./scripts/qa/verify-footer-variant-matrix.sh
./scripts/qa/verify-branding-token-integrity.sh

# Live smoke test (after deployment):
TENANT_FOOTER_LIVE=1 ./scripts/qa/verify-tenant-footer-variant-lane.sh
```

### Step 11: Visual Smoke Test

Visit the new domain in a browser and confirm:
- Footer shows the correct `brand` name
- Footer copyright line shows the correct `copyrightHolder`
- Footer WhatsApp link uses the correct number
- Logo renders (check `/static/images/logo.png` is served)

---

## Section 6: Fallback Rules for Missing Tenant Config

When `window.location.hostname` does not match any key in `SITE_VARIANTS`:

1. **Fallback variant** is used: `SITE_VARIANTS[hostname] || { brand: config.SITE_NAME, ... }`
2. `brand` falls back to `config.SITE_NAME` from MFE env config, then to the hardcoded string
   `'Mereka Academy'`.
3. `copyrightHolder` falls back to `config.PLATFORM_NAME` from MFE env config, then to `'MEREKA'`.
4. `whatsapp` is always `'601135271981'` (no per-tenant override in fallback).

**When fallback applies**:
- `localhost` and `apps.localhost` (local development)
- Staging or preview environments with non-production hostnames
- Unknown/misconfigured domains
- K8s service-internal hostnames

**How to detect fallback in production** (should not happen for known domains):
```bash
# Check that the domain is in SITE_VARIANTS:
grep "'newdomain.example.com'" infrastructure/tutor/plugins/mereka_lms.py
```

If the domain is missing from `SITE_VARIANTS`, the fallback renders the platform default
brand — which is acceptable for staging but must not occur in production for a named tenant.

---

## Section 7: References

- [`infrastructure/tutor/plugins/mereka_lms.py`](../../infrastructure/tutor/plugins/mereka_lms.py) — `SITE_VARIANTS` map, `MerekaFooter` component
- [`infrastructure/tutor/plugins/multi-tenancy/brand-config-schema.json`](../../infrastructure/tutor/plugins/multi-tenancy/brand-config-schema.json) — footer.variant enum schema
- [`docs/operations/FOOTER_VARIANT_MATRIX.md`](FOOTER_VARIANT_MATRIX.md) — per-domain matrix table (existing)
- [`docs/operations/MULTITENANT_BRAND_PLATFORM.md`](MULTITENANT_BRAND_PLATFORM.md) — brand platform governance
- [`docs/operations/TENANT_BRANDING_SURFACE_MATRIX.md`](TENANT_BRANDING_SURFACE_MATRIX.md) — all branding surfaces
- [`scripts/qa/verify-tenant-footer-variant-lane.sh`](../../scripts/qa/verify-tenant-footer-variant-lane.sh) — this bead's verification script
- [`scripts/qa/verify-footer-variant-matrix.sh`](../../scripts/qa/verify-footer-variant-matrix.sh) — SITE_VARIANTS DRY + completeness check
- [`scripts/qa/verify-tenant-branding-runtime.sh`](../../scripts/qa/verify-tenant-branding-runtime.sh) — live domain routing check
- [`scripts/tenants/provision-tenant.sh`](../../scripts/tenants/provision-tenant.sh) — tenant provisioning
- [`infrastructure/tutor/apply-patches.sh`](../../infrastructure/tutor/apply-patches.sh) — must run after `tutor config save`
