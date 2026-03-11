# Tenant / Domain Authority Matrix

> Canonical reference for who owns what across the Mereka LMS multi-tenant platform.
>
> **Source of truth chain**: This document summarizes the model.
> Machine-readable sources remain authoritative:
> - `deploy/k8s/tenancy/tenant-registry.yaml` (domains, routing, proof priority)
> - `infrastructure/tenants/tenant-contracts.yml` (tenant metadata, provisioning)
> - `infrastructure/tutor/multisite-sites.yml` (Open edX Site records)

## Definitions

| Term | Meaning |
|------|---------|
| **Tenant** | A branded entity with its own Django `Site`, `SiteConfiguration`, `EnterpriseCustomer`, and `TenantConfig`. Courses are scoped by `course_org_filter`. |
| **Platform operator** | Mereka Academy. Owns infrastructure, shared services, and the primary deployment. |
| **Partner tenant** | Biji-Biji Initiative, Skill Our Future. Branded subsites sharing the platform. |
| **Enterprise Customer** | Open edX `enterprise.EnterpriseCustomer` record. Every tenant is one. |
| **Site** | Django `django.contrib.sites.Site` record. Maps a domain to tenant-scoped config. |

## Tenant Authority Table

| Property | Mereka Academy | Biji-Biji Initiative | Skill Our Future |
|----------|---------------|---------------------|-----------------|
| **Role** | Platform operator + tenant | Partner tenant | Partner tenant |
| **Slug** | `mereka` | `biji-biji` (registry) / `bijibiji` (contract) | `skillourfuture` |
| **Org code** | `MEREKA` | `BIJIBIJI` | `SKILLOURFUTURE` |
| **Enterprise Customer** | Yes (required by ADR-024) | Yes (exists) | Yes (exists) |
| **Is primary** | Yes | No | No |
| **Country** | MY | MY | MY |
| **Theme** | `mereka` | `mereka` (shared) | `mereka` (shared) |
| **Active** | Yes | Yes | Yes |

## Domain Matrix (Production)

| Tenant | Role | Domain | Service | Status | P |
|--------|------|--------|---------|--------|---|
| mereka | LMS (primary) | `academyv2.mereka.io` | caddy→lms:8000 | active | P0 |
| mereka | Studio | `studio.academyv2.mereka.io` | caddy→cms:8000 | active | P0 |
| mereka | MFE | `apps.academyv2.mereka.io` | caddy→mfe:8002 | active | P0 |
| mereka | Preview | `preview.academyv2.mereka.io` | caddy→lms:8000 | active | P1 |
| mereka | Discovery | `discovery.academyv2.mereka.io` | caddy→discovery:8000 | active | P0 |
| mereka | Notes | `notes.academyv2.mereka.io` | caddy→notes:8000 | active | P1 |
| mereka | Credentials | `credentials.academyv2.mereka.io` | caddy→credentials:8000 | active | P1 |
| mereka | Forum | `forum.academyv2.mereka.io` | caddy→lms:8000 | active | P1 |
| mereka | Enterprise Admin | `admin.academyv2.mereka.io` | caddy→enterprise-admin-portal:8002 | active | P1 |
| mereka | Enterprise Learner | `learner.academyv2.mereka.io` | caddy→enterprise-learner-portal:8002 | active | P2 |
| mereka | Ecommerce (legacy) | `ecommerce.academyv2.mereka.io` | caddy→ecommerce:8000 | deprecated | P2 |
| mereka | Auth (external) | `auth0.mereka.io` | Authentik (external) | active | P0 |
| biji-biji | LMS (primary) | `academy.biji-biji.com` | caddy→lms:8000 | active | P0 |
| biji-biji | Studio | `studio.academy.biji-biji.com` | caddy→cms:8000 | active | P0 |
| biji-biji | MFE | `apps.academy.biji-biji.com` | caddy→mfe:8002 | active | P0 |
| skillourfuture | LMS (primary) | `skillourfuture.academy.mereka.io` | caddy→lms:8000 | active | P0 |
| skillourfuture | Studio | `studio.skillourfuture.academy.mereka.io` | caddy→cms:8000 | planned | P2 |
| skillourfuture | MFE | `apps.skillourfuture.academy.mereka.io` | caddy→mfe:8002 | planned | P2 |

## Domain Matrix (Dev)

| Tenant | Role | Domain | Status | P |
|--------|------|--------|--------|---|
| mereka | LMS | `academyv2.mereka.dev` | active | P1 |
| mereka | Studio | `studio.academyv2.mereka.dev` | active | P1 |
| mereka | MFE | `apps.academyv2.mereka.dev` | active | P1 |
| mereka | Preview | `preview.academyv2.mereka.dev` | active | P2 |
| mereka | Discovery | `discovery.academyv2.mereka.dev` | active | P1 |
| mereka | Enterprise Admin | `admin.academyv2.mereka.dev` | active | P2 |
| mereka | Enterprise Learner | `learner.academyv2.mereka.dev` | active | P2 |
| mereka | Auth | `auth0.mereka.dev` | active | P1 |

> Dev environment currently only provisions the `mereka` tenant.
> Biji-Biji and SkillOurFuture have dev domain patterns defined in config.sh
> but are not yet deployed to rke2-nonprod.

## Service Isolation Model

| Service | Isolation | Notes |
|---------|-----------|-------|
| **LMS** | Shared process, ORM queryset filtering via `course_org_filter` | All tenants share one LMS deployment |
| **CMS (Studio)** | Shared process | Studio is platform-shared (ADR-024) |
| **MFE** | Shared deployment, tenant routing via `SiteConfiguration` | One MFE pod serves all tenants |
| **Enterprise Admin/Learner** | Shared deployment, tenant-specific `env.config.js` | ConfigMap per tenant for branding |
| **Discovery** | Shared | Catalog scoped by tenant queries |
| **Forum** | Shared (runs in-process with LMS) | Scoped by course membership |
| **Notes** | Shared | Scoped by course enrollment |
| **Credentials** | Shared | Scoped by user identity |
| **Enterprise services** | Shared (catalog, access, subsidy, license-manager) | Scoped by `EnterpriseCustomer.uuid` |

## Cookie Domain Boundaries

| Tenant | Cookie domain | Scope |
|--------|--------------|-------|
| mereka (prod) | `.academyv2.mereka.io` | Shared across LMS, Studio, MFE, enterprise portals |
| biji-biji (prod) | `.biji-biji.com` | Note: broader than `.academy.biji-biji.com` |
| skillourfuture (prod) | `.skillourfuture.academy.mereka.io` | Isolated from mereka cookies |
| mereka (dev) | `.academyv2.mereka.dev` | Dev-only |

## Enterprise Admin/Learner Portal Per-Tenant Entry Points

| Tenant | Admin Portal | Learner Portal | MFE env file |
|--------|-------------|----------------|--------------|
| mereka | `admin.academyv2.mereka.io` | `learner.academyv2.mereka.io` | `enterprise-mfe-env.js` |
| biji-biji | `admin.academy.biji-biji.com` | (not yet configured) | `biji-biji-mfe-env.js` |
| skillourfuture | `admin.skillourfuture.academy.mereka.io` | (not yet configured) | `skillourfuture-mfe-env.js` |

## Ambiguities and Open Questions

1. **Mereka dual role**: Mereka is both platform operator and enterprise customer. This is correct per ADR-024 but means "Mereka" appears in two capacities. The `is_primary: true` flag distinguishes it.

2. **Slug inconsistency**: tenant-registry uses `biji-biji`, tenant-contracts uses `bijibiji`. The `provision_tenant.py` management command and `EnterpriseCustomer.slug` in the DB may differ. This must be reconciled.

3. **SkillOurFuture Studio/MFE**: Domains are defined but status is `planned` - no TLS cert, not routable. Enterprise admin/learner portals for this tenant are not yet in prod Ingress.

4. **Biji-Biji Learner Portal**: The `biji-biji-mfe-env.js` defines enterprise API URLs under `admin.academy.biji-biji.com` but no corresponding `learner.academy.biji-biji.com` domain exists in the registry.

5. **Enterprise portals per-tenant**: Currently enterprise admin/learner are only deployed as shared K8s services. Tenant-specific routing happens via ConfigMap swap, but the MFE containers are shared. The admin/learner domains for biji-biji and skillourfuture are defined in MFE env files but may not have Ingress/Caddy routing.
