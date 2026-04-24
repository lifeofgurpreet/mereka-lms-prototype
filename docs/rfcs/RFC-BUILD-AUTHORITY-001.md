---
id: RFC-BUILD-AUTHORITY-001
title: Shared Build Cache and Build Observability as One Governed System
status: draft
authors: [platform-lead]
created: 2026-04-16
epic: mereka-lms-jj97
spec: specs/build-authority-deterministic-builds_spec.md
supersedes: []
---

# RFC-BUILD-AUTHORITY-001: Shared Build Cache and Build Observability

## Problem

Builds are slow and opaque. A wiped runner causes a catastrophe (90+ min cold
build) instead of an inconvenience. Cache, metrics, classification, and
release-unit tracking live in scattered places or don't exist. The result:

- Cold OpenEdX builds take 30-90+ minutes because GHA cache is effectively
  empty (12 buildkit blobs, only 64MB of real data against a 3-5GB target).
- "Warm build" and "cold build" are hand-labeled stories, not derived signals.
- There is no single ID that joins build → promotion → realization → runtime.
- Developers cannot benefit from CI's cache; they rebuild from scratch.
- Performance regressions are discovered via chat complaints, not alerts.
- Multiple competing cache authorities (type=gha, type=registry, local) with
  no governance.

This is not a performance project. It is a build-truth project.

## Goals

1. **Shared cache authority**: one governed shared cache source that VPS
   runners, ARC runners, and developer laptops all consume.
2. **Release-unit correlation**: one ID joins build, promotion, realization,
   and runtime proof without human reconstruction.
3. **Derived classification**: warm/cold/partial are computed from raw signals
   (cache manifest found, layer reuse ratio) not hand-entered labels.
4. **Single observability surface**: extend the existing
   Prometheus/Grafana/Tempo/Loki estate; do not create a parallel CI silo.
5. **Proactive alerting**: cache breakage, P95 breaches, and broken
   conveyor states fire before humans notice.
6. **Developer parity**: a developer on their laptop can pull the same
   shared cache CI uses and rebuild in the same warm time.

## Non-Goals

- Not replacing GitHub Actions.
- Not building a custom CI orchestrator.
- Not optimizing individual Docker layers beyond what cache provides.
- Not touching enterprise MFE or purchase-gateway builds in this RFC (separate
  workflows, separate scope).
- Not optimizing GitHub-hosted runner costs.

## Design

### Cache Authority Model (L1 / L2 / L3)

#### L1 — Runner-local cache (opportunistic)

Per-runner buildx / Docker daemon cache.

- **Usefulness**: fastest path on a warm fastlane runner
- **Limitations**: ephemeral on ARC, fragile on rebuilds/daemon resets
- **Treat as**: best-effort accelerator only, never authoritative

#### L2 — Shared registry cache (authoritative)

Dedicated GHCR cache refs, one per image family and platform:

```
ghcr.io/biji-biji-initiative/mereka-lms/cache/openedx:main-amd64
ghcr.io/biji-biji-initiative/mereka-lms/cache/mfe:main-amd64
```

Optional later (not in scope for PR 1):

```
ghcr.io/biji-biji-initiative/mereka-lms/cache/openedx:release-amd64
ghcr.io/biji-biji-initiative/mereka-lms/cache/mfe:release-amd64
ghcr.io/biji-biji-initiative/mereka-lms/cache/openedx:pr-<number>-amd64
```

#### L3 — Final-image fallback (transitional)

Keep `OPENEDX_CACHE_REF` and `MFE_CACHE_REF` (the `mereka-brand` tag) as
secondary import source during the transition. Retire in Phase 5.

### Cache Write Policy

**Trusted writes only:**

- `main` branch, `push` event, trusted workflow: `cache-to` enabled
- All other contexts: `cache-from` only, never `cache-to`
- Forks: never write shared cache (enforced by GitHub's fork secret policy)
- PRs: read-only by default

**Read for everyone:**

- fastlane runners: read
- ARC runners: read
- developer laptops: read
- trusted PR branches: read

**PR advanced mode (future):**

- same-repo trusted PRs may write ephemeral PR-scoped caches
  (`cache/openedx:pr-<number>-amd64`) with TTL cleanup
- forks never write

### Bake Config Shape

**First-class pattern:**

```hcl
target "openedx-proof" {
  cache-from = [
    "type=registry,ref=ghcr.io/biji-biji-initiative/mereka-lms/cache/openedx:main-amd64",
    "type=registry,ref=${OPENEDX_CACHE_REF}",  # fallback, transitional
  ]
  cache-to = [
    "type=registry,ref=ghcr.io/biji-biji-initiative/mereka-lms/cache/openedx:main-amd64,mode=max",
  ]
}
```

Same for `mfe-proof`.

**Workflow guard** — only trusted main builds set `cache-to`:

```yaml
- name: Build OpenEdX image
  env:
    # Only write to shared cache on trusted main builds
    CACHE_TO_ARG: ${{ github.ref == 'refs/heads/main' && github.event_name == 'push' && format('--cache-to=type=registry,ref={0}/cache/openedx:main-amd64,mode=max', env.REGISTRY) || '' }}
```

### Release-Unit Data Model

**Core join key**: `release_unit_id = source_sha` (or the canonical
release object source SHA when release objects are involved).

Every metric, trace, log line, dashboard row, and alert carries
`release_unit_id`. This allows one query to answer:

- How long did release unit X take to build?
- Did it hit shared cache?
- Which runner built it?
- Did promotion happen?
- Did Argo realize it?
- Did runtime proof pass?

Reuse existing promotion_record/release_object/runtime_proof surfaces.
Do NOT duplicate conveyor or runtime proof work.

### Raw Telemetry, Derived Classification

**Store as raw facts** (not labels):

- `ci_cache_source_found{source="registry|image|gha|local"}` (bool)
- `ci_cache_manifest_digest_imported`
- `ci_cache_manifest_digest_exported`
- `ci_layer_reuse_count` / `ci_layer_total_count`
- `ci_queue_duration_seconds`
- `ci_build_duration_seconds`
- `ci_scan_duration_seconds{tool="syft|trivy"}`
- `ci_runner_class` (fastlane/arc-heavy/arc-standard/github-hosted)
- `ci_release_unit_info{source_sha, ...}`

**Derived in Prometheus recording rules** (not stored as raw facts):

- **Fully cold**: no shared manifest found, layer reuse < 20%
- **Registry warm**: shared manifest found, layer reuse 20-90%
- **Locally hot**: local cache available, layer reuse > 90%
- **Partial warm**: one image warm + one cold, OR build warm + scan cold,
  OR build warm + promotion slow

### Observability Data Sources

1. **GitHub workflow events** (webhooks): queue time, start/end, outcome,
   runner class, retry count, concurrency cancellations.
2. **In-workflow build metadata**: buildx metadata file, cache refs, image
   digest, build duration.
3. **Build log parsing**: cache import/export success, layer reuse, SBOM/Trivy
   duration.
4. **Argo + runtime proof**: reuse existing conveyor/runtime proof surfaces.

### Dashboard: `ci-build-overview`

Six rows, one pane of glass:

| Row | Content |
|-----|---------|
| **1. Executive Health** | Latest release units, P50/P95 by stage, failure rate by stage, cache hit ratio by image |
| **2. Cache Truth** | Shared cache hit/miss trend, cache export success rate, layer reuse ratio, cache manifest age |
| **3. Stage Bottlenecks** | Queue vs build vs scan vs promotion vs realization (heatmap by runner class + image family) |
| **4. Runner Comparison** | Fastlane vs ARC — BUT only after controlling for cache class (registry-warm vs registry-warm, never warm vs cold) |
| **5. Conveyor State** | Artifact truth, promotion truth, realization truth, runtime truth by release unit |
| **6. Failure Analysis** | Classed failures over 7d/30d, new failure class detection |

### Alerts

Alert on broken system behavior, not raw slowness alone:

- 3 consecutive shared-cache misses on main
- shared-cache export failing on trusted main builds
- queue time above moving P95
- build duration above moving P95
- promotion stage failing for same class twice in a row
- release unit stuck between promotion and realization
- runtime proof red after successful realization

## Rollout Plan

### Phase 0 — Baseline and freeze the model

Before any cache changes:

- Capture last 10 successful builds with stage timings, queue times,
  per-image durations, cache source availability
- Store as `docs/ops/ci-cd/baseline-pre-cache-authority-2026-04-16.md`
- Define release_unit_id schema

Bead: `mereka-lms-jj97.10` (baseline), `mereka-lms-jj97.9` (release-unit model)

### Phase 1 — Shared registry cache for OpenEdX + MFE

- Change bake targets: add registry cache import/export
- Keep `OPENEDX_CACHE_REF`/`MFE_CACHE_REF` fallback temporarily
- Trusted main writes only; PRs read-only
- Update workflow contract verifier
- Update fixtures

Bead: `mereka-lms-jj97.1` (cache authority), `mereka-lms-jj97.12` (governance)

### Phase 2 — Minimal observability

- Raw telemetry schema in place
- Webhook receiver emitting release_unit_id
- Basic Prometheus scrape targets

Bead: `mereka-lms-jj97.11` (raw telemetry), `mereka-lms-jj97.2` (webhook)

### Phase 3 — Dashboard + alerts

- Single Grafana `ci-build-overview.json`
- 4-6 core alerts
- Recording rules for derived classifications

Bead: `mereka-lms-jj97.3` (rules), `mereka-lms-jj97.4` (dashboard)

### Phase 4 — Developer consumption

- Document `docker buildx build --cache-from=type=registry,...` for devs
- Optional developer helper target
- Clear rules on read vs write

Bead: TBD (part of docs update with Phase 1)

### Phase 5 — Retire or demote GHA cache

After registry cache proves stable over 30 days:

- Remove `type=gha` from heavy targets, OR
- Keep only for lightweight metadata/localized cases

Do not keep two competing cache authorities forever.

## Security and Governance

**Shared cache write controls:**

- Only trusted branches write shared cache (main)
- Forks never write shared cache (GitHub's fork secret policy handles this)
- Branch caches, if any, are ephemeral and isolated with TTL

**Retention:**

- Rolling main cache refs stay current (overwritten each build)
- Optional PR caches get TTL cleanup (30 days)
- Dashboard surfaces stale cache manifest age (alert if >24h without write)

**Proof governance (every cache-affecting change updates all of):**

- `docker-bake.hcl`
- `scripts/qa/verify-build-workflow-contract.sh`
- fixture tests
- `docs/ops/ci-cd/CACHE_AUTHORITY.md`
- dashboard docs if metric names change

## Anti-Goals

- Do NOT make GHA cache and GHCR cache both "primary"
- Do NOT let PRs write shared main cache by default
- Do NOT build a second CI observability stack outside the existing one
- Do NOT store hand-made "warm/cold" labels as truth
- Do NOT compare runner classes without controlling for cache class
- Do NOT optimize dashboards before the data model is right

## Acceptance Criteria (Definition of Done)

### Cache DoD

- Next 5 trusted main builds import shared registry cache successfully
- A wiped fastlane runner rebuilds in registry-warm time, not fully-cold
- A developer can consume the same shared cache locally
- Heavy image builds no longer depend on GHA cache as primary authority
- PR builds prove they did NOT write shared main cache

### Observability DoD

- One dashboard answers "where is the time going?"
- One release-unit ID joins build → promotion → realization → runtime
- Warm/cold/partial derived from real signals
- Cache breakage alerted before humans complain

### Codebase DoD

- Bake config, workflow contract, fixtures, docs, operator surfaces all agree
- No duplicate cache or observability authority remains
- RFC referenced from README and architecture docs

## Risks

| Risk | Mitigation |
|------|-----------|
| Registry cache push fails due to GHCR rate limits | Exponential backoff; fall back to `OPENEDX_CACHE_REF` for read-only; alert |
| Cache manifest grows unbounded | `mode=max` with GHCR package TTL; monitor size; prune old cache refs |
| PR writes pollute shared cache | Workflow-level guard: `cache-to` only set when `github.ref == 'refs/heads/main' && event_name == 'push'`; verifier checks this |
| Base image update invalidates cache silently | Docker content-addresses layers; invalid cache is automatically bypassed; no manual invalidation needed |
| Dev laptops can't reach GHCR from some networks | Document as known limitation; dev can still fall back to `tutor images build` without cache |
| New failure classes emerge | Failure taxonomy (bucket 1-4) is extensible; add bucket if pattern repeats 3+ times |

## What Merges First

1. **PR 1** — Cache authority: `docker-bake.hcl` registry cache + workflow
   guard + verifier + fixtures + docs (mereka-lms)
2. **PR 2** — Minimal build telemetry: workflow event ingestion +
   release_unit_id + basic Prometheus metrics (bbi-infrastructure or
   vps-infrastructure)
3. **PR 3** — Grafana dashboard + alerts (vps-infrastructure)
4. **PR 4** — Dev consumption docs (mereka-lms)

## References

- SPEC-BUILD-AUTHORITY (`specs/build-authority-deterministic-builds_spec.md`)
- BUILD_FAILURE_TAXONOMY (`docs/ops/ci-cd/BUILD_FAILURE_TAXONOMY.md`)
- AUTOMATION_AUTHORSHIP_AUDIT (`docs/ops/ci-cd/AUTOMATION_AUTHORSHIP_AUDIT.md`)
- CI_TOKENS_FOR_DEVELOPERS (`docs/guides/CI_TOKENS_FOR_DEVELOPERS.md`)
- ADR-004: CI Token Architecture (bbi-infrastructure)
- SPEC-OBS-VPS-001 through 004 (existing observability stack)
- Epic `mereka-lms-jj97`
- Issue mereka-lms#1780 (epic)
- Issue bbi-infrastructure#2993 (token consolidation)
- Issue mereka-lms#1776 (scan optimization)
- Issue mereka-lms#1778 (buildx cleanup)
