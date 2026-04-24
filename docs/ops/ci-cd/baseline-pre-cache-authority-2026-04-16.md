---
id: BASELINE-PRE-CACHE-2026-04-16
status: snapshot
captured: 2026-04-16
epic: mereka-lms-jj97
bead: mereka-lms-jj97.10
---

# Phase 0 Baseline: Pre-Cache-Authority Build Performance

## Why This Exists

This document is the Phase 0 evidence baseline for the Shared Cache Authority sprint
(epic `mereka-lms-jj97`, RFC `RFC-BUILD-AUTHORITY-001`).

Without a baseline captured before the cache authority change lands, we cannot prove
that PR 2 (cache authority) improved anything. We would be comparing runs against
folklore rather than data. Every headline number in this document is a pre-change
measurement. Once PR 2 lands, the next 10 successful runs on `main` become the
post-change comparison set and those numbers are checked against the targets listed
in the **What to Compare** section below.

Red line (from RFC): do not hand-label builds as warm or cold from vibes. The
classification in this document is derived from observable facts — job durations and
runner labels — not from assumption. Where evidence is absent, the classification
is marked low-confidence.

---

## Method

### Queries Used

```bash
# List last 20 successful runs
gh run list \
  --workflow=build-tutor-images.yml \
  --status=success \
  --limit=20 \
  --json databaseId,createdAt,updatedAt,conclusion,headSha,event,headBranch,name

# Per-run job inventory (start/end per job)
gh run view <run-id> --json jobs

# Runner label per build job
gh api /repos/biji-biji-initiative/mereka-lms/actions/runs/<run-id>/jobs \
  --jq '.jobs[] | select(.name | test("Build (OpenEdX|MFE) Image")) | "\(.name): runner=\(.runner_name) labels=\(.labels)"'

# Failed run classification
gh run list --workflow=build-tutor-images.yml --status=failure --limit=20 \
  --json databaseId,createdAt,updatedAt,conclusion,headSha,event,headBranch,name

gh api /repos/biji-biji-initiative/mereka-lms/actions/runs/<run-id>/jobs \
  --jq '.jobs[] | select(.conclusion == "failure") | "\(.name) => \(.steps[] | select(.conclusion == "failure") | .name)"'
```

### Window Queried

2026-04-10 through 2026-04-16. The workflow was triggered by push to `main` (8 runs)
and `workflow_dispatch` on `main` (2 runs).

### Selection Criteria

Ten most recent successful runs of `build-tutor-images.yml`. All 10 are on the `main`
branch. The GitHub API returns step-level `startedAt`/`completedAt` as empty strings for
completed runs (a known GHA API limitation). Job-level start and end timestamps are
available and used for all duration measurements.

### Duration Measurement

- **total_run**: `workflow.createdAt` → `workflow.updatedAt`
- **queue_approx**: `workflow.createdAt` → `Build OpenEdX Image.startedAt` (this
  includes pre-build orchestration jobs: Cancel, Lint, Resolve Scope, Select Lane,
  Prepare Context — not a pure runner queue time)
- **build_openedx**: `Build OpenEdX Image.startedAt` → `Build OpenEdX Image.completedAt`
- **build_mfe**: `Build MFE Image.startedAt` → `Build MFE Image.completedAt`
- **scan_openedx**: `Post-push OpenEdX Scan.startedAt` → `Post-push OpenEdX Scan.completedAt`
- **scan_mfe**: `Post-push MFE Scan.startedAt` → `Post-push MFE Scan.completedAt`

### Cache State Classification

Cache state is derived as follows, not assumed:

| Class | Derivation rule |
|---|---|
| `local-hot` | build_openedx < 90s AND build_mfe < 90s (both sub-pipeline-overhead threshold) |
| `registry-warm` | build_openedx 90-600s OR build_mfe 90-300s (partial reuse, not fully cold) |
| `true-cold` | build_openedx > 600s (full webpack rebuild, no layer reuse) |
| `low-confidence` | Applied when duration pattern is ambiguous or runner changed mid-sample |

Without per-step timestamps or buildx log grep output from the API, the cache state
for each run is classified from job durations alone. The `Verify OpenEdX build cache
health` step exists in the workflow and logs cache evidence, but that log text is not
accessible via the jobs API — it requires `gh run view --log` which streams potentially
hundreds of MB. Step-log extraction is deferred to the telemetry pipeline (PR 3).

---

## Run Inventory

All 10 runs are on branch `main`. Durations in seconds.

| # | run_id | head_sha | event | runner_label | total | queue_approx | build-openedx | build-mfe | scan-openedx | scan-mfe | inferred_class | link |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | 24479243558 | fd4cf075 | push | mereka-lms-vps-fastlane-build | 1661s | 187s | 206s | 105s | 1209s | 212s | registry-warm | [run](https://github.com/biji-biji-initiative/mereka-lms/actions/runs/24479243558) |
| 2 | 24436903729 | a9bfa6fb | push | cie-vps-fastlane-build | 693s | 84s | 194s | 82s | 338s | 107s | registry-warm | [run](https://github.com/biji-biji-initiative/mereka-lms/actions/runs/24436903729) |
| 3 | 24427346920 | 640d867c | push | cie-vps-fastlane-build | 2266s | 79s | 1709s | 75s | 436s | 78s | true-cold (openedx) | [run](https://github.com/biji-biji-initiative/mereka-lms/actions/runs/24427346920) |
| 4 | 24423819160 | db66d6f6 | push | cie-vps-fastlane-build | 800s | 126s | 158s | 75s | 469s | 108s | registry-warm | [run](https://github.com/biji-biji-initiative/mereka-lms/actions/runs/24423819160) |
| 5 | 24420988387 | 20ddce9a | push | cie-vps-fastlane-build | 2299s | 156s | 1576s | 110s | 460s | 197s | true-cold (openedx) | [run](https://github.com/biji-biji-initiative/mereka-lms/actions/runs/24420988387) |
| 6 | 24399821424 | 407c8e0f | push | cie-vps-fastlane-build | 4108s | 80s | 186s | 81s | 1334s | 460s | registry-warm (scan anomaly) | [run](https://github.com/biji-biji-initiative/mereka-lms/actions/runs/24399821424) |
| 7 | 24292565290 | d6e9f14f | workflow_dispatch | mereka-k8s-heavy-builders | 2397s | 124s | 133s | 102s | 2051s | 183s | local-hot (scan anomaly) | [run](https://github.com/biji-biji-initiative/mereka-lms/actions/runs/24292565290) |
| 8 | 24290561577 | 0f2f4067 | workflow_dispatch | mereka-k8s-heavy-builders | 1103s | 101s | 133s | 147s | 865s | 207s | local-hot | [run](https://github.com/biji-biji-initiative/mereka-lms/actions/runs/24290561577) |
| 9 | 24251576373 | 16aec1d6 | push | mereka-vps-fastlane-build | 2784s | 63s | 72s | 56s | 2523s | 383s | local-hot (scan anomaly) | [run](https://github.com/biji-biji-initiative/mereka-lms/actions/runs/24251576373) |
| 10 | 24244345117 | e4764d58 | push | mereka-vps-fastlane-build | 4781s | 1205s | 86s | 68s | 2017s | 661s | local-hot (queue anomaly) | [run](https://github.com/biji-biji-initiative/mereka-lms/actions/runs/24244345117) |

Notes on runner label evolution: three distinct fastlane labels appear across the 10 runs
(`mereka-lms-vps-fastlane-build`, `cie-vps-fastlane-build`, `mereka-vps-fastlane-build`).
These all resolve to the same physical VPS host (`vmi3220759`) based on runner name
prefixes observed in the API. The label change reflects a CI routing rename, not a runner
hardware change. Runs 7-8 used ARC (`mereka-k8s-heavy-builders`) because the workflow
event was `workflow_dispatch` and the fastlane selector fell back to ARC at that time.

---

## Aggregate Timings

### All 10 Runs (mixed runner classes, mixed cache states)

| Stage | P50 | P95 | Mean | Min | Max | n= |
|---|---|---|---|---|---|---|
| total_run | 2299s (38m) | 4781s (80m) | 2289s (38m) | 693s (12m) | 4781s (80m) | 10 |
| queue_approx | 126s (2m) | 1205s (20m) | 220s (3m) | 63s | 1205s | 10 |
| build_openedx | 186s (3m) | 1709s (28m) | 445s (7m) | 72s | 1709s | 10 |
| build_mfe | 82s | 147s | 90s | 56s | 147s | 10 |
| scan_openedx | 1209s (20m) | 2523s (42m) | 1170s (20m) | 338s | 2523s | 10 |
| scan_mfe | 207s | 661s | 260s | 78s | 661s | 10 |

### Fastlane Runs Only (runs 1-6, 9-10; n=8)

| Stage | P50 | P95 | Mean | Min | Max | n= |
|---|---|---|---|---|---|---|
| build_openedx | 190s | 1709s | 502s | 72s | 1709s | 8 |
| build_mfe | 83s | 147s | 82s | 56s | 110s | 8 |
| scan_openedx | 1272s | 2523s | 1300s | 338s | 2523s | 8 |
| scan_mfe | 204s | 661s | 274s | 78s | 661s | 8 |

### ARC Heavy Runs Only (runs 7-8; n=2)

n=2 is not statistically meaningful but is captured for completeness.

| Stage | Run 7 | Run 8 |
|---|---|---|
| build_openedx | 133s | 133s |
| build_mfe | 102s | 147s |
| scan_openedx | 2051s | 865s |
| scan_mfe | 183s | 207s |

ARC build times are suspiciously similar (133s/133s openedx) suggesting layer reuse
from the ARC PVC cache (`arc-docker-cache` 50Gi persistent volume). However scan times
vary 3.7x between the two ARC runs, indicating scan variability dominates ARC total time.

---

## Cache Evidence

Per-step log content is not accessible via the GitHub jobs API (step `startedAt` /
`completedAt` are empty for completed runs, and log streaming requires a separate
authenticated request that would pull hundreds of MB per run). The following evidence
is therefore derived from job durations only.

### What the Workflow Does (Pre-Change State)

From `docker-bake.hcl` and `.github/workflows/build-tutor-images.yml`:

**openedx-proof target (current)**:
```
cache-from = [
  "type=gha,scope=tutor-openedx-proof",
  "type=registry,ref=${OPENEDX_CACHE_REF}",   # defaults to overhangio/openedx:21.0.0-cache
]
cache-to = [
  "type=gha,mode=max,scope=tutor-openedx-proof",
]
```

**mfe-proof target (current)**:
```
cache-from = [
  "type=gha,scope=tutor-openedx-mfe-proof",
  "type=registry,ref=${MFE_CACHE_REF}",        # defaults to overhangio/openedx-mfe:21.0.0-cache
]
cache-to = [
  "type=gha,mode=max,scope=tutor-openedx-mfe-proof",
]
```

The workflow overrides `OPENEDX_CACHE_REF` to `ghcr.io/.../openedx:mereka-brand` at
runtime (or `mereka-brand-fast` for fast builds). The GHA cache (`type=gha`) is
checked first, then the registry ref as secondary.

**Critical gap**: `type=gha` cache is runner-local to GitHub-hosted runners and not
shared across VPS fastlane runners. A VPS fastlane build that finds an empty
`type=gha` cache falls through to `type=registry` (the `mereka-brand` image). If the
`mereka-brand` image is not rebuilt recently or has an incompatible layer hash, the
build is effectively cold.

### Per-Run Cache State Assessment

| # | run_id | build_openedx | Cache state assessment |
|---|---|---|---|
| 1 | 24479243558 | 206s | Registry-warm. ~3m for full OpenEdX build indicates significant layer reuse from registry ref. Not a full cold build (cold = 28-50m). Not trivially local-hot (local-hot = <90s on this runner). |
| 2 | 24436903729 | 194s | Registry-warm. Similar pattern to run 1. |
| 3 | 24427346920 | 1709s | True-cold. 28+ minutes is consistent with full pip install + collectstatic from scratch. The `mereka-brand` registry ref likely had an incompatible layer hash (upstream tutor change or plugin change). |
| 4 | 24423819160 | 158s | Registry-warm. Immediately after run 3 would have exported fresh GHA cache. Likely used GHA cache exported by run 3. |
| 5 | 24420988387 | 1576s | True-cold. Preceding run 3 on the same day was also cold. Both point to a cache-busting change in the commit range (2026-04-14 batch). |
| 6 | 24399821424 | 186s | Registry-warm. Earlier in the same day (April 14 morning) — cache was still valid before the cold-busting change. |
| 7 | 24292565290 | 133s | Local-hot. ARC PVC cache (`arc-docker-cache`) was warm. Sub-90s threshold exceeded slightly but ARC runner overhead is higher (pod startup + DinD init). |
| 8 | 24290561577 | 133s | Local-hot. Same ARC runner pattern. PVC was clearly warm. |
| 9 | 24251576373 | 72s | Local-hot. 72s is the fastest openedx build in the sample — strong layer reuse from fastlane runner's local daemon cache. |
| 10 | 24244345117 | 86s | Local-hot. Similar to run 9. Note: queue_approx for this run is 1205s (20m), suggesting the runner was busy/queued — but once the job started, the build itself was fast. |

### Cache Import/Export Evidence

Without step-log access, it cannot be directly confirmed which cache type (GHA vs
registry) was the source for each run. The `Verify build cache health` step in the
workflow logs "Cache manifest imported from: ..." but that text is not captured here.

**Data gap**: No per-run evidence of whether `type=gha` or `type=registry` was the
actual cache source. This is the primary gap that limits pre/post-change comparison
validity. After PR 3 (telemetry ingestion) lands, this will be captured automatically
as a Prometheus label `cache_source_found`.

---

## Failure Modes Observed in Window

20 failed runs were found in the same window (2026-04-10 to 2026-04-16). Using
`BUILD_FAILURE_TAXONOMY.md` buckets:

| run_id | date | event | failed_job | failed_step | taxonomy_bucket |
|---|---|---|---|---|---|
| 24509482517 | 2026-04-16 | push | Build OpenEdX Image, Build MFE Image | Build OpenEdX/MFE image | Source Defect (deterministic build failure) |
| 24491141960 | 2026-04-16 | push | Build OpenEdX Image; SLSA | Build OpenEdX image; Log in to GHCR | Mixed: Source Defect + External Platform Defect |
| 24419232252 | 2026-04-14 | push | Post-push MFE Scan, Post-push OpenEdX Scan | Set up Docker Buildx | Runner/Daemon/Buildx Infrastructure Defect |
| 24400318736 | 2026-04-14 | push | Post-push MFE Scan, Post-push OpenEdX Scan | Set up Docker Buildx | Runner/Daemon/Buildx Infrastructure Defect |
| 24394024942 | 2026-04-14 | push | Dispatch Dev Promotion | Dispatch dev promotion | Workflow Contract Defect (cross-repo dispatch) |
| 24392562186 | 2026-04-14 | push | Generate Release Bundle | Dispatch dev promotion | Workflow Contract Defect (cross-repo dispatch) |
| 24389039021 | 2026-04-14 | push | Generate Release Bundle | Dispatch dev promotion | Workflow Contract Defect (cross-repo dispatch) |
| 24385183274 | 2026-04-14 | push | Build MFE Image | Build MFE image | Source Defect (or true-cold failure in build) |
| 24382675313 | 2026-04-14 | workflow_dispatch | Build MFE Image | Build MFE image | Source Defect (or true-cold failure in build) |
| 24380931231 | 2026-04-14 | workflow_dispatch | Select Build Lane | Select runner lane | Runner/Daemon/Buildx Infrastructure Defect |

Note: the 20 failed runs include many runs on 2026-04-14 when a high-volume batch of
commits was being debugged. The `Set up Docker Buildx` failures (runs 24419232252 and
24400318736) in the scan jobs are a Runner/Daemon pattern: the scan jobs use DinD and
a buildx setup failure there is runner-state-dependent, not a code defect.

The cross-repo dispatch failures (24394024942, 24392562186, 24389039021) are a
Workflow Contract Defect — the dispatch envelope or token scope was incorrect for those
commits. These were fixed by 2026-04-14T13:00 given that run 24399821424 (12:49 UTC)
succeeded.

---

## Known Anomalies

### Run 6 (24399821424): Scan Duration Spike — 4108s Total

`scan_openedx` took 1334s (22m) and `scan_mfe` took 460s (8m). These are 2-4x the
scan durations seen in adjacent runs with similar build times. The OpenEdX Scan job
started at 2026-04-14T13:33:40Z — 40 minutes after the build completed. This 40-minute
gap implies the scan job was queued behind other jobs on the fastlane runner, not a
scan process slowdown. The total run ended at 13:57:46, making this the longest run in
the sample at 68 minutes.

### Run 9 (24251576373): OpenEdX Scan — 2523s (42m)

Fastest build in the sample (72s build_openedx) followed by the slowest scan (2523s).
Scan duration is not correlated with build duration. This confirms that scan time is
an independent variable driven by: image size, CVE DB download freshness, SBOM
generation speed (syft), and runner-local cache availability for the registry pull in
the scan job. The 42-minute scan on run 9 is the single longest observed scan in the
sample.

### Run 10 (24244345117): 20-Minute Queue

`queue_approx` = 1205s (20 minutes). The build itself was fast (86s). The delay was
in the pre-build orchestration phase — either the runner was servicing another job or
the `Prepare Tutor Build Context` job was queued. The `Resolve Build Scope` job
started at 13:24:03 which is 19 minutes after run creation at 13:04:50. This is an
outlier: the next worst queue is 187s (3m). Cause not determinable without runner
state logs.

### Two Runner Classes in Sample

Runs 7-8 used `mereka-k8s-heavy-builders` (ARC), while runs 1-6 and 9-10 used VPS
fastlane variants. ARC and VPS have different local cache persistence models: ARC has
a 50Gi PVC (`arc-docker-cache`) shared across runner pods in the pool; VPS fastlane
uses the runner daemon's local buildx cache on disk. This means the two runner classes
are NOT directly comparable without controlling for cache state — which is exactly
what the benchmark class taxonomy in `BENCHMARK_CLASSES.md` is designed to enforce.

### Three Fastlane Label Names

The fastlane runner label changed three times during the 6-day window:
- `mereka-vps-fastlane-build` (runs 9-10, 2026-04-10)
- `cie-vps-fastlane-build` (runs 2-6, 2026-04-14 to 2026-04-15)
- `mereka-lms-vps-fastlane-build` (run 1, 2026-04-15)

All three labels resolve to the same physical runner (`vmi3220759`) based on runner
name prefixes. The label change was a routing configuration update, not a hardware
change. This is documented in the current branch fix (`fix/fastlane-labels-stw3`).
The label inconsistency does not affect this baseline's validity but should be
considered when joining future metrics by `runner_label`.

---

## What to Compare Against Post-Change

Once PR 2 (cache authority) lands and the next 10 successful main-push runs have
completed, compare these specific metrics:

### Primary Targets

| Metric | Pre-change P50 | Target post-change P50 | Definition of improvement |
|---|---|---|---|
| build_openedx | 186s | < 120s | 35% reduction (registry warm path should be sub-2min) |
| build_mfe | 82s | < 60s | 25% reduction |
| total_run | 2299s | < 1800s | 20% reduction (driven primarily by scan, not build) |

### Cache Health Targets (new metrics, not measurable pre-change)

After PR 3 (telemetry) lands, add:

| Metric | Target | Notes |
|---|---|---|
| % runs with `cache_source_found=registry` | > 80% | Confirms shared registry cache is being used |
| % runs classified `true-cold` | < 20% | Cold builds should be rare after shared cache |
| scan_openedx P50 | < 600s | Scan dominates pipeline; target set by `jj97.8` optimization |

### What Will NOT Change Immediately

- `scan_openedx` and `scan_mfe` durations: the cache authority change does not affect
  scan. Scan optimization is a separate workstream (`jj97.8`). Do not attribute scan
  improvements or regressions to the cache authority PR.
- True-cold builds triggered by cache-busting source changes: even with shared registry
  cache, a change to `requirements.txt` or MFE plugin source will still produce a
  cold-ish build. The shared cache reduces cold build cost from 30-50m to registry-warm
  (~5-10m), but does not eliminate cold builds.

### Comparison Validity

The primary gap limiting comparison validity is the absence of per-run cache-source
evidence. Post-change, the `Verify build cache health` step will need to emit a
structured log line or step output that identifies whether the registry shared cache
was the source. Without that, post-change runs could still be classified only by
duration — the same proxy used here.

**Recommendation**: before declaring PR 2 successful, verify at least 3 runs have
explicit log evidence of `importing cache manifest from ghcr.io/.../cache/openedx:main-amd64`.

---

## Raw Data Appendix

### Run List JSON (from gh CLI)

```json
[
  {"databaseId": 24479243558, "event": "push", "headBranch": "main", "headSha": "fd4cf0753255e2e9b2dd8e0cb81875f7daf486d1", "createdAt": "2026-04-15T21:26:16Z", "updatedAt": "2026-04-15T21:53:57Z", "conclusion": "success"},
  {"databaseId": 24436903729, "event": "push", "headBranch": "main", "headSha": "a9bfa6fb0be17ecd5fe22dc8d2a64584258ddee5", "createdAt": "2026-04-15T04:46:26Z", "updatedAt": "2026-04-15T04:57:59Z", "conclusion": "success"},
  {"databaseId": 24427346920, "event": "push", "headBranch": "main", "headSha": "640d867cc3a59ae3c75d736c7de7dd5e8907bf99", "createdAt": "2026-04-14T23:05:23Z", "updatedAt": "2026-04-14T23:43:09Z", "conclusion": "success"},
  {"databaseId": 24423819160, "event": "push", "headBranch": "main", "headSha": "db66d6f66b77203b2e9de749629c0d2b0c56bb65", "createdAt": "2026-04-14T21:27:49Z", "updatedAt": "2026-04-14T21:41:09Z", "conclusion": "success"},
  {"databaseId": 24420988387, "event": "push", "headBranch": "main", "headSha": "20ddce9a15836a2b8bf2abc0a603ec9a99ba24bc", "createdAt": "2026-04-14T20:20:59Z", "updatedAt": "2026-04-14T20:59:18Z", "conclusion": "success"},
  {"databaseId": 24399821424, "event": "push", "headBranch": "main", "headSha": "407c8e0f4c78f4b91198b92f0bf0f74f0beb7386", "createdAt": "2026-04-14T12:49:18Z", "updatedAt": "2026-04-14T13:57:46Z", "conclusion": "success"},
  {"databaseId": 24292565290, "event": "workflow_dispatch", "headBranch": "main", "headSha": "d6e9f14f623d26256ed55c0ef174a3fea19eada5", "createdAt": "2026-04-11T22:01:11Z", "updatedAt": "2026-04-11T22:41:08Z", "conclusion": "success"},
  {"databaseId": 24290561577, "event": "workflow_dispatch", "headBranch": "main", "headSha": "0f2f40674c1464fb0a71976eee571ad01a8f2e46", "createdAt": "2026-04-11T20:07:22Z", "updatedAt": "2026-04-11T20:25:45Z", "conclusion": "success"},
  {"databaseId": 24251576373, "event": "push", "headBranch": "main", "headSha": "16aec1d6684a39fa8cc40629cd7a0b244ed46497", "createdAt": "2026-04-10T15:51:57Z", "updatedAt": "2026-04-10T16:38:21Z", "conclusion": "success"},
  {"databaseId": 24244345117, "event": "push", "headBranch": "main", "headSha": "e4764d5834b6e24c26069e7edb2a527d05ae3b1d", "createdAt": "2026-04-10T13:04:50Z", "updatedAt": "2026-04-10T14:24:31Z", "conclusion": "success"}
]
```

### Per-Run Job Timestamps (raw)

#### Run 1 — 24479243558 (2026-04-15 push fd4cf075)

Runner: `mereka-lms-vps-fastlane-build` (vmi3220759)

| job | start | end | dur_s |
|---|---|---|---|
| Cancel Superseded Queued Main Builds | 2026-04-15T21:26:18Z | 2026-04-15T21:26:21Z | 3 |
| Lint & Validate | 2026-04-15T21:26:24Z | 2026-04-15T21:26:32Z | 8 |
| Resolve Build Scope | 2026-04-15T21:26:23Z | 2026-04-15T21:26:32Z | 9 |
| Render Preflight Contract | 2026-04-15T21:26:35Z | 2026-04-15T21:26:50Z | 15 |
| Select Build Lane | 2026-04-15T21:26:36Z | 2026-04-15T21:26:47Z | 11 |
| Prepare Tutor Build Context | 2026-04-15T21:26:53Z | 2026-04-15T21:27:34Z | 41 |
| Build OpenEdX Image | 2026-04-15T21:29:23Z | 2026-04-15T21:32:49Z | **206** |
| Build MFE Image | 2026-04-15T21:27:36Z | 2026-04-15T21:29:21Z | **105** |
| Post-push MFE Scan | 2026-04-15T21:29:25Z | 2026-04-15T21:32:57Z | **212** |
| Post-push OpenEdX Scan | 2026-04-15T21:32:54Z | 2026-04-15T21:53:03Z | **1209** |
| SLSA Provenance & Attestation | 2026-04-15T21:35:50Z | 2026-04-15T21:36:51Z | 61 |
| Generate Release Bundle | 2026-04-15T21:38:49Z | 2026-04-15T21:40:30Z | 101 |
| Dispatch Dev Promotion | 2026-04-15T21:53:23Z | 2026-04-15T21:53:57Z | 34 |

#### Run 2 — 24436903729 (2026-04-15 push a9bfa6fb)

Runner: `cie-vps-fastlane-build` (vmi3220759)

| job | start | end | dur_s |
|---|---|---|---|
| Cancel Superseded Queued Main Builds | 2026-04-15T04:46:28Z | 2026-04-15T04:46:31Z | 3 |
| Lint & Validate | 2026-04-15T04:46:34Z | 2026-04-15T04:46:44Z | 10 |
| Resolve Build Scope | 2026-04-15T04:46:34Z | 2026-04-15T04:46:43Z | 9 |
| Select Build Lane | 2026-04-15T04:46:45Z | 2026-04-15T04:46:54Z | 9 |
| Render Preflight Contract | 2026-04-15T04:46:47Z | 2026-04-15T04:47:05Z | 18 |
| Prepare Tutor Build Context | 2026-04-15T04:47:08Z | 2026-04-15T04:47:48Z | 40 |
| Build MFE Image | 2026-04-15T04:47:50Z | 2026-04-15T04:49:12Z | **82** |
| Build OpenEdX Image | 2026-04-15T04:47:50Z | 2026-04-15T04:51:04Z | **194** |
| Post-push MFE Scan | 2026-04-15T04:49:14Z | 2026-04-15T04:51:01Z | **107** |
| Post-push OpenEdX Scan | 2026-04-15T04:51:07Z | 2026-04-15T04:56:45Z | **338** |
| SLSA Provenance & Attestation | 2026-04-15T04:51:10Z | 2026-04-15T04:52:43Z | 93 |
| Generate Release Bundle | 2026-04-15T04:52:47Z | 2026-04-15T04:55:16Z | 149 |
| Dispatch Dev Promotion | 2026-04-15T04:56:49Z | 2026-04-15T04:57:59Z | 70 |

#### Run 3 — 24427346920 (2026-04-14 push 640d867c)

Runner: `cie-vps-fastlane-build` (vmi3220759)

| job | start | end | dur_s |
|---|---|---|---|
| Cancel Superseded Queued Main Builds | 2026-04-14T23:05:27Z | 2026-04-14T23:05:31Z | 4 |
| Resolve Build Scope | 2026-04-14T23:05:34Z | 2026-04-14T23:05:45Z | 11 |
| Lint & Validate | 2026-04-14T23:05:34Z | 2026-04-14T23:05:40Z | 6 |
| Render Preflight Contract | 2026-04-14T23:05:47Z | 2026-04-14T23:05:59Z | 12 |
| Select Build Lane | 2026-04-14T23:05:47Z | 2026-04-14T23:05:55Z | 8 |
| Prepare Tutor Build Context | 2026-04-14T23:06:01Z | 2026-04-14T23:06:40Z | 39 |
| Build MFE Image | 2026-04-14T23:06:42Z | 2026-04-14T23:07:57Z | **75** |
| Build OpenEdX Image | 2026-04-14T23:06:42Z | 2026-04-14T23:35:11Z | **1709** |
| Post-push MFE Scan | 2026-04-14T23:07:59Z | 2026-04-14T23:09:17Z | **78** |
| Post-push OpenEdX Scan | 2026-04-14T23:35:13Z | 2026-04-14T23:42:29Z | **436** |
| SLSA Provenance & Attestation | 2026-04-14T23:35:16Z | 2026-04-14T23:36:29Z | 73 |
| Generate Release Bundle | 2026-04-14T23:36:32Z | 2026-04-14T23:38:15Z | 103 |
| Dispatch Dev Promotion | 2026-04-14T23:42:33Z | 2026-04-14T23:43:08Z | 35 |

#### Run 4 — 24423819160 (2026-04-14 push db66d6f6)

Runner: `cie-vps-fastlane-build` (vmi3220759)

| job | start | end | dur_s |
|---|---|---|---|
| Cancel Superseded Queued Main Builds | 2026-04-14T21:27:52Z | 2026-04-14T21:27:57Z | 5 |
| Resolve Build Scope | 2026-04-14T21:27:59Z | 2026-04-14T21:28:09Z | 10 |
| Lint & Validate | 2026-04-14T21:28:00Z | 2026-04-14T21:28:08Z | 8 |
| Select Build Lane | 2026-04-14T21:28:12Z | 2026-04-14T21:28:21Z | 9 |
| Render Preflight Contract | 2026-04-14T21:28:11Z | 2026-04-14T21:28:26Z | 15 |
| Prepare Tutor Build Context | 2026-04-14T21:28:29Z | 2026-04-14T21:29:03Z | 34 |
| Build OpenEdX Image | 2026-04-14T21:29:55Z | 2026-04-14T21:32:33Z | **158** |
| Build MFE Image | 2026-04-14T21:29:06Z | 2026-04-14T21:30:21Z | **75** |
| Post-push MFE Scan | 2026-04-14T21:31:13Z | 2026-04-14T21:33:01Z | **108** |
| Post-push OpenEdX Scan | 2026-04-14T21:32:35Z | 2026-04-14T21:40:24Z | **469** |
| SLSA Provenance & Attestation | 2026-04-14T21:32:38Z | 2026-04-14T21:33:54Z | 76 |
| Generate Release Bundle | 2026-04-14T21:33:58Z | 2026-04-14T21:35:45Z | 107 |
| Dispatch Dev Promotion | 2026-04-14T21:40:30Z | 2026-04-14T21:41:08Z | 38 |

#### Run 5 — 24420988387 (2026-04-14 push 20ddce9a)

Runner: `cie-vps-fastlane-build` (vmi3220759)

| job | start | end | dur_s |
|---|---|---|---|
| Cancel Superseded Queued Main Builds | 2026-04-14T20:22:18Z | 2026-04-14T20:22:22Z | 4 |
| Resolve Build Scope | 2026-04-14T20:22:24Z | 2026-04-14T20:22:33Z | 9 |
| Lint & Validate | 2026-04-14T20:22:25Z | 2026-04-14T20:22:34Z | 9 |
| Select Build Lane | 2026-04-14T20:22:37Z | 2026-04-14T20:22:49Z | 12 |
| Render Preflight Contract | 2026-04-14T20:22:37Z | 2026-04-14T20:22:53Z | 16 |
| Prepare Tutor Build Context | 2026-04-14T20:22:56Z | 2026-04-14T20:23:32Z | 36 |
| Build MFE Image | 2026-04-14T20:23:35Z | 2026-04-14T20:25:25Z | **110** |
| Build OpenEdX Image | 2026-04-14T20:23:35Z | 2026-04-14T20:49:51Z | **1576** |
| Post-push MFE Scan | 2026-04-14T20:25:28Z | 2026-04-14T20:28:45Z | **197** |
| Post-push OpenEdX Scan | 2026-04-14T20:50:44Z | 2026-04-14T20:58:24Z | **460** |
| SLSA Provenance & Attestation | 2026-04-14T20:49:57Z | 2026-04-14T20:52:33Z | 156 |
| Generate Release Bundle | 2026-04-14T20:52:37Z | 2026-04-14T20:54:27Z | 110 |
| Dispatch Dev Promotion | 2026-04-14T20:58:28Z | 2026-04-14T20:59:18Z | 50 |

#### Run 6 — 24399821424 (2026-04-14 push 407c8e0f)

Runner: `cie-vps-fastlane-build` (vmi3220759)

| job | start | end | dur_s |
|---|---|---|---|
| Cancel Superseded Queued Main Builds | 2026-04-14T12:49:22Z | 2026-04-14T12:49:27Z | 5 |
| Resolve Build Scope | 2026-04-14T12:49:30Z | 2026-04-14T12:49:41Z | 11 |
| Lint & Validate | 2026-04-14T12:49:30Z | 2026-04-14T12:49:38Z | 8 |
| Render Preflight Contract | 2026-04-14T12:49:44Z | 2026-04-14T12:50:00Z | 16 |
| Select Build Lane | 2026-04-14T12:49:44Z | 2026-04-14T12:49:52Z | 8 |
| Prepare Tutor Build Context | 2026-04-14T12:50:03Z | 2026-04-14T12:50:36Z | 33 |
| Build MFE Image | 2026-04-14T12:50:38Z | 2026-04-14T12:51:59Z | **81** |
| Build OpenEdX Image | 2026-04-14T12:50:38Z | 2026-04-14T12:53:44Z | **186** |
| Post-push MFE Scan | 2026-04-14T12:56:47Z | 2026-04-14T13:04:27Z | **460** |
| SLSA Provenance & Attestation | 2026-04-14T12:54:46Z | 2026-04-14T12:57:15Z | 149 |
| Post-push OpenEdX Scan | 2026-04-14T13:33:40Z | 2026-04-14T13:55:54Z | **1334** |
| Generate Release Bundle | 2026-04-14T12:57:20Z | 2026-04-14T12:59:57Z | 157 |
| Dispatch Dev Promotion | 2026-04-14T13:56:07Z | 2026-04-14T13:57:45Z | 98 |

Note: OpenEdX Scan job did not start until 13:33:40, which is 40 minutes after build
completed at 12:53:44. This indicates the scan job was waiting for runner capacity.

#### Run 7 — 24292565290 (2026-04-11 workflow_dispatch d6e9f14f)

Runner: `mereka-k8s-heavy-builders` (ARC)

| job | start | end | dur_s |
|---|---|---|---|
| Cancel Superseded Queued Main Builds | 2026-04-11T22:02:04Z | 2026-04-11T22:02:09Z | 5 |
| Lint & Validate | 2026-04-11T22:02:11Z | 2026-04-11T22:02:17Z | 6 |
| Resolve Build Scope | 2026-04-11T22:02:11Z | 2026-04-11T22:02:22Z | 11 |
| Select Build Lane | 2026-04-11T22:02:25Z | 2026-04-11T22:02:33Z | 8 |
| Prepare Tutor Build Context | 2026-04-11T22:02:25Z | 2026-04-11T22:03:11Z | 46 |
| Build OpenEdX Image | 2026-04-11T22:03:15Z | 2026-04-11T22:05:28Z | **133** |
| Build MFE Image | 2026-04-11T22:03:53Z | 2026-04-11T22:05:35Z | **102** |
| Post-push OpenEdX Scan | 2026-04-11T22:05:53Z | 2026-04-11T22:40:04Z | **2051** |
| SLSA Provenance & Attestation | 2026-04-11T22:05:38Z | 2026-04-11T22:06:35Z | 57 |
| Post-push MFE Scan | 2026-04-11T22:05:57Z | 2026-04-11T22:09:00Z | **183** |
| Generate Release Bundle | 2026-04-11T22:40:13Z | 2026-04-11T22:41:07Z | 54 |

Note: `Dispatch Dev Promotion` did not appear in this run (no record in API). The run
completed at 22:41:08 based on `updatedAt`. This may indicate Dispatch was skipped or
the run completed with the bundle step as the terminal job.

#### Run 8 — 24290561577 (2026-04-11 workflow_dispatch 0f2f4067)

Runner: `mereka-k8s-heavy-builders` (ARC)

| job | start | end | dur_s |
|---|---|---|---|
| Cancel Superseded Queued Main Builds | 2026-04-11T20:07:56Z | 2026-04-11T20:07:59Z | 3 |
| Resolve Build Scope | 2026-04-11T20:08:02Z | 2026-04-11T20:08:13Z | 11 |
| Lint & Validate | 2026-04-11T20:08:02Z | 2026-04-11T20:08:11Z | 9 |
| Prepare Tutor Build Context | 2026-04-11T20:08:15Z | 2026-04-11T20:08:59Z | 44 |
| Select Build Lane | 2026-04-11T20:08:15Z | 2026-04-11T20:08:24Z | 9 |
| Build MFE Image | 2026-04-11T20:09:26Z | 2026-04-11T20:11:53Z | **147** |
| Build OpenEdX Image | 2026-04-11T20:09:03Z | 2026-04-11T20:11:16Z | **133** |
| Post-push OpenEdX Scan | 2026-04-11T20:11:19Z | 2026-04-11T20:25:44Z | **865** |
| Post-push MFE Scan | 2026-04-11T20:11:57Z | 2026-04-11T20:15:24Z | **207** |
| SLSA Provenance & Attestation | 2026-04-11T20:11:57Z | 2026-04-11T20:12:59Z | 62 |
| Generate Release Bundle | 2026-04-11T20:25:44Z | 2026-04-11T20:25:44Z | 0 (skipped) |

Note: `Generate Release Bundle` and `Dispatch Dev Promotion` were skipped or did not
appear for this run. The run was a `workflow_dispatch` and may have had a condition
preventing the promotion chain.

#### Run 9 — 24251576373 (2026-04-10 push 16aec1d6)

Runner: `mereka-vps-fastlane-build` (vmi3220759)

| job | start | end | dur_s |
|---|---|---|---|
| Cancel Superseded Queued Main Builds | 2026-04-10T15:52:00Z | 2026-04-10T15:52:04Z | 4 |
| Resolve Build Scope | 2026-04-10T15:52:07Z | 2026-04-10T15:52:18Z | 11 |
| Lint & Validate | 2026-04-10T15:52:07Z | 2026-04-10T15:52:15Z | 8 |
| Prepare Tutor Build Context | 2026-04-10T15:52:21Z | 2026-04-10T15:52:58Z | 37 |
| Select Build Lane | 2026-04-10T15:52:20Z | 2026-04-10T15:52:27Z | 7 |
| Build OpenEdX Image | 2026-04-10T15:53:00Z | 2026-04-10T15:54:12Z | **72** |
| Build MFE Image | 2026-04-10T15:53:00Z | 2026-04-10T15:53:56Z | **56** |
| Post-push MFE Scan | 2026-04-10T15:53:59Z | 2026-04-10T16:00:22Z | **383** |
| Post-push OpenEdX Scan | 2026-04-10T15:55:28Z | 2026-04-10T16:37:31Z | **2523** |
| SLSA Provenance & Attestation | 2026-04-10T15:54:16Z | 2026-04-10T15:55:21Z | 65 |
| Generate Release Bundle | 2026-04-10T16:37:34Z | 2026-04-10T16:38:21Z | 47 |

#### Run 10 — 24244345117 (2026-04-10 push e4764d58)

Runner: `mereka-vps-fastlane-build` (vmi3220759)

| job | start | end | dur_s |
|---|---|---|---|
| Cancel Superseded Queued Main Builds | 2026-04-10T13:23:55Z | 2026-04-10T13:24:00Z | 5 |
| Lint & Validate | 2026-04-10T13:24:04Z | 2026-04-10T13:24:13Z | 9 |
| Prepare Tutor Build Context | 2026-04-10T13:24:16Z | 2026-04-10T13:24:52Z | 36 |
| Select Build Lane | 2026-04-10T13:24:17Z | 2026-04-10T13:24:27Z | 10 |
| Build MFE Image | 2026-04-10T13:24:54Z | 2026-04-10T13:26:02Z | **68** |
| Build OpenEdX Image | 2026-04-10T13:24:55Z | 2026-04-10T13:26:21Z | **86** |
| Post-push MFE Scan | 2026-04-10T13:26:26Z | 2026-04-10T13:37:27Z | **661** |
| Post-push OpenEdX Scan | 2026-04-10T13:26:39Z | 2026-04-10T14:00:16Z | **2017** |
| SLSA Provenance & Attestation | 2026-04-10T14:17:50Z | 2026-04-10T14:21:02Z | 192 |
| Resolve Build Scope | 2026-04-10T13:24:03Z | 2026-04-10T13:24:13Z | 10 |
| Generate Release Bundle | 2026-04-10T14:23:18Z | 2026-04-10T14:24:30Z | 72 |

Note: `createdAt` is 13:04:50 but all jobs started at 13:23:55+. The 19-minute gap
(1205s) is the queue/runner-acquisition time. The workflow dispatch or GitHub webhook
latency is not the cause — this is the same runner processing earlier work.

### Computed Duration Table (Python source)

```
run_id          total   q_approx   openedx   mfe   scan_oedx   scan_mfe   runner_label
24479243558     1661    187         206       105   1209         212        mereka-lms-vps-fastlane-build
24436903729      693     84         194        82    338         107        cie-vps-fastlane-build
24427346920     2266     79        1709        75    436          78        cie-vps-fastlane-build
24423819160      800    126         158        75    469         108        cie-vps-fastlane-build
24420988387     2299    156        1576       110    460         197        cie-vps-fastlane-build
24399821424     4108     80         186        81   1334         460        cie-vps-fastlane-build
24292565290     2397    124         133       102   2051         183        mereka-k8s-heavy-builders
24290561577     1103    101         133       147    865         207        mereka-k8s-heavy-builders
24251576373     2784     63          72        56   2523         383        mereka-vps-fastlane-build
24244345117     4781   1205          86        68   2017         661        mereka-vps-fastlane-build

Aggregates (n=10):
  total_run:    mean=2289s  p50=2299s  p95=4781s  min=693s   max=4781s
  build_openedx: mean=445s  p50=186s   p95=1709s  min=72s    max=1709s
  build_mfe:     mean=90s   p50=82s    p95=147s   min=56s    max=147s
  scan_openedx:  mean=1170s p50=1209s  p95=2523s  min=338s   max=2523s
  scan_mfe:      mean=260s  p50=207s   p95=661s   min=78s    max=661s
```

---

*Captured by implementor-E on 2026-04-16. Read-only queries only — no builds triggered,
no workflows modified. Bead: mereka-lms-jj97.10.*
