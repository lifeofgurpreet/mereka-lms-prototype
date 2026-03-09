# Operations Policies
_Audience: Operators and reviewers • Owner: Platform Team • Last verified: 2026-03-09 • Status: canonical_

Use this root when you need the rules that govern how operators are allowed to run the platform. Start here for safety boundaries, retention rules, readiness gates, and operator behavior constraints. Do not use this root for execution steps or live status.

## Start Here

| If you need to... | Read this first | Then go deeper in |
|---|---|---|
| Understand what operators may or may not do | [`ALLOWED_ACTIONS_POLICY.md`](ALLOWED_ACTIONS_POLICY.md) | [`../../ops/runbooks/README.md`](../../ops/runbooks/README.md) |
| Check deployment and change-control rules | [`MERGE_FIRST_DEPLOYMENT_PROTOCOL.md`](MERGE_FIRST_DEPLOYMENT_PROTOCOL.md) | [`REPO_BOUNDARIES.md`](REPO_BOUNDARIES.md) |
| Check Tutor or runtime safety boundaries | [`TUTOR_CONFIG_SAFETY.md`](TUTOR_CONFIG_SAFETY.md) | [`../../reference/operations/README.md`](../../reference/operations/README.md) |
| Check auth, privacy, or retention policy | [`AUTH_HARDENING_SPEC.md`](AUTH_HARDENING_SPEC.md) | [`DATA_RETENTION_POLICY.md`](DATA_RETENTION_POLICY.md) |
| Check observability or SLO policy | [`OBSERVABILITY_GA_READINESS_GATE.md`](OBSERVABILITY_GA_READINESS_GATE.md) | [`SLO_POLICY.md`](SLO_POLICY.md) |
| Check exception handling | [`SECURITY_EXCEPTIONS.md`](SECURITY_EXCEPTIONS.md) | [`A11Y_EXCEPTIONS.md`](A11Y_EXCEPTIONS.md) |

## Use this directory for

- deployment and maintenance policy
- security and retention policy for operations
- ownership and operational boundary rules
- readiness and exception policy that governs operator behavior

## Deployment and platform safety

- [`ALLOWED_ACTIONS_POLICY.md`](ALLOWED_ACTIONS_POLICY.md) for operator action boundaries
- [`MAINTENANCE_WINDOWS.md`](MAINTENANCE_WINDOWS.md) for planned maintenance policy
- [`MERGE_FIRST_DEPLOYMENT_PROTOCOL.md`](MERGE_FIRST_DEPLOYMENT_PROTOCOL.md) for merge and deployment sequencing
- [`REPO_BOUNDARIES.md`](REPO_BOUNDARIES.md) for operational ownership boundaries
- [`TUTOR_CONFIG_SAFETY.md`](TUTOR_CONFIG_SAFETY.md) for Tutor configuration safety rules
- [`BRANCH_PROTECTION.md`](BRANCH_PROTECTION.md) for protected-branch expectations
- [`CI_RUNNER_POLICY.md`](CI_RUNNER_POLICY.md) for CI runner posture
- [`BINARY_PINNING.md`](BINARY_PINNING.md) for binary pinning requirements

## Security, privacy, and retention

- [`AUTH_HARDENING_SPEC.md`](AUTH_HARDENING_SPEC.md) for operator-facing auth hardening requirements
- [`SECURITY_EXCEPTIONS.md`](SECURITY_EXCEPTIONS.md) for governed security exceptions
- [`PII_DATA_INVENTORY.md`](PII_DATA_INVENTORY.md) for PII handling scope
- [`DATA_RETENTION_POLICY.md`](DATA_RETENTION_POLICY.md) for retention expectations
- [`ANALYTICS_DATA_RETENTION.md`](ANALYTICS_DATA_RETENTION.md) for analytics retention specifics
- [`EVIDENCE_REDACTION_POLICY.md`](EVIDENCE_REDACTION_POLICY.md) for evidence redaction rules

## Operations, observability, and service governance

- [`MULTISITE_GOVERNANCE.md`](MULTISITE_GOVERNANCE.md) for multisite operator governance
- [`OBSERVABILITY_OWNERSHIP.md`](OBSERVABILITY_OWNERSHIP.md) for monitoring ownership and responsibility
- [`OBSERVABILITY_GA_READINESS_GATE.md`](OBSERVABILITY_GA_READINESS_GATE.md) for observability readiness policy
- [`OBSERVABILITY_ARTIFACT_RETENTION_MATRIX.md`](OBSERVABILITY_ARTIFACT_RETENTION_MATRIX.md) for telemetry artifact retention
- [`OTEL_NAMING_CONVENTIONS.md`](OTEL_NAMING_CONVENTIONS.md) for telemetry naming rules
- [`SLA_REPORTING.md`](SLA_REPORTING.md) for service-level reporting policy
- [`SLO_POLICY.md`](SLO_POLICY.md) for service-level objective policy
- [`ONCALL_ROTATION.md`](ONCALL_ROTATION.md) for on-call expectations
- [`A11Y_EXCEPTIONS.md`](A11Y_EXCEPTIONS.md) for accessibility exception handling
- [`FOOTER_SLOT_ONLY_POLICY.md`](FOOTER_SLOT_ONLY_POLICY.md) for footer-slot operational constraints
- [`PR_HANDOFF_POLICY.md`](PR_HANDOFF_POLICY.md) for operator review and handoff rules

## Do not use this directory for

- live status tracking, which belongs in `docs/status/**`
- detailed runbooks, which belong in `docs/ops/runbooks/**`
- historical reports, which belong in archive surfaces

## How To Use This Root Well

1. Start here when the question is “what is allowed?” or “what rule governs this operation?”
2. If you already know the rule and need execution steps, leave this root and move to [`../../ops/runbooks/README.md`](../../ops/runbooks/README.md).
3. If you need factual inventories or contracts rather than rules, leave this root and move to [`../../reference/operations/README.md`](../../reference/operations/README.md).
