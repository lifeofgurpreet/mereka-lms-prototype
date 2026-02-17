# Tenant Brand Pack Schema

_Audience: Platform Engineering + Design + Tenant Operations • Last updated: 2026-02-17_

**Purpose**: Document the tenant brand pack schema, asset requirements, naming conventions, and fallback rules for multi-tenant branding.

**Machine-Checkable Spec**: `specs/brand-pack-schema.json`
**Template**: `scripts/tenants/brand-pack-template.json`
**Contract**: `docs/branding/TENANT_BRANDING_CONTRACT.md`
**Validation**: `scripts/tenants/validate-tenant-brand-pack.sh`

---

## Table of Contents

1. [Overview](#overview)
2. [Schema Structure](#schema-structure)
3. [Required Fields](#required-fields)
4. [Optional Fields](#optional-fields)
5. [Asset Naming Conventions](#asset-naming-conventions)
6. [Asset Requirements](#asset-requirements)
7. [Fallback Rules](#fallback-rules)
8. [Validation](#validation)
9. [Examples](#examples)
10. [Troubleshooting](#troubleshooting)

---

## Overview

The **Tenant Brand Pack Schema** defines the structure and validation rules for tenant branding configuration files (`branding.json`). Each tenant provides a brand pack containing:

- **Metadata**: Slug, name, domain
- **Colors**: Primary, secondary, accent, text-on-primary
- **Logos**: Horizontal logo, square logo, white logo, favicon
- **Footer**: Text, links, contact email

The schema is defined in `specs/brand-pack-schema.json` and enforced by:
- **JSON Schema validation** (draft 2020-12)
- **Brand pack validator** (`scripts/tenants/validate-tenant-brand-pack.sh`)
- **CI gates** (GitHub Actions)

**Key Principles**:
- **Machine-checkable**: Schema enforced via JSON Schema validator
- **Strict validation**: Required fields must be present, optional fields have defaults
- **Asset isolation**: Each tenant's assets are stored in isolated directories
- **Zero-downtime updates**: Brand pack changes apply without image rebuild

---

## Schema Structure

```json
{
  "slug": "tenant-slug",
  "name": "Tenant Display Name",
  "domain": "tenant.academyv2.mereka.io",
  "colors": {
    "primary": "#1a73e8",
    "secondary": "#4285f4",
    "accent": "#C70039",
    "text_on_primary": "#FFFFFF"
  },
  "logos": {
    "logo_url": "/static/themes/mereka/tenants/tenant-slug/logos/logo.png",
    "logo_square_url": "/static/themes/mereka/tenants/tenant-slug/logos/logo-square.png",
    "logo_white_url": "/static/themes/mereka/tenants/tenant-slug/logos/logo-white.png",
    "favicon_url": "/static/themes/mereka/tenants/tenant-slug/favicons/favicon.ico"
  },
  "footer": {
    "text": "© 2026 Tenant Name. All rights reserved.",
    "links": [
      {
        "title": "Privacy Policy",
        "url": "https://tenant.com/privacy"
      }
    ],
    "contact_email": "support@tenant.com"
  }
}
```

---

## Required Fields

### Metadata

| Field | Type | Pattern | Description |
|-------|------|---------|-------------|
| **slug** | string | `^[a-z0-9-]+$` | Tenant identifier (2-63 chars, lowercase, alphanumeric + hyphens only) |
| **name** | string | - | Human-readable tenant name (1-200 chars) |
| **domain** | string | `^([a-z0-9-]+\.)+[a-z]{2,}$` | Primary fully-qualified domain name |

**Examples**:
```json
{
  "slug": "acme-corp",
  "name": "Acme Corporation",
  "domain": "acme.academyv2.mereka.io"
}
```

**Validation**:
- `slug` must match directory name (`infrastructure/tutor/themes/mereka/tenants/<slug>/`)
- `slug` cannot contain uppercase letters, spaces, or special characters
- `domain` must be valid FQDN (no IP addresses)

---

### Colors

| Field | Type | Pattern | Description |
|-------|------|---------|-------------|
| **primary** | string | `^#[0-9A-Fa-f]{6}$` | Primary brand color (buttons, links, headers) |

**Required**: `primary`
**Optional**: `secondary`, `accent`, `text_on_primary`

**Examples**:
```json
{
  "colors": {
    "primary": "#FF5733"
  }
}
```

**Fallback**:
- If `secondary` not provided → defaults to `#4285f4` (platform default)
- If `accent` not provided → defaults to primary color (darker shade)
- If `text_on_primary` not provided → defaults to `#FFFFFF` (white)

---

### Logos

| Field | Type | Description |
|-------|------|-------------|
| **logo_url** | string | Primary horizontal logo (PNG/SVG, max 400×100px, <500KB) |
| **favicon_url** | string | Favicon (ICO/PNG, 32×32px or 64×64px, <500KB) |

**Required**: `logo_url`, `favicon_url`
**Optional**: `logo_square_url`, `logo_white_url`

**Examples**:
```json
{
  "logos": {
    "logo_url": "/static/themes/mereka/tenants/acme-corp/logos/logo.png",
    "favicon_url": "/static/themes/mereka/tenants/acme-corp/favicons/favicon.ico"
  }
}
```

**Fallback**:
- If `logo_square_url` not provided → primary logo (cropped center)
- If `logo_white_url` not provided → primary logo (auto-inverted)

---

### Footer

| Field | Type | Pattern | Description |
|-------|------|---------|-------------|
| **contact_email** | string | `^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$` | Support/contact email address |

**Required**: `contact_email`
**Optional**: `text`, `links`

**Examples**:
```json
{
  "footer": {
    "contact_email": "support@acme.com"
  }
}
```

**Fallback**:
- If `text` not provided → `"© {year} {tenant_name}. All rights reserved."`
- If `links` not provided → empty array (no links)

---

## Optional Fields

### Colors

| Field | Type | Pattern | Description |
|-------|------|---------|-------------|
| **secondary** | string | `^#[0-9A-Fa-f]{6}$` | Secondary brand color (accents, highlights) |
| **accent** | string | `^#[0-9A-Fa-f]{6}$` | Accent color (callouts, special elements) |
| **text_on_primary** | string | `^#[0-9A-Fa-f]{6}$` | Text color for use on primary color background |

**Examples**:
```json
{
  "colors": {
    "primary": "#FF5733",
    "secondary": "#FFC300",
    "accent": "#C70039",
    "text_on_primary": "#FFFFFF"
  }
}
```

---

### Logos

| Field | Type | Description |
|-------|------|-------------|
| **logo_square_url** | string | Square logo (PNG/SVG, 200×200px, <500KB) for small spaces |
| **logo_white_url** | string | White logo (PNG/SVG, max 400×100px, <500KB) for dark backgrounds |

**Examples**:
```json
{
  "logos": {
    "logo_url": "/static/themes/mereka/tenants/acme-corp/logos/logo.png",
    "logo_square_url": "/static/themes/mereka/tenants/acme-corp/logos/logo-square.png",
    "logo_white_url": "/static/themes/mereka/tenants/acme-corp/logos/logo-white.png",
    "favicon_url": "/static/themes/mereka/tenants/acme-corp/favicons/favicon.ico"
  }
}
```

---

### Footer

| Field | Type | Max Length | Description |
|-------|------|------------|-------------|
| **text** | string | 500 chars | Footer copyright/disclaimer text (plaintext only, no HTML) |
| **links** | array | 10 links | Footer navigation links (HTTPS only) |

**Link Object Structure**:
```json
{
  "title": "Link Text",
  "url": "https://example.com/page"
}
```

**Examples**:
```json
{
  "footer": {
    "text": "© 2026 Acme Corp. All rights reserved.",
    "links": [
      {
        "title": "Privacy Policy",
        "url": "https://acme.com/privacy"
      },
      {
        "title": "Terms of Service",
        "url": "https://acme.com/terms"
      }
    ],
    "contact_email": "support@acme.com"
  }
}
```

**Validation**:
- `text` must not contain HTML tags (plaintext only)
- `links` array max 10 items
- Each link `url` must use HTTPS (http:// rejected)
- Each link `title` max 100 characters

---

## Asset Naming Conventions

### Directory Structure

```
infrastructure/tutor/themes/mereka/tenants/<slug>/
├── branding.json              # Brand pack configuration (validated by schema)
├── logos/
│   ├── logo.png               # Primary horizontal logo
│   ├── logo-square.png        # Square logo (optional)
│   ├── logo-white.png         # White logo for dark backgrounds (optional)
│   └── logo.svg               # SVG version (optional)
├── favicons/
│   ├── favicon.ico            # 32×32px ICO
│   └── favicon-64.png         # 64×64px PNG (optional)
└── css/
    └── custom.css             # Tenant-specific CSS overrides (optional)
```

### File Naming Rules

| Asset Type | Filename Pattern | Required |
|------------|------------------|----------|
| Primary logo | `logo.png` or `logo.svg` | ✅ REQUIRED |
| Square logo | `logo-square.png` or `logo-square.svg` | ⚪ OPTIONAL |
| White logo | `logo-white.png` or `logo-white.svg` | ⚪ OPTIONAL |
| Favicon | `favicon.ico` | ✅ REQUIRED |
| Favicon PNG | `favicon-64.png` | ⚪ OPTIONAL |

**Path Convention**:
```json
{
  "logos": {
    "logo_url": "/static/themes/mereka/tenants/<slug>/logos/logo.png",
    "favicon_url": "/static/themes/mereka/tenants/<slug>/favicons/favicon.ico"
  }
}
```

**Important**: Paths in `branding.json` must match actual file locations on disk.

---

## Asset Requirements

### Image Formats

| Asset | Accepted Formats | Recommended |
|-------|------------------|-------------|
| Primary logo | PNG, SVG | SVG (scalable, smaller file size) |
| Square logo | PNG, SVG | PNG (predictable rendering) |
| White logo | PNG, SVG | PNG with transparency |
| Favicon | ICO, PNG | ICO (universal support) |

### Dimensions

| Asset | Max Dimensions | Notes |
|-------|----------------|-------|
| Primary logo | 400×100px | Horizontal layout, transparent background recommended |
| Square logo | 200×200px | Square aspect ratio, centered content |
| White logo | 400×100px | Same as primary, white color on transparent background |
| Favicon | 32×32px or 64×64px | ICO format supports multiple sizes |

### File Size Limits

All logo assets must be **<500KB** per file.

**Validation**:
```bash
# Check file size
ls -lh infrastructure/tutor/themes/mereka/tenants/acme-corp/logos/logo.png
# Should be <500KB
```

**Optimization**:
- Use `pngquant` for PNG compression: `pngquant --quality 80-100 logo.png`
- Use `svgo` for SVG optimization: `svgo logo.svg`

### Color Modes

- **Primary logo**: Full color or monochrome, works on light backgrounds
- **Square logo**: Full color or monochrome, works on light backgrounds
- **White logo**: White/light color, transparent background, works on dark backgrounds
- **Favicon**: High contrast, recognizable at small sizes

---

## Fallback Rules

### Logo Fallback Chain

```
logo_url:
  1. TenantSiteConfiguration.mfe_config['LOGO_URL']
  2. TenantSiteConfiguration.values['logo_url']
  3. /static/themes/mereka/tenants/<slug>/logos/logo.png
  4. /static/images/logo.png (platform default)

logo_square_url:
  1. TenantSiteConfiguration.mfe_config['LOGO_TRADEMARK_URL']
  2. TenantSiteConfiguration.values['logo_square_url']
  3. /static/themes/mereka/tenants/<slug>/logos/logo-square.png
  4. logo_url (cropped center)

logo_white_url:
  1. TenantSiteConfiguration.mfe_config['LOGO_WHITE_URL']
  2. TenantSiteConfiguration.values['logo_white_url']
  3. /static/themes/mereka/tenants/<slug>/logos/logo-white.png
  4. logo_url (auto-inverted)

favicon_url:
  1. TenantSiteConfiguration.values['favicon_url']
  2. /static/themes/mereka/tenants/<slug>/favicons/favicon.ico
  3. /static/images/favicon.ico (platform default)
```

### Color Fallback Chain

```
primary:
  1. TenantSiteConfiguration.values['primary_color']
  2. branding.json colors.primary
  3. #1a73e8 (platform default)

secondary:
  1. TenantSiteConfiguration.values['secondary_color']
  2. branding.json colors.secondary
  3. #4285f4 (platform default)

accent:
  1. TenantSiteConfiguration.values['accent_color']
  2. branding.json colors.accent
  3. primary color (darker shade)

text_on_primary:
  1. TenantSiteConfiguration.values['text_on_primary']
  2. branding.json colors.text_on_primary
  3. #FFFFFF (white)
```

### Footer Fallback Chain

```
footer.text:
  1. TenantSiteConfiguration.values['footer_text']
  2. branding.json footer.text
  3. "© {year} {tenant_name}. All rights reserved."

footer.links:
  1. TenantSiteConfiguration.values['footer_links']
  2. branding.json footer.links
  3. [] (empty array)

footer.contact_email:
  1. TenantSiteConfiguration.values['contact_email']
  2. branding.json footer.contact_email
  3. platform support email
```

**Implementation**: See `infrastructure/tutor/custom-apps/openedx_tenant_cache/branding.py`

---

## Validation

### JSON Schema Validation

The schema is defined in `specs/brand-pack-schema.json` (JSON Schema draft 2020-12).

**Validate with `jq`**:
```bash
# Check if jq and ajv-cli are installed
which jq ajv

# Validate branding.json against schema
ajv validate -s specs/brand-pack-schema.json -d infrastructure/tutor/themes/mereka/tenants/acme-corp/branding.json
```

### Automated Validation

**Brand Pack Validator**:
```bash
# Validate all tenants
./scripts/tenants/validate-tenant-brand-pack.sh

# Validate specific tenant
./scripts/tenants/validate-tenant-brand-pack.sh --slug acme-corp

# Strict mode (warnings treated as failures)
./scripts/tenants/validate-tenant-brand-pack.sh --strict
```

**What it checks**:
- ✅ `branding.json` is valid JSON
- ✅ All required fields present
- ✅ `slug` matches directory name
- ✅ `slug` matches pattern (`^[a-z0-9-]+$`, 2-63 chars)
- ✅ All colors are valid hex (`^#[0-9A-Fa-f]{6}$`)
- ✅ Logo files exist on disk
- ✅ Logo files are <500KB
- ✅ Footer links use HTTPS
- ✅ Footer text is plaintext (no HTML)
- ✅ Footer text is <500 chars
- ✅ Contact email is valid email format
- ✅ Domain is valid FQDN

### CI Validation

Brand pack schema validation runs automatically on every commit:

```yaml
# .github/workflows/ci.yml
jobs:
  brand-pack-schema:
    name: Brand Pack Schema Validation
    runs-on: ubuntu-latest
    steps:
      - name: Verify brand pack schema compliance
        run: ./scripts/qa/verify-brand-pack-schema.sh
```

**Validation also runs in**:
- `monitoring-guardrails` job (script syntax check)

---

## Examples

### Minimal Brand Pack (Required Fields Only)

```json
{
  "slug": "minimal-tenant",
  "name": "Minimal Tenant",
  "domain": "minimal.academyv2.mereka.io",
  "colors": {
    "primary": "#1a73e8"
  },
  "logos": {
    "logo_url": "/static/themes/mereka/tenants/minimal-tenant/logos/logo.png",
    "favicon_url": "/static/themes/mereka/tenants/minimal-tenant/favicons/favicon.ico"
  },
  "footer": {
    "contact_email": "support@minimal.com"
  }
}
```

### Complete Brand Pack (All Fields)

```json
{
  "slug": "acme-corp",
  "name": "Acme Corporation",
  "domain": "acme.academyv2.mereka.io",
  "colors": {
    "primary": "#FF5733",
    "secondary": "#FFC300",
    "accent": "#C70039",
    "text_on_primary": "#FFFFFF"
  },
  "logos": {
    "logo_url": "/static/themes/mereka/tenants/acme-corp/logos/logo.png",
    "logo_square_url": "/static/themes/mereka/tenants/acme-corp/logos/logo-square.png",
    "logo_white_url": "/static/themes/mereka/tenants/acme-corp/logos/logo-white.png",
    "favicon_url": "/static/themes/mereka/tenants/acme-corp/favicons/favicon.ico"
  },
  "footer": {
    "text": "© 2026 Acme Corp. All rights reserved.",
    "links": [
      {
        "title": "Privacy Policy",
        "url": "https://acme.com/privacy"
      },
      {
        "title": "Terms of Service",
        "url": "https://acme.com/terms"
      },
      {
        "title": "Contact Us",
        "url": "https://acme.com/contact"
      }
    ],
    "contact_email": "support@acme.com"
  }
}
```

### Using Template

```bash
# Copy template to new tenant directory
cp scripts/tenants/brand-pack-template.json \
   infrastructure/tutor/themes/mereka/tenants/new-tenant/branding.json

# Edit with tenant-specific values
vim infrastructure/tutor/themes/mereka/tenants/new-tenant/branding.json

# Validate
./scripts/tenants/validate-tenant-brand-pack.sh --slug new-tenant
```

---

## Troubleshooting

### Issue: "slug must match pattern ^[a-z0-9-]+$"

**Cause**: Slug contains uppercase letters, spaces, or special characters.

**Fix**: Use only lowercase letters, numbers, and hyphens:
```json
{
  "slug": "acme-corp"  // ✅ Valid
  // "slug": "Acme Corp"  // ❌ Invalid (uppercase, space)
  // "slug": "acme.corp"  // ❌ Invalid (dot)
}
```

---

### Issue: "colors.primary is not valid hex"

**Cause**: Color value is not a valid 6-character hex color.

**Fix**: Use format `#RRGGBB` (6 hex digits):
```json
{
  "colors": {
    "primary": "#FF5733"  // ✅ Valid
    // "primary": "#F53"      // ❌ Invalid (3 digits)
    // "primary": "red"       // ❌ Invalid (named color)
    // "primary": "rgb(255,87,51)"  // ❌ Invalid (RGB format)
  }
}
```

---

### Issue: "logos.logo_url does not exist on disk"

**Cause**: Path in `branding.json` does not match actual file location.

**Fix**: Ensure file exists and path is correct:
```bash
# Check if file exists
ls -lh infrastructure/tutor/themes/mereka/tenants/acme-corp/logos/logo.png

# If file is in different location, move it:
mv logo.png infrastructure/tutor/themes/mereka/tenants/acme-corp/logos/logo.png

# Update branding.json path
vim infrastructure/tutor/themes/mereka/tenants/acme-corp/branding.json
```

---

### Issue: "footer.links[0].url does not use HTTPS"

**Cause**: Footer link URL uses `http://` instead of `https://`.

**Fix**: Use HTTPS URLs only:
```json
{
  "footer": {
    "links": [
      {
        "title": "Privacy Policy",
        "url": "https://acme.com/privacy"  // ✅ Valid
        // "url": "http://acme.com/privacy"   // ❌ Invalid (HTTP)
      }
    ]
  }
}
```

---

### Issue: "footer.text contains HTML tags"

**Cause**: Footer text contains HTML markup.

**Fix**: Use plaintext only (no HTML):
```json
{
  "footer": {
    "text": "© 2026 Acme Corp. All rights reserved."  // ✅ Valid
    // "text": "© 2026 <strong>Acme Corp</strong>. All rights reserved."  // ❌ Invalid (HTML)
  }
}
```

---

## Related Documents

- **Schema Definition**: `specs/brand-pack-schema.json`
- **Template**: `scripts/tenants/brand-pack-template.json`
- **Contract**: `docs/branding/TENANT_BRANDING_CONTRACT.md`
- **Provisioning**: `docs/operations/TENANT_PROVISIONING.md`
- **Multi-site**: `docs/operations/MULTISITE.md`
- **Validation**: `scripts/tenants/validate-tenant-brand-pack.sh`
- **CI Gates**: `.github/workflows/ci.yml`

---

## Changelog

| Date | Change | Author |
|------|--------|--------|
| 2026-02-17 | Initial brand pack schema documentation | Claude Agent (bead w0th) |
