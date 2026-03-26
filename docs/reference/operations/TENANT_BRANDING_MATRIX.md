# Tenant Branding Matrix

> **Bead**: mereka-lms-115d.9
> **Last updated**: 2026-03-26
> **Canonical code**: `infrastructure/tutor/plugins/mereka_lms.py` — `SITE_VARIANTS` map (~line 671)

---

## Tenant Domain Registry

| Domain | Brand Name | Copyright Holder | WhatsApp | Logo | Tokens Override | Footer Variant |
|--------|-----------|-----------------|----------|------|----------------|---------------|
| `academyv2.mereka.io` | Mereka Academy | MEREKA | `601135271981` | `/static/images/logo.png` (shared) | none (global) | mereka |
| `academy.biji-biji.com` | Biji-Biji Academy | Biji-Biji Initiative | `601135271981` | `/static/images/logo.png` (shared) | none (global) | biji-biji |
| `skillourfuture.academy.mereka.io` | Skill Our Future Academy | MEREKA | `601135271981` | `/static/images/logo.png` (shared) | none (global) | skillourfuture |
| *(default / unknown host)* | *(reads `config.SITE_NAME`)* | *(reads `config.PLATFORM_NAME` or `MEREKA`)* | `601135271981` | `/static/images/logo.png` (shared) | none (global) | *(fallback)* |

**Notes**:
- Logo path is currently shared across all domains (served from LMS base URL).
- WhatsApp number is currently identical for all domains — update per-domain if required.
- Per-domain CSS token override is a planned Phase 3 enhancement (see Override Inheritance Model below).
- The fallback row applies to any hostname not listed above (localhost, staging, unknown domains).

**Current runtime note**:
- Live staging still serves the older app image until promotion catches up, so tenant authn can still show default `mereka-brand*.css` on the staging surface even though the matrix itself is correct.

---

## Override Inheritance Model

All tenants inherit the global theme (`mereka.scss`, `tokens.css`, `mereka-overrides.css`).
Per-tenant customization is currently limited to:

1. **Footer content** (via `SITE_VARIANTS` in `mereka_lms.py`)
2. **Brand name / copyright** (via `SITE_VARIANTS`)
3. **Contact info** (WhatsApp number per domain)

### Fallback Chain

```
Tenant-specific SITE_VARIANT
  → Global SITE_VARIANT fallback (config.SITE_NAME / config.PLATFORM_NAME)
    → Default Mereka branding ('Mereka Academy' / 'MEREKA')
```

The fallback is implemented inline in `MerekaFooter` as:

```js
const variant = SITE_VARIANTS[hostname] || {
  brand: (typeof config !== 'undefined' && config.SITE_NAME) || siteName || 'Mereka Academy',
  copyrightHolder: (typeof config !== 'undefined' && config.PLATFORM_NAME) || 'MEREKA',
  whatsapp: '601135271981'
};
```

### Global Theme Source

Design tokens live in `assets/branding/tokens.css` and are injected into all tenants via:

- `infrastructure/tutor/themes/mereka/common/static/css/mereka-overrides.css` — LMS/CMS
- `infrastructure/tutor/themes/mereka/mfe/mereka.scss` — MFE frontend

No tenant currently overrides these tokens. Any per-domain token override must be implemented
as a separate CSS file loaded conditionally after the global tokens (Phase 3).

---

## Adding a New Tenant (Operator Checklist)

Follow this checklist when onboarding a new branded domain:

- [ ] **1. Add entry to `SITE_VARIANTS`** in `infrastructure/tutor/plugins/mereka_lms.py`:
  ```js
  'newdomain.example.com': { brand: 'Brand Name', copyrightHolder: 'Entity Name', whatsapp: '601XXXXXXXXX' },
  ```

- [ ] **2. Update this document** — add a row to the Tenant Domain Registry table above.

- [ ] **3. Update `FOOTER_VARIANT_MATRIX.md`** — add the domain to the per-domain footer matrix.

- [ ] **4. Add domain to `ALLOWED_HOSTS` and `CSRF_TRUSTED_ORIGINS`** via `apply-patches.sh`:
  ```bash
  # infrastructure/tutor/apply-patches.sh contains EXTRA_ALLOWED_HOSTS / CSRF_TRUSTED_ORIGINS
  # Ensure the new domain appears there, then:
  ./infrastructure/tutor/apply-patches.sh
  ```

- [ ] **5. Configure DNS + SSL**:
  - Single-level subdomain (e.g., `academy.mereka.io`): Cloudflare proxy (orange cloud) is fine.
  - Multi-level subdomain (e.g., `x.y.mereka.io`): Use DNS-only (gray cloud) + Let's Encrypt.
  - See `docs/ops/runbooks/DOMAIN_MANAGEMENT.md`.

- [ ] **6. Add Caddy host block if needed** (only for domains not routed via existing wildcard).

- [ ] **7. Provision TenantConfig record**:
  ```bash
  ./scripts/tenants/provision-tenant.sh newdomain.example.com "Brand Name"
  ```

- [ ] **8. Rebuild and redeploy MFE** (SITE_VARIANTS is embedded in MFE bundle):
  ```bash
  tutor images build mfe
  tutor local restart mfe
  ```

- [ ] **9. Run verification**:
  ```bash
  ./scripts/qa/verify-tenant-branding-matrix.sh
  ./scripts/qa/verify-footer-variant-matrix.sh
  ```

- [ ] **10. Smoke test** — visit the new domain and confirm footer shows correct brand name
  and copyright holder.

---

## Rollback Plan

If a domain mapping is misconfigured or a new tenant domain causes issues:

### Immediate Rollback (config-level)

1. **Automatic fallback**: If a domain key is missing or typo'd in `SITE_VARIANTS`, the fallback
   variant (Mereka Academy / MEREKA branding) is used automatically. No site outage occurs.

2. **Remove a tenant**: Delete the domain entry from `SITE_VARIANTS` in `mereka_lms.py`,
   rebuild and redeploy the MFE:
   ```bash
   tutor images build mfe && tutor local restart mfe
   ```
   No data loss — SITE_VARIANTS is config-only, no database rows are affected.

3. **Emergency force-fallback**: To force all tenants to use default Mereka branding
   regardless of hostname, clear the `SITE_VARIANTS` map to an empty object:
   ```js
   const SITE_VARIANTS = {};
   ```
   The fallback branch then applies universally. Rebuild MFE to deploy.

### Misconfigured Domain Mapping (DNS/middleware)

If `TenantResolutionMiddleware` maps a request to the wrong tenant:

1. Check `TenantConfig` records via Django admin (`/admin/multi_tenancy/tenantconfig/`).
2. Correct the `domain` field for the misconfigured record.
3. Flush Redis cache: `tutor local run lms ./manage.py lms shell -c "from django.core.cache import cache; cache.clear()"`
4. Verify with `./scripts/tenants/provision-tenant.sh --verify newdomain.example.com`.

### Existing Tenants — Migration Note

Tenants live on the platform **before** the formal branding matrix was established.
The `SITE_VARIANTS` map was already in place when this document was written; no data migration
is required. The three production domains (`academyv2.mereka.io`, `academy.biji-biji.com`,
`skillourfuture.academy.mereka.io`) are already fully configured.

If you are migrating a tenant from a legacy domain to a new domain:
1. Add the new domain to `SITE_VARIANTS` (keep the old entry until DNS cutover).
2. After DNS cutover and verification, remove the old domain entry.
3. Rebuild MFE.

---

## Verification

Run the verification script to confirm this matrix and `SITE_VARIANTS` are in sync:

```bash
./scripts/qa/verify-tenant-branding-matrix.sh
```

The script checks:

| AC | Check |
|----|-------|
| AC-TEN-001 | `TENANT_BRANDING_MATRIX.md` exists with >= 2 domain rows and all required columns |
| AC-TEN-002 | `SITE_VARIANTS` has >= 2 entries + fallback; `tokens.css` exists as global theme source |
| AC-TEN-003 | Each domain in `SITE_VARIANTS` has non-empty brand/copyrightHolder/whatsapp; cross-checked vs `FOOTER_VARIANT_MATRIX.md` |
| AC-TEN-004 | This document has "Rollback Plan" and "Adding a New Tenant" sections |

---

## References

- [`infrastructure/tutor/plugins/mereka_lms.py`](../../../infrastructure/tutor/plugins/mereka_lms.py) — `SITE_VARIANTS` map, `MerekaFooter` component
- [`docs/reference/operations/FOOTER_VARIANT_MATRIX.md`](FOOTER_VARIANT_MATRIX.md) — per-domain footer skin (companion document)
- [`assets/branding/tokens.css`](../../../assets/branding/tokens.css) — global design tokens (CSS custom properties)
- [`infrastructure/tutor/plugins/multi-tenancy/`](../../../infrastructure/tutor/plugins/multi-tenancy/) — TenantConfig model + TenantResolutionMiddleware
- [`scripts/tenants/provision-tenant.sh`](../../../scripts/tenants/provision-tenant.sh) — tenant provisioning
- [`scripts/qa/verify-tenant-branding-matrix.sh`](../../../scripts/qa/verify-tenant-branding-matrix.sh) — verification script
- [`scripts/qa/verify-footer-variant-matrix.sh`](../../../scripts/qa/verify-footer-variant-matrix.sh) — footer variant verification
