# Footer Variant Matrix

> Single source of truth for per-domain footer and skin configuration.
>
> **Bead**: mereka-lms-8jao.10
> **Last updated**: 2026-03-27
> **Canonical code**: `infrastructure/tutor/plugins/_mereka_lms/mfe_runtime_definitions.js` — `MEREKA_SITE_VARIANTS` + `getMerekaVariant()`

---

## Section 1: Per-Domain Variant Matrix

| Domain | Brand Name | Copyright Holder | WhatsApp | Logo Path | Color Theme | Footer Slot | Status |
|--------|-----------|-----------------|----------|-----------|-------------|-------------|--------|
| `academyv2.mereka.io` | Mereka Academy | MEREKA | `601135271981` | `/theme/logo-horizontal.svg` | `mereka-brand*.css` | `org.openedx.frontend.layout.footer.v1` | Active |
| `academy.biji-biji.com` | Biji-Biji Academy | Biji-Biji Initiative | `601135271981` | `/theme/biji-biji/logo-horizontal.svg` | `biji-biji-brand*.css` | `org.openedx.frontend.layout.footer.v1` | Active |
| `skillourfuture.academy.mereka.io` | Skill Our Future Academy | MEREKA | `601135271981` | `/theme/skillourfuture/logo-horizontal.svg` | `sof-brand*.css` | `org.openedx.frontend.layout.footer.v1` | Active |
| *(default / unknown host)* | *(reads `config.SITE_NAME`, except stock `My Open edX` coerces to `Mereka Academy`)* | *(reads `config.PLATFORM_NAME`, except stock `My Open edX` coerces to `MEREKA`)* | `601135271981` | `/theme/logo-horizontal.svg` | `mereka-brand*.css` | `org.openedx.frontend.layout.footer.v1` | Fallback |

**Notes**:
- The footer data lives in `MEREKA_SITE_VARIANTS`, not in Django `SiteConfiguration`.
- The helper first checks canonical LMS hostnames, then derives `apps.*`, `staging.*`, and `.mereka.dev` candidates before falling back.
- Logo/theme asset paths are tenant-specific inside the MFE bundle and are resolved against `config.LMS_BASE_URL`.

---

## Section 2: Source of Truth Chain

The per-domain variant values flow through this chain at runtime:

```text
MEREKA_SITE_VARIANTS (_mereka_lms/mfe_runtime_definitions.js)
  └── keyed by canonical LMS domain
  └── resolves: brand, copyrightHolder, supportEmail, helpUrl, logo/theme assets

getMerekaVariant(hostname, config)
  └── exact LMS hostname match
  └── derived candidate match for apps./staging./.mereka.dev hosts
  └── deterministic unknown-host fallback using config.SITE_NAME / config.PLATFORM_NAME

MerekaFooter
  └── reads getMerekaVariant(window.location.hostname, getConfig())
  └── renders footer shell, links, logo, and legal row

mereka_lms_mfe_slots.py
  └── hides default_contents in org.openedx.frontend.layout.footer.v1
  └── inserts MerekaFooter as the active footer widget
```

### Where Each Value Comes From

| Field | Source | Changed via |
|-------|--------|-------------|
| `brand` | `MEREKA_SITE_VARIANTS[domain].brand` | Edit `_mereka_lms/mfe_runtime_definitions.js`, rebuild MFE |
| `copyrightHolder` | `MEREKA_SITE_VARIANTS[domain].copyrightHolder` | Edit `_mereka_lms/mfe_runtime_definitions.js`, rebuild MFE |
| `whatsapp` | `MEREKA_BASE_VARIANT.whatsapp` or domain override | Edit `_mereka_lms/mfe_runtime_definitions.js`, rebuild MFE |
| `supportEmail` | Domain override in `MEREKA_SITE_VARIANTS` | Edit `_mereka_lms/mfe_runtime_definitions.js`, rebuild MFE |
| Logo URL | `variant.logoUrl` resolved against `config.LMS_BASE_URL` | Edit `_mereka_lms/mfe_runtime_definitions.js` and theme assets |
| Fallback brand | `config.SITE_NAME` unless stock `My Open edX` | Tutor config + multi-tenancy + runtime helper |
| Fallback copyright | `config.PLATFORM_NAME` unless stock `My Open edX` | Tutor config + runtime helper |

---

## Section 3: Config-First Migration Path

### Phase 1 — Current State: Runtime Helper in Plugin JS

**Status**: Active

```js
const MEREKA_SITE_VARIANTS = {
  'academyv2.mereka.io': { ...MEREKA_BASE_VARIANT, brand: 'Mereka Academy', ... },
  'academy.biji-biji.com': { ...MEREKA_BASE_VARIANT, brand: 'Biji-Biji Academy', ... },
  'skillourfuture.academy.mereka.io': { ...MEREKA_BASE_VARIANT, brand: 'Skill Our Future Academy', ... },
};

const getMerekaVariant = (hostname, config) => {
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
};
```

**Pros**:
- deterministic and self-contained
- supports canonical LMS domains plus MFE/staging hostnames
- does not require a runtime API round-trip for footer rendering

**Cons**:
- adding a tenant domain still requires an MFE rebuild
- the runtime helper remains code-owned rather than config-owned

### Phase 2 — Next: Config-Owned Variant Map

**Status**: Planned

Move the variant map to a structured runtime config surface while keeping the same `getMerekaVariant()` fallback semantics.

### Phase 3 — Future: TenantConfig API Surface

**Status**: Backlog

Expose tenant footer variant data through a lightweight platform-owned API only if operational needs outweigh the simplicity of the current bundle-owned map.

---

## Section 4: Adding a New Domain

Follow this checklist when onboarding a 4th (or nth) branded domain:

### Operator Checklist

- [ ] **1. Add entry to `MEREKA_SITE_VARIANTS`** in `infrastructure/tutor/plugins/_mereka_lms/mfe_runtime_definitions.js`:
  ```js
  'newdomain.example.com': {
    ...MEREKA_BASE_VARIANT,
    brand: 'Brand Name',
    copyrightHolder: 'Entity Name',
    supportEmail: 'support@example.com',
  },
  ```

- [ ] **2. Update this document** — add a row to the Per-Domain Variant Matrix (Section 1).

- [ ] **3. Add domain to Tutor multi-site config / SiteConfiguration** so the platform recognizes the host and serves the correct `SITE_NAME` / `PLATFORM_NAME` fallback values.

- [ ] **4. If you changed Tutor config**, rerun the standard Tutor regeneration flow:
  ```bash
  export TUTOR_ROOT="$(pwd)/tutor_env"
  ./scripts/infra/tutor-config-save.sh --set ...
  ```

- [ ] **5. Add domain to multi-tenancy plugin config** — provision a `TenantConfig` record if the host needs tenant-specific resolution beyond the footer bundle:
  ```bash
  ./scripts/tenants/provision-tenant.sh newdomain.example.com "Brand Name"
  ```

- [ ] **6. Publish updated MFE assets**:
  - local validation:
    ```bash
    ./scripts/infra/build-mfe-image.sh --local-defaults --build-profile fast
    tutor local restart mfe
    ```
  - shared environments:
    - build and publish through `.github/workflows/build-tutor-images.yml`
    - promote the resulting digests through the reviewed GitOps path

- [ ] **7. Run verification**:
  ```bash
  ./scripts/qa/verify-footer-variant-matrix.sh
  ./scripts/qa/verify-tenant-branding-matrix.sh
  ./scripts/qa/verify-tenant-footer-variant-lane.sh
  ```

- [ ] **8. Smoke test** — visit the new domain and confirm footer shows the correct brand name, copyright holder, and theme assets.

---

## Section 5: Verification

Run the verification script to confirm this matrix document and the runtime helper are in sync:

```bash
./scripts/qa/verify-footer-variant-matrix.sh
```

The script checks:

| AC | Check |
|----|-------|
| AC-FTVAR-001 | `MEREKA_SITE_VARIANTS` contains all 3 production domains |
| AC-FTVAR-002 | Each variant has `brand`, `copyrightHolder`, and `whatsapp` (direct or inherited) |
| AC-FTVAR-003 | This matrix document exists and points to the canonical runtime definitions module |
| AC-FTVAR-004 | `getMerekaVariant()` performs exact match, derived-host lookup, and unknown-host fallback |
| AC-FTVAR-005 | Domain strings are confined to `MEREKA_SITE_VARIANTS` inside `mfe_runtime_definitions.js` |

---

## References

- [`infrastructure/tutor/plugins/_mereka_lms/mfe_runtime_definitions.js`](../../../infrastructure/tutor/plugins/_mereka_lms/mfe_runtime_definitions.js) — `MEREKA_SITE_VARIANTS`, `getMerekaVariant`, `MerekaFooter`
- [`infrastructure/tutor/plugins/mereka_lms_mfe_slots.py`](../../../infrastructure/tutor/plugins/mereka_lms_mfe_slots.py) — footer slot registration
- [`docs/reference/operations/TENANT_BRANDING_MATRIX.md`](TENANT_BRANDING_MATRIX.md) — companion tenant registry view
- [`docs/ops/runbooks/TENANT_FOOTER_VARIANT_LANE.md`](../../ops/runbooks/TENANT_FOOTER_VARIANT_LANE.md) — operator-facing footer lane guide
- [`scripts/qa/verify-footer-variant-matrix.sh`](../../../scripts/qa/verify-footer-variant-matrix.sh) — verification script
