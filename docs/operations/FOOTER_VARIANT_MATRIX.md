# Footer Variant Matrix

> Single source of truth for per-domain footer and skin configuration.
>
> **Bead**: mereka-lms-8jao.10
> **Last updated**: 2026-02-18
> **Canonical code**: `infrastructure/tutor/plugins/mereka_lms.py` — `SITE_VARIANTS` map (~line 671)

---

## Section 1: Per-Domain Variant Matrix

| Domain | Brand Name | Copyright Holder | WhatsApp | Logo Path | Color Theme | Footer Slot | Status |
|--------|-----------|-----------------|----------|-----------|-------------|-------------|--------|
| `academyv2.mereka.io` | Mereka Academy | MEREKA | `601135271981` | `/static/images/logo.png` | `--mereka-color-teal` primary | `org.openedx.frontend.layout.footer.v1` | ✅ Active |
| `academy.biji-biji.com` | Biji-Biji Academy | Biji-Biji Initiative | `601135271981` | `/static/images/logo.png` | `--mereka-color-teal` primary | `org.openedx.frontend.layout.footer.v1` | ✅ Active |
| `skillourfuture.academy.mereka.io` | Skill Our Future Academy | MEREKA | `601135271981` | `/static/images/logo.png` | `--mereka-color-teal` primary | `org.openedx.frontend.layout.footer.v1` | ✅ Active |
| *(default / unknown host)* | *(reads `config.SITE_NAME`)* | *(reads `config.PLATFORM_NAME` or `MEREKA`)* | `601135271981` | `/static/images/logo.png` | `--mereka-color-teal` primary | `org.openedx.frontend.layout.footer.v1` | ✅ Fallback |

**Notes**:
- Logo path is currently shared across all domains (served from LMS base URL).
- WhatsApp number is currently identical for all domains — update per-domain if required.
- Color theme override per domain is a planned Phase 3 enhancement (see Section 3).
- The fallback row applies to any hostname not listed above (localhost, staging, unknown domains).

---

## Section 2: Source of Truth Chain

The per-domain variant values flow through this chain at runtime:

```
SITE_VARIANTS (mereka_lms.py)
  └── keyed by window.location.hostname (browser-side lookup)
  └── resolves: brand, copyrightHolder, whatsapp
  └── fallback: config.SITE_NAME / config.PLATFORM_NAME (from env.config.jsx)

env.config.jsx (MFE build-time injection)
  └── SITE_NAME     → human-readable site name (e.g., "Mereka Academy")
  └── LMS_BASE_URL  → used to construct logoUrl
  └── PLATFORM_NAME → used by fallback variant as copyrightHolder

Multi-tenancy middleware (infrastructure/tutor/plugins/multi-tenancy/)
  └── TenantConfig model → resolves domain → sets SITE_NAME per request
  └── Serves SITE_NAME into LMS session → MFE reads via /api/user/v1/account

Logo files (theme static assets)
  └── infrastructure/tutor/themes/mereka/lms/static/images/logo.png
  └── Currently one shared logo — per-domain logo is a Phase 3 enhancement
```

### Where Each Value Comes From

| Field | Source | Changed via |
|-------|--------|-------------|
| `brand` | `SITE_VARIANTS[hostname].brand` | Edit `SITE_VARIANTS` in `mereka_lms.py`, rebuild MFE |
| `copyrightHolder` | `SITE_VARIANTS[hostname].copyrightHolder` | Edit `SITE_VARIANTS` in `mereka_lms.py`, rebuild MFE |
| `whatsapp` | `SITE_VARIANTS[hostname].whatsapp` | Edit `SITE_VARIANTS` in `mereka_lms.py`, rebuild MFE |
| Logo URL | `config.LMS_BASE_URL + /static/images/logo.png` | Replace theme static file |
| Fallback brand | `config.SITE_NAME` (from env.config.jsx) | Tutor config + multi-tenancy |
| Fallback copyright | `config.PLATFORM_NAME` | Tutor config |

---

## Section 3: Config-First Migration Path

### Phase 1 — Current State: Hardcoded in Plugin JS

**Status**: Active

```js
// infrastructure/tutor/plugins/mereka_lms.py (inside MerekaFooter component)
const SITE_VARIANTS = {
  'academyv2.mereka.io':             { brand: 'Mereka Academy', ... },
  'academy.biji-biji.com':           { brand: 'Biji-Biji Academy', ... },
  'skillourfuture.academy.mereka.io': { brand: 'Skill Our Future Academy', ... },
};
const variant = SITE_VARIANTS[hostname] || { brand: config.SITE_NAME, ... };
```

**Pros**: Simple, zero infrastructure dependencies, works offline.
**Cons**: Adding a domain requires editing Python source + MFE rebuild + redeploy.

---

### Phase 2 — Next: Extract to `env.config.jsx` Site Config

**Status**: Planned

Move the variant map from hardcoded JS to MFE environment config so it can be updated without rebuilding.

```js
// env.config.jsx (MFE reads at startup, no rebuild needed for config changes)
const siteVariants = window.env?.MEREKA_SITE_VARIANTS
  ? JSON.parse(window.env.MEREKA_SITE_VARIANTS)
  : {};
const variant = siteVariants[hostname] || defaultVariant;
```

**Tutor config addition**:
```yaml
# tutor_env/config.yml
MFE_CONFIG_EXTRA:
  MEREKA_SITE_VARIANTS: '{"academyv2.mereka.io":{"brand":"Mereka Academy",...}}'
```

**Pros**: No MFE rebuild for domain additions — only Tutor config change + service restart.
**Cons**: Config change still requires `tutor config save` + `apply-patches.sh` + service restart.

---

### Phase 3 — Future: TenantConfig API serves variant config

**Status**: Backlog

The `TenantConfig` model (`infrastructure/tutor/plugins/multi-tenancy/`) already maps domain → tenant. Extend it to serve footer variant config via a lightweight JSON API endpoint that the MFE polls at startup.

```js
// MFE fetches on mount
const variant = await fetch('/api/tenancy/v1/footer-config/')
  .then(r => r.json())
  .catch(() => defaultVariant);
```

**Pros**: Zero config file changes — operators edit tenant config via Django admin.
**Cons**: Adds API dependency; MFE must handle fetch failure gracefully.

---

## Section 4: Adding a New Domain

Follow this checklist when onboarding a 4th (or nth) branded domain:

### Operator Checklist

- [ ] **1. Add entry to `SITE_VARIANTS`** in `infrastructure/tutor/plugins/mereka_lms.py`:
  ```js
  'newdomain.example.com': { brand: 'Brand Name', copyrightHolder: 'Entity Name', whatsapp: '601XXXXXXXXX' },
  ```

- [ ] **2. Update this document** — add a row to the Per-Domain Variant Matrix (Section 1).

- [ ] **3. Add domain to Tutor multi-site config** — in `tutor_env/config.yml`:
  ```yaml
  LMS_HOST: academyv2.mereka.io  # primary
  # EXTRA_HOSTS includes newdomain.example.com
  ```

- [ ] **4. Run apply-patches.sh** after any `tutor config save`:
  ```bash
  ./infrastructure/tutor/apply-patches.sh
  ```

- [ ] **5. Add domain to multi-tenancy plugin config** — provision a TenantConfig record:
  ```bash
  ./scripts/tenants/provision-tenant.sh newdomain.example.com "Brand Name"
  ```

- [ ] **6. Add CSRF trusted origin and allowed host** — ensure the domain appears in:
  - `CSRF_TRUSTED_ORIGINS` (via apply-patches.sh or tutor config)
  - `ALLOWED_HOSTS` (via apply-patches.sh or tutor config)

- [ ] **7. SSL certificate** — for multi-level subdomains (`x.y.mereka.io`), use DNS-only
  (gray cloud) + Let's Encrypt. See `docs/operations/DOMAIN_MANAGEMENT.md`.

- [ ] **8. Rebuild and redeploy MFE**:
  ```bash
  tutor images build mfe
  tutor local restart mfe
  ```

- [ ] **9. Run verification**:
  ```bash
  ./scripts/qa/verify-footer-variant-matrix.sh
  ```

- [ ] **10. Smoke test** — visit the new domain and confirm footer shows correct brand name
  and copyright holder.

---

## Section 5: Verification

Run the verification script to confirm this matrix document and the `SITE_VARIANTS` map are in sync:

```bash
./scripts/qa/verify-footer-variant-matrix.sh
```

The script checks:

| AC | Check |
|----|-------|
| AC-FTVAR-001 | `SITE_VARIANTS` contains all 3 production domains |
| AC-FTVAR-002 | Each variant has `brand`, `copyrightHolder`, `whatsapp` fields (no nulls) |
| AC-FTVAR-003 | This matrix document exists with all domains documented |
| AC-FTVAR-004 | Fallback variant exists for unknown hostnames |
| AC-FTVAR-005 | No domain strings duplicated outside `SITE_VARIANTS` inside `MerekaFooter` body |

---

## References

- [`infrastructure/tutor/plugins/mereka_lms.py`](../../infrastructure/tutor/plugins/mereka_lms.py) — `SITE_VARIANTS` map, `MerekaFooter` component
- [`docs/concepts/architecture/COPY_TERMINOLOGY_CONTRACT.md`](../concepts/architecture/COPY_TERMINOLOGY_CONTRACT.md) — domain → brand copy table
- [`docs/concepts/architecture/MULTISITE_UX_CONSISTENCY.md`](../concepts/architecture/MULTISITE_UX_CONSISTENCY.md) — SITE_VARIANTS UX consistency requirements
- [`docs/concepts/architecture/FOOTER_SLOT_MIGRATION.md`](../concepts/architecture/FOOTER_SLOT_MIGRATION.md) — footer slot wiring contract
- [`infrastructure/tutor/plugins/multi-tenancy/`](../../infrastructure/tutor/plugins/multi-tenancy/) — TenantConfig model
- [`scripts/tenants/provision-tenant.sh`](../../scripts/tenants/provision-tenant.sh) — tenant provisioning
- [`scripts/qa/verify-footer-variant-matrix.sh`](../../scripts/qa/verify-footer-variant-matrix.sh) — verification script
