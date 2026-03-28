# Two-Week Platform Truth Takeover Prompt

You are taking over the active `mereka-lms` platform-truth lane.

Start by reading:

1. `docs/status/active/TWO_WEEK_PLATFORM_TRUTH_TRACKER_2026-03-28.md`
2. `docs/status/active/README.md`
3. `scripts/qa/verify-build-workflow-contract.sh`
4. `scripts/qa/test-verify-build-workflow-contract.sh`
5. `scripts/qa/verify-mfe-config-contract.sh`
6. `tests/e2e/tests/tenant-palette-bridge.spec.ts`

Read the relevant PRs/issues directly:

7. `https://github.com/Biji-Biji-Initiative/mereka-lms/pull/1169`
8. `https://github.com/Biji-Biji-Initiative/mereka-lms/pull/1168`
9. `https://github.com/Biji-Biji-Initiative/mereka-lms/pull/1166`
10. `https://github.com/Biji-Biji-Initiative/mereka-lms/issues/1164`
11. `https://github.com/Biji-Biji-Initiative/bbi-infrastructure/pull/2165`
12. `https://github.com/Biji-Biji-Initiative/bbi-infrastructure/pull/2164`

## Mission

Keep the remaining platform work truthful across all three planes:

- app repo truth
- infra/promotion truth
- live runtime truth

The objective is not to keep opening new lanes. The objective is to close the current control point in the right order and leave evidence that survives handoff.

## Clean worktrees

Do not use the dirty root worktree.

Use only:

- `/tmp/mereka-build-sbom-guard` for `#1169`
- `/tmp/mereka-tenant-palette-bridge` for `#1166` follow-through and tenant-host runtime proof
- `/tmp/mereka-two-week-tracker` for tracker refreshes

## Current control point

The active work is now:

1. finish `#1169`
2. carry merged `#1166` through build -> promotion -> runtime realization
3. keep `#1164` open until tenant-host runtime proof exists
4. keep nonprod MFE-config parity represented as closed
5. keep the prod `502` behavior classified as availability/outage work, not as a reopened MFE-config contract bug

## Immediate first tasks

### First lane: `#1169`

Work in `/tmp/mereka-build-sbom-guard`.

Run:

1. `gh pr checks 1169 --repo Biji-Biji-Initiative/mereka-lms`
2. `gh pr view 1169 --repo Biji-Biji-Initiative/mereka-lms --json headRefOid,mergeable,url`
3. if CI is green, merge it
4. if CI fails, fix only the concrete failure boundary

Do not invent another workflow change unless the fresh rerun gives you a real failure.

### Second lane: merged `#1166`

Work in `/tmp/mereka-tenant-palette-bridge`.

Start with:

1. `gh run view 23679457112 --repo Biji-Biji-Initiative/mereka-lms --json status,conclusion,jobs,url,headSha`
2. `gh pr list --repo Biji-Biji-Initiative/bbi-infrastructure --state open --search '21dad073 in:title' --json number,title,url`
3. `gh run list --repo Biji-Biji-Initiative/bbi-infrastructure --workflow promote-dev-image.yml --limit 20`

If build completion has not yet created a promotion PR/run, keep watching the handoff instead of pretending the runtime lane moved.

Only after deployment movement is real, rerun the tenant-host probes and browser proof.

### Third lane: prod anomaly

Treat prod as a separate availability lane.

The current verified boundary is broad public-host failure:

- `https://academyv2.mereka.io/` → `502`
- `https://academyv2.mereka.io/api/mfe_config/v1` → `502`
- `https://apps.academyv2.mereka.io/` → `502`
- `https://apps.academyv2.mereka.io/api/mfe_config/v1?mfe=authn` → `502`
- `https://studio.academyv2.mereka.io/` → `502`
- `https://preview.academyv2.mereka.io/` → `502`

Do not reopen the old nonprod MFE-config parity bug because of this.

## Non-negotiable rules

- Do not collapse repo truth, infra truth, and runtime truth into one sentence.
- Do not close `#1164` because `#1166` is merged.
- Do not rediscover already-closed queue debt unless fresh evidence proves regression.
- Do not describe the prod outage as an `/api/mfe_config/v1` bug unless the broad `502` surface disappears and a narrower boundary remains.
- Do not widen `#1169` into general CI cleanup.
- Do not widen merged `#1166` into a new source-implementation lane unless runtime proof shows the merge was insufficient.
- Do not leave the tracker ahead of reality.

## Required proof discipline

Every report must name its plane:

- `repo_truth`
- `pr_truth`
- `infra_truth`
- `runtime_truth`

Every handoff note must include:

1. exact current head or merged commit
2. exact commands run
3. exact remaining blocker
4. exact done criteria still missing

## Minimum acceptable success for this handoff

- `#1169` is merged or reduced to one concrete failing boundary
- merged `#1166` has crossed into a visible build/promotion/runtime path
- `#1164` remains open until tenant-host runtime proof exists
- nonprod MFE-config parity remains represented as closed
- the prod outage remains correctly classified as availability work
- the active tracker still matches the actual system state
