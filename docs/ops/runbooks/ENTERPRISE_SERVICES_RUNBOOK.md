# Enterprise Services Runbook
_Audience: Operators and enterprise admins • Owner: Platform Team • Last verified: 2026-04-09 • Status: canonical_

Use this runbook as the operational entry point for enterprise microservices, tenant entitlements, and enterprise admin surfaces.

## Start here

- [`../../guides/admin/ENTERPRISE_SERVICES_GUIDE.md`](../../guides/admin/ENTERPRISE_SERVICES_GUIDE.md)
- [`../../reference/operations/ENTERPRISE_MULTI_TENANCY_NAVIGATION.md`](../../reference/operations/ENTERPRISE_MULTI_TENANCY_NAVIGATION.md)
- [`ENTERPRISE_BOOTSTRAP_APPLY_RUNBOOK.md`](ENTERPRISE_BOOTSTRAP_APPLY_RUNBOOK.md)
- [`TENANT_PROVISIONING.md`](TENANT_PROVISIONING.md)
- [`AUTH_SSO_RUNBOOK.md`](AUTH_SSO_RUNBOOK.md)
- [`ENTERPRISE_SSO_GUIDE.md`](ENTERPRISE_SSO_GUIDE.md)
- [`MULTI_TENANCY_RUNBOOK.md`](MULTI_TENANCY_RUNBOOK.md)

Use this page as the operational router only. Tenant bootstrap/apply execution
docs, variant comparisons, and review-era execution notes should not compete with the
active bootstrap and SSO front doors above.

Historical enterprise onboarding notes may still exist in archive paths, but
they stay background-only. Return to the current front doors above before making
runtime claims or operator changes.

## Service Surfaces In Scope

Treat the enterprise stack as these current service families plus the two portal
surfaces that depend on them:

- `enterprise-catalog`
- `license-manager`
- `enterprise-access`
- `enterprise-subsidy`
- integrated-channel jobs
- enterprise admin portal
- enterprise learner portal

Do not collapse “enterprise is broken” into one undifferentiated incident. The
service family and portal surface must be named before the operator path is
safe.

## Quick Triage Questions

Before changing anything, establish:

1. which tenant or enterprise customer is affected
2. whether the symptom is portal routing, LMS auth, service API behavior, or
   background sync
3. whether the failure is isolated to catalog, license, access, subsidy, or
   channel sync
4. whether the issue is runtime-only or caused by missing tenant/onboarding
   configuration
5. whether the launch can fall back to a non-enterprise path while recovery is
   in progress

## Service Restart Procedure

Use controlled restarts only after tenant scope and failing service family are
clear.

1. identify the affected deployment or job family in the current namespace
2. capture failing pod names, recent logs, and the impacted tenant/customer UUID
3. confirm whether the issue is portal-only before restarting backend services
4. restart the smallest affected surface first
5. verify portal/API recovery and tenant-specific behavior before expanding the
   blast radius

If the symptom is actually SSO/bootstrap misconfiguration, do not hide it behind
blind service restarts.

## Common Failure Scenarios

### Admin Or Learner Portal Loads But Enterprise Data Is Missing

- confirm the correct tenant host and portal route first
- verify the enterprise customer mapping and tenant onboarding state
- determine whether the missing data belongs to catalog, license, subsidy, or
  access evaluation
- if the portal is healthy but data is empty, treat it as a backend or tenant
  config incident, not a frontend-only problem

### License Assignment Or Activation Fails

- verify the tenant/customer and learner identity are correct
- determine whether the failure is allocation, activation, or revocation
- confirm whether the learner should fall back to direct enrollment or remain
  blocked
- preserve the failing entitlement context before retrying mutations

### Catalog Sync Or Visibility Is Wrong

- distinguish catalog publication/state drift from route or auth issues
- confirm whether the bad state is isolated to one enterprise customer or all
  customers
- if integrated-channel sync is involved, move immediately to the channel-sync
  troubleshooting lane below

### Subsidy State Or Balance Looks Wrong

- capture the tenant, subsidy type, and learner/admin action that exposed the
  issue
- check whether this is display drift, stale sync, or a real accounting update
  failure
- do not promise manual correction until the source of truth is identified

## Channel Sync Troubleshooting

For Degreed, Cornerstone, or similar integrated-channel issues:

- confirm which channel is in scope
- confirm whether the failure is configuration, scheduled sync, retry/backoff,
  or downstream payload handling
- use the admin guide to re-check configuration shape before blaming runtime
- preserve dry-run or failed-sync evidence before changing credentials or
  schedules

If the course or client launch depends on a successful sync, record the
degraded fallback posture before continuing.

## SAML And Enterprise Auth Troubleshooting

For enterprise login failures:

- route first through [ENTERPRISE_SSO_GUIDE.md](ENTERPRISE_SSO_GUIDE.md)
- confirm the tenant mapping and enterprise customer linkage before reworking
  provider config
- separate “IdP metadata/config failure” from “LMS login or post-login routing
  failure”
- if login succeeds but landing is wrong, treat it as tenant/runtime routing
  drift, not an IdP success

## Rollback Boundary

### Per-Service Rollback

Use per-service rollback when one enterprise service family is degraded but the
 broader tenant stack remains usable.

- stop or isolate only the failing service lane
- preserve affected tenant evidence
- verify whether portal surfaces can remain partially available
- restore the last known-good deployment path through the governed release lane

### Full Stack Rollback

Use full enterprise rollback only when:

- shared tenant onboarding state is wrong across multiple services
- enterprise portal routing/auth is broadly unusable
- a coordinated promotion introduced a stack-wide regression

Do not describe ad hoc live-cluster mutation as the durable rollback path.
Enterprise rollback still follows the platform-governed promotion and recovery
model.

## Database Backup And Restore Boundary

Enterprise services rely on shared platform durability rather than a special
enterprise-only backup system.

Use these current owners:

- [DISASTER_RECOVERY.md](DISASTER_RECOVERY.md)
- [MONGODB_ATLAS_RUNBOOK.md](MONGODB_ATLAS_RUNBOOK.md)
- [BACKUP_COVERAGE_MATRIX.md](../../reference/operations/BACKUP_COVERAGE_MATRIX.md)

This runbook should define when enterprise operators escalate into recovery. It
should not restate the whole backup system.

## License, Catalog, And Subsidy Evidence Expectations

Before approving a risky recovery or override:

- record the affected tenant/customer
- capture the exact learner/admin symptom
- identify the source of truth for the expected entitlement/catalog/subsidy
  state
- name the fallback posture if the recovery must be delayed
- preserve the operator handoff entry showing who accepted the action

## Canonical Companion Surfaces

- platform authority boundary:
  [../../architecture/PLATFORM_AUTHORITY_MAP.md](../../architecture/PLATFORM_AUTHORITY_MAP.md)
- admin-facing setup and sync guidance:
  [../../guides/admin/ENTERPRISE_SERVICES_GUIDE.md](../../guides/admin/ENTERPRISE_SERVICES_GUIDE.md)
- SSO and IdP onboarding:
  [ENTERPRISE_SSO_GUIDE.md](ENTERPRISE_SSO_GUIDE.md)
- tenant routing and portal navigation:
  [../../reference/operations/ENTERPRISE_MULTI_TENANCY_NAVIGATION.md](../../reference/operations/ENTERPRISE_MULTI_TENANCY_NAVIGATION.md)
