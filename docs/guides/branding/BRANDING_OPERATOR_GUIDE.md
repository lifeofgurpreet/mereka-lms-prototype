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
// These three fields are runtime-resolved from window.location.hostname — no image rebuild needed
// to switch WHICH entry is active, but an image rebuild IS required to ADD/CHANGE an entry.
const SITE_VARIANTS = {
  'academyv2.mereka.io':               { brand: 'Mereka Academy',           copyrightHolder: 'MEREKA',                whatsapp: '601135271981' },
  'academy.biji-biji.com':             { brand: 'Biji-Biji Academy',         copyrightHolder: 'Biji-Biji Initiative',  whatsapp: '601135271981' },
  'skillourfuture.academy.mereka.io':  { brand: 'Skill Our Future Academy',  copyrightHolder: 'MEREKA',                whatsapp: '601135271981' },
};
```

**SITE_VARIANTS field reference:**

| Field | Controls | Where rendered | Rebuild to change? |
|-------|---------|----------------|-------------------|
| `brand` | Footer brand name (e.g. "Mereka Academy") | MFE footer logo alt text + Zone 1 brand | Yes — MFE image rebuild |
| `copyrightHolder` | Legal copyright string "© 2026 {holder}" | MFE footer legal zone | Yes — MFE image rebuild |
| `whatsapp` | WhatsApp contact number in Zone 1 | MFE footer social row | Yes — MFE image rebuild |

**Other MFE footer content (currently global — not per-tenant):**

| Content | Location in mereka_lms.py | How to make per-tenant |
|---------|--------------------------|----------------------|
| `navLinks` (About, Andragogy, Help Centre…) | `const navLinks = [...]` line ~745 | Extend SITE_VARIANTS with `navLinks` array |
| Help Centre URL (`https://help.mereka.io/`) | Hardcoded in `navLinks` | Extend SITE_VARIANTS with `helpUrl` field |
| Social handles (TikTok, Instagram, Facebook…) | `const socialLinks = [...]` line ~737 | Extend SITE_VARIANTS with `socialLinks` array |
| Corporate/Academy/Marketplace link groups | `const corporateLinks`, `academyLinks`… | Extend SITE_VARIANTS with column arrays |

**To extend SITE_VARIANTS with support email + help URL for a new tenant**, add to the per-domain object:
```javascript
// Example: add helpUrl + supportEmail as extendable fields
const SITE_VARIANTS = {
  'academyv2.mereka.io': {
    brand: 'Mereka Academy', copyrightHolder: 'MEREKA', whatsapp: '601135271981',
    helpUrl: 'https://help.mereka.io/',
    supportEmail: 'support@mereka.io',
  },
  'newtenant.example.com': {
    brand: 'NewTenant Academy', copyrightHolder: 'NewTenant Inc', whatsapp: '60XXXXXXXXX',
    helpUrl: 'https://help.newtenant.com/',
    supportEmail: 'academy@newtenant.com',
  },
};
// Then use variant.helpUrl / variant.supportEmail in the JSX body
```
After editing, rebuild: `tutor images build mfe` → push → rolling restart.

---

## Tenant Branding Override Workflow

For adding or updating a tenant's brand (logo, colors, per-site name, footer links):

### Step 1: Update SITE_VARIANTS (MFE footer)

Edit `infrastructure/tutor/plugins/mereka_lms.py` → `SITE_VARIANTS` map.

**Minimum fields** (required for all tenants):
```javascript
'newtenant.example.com': { brand: 'Tenant Brand Name', copyrightHolder: 'Legal Entity Name', whatsapp: '60XXXXXXXXX' },
```

**Extended fields** (add when tenant needs custom support contact or help URL):
```javascript
'newtenant.example.com': {
  brand: 'Tenant Brand Name',
  copyrightHolder: 'Legal Entity Name',
  whatsapp: '60XXXXXXXXX',
  helpUrl: 'https://help.newtenant.com/',    // optional — defaults to https://help.mereka.io/
  supportEmail: 'academy@newtenant.com',     // optional — document in JSX body to render
},
```

After adding, rebuild: `tutor images build mfe` → push → rolling restart.

### Step 2: Update PLATFORM_NAME (LMS copyright)

Django admin → **Sites** → **Site Configuration** for the tenant's domain.
Set `PLATFORM_NAME` = tenant display name.
This controls `get_platform_name()` in LMS Mako templates (footer copyright + page titles).

**No image rebuild needed** — SiteConfiguration is read at request time.

### Step 3: Update logos

```bash
# Update canonical brand assets first:
# - default brand: assets/branding/
# - tenant package brands: assets/branding/tenants/<slug>/

# Sync themes + all brand-* packages
./scripts/branding/sync-brand-assets.sh

# Verify no drift across all consumers
./scripts/qa/verify-brand-asset-drift.sh
```

Logo changes require LMS image rebuild.

### Step 4: Update LMS footer links (if tenant needs custom Support/Explore/Partners links)

LMS footer links are currently **global** (shared across all LMS tenants). They are hardcoded in:
`infrastructure/tutor/themes/mereka/lms/templates/footer.html`

**Current state**: All tenants share the same LMS footer links:
- Support: `techadmin@biji-biji.com`, `support@mereka.io`, `/help`, `/privacy`
- Explore: `/courses`, `/dashboard`, `mereka.my`, `team@mereka.io`
- Partners: `biji-biji.com`, `mereka.my/partner`, `mereka.my/stories`

**To give a tenant custom LMS footer links TODAY** (requires image rebuild):
1. Edit `footer.html` to use `${settings.PLATFORM_NAME}` checks or Django `SiteConfiguration` key lookups
2. OR implement via `TenantConfig.footer_config` (bead 2rcf — pending)
3. Build: `tutor images build openedx -a PIP_COMMAND=pip` → push → rolling restart

**Production-grade multi-tenant LMS footer** is gated on bead 2rcf (TenantConfig model).
Until 2rcf is live, edit `footer.html` directly for urgent per-tenant customization.

### Step 5: Verify

```bash
# Source-only (CI-safe, no network needed)
./scripts/qa/verify-footer-parity.sh
./scripts/qa/verify-multisite-config.sh
./scripts/qa/verify-favicon-multisite.sh

# Live (requires deployed cluster)
./scripts/qa/verify-footer-parity.sh --live
```

**Full contract**: `docs/guides/branding/TENANT_BRANDING_CONTRACT.md` → "Footer Parity Contract" section.

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

## Plugin-vs-Theme Decision Table

Use this table to choose the correct extension surface. Wrong surface = changes lost on next `tutor config save`.

### By surface

| What you want to change | Surface | Correct mechanism | File to edit | Rebuild needed |
|------------------------|---------|------------------|--------------|----------------|
| Footer content, links, layout | **MFE** (React apps) | FPF `footer_slot` Replace in Tutor plugin | `mereka_lms.py` → `MerekaFooter` JSX | MFE image rebuild |
| Footer content, links, layout | **LMS** (Mako pages) | Open edX Comprehensive Theming | `themes/mereka/lms/templates/footer.html` | LMS image rebuild |
| Footer content, layout | **Studio** (CMS) | Open edX Comprehensive Theming | `themes/mereka/cms/templates/widgets/footer.html` | LMS image rebuild |
| Header logo, nav | **LMS** | Comprehensive Theming | `themes/mereka/lms/templates/header/brand.html` | LMS image rebuild |
| CSS variables, fonts, colors | **MFE** | Tutor plugin → mfe-env-config hook / `mfe/mereka.scss` | `mereka_lms.py` or `themes/mereka/mfe/mereka.scss` | MFE image rebuild |
| CSS variables, fonts, colors | **LMS/CMS** | Comprehensive Theming SCSS | `themes/mereka/lms/static/sass/theme.scss` | LMS image rebuild |
| Django settings (ALLOWED_HOSTS, etc.) | **LMS/CMS** | Tutor plugin hook | `mereka_lms.py` → `openedx-lms-production-settings` | Pod restart |
| Dockerfile dependencies (Node, Python) | **LMS/MFE image** | Tutor plugin Dockerfile hook | `mereka_lms.py` → `openedx-dockerfile-*` hook | Full image rebuild |
| K8s manifests / Caddy config | **Deployment** | Tutor plugin `k8s-` / `caddyfile-` hooks | `mereka_lms.py` → appropriate K8s hook | ArgoCD sync |
| Anything without a Tutor plugin hook | **Any** | `apply-patches.sh` (last resort) | `infrastructure/tutor/apply-patches.sh` | Depends |

### By decision

```
Need to change something in Open edX...

Is it a React MFE surface?
├── YES → use mereka_lms.py (Tutor plugin)
│         (FPF slots, mfe-env-config hook, SCSS hook)
│
└── NO → Is it a Mako template / SCSS / static asset?
          ├── YES → use themes/mereka/**
          │         (Comprehensive Theming — canonical for server-rendered pages)
          │
          └── NO → Is it a Django setting or Dockerfile change?
                    ├── YES → use mereka_lms.py hooks
                    │         (plugin hooks survive tutor config save)
                    │
                    └── NO → Does a Tutor plugin hook exist for it?
                              ├── YES → use mereka_lms.py
                              └── NO → use apply-patches.sh (last resort)
                                       Document in PLUGIN_MIGRATION_SURVEY.md
```

### apply-patches.sh rule

`apply-patches.sh` is for **items with no supported Tutor plugin hook only**.
See `docs/guides/branding/PLUGIN_MIGRATION_SURVEY.md` Section C (10 remaining items).

If a Tutor plugin hook exists → use it. `apply-patches.sh` entries should decrease over time.

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
| **This guide** (entry point) | `docs/guides/branding/BRANDING_OPERATOR_GUIDE.md` |
| Footer parity contract (per-tenant) | `docs/guides/branding/TENANT_BRANDING_CONTRACT.md` → "Footer Parity Contract" |
| Plugin migration roadmap | `docs/guides/branding/PLUGIN_MIGRATION_SURVEY.md` |
| Operating model + exception policy | `docs/guides/branding/BRANDING_OPERATING_MODEL.md` |
| Regression gates | `docs/guides/branding/BRANDING_GUARDRAILS.md` |
| MFE v2 footer zone mapping | `docs/guides/branding/FOOTER_V2_TO_LMS_MAPPING.md` |
| Paragon design token alignment | `docs/guides/branding/PARAGON_TOKEN_ALIGNMENT.md` |
| Tenant provisioning runbook | `docs/runbooks/operations/TENANT_PROVISIONING.md` |
| Post-deploy verification | `scripts/qa/post-deploy-verify.sh` |
