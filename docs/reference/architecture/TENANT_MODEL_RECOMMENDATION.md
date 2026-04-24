# Tenant Model Recommendation

> Short recommendation memo answering the key structural questions
> about the Mereka LMS multi-tenant model.
>
> **Date**: 2026-03-11
> **Status**: Proposed (pending operator review)

## Q1: Should Mereka be operator-only, enterprise-customer, or both?

**Recommendation: Both.**

Mereka Academy is the platform operator AND a tenant. ADR-024 already mandates this: "Every tenant MUST have first-class application-layer records." The 109 existing courses belong to org `MEREKA` and need an `EnterpriseCustomer` to appear in enterprise catalogs and portals.

Without an `EnterpriseCustomer` for Mereka:
- The enterprise admin portal at `admin.academyv2.mereka.io` cannot resolve a customer UUID
- The enterprise learner portal has no catalog to display
- Enterprise enrollment tracking is impossible

The `is_primary: true` flag in `tenant-registry.yaml` already distinguishes Mereka from partner tenants.

## Q2: Should BGPG and SOF remain enterprise customers on a shared platform, or become site-level tenants?

**Recommendation: Remain enterprise customers on the shared platform.**

The current architecture (ADR-024) is correct:
- Shared LMS/CMS deployment with ORM-level isolation via `course_org_filter`
- Per-tenant `Site` + `SiteConfiguration` + `EnterpriseCustomer` records
- Shared enterprise services (catalog, access, subsidy) scoped by `EnterpriseCustomer.uuid`

Reasons NOT to elevate to separate infrastructure:
1. No courses exist under `BIJIBIJI` or `SKILLOURFUTURE` orgs yet — separate infra would be empty
2. The platform has only 109 courses total — no scale pressure
3. Shared deployment reduces operational cost
4. ADR-024 explicitly rejected "fully separate infrastructure stacks"

**When to reconsider**: If a partner tenant needs isolated data (different MySQL instance), custom auth (different IdP), or independent release cycles.

## Q3: What are the recommended default learner/admin entry points?

**Recommendation: Use the existing domain pattern.**

| Tenant | Admin Portal | Learner Portal |
|--------|-------------|----------------|
| mereka | `admin.academyv2.mereka.io` | `learner.academyv2.mereka.io` |
| biji-biji | `admin.academyv2.mereka.io` | `learner.academyv2.mereka.io` |
| skillourfuture | `admin.academyv2.mereka.io` | `learner.academyv2.mereka.io` |

These domains are already the active shared enterprise surface. What's missing is:
1. Enterprise data to populate partner tenant views
2. A conscious product decision before adding dedicated partner enterprise hostnames

## Q4: What is the minimum clean target model for the current phase?

**The smallest model that makes enterprise portals functional:**

### Must have (before enterprise portals are useful)

1. **3 EnterpriseCustomer records** — mereka, bijibiji, skillourfuture
2. **3 EnterpriseCustomerCatalog records** — one per customer, with CatalogQuery
3. **Admin user links** — at least 1 admin per customer via EnterpriseCustomerUser
4. **Waffle switches** — 5 switches per tenant (15 total)

### Should have (short-term)

5. **Slug reconciliation** — fix `biji-biji` vs `bijibiji` inconsistency
6. **Catalog query decision** — whether partner tenants see MEREKA courses
7. **Course content for partner orgs** — or explicit decision to share MEREKA org

### Can defer

8. Enterprise enrollments (created naturally as users enroll)
9. License management (not yet needed)
10. Integrated channels (no external LMS targets yet)
11. Subsidy configuration (no budget pools defined)

## Summary

The platform has the right architecture (ADR-024) and the right tooling (`provision_tenant.py`, `provision-all-tenants.sh`). What's missing is the enterprise data layer: catalogs, queries, and user links. The bootstrap spec (`config/enterprise-tenants/dev.enterprise-tenants.yaml`) and tooling (`bootstrap-enterprise-tenants.py`) produced in this work fill that gap.

**Immediate next steps** (after runtime blocker is resolved):
1. Run `bootstrap-enterprise-tenants.py --env dev --apply` to populate enterprise data
2. Run `validate-enterprise-tenants.py` to verify
3. Verify enterprise portals show catalog content
