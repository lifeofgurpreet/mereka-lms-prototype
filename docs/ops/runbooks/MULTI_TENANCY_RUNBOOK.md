# Multi-Tenancy Runbook
_Audience: Platform Eng + Enterprise Account Managers • Owner: Engineering Lead • Last updated: 2026-02-10_

This runbook covers operational procedures for multi-tenancy architecture verification.

> **Status**: Multi-tenancy is **partially implemented** (Tier 4.1). Core tenant isolation via Open edX Organizations is operational. Full enterprise tenant management is in progress.
> **Spec**: `specs/multi-tenancy-architecture_spec.md`
> **Testmap**: `specs/testmaps/multi-tenancy-architecture_spec.testmap.yml`

## Prerequisites

- LMS admin access
- Multiple test user accounts across different tenant organizations
- Access to production GKE cluster

---

## Tenant Isolation Verification

### Procedure
1. Create test accounts in two different organizations (e.g., `org-a`, `org-b`)
2. Log in as `org-a` user:
   - Verify only `org-a` courses are visible in catalog
   - Verify `org-b` course URLs return 403/404
   - Verify dashboard shows only `org-a` enrollments
3. Log in as `org-b` user:
   - Verify only `org-b` courses are visible
   - Verify `org-a` course URLs return 403/404
4. Log in as platform admin:
   - Verify admin can see all organizations
   - Verify admin can switch context between tenants
5. Verify data isolation at the database level:
   ```bash
   kubectl exec -n mereka-lms deploy/lms -- python manage.py lms shell -c "
   from organizations.models import Organization
   for org in Organization.objects.all():
       print(f'{org.short_name}: {org.courseorganizationmapping_set.count()} courses')
   "
   ```

### Acceptance
- Users in org-a cannot see or access org-b content
- Users in org-b cannot see or access org-a content
- Platform admin has cross-tenant visibility
- No data leakage between tenant boundaries
- API responses respect organization filtering
