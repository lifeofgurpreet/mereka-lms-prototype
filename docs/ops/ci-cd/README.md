# CI/CD Operator Surface
_Audience: Operators and release owners • Owner: Platform Team • Last verified: 2026-04-22 • Status: canonical_

This directory is the active operator surface for CI runner posture, cache and
benchmark truth, release-unit evidence, and durable mobile delivery procedure.
Use it to navigate the build-proof system. The underlying source -> render ->
artifact rules still live in the linked contracts, policies, and runbooks.

## Start here

| If you need to... | Read this first | Then go deeper in |
|---|---|---|
| Understand ARC vs fastlane Linux runner posture | [`CI_CD_RUNNERS.md`](CI_CD_RUNNERS.md) | [`RUNNER_HYGIENE.md`](RUNNER_HYGIENE.md), [`../../policies/operations/CI_RUNNER_POLICY.md`](../../policies/operations/CI_RUNNER_POLICY.md) |
| Understand which local/bootstrap/build proof lane actually proves what | [`../../reference/contracts/DEVELOPER_ENVIRONMENT_PROOF_MATRIX.md`](../../reference/contracts/DEVELOPER_ENVIRONMENT_PROOF_MATRIX.md) | [`BUILD_FAILURE_TAXONOMY.md`](BUILD_FAILURE_TAXONOMY.md), [`../../reference/contracts/VERIFIER_CONTRACT_CATALOG.md`](../../reference/contracts/VERIFIER_CONTRACT_CATALOG.md) |
| Understand cache authority and benchmark classes before comparing runner performance | [`CACHE_AUTHORITY.md`](CACHE_AUTHORITY.md) | [`BENCHMARK_CLASSES.md`](BENCHMARK_CLASSES.md), [`CI_METRICS.md`](CI_METRICS.md) |
| Understand release-object and CI evidence shape | [`RELEASE_UNIT_SCHEMA.md`](RELEASE_UNIT_SCHEMA.md) | [`CI_METRICS.md`](CI_METRICS.md), [`BUILD_FAILURE_TAXONOMY.md`](BUILD_FAILURE_TAXONOMY.md) |
| Check Tutor-specific CI workflow behavior | [`../../reference/operations/TUTOR_CONFIG_CI.md`](../../reference/operations/TUTOR_CONFIG_CI.md) | [`../../reference/operations/CI_CD_SETUP.md`](../../reference/operations/CI_CD_SETUP.md) |
| Work on mobile/iOS delivery automation | [`FASTLANE_AUTOMATION.md`](FASTLANE_AUTOMATION.md) | [`../../reference/operations/IOS_CI_CD_REFERENCE.md`](../../reference/operations/IOS_CI_CD_REFERENCE.md) |
| Check CI cost or throughput posture | [`CI_METRICS.md`](CI_METRICS.md) | [`../../reference/operations/GITHUB_ACTIONS_COST_MONITORING.md`](../../reference/operations/GITHUB_ACTIONS_COST_MONITORING.md) |
| Check whether a CI/CD item is active status rather than enduring guidance | [`../../status/active/README.md`](../../status/active/README.md) | The relevant active status document |

## Use this directory for

- runner operations
- cache and benchmark-class routing
- release-unit and CI evidence routing
- durable mobile delivery procedure
- direct routing into CI/CD reference, policy, and status owners

## Do not use this directory for

- application architecture decisions, which belong in ADRs or architecture standards
- historical rollout reporting, which belongs in `docs/status/**` or `reports/**`
- transient cost analysis and implementation trackers
- transitional copies under superseded roots

## Build and release docs

- [`CI_CD_RUNNERS.md`](CI_CD_RUNNERS.md)
- [`CACHE_AUTHORITY.md`](CACHE_AUTHORITY.md)
- [`BENCHMARK_CLASSES.md`](BENCHMARK_CLASSES.md)
- [`BUILD_FAILURE_TAXONOMY.md`](BUILD_FAILURE_TAXONOMY.md)
- [`CI_METRICS.md`](CI_METRICS.md)
- [`RELEASE_UNIT_SCHEMA.md`](RELEASE_UNIT_SCHEMA.md)
- [`RUNNER_HYGIENE.md`](RUNNER_HYGIENE.md)
- [`FASTLANE_AUTOMATION.md`](FASTLANE_AUTOMATION.md)

## CI/CD references

- [`../../reference/contracts/DEVELOPER_ENVIRONMENT_PROOF_MATRIX.md`](../../reference/contracts/DEVELOPER_ENVIRONMENT_PROOF_MATRIX.md)
- [`../../reference/operations/CI_CD_SETUP.md`](../../reference/operations/CI_CD_SETUP.md)
- [`../../reference/operations/TUTOR_CONFIG_CI.md`](../../reference/operations/TUTOR_CONFIG_CI.md)
- [`../../reference/operations/IOS_CI_CD_REFERENCE.md`](../../reference/operations/IOS_CI_CD_REFERENCE.md)
- [`../../reference/operations/GITHUB_ACTIONS_COST_MONITORING.md`](../../reference/operations/GITHUB_ACTIONS_COST_MONITORING.md)
- [`../../reference/operations/GKE_AUTOPILOT_COST_ESTIMATE.md`](../../reference/operations/GKE_AUTOPILOT_COST_ESTIMATE.md)

## Status and reports

- [`../../status/active/CI_OPTIMIZATION_TRACKER.md`](../../status/active/CI_OPTIMIZATION_TRACKER.md)
- [`../../status/active/FRONTEND_CI_CEREMONY_REDUCTION_2026-03-02.md`](../../status/active/FRONTEND_CI_CEREMONY_REDUCTION_2026-03-02.md)
- [`../../reports/2025/learnings/DEV_ENV_COST_OPTIMIZATION_2025-11-12.md`](../../reports/2025/learnings/DEV_ENV_COST_OPTIMIZATION_2025-11-12.md)
- [`../../reports/2026/learnings/CI_PIPELINE_COST_OPTIMIZATION.md`](../../reports/2026/learnings/CI_PIPELINE_COST_OPTIMIZATION.md)

## What this root is not

- Not the source of CI/CD policy rules. Use `docs/policies/operations/**` for rules and constraints.
- Not the place for active release/status reporting. Use `docs/status/**`.
- Not the place for factual runtime inventories. Use `docs/reference/operations/**`.
- Not a live CI dashboard. Query GitHub Actions with `gh run list` / `gh run view`
  and check the active tracking issue before calling a lane green.
