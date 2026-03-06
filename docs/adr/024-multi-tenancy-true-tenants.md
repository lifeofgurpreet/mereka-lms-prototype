---
title: "True Multi-Tenancy for Subsites (Biji-Biji, SkillOurFuture)"
type: "adr"
status: "accepted"
owner: "engineering"
last_updated: "2026-03-05"
links:
  related_adrs:
    - "docs/adr/001-mongodb-atlas.md"
    - "docs/adr/021-openedx-tutor-methodology.md"
  related_specs:
    - "specs/multi-tenancy-architecture_spec.md"
    - "specs/multi-site-domains_spec.md"
    - "specs/enterprise-microservices_spec.md"
    - "specs/branding-system_spec.md"
---

# ADR-024: True Multi-Tenancy for Subsites (Biji-Biji, SkillOurFuture)

**Status**: Accepted
**Date**: 2026-03-05
**Deciders**: Gurpreet Singh (Founder / Platform Owner)

<!-- Last verified: 2026-03-05 -->

## Context

Mereka Academy operates multiple organizational brands: the primary Mereka Academy, the
partner-branded Biji-Biji Initiative (`academy.biji-biji.com`), and the program-specific
SkillOurFuture (`skillourfuture.academy.mereka.io`). These subsites currently function as
**alias domains** — they point to the same Open edX platform instance and share everything.

The question arose: should these subsites have the same breadth of service coverage (Notes,
Forum, Credentials, Discovery, Enterprise Portals, Ecommerce) as the primary
`academyv2.mereka.io` site? Or is it acceptable for them to share a subset?

After research into Open edX's official multi-tenancy capabilities, community best practices
(eox-tenant, OpenCraft's Ocim), and the platform's own service isolation models, we determined
that **Biji-Biji and SkillOurFuture are true tenants, not vanity aliases**. They must have
full tenant infrastructure — no compromises.

## Decision

**Biji-Biji and SkillOurFuture are true tenants. Every new subsite is a true tenant. No
subsite will ever be treated as a vanity alias.**

This means every tenant MUST have:

### 1. Application-Layer Records (Django DB)

| Record | Purpose | How It's Created |
|--------|---------|-----------------|
| Django `Site` | Domain-based request routing | Django admin or provisioning script |
| `SiteConfiguration` | Per-tenant settings (theme, features, branding) | Django admin or provisioning script |
| `EnterpriseCustomer` | Tenant identity (UUID, slug, feature flags) | Django admin or provisioning script |
| `EnterpriseCustomerIdentityProvider` | Tenant SSO linkage | Django admin |
| Discovery `Partner` record | Course catalog scoping | Discovery admin API |
| Discovery `Site` record | Domain-to-partner mapping in Discovery | Discovery admin |

### 2. Per-Service Isolation Model

This is the critical table. Every agent working on multi-tenancy MUST understand this:

| Service | Own Domain Per Tenant? | Own DB Records? | Isolation Mechanism | Notes |
|---------|:---------------------:|:---------------:|---------------------|-------|
| **LMS** | YES | Site + SiteConfig | Django Sites framework | Each tenant gets `{slug}.academyv2.mereka.io` or a custom domain |
| **Studio (CMS)** | NO | N/A | Shared — single Studio for all | Tenants don't need Studio; course authoring is platform-level |
| **Notes (edx-notes-api)** | NO | None needed | `course_id` scoping (implicit) | Note model has no `site_id` field at all. Course IDs contain org prefix → natural namespace isolation |
| **Forum (openedx-forum v2)** | NO | None needed | `course_id` scoping (in-process) | Runs inside LMS process. Thread isolation by course membership. If two tenants share a course, learners see each other's posts (expected) |
| **Credentials** | YES | Site + SiteConfig | Django Sites framework | `CourseCertificate` has unique constraint on `(site, course_id, certificate_type)` |
| **Discovery** | YES | Site + Partner | Partner model | Each tenant needs a Partner + Site for catalog scoping. `course_org_filter` restricts visible courses |
| **Ecommerce / Purchase Gateway** | YES | Partner + Site + SiteConfig | Partner + Oscar Site model | Each tenant needs separate payment flow records |
| **Enterprise Learner Portal** | NO | EnterpriseCustomer | Slug-based URL routing (`/:slug/`) | Single MFE instance serves all — designed for multi-tenant from the start |
| **Enterprise Admin Portal** | NO | EnterpriseCustomer | Slug-based URL routing (`/:slug/`) | Same as learner portal |
| **MFEs (Learning, Authn, etc.)** | Depends | Config via MFE_CONFIG_API | Runtime config per tenant | Branding via `SiteConfiguration` values at runtime |

### 3. Infrastructure Requirements Per Tenant

| Requirement | Needed? | Details |
|-------------|---------|---------|
| Own LMS domain | YES | `{slug}.academyv2.mereka.io` or custom domain (e.g., `academy.biji-biji.com`) |
| Own MFE domain | YES | `apps.{lms_domain}` for each tenant LMS domain |
| Own Studio domain | NO | Studio is shared platform-wide |
| Own Notes domain | NO | Notes has no site awareness — shared is correct |
| Own Forum domain | NO | Forum v2 runs in-process with LMS — no separate domain |
| Own Credentials domain | FUTURE | Needed when tenant issues its own certificates (not Day 1) |
| Own Discovery domain | NO | Shared Discovery with per-tenant Partner records |
| Own Enterprise portal domains | NO | Slug-based routing, not domain-based |
| Ingress + TLS for LMS domain | YES | cert-manager + letsencrypt-prod |
| Caddy host matcher | YES | Route tenant domain to LMS backend |
| ALLOWED_HOSTS entry | YES | LMS Django setting |
| CSRF_TRUSTED_ORIGINS entry | YES | LMS Django setting |
| `course_org_filter` | YES | In SiteConfiguration — restricts course visibility to tenant's org |
| Branding assets | YES | Theme directory: `tenants/{slug}/` |

### 4. What "True Tenant" Does NOT Mean

To be crystal clear on the shared-everything model:

- **NOT separate K8s namespaces** — all tenants share `mereka-lms` namespace
- **NOT separate databases** — all tenants share Cloud SQL and MongoDB Atlas
- **NOT separate Redis instances** — shared Redis with namespace-prefixed keys
- **NOT separate service deployments** — one LMS, one Discovery, one set of enterprise services
- **NOT separate Docker images** — all tenants run the same platform version

Isolation is at the **application layer** (Django querysets, API permission checks, Sites
framework, EnterpriseCustomer scoping), not at the infrastructure layer.

## Consequences

### Positive

- Every tenant gets first-class treatment — correct certificate issuance, proper course
  catalog scoping, proper branding, proper analytics isolation
- The provisioning script (`scripts/tenants/provision-tenant.sh`) becomes the single source
  of truth for what a tenant needs
- No "half-baked" tenants that work for LMS but break on Credentials or Discovery
- Agents have an unambiguous reference for what records to create

### Negative

- More provisioning work per tenant (Site + SiteConfig + EnterpriseCustomer + Partner +
  catalog + ALLOWED_HOSTS + CSRF + ingress + Caddy + branding)
- Credentials and Discovery need per-tenant Site records, which increases Django admin
  complexity
- Custom domains require DNS + TLS management per tenant

### Current State (Verified 2026-03-05 via live cluster)

| Record | Biji-Biji | SkillOurFuture | Mereka |
|--------|-----------|----------------|--------|
| `EnterpriseCustomer` | uuid=378aa476, slug=bijibiji, site=4 | uuid=36d0e89b, slug=skillourfuture, site=7 | uuid=6435193a, slug=mereka, site=6 |
| `SiteConfiguration` | enabled=True, org_filter=BIJIBIJI | enabled=True, org_filter=SKILLOURFUTURE | enabled=True, org_filter=MEREKA |
| Django `Site` (LMS) | academy.biji-biji.com (id=4) | skillourfuture.academy.mereka.io (id=7) | academyv2.mereka.io (id=6) |
| Django `Site` (MFE) | apps.academy.biji-biji.com (id=9) | apps.skillourfuture.academy.mereka.io (id=10) | apps.academyv2.mereka.io (id=8) |

### Remaining Gaps

| Gap | Status | Action |
|-----|--------|--------|
| Discovery `Partner` records for subsites | **UNVERIFIED** | Check Discovery admin API |
| Enterprise learner portal naming inconsistency | **OPEN** | See issue #206 |
| Enterprise MFEs 503 on dev | **OPEN** | See issue #206 (infrastructure fix) |
| No dev/staging domains for subsites | **BY DESIGN** | Subsites test on shared dev platform; prod-only custom domains are correct |

## Open edX Official Context

This decision is grounded in how Open edX upstream handles multi-tenancy:

1. **Django Sites framework** is the canonical per-tenant routing mechanism (used by LMS,
   Credentials, Discovery, Ecommerce)
2. **EnterpriseCustomer** is the canonical tenant identity model (used by all enterprise
   services)
3. **eox-tenant** (by eduNEXT) is the most mature community multi-tenancy plugin — it extends
   Sites framework with runtime per-tenant Django setting overrides
4. **Forum and Notes have no site awareness** — this is a known upstream limitation, not a bug.
   Isolation works through `course_id` scoping, which is sufficient because course IDs contain
   the org prefix
5. **Enterprise portals use slug-based routing** — this is by design, not a limitation. The
   `/:enterpriseSlug/` pattern supports multi-tenancy natively without per-tenant domains
6. **MFE multi-tenancy is the biggest gap** in the ecosystem — `MFE_CONFIG_API` provides
   runtime config but visual customization per tenant is limited

Sources:
- [edx-django-sites-extensions](https://github.com/openedx/edx-django-sites-extensions)
- [eox-tenant](https://github.com/eduNEXT/eox-tenant)
- [Open edX Partners, Sites, and Organizations](https://openedx.atlassian.net/wiki/spaces/AC/pages/103907632)
- [frontend-app-learner-portal-enterprise](https://github.com/openedx/frontend-app-learner-portal-enterprise)
- [edx-notes-api models.py](https://github.com/openedx/edx-notes-api/blob/master/notesapi/v1/models.py)

## Related

- `specs/multi-tenancy-architecture_spec.md` — Full spec with 50+ ACs
- `specs/multi-site-domains_spec.md` — Domain configuration contract
- `docs/operations/DOMAIN_MATRIX.md` — Current domain inventory
- GitHub issue #206 — Domain infrastructure gaps
- `scripts/tenants/provision-tenant.sh` — Tenant provisioning automation
