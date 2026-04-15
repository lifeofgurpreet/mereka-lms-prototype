# Content Libraries Enterprise Onboarding

Use this guide when a tenant or enterprise onboarding owner needs to decide how
Content Libraries v2 should be introduced for a new client, program, or shared
content domain.

Primary handbook entry point:

- [../INDEX_BY_AUDIENCE.md](../INDEX_BY_AUDIENCE.md)

This guide complements, but does not replace:

- [ENTERPRISE_SERVICES_GUIDE.md](ENTERPRISE_SERVICES_GUIDE.md)
- [MULTI_SITE_GUIDE.md](MULTI_SITE_GUIDE.md)
- [../../concepts/architecture/content-libraries-overview.md](../../concepts/architecture/content-libraries-overview.md)
- [../../ops/runbooks/CONTENT_LIBRARIES_V2_RUNBOOK.md](../../ops/runbooks/CONTENT_LIBRARIES_V2_RUNBOOK.md)
- [../../ops/runbooks/TENANT_PROVISIONING.md](../../ops/runbooks/TENANT_PROVISIONING.md)

## Current Boundary

As of 2026-04-10:

- Content Libraries v2 is a real reusable-content surface.
- Library ownership is organization-scoped and must respect tenant boundaries.
- Platform-shared libraries are a deliberate governance choice, not a default.
- Bulk import and large migration workflows remain gated operator paths.

Do not promise a self-serve tenant migration/import workflow unless the current
lane has explicit operator proof for it.

## Onboarding Intake Package

Before creating or assigning tenant libraries, collect:

- tenant or organization name
- intended library owners
- whether the content is tenant-private or intentionally shared
- expected component types
- whether existing content must be migrated or only new libraries created
- expected launch date and first course consumers

If those answers are incomplete, the library onboarding decision is still
exploratory.

## Decide The Ownership Model First

Choose one of these before creating anything:

| Model | Use when | Boundary |
| --- | --- | --- |
| Tenant-scoped library | content is specific to one enterprise customer or org | visible only inside that tenant/org boundary |
| Platform-shared reusable library | content is intentionally reused across many tenants or programs | requires deliberate shared-library governance |
| Course-team-only library | content supports a narrow program or authoring group | should not be represented as enterprise-shared infrastructure |

Do not start by creating a platform-global library and “sorting permissions out
later.”

## Tenant Creation And Library Setup

For a new tenant:

1. complete tenant/site provisioning first
2. confirm the owning organization exists and is staffed correctly
3. create the initial libraries in the correct organization scope
4. assign Library Admin and Library Author roles deliberately
5. record the library keys/slugs in the onboarding evidence set

If the tenant itself is not provisioned cleanly yet, stop and resolve that
through [../../ops/runbooks/TENANT_PROVISIONING.md](../../ops/runbooks/TENANT_PROVISIONING.md)
before starting library setup.

## Shared Versus Tenant-Private Content

Ask these questions:

- should another tenant ever see or reuse this content?
- who approves updates?
- who is allowed to publish changes?
- would a future change create contractual or branding risk if reused broadly?

If the answer is uncertain, default to tenant-private ownership.

## Search, Analytics, And Discovery Expectations

Search and analytics are companion lanes, not the ownership source of truth.

- library ownership and visibility are decided by organization scope and
  permissions
- search may help discovery when enabled
- analytics may help usage reporting when enabled

Do not use absent search or analytics data as proof that onboarding failed.

## Launch Checklist

Before calling the tenant ready:

- the correct owning organization is attached
- initial admins/authors are assigned
- the intended libraries exist with the right slugs and titles
- sample components are published where needed
- at least one destination course or authoring workflow has been verified if
  the launch depends on immediate reuse
- any gated bulk-import or migration dependency is explicitly classified

## No-Promise Rules

Do not promise:

- self-serve tenant-to-tenant library migration
- tenant admins operating bulk import tooling themselves
- cross-tenant shared libraries without explicit governance approval
- analytics dashboards or search coverage in a lane that has not enabled them

## Escalate When

Escalate to platform operators when:

- organization ownership is unclear
- cross-tenant visibility looks wrong
- the tenant needs bulk import or migration support
- a publish/reference workflow is failing during onboarding validation
- search or analytics behavior is being mistaken for ownership truth

## Metadata

- Owner: Platform Team
- Last reviewed: 2026-04-10
- Applies to: tenant admins, enterprise onboarding owners, and platform
  operators onboarding library use for enterprise clients
