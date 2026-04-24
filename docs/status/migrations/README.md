# Migration Status Reports
_Audience: Contributors and reviewers • Owner: Platform Team • Last verified: 2026-03-09 • Status: canonical_

This directory is the active migration-reporting surface for in-flight migration work. Start here when the question is “what is the current migration state?” rather than “what is the source system?” or “what procedure should I run?”

## Start here

| If you need to... | Read this first | Then go deeper in |
|---|---|---|
| Check Kajabi migration status | [KAJABI_MIGRATION_STATUS.md](KAJABI_MIGRATION_STATUS.md) | [`../../reference/migrations/kajabi/README.md`](../../reference/migrations/kajabi/README.md) |
| Check the Kajabi completion-data decision | [KAJABI_COURSES_WITHOUT_COMPLETION_DATA.md](KAJABI_COURSES_WITHOUT_COMPLETION_DATA.md) | [KAJABI_MIGRATION_STATUS.md](KAJABI_MIGRATION_STATUS.md) |
| Check MCT migration status | [MCT_MIGRATION_STATUS.md](MCT_MIGRATION_STATUS.md) | [`../../reference/migrations/mct/README.md`](../../reference/migrations/mct/README.md) |
| Check Drive/Airtable migration state | [drive-airtable-STATUS.md](drive-airtable-STATUS.md) | [`../../reference/migrations/drive-airtable/README.md`](../../reference/migrations/drive-airtable/README.md) |
| Check rollout/rollback posture around migration work | [MIGRATION_STATUS_AND_ROLLBACK.md](MIGRATION_STATUS_AND_ROLLBACK.md) | [RKE2_MIGRATION_PLAN.md](RKE2_MIGRATION_PLAN.md) |
| Decide whether something belongs here at all | [`../INDEX.md`](../INDEX.md) | [`../../reference/migrations/README.md`](../../reference/migrations/README.md) or [`../../ops/runbooks/README.md`](../../ops/runbooks/README.md) |

## Use this directory for

- migration status notes
- rollout matrices tied to migrations
- rollback posture reports for current migration work
- migration-specific follow-up status that is still active

## Do not use this directory for

- general active status tracking that belongs in `docs/status/active/`
- readiness assessments that belong in `docs/status/readiness/`
- archive-only migration history that should no longer be in the active reporting root

## Authority rule

Files here are part of the active reporting root under `docs/status/**`.

Do not create new active migration status docs under legacy `reports/**` paths.

## Current migration reports

| Report | Use it when... |
|---|---|
| [drive-airtable-STATUS.md](drive-airtable-STATUS.md) | You need the current Drive/Airtable migration state. |
| [2026-03-wave-2b-final-closeout.md](2026-03-wave-2b-final-closeout.md) | You need the canonical closeout record for the completed Wave 2B-Final convergence wave. |
| [KAJABI_COURSES_WITHOUT_COMPLETION_DATA.md](KAJABI_COURSES_WITHOUT_COMPLETION_DATA.md) | You need the current decision on Kajabi courses that lack historical completion data. |
| [KAJABI_MIGRATION_STATUS.md](KAJABI_MIGRATION_STATUS.md) | You need the current Kajabi migration state. |
| [MCT_MIGRATION_STATUS.md](MCT_MIGRATION_STATUS.md) | You need the current MCT migration state. |
| [MIGRATION_STATUS_AND_ROLLBACK.md](MIGRATION_STATUS_AND_ROLLBACK.md) | You need migration rollback and active rollout posture. |
| [RKE2_MIGRATION_PLAN.md](RKE2_MIGRATION_PLAN.md) | You need the current RKE2 migration plan. |
| [RKE2_NONPROD_THEME_AND_CONVERGENCE_FIX.md](RKE2_NONPROD_THEME_AND_CONVERGENCE_FIX.md) | You need the nonprod convergence status item tied to migration work. |
| [RKE2_ROLLOUT_MATRIX.md](RKE2_ROLLOUT_MATRIX.md) | You need the RKE2 rollout matrix. |
| [STAGING_PROMOTION_PLAYBOOK_110.md](STAGING_PROMOTION_PLAYBOOK_110.md) | You need the active staging-promotion playbook/status item. |

## What this root is not

- Not the source-system reference root. Use `docs/reference/migrations/**`.
- Not the migration execution root. Use `docs/ops/runbooks/**`.
- Not the place for archived migration closeout. That belongs in cold/archive surfaces.
