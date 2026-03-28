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

The queue is no longer the problem. `#1155` is already merged, live LMS/apps MFE-config parity is repaired, and `#843` is closed.

The system is currently concentrated around:

1. landing `#1157` as the active shared footer content source lane
2. landing `#1158` and `#1159` as the tenant-branding contract/palette truth cleanup
3. landing `#1160` so the browser smoke lane hard-requires both public MFE-config surfaces
4. keeping the repaired MFE-config parity explicit and verifier-backed
5. leaving the closed enterprise/frontend ownership lanes retired unless fresh evidence reopens them

Use the clean clones only:

- `/tmp/mereka-footer-source` for the active footer-source lane on `#1157`
- `/tmp/mereka-tenant-runtime-contract` for the tenant-branding runtime-contract lane on `#1158`
- `/tmp/mereka-mfe-config-smoke` for the smaller dual-surface smoke-proof lane on `#1160`
- `/tmp/mereka-two-week-tracker` for tracker/takeover doc follow-ups

## Immediate first task

Start with `T-01` from the tracker unless fresh evidence proves another lane is now more urgent.

Current verified first move:

1. pick up `#1157` for the shared footer source lane in `/tmp/mereka-footer-source`
2. then pick up `#1158` in `/tmp/mereka-tenant-runtime-contract` so the tenant-branding docs/schema/verifier stop over-claiming runtime CSS token injection
3. evaluate `#1159` as the narrower palette-truth follow-on, not as a separate runtime-injector lane
4. land `#1160` in `/tmp/mereka-mfe-config-smoke` so the browser smoke lane requires both public MFE-config surfaces
5. after that, keep the tracker aligned in `/tmp/mereka-two-week-tracker` with the current control point

## Non-negotiable rules

- Do not collapse repo truth, infra truth, and runtime truth into one sentence.
- Do not close an issue because the source looks right if runtime proof is part of the acceptance boundary.
- Do not rediscover already-closed queue debt unless new evidence shows regression.
- Do not describe the MFE-config lane as open runtime breakage if fresh live probes show parity is repaired.
- Do not misclassify the `Post-Deploy E2E Gate` failure as an app-runtime defect; the proven root cause is workflow checkout ordering and the fix is already merged in `#1154`.
- Do not widen the now-merged `#1148` or `#1153` lanes into general cleanup.
- Do not jump straight to tenant CSS runtime injection before the clearer shared-footer single-source lane.
- Do not jump straight to a runtime injector before `#1158` lands; current repo truth still needed a contract cleanup first.
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

1. `T-01` land `#1157` for the shared footer content source
2. `T-02` land `#1158` and then classify/land `#1159` without duplicating scope
3. `T-03` land `#1160` for the dual-surface smoke hardening
4. `T-04` keep the repaired MFE-config parity explicit and verifier-backed
5. `T-05` keep the closed enterprise/frontend ownership lanes retired unless they regress

## Minimum acceptable success for this program handoff

- `#1155` is merged and the tracker reflects that control point instead of treating it as open
- `#1157` is the active footer-source lane and advances the shared footer source of truth
- `#1158` is the active tenant-branding contract-truth lane and removes contradictory runtime claims before injector work starts
- `#1160` preserves the repaired LMS/apps MFE-config parity in the browser smoke lane, not only the dedicated contract verifier
- dev and staging LMS/apps MFE-config surfaces stay aligned for the governed learner/account/profile/login keys
- the `#2161` false-negative is closed by `#2162` and its merge-commit follow-through
- the repaired MFE-config parity remains explicit and verifier-backed
- the shared footer content source lane remains the active merge lane with one canonical payload for LMS and MFE public footer content
- the next promotion proof bundle still covers build digest -> overlay -> Argo -> live runtime
- the active tracker still matches the real state without narrative drift
