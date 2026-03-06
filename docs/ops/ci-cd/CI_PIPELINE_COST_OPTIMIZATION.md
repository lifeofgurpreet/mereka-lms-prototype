# CI Pipeline Cost Optimization — Expert Review & Action Plan

<!-- Last reviewed: 2026-02-26 -->

**Status**: PHASE 4 COMPLETE — `verify-specs.yml` merged into `ci.yml`; see [CI_OPTIMIZATION_TRACKER.md](CI_OPTIMIZATION_TRACKER.md) for task status
**Source**: External DevOps engineer review (three rounds) of GitHub Actions pipeline
**Related**: [CI_CD_SETUP.md](CI_CD_SETUP.md) | [GITHUB_ACTIONS_COST_MONITORING.md](GITHUB_ACTIONS_COST_MONITORING.md)
**Implementation tracker**: [CI_OPTIMIZATION_TRACKER.md](CI_OPTIMIZATION_TRACKER.md) (agent-ready task list with file mappings)

## Context

As of 2026-02-26, this repository has **48 workflow files** in `.github/workflows/`. An external DevOps review identified systemic cost and efficiency problems across two review rounds. The pipeline is described as an "enterprise-grade compliance engine running on a brute-force execution model."

This document captures validated findings, grades them against our actual workflow state, and defines a phased implementation plan culminating in self-hosted runners on our existing K8s cluster.

---

## Part 1: Compute & Execution Waste

### 1.1 macOS Runner Premium (10x Cost Multiplier)

**Workflow**: `ios-testflight.yml`
**Runner**: `macos-14`
**Trigger**: Push to `main` touching `ios/**`

**Impact**: GitHub charges $0.08/min for macOS vs $0.008/min for Linux. A 30-minute iOS build = 300 Linux-equivalent minutes. At 10 pushes/week, this is 3,000 Linux-equivalent minutes/month from one workflow alone.

**Validation**: Confirmed. The workflow triggers on every push to main that touches the `ios/` directory and uses `macos-14`.

**Fix**: Change trigger to `workflow_dispatch` only (manual) or tag-based (`v*.*.*-ios`). iOS builds are infrequent and don't need CI gating on every push. Cannot move to K8s (requires macOS/Xcode). Options: keep on GitHub (optimized trigger) or buy a Mac Mini as a dedicated runner.

### 1.2 Missing Concurrency Controls on Heavy Workflows

**Affected**: `ci.yml`, `verify-specs.yml`, `iac-scan.yml`, all PR-triggered workflows

**Problem**: If a developer pushes three commits to a PR in 10 minutes, GitHub spins up three overlapping parallel executions of the entire suite.

**Impact**: 3x cost for the same PR validation. If CI takes 45 aggregate minutes, three rapid commits burn 135 minutes.

**Validation**: Confirmed. No `concurrency` blocks found on `ci.yml` or `verify-specs.yml`. Only `post-deploy-e2e.yml` has concurrency controls.

**Fix**: Add to all PR-triggered workflows:
```yaml
concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true
```

### 1.3 Docker Build Caching "Illusion"

**Workflow**: `build-tutor-images.yml`

**Problem**: Uses `docker/setup-buildx-action` with `driver: docker`, but `tutor images build` wraps standard `docker build` — GitHub Actions is NOT preserving layer cache between runs.

**Impact**: Every run builds GBs of images entirely from scratch. 20-40 minutes of heavy compute per run.

**Validation**: Confirmed. No `--cache-from` or `--cache-to` arguments are passed to the Tutor build process.

**Fix**: Inject BuildKit caching via `DOCKER_BUILD_OPTIONS` environment variable:
```bash
export DOCKER_BUILD_OPTIONS="--cache-from=type=gha --cache-to=type=gha,mode=max"
```
Or better: move to self-hosted runner with persistent Docker layer cache via PVC (see Part 4).

### 1.4 Trivy Vulnerability Scan Duplication

**Workflow**: `build-tutor-images.yml`

**Problem**: Runs `aquasecurity/trivy-action` twice per image — once for CRITICAL (blocking) and once for HIGH (informational). Trivy downloads its vulnerability database and scans multi-GB image layers twice.

**Fix**: Run Trivy once outputting to JSON. Use `jq` to separate CRITICAL (fail CI) from HIGH (informational report) from the same scan output. Halves scan time.

### 1.5 Micro-Job Spin-Up Overhead (VM Boot Tax)

**Original claim**: ci.yml has 30+ tiny jobs.

**Validation**: The reviewer was right — deep audit reveals `ci.yml` has **74 distinct jobs** (not 30+, not 5). Each provisions a separate VM, checks out the repo, and installs dependencies. 17 of these 74 jobs are conditional (only fire when PR title contains specific keywords like "branding", "token", "a11y"). Additionally, `verify-specs.yml` matrix creates 12 parallel jobs running 71 verification scripts. Combined: **86+ job spin-ups per push to main**.

At 30-45 seconds of boot overhead per job, that's ~37-65 minutes of pure VM setup waste per CI run.

**Better approach**: Use `xargs -P 4` or GNU `parallel` within a single job to run bash scripts across CPU cores instead of across VMs. Consolidate 74 micro-jobs into 3-4 logical jobs. Eliminates 70+ VM boot sequences.

---

## Part 2: Silent Cost Drains

### 2.1 Artifact Storage Bloat

**Problem**: Playwright traces (~50MB each) uploaded 4x/day across 3 workflows. With 14-30 day retention, this accumulates 8+ GB of artifacts for *passing* jobs.

**Validation**: Confirmed. Retention periods range from 7 to 90 days across workflows.

**Fix**:
- Set `retention-days: 3` for logs and traces on passing workflows
- Wrap heavy uploads (Playwright traces/videos/screenshots) with `if: failure()` — only upload on failure
- Keep lightweight text logs at current retention

### 2.2 Playwright Browser Redundancy

**Problem**: `npx playwright install --with-deps chromium` (~300MB download) runs in 4-5 separate workflows with no caching and inconsistent version pinning (unspecified, 1.50.0, auto-installed).

**Fix**: Cache `~/.cache/ms-playwright` using `actions/cache` keyed by Playwright version. Create composite action `.github/actions/setup-playwright/action.yml` with pinned version.

### 2.3 Wasted continue-on-error Crons

**Affected**: `ttfs-onboarding.yml`, `lighthouse-ci.yml`, `translation-check.yml`

**Problem**: `continue-on-error: true` at job level means if an external service goes down, the workflow fails silently but keeps spinning up every 6 hours, burning compute for nothing.

**Fix**: Remove `continue-on-error: true`. Add retry logic *inside* the bash scripts instead of masking workflow failure. Failed crons should be visible.

---

## Part 3: Duplication & Maintenance Debt

### 3.1 Workflow Duplication (ci.yml vs verify-specs.yml)

**Current state**:
- `ci.yml`: **74 jobs** — lint, branding, token validation, a11y, security scans, spec checks (17 are conditional on PR title keywords)
- `verify-specs.yml`: 12-group matrix running 71 verification scripts (fast on PRs, full on push)

**Validation**: The duplication is complementary (linting vs verification), not identical. But both trigger on the same events with overlapping path filters → redundant checkout/setup overhead.

**Fix**: Merge spec-lint from `ci.yml` into the `fast-verification` job of `verify-specs.yml`. Then flatten the combined pipeline into 3 logical jobs:
1. **Static-Analysis**: All YAML, Markdown, shell linting + spec linting (run scripts in parallel with `xargs -P`)
2. **Unit-and-Config-Tests**: Python pytest, Tutor config generation, rendering logic
3. **Security-Scans**: TruffleHog, CodeQL, pip-audit

### 3.2 Boilerplate Sprawl (Copy-Paste Trap)

**Problem**: Upgrading Python from 3.11→3.12, or updating the GCP auth action, requires manually editing 25+ YAML files.

**Fix**: Create composite actions in `.github/actions/`:

| Action | Replaces |
|--------|----------|
| `setup-python-env` | Checkout + Python setup + pip cache + base deps install |
| `auth-gcp-gke` | GCP auth + gcloud setup + GKE credentials + graceful fallback |
| `setup-playwright` | Playwright install + browser cache + version pinning |

### 3.3 Secrets Sprawl

**Problem**: Dozens of individual secrets passed manually (e.g., `SSO_CANARY_EMAIL_PROD`, `SSO_CANARY_STUDIO_PASSWORD_DEV`) into bash environments across multiple workflow files.

**Fix**: Since we already use Infisical, the CI runner should authenticate via a single Machine Identity Token and pull secrets directly. This centralizes secret rotation and drastically cleans up YAML.

### 3.4 Aggressive Cron Schedule Sprawl

**6-hourly workflows** (4 runs/day each = 16 runs/day combined):

| Workflow | Schedule | Purpose |
|----------|----------|---------|
| `public-health-check.yml` | Every 6h | Branding + auth surface checks |
| `argocd-drift-check.yml` | Every 6h | GitOps drift detection (3+1 jobs) |
| `authenticated-sso-canary.yml` | Every 6h | Playwright SSO login test |
| `operations-gates-runtime.yml` | Every 6h | Consolidated runtime gates |

**Daily workflows** (3 runs/day combined):

| Workflow | Schedule | Purpose |
|----------|----------|---------|
| `observability-audit.yml` | Daily 1:00 AM | Local + runtime observability |
| `alert-routing-audit.yml` | Daily 3:00 AM | Alert routing verification |
| `observability-parity-runtime.yml` | Daily 3:15 AM | 3-env parity (matrix) |

**Validation**: ~19 scheduled workflow executions per day, ~570/month.

**Fix**:
1. Reduce `argocd-drift-check` and `operations-gates-runtime` to 12-hourly or daily
2. Keep `public-health-check` at 6-hourly (lightweight uptime canary)
3. Merge `authenticated-sso-canary` into `operations-gates-runtime` (already has it as optional step)
4. Combine 3 daily observability workflows into one "Nightly Infrastructure Audit"
5. Change `secret-scan-audit` from weekly to monthly (per-PR TruffleHog covers new commits)
6. Better: shift scheduled checks to `workflow_run` triggers (post-deploy) instead of blind timers

### 3.5 Heavy Security Scans

**Problem**: `secret-scan-audit.yml` runs TruffleHog with `fetch-depth: 0` (full history) weekly. `ci.yml` also runs TruffleHog on every PR.

**Fix**: Keep per-PR incremental scan. Move full-history scan to monthly. Use `--since-commit` with last scan SHA to make it incremental.

---

## Part 4: Self-Hosted Runners on K8s (The Strategic Play)

### Why This Matters

We already pay for 3 worker nodes (rke2-nonprod cluster). GitHub Actions compute is metered on top of that. Moving CI workloads to our own cluster transforms the billing model from "pay-per-minute" to "utilizing existing sunk costs."

**Expected outcome**: $0 for Linux workloads on GitHub Actions.

### Architecture: Actions Runner Controller (ARC)

Do NOT manually install the GitHub Runner binary. Use **Actions Runner Controller (ARC)** — the official GitHub-supported Kubernetes operator.

**How it works**:
1. ARC runs as a pod in the dev/staging cluster
2. Listens to the GitHub repository via webhooks (using a GitHub App)
3. When a workflow triggers, ARC spins up an ephemeral pod to run that job
4. Pod is destroyed after job completes (clean environment every time)

### Effort Estimate

| Phase | Time | Work |
|-------|------|------|
| Infrastructure setup | 2-4h | Install ARC Helm charts, create GitHub App |
| Runner Scale Set config | 2-4h | Define pools (heavy-builders, standard-workers) |
| Workflow migration | 1-2 days | Change `runs-on: ubuntu-24.04` → `runs-on: mereka-k8s-runners` |

### Workload Placement Strategy

| Workload | Where | Rationale |
|----------|-------|-----------|
| `build-tutor-images.yml` | **K8s (ARC)** | Needs 12GB+ RAM, GitHub runners only have 7GB → currently swapping to disk. K8s can allocate dedicated resources. |
| All cron jobs (drift, observability, health) | **K8s (ARC)** | Absorb 24/7 background noise on existing compute. Direct cluster access via ServiceAccount → no GCP auth overhead. |
| E2E / Playwright tests | **K8s (ARC)** | Persistent Playwright browser cache via PVC. |
| `ci.yml` (includes verification; `verify-specs.yml` merged in Phase 4) | **Either** | Fast, lightweight. Can stay on GitHub-hosted runners or move to ARC. |
| `ios-testflight.yml` | **GitHub macOS** | Xcode requires macOS. Cannot run on Linux K8s. Must stay on GitHub (or buy a Mac Mini). |

### Unique K8s Runner Advantages

**1. Persistent Docker Layer Caching (DinD)**

Configure Docker-in-Docker sidecar with a PVC. The Docker daemon remembers image layers between builds.

**Impact**: Tutor builds drop from 30+ minutes to ~5 minutes (only rebuilds changed layers).

**2. Persistent npm/pip/Playwright Caches**

Mount a PVC to `~/.cache`. Dependencies instantly available to every job pod.

**Impact**: Eliminates minutes of internet downloads per run.

**3. Direct Cluster Access**

Runner pods inside the cluster use Kubernetes ServiceAccounts (RBAC) for direct access. No GCP auth, no gcloud setup, no kubeconfig fetching.

**Impact**: Eliminates the entire GCP auth boilerplate from 6+ workflows.

### Security Guardrails (CRITICAL)

**If repo is private**: Safe. No external code runs on your cluster.

**If repo is public**: MUST configure GitHub to "Require approval for all outside collaborators" before running workflows. Without this, a malicious PR could run arbitrary code on your cluster.

**Current status**: The `mereka-lms` repo is private. Safe to proceed.

---

## Phased Implementation Plan

### Phase 1: Immediate Cost Drop (~1 hour, no architecture changes)

| Change | File | Impact |
|--------|------|--------|
| iOS build → manual/tag-only trigger | `ios-testflight.yml` | Eliminate macOS runner waste |
| Add `concurrency` + `cancel-in-progress` to PR workflows | `ci.yml`, `iac-scan.yml` (verify-specs.yml merged into ci.yml) | Prevent duplicate runs on rapid pushes |
| Reduce argocd-drift to 12-hourly | `argocd-drift-check.yml` | -2 runs/day |
| Reduce operations-gates to 12-hourly | `operations-gates-runtime.yml` | -2 runs/day |
| Merge SSO canary into operations-gates | Delete `authenticated-sso-canary.yml` | -4 runs/day |
| Secret scan weekly → monthly | `secret-scan-audit.yml` | -3 runs/month |
| Artifact retention: 3 days for passing, upload traces only on failure | All workflows with `upload-artifact` | Reduce storage costs |
| Remove `continue-on-error: true` from cron jobs | `ttfs-onboarding.yml`, `lighthouse-ci.yml`, `translation-check.yml` | Stop masking failures |

**No quality gates lost.** All checks remain; only frequency/hygiene changes.

### Phase 2: Consolidation (~2-3 hours)

| Change | Files | Impact |
|--------|-------|--------|
| Merge 3 daily observability workflows into 1 | `observability-audit.yml`, `alert-routing-audit.yml`, `observability-parity-runtime.yml` | -2 daily GCP auths, 1 spin-up instead of 3 |
| Merge spec-lint + verify-specs into ci.yml (DONE — Phase 4) | `ci.yml` (absorbed `verify-specs.yml`) | -1 job spin-up per PR |
| Flatten verification matrix to `static-validation` + `full-verification` jobs (DONE — Phase 4) | `ci.yml` | -8 job spin-ups per push |
| Run Trivy once, split with jq | `build-tutor-images.yml` | Halve scan time per image |
| Use `xargs -P 4` for bash script execution | Consolidated validation jobs | Full CPU utilization on single VM |

### Phase 3: Composite Actions & Caching (~3-4 hours)

| Change | Files | Impact |
|--------|-------|--------|
| Create `setup-python-env` composite action | `.github/actions/setup-python-env/action.yml` | DRY Python setup across 25+ workflows |
| Create `auth-gcp-gke` composite action | `.github/actions/auth-gcp-gke/action.yml` | DRY GCP auth across 6+ workflows |
| Create `setup-playwright` composite action | `.github/actions/setup-playwright/action.yml` | Consistent version + cached browsers |
| Add pip caching globally | All Python workflows | ~30-60s saved per job |
| Pin Playwright version across all E2E workflows | All E2E workflows | Reproducible, cacheable |
| Infisical Machine Identity for CI secrets | Workflow secrets config | Centralize secret rotation |

### Phase 4: Self-Hosted Runners (1-3 days)

| Step | Time | Work |
|------|------|------|
| Deploy ARC to rke2-nonprod cluster | 2-4h | Helm install + GitHub App creation |
| Define scale sets (heavy-builders + standard-workers) | 2-4h | Resource limits, PVC for Docker/cache |
| Migrate cron jobs to K8s runners | 4h | Change `runs-on:` + verify all pass |
| Migrate `build-tutor-images.yml` to K8s runners | 4h | DinD + PVC caching for Docker layers |
| Migrate Playwright/E2E to K8s runners | 4h | PVC for browser cache |
| Optimize iOS → manual dispatch only | 30min | Already done in Phase 1 |

---

## Cost Model

### Current (Before Optimization)

| Category | Runs/Month | Avg Min/Run | Linux-Equiv Min | Est. Cost |
|----------|------------|-------------|-----------------|-----------|
| ci.yml (PR+push, 74 jobs) | ~80 | 45 | 3,600 | $28.80 |
| ci.yml full-verification job (formerly verify-specs.yml matrix) | ~80 | 15 | 1,200 | $9.60 |
| ios-testflight.yml (macOS) | ~10 | 30 | **3,000** | $24.00 |
| build-tutor-images.yml | ~8 | 35 | 280 | $2.24 |
| 6-hourly scheduled (4 workflows) | ~480 | 3 | 1,440 | $11.52 |
| Daily scheduled (3 workflows) | ~90 | 5 | 450 | $3.60 |
| Weekly scheduled (1 workflow) | ~4 | 10 | 40 | $0.32 |
| Post-deploy/manual | ~20 | 8 | 160 | $1.28 |
| **Total** | **~772** | | **~10,170** | **~$81.36** |

*Estimates assume GitHub Free plan (2,000 included minutes). Overages at Linux rate $0.008/min.*

*Note: ci.yml cost is the dominant factor. With 74 jobs, each PR/push run burns ~45 aggregate runner-minutes across all parallel jobs. The 17 conditional jobs reduce this somewhat on PRs that don't match keywords.*

### After Phase 2 (immediate drops, ~40% reduction)

~6,100 Linux-equiv min/month → **~$48.80/month**
(iOS eliminated, concurrency prevents duplicate runs, artifact hygiene)

### After Phase 4 (consolidation, ~65% reduction)

~3,600 Linux-equiv min/month → **~$28.80/month**
(74 micro-jobs → 3-4 consolidated jobs, verify-specs merged, xargs parallelism)

### After Phase 5 (Self-hosted on K8s, ~95% reduction)

Only iOS builds remain on GitHub-hosted runners. Everything else on sunk-cost K8s compute.

~300 Linux-equiv min/month (iOS only) → **~$2.40/month**

---

## Decision Log

| Date | Decision | Rationale |
|------|----------|-----------|
| 2026-02-26 | Document findings, no immediate action | Review needed before touching 48 workflow files |
| | Phase 1 approved? | |
| | Phase 2 approved? | |
| | Phase 3 approved? | |
| | Phase 4 approved? | |

---

## References

- [GitHub Actions Billing](https://docs.github.com/en/billing/managing-billing-for-github-actions)
- [Actions Runner Controller (ARC)](https://github.com/actions/actions-runner-controller) — official K8s operator
- `docs/ops/ci-cd/GITHUB_ACTIONS_COST_MONITORING.md` — monitoring setup and scripts
- `docs/ops/ci-cd/CI_CD_SETUP.md` — workflow documentation
- `specs/ci-cd-pipeline_spec.md` — CI/CD spec with acceptance criteria
