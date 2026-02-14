# Per-Tenant Branding Assets

This directory contains per-tenant branding assets for multi-tenant deployments.

## Directory Structure

```
tenants/
├── {tenant_slug}/
│   ├── logos/
│   │   ├── logo.png
│   │   ├── logo-white.png
│   │   └── logo-horizontal.png
│   ├── favicons/
│   │   ├── favicon.ico
│   │   └── favicon.svg
│   └── styles/
│       └── overrides.css
```

## How Tenant Branding Works

1. **Static assets** are stored in this directory, organized by tenant slug
2. **SiteConfiguration** stores JSON overlays with URLs pointing to these assets
3. **MFE** reads SiteConfiguration at runtime for tenant-specific logos and colors
4. **Tenant branding changes do NOT require image rebuild** — assets are deployed via `collectstatic`

## Adding a New Tenant

1. Create directory: `tenants/{slug}/logos/` and `tenants/{slug}/favicons/`
2. Add logo and favicon files
3. Create a `TenantSiteMapping` record in Django admin
4. Create a `TenantSiteConfiguration` with `mfe_config` pointing to the assets
5. Run `collectstatic` to deploy assets

## Default Branding

If no tenant-specific branding is configured, the default Mereka Academy branding
from `infrastructure/tutor/themes/mereka/` is used.
