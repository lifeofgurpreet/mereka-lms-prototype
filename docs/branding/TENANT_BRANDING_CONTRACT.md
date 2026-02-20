# Tenant Branding Contract

_Audience: Platform Engineering + Operations + Design • Last updated: 2026-02-17_

**Purpose**: Define required inputs, fallback rules, and ownership for tenant branding in Mereka Academy multi-tenant Open edX.

**Spec Reference**: `specs/multi-tenancy-architecture_spec.md`
**Readiness Assessment**: `docs/operations/TENANT_BRANDING_READINESS_RAG.md`
**Verification**: `scripts/qa/verify-tenant-branding-contract.sh`

---

## Table of Contents

1. [Overview](#overview)
2. [Required Inputs Per Tenant](#required-inputs-per-tenant)
3. [Fallback Rules](#fallback-rules)
4. [Brand Pack Structure](#brand-pack-structure)
5. [Domain Mapping](#domain-mapping)
6. [MFE Configuration Keys](#mfe-configuration-keys)
7. [Ownership Boundaries](#ownership-boundaries)
8. [Zero-Downtime Brand Pack Workflow](#zero-downtime-brand-pack-workflow)
9. [Verification Checklist](#verification-checklist)
10. [Troubleshooting](#troubleshooting)

---

## Overview

Each tenant in the Mereka Academy platform requires a **brand pack** — a collection of assets, colors, and configuration that define the tenant's visual identity.

**Key Principles**:
- **Required assets have defaults**: Platform never breaks if a tenant skips optional inputs
- **Runtime overlay**: Tenant branding overlays platform defaults (no code changes)
- **Zero-downtime updates**: Branding changes apply via config updates + cache invalidation (no image rebuild)
- **Isolation**: Tenants cannot access or modify other tenants' branding

---

## Required Inputs Per Tenant

### 1. Logos

| Asset | Format | Dimensions | Required | Fallback |
|-------|--------|------------|----------|----------|
| **Primary Logo (horizontal)** | PNG/SVG | Max 400×100px | ✅ REQUIRED | Platform default (Mereka logo) |
| **Square Logo** | PNG/SVG | 200×200px | 🟡 RECOMMENDED | Primary logo (cropped) |
| **White Logo** | PNG/SVG | Max 400×100px | 🟡 RECOMMENDED | Primary logo (auto-inverted) |
| **Favicon** | ICO/PNG | 32×32px or 64×64px | ✅ REQUIRED | Platform default favicon |

**Storage**:
- Local: `infrastructure/tutor/themes/mereka/tenants/<slug>/logos/`
- Database: `TenantSiteConfiguration.values['logo_url']`, `TenantSiteConfiguration.mfe_config['LOGO_URL']`

**Validation**:
- Max file size: 500KB per logo
- Accepted formats: PNG, SVG, ICO (for favicon only)
- Transparency: Recommended for square/white logos

---

### 2. Colors

| Property | CSS Variable | Format | Required | Fallback |
|----------|--------------|--------|----------|----------|
| **Primary Color** | `--primary-color` | Hex (#RRGGBB) | ✅ REQUIRED | `#1a73e8` (Mereka blue) |
| **Secondary Color** | `--secondary-color` | Hex (#RRGGBB) | 🟡 RECOMMENDED | `#4285f4` (Mereka light blue) |
| **Accent Color** | `--accent-color` | Hex (#RRGGBB) | ⚪ OPTIONAL | Primary color (darker shade) |
| **Text on Primary** | `--text-on-primary` | Hex (#RRGGBB) | ⚪ OPTIONAL | `#FFFFFF` (white) |

**Storage**:
- Database: `TenantSiteConfiguration.values['primary_color']`, `values['secondary_color']`, etc.

**Validation**:
- Must be valid hex colors (regex: `^#[0-9A-Fa-f]{6}$`)
- Contrast ratio requirements:
  - Primary + Text on Primary: WCAG AA (4.5:1 minimum)
  - Secondary + Background: WCAG AA (3:1 minimum)

---

### 3. Footer Configuration

> **See also**: [Footer Parity Contract](#footer-parity-contract) for the authoritative per-surface breakdown.

| Field | Type | Max Length | Required | Fallback |
|-------|------|------------|----------|----------|
| **Footer Text** | Plaintext | 500 chars | ⚪ OPTIONAL | "© {year} {tenant_name}. All rights reserved." |
| **Footer Links** | JSON array | 10 links max | ⚪ OPTIONAL | Empty array (no links) |
| **Contact Email** | Email | 100 chars | ✅ REQUIRED | Platform support email |

**Footer Links Format**:
```json
{
  "footer_links": [
    {"title": "Privacy Policy", "url": "https://example.com/privacy"},
    {"title": "Terms of Service", "url": "https://example.com/terms"},
    {"title": "Contact Us", "url": "https://example.com/contact"}
  ]
}
```

**Storage**:
- Database: `TenantSiteConfiguration.values['footer_text']`, `values['footer_links']`
- MFE: Injected via `inject_mfe_branding()` at runtime

**Validation**:
- Footer text: No HTML allowed (plaintext only)
- Footer links: URLs must be HTTPS (http:// rejected)
- Contact email: Valid email format (RFC 5322)

---

### 4. Domain Mapping

| Field | Type | Required | Fallback |
|-------|------|----------|----------|
| **Primary Domain** | FQDN | ✅ REQUIRED | None (provisioning fails) |
| **Alternate Domains** | FQDN array | ⚪ OPTIONAL | Empty array |
| **Studio Domain** | FQDN | ⚪ OPTIONAL | `studio.{primary_domain}` |
| **MFE Domain** | FQDN | ⚪ OPTIONAL | `apps.{primary_domain}` |

**Examples**:
- Mereka Academy: `academyv2.mereka.io`, `academy.biji-biji.com`, `skillourfuture.academy.mereka.io`
- Acme Corp: `acme.academyv2.mereka.io`, `studio.acme.academyv2.mereka.io`, `apps.acme.academyv2.mereka.io`

**Storage**:
- Database: `TenantSiteMapping.site.domain` (primary), Django `Site` model supports one domain only
- Alternate domains: Stored in `TenantSiteConfiguration.values['alternate_domains']` (array)

**Validation**:
- Primary domain: Must be unique across all tenants
- Alternate domains: Must not conflict with other tenants' primary domains
- DNS: A/CNAME records must point to platform load balancer IP

---

### 5. MFE Configuration Keys

MFE-specific branding keys injected at runtime via `inject_mfe_branding()`.

| Key | Type | Required | Fallback |
|-----|------|----------|----------|
| **LOGO_URL** | URL | ✅ REQUIRED | Platform default logo URL |
| **LOGO_TRADEMARK_URL** | URL | ⚪ OPTIONAL | `LOGO_URL` |
| **LOGO_WHITE_URL** | URL | ⚪ OPTIONAL | `LOGO_URL` |
| **FAVICON_URL** | URL | ✅ REQUIRED | Platform default favicon URL |
| **SITE_NAME** | String | ✅ REQUIRED | `TenantSiteMapping.name` |
| **MARKETING_SITE_BASE_URL** | URL | ⚪ OPTIONAL | `https://{primary_domain}` |
| **SUPPORT_EMAIL** | Email | ✅ REQUIRED | `TenantSiteMapping.contact_email` |
| **TERMS_OF_SERVICE_URL** | URL | ⚪ OPTIONAL | Platform default ToS URL |
| **PRIVACY_POLICY_URL** | URL | ⚪ OPTIONAL | Platform default privacy URL |

**Storage**:
- Database: `TenantSiteConfiguration.mfe_config` (JSONField)

**Validation**:
- URLs: Must be absolute URLs (http:// or https://)
- SITE_NAME: Max 100 characters
- SUPPORT_EMAIL: Valid email format

---

## Fallback Rules

**Principle**: Platform never breaks if a tenant skips optional inputs. Fallback order:

1. **Tenant-specific value** (if provided)
2. **Tenant name/slug-derived value** (if applicable)
3. **Platform default** (from settings)

### Logo Fallback Chain

```
LOGO_URL:
  1. TenantSiteConfiguration.mfe_config['LOGO_URL']
  2. TenantSiteConfiguration.values['logo_url']
  3. TenantSiteMapping.branding_config['logo_url']
  4. settings.DEFAULT_ORG_LOGO_URL
  5. '/static/images/logo.png' (hardcoded platform default)
```

### Color Fallback Chain

```
PRIMARY_COLOR:
  1. TenantSiteConfiguration.values['primary_color']
  2. TenantSiteMapping.branding_config['primary_color']
  3. settings.DEFAULT_ORG_PRIMARY_COLOR
  4. '#1a73e8' (hardcoded platform default)
```

### Footer Fallback Chain

```
FOOTER_TEXT:
  1. TenantSiteConfiguration.values['footer_text']
  2. TenantSiteMapping.branding_config['footer_text']
  3. "© {year} {tenant_name}. All rights reserved."
```

**Implementation**: See `infrastructure/tutor/custom-apps/openedx_tenant_cache/branding.py:49-106`

---

## Brand Pack Structure

Recommended directory structure for tenant assets:

```
infrastructure/tutor/themes/mereka/tenants/<slug>/
├── logos/
│   ├── logo.png                # Primary logo (horizontal)
│   ├── logo-square.png         # Square logo
│   ├── logo-white.png          # White logo (for dark backgrounds)
│   └── logo.svg                # SVG version (optional)
├── favicons/
│   ├── favicon.ico             # 32×32px ICO
│   └── favicon-64.png          # 64×64px PNG (optional)
├── styles/
│   └── custom.css              # Tenant-specific CSS overrides (optional)
└── config.json                 # Tenant branding metadata (validated by specs/brand-pack-schema.json — see scripts/qa/verify-brand-pack-schema.sh)
```

**config.json Example**:

```json
{
  "slug": "acme-corp",
  "name": "Acme Corp",
  "domain": "acme.academyv2.mereka.io",
  "colors": {
    "primary": "#FF5733",
    "secondary": "#FFC300",
    "accent": "#C70039"
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
      {"title": "Privacy Policy", "url": "https://acme.com/privacy"},
      {"title": "Terms of Service", "url": "https://acme.com/terms"}
    ],
    "contact_email": "support@acme.com"
  }
}
```

**Note**: `config.json` is optional metadata for ops reference. Actual runtime config comes from database (`TenantSiteConfiguration`).

---

## Domain Mapping

### DNS Configuration

For each tenant domain:

1. **Get load balancer IP**:
   ```bash
   kubectl get svc caddy -n mereka-lms -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
   ```

2. **Add A record**:
   ```
   acme.academyv2.mereka.io → <load-balancer-ip>
   ```

3. **Wait for propagation** (verify with `dig acme.academyv2.mereka.io`)

4. **Update LMS settings**:
   ```bash
   tutor config save --set "ALLOWED_HOSTS=['academyv2.mereka.io', 'acme.academyv2.mereka.io']"
   tutor config save --set "CSRF_TRUSTED_ORIGINS=['https://academyv2.mereka.io', 'https://acme.academyv2.mereka.io']"
   ./infrastructure/tutor/apply-patches.sh
   tutor k8s restart
   ```

### SSL Certificates

**Cloudflare Free SSL**: Covers `*.mereka.io` and `*.academyv2.mereka.io` only.

For multi-level subdomains (e.g., `acme.academyv2.mereka.io`):
- Use DNS-only mode (gray cloud) + Let's Encrypt via cert-manager (K8s) or Caddy (standalone)
- Cert-manager issues wildcard certs automatically for `*.academyv2.mereka.io`

**Reference**: `docs/reference/domain-ssl-management.md`

---

## MFE Configuration Keys

MFE branding is injected at runtime via the `mfe_config` API endpoint.

### API Endpoint

```
GET /api/v1/mfe_config
Host: acme.academyv2.mereka.io
```

**Response** (includes tenant overlay):

```json
{
  "LOGO_URL": "https://acme.academyv2.mereka.io/static/themes/mereka/tenants/acme-corp/logos/logo.png",
  "LOGO_TRADEMARK_URL": "https://acme.academyv2.mereka.io/static/themes/mereka/tenants/acme-corp/logos/logo-square.png",
  "LOGO_WHITE_URL": "https://acme.academyv2.mereka.io/static/themes/mereka/tenants/acme-corp/logos/logo-white.png",
  "FAVICON_URL": "https://acme.academyv2.mereka.io/static/themes/mereka/tenants/acme-corp/favicons/favicon.ico",
  "SITE_NAME": "Acme Corp",
  "PRIMARY_COLOR": "#FF5733",
  "SECONDARY_COLOR": "#FFC300",
  "MARKETING_SITE_BASE_URL": "https://acme.academyv2.mereka.io",
  "SUPPORT_EMAIL": "support@acme.com",
  "TERMS_OF_SERVICE_URL": "https://acme.com/terms",
  "PRIVACY_POLICY_URL": "https://acme.com/privacy"
}
```

**Implementation**: `infrastructure/tutor/custom-apps/openedx_tenant_cache/branding.py:109-137`

### Caching

- **Cache key**: `tenant:{enterprise_uuid}:branding:mfe_config`
- **TTL**: 300 seconds (5 minutes)
- **Cache backend**: Redis
- **Invalidation**: Automatic on `TenantSiteConfiguration.save()`

---

## Ownership Boundaries

| Responsibility | Owner | SLA |
|----------------|-------|-----|
| **Platform defaults** (fallback logos, colors) | Platform Engineering | N/A (one-time setup) |
| **Tenant brand pack** (logos, colors, footer) | Tenant Operations / Design Team | 2 business days (new tenant) |
| **DNS configuration** | Platform Engineering | 1 business day (new domain) |
| **SSL certificates** | Platform Engineering (automated) | 1 hour (cert-manager auto-issues) |
| **Theme directory structure** | Platform Engineering | N/A (created during provisioning) |
| **Database configuration** | Platform Engineering (via provision_tenant) | 1 hour (provisioning script) |
| **Asset upload** | Tenant Operations / Design Team | Self-service (ops runbook) |
| **Verification** | Platform Engineering (automated) | 30 minutes (CI gates) |
| **Brand pack updates** | Tenant Operations / Design Team | Self-service (zero-downtime workflow) |
| **Incident response** (branding regressions) | Platform Engineering | 4 hours (P1 incidents) |

### Handoff Points

1. **Tenant onboarding**: Design Team → Tenant Ops (brand pack assets)
2. **Provisioning**: Tenant Ops → Platform Eng (run provision_tenant script)
3. **DNS setup**: Platform Eng → Tenant Ops (A record instructions)
4. **Brand pack upload**: Tenant Ops (self-service via runbook)
5. **Verification**: Platform Eng (automated via CI gates)

---

## Zero-Downtime Brand Pack Workflow

**Goal**: Update tenant branding (logo, colors, footer) without image rebuild or downtime.

### Step 1: Upload Assets

```bash
# Upload new logo to tenant directory
cp acme-new-logo.png infrastructure/tutor/themes/mereka/tenants/acme-corp/logos/logo.png

# Upload new favicon
cp acme-new-favicon.ico infrastructure/tutor/themes/mereka/tenants/acme-corp/favicons/favicon.ico
```

### Step 2: Sync to Static Directory

```bash
# Option A: Full branding sync
./scripts/branding/sync-brand-assets.sh

# Option B: Tenant-specific sync (faster)
tutor local run lms python manage.py lms collectstatic --noinput \
  --clear --link \
  --ignore '*.scss' --ignore '*.sass'
```

**For Kubernetes**:

```bash
# Sync to all LMS pods
kubectl exec -n mereka-lms deployment/lms -- \
  python manage.py lms collectstatic --noinput --clear --link
```

### Step 3: Update Database Configuration

```bash
# Update colors and footer via Django shell
tutor local run lms python manage.py lms shell << 'EOF'
from openedx_tenant_cache.models import TenantSiteMapping

tenant = TenantSiteMapping.get_by_slug('acme-corp')
config = tenant.site_config

# Update colors
config.values['primary_color'] = '#FF5733'
config.values['secondary_color'] = '#FFC300'

# Update footer
config.values['footer_text'] = '© 2026 Acme Corp. All rights reserved.'

# Update MFE logo URLs (if paths changed)
config.mfe_config['LOGO_URL'] = '/static/themes/mereka/tenants/acme-corp/logos/logo.png'
config.mfe_config['FAVICON_URL'] = '/static/themes/mereka/tenants/acme-corp/favicons/favicon.ico'

config.save()
EOF
```

### Step 4: Invalidate Cache

```bash
# Clear Redis cache for tenant
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

### Step 5: Verify Changes

```bash
# Check branding via API
curl -H "Host: acme.academyv2.mereka.io" \
  https://academyv2.mereka.io/api/v1/mfe_config | jq .

# Run branding verifier
./scripts/qa/verify-tenant-branding.sh acme-corp

# Visual check
# Open https://acme.academyv2.mereka.io in browser, verify new logo/colors
```

**Downtime**: Zero (static files served from existing pods, cache invalidation is instant)

**Rollback**: Revert file upload, re-run collectstatic, invalidate cache again.

---

## Verification Checklist

Use `scripts/qa/verify-tenant-branding-contract.sh` to verify compliance.

**Manual Checklist**:

- [ ] Primary logo uploaded (PNG/SVG, <500KB)
- [ ] Favicon uploaded (ICO, 32×32px or 64×64px)
- [ ] Primary color is valid hex (`^#[0-9A-Fa-f]{6}$`)
- [ ] Secondary color is valid hex (optional)
- [ ] Contact email is valid email format
- [ ] Footer text <500 characters (optional)
- [ ] Footer links are HTTPS URLs (if provided)
- [ ] Primary domain is unique (no conflicts)
- [ ] DNS A record points to load balancer IP
- [ ] ALLOWED_HOSTS includes tenant domain
- [ ] CSRF_TRUSTED_ORIGINS includes tenant domain
- [ ] TenantSiteMapping record exists in database
- [ ] TenantSiteConfiguration record exists in database
- [ ] `inject_mfe_branding()` returns tenant-specific config
- [ ] Cache invalidation works (update logo → verify change)
- [ ] Branding gates pass (`./scripts/branding/run-branding-gates.sh prod`)

**Automated Verifier**:

```bash
./scripts/qa/verify-tenant-branding-contract.sh acme-corp
```

**Expected Output**:

```
=== Tenant Branding Contract Verification ===
Tenant: acme-corp

[PASS] Primary logo exists
[PASS] Favicon exists
[PASS] Primary color is valid hex
[PASS] Contact email is valid
[PASS] TenantSiteMapping record exists
[PASS] TenantSiteConfiguration record exists
[PASS] MFE config injection works
[PASS] Branding gates pass

✅ All checks passed
```

---

## Troubleshooting

### Issue: Logo not appearing on tenant site

**Cause**: Static files not collected or cached response.

**Fix**:
1. Run `collectstatic`: `tutor local run lms python manage.py lms collectstatic --noinput`
2. Clear cache: `tutor local run lms python manage.py lms shell -c "from openedx_tenant_cache.cache import tenant_cache_clear; tenant_cache_clear('tenant-uuid')"`
3. Hard refresh browser (Cmd+Shift+R / Ctrl+Shift+R)

---

### Issue: MFE shows platform logo instead of tenant logo

**Cause**: `ENABLE_MULTI_TENANT_BRANDING=False` or `inject_mfe_branding()` not called.

**Fix**:
1. Verify feature flag: `tutor config printvalue ENABLE_MULTI_TENANT_BRANDING` (should be `true`)
2. Check middleware: `grep TenantResolutionMiddleware tutor_env/env/apps/openedx/settings/lms/production.py`
3. Verify MFE config injection: `curl https://acme.academyv2.mereka.io/api/v1/mfe_config | jq .LOGO_URL`

---

### Issue: Primary color not applying

**Cause**: CSS specificity conflict or cached CSS.

**Fix**:
1. Verify database config: `tutor local run lms python manage.py lms shell -c "from openedx_tenant_cache.models import TenantSiteMapping; print(TenantSiteMapping.get_by_slug('acme-corp').site_config.values['primary_color'])"`
2. Check CSS injection: Inspect element, verify `--primary-color` CSS variable in `:root`
3. Rebuild MFE (if CSS is image-baked): `tutor images build mfe && tutor k8s restart`

---

### Issue: Footer text not updating

**Cause**: Cache not invalidated.

**Fix**:
1. Clear Redis cache: `tenant_cache_clear(tenant_uuid)`
2. Restart LMS pods: `tutor k8s restart`
3. Verify API response: `curl https://acme.academyv2.mereka.io/api/v1/mfe_config | jq .FOOTER_TEXT`

---

---

## Footer Parity Contract

_Added: 2026-02-20 (bead 1kwf + bz9p)_

Defines the authoritative source of truth for each footer surface, the per-tenant field values,
and the verification commands to confirm parity. This section replaces the informal footer notes
previously scattered across audit documents.

### Surface Map

| Surface | Template / Source | Auth Source | Multi-tenant? | Status |
|---------|------------------|-------------|---------------|--------|
| **LMS Mako footer** | `themes/mereka/lms/templates/footer.html` | `SiteConfiguration.PLATFORM_NAME` | Partial (see note) | ✅ Source-complete; awaiting image rebuild |
| **Studio footer** | `themes/mereka/cms/templates/widgets/footer.html` | Static (Mereka Academy) | No | ✅ Source-complete; awaiting image rebuild |
| **MFE footer (all MFEs)** | `mereka_lms.py` → `MerekaFooter` component | `SITE_VARIANTS` hostname map | Yes | ✅ Source-complete; awaiting MFE image deploy |

**LMS Mako note**: `static.get_platform_name()` reads `SiteConfiguration.get_value('PLATFORM_NAME')`,
which Django Sites framework makes per-domain. This achieves partial multi-tenancy: the copyright
holder tracks `PLATFORM_NAME`. Navigation links (emails, help URLs) remain Mereka-specific hardcodes
until bead 2rcf (full TenantConfig) lands.

### Per-Tenant Footer Fields (Current Production)

| Tenant | Domain | MFE `brand` | MFE `copyrightHolder` | LMS copyright (`PLATFORM_NAME`) | Studio |
|--------|--------|-------------|----------------------|----------------------------------|--------|
| Mereka Academy | `academyv2.mereka.io` | Mereka Academy | MEREKA | Mereka Academy | Mereka Academy |
| Biji-Biji Academy | `academy.biji-biji.com` | Biji-Biji Academy | Biji-Biji Initiative | Biji-Biji Academy | Mereka Academy |
| Skill Our Future | `skillourfuture.academy.mereka.io` | Skill Our Future Academy | MEREKA | Skill Our Future Academy | Mereka Academy |

**Note**: Studio footer is a single static template shared across all tenants (single Studio pod).
It shows Mereka branding regardless of which domain the author navigated from. This is an accepted
limitation until Studio subdomain routing per tenant is implemented (bead 3sxq, backlog).

### Authoritative MFE Source (`mereka_lms.py` `SITE_VARIANTS`)

```javascript
const SITE_VARIANTS = {
  'academyv2.mereka.io': {
    brand: 'Mereka Academy',
    copyrightHolder: 'MEREKA',
    whatsapp: '601135271981',
  },
  'academy.biji-biji.com': {
    brand: 'Biji-Biji Academy',
    copyrightHolder: 'Biji-Biji Initiative',
    whatsapp: '601135271981',
  },
  'skillourfuture.academy.mereka.io': {
    brand: 'Skill Our Future Academy',
    copyrightHolder: 'MEREKA',
    whatsapp: '601135271981',
  },
};
```

**Update procedure**: Edit `mereka_lms.py`, rebuild MFE image, deploy. No DB change needed.
SITE_VARIANTS is build-time configuration (not runtime-configurable). When bead 2rcf lands, these
values will be superseded by `TenantConfig.copyrightHolder` read at render time.

### Banned Strings

No footer on any surface may contain these strings without Mereka co-branding context:

- `Powered by Open edX` — white-label deployment; attribution in docs per OEP-11
- `Powered by Tutor` — same as above
- `Biji-Biji Initiative` on Mereka/SkillourfFuture surfaces

Verification enforced by: `scripts/qa/verify-footer-parity.sh`

### Verification Commands

**Run all footer parity checks** (local, source-level):
```bash
./scripts/qa/verify-footer-parity.sh
# Expected: PASS ≥32, FAIL 0, WARN 1 (accepted: Enterprise MFE)
```

**Per-tenant live verification** (run after image deploy):
```bash
# Mereka Academy
curl -s https://academyv2.mereka.io/ | grep -i "powered by open edx" && echo FAIL || echo PASS

# Biji-Biji Academy — LMS copyright
curl -s https://academy.biji-biji.com/ | grep -i "Biji-Biji Initiative" && echo FOUND || echo MISSING

# Skill Our Future — LMS copyright
curl -s https://skillourfuture.academy.mereka.io/ | grep -i "Skill Our Future" && echo FOUND || echo MISSING

# Studio (any domain — single pod)
curl -s https://studio.academyv2.mereka.io/ | grep -i "powered by open edx" && echo FAIL || echo PASS
```

**Full post-deploy verification** (after WhiteCliff rebuilds and deploys images):
```bash
./scripts/qa/post-deploy-verify.sh prod
# Check 1 (Studio white-label) + Check 3 (LMS CSS) must PASS
```

### Gap Register (Path to True Multi-Tenant Footer)

| Gap | Surface | Current | Target | Owner Bead | Priority |
|-----|---------|---------|--------|------------|----------|
| Hardcoded nav links (emails, help URLs) | LMS Mako | Mereka-specific | `SiteConfiguration` per-domain | 2rcf | P2 |
| Copyright holder source of truth | LMS Mako | `get_platform_name()` (global settings) | `TenantConfig.copyrightHolder` | 2rcf | P2 |
| `SITE_VARIANTS` runtime vs build-time | MFE | Build-time constant | `TenantConfig` API at render | 2rcf | P3 |
| Studio per-tenant footer | CMS | Single shared template | Subdomain-aware CMS routing | 3sxq | P3 (backlog) |
| Enterprise MFE footer | Enterprise portals | Open edX default | `MerekaFooter` wired via env | backlog | P4 |

## Related Documents

- **Provisioning Guide**: `docs/operations/TENANT_PROVISIONING.md`
- **RAG Assessment**: `docs/operations/TENANT_BRANDING_READINESS_RAG.md`
- **Architecture**: `docs/architecture/multi-tenancy-overview.md`
- **Spec**: `specs/multi-tenancy-architecture_spec.md`
- **Branding Model**: `docs/branding/BRANDING_OPERATING_MODEL.md`
- **Domain/SSL**: `docs/reference/domain-ssl-management.md`

---

## Changelog

| Date | Change | Author |
|------|--------|--------|
| 2026-02-20 | Added Footer Parity Contract section; per-tenant field table; gap register; verification commands (bead 1kwf) | Claude Agent (BoldBadger) |
| 2026-02-17 | Initial tenant branding contract | Claude Agent (task 2rg1) |
