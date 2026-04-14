# Content Libraries v2 Disaster Recovery
_Audience: Platform operators and migration owners • Owner: Platform Team • Last verified: 2026-04-10 • Status: canonical_

Use this runbook for backup, restore, and recovery procedures specific to
Content Libraries v2.

This is the current owner for content-library recovery guidance. It
complements, but does not replace:

- [CONTENT_LIBRARIES_V2_RUNBOOK.md](CONTENT_LIBRARIES_V2_RUNBOOK.md)
- [CONTENT_LIBRARIES_V2_MIGRATION.md](CONTENT_LIBRARIES_V2_MIGRATION.md)
- [../../concepts/architecture/content-libraries-overview.md](../../concepts/architecture/content-libraries-overview.md)
- [../../reference/operations/LIBRARIES_GCS_SETUP.md](../../reference/operations/LIBRARIES_GCS_SETUP.md)
- [../../../specs/content-libraries-v2_spec.md](../../../specs/content-libraries-v2_spec.md)

## Current Boundary

As of 2026-04-10:

- Content Libraries v2 is a real platform authoring surface
- recovery depends on both metadata and object-storage durability
- this runbook defines the recovery shape and evidence expectations
- do not claim a fully verified library DR lane unless backup and restore have
  been exercised in the target lane with evidence

## What Must Be Preserved

Recovery is incomplete unless all of the following survive:

- library metadata and ownership
- component content
- version history
- team and permission assignments
- referenced storage bundles

Restoring only the metadata row or only the object-storage payload is not a
successful library recovery.

## Recovery Dependencies

The current recovery model depends on:

- metadata persistence for library records and relationships
- durable Blockstore/object storage backing
- the current Blockstore/GCS setup documented in
  [../../reference/operations/LIBRARIES_GCS_SETUP.md](../../reference/operations/LIBRARIES_GCS_SETUP.md)

## Operator Checklist

Before attempting recovery:

1. identify the affected library key and owning organization
2. determine whether this is:
   - soft-delete restore
   - point-in-time metadata restore
   - storage/object recovery
   - full library reconstruction
3. confirm the backup or export source you will use
4. capture before-state evidence
5. confirm whether restored libraries must be re-indexed or revalidated in the
   authoring/API surface

## Recovery Routes

### 1. Soft-delete restore

Use this when the library still exists inside the soft-delete recovery window.

Required outcome:

- the original library key is restored
- permissions are intact
- published and draft state are checked before handing the library back to
  authors

### 2. Metadata restore

Use this when library records or relationships were lost or corrupted.

Required outcome:

- library record restored
- organization and team assignments restored
- version history verified

### 3. Object-storage / Blockstore restore

Use this when content bundles or published library payloads are missing or
corrupted.

Required outcome:

- component payloads restored
- library content renders correctly in the API/authoring surface
- references remain consistent with metadata state

### 4. Full library reconstruction

Use this when both metadata and storage need recovery or when the safest path is
re-import from a known-good export.

Required outcome:

- library recreated or restored with the expected library key or documented
  successor key
- content integrity checked
- permissions reassigned if they are not automatically restored

## Verification Expectations

After recovery, verify:

- the library appears in the expected organization scope
- component count matches the expected baseline
- a sample of components renders correctly
- publish/version history is present or any loss is explicitly recorded
- permissions match the intended owner/team set

If the library is referenced by courses, also verify those references still
behave correctly or record any required resync step.

## Evidence Expectations

Any library recovery event should leave:

- affected library key
- recovery type
- backup/export source used
- before/after library inventory
- permission verification evidence
- any follow-up re-index or resync action

## Related

- Operations: [CONTENT_LIBRARIES_V2_RUNBOOK.md](CONTENT_LIBRARIES_V2_RUNBOOK.md)
- Migration/restore context: [CONTENT_LIBRARIES_V2_MIGRATION.md](CONTENT_LIBRARIES_V2_MIGRATION.md)
- Architecture model: [../../concepts/architecture/content-libraries-overview.md](../../concepts/architecture/content-libraries-overview.md)
- Storage setup: [../../reference/operations/LIBRARIES_GCS_SETUP.md](../../reference/operations/LIBRARIES_GCS_SETUP.md)
