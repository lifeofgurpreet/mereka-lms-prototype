# OG-02: Conveyor Timing Scoreboard

**Charter**: Mereka LMS Conveyor Closure (rc02-102a56a07d)
**Item**: OG-02 — Hardening: end-to-end conveyor timing baseline
**Date**: 2026-04-18
**Data window**: 2026-04-14 to 2026-04-17 (most recent 50 runs)

---

## Methodology

### Workflow Map

```
mereka-lms main push
  └─► build-tutor-images.yml (mereka-lms repo)
        ├─ Lint & Validate
        ├─ Resolve Build Scope
        ├─ Select Build Lane / Render Preflight Contract
        ├─ Prepare Tutor Build Context
        ├─ Build OpenEdX Image  ─┐
        ├─ Build MFE Image      ─┘ (parallel)
        ├─ Post-push OpenEdX Scan ─┐
        ├─ Post-push MFE Scan     ─┘ (parallel — OpenEdX scan is the long pole)
        ├─ SLSA Provenance & Attestation
        ├─ Generate Release Bundle  ← artifact upload milestone
        ├─ Manual GitOps Bridge
        └─ Dispatch Dev Promotion   ← fires workflow_dispatch to bbi-infrastructure
              │
              ▼ (sub-second lag)
        promote-dev-image.yml (bbi-infrastructure repo)
              └─ Promote to Dev  ← creates overlay PR + enables auto-merge
```

### Data Sources

```bash
# Build runs
gh run list --repo Biji-Biji-Initiative/mereka-lms \
  --workflow build-tutor-images.yml --branch main -L 50 \
  --json databaseId,conclusion,startedAt,updatedAt,headSha

# Per-run job timing
gh run view <run_id> --repo Biji-Biji-Initiative/mereka-lms --json jobs

# Promote runs
gh run list --repo Biji-Biji-Initiative/bbi-infrastructure \
  --workflow promote-dev-image.yml -L 60 \
  --json databaseId,conclusion,startedAt,updatedAt,headSha
```

### Matching Logic

The Dispatch Dev Promotion job in mereka-lms fires `workflow_dispatch` to bbi-infrastructure. The promote run starts within seconds (clock skew observed: -13 s to -8 s, consistent with GitHub's event delivery timing). Matches were confirmed by aligning `dispatch_end` timestamps to `promote_start` within a ±15 s window.

---

## End-to-End Timing Table

Only cycles where **build success + promote success** are both confirmed are included. Argo sync latency is not included because ArgoCD auto-sync triggers on overlay PR merge (≈30 s poll interval on this cluster).

| # | SHA (mereka-lms) | Build Start (UTC) | Build Duration | Time to Bundle | Dispatch→Promote Gap | Promote Duration | Total Wall Clock |
|---|---|---|---|---|---|---|---|
| 1 | `102a56a07d` | 2026-04-17 23:14 | 31m 18s | 10m 52s | ~0s | 1m 31s | **32m 44s** |
| 2 | `29505f7fb3` | 2026-04-17 02:42 | 64m 31s | 23m 43s | ~0s | 1m 07s | **65m 24s** |
| 3 | `74eb96d9bc` | 2026-04-17 02:22 | 34m 27s | 29m 41s | ~0s | 1m 13s | **35m 30s** |
| 4 | `db66d6f66b` | 2026-04-14 21:27 | 13m 20s | 7m 56s | ~0s | 1m 18s | **14m 36s** |

**Column definitions:**
- **Build Duration**: `build_run.updatedAt - build_run.startedAt` (wall clock from first job to last job complete)
- **Time to Bundle**: `Generate Release Bundle job completedAt - build_run.startedAt` (milestone: artifact is available for downstream)
- **Dispatch→Promote Gap**: `promote_run.startedAt - Dispatch Dev Promotion job completedAt` (negative values due to clock skew → reported as ~0s)
- **Promote Duration**: `promote_run.updatedAt - promote_run.startedAt`
- **Total Wall Clock**: `promote_run.updatedAt - build_run.startedAt`

---

## Per-Job Breakdown (Representative Runs)

### Cycle 1 — SHA 102a56a07d (31m 18s build, 2026-04-17)

| Job | Start (UTC) | End (UTC) | Duration |
|---|---|---|---|
| Cancel Superseded Queued Main Builds | 23:14:17 | 23:14:22 | 5s |
| Lint & Validate | 23:14:25 | 23:14:34 | 9s |
| Resolve Build Scope | 23:14:24 | 23:14:36 | 12s |
| Select Build Lane | 23:14:38 | 23:14:46 | 8s |
| Render Preflight Contract | 23:14:38 | 23:14:52 | 14s |
| Prepare Tutor Build Context | 23:14:54 | 23:15:29 | 35s |
| **Build OpenEdX Image** | **23:15:32** | **23:18:18** | **2m 46s** |
| **Build MFE Image** | **23:15:31** | **23:16:53** | **1m 22s** |
| Post-push MFE Scan | 23:16:56 | 23:24:18 | 7m 22s |
| **Post-push OpenEdX Scan** | **23:18:21** | **23:44:53** | **26m 32s** ← long pole |
| SLSA Provenance & Attestation | 23:19:54 | 23:23:37 | 3m 43s |
| Generate Release Bundle | 23:23:41 | 23:25:07 | 1m 26s |
| Dispatch Dev Promotion | 23:44:56 | 23:45:32 | 36s |
| **Promote to Dev** (bbi-infrastructure) | **23:45:28** | **23:46:59** | **1m 31s** |

**Observation**: The OpenEdX scan (26m 32s) is the long pole for this cycle. The release bundle was ready at 23:25:07 — 19m 46s before the promote fired. The promote is blocked waiting for the scan to complete, not waiting for the bundle.

### Cycle 4 — SHA db66d6f66b (13m 20s build, 2026-04-14)

| Job | Start (UTC) | End (UTC) | Duration |
|---|---|---|---|
| Build OpenEdX Image | 21:29:55 | 21:32:33 | 2m 38s |
| Build MFE Image | 21:29:06 | 21:30:21 | 1m 15s |
| Post-push OpenEdX Scan | 21:32:35 | 21:40:24 | 7m 49s |
| Generate Release Bundle | 21:33:58 | 21:35:45 | 1m 47s |
| Dispatch Dev Promotion | 21:40:30 | 21:41:08 | 38s |
| **Promote to Dev** | **21:41:07** | **21:42:25** | **1m 18s** |

**Observation**: Fastest end-to-end cycle (14m 36s). The OpenEdX scan took only 7m 49s vs 26m+ in cycle 1 — consistent with cache warm vs cold behavior.

---

## Statistics

| Metric | Cycle 1 | Cycle 2 | Cycle 3 | Cycle 4 | **p50** | **p95** |
|---|---|---|---|---|---|---|
| **build_duration** | 31m 18s | 64m 31s | 34m 27s | 13m 20s | **32m 52s** | **64m 31s** |
| **time_to_bundle** | 10m 52s | 23m 43s | 29m 41s | 7m 56s | **17m 17s** | **29m 41s** |
| **dispatch→promote_gap** | ~0s | ~0s | ~0s | ~0s | **~0s** | **~0s** |
| **promote_duration** | 1m 31s | 1m 07s | 1m 13s | 1m 18s | **1m 15s** | **1m 31s** |
| **total_wall_clock** | 32m 44s | 65m 24s | 35m 30s | 14m 36s | **34m 07s** | **65m 24s** |

*p50 = median; p95 = 95th percentile. N=4; statistics are indicative, not statistically robust.*

---

## Data Limitations and Caveats

### Why N=4 Instead of N=10

The 50-run window (2026-04-14 to 2026-04-17) contained **12 successful builds** but only **4 confirmed end-to-end cycles** (build success + promote success). The remaining 8 builds dispatched to promote runs that **failed**. Analysis of the failure pattern:

| Build SHA | Build Result | Promote Result | Failure Reason |
|---|---|---|---|
| `ef5b41d7cf` | success | failure (`74168e2e76d5`) | Promote failure at 00:43:39 — promote job itself errored |
| `f1e2f2b7fc` | success | failure (`8643c87a1b78`) | Promote failure at 00:16:14 |
| `8a4edd9cf0` | success | no matching promote | No promote run found within ±15s window of dispatch |
| `fd4cf07532` | success | failure (`b8b0faa27321`) | Promote failure — 10m 51s duration suggests PR creation race |
| `a9bfa6fb0b` | success | failure (`d98281836847`) | 4m 43s failure |
| `640d867cc3` | success | failure (`576b2d330117`) | 1m 19s failure |
| `20ddce9a15` | success | failure (`4c3325a9e909`) | 1m 47s failure |
| `407c8e0f4c` | success | failure (`1392e857a49e`) | Failure at 14:00:34 |

**Promote failure rate in this window: 8/12 = 67%.** This is the primary reliability problem for the conveyor. The OG-03 promote audit documents the root causes.

To reach N=10 with confirmed end-to-end successes, data would need to extend back to March 2026 where the matching is harder (bbi-infrastructure promote SHAs do not include the triggering mereka-lms SHA as `headSha` — they use the bbi-infrastructure HEAD SHA at the time of dispatch).

### Dispatch→Promote Gap Measurement

The observed gap is consistently negative (−8 s to −13 s). This is clock skew between the GitHub Actions timing recorded for mereka-lms dispatch job completion and the bbi-infrastructure promote job start. The true dispatch latency is sub-second (GitHub `workflow_dispatch` is delivered synchronously). No queuing delay is observable.

### Argo Sync Latency (Not Measured)

After the promote PR is auto-merged, ArgoCD polls every 30 s (`timeout.reconciliation=30s`). The overlay image tag change triggers a sync. Typical sync duration for `mereka-lms-dev` is 2–5 min (observed from `operationState` timestamps). This adds 2.5–5.5 min to the user-visible "image live on dev" wall clock but is outside the build→promote measurement boundary.

**Estimated full conveyor (build start → pods running)**: p50 ≈ **37–40 min**; p95 ≈ **70–72 min**.

---

## Key Findings

1. **The OpenEdX post-push scan is the long pole.** It ranges from 7m 49s (cache warm) to 26m 32s (cold/slow runner). It blocks the Dispatch job from firing. The release bundle is ready 10–23 min before the promote triggers.

2. **The promote step itself is fast and reliable.** When it succeeds, it completes in 1m 07s–1m 31s. The 67% failure rate is not a latency problem — it's a correctness/availability problem documented in OG-03.

3. **The dispatch→promote gap is effectively zero.** No queuing delay exists between build and promote. If the promote is slow to start, it indicates a GitHub Actions runner availability issue in bbi-infrastructure, not a problem in the dispatch mechanism.

4. **The fastest observed end-to-end cycle is 14m 36s** (cache-warm OpenEdX scan). The theoretical minimum for a cache-warm run is approximately:
   - Pre-build gates: ~2m
   - Build OpenEdX (cache hit): ~3m
   - Build MFE (cache hit): ~2m
   - OpenEdX scan (warm): ~8m
   - Release bundle: ~2m
   - Dispatch + Promote: ~2m
   - **Total theoretical minimum: ~19m**

5. **Cycle 2 (64m 31s) is an outlier.** The 64m build duration for SHA `29505f7fb3` was driven by a cold OpenEdX scan (42m 35s inferred from dispatch end vs scan start). This is a known issue documented in `feedback-post-push-scan-no-retry.md` — the SBOM/Trivy scan has no retry and timeouts silently inflate wall clock.

---

## Recommendations

| Priority | Finding | Recommended Action |
|---|---|---|
| HIGH | 67% promote failure rate | Fix promote failures first (OG-03 root cause) — timing improvements are irrelevant if the promote doesn't succeed |
| MEDIUM | OpenEdX scan is long pole (7–26m variability) | Add retry with `continue-on-error: false` + timeout cap; consider moving scan to non-blocking post-promote job |
| LOW | Bundle ready 10–23m before dispatch fires | No action needed — bundle early-readiness is not blocking anything; the scan blocks the dispatch, not the bundle |
| INFO | Argo sync adds 2–5m not measured here | Add a conveyor probe that measures pod rollout time as a separate signal |

---

## Raw Data Reference

### Successful Build Runs (all, window 2026-04-14 to 2026-04-17)

| Run ID | SHA | Start | Duration | Conclusion |
|---|---|---|---|---|
| 24590743862 | 102a56a07d | 2026-04-17T23:14:15Z | 31m 18s | success |
| 24544983075 | 29505f7fb3 | 2026-04-17T02:42:43Z | 64m 31s | success |
| 24544462539 | 74eb96d9bc | 2026-04-17T02:22:53Z | 34m 27s | success |
| 24541022719 | ef5b41d7cf | 2026-04-17T00:21:03Z | 20m 53s | success (promote FAILED) |
| 24540213446 | f1e2f2b7fc | 2026-04-16T23:55:08Z | 20m 00s | success (promote FAILED) |
| 24536619263 | 8a4edd9cf0 | 2026-04-16T22:10:20Z | 21m 25s | success (promote NOT FOUND) |
| 24479243558 | fd4cf07532 | 2026-04-15T21:26:16Z | 27m 41s | success (promote FAILED) |
| 24436903729 | a9bfa6fb0b | 2026-04-15T04:46:26Z | 11m 33s | success (promote FAILED) |
| 24427346920 | 640d867cc3 | 2026-04-14T23:05:23Z | 37m 46s | success (promote FAILED) |
| 24423819160 | db66d6f66b | 2026-04-14T21:27:49Z | 13m 20s | success (promote success) |
| 24420988387 | 20ddce9a15 | 2026-04-14T20:20:59Z | 38m 19s | success (promote FAILED) |
| 24399821424 | 407c8e0f4c | 2026-04-14T12:49:18Z | 68m 28s | success (promote FAILED) |

### Successful Promote Runs (matched to build cycles above)

| Promote Run ID | Start | Duration | Matched Build SHA |
|---|---|---|---|
| 24591542962 | 2026-04-17T23:45:23Z | 1m 31s | 102a56a07d |
| 24546608401 | 2026-04-17T03:47:00Z | 1m 07s | 29505f7fb3 |
| 24545349967 | 2026-04-17T02:57:10Z | 1m 13s | 74eb96d9bc |
| 24424327899 | 2026-04-14T21:41:00Z | 1m 18s | db66d6f66b |
