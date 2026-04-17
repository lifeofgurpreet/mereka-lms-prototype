# Agent Brief: Sprint — Shared Cache Authority + Build Telemetry

> **For**: Next implementation agent
> **Program lead**: Agent 1 (LMS app/runtime proof owner — stays in lane)
> **Agent role**: Dedicated build-substrate implementer
> **Created**: 2026-04-16
> **Epic**: `mereka-lms-jj97` (beads)
> **RFC**: `docs/rfcs/RFC-BUILD-AUTHORITY-001.md`
> **Spec**: `specs/build-authority-deterministic-builds_spec.md`

---

## Read Before You Start

1. `docs/rfcs/RFC-BUILD-AUTHORITY-001.md` — the authoritative design document
2. `docs/ops/ci-cd/BUILD_FAILURE_TAXONOMY.md` — how to classify every failure you observe
3. `docs/ops/ci-cd/AUTOMATION_AUTHORSHIP_AUDIT.md` — the token identity model
4. `docs/guides/CI_TOKENS_FOR_DEVELOPERS.md` — the canonical token pattern (GITHUB_TOKEN for GHCR, GitHub App for cross-repo)
5. `specs/build-authority-deterministic-builds_spec.md` — 7 requirements (R1-R7)
6. `~/infrastructure/observability/` specs SPEC-OBS-VPS-001 through 004 — existing stack contract
7. `bbi-infrastructure/docs/adr/004-ci-token-architecture.md` — token architecture decision
8. Epic comment on `mereka-lms-jj97` with acceptance criteria and red lines

Run `br show mereka-lms-jj97` and `br graph mereka-lms-jj97` to see the full dependency tree before you start.

---

## Your Mission

Make build performance and build cache **shared, observable, governed, non-tribal**.

Sprint succeeds when:

- A wiped runner is no longer a 60-90 minute surprise
- Future developers can answer: was this build cold or warm, which cache hit, was the bottleneck queue/build/SBOM/Trivy/promotion, was fastlane actually faster or just luckier
- `fastlane vs ARC` discussions are answered from data, not inference

You are NOT optimizing for "a faster-looking run." You are building the first-class substrate that lets the org answer these questions without folklore.

---

## Lane Boundaries (critical)

### You OWN

- `docker-bake.hcl` cache configuration
- `.github/workflows/build-tutor-images.yml` build steps (cache-from/to, metrics emission)
- `.github/actions/emit-build-metrics/` (new composite action)
- `scripts/ci/emit-build-metrics.sh` (new build-log parser)
- `scripts/qa/verify-build-workflow-contract.sh` (verifier updates)
- `docs/ops/ci-cd/CACHE_AUTHORITY.md` (new operator doc)
- `docs/ops/ci-cd/CI_METRICS.md` (new authoritative metric names list)
- `specs/build-authority-deterministic-builds_spec.md` updates
- Test fixtures for cache authority pattern

### You DO NOT OWN (stay out)

- Tenant runtime proof, cookie/auth, MFE config — that's Agent 1 (LMS app lane)
- GitOps overlays, DNS/TLS/Ingress, Argo apps — that's bbi-infrastructure
- Control-plane contracts — that's platform-control-plane
- Content migration (MCT, Kajabi, videos) — separate lane
- Open edX Django settings, plugin logic, MFE source — stay away
- Schema migrations — separate lane

If you find yourself editing `tutor_env/*`, `infrastructure/tutor/plugins/*`, `deploy/k8s/*`, `services/*`, or `apps/*` — **stop and emit a boundary report**.

### Cross-repo work

The **cache refs** live in GHCR:
`ghcr.io/biji-biji-initiative/mereka-lms/cache/openedx:main-amd64` and `mfe:main-amd64`

The **VPS observability stack** lives in `~/infrastructure/observability/` (dev) and `bbi-infrastructure/` (prod overlays). Any CI metrics that land in Prometheus/Grafana need PRs against the **vps infrastructure repo** — NOT this one.

The **webhook receiver** (`ci-metrics-receiver`) lives on the VPS — its code goes in `~/projects/vps/infrastructure/ci-metrics-receiver/`, not in this repo.

---

## Red Lines (from program brief — do NOT violate)

1. **Do not add a second observability island** beside existing Prometheus/Grafana/Tempo/Loki.
2. **Do not keep GHA cache and GHCR cache as co-equal primary authorities.** Pick one (GHCR registry).
3. **Do not compare ARC vs VPS without controlling for cache state.** Always filter by benchmark_class.
4. **Do not hand-label builds as "warm" or "cold" from vibes.** Classification must be DERIVED from raw facts.
5. **Do not let PR branches write to the shared main cache by default.** Workflow guard must enforce.
6. **Do not build a dashboard first and invent data semantics later.** Data model (jj97.9, jj97.11, jj97.13) lands before dashboard (jj97.4).

---

## PR Sequencing (strict — do not reorder)

### PR 1 — Foundation (bead `jj97.15`)

**Must land before any implementation PR.**

Deliverables:
- [ ] Extend `docs/rfcs/RFC-BUILD-AUTHORITY-001.md` if gaps found during implementation
- [x] Write `bbi-infrastructure/docs/adr/024-build-cache-authority.md` (parallel to ADR-004; filed as 024 not 005 — `005-auth-canonical-branch-and-ownership.md` already exists)
- [ ] Write `docs/ops/ci-cd/CI_METRICS.md` — authoritative list of metric names with label schema
- [ ] Write `docs/ops/ci-cd/CACHE_AUTHORITY.md` — operator runbook for cache refs, policy, failure modes
- [ ] Define benchmark class taxonomy in `docs/ops/ci-cd/BENCHMARK_CLASSES.md`
- [ ] Define `release_unit_id` schema (canonical: `source_sha` of the build commit; join across conveyor surfaces)

**Definition of done**:
- RFC + ADR + CI_METRICS.md + CACHE_AUTHORITY.md + BENCHMARK_CLASSES.md all exist, linked, consistent
- Team can read them as a package and agree on names before any code changes

### PR 2 — Cache authority in mereka-lms (bead `jj97.1` + `.10` + `.12`)

Deliverables:
- [ ] Phase 0: Capture baseline — 10 builds of pre-change evidence at `docs/ops/ci-cd/baseline-pre-cache-authority-2026-04-16.md` (`jj97.10`)
- [ ] Modify `docker-bake.hcl`:
  - `openedx-proof` target: `cache-from = [type=registry,ref=ghcr.io/.../cache/openedx:main-amd64, type=registry,ref=${OPENEDX_CACHE_REF}]`, `cache-to = [type=registry,ref=ghcr.io/.../cache/openedx:main-amd64,mode=max]`
  - Same for `mfe-proof`
- [ ] Modify `build-tutor-images.yml`:
  - `cache-to` only set when `github.ref == 'refs/heads/main' && github.event_name == 'push'`
  - Use `${{ secrets.GITHUB_TOKEN }}` for GHCR login (already done in mereka-lms#1779)
- [ ] Update `scripts/qa/verify-build-workflow-contract.sh` to assert:
  - cache-from includes shared registry ref
  - cache-to only set on trusted main
  - no type=gha in heavy targets
- [ ] Add fixture tests (`tests/` or equivalent) proving the guards work
- [ ] Write cache governance doc and proof contract (`jj97.12`)

**Definition of done**:
- Next 5 trusted main builds import shared registry cache successfully (verify via logs)
- Wiped fastlane runner (drop cache, rebuild) lands in "registry-warm" time — target <10min for OpenEdX, <5min for MFE
- A developer on their laptop can run `docker buildx build --cache-from=type=registry,ref=ghcr.io/.../cache/openedx:main-amd64` and get a warm build
- PR builds prove they did NOT write shared main cache (verify: no `cache-to` set on PR runs)
- Heavy image builds no longer depend on GHA cache as primary authority

### PR 3 — Minimal telemetry ingestion (beads `jj97.2` + `.11` + `.9`)

Deliverables (in `~/projects/vps/infrastructure/` — NOT this repo):
- [ ] Deploy `ci-metrics-receiver` FastAPI service (PM2-managed, port 9250)
- [ ] Webhook endpoint receives `workflow_run` + `workflow_job` events from GitHub
- [ ] Extracts: queue time, build time, scan time, runner class, conclusion
- [ ] Carries `release_unit_id = source_sha` as label on every metric
- [ ] Pushes to Prometheus via remote-write
- [ ] Add Caddy entry `ci-metrics.mereka.dev` → `localhost:9250`
- [ ] Configure GitHub webhook on `mereka-lms` repo

Deliverables in this repo (mereka-lms):
- [ ] `scripts/ci/emit-build-metrics.sh` — parses buildx log for layer-level detail
- [ ] `.github/actions/emit-build-metrics/action.yml` — composite action wrapping the script
- [ ] Modify `build-tutor-images.yml`: call `emit-build-metrics` after each build job's cache health check
- [ ] Raw telemetry schema documented in `docs/ops/ci-cd/CI_METRICS.md`

**Definition of done**:
- Every build emits metrics with `release_unit_id` label
- `release_unit_id` joins build → promotion → realization → runtime proof (query-able in Grafana)
- Classification (warm/cold/partial) is DERIVED from `cache_source_found` and `layer_reuse_ratio`, not stored as label
- Prometheus `sum(ci_build_duration_seconds) by (benchmark_class, runner_class)` works

### PR 4 — Grafana dashboard + alerts (beads `jj97.3` + `.4`)

Deliverables (in `~/projects/vps/infrastructure/` — NOT this repo):
- [ ] `prometheus/ci_build_rules.yml` — recording rules for P50/P95/success rate/cache hit rate
- [ ] `prometheus/ci_build_alerts.yml` — 4-6 alerts (cache misses, P95 breach, queue wait, chain broken, realization stuck)
- [ ] `grafana/dashboards/ci/ci-build-overview.json` — single pane of glass, 6 rows
- [ ] Fix Prometheus retention from 7d to 90d in docker-compose
- [ ] Add dashboard folder provider to grafana provisioning

**Definition of done**:
- One dashboard answers "where is the time going?" from scan of its panels
- Row 4 (runner comparison) filters by benchmark_class — never compares warm vs cold
- Alerts fire on real behavior change, not raw slowness
- Dashboard links to release_unit_id drill-down

### PR 5 — Controlled benchmark lane (bead `jj97.14`)

Deliverables:
- [ ] `.github/workflows/build-benchmark.yml` — manual `workflow_dispatch` + weekly schedule
- [ ] Inputs: `runner_class` (fastlane|arc-heavy), `benchmark_class` (true-cold|registry-warm|local-hot|scan-only)
- [ ] Sets up conditions explicitly (wipes local cache for true-cold, uses shared cache for registry-warm, etc.)
- [ ] Emits metrics with explicit `benchmark_class` label
- [ ] Produces evidence artifact comparing runs across classes

**Definition of done**:
- ARC vs fastlane comparison can be run by invoking the same benchmark_class on both
- Weekly schedule produces trend data in Prometheus
- Results visible in Grafana dashboard

---

## Parallel Workstreams (not PR-sequenced)

### `jj97.6` — Token consolidation (GHCR part done, App scope remaining)

This is shared with bbi-infrastructure. Already partially complete:
- ✅ `reusable-build-push.yml` uses GITHUB_TOKEN (bbi-infrastructure#2996)
- ✅ `build-tutor-images.yml` uses GITHUB_TOKEN (mereka-lms#1779)
- ⏳ Add `packages:write` to GitHub App so pull-secret sync can retire `ORG_GHCR_TOKEN`
- ⏳ Migrate `sync-ghcr-shared-pull-secrets.sh` to App token
- ⏳ Revoke `ORG_GHCR_TOKEN` PAT entirely

Coordinate with infra team (bbi-infrastructure#2993).

### `jj97.7` — Buildx cleanup automation

On VPS fastlane runner (vmi3220759):
- [ ] Post-job hook to prune stale buildx builder containers
- [ ] Guard Docker socket permissions (chmod 666 check on daemon restart)
- [ ] Monitor buildx container count, alert if > 5

### `jj97.8` — Scan optimization (3 fat steps, 63% of pipeline)

Issue #1776 already has full analysis:

1. **Branding verify** (470s, 8min): Replace docker pull of 5GB image with layer-extract for `staticfiles.json`, OR have build job upload it as artifact. Target: 470s → ~5s.
2. **SBOM generation** (394s, 7min): Change `syft scan registry:...` to `syft scan docker:...` to reuse local cache. Target: 394s → ~100s.
3. **Trivy scan** (246s, 4min): Limited room, bound by image size + CVE DB download.

Combined: ~20min scan drops to ~5min.

### `jj97.5` — In-workflow OTLP layer detail (blocked on `.2`)

Composite action parses buildx log for layer-level cache detail, pushes OTLP metrics to VPS OTel Collector. Deep Docker layer visibility that webhooks cannot provide.

---

## Operational Guardrails

### Before any implementation

1. Read the RFC and spec end-to-end
2. Run `br ready` to see available beads
3. Claim your bead: `br claim <bead-id>` (sets owner=your-name, status=in_progress)
4. Check `br show <bead-id>` for full context

### During implementation

1. Measure before you change — capture Phase 0 baseline per `jj97.10`
2. Update all of: bake config + workflow verifier + fixtures + docs + dashboard docs (proof governance per `jj97.12`)
3. Test locally against `tutor images build` before pushing
4. Check `docs/ops/ci-cd/BUILD_FAILURE_TAXONOMY.md` when builds fail — classify the failure bucket first
5. Use `gh run watch` or the monitor tool for CI observation — don't poll

### Before committing

1. Run `python3 scripts/governance/generate-ci-static-inventory.py --check`
2. Run `agent-verify --quick` or stack-specific tests
3. Verify workflow YAML parses: `python3 -c "import yaml; yaml.safe_load(open('.github/workflows/build-tutor-images.yml'))"`
4. Run `ubs` on changed files

### Commit discipline

- Small focused commits, one concern per commit
- Conventional Commits format (`fix(ci):`, `feat(cache):`, `docs(rfc):`)
- Reference bead ID in commit body (`Bead: mereka-lms-jj97.1`)
- Co-author: `Co-Authored-By: Claude <noreply@anthropic.com>`

### After landing a PR

1. Update the bead: `br update <bead-id> --status completed`
2. `br sync --flush-only --force` to persist to JSONL
3. Commit the `.beads/` changes
4. Check downstream beads are unblocked: `br ready`

---

## Acceptance Criteria (from program brief — ALL must be true at sprint end)

- [ ] Heavy builds use shared registry cache as primary shared authority
- [ ] PRs read the shared cache but do NOT write the shared main cache
- [ ] Release-unit IDs join build → promotion → realization → runtime
- [ ] Controlled benchmark classes exist and are machine-readable
- [ ] A dashboard shows build health and cache health in one place
- [ ] Alerts exist for cache breakage and stage regressions
- [ ] The next "fastlane vs ARC" discussion can be answered from data, not inference

---

## What I (Agent 1) Will NOT Do

I am the LMS app/runtime proof owner. I will:

- Write and evolve the RFC/spec
- Review your PRs from the app-lane perspective (cache correctness, no app regressions)
- Keep the epic and beads current with feedback
- Coordinate with infra team on cross-repo pieces
- File follow-up beads if you discover new failure classes

I will NOT:

- Implement the cache code myself
- Deploy the webhook receiver
- Write the Grafana dashboard JSON
- Run benchmark workflows

You have full ownership of the implementation. Ping me with questions or for RFC clarifications only.

---

## Handoff Checklist

Before starting, confirm:

- [ ] You can access GHCR (test: `docker pull ghcr.io/biji-biji-initiative/mereka-lms/openedx:mereka-brand`)
- [ ] You can SSH to VPS runner (`root@100.68.111.80` via Tailscale)
- [ ] You have `br` (beads CLI) and `gh` authenticated
- [ ] You can reach Prometheus (`https://prometheus.mereka.dev`) and Grafana
- [ ] You have read the 8 reference documents listed at the top

Ready to start? First bead is `jj97.15` (the RFC+ADR+data model foundation). It blocks everything else. Get that landed first.

---

**Sprint end state**: Make builds shared, measurable, and boring. Once that lands, the sprint after that can make a much smarter decision about widening fastlane, optimizing SBOM/Trivy, comparing ARC vs VPS fairly, and pushing into deeper build-authority cleanup.
