# Two-Week Platform Truth Takeover Prompt

You are taking over the `mereka-lms` two-week platform-truth lane.

Start by reading:

1. `docs/status/active/TWO_WEEK_PLATFORM_TRUTH_TRACKER_2026-03-28.md`
2. `docs/status/active/README.md`
3. `docs/status/active/UI_RUNTIME_TRUTH_TRACKER_2026-03-25.md`
4. `docs/status/active/DEV_STAGING_TRUTH_TRACKER_2026-03-25.md`
5. `scripts/qa/verify-mfe-config-contract.sh`
6. `scripts/qa/verify-multisite-config.sh`

If you are checking the just-merged enterprise proof lane, also read:

7. `https://github.com/Biji-Biji-Initiative/mereka-lms/pull/1148`
8. `https://github.com/Biji-Biji-Initiative/mereka-lms/issues/842`
9. `https://github.com/Biji-Biji-Initiative/mereka-lms/issues/843`
10. `https://github.com/Biji-Biji-Initiative/mereka-lms/issues/834`

## Mission

Keep the next two weeks of platform work truthful across all three planes:

- app repo truth
- infra/promotion truth
- live runtime truth

The objective is not "keep the queue busy." The objective is "finish the remaining lanes in the right order, with proof that survives handoff."

## Current control point

The queue is no longer the problem.

The system is currently concentrated around:

1. restoring `mereka-lms` `main` to green after `#1149`
2. following through the merged `bbi-infrastructure#2160` proof result without pretending the failed cluster audit is closed
3. merging `mereka-lms#1150` so the partially repaired MFE config lane stays contract-honest
4. cleaning the remaining frontend source-of-truth drift after runtime truth is repaired

## Immediate first task

Start with `T-01b` from the tracker unless fresh evidence proves another lane is now more urgent.

Current verified first move:

1. work from `/tmp/mereka-two-week-tracker` and regenerate `verification/catalogs/verification_catalog.json`
2. get the app-repo follow-up green so `mereka-lms` `main` returns to green
3. then classify the `#2160` merge result correctly from the merge commit evidence instead of treating it as operationally closed

## Non-negotiable rules

- Do not collapse repo truth, infra truth, and runtime truth into one sentence.
- Do not close an issue because the source looks right if runtime proof is part of the acceptance boundary.
- Do not rediscover already-closed queue debt unless new evidence shows regression.
- Do not describe the MFE config lane as fully repaired; the three original null keys are fixed, but account/profile/login parity is still open.
- Do not ignore a red `main` branch in the app repo while claiming the tracker is current.
- Do not widen the now-merged `#1148` lane into general enterprise cleanup.
- Do not leave the tracker ahead of reality.

## Required proof discipline

When you report a lane, always name which plane you are talking about:

- `repo_truth`
- `pr_truth`
- `infra_truth`
- `runtime_truth`

Every handoff note must include:

1. exact current head or merged commit
2. exact commands run
3. exact failure boundary if still open
4. exact done criteria still missing

## Working order for the next agent

1. `T-01b` restore app main to green after the tracker merge
2. `T-03` treat `#2160` as merged-but-not-operationally-closed and carry the failed cluster-audit truth forward honestly
3. `T-02` merge `#1150` so the partially repaired nonprod MFE config contract stays guarded
4. `T-04` work `#843` through `#1153` after the red-main and active infra PR lanes are drained
5. `T-05` refresh trackers/handoffs after truth advances, not before

## Minimum acceptable success for this program handoff

- `#1148` is merged cleanly
- dev and staging LMS-host/apps-host MFE config surfaces stay non-null for learner/account/discussions URLs
- the remaining account/profile/login parity gap is either fixed or explicitly still the active runtime defect
- `mereka-lms` `main` is green again after the tracker/docs follow-up
- `bbi-infrastructure#2160` is merged and its merge commit has an explicit post-merge proof result that is classified truthfully
- the next promotion proof bundle explicitly covers build digest -> overlay -> Argo -> live runtime
- the active tracker still matches the real state without narrative drift
