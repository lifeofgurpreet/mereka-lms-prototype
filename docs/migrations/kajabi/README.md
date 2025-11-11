# Kajabi Migration Docs
_Audience: Platform Eng + Data • Owner: Migration Squad • Last verified: 2025-11-09_

All Kajabi-related content lives in this folder. Start with [`KAJABI_MIGRATION.md`](KAJABI_MIGRATION.md) for the canonical pipeline, then dive into the supporting references below.

| Doc | Purpose |
| --- | --- |
| [`KAJABI_MIGRATION.md`](KAJABI_MIGRATION.md) | Main playbook from export → transform → import. |
| [`KAJABI_MIGRATION_NOTES.md`](KAJABI_MIGRATION_NOTES.md) | Field notes and data quirks discovered while transforming. |
| [`KAJABI_MIGRATION_HANDOVER.md`](KAJABI_MIGRATION_HANDOVER.md) | Ops handoff checklist once migration moves to prod. |
| [`KAJABI_MIGRATION_STATUS.md`](KAJABI_MIGRATION_STATUS.md) | Progress tracker for processed courses/users. |
| [`KAJABI_MIGRATION_VERIFICATION.md`](KAJABI_MIGRATION_VERIFICATION.md) | QA plan for verifying imported content. |
| [`EXECUTION_PLAN_VERIFICATION.md`](EXECUTION_PLAN_VERIFICATION.md) | Step-by-step plan for comparing Kajabi vs Open edX counts. |
| [`MIGRATION_STATUS_AND_ROLLBACK.md`](MIGRATION_STATUS_AND_ROLLBACK.md) | Snapshot of migration state plus rollback options. |
| [`ROLLBACK_AND_SAFETY.md`](ROLLBACK_AND_SAFETY.md) | Safety checklist and rollback guidance before re-running imports. |
| [`VERIFY_WHEN_SITE_BACK_UP.md`](VERIFY_WHEN_SITE_BACK_UP.md) | Instructions for re-running verification after downtime. |
| [`VERIFY_AND_SYNC_KAJABI.md`](VERIFY_AND_SYNC_KAJABI.md) | How to re-sync deltas after the initial import. |
| [`KAJABI_CERTIFICATE_MIGRATION.md`](KAJABI_CERTIFICATE_MIGRATION.md) | Certificate-specific migration steps. |
| [`KAJABI_LESSON_CONTENT_FIX.md`](KAJABI_LESSON_CONTENT_FIX.md) | Script notes for repairing malformed lessons. |
| [`KAJABI_LESSON_CONTENT_ISSUE.md`](KAJABI_LESSON_CONTENT_ISSUE.md) | Ongoing bug tracker for lesson imports. |
