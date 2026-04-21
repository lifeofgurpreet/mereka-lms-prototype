---
id: BENCHMARK-CLASSES-001
status: draft
created: 2026-04-16
epic: mereka-lms-jj97
bead: jj97.18
blocks: [jj97.13, jj97.14, jj97.15]
---

# Benchmark Classes — Build Performance Taxonomy

> **Audience**: CI/CD engineers, infra team, anyone comparing "fastlane vs ARC" or "this PR built faster".
> **Related**: `RFC-BUILD-AUTHORITY-001.md`, `BUILD-AUTHORITY-SPRINT-AGENT-BRIEF.md`, `CI_METRICS.md`
> **Runner-class taxonomy source-of-truth**: [`bbi-infrastructure/config/runner-class-taxonomy.yaml`](https://github.com/Biji-Biji-Initiative/bbi-infrastructure/blob/main/config/runner-class-taxonomy.yaml) (per ADR-025 §1). The `runner_class` label values used throughout this document (`fastlane`, `arc-standard`, `arc-heavy`, `arc-prod`, `github-hosted`) are closed-set enums defined upstream. Do NOT redefine them locally.

---

## Upstream taxonomy binding

This document treats the upstream `runner-class-taxonomy.yaml` as authoritative. When the LMS build-workflow gate `scripts/qa/verify-runner-class-taxonomy-upstream.sh` runs in CI, every `runs-on:` label in `.github/workflows/` is checked against that file's `label_globs`. Labels outside the closed set are rejected unless marked with `# ci:allow-github-hosted` or `# ci:runner-exempt <reason>`.

Ownership: infra team owns the YAML; the LMS repo's drift gate is the consumer. When infra adds, removes, or renames a runner class, the LMS gate picks it up on its next CI run — there is no local taxonomy to update here.

---

## Why benchmark classes exist

Comparing ARC-heavy runners against fastlane VPS runners is meaningless without first controlling for cache state. A warm fastlane run (local Docker cache intact, all layers reused) measured against a cold ARC run (freshly provisioned ephemeral runner, no registry cache yet imported) will make fastlane look faster by 30–40 minutes — not because it is fundamentally faster, but because the comparison is confounded by cache state. Benchmark classes provide the controlled variable: they define the exact cache conditions under which a build is measured, so that runner-class comparisons (`runner_class=fastlane` vs `runner_class=arc-heavy`) are apples-to-apples. Without this control, every "fastlane vs ARC" discussion reduces to folklore and confirmation bias. With it, the question becomes a query.

### 2026-04-20 truth correction

The workflow input now accepts `benchmark_class=app-cache-cold`. The old
`benchmark_class=true-cold` value remains accepted only as a legacy alias. Both
select **app-cache-cold**: wipe local BuildKit builder/cache state and suppress
the shared app-level GHCR `cache-from` ref before running the canonical
bake/build helpers. This does **not** prove a pristine Docker daemon, an empty
base-image store, a fresh VM, or an empty ARC/fastlane host outside the explicit
BuildKit state the workflow controls.

Use `app-cache-cold` in prose, workflow dispatches, artifact names, and new
metadata. Use `true-cold` only when discussing historical dashboard values or
the backwards-compatible alias.

---

## The four classes

### 1. `app-cache-cold`

#### Definition

Current workflow contract:

- wipes local BuildKit cache and builder state (`docker buildx prune -af`,
  buildx state removal, recreated builder)
- skips GHCR login for the class
- clears `CACHE_FROM_ARG`, so the canonical build helpers use no shared
  app-level registry cache import
- renders Tutor build contexts with the same dependency-acquisition contract
  used by local/bootstrap lanes: Tutor-exposed images use `mirror.gcr.io`, and
  `dependency-image-mirrors.sh` normalizes the known Tutor-emitted hardcoded
  Docker Hub refs
- configures the measured BuildKit builders with a `docker.io` registry mirror
  as a fallback guard; this is not the primary contract for hardcoded upstream
  `FROM`/`COPY --from` refs because BuildKit can still fall back to Docker Hub
- selects no-cache bake targets through `--cache-mode none`
- keeps benchmark output local (`--output-mode docker`) and does not write
  registry cache
- fails the measured build job if the benchmark artifact records
  `OUTCOME=failure`; uploaded artifacts are diagnostics, not a waiver

Limitations:

- it is not a machine-cold clean-room build
- it does not prove the Docker daemon image store is empty
- it does not prove base images were absent before the run
- it does not prove a brand-new fastlane host or ARC PVC

If the measured telemetry later shows no successful cache import and
`ci_layer_reuse_ratio < 0.20`, the observed run may be classified as true-cold
by the metrics layer. That is an observed outcome, not something the current
workflow input can guarantee on persistent runners.

#### Reproducible setup

```bash
# On the target runner (fastlane VPS or ARC pod with exec access):

# 1. Wipe all local buildx cache (L1)
docker buildx prune -af

# 2. Remove any lingering buildx builder instance state
rm -rf /tmp/buildx-* ~/.docker/buildx

# 3. Force a new builder instance (clears layer cache from daemon)
docker buildx rm mereka-builder 2>/dev/null || true
docker buildx create --name mereka-builder --driver docker-container --use

# 4. Suppress the shared app-level registry cache import.
#    Set CACHE_FROM_ARG="" in the benchmark workflow step.
#    The current workflow does this automatically for benchmark_class=app-cache-cold.
#    Do NOT push a zeroed cache; this is a read-only suppression.

# 5. Select no-cache bake targets through the canonical helpers:
#    scripts/infra/build-openedx-image.sh --cache-mode none ...
#    scripts/infra/build-mfe-image.sh --cache-mode none ...

# 6. Verify explicit BuildKit state before triggering build:
docker buildx du          # Should show 0B or minimal buildx cache

# Optional note:
# docker system df may still show base images on persistent runners.
# That is outside this class guarantee.
```

#### What it tests

The app-cache-cold recovery path: how long do the canonical Open edX and MFE
build helpers take when shared app-level BuildKit cache imports are disabled?
This catches hidden dependency on registry cache, cache-importing bake targets,
and helper arguments that only work on the warm path.

It is not a full disaster-recovery baseline for a pristine machine. A separate
machine-cold lane would need an explicitly fresh runner/daemon contract and its
own proof artifacts.

#### Expected timing band

| image_family | P50 | P95 | Notes |
|---|---|---|---|
| openedx | 30–90 min | TBD | RFC problem statement; range driven by upstream layer fetch variability |
| mfe | ~44 min (2652s observed) | TBD | 12 MFEs × cold webpack; single observed data point from run 24226842382 |

P95 entries become bead `jj97.10` (baseline capture) outputs.

#### Anti-uses

- Do NOT market `benchmark_class=app-cache-cold` or the legacy `true-cold` alias
  as pristine machine-cold proof.
- Do NOT use app-cache-cold as a routine regression test — it is slow by
  definition and tells you little about steady-state performance.
- Do NOT compare app-cache-cold timings across runner classes without also
  controlling for CPU count, daemon state, and DinD overhead.
- Do NOT use app-cache-cold results to argue for or against fastlane normal
  operations; use `registry-warm` or `local-hot` for those questions.

---

### 2. `registry-warm`

#### Definition

L2 (shared GHCR registry cache) imported successfully: `ci_cache_source_found{source="registry"} == 1`. Layer reuse ratio is between 20% and 90%: `0.20 ≤ ci_layer_reuse_ratio ≤ 0.90`. L1 (runner-local) may or may not be present, but the classification is driven by the registry import success signal, not local state.

This is the **target steady state** for all production builds. A wiped runner that can still reach the GHCR registry cache should fall into this class.

#### Reproducible setup

```bash
# On the target runner:

# 1. Wipe local buildx cache to remove L1 advantage
docker buildx prune -af
docker buildx rm mereka-builder 2>/dev/null || true
docker buildx create --name mereka-builder --driver docker-container --use

# 2. Confirm GHCR registry cache is populated and reachable:
docker buildx imagetools inspect \
  ghcr.io/biji-biji-initiative/mereka-lms/cache/openedx:main-amd64
docker buildx imagetools inspect \
  ghcr.io/biji-biji-initiative/mereka-lms/cache/mfe:main-amd64
# Both must return a valid manifest. If either returns 404/error,
# run a trusted main build first to populate the cache.

# 3. Set cache-from to include the registry ref (standard workflow config).
#    CACHE_FROM_ARG is set by the workflow; verify it includes:
#    type=registry,ref=ghcr.io/biji-biji-initiative/mereka-lms/cache/openedx:main-amd64

# 4. Trigger the benchmark build without modifying the Dockerfile or
#    any layer-invalidating source (e.g., a trivial workflow-only change).
```

#### What it tests

The **primary engineering target**: given a populated shared registry cache, how long does a build take on a fresh runner? This is the number that matters for "fastlane vs ARC" comparisons. It answers: does ARC-heavy produce acceptable warm builds, or do we still need VPS fastlane for steady-state CI?

#### Expected timing band

| image_family | P50 | P95 | Notes |
|---|---|---|---|
| openedx | <10 min (target) | TBD | RFC DoD; 71s observed on full cache-hit (L1/L2), range depends on partial layer reuse |
| mfe | <5 min (target) | TBD | RFC DoD; warm path ~5–8 min observed for YAML-only changes |

#### Anti-uses

- Do NOT conflate `registry-warm` with `local-hot`. A runner that has L1 cache will produce artificially low times within the `registry-warm` band.
- Do NOT use `registry-warm` as evidence the cache is "healthy" without also checking `ci_cache_manifest_digest_imported` — a stale manifest that happens to reuse layers by content-address can produce `registry-warm` class without the cache authority itself being fresh.
- Do NOT treat all `registry-warm` runs as equivalent — a 25% reuse ratio and an 89% reuse ratio are both `registry-warm` by definition but have very different timings.

---

### 3. `local-hot`

#### Definition

L1 (runner-local Docker daemon or buildx cache) is available and dominant: `ci_layer_reuse_ratio > 0.90` (more than 90% of layers reused). This class is achievable only on persistent runners (fastlane VPS) or ARC runners with large persistent PVC (`arc-docker-cache`, 50Gi). Ephemeral runners will almost never land here on first use of a build day.

#### Reproducible setup

```bash
# Prerequisites: a runner that has previously built the same image family
# and NOT had its cache wiped.

# On fastlane VPS (persistent Docker daemon):
# Simply trigger the same build twice in succession without any
# layer-invalidating changes. The second run will be local-hot.

# On ARC with persistent PVC:
# The arc-docker-cache PVC (50Gi) retains layers across runner pod restarts.
# Confirm PVC is mounted:
kubectl get pvc arc-docker-cache -n arc-runners

# Verify local cache is populated before triggering:
docker buildx du   # Should show significant GiB of cached layers

# Trigger with the same image family, same Dockerfile, same base image tag.
# No artificial setup needed — do NOT pre-wipe anything for this class.
```

#### What it tests

**Best-case performance** on a warm persistent runner. Shows the upper bound of what fastlane can achieve on repeated runs (YAML-only changes, config-only changes). The 71-second OpenEdX build observed on 2026-04-10 is a `local-hot` data point — it represents the performance envelope when everything is working perfectly.

#### Expected timing band

| image_family | P50 | P95 | Notes |
|---|---|---|---|
| openedx | ~71s observed | TBD | Single observed data point, run 24226842382, full cache hit |
| mfe | 5–8 min observed | TBD | Warm path with local cache; still slower than openedx because of per-MFE npm overhead |

#### Anti-uses

- Do NOT use `local-hot` results to set SLOs for all builds — most builds (especially on ARC or after daemon resets) will never reach this class.
- Do NOT compare `local-hot` fastlane against `registry-warm` ARC and conclude fastlane is faster — you are measuring different cache classes.
- Do NOT report `local-hot` as the "warm build time" to stakeholders — it overstates the steady-state improvement achievable from the registry cache authority change alone.

---

### 4. `scan-only`

#### Definition

The image was already built and pushed in a prior step. The job that runs is exclusively: SBOM generation (syft), vulnerability scan (Trivy), and/or branding verification — no Docker build step executed. Signal: `job_name =~ ".*scan.*"` AND `ci_build_duration_seconds == 0` (or absent). The `ci_scan_duration_seconds{tool="syft|trivy"}` metrics are non-zero.

This class exists to isolate scan optimization work (bead `jj97.8`) from the build path. It is the only class where `ci_build_duration_seconds == 0` is expected and correct, not a pipeline error.

#### Reproducible setup

```bash
# Scan-only is not a state to "set up" — it is a job-level classification.
# The `Post-push OpenEdX Scan` and `Post-push MFE Scan` jobs in
# build-tutor-images.yml are always scan-only.

# To benchmark scan-only in isolation:
# 1. Trigger build-tutor-images.yml on a branch where the image digest
#    is already known (skip-build or use existing image input).
# 2. OR trigger only the scan jobs via workflow_dispatch if the workflow
#    supports an image-already-pushed mode.
# 3. Measure ci_scan_duration_seconds{tool="syft"} and
#    ci_scan_duration_seconds{tool="trivy"} independently.

# Current observed timings (issue #1776 analysis):
# - Branding verify: ~470s (8 min)  — target: <5s (artifact reuse)
# - SBOM (syft):     ~394s (7 min)  — target: ~100s (local image vs registry)
# - Trivy:           ~246s (4 min)  — limited optimization headroom
```

#### What it tests

The scan pipeline in isolation from the build pipeline. Answers: how much of the observed wall-clock time is scan overhead? Is `jj97.8` optimization having an effect? What is the current vs target scan time contribution?

#### Expected timing band

| image_family | P50 | P95 | Notes |
|---|---|---|---|
| openedx | ~20 min current → ~5 min target | TBD | jj97.8 analysis; sum of syft + trivy + branding-verify |
| mfe | inherited from openedx scan pattern | TBD | Same toolchain, similar image size |

#### Anti-uses

- Do NOT include `scan-only` job timings in build-path SLOs — the scan runs asynchronously and does not gate promotion.
- Do NOT compare `scan-only` class timings across runner classes as a proxy for build performance — the scan is I/O and network bound, not compute bound.
- Do NOT treat SBOM hang (observed as situational on 2026-04-10 run 24225153401/24226466192) as representative of `scan-only` P50 — it is a P95+ tail event tied to anchore.io upstream latency.

---

## How classification is DERIVED (not labeled)

**Red line #4 from the program brief**: do not hand-label builds as "warm" or "cold" from vibes. Classification MUST be computed from raw signal metrics in Prometheus recording rules. No workflow step may emit `benchmark_class` as a hand-set string label — it is always a derived value.

The GitHub workflow still accepts an input named `benchmark_class`. Treat that
field as a requested precondition, not as final truth. The final observed class
must come from telemetry. In particular, the requested precondition
`benchmark_class=app-cache-cold` means app-level cache imports are disabled; the
observed metrics decide whether the run actually behaved like true-cold,
registry-warm, or local-hot.

The raw facts emitted per build:

```
ci_cache_source_found{source="registry|image|gha|local"}  # gauge: 1=found, 0=not found
ci_layer_reuse_count          # integer: layers reused
ci_layer_total_count          # integer: total layers in image
ci_build_duration_seconds     # 0 if no build step ran
ci_scan_duration_seconds{tool="syft|trivy"}
```

The derived layer reuse ratio is:

```
ci_layer_reuse_ratio = ci_layer_reuse_count / ci_layer_total_count
```

**Recording rule logic (PromQL pseudocode)**:

```promql
# observed true-cold: no successful cache import from any shared source
# AND <20% layer reuse
benchmark_class:true_cold =
  absent(ci_cache_source_found{source=~"registry|image"} == 1)
  and ci_layer_reuse_ratio < 0.20

# registry-warm: shared registry import succeeded AND 20-90% layer reuse
benchmark_class:registry_warm =
  ci_cache_source_found{source="registry"} == 1
  and ci_layer_reuse_ratio >= 0.20
  and ci_layer_reuse_ratio <= 0.90

# local-hot: >90% layer reuse (regardless of registry import)
benchmark_class:local_hot =
  ci_layer_reuse_ratio > 0.90

# scan-only: job name matches scan pattern AND build duration is zero
benchmark_class:scan_only =
  job_name =~ ".*scan.*"
  and ci_build_duration_seconds == 0
```

These recording rules live in `prometheus/ci_build_rules.yml` (vps-infrastructure repo, bead `jj97.3`). The `ci-build-overview` Grafana dashboard uses the derived label — never a raw string set by a workflow step.

**Precedence**: `local-hot` takes precedence over `registry-warm` (reuse ratio > 0.90 wins even if registry import also succeeded). `scan-only` is mutually exclusive with the build classes by definition.

---

## Controlled benchmark workflow

Bead `jj97.14` delivers `.github/workflows/build-benchmark.yml`. This workflow exists precisely so that classes can be compared under identical conditions.

**Workflow inputs** (`workflow_dispatch`):

| Input | Values | Purpose |
|---|---|---|
| `runner_class` | `fastlane` \| `arc-heavy` | Which runner pool to use |
| `benchmark_class` | `app-cache-cold` \| `true-cold` \| `registry-warm` \| `local-hot` \| `scan-only` | Requested cache precondition before the build; `true-cold` is a legacy alias for `app-cache-cold` |
| `image_family` | `openedx` \| `mfe` | Which image to build |

**How the workflow enforces conditions per class** (before invoking the actual build step):

- `app-cache-cold`: executes `docker buildx prune -af`, drops `CACHE_FROM_ARG` to empty string, renders Tutor build context with mirrored dependency pulls plus the explicit dependency-image mirror patch, configures the measured BuildKit builder with a Docker Hub registry mirror fallback, invokes no-cache bake targets through the canonical helpers, and fails the job if the measured build records `OUTCOME=failure`
- `true-cold`: legacy alias normalized to `proof_class=app-cache-cold` in artifacts and metadata
- `registry-warm`: executes `docker buildx prune -af` to remove L1, leaves `CACHE_FROM_ARG` pointing at the shared GHCR registry ref
- `local-hot`: no cache wipe; relies on persistent runner state; asserts `ci_layer_reuse_ratio > 0.90` post-build as a guard
- `scan-only`: skips build steps entirely; uses an already-pushed image digest as input

**Outputs** per run: a structured artifact containing
`requested_benchmark_class`, normalized `proof_class`, normalized
`benchmark_class`, `machine_cold_claim`, `runner_class`, `image_family`,
`release_unit_id`, and stage timings — importable by `jj97.10` baseline
collection. Consumers must not treat the requested `benchmark_class` field as
final observed cache truth.

---

## Comparing ARC vs fastlane fairly

The only valid comparisons are **same class, same image_family, different runner_class**:

```
Valid:   registry-warm / openedx / fastlane  vs  registry-warm / openedx / arc-heavy
Valid:   app-cache-cold / mfe / fastlane      vs  app-cache-cold / mfe / arc-heavy
Invalid: registry-warm / openedx / fastlane  vs  app-cache-cold / openedx / arc-heavy
Invalid: local-hot / mfe / fastlane          vs  registry-warm / mfe / arc-heavy
```

**Grafana filter pattern** for Row 4 (Runner Comparison) of `ci-build-overview`:

```
{benchmark_class="registry-warm", image_family="$image_family"}
| avg by (runner_class) [ci_build_duration_seconds]
```

The `benchmark_class` variable must be pinned, not left as "All", when comparing runner classes. The dashboard template variable for Row 4 will enforce this by making `benchmark_class` a required (non-All) filter in that row.

---

## Schedule

Benchmark runs on a weekly cron to produce trend baseline data in Prometheus:

```yaml
# Suggested schedule in build-benchmark.yml:
on:
  schedule:
    - cron: '0 6 * * 1'   # Monday 06:00 UTC — low-traffic window, before business hours
```

**Matrix**: `runner_class` × `benchmark_class` × `image_family`

| runner_class | benchmark_class | image_family | Est. duration |
|---|---|---|---|
| fastlane | app-cache-cold | openedx | 30–90 min |
| fastlane | app-cache-cold | mfe | ~44 min |
| fastlane | registry-warm | openedx | ~10 min |
| fastlane | registry-warm | mfe | ~5–8 min |
| fastlane | local-hot | openedx | ~2 min |
| fastlane | local-hot | mfe | ~5–8 min |
| arc-heavy | app-cache-cold | openedx | 30–90 min |
| arc-heavy | app-cache-cold | mfe | ~44 min |
| arc-heavy | registry-warm | openedx | ~10 min |
| arc-heavy | registry-warm | mfe | ~5–8 min |

**Budget estimate**: if run sequentially, the full matrix is approximately **5–7 hours** of wall-clock runner time per week. In practice, the app-cache-cold runs will not be scheduled weekly (too expensive) — they are run on demand when the cache-disabled helper baseline needs refreshing. The weekly cron runs only `registry-warm` and `scan-only` per image_family and runner_class, bringing the weekly budget to approximately **60–90 minutes**.

---

## Expected timing reference table

| image_family | class | P50 | P95 | source |
|---|---|---|---|---|
| openedx | app-cache-cold | 30–90 min | TBD (jj97.10) | no pristine daemon claim |
| openedx | registry-warm | <10 min target | TBD (jj97.10) | RFC DoD |
| openedx | local-hot | ~71s observed | TBD (jj97.10) | MEMORY ref, run 24226842382 |
| openedx | scan-only | ~20 min current → ~5 min target | TBD (jj97.10) | jj97.8 analysis |
| mfe | app-cache-cold | 44:12 (2652s) observed | TBD (jj97.10) | no pristine daemon claim |
| mfe | registry-warm | <5 min target | TBD (jj97.10) | RFC DoD |
| mfe | local-hot | 5–8 min observed | TBD (jj97.10) | MEMORY ref warm-path measurement |
| mfe | scan-only | inherited from openedx scan pattern | TBD (jj97.10) | Same toolchain |

TBD (jj97.10) entries are filled by the Phase 0 baseline capture (10 builds of pre-change evidence at `docs/ops/ci-cd/baseline-pre-cache-authority-2026-04-16.md`) and then updated by weekly benchmark runs once the controlled benchmark workflow (jj97.14) is operational.

---

## Anti-patterns

**DO NOT hand-set observed class labels.** The workflow may carry `benchmark_class` / `proof_class` as requested precondition annotations in JSON artifacts, but Prometheus cache classification is always derived from `ci_cache_source_found` and `ci_layer_reuse_ratio`. A dashboard or metrics exporter that treats `BENCHMARK_CLASS=registry-warm` as observed runtime truth is lying — it is asserting what it hopes happened, not what actually happened.

**DO NOT compare across classes without controlling.** An app-cache-cold ARC run vs a `local-hot` fastlane run tells you nothing about runner class performance. Before publishing any "ARC vs fastlane" number, verify that both runs share the same requested precondition and the same observed telemetry class in Grafana Row 4.

**DO NOT treat "warm" as one number.** `registry-warm` with 25% layer reuse and `registry-warm` with 89% layer reuse are both in the same class by definition, but their wall-clock times differ significantly. When reporting P50, include the layer reuse ratio distribution. When setting SLOs, use a specific layer reuse sub-band.

**DO NOT use scan-only timings in build SLOs.** Scan steps run asynchronously after image push and do not gate promotion. Including scan time in "build time" inflates the number and misattributes the bottleneck.

**DO NOT promote a `local-hot` observation as the warm-path SLO.** The 71-second OpenEdX build is a best-case `local-hot` result. The achievable steady-state target for most CI runs (which start without L1 cache) is the `registry-warm` P50 — currently <10 min target for OpenEdX, <5 min for MFE.

---

## References

- `docs/rfcs/RFC-BUILD-AUTHORITY-001.md` — authoritative design; section "Raw Telemetry, Derived Classification" defines four classes with thresholds
- `docs/rfcs/BUILD-AUTHORITY-SPRINT-AGENT-BRIEF.md` — section "PR 5 — Controlled benchmark lane" defines `runner_class`, `benchmark_class`, `image_family` workflow inputs
- Bead `jj97.13` — controlled benchmark classes implementation (blocked by this doc)
- Bead `jj97.14` — benchmark workflow `build-benchmark.yml` (blocked by this doc)
- Bead `jj97.15` — PR 1 foundation docs (this doc is one of five deliverables)
- Bead `jj97.10` — Phase 0 baseline capture; fills TBD P95 entries in this doc
- `docs/ops/ci-cd/CI_METRICS.md` (forthcoming, bead `jj97.11`) — authoritative metric name schema
- `docs/ops/ci-cd/BUILD_FAILURE_TAXONOMY.md` — how to classify failures observed during benchmarks
- MEMORY reference `reference-fastlane-speed-measurements.md` — source for all observed wall-clock numbers (run 24226842382, 2026-04-10)
