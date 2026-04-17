---
id: CI-METRICS-001
status: draft
created: 2026-04-16
epic: mereka-lms-jj97
spec: specs/build-authority-deterministic-builds_spec.md
rfc: docs/rfcs/RFC-BUILD-AUTHORITY-001.md
---

# CI_METRICS — Authoritative Metric Name List

> This is the single source of truth for every Prometheus metric emitted by the
> `ci-metrics-receiver` webhook service and the `emit-build-metrics` composite
> action. No metric name may be introduced in a workflow, recording rule, alert,
> or dashboard that is not listed here first. To add a metric, update this doc and
> raise a PR against bead `jj97.11`.

---

## 1. Naming Convention

| Rule | Detail |
|------|--------|
| **Prefix** | All CI metrics MUST begin with `ci_` |
| **Case** | `snake_case` throughout — no hyphens, no dots |
| **Unit suffix** | `_seconds` for durations, `_total` for monotonically-increasing counters, `_info` for static metadata labels |
| **No unit** | Gauges that are dimensionless ratios or counts carry no suffix |
| **Time unit** | Seconds always. Do NOT use `_ms`, `_ns`, or `_minutes` suffixes. |
| **Histogram buckets** | All histogram metrics MUST define explicit buckets in the receiver. Default Prometheus buckets (.005 …10) are not appropriate for build durations that range from 30s to 6000s. |
| **Cardinality** | Labels that could produce >10k series (e.g. raw commit SHAs used as label values) MUST NOT be added as labels. Carry them in `_info` metrics only. |

Correct examples: `ci_build_duration_seconds`, `ci_cache_source_found`, `ci_build_outcome_total`

Wrong examples: `ci-build-duration`, `build_seconds`, `ci_build_duration_ms`, `ci_build_warm`

---

## 2. Required Labels on Every Metric

Every metric emitted by any source in this system MUST carry the following labels.
Absence of a required label makes the metric unroutable in recording rules and
alerts, breaking the classification and join model.

| Label | Type | Justification |
|-------|------|---------------|
| `release_unit_id` | `string` (SHA-7 or full commit SHA) | The join key. Joins build → promotion → realization → runtime proof. Without it, dashboard rows cannot be correlated. |
| `runner_class` | `enum`: `fastlane \| arc-heavy \| arc-standard \| github-hosted` | Runner class must be a first-class dimension so row 4 of the dashboard can control for cache state before comparing classes. |
| `image_family` | `enum`: `openedx \| mfe` | Durations, reuse ratios, and cache hit rates differ by order of magnitude between OpenEdX (~30-90 min cold) and MFE (~15-20 min cold). Mixing them in one histogram obscures the signal. |
| `workflow_run_id` | `string` (GitHub Actions run ID) | Secondary join key. Allows a Grafana panel to link out to the exact GitHub run without any other context. Also used by `ci_release_unit_info` to map SHA → run. |

Additional per-metric labels are defined in the catalog below. Labels in the catalog are
additive — they layer on top of the four required labels, not replace them.

---

## 3. Metric Catalog

### 3.1 Duration Histograms

These are the primary signal metrics. All are histograms, not gauges, because P50/P95 are
the operationally useful aggregations. See Section 6 for recording rules that pre-compute them.

| Name | Type | Additional Labels | Source | Example PromQL |
|------|------|-------------------|--------|----------------|
| `ci_queue_duration_seconds` | histogram | — | webhook (`workflow_run`) | `histogram_quantile(0.95, sum(rate(ci_queue_duration_seconds_bucket[1h])) by (le, runner_class))` |
| `ci_build_duration_seconds` | histogram | `build_target` (e.g. `openedx-proof`, `mfe-proof`) | webhook + buildx-meta | `histogram_quantile(0.95, sum(rate(ci_build_duration_seconds_bucket[24h])) by (le, image_family, runner_class))` |
| `ci_scan_duration_seconds` | histogram | `tool` (`syft \| trivy`) | webhook (`workflow_job`) | `histogram_quantile(0.95, sum(rate(ci_scan_duration_seconds_bucket[24h])) by (le, tool, image_family))` |
| `ci_promotion_duration_seconds` | histogram | — | webhook (`workflow_run` cross-repo dispatch completion) | `histogram_quantile(0.95, sum(rate(ci_promotion_duration_seconds_bucket[24h])) by (le, image_family))` |
| `ci_realization_duration_seconds` | histogram | — | Argo webhook or runtime-proof surface (reuse existing conveyor) | `histogram_quantile(0.95, sum(rate(ci_realization_duration_seconds_bucket[24h])) by (le))` |

**Histogram bucket recommendation** (override Prometheus defaults):

```yaml
# For queue (30s–600s range)
buckets: [30, 60, 90, 120, 180, 300, 600]
# For build (60s–6000s range)
buckets: [60, 120, 300, 600, 900, 1800, 3600, 6000]
# For scan (30s–900s range)
buckets: [30, 60, 120, 180, 300, 600, 900]
# For promotion/realization (60s–1800s range)
buckets: [60, 120, 300, 600, 900, 1800]
```

---

### 3.2 Cache Fact Metrics

These store raw facts only. Warm/cold/partial classification MUST NOT be stored here.
See Section 6 for the recording rules that derive classification from these facts.

| Name | Type | Additional Labels | Source | Notes |
|------|------|-------------------|--------|-------|
| `ci_cache_source_found` | gauge | `source` (`registry \| image \| gha \| local`) | buildlog / buildx-meta | Value `1` = manifest found before build started; `0` = not found. One series per `source` value per build. |
| `ci_cache_manifest_digest_imported` | info | `digest` (image manifest SHA256) | buildx-meta `cache-from` result | Carries the exact manifest SHA that was imported. Value always `1` when present, absent when no import occurred. |
| `ci_cache_manifest_digest_exported` | info | `digest` (image manifest SHA256) | buildx-meta `cache-to` result | Carries the exact manifest SHA written. Absent on non-trusted builds (PRs). |
| `ci_cache_export_success` | gauge | — | buildlog | `1` = `cache-to` completed without error on a trusted main build; `0` = export attempted but failed. Absent on non-trusted builds. |
| `ci_layer_reuse_count` | gauge | — | buildlog parser (`emit-build-metrics.sh`) | Count of layers resolved from cache (not rebuilt). |
| `ci_layer_total_count` | gauge | — | buildlog parser | Total layer count in this build. Layer reuse ratio = `ci_layer_reuse_count / ci_layer_total_count`. |

---

### 3.3 Identity / Metadata Metrics

These are `_info` style (value always `1`; data carried in labels). They exist so that
PromQL `* on(release_unit_id) group_left(source_sha, source_ref) ci_release_unit_info` can
join rich context onto any numeric metric without blowing up cardinality in the numeric series.

| Name | Type | Labels Carried | Source | Notes |
|------|------|----------------|--------|-------|
| `ci_runner_class` | info | `runner_class`, `runner_name` | webhook (`workflow_job`) | One series per job. `runner_class` is the normalized enum; `runner_name` is the raw GitHub label. Value `1`. |
| `ci_release_unit_info` | info | `source_sha`, `source_ref`, `openedx_digest`, `mfe_digest` | webhook (`workflow_run`) + buildx-meta | Joins the human-readable context (branch, full SHA, image digests) onto numeric metrics via `release_unit_id`. Do NOT put `source_sha` or `openedx_digest` as labels on the duration histograms. |

---

### 3.4 Outcome Counter

| Name | Type | Additional Labels | Source | Example PromQL |
|------|------|-------------------|--------|----------------|
| `ci_build_outcome_total` | counter | `conclusion` (`success \| failure \| cancelled \| timed_out`) | webhook (`workflow_run`) | `sum(rate(ci_build_outcome_total{conclusion="failure"}[7d])) by (image_family)` |

---

## 4. Webhook Event Schema

The `ci-metrics-receiver` FastAPI service (VPS, port 9250) receives GitHub webhook
`workflow_run` and `workflow_job` events and emits one Prometheus metric push per event.

### 4.1 Ingestion Contract

The receiver normalizes the raw GitHub event into an internal event object before emitting
metrics. The shape below is what the receiver stores/forwards — not the raw GitHub payload.

```json
{
  "schema_version": "ci-event/v1",
  "event_type": "workflow_run",
  "release_unit_id": "74a1998d6",
  "workflow_run_id": "24491141960",
  "job_name": "build-openedx",
  "image_digest": "sha256:abc123def456...",
  "cache_sources": [
    "type=registry,ref=ghcr.io/biji-biji-initiative/mereka-lms/cache/openedx:main-amd64",
    "type=registry,ref=ghcr.io/biji-biji-initiative/mereka-lms/openedx:mereka-brand"
  ],
  "cache_export": "type=registry,ref=ghcr.io/biji-biji-initiative/mereka-lms/cache/openedx:main-amd64,mode=max",
  "runner_class": "fastlane",
  "queue_duration": 12.4,
  "build_duration": 421.7,
  "scan_duration": 394.0,
  "outcome": "success"
}
```

### 4.2 Field Definitions

| Field | Type | Notes |
|-------|------|-------|
| `schema_version` | `"ci-event/v1"` | Fixed; bump minor on backwards-compatible addition, major on breaking change |
| `event_type` | `"workflow_run" \| "workflow_job"` | Maps to the GitHub event that triggered this record |
| `release_unit_id` | string | `source_sha` (the commit SHA that triggered the build); used as primary join key on all emitted metrics |
| `workflow_run_id` | string | GitHub Actions `run.id` — secondary key for linking to the UI |
| `job_name` | string | Raw GitHub job name (e.g. `build-openedx`, `scan-openedx-image`) |
| `image_digest` | string | OCI manifest digest of the built/scanned image; `null` on non-image jobs |
| `cache_sources` | ordered array of strings | All `cache-from` refs in evaluation order (first = highest priority). Order is significant — used to classify registry vs fallback hit. |
| `cache_export` | string | The `cache-to` ref, or `null` when this was a non-trusted build (PR, fork) |
| `runner_class` | `"fastlane" \| "arc-heavy" \| "arc-standard" \| "github-hosted"` | Normalized from GitHub runner label |
| `queue_duration` | float (seconds) | Seconds from `workflow.created_at` to `workflow.run_started_at` |
| `build_duration` | float (seconds) | Seconds from job start to job completion (Docker build steps only, when isolable) |
| `scan_duration` | float (seconds) | Duration of SBOM/Trivy scan steps; `null` if this event is not a scan job |
| `outcome` | `"success" \| "failure" \| "cancelled" \| "timed_out"` | Normalized from GitHub `conclusion` |

### 4.3 Example: successful registry-warm OpenEdX build

```json
{
  "schema_version": "ci-event/v1",
  "event_type": "workflow_run",
  "release_unit_id": "74a1998d6",
  "workflow_run_id": "24491141960",
  "job_name": "build-openedx",
  "image_digest": "sha256:dfbe7ef31806...",
  "cache_sources": [
    "type=registry,ref=ghcr.io/biji-biji-initiative/mereka-lms/cache/openedx:main-amd64",
    "type=registry,ref=ghcr.io/biji-biji-initiative/mereka-lms/openedx:mereka-brand"
  ],
  "cache_export": "type=registry,ref=ghcr.io/biji-biji-initiative/mereka-lms/cache/openedx:main-amd64,mode=max",
  "runner_class": "fastlane",
  "queue_duration": 12.4,
  "build_duration": 421.7,
  "scan_duration": 394.0,
  "outcome": "success"
}
```

---

## 5. Alert Names

Full PromQL expressions and `for:` durations live in `prometheus/ci_build_alerts.yml`
(bead `jj97.3`, vps-infrastructure repo). This section defines the canonical alert
names so that dashboards, runbooks, and Slack notifications refer to consistent identifiers.

| Alert Name | One-line Trigger |
|------------|-----------------|
| `CICacheImportFailing` | 3 consecutive trusted-main builds where `ci_cache_source_found{source="registry"} == 0` for the same `image_family` |
| `CICacheExportFailing` | `ci_cache_export_success == 0` on a trusted-main build (i.e. a main-branch push that attempted `cache-to` but reported failure) |
| `CIBuildP95Breach` | `ci_build_duration_seconds` P95 (by `image_family`, `runner_class`) exceeds 1.5× the rolling 7-day P95 baseline for that combination |
| `CIQueueP95Breach` | `ci_queue_duration_seconds` P95 exceeds 1.5× the rolling 7-day P95 baseline |
| `CIPromotionStuck` | Same `release_unit_id` has `ci_build_outcome_total{conclusion="success"}` > 0 but `ci_promotion_duration_seconds` has no observation after 30 minutes (cross-repo dispatch likely failed) |
| `CIRealizationStuck` | `ci_promotion_duration_seconds` has an observation (promotion succeeded) but `ci_realization_duration_seconds` has no observation for the same `release_unit_id` after 15 minutes |
| `CIRuntimeProofRedAfterRealization` | `ci_realization_duration_seconds` has an observation for a `release_unit_id` but the corresponding runtime proof (existing conveyor surface) is in a failed state |

**Failure bucket mapping** (for triage, per `BUILD_FAILURE_TAXONOMY.md`):

| Alert | Expected bucket |
|-------|----------------|
| `CICacheImportFailing` | Bucket 3 (runner/infra) or Bucket 4 (GHCR platform) |
| `CICacheExportFailing` | Bucket 3 or Bucket 4 |
| `CIBuildP95Breach` | Bucket 1 (source) or Bucket 3 (infra regression) |
| `CIQueueP95Breach` | Bucket 3 (runner concurrency/scaling) |
| `CIPromotionStuck` | Bucket 2 (workflow contract) or Bucket 4 (GitHub API) |
| `CIRealizationStuck` | Outside CI lane — Argo/GitOps issue in bbi-infrastructure |
| `CIRuntimeProofRedAfterRealization` | Outside CI lane — App regression (LMS lane) |

---

## 6. Derived Metrics (Recording Rules — NOT Raw)

Classification of a build as warm, cold, or partial MUST be derived via Prometheus recording
rules from the raw fact metrics. It MUST NOT be stored as a label on any raw metric.

Recording rules live in `prometheus/ci_build_rules.yml` (bead `jj97.3`, vps-infrastructure repo).
This section defines the thresholds and derivation logic.

### 6.1 Layer Reuse Ratio

```promql
# recording rule name: ci:layer_reuse_ratio
ci_layer_reuse_count / ci_layer_total_count
```

This is a dimensionless gauge between 0 and 1. It is the raw input to classification.

### 6.2 Classification Thresholds (from RFC §"Raw Telemetry, Derived Classification")

| Class | Condition | Raw facts used |
|-------|-----------|---------------|
| `fully_cold` | `ci_cache_source_found{source="registry"} == 0` AND `ci:layer_reuse_ratio < 0.20` | No shared manifest found, fewer than 20% of layers came from any cache |
| `registry_warm` | `ci_cache_source_found{source="registry"} == 1` AND `ci:layer_reuse_ratio >= 0.20` AND `ci:layer_reuse_ratio <= 0.90` | Shared registry manifest found, 20–90% layer reuse |
| `locally_hot` | `ci:layer_reuse_ratio > 0.90` | >90% layer reuse (L1 local cache, or exact rebuild) |
| `partial_warm` | Any multi-image or multi-stage build where one component is `registry_warm` and another is `fully_cold`, OR build is warm but scan stage has no cache benefit | Heterogeneous cache state across jobs in the same `workflow_run_id` |

### 6.3 Derived Recording Rule Names

These are the recording rule names that the dashboard and alert rules consume. They are
pre-aggregated rates, not raw metric names, and belong in `prometheus/ci_build_rules.yml`.

| Recording Rule Name | Definition |
|--------------------|-----------|
| `ci:build_p50_seconds` | `histogram_quantile(0.50, sum(rate(ci_build_duration_seconds_bucket[1h])) by (le, image_family, runner_class))` |
| `ci:build_p95_seconds` | `histogram_quantile(0.95, ...)` same shape |
| `ci:queue_p95_seconds` | `histogram_quantile(0.95, sum(rate(ci_queue_duration_seconds_bucket[1h])) by (le, runner_class))` |
| `ci:cache_hit_rate` | `sum(ci_cache_source_found{source="registry"} == 1) by (image_family) / sum(ci_cache_source_found{source="registry"}) by (image_family)` |
| `ci:layer_reuse_ratio` | `ci_layer_reuse_count / ci_layer_total_count` |
| `ci:build_success_rate` | `sum(rate(ci_build_outcome_total{conclusion="success"}[24h])) by (image_family) / sum(rate(ci_build_outcome_total[24h])) by (image_family)` |

**Hard rule**: Do not add `benchmark_class` or `warm` / `cold` / `partial` as a label to any
raw metric time series. These are recording-rule outputs that are queried, not ingested.

---

## 7. Anti-Patterns

These are explicitly forbidden. Any PR that introduces one of these patterns must be rejected.

| Anti-pattern | Why forbidden |
|-------------|---------------|
| Storing `warm`/`cold`/`partial` as a label on a raw metric | Violates RFC §Anti-Goals. Classification is derived, not hand-labeled. |
| Inventing a metric name not in this doc | Creates an untracked parallel observability surface. Update this doc first. |
| Emitting the same logical metric with different label sets from different sources | Creates join impossibility. One metric, one label set, one source. |
| Using `_ms` or `_ns` suffix | Prometheus convention is seconds. Consumers must not have to convert. |
| Using raw GitHub commit SHA as a label (not `release_unit_id` shortform) | High cardinality destroys TSDB performance. SHA goes in `ci_release_unit_info` only. |
| Comparing `ci_build_duration_seconds` across `runner_class` without filtering by `ci:layer_reuse_ratio` class | Compares warm vs cold, not fastlane vs ARC. Always filter by classification first. |
| Adding `cache-from` or `cache-to` status as labels on `ci_build_duration_seconds` | That's what `ci_cache_source_found` and `ci_cache_export_success` are for. Separate concerns. |
| Creating a second Prometheus / Pushgateway / InfluxDB instance for CI metrics | Violates RFC §Non-Goals. All CI metrics go through the existing VPS stack. |
| Setting `status: active` on this doc before all metrics in the catalog have a real emitter | The catalog is the contract; it must not be declared active before implementation. |

---

## 8. References

| Document | Location | Purpose |
|----------|----------|---------|
| RFC-BUILD-AUTHORITY-001 | `docs/rfcs/RFC-BUILD-AUTHORITY-001.md` | Authoritative design — read before implementing |
| Agent Brief (sprint) | `docs/rfcs/BUILD-AUTHORITY-SPRINT-AGENT-BRIEF.md` | PR sequencing, acceptance criteria, lane boundaries |
| Build Failure Taxonomy | `docs/ops/ci-cd/BUILD_FAILURE_TAXONOMY.md` | Four buckets for classifying failures; alert triage mapping |
| Cache Authority Runbook | `docs/ops/ci-cd/CACHE_AUTHORITY.md` | Cache ref naming, write policy, failure modes (bead `jj97.12`) |
| Benchmark Classes | `docs/ops/ci-cd/BENCHMARK_CLASSES.md` | `benchmark_class` taxonomy and controlled run protocol (bead `jj97.15`) |
| Build Authority Spec | `specs/build-authority-deterministic-builds_spec.md` | R1–R7 requirements the metrics must satisfy |
| SPEC-OBS-VPS-001 | `~/infrastructure/observability/SPEC-OBS-VPS-001-alerts.md` | Alerting infrastructure this doc's alerts extend |
| SPEC-OBS-VPS-004 | `~/infrastructure/observability/SPEC-OBS-VPS-004-app-instrumentation-contract.md` | App instrumentation contract; `ci_*` namespace does not conflict |
| Epic `mereka-lms-jj97` | beads (run `br show mereka-lms-jj97`) | Full dependency tree and acceptance criteria |

---

## 9. Open Questions

These are gaps found during doc authorship that require resolution before bead `jj97.2`
can declare `ci_realization_duration_seconds` and `CIRealizationStuck` fully implemented.

| # | Question | Blocking |
|---|----------|---------|
| OQ-1 | `ci_realization_duration_seconds` source is listed as "Argo webhook or runtime-proof surface (reuse existing conveyor)" — the exact webhook endpoint or conveyor metric name in `bbi-infrastructure` is not specified in the RFC or brief. Which existing surface does this consume? | Needed before `CIRealizationStuck` alert PromQL can be written (bead `jj97.3`) |
| OQ-2 | `ci_promotion_duration_seconds` boundary: does the timer start at `workflow_run` completion of `build-tutor-images.yml`, or at the point the cross-repo dispatch call is made? The brief says "cross-repo dispatch completion" but the dispatch and the downstream PR merge are separate events. Clarify the start and end timestamps. | Needed before `CIPromotionStuck` alert threshold can be calibrated |
| OQ-3 | `ci_scan_duration_seconds` distinguishes `tool=syft` vs `tool=trivy` but the brief also mentions "branding verify" (470s, 8min) as a fat scan step. Should a third `tool=branding-verify` value be added, or is that tracked only via `ci_build_duration_seconds{build_target="verify-branding"}`? | Low — jj97.8 (scan optimization) can resolve, not blocking PR 1 |
| OQ-4 | `benchmark_class` label is referenced in the brief's recording-rule PromQL example (`sum(ci_build_duration_seconds) by (benchmark_class, runner_class)`) and in PR 5 deliverables, but this doc does not add `benchmark_class` as a required label because it only applies to benchmark workflow runs (PR 5, bead `jj97.14`). Confirm: `benchmark_class` is an _optional_ additional label present only on metrics emitted by `build-benchmark.yml`, absent on regular builds. | Confirm before `BENCHMARK_CLASSES.md` is authored |
