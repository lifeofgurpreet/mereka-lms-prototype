# Tenant Provisioning Runbook
_Audience: Platform Eng + Operations • Owner: Engineering Lead • Last updated: 2026-02-10_

This runbook covers operational procedures for multi-tenant provisioning and management.

> **Status**: Multi-tenancy architecture foundation is **in progress** (Tier 4.1). TenantConfig model, middleware, and provisioning command are implemented.
> **Spec**: `specs/multi-tenancy-architecture_spec.md`
> **Testmap**: `specs/testmaps/multi-tenancy-architecture_testmap.yaml`

## Prerequisites

- Django admin access (`/admin/`)
- Kubernetes access to `mereka-lms` namespace
- Infisical access for tenant-specific secrets
- Cloudflare access for DNS configuration

---

## Provisioning a New Tenant (End-to-End)

### Automated Provisioning (Preferred)
```bash
# Provision all core records in one command (idempotent — safe to re-run):
kubectl exec -n mereka-lms -l app.kubernetes.io/name=lms -- \
  python manage.py lms provision_tenant \
    --slug client-corp \
    --name "Client Corp" \
    --domain client.academyv2.mereka.io \
    --contact-email admin@clientcorp.com \
    --country MY
```
This creates: Django Site, SiteConfiguration, EnterpriseCustomer, and TenantConfig in one step.

### Manual Procedure (Alternative)
1. **Create Site and SiteConfiguration**:
   ```bash
   kubectl exec -n mereka-lms -l app.kubernetes.io/name=lms -- \
     python manage.py lms create_site \
       --domain "client.academyv2.mereka.io" \
       --site-name "Client Learning Portal"
   ```
2. **Create EnterpriseCustomer** (via Django admin or API):
   - Navigate to `/admin/enterprise/enterprisecustomer/add/`
   - Fill in:
     - Name: "Client Corp"
     - UUID: (auto-generated)
     - Slug: `client-corp`
     - Site: Select site created above
     - Active: True
3. **Configure Branding**:
   ```bash
   # Upload client logo to object storage
   gsutil cp client-logo.png gs://mereka-lms-assets/branding/client-corp/

   # Update branding config
   kubectl exec -n mereka-lms -l app.kubernetes.io/name=lms -- \
     python manage.py lms configure_branding \
       --enterprise-uuid <uuid> \
       --logo-url "https://assets.academyv2.mereka.io/branding/client-corp/logo.png" \
       --primary-color "#003366" \
       --secondary-color "#FF6600"
   ```
4. **Configure DNS** (Cloudflare):
   - Add CNAME: `client.academyv2.mereka.io` → `academyv2.mereka.io`
   - Enable proxy (orange cloud) for Cloudflare SSL
5. **Create Enterprise Catalog**:
   ```bash
   kubectl exec -n mereka-lms -l app.kubernetes.io/name=enterprise-catalog -- \
     python manage.py create_catalog \
       --enterprise-customer-uuid <uuid> \
       --title "Client Corp Catalog" \
       --content-filter '{"content_type":"course","content_key":["course-v1:*"]}'
   ```
6. **Configure SSO/SAML** (if applicable):
   - Add IdP metadata URL in Django admin
   - Set entity ID: `https://client.academyv2.mereka.io`
   - Test SSO login with client test user
7. **Create License Pool** (if subscription model):
   ```bash
   kubectl exec -n mereka-lms -l app.kubernetes.io/name=license-manager -- \
     python manage.py create_subscription_plan \
       --enterprise-customer-uuid <uuid> \
       --licenses 500 \
       --expiration-date 2025-12-31
   ```
8. **Grant Admin Access**:
   - Add client admin users to enterprise admin role
   - Send invite to enterprise admin portal
9. **Verify Isolation** (run automated tests):
   ```bash
   kubectl exec -n mereka-lms -l app.kubernetes.io/name=lms -- \
     python manage.py lms test_tenant_isolation --enterprise-uuid <uuid>
   ```

### Acceptance
- Tenant has unique domain and branding
- Catalog shows only approved courses
- SSO login works for client users
- Zero cross-tenant data visible in admin portal
- Analytics dashboard shows only tenant's data
- Isolation tests pass (no data leakage)

---

## Verifying Tenant Isolation (Security Check)

### Procedure
1. **Test data leakage** (automated):
   ```bash
   kubectl exec -n mereka-lms -l app.kubernetes.io/name=lms -- \
     python manage.py lms test_tenant_isolation \
       --tenant-a <uuid-a> \
       --tenant-b <uuid-b>
   ```
2. **Manual verification**:
   - Log in as Tenant A admin
   - Attempt to access Tenant B's catalog API:
     ```bash
     curl -H "Authorization: Bearer <tenant-a-token>" \
       https://api.academyv2.mereka.io/enterprise/v1/enterprise-catalogs/<tenant-b-catalog-id>/
     # Should return 403 Forbidden
     ```
   - Verify Tenant A admin portal shows zero Tenant B records
3. **Check database queries**:
   ```bash
   kubectl exec -n mereka-lms -l app.kubernetes.io/name=lms -- \
     python manage.py lms check_queryset_filtering \
       --enterprise-uuid <uuid>
   # Verifies all queries include enterprise_customer_uuid filter
   ```

### Acceptance
- Tenant A cannot list/view/edit Tenant B's data via API
- Tenant A admin portal shows zero Tenant B records
- All database queries include tenant filter (no full-table scans)
- Isolation test suite returns PASS

---

## Offboarding a Tenant (Data Deletion)

### Procedure (CRITICAL - Requires Legal Approval)
1. **Verify approval**:
   - Obtain written approval from client and legal team
   - Confirm no legal hold or retention requirement
2. **Export tenant data** (for compliance):
   ```bash
   kubectl exec -n mereka-lms -l app.kubernetes.io/name=lms -- \
     python manage.py lms export_tenant_data \
       --enterprise-uuid <uuid> \
       --output /tmp/tenant-export.zip
   ```
3. **Download and archive export**:
   ```bash
   kubectl cp mereka-lms/<pod>:/tmp/tenant-export.zip ./tenant-export-<uuid>.zip
   gsutil cp tenant-export-<uuid>.zip gs://mereka-lms-backups/tenant-offboarding/
   ```
4. **Revoke all licenses**:
   ```bash
   kubectl exec -n mereka-lms -l app.kubernetes.io/name=license-manager -- \
     python manage.py revoke_all_licenses --enterprise-uuid <uuid>
   ```
5. **Delete tenant data** (MySQL):
   ```bash
   kubectl exec -n mereka-lms -l app.kubernetes.io/name=lms -- \
     python manage.py lms delete_tenant_data \
       --enterprise-uuid <uuid> \
       --confirm
   ```
6. **Delete tenant data** (MongoDB Atlas):
   ```bash
   kubectl exec -n mereka-lms -l app.kubernetes.io/name=lms -- \
     python manage.py lms delete_tenant_forum_data \
       --enterprise-uuid <uuid> \
       --confirm
   ```
7. **Delete tenant data** (ClickHouse analytics):
   ```bash
   kubectl exec -n mereka-lms -l app.kubernetes.io/name=lms -- \
     python manage.py lms delete_tenant_analytics_data \
       --enterprise-uuid <uuid> \
       --confirm
   ```
8. **Remove DNS records** (Cloudflare)
9. **Mark EnterpriseCustomer as deleted** (soft delete):
   ```bash
   kubectl exec -n mereka-lms -l app.kubernetes.io/name=lms -- \
     python manage.py lms deactivate_enterprise_customer \
       --enterprise-uuid <uuid>
   ```
10. **Generate deletion proof**:
    ```bash
    kubectl exec -n mereka-lms -l app.kubernetes.io/name=lms -- \
      python manage.py lms generate_deletion_proof \
        --enterprise-uuid <uuid> \
        --output /tmp/deletion-proof.json
    ```

### Acceptance
- All tenant data deleted from MySQL, MongoDB, ClickHouse
- Tenant users can no longer log in
- DNS records removed
- Data export archived in GCS
- Cryptographic deletion proof generated
- Deletion logged for audit

---

## Troubleshooting Cross-Tenant Data Leakage

### Symptoms
- Tenant A admin sees Tenant B's courses/users in portal
- API returns data from wrong tenant

### Diagnosis
1. Reproduce issue and capture API request:
   ```bash
   # Log API request/response
   kubectl logs -n mereka-lms -l app.kubernetes.io/name=lms --tail=100 | grep -A 10 "enterprise-catalogs"
   ```
2. Check database query:
   ```sql
   -- Verify query includes tenant filter
   SELECT * FROM enterprise_catalog
   WHERE enterprise_customer_uuid = '<uuid>';
   ```
3. Identify missing filter in code:
   - Search codebase for API view/queryset
   - Check if `filter_queryset_by_tenant()` is applied

### Resolution
1. **Immediate mitigation**: Disable affected API endpoint
   ```bash
   kubectl set env deployment/lms ENABLE_ENTERPRISE_CATALOG_API=false -n mereka-lms
   ```
2. **Fix code**: Add tenant filter to queryset
   ```python
   # Example fix
   queryset = EnterpriseCatalog.objects.filter(
       enterprise_customer_uuid=self.request.user.enterprise_customer_uuid
   )
   ```
3. **Deploy fix**: Release patch version
4. **Re-enable API**: After verification
5. **Notify affected tenants**: If data was exposed

### Acceptance
- Data leakage is stopped immediately
- Root cause identified and fixed in code
- Isolation tests updated to catch similar issues
- Post-mortem documented

---

## Monitoring Tenant Metrics

### Key Metrics (Per-Tenant)
```bash
# Active users per tenant
kubectl exec -n mereka-lms prometheus-0 -- \
  promtool query instant 'sum(lms_active_users) by (enterprise_customer_uuid)'

# Enrollment count per tenant
kubectl exec -n mereka-lms prometheus-0 -- \
  promtool query instant 'sum(lms_enrollments) by (enterprise_customer_uuid)'

# API requests per tenant
kubectl exec -n mereka-lms prometheus-0 -- \
  promtool query instant 'rate(lms_api_requests_total[5m]) by (enterprise_customer_uuid)'
```

### Alerts
- **Critical**: Tenant isolation test fails (data leakage detected)
- **Warning**: Tenant API error rate >5% for 15 minutes
- **Info**: New tenant provisioned (for tracking)
- **Info**: Tenant offboarding initiated (for audit)

---

## Related Documentation
- **Spec**: `specs/multi-tenancy-architecture_spec.md`
- **Architecture**: `docs/architecture/multi-tenancy-overview.md`
- **Enterprise Services**: `specs/enterprise-microservices_spec.md`
- **General Troubleshooting**: `docs/operations/TROUBLESHOOTING.md`
