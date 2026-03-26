# Multitenant Brand Platform

_Audience: Platform Engineering + Tenant Operations • Owner: Platform Team • Last verified: 2026-03-26 • Status: canonical_

This document is the operational reference for the Mereka LMS multi-tenant brand platform. It covers the brand config model, runtime fallback rules, per-tenant smoke paths, contract test strategy, the SkillOurFuture migration guide, and governance policy.

Current runtime note: live staging still shows the deployment lag from the merged app/runtime work, so `/api/mfe_config/v1` leakage and tenant CSS mismatch remain live until promotion catches up. That is a deployment-state issue, not a contract-model issue.

---

## Table of Contents

1. [Tenant Brand Config Model](#1-tenant-brand-config-model)
2. [Runtime Fallback Rules](#2-runtime-fallback-rules)
3. [Per-Tenant Preview Smoke Paths](#3-per-tenant-preview-smoke-paths)
4. [Contract Test Strategy (No Global Brand Leakage)](#4-contract-test-strategy-no-global-brand-leakage)
5. [SkillOurFuture Brand Migration Guide](#5-skillourfuture-brand-migration-guide)
6. [Governance Policy](#6-governance-policy)
7. [Quick Reference](#7-quick-reference)

---

## 1. Tenant Brand Config Model

### Storage

Brand profiles are stored in `TenantConfig.branding_config` (Django JSONField, default `{}`). The canonical schema is at:

```
infrastructure/tutor/plugins/multi-tenancy/brand-config-schema.json
```

Schema version: `1.0`

### Top-Level Fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `tenant_id` | string | Yes | URL-safe slug matching `TenantConfig.slug` |
| `display_name` | string | Yes | Human-readable name for page titles and footers |
| `logos` | object | No | Logo asset URLs (primary, white, favicon, footer) |
| `palette` | object | No | Hex colour tokens (primary, secondary, accent, background, text) |
| `typography` | object | No | Font family, heading font, font source URL |
| `footer` | object | No | Footer variant, copyright holder, WhatsApp, legal/social links |
| `legal_doc_urls` | object | No | Terms, Privacy, Cookie Policy URLs |
| `fallback_tenant_id` | string | No | Slug to inherit missing fields from (default: `mereka`) |
| `_meta` | object | No | Audit metadata (approved_by, approved_at, source_pr) |

### Logo Fields

```json
"logos": {
  "primary":  "https://<domain>/theming/asset/mereka/images/logo-horizontal.png",
  "white":    "https://<domain>/theming/asset/mereka/images/logo-horizontal-white.png",
  "favicon":  "https://<domain>/theming/asset/mereka/images/favicon.ico",
  "footer":   "https://<domain>/theming/asset/mereka/images/logo-footer.png"
}
```

All values must be absolute `https://` URLs. The LMS serves theme assets under `/theming/asset/mereka/`.

### Palette (CSS Token Mapping)

Each palette key maps directly to a CSS custom property injected by the plugin:

| Config key | CSS variable | Used by |
|------------|--------------|---------|
| `palette.primary` | `--mereka-color-primary` | Buttons, links, active states |
| `palette.secondary` | `--mereka-color-secondary` | Hover states, accents |
| `palette.accent` | `--mereka-color-accent` | CTA highlights |
| `palette.background` | `--mereka-color-background` | Page background |
| `palette.text` | `--mereka-color-text` | Body text (must pass WCAG AA contrast) |

All values must be 6-digit hex: `^#[0-9a-fA-F]{6}$`.

### Typography Fields

```json
"typography": {
  "font_family":    "\"Nunito\", sans-serif",
  "heading_font":   "\"Nunito\", sans-serif",
  "font_source_url": "https://fonts.googleapis.com/css2?family=Nunito:wght@400;600;700&display=swap"
}
```

`font_source_url` is loaded via a `<link>` tag injected into the MFE head. Only `https://` sources are permitted (CSP compliance).

### Footer Fields

```json
"footer": {
  "variant": "mereka-v2",
  "copyright_holder": "Mereka (M) Sdn. Bhd.",
  "whatsapp": "+60123456789",
  "legal_links": [
    { "label": "Terms of Use", "url": "https://academyv2.mereka.io/terms" },
    { "label": "Privacy Policy", "url": "https://academyv2.mereka.io/privacy" }
  ],
  "social_links": [
    { "platform": "linkedin", "url": "https://linkedin.com/company/mereka-my" }
  ]
}
```

`variant` controls which branch of `MerekaFooter` is rendered. Valid values: `mereka-v2`, `bijibiji`, `skillourfuture`, `custom`.

### Legal Doc URLs

```json
"legal_doc_urls": {
  "terms":   "https://<domain>/terms",
  "privacy": "https://<domain>/privacy",
  "cookies": "https://<domain>/cookies"
}
```

`cookies` is optional. If omitted, the Privacy Policy page is assumed to cover cookies.

---

## 2. Runtime Fallback Rules

### Fallback Hierarchy

```
Tenant branding_config
        ↓  (field missing or empty)
fallback_tenant_id config  (if set)
        ↓  (still missing)
Platform defaults  (TenantConfig.slug == 'mereka')
        ↓  (platform defaults missing)
Open edX upstream defaults
```

### Field-Level Rules

| Condition | Behaviour |
|-----------|-----------|
| `branding_config == {}` (empty dict) | All fields inherit from platform defaults (`mereka` tenant). No error raised. |
| `logos.primary` missing | Falls back to `https://academyv2.mereka.io/theming/asset/mereka/images/logo-horizontal.png` |
| `palette.*` missing | Falls back to Mereka design token values from `assets/branding/tokens.css` |
| `footer.variant` missing | Defaults to `mereka-v2` |
| `footer.copyright_holder` missing | Defaults to `"Mereka (M) Sdn. Bhd."` |
| `display_name` missing | Falls back to `SiteConfiguration.SITE_NAME` or platform default `"Mereka Academy"` |
| `legal_doc_urls.*` missing | No legal links rendered in footer (no broken links) |
| `typography.font_source_url` missing | System font stack used; no external font loaded |

### Validation at Provisioning

When a brand profile is loaded via `provision_tenant` management command or `scripts/tenants/provision-tenant.sh`, the profile is validated against the JSON Schema before being saved. Invalid profiles are rejected with a structured error:

```
TenantBrandConfigError: Field 'palette.primary' value '#xyz' does not match pattern '^#[0-9a-fA-F]{6}$'
```

Validation checks:
- `tenant_id` pattern: `^[a-z0-9-]{2,63}$`
- All URL fields: must start with `https://`
- Hex colours: must be 6-digit hex
- `footer.variant`: must be one of the allowed enum values
- `footer.whatsapp`: must match E.164 format `^\+[0-9]{7,15}$`

### Runtime Invalid Config Handling

If a saved `branding_config` is structurally invalid at runtime (e.g. corrupted JSON or schema violation introduced by direct DB edit), `TenantResolutionMiddleware` logs a warning and falls back to platform defaults. The LMS does not crash; the fallback is logged at `WARNING` level:

```
WARNING mereka_tenancy.middleware: branding_config for tenant 'foo' failed validation, using platform defaults
```

---

## 3. Per-Tenant Preview Smoke Paths

These are the branded screen routes that must be visually verified after any brand profile update.

### Tenant Domains

| Tenant | Primary Domain | Studio Domain | MFE Domain |
|--------|---------------|---------------|------------|
| mereka | `academyv2.mereka.io` | `studio.academyv2.mereka.io` | `apps.academyv2.mereka.io` |
| bijibiji | `academy.biji-biji.com` | `studio.academy.biji-biji.com` | `apps.academy.biji-biji.com` |
| skillourfuture | `skillourfuture.academy.mereka.io` | `studio.academyv2.mereka.io` (shared) | `apps.skillourfuture.academy.mereka.io` |

### Required Smoke Paths Per Tenant

For each tenant domain, verify these routes render with the correct brand identity:

| Screen | Path | Brand Markers to Check |
|--------|------|------------------------|
| LMS Home | `/` | Logo (header), page title, favicon |
| Authn / Login | `/login` (redirects to MFE) or `apps.<domain>/authn/login` | Logo, background colour, font |
| Learner Dashboard | `apps.<domain>/learner-dashboard/` | Header logo, footer variant, palette |
| Course Player | `apps.<domain>/learning/course/<id>/` | Logo, footer |
| Studio Home | `studio.<domain>/home` | Logo, page title |
| Forum Shell | `/courses/<id>/discussion/forum/` (auth required) | Footer, brand colours |

### Smoke Command

```bash
# Syntax check + offline doc verification
./scripts/qa/verify-multitenant-brand-platform.sh

# Runtime HTTP probes (requires live cluster)
BRAND_LIVE=1 ./scripts/qa/verify-multitenant-brand-platform.sh

# Full branding gate (runs all branding sub-scripts)
RUN_LIVE_GATE=0 BRANDING_LEVEL=deep ./scripts/branding/run-branding-gates.sh prod
```

### Screenshot Capture

After any brand profile update, capture screenshots for each tenant using the automated script:

```bash
# Captures LMS, authn, dashboard, and Studio for all tenant domains
./scripts/qa/capture-branding-screenshots.sh --all-tenants
```

Screenshots are saved to `var/branding-screenshots/<tenant>/<timestamp>/`. They form the visual evidence artefact for the release checklist.

---

## 4. Contract Test Strategy (No Global Brand Leakage)

### What "Global Brand Leakage" Means

A global brand leak occurs when one tenant's brand identity (logo URL, colour token, display name, copyright text) is rendered on a different tenant's domain. This breaks the isolation contract.

### Detection Points

| Layer | Leakage Type | Detection Method |
|-------|-------------|-----------------|
| MFE config (`/api/mfe_config/v1`) | Wrong `LOGO_URL`, `SITE_NAME`, or `LMS_BASE_URL` for the requesting domain | `verify-tenant-branding-runtime.sh` |
| SITE_VARIANTS map | Hard-coded domain strings outside the `SITE_VARIANTS` block in `mereka_lms.py` | `verify-footer-variant-matrix.sh` (AC-FTVAR-005 DRY check) |
| CSS token injection | Wrong `--mereka-color-*` values for tenant palette | Design token validation in CI |
| Footer plugin slot | Copyright text, WhatsApp number, social links from wrong tenant | `verify-footer-variant-matrix.sh` (AC-FTVAR-002) |
| Django `SiteConfiguration` | `SITE_NAME` set globally instead of per-site | `verify-multisite-config.sh` |

### Contract Test Files

| Test Script | AC Coverage | Runs in CI |
|-------------|-------------|------------|
| `scripts/qa/verify-multitenant-brand-platform.sh` | AC-MB-001..006 | Yes (always) |
| `scripts/qa/verify-footer-variant-matrix.sh` | AC-FTVAR-001..005 | Yes (always) |
| `scripts/qa/verify-tenant-branding-runtime.sh` | AC-TBR-101..103 | Offline-safe (runtime probes skipped) |
| `scripts/qa/verify-tenant-branding-contract.sh` | AC-TBQA-001..005 | Yes (always) |
| `scripts/qa/verify-tenant-isolation-evidence.sh` | AC-UI-201..205 | On PR with `tenant|branding` in title |

### Hard-Coded Brand Value Prohibition

The following patterns are **forbidden** outside their designated config maps:

```bash
# Forbidden in MFE plugin source (use SITE_VARIANTS lookup instead):
if (hostname === 'academyv2.mereka.io') { brand = 'Mereka'; }

# Forbidden in settings files (use SiteConfiguration instead):
SITE_NAME = "Mereka Academy"  # Only in platform defaults, not per-tenant code
```

Run `verify-no-dom-overrides.sh` and `verify-footer-variant-matrix.sh` to enforce this.

---

## 5. SkillOurFuture Brand Migration Guide

See also: `docs/ops/runbooks/migrations/SKILLOURFUTURE_BRAND_MIGRATION.md` (full step-by-step guide with checklist).

### Summary

SkillOurFuture (`skillourfuture`) is already represented as a tenant domain in `SITE_VARIANTS`. The migration task is to promote it from a minimal variant to a fully-specified brand profile in `TenantConfig.branding_config`.

**Current state**: `branding_config = {}` (uses platform defaults)
**Target state**: Full brand profile with custom palette, logos, footer variant, and legal URLs.

### Migration Steps (Summary)

1. Collect brand assets from the SkillOurFuture design brief.
2. Upload assets to `assets/branding/tenants/skillourfuture/`.
3. Create `scripts/tenants/brand-pack-template.json` copy for `skillourfuture` using `brand-config-schema.json`.
4. Validate: `scripts/tenants/validate-tenant-brand-pack.sh skillourfuture`.
5. Open a PR with `tenant | branding | skillourfuture` in the title to trigger all contract gates.
6. After PR approval, apply: `scripts/tenants/provision-tenant.sh --update-brand skillourfuture`.
7. Capture screenshots: `scripts/qa/capture-branding-screenshots.sh --tenant skillourfuture`.
8. Confirm smoke paths per Section 3.

---

## 6. Governance Policy

### Who Owns Tenant Brand Policy

| Role | Responsibility |
|------|----------------|
| **Platform Engineering** (GitHub team `@Biji-Biji-Initiative/platform`) | Schema changes, CI gate changes, token system updates |
| **Academic Ops** (GitHub team `@Biji-Biji-Initiative/academic-ops`) | Per-tenant display name, legal URLs, copyright text |
| **Brand / Design** (requester) | Logo assets, palette, typography — must be delivered as a brand pack |

### Approval Flow for Brand Profile Changes

```
1. Brand / Academic Ops prepares brand pack JSON
      ↓
2. validate-tenant-brand-pack.sh passes locally
      ↓
3. Open PR with at least one reviewer from Platform Engineering
      ↓
4. CI runs all contract gates (must all pass)
      ↓
5. Platform Eng approves + merges
      ↓
6. provision-tenant.sh --update-brand <slug> applied to production
      ↓
7. Screenshots captured, stored as release evidence
```

### Prohibited Changes Without PR Review

- Changing `palette.primary` or `palette.secondary` (contrast compliance impact)
- Changing `footer.variant` (changes rendered footer component)
- Changing `legal_doc_urls.*` (legal compliance)
- Any schema change to `brand-config-schema.json`

### Audit Trail

All brand profile changes must include a `_meta` block with `approved_by`, `approved_at`, and `source_pr`. The provisioning script enforces this at apply time:

```bash
# Will reject if _meta.approved_by is missing
scripts/tenants/provision-tenant.sh --update-brand skillourfuture
```

Changes are logged in `reports/2026/audits/CONFIG_REVIEW_2026-02-03.md` under a "Tenant Brand Profile" section.

### Quarterly Review

Platform Engineering reviews all active tenant brand profiles on the first working Monday of each quarter:
- Confirm `_meta.approved_at` is within 12 months.
- Verify all logo URLs still resolve with HTTP 200.
- Check contrast compliance has not regressed.
- Remove inactive tenant profiles.

---

## 7. Quick Reference

```bash
# Validate brand config schema
scripts/tenants/validate-tenant-brand-pack.sh <tenant-slug>

# Full offline contract verification (all 6 ACs)
./scripts/qa/verify-multitenant-brand-platform.sh

# Runtime smoke (live cluster)
BRAND_LIVE=1 ./scripts/qa/verify-multitenant-brand-platform.sh

# Provision brand profile update
scripts/tenants/provision-tenant.sh --update-brand <tenant-slug>

# Capture brand screenshots
scripts/qa/capture-branding-screenshots.sh --tenant <tenant-slug>

# Full branding CI gate
RUN_LIVE_GATE=0 BRANDING_LEVEL=deep ./scripts/branding/run-branding-gates.sh prod
```

### Related Documents

| Document | Purpose |
|----------|---------|
| `docs/reference/operations/TENANT_BRANDING_SURFACE_MATRIX.md` | Per-domain branding surface registry |
| `docs/reference/operations/FOOTER_VARIANT_MATRIX.md` | Footer variant per domain |
| `docs/evidence/operations/TENANT_ISOLATION_EVIDENCE.md` | Cross-tenant isolation controls |
| `docs/policies/operations/MULTISITE_GOVERNANCE.md` | Site + domain governance checklist |
| `docs/ops/runbooks/migrations/SKILLOURFUTURE_BRAND_MIGRATION.md` | SkillOurFuture brand migration guide |
| `infrastructure/tutor/plugins/multi-tenancy/brand-config-schema.json` | JSON Schema for brand profiles |
| `specs/multi-tenancy-architecture_spec.md` | Multi-tenancy architecture specification |
