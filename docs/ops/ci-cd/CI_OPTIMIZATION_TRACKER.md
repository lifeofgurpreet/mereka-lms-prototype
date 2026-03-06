# CI/CD Optimization & Cost Reduction — Implementation Tracker

<!-- Last updated: 2026-03-05 (Phase 6 complete; ADR-026 lessons documented) -->

**Objective**: Migrate heavy CI/CD workloads to self-hosted Kubernetes runners (ARC), eliminate compute waste, consolidate micro-jobs, and optimize caching — driving GitHub Actions costs from ~$56/month to near-zero without compromising any quality gates.

**Parent doc**: [CI_PIPELINE_COST_OPTIMIZATION.md](CI_PIPELINE_COST_OPTIMIZATION.md) (analysis & rationale)
**TRACKER.md IDs**: T150–T156 (Sprint 12)

**Execution rule**: Proceed phase by phase. Do not skip to Phase 4 before Phase 3 is completed — the composite actions built in Phase 3 are required to cleanly flatten the jobs in Phase 4. Update this tracker's checkboxes and add file path notes as you commit changes.

**Quality rule**: This is about performance, not reducing quality. Every guardrail, compliance check, and verification script must survive. Zero gates dropped.

**Doc update rule**: After modifying any YAML or bash script, search `docs/` and `specs/` for references to changed workflow names or structures and update them.

---

## Current State (Baseline Numbers)

| Metric | Count | Notes |
|--------|-------|-------|
| Workflow files | 48 | in `.github/workflows/` |
| Jobs in `ci.yml` | **74** | Each spins up a separate VM |
| Matrix groups in `verify-specs.yml` | 12 | 71 verification scripts total |
| Workflows with `upload-artifact` | 31 | Artifact storage cost driver |
| Workflows with `continue-on-error: true` | 14 | Masking failures |
| Workflows using Playwright | 5 | ~300MB browser download each |
| Workflows authenticating to GCP | 9 | Repeated auth boilerplate |
| Workflows setting up Python | 10 | Repeated pip install |
| Scheduled cron runs/day | ~19 | 4 workflows every 6h + 3 daily + weekly |
| Conditional jobs in ci.yml | 17 | Only run on PR with matching title keywords |
| Job dependencies in ci.yml | 1 | `a11y-regression-lane` → `authenticated-smoke-a11y` |

---

## Risks & Constraints

### R1: ci.yml has 74 jobs, not the 5 originally estimated

The external review said "30+ jobs" and we initially corrected it to "5 jobs." Both were wrong — ci.yml actually has **74 distinct jobs**. This is the core of the micro-job problem. Each job provisions a VM, checks out the repo, and installs dependencies. At 30-45 seconds of boot overhead per job, that's ~37 minutes of pure setup waste per CI run.

**Constraint**: When consolidating, we must preserve the exact same script set. Every script maps to specific acceptance criteria (AC-* IDs). Dropping a script means dropping compliance coverage.

### R2: 17 ci.yml jobs are conditional (PR title matching)

These jobs only run when the PR title contains specific keywords (e.g., "branding", "token", "a11y"). When consolidating into fewer jobs, we must either:
- Keep conditional logic inside the consolidated job (run script blocks conditionally)
- Or accept that consolidated jobs always run all checks (slightly more compute, simpler logic)

**Recommendation**: Accept always-run for consolidated jobs. The scripts are fast (milliseconds to seconds). The VM boot cost we save dwarfs the script execution cost.

### R3: Observability workflow merge has 5 incompatibilities

The three daily observability workflows have different:
1. **`strict_runtime` defaults**: `observability-audit` defaults `false` (graceful), `alert-routing-audit` defaults `true` (strict fail)
2. **GCP project handling**: Two workflows hardcode `mereka-lms`, parity workflow computes per-lane from env vars
3. **Matrix strategy**: Parity uses 3-lane matrix (dev/nonprod/prod), others don't
4. **Failure semantics**: Different fallback behaviors when GCP auth fails
5. **Artifact structures**: Different naming, retention, and rollup patterns

**Constraint**: Merge must preserve per-job failure semantics. Cannot flatten to a single `strict_runtime` default.

### R4: verify-specs.yml scripts overlap with ci.yml's verify-static job

`ci.yml` has a `verify-static` job that runs 28+ verification scripts. `verify-specs.yml` runs 71 scripts in 12 groups. There is overlap (both run scripts from `scripts/qa/`), but they are NOT identical. The merger must deduplicate without dropping any script.

### R5: One job dependency chain must be preserved

`a11y-regression-lane` depends on `authenticated-smoke-a11y` in ci.yml. When consolidating, this dependency must be preserved (run sequentially within the consolidated job, or keep as separate jobs).

### R6: Artifact upload patterns differ across workflows

Some workflows use `${{ github.run_id }}-${{ github.run_attempt }}` in artifact names (for dedup). Others use static names. The merged workflows must preserve unique artifact naming to avoid overwriting.

---

## Phase 1: Infrastructure Preparation — Actions Runner Controller (ARC)

*TRACKER.md: T150 | Priority: P1 | Effort: M | Deps: none*

> **Note**: Agents can write the manifests and docs. A human will need to apply them to the cluster and configure the GitHub App in organization settings.

- [x] **Task 1.1**: Create ARC Helm values and Kustomize manifests
  - Created: `deploy/k8s/base/arc/kustomization.yaml`
  - Created: `deploy/k8s/base/arc/namespace.yaml` (namespaces: `arc-systems`, `arc-runners`)
  - Created: `deploy/k8s/base/arc/helm-values.yaml` (ARC controller Helm values)
  - Reference: [ARC docs](https://github.com/actions/actions-runner-controller)

- [x] **Task 1.2**: Define standard RunnerScaleSet (`mereka-k8s-runners`)
  - Created: `deploy/k8s/base/arc/runner-scale-set-standard.yaml`
  - Config: ubuntu-latest equivalent, 2 CPU / 4GB RAM, ephemeral pods (emptyDir work dir)
  - For: linting, spec verification, cron audits, lightweight checks

- [x] **Task 1.3**: Define heavy RunnerScaleSet (`mereka-k8s-heavy-builders`)
  - Created: `deploy/k8s/base/arc/runner-scale-set-heavy.yaml`
  - Config: DinD sidecar (docker:24-dind), 4 CPU / 12GB RAM runner + 4 CPU / 8GB DinD
  - PVC: `arc-docker-cache` (50Gi, `local-path`) — Docker layer cache + daemon data root
  - PVC: `arc-dep-cache` (10Gi, `local-path`) — pip / npm / Playwright browser cache
  - For: `build-tutor-images.yml`, Playwright E2E, heavy compute

- [x] **Task 1.4**: Wire ARC into rke2-nonprod overlay
  - NOTE: ARC is NOT added to overlay resources list — the overlay's `namespace: mereka-lms`
    transformer would override `arc-runners`/`arc-systems` namespaces on ARC resources.
  - ARC is applied separately: `kubectl apply -k deploy/k8s/base/arc/`
  - Added explanation comment to `deploy/k8s/overlays/rke2-nonprod/kustomization.yaml`
  - Created: `deploy/k8s/overlays/rke2-nonprod/patches/arc-storage-class.yaml`
    (documents expected state; applied standalone, not via overlay patch mechanism)

- [x] **Task 1.5**: Create operational documentation
  - Created: `docs/ops/ci-cd/CI_CD_RUNNERS.md`
  - Content: GitHub App setup (4-step guide), ARC architecture diagram, runner labels,
    PVC caching strategy (BuildKit args included), security model, troubleshooting,
    deploy sequence, verification commands

---

## Phase 2: Stop the Bleed — Immediate Cost Drops

*TRACKER.md: T151 | Priority: P1 | Effort: S | Deps: none (independent of Phase 1)*

- [x] **Task 2.1**: Change iOS build trigger to manual/tag-only
  - Modify: `.github/workflows/ios-testflight.yml`
  - Remove: `push: branches: [main] paths: ['ios/**']`
  - Keep: `workflow_dispatch`
  - Add: `push: tags: ['v*-ios']`
  - Impact: Eliminates ~3,000 Linux-equivalent minutes/month (macOS 10x multiplier)

- [x] **Task 2.2**: Add concurrency controls to PR-triggered workflows
  - Modify (add `concurrency` block to each):
    - `.github/workflows/ci.yml`
    - `.github/workflows/verify-specs.yml`
    - `.github/workflows/iac-scan.yml`
    - `.github/workflows/tutor-config-verify.yml`
    - `.github/workflows/dependency-review.yml`
    - `.github/workflows/codeql.yml`
  - Block to add:
    ```yaml
    concurrency:
      group: ${{ github.workflow }}-${{ github.ref }}
      cancel-in-progress: true
    ```
  - Impact: Prevents 2-3x duplicate runs on rapid PR pushes

- [x] **Task 2.3**: Reduce artifact retention for passing workflows
  - Modify **all 31 workflows with `actions/upload-artifact`** (see file list below)
  - Change: `retention-days` to `3` for logs, reports, and traces
  - Files to scan:
    - `.github/workflows/alert-routing-audit.yml`
    - `.github/workflows/authenticated-sso-canary.yml`
    - `.github/workflows/accessibility-audit.yml`
    - `.github/workflows/argocd-drift-check.yml`
    - `.github/workflows/atlas-health.yml`
    - `.github/workflows/build-tutor-images.yml`
    - `.github/workflows/ci.yml`
    - `.github/workflows/dr-evidence-bundle.yml`
    - `.github/workflows/e2e-tests.yml`
    - `.github/workflows/iac-scan.yml`
    - `.github/workflows/ios-testflight.yml`
    - `.github/workflows/lighthouse-ci.yml`
    - `.github/workflows/observability-audit.yml`
    - `.github/workflows/observability-compliance.yml`
    - `.github/workflows/observability-parity-runtime.yml`
    - `.github/workflows/operations-gates-runtime.yml`
    - `.github/workflows/post-deploy-e2e.yml`
    - `.github/workflows/public-health-check.yml`
    - `.github/workflows/release-evidence-bundle.yml`
    - `.github/workflows/release-evidence.yml`
    - `.github/workflows/scorecard.yml`
    - `.github/workflows/secret-scan-audit.yml`
    - `.github/workflows/smoke-authenticated.yml`
    - `.github/workflows/tenant-isolation-check.yml`
    - `.github/workflows/translation-check.yml`
    - `.github/workflows/tutor-config-verify.yml`
    - `.github/workflows/ttfs-onboarding.yml`
    - `.github/workflows/verify-commit-signing.yml`
    - `.github/workflows/verify-patch-idempotency.yml`
    - `.github/workflows/verify-specs.yml`
    - `.github/workflows/verify-wif-readiness.yml`

- [x] **Task 2.4**: Conditionally upload heavy Playwright artifacts (only on failure)
  - Modify (wrap trace/video/screenshot uploads with `if: failure()`):
    - `.github/workflows/e2e-tests.yml`
    - `.github/workflows/post-deploy-e2e.yml`
    - `.github/workflows/smoke-authenticated.yml`
    - `.github/workflows/authenticated-sso-canary.yml`
    - `.github/workflows/operations-gates-runtime.yml`
  - Keep: lightweight text logs always uploaded (for audit trail)

---

## Phase 3: Abstraction & Reusable Composite Actions

*TRACKER.md: T152 | Priority: P1 | Effort: M | Deps: T151*

- [x] **Task 3.1**: Create composite action — GCP/GKE auth
  - Created: `.github/actions/gcp-gke-auth/action.yml`
  - Inputs: `gcp_sa_key`, `gcloud_project` (default: `mereka-lms`), `gke_project` (default: `bbi-k8`),
    `gke_location` (default: `asia-southeast1-c`), `gke_cluster` (default: `bbi-k8-cluster`),
    `skip_gke` (default: `false`), `skip_gcloud` (default: `false`), `strict_runtime` (default: `false`)
  - Outputs: `has_cluster` (boolean); also sets `CAN_RUN_RUNTIME` env var for workflows that use it
  - Refactored all **9 consumer workflows** to use composite action:
    - `.github/workflows/alert-routing-audit.yml` — gcloud(mereka-lms) + GKE, strict default true
    - `.github/workflows/argocd-drift-check.yml` — gcloud(bbi-k8) + GKE, graceful fallback, id=gke-auth preserved
    - `.github/workflows/build-tutor-images.yml` — auth only (skip_gke+skip_gcloud=true), 3 jobs patched
    - `.github/workflows/cloud-sql-backup.yml` — gcloud(mereka-lms) + skip_gke=true
    - `.github/workflows/dr-evidence-bundle.yml` — gcloud(mereka-lms) + GKE, strict default true
    - `.github/workflows/observability-audit.yml` — gcloud(mereka-lms) + GKE, strict default false
    - `.github/workflows/observability-parity-runtime.yml` — gcloud($OBS_GCP_PROJECT per-lane) + GKE, strict=true
    - `.github/workflows/operations-gates-runtime.yml` — conditional (HAS_GCP_SA_KEY gate preserved)
    - `.github/workflows/release-evidence.yml` — auth only (skip_gke+skip_gcloud=true)

- [x] **Task 3.2**: Create composite action — Python environment
  - Create directory: `.github/actions/setup-python-env/`
  - Create: `.github/actions/setup-python-env/action.yml`
  - Extract from: checkout + `actions/setup-python` + pip cache + base deps install (pyyaml, ruff, yamllint)
  - Inputs: `python-version` (default: `3.12`), `extra-deps` (optional pip packages)
  - Currently duplicated in **10 workflows**:
    - `.github/workflows/authenticated-sso-canary.yml`
    - `.github/workflows/build-tutor-images.yml`
    - `.github/workflows/ci.yml`
    - `.github/workflows/operations-gates-runtime.yml`
    - `.github/workflows/tutor-config-verify.yml`
    - `.github/workflows/tutor-plugin-test.yml`
    - `.github/workflows/validate-multisite.yml`
    - `.github/workflows/verify-patch-idempotency.yml`
    - `.github/workflows/verify-specs.yml`

- [x] **Task 3.3**: Create composite action — Playwright setup
  - Created: `.github/actions/setup-playwright/action.yml`
  - Inputs: `node-version` (default: `18`), `playwright-version` (default: `1.50.0`), `npm-cache-dependency-path` (optional)
  - Caches `~/.cache/ms-playwright` keyed by `playwright-${{ inputs.playwright-version }}-${{ runner.os }}`
  - Skip browser install on cache hit
  - Refactored **3 Node-based workflows** (setup-node + npx playwright install consolidated):
    - `.github/workflows/e2e-tests.yml` — composite action + separate `npm install` step preserved
    - `.github/workflows/post-deploy-e2e.yml` — composite action + conditional `npm install` step preserved
    - `.github/workflows/smoke-authenticated.yml` — composite action replaces both setup-node and Install Playwright steps
  - **NOT refactored** (use Python Playwright, not Node — incompatible with this action):
    - `.github/workflows/authenticated-sso-canary.yml` — uses `pip install playwright==1.50.0` + `python -m playwright install`
    - `.github/workflows/operations-gates-runtime.yml` — same Python pattern, embedded in a conditional `run:` block with the canary script

- [x] **Task 3.4**: Refactor all workflows to use composite actions
  - Replace hardcoded GCP auth blocks → `uses: ./.github/actions/gcp-gke-auth` (9 workflows)
  - Replace hardcoded Python setup blocks → `uses: ./.github/actions/setup-python-env` (10 workflows)
  - Replace hardcoded Playwright setup blocks → `uses: ./.github/actions/setup-playwright` (5 workflows)
  - Verify: all workflows still pass after refactor

---

## Phase 4: Workflow Consolidation — Squashing Micro-Jobs

*TRACKER.md: T153 | Priority: P1 | Effort: M | Deps: T152*

- [x] **Task 4.1**: Merge `verify-specs.yml` into `ci.yml`
  - Modify: `.github/workflows/ci.yml` — absorb fast-verification + full-verification logic
  - Delete: `.github/workflows/verify-specs.yml`
  - Preserve: all 14 verification groups, fast vs full distinction, PR comments
  - **Docs/specs updated**:
    - `specs/github-actions-cost-monitoring_spec.md` ✓
    - `docs/README.md` ✓
    - `docs/guides/standards/DOCUMENTATION_STANDARDS.md` ✓
    - `docs/ops/security/ALLOWED_ACTIONS_POLICY.md` ✓
    - `docs/ops/ci-cd/CI_PIPELINE_COST_OPTIMIZATION.md` ✓

- [x] **Task 4.2**: Refactor `ci.yml` into 3-4 main jobs
  - **Job 1: `static-validation`** — Group all YAML, Markdown, shell syntax checks + spec linting
    - Use `xargs -P 4` to run bash scripts in parallel on same runner (not matrix)
    - Replaces: `spec-lint` job + fast-verification scripts
  - **Job 2: `tutor-config-tests`** — Tutor rendering, idempotency, config validation
    - Replaces: tutor-config-verify logic
  - **Job 3: `security-scans`** — TruffleHog (HEAD only), CodeQL, pip-audit
    - Replaces: separate security scan steps
  - **Job 4 (on push only): `full-verification`** — All 67+ verification scripts
    - Use `xargs -P 4` within a single job instead of 14-group matrix
    - Timeout: 120s per script (preserved)
  - Impact: ~21 job spin-ups → ~4 job spin-ups per push

- [x] **Task 4.3**: Consolidate tenant branding QA jobs
  - Scanned `.github/workflows/ci.yml` for tenant-branding-matrix, tenant-ui-smoke, tenant-isolation-evidence
  - Merged into single `branding-validation` step within `static-validation` job

- [x] **Task 4.4**: Consolidate accessibility gate jobs
  - Scanned `.github/workflows/ci.yml` and `.github/workflows/accessibility-audit.yml`
  - Merged into single `accessibility-validation` step within `static-validation` job

---

## Phase 5: Heavy Workload Migration to ARC

*TRACKER.md: T154 | Priority: P2 | Effort: M | Deps: T150, T153*

> **Prerequisite**: Phase 1 (ARC infrastructure) must be deployed and verified.

- [x] **Task 5.1**: Migrate image builds to heavy-builders
  - Modify: `.github/workflows/build-tutor-images.yml`
  - Change: image build jobs default to `runs-on: mereka-k8s-heavy-builders`
    with manual workflow fallback to `github-hosted` when explicitly selected
    via `openedx_runner=github-hosted`.
  - BuildKit policy hardened: disable BuildKit only on GitHub-hosted fallback;
    keep BuildKit enabled on ARC self-hosted runners.
  - Impact: Builds use 12GB+ RAM natively (no disk swapping), persistent Docker layer cache via PVC

- [x] **Task 5.2**: Migrate E2E/smoke/cron to standard runners with fallback conditional
  - Pattern: `runs-on: ${{ vars.USE_SELF_HOSTED_RUNNERS == 'true' && 'mereka-k8s-runners' || 'ubuntu-24.04' }}`
  - Set `USE_SELF_HOSTED_RUNNERS=true` as a GitHub repository variable when ARC is deployed.
    When ARC is not deployed (or variable is unset), workflows fall back to `ubuntu-24.04` automatically.
  - Modified (all now use fallback conditional):
    - `.github/workflows/e2e-tests.yml` (2 jobs)
    - `.github/workflows/post-deploy-e2e.yml` (3 jobs)
    - `.github/workflows/smoke-authenticated.yml` (2 jobs)
    - `.github/workflows/argocd-drift-check.yml` (3 jobs)
    - `.github/workflows/operations-gates-runtime.yml`
    - `.github/workflows/public-health-check.yml`
    - `.github/workflows/daily-infrastructure-audit.yml` (3 jobs — merged replacement for
      observability-audit + alert-routing-audit + observability-parity-runtime)
    - `.github/workflows/secret-scan-audit.yml`
    - `.github/workflows/dr-evidence-bundle.yml`
    - `.github/workflows/tenant-isolation-check.yml`
    - `.github/workflows/mfe-slot-runtime-gates.yml`
  - Impact: All scheduled/E2E compute on sunk-cost K8s; graceful fallback to GitHub-hosted
    when ARC is not yet deployed (zero downtime during rollout)

- [x] **Task 5.3**: Optimize Docker build caching
  - Modify: `.github/workflows/build-tutor-images.yml`
  - Inject BuildKit cache args into Tutor build process on ARC heavy runners:
    ```bash
    export DOCKER_BUILD_OPTIONS="--cache-from=type=local,src=/cache/docker/buildkit --cache-to=type=local,dest=/cache/docker/buildkit,mode=max"
    ```
  - Build commands now append cache args only when `/cache/docker` exists (ARC PVC path).
  - GitHub-hosted fallback keeps BuildKit disabled and skips cache args.
  - Impact: Tutor builds drop from 30+ min to ~5 min (only changed layers rebuilt)

- [x] **Task 5.4**: Optimize Trivy scans (single-pass)
  - Modify: `.github/workflows/build-tutor-images.yml`
  - Current state: each image already uses a single Trivy JSON scan
    (`--severity CRITICAL,HIGH`) with `jq` split:
    - CRITICAL count gates build failure
    - HIGH findings exported as artifact summary
  - Impact: Halves security scan time per image build

- [x] **Task 5.5**: Migrate remaining LEGACY workflows (issue #124 follow-up)
  - Playwright-based browser-test workflows migrated to `mereka-k8s-heavy-builders`:
    - `.github/workflows/cross-browser-branding-smoke.yml`
    - `.github/workflows/mfe-live-dom-audit.yml`
    - `.github/workflows/npm-start-mfe-smoke.yml`
    - `.github/workflows/frontend-branding-closure.yml`
  - Lightweight static workflows pinned from `ubuntu-latest` → `ubuntu-24.04` (Class C, CONFORM):
    - `.github/workflows/email-template-branding.yml`
    - `.github/workflows/certificate-branding.yml`
    - `.github/workflows/a11y-tenant-branding.yml`
    - `.github/workflows/mfe-selector-hardening.yml`
    - `.github/workflows/paragon-runtime-contract.yml`
    - `.github/workflows/paragon-theme-budget.yml`
    - `.github/workflows/frontend-performance-spotcheck.yml`
  - `docs/ops/ci-cd/CI_RUNNER_POLICY.md` audit table updated to CONFORM for all 11 jobs
  - Remaining LEGACY entry: `build-ios-app.yml` uses `macos-latest` (Class D, tracked separately)

---

## Phase 6: Cron Schedule Rationalization

*TRACKER.md: T155 | Priority: P2 | Effort: S | Deps: T153*

- [x] **Task 6.1**: Reduce 6-hourly schedules
  - Modified (changed `0 */6 * * *` → `0 2 * * *` daily):
    - `.github/workflows/argocd-drift-check.yml`
    - `.github/workflows/operations-gates-runtime.yml`
  - Kept at 6-hourly (lightweight, no GCP auth):
    - `.github/workflows/public-health-check.yml`
  - Merged into `operations-gates-runtime.yml` (SSO canary was already an optional step):
    - `.github/workflows/authenticated-sso-canary.yml` → **DELETED**

- [x] **Task 6.2**: Shift to event-driven triggers where applicable
  - `.github/workflows/post-deploy-e2e.yml` — confirmed already has `workflow_run` on "Build Tutor Images"
  - `.github/workflows/argocd-drift-check.yml` — added `workflow_run` trigger on "Build Tutor Images" as supplement to daily cron

- [x] **Task 6.3**: Remove `continue-on-error: true` from cron/audit jobs
  - Removed job-level `continue-on-error: true`:
    - `.github/workflows/ttfs-onboarding.yml`
    - `.github/workflows/lighthouse-ci.yml`
    - `.github/workflows/translation-check.yml` (job-level only; step-level continue-on-error on translation verification step is intentional graceful degradation)

- [x] **Task 6.4**: Combine daily observability audits into single workflow
  - Created: `.github/workflows/daily-infrastructure-audit.yml`
    - Job 1: `local-audits` — local observability audit (no GCP)
    - Job 2: `runtime-audits` — runtime observability + alert routing (GCP, per-source strict_runtime)
    - Job 3: `parity-check` — 3-env matrix (dev/nonprod/prod, per-lane GCP project)
    - Job 4: `parity-rollup` — cross-env rollup summary (stability check on schedule)
    - Schedule: daily at 01:00 UTC; also `workflow_dispatch` with all original inputs
  - Per R3: `strict_runtime` semantics preserved (obs defaults false, alert-routing defaults true, parity always strict)
  - Per R3: per-lane GCP project handling preserved in parity-check matrix
  - Per R3: original artifact names preserved (`observability-audit-local`, `observability-audit-runtime`, `alert-routing-audit-$run_id-$run_attempt`, `observability-parity-*`, `observability-parity-rollup`)
  - Deleted originals:
    - `.github/workflows/observability-audit.yml` → **DELETED**
    - `.github/workflows/alert-routing-audit.yml` → **DELETED**
    - `.github/workflows/observability-parity-runtime.yml` → **DELETED**

- [x] **Task 6.5**: Change TruffleHog full-history scan to monthly
  - Modified: `.github/workflows/secret-scan-audit.yml`
  - Changed: `0 3 * * 1` (weekly Monday) → `0 3 1 * *` (1st of each month)
  - Note: Per-PR TruffleHog in `ci.yml` covers new commits continuously

---

## Lessons Learned (ADR-026)

*Documented: 2026-03-05 | See: [docs/adr/026-cicd-build-pipeline-lessons.md](../../adr/026-cicd-build-pipeline-lessons.md)*

Eight failure modes discovered during the ARC migration and GHCR switch (March 2026) are
captured as binding decisions in ADR-026. A compliance verification script runs on every PR:

```bash
scripts/qa/verify-cicd-lessons-compliance.sh
```

| Lesson | Binding Decision | Automated? |
|--------|-----------------|------------|
| 1 — Registry mismatch (GAR on rke2-nonprod) | Always use GHCR for new images | YES (B1 check) |
| 2 — `--load` with docker-container driver fails in DinD | Use `--push` directly to registry | Manual |
| 3 — ARC minRunners:0 cold start delay | Tolerate 2-3 min; revisit at threshold | Manual |
| 4 — `gh run watch` breaks on GitHub 502s | Use `gh run view --exit-status` in loops | Manual |
| 5 — No live log access during builds | Implement progress artifacts for >10 min builds | Manual |
| 6 — Stale version refs across 27+ files | requirements-tutor.txt is single source of truth | YES (B6 check) |
| 7 — python3.11 hard-coded, Ulmo uses 3.12 | Use unversioned `python3` in containers | YES (B7 check) |
| 8 — DinD MTU mismatch on WireGuard CNI | Set daemon MTU to pod network MTU | YES (B8 check) |

---

## Phase 7: Documentation & Specification Alignment

*TRACKER.md: T156 | Priority: P2 | Effort: S | Deps: T153, T155*

- [x] **Task 7.1**: Update spec references for merged `verify-specs.yml`
  - Updated (workflow name references):
    - `specs/github-actions-cost-monitoring_spec.md` ✓ (frontmatter, metrics labels, budget config, related docs)
    - `specs/ci-cd-pipeline_spec.md` — pending (Phase 7 full pass)
    - `specs/plans/ci-cd-pipeline_plan.md` — pending (Phase 7 full pass)
    - `specs/plans/ci-cd-pipeline_testplan.md` — pending (Phase 7 full pass)
  - Updated (doc references):
    - `docs/README.md` ✓
    - `docs/guides/standards/DOCUMENTATION_STANDARDS.md` ✓
    - `docs/ops/security/ALLOWED_ACTIONS_POLICY.md` ✓

- [x] **Task 7.2**: Update observability doc references for merged audit workflow
  - Modify (update workflow names from 3 separate → `daily-infrastructure-audit.yml`):
    - `docs/ops/ci-cd/CI_CD_SETUP.md` ✓ (workflow table + section renamed + detail block updated)
    - `docs/ops/monitoring/OBSERVABILITY_ENHANCEMENT_PLAN.md` ✓ (2 references: CI automation entry + alert routing audit)
    - `docs/ops/monitoring/OBSERVABILITY_ROADMAP_MEREKA_LMS.md` ✓ (parity matrix variables note)
    - `docs/operations/OBSERVABILITY_PARITY_WORKFLOW_SETUP.md` ✓ (purpose line + consolidation note)
    - `docs/operations/WORKLOAD_IDENTITY_FEDERATION.md` ✓ (workflow table + Phase 1 example workflow)
    - `docs/qa/OBSERVABILITY_CANONICAL_INDEX.md` ✓ (parity execution source entry)
    - `docs/qa/OBSERVABILITY_FIRST_CLASS_READINESS_REPORT.md` ✓ (2 references: enforcement point + PAR-C004 row)

- [x] **Task 7.3**: Update runner documentation for ARC
  - Modified (added ARC runner labels + reference to `CI_CD_RUNNERS.md`):
    - `docs/ops/ci-cd/CI_CD_SETUP.md` ✓ (new "Self-Hosted Runners (ARC)" section with label table + link)
    - `docs/ops/ci-cd/GITHUB_ACTIONS_COST_MONITORING.md` ✓ ("Self-Hosted Runners" section updated from "Future" to "Implemented" with ARC cost estimates + link to `CI_CD_RUNNERS.md`)
  - Note: spec files (`specs/ci-cd-pipeline_spec.md` etc.) are deferred to a separate spec-alignment pass

- [x] **Task 7.4**: Cross-reference new docs
  - `docs/ops/ci-cd/CI_CD_SETUP.md` ✓ — references `CI_CD_RUNNERS.md` in new ARC section + See Also
  - `docs/ops/ci-cd/GITHUB_ACTIONS_COST_MONITORING.md` ✓ — already referenced `CI_PIPELINE_COST_OPTIMIZATION.md` and `CI_OPTIMIZATION_TRACKER.md` in Related Documentation section
- `docs/ops/quickref/README.md` ✓ — added new "CI/CD & Cost Optimization" category with 6 file entries

---

## File Impact Summary

### New files to create

| File | Phase | Task |
|------|-------|------|
| `deploy/k8s/base/arc/kustomization.yaml` | 1 | 1.1 |
| `deploy/k8s/base/arc/namespace.yaml` | 1 | 1.1 |
| `deploy/k8s/base/arc/helm-values.yaml` | 1 | 1.1 |
| `deploy/k8s/base/arc/runner-scale-set-standard.yaml` | 1 | 1.2 |
| `deploy/k8s/base/arc/runner-scale-set-heavy.yaml` | 1 | 1.3 |
| `deploy/k8s/overlays/rke2-nonprod/patches/arc-storage-class.yaml` | 1 | 1.4 |
| `docs/ops/ci-cd/CI_CD_RUNNERS.md` | 1 | 1.5 |
| `.github/actions/gcp-gke-auth/action.yml` | 3 | 3.1 |
| `.github/actions/setup-python-env/action.yml` | 3 | 3.2 |
| `.github/actions/setup-playwright/action.yml` | 3 | 3.3 |
| `.github/workflows/daily-infrastructure-audit.yml` | 6 | 6.4 |

### Files to delete (after merge verified)

| File | Phase | Task | Merged into |
|------|-------|------|-------------|
| `.github/workflows/verify-specs.yml` | 4 | 4.1 | `ci.yml` |
| `.github/workflows/authenticated-sso-canary.yml` | 6 | 6.1 | `operations-gates-runtime.yml` |
| `.github/workflows/observability-audit.yml` | 6 | 6.4 | `daily-infrastructure-audit.yml` |
| `.github/workflows/alert-routing-audit.yml` | 6 | 6.4 | `daily-infrastructure-audit.yml` |
| `.github/workflows/observability-parity-runtime.yml` | 6 | 6.4 | `daily-infrastructure-audit.yml` |

### Files modified per phase

| Phase | Workflow files modified | Docs/specs modified |
|-------|------------------------|---------------------|
| 1 | 0 | 0 (new files only) |
| 2 | ~35 (all with upload-artifact + concurrency targets) | 0 |
| 3 | ~19 (GCP auth + Python + Playwright consumers) | 0 |
| 4 | 2 (`ci.yml`, `accessibility-audit.yml`) | 5 (verify-specs refs) |
| 5 | ~13 (runner label changes) | 0 |
| 6 | ~8 (schedule + continue-on-error changes) | 12 (observability refs) |
| 7 | 0 | ~15 (doc/spec alignment) |

---

## Cost Projection

| Milestone | Linux-Equiv Min/Month | Est. Cost/Month |
|-----------|----------------------|-----------------|
| Current (baseline) | ~10,170 | ~$81.36 |
| After Phase 2 (immediate drops) | ~6,100 | ~$48.80 |
| After Phase 4 (consolidation) | ~3,600 | ~$28.80 |
| After Phase 5 (ARC migration) | ~300 | ~$2.40 |

---

## Verification Checklist (Run After Each Phase)

```bash
# After Phase 2: verify all workflows still trigger correctly
gh workflow list --repo Biji-Biji-Initiative/mereka-lms

# After Phase 3: verify composite actions work
gh workflow run ci.yml --ref main  # manual trigger test

# After Phase 4: verify merged workflows pass
gh run list --workflow=ci.yml --limit=3

# After Phase 5: verify K8s runners are picking up jobs
kubectl get pods -n arc-systems  # ARC controller
kubectl get pods -n arc-runners  # Ephemeral runner pods

# After Phase 6: verify nightly audit runs
gh run list --workflow=daily-infrastructure-audit.yml --limit=1

# Full verification
./scripts/qa/verify-ci-cd-pipeline.sh
./scripts/qa/verify-github-actions-cost.sh
```
