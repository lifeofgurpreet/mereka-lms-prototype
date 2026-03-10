# Monitoring and Observability
_Audience: Operators • Owner: Platform Team • Last verified: 2026-03-09 • Status: canonical_

Use this root as a small operator portal into the canonical monitoring surfaces. It does not own local monitoring content; it routes operators directly to the live runbook, reference, policy, and status docs.

## Start Here

| If you need to... | Read this first | Then go deeper in |
|---|---|---|
| Get oriented quickly on the monitoring surface | [`../runbooks/OBSERVABILITY_QUICKSTART.md`](../runbooks/OBSERVABILITY_QUICKSTART.md) | [`../../reference/operations/README.md`](../../reference/operations/README.md) |
| Check logging and Sentry behavior | [`../../reference/operations/LOGGING_AND_SENTRY.md`](../../reference/operations/LOGGING_AND_SENTRY.md) | [`../../reference/operations/MONITORING.md`](../../reference/operations/MONITORING.md) |
| Understand who owns what in observability | [`../../policies/operations/OBSERVABILITY_OWNERSHIP.md`](../../policies/operations/OBSERVABILITY_OWNERSHIP.md) | [`../../policies/operations/README.md`](../../policies/operations/README.md) |
| Compare expected versus actual monitoring coverage | [`../../reference/operations/OBSERVABILITY_PARITY_MATRIX.md`](../../reference/operations/OBSERVABILITY_PARITY_MATRIX.md) | [`../../status/readiness/README.md`](../../status/readiness/README.md) |
| Check retention or artifact handling | [`../../policies/operations/OBSERVABILITY_ARTIFACT_RETENTION_MATRIX.md`](../../policies/operations/OBSERVABILITY_ARTIFACT_RETENTION_MATRIX.md) | [`../../evidence/operations/README.md`](../../evidence/operations/README.md) |
| Review active observability work | [`../../status/active/OBSERVABILITY_ENHANCEMENT_PLAN.md`](../../status/active/OBSERVABILITY_ENHANCEMENT_PLAN.md) | [`../../status/active/OBSERVABILITY_ROADMAP_MEREKA_LMS.md`](../../status/active/OBSERVABILITY_ROADMAP_MEREKA_LMS.md) |

## This portal points to

- [`../runbooks/OBSERVABILITY_QUICKSTART.md`](../runbooks/OBSERVABILITY_QUICKSTART.md) for the fastest operator route
- [`../../reference/operations/MONITORING.md`](../../reference/operations/MONITORING.md) for monitoring reference
- [`../../reference/operations/LOGGING_AND_SENTRY.md`](../../reference/operations/LOGGING_AND_SENTRY.md) for logs and Sentry
- [`../../reference/operations/OBSERVABILITY_PARITY_MATRIX.md`](../../reference/operations/OBSERVABILITY_PARITY_MATRIX.md) for expected-vs-actual parity
- [`../../policies/operations/OBSERVABILITY_OWNERSHIP.md`](../../policies/operations/OBSERVABILITY_OWNERSHIP.md) for ownership and change control
- [`../../policies/operations/OBSERVABILITY_ARTIFACT_RETENTION_MATRIX.md`](../../policies/operations/OBSERVABILITY_ARTIFACT_RETENTION_MATRIX.md) for retention rules
- [`../../status/active/OBSERVABILITY_ENHANCEMENT_PLAN.md`](../../status/active/OBSERVABILITY_ENHANCEMENT_PLAN.md) for active execution work
- [`../../status/active/OBSERVABILITY_ROADMAP_MEREKA_LMS.md`](../../status/active/OBSERVABILITY_ROADMAP_MEREKA_LMS.md) for roadmap context

## This portal does not contain

- local monitoring leaf docs
- active incident or readiness status
- cold historical evidence
- architecture authority

## What This Root Is Not

- Not the live reporting surface. Use [`../../status/INDEX.md`](../../status/INDEX.md) for active status, readiness, and migration reporting.
- Not the cold proof archive. Use [`../../evidence/INDEX.md`](../../evidence/INDEX.md) for active proof and `docs/archive/evidence/**` only for retired proof.
- Not the place for architecture authority. Use [`../../concepts/architecture/README.md`](../../concepts/architecture/README.md) and [`../../policies/README.md`](../../policies/README.md) for system rules and policy.
