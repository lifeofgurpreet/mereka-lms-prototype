---
spec: multi-tenancy-architecture_spec.md
plan: plans/multi-tenancy-architecture_plan.md
tier: 4
status: draft
last_updated: "2026-02-10"
---

# Multi-Tenancy Architecture -- Test Plan

**Source Spec**: `specs/multi-tenancy-architecture_spec.md`

## Test Infrastructure

This project uses shell-based verification scripts (`scripts/qa/`) as the primary test framework. There are no unit test frameworks (Vitest, Jest, pytest) configured for infrastructure-level testing. Tests are categorized as:

| Test Type | Tool | Convention |
|-----------|------|------------|
| `shell_verification` | Bash scripts | `scripts/qa/verify-*.sh`, `scripts/qa/audit-*.sh` |
| `kubectl_check` | kubectl commands | Inline kubectl commands checking K8s state |
| `smoke_test` | Bash + curl | `scripts/qa/smoke-*.sh`, HTTP endpoint checks |
| `manual_verification` | Human checklist | Visual checks, admin portal walkthroughs |
| `load_test` | Bash + curl/k6 | `scripts/qa/load-test-*.sh` |

---

## Test Matrix: Acceptance Criteria

### Tenant Identity (AC-001, AC-002)

| AC | Test Case | Type | File / Command | Fixtures / Prerequisites |
|----|-----------|------|----------------|--------------------------|
| AC-001 | Provisioning script creates EnterpriseCustomer, Site, and SiteConfiguration with correct values | `shell_verification` | `scripts/qa/verify-tenant-provisioning.sh` | Clean test database; provisioning script available |
| AC-001 | After provisioning, Django admin shows EnterpriseCustomer with correct UUID, slug, site linkage | `kubectl_check` | `kubectl exec -n mereka-lms deploy/lms -- python manage.py lms shell -c "from enterprise.models import EnterpriseCustomer; print(EnterpriseCustomer.objects.filter(slug='acme-corp').values())"` | Provisioned test tenant |
| AC-002 | Provisioning script re-run with same slug exits with "already provisioned" message | `shell_verification` | `scripts/qa/verify-tenant-provisioning.sh --test-idempotency` | Previously provisioned tenant |
| AC-002 | Provisioning script re-run does NOT create duplicate Site or SiteConfiguration records | `shell_verification` | `scripts/qa/verify-tenant-provisioning.sh --test-no-duplicates` | Previously provisioned tenant |

### Data Isolation (AC-003 through AC-007)

| AC | Test Case | Type | File / Command | Fixtures / Prerequisites |
|----|-----------|------|----------------|--------------------------|
| AC-003 | Admin A calling enterprise-catalogs API returns zero catalogs from tenant B | `shell_verification` | `scripts/qa/verify-tenant-isolation.sh --test=api-catalogs` | Two provisioned tenants with separate catalogs |
| AC-004 | Admin A calling subscriptions API with tenant B UUID returns HTTP 403 | `shell_verification` | `scripts/qa/verify-tenant-isolation.sh --test=api-subscriptions-cross` | Two provisioned tenants; admin A JWT token |
| AC-005 | Admin A querying ClickHouse via Superset sees zero events from tenant B | `manual_verification` | Manual: Log in to Superset as tenant A admin, query xAPI events, verify zero rows with tenant B UUID | Superset RLS configured; both tenants have xAPI events |
| AC-005 | Direct ClickHouse query with tenant A filter returns zero tenant B rows | `shell_verification` | `scripts/qa/verify-tenant-isolation.sh --test=analytics` | ClickHouse with `enterprise_customer_uuid` column populated |
| AC-006 | Non-superuser database role cannot read EnterpriseCustomer records outside their service scope | `kubectl_check` | `kubectl exec -n mereka-lms deploy/lms -- python manage.py lms dbshell` (verify GRANT restrictions) | MySQL user grants configured per enterprise service |
| AC-007 | Multi-org user in learner portal sees tenant selection screen, not aggregated data | `manual_verification` | Manual: Create user in both tenants, login, verify tenant selector appears, verify each tenant shows only its own data | User linked to two EnterpriseCustomer records |

### Branding (AC-008 through AC-011)

| AC | Test Case | Type | File / Command | Fixtures / Prerequisites |
|----|-----------|------|----------------|--------------------------|
| AC-008 | Tenant domain serves tenant-specific logo, not default Mereka logo | `smoke_test` | `scripts/qa/verify-tenant-branding.sh --tenant=acme-corp --check=logo` | Tenant provisioned with custom logo in SiteConfiguration |
| AC-008 | Tenant domain with missing logo falls back to Mereka default (no broken image) | `smoke_test` | `scripts/qa/verify-tenant-branding.sh --tenant=fallback-test --check=logo-fallback` | Tenant provisioned without custom logo |
| AC-009 | Login page at tenant domain uses tenant's primary brand color | `manual_verification` | Manual: Navigate to `acme.academyv2.mereka.io`, inspect CSS custom property `--pgn-color-primary` matches configured value | Tenant provisioned with brand colors |
| AC-010 | Footer at tenant domain shows tenant organization name and tagline | `smoke_test` | `scripts/qa/verify-tenant-branding.sh --tenant=acme-corp --check=footer` | Tenant provisioned with footer config |
| AC-011 | Updated tenant logo served after collectstatic without image rebuild | `shell_verification` | `scripts/qa/verify-tenant-branding.sh --test=hot-update` | Replace logo file, run collectstatic, verify new file is served |

### Domain Routing (AC-012 through AC-014)

| AC | Test Case | Type | File / Command | Fixtures / Prerequisites |
|----|-----------|------|----------------|--------------------------|
| AC-012 | Tenant subdomain responds with tenant-branded page | `smoke_test` | `scripts/qa/smoke-test-tenant.sh --domain=acme.academyv2.mereka.io` | Tenant domain added to Caddy and ALLOWED_HOSTS |
| AC-013 | Client-owned CNAME domain responds with tenant-branded page and valid SSL | `smoke_test` | `scripts/qa/smoke-test-tenant.sh --domain=learning.acmecorp.com --check-ssl` | CNAME configured, Let's Encrypt certificate issued |
| AC-014 | Simultaneous requests to two tenant domains resolve correct SiteConfiguration each | `shell_verification` | `scripts/qa/verify-tenant-isolation.sh --test=concurrent-domain-resolution` | Two tenants with different domains; parallel curl requests |

### Authentication (AC-015 through AC-017)

| AC | Test Case | Type | File / Command | Fixtures / Prerequisites |
|----|-----------|------|----------------|--------------------------|
| AC-015 | `/enterprise/login/{slug}` redirects to configured SAML IdP | `smoke_test` | `scripts/qa/verify-tenant-sso.sh --slug=acme-corp --check=redirect` | SAML IdP configured for tenant |
| AC-016 | New user from SAML assertion is auto-provisioned and linked to correct EnterpriseCustomer | `manual_verification` | Manual: Complete SAML flow with new user, verify EnterpriseCustomerUser record created | SAML IdP returning valid assertion for unregistered email |
| AC-017 | SAML assertion from tenant A IdP links user to tenant A only, not tenant B | `shell_verification` | `scripts/qa/verify-tenant-isolation.sh --test=saml-cross-tenant` | Both tenants with SAML configured; test user authenticates via tenant A |

### Analytics (AC-018 through AC-020)

| AC | Test Case | Type | File / Command | Fixtures / Prerequisites |
|----|-----------|------|----------------|--------------------------|
| AC-018 | xAPI event from enterprise learner includes correct `enterprise_customer_uuid` in ClickHouse | `shell_verification` | `scripts/qa/verify-tenant-analytics.sh --test=event-tagging` | Enterprise learner enrolled in course; `ENABLE_TENANT_ANALYTICS_SCOPING=true` |
| AC-019 | Tenant admin in Superset sees only their tenant's enrollment data (RLS enforced) | `manual_verification` | Manual: Log in to Superset as tenant admin, query enrollment dashboard, verify row count matches tenant's actual enrollments | Superset RLS configured; tenant has enrolled learners |
| AC-020 | Platform operator in Superset sees cross-tenant aggregate data | `manual_verification` | Manual: Log in to Superset as superuser, query cross-tenant overview, verify data from all tenants is visible | Superuser Superset account; multiple tenants with data |

### Provisioning and Offboarding (AC-021 through AC-024)

| AC | Test Case | Type | File / Command | Fixtures / Prerequisites |
|----|-----------|------|----------------|--------------------------|
| AC-021 | Provisioning script creates all required records within 15 minutes | `shell_verification` | `scripts/qa/verify-tenant-provisioning.sh --test=full-provision --timeout=900` | Valid provisioning inputs; clean slate |
| AC-022 | After offboarding data deletion, zero enterprise_catalog records exist for tenant UUID | `shell_verification` | `scripts/qa/verify-tenant-offboarding.sh --test=data-deletion --uuid={tenant_uuid}` | Offboarded test tenant with completed grace period |
| AC-023 | After offboarding, zero ClickHouse events exist for tenant UUID | `shell_verification` | `scripts/qa/verify-tenant-offboarding.sh --test=clickhouse-deletion --uuid={tenant_uuid}` | Offboarded test tenant |
| AC-024 | Offboarding audit log entry exists with correct action, UUID, actor, timestamp | `shell_verification` | `scripts/qa/verify-tenant-offboarding.sh --test=audit-log --uuid={tenant_uuid}` | Completed offboarding action |

### Isolation Verification (AC-025, AC-026)

| AC | Test Case | Type | File / Command | Fixtures / Prerequisites |
|----|-----------|------|----------------|--------------------------|
| AC-025 | Full isolation test suite passes for two provisioned tenants | `shell_verification` | `scripts/qa/verify-tenant-isolation.sh --tenant-a={uuid_a} --tenant-b={uuid_b}` | Two provisioned tenants with catalogs, users, and analytics data |
| AC-025 | Isolation test catches intentionally broken isolation (negative test) | `shell_verification` | `scripts/qa/verify-tenant-isolation.sh --test=negative --inject-leak` | Test harness that temporarily disables queryset filtering |
| AC-026 | Nightly isolation test cron job fires Critical alert on failure | `kubectl_check` | `kubectl get cronjob -n mereka-lms nightly-isolation-test -o yaml` (verify schedule and alerting) + manual trigger with injected failure | CronJob deployed; alert routing configured |

### Performance (AC-027, AC-028)

| AC | Test Case | Type | File / Command | Fixtures / Prerequisites |
|----|-----------|------|----------------|--------------------------|
| AC-027 | Enterprise catalog API p95 latency <= 300ms with 10 tenants | `load_test` | `scripts/qa/load-test-multi-tenant.sh --tenants=10 --duration=300 --threshold-p95=300` | 10 provisioned test tenants with catalogs |
| AC-028 | No tenant p95 exceeds 120% of single-tenant baseline with 50 tenants | `load_test` | `scripts/qa/load-test-multi-tenant.sh --tenants=50 --duration=600 --threshold-ratio=1.2` | 50 provisioned test tenants; single-tenant baseline measurement |

---

## Edge Case Tests

| Edge Case | Test Case | Type | File / Command | Fixtures |
|-----------|-----------|------|----------------|----------|
| EC-01: Partial provisioning recovery | Kill provisioning script mid-execution, re-run, verify no duplicates and all records created | `shell_verification` | `scripts/qa/verify-tenant-provisioning.sh --test=partial-recovery` | Interrupt mechanism (kill -9 after step 3) |
| EC-02: Duplicate slug rejection | Attempt to provision with existing slug, verify rejection before any records created | `shell_verification` | `scripts/qa/verify-tenant-provisioning.sh --test=duplicate-slug` | Existing tenant with target slug |
| EC-03: Duplicate domain rejection | Attempt to provision with domain already mapped to another Site, verify rejection | `shell_verification` | `scripts/qa/verify-tenant-provisioning.sh --test=duplicate-domain` | Existing tenant with target domain |
| EC-04: Invalid SAML metadata | Provision tenant with unreachable SAML metadata URL, verify provisioning continues with SAML as pending | `shell_verification` | `scripts/qa/verify-tenant-provisioning.sh --test=invalid-saml --saml-url=http://unreachable` | Provisioning script with SAML step |
| EC-05: Redis cache key collision prevention | Verify all tenant-specific cache keys include UUID prefix | `shell_verification` | `scripts/qa/verify-tenant-cache-keys.sh` | Two provisioned tenants with cache data |
| EC-06: Missing branding asset fallback | Remove tenant logo file, verify Mereka default is served (no broken image) | `smoke_test` | `scripts/qa/verify-tenant-branding.sh --test=missing-asset-fallback` | Tenant with deleted logo file |
| EC-07: Malformed SiteConfiguration JSON fallback | Set tenant SiteConfiguration.values to invalid JSON, verify default config used, no 500 error | `shell_verification` | `scripts/qa/verify-tenant-branding.sh --test=malformed-siteconfig` | Tenant with intentionally broken SiteConfiguration |
| EC-08: Admin cross-tenant user lookup returns "not found" | Tenant A admin searches for user email belonging only to tenant B, verify "not found" (not "exists in another tenant") | `shell_verification` | `scripts/qa/verify-tenant-isolation.sh --test=user-enumeration-prevention` | User in tenant B only; admin A JWT |
| EC-09: Multi-org user sees tenant selection (no default) | User in both tenants accesses learner portal without explicit context, verify selection screen (no auto-default) | `manual_verification` | Manual: Log in as multi-org user, verify tenant selection prompt | User in two tenants |
| EC-10: Offboarding with active enrollments | Offboard tenant, verify LMS enrollments NOT revoked (only enterprise membership removed) | `shell_verification` | `scripts/qa/verify-tenant-offboarding.sh --test=active-enrollments-preserved` | Tenant with enrolled learners |
| EC-11: ClickHouse query without tenant filter blocked by RLS | Non-superuser Superset query omitting enterprise_customer_uuid filter is blocked | `manual_verification` | Manual: Create Superset query without filter as tenant admin, verify query is blocked or returns empty | Superset RLS policies active |
| EC-12: Tenant-scoped rate limits independent | Tenant A hitting rate limit does not affect tenant B API access | `load_test` | `scripts/qa/load-test-multi-tenant.sh --test=rate-limit-independence` | Two tenants; rate limit configuration |
| EC-13: SAML assertion for wrong tenant rejected | Send SAML assertion with issuer not matching any configured IdP, verify rejection and security event logged | `shell_verification` | `scripts/qa/verify-tenant-sso.sh --test=wrong-issuer` | SAML test harness with incorrect issuer |
| EC-14: Pending user invited by multiple tenants | Same email with PendingEnterpriseCustomerUser in two tenants; on registration, both memberships created | `shell_verification` | `scripts/qa/verify-tenant-provisioning.sh --test=pending-multi-tenant` | Pending records in two tenants |
| EC-15: Data deletion race condition | Run deletion while event bus delivers delayed messages, verify re-scan catches late records | `shell_verification` | `scripts/qa/verify-tenant-offboarding.sh --test=deletion-race` | Offboarding script with simulated delayed event |

---

## Test Execution Plan

### Phase 0 Gate (Week 2)

Run before proceeding to Phase 1:

```bash
# Verify provisioning script skeleton works
scripts/qa/verify-tenant-provisioning.sh --dry-run

# Verify isolation test skeleton runs without error
scripts/qa/verify-tenant-isolation.sh --dry-run

# Verify ClickHouse schema migration applied
scripts/qa/verify-tenant-analytics.sh --test=schema-check

# Verify feature flags are all OFF
scripts/qa/verify-tenant-flags.sh --expect=all-off

# Verify tenant branding directory exists
test -d infrastructure/tutor/themes/mereka/tenants/_template/ && echo "PASS" || echo "FAIL"
```

### Phase 1 Gate (Week 4)

Run before proceeding to Phase 2:

```bash
# Verify Mereka self-tenant provisioned correctly
scripts/qa/verify-tenant-provisioning.sh --tenant=mereka-academy

# Verify existing smoke tests still pass (regression)
scripts/qa/smoke-test.sh

# Verify single-tenant isolation baseline
scripts/qa/verify-tenant-isolation.sh --single-tenant --tenant={mereka_uuid}

# Verify branding flag enabled and default branding unchanged
scripts/qa/verify-tenant-branding.sh --tenant=mereka-academy --check=default-unchanged

# Verify ClickHouse backfill complete
scripts/qa/verify-tenant-analytics.sh --test=backfill-complete
```

### Phase 2 Gate (Week 7)

Run before proceeding to Phase 3:

```bash
# FULL isolation test suite
scripts/qa/verify-tenant-isolation.sh --tenant-a={mereka_uuid} --tenant-b={client_uuid}

# Verify pilot client branding
scripts/qa/verify-tenant-branding.sh --tenant={client_slug}

# Smoke test both tenant domains
scripts/qa/smoke-test-tenant.sh --domain=academyv2.mereka.io
scripts/qa/smoke-test-tenant.sh --domain={client_domain}

# Verify SSO redirect
scripts/qa/verify-tenant-sso.sh --slug={client_slug} --check=redirect
```

### Phase 3 Gate (Week 10)

Run before declaring operational readiness:

```bash
# Nightly isolation job configured and tested
kubectl get cronjob -n mereka-lms nightly-isolation-test

# Offboarding tested end-to-end
scripts/qa/verify-tenant-offboarding.sh --test=full-cycle --uuid={test_tenant_uuid}

# Load test with 10 tenants
scripts/qa/load-test-multi-tenant.sh --tenants=10

# All dashboards rendering
scripts/qa/audit-grafana-dashboard.sh --dashboards=multi-tenancy-overview,tenant-health,noisy-neighbor,isolation-compliance

# Edge case suite
scripts/qa/verify-tenant-provisioning.sh --test=all-edge-cases
scripts/qa/verify-tenant-isolation.sh --test=all-edge-cases
```

### Phase 4 Gate (Week 12+)

```bash
# 50-tenant load test
scripts/qa/load-test-multi-tenant.sh --tenants=50

# ClickHouse partition benchmarks documented
test -f infrastructure/clickhouse/benchmarks/partition-strategy.md && echo "PASS"

# Scaling report documented
test -f docs/architecture/multi-tenancy-scaling-report.md && echo "PASS"
```

---

## Test Coverage Summary

| Category | AC Count | Automated Tests | Manual Tests | Total Coverage |
|----------|----------|-----------------|--------------|----------------|
| Tenant Identity | 2 | 4 | 0 | 100% |
| Data Isolation | 5 | 4 | 2 | 100% |
| Branding | 4 | 4 | 1 | 100% |
| Domain Routing | 3 | 3 | 0 | 100% |
| Authentication | 3 | 2 | 1 | 100% |
| Analytics | 3 | 1 | 2 | 100% |
| Provisioning/Offboarding | 4 | 4 | 0 | 100% |
| Isolation Verification | 2 | 3 | 0 | 100% |
| Performance | 2 | 2 | 0 | 100% |
| **Edge Cases** | 15 | 12 | 3 | 100% |
| **TOTAL** | **28 ACs + 15 ECs** | **39** | **9** | **100%** |
