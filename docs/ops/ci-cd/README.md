# CI/CD Operator Surface
_Audience: Operators and release owners • Owner: Platform Team • Last verified: 2026-03-09 • Status: canonical_

This directory contains the canonical operator-facing CI/CD surface for build, release, runner, and cost-optimization operations. Start here when the question is “how do we operate the delivery system?” rather than “what policy governs it?” or “what does the runtime look like?”

## Start here

| If you need to... | Read this first | Then go deeper in |
|---|---|---|
| Understand runner posture or build-execution expectations | [`CI_CD_RUNNERS.md`](CI_CD_RUNNERS.md) | [`../../policies/operations/README.md`](../../policies/operations/README.md) |
| Check Tutor-specific CI behavior | [`TUTOR_CONFIG_CI.md`](TUTOR_CONFIG_CI.md) | [`../runbooks/README.md`](../runbooks/README.md) |
| Work on mobile/iOS delivery automation | [`FASTLANE_AUTOMATION.md`](FASTLANE_AUTOMATION.md) | [`ios-cicd-spec.md`](ios-cicd-spec.md) |
| Check CI cost or throughput posture | [`GITHUB_ACTIONS_COST_MONITORING.md`](GITHUB_ACTIONS_COST_MONITORING.md) | [`COST_OPTIMIZATION.md`](COST_OPTIMIZATION.md) |
| Check whether a CI/CD item is active status rather than enduring guidance | [`../../status/active/README.md`](../../status/active/README.md) | The relevant active status document |

## Common operator routes

| Question | Start here | Escalate to |
|---|---|---|
| "Why did the build or release system fail?" | [`CI_CD_RUNNERS.md`](CI_CD_RUNNERS.md) or [`TUTOR_CONFIG_CI.md`](TUTOR_CONFIG_CI.md) | [`../runbooks/README.md`](../runbooks/README.md) |
| "Which rule governs this pipeline change?" | [`../../policies/operations/README.md`](../../policies/operations/README.md) | The specific policy doc under `docs/policies/operations/**` |
| "Where is the current release/problem status?" | [`../../status/active/README.md`](../../status/active/README.md) | The specific active status note |
| "Where is the evidence that a pipeline or release claim is true?" | [`../../evidence/INDEX.md`](../../evidence/INDEX.md) | The specific evidence pack |

## Use this directory for

- build and runner operating references
- CI/CD cost and throughput guidance
- release pipeline operational notes
- operator-facing CI/CD troubleshooting and standards

## Do not use this directory for

- application architecture decisions, which belong in ADRs or architecture standards
- historical rollout reporting, which belongs in `docs/status/**`
- transitional copies under superseded roots

## Build and release docs

- [`CI_CD_RUNNERS.md`](CI_CD_RUNNERS.md)
- [`TUTOR_CONFIG_CI.md`](TUTOR_CONFIG_CI.md)
- [`FASTLANE_AUTOMATION.md`](FASTLANE_AUTOMATION.md)
- [`ios-cicd-spec.md`](ios-cicd-spec.md)

## Cost and optimization docs

- [`GITHUB_ACTIONS_COST_MONITORING.md`](GITHUB_ACTIONS_COST_MONITORING.md)
- [`COST_OPTIMIZATION.md`](COST_OPTIMIZATION.md)
- [`cost-estimate.md`](cost-estimate.md)
- [`CI_PIPELINE_COST_OPTIMIZATION.md`](CI_PIPELINE_COST_OPTIMIZATION.md)
- [`CI_OPTIMIZATION_TRACKER.md`](CI_OPTIMIZATION_TRACKER.md)
- [`CI_CEREMONY_REDUCTION_MATRIX_104.md`](CI_CEREMONY_REDUCTION_MATRIX_104.md)

## What this root is not

- Not the source of CI/CD policy rules. Use `docs/policies/operations/**` for rules and constraints.
- Not the place for active release/status reporting. Use `docs/status/**`.
- Not the place for factual runtime inventories. Use `docs/reference/operations/**`.

## Review standard

- A CI/CD doc here should help an operator act, verify, or troubleshoot.
- If the file mainly defines a durable rule, move or rewrite it under `docs/policies/**`.
- If the file mainly reports the current state of a rollout or initiative, move it to `docs/status/**`.
