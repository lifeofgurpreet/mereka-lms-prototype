# mereka-lms Implementation Tracker

**Last updated**: 2026-02-24
**Branch**: main
**Sources**: Internal audit (2026-02-24) + DR2 research review (2026-02-24)

## Summary

| Status | Count |
|--------|-------|
| TODO   | 71    |
| PARTIAL| 16    |
| BLOCKED| 3     |
| **Total** | **90** |

Cross-reference: DR2 items I-001→I-050 mapped below. Each task shows `DR2:I-0XX` when sourced from the PDF.

Audit baseline: 33 EXISTS (not tracked here) · 10 PARTIAL · 6 MISSING · 17 repo-specific

---

## Sprint 1: Supply-Chain Security & CI Hardening (P0)

*Immediate risk reduction. Unblocks CI reliability, prevents supply-chain incidents. Do first.*

| ID | Title | Priority | Status | Source | Effort | Deps | Description |
|----|-------|----------|--------|--------|--------|------|-------------|
| T001 | Create SECURITY.md | P0 | TODO | I04 | S | — | Vulnerability disclosure policy: contact, timeline, scope. No file exists at all. |
| T052 | Pin GitHub Actions to commit SHAs | P0 | TODO | DR2:I-001 | M | — | All 3 repos: mereka-lms, bbi-infrastructure, platform-control-plane. Replace version tags (`uses: actions/checkout@v4`) with immutable SHA refs to prevent tag-mutation attacks. |
| T053 | Enforce org/repo allowed-actions policy | P0 | TODO | DR2:I-002 | M | T052 | Configure GitHub org-level "Allowed Actions" to blocklist unreviewed third-party actions; pair with SHA pinning. |
| T005 | Add SBOM generation to CI | P0 | TODO | I09, DR2:I-003 | M | — | Add Syft step to `build-tutor-images.yml` generating CycloneDX SBOM per image. Attach to OCI image as attestation and store as a workflow artifact. No SBOM today. |
| T002 | Add pip-audit to CI (vuln gate) | P0 | TODO | I10, DR2:I-005 | S | — | Trivy covers container layers but pyproject.toml deps have no Python-level audit. Add pip-audit AND make Trivy severity threshold blocking for releases. Define severity policy (CRITICAL=fail, HIGH=warn) and maintain exceptions register. |
| T054 | Add build provenance/SLSA attestations | P0 | TODO | DR2:I-004 | M | T052, T092 | Generate SLSA-style provenance for OCI images using `slsa-github-generator` or `cosign attest`. Attach attestations alongside SBOMs. |
| T006 | Configure OpenSSF Scorecard | P0 | TODO | I12 | S | — | Add `.github/workflows/scorecard.yml`. Free signal on supply-chain posture; feeds into Dependency Review. |
| T055 | Render Tutor env in CI (fix idempotency skip) | P0 | TODO | DR2:I-006 | M | — | CRITICAL: `tests/tutor/test_idempotency.sh` exits early if `tutor_env/` is missing in CI. Add a CI step that renders the Tutor environment before running idempotency tests so they don't silently skip. |
| T056 | Implement Cache-Control headers in MFE Caddyfile | P0 | TODO | DR2:I-008 | M | — | Hashed assets: `Cache-Control: max-age=31536000, immutable`; `index.html`: `no-cache`; API responses: `no-store`. Prevents stale MFE code after deploys. |
| T091 | Standardize workflow permissions (least-privilege) | P1 | TODO | DR2:I-013 | S | — | All GitHub Actions workflows must declare minimal `permissions:` block. Default `GITHUB_TOKEN` scope is too broad; enumerate `contents: read` etc. per job. |
| T092 | Replace JSON SA key with Workload Identity Federation | P1 | TODO | DR2:I-014 | M | — | Remove `GCP_SA_KEY` secret from all repos. Configure OIDC Workload Identity Federation so CI jobs authenticate to GCP without long-lived credentials. |
| T057 | Pin binary downloads in bbi-infrastructure CI | P1 | TODO | DR2:I-015 | S | — | Pin `yq`, `kubectl`, `helm` and other downloaded binaries to SHA or exact version in CI workflows. Cross-repo: bbi-infrastructure. |
| T058 | Pin binary downloads in platform-control-plane CI | P1 | TODO | DR2:I-016 | S | — | Same as T057 for platform-control-plane repo. Cross-repo: platform-control-plane. |
| T059 | Add GitHub Advanced Security secret scanning | P1 | TODO | DR2:I-017 | M | — | Enable GHAS secret scanning and push protection across all repos. Complements local pre-commit hook already in place. |
| T060 | Add Dependency Review workflow | P1 | TODO | DR2:I-011 | S | — | Add `dependency-review.yml` that blocks PRs introducing known-vulnerable or license-incompatible deps. Uses GitHub's built-in dependency review action. |
| T061 | Add Dependabot for pip/npm/terraform | P1 | TODO | DR2:I-012 | S | — | Add `.github/dependabot.yml` covering `pip` (pyproject.toml), `npm` (package.json), `terraform` (infrastructure/terraform/). |
| T062 | Replace PAT-based GitOps with GitHub App token | P2 | TODO | DR2:I-033 | M | — | Current GitOps commits use a PAT that isn't rotated. Replace with a GitHub App token (scoped, auto-rotating) or fine-grained PAT with documented rotation schedule. |
| T063 | Pin runner images to ubuntu-24.04 | P2 | TODO | DR2:I-032 | S | — | Replace `runs-on: ubuntu-latest` with `runs-on: ubuntu-24.04` across all workflows in all repos to prevent silent runner image drift. |
| T004 | Pin Terraform providers + add IaC scanning | P0 | TODO | I14, DR2:I-041, DR2:I-042 | S | — | Add tfsec or checkov as a CI job against `infrastructure/terraform/`. Add Trivy config scan for K8s manifests. Pin all Terraform provider versions with `required_providers` + lockfile. |
| T064 | Add commit signing (Sigstore/GitHub) | P3 | TODO | DR2:I-049 | M | — | Enable Sigstore keyless signing or GitHub's commit signing for merges to main. Verify signatures in CI as a soft gate initially. |

### Sprint 1 Implementation Plans

#### Swarm Batch 1 — mereka-lms only, no cross-repo, no RKE2

**Agent assignment strategy**: T052+T091+T063 touch the same 17 workflow files — assign to ONE agent to avoid conflicts. Other tasks are independent files (new workflows, new config files, Caddyfile).

---

#### T001 Plan: Create SECURITY.md

**Files**: `SECURITY.md` (new)

**Content**: Standard vulnerability disclosure policy. Contact: `security@mereka.io`. Response timeline: acknowledge 48h, triage 5 business days, fix per severity (Critical: 7d, High: 30d, Medium: 90d). Scope: mereka-lms, bbi-infrastructure, platform-control-plane. Out of scope: upstream Open edX (report to openedx.org). Supported versions: latest release only.

**Done when**: `SECURITY.md` exists at repo root with valid contact, timeline, and scope sections.

---

#### T052+T091+T063 Plan: Harden all 17 workflows (combined)

**Files**: All 17 `.github/workflows/*.yml`:
`ci.yml`, `build-tutor-images.yml`, `tutor-config-verify.yml`, `tutor-plugin-test.yml`, `policy-checks.yml`, `verify-specs.yml`, `authenticated-sso-canary.yml`, `smoke-authenticated.yml`, `build-ios-app.yml`, `cloud-sql-backup.yml`, `public-health-check.yml`, `release-evidence.yml`, `observability-audit.yml`, `alert-routing-audit.yml`, `operations-gates-runtime.yml`, `dr-evidence-bundle.yml`, `ios-testflight.yml`

**T052 — Pin Actions to SHAs**:
For each `uses:` line, resolve the current version tag to its commit SHA:
- `actions/checkout@v4` → `actions/checkout@<sha>`
- `actions/setup-python@v5` → `actions/setup-python@<sha>`
- `actions/upload-artifact@v4` → `actions/upload-artifact@<sha>`
- `actions/download-artifact@v4` → `actions/download-artifact@<sha>`
- `actions/github-script@v7` → `actions/github-script@<sha>`
- `actions/setup-node@v4` → `actions/setup-node@<sha>`
- `google-github-actions/auth@v2` → `google-github-actions/auth@<sha>`
- `docker/setup-buildx-action@v3` → `docker/setup-buildx-action@<sha>`
- `aquasecurity/trivy-action@master` → `aquasecurity/trivy-action@<sha>`
- `ludeeus/action-shellcheck@master` → `ludeeus/action-shellcheck@<sha>`
- `trufflesecurity/trufflehog@main` → `trufflesecurity/trufflehog@<sha>`

Add `# vX.Y.Z` comment after each SHA for readability.

**T091 — Add permissions blocks**:
Add top-level `permissions: {}` (deny-all default) to every workflow. Then add per-job permissions as needed:
- Read-only jobs: `permissions: { contents: read }`
- PR comment jobs: `permissions: { contents: read, pull-requests: write }`
- Artifact upload: `permissions: { contents: read, actions: write }` (if needed)
- `build-tutor-images.yml`: `permissions: { contents: write, packages: write }` (pushes images)
- `cloud-sql-backup.yml`: `permissions: { contents: read, id-token: write }` (GCP auth)

**T063 — Pin runners**:
Replace all `runs-on: ubuntu-latest` with `runs-on: ubuntu-24.04`.

**Done when**: All 17 workflows have (a) SHA-pinned actions with version comments, (b) explicit minimal permissions, (c) `ubuntu-24.04` runners. CI passes on the PR.

---

#### T006 Plan: OpenSSF Scorecard workflow

**Files**: `.github/workflows/scorecard.yml` (new)

**Content**:
```yaml
name: Scorecard
on:
  schedule:
    - cron: '0 6 * * 1'  # Weekly Monday 6am UTC
  push:
    branches: [main]
permissions:
  security-events: write
  id-token: write
  contents: read
  actions: read
jobs:
  analysis:
    runs-on: ubuntu-24.04
    steps:
      - uses: actions/checkout@<sha>  # pin
      - uses: ossf/scorecard-action@<sha>  # pin
        with:
          results_file: results.sarif
          results_format: sarif
          publish_results: true
      - uses: github/codeql-action/upload-sarif@<sha>  # pin
        with:
          sarif_file: results.sarif
```

**Done when**: Workflow exists, passes on push to main, results visible in GitHub Security tab.

---

#### T060 Plan: Dependency Review workflow

**Files**: `.github/workflows/dependency-review.yml` (new)

**Content**: Use `actions/dependency-review-action` on `pull_request` events. Block PRs with CRITICAL/HIGH vulns. Allow license exceptions via config.

**Done when**: Workflow exists, triggers on PRs, blocks known-vulnerable deps.

---

#### T061 Plan: Dependabot config

**Files**: `.github/dependabot.yml` (new)

**Content**:
```yaml
version: 2
updates:
  - package-ecosystem: "pip"
    directory: "/"
    schedule:
      interval: "weekly"
  - package-ecosystem: "npm"
    directory: "/"
    schedule:
      interval: "weekly"
  - package-ecosystem: "github-actions"
    directory: "/"
    schedule:
      interval: "weekly"
  - package-ecosystem: "terraform"
    directory: "/infrastructure/terraform/"
    schedule:
      interval: "monthly"
```

Note: `github-actions` ecosystem will auto-PR SHA pin updates — complements T052.

**Done when**: File exists, Dependabot starts opening PRs within 24h.

---

#### T055 Plan: Fix Tutor env rendering in CI

**Files**: `.github/workflows/ci.yml` (modify the tutor test job)

**Problem**: `tests/tutor/test_idempotency.sh` exits early when `tutor_env/` doesn't exist. In CI, the tutor environment isn't rendered, so tests silently pass without actually running.

**Fix**: In the CI job that runs tutor tests, add steps before test execution:
1. `pip install "tutor[full]==18.2.2"`
2. `export TUTOR_ROOT=$(pwd)/tutor_env`
3. `tutor config save` — generates the tutor_env/ directory
4. `./infrastructure/tutor/apply-patches.sh` — applies all patches
5. Now run `tests/tutor/test_idempotency.sh`

**Done when**: CI log shows idempotency tests actually executing (not skipping), and tests pass.

---

#### T056 Plan: MFE Caddyfile Cache-Control headers

**Files**: `deploy/k8s/base/plugins/mfe/apps/mfe/Caddyfile` (modify)

**Changes**: Add `header` directives to each `file_server` block:
- Hashed assets (`*.js`, `*.css` with hash in filename): `Cache-Control "public, max-age=31536000, immutable"`
- `index.html` and `/`: `Cache-Control "no-cache"` (forces revalidation on deploy)
- API proxy routes: `Cache-Control "no-store"`

**Pattern**:
```
@hashed path *.js *.css *.woff2 *.png *.jpg *.svg
header @hashed Cache-Control "public, max-age=31536000, immutable"
header /index.html Cache-Control "no-cache"
```

**Done when**: Caddyfile has explicit Cache-Control for hashed assets, index.html, and API routes. `curl -I` against MFE assets returns correct headers.

---

#### T002 Plan: pip-audit + make Trivy blocking

**Files**: `.github/workflows/ci.yml` (modify)

**Changes**:
1. Add pip-audit job: `pip install pip-audit && pip-audit --require-hashes --desc -r requirements.txt` (or from pyproject.toml)
2. In `build-tutor-images.yml`: change Trivy `exit-code: 0` → `exit-code: 1` for CRITICAL severity. Keep HIGH as warning (exit-code: 0 but upload SARIF).
3. Add `--ignorefile .trivyignore` support for documented exceptions.

**Done when**: pip-audit runs in CI, Trivy blocks on CRITICAL vulns, `.trivyignore` exists (can be empty initially).

---

#### T003 Plan: .tool-versions

**Files**: `.tool-versions` (new)

**Content**:
```
python 3.12.8
nodejs 18.20.4
```

Match versions to what CI currently uses in `actions/setup-python` and `actions/setup-node`.

**Done when**: File exists, versions match CI.

---

#### T068 Plan: PR template

**Files**: `.github/PULL_REQUEST_TEMPLATE.md` (new)

**Content**: Checklist: What changed, Why, Specs updated (if applicable), Tests added/updated, Rollout plan (for infra changes), Verification steps.

**Done when**: File exists, new PRs auto-populate the template.

---

#### T070 Plan: CODEOWNERS

**Files**: `.github/CODEOWNERS` (new)

**Content**:
```
# GitOps production overlays — require infra review
deploy/k8s/overlays/production/ @Biji-Biji-Initiative/infra
# GitHub Actions workflows — require infra review
.github/workflows/ @Biji-Biji-Initiative/infra
# Secrets configuration
deploy/k8s/base/secrets/ @Biji-Biji-Initiative/infra
# Tutor patches — require platform review
infrastructure/tutor/ @Biji-Biji-Initiative/platform
```

**Done when**: File exists, GitHub shows required reviewers on PRs touching those paths. (Requires the GitHub teams to exist — may need to create them.)

---

## Swarm Batch 1: Task → Agent Assignment

| Agent | Tasks | Files touched | Isolation |
|-------|-------|---------------|-----------|
| **workflow-hardener** | T052+T091+T063 | All 17 `.github/workflows/*.yml` | worktree |
| **security-scaffolder** | T001, T068, T070 | `SECURITY.md`, `.github/PULL_REQUEST_TEMPLATE.md`, `.github/CODEOWNERS` | worktree |
| **ci-gates** | T006, T060, T061 | 3 new workflow files + `dependabot.yml` | worktree |
| **tutor-ci-fix** | T055, T002 | `ci.yml`, `build-tutor-images.yml` | worktree |
| **caddyfile-headers** | T056 | `deploy/k8s/base/plugins/mfe/apps/mfe/Caddyfile` | worktree |
| **tooling** | T003 | `.tool-versions` | worktree |

**Conflict risk**: workflow-hardener and tutor-ci-fix both touch `ci.yml`. Sequence: workflow-hardener first (bulk changes), tutor-ci-fix second (adds pip-audit job + Tutor rendering).

---

## Sprint 2: CI Quality Gates & Testing (P0–P1)

*Build integrity, idempotency tests, vuln gating, spec coverage, branch protection.*

| ID | Title | Priority | Status | Source | Effort | Deps | Description |
|----|-------|----------|--------|--------|--------|------|-------------|
| T003 | Add .tool-versions for Python | P0 | TODO | I07 | S | — | CI pins `python-version: '3.12'` ad hoc in each job. Add `.tool-versions` (asdf/rtx) so local dev matches CI exactly. |
| T043 | Pin requirements with uv lockfile | P3 | TODO | I08 | S | — | Main repo has no `requirements.lock`. Generate with `uv pip compile pyproject.toml -o requirements.lock` and commit. |
| T022 | Add pytest coverage gate to CI | P1 | TODO | I24 | S | — | `pytest-cov` is in dev deps but no `--cov --cov-fail-under` in CI. Add a coverage job with a floor (suggest 60% to start). |
| T023 | Add purchase-gateway unit tests | P1 | TODO | NEW | M | T022 | `services/purchase-gateway/tests/` exists but coverage unknown. Add tests for Stripe webhook handler and order model. |
| T065 | Add CodeQL SAST workflow | P1 | TODO | DR2:I-010 | M | — | Enable CodeQL analysis for Python and JavaScript where eligible. Integrate into PR checks as a non-blocking gate initially, escalate to blocking. |
| T066 | Establish spec coverage floor per PR | P1 | TODO | DR2:I-018 | M | — | Define a "spec coverage" metric (fraction of ACs with a corresponding test). Enforce a minimum floor per PR, ratchet upward each sprint, review in retro. |
| T067 | Add Aspects version compatibility enforcement test | P1 | TODO | DR2:I-020 | M | — | Add a CI test that validates the deployed Aspects version is compatible with the target Open edX release. Prevents silent incompatibilities during upgrades. |
| T068 | Add PR template aligned to specs/rollout/verification | P2 | TODO | DR2:I-028 | S | — | Add `.github/PULL_REQUEST_TEMPLATE.md` with checklist: specs updated, tests added, rollout plan, verification steps. |
| T069 | Branch protection + Scorecard alignment | P1 | TODO | DR2:I-029 | S | — | Enforce branch protection: require ≥1 review, passing status checks, no direct pushes to main. Tune for Scorecard: signed commits, stale review dismissal, no force-push. |
| T070 | Add CODEOWNERS for infra-critical paths | P2 | TODO | DR2:I-030 | S | — | Add `CODEOWNERS` file covering GitOps overlays (`deploy/k8s/overlays/production/`), GitHub Actions workflows, and secrets configs. Require owner review for those paths. |
| T019 | Add patch idempotency tests | P1 | TODO | NEW | M | T018 | Each patch module should be testable in isolation (run twice, same result). Add to `tests/tutor/`. |
| T021 | Verify no `latest` tags in production overlays | P1 | TODO | NEW | S | T020 | `verify-no-latest-prod-tags.sh` exists but not wired into CI as a blocking gate. Wire it. Enforce digest-only refs in production overlays — no tag-only references allowed. |
| T017 | Validate SITE_VARIANTS + multisite config | P1 | TODO | NEW | M | — | `multisite-sites.dev.yml` and `SITE_VARIANTS` dict need a CI validation job that catches schema drift. |
| T071 | Add smoke tests for authn MFE config endpoint | P1 | TODO | DR2:I-035 | M | — | Add automated checks for: authn MFE config endpoint returns valid JSON, cookie domain is correct for each tenant, OAuth redirect URIs match config. |
| T072 | Add automated tenant isolation tests | P1 | TODO | DR2:I-036 | L | T011 | Automated tests that verify tenant A cannot access tenant B's data for: auth tokens, analytics events, branding assets. |
| T049 | E2E test framework (Playwright) | P3 | TODO | I26 | L | T011 | Only shell smoke tests exist. Add Playwright with 5 critical-path tests: login, enroll, play video, forum post, certificate. |
| T050 | Wire E2E into post-deploy gate | P3 | TODO | NEW | S | T049 | Once Playwright exists, add as a blocking step in `release-evidence.yml`. |
| T073 | Add visual regression baseline governance | P2 | TODO | DR2:I-038 | M | — | Define approval process for visual regression baseline images and add drift alerts (e.g., Percy or Chromatic). Prevents silent UI regressions from Tutor/MFE upgrades. |
| T074 | Add TTFS onboarding flow tests | P3 | TODO | DR2:I-039 | M | — | Add "time-to-first-success" tests that simulate a new learner completing registration, enrollment, and first lesson. Tracks onboarding funnel health. |

---

## Sprint 3: Platform Stability & Migration (P1)

*RKE2 hardening, MFE migration, branding, apply-patches refactor. Unblocks enterprise features.*

| ID | Title | Priority | Status | Source | Effort | Deps | Description |
|----|-------|----------|--------|--------|--------|------|-------------|
| T007 | Fix RKE2 ecommerce-worker CrashLoop | P0 | PARTIAL | 1jsy | M | — | ecommerce-worker crashes on nonprod; payments-gateway parity gap. Partially investigated. |
| T008 | Resolve Argo app stale Degraded | P0 | PARTIAL | 3bm2 | M | — | ArgoCD shows Degraded for fully-synced apps. Root cause in health check config; partially traced. |
| T009 | RKE2 operational hardening | P0 | PARTIAL | aza7 | L | T007, T008 | PodDisruptionBudgets, resource limits, HPA baselines, runbook links for all critical workloads. |
| T010 | MFE Dockerfile Ulmo migration | P1 | PARTIAL | 2s47 | L | — | Systematically update all MFE source refs from `release/nutmeg` / `release/palm` to `release/ulmo.1`. Tracked in bead 2s47. |
| T011 | Validate LMS on rke2-nonprod | P1 | PARTIAL | 5ngf.2 | M | T010 | Smoke tests, routing checks, cutover readiness gate. Evidence partially collected. |
| T012 | RKE2 nonprod smoke + tenant route matrix | P1 | PARTIAL | 288f | M | T011 | Full tenant route matrix (all hostnames × HTTP methods × auth states). Partially captured. |
| T013 | RKE2 LMS migration completion plan | P1 | PARTIAL | 5ngf | L | T011, T012 | Final cutover plan: DNS flip, rollback criteria, on-call schedule, post-cutover verification. |
| T014 | BoldBadger: RKE2 end-to-end rollout | P1 | PARTIAL | 3st7 | L | T009, T013 | Final hardening and handoff checklist for RKE2-nonprod as production-ready lane. |
| T015 | Footer parity: port v2 footer into LMS/MFEs | P1 | TODO | 1kwf.1 | M | — | Plugin-first approach. Mereka Frontend v2 footer not yet ported into Tutor plugin or MFE slot. |
| T016 | WhiteCliff brand/plugin parity lane | P1 | PARTIAL | 1kwf | L | T015 | Studio surfaces, footer, all MFE surfaces. Superset of T015. |
| T018 | Refactor apply-patches.sh into composable units | P1 | TODO | NEW | L | — | Script is 1666 lines. Split into per-concern patch files (mysql-auth, mfe-node, domains, etc.) called from a thin orchestrator. Reduces diff noise and merge conflicts. |
| T020 | Automate image tag promotion in Kustomize | P1 | TODO | NEW, DR2:I-007 | M | — | Production Kustomize overlays have manually managed image tags. Enforce digest-only refs in production overlays (no tag-only). Add a CI step or script to bump tags/digests from the built SHA on merge to main. |
| T024 | Scheduled park/unpark validation | P1 | TODO | NEW | S | — | Park/unpark scripts exist but need a monthly dry-run CI job to confirm they still work after cluster changes. |
| T044 | Clarify Tutor 21.0.0 patch level | P3 | TODO | NEW, DR2:I-047 | S | T042 | Tutor Ulmo may have patch releases. Confirm pinned patch version in CI. Also: create a spike branch with compatibility test suite and rollback plan for next Ulmo upgrade. Document update process. |
| T075 | Add ArgoCD drift detection + alerting | P2 | TODO | DR2:I-034 | M | — | Add alerting for ArgoCD "Synced but wrong" cases (drift between git and live). Cross-repo: bbi-infrastructure. Configure Prometheus alerting on `argocd_app_info` where sync_status=Synced but health_status!=Healthy. |
| T045 | MongoDB Atlas: dev seed script | P3 | TODO | NEW | M | — | Atlas is the only MongoDB option (no local fallback). Add a `scripts/infra/seed-mongo-dev.sh` that populates a dev Atlas cluster from fixtures so new devs don't need prod access. |
| T046 | MongoDB Atlas: connection health in CI | P3 | TODO | NEW | S | — | Add a lightweight CI job that validates Atlas SRV connectivity using a test-only account. Currently no CI signal for Atlas reachability. |
| T047 | Wire Credential/Notes service into smoke matrix | P3 | TODO | NEW | S | T011 | Both services are deployed but not in the post-deploy smoke checklist. Add to `scripts/qa/smoke-test.sh`. |
| T048 | preview.academyv2.mereka.io redirect | P3 | TODO | bims | S | — | Add /dashboard redirect and explanation page per bead bims. |
| T051 | Enterprise MFE Dockerfile maintenance process | P3 | TODO | NEW | S | T010 | Custom Dockerfiles for enterprise portals diverge from upstream on each Ulmo patch. Add a `docs/operations/ENTERPRISE_MFE_MAINTENANCE.md` with diff-and-rebase checklist. |

#### T007 Plan: ecommerce-worker CrashLoop

**When ready** (K8s work deferred):
1. `kubectl logs -n mereka-lms -l app=enterprise-access-worker --previous` — get crash reason
2. Likely causes: missing env var, DB connection refused, or memory OOM (we already added `--concurrency=2`)
3. Check if payments-gateway service exists in RKE2 namespace or if ecommerce-worker references a service that doesn't exist yet
4. Fix config or resource limits, verify with `kubectl get pods -w`

#### T008 Plan: ArgoCD stale Degraded

**When ready**:
1. `kubectl get app -n argocd -o yaml | grep -A5 health` — check health assessment rules
2. Likely cause: custom health check lua script missing for a CRD, or a resource reports unhealthy status that ArgoCD doesn't know how to interpret
3. Fix: add custom health check in ArgoCD ConfigMap, or fix the underlying resource health
4. Verify: `argocd app get <name> --refresh`

#### T010 Plan: MFE Ulmo migration

**Problem**: MFE Dockerfiles and source refs may still point at older release branches (nutmeg/palm/quince). The Tutor Ulmo build expects `release/ulmo.1` tags. Stale refs cause build failures or silently ship old code.

**Steps**:
1. Inventory: grep all Dockerfiles, `apply-patches.sh`, and `mfe-build/Dockerfile` for MFE git refs (branch names, tags, commit SHAs)
2. Cross-reference against Open edX Ulmo release tags for each MFE (learning, authn, discussions, profile, account, gradebook, etc.)
3. Update refs to `release/ulmo.1` (or latest Ulmo-compatible tag)
4. Build locally: `tutor images build mfe` and confirm all MFEs compile
5. Run `verify-mfe-ulmo-migration.sh` (already exists) to confirm
6. Update `infrastructure/tutor/mfe-build/README.md` with the ref table

#### T018 Plan: apply-patches.sh refactor

**Problem**: Single 1666-line Python-embedded-in-bash script. Every Tutor config change, branding tweak, or MFE update touches it. Merge conflicts are frequent. No tests. Failure mode is silent (patches silently don't apply if markers drift).

**Current patch concerns** (audit needed to confirm exact count):
- MySQL 8 auth plugin fix
- MFE Node 18 build toolchain (g++, python3)
- Extra domain names (biji-biji.com, skillourfuture)
- Webpack memory limit (NODE_OPTIONS)
- CSRF trusted origins + allowed hosts
- Custom Mereka footer component for MFEs
- Prometheus metrics integration
- MongoDB Atlas SRV support
- Custom apps COPY + pip install (mfe_oauth_fix, openedx_prometheus, mereka_tenancy)
- Build optimizations and retry logic

**Target architecture**:
```
infrastructure/tutor/patches/
├── 00-mysql-auth.py
├── 01-mfe-node-toolchain.py
├── 02-extra-domains.py
├── 03-webpack-memory.py
├── 04-csrf-hosts.py
├── 05-mereka-footer.py
├── 06-prometheus.py
├── 07-mongodb-atlas-srv.py
├── 08-custom-apps.py
├── 09-build-optimizations.py
└── apply-all.sh          # thin orchestrator: loops patches, verifies each
```

**Steps**:
1. Inventory: read apply-patches.sh, identify every discrete patch concern and its markers
2. Extract: one `.py` file per concern, each with `apply(content) -> content` signature
3. Orchestrator: `apply-all.sh` sources config, runs each patch, runs `verify-tutor-config.sh`
4. Test: for each patch module, add a test in `tests/tutor/` that applies twice and asserts idempotency
5. Migration: replace `apply-patches.sh` with `apply-all.sh`, update all docs and scripts that reference it

**Risk**: High — this script is load-bearing. Must be done on a branch with before/after diff comparison of generated Tutor output. Run `tutor config save && apply-patches.sh` on both old and new, diff the results.

#### T020 Plan: image tag automation

**Problem**: `deploy/k8s/overlays/production/kustomization.yaml` has hardcoded image tags like `mereka-brand-hotfix-full-v3` and `1c66529-20260220023917`. Tags are bumped by hand in PRs. This caused the merge conflict in PR #90 and will keep causing conflicts. Production overlays must reference digests (not tags) to guarantee immutability.

**Current state**: `build-tutor-images.yml` builds and pushes images tagged with git SHA. But nothing updates the Kustomize overlay to reference the new tag.

**Options**:
- **A) kustomize edit set image in CI** — after image push, a CI step runs `kustomize edit set image` and commits. Simple but creates auto-commits on main.
- **B) Renovate/Dependabot for image tags** — external bot opens PRs when new tags appear in registry. More reviewable but adds latency.
- **C) Script + manual trigger** — `scripts/infra/bump-image-tags.sh` queries Artifact Registry for latest SHA-tagged images and updates kustomization.yaml. Dev runs it, reviews diff, commits. Low-tech, high-control.

**Recommendation**: Option C first (least risky, most transparent), graduate to A or B later. Phase 2: convert to digest-pinned refs (`image@sha256:...`) as T021 enforcement requires.

**Steps**:
1. Write `scripts/infra/bump-image-tags.sh` that queries `gcloud artifacts docker tags list` for each image in kustomization.yaml
2. Script outputs a diff preview before writing
3. Add to `release-openedx-gitops.sh` as an optional step
4. Wire T021: CI job that greps production kustomization for `:latest` and fails if found

---

## Sprint 4: Enterprise Features & Compliance (P1–P2)

*Video, purchase gateway, accessibility, privacy, tenant isolation, LTI/SAML, localization.*

| ID | Title | Priority | Status | Source | Effort | Deps | Description |
|----|-------|----------|--------|--------|--------|------|-------------|
| T025 | Video: full Mux + XBlock + Analytics pipeline | P1 | PARTIAL | 1bdm | L | — | Mux upload, XBlock playback, analytics events. 37 ACs tracked in epic 1bdm. Partially implemented. |
| T026 | Mux alert wiring | P2 | TODO | NEW | S | T025 | `verify-mux-alerts.sh` exists but Mux asset-status webhook → Alertmanager route needs validation in nonprod. |
| T027 | Purchase gateway: complete Stripe integration | P2 | PARTIAL | NEW | L | — | FastAPI scaffold exists (`services/purchase-gateway/`). Stripe webhook handler, order lifecycle, and refund flow need completion per `specs/ecommerce-purchase-gateway_spec.md`. |
| T028 | Purchase gateway: K8s production deployment | P2 | TODO | NEW | M | T027 | `k8s/` dir inside purchase-gateway exists but no ArgoCD Application manifest. Wire into `deploy/k8s/base/`. |
| T029 | Deprecate Oscar ecommerce references | P2 | TODO | NEW | S | T028 | Audit and remove Oscar-era config from Tutor env and docs once purchase-gateway is live. |
| T030 | Forum service: Meilisearch dependency validation | P2 | TODO | NEW | S | — | openedx-forum v0.3.8 depends on Meilisearch. Confirm Meilisearch is deployed in RKE2 nonprod and indexed. No evidence file exists. |
| T031 | Forum service: smoke test in RKE2 | P2 | TODO | NEW | S | T030, T011 | Add forum to post-deploy smoke matrix (create thread, reply, search). |
| T032 | Mobile: deploy enterprise mobile apps | P2 | PARTIAL | mci9 | L | T011 | 37 ACs in epic mci9. iOS TestFlight CI exists (`build-ios-app.yml`). Backend API and push notifications need completion. |
| T033 | Mobile secrets runtime validation | P2 | TODO | NEW | S | T032 | `verify-mobile-secrets-runtime.sh` exists but not in CI. Wire as a post-deploy gate. |
| T034 | GDPR cookie consent UI + user retirement pipeline | P2 | PARTIAL | I21, DR2:I-021 | M | — | Spec and policy exist but no cookie banner implemented. Enrich: add Open edX user retirement pipeline integration and custom service PII cleanup hooks (purchase-gateway, analytics). |
| T035 | LTI integration guide + SAML config alignment | P2 | PARTIAL | I17, DR2:I-022, DR2:I-050 | S | — | LTI referenced in specs. Write `docs/integrations/LTI.md` with Open edX LTI consumer config steps. Add SAML config presence check and metadata endpoint verification. Align to official Open edX operator docs. |
| T036 | Accessibility: WCAG 2.2 AA compliance | P2 | PARTIAL | I44, DR2:I-009 | M | — | Policy doc and manual scripts exist. Wire axe-core as automated CI check on key routes. Enrich: add Focus Not Obscured (SC 2.4.12), Target Size (SC 2.5.8), and Accessible Authentication (SC 3.3.8) beyond existing contrast checks. |
| T037 | Atlas/Transifex translation pipeline | P2 | PARTIAL | I42, DR2:I-037 | M | — | Bilingual (EN/MS) mentioned in cross-cutting spec. Add `scripts/infra/sync-translations.sh` using `openedx-atlas` CLI. Add MFE locale file completeness check to CI. |
| T076 | Implement Reusable LTI Store (Ulmo feature) | P2 | TODO | DR2:I-023 | L | T035 | Implement or verify the Reusable LTI Store feature introduced in Ulmo. Configure and test LTI tool persistence across course contexts. |
| T077 | Add Policy-as-Code for pod security standards | P2 | TODO | DR2:I-024 | L | — | Implement Kyverno or Gatekeeper policies enforcing pod security standards (non-root, no privileged, seccomp). Cross-repo: bbi-infrastructure. |
| T078 | ExternalSecrets refresh + failure alerting | P1 | TODO | DR2:I-040 | M | — | Add tests and Prometheus alerts for ExternalSecrets refresh failures and stale secrets (last sync > 2h). Cross-repo: bbi-infrastructure. |
| T079 | Analytics data retention as tested config | P2 | TODO | DR2:I-045 | M | — | Encode Aspects analytics data retention policy as configuration (lifecycle rules). Add CI test that validates retention config matches the documented policy. |
| T080 | Add security incident runbook (supply-chain) | P2 | TODO | DR2:I-046 | M | — | Write `docs/operations/SECURITY_INCIDENT_SUPPLY_CHAIN.md` covering: detection signals, isolation steps, comms template, post-incident review checklist. |
| T081 | Create security exceptions register | P2 | TODO | DR2:I-048 | M | — | Create a tracked register of accepted security exceptions with expiry dates. Add a CI job that fails if any exception is past its expiry date. |

#### T027 Plan: purchase gateway completion

**Problem**: Oscar ecommerce is legacy and being replaced by a custom FastAPI + PostgreSQL + Stripe service. The scaffold exists at `services/purchase-gateway/` but is incomplete. The spec exists at `specs/ecommerce-purchase-gateway_spec.md`.

**What exists** (needs audit to confirm):
- FastAPI app structure
- Database models (probably SQLAlchemy/SQLModel)
- K8s directory inside the service

**What's likely missing**:
- Stripe webhook handler (checkout.session.completed, payment_intent.succeeded, charge.refunded)
- Order lifecycle state machine (pending → paid → fulfilled → refunded)
- Enrollment trigger on successful payment (call Open edX enrollment API)
- Refund flow
- Admin dashboard or at minimum admin API
- Tests

**Steps**:
1. Audit: read the spec and the existing code, produce a gap list
2. Plan: break into sub-tasks with AC from the spec
3. Implement: Stripe webhooks → order model → enrollment trigger → refund
4. Test: unit tests for each handler, integration test with Stripe test mode
5. Deploy: T028 handles K8s wiring

**Dependency**: needs a product decision on pricing model (per-course? subscription? bundles?) before implementation can finish. Flag this early.

---

## Sprint 5: Polish, Governance & Scale (P2–P3)

*Release strategy, DR drills, observability, container hardening, backlog items.*

| ID | Title | Priority | Status | Source | Effort | Deps | Description |
|----|-------|----------|--------|--------|--------|------|-------------|
| T042 | Document Tutor upgrade cadence + EOL policy | P3 | TODO | I05, DR2:I-019, DR2:I-047 | S | — | Add `docs/adr/002-tutor-upgrade-policy.md` with explicit Redwood vs Ulmo decision, migration timeline, and who decides upgrades. Include Tutor EOL dates. |
| T082 | Publish release evidence bundle + retention policy | P2 | TODO | DR2:I-031 | M | — | Define what constitutes a "release evidence bundle" (test results, SBOM, scan report, deploy log). Automate assembly in CI and define a retention policy (e.g., 90 days in GCS). |
| T083 | Standardize OpenTelemetry naming + dashboard contract tests | P2 | TODO | DR2:I-025 | M | — | Standardize OTEL metric/trace naming conventions. Add contract tests that verify dashboards reference only known metric names (prevents silent dashboard breakage on rename). |
| T084 | Add Lighthouse CI + bundle budgets + INP metric | P2 | TODO | DR2:I-026 | M | — | Add Lighthouse CI to post-deploy pipeline. Define bundle size budgets per MFE. Update from FID → INP (Interaction to Next Paint) metric per Core Web Vitals v4. |
| T085 | Formalize staging activation path | P2 | TODO | DR2:I-027 | L | — | Document and implement the promotion path from nonprod → staging → production in bbi-infrastructure. Cross-repo: bbi-infrastructure. |
| T086 | Convert DR evidence into scheduled backup/restore drills | P1 | TODO | DR2:I-044 | L | — | Convert one-off DR evidence into recurring scheduled drills (monthly). Add enforced gates: drill must pass before production releases. Cross-repo: bbi-infrastructure. |
| T087 | Container hardening (non-root, read-only FS, seccomp) | P2 | TODO | DR2:I-043 | L | — | Enforce non-root runtime user, read-only root filesystem, and seccomp/AppArmor profiles for all LMS containers. Coordinate with T077 (policy-as-code). |
| T038 | Course data recovery (MCT + Kajabi) | P4 | BLOCKED | 1qo | L | T039 | Recovery plan blocked on artifact availability. See bead 1qo. |
| T039 | Restore MCT/Kajabi courses into Atlas | P4 | BLOCKED | hd3 | L | — | Prerequisite artifacts needed. See bead hd3. |
| T040 | Run Kajabi dry-run import | P4 | BLOCKED | 2hj | M | T039 | Blocked on T039. See bead 2hj. |
| T041 | Proctoring: integrate enterprise proctoring | P4 | TODO | i8lo | L | T011 | 38 ACs in epic i8lo. Requires stable RKE2 production cluster first. |

---

## Dependency Graph

```
T003 (.tool-versions)
T002 (pip-audit + vuln gate)
T052 (SHA pin actions) → T053 (allowed-actions policy)
T052 → T054 (SLSA attestations) ← T092 (WIF/OIDC)
T063 (pin runners)

T006 (Scorecard) → T069 (branch protection)
T060 (dependency review) ← T006
T022 (coverage gate) → T023 (pg tests)
T065 (CodeQL) ← T052

T007 + T008 → T009 (hardening) → T014 (BoldBadger rollout)
T010 (MFE migration) → T011 (validate LMS) → T012 (smoke matrix) → T013 (cutover plan) → T014

T015 (footer) → T016 (WhiteCliff parity)
T018 (refactor patches) → T019 (idempotency tests)
T020 (image tag automation) → T021 (no-latest gate)
T027 (purchase gateway) → T028 (K8s deploy) → T029 (deprecate Oscar)
T030 (Meilisearch) → T031 (forum smoke)
T035 (LTI) → T076 (Reusable LTI Store)
T039 (Atlas restore) → T040 (Kajabi dry-run) ← T038
T049 (Playwright) → T050 (E2E gate)
T042 (upgrade policy) → T044 (Ulmo spike)
T077 (policy-as-code) ← T087 (container hardening)
T082 (evidence bundle) ← T086 (DR drills)
```

---

## Quick Filters

**Do next (unblocked P0/P1 TODOs, small effort)**:
T001, T003, T006, T022, T024, T052, T057, T058, T060, T061, T063, T069, T091

**Ready after first wave (deps on items above)**:
T053 (needs T052), T021 (needs T020), T054 (needs T052+T092), T065 (needs T052)

**Active bead work (PARTIAL)**:
T007, T008, T009, T010, T011, T012, T013, T014, T015, T016, T025, T027, T032, T034

**Sequenced — waiting on cluster stability (T011)**:
T028, T031, T033, T041, T047, T050, T072

**Blocked — waiting on data artifacts**:
T038, T039, T040

**Cross-repo: bbi-infrastructure**:
T053, T057, T075, T077, T078, T085, T086

**Cross-repo: platform-control-plane**:
T058

---

## DR2 Cross-Reference Index

| DR2 ID | Title (abbreviated) | Tracker ID | Status |
|--------|---------------------|------------|--------|
| I-001 | Pin GitHub Actions to commit SHAs | T052 | TODO |
| I-002 | Enforce org/repo allowed-actions policy | T053 | TODO |
| I-003 | SBOM for images (Syft/Anchore, OCI attestation) | T005 | TODO (enriched) |
| I-004 | Build provenance/SLSA attestations | T054 | TODO |
| I-005 | Vuln scanning blocking for releases | T002 | TODO (enriched) |
| I-006 | Render Tutor env in CI (fix idempotency skip) | T055 | TODO |
| I-007 | Digest pinning in production overlays | T020/T021 | TODO (enriched) |
| I-008 | Cache-Control headers in MFE Caddyfile | T056 | TODO |
| I-009 | WCAG 2.2 AA (Focus Not Obscured, Target Size, etc.) | T036 | PARTIAL (enriched) |
| I-010 | Enable CodeQL SAST workflow | T065 | TODO |
| I-011 | Add Dependency Review workflow | T060 | TODO |
| I-012 | Add Dependabot for pip/npm/terraform | T061 | TODO |
| I-013 | Standardize minimal workflow permissions | T091 | TODO |
| I-014 | Replace JSON SA key with Workload Identity Federation | T092 | TODO |
| I-015 | Pin tool binary downloads in bbi-infrastructure CI | T057 | TODO |
| I-016 | Pin tool binary downloads in platform-control-plane CI | T058 | TODO |
| I-017 | Add GitHub Advanced Security secret scanning | T059 | TODO |
| I-018 | Establish spec coverage floor per PR | T066 | TODO |
| I-019 | Release track ADR (Redwood vs Ulmo decision) | T042 | TODO (enriched) |
| I-020 | Aspects version compatibility enforcement test | T067 | TODO |
| I-021 | User retirement PII pipeline | T034 | PARTIAL (enriched) |
| I-022 | SAML config alignment + metadata endpoints | T035 | PARTIAL (enriched) |
| I-023 | Implement Reusable LTI Store (Ulmo feature) | T076 | TODO |
| I-024 | Policy-as-Code for pod security standards | T077 | TODO |
| I-025 | Standardize OTel naming + dashboard contract tests | T083 | TODO |
| I-026 | Lighthouse CI + bundle budgets + INP metric | T084 | TODO |
| I-027 | Formalize staging activation path | T085 | TODO |
| I-028 | Add repo-level PR template | T068 | TODO |
| I-029 | Require PR reviews + status checks (Scorecard) | T069 | TODO |
| I-030 | Add CODEOWNERS for infra-critical paths | T070 | TODO |
| I-031 | Publish release evidence bundle + retention policy | T082 | TODO |
| I-032 | Pin runner images to ubuntu-24.04 | T063 | TODO |
| I-033 | Replace PAT-based GitOps with GitHub App token | T062 | TODO |
| I-034 | ArgoCD drift detection + alerting for "Synced but wrong" | T075 | TODO |
| I-035 | Smoke tests for authn MFE config + cookie domain | T071 | TODO |
| I-036 | Automated tenant isolation tests | T072 | TODO |
| I-037 | Translation pipeline (openedx-atlas + MFE locale checks) | T037 | PARTIAL (enriched) |
| I-038 | Visual regression baseline governance | T073 | TODO |
| I-039 | TTFS onboarding flow tests | T074 | TODO |
| I-040 | ExternalSecrets refresh interval + failure alerting | T078 | TODO |
| I-041 | Terraform drift detection (tfsec/checkov + plan output) | T004 | TODO (enriched) |
| I-042 | Trivy config scanning for K8s manifests + Terraform | T004 | TODO (enriched) |
| I-043 | Container hardening (non-root, read-only FS, seccomp) | T087 | TODO |
| I-044 | Scheduled backup/restore drills with enforced gates | T086 | TODO |
| I-045 | Analytics data retention as tested config | T079 | TODO |
| I-046 | Security incident runbook (supply-chain) | T080 | TODO |
| I-047 | Ulmo upgrade spike (compat test suite + rollback plan) | T042/T044 | TODO (enriched) |
| I-048 | Security exceptions register with expiry + CI enforcement | T081 | TODO |
| I-049 | Commit signing (Sigstore/GitHub) + CI verification | T064 | TODO |
| I-050 | SSO/SAML/LTI docs aligned to official Open edX operator pages | T035 | PARTIAL (enriched) |
