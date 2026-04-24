# Tenant / Domain / Surface Authority

> Canonical reference for entities, domains, surfaces, and ownership across the Mereka LMS platform.
>
> **Purpose**: A new operator reads this once and stops being confused.
>
> **Source of truth chain**:
> - `deploy/k8s/tenancy/tenant-registry.yaml` — domains, routing, proof priority
> - `infrastructure/tenants/tenant-contracts.yml` — tenant metadata, provisioning input
> - `infrastructure/tutor/multisite-sites.yml` — Open edX Site records (prod)
> - This document — human-readable summary + surface mapping

## Core Concepts

| Concept | Definition | Record Type |
|---------|-----------|-------------|
| **Platform operator** | The entity that owns the infrastructure, shared services, and primary deployment. Currently: Mereka Academy. | N/A (organizational) |
| **Tenant** | A branded entity with first-class application-layer records. Every tenant has a Django `Site`, `SiteConfiguration`, `EnterpriseCustomer`, and `TenantConfig`. Per ADR-024, tenants are NOT vanity aliases. | `EnterpriseCustomer` + `Site` + `SiteConfiguration` + `TenantConfig` |
| **Open edX Site** | Django `django.contrib.sites.Site` record mapping a domain to tenant-scoped configuration. Drives `SiteConfiguration` lookup on every request. | `Site.domain` |
| **Enterprise Customer** | `enterprise.EnterpriseCustomer` record. Scopes catalogs, enrollments, user links, and portal access. Every tenant is one. | `EnterpriseCustomer.slug` / `.uuid` |
| **Enterprise slug** | URL-safe identifier for enterprise features. Used in portal URL paths (`/:slug/`) and API scoping. | `EnterpriseCustomer.slug` |
| **Surface** | A user-facing application accessed via a domain. Surfaces include LMS, Studio, MFE, enterprise portals, and Django admin. | Deployment + domain |

## Entity / Tenant Table

| Property | Mereka Academy | Biji-Biji Initiative | Skill Our Future |
|----------|---------------|---------------------|-----------------|
| **Role** | Platform operator + primary tenant | Partner tenant | Partner tenant |
| **Tenant slug** | `mereka` | `biji-biji` (registry) / `bijibiji` (contract) | `skillourfuture` |
| **Org code** | `MEREKA` | `BIJIBIJI` | `SKILLOURFUTURE` |
| **Enterprise Customer exists?** | **LIKELY MISSING** | Yes | Yes |
| **Enterprise Customer Catalog?** | **No** | **No** | **No** |
| **Course count (org)** | 109 | 0 | 0 |
| **Country** | MY | MY | MY |
| **Theme** | `mereka` | `mereka` (shared) | `mereka` (shared) |
| **Primary contact** | team@mereka.io | admin@biji-biji.com | admin@mereka.io |
| **Active** | Yes | Yes | Yes |

### Slug inconsistency (action required)

The canonical tenant registry uses `biji-biji` while `tenant-contracts.yml` uses `bijibiji`. This must be reconciled before bootstrap. The registry slug `biji-biji` is canonical.

## Domain Matrix — Production

| Tenant | Surface | Domain | Backend | Status | Priority |
|--------|---------|--------|---------|--------|----------|
| **mereka** | LMS | `academyv2.mereka.io` | caddy→lms:8000 | active | P0 |
| | Studio | `studio.academyv2.mereka.io` | caddy→cms:8000 | active | P0 |
| | MFE | `apps.academyv2.mereka.io` | caddy→mfe:8002 | active | P0 |
| | Preview | `preview.academyv2.mereka.io` | caddy→lms:8000 | active | P1 |
| | Discovery | `discovery.academyv2.mereka.io` | caddy→discovery:8000 | active | P0 |
| | Notes | `notes.academyv2.mereka.io` | caddy→notes:8000 | active | P1 |
| | Credentials | `credentials.academyv2.mereka.io` | caddy→credentials:8000 | active | P1 |
| | Forum | `forum.academyv2.mereka.io` | caddy→lms:8000 | active | P1 |
| | Enterprise Admin | `admin.academyv2.mereka.io` | caddy→enterprise-admin-portal:8002 | active | P1 |
| | Enterprise Learner | `learner.academyv2.mereka.io` | caddy→enterprise-learner-portal:8002 | active | P2 |
| | Ecommerce (legacy) | `ecommerce.academyv2.mereka.io` | caddy→ecommerce:8000 | deprecated | P2 |
| | Auth (external) | `auth0.mereka.io` | Authentik (external) | active | P0 |
| | Analytics | `analytics.academyv2.mereka.io` | caddy→superset:8088 | active | P1 |
| **biji-biji** | LMS | `academy.biji-biji.com` | caddy→lms:8000 | active | P0 |
| | Studio | `studio.academy.biji-biji.com` | caddy→cms:8000 | active | P0 |
| | MFE | `apps.academy.biji-biji.com` | caddy→mfe:8002 | active | P0 |
| | Preview | `preview.academy.biji-biji.com` | caddy→lms:8000 | planned | P2 |
| | Enterprise Admin | `admin.academy.biji-biji.com` | caddy→enterprise-admin-portal:8002 | planned | P2 |
| | Enterprise Learner | `learner.academy.biji-biji.com` | caddy→enterprise-learner-portal:8002 | planned | P2 |
| | Credentials | `credentials.academy.biji-biji.com` | caddy→credentials:8000 | planned | P2 |
| | Analytics | `analytics.academy.biji-biji.com` | caddy→superset:8088 | planned | P2 |
| **skillourfuture** | LMS (legacy root) | `skillourfuture.academy.mereka.io` | caddy→lms:8000 | active | P0 |
| | LMS (target root) | `skillourfuture.academyv2.mereka.io` | caddy→lms:8000 | planned | P1 |
| | Studio | `studio.skillourfuture.academyv2.mereka.io` | caddy→cms:8000 | planned | P2 |
| | MFE | `apps.skillourfuture.academyv2.mereka.io` | caddy→mfe:8002 | planned | P2 |
| | Preview | `preview.skillourfuture.academyv2.mereka.io` | caddy→lms:8000 | planned | P2 |
| | Enterprise Admin | `admin.skillourfuture.academyv2.mereka.io` | caddy→enterprise-admin-portal:8002 | planned | P2 |
| | Enterprise Learner | `learner.skillourfuture.academyv2.mereka.io` | caddy→enterprise-learner-portal:8002 | planned | P2 |
| | Credentials | `credentials.skillourfuture.academyv2.mereka.io` | caddy→credentials:8000 | planned | P2 |
| | Analytics | `analytics.skillourfuture.academyv2.mereka.io` | caddy→superset:8088 | planned | P2 |

> BB/SOF planned entries: target-state intent ratified by domain truth convergence tranche.
> Current runtime is shared for enterprise-admin/learner/credentials/analytics.
> SOF target root: `*.skillourfuture.academyv2.mereka.io` (migration from legacy `*.skillourfuture.academy.mereka.io`).

## Domain Matrix — Dev

| Tenant | Surface | Domain | Status | Priority |
|--------|---------|--------|--------|----------|
| mereka | LMS | `academyv2.mereka.dev` | active | P1 |
| mereka | Studio | `studio.academyv2.mereka.dev` | active | P1 |
| mereka | MFE | `apps.academyv2.mereka.dev` | active | P1 |
| mereka | Preview | `preview.academyv2.mereka.dev` | active | P2 |
| mereka | Discovery | `discovery.academyv2.mereka.dev` | active | P1 |
| mereka | Notes | `notes.academyv2.mereka.dev` | active | P2 |
| mereka | Credentials | `credentials.academyv2.mereka.dev` | active | P2 |
| mereka | Forum | `forum.academyv2.mereka.dev` | active | P2 |
| mereka | Enterprise Admin | `admin.academyv2.mereka.dev` | active | P2 |
| mereka | Enterprise Learner | `learner.academyv2.mereka.dev` | active | P2 |
| mereka | Analytics | `analytics.academyv2.mereka.dev` | active | P2 |
| mereka | Auth | `auth0.mereka.dev` | active | P1 |
| biji-biji | LMS | `biji-biji.academyv2.mereka.dev` | active | P1 |
| biji-biji | Studio | `studio.biji-biji.academyv2.mereka.dev` | active | P1 |
| biji-biji | MFE | `apps.biji-biji.academyv2.mereka.dev` | active | P1 |
| biji-biji | Preview | `preview.biji-biji.academyv2.mereka.dev` | planned | P2 |
| biji-biji | Enterprise Admin | `admin.biji-biji.academyv2.mereka.dev` | planned | P2 |
| biji-biji | Enterprise Learner | `learner.biji-biji.academyv2.mereka.dev` | planned | P2 |
| biji-biji | Credentials | `credentials.biji-biji.academyv2.mereka.dev` | planned | P2 |
| biji-biji | Analytics | `analytics.biji-biji.academyv2.mereka.dev` | planned | P2 |
| skillourfuture | LMS | `skillourfuture.academyv2.mereka.dev` | active | P1 |
| skillourfuture | Studio | `studio.skillourfuture.academyv2.mereka.dev` | active | P1 |
| skillourfuture | MFE | `apps.skillourfuture.academyv2.mereka.dev` | active | P1 |
| skillourfuture | Preview | `preview.skillourfuture.academyv2.mereka.dev` | planned | P2 |
| skillourfuture | Enterprise Admin | `admin.skillourfuture.academyv2.mereka.dev` | planned | P2 |
| skillourfuture | Enterprise Learner | `learner.skillourfuture.academyv2.mereka.dev` | planned | P2 |
| skillourfuture | Credentials | `credentials.skillourfuture.academyv2.mereka.dev` | planned | P2 |
| skillourfuture | Analytics | `analytics.skillourfuture.academyv2.mereka.dev` | planned | P2 |

> All three tenants provisioned on rke2-nonprod (dev). BB/SOF LMS/Studio/MFE verified on live ingress 2026-03-20.
> Planned entries: target-state intent. Current runtime shared for enterprise/credentials/analytics.

## Surface Map

| Surface | Primary purpose | Owning service | Expected user role | Current maturity |
|---------|----------------|---------------|--------------------|------------------|
| **LMS** (`/`) | Learner course access, enrollment | LMS pod (Django) | All authenticated users | Mature, production |
| **Studio** (`studio.*`) | Course authoring, content management | CMS pod (Django) | Course creators, staff | Mature, production |
| **MFE** (`apps.*`) | Modern React UI for learning, profile, etc. | MFE pod (React/Caddy) | All authenticated users | Mature, production |
| **Admin Console MFE** (`apps.*/admin-console/`) | RBAC, org management, content libraries | MFE pod (sub-path) | `is_staff` or `org_admin` | Shipped with Ulmo, functional |
| **Enterprise Admin Portal** (`admin.*`) | Enterprise catalog, access, licenses, subsidies | enterprise-admin-portal pod | Enterprise admins (per tenant) | Deployed, **data-empty** |
| **Enterprise Learner Portal** (`learner.*`) | Enterprise course browsing, subsidy enrollment | enterprise-learner-portal pod | Enterprise learners (per tenant) | Deployed, **data-empty** |
| **LMS Django Admin** (`*/admin/`) | User/course/permission management | LMS pod | `is_staff` or `is_superuser` | Mature, production |
| **Studio Django Admin** (`studio.*/admin/`) | CMS model management | CMS pod | `is_staff` or `is_superuser` | Mature, production |
| **Discovery Admin** (`discovery.*/admin/`) | Catalog config | Discovery pod | `is_staff` in discovery DB | Available |
| **Credentials Admin** (`credentials.*/admin/`) | Certificate management | Credentials pod | `is_staff` in credentials DB | Available |
| **Purchase Gateway** (API only) | Payment admin | Gateway pod (FastAPI) | API key | Activated, in use |

## Service Isolation Model

| Service | Isolation level | Scope boundary |
|---------|----------------|---------------|
| LMS / CMS | Shared process | `course_org_filter` in `SiteConfiguration` |
| MFE | Shared deployment | `mfe_config` API returns tenant-scoped values |
| Enterprise Admin/Learner | Shared deployment | `EnterpriseCustomer.uuid` scopes all queries |
| Enterprise services (catalog/access/subsidy/license) | Shared deployment | `EnterpriseCustomer.uuid` scopes all queries |
| Discovery | Shared | Catalog queries scoped by enterprise customer |
| Forum | Shared (in-process with LMS) | Course membership |

## Cookie Domain Boundaries

| Tenant | Cookie domain | Shared across |
|--------|--------------|--------------|
| mereka (prod) | `.academyv2.mereka.io` | LMS, Studio, MFE, enterprise portals |
| biji-biji (prod) | `.biji-biji.com` | LMS, Studio, MFE |
| skillourfuture (prod) | `.skillourfuture.academy.mereka.io` | LMS only (Studio/MFE are planned) |
| mereka (dev) | `.academyv2.mereka.dev` | LMS, Studio, MFE, enterprise portals |

## Runtime Config Sources

| Surface | Config source | How env-specific values arrive |
|---------|--------------|-------------------------------|
| LMS/CMS | `openedx-config` ConfigMap (settings files) | `configMapGenerator` with overlay `behavior: merge` |
| MFE | `mfe_config` API from LMS | Runtime API call; values from `SiteConfiguration.site_values` |
| Enterprise MFE | `enterprise-mfe-env` ConfigMap (`env.config.js`) | `configMapGenerator` with overlay `behavior: replace`; base uses localhost placeholders |
| Enterprise services | Per-service config YAML (init container) | Python config-gen from env vars at pod start |

## Current Ambiguities

1. **Mereka missing as EnterpriseCustomer**: ADR-024 requires it. Without it, enterprise portals cannot resolve a customer UUID for the primary tenant.

2. **Zero enterprise catalogs**: Even after runtime fix lands, portals will show empty content until catalogs are created.

3. **Partner orgs have no courses**: BIJIBIJI and SKILLOURFUTURE orgs have 0 courses. Catalogs scoped to those orgs will be empty. Decision needed: share MEREKA courses or create org-specific courses.

4. **Slug mismatch**: `biji-biji` vs `bijibiji` across different config files.

5. **SkillOurFuture infrastructure incomplete**: Studio and MFE domains are `planned` — no TLS cert, no Ingress routing.

6. **Enterprise partner admin surface is shared**: partner enterprise MFEs use tenant-specific LMS/Studio/apps hosts, but their enterprise admin APIs currently live behind the shared primary admin surface `admin.academyv2.mereka.io`. Dedicated partner admin domains are not part of the active routing contract.
