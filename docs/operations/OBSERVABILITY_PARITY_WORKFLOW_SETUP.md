# Observability Parity Workflow Setup

Date: 2026-02-25

## Purpose

Configure and operate `.github/workflows/observability-parity-runtime.yml` for sustained dev/nonprod/prod parity verification.

## Required Repository Variables

Set these in GitHub repository variables:

1. `OBS_PARITY_DEV_K8S_CONTEXT`
2. `OBS_PARITY_NONPROD_K8S_CONTEXT`
3. `OBS_PARITY_PROD_K8S_CONTEXT`
4. `OBS_PARITY_REQUIRE_PROD_CONTEXT_MATCH` (optional, defaults to `1` for this workflow run)

Optional project overrides:

1. `OBS_PARITY_DEV_GCP_PROJECT`
2. `OBS_PARITY_NONPROD_GCP_PROJECT`
3. `OBS_PARITY_PROD_GCP_PROJECT`

Shared cluster access variables (already used by other workflows):

1. `GKE_CLUSTER_PROJECT`
2. `GKE_CLUSTER_LOCATION`
3. `GKE_CLUSTER_NAME`

## Non-negotiable Behavior

1. Production parity cannot silently skip.
2. If `OBS_PARITY_PROD_K8S_CONTEXT` is missing, the `prod` matrix lane fails.
3. Parity run validates that the resolved context exists in kubeconfig and can answer `kubectl cluster-info`.
4. In prod lane, when `OBS_PARITY_REQUIRE_PROD_CONTEXT_MATCH=1`, the kubeconfig `current-context` must exactly match
   `OBS_PARITY_PROD_K8S_CONTEXT`.
5. Rollup gate is strict no-skip (`--require-no-skips`), so dev/nonprod skips fail consolidated parity status.
6. Scheduled runs now validate streak continuity with `scripts/qa/verify-parity-rollup-stability.sh` and require
   three consecutive scheduled successful rollups to satisfy sustained stability criteria.
7. Non-production tracing pilot checks are strict in the nonprod lane by setting workflow runtime env
   `OBS_REQUIRE_TRACING_ARTIFACT=1` and `OBS_EVIDENCE_REQUIRE_TRACING_IDENTITY=1` during that lane only.

## Runtime Outputs Per Environment

Artifacts uploaded as `observability-parity-<env>`:

1. `observability-parity-delta.md`
2. `observability-parity-delta.json`
3. `observability-parity-review.md`
4. `observability-compliance-runtime.json`
5. `observability-compliance-runtime.md`
6. `observability-runtime-verify-runtime.txt`
7. `observability-runtime-verify-runtime.md`
8. `observability-first-class-runtime-evidence-index.json`
9. `observability-correlation-headers-runtime.txt`
10. `observability-logging-pipeline-runtime.txt`
11. `observability-tracing-runtime.txt`

Consolidated rollup artifact:
1. `observability-parity-rollup` (workflow artifact)
2. includes `observability-parity-rollup.md` and `observability-parity-rollup.json`

## Weekly Review Ritual

Every week, review parity artifacts for `dev/nonprod/prod` and record:

1. Fail/pass status per environment.
2. Identity correctness (`env/profile/context/project`).
3. Regressions since prior week.
4. Required follow-up actions with owner + target date.

Closure criteria for parity gaps:
1. PAR-001 closes only after 3 consecutive scheduled rollups with no skipped environments.
2. PAR-002 closes only after 3 consecutive scheduled rollups with no parity delta failures.

Weekly reviews must be captured with the repo issue template:

- `docs` location: `/.github/ISSUE_TEMPLATE/observability-parity-review.md`
- Issue title format: `Observability Parity Review - Week of <YYYY-MM-DD>`

Artifacts now include:
1. `observability-parity-stability.json` (from `verify-parity-rollup-stability.sh`)
2. `observability-parity-rollup.md/json`

## Suggested Review Template

```text
Week of: <YYYY-MM-DD>
Environment: <dev|nonprod|prod>
Status: <pass|fail|skipped>
Identity: <value from evidence index>
Top failures: <PARITY-xxx checks>
Owner: <team/person>
Target fix date: <YYYY-MM-DD>
```

## Nonprod Tracing Evidence Step (Pilot Track)

For each nonprod parity run, the nonprod lane must also ensure:

1. `observability-logging-pipeline-runtime.txt` exists and includes all AC-LOG checks.
2. `observability-tracing-runtime.txt` exists and documents the selected pilot tracing contract status.
3. Pilot flow traceability evidence is captured in the weekly handoff (`docs/evidence/observability/`), including one trace path with matching request-id/log correlation.

Automation note:
- `scripts/qa/build-observability-parity-review.sh` now auto-generates
  `observability-parity-review.md` from the delta JSON for each environment run.
- `scripts/qa/build-observability-parity-rollup.sh` now consolidates per-environment
  parity outputs into a single run-level rollup summary.
