# Two-Week Platform Truth Takeover Prompt

You are taking over the `mereka-lms` two-week platform-truth lane.

Start by reading:

1. `docs/status/active/TWO_WEEK_PLATFORM_TRUTH_TRACKER_2026-03-28.md`
2. `docs/status/active/README.md`
3. `docs/status/active/UI_RUNTIME_TRUTH_TRACKER_2026-03-25.md`
4. `docs/status/active/DEV_STAGING_TRUTH_TRACKER_2026-03-25.md`
5. `scripts/qa/verify-mfe-config-contract.sh`
6. `scripts/qa/verify-post-deploy-gate.sh`

If you need the closed proof lanes for context, also read:

7. `https://github.com/Biji-Biji-Initiative/mereka-lms/pull/1148`
8. `https://github.com/Biji-Biji-Initiative/mereka-lms/pull/1153`
9. `https://github.com/Biji-Biji-Initiative/mereka-lms/issues/842`
10. `https://github.com/Biji-Biji-Initiative/mereka-lms/issues/843`
11. `https://github.com/Biji-Biji-Initiative/mereka-lms/issues/834`

## Mission

Keep the next two weeks of platform work truthful across all three planes:

- app repo truth
- infra/promotion truth
- live runtime truth

The objective is not "keep the queue busy." The objective is "finish the remaining lanes in the right order, with proof that survives handoff."

## Current control point

The queue is no longer the problem.

The system is currently concentrated around:

1. merging `mereka-lms#1155` so the docs catch up to reality
2. opening the next real implementation lane: shared footer content source across LMS and MFE surfaces
3. opening the MFE-config contract truth lane so the live parity repair is backed by an explicit contract and verifier
4. leaving the closed enterprise/frontend ownership lanes retired unless fresh evidence reopens them

## Immediate first task

Start with `T-01` from the tracker unless fresh evidence proves another lane is now more urgent.

Current verified first move:

1. refresh and merge `#1155`
2. then open the shared footer payload lane rather than reopening closed ownership work
3. after that, open the MFE-config contract lane and keep the runtime parity repair explicit

## Non-negotiable rules

- Do not collapse repo truth, infra truth, and runtime truth into one sentence.
- Do not close an issue because the source looks right if runtime proof is part of the acceptance boundary.
- Do not rediscover already-closed queue debt unless new evidence shows regression.
- Do not describe the MFE-config lane as open runtime breakage if fresh live probes show parity is repaired.
- Do not misclassify the `Post-Deploy E2E Gate` failure as an app-runtime defect; the proven root cause is workflow checkout ordering and the fix is already merged in `#1154`.
- Do not widen the now-merged `#1148` or `#1153` lanes into general cleanup.
- Do not jump straight to tenant CSS runtime injection before the clearer shared-footer single-source lane.
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

1. `T-01` merge `#1155`
2. `T-02` open the shared footer content source lane
3. `T-03` open the MFE-config contract truth lane
4. `T-04` keep the closed enterprise/frontend ownership lanes retired unless fresh evidence reopens them

## Minimum acceptable success for this program handoff

- `#1154` is merged and its post-merge `main` runs are clean
- dev and staging LMS-host/apps-host MFE-config surfaces stay aligned for the governed learner/account/profile/login keys
- the `#2161` false-negative is closed by `#2162` and its merge-commit follow-through
- the shared footer content source lane is opened as the next implementation lane with one canonical payload for LMS and MFE public footer content
- the MFE-config contract lane is opened as the next truth lane after the shared footer source
- the next promotion proof bundle still covers build digest -> overlay -> Argo -> live runtime
- the active tracker still matches the real state without narrative drift
