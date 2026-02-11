# Multi-Tenancy Architecture Overview
_Audience: Engineering + Architecture • Last updated: 2026-02-10_

## System Overview

Mereka Academy's multi-tenancy architecture enables a single Open edX deployment to serve multiple independent client organizations ("tenants") from shared infrastructure. Each tenant gets its own branded experience, curated course catalog, user population, administrative controls, analytics dashboards, and SSO integration -- all running on one GKE cluster, one MySQL instance, and one set of Open edX services.

**Key differentiator**: Shared-everything architecture with strict logical isolation, leveraging Open edX's native `EnterpriseCustomer` model as the tenant boundary.

---

## Component Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                      Ingress Layer                              │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │ Caddy Reverse Proxy                                      │   │
│  │ - Domain routing: client-a.mereka.io → Site A           │   │
│  │                   client-b.mereka.io → Site B           │   │
│  └──────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
                        │
                        ▼
┌─────────────────────────────────────────────────────────────────┐
│                    Application Layer                            │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │ LMS (Django)                                             │   │
│  │ - Django Sites framework (per-tenant domain mapping)    │   │
│  │ - SiteConfiguration (per-tenant settings)               │   │
│  │ - EnterpriseCustomer model (tenant identity)            │   │
│  │ - Queryset filtering: WHERE enterprise_customer_uuid=X  │   │
│  └──────────────────────────────────────────────────────────┘   │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │ Enterprise Microservices (5 services)                    │   │
│  │ - enterprise-catalog (per-tenant course catalogs)        │   │
│  │ - license-manager (per-tenant license pools)             │   │
│  │ - enterprise-access (per-tenant access policies)         │   │
│  │ - enterprise-subsidy (per-tenant subsidy ledgers)        │   │
│  │ - integrated-channels (per-tenant HR integrations)       │   │
│  └──────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
                        │
                        ▼
┌─────────────────────────────────────────────────────────────────┐
│                      Data Layer                                 │
│  ┌──────────────────┐  ┌──────────────────┐  ┌──────────────┐  │
│  │ MySQL (Cloud SQL)│  │ MongoDB Atlas    │  │ ClickHouse   │  │
│  │ - Users          │  │ - Courseware     │  │ - Analytics  │  │
│  │ - Enrollments    │  │ - Forum posts    │  │ - xAPI events│  │
│  │ - Grades         │  │ (tenant_uuid tag)│  │ (tenant col) │  │
│  │ (tenant_uuid FK) │  │                  │  │              │  │
│  └──────────────────┘  └──────────────────┘  └──────────────┘  │
└─────────────────────────────────────────────────────────────────┘

Tenant Isolation Layers:
┌─────────────────────────────────────────────────────────────────┐
│ 1. Domain Routing → Django Site → EnterpriseCustomer           │
│ 2. Queryset Filtering → WHERE enterprise_customer_uuid=X       │
│ 3. API Permissions → User.enterprise_customer == Tenant UUID   │
│ 4. Analytics Queries → WHERE tenant=X (ClickHouse)             │
│ 5. Branding → SiteConfiguration.theme = tenant_theme           │
└─────────────────────────────────────────────────────────────────┘
```

---

## Data Flow

### Tenant Provisioning Flow
1. **Admin** creates `EnterpriseCustomer` record in Django admin
2. **System** generates unique UUID for tenant
3. **Admin** creates Django `Site` with tenant domain (e.g., `client-a.mereka.io`)
4. **Admin** links `Site` to `EnterpriseCustomer` via FK
5. **System** creates `SiteConfiguration` with tenant branding (logo, colors)
6. **Admin** creates enterprise catalog via `enterprise-catalog` API
7. **Admin** creates license pool (if subscription model) via `license-manager` API
8. **Admin** configures SSO/SAML IdP (if applicable)
9. **System** provisions analytics dashboard with tenant filter

### Request Flow (Tenant A Learner)
1. **Learner** accesses `https://client-a.mereka.io`
2. **Caddy** routes to LMS pod based on domain
3. **Django Sites** middleware resolves domain to `Site` record
4. **Site** record links to `EnterpriseCustomer` UUID
5. **LMS** attaches `enterprise_customer_uuid` to request context
6. **All queries** include `WHERE enterprise_customer_uuid = 'uuid-a'`
7. **Branding** applies from `SiteConfiguration` (Tenant A theme)
8. **Catalog** shows only Tenant A's approved courses
9. **Response** rendered with Tenant A branding, zero Tenant B data

### Cross-Tenant Isolation Verification
1. **Admin** runs isolation test suite
2. **Test** logs in as Tenant A admin
3. **Test** attempts to access Tenant B catalog API
4. **API** checks `request.user.enterprise_customer_uuid` != Tenant B UUID
5. **API** returns `403 Forbidden`
6. **Test** verifies Tenant A admin portal shows zero Tenant B records
7. **Test** checks database queries include tenant filter (no full-table scans)
8. **Result**: PASS (no data leakage detected)

---

## Integration Points

### Django Sites Framework
- **Model**: `django.contrib.sites.models.Site`
- **Usage**: Maps domain to site ID, site to `EnterpriseCustomer`
- **Middleware**: `django.contrib.sites.middleware.CurrentSiteMiddleware`

### SiteConfiguration
- **Model**: `openedx.core.djangoapps.site_configuration.models.SiteConfiguration`
- **Fields**: `site` (FK to Site), `values` (JSONField with theme config)
- **Usage**: Per-tenant logos, colors, footer, CSRF/CORS settings

### EnterpriseCustomer Model
- **App**: `openedx-enterprise` Django package (ships with Open edX)
- **Key Fields**:
  - `uuid` (UUID, primary key) - Tenant identifier
  - `name` (str) - Display name
  - `slug` (str) - URL-safe identifier
  - `site` (FK to Site) - Associated domain
  - `active` (bool) - Enable/disable tenant
- **Foreign Keys**: Most tenant-scoped models have `enterprise_customer` FK

### Enterprise Microservices
- **Catalog**: Per-tenant course catalogs (filter by `enterprise_customer_uuid`)
- **License Manager**: Per-tenant license pools
- **Access**: Per-tenant access policies (SSO, consent)
- **Subsidy**: Per-tenant subsidy ledgers
- **Integrated Channels**: Per-tenant HR/LMS integrations (Degreed, Cornerstone)

---

## Key Design Decisions

### 1. Isolation Model: Shared-Everything vs. Separate Databases
**Decision**: Shared-everything (one database, logical isolation)

**Rationale**:
- **Cost**: Separate databases per tenant multiply infrastructure costs (50 tenants = 50× database cost).
- **Maintenance**: Shared database means one backup, one migration, one schema.
- **Open edX design**: Upstream `EnterpriseCustomer` model is designed for shared-database multi-tenancy.

**Trade-offs**:
- Requires strict queryset filtering (risk of data leakage if filter is missing).
- Cannot offer per-tenant database performance tuning.
- All tenants share database connection pool (noisy neighbor risk).

### 2. Tenant Identifier: EnterpriseCustomer UUID vs. Custom Model
**Decision**: Use Open edX's native `EnterpriseCustomer` model

**Rationale**:
- **Upstream compatibility**: No forking of Open edX core.
- **Feature completeness**: Enterprise features (catalog, licenses, SSO) already integrated.
- **Community alignment**: Other Open edX deployments use same pattern.

**Trade-offs**:
- Tightly coupled to Open edX data model (harder to migrate off Open edX).
- Enterprise features are paid features in some Open edX distributions (we run open-source).

### 3. Branding: Per-Site Themes vs. Runtime Theme Switching
**Decision**: Per-site themes via `SiteConfiguration`

**Rationale**:
- **Performance**: Theme loaded once per site, cached, no runtime switching overhead.
- **Simplicity**: Aligns with Django Sites framework (one site = one theme).
- **MFE support**: MFEs can query site config and apply branding at build time.

**Trade-offs**:
- Cannot switch user between tenants without logout/re-login.
- Rebranding requires cache invalidation across all pods.

### 4. Domain Strategy: Subdomains vs. Path-Based Routing
**Decision**: Subdomains (`client-a.mereka.io`, `client-b.mereka.io`)

**Rationale**:
- **Isolation**: Subdomains provide clear tenant boundary (cookies don't leak across subdomains).
- **SSL**: Wildcard SSL covers all subdomains (`*.mereka.io`).
- **Professional**: Clients prefer branded subdomains over path-based routing (`mereka.io/client-a`).

**Trade-offs**:
- Requires DNS configuration per tenant.
- Cannot use Cloudflare Free SSL for multi-level subdomains (workaround: use DNS-only + Let's Encrypt).

### 5. Analytics: Shared ClickHouse vs. Per-Tenant Databases
**Decision**: Shared ClickHouse with `tenant_id` column, row-level security in Superset

**Rationale**:
- **Cost**: ClickHouse can handle 50+ tenants in one database efficiently.
- **Query simplicity**: Single query with `WHERE tenant_id = X` vs. complex cross-database joins.
- **Superset integration**: Row-level security filters data by logged-in user's tenant.

**Trade-offs**:
- Tenant A queries can be slowed by Tenant B's high-volume analytics (QoS risk).
- One misbehaving query can affect all tenants (noisy neighbor).

---

## Tenant Isolation Guarantees

### Database Layer (MySQL)
- **Mechanism**: All queries MUST include `WHERE enterprise_customer_uuid = X`
- **Enforcement**: Django queryset manager overrides (automatic filtering)
- **Verification**: Automated test suite queries for cross-tenant leaks

### API Layer
- **Mechanism**: Permission classes check `request.user.enterprise_customer` == resource tenant
- **Enforcement**: DRF permission classes applied to all enterprise API views
- **Verification**: Automated API tests attempt cross-tenant access (expect 403)

### Analytics Layer (ClickHouse)
- **Mechanism**: `tenant_id` column on all xAPI event tables
- **Enforcement**: Superset row-level security policies filter by user's tenant
- **Verification**: Manual verification by logging in as different tenant admins

### UI Layer (MFEs)
- **Mechanism**: MFE queries `/api/v1/enterprise/` to get tenant context, filters all data
- **Enforcement**: API returns only tenant-scoped data
- **Verification**: Automated Playwright tests verify UI shows zero cross-tenant data

---

## Performance Considerations

### Queryset Filtering Overhead
- **Impact**: `WHERE enterprise_customer_uuid = X` adds one index lookup per query
- **Mitigation**: Index on `enterprise_customer_uuid` column (all tenant-scoped tables)
- **Measurement**: p95 query latency increases <10ms vs. non-filtered queries

### Catalog Query Scaling
- **Impact**: Tenant with 1000+ courses sees slow catalog queries
- **Mitigation**: Redis caching (TTL: 1 hour), pagination (page_size: 50)
- **Measurement**: p95 catalog API latency <300ms with caching

### Analytics Query Scaling
- **Impact**: ClickHouse `WHERE tenant_id = X` filters 100M+ rows
- **Mitigation**: ClickHouse partitioning by `tenant_id` (optional, at 50+ tenants)
- **Measurement**: p95 analytics query latency <2s with partitioning

---

## Implementation Artifacts

### Django App: `mereka_tenancy`
- **Location**: `infrastructure/tutor/plugins/multi-tenancy/`
- **Model**: `TenantConfig` — extends `EnterpriseCustomer` via OneToOneField
  - Fields: `slug`, `branding_config`, `sso_config`, `feature_flags`, `is_active`, `provisioned_at`
- **Middleware**: `TenantResolutionMiddleware` — resolves hostname → Site → EnterpriseCustomer → TenantConfig
  - Sets `request.tenant_uuid`, `request.tenant_slug`
  - Adds `X-Tenant-ID` response header
- **Management Command**: `provision_tenant` — idempotent tenant provisioning
  - Usage: `manage.py lms provision_tenant --slug acme --name "Acme Corp" --domain acme.academyv2.mereka.io`
- **Tutor Integration**: Installed via `apply-patches.sh` (INSTALLED_APPS + MIDDLEWARE)
- **Docker Integration**: Copied as `/openedx/mereka_tenancy` in the openedx image

### K8s Resources
- **ConfigMap**: `deploy/k8s/base/apps/multi-tenancy/configmap-tenants.yaml` — tenant registry
- **Kustomization**: `deploy/k8s/base/apps/multi-tenancy/kustomization.yaml`

### Verification Scripts
- `scripts/qa/verify-tenant-model.sh` — TenantConfig model structure
- `scripts/qa/verify-tenant-middleware.sh` — Middleware class and settings integration
- `scripts/qa/verify-tenant-configmap.sh` — K8s ConfigMap template
- `scripts/qa/verify-tenant-provisioning.sh` — Management command structure
- `scripts/qa/verify-tenant-isolation-patterns.sh` — Isolation patterns across codebase

---

## Related Specs and ADRs
- **Spec**: `specs/multi-tenancy-architecture_spec.md`
- **Runbook**: `docs/runbooks/tenant-provisioning-runbook.md`
- **Enterprise Services**: `specs/enterprise-microservices_spec.md`
- **Branding**: `specs/branding-system_spec.md`
- **Multi-Site Domains**: `specs/multi-site-domains_spec.md`
- **Analytics**: `specs/analytics-pipeline_spec.md`
