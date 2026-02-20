# Branding Operator Guide

_Audience: Platform Engineering + Ops • Last updated: 2026-02-20_

Single navigation page for all Mereka Academy branding and theming operations.
Use this as your entry point — every section links to authoritative detail docs.

---

## Quick Decision Tree

```
Need to change branding on…

 ├── MFE (React apps: authn, learning, account, etc.)
 │    └── Footer content/links/copy → edit MerekaFooter in mereka_lms.py
 │    └── Colors/fonts/CSS variables  → edit mfe/mereka.scss or design tokens
 │    └── Logo/favicon URL            → update SITE_VARIANTS or MFE env config
 │    └── Plugin slot override        → add/edit PLUGIN_SLOTS in mereka_lms.py
 │
 ├── LMS (server-rendered Mako pages)
 │    └── Footer                      → edit themes/mereka/lms/templates/footer.html
 │    └── Header / logo               → edit themes/mereka/lms/templates/header/brand.html
 │    └── Homepage hero               → edit themes/mereka/lms/templates/index_overlay.html
 │    └── CSS / SCSS                  → edit themes/mereka/lms/static/sass/theme.scss
 │
 ├── Studio (CMS — server-rendered)
 │    └── Footer                      → edit themes/mereka/cms/templates/widgets/footer.html ← CANONICAL
 │    └── Head / fonts / CSS          → edit themes/mereka/cms/templates/head-extra.html
 │    └── SCSS                        → edit themes/mereka/cms/static/sass/theme.scss
 │
 └── Tenant-specific override
      └── New tenant logo/colors      → see Tenant Brand Pack workflow below
      └── Per-tenant footer copy      → edit SITE_VARIANTS in mereka_lms.py (MFE)
      └── Per-site PLATFORM_NAME      → Django admin → Sites → Site Configuration
```

---

## Surface Reference

### LMS/CMS: Comprehensive Theming (server-rendered)

These surfaces use Open edX Comprehensive Theming. Files live under
`infrastructure/tutor/themes/mereka/` and override upstream templates at build time.

| Surface | File | Mechanism | Update trigger |
|---------|------|-----------|----------------|
| LMS footer | `lms/templates/footer.html` | Mako template override | Image rebuild |
| LMS header logo | `lms/templates/header/brand.html` | Mako template override | Image rebuild |
| LMS homepage hero | `lms/templates/index_overlay.html` | Mako template override | Image rebuild |
| LMS SCSS/CSS | `lms/static/sass/theme.scss` | SASS compilation | Image rebuild |
| Studio footer | `cms/templates/widgets/footer.html` | Mako template override (**canonical renderer**) | Image rebuild |
| Studio head/CSS | `cms/templates/head-extra.html` | Mako template override | Image rebuild |
| Studio SCSS | `cms/static/sass/theme.scss` | SASS compilation | Image rebuild |
| Design tokens | `common/static/css/mereka-design-tokens.css` | Static CSS file | `sync-brand-assets.sh` |

**Key rule**: Changes to any file under `themes/mereka/` require `tutor images build openedx`
to take effect. There is no hot-reload for Mako templates in production.

**Editing workflow**:
```bash
# 1. Edit the theme file
vim infrastructure/tutor/themes/mereka/lms/templates/footer.html

# 2. Verify at source before building
./scripts/qa/verify-footer-parity.sh
./scripts/qa/verify-studio-authoring-branding.sh

# 3. Build image (WhiteCliff lane)
tutor images build openedx -a PIP_COMMAND=pip
tutor images push openedx

# 4. Update image tag and deploy
# (Update deploy/k8s/overlays/production/kustomization.yaml)
```

---

### MFE: Plugin-First (React, FPF plugin slots)

MFE surfaces use the Frontend Plugin Framework (FPF) slot system. Overrides are injected
at build time via `mereka_lms.py` Tutor plugin hooks.

| Surface | Mechanism | File | Update trigger |
|---------|-----------|------|----------------|
| Footer (all MFEs) | FPF `footer_slot` Replace | `mereka_lms.py` → `MerekaFooter` JSX | MFE image rebuild |
| Fonts/SCSS | `env.config.jsx` SCSS import | `mereka_lms.py` → mfe-env-config hook | MFE image rebuild |
| Cookie banner | `banner_notification_slot` | `mereka_lms.py` | MFE image rebuild |
| MFE env config (LMS URLs, etc.) | `mfe-env-config` hook | `mereka_lms.py` | MFE image rebuild |

**Plugin-first rule**: MFE customizations MUST go through `mereka_lms.py` Tutor plugin hooks.
Do NOT add patches to `apply-patches.sh` for MFE-related changes unless as a defense-in-depth
fallback (dual-path) with identical JSX.

**MFE footer editing workflow**:
```bash
# 1. Edit MerekaFooter JSX in mereka_lms.py
vim infrastructure/tutor/plugins/mereka_lms.py
# Also update the identical copy in apply-patches.sh (footer_component variable)

# 2. Verify at source
./scripts/qa/verify-mfe-footer-slot.sh      # 30 PASS / 0 FAIL / 0 WARN expected
./scripts/qa/verify-footer-parity.sh        # 38 PASS / 0 FAIL / 1 WARN expected

# 3. Build MFE image
tutor images build mfe
tutor images push mfe

# 4. Update image tag and deploy (ArgoCD sync)
```

**Per-tenant footer variant** (SITE_VARIANTS in mereka_lms.py):
```javascript
// Hostname → { brand, copyrightHolder, whatsapp }
const SITE_VARIANTS = {
  'academyv2.mereka.io': { brand: 'Mereka Academy', copyrightHolder: 'MEREKA', ... },
  'academy.biji-biji.com': { brand: 'Biji-Biji Academy', copyrightHolder: 'Biji-Biji Initiative', ... },
  'skillourfuture.academy.mereka.io': { brand: 'Skill Our Future Academy', copyrightHolder: 'MEREKA', ... },
};
```

---

## Tenant Branding Override Workflow

For adding or updating a tenant's brand (logo, colors, per-site name):

### Step 1: Update SITE_VARIANTS (MFE footer)
Edit `infrastructure/tutor/plugins/mereka_lms.py` → `SITE_VARIANTS` map.
Required fields: `brand`, `copyrightHolder`, `whatsapp`.

### Step 2: Update PLATFORM_NAME (LMS copyright)
Django admin → **Sites** → **Site Configuration** for the tenant's domain.
Set `PLATFORM_NAME` = tenant display name. This controls `get_platform_name()` in LMS Mako templates.

### Step 3: Update logos
```bash
# Place logos at:
infrastructure/tutor/themes/mereka/tenants/<slug>/logos/logo.png
infrastructure/tutor/themes/mereka/tenants/<slug>/favicons/favicon.ico

# Sync assets
./scripts/branding/sync-brand-assets.sh
```

### Step 4: Verify
```bash
./scripts/qa/verify-footer-parity.sh
./scripts/qa/verify-multisite-config.sh
./scripts/qa/verify-favicon-multisite.sh
```

**Full contract**: `docs/branding/TENANT_BRANDING_CONTRACT.md` → "Footer Parity Contract" section.

---

## Banned Patterns (Auto-detected by QA scripts)

| Pattern | Surfaces checked | Script |
|---------|-----------------|--------|
| `Powered by Open edX` (unbranded) | LMS footer, Studio footer, MFE footer | `verify-footer-parity.sh` |
| `Powered by Tutor` | LMS footer, Studio footer | `verify-footer-parity.sh` |
| Google Fonts import (`fonts.googleapis.com`) | All CSS, Studio CSS | `verify-studio-authoring-branding.sh` |
| Open edX logo tag (`open-edx-logo-tag`) | Studio footer | `verify-footer-parity.sh` |
| Hardcoded copyright year (e.g. `© 2024`) | LMS footer | `verify-footer-parity.sh` AC-FTPAR-006 |

---

## Accepted Warnings (Not Gate Failures)

| Warning | Reason | Resolution |
|---------|--------|-----------|
| Enterprise MFE portals use Open edX default footer | No MerekaFooter slot wiring; low priority | P4 backlog |
| LMS nav links (emails, help URL) are Mereka-specific | Multi-tenant nav pending bead 2rcf (TenantConfig) | Bead 2rcf |
| Studio footer — single static template (no per-tenant) | Single Studio pod; tenant routing not implemented | Bead 3sxq (backlog) |

---

## apply-patches.sh vs. Plugin: When to Use Which

| Change type | Use | Why |
|------------|-----|-----|
| MFE plugin slot override | `mereka_lms.py` | FPF slots are the canonical mechanism |
| LMS/CMS template override | `themes/mereka/**` | Comprehensive Theming is the canonical mechanism |
| LMS Django settings (ALLOWED_HOSTS, etc.) | `mereka_lms.py` → `openedx-lms-production-settings` hook | Plugin hooks are maintained across Tutor upgrades |
| Dockerfile modifications (Node, Python deps) | `mereka_lms.py` → appropriate Dockerfile hook | Plugin hooks survive `tutor config save` regeneration |
| `apply-patches.sh` | **ONLY** for items without a supported Tutor plugin hook | See `PLUGIN_MIGRATION_SURVEY.md` Section C (10 items) |

**Rule**: If a Tutor plugin hook exists, use it. `apply-patches.sh` is legacy escape hatch only.
See `docs/branding/PLUGIN_MIGRATION_SURVEY.md` for the full migration roadmap.

---

## Verification Commands (run before any PR)

```bash
# Footer surfaces (source-level — no live cluster needed)
./scripts/qa/verify-footer-parity.sh
# Expected: 38 PASS / 0 FAIL / 1 WARN

# MFE plugin slot wiring
./scripts/qa/verify-mfe-footer-slot.sh
# Expected: 30 PASS / 0 FAIL / 0 WARN

# Studio authoring branding (source + live CSS check)
./scripts/qa/verify-studio-authoring-branding.sh

# Multi-site config correctness
./scripts/qa/verify-multisite-config.sh

# Post-deploy (requires live cluster)
./scripts/qa/post-deploy-verify.sh prod
# Expected exit 0 after WhiteCliff deploys
```

---

## Document Index

| Topic | Document |
|-------|---------|
| **This guide** (entry point) | `docs/branding/BRANDING_OPERATOR_GUIDE.md` |
| Footer parity contract (per-tenant) | `docs/branding/TENANT_BRANDING_CONTRACT.md` → "Footer Parity Contract" |
| Plugin migration roadmap | `docs/branding/PLUGIN_MIGRATION_SURVEY.md` |
| Operating model + exception policy | `docs/branding/BRANDING_OPERATING_MODEL.md` |
| Regression gates | `docs/branding/BRANDING_GUARDRAILS.md` |
| MFE v2 footer zone mapping | `docs/branding/FOOTER_V2_TO_LMS_MAPPING.md` |
| Paragon design token alignment | `docs/branding/PARAGON_TOKEN_ALIGNMENT.md` |
| Tenant provisioning runbook | `docs/operations/TENANT_PROVISIONING.md` |
| Post-deploy verification | `scripts/qa/post-deploy-verify.sh` |
