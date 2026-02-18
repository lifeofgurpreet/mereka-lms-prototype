# Tenant Branding Surface Matrix

> Source of truth for per-domain branding verification. Consumed by `scripts/qa/verify-tenant-branding-runtime.sh`.

## Domain Registry

| Domain | Tenant Slug | Expected SITE_NAME | Logo Theme | Footer Variant | Status |
|--------|-------------|-------------------|------------|----------------|--------|
| academyv2.mereka.io | mereka | Mereka Academy | mereka | mereka-v2 | Active |
| academy.biji-biji.com | bijibiji | Mereka Academy | mereka | mereka-v2 | Active |
| skillourfuture.academy.mereka.io | skillourfuture | Mereka Academy | mereka | mereka-v2 | Active |

> **Note**: All 3 tenants currently share the same SITE_NAME ("Mereka Academy") and branding theme ("mereka"). Per-tenant SITE_NAME differentiation and custom brand colors are Phase 2 scope (`branding_config` population).

## MFE Config Contract (`/api/mfe_config/v1`)

Each domain MUST return these keys with domain-specific values:

| Key | Assertion | Example (academyv2.mereka.io) |
|-----|-----------|-------------------------------|
| `SITE_NAME` | Non-empty, not "Open edX" | "Mereka Academy" |
| `LOGO_URL` | Contains domain, not default openedx logo | `https://academyv2.mereka.io/theming/asset/mereka/images/logo-horizontal.png` |
| `LOGO_WHITE_URL` | Contains domain | `https://academyv2.mereka.io/theming/asset/mereka/images/logo-horizontal-white.png` |
| `FAVICON_URL` | Contains domain | `https://academyv2.mereka.io/theming/asset/mereka/images/favicon.ico` |
| `LMS_BASE_URL` | Matches `https://{domain}` | `https://academyv2.mereka.io` |

## Brand Color Tokens (Phase 2)

When `branding_config` is populated per tenant, the MFE config should include CSS custom properties:

| Token | Purpose | Default |
|-------|---------|---------|
| `--mereka-color-primary` | Primary brand color | `#2d898b` |
| `--mereka-color-secondary` | Secondary brand color | `#295cad` |
| `--mereka-color-accent` | Accent color | `#f5a623` |

> **Current state**: `branding_config` is `{}` for all tenants. Brand color tokens are not yet injected. This is expected and NOT a failure condition.

## Footer Variant Contract

| Domain | Footer Template | Corporate Nav | Social Links |
|--------|----------------|---------------|--------------|
| academyv2.mereka.io | mereka-v2 | Yes | Yes |
| academy.biji-biji.com | mereka-v2 | Yes | Yes |
| skillourfuture.academy.mereka.io | mereka-v2 | Yes | Yes |

## Verification Commands

```bash
# Full runtime check (all domains)
./scripts/qa/verify-tenant-branding-runtime.sh --env prod

# Single domain check
curl -s https://academyv2.mereka.io/api/mfe_config/v1 | python3 -m json.tool

# Governance gate (includes branding)
./scripts/qa/run-multisite-governance-gates.sh --env prod
```

## Known Gaps (Next Owner: Phase 2 / 2hvr successor)

| Gap | Impact | Severity | Next Action |
|-----|--------|----------|-------------|
| SITE_NAME identical across all 3 domains | No per-tenant name differentiation in MFE header | Low | Populate `branding_config.site_name` per TenantConfig |
| Brand color tokens missing | Default Mereka theme used everywhere | Low | Populate `branding_config.primary_color` etc. per TenantConfig |
| Logo assets identical across domains | No visual brand differentiation | Low | Upload per-tenant logos, update theme asset paths |

## Changelog

| Date | Author | Change |
|------|--------|--------|
| 2026-02-18 | WhiteCliff | Initial matrix created from live production data |
