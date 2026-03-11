# Enterprise Bootstrap Dry-Run: partner-isolated Variant

> Canonical dry-run output showing exactly what objects would be created
> when `bootstrap-enterprise-tenants.py --env dev` runs against the
> `partner-isolated` variant.
>
> Source spec: `config/enterprise-tenants/dev.enterprise-tenants.partner-isolated.yaml`

## Summary

| Metric | Value |
|--------|-------|
| Tenants processed | 3 |
| Total actions | 27 |
| Creates | 21 |
| Ensures | 15 (waffle switches) |
| Errors | 0 |

## Tenant: mereka (Mereka Academy)

**Role**: Platform operator — identical to shared-mereka variant

| # | Action | Object |
|---|--------|--------|
| 1 | CREATE | `Site domain=academyv2.mereka.dev` |
| 2 | CREATE | `EnterpriseCustomer slug=mereka name=Mereka Academy` |
| 3 | CREATE | `Catalog title='Mereka Academy Full Catalog'` |
| 4 | CREATE | `CatalogQuery org_filter=['MEREKA']` |
| 5 | CREATE | `EnterpriseCustomerUser email=team@mereka.io role=admin` |
| 6 | ENSURE | `Waffle Switch enterprise.enable_learner_portal.mereka = on` |
| 7 | ENSURE | `Waffle Switch enterprise.enable_analytics_screen.mereka = on` |
| 8 | ENSURE | `Waffle Switch enterprise.enable_audit_enrollment.mereka = off` |
| 9 | ENSURE | `Waffle Switch enterprise.enable_portal_code_management.mereka = off` |
| 10 | ENSURE | `Waffle Switch enterprise.enable_integrated_learner_portal_search.mereka = on` |

**Catalog visibility**: 109 courses (all MEREKA org courses)

---

## Tenant: bijibiji (Biji-Biji Academy)

**Role**: Partner tenant (ISOLATED)

| # | Action | Object |
|---|--------|--------|
| 1 | CREATE | `Site domain=academy.biji-biji.com` |
| 2 | CREATE | `EnterpriseCustomer slug=bijibiji name=Biji-Biji Academy` |
| 3 | CREATE | `Catalog title='Biji-Biji Academy Catalog'` |
| 4 | CREATE | `CatalogQuery org_filter=['BIJIBIJI']` |
| 5 | CREATE | `EnterpriseCustomerUser email=admin@biji-biji.com role=admin` |
| 6 | ENSURE | `Waffle Switch enterprise.enable_learner_portal.bijibiji = on` |
| 7 | ENSURE | `Waffle Switch enterprise.enable_analytics_screen.bijibiji = on` |
| 8 | ENSURE | `Waffle Switch enterprise.enable_audit_enrollment.bijibiji = off` |
| 9 | ENSURE | `Waffle Switch enterprise.enable_portal_code_management.bijibiji = off` |
| 10 | ENSURE | `Waffle Switch enterprise.enable_integrated_learner_portal_search.bijibiji = on` |

**Catalog visibility**: 0 courses (BIJIBIJI org has no courses yet)

---

## Tenant: skillourfuture (Skill Our Future)

**Role**: Partner tenant (ISOLATED)

| # | Action | Object |
|---|--------|--------|
| 1 | CREATE | `Site domain=skillourfuture.academy.mereka.io` |
| 2 | CREATE | `EnterpriseCustomer slug=skillourfuture name=Skill Our Future` |
| 3 | CREATE | `Catalog title='Skill Our Future Catalog'` |
| 4 | CREATE | `CatalogQuery org_filter=['SKILLOURFUTURE']` |
| 5 | CREATE | `EnterpriseCustomerUser email=admin@mereka.io role=admin` |
| 6 | ENSURE | `Waffle Switch enterprise.enable_learner_portal.skillourfuture = on` |
| 7 | ENSURE | `Waffle Switch enterprise.enable_analytics_screen.skillourfuture = on` |
| 8 | ENSURE | `Waffle Switch enterprise.enable_audit_enrollment.skillourfuture = off` |
| 9 | ENSURE | `Waffle Switch enterprise.enable_portal_code_management.skillourfuture = off` |
| 10 | ENSURE | `Waffle Switch enterprise.enable_integrated_learner_portal_search.skillourfuture = on` |

**Catalog visibility**: 0 courses (SKILLOURFUTURE org has no courses yet)

---

## Object Creation Summary

| Object Type | Count | Notes |
|-------------|-------|-------|
| Site | 3 | One per tenant (may already exist) |
| EnterpriseCustomer | 3 | mereka, bijibiji, skillourfuture |
| EnterpriseCustomerCatalog | 3 | One catalog per tenant |
| CatalogQuery | 3 | Defines org_filter for each catalog |
| EnterpriseCustomerUser | 3 | Admin link per tenant |
| Waffle Switch | 15 | 5 switches per tenant |
| **Total** | **30** | All idempotent (get_or_create) |

## Key Difference From shared-mereka

In this variant, **partner catalogs contain ONLY their own org**:

| Tenant | org_filter (partner-isolated) | org_filter (shared-mereka) |
|--------|-------------------------------|---------------------------|
| mereka | `['MEREKA']` | `['MEREKA']` |
| bijibiji | `['BIJIBIJI']` | `['BIJIBIJI', 'MEREKA']` |
| skillourfuture | `['SKILLOURFUTURE']` | `['SKILLOURFUTURE', 'MEREKA']` |

## Consequence: Empty Partner Catalogs

| Tenant | Courses visible | Learner portal state |
|--------|----------------|---------------------|
| mereka | 109 | Populated |
| bijibiji | **0** | **Empty — no courses to show** |
| skillourfuture | **0** | **Empty — no courses to show** |

Partner portals will render but show no content until partners create courses under their own org codes (BIJIBIJI, SKILLOURFUTURE).
