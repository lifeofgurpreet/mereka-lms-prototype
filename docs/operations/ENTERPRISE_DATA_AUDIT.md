# Enterprise Data Audit

> Audit of enterprise data model state based on reported telemetry and codebase analysis.
>
> **Date**: 2026-03-11
> **Method**: Read-only codebase inspection + reported cluster state
> **Scope**: All three tenants across production and dev environments

## Enterprise Customer Records

| Enterprise Customer | Slug | Active | Site Linked | Notes |
|-------------------|------|--------|-------------|-------|
| Biji Biji Initiative | `biji-biji` or `bijibiji` | Yes | Unknown | Reported present |
| Skill Our Future | `skillourfuture` | Yes | Unknown | Reported present |
| Mereka Academy | `mereka` | **UNKNOWN** | Unknown | **Not confirmed in report** |

### Gap: Mereka as Enterprise Customer

The initial report states "No Mereka enterprise customer currently exists." Per ADR-024, every tenant MUST have an `EnterpriseCustomer` record. If Mereka lacks one, the enterprise admin/learner portals cannot function for the primary tenant.

**Action required**: Verify via `provision_tenant.py --slug mereka --dry-run` and create if missing.

## Enterprise Customer Catalogs

| Customer | Catalog Count | Status |
|----------|--------------|--------|
| Biji Biji Initiative | **0** | Missing |
| Skill Our Future | **0** | Missing |
| Mereka Academy | **0** | Missing (customer may not exist) |

**Impact**: Without catalogs, enterprise learner/admin portals show empty course listings even when the UI renders correctly. The runtime agent's MFE fix will produce a working shell with no content.

### What a Catalog Needs

Each `EnterpriseCustomerCatalog` requires:
1. A `CatalogQuery` defining course selection rules (typically `content_filter` JSON)
2. An association to the `EnterpriseCustomer`
3. A title for display

Typical catalog query for org-based filtering:
```json
{
  "content_filter": {
    "content_type": "course",
    "partner": "edx",
    "organizations.key": ["MEREKA"]
  }
}
```

## Enterprise Customer Users

| Customer | Linked Users | Status |
|----------|-------------|--------|
| Biji Biji Initiative | Minimal | Only a few links exist |
| Skill Our Future | Minimal | Only a few links exist |
| Mereka Academy | **0** | Customer may not exist |

**Impact**: Without `EnterpriseCustomerUser` records, users cannot access enterprise features (learner portal, admin portal, license assignment, subsidy enrollment).

## Enterprise Course Enrollments

| Customer | EnterpriseCourseEnrollment Count | Status |
|----------|--------------------------------|--------|
| All | **0** | None exist |

**Impact**: No enterprise enrollment tracking. Course completions, analytics, and integrated channel sync have no data.

## Course Inventory

| Org | Course Count | Enterprise Catalog Coverage |
|-----|-------------|---------------------------|
| MEREKA | 109 | **0%** (no catalog exists) |
| BIJIBIJI | 0 | N/A |
| SKILLOURFUTURE | 0 | N/A |

**Key finding**: All 109 courses belong to org `MEREKA`. No courses exist under `BIJIBIJI` or `SKILLOURFUTURE` orgs. This means:
- Biji-Biji and SkillOurFuture tenants have zero course content
- Either courses need to be created under those orgs, or `course_org_filter` needs to include `MEREKA` for those tenants
- The current `multisite-sites.yml` filters strictly by org, so these tenants see empty catalogs

## Data Object Summary

| Object | Expected Count | Actual Count | Gap |
|--------|---------------|-------------|-----|
| EnterpriseCustomer | 3 | 2 (possibly) | Mereka missing |
| EnterpriseCustomerCatalog | ≥3 (1 per customer) | 0 | All missing |
| CatalogQuery | ≥3 | 0 | All missing |
| EnterpriseCustomerUser | Dozens+ | ~minimal | Near-zero |
| EnterpriseCourseEnrollment | Varies | 0 | All missing |
| TenantConfig | 3 | Unknown | Not verified |
| Site | 3 | Likely 3 | From multisite-sites.yml |
| SiteConfiguration | 3 | Likely 3 | From multisite-sites.yml |

## Likely Configuration Errors

1. **Slug mismatch between registry and contract**: `biji-biji` vs `bijibiji`. If the DB uses one and scripts use the other, provisioning will create duplicates.

2. **Missing EnterpriseCustomer for Mereka**: The platform operator tenant may lack the enterprise record that links it to catalog, portal, and enrollment features.

3. **Zero catalogs for all customers**: Even if enterprise services render, the "Browse and Request" and course listing features will return empty results.

4. **Empty partner orgs**: BIJIBIJI and SKILLOURFUTURE orgs have no courses. Catalogs for those tenants would be empty regardless.

5. **Enterprise admin/learner domains for biji-biji and skillourfuture**: MFE env files define these domains, but they may not be in Ingress or Caddy routing yet.

## Recommendations

1. **Immediate**: Create `EnterpriseCustomer` for Mereka tenant (via `provision_tenant.py`)
2. **Immediate**: Create one `EnterpriseCustomerCatalog` + `CatalogQuery` per tenant
3. **Immediate**: Link admin users to their enterprise customers via `EnterpriseCustomerUser`
4. **Short-term**: Resolve slug inconsistency (`biji-biji` vs `bijibiji`)
5. **Short-term**: Decide whether partner tenants share MEREKA courses or create their own orgs
6. **Medium-term**: Populate `EnterpriseCourseEnrollment` records for existing learner enrollments
