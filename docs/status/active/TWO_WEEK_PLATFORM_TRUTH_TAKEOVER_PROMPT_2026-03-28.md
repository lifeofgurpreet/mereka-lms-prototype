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

1. confirming `#1148` stays closed on truthful post-merge evidence
2. fixing the live LMS-host MFE config API null-key gap without confusing it with the healthy apps-host verifier surface
3. keeping the promotion boundary boring and explicit
4. cleaning the remaining frontend source-of-truth drift after runtime truth is repaired

Current active runtime-fix PR:

- `bbi-infrastructure#2158` `fix(mereka-lms): backfill MFE config URLs in env overlays`

## Immediate first task

Start with `T-02` from the tracker unless fresh evidence proves another lane is now more urgent.

Current verified first move:

1. verify `#1148` post-merge state and `#842` closure
2. work from `/tmp/bbi-mfe-config-fix` and `bbi-infrastructure#2158` for the runtime contract repair
3. keep `/tmp/mereka-two-week-tracker` ready for tracker truth updates if the control point changes again

## Non-negotiable rules

- Do not collapse repo truth, infra truth, and runtime truth into one sentence.
- Do not close an issue because the source looks right if runtime proof is part of the acceptance boundary.
- Do not rediscover already-closed queue debt unless new evidence shows regression.
- Do not assume the MFE config API gap is owned by infra or app until the diff proves the owner.
- Do not describe the apps-host and LMS-host `/api/mfe_config/v1` surfaces as if they are currently identical.
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

1. `T-01` confirm `#1148` remains closed on post-merge truth
2. `T-02` repair the live LMS-host MFE config API contract truth
3. `T-03` prove the next promotion path from build digest to live runtime
4. `T-04` work `#843` only after `T-02` is no longer open
5. `T-05` refresh trackers/handoffs after truth advances, not before

## Minimum acceptable success for this program handoff

- `#1148` is merged cleanly
- the live dev LMS-host MFE config API no longer returns `None` for learner/account/discussions MFE URLs, or the supported contract surface has been explicitly narrowed and documented
- the next promotion proof bundle explicitly covers build digest -> overlay -> Argo -> live runtime
- the active tracker still matches the real state without narrative drift
