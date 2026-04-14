# Content Libraries v2 Operations Runbook
_Audience: Platform operators and migration owners • Owner: Platform Team • Last verified: 2026-04-10 • Status: canonical_

Use this runbook for operator procedures around Content Libraries v2.

This is the current owner for bulk library-operations guidance. It complements,
but does not replace:

- [CONTENT_LIBRARIES_V2_MIGRATION.md](CONTENT_LIBRARIES_V2_MIGRATION.md)
- [CONTENT_LIBRARIES_DISASTER_RECOVERY.md](CONTENT_LIBRARIES_DISASTER_RECOVERY.md)
- [../../concepts/architecture/content-libraries-overview.md](../../concepts/architecture/content-libraries-overview.md)
- [../../reference/operations/LIBRARIES_GCS_SETUP.md](../../reference/operations/LIBRARIES_GCS_SETUP.md)
- [../../../specs/content-libraries-v2_spec.md](../../../specs/content-libraries-v2_spec.md)

## Current Status

As of 2026-04-10:

- Content Libraries v2 is a real platform surface.
- The dedicated bulk library tooling described in the spec and plan is still a
  planned/gated workflow, not a universally enabled operator command.
- This runbook owns the intended bulk-operation procedure shape so future work
  does not point at retired placeholder roots.

Do not claim bulk-create or org-migration support as production-ready until the
implementing command/feature flag and verification steps land.

## When To Use This Runbook

Use this runbook when you need to:

- verify whether bulk library create/import is available in the current lane
- prepare a library inventory for enterprise onboarding
- plan a library migration between organizations
- verify which metadata and storage dependencies must be preserved before a
  library import/export or migration

Use the disaster-recovery companion when the task is backup, restore, or
recovery.

## Operation Classes

Treat bulk library work as one of four distinct classes:

| Class | Typical trigger | Current boundary |
| --- | --- | --- |
| Bulk create | new tenant or program needs many libraries seeded at once | planned/gated command path only |
| Bulk import | known export or CSV source needs to be ingested | planned/gated command path only |
| Inter-org migration | ownership must move between organizations | governed migration path with permission reset checks |
| Bulk metadata repair | slugs, ownership, or visibility metadata need coordinated correction | operator-only; never ad-hoc author self-service |

If the requested work does not fit one of these classes, stop and define the
operation more precisely before acting.

## Preconditions

Before any bulk library operation:

1. Confirm the target lane and tenant in [../../reference/platform/DOMAIN_AND_ACCESS_REFERENCE.md](../../reference/platform/DOMAIN_AND_ACCESS_REFERENCE.md).
2. Confirm storage/backing services in [../../reference/operations/LIBRARIES_GCS_SETUP.md](../../reference/operations/LIBRARIES_GCS_SETUP.md).
3. Confirm the governing contract in [../../../specs/content-libraries-v2_spec.md](../../../specs/content-libraries-v2_spec.md).
4. Confirm whether the bulk-import gate is actually enabled in the current environment.

If the feature flag or command is absent, stop and treat the operation as
planned work, not an ad-hoc shell exercise.

## Minimum Source Inventory

Before any bulk operation, collect:

- source organization and target organization
- library keys or slugs in scope
- expected title and visibility metadata
- source CSV or export artifact version
- permission owners for the destination state
- rollback source if the operation mutates an existing library set

Do not start a bulk operation with only a verbal list of titles or slugs.

## Bulk Library Creation

### Intended Command Contract

The planned bulk-create flow is based on:

- management command: `./manage.py create_libraries_from_csv`
- gate: `CONTENT_LIBRARIES_BULK_IMPORT_ENABLED`

### CSV Shape

The current planned CSV format is:

| Column | Meaning |
| --- | --- |
| `org` | owning organization |
| `slug` | URL-safe library slug |
| `title` | library display title |
| `description` | human-readable purpose |
| `library_type` | library type / restriction mode |

### Operator Checklist

Before running any bulk-create implementation:

- validate the organization list with the owning tenant/course-author admins
- confirm slug naming conventions are approved
- confirm duplicate-slug handling behavior
- confirm the import is idempotent or has a rollback plan
- capture the source CSV in the release/migration evidence set

### Current Boundary

If the command is not present or the feature gate is disabled:

- do not invent an unsupported import workflow
- record the request as deferred implementation work
- link the request back to the content-libraries plan/spec

## Post-Operation Verification

After any bulk library operation, verify:

1. every expected library key exists in the correct organization scope
2. titles, slugs, and visibility metadata match the source inventory
3. permissions match the intended author/admin set
4. a sample of components renders correctly in the authoring/API surface
5. any destination courses or references still resolve correctly

If any verification item fails, stop and record the operation as partial rather
than calling it complete.

## Library Migration Between Organizations

The current planned migration procedure is:

1. export the source library
2. update organization metadata for the target organization
3. import into the target organization
4. verify permissions reset to the target org admins
5. verify content and version history preservation

### Required Checks

For any future implementation, verify:

- target org admins are assigned correctly
- stale source-org permissions are removed
- referenced content remains intact
- publish/version history is preserved or explicitly documented if not preserved
- analytics/usage records are not silently attributed to the wrong org

## Evidence Expectations

Any bulk library operation should leave:

- source CSV or export artifact
- operator command transcript or workflow link
- before/after library inventory
- permission verification evidence
- rollback or restore notes if the operation mutates existing libraries
- explicit operator classification of the operation type

## Related

- Migration context: [CONTENT_LIBRARIES_V2_MIGRATION.md](CONTENT_LIBRARIES_V2_MIGRATION.md)
- Recovery: [CONTENT_LIBRARIES_DISASTER_RECOVERY.md](CONTENT_LIBRARIES_DISASTER_RECOVERY.md)
- Storage setup: [../../reference/operations/LIBRARIES_GCS_SETUP.md](../../reference/operations/LIBRARIES_GCS_SETUP.md)
- Architecture model: [../../concepts/architecture/content-libraries-overview.md](../../concepts/architecture/content-libraries-overview.md)
- Verification: [../../../scripts/qa/verify-content-libraries-v2.sh](../../../scripts/qa/verify-content-libraries-v2.sh)
