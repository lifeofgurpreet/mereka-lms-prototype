---
title: "Multi-Tenancy Architecture"
type: "feature_spec"
id: "SPEC-MULTI-TENANCY-ARCHITECTURE"
status: "approved"
spec_class: "system"
owner: "engineering"
vehicle: "talent_platform"
created: "2026-02-13"
last_reviewed: "2026-03-09"
review_due: "2026-06-09"
domain: "tenancy"
normativity: "normative"
last_updated: "2026-02-13"
version: "1.0.0"
depends_on:
  - "specs/repository-structure_spec.md"
  - "specs/k8s-deployment_spec.md"
  - "specs/secrets-management_spec.md"
  - "specs/observability-stack_spec.md"
  - "specs/branding-system_spec.md"
  - "specs/multi-site-domains_spec.md"
  - "specs/platform-middleware-custom-apps_spec.md"
supersedes: []
superseded_by: null
verification_sources:
  - "scripts/qa/verify-multisite-config.sh"
  - "scripts/qa/verify-org-role-ownership.sh"
  - "scripts/qa/run-multisite-governance-gates.sh"
interfaces:
  - "django-sites"
  - "enterprise-customer"
tags:
  - "tenant.lifecycle"
  - "tenant.isolation"
  - "platform.control-plane"
summary: "System-level contract for tenant identity, isolation boundaries, provisioning, branding, and shared-infrastructure multi-tenancy across Mereka LMS."
links:
  related_docs:
    - "docs/concepts/architecture/MULTISITE.md"
    - "docs/ops/runbooks/TENANT_PROVISIONING.md"
    - "docs/ops/runbooks/TROUBLESHOOTING.md"
  related_specs:
    - "specs/enterprise-microservices_spec.md"
    - "specs/branding-system_spec.md"
    - "specs/multi-site-domains_spec.md"
    - "specs/secrets-management_spec.md"
    - "specs/k8s-deployment_spec.md"
    - "specs/analytics-pipeline_spec.md"
    - "specs/observability-stack_spec.md"
    - "specs/cross-cutting-requirements_spec.md"
---

# Human Summary

## What we're building

A multi-tenancy architecture for Mereka Academy that enables a single Open edX deployment to serve multiple independent client organizations ("tenants") from shared infrastructure. Each tenant gets its own branded experience, curated course catalog, user population, administrative controls, analytics dashboards, and SSO integration -- all running on one GKE cluster, one MySQL instance, and one set of Open edX services.

The architecture uses Open edX's native `EnterpriseCustomer` model as the tenant boundary. Isolation is achieved at the application layer (Django queryset filtering, API permission enforcement, the enterprise consent framework) rather than through separate databases or separate deployments per tenant. This is a "shared-everything" model with strict logical isolation, consistent with how Open edX upstream designs enterprise multi-tenancy.

The system extends across all platform layers: the LMS and CMS (via Django Sites framework and SiteConfiguration), the enterprise microservices (enterprise-catalog, license-manager, enterprise-access, enterprise-subsidy, integrated-channels), the micro-frontends (admin portal, learner portal, branded MFEs), the analytics pipeline (Aspects/ClickHouse with tenant-scoped queries), and the observability stack (tenant-labeled metrics and logs).

## Why it matters

Mereka Academy's business model requires onboarding multiple corporate clients, each expecting a private, branded learning environment without cross-contamination of data or learner experiences. Today, supporting a new client means ad-hoc Django admin configuration, manual branding patches, and no formal isolation guarantees. This spec establishes the architectural contract that every other spec and implementation must respect: the definition of a tenant, how tenants are isolated, how tenants are provisioned, and what guarantees the platform makes about cross-tenant data leakage.

Without this spec, the branding system has no framework for per-tenant themes, the enterprise services have no formal isolation verification strategy, the analytics pipeline has no tenant-scoping contract, and the secrets management system has no per-tenant credential segregation model. This is the foundational spec that makes "many clients" work.

## Success looks like

- A new tenant (enterprise client) can be fully provisioned -- branding, catalog, SSO, licenses, analytics -- within 4 hours of admin work and zero code changes
- Zero cross-tenant data leakage: tenant A's admin portal shows zero records belonging to tenant B, verified by automated isolation tests
- Per-tenant branding: each tenant's learners see only their branded login page, footer, logos, and color scheme
- Per-tenant analytics: each tenant admin sees only their learners' enrollment, completion, and engagement data
- Per-tenant SSO: each tenant's SAML/OIDC IdP authenticates only their users, with no cross-tenant authentication
- Horizontal scaling: the platform can support 50+ concurrent tenants without degrading p95 latency beyond the thresholds in the enterprise-microservices spec
- Tenant offboarding produces a complete data export and verifiable deletion within 30 days

---

# Agent Contract

## Scope

- In scope:
  - Tenant isolation model selection and architectural rationale
  - Tenant data model: what constitutes a "tenant" and its relationship to existing Open edX models
  - Data segregation strategy for all data stores (MySQL, MongoDB Atlas, Redis, ClickHouse)
  - Per-tenant branding and customization framework (themes, logos, colors, footer, MFE config)
  - Per-tenant domain routing and site configuration (Django Sites, SiteConfiguration, Caddy)
  - Per-tenant authentication and authorization (SSO/SAML, role-based access, consent)
  - Per-tenant analytics and reporting (Aspects/ClickHouse scoped queries, Superset row-level security)
  - Tenant provisioning workflow (creating a new tenant end-to-end)
  - Tenant offboarding workflow (data export, deletion, deprovisioning)
  - Cross-tenant isolation verification strategy (automated tests)
  - Performance and scaling considerations for multi-tenant workloads
  - Compliance, audit, and data residency requirements
  - Integration points with all related specs (enterprise services, branding, multi-site domains, analytics, secrets, K8s, observability)

- Out of scope:
  - Separate K8s cluster or namespace per tenant (out of scope; all tenants share `mereka-lms` namespace)
  - Separate database instance per tenant (out of scope; shared Cloud SQL)
  - Custom code changes to Open edX platform core (we use upstream capabilities)
  - Individual tenant onboarding details (covered in runbook)
  - Payment/billing per tenant (handled by ecommerce service and commercial agreements)
  - Mobile app per-tenant customization (covered by `specs/mobile-apps-enterprise_spec.md`)

## Non-goals

- Building a self-service tenant provisioning portal (admin-mediated provisioning is sufficient for v1)
- Supporting tenant-level infrastructure isolation (separate clusters, VPCs, or database instances per tenant)
- Supporting tenant-specified data residency regions (all data resides in GCP `asia-southeast1`; regional isolation is a future enhancement)
- Implementing tenant-level rate limiting distinct from the enterprise API rate limits defined in `specs/enterprise-microservices_spec.md`
- Supporting per-tenant Open edX version pinning (all tenants run the same platform version)
- Building a tenant management API (tenants are managed via Django admin and provisioning scripts for v1)
- White-labeling the Open edX admin (Studio/CMS) per tenant (Studio is shared; enterprise admins use the admin portal MFE)

## Assumptions

- The `EnterpriseCustomer` model from the `openedx-enterprise` Django app is the canonical tenant identifier, as defined in `specs/enterprise-microservices_spec.md`
- Open edX's Django Sites framework and `SiteConfiguration` model are functional and can drive per-site (per-tenant) configuration
- The Tutor 21.0.0 (Ulmo) deployment includes the `openedx-enterprise` package in the base image
- The existing Cloud SQL (MySQL 8) instance can support the additional query load from multi-tenant filtering (queryset-level `WHERE enterprise_customer_uuid = ...`)
- MongoDB Atlas (modulestore, forum) does not require per-tenant isolation at v1 because enterprise services handle content access control through the catalog layer
- The existing Caddy reverse proxy can route to tenant-specific domains without per-tenant Caddy configuration (wildcard or multi-domain blocks suffice)
- The existing observability stack (Prometheus, Loki, Tempo) can handle tenant-labeled metrics and log queries without performance degradation at 50 tenants
- Tenant count at launch: 5-10 clients; scaling target: 50+ clients within 12 months

---

## Requirements

### Functional

#### Tenant Identity and Data Model

- The system MUST define a tenant as an `EnterpriseCustomer` record in the LMS database, identified by a globally unique UUID (`enterprise_customer_uuid`)
- The system MUST support a human-readable tenant slug (`enterprise_slug`) for URL-based routing (e.g., `/enterprise/login/{slug}`)
- The system MUST associate each tenant with a Django `Site` record via the `site_id` foreign key on `EnterpriseCustomer`, enabling per-tenant site configuration
- The system MUST support a `SiteConfiguration` record per tenant Django Site, containing tenant-specific settings (theme, branding, feature flags, allowed hosts)
- The system MUST support a tenant having multiple associated domains (e.g., `acme.academyv2.mereka.io` and `learning.acmecorp.com`) mapped to the same Django Site
- The system MUST support a user belonging to multiple tenants simultaneously via `EnterpriseCustomerUser` records, one per tenant-user pair
- The system MUST support `PendingEnterpriseCustomerUser` records for users invited to a tenant but not yet registered in the LMS
- The system MUST maintain a tenant configuration record that includes at minimum: `uuid`, `name`, `slug`, `active` (boolean), `site_id`, `country`, `contact_email`, enterprise IdP linkage slug (via `EnterpriseCustomerIdentityProvider` or legacy `identity_provider`), and all enterprise feature flags enumerated in `specs/enterprise-microservices_spec.md`

#### Tenant Isolation -- Data Segregation

- The system MUST enforce application-level data isolation: every database query in enterprise services and enterprise-scoped LMS views MUST filter by `enterprise_customer_uuid`
- The system MUST NOT use database-level isolation (separate schemas or databases per tenant) for the core LMS database; isolation is at the queryset/ORM level
- Enterprise service databases (enterprise_catalog, license_manager, enterprise_access, enterprise_subsidy) MUST filter all API responses and internal queries by `enterprise_customer_uuid`
- The system MUST ensure that no REST API endpoint returns data belonging to a tenant other than the one identified by the authenticated user's enterprise membership or the explicit `enterprise_customer_uuid` path parameter
- The system MUST prevent direct database joins across tenant boundaries; cross-tenant aggregation MUST only be possible via platform-admin-level queries (superuser)
- Redis cache keys MUST be namespaced by `enterprise_customer_uuid` where the cached data is tenant-specific (e.g., catalog content metadata, license counts)
- The system MUST NOT share Redis cache entries across tenants for tenant-specific data; shared platform data (course metadata not scoped to a tenant) MAY use shared cache keys

##### MongoDB Collection Isolation Model

- Open edX uses a **shared-everything MongoDB model**: all tenants share the same MongoDB databases (`openedx` for modulestore, `cs_comments_service` for forum), with tenant isolation enforced at the **application layer** rather than at the database or collection level
- The system MUST NOT implement per-tenant MongoDB databases or collections; all course data, forum data, and modulestore content reside in shared collections
- Modulestore courses MUST be org-scoped, where the `org` field maps to the tenant; tenant isolation for course access MUST be enforced by the enterprise-catalog layer filtering courses by `org`
- Forum posts MUST be course-scoped; since courses are tenant-scoped via enrollment and catalog assignment, forum data is implicitly tenant-scoped by course membership
- The system MUST NOT rely on MongoDB-level access control (database users, collection-level permissions) for tenant isolation; all database access MUST go through the LMS/forum application layer with Django ORM queryset filtering
- Given a MongoDB query for modulestore data (e.g., finding all courses), the application layer MUST filter by the `org` field to scope results to the requesting tenant
- Given a forum query for discussion threads, the application layer MUST scope results to courses that the requesting tenant has access to via their enterprise catalog and enrollment records
- Cross-tenant forum visibility (where tenants share a course): if two tenants include the same course in their catalogs, learners from both tenants enrolled in that course MAY see each other's forum posts; this is the expected behavior for shared course content. The system SHOULD support per-tenant forum isolation via course duplication (separate course runs per tenant) if a tenant requires private discussions

#### Tenant Isolation -- Authentication and Authorization

- Each tenant MUST support an independent SSO/SAML or OIDC identity provider configuration, as specified in `specs/enterprise-microservices_spec.md`
- SAML authentication for a tenant's IdP MUST link the authenticated user to that specific tenant's `EnterpriseCustomer` record; no cross-tenant IdP linking is permitted
- The system MUST support slug-based login routing: `https://{lms_host}/enterprise/login/{tenant_slug}` MUST redirect to the correct tenant's IdP
- The system MUST enforce role-based access control (RBAC) at the tenant level:
  - `enterprise_admin` role: full administrative access to a specific tenant's resources (licenses, catalogs, learners, channels, analytics)
  - `enterprise_learner` role: learner-level access to a specific tenant's catalog and enrollment features
  - `enterprise_openedx_operator` role (platform admin): cross-tenant administrative access for platform operators only
- The system MUST enforce that an `enterprise_admin` for tenant A cannot access any API endpoint or admin portal view scoped to tenant B
- The system MUST enforce that an `enterprise_learner` for tenant A cannot browse catalogs, view licenses, or access portal features belonging to tenant B
- Multi-org users (belonging to tenants A and B) MUST explicitly select their tenant context in the learner portal; the system MUST NOT aggregate data from multiple tenants into a single view unless the user holds `enterprise_openedx_operator` role
- Session cookies MUST be scoped to the LMS domain (per `specs/multi-site-domains_spec.md`); tenant isolation MUST NOT depend on cookie domain separation but on application-level permission checks
- The system MUST log all cross-tenant access attempts (whether successful or denied) as security events

#### Per-Tenant Branding and Customization

- The system MUST support per-tenant branding overrides via `SiteConfiguration` values, stored as JSON in the `values` field
- Per-tenant branding MUST support overriding at minimum:
  - Logo (horizontal, square, white variants) -- URL paths to tenant-specific static assets
  - Favicon
  - Primary and secondary brand colors (CSS custom properties)
  - Footer content (organization name, tagline, links, contact email)
  - Login page branding (logo, welcome text)
  - Email sender alias and branding
- The base Mereka theme (per `specs/branding-system_spec.md`) MUST serve as the default; tenant-specific overrides MUST layer on top of the base theme, not replace it entirely
- Tenant branding assets (logos, favicons) MUST be stored in a tenant-specific directory within the theme structure: `infrastructure/tutor/themes/mereka/tenants/{tenant_slug}/`
- The system MUST support tenant branding via MFE configuration: the `env.config.jsx` mechanism MUST read `SiteConfiguration` values at runtime to apply tenant-specific styles and logos
- The system SHOULD support a preview mode that allows a platform admin to view the LMS as it would appear to a specific tenant's users, without switching accounts
- Tenant branding changes MUST NOT require a full image rebuild; static asset changes MUST be deployable via `collectstatic` and CDN cache invalidation
- The system MUST ensure that the enterprise admin portal MFE and enterprise learner portal MFE display the correct tenant branding based on the authenticated admin's or learner's enterprise membership

#### Per-Tenant Domain Routing and Site Configuration

- The system MUST support assigning one or more custom domains to a tenant via the Django Sites framework
- Each tenant domain MUST be added to `ALLOWED_HOSTS` and `CSRF_TRUSTED_ORIGINS` in LMS settings (per `specs/multi-site-domains_spec.md`)
- Caddy reverse proxy configuration MUST support routing requests for tenant-specific domains to the LMS, including proper `Host` header forwarding
- The system MUST resolve the correct `SiteConfiguration` for each incoming request based on the `Host` header, enabling per-tenant theme and feature flag resolution
- The system SHOULD support a default tenant domain pattern of `{tenant_slug}.academyv2.mereka.io` for tenants that do not bring their own domain
- The system MUST support client-owned domains (e.g., `learning.acmecorp.com`) via CNAME records pointing to the Mereka LMS load balancer, with SSL certificates managed via Let's Encrypt (per Cloudflare multi-level subdomain rules in CLAUDE.md)
- MFE routing MUST support tenant context: the enterprise learner portal and admin portal MUST detect the tenant from the authenticated user's enterprise membership, not from the domain alone

#### Per-Tenant Analytics and Reporting

- The analytics pipeline (per `specs/analytics-pipeline_spec.md`) MUST tag all xAPI events with the learner's `enterprise_customer_uuid` where applicable
- ClickHouse event storage MUST include an `enterprise_customer_uuid` column (nullable, for non-enterprise learners) on the primary events table
- Superset dashboards MUST support row-level security (RLS) that restricts a tenant admin's view to events tagged with their `enterprise_customer_uuid`
- The system MUST provide per-tenant analytics dashboards covering:
  - Enrollment count and trend
  - Course completion rate
  - License utilization (assigned, activated, revoked)
  - Learner engagement (active learners per week)
  - Subsidy balance burn rate
- The system MUST ensure that a tenant admin querying Superset or the admin portal analytics view cannot access analytics data for any other tenant
- The system SHOULD support tenant analytics data export in CSV/JSON format for tenant admins
- Platform operators (superuser) MUST be able to view cross-tenant aggregate analytics for capacity planning

#### Tenant Provisioning

- The system MUST support a documented, repeatable tenant provisioning workflow that creates all required records for a new tenant
- Tenant provisioning MUST include the following steps (order matters):
  1. Create Django `Site` record with the tenant's primary domain
  2. Create `SiteConfiguration` record with tenant-specific settings (theme, features, branding JSON)
  3. Create `EnterpriseCustomer` record linked to the Django Site, with all enterprise feature flags configured
  4. Create enterprise catalogs with appropriate content filters
  5. Create subscription plans and/or subsidy records
  6. Create access policies linking catalogs to subscriptions/subsidies
  7. Configure SAML/OIDC identity provider (if applicable)
  8. Configure integrated channel connections (if applicable)
  9. Deploy tenant-specific branding assets (logos, favicon) to the theme directory
  10. Run `collectstatic` to publish tenant assets
  11. Add tenant domain to Caddy configuration and `ALLOWED_HOSTS`
  12. Verify tenant isolation by running the cross-tenant isolation test suite
- The system MUST provide a provisioning script (`scripts/tenants/provision-tenant.sh`) that automates steps 1-6 via Django management commands or direct API calls
- The provisioning script MUST be idempotent: running it twice for the same tenant MUST NOT create duplicate records
- The system MUST validate all provisioning inputs before creating any records (fail-fast on invalid slug, duplicate domain, etc.)

#### Tenant Offboarding

- The system MUST support a documented tenant offboarding workflow
- Tenant offboarding MUST include:
  1. Data export: generate a complete export of the tenant's data (learner records, enrollment data, completion data, license assignments, subsidy transactions, analytics events) in a format agreed upon with the tenant
  2. Deactivation: set `EnterpriseCustomer.active = False`, disabling all enterprise features for the tenant
  3. SSO disablement: disable the tenant's SAML/OIDC provider configuration
  4. Integrated channel disablement: disable all channel sync tasks for the tenant
  5. Grace period: maintain deactivated state for 30 days to allow data retrieval
  6. Data deletion: after the grace period, delete all tenant-specific records from enterprise service databases, ClickHouse analytics, and Redis caches
  7. Branding cleanup: remove tenant-specific assets from the theme directory
  8. Domain removal: remove tenant domains from Caddy, `ALLOWED_HOSTS`, and `CSRF_TRUSTED_ORIGINS`
- The system MUST log all offboarding actions for audit purposes
- Data deletion MUST be verifiable: a post-deletion verification script MUST confirm zero records remain for the offboarded tenant UUID across all data stores

#### Cross-Tenant Isolation Verification

- The system MUST include an automated isolation test suite (`scripts/qa/verify-tenant-isolation.sh`) that validates:
  - API-level isolation: authenticate as tenant A admin, attempt to access tenant B resources, verify HTTP 403 on all enterprise API endpoints
  - Portal-level isolation: authenticate as tenant A admin in the admin portal, verify zero records from tenant B appear in any view
  - Analytics isolation: query ClickHouse as tenant A, verify zero events from tenant B are returned
  - Search isolation: query enterprise catalog search as tenant A, verify zero results from tenant B catalogs
- The isolation test suite MUST be run as part of the tenant provisioning workflow (step 12)
- The isolation test suite SHOULD be run nightly as a scheduled job to detect regressions
- The isolation test suite MUST log all test results with timestamps for audit purposes

### Non-Functional Requirements

#### Performance

- Adding a tenant MUST NOT degrade p95 latency for existing tenants' API calls by more than 5%
- The `enterprise_customer_uuid` column MUST be indexed on all enterprise service database tables that are filtered by tenant
- Redis cache hit rates for tenant-specific data SHOULD remain above 90% under normal operation
- The platform MUST support at least 50 concurrent active tenants without exceeding the latency thresholds defined in `specs/enterprise-microservices_spec.md`
- Tenant provisioning MUST complete within 15 minutes for automated steps (excluding manual branding asset creation)
- ClickHouse queries scoped to a single tenant MUST NOT scan data from other tenants (partition pruning or index-based filtering required)

#### Security

- All tenant isolation MUST be enforced at the application layer (Django ORM queryset filtering, API permission classes); it MUST NOT rely solely on frontend UI restrictions
- Cross-tenant data leakage MUST be treated as a P0 security incident with immediate response
- Tenant admin API tokens MUST be scoped to a single `enterprise_customer_uuid`; tokens MUST NOT grant cross-tenant access
- The system MUST NOT log tenant-specific PII (learner emails, names) in shared log streams; logs MUST use hashed identifiers (per `specs/enterprise-microservices_spec.md`)
- SAML private keys MUST be per-tenant and stored in K8s secrets via ExternalSecrets (per `specs/secrets-management_spec.md`)
- The system MUST enforce that Django management commands that operate on tenant data require an explicit `--enterprise-customer-uuid` argument to prevent accidental cross-tenant operations

#### Compliance and Audit

- The system MUST maintain an audit log of all tenant provisioning and offboarding actions, including: action type, tenant UUID, actor (admin user), timestamp, and outcome (success/failure)
- The system MUST support data export for any tenant within 5 business days of a request (PDPA/GDPR data portability)
- The system MUST support data deletion for a deactivated tenant within 30 days (PDPA/GDPR right to erasure)
- The system MUST maintain tenant-level access logs: every API request to enterprise services MUST log the `enterprise_customer_uuid`, `user_id_hash`, `endpoint`, `method`, `status_code`, and `timestamp`
- The system SHOULD support generating a tenant isolation compliance report on demand, showing the results of the latest isolation test suite run

#### Scalability

- The shared MySQL database architecture MUST support 50+ tenants without requiring database sharding at v1
- If query performance degrades below acceptable thresholds at high tenant counts, the system SHOULD support horizontal read replicas for enterprise service databases
- The system SHOULD support a migration path from shared-database to per-tenant-database isolation if regulatory or client requirements demand it in the future (this is a non-goal for v1 but the schema design should not preclude it)

### EnterpriseCustomer Canonical Schema (v1.1.0)

This section defines the canonical data model for the `EnterpriseCustomer` entity. All specs referencing enterprise tenant data MUST use this schema as the single source of truth. Individual specs SHOULD NOT redefine these fields; they SHOULD reference this section.

**Model version: 1.1.0** — canonical schema, referenced by all service specs

| Field | Type | Source Spec | Description |
|-------|------|-------------|-------------|
| `uuid` | UUID (primary key) | multi-tenancy-architecture | Globally unique tenant identifier; canonical tenant boundary for all enterprise services |
| `name` | string | enterprise-microservices | Display name for the enterprise organization |
| `slug` | string (unique) | multi-tenancy-architecture | URL-safe identifier for tenant-specific routing (e.g., `/enterprise/login/{slug}`) |
| `active` | boolean | multi-tenancy-architecture | Whether the tenant is currently active; `False` disables all enterprise features for this tenant |
| `site_id` | FK (Django Site) | multi-tenancy-architecture | Link to Django Site record for per-tenant site configuration and domain routing |
| `country` | string (ISO 3166-1) | multi-tenancy-architecture | Tenant's primary country code (for compliance, data residency planning, analytics) |
| `contact_email` | email | multi-tenancy-architecture | Primary contact email for tenant (ops notifications, billing alerts) |
| `identity_provider` (legacy) / `EnterpriseCustomerIdentityProvider.provider_id` (preferred) | string (IdP slug linkage) | auth-sso-enterprise | SAML/OIDC identity provider slug linking to the tenant's SSO configuration |
| `enable_data_sharing_consent` | boolean | enterprise-microservices | Whether the data sharing consent (DSC) framework is enabled for this tenant |
| `enforce_data_sharing_consent` | boolean | enterprise-microservices | Whether DSC is required before enrollment completion data is visible to the tenant admin |
| `enable_audit_enrollment` | boolean | enterprise-microservices | Whether learners can enroll in audit mode (free) for tenant-subsidized courses |
| `enable_audit_data_reporting` | boolean | enterprise-microservices | Whether audit-mode enrollment data is reported to the tenant (typically disabled) |
| `hide_course_original_price` | boolean | enterprise-microservices | Whether to hide the course's list price in the learner portal (enterprise-subsidized courses) |
| `enable_portal_code_management_screen` | boolean | enterprise-microservices | Whether enterprise admins can manage coupon codes in the admin portal |
| `enable_learner_portal` | boolean | enterprise-microservices | Whether the enterprise learner portal is enabled for this tenant |
| `enable_integrated_customer_learner_portal_search` | boolean | enterprise-microservices | Whether enterprise catalog search is enabled in the learner portal |
| `enable_analytics_screen` | boolean | enterprise-microservices | Whether the analytics dashboard is enabled in the admin portal for this tenant |
| `sender_alias` | string | enterprise-microservices | Email sender alias for tenant-specific system emails (e.g., "Acme Learning Team") |
| `enable_slug_login` | boolean | auth-sso-enterprise | Whether slug-based login routing (`/enterprise/login/{slug}`) is enabled for this tenant |
| `branding_logo_url` | URL | badges-credentials-enterprise | Tenant's primary logo URL (used in badge issuer profiles, emails, and portal branding; referenced in specs/badges-credentials-enterprise_spec.md) |
| `webhook_urls` | JSON (list of URLs) | badges-credentials-enterprise | Webhook endpoints for badge events (`badge_issued`, `badge_revoked`, etc.); used by badge system (referenced in specs/badges-credentials-enterprise_spec.md) |
| `issuer_profile` | JSON | badges-credentials-enterprise | Badge issuer profile metadata (name, description, email, logo) for OpenBadges assertions |
| `stripe_connect_account_id` | string | ecommerce-purchase-gateway | Stripe Connect account ID for tenant-specific payment processing (if using Stripe Connect multi-tenant billing; referenced in specs/ecommerce-purchase-gateway_spec.md) |

**Notes**:
- Fields marked with `(FK)` are foreign keys or references to other models.
- Additional tenant-specific configuration (SSO SAML metadata, catalog filters, access policies) is stored in related models (`SAMLProviderConfig`, `EnterpriseCatalog`, `SubsidyAccessPolicy`) linked via `enterprise_customer_uuid`.
- Feature flags listed here are Django model fields on `EnterpriseCustomer`. Platform-wide feature flags (e.g., `ENABLE_ENTERPRISE_LEARNER_PORTAL`) are separate environment settings.
- This schema is version-controlled. Breaking changes to these fields MUST be documented as a schema version increment (e.g., v2.0) and communicated across all dependent specs.
- Specs that add new `EnterpriseCustomer` fields MUST update this canonical schema and increment the version number.

### Terminology Glossary

This section defines canonical terms used throughout the multi-tenancy architecture and related specs. All specs referencing these concepts MUST use the terms as defined here.

| Term | Definition | Canonical Reference |
|------|------------|-------------------|
| EnterpriseCustomer | The Django model representing a tenant organization in the Open edX enterprise system. The `uuid` field is the globally unique, canonical tenant identifier used for data segregation, API scoping, and analytics tagging across all enterprise services | enterprise-microservices_spec.md |
| Tenant | An organization (represented by an `EnterpriseCustomer` record) that subscribes to the Mereka Academy platform. Each tenant receives a branded, isolated learning environment with its own user population, course catalog, licenses, subsidies, SSO configuration, and analytics scope. Synonyms: "enterprise client", "client organization", "enterprise", "org" | multi-tenancy-architecture_spec.md |
| Site | A Django `Site` model record mapping one or more domain names to tenant-specific configuration. Each `EnterpriseCustomer` links to a `Site` via the `site_id` foreign key, enabling per-tenant domain routing, theme resolution, and feature flag configuration via the associated `SiteConfiguration` | multi-site-domains_spec.md |
| Learner | An individual user (Django `User` model) enrolled in one or more courses on the platform. A learner may belong to zero, one, or multiple tenants simultaneously via `EnterpriseCustomerUser` link records. Non-enterprise learners (individual enrollments) are not linked to any tenant | auth-sso-enterprise_spec.md |
| Catalog | A curated collection of courses (`EnterpriseCatalog` model) available to a specific tenant. Catalogs are content-filtered subsets of the full course library, scoped by `enterprise_customer_uuid`. Learners see only courses from catalogs assigned to their tenant(s) | enterprise-microservices_spec.md |
| Entitlement | A purchased or allocated right for a learner to enroll in a specific course or program, represented by the `CourseEntitlement` model. Entitlements may be transferable (assignable to different learners) or non-transferable (bound to a specific learner). Enterprise-subsidized entitlements are managed via the subsidy service | ecommerce-purchase-gateway_spec.md |

**Notes**:
- These definitions establish the **single source of truth** for architectural concepts. Specs SHOULD NOT redefine these terms.
- When a spec introduces a new architectural concept that will be referenced across multiple specs, it SHOULD be added to this glossary.
- Synonyms are provided for common alternate terms, but specs SHOULD prefer the canonical term listed in the "Term" column.

---

## Acceptance Criteria

### Tenant Identity

- [ ] AC-MTA-001: Given a new enterprise client "Acme Corp", when the provisioning script runs with `--slug=acme-corp --name="Acme Corp" --domain=acme.academyv2.mereka.io`, then an `EnterpriseCustomer` record is created with a unique UUID, a Django `Site` with the specified domain, and a `SiteConfiguration` with Mereka default values
- [ ] AC-MTA-002: Given tenant "Acme Corp" exists, when the provisioning script runs again with the same slug, then no duplicate records are created and the script exits with a success message indicating "already provisioned"

### Data Isolation

- [ ] AC-MTA-003: Given tenant A (Acme) and tenant B (Beta), when admin A calls `GET /api/v1/enterprise-catalogs/`, then zero catalogs belonging to tenant B are returned
- [ ] AC-MTA-004: Given tenant A and tenant B, when admin A calls `GET /api/v1/subscriptions/` with tenant B's UUID in the path, then the response is HTTP 403
- [ ] AC-MTA-005: Given tenant A and tenant B, when admin A queries ClickHouse analytics via Superset, then zero xAPI events with tenant B's UUID are visible
- [ ] AC-MTA-006: Given tenant A and tenant B, when a raw SQL query `SELECT * FROM enterprise_enterprisecustomer` is executed by a non-superuser database role, then only the requesting service's scoped records are returned (database user grants prevent cross-schema access for enterprise service databases)
- [ ] AC-MTA-007: Given a learner belonging to both tenant A and tenant B, when they log into the enterprise learner portal and select tenant A, then only tenant A's catalog, licenses, and enrollment data are visible

### Branding

- [ ] AC-MTA-008: Given tenant "Acme Corp" with a custom logo configured in `SiteConfiguration`, when a learner navigates to `acme.academyv2.mereka.io`, then the Acme Corp logo is displayed (not the default Mereka logo)
- [ ] AC-MTA-009: Given tenant "Acme Corp" with custom brand colors configured, when the login page loads at `acme.academyv2.mereka.io`, then the primary brand color matches the configured value
- [ ] AC-MTA-010: Given tenant "Acme Corp" with a custom footer configured, when any page loads, then the footer displays Acme Corp branding (not default Mereka footer)
- [ ] AC-MTA-011: Given a tenant branding asset update (new logo), when `collectstatic` is run, then the updated logo is served without requiring an image rebuild

### Domain Routing

- [ ] AC-MTA-012: Given tenant "Acme Corp" with domain `acme.academyv2.mereka.io`, when a browser requests that domain, then the LMS responds with the correct Acme-branded page
- [ ] AC-MTA-013: Given tenant "Acme Corp" with a client-owned domain `learning.acmecorp.com` configured as a CNAME, when a browser requests that domain, then the LMS responds with the correct Acme-branded page and a valid SSL certificate
- [ ] AC-MTA-014: Given two tenants with different domains, when requests arrive simultaneously for both domains, then each request resolves the correct `SiteConfiguration` based on `Host` header

### Authentication

- [ ] AC-MTA-015: Given tenant "Acme Corp" with SAML IdP configured, when a user navigates to `/enterprise/login/acme-corp`, then they are redirected to Acme's IdP
- [ ] AC-MTA-016: Given a successful SAML assertion from Acme's IdP for a new user, when processed, then the user is auto-provisioned and linked to the Acme `EnterpriseCustomer`
- [ ] AC-MTA-017: Given tenant A's IdP and tenant B's IdP, when a user authenticates via tenant A's IdP, then they are linked to tenant A only (no cross-tenant linking from the SAML flow)

### Analytics

- [ ] AC-MTA-018: Given tenant "Acme Corp" with enrolled learners, when a learner completes a course, then the xAPI event in ClickHouse includes `enterprise_customer_uuid` matching Acme's UUID
- [ ] AC-MTA-019: Given tenant "Acme Corp" admin in Superset, when they query the enrollment dashboard, then row-level security filters ensure only Acme's data is visible
- [ ] AC-MTA-020: Given platform operator (superuser) in Superset, when they query the cross-tenant overview dashboard, then aggregate data from all tenants is visible

### Provisioning and Offboarding

- [ ] AC-MTA-021: Given valid provisioning inputs, when `scripts/tenants/provision-tenant.sh` runs, then all required records (Site, SiteConfiguration, EnterpriseCustomer, catalogs, subscriptions, access policies) are created within 15 minutes
- [ ] AC-MTA-022: Given tenant "Acme Corp" is offboarded, when the offboarding script completes data deletion, then `SELECT count(*) FROM enterprise_catalog WHERE enterprise_customer_uuid = '{acme_uuid}'` returns 0 across all enterprise service databases
- [ ] AC-MTA-023: Given tenant "Acme Corp" is offboarded, when ClickHouse is queried, then zero events with Acme's UUID exist
- [ ] AC-MTA-024: Given a tenant offboarding action, when it completes, then an audit log entry exists with: tenant UUID, action "offboarded", actor, timestamp

### Isolation Verification

- [ ] AC-MTA-025: Given tenants A and B are provisioned, when `scripts/qa/verify-tenant-isolation.sh --tenant-a={uuid_a} --tenant-b={uuid_b}` runs, then all isolation checks pass (API, portal, analytics, search)
- [ ] AC-MTA-026: Given the nightly isolation test job runs, when any isolation check fails, then a Critical alert is fired to the oncall channel

### Performance

- [ ] AC-MTA-027: Given 10 active tenants, when enterprise catalog API queries are benchmarked, then p95 latency remains <= 300ms (per enterprise-microservices spec)
- [ ] AC-MTA-028: Given 50 active tenants simulated in a load test, when concurrent API requests are sent from 50 different tenant contexts, then no tenant's p95 latency exceeds 120% of the single-tenant baseline

### Cross-Tenant Isolation

- [ ] AC-MTA-029: Given Tenant A's admin is authenticated, when they attempt to access Tenant B's learner data via API, then HTTP 403 is returned
- [ ] AC-MTA-030: Given Tenant A's learner data exists in the database, when Tenant B's admin queries the API, then zero records from Tenant A are returned
- [ ] AC-MTA-031: Given Tenant A sends a webhook event, when the webhook payload is inspected, then it contains ONLY Tenant A's data (no cross-tenant leakage)
- [ ] AC-MTA-032: Given Tenant A's admin queries the enterprise catalog API, when the response is returned, then zero courses from Tenant B's private catalog are visible
- [ ] AC-MTA-033: Given Tenant A's admin attempts to assign a license from Tenant B's subscription plan, when the API processes the request, then HTTP 403 is returned

---

## Edge Cases

### Tenant Provisioning Failures

- **Partial provisioning**: If the provisioning script fails midway (e.g., after creating the EnterpriseCustomer but before creating catalogs), the script MUST support resumption. On re-run, it MUST skip already-created records (idempotency) and continue from the point of failure. All provisioning steps MUST be individually idempotent
- **Duplicate slug**: If a provisioning request uses a slug that already belongs to another tenant, the system MUST reject the request with a clear error before creating any records
- **Duplicate domain**: If a provisioning request assigns a domain already mapped to another Django Site, the system MUST reject the request. One domain can belong to only one Site/tenant
- **Invalid SAML metadata**: If the tenant's SAML IdP metadata URL returns an error during provisioning, the system MUST log the error, skip the SAML configuration step, and list it as a pending action in the provisioning report (not a hard failure)

### Cross-Tenant User Operations

- **User moves between tenants**: If a user is removed from tenant A and added to tenant B, their LMS account persists but their enterprise membership changes. Enrollments created under tenant A's subsidy remain active (LMS enrollments are not tenant-scoped) but license utilization for tenant A is updated
- **Multi-org user context confusion**: If a multi-org user accesses the enterprise learner portal without selecting a tenant context, the system MUST present a tenant selection screen listing all their active enterprise memberships. The system MUST NOT default to any tenant
- **Admin attempts cross-tenant user lookup**: If tenant A admin searches for a user by email and that user belongs to tenant B (but not A), the system MUST return "user not found" (not "user exists in another tenant") to prevent enumeration attacks
- **Pending user invited by multiple tenants**: If the same email address has `PendingEnterpriseCustomerUser` records for tenants A and B, when the user registers, both pending records MUST be resolved and the user MUST be linked to both tenants

### Data Isolation Edge Cases

- **Shared course content**: If tenants A and B both include the same course in their catalogs, enrollment data MUST be segregated: tenant A's admin sees only learners enrolled through tenant A's subscription/subsidy, even though the underlying LMS enrollment is shared. Completion data visible to each admin is filtered by `EnterpriseCustomerUser` membership
- **Redis cache poisoning**: If a bug causes a cache key collision between tenants (e.g., missing UUID namespace), the worst case is a tenant seeing stale or incorrect catalog data. The system MUST prefix all tenant-specific cache keys with the `enterprise_customer_uuid` to prevent this. Cache keys MUST follow the format: `enterprise:{uuid}:{key_type}:{key_id}`
- **ClickHouse query without tenant filter**: If a Superset query omits the `enterprise_customer_uuid` filter (e.g., a misconfigured dashboard), row-level security MUST block the query for non-superusers. The system MUST NOT allow unfiltered queries from tenant admin contexts
- **MongoDB forum data visibility**: If tenants A and B share a course with forum discussions, learners from both tenants can see each other's forum posts (forum threads are course-scoped, not tenant-scoped). This is the expected behavior for shared courses. If a tenant requires private forum threads, the course MUST be duplicated (separate course runs per tenant)

### Branding Edge Cases

- **Missing tenant branding assets**: If a tenant's logo file is missing from the theme directory, the system MUST fall back to the default Mereka logo (per `specs/branding-system_spec.md`). The system MUST NOT display a broken image or error
- **Branding cache stale after update**: If a tenant's branding is updated but the CDN/browser cache serves the old version, the system MUST support cache invalidation via `collectstatic --clear` and a CDN purge. Tenant branding URLs SHOULD include a version hash or timestamp for cache busting
- **SiteConfiguration invalid JSON**: If a tenant's `SiteConfiguration.values` field contains malformed JSON, the system MUST fall back to Mereka default configuration for that tenant and log an error. The system MUST NOT crash or serve 500 errors to the tenant's users

### Authentication Edge Cases

- **IdP down**: If a tenant's SAML IdP is unreachable, the system MUST display a clear error message to the user ("Your organization's login service is temporarily unavailable") rather than a generic 500 error. The system MUST NOT redirect to a different tenant's IdP
- **SAML assertion for wrong tenant**: If a SAML assertion arrives at the generic ACS endpoint but the `issuer` does not match any configured tenant IdP, the system MUST reject the assertion and log a security event
- **Concurrent IdP metadata refresh**: If multiple tenants' IdP metadata refresh jobs run simultaneously, they MUST NOT interfere with each other. Each refresh MUST be scoped to a single IdP entity ID

### Offboarding Edge Cases

- **Offboarding tenant with active enrollments**: If a tenant is offboarded but learners have active LMS enrollments, the enrollments MUST NOT be automatically revoked (enrollments are LMS-level, not tenant-level). The enterprise membership is removed, but the learner retains access to courses they were enrolled in (unless explicitly revoked in the offboarding workflow)
- **Offboarding tenant with integrated channel sync pending**: If a tenant is offboarded while a channel sync is in progress, the system MUST cancel the pending sync task and mark it as "cancelled - tenant offboarded" in the sync log
- **Data deletion race condition**: If a data deletion job is running for tenant A while new data arrives (e.g., a delayed event bus message), the deletion job MUST re-scan after completion to catch late-arriving records. The system MUST verify zero records remain after the final pass

### Rate Limiting

- Tenant-scoped API rate limits (per `specs/enterprise-microservices_spec.md`) MUST be enforced independently per tenant: one tenant hitting its rate limit MUST NOT affect another tenant's API access
- Internal service-to-service calls MUST use the elevated rate limit tier regardless of tenant context (per enterprise-microservices spec)

---

## Observability

### Logs

- **Tenant context in all logs**: Every log line from enterprise services and tenant-scoped LMS views MUST include the `enterprise_customer_uuid` field. Platform-level logs (non-tenant-scoped) MUST omit this field (not set it to null or empty)
- **Provisioning audit log**: All tenant provisioning actions MUST be logged with: `action` (provision, update, deactivate, offboard, delete), `enterprise_customer_uuid`, `enterprise_slug`, `actor_user_id`, `timestamp`, `details` (JSON of what was created/changed), `outcome` (success, failure, partial)
- **Isolation violation log**: Any request that is denied due to cross-tenant access attempt MUST be logged as a security event with: `requesting_user_id_hash`, `requesting_enterprise_uuid`, `target_enterprise_uuid`, `endpoint`, `method`, `timestamp`
- **Branding resolution log**: When the system resolves tenant branding from `SiteConfiguration`, it SHOULD log (at DEBUG level): `enterprise_customer_uuid`, `site_id`, `resolved_theme`, `fallback_used` (boolean)
- **Sensitive data rule**: Per `specs/enterprise-microservices_spec.md`, logs MUST NOT contain raw email addresses, SAML assertions, API keys, or database passwords

### Metrics

- `tenant_count_active` (gauge) -- number of active `EnterpriseCustomer` records where `active=True`
- `tenant_count_total` (gauge) -- total `EnterpriseCustomer` records including deactivated
- `tenant_user_count` (gauge, labels: `enterprise_customer_uuid`) -- number of `EnterpriseCustomerUser` records per tenant
- `tenant_api_requests_total` (counter, labels: `enterprise_customer_uuid`, `service_name`, `endpoint`, `status_code`) -- API request volume per tenant per service
- `tenant_api_latency_seconds` (histogram, labels: `enterprise_customer_uuid`, `service_name`, `endpoint`) -- API latency per tenant per service
- `tenant_isolation_check_result` (gauge, labels: `test_name`, `outcome` [pass, fail]) -- result of the latest isolation test suite run
- `tenant_provisioning_duration_seconds` (histogram) -- time to complete tenant provisioning
- `tenant_offboarding_duration_seconds` (histogram) -- time to complete tenant offboarding
- `tenant_branding_fallback_total` (counter, labels: `enterprise_customer_uuid`) -- number of times branding fell back to Mereka default (indicates misconfiguration)
- All enterprise service metrics defined in `specs/enterprise-microservices_spec.md` MUST include the `enterprise_customer_uuid` label

### Alerts

- **Critical**: `tenant_isolation_check_result{outcome="fail"}` for any test name -- immediate investigation required (potential data leakage)
- **Critical**: `tenant_api_requests_total` with `status_code=403` and `endpoint` matching cross-tenant access pattern exceeds 10 in 5 minutes for any user -- potential attack or misconfiguration
- **Warning**: `tenant_branding_fallback_total` increases for any tenant -- branding misconfiguration, investigate `SiteConfiguration`
- **Warning**: `tenant_api_latency_seconds` p95 exceeds 120% of baseline for any tenant -- potential noisy neighbor issue
- **Info**: `tenant_count_active` changes -- new tenant provisioned or tenant deactivated

### Dashboards

- **Multi-Tenancy Overview**: Active tenant count, total users per tenant, API request volume per tenant, latest isolation test results, provisioning/offboarding activity log
- **Tenant Health**: Per-tenant API latency (p50, p95, p99), error rate, cache hit rate, license utilization, subsidy balance, branding fallback count
- **Noisy Neighbor Detection**: API request volume and latency distributions across tenants, identifying tenants whose workload disproportionately affects shared infrastructure
- **Isolation Compliance**: Historical isolation test results, cross-tenant access denial log, provisioning/offboarding audit trail

---

## Rollout & Rollback

### Rollout Plan

#### Phase 0: Foundation (Week 1-2)

1. Implement tenant-scoped Redis cache key namespacing (`enterprise:{uuid}:...` prefix)
2. Add `enterprise_customer_uuid` column to ClickHouse xAPI events table (nullable, backfill later)
3. Create provisioning script skeleton (`scripts/tenants/provision-tenant.sh`) with idempotent Django management command wrappers
4. Create isolation test suite skeleton (`scripts/qa/verify-tenant-isolation.sh`)
5. Define Superset row-level security policies for tenant-scoped dashboards
6. Create tenant branding directory structure (`infrastructure/tutor/themes/mereka/tenants/`)

#### Phase 1: First Tenant -- Mereka Default (Week 3-4)

1. Provision "Mereka Academy" as the first `EnterpriseCustomer` (self-tenant representing the platform default)
2. Link existing Django Site (`academyv2.mereka.io`) to the Mereka enterprise customer
3. Verify all existing functionality continues to work (regression test)
4. Tag existing xAPI events in ClickHouse with the Mereka enterprise customer UUID (backfill migration)
5. Run isolation test suite (single-tenant baseline: no cross-tenant checks, but verify the framework works)

#### Phase 2: Second Tenant -- Pilot Client (Week 5-7)

1. Provision the first external client tenant using the provisioning script
2. Deploy client-specific branding assets
3. Configure client SSO/SAML integration
4. Create client catalog with content filters
5. Create client subscription plan and access policies
6. Run isolation test suite with two tenants (full cross-tenant verification)
7. Verify per-tenant analytics in Superset
8. Verify per-tenant admin portal and learner portal

#### Phase 3: Operational Hardening (Week 8-10)

1. Enable nightly isolation test job
2. Enable all multi-tenancy observability alerts and dashboards
3. Load test with 10 simulated tenants
4. Document tenant provisioning runbook
5. Document tenant offboarding runbook
6. Onboard 2-3 additional pilot clients
7. Implement tenant offboarding workflow and test with a decommissioned test tenant

#### Phase 4: Scale (Week 11+)

1. Load test with 50 simulated tenants
2. Tune database indexes and Redis caching based on multi-tenant query patterns
3. Evaluate ClickHouse partitioning by `enterprise_customer_uuid` for query performance
4. Consider read replicas if Cloud SQL query latency degrades
5. Onboard production enterprise clients

### Feature Flags

- `ENABLE_MULTI_TENANT_BRANDING` -- gate per-tenant branding resolution from `SiteConfiguration` (default: off; enable after Phase 1)
- `ENABLE_TENANT_ANALYTICS_SCOPING` -- gate xAPI event tagging with `enterprise_customer_uuid` (default: off; enable after Phase 0 step 2)
- `ENABLE_TENANT_PROVISIONING_SCRIPT` -- gate the provisioning script (default: off; enable after Phase 1)
- `ENABLE_NIGHTLY_ISOLATION_TESTS` -- gate the nightly isolation test cron job (default: off; enable after Phase 3 step 1)
- All enterprise service feature flags from `specs/enterprise-microservices_spec.md` remain applicable and are consumed by this spec

### Backward Compatibility

- Enabling multi-tenancy MUST NOT affect existing non-enterprise learner workflows (individual enrollment, course browsing, learner dashboard)
- The existing Mereka Academy branding (per `specs/branding-system_spec.md`) MUST remain the default for users not associated with any enterprise customer
- The existing multi-site domain configuration (per `specs/multi-site-domains_spec.md`) MUST continue to work; tenant domains are additive
- All existing specs' acceptance criteria MUST continue to pass after multi-tenancy is enabled
- Existing Django admin workflows for managing `EnterpriseCustomer` records MUST continue to work alongside the provisioning script

### Rollback Steps

#### Disable Per-Tenant Branding

1. Set `ENABLE_MULTI_TENANT_BRANDING=false` in LMS settings
2. All tenants will see the default Mereka branding
3. No data loss; tenant `SiteConfiguration` records are preserved
4. Re-enable when branding issues are resolved

#### Disable Tenant Analytics Scoping

1. Set `ENABLE_TENANT_ANALYTICS_SCOPING=false` in analytics pipeline configuration
2. New xAPI events will be written without `enterprise_customer_uuid` tagging
3. Existing tagged events are preserved in ClickHouse
4. Superset dashboards will show unscoped data until re-enabled

#### Full Multi-Tenancy Rollback

1. Disable all multi-tenancy feature flags
2. Enterprise services continue to operate (they have their own feature flags per `specs/enterprise-microservices_spec.md`)
3. Tenant-specific branding reverts to Mereka default
4. Tenant-specific analytics scoping is disabled (all data visible to superusers only)
5. Tenant-specific domains continue to resolve to the LMS (Django Sites still active) but without tenant-specific customization
6. No data is deleted; tenants can be re-enabled by toggling flags back on

#### Emergency: Suspected Cross-Tenant Data Leak

1. Immediately disable the affected service's API by scaling its Deployment to 0 replicas
2. Notify the security team and affected tenant admins
3. Capture logs from the past 1 hour for the affected service
4. Run the isolation test suite manually to identify the scope of the leak
5. Apply fix and redeploy
6. Run the full isolation test suite to verify the fix
7. File a P0 incident report with root cause analysis

---

## Open Questions

1. **Tenant branding delivery mechanism**: Should per-tenant branding be delivered via (a) `SiteConfiguration` JSON read at runtime by MFEs, (b) separate static asset bundles per tenant deployed alongside the main build, or (c) a tenant-config API endpoint that MFEs call on load? Option (a) is simplest but may not support deep CSS customization. Option (b) is the most flexible but requires a build-per-tenant. Option (c) is a middle ground. Need UX and engineering input.

2. **MongoDB courseware isolation**: Should we implement per-tenant partitioning in MongoDB for the modulestore? Currently, courseware is shared and access is controlled at the catalog layer. If a tenant requires that their course content itself (not just enrollment data) is invisible to other tenants at the database level, MongoDB partitioning would be needed. This significantly increases complexity. Need business requirement clarification.

3. **Forum thread isolation for shared courses**: If two tenants share the same course, their learners can currently see each other's forum posts. Should we implement tenant-scoped forum threads (requires `cs_comments_service` modification or per-tenant course duplication)? Need product decision.

4. **ClickHouse partitioning strategy**: Should the xAPI events table be partitioned by `enterprise_customer_uuid` (improves per-tenant query performance) or by date (improves time-range queries)? Or both (composite partition key)? Need performance benchmarking with realistic tenant counts.

5. **Tenant admin self-service branding**: Should tenant admins be able to upload their own logos and configure brand colors via the admin portal MFE, or should branding changes require platform operator intervention? Self-service reduces operational burden but requires a file upload + validation pipeline. Need product decision.

6. **Data residency**: Some enterprise clients may require that their data resides in a specific geographic region (e.g., EU, Malaysia). The current architecture runs everything in `asia-southeast1`. Supporting data residency would require multi-region deployment or per-tenant database routing. This is explicitly a non-goal for v1, but should we document the migration path now? Need compliance team input.

7. **Tenant SLA tiers**: Should different tenants have different SLA tiers (e.g., premium tenants get higher rate limits, dedicated cache pools, priority support)? If so, this would affect the observability and alerting configuration. Need commercial input.

8. **Cost attribution**: How should infrastructure costs be attributed to individual tenants for billing purposes? Options: (a) proportional to user count, (b) proportional to API request volume, (c) flat fee per tenant, (d) metered usage. This affects observability requirements (need per-tenant resource consumption metrics). Need finance input.

9. **Tenant-level backup and restore**: Should the system support restoring a single tenant's data from backup without affecting other tenants? The current Cloud SQL backup is instance-level. Per-tenant logical backups would require additional tooling. Need disaster recovery requirements.

10. **Cross-tenant superuser audit**: Platform operators (superusers) can access all tenant data. Should superuser cross-tenant access be gated behind additional verification (e.g., break-glass procedure, time-limited elevated access) to prevent accidental or malicious cross-tenant data exposure? Need security policy input.
