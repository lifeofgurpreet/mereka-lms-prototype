# Two-Week Platform Truth Takeover Prompt

You are taking over the `mereka-lms` two-week platform-truth lane.

Start by reading:

1. `docs/status/active/TWO_WEEK_PLATFORM_TRUTH_TRACKER_2026-03-28.md`
2. `docs/status/active/README.md`
3. `docs/status/active/UI_RUNTIME_TRUTH_TRACKER_2026-03-25.md`
4. `docs/status/active/DEV_STAGING_TRUTH_TRACKER_2026-03-25.md`
5. `scripts/qa/verify-mfe-config-contract.sh`
6. `scripts/qa/verify-tenant-visual-contract.sh`

If you need the closed proof lanes for context, also read:

7. `https://github.com/Biji-Biji-Initiative/mereka-lms/pull/1148`
8. `https://github.com/Biji-Biji-Initiative/mereka-lms/pull/1158`
9. `https://github.com/Biji-Biji-Initiative/mereka-lms/pull/1165`
10. `https://github.com/Biji-Biji-Initiative/mereka-lms/issues/842`
11. `https://github.com/Biji-Biji-Initiative/mereka-lms/issues/843`
12. `https://github.com/Biji-Biji-Initiative/mereka-lms/issues/834`

If you need the active successor implementation lane context, also read:

13. `https://github.com/Biji-Biji-Initiative/mereka-lms/issues/1164`

## Mission

Keep the next two weeks of platform work truthful across all three planes:

- app repo truth
- infra/promotion truth
- live runtime truth

The objective is not "keep the queue busy." The objective is "finish the remaining lanes in the right order, with proof that survives handoff."

## Current control point

The queue is no longer the problem. `#1158`, `#1165`, and `#1166` are merged, `#834` is closed, `#1167` is the active tracker-refresh doc lane, and `#1164` is intentionally still open until live tenant-host proof exists.

The system is currently concentrated around:

1. carrying merged `#1166` through post-merge main and deployment truthfully
2. keeping `#1164` open until live tenant-host runtime proof exists
3. keeping the repaired nonprod MFE-config parity lane represented as closed
4. keeping closed enterprise/frontend ownership lanes retired unless fresh evidence reopens them
5. keeping the current board aligned with reality as merges land quickly

Use the clean clones only:

- `/tmp/mereka-tenant-palette-bridge` for `#1166` follow-through and live-proof commands
- `/tmp/mereka-two-week-tracker` for tracker/closeout doc follow-ups

## Immediate first task

Start with `T-01` from the tracker unless fresh evidence proves another lane is now more urgent.

Current verified first move:

1. treat `#1166` as merged repo truth, not an open PR lane
2. verify post-merge `main` and deployment movement for `#1166`
3. run the targeted tenant-host proof once the merged change is actually live
4. keep `/tmp/mereka-two-week-tracker` aligned with the new control point and `#1167` truthful
5. keep `#1164` open until that runtime proof exists

## Non-negotiable rules

- Do not collapse repo truth, infra truth, and runtime truth into one sentence.
- Do not close an issue because the source looks right if runtime proof is part of the acceptance boundary.
- Do not rediscover already-closed queue debt unless new evidence shows regression.
- Do not describe the MFE-config lane as open runtime breakage if fresh live probes show parity is repaired.
- Do not misclassify the `Post-Deploy E2E Gate` failure as an app-runtime defect; the proven root cause is workflow checkout ordering and the fix is already merged in `#1154`.
- Do not widen the now-merged `#1148`, `#1153`, `#1158`, or `#1165` lanes into general cleanup.
- Do not reopen `#1157` or `#1159` casually; both are no longer active merge lanes.
- Do not close `#1164` before live tenant-host runtime proof is recorded.
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

1. `T-01` keep merged `#1166` truthful through post-merge and runtime proof
2. `T-02` keep `#1164` open until live tenant-host proof exists
3. `T-03` keep the repaired MFE-config parity lane explicit and verifier-backed
4. `T-04` keep merged infra proof-chain lanes explicit
5. `T-05` keep the tracker and retired lanes truthful

## Minimum acceptable success for this program handoff

- `#1166` is merged, post-merge `main` is clean, and runtime proof is recorded
- `#1164` stays open until live tenant-host runtime proof exists
- `#1158` and `#1165` remain represented as merged truth, not active lanes
- infra `#2164` remains represented as merged proof-chain truth
- infra `#2158` remains represented as the merged nonprod MFE-config repair
- the tracker still matches the real repo, infra, and runtime state without narrative drift
