# Tenant Provisioning Guide

This document describes how to provision new tenants in the Mereka Academy multi-tenant Open edX platform.

**Spec**: `specs/multi-tenancy-architecture_spec.md`  
**Acceptance Criteria**: AC-MTA-001, AC-MTA-002, AC-MTA-021

---

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [What is a Tenant?](#what-is-a-tenant)
3. [Provisioning Process](#provisioning-process)
4. [Mereka Academy - First Tenant](#mereka-academy---first-tenant)
5. [Fast-Path Brand Pack Flow](#fast-path-brand-pack-flow)
6. [Provisioning Steps Explained](#provisioning-steps-explained)
7. [Idempotency Guarantees](#idempotency-guarantees)
8. [Using .env Files for Repeatability](#using-env-files-for-repeatability)
9. [xAPI Backfill Procedure](#xapi-backfill-procedure)
10. [Post-Provisioning Checklist](#post-provisioning-checklist)
11. [Troubleshooting](#troubleshooting)
12. [Rollback/Offboarding](#rollbackoffboarding)

---

## Prerequisites

Before provisioning a tenant, ensure:

1. **openedx_tenant_cache app is installed**  
   - Located at `infrastructure/tutor/custom-apps/openedx_tenant_cache/`
   - Installed via Tutor plugin or manual INSTALLED_APPS entry
   - Migrations have been run: `tutor local run lms python manage.py lms migrate openedx_tenant_cache`

2. **edx-enterprise is available** (recommended but optional)  
   - If available, full EnterpriseCustomer objects are created
   - If not available, the command generates a UUID for the mapping only

3. **Database migrations are current**  
   - TenantSiteMapping and TenantSiteConfiguration tables exist

4. **Kubernetes cluster or Tutor local environment is running**  
   - For K8s: `kubectl get pods -n mereka-lms` shows LMS pods running
   - For local: `tutor local dc ps` shows containers up

5. **DNS planning**  
   - Decide on tenant domain (e.g., `acme.academyv2.mereka.io` or custom domain)
   - Ensure DNS can be updated post-provisioning

---

## What is a Tenant?

A **tenant** in the Mereka Academy platform represents a distinct organization or customer using the LMS. Each tenant has:

- **Isolated branding**: Logo, favicon, colors, footer text
- **Separate EnterpriseCustomer**: For enrollment policies, catalogs, SSO
- **Dedicated domain**: E.g., `acme.academyv2.mereka.io`
- **Custom configuration**: Platform name, site name, email sender alias
- **Analytics isolation**: xAPI events tagged with enterprise UUID

Tenants share the same codebase, database, and infrastructure but appear as separate platforms to end users.

---

## Provisioning Process

Canonical tenant metadata now lives in:

- `infrastructure/tenants/tenant-contracts.yml`

This contract is the declarative source for domain roots, org codes, registry slugs, and enterprise MFE env config mapping.

Before provisioning, verify contract drift across Caddy + multisite + tenant-registry + enterprise MFE env files:

```bash
./scripts/qa/verify-tenant-contract-alignment.sh
```

Provisioning is performed via the Django management command:

```bash
python manage.py lms provision_tenant \
  --slug <tenant-slug> \
  --name "<Tenant Display Name>" \
  --domain <tenant.domain.com> \
  [--contact-email admin@tenant.com] \
  [--country MY] \
  [--enterprise-uuid <existing-uuid>]
```

**Wrapper script** (recommended):

```bash
./scripts/tenants/provision-tenant.sh \
  --slug acme-corp \
  --name "Acme Corp" \
  --domain acme.academyv2.mereka.io \
  --contact-email admin@acme.com \
  --country US \
  [--dry-run]
```

The wrapper script:
- Detects execution environment (Kubernetes vs Tutor local)
- Validates slug format
- Provides post-provisioning reminders
- Supports `--dry-run` for preview

For batch provisioning from the canonical contract:

```bash
./scripts/tenants/provision-all-tenants.sh --dry-run
./scripts/tenants/provision-all-tenants.sh
```

---

## Mereka Academy - First Tenant

**Mereka Academy** is the first tenant to be provisioned. Use the pre-configured environment file:

```bash
./scripts/tenants/provision-tenant.sh \
  --from-env scripts/tenants/mereka-tenant.env \
  [--dry-run]
```

**Environment file contents** (`scripts/tenants/mereka-tenant.env`):

```bash
TENANT_SLUG=mereka
TENANT_NAME="Mereka Academy"
TENANT_DOMAIN=academyv2.mereka.io
TENANT_CONTACT_EMAIL=tech@mereka.io
TENANT_COUNTRY=MY
TENANT_ENTERPRISE_UUID=   # Auto-generated on first run
```

**Dry run first** (recommended):

```bash
./scripts/tenants/provision-tenant.sh \
  --from-env scripts/tenants/mereka-tenant.env \
  --dry-run
```

Review the output, then run without `--dry-run` to execute.

---

## Fast-Path Brand Pack Flow

**Goal**: Streamlined workflow for creating, validating, and deploying tenant branding without image rebuild.

**Audience**: Tenant Operations, Design Team, Platform Engineering

**Prerequisites**:
- Tenant provisioned via `provision_tenant` command (see [Provisioning Process](#provisioning-process))
- Brand assets prepared (logo, favicon, colors)

---

### Step 1: Create Brand Pack

```bash
# Start from tracked tenant brand-pack template and adjust values
cp scripts/tenants/brand-pack-template.json /tmp/acme-branding.json
vim /tmp/acme-branding.json

# Example tracked reference payload
cp scripts/tenants/acme-branding.json /tmp/acme-branding.example.json
```

**branding.json Example**:
```json
{
  "slug": "acme-corp",
  "name": "Acme Corporation",
  "domain": "acme.academyv2.mereka.io",
  "colors": {
    "primary": "#FF5733"
  },
  "logos": {
    "logo_url": "/static/themes/mereka/tenants/acme-corp/logos/logo.png",
    "favicon_url": "/static/themes/mereka/tenants/acme-corp/favicons/favicon.ico"
  },
  "footer": {
    "contact_email": "support@acme.com"
  }
}
```

**Reference**:
- **Schema**: `specs/standards/brand-pack-schema.json`
- **Docs**: `docs/reference/operations/TENANT_BRAND_PACK_SCHEMA.md`
- **Template**: `infrastructure/tutor/themes/mereka/tenants/_template/`

---

### Step 2: Add Assets

```bash
# Validate the brand-pack JSON (path points to your working file)
./scripts/tenants/validate-tenant-brand-pack.sh --slug acme-corp

# Sync tenant branding assets from canonical tenant sources
./scripts/tenants/sync-tenant-branding.sh --tenant acme-corp

# Optional: repo-wide asset sync after tenant update
./scripts/branding/sync-brand-assets.sh
```

**Asset Requirements**:
- Formats: PNG, SVG (logos), ICO (favicon)
- Max file size: 500KB per asset
- Logo dimensions: Max 400×100px (horizontal), 200×200px (square)
- Favicon dimensions: 32×32px or 64×64px

---

### Step 3: Validate Brand Pack

```bash
# Validate tenant brand pack structure and content
./scripts/tenants/validate-tenant-brand-pack.sh --slug acme-corp

# Expected output:
# [PASS] branding.json exists
# [PASS] branding.json is valid JSON
# [PASS] All required fields present
# [PASS] slug matches directory name (acme-corp)
# [PASS] colors.primary is valid hex (#FF5733)
# [PASS] logos.logo_url exists on disk
# [PASS] logos.favicon_url exists on disk
# ...
# ✅ All checks passed
```

**What it checks**:
- Directory structure (logos/, favicons/, css/)
- JSON validity
- Required fields present
- Slug matches directory name and pattern
- Colors are valid hex
- Logo files exist and are <500KB
- Footer links use HTTPS
- Email format valid
- Domain is valid FQDN

---

### Step 4: Apply Branding

```bash
# Option A: Sync to static directory (local development)
tutor local run lms python manage.py lms collectstatic --noinput --clear --link

# Option B: Sync to Kubernetes pods (production)
kubectl exec -n mereka-lms deployment/lms -- \
  python manage.py lms collectstatic --noinput --clear --link

# Option C: Use branding sync script (recommended)
./scripts/branding/sync-brand-assets.sh
```

**What happens**:
- Brand pack assets copied to `/static/themes/mereka/tenants/<slug>/`
- Assets served via Caddy/Nginx reverse proxy
- No image rebuild required

---

### Step 5: Update Database Configuration

```bash
# Update tenant configuration in database (optional, if not set during provisioning)
tutor local run lms python manage.py lms shell << 'EOF'
from openedx_tenant_cache.models import TenantSiteMapping

tenant = TenantSiteMapping.get_by_slug('acme-corp')
config = tenant.site_config

# Update colors
config.values['primary_color'] = '#FF5733'

# Update MFE logo URLs
config.mfe_config['LOGO_URL'] = '/static/themes/mereka/tenants/acme-corp/logos/logo.png'
config.mfe_config['FAVICON_URL'] = '/static/themes/mereka/tenants/acme-corp/favicons/favicon.ico'

config.save()
EOF
```

**Why**: Database config overrides file-based config at runtime.

---

### Step 6: Invalidate Cache

```bash
# Clear Redis cache for tenant (ensures immediate visibility)
tutor local run lms python manage.py lms shell << 'EOF'
from openedx_tenant_cache.cache import tenant_cache_clear

tenant_uuid = 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx'  # Replace with actual UUID
tenant_cache_clear(tenant_uuid)
EOF
```

**Kubernetes**:
```bash
kubectl exec -n mereka-lms deployment/lms -- \
  python manage.py lms shell -c "from openedx_tenant_cache.cache import tenant_cache_clear; tenant_cache_clear('tenant-uuid')"
```

---

### Step 7: Runtime Verification

```bash
# Verify branding via MFE config API
curl -H "Host: acme.academyv2.mereka.io" \
  https://academyv2.mereka.io/api/v1/mfe_config | jq .

# Expected output:
# {
#   "LOGO_URL": "https://acme.academyv2.mereka.io/static/themes/mereka/tenants/acme-corp/logos/logo.png",
#   "FAVICON_URL": "https://acme.academyv2.mereka.io/static/themes/mereka/tenants/acme-corp/favicons/favicon.ico",
#   "PRIMARY_COLOR": "#FF5733",
#   "SITE_NAME": "Acme Corporation",
#   ...
# }

# Run automated branding verifier
./scripts/qa/verify-tenant-branding.sh acme-corp

# Visual check (open in browser)
# https://acme.academyv2.mereka.io
```

**Downtime**: Zero (static files served from existing pods, cache invalidation is instant)

**Rollback**: Revert file upload, re-run collectstatic, invalidate cache again.

---

### Fast-Path Summary

| Step | Command | Time |
|------|---------|------|
| 1. Create brand pack | `cp -r _template/ acme-corp/ && vim branding.json` | 5 min |
| 2. Add assets | `cp logo.png favicons/favicon.ico` | 2 min |
| 3. Validate | `./scripts/tenants/validate-tenant-brand-pack.sh --slug acme-corp` | 1 min |
| 4. Apply branding | `tutor local run lms collectstatic` | 2 min |
| 5. Update DB config | `python manage.py lms shell` | 2 min |
| 6. Invalidate cache | `tenant_cache_clear(uuid)` | 1 min |
| 7. Verify | `curl /api/v1/mfe_config` | 1 min |
| **Total** | | **~15 min** |

**Reference**:
- **Contract**: `docs/guides/branding/TENANT_BRANDING_CONTRACT.md` (fallback rules, ownership boundaries)
- **Schema Docs**: `docs/reference/operations/TENANT_BRAND_PACK_SCHEMA.md` (asset requirements, validation)
- **Multi-site**: `docs/concepts/architecture/multi-tenancy-overview.md` (DNS, TLS, domain mapping)

---

## Provisioning Steps Explained

The provisioning command performs **11 steps** idempotently:

### Step 1: Create Django Site
- Creates or retrieves a Django `Site` object for the tenant domain
- Example: `Site(domain='acme.academyv2.mereka.io', name='Acme Corp')`

### Step 2: Create EnterpriseCustomer
- If `edx-enterprise` is installed, creates or retrieves an `EnterpriseCustomer`
- If not installed, generates a UUID for the mapping
- Fields: `name`, `slug`, `active`, `site`, `contact_email`, `country`

### Step 3: Create TenantSiteMapping
- Links the EnterpriseCustomer UUID to the Django Site
- Stores tenant metadata: `slug`, `name`, `is_active`, `branding_config`

### Step 4: Create TenantSiteConfiguration
- Stores per-tenant configuration overlays
- `values`: Platform name, logo URLs, colors, footer text
- `mfe_config`: MFE-specific branding (injected at runtime)

### Step 5: Create Enterprise Catalog
- Creates a default catalog linked to the EnterpriseCustomer
- Empty `content_filter` includes all courses
- Can be customized later via Django admin

### Step 6: Subscription Plan (Placeholder)
- Placeholder for license-manager or subscription plans
- Configure manually via admin after provisioning

### Step 7: Access Policy (Placeholder)
- Placeholder for enterprise-access subsidy policies
- Configure manually via admin after provisioning

### Step 8: SAML/OIDC Identity Provider (Placeholder)
- Placeholder for SSO configuration
- Use `scripts/tenants/configure-tenant-idp.sh --tenant-slug <slug>` (Phase 4)

### Step 9: Integrated Channels (Placeholder)
- Placeholder for Degreed, Cornerstone, SAP SuccessFactors, etc.
- Configure manually via admin after provisioning

### Step 10: Branding Directory
- Creates directory structure for tenant assets:
  ```
  themes/mereka/tenants/<slug>/
    logos/
    favicons/
    styles/
  ```

### Step 11: Summary
- Prints provisioning summary with UUIDs and status for each step

---

## Idempotency Guarantees

The provisioning command is **fully idempotent**:

- **get_or_create** pattern for all models
- **Duplicate slug check**: Prevents duplicate tenant slugs
- **Duplicate UUID check**: Reuses existing EnterpriseCustomer if UUID provided
- **transaction.atomic**: All steps succeed or fail together
- **Safe to re-run**: Running the command multiple times with the same arguments produces the same result

**Example**:

```bash
# First run: Creates all resources
./scripts/tenants/provision-tenant.sh --slug acme-corp --name "Acme Corp" --domain acme.academyv2.mereka.io

# Second run: Reports "Already exists" for all resources
./scripts/tenants/provision-tenant.sh --slug acme-corp --name "Acme Corp" --domain acme.academyv2.mereka.io
```

---

## Using .env Files for Repeatability

For production tenants, create a `.env` file in `scripts/tenants/`:

**Example**: `scripts/tenants/acme-tenant.env`

```bash
TENANT_SLUG=acme-corp
TENANT_NAME="Acme Corp"
TENANT_DOMAIN=acme.academyv2.mereka.io
TENANT_CONTACT_EMAIL=admin@acme.com
TENANT_COUNTRY=US
TENANT_ENTERPRISE_UUID=   # Leave empty for auto-generation
```

**Provision from .env**:

```bash
./scripts/tenants/provision-tenant.sh --from-env scripts/tenants/acme-tenant.env
```

**Benefits**:
- Version-controlled tenant definitions
- Repeatable provisioning across environments (local, staging, production)
- Clear documentation of tenant configuration

---

## xAPI Backfill Procedure

For existing tenants with historical xAPI events, backfill the `enterprise_customer_uuid` column:

### 1. Dry Run (Preview)

```bash
# Kubernetes
kubectl exec -n mereka-lms <lms-pod> -- \
  python manage.py lms backfill_xapi_enterprise_uuid \
  --enterprise-uuid <uuid> \
  --org-id Mereka \
  --dry-run

# Tutor Local
tutor local run lms python manage.py lms backfill_xapi_enterprise_uuid \
  --enterprise-uuid <uuid> \
  --org-id Mereka \
  --dry-run
```

### 2. Execute Backfill

```bash
# Remove --dry-run to execute
kubectl exec -n mereka-lms <lms-pod> -- \
  python manage.py lms backfill_xapi_enterprise_uuid \
  --enterprise-uuid <uuid> \
  --org-id Mereka \
  --batch-size 10000
```

### 3. Verify

```sql
-- ClickHouse query
SELECT 
  org_id,
  enterprise_customer_uuid,
  count() AS events
FROM xapi_events_all
WHERE org_id = 'Mereka'
GROUP BY org_id, enterprise_customer_uuid;
```

**Options**:
- `--enterprise-uuid`: UUID from TenantSiteMapping
- `--org-id`: Filter by organization (e.g., 'Mereka')
- `--batch-size`: Rows per batch (default: 10000)
- `--dry-run`: Preview without making changes

---

## Post-Provisioning Checklist

After provisioning a tenant, complete these steps:

### 1. DNS Configuration

Add DNS record pointing tenant domain to LMS load balancer:

```bash
# Get load balancer IP
kubectl get svc caddy -n mereka-lms -o jsonpath='{.status.loadBalancer.ingress[0].ip}'

# Add A record
acme.academyv2.mereka.io → <load-balancer-ip>
```

### 2. Update LMS Settings

Add tenant domain to `ALLOWED_HOSTS` and `CSRF_TRUSTED_ORIGINS`:

```bash
# Edit Tutor config
tutor config save --set "ALLOWED_HOSTS=['academyv2.mereka.io', 'acme.academyv2.mereka.io']"
tutor config save --set "CSRF_TRUSTED_ORIGINS=['https://academyv2.mereka.io', 'https://acme.academyv2.mereka.io']"

# Apply patches and restart
./infrastructure/tutor/apply-patches.sh
tutor k8s restart
```

### 3. Configure SSO (If Applicable)

```bash
./scripts/tenants/configure-tenant-idp.sh \
  --tenant-slug acme-corp \
  --idp-type saml \
  --metadata-url https://idp.acme.com/metadata
```

### 4. Upload Branding Assets

```bash
# Upload logo
cp acme-logo.png themes/mereka/tenants/acme-corp/logos/logo.png

# Upload favicon
cp acme-favicon.ico themes/mereka/tenants/acme-corp/favicons/favicon.ico

# Sync to Tutor
./scripts/branding/sync-brand-assets.sh
```

### 5. Create Enterprise Catalog

Via Django admin (`/admin/enterprise/enterprisecustomercatalog/`):
- Create a new catalog for the EnterpriseCustomer
- Set `content_filter` to restrict courses (or leave empty for all)

### 6. Create Subscription Plans

Via Django admin (`/admin/subscriptions/subscriptionplan/`) or license-manager API:
- Create a subscription plan
- Link to EnterpriseCustomer
- Set license limits

### 7. Verify Isolation

```bash
./scripts/qa/verify-tenant-isolation.sh
```

---

## Troubleshooting

### Issue: "EnterpriseCustomer with UUID X not found"

**Cause**: `--enterprise-uuid` provided but UUID doesn't exist in database.

**Fix**:
- Omit `--enterprise-uuid` to auto-generate
- OR verify the UUID exists: `tutor local run lms python manage.py lms shell -c "from enterprise.models import EnterpriseCustomer; print(EnterpriseCustomer.objects.all())"`

---

### Issue: "Slug must be lowercase alphanumeric"

**Cause**: Slug contains invalid characters (uppercase, spaces, special chars).

**Fix**: Use lowercase letters, numbers, hyphens, and underscores only:
- Valid: `acme-corp`, `mereka_academy`, `tenant123`
- Invalid: `Acme Corp`, `acme.corp`, `tenant@123`

---

### Issue: "Site with domain X already exists"

**Cause**: Django Site with the same domain already exists.

**Fix**:
- If this is intentional (re-provisioning), the command will reuse the existing Site
- If the domain is wrong, delete the Site: `python manage.py lms shell -c "from django.contrib.sites.models import Site; Site.objects.filter(domain='X').delete()"`

---

### Issue: "edx-enterprise not installed"

**Cause**: The `enterprise` module is not available.

**Fix**:
- The command will generate a UUID and create TenantSiteMapping only
- EnterpriseCustomer features (catalogs, SSO, subscriptions) will not be available
- Install `edx-enterprise` if full enterprise features are needed

---

### Issue: "ClickHouse backfill fails"

**Cause**: `event_sink_clickhouse` not installed or ClickHouse unreachable.

**Fix**:
- The command will print manual SQL instructions
- Run the SQL directly in ClickHouse client:
  ```sql
  ALTER TABLE xapi_events_all 
  ADD COLUMN IF NOT EXISTS enterprise_customer_uuid UUID;

  ALTER TABLE xapi_events_all 
  UPDATE enterprise_customer_uuid = '<uuid>' 
  WHERE enterprise_customer_uuid IS NULL AND org_id = 'Mereka';
  ```

---

## Rollback/Offboarding

To deactivate a tenant (without deleting data):

### 1. Mark Tenant as Inactive

```python
from openedx_tenant_cache.models import TenantSiteMapping
tenant = TenantSiteMapping.get_by_slug('acme-corp')
tenant.is_active = False
tenant.save()
```

### 2. Deactivate EnterpriseCustomer

```python
from enterprise.models import EnterpriseCustomer
ec = EnterpriseCustomer.objects.get(slug='acme-corp')
ec.active = False
ec.save()
```

### 3. Remove DNS Record

Delete the A record for the tenant domain.

### 4. Remove from ALLOWED_HOSTS

```bash
tutor config save --set "ALLOWED_HOSTS=['academyv2.mereka.io']"
./infrastructure/tutor/apply-patches.sh
tutor k8s restart
```

---

To **permanently delete** a tenant (destructive):

```python
# Delete all related data
from openedx_tenant_cache.models import TenantSiteMapping
tenant = TenantSiteMapping.objects.get(slug='acme-corp')
tenant.delete()  # Cascade deletes TenantSiteConfiguration

# Optionally delete EnterpriseCustomer (cascade deletes catalogs, subscriptions, etc.)
from enterprise.models import EnterpriseCustomer
EnterpriseCustomer.objects.filter(slug='acme-corp').delete()
```

**Warning**: This cannot be undone. Back up data before deleting.

---

## Summary

Tenant provisioning is a **one-command operation** that creates all required resources idempotently:

```bash
# Mereka Academy (first tenant)
./scripts/tenants/provision-tenant.sh --from-env scripts/tenants/mereka-tenant.env

# New tenant
./scripts/tenants/provision-tenant.sh \
  --slug acme-corp \
  --name "Acme Corp" \
  --domain acme.academyv2.mereka.io \
  --contact-email admin@acme.com \
  --country US
```

Post-provisioning steps (DNS, SSO, branding, catalogs) are required for full tenant activation.

For questions or issues, refer to:
- **Spec**: `specs/multi-tenancy-architecture_spec.md`
- **Verification**: `./scripts/qa/verify-tenant-isolation.sh`
- **Models**: `infrastructure/tutor/custom-apps/openedx_tenant_cache/models.py`
