# Monitoring and Observability
_Audience: Operators • Owner: Platform Team • Last verified: 2026-03-09 • Status: canonical_

Use this root when you need the operator-facing monitoring and observability surface. This is where operators should start for dashboards, alerting, telemetry posture, and logging/Sentry reference. It is not the place for live incident status or architecture decisions.

## Start Here

| If you need to... | Read this first | Then go deeper in |
|---|---|---|
| Get oriented quickly on the monitoring surface | [`OBSERVABILITY_QUICKSTART.md`](OBSERVABILITY_QUICKSTART.md) | [`../../reference/operations/README.md`](../../reference/operations/README.md) |
| Check logging and Sentry behavior | [`LOGGING_AND_SENTRY.md`](LOGGING_AND_SENTRY.md) | [`../../reference/operations/MONITORING.md`](../../reference/operations/MONITORING.md) |
| Understand who owns what in observability | [`OBSERVABILITY_OWNERSHIP.md`](OBSERVABILITY_OWNERSHIP.md) | [`../../policies/operations/README.md`](../../policies/operations/README.md) |
| Compare expected versus actual monitoring coverage | [`OBSERVABILITY_PARITY_MATRIX.md`](OBSERVABILITY_PARITY_MATRIX.md) | [`../../status/readiness/README.md`](../../status/readiness/README.md) |
| Check retention or artifact handling | [`OBSERVABILITY_ARTIFACT_RETENTION_MATRIX.md`](OBSERVABILITY_ARTIFACT_RETENTION_MATRIX.md) | [`../../evidence/operations/README.md`](../../evidence/operations/README.md) |

## Use this directory for

- monitoring reference material
- observability operating guidance
- alerting ownership and retention policy references
- dashboards, telemetry, and logging guidance for operators

## Do not use this directory for

- active incident or readiness status, which belongs in `docs/status/**`
- cold historical evidence, which belongs in `docs/archive/evidence/**`
- general architecture policy, which belongs in `docs/concepts/architecture/**` or `docs/policies/**`

## Monitoring and telemetry docs

| Doc | Use it when... |
|---|---|
| [`OBSERVABILITY_QUICKSTART.md`](OBSERVABILITY_QUICKSTART.md) | You need the fastest route into the observability surface. |
| [`LOGGING_AND_SENTRY.md`](LOGGING_AND_SENTRY.md) | You are checking application logs, Sentry wiring, or error tracking posture. |
| [`OBSERVABILITY_OWNERSHIP.md`](OBSERVABILITY_OWNERSHIP.md) | You need to know who owns an alerting or telemetry concern. |
| [`OBSERVABILITY_PARITY_MATRIX.md`](OBSERVABILITY_PARITY_MATRIX.md) | You are checking whether expected telemetry is actually present. |
| [`OBSERVABILITY_ARTIFACT_RETENTION_MATRIX.md`](OBSERVABILITY_ARTIFACT_RETENTION_MATRIX.md) | You need artifact retention expectations for observability outputs. |
| [`OBSERVABILITY_ENHANCEMENT_PLAN.md`](OBSERVABILITY_ENHANCEMENT_PLAN.md) | You need the current improvement direction for the observability surface. |
| [`OBSERVABILITY_ROADMAP_MEREKA_LMS.md`](OBSERVABILITY_ROADMAP_MEREKA_LMS.md) | You need the broader observability roadmap and sequencing context. |

## What This Root Is Not

- Not the live reporting surface. Use [`../../status/INDEX.md`](../../status/INDEX.md) for active status, readiness, and migration reporting.
- Not the cold proof archive. Use [`../../evidence/INDEX.md`](../../evidence/INDEX.md) for active proof and `docs/archive/evidence/**` only for retired proof.
- Not the place for architecture authority. Use [`../../concepts/architecture/README.md`](../../concepts/architecture/README.md) and [`../../policies/README.md`](../../policies/README.md) for system rules and policy.
