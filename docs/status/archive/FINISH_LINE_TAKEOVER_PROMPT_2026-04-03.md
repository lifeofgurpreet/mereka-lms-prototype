# Finish-Line Takeover Prompt

_Audience: Contributors and reviewers • Owner: Platform Team • Last verified:
2026-04-03T06:58:00Z • Status: active_

Read first:

1. [`FINISH_LINE_MASTER_TRACKER_2026-04-03.md`](./FINISH_LINE_MASTER_TRACKER_2026-04-03.md)
2. [`TENANT_OPERATING_SYSTEM_BLUEPRINT_2026-04-03.md`](./TENANT_OPERATING_SYSTEM_BLUEPRINT_2026-04-03.md)
3. [`DOMAIN_TRUTH_CONVERGENCE_TRACKER_2026-03-31.md`](./DOMAIN_TRUTH_CONVERGENCE_TRACKER_2026-03-31.md)

## Current truth planes

- `repo_truth`
  - `#1302`, `#1303`, `#1304`, `#1308`, and `#1309` are merged.
- `#1310` is the active release-object lane.
- `infra_truth`
- `bbi-infrastructure#2392` is merged and was required for the
  non-primary `apps.*` repair to become live.
- `runtime_truth`
  - dev runtime-routing proof is green for the active tenant set
  - staging runtime-routing proof is green for the active tenant set
  - prod is still open

## Immediate first task

1. Check `#1310`.
2. If it has no branch-specific failures, merge it.
3. After `#1310`, start the GitOps consumer tranche for release objects.
4. Do not start another abstract control-plane branch before the
   release object is consumed somewhere real.

## Non-negotiable rules

- Do not collapse repo truth, infra truth, and runtime truth into one sentence.
- Do not claim runtime closure from a merged PR.
- Do not fix inherited baseline debt inside a feature lane unless it is
  severity-blocking.
- Do not keep multiple multisite seed authorities alive if one canonical
  reconciler can replace them.
- Do not start prod claims without an explicit prod runtime proof run.

## Commands you are expected to use

- `bash scripts/tenants/verify-dev-runtime-proof.sh --namespace mereka-lms-dev`
- `bash scripts/tenants/verify-staging-runtime-proof.sh --namespace stg-mereka-lms`
- `bash scripts/qa/verify-generated-surfaces.sh`
- `python3 scripts/ci/generate_ci_failure_baseline.py --repo`
  `Biji-Biji-Initiative/mereka-lms --branch-run-id <run>`
  `--baseline-run-id <run> --output <file>`
- `bash scripts/qa/ops-preflight.sh --strict`
- `bash scripts/infra/verify-release-preflight.sh --env <dev|staging|prod>`

## Current branch and PR anchors

- merged severity-policy lane: `#1309` at `53ae16b4921d8824ac64a498b51a10c0ef5e269a`
- active release-object lane: `#1310`
- verified paired runtime repair:
  - app PR `#1308`
  - infra PR `#2392`

## Minimum acceptable success before stopping

Do not stop at “CI looks better.” Minimum acceptable success is:

1. `#1310` merged or machine-classified as baseline-only with no branch failures
2. release object emitted by build workflow and validated by schema
3. next tranche identified as the GitOps consumer, not another app-side
   documentation pass
