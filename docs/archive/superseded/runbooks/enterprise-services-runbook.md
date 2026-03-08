# Enterprise Microservices Runbook
_Audience: Platform Eng + Enterprise Operations • Owner: Engineering Lead • Last updated: 2026-02-27_

This runbook covers operational procedures for the enterprise microservices suite.

> **Status**: Enterprise microservices are deployed with two operational profiles:
> - **active profile**: services scaled up and serving traffic
> - **parked profile**: services intentionally scaled to `0` until activation window
> **Spec**: `specs/enterprise-microservices_spec.md`
> **Testmap**: `specs/testmaps/enterprise-microservices_spec.testmap.yml`

## Prerequisites

- Kubernetes access to `mereka-lms` namespace
- Django admin access for LMS
- Enterprise admin portal access
- MySQL/Redis access for troubleshooting

---

## Onboarding a New Enterprise Customer

### Procedure
1. Run deterministic onboarding workflow in dry-run mode:
   ```bash
   ./scripts/tenants/onboard-enterprise-tenant.sh \
     --slug client-corp \
     --name "Client Corp" \
     --domain client.academyv2.mereka.io \
     --idp-type saml \
     --idp-slug tpa-saml-client-corp \
     --display-name "Client Corp SAML" \
     --metadata-url "https://idp.client-corp.com/metadata.xml" \
     --entity-id "https://idp.client-corp.com/entity" \
     --dry-run
   ```
2. Apply onboarding workflow:
   ```bash
   ./scripts/tenants/onboard-enterprise-tenant.sh \
     --slug client-corp \
     --name "Client Corp" \
     --domain client.academyv2.mereka.io \
     --idp-type saml \
     --idp-slug tpa-saml-client-corp \
     --display-name "Client Corp SAML" \
     --metadata-url "https://idp.client-corp.com/metadata.xml" \
     --entity-id "https://idp.client-corp.com/entity" \
     --apply
   ```
3. Verify enterprise runtime gates:
   ```bash
   ./scripts/qa/verify-enterprise-sso-readiness.sh --env prod --mode all --tenant client-corp
   STRICT=1 REQUIRE_ENTERPRISE_SITE_MAPPING=1 ./scripts/qa/verify-multisite-config.sh prod
   ./scripts/qa/verify-enterprise-service-deployment.sh --env prod
   ./scripts/migrations/run-verification-pipeline.sh
   ```
   If environment is intentionally parked (all enterprise deployments at `replicas=0`), use:
   ```bash
   ./scripts/qa/verify-enterprise-service-deployment.sh --env prod --allow-parked-services
   ```
4. Configure enterprise catalogs/license pools and role assignments as required by the customer onboarding plan.

### Acceptance
- Enterprise customer appears in admin portal
- Catalog shows only approved courses
- License pool is created with correct seat count
- SSO login works for client users
- Client admin can access enterprise portal

---

## Allocating Licenses to Learners

### Procedure
1. Access enterprise admin portal at `https://admin.academyv2.mereka.io`
2. Navigate to **Subscriptions** → select license pool
3. Click **Assign Licenses**
4. Upload CSV with learner emails:
   ```csv
   email
   learner1@client.com
   learner2@client.com
   ```
5. Review assignments
6. Click **Confirm Assignment**
7. Verify licenses are allocated:
   ```bash
   kubectl exec -n mereka-lms -l app.kubernetes.io/name=license-manager -- \
     python manage.py list_licenses --enterprise-customer-uuid <uuid>
   ```
8. Verify learners receive invitation emails

### Acceptance
- Licenses are allocated within 60 seconds
- Learners receive email with activation link
- License count decrements in admin portal
- Learners can access enterprise learner portal

---

## Revoking Licenses

### Procedure
1. Access enterprise admin portal
2. Navigate to **Subscriptions** → **Active Licenses**
3. Select learner(s) to revoke
4. Click **Revoke License**
5. Confirm revocation
6. Verify license is revoked:
   ```bash
   kubectl logs -n mereka-lms -l app.kubernetes.io/name=license-manager --tail=50 | grep revoke
   ```
7. Verify learner loses access to enterprise courses:
   - Check LMS enrollment API
   - Verify course access returns 403

### Acceptance
- License is revoked within 60 seconds
- Learner cannot access enterprise courses
- License returns to available pool
- Revocation is logged in audit trail

---

## Syncing Completion Data to Integrated Channel

### Procedure (Example: Degreed integration)
1. Configure channel integration in Django admin:
   - Navigate to `/admin/integrated_channel/degreedenterprisecustomerconfiguration/`
   - Add config for enterprise customer
   - Set Degreed base URL and API credentials
2. Enable sync for course completions:
   ```bash
   kubectl exec -n mereka-lms -l app.kubernetes.io/name=enterprise-integrated-channels -- \
     python manage.py transmit_learner_data \
       --enterprise-customer-uuid <uuid> \
       --channel degreed
   ```
3. Monitor sync job:
   ```bash
   kubectl logs -n mereka-lms -l app.kubernetes.io/name=enterprise-integrated-channels --tail=100 | grep degreed
   ```
4. Verify data appears in Degreed dashboard:
   - Log in to client's Degreed instance
   - Check for recent completions

### Acceptance
- Sync completes within 30 minutes
- All completions since last sync are transmitted
- Errors are logged and retried (max 3 attempts)
- Client sees completion data in their LMS/LXP

---

## Troubleshooting Catalog Query Timeouts

### Symptoms
- Enterprise admin portal shows "Catalog loading..." indefinitely
- API returns 504 Gateway Timeout

### Diagnosis
1. Check catalog service logs:
   ```bash
   kubectl logs -n mereka-lms -l app.kubernetes.io/name=enterprise-catalog --tail=100 | grep -i timeout
   ```
2. Measure query latency:
   ```bash
   kubectl exec -n mereka-lms -l app.kubernetes.io/name=enterprise-catalog -- \
     python manage.py query_catalog --enterprise-customer-uuid <uuid> --benchmark
   ```
3. Identify slow queries in MySQL:
   ```sql
   SELECT * FROM INFORMATION_SCHEMA.PROCESSLIST WHERE TIME > 10;
   ```

### Resolution
- **Large catalog (>1000 courses)**:
  - Enable pagination: `?page=1&page_size=50`
  - Add Redis caching for catalog queries
- **Missing index**:
  ```bash
  kubectl exec -n mereka-lms -l app.kubernetes.io/name=enterprise-catalog -- \
    python manage.py dbshell -c "
    SHOW INDEX FROM enterprise_catalog_catalogquery;
    "
  ```
- **Stale cache**:
  ```bash
  kubectl exec -n mereka-lms -l app.kubernetes.io/name=enterprise-catalog -- \
    python manage.py clear_catalog_cache --enterprise-customer-uuid <uuid>
  ```

### Acceptance
- Catalog queries complete within 300ms at p95
- Pagination is enabled for catalogs >100 courses
- Redis cache hit rate >80%

---

## Monitoring Enterprise Services Health

### Key Metrics
```bash
# Enterprise catalog API latency (p95 < 300ms)
kubectl exec -n mereka-lms prometheus-0 -- \
  promtool query instant 'histogram_quantile(0.95, enterprise_catalog_api_duration_seconds_bucket)'

# License allocation success rate (>99%)
kubectl exec -n mereka-lms prometheus-0 -- \
  promtool query instant 'rate(license_manager_allocations_success_total[5m]) / rate(license_manager_allocations_total[5m])'

# Integrated channel sync success rate (>95%)
kubectl exec -n mereka-lms prometheus-0 -- \
  promtool query instant 'rate(integrated_channels_sync_success_total[5m]) / rate(integrated_channels_sync_attempts_total[5m])'
```

### Alerts
- **Critical**: Enterprise catalog API p95 latency >1s for 10 minutes
- **Warning**: License allocation success rate <95% for 15 minutes
- **Warning**: Integrated channel sync failures >5% for 30 minutes
- **Info**: New enterprise customer created (for onboarding tracking)

---

## Related Documentation
- **Spec**: `specs/enterprise-microservices_spec.md`
- **Architecture**: `docs/architecture/enterprise-services-overview.md`
- **Multi-Tenancy**: `specs/multi-tenancy-architecture_spec.md`
- **General Troubleshooting**: `docs/runbooks/operations/TROUBLESHOOTING.md`
