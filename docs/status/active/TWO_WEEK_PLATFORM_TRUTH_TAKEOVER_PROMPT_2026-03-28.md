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

The queue is no longer the problem. `#1157`, `#1161`, `#1162`, and infra `#2164` are merged, live LMS/apps MFE-config parity is repaired, and `#842` / `#843` are closed.

The system is currently concentrated around:

1. landing `#1158` as the tenant-branding contract-truth cleanup
2. landing `#1160` so the browser smoke lane hard-requires both public MFE-config surfaces
3. keeping merged infra `#2164` represented truthfully as part of the promotion-proof chain
4. keeping the repaired MFE-config parity explicit and verifier-backed
5. leaving the closed enterprise/frontend ownership lanes retired unless fresh evidence reopens them

Use the clean clones only:

- `/tmp/mereka-tenant-runtime-contract` for the tenant-branding runtime-contract lane on `#1158`
- `/tmp/mereka-mfe-config-smoke` for the smaller dual-surface smoke-proof lane on `#1160`
- `/tmp/bbi-promotion-proof-bundle` for infra proof lane `#2164`
- `/tmp/mereka-two-week-tracker` for tracker/takeover doc follow-ups

## Immediate first task

Start with `T-01` from the tracker unless fresh evidence proves another lane is now more urgent.

Current verified first move:

1. pick up `#1158` in `/tmp/mereka-tenant-runtime-contract` so the tenant-branding docs/schema/verifier stop over-claiming runtime CSS token injection
2. land `#1160` in `/tmp/mereka-mfe-config-smoke` so the browser smoke lane requires both public MFE-config surfaces
3. keep the tracker aligned in `/tmp/mereka-two-week-tracker` with the current control point
4. treat `#2164` as merged proof-chain reality, not an active queue item
5. treat `#1159` as closed unless a narrow, deliberate follow-on is still needed after `#1158`

## Non-negotiable rules

- Do not collapse repo truth, infra truth, and runtime truth into one sentence.
- Do not close an issue because the source looks right if runtime proof is part of the acceptance boundary.
- Do not rediscover already-closed queue debt unless new evidence shows regression.
- Do not describe the MFE-config lane as open runtime breakage if fresh live probes show parity is repaired.
- Do not misclassify the `Post-Deploy E2E Gate` failure as an app-runtime defect; the proven root cause is workflow checkout ordering and the fix is already merged in `#1154`.
- Do not widen the now-merged `#1148` or `#1153` lanes into general cleanup.
- Do not reopen `#1157` or `#1159` casually; both are no longer active merge lanes.
- Do not jump straight to a runtime injector before `#1158` and `#1160` are settled.
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

1. `T-01` land `#1158`
2. `T-02` land `#1160`
3. `T-03` keep merged infra `#2164` explicit in the promotion proof chain
4. `T-04` keep the repaired MFE-config parity explicit and verifier-backed
5. `T-05` keep the tracker and retired lanes truthful

## Minimum acceptable success for this program handoff

- `#1158` is merged and removes contradictory tenant-branding runtime claims before injector work starts
- `#1160` preserves the repaired LMS/apps MFE-config parity in the browser smoke lane, not only the dedicated contract verifier
- infra `#2164` remains represented as merged proof-chain truth
- dev and staging LMS/apps MFE-config surfaces stay aligned for the governed learner/account/profile/login keys
- the `#2161` false-negative is closed by `#2162`, and `#2163` / `#2164` extend the proof chain cleanly
- the repaired MFE-config parity remains explicit and verifier-backed
- the shared footer content source lane remains retired unless fresh evidence reopens it
- the next promotion proof bundle still covers build digest -> overlay -> Argo -> live runtime
- the active tracker still matches the real state without narrative drift
