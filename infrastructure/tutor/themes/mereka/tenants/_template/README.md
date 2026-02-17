# Tenant Brand Pack Template

This directory provides a template structure for creating new tenant brand packs.

## Quick Start

```bash
# Copy template to new tenant
cp -r infrastructure/tutor/themes/mereka/tenants/_template \
      infrastructure/tutor/themes/mereka/tenants/new-tenant

# Edit branding.json with tenant-specific values
vim infrastructure/tutor/themes/mereka/tenants/new-tenant/branding.json

# Add tenant logo assets
cp new-tenant-logo.png infrastructure/tutor/themes/mereka/tenants/new-tenant/logos/logo.png
cp new-tenant-favicon.ico infrastructure/tutor/themes/mereka/tenants/new-tenant/favicons/favicon.ico

# Validate brand pack
./scripts/tenants/validate-tenant-brand-pack.sh --slug new-tenant
```

## Directory Structure

```
_template/
├── branding.json       # Brand pack configuration (symlinked to scripts/tenants/brand-pack-template.json)
├── logos/              # Logo assets directory
├── favicons/           # Favicon assets directory
└── css/                # Custom CSS overrides (optional)
```

## Required Assets

1. **Primary Logo** (`logos/logo.png` or `logos/logo.svg`)
   - Format: PNG or SVG
   - Max dimensions: 400×100px
   - Max file size: 500KB
   - Transparent background recommended

2. **Favicon** (`favicons/favicon.ico`)
   - Format: ICO or PNG
   - Dimensions: 32×32px or 64×64px
   - Max file size: 500KB

## Optional Assets

1. **Square Logo** (`logos/logo-square.png` or `logos/logo-square.svg`)
   - Format: PNG or SVG
   - Dimensions: 200×200px
   - Max file size: 500KB

2. **White Logo** (`logos/logo-white.png` or `logos/logo-white.svg`)
   - Format: PNG or SVG
   - Max dimensions: 400×100px
   - Max file size: 500KB
   - For use on dark backgrounds

3. **Custom CSS** (`css/custom.css`)
   - Tenant-specific CSS overrides
   - Use CSS custom properties (`--mereka-color-*`) from design tokens

## branding.json Schema

See `specs/brand-pack-schema.json` for the complete JSON Schema.

**Required fields**:
- `slug`: Tenant identifier (lowercase, alphanumeric + hyphens, 2-63 chars)
- `name`: Human-readable tenant name
- `domain`: Primary FQDN for the tenant
- `colors.primary`: Primary brand color (hex format)
- `logos.logo_url`: Path to primary logo
- `logos.favicon_url`: Path to favicon
- `footer.contact_email`: Support email address

**Optional fields**:
- `colors.secondary`: Secondary brand color
- `colors.accent`: Accent color
- `colors.text_on_primary`: Text color for primary background
- `logos.logo_square_url`: Path to square logo
- `logos.logo_white_url`: Path to white logo
- `footer.text`: Custom footer text
- `footer.links`: Footer navigation links (max 10)

## Validation

```bash
# Validate all tenants
./scripts/tenants/validate-tenant-brand-pack.sh

# Validate specific tenant
./scripts/tenants/validate-tenant-brand-pack.sh --slug new-tenant

# Strict mode (warnings treated as failures)
./scripts/tenants/validate-tenant-brand-pack.sh --strict
```

## Documentation

- **Schema Docs**: `docs/branding/TENANT_BRAND_PACK_SCHEMA.md`
- **Contract**: `docs/branding/TENANT_BRANDING_CONTRACT.md`
- **Provisioning**: `docs/operations/TENANT_PROVISIONING.md`
- **JSON Schema**: `specs/brand-pack-schema.json`

## Example

See `scripts/tenants/brand-pack-template.json` for a complete example with all fields.
