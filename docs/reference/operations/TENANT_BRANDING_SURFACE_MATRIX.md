# Tenant Branding Surface Matrix

_Last updated: 2026-03-24_

> Source of truth for per-domain branding verification. Consumed by `scripts/qa/verify-tenant-branding-runtime.sh` and cross-checked against `infrastructure/tutor/plugins/_mereka_lms/mfe_runtime_definitions.js`.

## Domain Registry

| Domain | Tenant Slug | Expected `SITE_NAME` | Standard MFE Theme | Standard MFE Logo | Footer Variant | Status |
|--------|-------------|----------------------|--------------------|-------------------|----------------|--------|
| academyv2.mereka.io | mereka | Mereka Academy | `mereka-brand.min.css` | `/theme/logo-horizontal.svg` | `mereka-v2` | Active |
| academy.biji-biji.com | biji-biji | Biji-Biji Academy | `biji-biji-brand.min.css` | `/theme/biji-biji/logo-horizontal.svg` | `biji-biji` | Active |
| skillourfuture.academy.mereka.io | skillourfuture | Skill Our Future Academy | `sof-brand.min.css` | `/theme/skillourfuture/logo-horizontal.svg` | `skillourfuture` | Active |

The runtime model is now tenant-specific. Shared-shell fallback still exists for unknown hosts, but the three production tenant domains above are expected to resolve to explicit entries in `MEREKA_SITE_VARIANTS`.

## MFE Config Contract (`/api/mfe_config/v1`)

Each production tenant hostname MUST expose a tenant-specific MFE config:

| Key | Assertion | Example |
|-----|-----------|---------|
| `SITE_NAME` | Exact tenant-facing brand name, never `Open edX` | `Skill Our Future Academy` |
| `LOGO_URL` | Non-empty, tenant-branded asset URL, never default Open edX assets | `/theme/skillourfuture/logo-horizontal.svg` or `/brands/skillourfuture/logo.svg` |
| `LOGO_WHITE_URL` | Non-empty white/logo-on-dark variant | `/theme/skillourfuture/logo-horizontal-white.svg` or `/brands/skillourfuture/logo-white.svg` |
| `FAVICON_URL` | Non-empty favicon URL | `/theme/skillourfuture/favicon.ico` or `/brands/skillourfuture/favicon.ico` |
| `LMS_BASE_URL` | Matches the tenant hostname exactly | `https://skillourfuture.academy.mereka.io` |

The verifier only enforces tenant specificity and hostname alignment. It does not assume one asset root forever, because standard MFEs serve branding from `/theme/...` while enterprise MFEs use `/brands/<tenant>/...` in the shared image.

## Theme Bundle Contract

Standard MFEs load these brand bundles from `/theme/`:

| Tenant | Core Brand CSS | Light Brand CSS |
|--------|----------------|-----------------|
| Mereka | `mereka-brand.min.css` | `mereka-brand-light.min.css` |
| Biji-Biji | `biji-biji-brand.min.css` | `biji-biji-brand-light.min.css` |
| Skill Our Future | `sof-brand.min.css` | `sof-brand-light.min.css` |

Enterprise MFEs mirror the same tenant branding via per-tenant `env.config.js` files and `/brands/<tenant>/...` asset directories.

## Footer Variant Contract

| Domain | Brand Label | Copyright Holder | Support Email |
|--------|-------------|------------------|---------------|
| academyv2.mereka.io | Mereka Academy | MEREKA | `support@mereka.io` |
| academy.biji-biji.com | Biji-Biji Academy | Biji-Biji Initiative | `techadmin@biji-biji.com` |
| skillourfuture.academy.mereka.io | Skill Our Future Academy | MEREKA | `support@mereka.io` |

## Verification Commands

```bash
# Runtime tenant branding contract
bash scripts/qa/verify-tenant-branding-runtime.sh --env prod

# Footer / hostname variant map contract
bash scripts/qa/verify-footer-variant-matrix.sh

# Canonical brand assets + generated theme bundles
bash scripts/qa/verify-brand-asset-drift.sh
```

## Current Risks

| Risk | Why it matters | Severity | Next proof |
|------|----------------|----------|------------|
| `Build Tutor Images` still not green on current head | Standard MFE theme/logo assets are source-correct but not yet fully delivery-proven | High | Green relevant `Build Tutor Images` run |
| `Build Enterprise MFEs` still not green on current head | `/brands/<tenant>/...` delivery path is source-correct but not yet fully delivery-proven | High | Green relevant `Build Enterprise MFEs` run |
| Public branding probes can fail independently of DEV runtime | Public/prod proof is a separate lane from source/DEV proof | Medium | Keep DEV and public branding checks distinct |

## Changelog

| Date | Author | Change |
|------|--------|--------|
| 2026-03-24 | Codex | Updated matrix for tenant-specific SITE_NAME, theme bundle, and logo contracts |
| 2026-02-18 | WhiteCliff | Initial matrix created from live production data |
