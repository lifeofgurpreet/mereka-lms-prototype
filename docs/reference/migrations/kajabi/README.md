# Kajabi Migration Docs
_Audience: Platform Eng + Data • Owner: Migration Squad • Last verified: 2026-03-06 • Status: canonical_

All Kajabi-related content lives in this folder. Start with [`KAJABI_MIGRATION.md`](../../../ops/runbooks/migrations/kajabi/KAJABI_MIGRATION.md) for the canonical pipeline, then dive into the supporting references below.

| Doc | Purpose |
| --- | --- |
| [`../../../ops/runbooks/migrations/kajabi/KAJABI_MIGRATION.md`](../../../ops/runbooks/migrations/kajabi/KAJABI_MIGRATION.md) | Main playbook from export → transform → import. |
| [`KAJABI_MIGRATION_NOTES.md`](KAJABI_MIGRATION_NOTES.md) | Field notes and data quirks discovered while transforming. |
| [`../../../../reports/2026/closures/KAJABI_MIGRATION_HANDOVER.md`](../../../../reports/2026/closures/KAJABI_MIGRATION_HANDOVER.md) | Ops handoff checklist once migration moves to prod. |
| [`../../../status/migrations/KAJABI_MIGRATION_STATUS.md`](../../../status/migrations/KAJABI_MIGRATION_STATUS.md) | Progress tracker for processed courses/users. |
| [`../../../../reports/2024/verifications/KAJABI_MIGRATION_VERIFICATION_2024-11-08.md`](../../../../reports/2024/verifications/KAJABI_MIGRATION_VERIFICATION_2024-11-08.md) | Historical verification snapshot after the 2024 Kajabi import. |
| [`../../../ops/runbooks/migrations/kajabi/EXECUTION_PLAN_VERIFICATION.md`](../../../ops/runbooks/migrations/kajabi/EXECUTION_PLAN_VERIFICATION.md) | Step-by-step plan for comparing Kajabi vs Open edX counts. |
| [`../../../status/migrations/MIGRATION_STATUS_AND_ROLLBACK.md`](../../../status/migrations/MIGRATION_STATUS_AND_ROLLBACK.md) | Snapshot of migration state plus rollback options. |
| [`../../../ops/runbooks/migrations/kajabi/ROLLBACK_AND_SAFETY.md`](../../../ops/runbooks/migrations/kajabi/ROLLBACK_AND_SAFETY.md) | Safety checklist and rollback guidance before re-running imports. |
| [`../../../ops/runbooks/migrations/kajabi/VERIFY_WHEN_SITE_BACK_UP.md`](../../../ops/runbooks/migrations/kajabi/VERIFY_WHEN_SITE_BACK_UP.md) | Instructions for re-running verification after downtime. |
| [`../../../ops/runbooks/migrations/kajabi/VERIFY_AND_SYNC_KAJABI.md`](../../../ops/runbooks/migrations/kajabi/VERIFY_AND_SYNC_KAJABI.md) | How to re-sync deltas after the initial import. |
| [`KAJABI_CERTIFICATE_MIGRATION.md`](KAJABI_CERTIFICATE_MIGRATION.md) | Certificate-specific migration steps. |
| [`KAJABI_LESSON_CONTENT_FIX.md`](KAJABI_LESSON_CONTENT_FIX.md) | Script notes for repairing malformed lessons. |
| [`KAJABI_LESSON_CONTENT_ISSUE.md`](KAJABI_LESSON_CONTENT_ISSUE.md) | Ongoing bug tracker for lesson imports. |
