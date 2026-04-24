---
id: SPEC-BUILD-AUTHORITY
title: Build Authority and Deterministic Build Truth
status: draft
spec_class: domain
owner: platform-ci
created: 2026-04-16
last_reviewed: 2026-04-21
review_due: 2026-07-16
domain: platform
normativity: normative
depends_on:
  - ci-cd-pipeline_spec
supersedes: []
superseded_by: null
verification_sources:
  - .github/workflows/build-tutor-images.yml
  - .github/workflows/bootstrap-local-readiness.yml
  - .github/workflows/build-benchmark.yml
  - docs/ops/ci-cd/BUILD_FAILURE_TAXONOMY.md
  - docs/reference/contracts/DEVELOPER_ENVIRONMENT_PROOF_MATRIX.md
  - docs/ops/ci-cd/AUTOMATION_AUTHORSHIP_AUDIT.md
interfaces:
  - bbi-infrastructure promote-dev-image.yml
  - platform-control-plane contracts/
tags:
  - build
  - ci
  - deterministic
  - authority
summary: >
  Defines the single-owner model for how Open edX and MFE images are built,
  scanned, promoted, and proven. Every image-affecting change has one
  authoritative trigger path, one build owner, one promotion path, and one
  proof surface.
---

# Build Authority and Deterministic Build Truth

## Problem Statement

The release conveyor can be "correct" while the underlying build truth is
split across workflow YAML, build scripts, generated artifacts, trigger
filters, app/bot identity, runner topology, and scan/runtime proof surfaces.
That is too many quiet owners.

When a build fails, operators cannot quickly classify whether the failure is
a source defect, workflow contract defect, runner infrastructure defect, or
external platform defect. This ambiguity wastes hours on misdiagnosis.

## Scope

This spec covers the two primary images built in this repository:

1. **OpenEdX image** (`ghcr.io/biji-biji-initiative/mereka-lms/openedx`)
2. **MFE image** (`ghcr.io/biji-biji-initiative/mereka-lms/mfe`)

It does NOT cover enterprise MFE images (separate workflow) or purchase-gateway
(separate workflow).

## Requirements

### R1: Trigger Completeness

Every file that affects image build output MUST be in the `on.push.paths`
trigger list of `build-tutor-images.yml`.

**Verification**: `scripts/qa/verify-build-workflow-contract.sh` checks
the trigger structure today; comprehensive completeness check
(`verify-build-trigger-completeness.sh`) is planned per
`docs/rfcs/RFC-BUILD-AUTHORITY-001.md` Phase 1.

**Current state**: 44 watched paths. No known image-content gaps after
2026-04-16 cleanup (removed duplicates, added `select-build-lane` action).

### R2: No Duplicate Trigger Entries

The `on.push.paths` list MUST NOT contain duplicate entries.

**Verification**: Parse YAML, check `len(paths) == len(set(paths))`.

### R3: Automation PR Authorship

Every automation flow that creates PRs in repositories with required status
checks MUST use a GitHub App token (not `GITHUB_TOKEN` or
`github-actions[bot]`) so that `pull_request` event checks attach naturally.

**Flows in scope**:
- Dev promotion dispatch (build-tutor-images.yml -> bbi-infrastructure)
- Any future automation that creates PRs

**Verification**: After each graduation test cycle, confirm PR author is the
GitHub App identity by checking `gh pr view --json author`.

### R4: Failure Classification

Every build failure MUST be classifiable into exactly one of four buckets
within 5 minutes of observing the failure:

1. **Source defect** — code/config in repo is wrong
2. **Workflow contract defect** — CI YAML/scripts have logic error
3. **Runner infrastructure defect** — Docker/buildx/disk/network on runner
4. **External platform defect** — GitHub/GHCR/CDN degradation

**Verification**: `docs/ops/ci-cd/BUILD_FAILURE_TAXONOMY.md` provides the
decision tree. Operator can follow it mechanically.

### R5: Cold-Proof Class Honesty

Every build or bootstrap proof MUST name its cache and state class. A proof
MUST NOT be called pristine, machine-cold, or true cold unless the runner has a
fresh Docker daemon state, no pre-existing base images, no app-level BuildKit
cache imports, no runner-local layer cache, and a clean repo-scoped `TUTOR_ROOT`.

Supported proof classes:

| Class | What is disabled or reset | What may still exist | Verification |
|---|---|---|---|
| `app-cache-cold` image build | app-level BuildKit cache imports | persistent runner Docker daemon state, base images, registry mirror state | `build-benchmark.yml` with `benchmark_class=app-cache-cold`, `image_family=both` |
| clean local bootstrap | repo-scoped `TUTOR_ROOT` | prebuilt or pulled images; dependency mirrors | `bootstrap-local-readiness.yml` plus `scripts/infra/verify-local-bootstrap-readiness.sh` |
| registry-warm build | none; intentionally imports durable registry cache | GHCR BuildKit cache and optional runner-local cache | `build-tutor-images.yml` or benchmark registry-warm proof |
| machine-cold/pristine daemon | all app-level, runner-local, and daemon/base-image state | only network/package registry state | not currently a supported CI proof class |

**Verification**: `docs/reference/contracts/DEVELOPER_ENVIRONMENT_PROOF_MATRIX.md`
is the canonical lane matrix. The latest accepted app-cache-cold image-build
proof is run `24721668598` on `39ae0fb86`. The last accepted clean-bootstrap
baseline is run `24711453019` on `e7a4472cd`; current-main bootstrap rerun
`24730265503` on `12db1b6` is green as initialized-state proof after the
fastlane runner repair. That proof does not cover MFE authn route HTTP status
or branded theme asset presence when the bootstrap lane uses upstream images.
PR #1991 branch proof `24738471266` passed on `878994d0c` after run
`24736358890` was cancelled during active migrations and rerun `24737898005`
exposed stale `tutor_local` Docker project state left on the persistent runner.
The cleanup for that state is runner-proof hygiene, not a second build
authority. The green proof still showed about 56 minutes inside
`tutor local launch -I --skip-build`; future proof-lane work should make that
duration visible with phase timing and heartbeat artifacts.

**Current state**: app-cache-cold image proof and clean local bootstrap proof
are implemented classes. A pristine machine-cold proof remains a future explicit
lane, not something implied by existing fastlane or ARC runs.

### R6: Build Timing Governance

Each build step MUST have a measured baseline time and an alert threshold.

| Step | Warm Baseline | Cold Baseline | Alert Threshold |
|------|--------------|---------------|-----------------|
| Pre-build (checkout, setup) | 73s | 73s | 120s |
| OpenEdX image build | 71s (cache hit) | ~30min | 45min |
| MFE image build | 107s (cache hit) | ~44min | 60min |
| Post-push OpenEdX scan | ~5min | ~8min | 15min |
| Post-push MFE scan | ~2min | ~3min | 5min |
| Release bundle generation | ~10s | ~10s | 60s |
| Dispatch + infra PR | ~30s | ~30s | 120s |

**Verification**: Timing data emitted to `var/ci/build-*-timing.env` and
reported in GitHub step summary.

### R7: Single Build Owner

Each image build behavior MUST have exactly one authoritative source:

| Behavior | Owner |
|----------|-------|
| OpenEdX Dockerfile content | `infrastructure/tutor/plugins/mereka_lms.py` + Tutor hooks |
| MFE Dockerfile content | `infrastructure/tutor/plugins/_mereka_lms/mfe_dockerfile.py` + Tutor hooks |
| Patch application | `infrastructure/tutor/apply-patches.sh` |
| Build orchestration | `.github/workflows/build-tutor-images.yml` |
| Runner selection | `.github/actions/select-build-lane/action.yml` |
| Release object schema | `scripts/release/release_object_bindings.py` |
| Promotion dispatch envelope | `scripts/release/emit-proof-envelope.sh` |
| Scan behavior | `scripts/infra/install-trivy.sh` + workflow inline steps |
| Pre-checkout generated workspace cleanup | CI workflow cleanup steps bounded to generated paths only |

No hidden or duplicate ownership.

## Non-goals

- Replacing GitHub Actions as the CI orchestrator
- Building a custom CI scheduler or runner manager
- Optimizing individual Docker layers beyond what shared cache provides
- Touching enterprise MFE or purchase-gateway build workflows (separate scope)
- Optimizing GitHub-hosted runner cost (we run on self-hosted)
- Replacing the existing observability stack (Prometheus/Grafana/Tempo/Loki)
- Defining runtime proof or promotion contracts (owned by platform-control-plane)

## Out of Scope (Future Specs)

- Runner economics and lane governance (depends on build timing data)
- Staging rehearsal (depends on proven dev conveyor)
- Production readiness (depends on staging rehearsal)
- Enterprise MFE build authority (separate workflow, separate spec)

## Acceptance Criteria

This spec is satisfied when ALL of:

- [ ] AC-BAUTH-001: Every image-affecting file has an explicit conveyor trigger (R1)
- [ ] AC-BAUTH-002: No duplicate trigger entries exist (R2)
- [ ] AC-BAUTH-003: Automation PR authorship is consistent and trusted (R3)
- [ ] AC-BAUTH-004: Build failures can be classified in under 5 minutes (R4)
- [x] AC-BAUTH-005: Cold-proof work has a design stub or first implemented slice (R5)
- [ ] AC-BAUTH-006: Timing baselines are measured and documented (R6)
- [ ] AC-BAUTH-007: Build ownership is single-source for each behavior (R7)
- [ ] AC-BAUTH-008: The team can explain the build system without branch archaeology
- [ ] AC-BAUTH-009: `verify-build-workflow-contract.sh` and `verify-red-line-contract.sh` pass on `main`
- [ ] AC-BAUTH-010: Heavy image builds use shared registry cache as primary authority

### Verification Status

This table classifies the current proof mapping. "Mapped" means the AC has a
real verifier, workflow proof, monitoring source, or manual procedure in
`specs/_generated/testmaps/build-authority-deterministic-builds_spec.testmap.yml`.
It does not convert an unchecked AC into a completed one.

| AC | Status | Current proof mapping |
|---|---|---|
| AC-BAUTH-001 | Partial | `verify-build-workflow-contract.sh` enforces the known build path set; comprehensive image-affecting file discovery remains deferred to the trigger-completeness verifier planned in RFC Phase 1. |
| AC-BAUTH-002 | Mapped | `verify-build-workflow-contract.sh` rejects duplicate `build-tutor-images.yml` push path entries. |
| AC-BAUTH-003 | Partial | `verify-build-workflow-contract.sh` proves GitHub App token wiring; live downstream PR authorship remains a manual proof in `AUTOMATION_AUTHORSHIP_AUDIT.md`. |
| AC-BAUTH-004 | Manual | `BUILD_FAILURE_TAXONOMY.md` is the operator procedure; time-to-classification is proved during real failed-build triage. |
| AC-BAUTH-005 | Mapped | `verify-ci-cache-policy.sh` and `verify-cold-start-onboarding-contract.sh` prove the implemented proof-class slice. |
| AC-BAUTH-006 | Partial | `verify-build-workflow-contract.sh` proves timing artifacts are emitted; telemetry ingestion/dashboard closure remains tracked separately. |
| AC-BAUTH-007 | Mapped | `verify-build-workflow-contract.sh`, `verify-red-line-contract.sh`, and `verify-build-optimizations-render-delta-contract.sh` guard owner boundaries. |
| AC-BAUTH-008 | Partial | `verify-cold-start-onboarding-contract.sh`, the render-delta contract, and `CACHE_AUTHORITY.md` keep the explanation path current; onboarding feedback remains the human proof. |
| AC-BAUTH-009 | Mapped | `verify-build-workflow-contract.sh` and `verify-red-line-contract.sh` are both explicit verifier entries. |
| AC-BAUTH-010 | Mapped | `verify-ci-cache-policy.sh` and `verify-red-line-contract.sh` prove shared registry cache is the primary heavy-build authority. |

## Edge Cases

- **Workflow_dispatch on main with no source changes**: must still produce a release object that is byte-identical to the prior push-driven build for the same SHA.
- **Cache import 404 on a fresh trusted-main build**: build must proceed with empty cache and produce a valid manifest, populating the shared cache for the next run.
- **GHCR rate-limit during cache export**: build outcome must be `success` (build itself worked); cache-export-failure surfaces as a separate metric and alert, not a build failure.
- **Concurrent main pushes**: GitHub Actions concurrency group must serialize cache-writing builds; cache export from the older run must not overwrite a newer manifest.
- **Runner cleanup mid-build**: a runner pruned during build (buildx daemon restart) must fail fast with a recognizable error class (Runner infrastructure defect, R4 bucket 3) — not a silent corruption.
- **Forked PR**: must read shared cache (public read) and never write (enforced by GitHub fork-secret policy).

## Observability

- All metrics carry `release_unit_id = source_sha` per `docs/ops/ci-cd/CI_METRICS.md`
- Single dashboard `ci-build-overview` (six rows) is the operator surface — see RFC-BUILD-AUTHORITY-001 §Dashboard
- Alerts: `CICacheImportFailing`, `CICacheExportFailing`, `CIBuildP95Breach`, `CIQueueP95Breach`, `CIPromotionStuck`, `CIRealizationStuck`, `CIRuntimeProofRedAfterRealization`
- Cache health: `ci_cache_source_found`, `ci_cache_export_success`, `ci_layer_reuse_count` / `ci_layer_total_count`
- Failure classification follows `docs/ops/ci-cd/BUILD_FAILURE_TAXONOMY.md` (4 buckets)

## Rollout & Rollback

**Rollout** (per RFC-BUILD-AUTHORITY-001 phases):

1. Phase 0 — Baseline capture (jj97.10) — DONE 2026-04-16
2. Phase 1 — Shared registry cache for OpenEdX + MFE (jj97.1)
3. Phase 2 — Telemetry ingestion (jj97.2, jj97.11)
4. Phase 3 — Dashboard + alerts (jj97.3, jj97.4)
5. Phase 4 — Developer consumption (jj97.20)
6. Phase 5 — Retire L3 fallback (after 30d stable)

**Rollback**: each phase is independently revertable via PR revert. Cache changes (Phase 1) leave shared cache refs in place even after revert — no destructive cleanup needed; old refs become inert. Dashboard/alerts (Phase 3) are infrastructure-repo PRs; revert restores prior state without affecting builds.

## Open Questions

- OQ-1 — `ci_realization_duration_seconds` source: which Argo webhook endpoint emits the realization timestamp? (Resolve before jj97.3 alert PromQL.)
- OQ-2 — `ci_promotion_duration_seconds` timer boundary: clock starts at workflow completion or dispatch call? (Resolve before alert calibration.)
- OQ-3 — workflow_dispatch escape hatch for forced cache write: deliberate input `force_cache_write: bool` gated by actor check, or rely on empty-commit pattern?
- OQ-4 — L3 `OPENEDX_CACHE_REF` default in `docker-bake.hcl` points at upstream Overhangio image, not Mereka — update or remove after PR 2.
- OQ-5 — PR-scoped cache TTL mechanism: GHCR package retention, scheduled cleanup workflow, or manual?
- OQ-6 — GHCR 429 retry semantics for `cache-to`: confirm buildkit's behavior under registry rate-limit on push.
- OQ-7 — `local-hot` vs `registry-warm` precedence when both L1 and L2 succeed: precedence order should be `scan-only` > `local-hot` > `registry-warm` > `app-cache-cold` (proposed).
- OQ-8 — `partial-warm` from RFC §Derived Classification: dashboard-only diagnostic class, not a `benchmark_class` workflow input value.
