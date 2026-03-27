# Tenant Branding Matrix

> **Bead**: mereka-lms-115d.9
> **Last updated**: 2026-03-27
> **Canonical code**: `infrastructure/tutor/plugins/_mereka_lms/mfe_runtime_definitions.js` — `MEREKA_SITE_VARIANTS`

---

## Tenant Domain Registry

| Domain | Brand Name | Copyright Holder | WhatsApp | Logo | Tokens Override | Footer Variant |
|--------|-----------|-----------------|----------|------|----------------|---------------|
| `academyv2.mereka.io` | Mereka Academy | MEREKA | `601135271981` | `/theme/logo-horizontal.svg` | none (global) | mereka |
| `academy.biji-biji.com` | Biji-Biji Academy | Biji-Biji Initiative | `601135271981` | `/theme/biji-biji/logo-horizontal.svg` | none (global) | biji-biji |
| `skillourfuture.academy.mereka.io` | Skill Our Future Academy | MEREKA | `601135271981` | `/theme/skillourfuture/logo-horizontal.svg` | none (global) | skillourfuture |
| *(default / unknown host)* | *(reads `config.SITE_NAME`, except stock `My Open edX` coerces to `Mereka Academy`)* | *(reads `config.PLATFORM_NAME`, except stock `My Open edX` coerces to `MEREKA`)* | `601135271981` | `/theme/logo-horizontal.svg` | none (global) | fallback |

**Notes**:
- `MEREKA_SITE_VARIANTS` is the authoritative tenant footer registry for MFEs today.
- The runtime helper also resolves `apps.*`, `staging.*`, and `.mereka.dev` hostnames back to their canonical LMS domains.
- Design tokens remain global; per-tenant token divergence is still a future phase.

---

## Override Inheritance Model

All tenants inherit the global theme (`mereka.scss`, `tokens.css`, `mereka-overrides.css`).
Per-tenant customization is currently limited to:

1. **Footer content and links** via `MEREKA_SITE_VARIANTS`
2. **Brand name / copyright** via `MEREKA_SITE_VARIANTS`
3. **Logo/theme asset paths** via `MEREKA_SITE_VARIANTS`
4. **Fallback brand/platform values** via `config.SITE_NAME` / `config.PLATFORM_NAME`

### Fallback Chain

```text
Exact canonical LMS hostname in MEREKA_SITE_VARIANTS
  → Derived candidate match (apps./staging./.mereka.dev hostnames)
    → Deterministic fallback built from config.SITE_NAME / config.PLATFORM_NAME
      → Stock 'My Open edX' coerced to Mereka defaults
```

The fallback is implemented in `getMerekaVariant()` inside
`_mereka_lms/mfe_runtime_definitions.js`, not inline in docs-owned snippets.

### Global Theme Source

Design tokens live in `assets/branding/tokens.css` and are injected into all tenants via:

- `infrastructure/tutor/themes/mereka/common/static/css/mereka-overrides.css` — LMS/CMS
- `infrastructure/tutor/themes/mereka/mfe/mereka.scss` — MFEs

No tenant currently overrides these tokens. Any per-domain token override must be implemented
as a separate CSS file loaded after the global tokens.

---

## Adding a New Tenant (Operator Checklist)

Follow this checklist when onboarding a new branded domain:

- [ ] **1. Add entry to `MEREKA_SITE_VARIANTS`** in `infrastructure/tutor/plugins/_mereka_lms/mfe_runtime_definitions.js`:
  ```js
  'newdomain.example.com': {
    ...MEREKA_BASE_VARIANT,
    brand: 'Brand Name',
    copyrightHolder: 'Entity Name',
    supportEmail: 'support@example.com',
  },
  ```

- [ ] **2. Update this document** — add a row to the Tenant Domain Registry table above.

- [ ] **3. Update `FOOTER_VARIANT_MATRIX.md`** — keep the footer-specific matrix in sync with the tenant registry.

- [ ] **4. Add domain to allowed hosts / CSRF trusted origins** via the normal Tutor config workflow:
  ```bash
  export TUTOR_ROOT="$(pwd)/tutor_env"
  ./scripts/infra/tutor-config-save.sh --set ...
  ```

- [ ] **5. Configure DNS + SSL**:
  - single-level subdomain: Cloudflare proxy is fine
  - multi-level subdomain: use DNS-only + Let's Encrypt

- [ ] **6. Provision TenantConfig record** if the domain needs explicit platform tenant resolution:
  ```bash
  ./scripts/tenants/provision-tenant.sh newdomain.example.com "Brand Name"
  ```

- [ ] **7. Publish updated MFE image** because `MEREKA_SITE_VARIANTS` is embedded in the bundle:
  ```bash
  tutor images build mfe
  tutor local restart mfe
  ```
  For shared environments, publish through the GitHub build workflow and promote through reviewed GitOps.

- [ ] **8. Run verification**:
  ```bash
  ./scripts/qa/verify-tenant-branding-matrix.sh
  ./scripts/qa/verify-footer-variant-matrix.sh
  ./scripts/qa/verify-tenant-footer-variant-lane.sh
  ```

- [ ] **9. Smoke test** — visit the new domain and confirm footer shows correct brand name,
  copyright holder, and tenant theme assets.

---

## Rollback Plan

If a domain mapping is misconfigured or a new tenant domain causes issues:

### Immediate Rollback (config-level)

1. **Automatic fallback**: if a domain key is missing or typo'd in `MEREKA_SITE_VARIANTS`,
   the runtime helper falls back to `config.SITE_NAME` / `config.PLATFORM_NAME`, with stock
   `My Open edX` coerced to Mereka defaults.

2. **Remove a tenant**: delete the domain entry from `MEREKA_SITE_VARIANTS`,
   rebuild the MFE image, and redeploy it. No database rows are touched by this map.

3. **Emergency force-fallback**: clear the variant map:
   ```js
   const MEREKA_SITE_VARIANTS = {};
   ```
   The fallback branch then applies universally after the next MFE rebuild.

### Misconfigured Domain Mapping (DNS/middleware)

If `TenantResolutionMiddleware` maps a request to the wrong tenant:

1. Check `TenantConfig` records via Django admin.
2. Correct the `domain` field for the misconfigured record.
3. Flush platform caches if required.
4. Re-run the tenant verification scripts.

### Existing Tenants — Migration Note

The three production domains already live in `MEREKA_SITE_VARIANTS`; no data migration is required.
If you migrate a tenant to a new domain:

1. add the new domain entry alongside the old one
2. deploy and verify
3. remove the old entry after DNS cutover

---

## Verification

Run the verification script to confirm this matrix and the footer variant matrix are in sync:

```bash
./scripts/qa/verify-tenant-branding-matrix.sh
```

The script checks:

| AC | Check |
|----|-------|
| AC-TEN-001 | `TENANT_BRANDING_MATRIX.md` exists with >= 2 domain rows and all required columns |
| AC-TEN-002 | `MEREKA_SITE_VARIANTS` has >= 2 entries + fallback; `tokens.css` exists as global theme source |
| AC-TEN-003 | Each production domain has non-empty brand/copyrightHolder/whatsapp; cross-checked vs `FOOTER_VARIANT_MATRIX.md` |
| AC-TEN-004 | This document has rollback + onboarding + migration note sections |

---

## References

- [`infrastructure/tutor/plugins/_mereka_lms/mfe_runtime_definitions.js`](../../../infrastructure/tutor/plugins/_mereka_lms/mfe_runtime_definitions.js) — tenant footer/runtime map
- [`docs/reference/operations/FOOTER_VARIANT_MATRIX.md`](FOOTER_VARIANT_MATRIX.md) — footer-specific matrix
- [`assets/branding/tokens.css`](../../../assets/branding/tokens.css) — global design tokens
- [`infrastructure/tutor/plugins/multi-tenancy/`](../../../infrastructure/tutor/plugins/multi-tenancy/) — TenantConfig model + middleware
- [`scripts/tenants/provision-tenant.sh`](../../../scripts/tenants/provision-tenant.sh) — tenant provisioning
- [`scripts/qa/verify-tenant-branding-matrix.sh`](../../../scripts/qa/verify-tenant-branding-matrix.sh) — verification script
- [`scripts/qa/verify-footer-variant-matrix.sh`](../../../scripts/qa/verify-footer-variant-matrix.sh) — footer variant verification
