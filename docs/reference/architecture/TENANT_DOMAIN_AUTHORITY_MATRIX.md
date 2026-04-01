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

## Domain Matrix (Production) — Current Deployed Truth

| Tenant | Role | Domain | Status |
|--------|------|--------|--------|
| **mereka** | LMS | `academyv2.mereka.io` | active |
| | Studio | `studio.academyv2.mereka.io` | active |
| | MFE | `apps.academyv2.mereka.io` | active |
| | Preview | `preview.academyv2.mereka.io` | active |
| | Discovery | `discovery.academyv2.mereka.io` | active (shared) |
| | Notes | `notes.academyv2.mereka.io` | active (shared) |
| | Credentials | `credentials.academyv2.mereka.io` | active (shared) |
| | Forum | `forum.academyv2.mereka.io` | active (shared) |
| | Enterprise Admin | `admin.academyv2.mereka.io` | active (shared) |
| | Enterprise Learner | `learner.academyv2.mereka.io` | active (shared) |
| | Analytics | `analytics.academyv2.mereka.io` | active (dormant replicas) |
| | Auth | `auth0.mereka.io` | active (shared) |
| | Ecommerce | `ecommerce.academyv2.mereka.io` | deprecated |
| **biji-biji** | LMS | `academy.biji-biji.com` | active |
| | Studio | `studio.academy.biji-biji.com` | active |
| | MFE | `apps.academy.biji-biji.com` | active |
| | Preview | `preview.academy.biji-biji.com` | planned |
| **skillourfuture** | LMS | `skillourfuture.academy.mereka.io` | active (legacy root) |
| | Studio | `studio.skillourfuture.academy.mereka.io` | planned (legacy root) |
| | MFE | `apps.skillourfuture.academy.mereka.io` | planned (legacy root) |

## SOF Root Migration (Production)

| Current (legacy) | Target | Status |
|-----------------|--------|--------|
| `skillourfuture.academy.mereka.io` | `skillourfuture.academyv2.mereka.io` | planned |
| `studio.skillourfuture.academy.mereka.io` | `studio.skillourfuture.academyv2.mereka.io` | planned |
| `apps.skillourfuture.academy.mereka.io` | `apps.skillourfuture.academyv2.mereka.io` | planned |
| — | `preview.skillourfuture.academyv2.mereka.io` | planned |

## Surfaces Shared by Design

These surfaces use a single shared hostname for all tenants. This is an intentional
architectural decision — not an implementation gap.

| Surface | Shared hostname | Why |
|---------|----------------|-----|
| Discovery | `discovery.academyv2.*` | Backend API; users never visit; enterprise-catalog scopes by UUID |
| Notes | `notes.academyv2.*` | Backend API; users never visit; scoped by user_id + course_id |
| Forum | `forum.academyv2.*` | In-process LMS alias; discussions via course pages; not a distinct surface |
| Auth | `auth0.*` | Shared Authentik OIDC; transparent redirect |
| Ecommerce | `ecommerce.academyv2.*` | Deprecated; replaced by payments-gateway |

## Target-State Per-Tenant Surfaces (Not Yet Realized)

These surfaces currently use shared Mereka hostnames. The target-state model gives
each tenant its own hostname. Target-state intent ratified by the domain truth
convergence tranche; current runtime remains shared until realization.

| Surface | Current (shared) | BB target | SOF target | Gap |
|---------|-----------------|-----------|------------|-----|
| Enterprise Admin | `admin.academyv2.*` | `admin.academy.biji-biji.com` | `admin.skillourfuture.academyv2.mereka.io` | DNS, TLS, Caddy routing, MFE env config |
| Enterprise Learner | `learner.academyv2.*` | `learner.academy.biji-biji.com` | `learner.skillourfuture.academyv2.mereka.io` | DNS, TLS, Caddy routing, MFE env config |
| Credentials | `credentials.academyv2.*` | `credentials.academy.biji-biji.com` | `credentials.skillourfuture.academyv2.mereka.io` | DNS, TLS, Caddy routing, satellite ALLOWED_HOSTS |
| Analytics | `analytics.academyv2.*` | `analytics.academy.biji-biji.com` | `analytics.skillourfuture.academyv2.mereka.io` | DNS, TLS, Ingress host rule, Superset CORS |

## Domain Matrix (Dev)

| Tenant | Role | Domain | Status | P |
|--------|------|--------|--------|---|
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
| skillourfuture | LMS | `skillourfuture.academyv2.mereka.dev` | active | P1 |
| skillourfuture | Studio | `studio.skillourfuture.academyv2.mereka.dev` | active | P1 |
| skillourfuture | MFE | `apps.skillourfuture.academyv2.mereka.dev` | active | P1 |
| skillourfuture | Preview | `preview.skillourfuture.academyv2.mereka.dev` | planned | P2 |

> Dev environment provisions all three tenants on rke2-nonprod.
> BB and SOF dev tenant-pattern domains verified on live ingress 2026-03-20.

## Service Isolation Model

| Service | Isolation | Notes |
|---------|-----------|-------|
| **LMS** | Shared process, ORM queryset filtering via `course_org_filter` | All tenants share one LMS deployment |
| **CMS (Studio)** | Shared process | Studio is platform-shared (ADR-024) |
| **MFE** | Shared deployment, tenant routing via `SiteConfiguration` | One MFE pod serves all tenants |
| **Enterprise Admin/Learner** | Shared deployment, slug routing (ADR-024) | Per-tenant MFE env files exist as reference artifacts but are NOT deployed. Single `enterprise-mfe-env` ConfigMap serves all tenants. |
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
| biji-biji | `admin.academyv2.mereka.io` | `learner.academyv2.mereka.io` | `biji-biji-mfe-env.js` |
| skillourfuture | `admin.academyv2.mereka.io` | `learner.academyv2.mereka.io` | `skillourfuture-mfe-env.js` |

## Open Questions

1. **SOF root migration timing**: Current root `skillourfuture.academy.mereka.io` is active. Target root `skillourfuture.academyv2.mereka.io` is planned. Migration requires DNS, TLS, SiteConfiguration, ALLOWED_HOSTS, and redirect setup across repos.

2. **Slug inconsistency**: tenant-registry uses `biji-biji`, tenant-contracts uses `bijibiji`. Must be reconciled before bootstrap.

3. **Mereka dual role**: Platform operator + primary tenant (ADR-024). `is_primary: true` distinguishes it.
