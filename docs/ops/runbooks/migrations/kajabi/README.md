# Kajabi Migration Runbooks
_Audience: Operators • Owner: Platform Team • Last verified: 2026-03-09 • Status: canonical_

This subroot holds the live Kajabi migration execution and recovery procedures.

## Start here

- Need the verification entrypoint:
  - start with [`EXECUTION_PLAN_VERIFICATION.md`](EXECUTION_PLAN_VERIFICATION.md)
- Need the remigration procedure:
  - start with [`KAJABI_REMIGRATION_RUNBOOK.md`](KAJABI_REMIGRATION_RUNBOOK.md)

## Runbooks in this subroot

- [`EXECUTION_PLAN_VERIFICATION.md`](EXECUTION_PLAN_VERIFICATION.md)
- [`KAJABI_MIGRATION.md`](KAJABI_MIGRATION.md)
- [`KAJABI_REMIGRATION_RUNBOOK.md`](KAJABI_REMIGRATION_RUNBOOK.md)
- [`ROLLBACK_AND_SAFETY.md`](ROLLBACK_AND_SAFETY.md)
- [`VERIFY_AND_SYNC_KAJABI.md`](VERIFY_AND_SYNC_KAJABI.md)

## What this subroot is not

Do not use this subroot for:
- reference material, which belongs in `docs/reference/migrations/kajabi/**`
- migration status reporting, which belongs in `docs/status/migrations/**`
- completed verification reports, which belong in `reports/**`
- script repair notes and content-fix references, which belong in `docs/reference/migrations/kajabi/**`
- outage-specific recovery verification notes, which belong in `reports/**`
