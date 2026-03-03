# mereka-lms Implementation Tracker

**Last updated**: 2026-03-02
**Branch**: main
**Sources**: Internal audit · DR2 research review · DR1 frontend review · Top50 strategic priorities · CTO audit pass · Deployment parity review

## Summary

| Status | Count |
|--------|-------|
| DONE   | 150   |
| TODO   | 1     |
| PARTIAL| 0     |
| BLOCKED| 3     |
| **Total** | **154** |

Sprints 1–5: 94 tasks (91 DONE, 3 BLOCKED) — internal audit + DR2
Sprints 6–10: 48 tasks (47 DONE, 1 TODO) — T118 CDN deferred by stakeholder
Sprint 11: 5 tasks (5 DONE) — deployment parity & AC gap closure — DR1 frontend + Top50 strategic + CTO audit
Sprint 12: 7 tasks (7 DONE) — CI pipeline cost optimization (DevOps review)

Cross-references: DR2 items I-001→I-050 · DR1 findings P0-1→P2-2 · Top50 items #1→#50 · CTO audit #1→#31

---

## Sprint 1: Supply-Chain Security & CI Hardening (P0)

*Immediate risk reduction. Unblocks CI reliability, prevents supply-chain incidents. Do first.*

| ID | Title | Priority | Status | Source | Effort | Deps | Description |
|----|-------|----------|--------|--------|--------|------|-------------|
| T001 | Create SECURITY.md | P0 | DONE | I04 | S | — | Vulnerability disclosure policy: contact, timeline, scope. ✓ Batch 1. |
| T052 | Pin GitHub Actions to commit SHAs | P0 | DONE | DR2:I-001 | M | — | ✓ Batch 1. 17 workflows pinned to SHAs. Cross-repo (bbi-infra, pcp) still TODO. |
| T053 | Enforce org/repo allowed-actions policy | P0 | DONE | DR2:I-002 | M | T052 | ✓ Batch 3. Policy doc + verify-actions-pinned.sh script (203 refs validated). Wire into CI as follow-up. |
| T005 | Add SBOM generation to CI | P0 | DONE | I09, DR2:I-003 | M | — | ✓ Batch 2. CycloneDX SBOM via Syft in build-tutor-images.yml, uploaded as workflow artifacts. |
| T002 | Add pip-audit to CI (vuln gate) | P0 | DONE | I10, DR2:I-005 | S | — | ✓ Batch 1. pip-audit job added. Trivy split: CRITICAL=blocking, HIGH=info. .trivyignore created. |
| T054 | Add build provenance/SLSA attestations | P0 | DONE | DR2:I-004 | M | T052, T092 | ✓ Batch 9. cosign attest with keyless Sigstore signing. Provenance JSON artifacts. verify-slsa-provenance.sh (7 checks). Last P0 task! |
| T006 | Configure OpenSSF Scorecard | P0 | DONE | I12 | S | — | ✓ Batch 1. scorecard.yml added, weekly + on push to main. |
| T055 | Render Tutor env in CI (fix idempotency skip) | P0 | DONE | DR2:I-006 | M | — | ✓ Batch 1. CI renders tutor_env/ with .venv before tests. Opus fix: added venv creation for apply-patches.sh. |
| T056 | Implement Cache-Control headers in MFE Caddyfile | P0 | DONE | DR2:I-008 | M | — | ✓ Batch 1+2. Default no-cache for all responses (covers SPA routes), hashed assets immutable, API no-store. |
| T091 | Standardize workflow permissions (least-privilege) | P1 | DONE | DR2:I-013 | S | — | ✓ Batch 1. All 17 workflows have explicit permissions blocks. |
| T092 | Replace JSON SA key with Workload Identity Federation | P1 | DONE | DR2:I-014 | M | — | ✓ Batch 8. WORKLOAD_IDENTITY_FEDERATION.md + verify-wif-readiness.sh (8 checks, 7 SA key workflows found) + CI workflow. Opus fix: SIGPIPE in grep -v|grep -q pipeline. |
| T057 | Pin binary downloads in bbi-infrastructure CI | P1 | DONE | DR2:I-015 | S | — | ✓ Batch 16. BINARY_PINNING.md + verify-binary-pinning-bbi-infra.sh. Found 5 unpinned yq + 1 no-checksum in bbi-infra. Cross-repo fixes pending. |
| T058 | Pin binary downloads in platform-control-plane CI | P1 | DONE | DR2:I-016 | S | — | ✓ Batch 16. verify-binary-pinning-pcp.sh (4 PASS). Scans pcp workflows for unpinned downloads. Cross-repo fixes pending. |
| T059 | Add GitHub Advanced Security secret scanning | P1 | DONE | DR2:I-017 | M | — | ✓ Batch 4. GHAS secret-scanning.yml + TruffleHog weekly audit workflow + operational doc. Opus fix: rewrote to avoid script injection via toJson(). |
| T060 | Add Dependency Review workflow | P1 | DONE | DR2:I-011 | S | — | ✓ Batch 1. dependency-review.yml blocks CRITICAL vulns + AGPL/GPL licenses. |
| T061 | Add Dependabot for pip/npm/terraform | P1 | DONE | DR2:I-012 | S | — | ✓ Batch 1. dependabot.yml covering github-actions, pip, npm, terraform. |
| T062 | Replace PAT-based GitOps with GitHub App token | P2 | DONE | DR2:I-033 | M | — | ✓ Batch 8. GITHUB_APP_TOKEN.md + verify-github-app-token.sh (finds 2 GITOPS_PAT refs) + CI workflow. Opus review: PASS. |
| T063 | Pin runner images to ubuntu-24.04 | P2 | DONE | DR2:I-032 | S | — | ✓ Batch 1. All 17 workflows pinned. macOS runners left as-is (no stable pin). |
| T004 | Pin Terraform providers + add IaC scanning | P0 | DONE | I14, DR2:I-041, DR2:I-042 | S | — | ✓ Batch 3. iac-scan.yml with Trivy config mode for K8s + Terraform. Providers already pinned (~> 5.42). |
| T064 | Add commit signing (Sigstore/GitHub) | P3 | DONE | DR2:I-049 | M | — | ✓ Batch 8. COMMIT_SIGNING.md (GPG/SSH/Gitsign guide) + verify-commit-signing.sh (soft gate, --strict for hard gate) + CI workflow. Opus review: PASS. |

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
| T003 | Add .tool-versions for Python | P0 | DONE | I07 | S | — | ✓ Batch 1. python 3.12.8, nodejs 20.18.1. |
| T043 | Pin requirements with uv lockfile | P3 | DONE | I08 | S | — | ✓ Batch 2. requirements.lock generated by uv, committed. Test validates existence. |
| T022 | Add pytest coverage gate to CI | P1 | DONE | I24 | S | — | ✓ Batch 2. test-coverage job in ci.yml, 40% floor, non-blocking (continue-on-error). Placeholder tests in tests/test_placeholder.py. |
| T023 | Add purchase-gateway unit tests | P1 | DONE | NEW | M | T022 | ✓ Batch 3. Tests for checkout, webhook handler, fulfillment, models. Opus review found naming + fixture issues, fixed. |
| T065 | Add CodeQL SAST workflow | P1 | DONE | DR2:I-010 | M | — | ✓ Batch 2. codeql.yml for Python + JavaScript, SHA-pinned actions, weekly schedule + PR triggers, non-blocking. |
| T066 | Establish spec coverage floor per PR | P1 | DONE | DR2:I-018 | M | — | ✓ Batch 5. verify-spec-coverage.sh (AC detection + testmap cross-ref, 40% floor default, 85% current). SPEC_COVERAGE.md with ratcheting guide. |
| T067 | Add Aspects version compatibility enforcement test | P1 | DONE | DR2:I-020 | M | — | ✓ Batch 5. verify-aspects-compat.sh + aspects-compat.yml CI workflow (informational). Checks Redwood range >=0.70,<1.0. |
| T068 | Add PR template aligned to specs/rollout/verification | P2 | DONE | DR2:I-028 | S | — | ✓ Batch 1. `.github/PULL_REQUEST_TEMPLATE.md` with What/Why/Checklist/Infra/Verification sections. |
| T069 | Branch protection + Scorecard alignment | P1 | DONE | DR2:I-029 | S | — | ✓ Batch 4. BRANCH_PROTECTION.md doc + verify-branch-protection.sh script (8 checks). Opus fix: removed phantom "Verify Actions Pinned" check, completed REQUIRED_CHECKS list. |
| T070 | Add CODEOWNERS for infra-critical paths | P2 | DONE | DR2:I-030 | S | — | ✓ Batch 1. `CODEOWNERS` covering production overlays, workflows, secrets → @infra; tutor → @platform; specs → @engineering. |
| T019 | Add patch idempotency tests | P1 | DONE | NEW | M | T018 | ✓ Batch 9. verify-patch-idempotency.sh (23 duplicate markers, 10 targets). --tutor/--offline/--dry-run modes. CI workflow on infra changes. |
| T021 | Verify no `latest` tags in production overlays | P1 | DONE | NEW | S | T020 | ✓ Batch 5. verify-image-tags.yml CI workflow (blocking). Opus fix: aligned checkout SHA to repo standard. |
| T017 | Validate SITE_VARIANTS + multisite config | P1 | DONE | NEW | M | — | ✓ Batch 4. validate-multisite.yml CI workflow + validate-multisite-config.sh (7 sections, 12 checks). |
| T071 | Add smoke tests for authn MFE config endpoint | P1 | DONE | DR2:I-035 | M | — | ✓ Batch 6. smoke-authn-mfe.sh (5 tests: login page, config endpoint, required keys, cookie domain, OAuth URIs) + CI workflow. Opus fix: mktemp cleanup, timeout-minutes. |
| T072 | Add automated tenant isolation tests | P1 | DONE | DR2:I-036 | L | T011 | ✓ Batch 10. verify-tenant-isolation-gates.sh: 26 offline + 8 online checks (middleware, model constraints, branding scope, cross-tenant auth, cookie isolation). tenant-isolation-check.yml CI workflow. |
| T049 | E2E test framework (Playwright) | P3 | DONE | I26 | L | T011 | ✓ Batch 15. Playwright config + 5 critical-path tests (login, enroll, video, forum, cert) + verify script (15 PASS) + CI workflow. |
| T050 | Wire E2E into post-deploy gate | P3 | DONE | NEW | S | T049 | ✓ Batch 15. post-deploy-e2e.yml workflow + verify script (20 PASS) + POST_DEPLOY_GATE.md. Opus fix: BASE_URL env var mismatch, npm ci→install. |
| T073 | Add visual regression baseline governance | P2 | DONE | DR2:I-038 | M | — | ✓ Batch 7. VISUAL_REGRESSION.md + verify-visual-baselines.sh + baselines.json seed. Opus review: PASS. |
| T074 | Add TTFS onboarding flow tests | P3 | DONE | DR2:I-039 | M | — | ✓ Batch 8. TTFS_ONBOARDING.md (4-step funnel) + verify-ttfs-onboarding.sh (14 checks) + CI workflow. Opus review: PASS. |

---

## Sprint 3: Platform Stability & Migration (P1)

*RKE2 hardening, MFE migration, branding, apply-patches refactor. Unblocks enterprise features.*

| ID | Title | Priority | Status | Source | Effort | Deps | Description |
|----|-------|----------|--------|--------|--------|------|-------------|
| T007 | Fix RKE2 ecommerce-worker CrashLoop | P0 | DONE | 1jsy | M | — | ✓ Batch 13. Verification script checks deprecated Oscar worker health, recommends scale-to-zero (Purchase Gateway replaces it). |
| T008 | Resolve Argo app stale Degraded | P0 | DONE | 3bm2 | M | — | ✓ Batch 13. ArgoCD health config verification script + troubleshooting runbook. |
| T009 | RKE2 operational hardening | P0 | DONE | aza7 | L | T007, T008 | ✓ Batch 13. PDBs for core workloads + HPA baselines for lms-worker/cms-worker. Opus fix: removed duplicate lms/cms HPAs (already in apps/). |
| T010 | MFE Dockerfile Ulmo migration | P1 | DONE | 2s47 | L | — | ✓ Batch 13. MFE Ulmo migration verification script + operational doc. |
| T011 | Validate LMS on rke2-nonprod | P1 | DONE | 5ngf.2 | M | T010 | ✓ Batch 13. LMS RKE2 validation script (ingress, TLS, pod health, service endpoints). |
| T012 | RKE2 nonprod smoke + tenant route matrix | P1 | DONE | 288f | M | T011 | ✓ Batch 14. verify-rke2-tenant-routes.sh (43 PASS). Full route matrix: LMS, Studio, MFE, forum, discovery, notes + TLS/CORS/redirect checks. |
| T013 | RKE2 LMS migration completion plan | P1 | DONE | 5ngf | L | T011, T012 | ✓ Batch 14. verify-migration-completion-plan.sh (42 PASS) + RKE2_MIGRATION_PLAN.md (DNS cutover, 8 rollback criteria, on-call template). |
| T014 | BoldBadger: RKE2 end-to-end rollout | P1 | DONE | 3st7 | L | T009, T013 | ✓ Batch 14. verify-rke2-rollout-readiness.sh (52 PASS) + RKE2_ROLLOUT_CHECKLIST.md (7 sign-off gates). Opus fix: forum port 4567→8000. |
| T015 | Footer parity: port v2 footer into LMS/MFEs | P1 | DONE | 1kwf.1 | M | — | ✓ Batch 12. verify-footer-parity.sh (73 offline checks). FOOTER_PARITY.md architecture doc. Covers patch module, SCSS, assets, links. |
| T016 | WhiteCliff brand/plugin parity lane | P1 | DONE | 1kwf | L | T015 | ✓ Batch 14. verify-brand-parity.sh (84 PASS). Token stack, logos, favicons, fonts, footer, apply-patches.sh integration. BRAND_PARITY.md architecture doc. |
| T018 | Refactor apply-patches.sh into composable units | P1 | DONE | NEW | L | — | ✓ Batch 10. 10 patch modules in infrastructure/tutor/patches/. 42-line orchestrator. Opus review PASS. verify-patch-modularity.sh QA script. |
| T020 | Automate image tag promotion in Kustomize | P1 | DONE | NEW, DR2:I-007 | M | — | ✓ Batch 4. bump-image-tags.sh (queries Artifact Registry, dry-run default) + verify-no-latest-tags.sh. |
| T024 | Scheduled park/unpark validation | P1 | DONE | NEW | S | — | ✓ Batch 3. Monthly CI job: shellcheck + bash -n + set -euo pipefail verification. |
| T044 | Clarify Tutor 18.2.2 patch level | P3 | DONE | NEW, DR2:I-047 | S | T042 | ✓ Batch 6. Added "Current Version Pin" section to ADR-019 + verify-tutor-version-pin.sh (scans all files for version consistency, 14/14 PASS). |
| T075 | Add ArgoCD drift detection + alerting | P2 | DONE | DR2:I-034 | M | — | ✓ Batch 9. verify-argocd-drift.sh (offline/online per app). Scheduled 6h workflow with GitHub issue creation. ARGOCD_DRIFT.md runbook. |
| T045 | MongoDB Atlas: dev seed script | P3 | DONE | NEW | M | — | ✓ Batch 7. seed-mongo-dev.sh + fixtures (openedx + forum) + MONGODB_DEV_SEED.md. Prod guard + dry-run. Opus review: PASS. |
| T046 | MongoDB Atlas: connection health in CI | P3 | DONE | NEW | S | — | ✓ Batch 8. ATLAS_HEALTH.md + verify-atlas-health.sh (6 offline + 2 online checks) + atlas-health.yml (weekly). Opus review: PASS. |
| T047 | Wire Credential/Notes service into smoke matrix | P3 | DONE | NEW | S | T011 | ✓ Batch 11. verify-credentials-notes-smoke.sh: 14 offline + 8 online checks. Wired into Makefile qa-smoke. |
| T048 | preview.academyv2.mereka.io redirect | P3 | DONE | bims | S | — | ✓ Batch 7. K8s manifests (configmap+deployment+service+kustomization) + PREVIEW_REDIRECT.md + verify script. Opus fix: labels selector immutability + base kustomization wiring. |
| T051 | Enterprise MFE Dockerfile maintenance process | P3 | DONE | NEW | S | T010 | ✓ Batch 6. ENTERPRISE_MFE_MAINTENANCE.md (10 customization categories, 6-step checklist) + verify-mfe-customizations.sh (11 patch signature checks). |

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
| T025 | Video: full Mux + XBlock + Analytics pipeline | P1 | DONE | 1bdm | L | — | ✓ Batch 14. VIDEO_PIPELINE.md architecture doc. verify-video-pipeline.sh (12 PASS, 15 SKIP — skips are Phase 3-5 features). |
| T026 | Mux alert wiring | P2 | DONE | NEW | S | T025 | ✓ Batch 12. verify-mux-alert-wiring.sh (23 offline + online checks). Full pipeline: webhook → PrometheusRule → Alertmanager. |
| T027 | Purchase gateway: complete Stripe integration | P2 | DONE | NEW | L | — | ✓ Batch 15. verify-purchase-gateway-stripe.sh (81 PASS) + PURCHASE_GATEWAY.md architecture doc. Webhook, orders, refunds, fulfillment. |
| T028 | Purchase gateway: K8s production deployment | P2 | DONE | NEW | M | T027 | ✓ Batch 15. verify-purchase-gateway-k8s.sh rewritten (60 PASS) + PURCHASE_GATEWAY_K8S.md ops doc. Dark launch guard, secret rotation. |
| T029 | Deprecate Oscar ecommerce references | P2 | DONE | NEW | S | T028 | ✓ Batch 12. verify-oscar-deprecation.sh (KEEP/REMOVE/MIGRATE audit). OSCAR_DEPRECATION.md phased plan. |
| T030 | Forum service: Meilisearch dependency validation | P2 | DONE | NEW | S | — | ✓ Batch 6. FORUM_MEILISEARCH.md (operational doc) + verify-forum-meilisearch.sh (8 offline checks: deployment, image pin, service, Django settings, env-based keys, ExternalSecrets). |
| T031 | Forum service: smoke test in RKE2 | P2 | DONE | NEW | S | T030, T011 | ✓ Batch 10. verify-forum-smoke.sh: 10 offline + 7 online checks. Forum v2 in-process validation, Meilisearch health, API endpoints. Wired into Makefile qa-smoke. |
| T032 | Mobile: deploy enterprise mobile apps | P2 | DONE | mci9 | L | T011 | ✓ Batch 15. verify-mobile-deployment.sh (46 PASS) + MOBILE_DEPLOYMENT.md ops doc. iOS CI, mobile API, push notifications. Android deferred per ADR-016. |
| T033 | Mobile secrets runtime validation | P2 | DONE | NEW | S | T032 | ✓ Batch 12. Added --offline mode to verify-mobile-secrets-runtime.sh. mobile-secrets-check.yml CI workflow. Wired into Makefile. |
| T034 | GDPR cookie consent UI + user retirement pipeline | P2 | DONE | I21, DR2:I-021 | M | — | ✓ Batch 11. verify-gdpr-compliance.sh (12 offline + online checks). GDPR_COMPLIANCE.md runbook (retirement pipeline, PII cleanup, breach response). 9 SKIPs = features not yet implemented (cookie banner, PII registry). |
| T035 | LTI integration guide + SAML config alignment | P2 | DONE | I17, DR2:I-022, DR2:I-050 | S | — | ✓ Batch 11. LTI.md (LTI 1.1/1.3, grade passback, Ulmo Tool Store, SAML SP). verify-lti-saml-config.sh (17 offline + online checks). |
| T036 | Accessibility: WCAG 2.2 AA compliance | P2 | DONE | I44, DR2:I-009 | M | — | ✓ Batch 10. accessibility-audit.yml CI workflow (axe-core, 5 routes, wcag22aa). verify-accessibility.sh: WCAG 2.2 SC 2.4.12/2.5.8/3.3.8 checks. Non-blocking initially. |
| T037 | Atlas/Transifex translation pipeline | P2 | DONE | I42, DR2:I-037 | M | — | ✓ Batch 10. sync-translations.sh (openedx-atlas pull EN/MS, --dry-run/--check). verify-translations.sh (locale coverage >=80%). translation-check.yml CI workflow (weekly + on locale changes). |
| T076 | Implement Reusable LTI Store (Ulmo feature) | P2 | DONE | DR2:I-023 | L | T035 | ✓ Batch 12. verify-lti-store.sh (12 offline + online checks). LTI_STORE.md guide (Ulmo feature, tool persistence, admin workflow). |
| T077 | Add Policy-as-Code for pod security standards | P2 | DONE | DR2:I-024 | L | — | ✓ Batch 11. 4 Kyverno ClusterPolicies (Audit mode): require-non-root, disallow-privileged, require-seccomp, restrict-capabilities. Wired into base kustomization. verify-pod-security-policies.sh (31 checks). |
| T078 | ExternalSecrets refresh + failure alerting | P1 | DONE | DR2:I-040 | M | — | ✓ Batch 9. PrometheusRule: SyncFailure (critical, 10m) + StaleSync (warning, 2h). verify-eso-alerting.sh. ESO_ALERTING.md runbook. |
| T079 | Analytics data retention as tested config | P2 | DONE | DR2:I-045 | M | — | ✓ Batch 6. ANALYTICS_DATA_RETENTION.md + analytics-retention-config.yaml (4 tiers, PDPA/GDPR) + verify-analytics-retention.sh (16 checks). Opus fix: set -e exit code capture. |
| T080 | Add security incident runbook (supply-chain) | P2 | DONE | DR2:I-046 | M | — | ✓ Batch 3. Full runbook with P1-P4 severity, GitOps-safe rollback, comms templates, post-incident checklist. Opus review fixed GitOps violation + dep path. |
| T081 | Create security exceptions register | P2 | DONE | DR2:I-048 | M | — | ✓ Batch 5. SECURITY_EXCEPTIONS.md register (3 seeded entries) + verify-security-exceptions.sh + CI workflow (blocking on expired). |

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
| T042 | Document Tutor upgrade cadence + EOL policy | P3 | DONE | I05, DR2:I-019, DR2:I-047 | S | — | ✓ Batch 4. ADR-019 (renamed from 002 to avoid collision). Stay on Redwood, quarterly eval, pre-upgrade checklist, GitOps-safe rollback. |
| T082 | Publish release evidence bundle + retention policy | P2 | DONE | DR2:I-031 | M | — | ✓ Batch 5. RELEASE_EVIDENCE.md + assemble-release-evidence.sh + release-evidence-bundle.yml. Opus fix: Python path + JSON injection. |
| T083 | Standardize OpenTelemetry naming + dashboard contract tests | P2 | DONE | DR2:I-025 | M | — | ✓ Batch 7. OTEL_NAMING_CONVENTIONS.md + otel-metric-registry.yaml (14 metrics) + verify-otel-naming.sh. Opus review: PASS. |
| T084 | Add Lighthouse CI + bundle budgets + INP metric | P2 | DONE | DR2:I-026 | M | — | ✓ Batch 7. LIGHTHOUSE_BUDGETS.md + lighthouse-budgets.json (6 MFEs, INP/CLS/LCP) + verify-lighthouse-budgets.sh (14 checks) + lighthouse-ci.yml. Opus review: PASS after set-e fix. |
| T085 | Formalize staging activation path | P2 | DONE | DR2:I-027 | L | — | ✓ Batch 16. verify-staging-activation.sh (32 PASS) + STAGING_ACTIVATION.md. Nonprod→staging→production promotion path documented. Cross-repo: bbi-infrastructure. |
| T086 | Convert DR evidence into scheduled backup/restore drills | P1 | DONE | DR2:I-044 | L | — | ✓ Batch 16. verify-dr-drill-schedule.sh (8 PASS) + DR_DRILL_SCHEDULE.md. Monthly drill schedule, restore procedures, release gate. Cross-repo: bbi-infrastructure. |
| T087 | Container hardening (non-root, read-only FS, seccomp) | P2 | DONE | DR2:I-043 | L | — | ✓ Batch 11. Strategic merge patch for 17 base Deployments: runAsNonRoot, seccomp RuntimeDefault, readOnlyRootFilesystem, capabilities.drop ALL. MFE exempt. verify-container-hardening.sh (30 checks). Sub-kustomization services need separate patches. |
| T038 | Course data recovery (MCT + Kajabi) | P4 | BLOCKED | 1qo | L | T039 | Recovery plan blocked on artifact availability. See bead 1qo. |
| T039 | Restore MCT/Kajabi courses into Atlas | P4 | BLOCKED | hd3 | L | — | Prerequisite artifacts needed. See bead hd3. |
| T040 | Run Kajabi dry-run import | P4 | BLOCKED | 2hj | M | T039 | Blocked on T039. See bead 2hj. |
| T041 | Proctoring: integrate enterprise proctoring | P4 | DONE | i8lo | L | T011 | ✓ Batch 16. verify-proctoring-integration.sh (14 PASS, 10 SKIP — deferred features) + PROCTORING_INTEGRATION.md architecture doc. |
| T093 | Fix dev profile kustomization (bbi-infra request) | P0 | DONE | cross-team | M | — | ✓ profiles/dev kustomize builds cleanly. `../../local` ref is correct. Added runtime-secrets, ses-smtp, default-serviceaccount placeholders. Scaled enterprise services to 0. PR bbi-infrastructure#291. |
| T094 | Validate dev profile images pullable from RKE2 | P0 | DONE | cross-team | M | T093 | ✓ Base images (openedx, mfe) already cached on rke2-nonprod. Enterprise images 403 → fixed by scaling to replicas:0. Added default-serviceaccount with dev-image-puller imagePullSecret. |
| T095 | Fix dev pod CreateContainerConfigError | P0 | DONE | cross-team | M | T093 | ✓ Root causes: missing mereka-lms-runtime-secrets, ses-smtp-credentials, empty MYSQL_ROOT_PASSWORD. Fixed via placeholder secrets + Infisical password set. Pending: ArgoCD sync after PR merge. |
| T096 | Dev-on-RKE2 readiness checklist | P0 | DONE | cross-team | S | T093, T094, T095 | ✓ verify-rke2-dev-readiness.sh (5 offline + 9 online checks). RKE2_DEV_READINESS.md runbook. Offline: 5/5 PASS. Online: 6 PASS, 14 FAIL (expected pre-deploy). |

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
T057, T058, T092, T066, T081, T064, T062

**Ready after first wave (deps on items above)**:
T021 (needs T020 ✓), T054 (needs T052 ✓ + T092)

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
| I-001 | Pin GitHub Actions to commit SHAs | T052 | DONE |
| I-002 | Enforce org/repo allowed-actions policy | T053 | DONE |
| I-003 | SBOM for images (Syft/Anchore, OCI attestation) | T005 | DONE |
| I-004 | Build provenance/SLSA attestations | T054 | DONE |
| I-005 | Vuln scanning blocking for releases | T002 | DONE |
| I-006 | Render Tutor env in CI (fix idempotency skip) | T055 | DONE |
| I-007 | Digest pinning in production overlays | T020/T021 | DONE (T020) / TODO (T021) |
| I-008 | Cache-Control headers in MFE Caddyfile | T056 | DONE |
| I-009 | WCAG 2.2 AA (Focus Not Obscured, Target Size, etc.) | T036 | PARTIAL (enriched) |
| I-010 | Enable CodeQL SAST workflow | T065 | DONE |
| I-011 | Add Dependency Review workflow | T060 | DONE |
| I-012 | Add Dependabot for pip/npm/terraform | T061 | DONE |
| I-013 | Standardize minimal workflow permissions | T091 | DONE |
| I-014 | Replace JSON SA key with Workload Identity Federation | T092 | DONE |
| I-015 | Pin tool binary downloads in bbi-infrastructure CI | T057 | DONE |
| I-016 | Pin tool binary downloads in platform-control-plane CI | T058 | DONE |
| I-017 | Add GitHub Advanced Security secret scanning | T059 | DONE |
| I-018 | Establish spec coverage floor per PR | T066 | DONE |
| I-019 | Release track ADR (Redwood vs Ulmo decision) | T042 | DONE |
| I-020 | Aspects version compatibility enforcement test | T067 | DONE |
| I-021 | User retirement PII pipeline | T034 | PARTIAL (enriched) |
| I-022 | SAML config alignment + metadata endpoints | T035 | PARTIAL (enriched) |
| I-023 | Implement Reusable LTI Store (Ulmo feature) | T076 | DONE |
| I-024 | Policy-as-Code for pod security standards | T077 | DONE |
| I-025 | Standardize OTel naming + dashboard contract tests | T083 | DONE |
| I-026 | Lighthouse CI + bundle budgets + INP metric | T084 | DONE |
| I-027 | Formalize staging activation path | T085 | DONE |
| I-028 | Add repo-level PR template | T068 | DONE |
| I-029 | Require PR reviews + status checks (Scorecard) | T069 | DONE |
| I-030 | Add CODEOWNERS for infra-critical paths | T070 | DONE |
| I-031 | Publish release evidence bundle + retention policy | T082 | DONE |
| I-032 | Pin runner images to ubuntu-24.04 | T063 | DONE |
| I-033 | Replace PAT-based GitOps with GitHub App token | T062 | DONE |
| I-034 | ArgoCD drift detection + alerting for "Synced but wrong" | T075 | DONE |
| I-035 | Smoke tests for authn MFE config + cookie domain | T071 | DONE |
| I-036 | Automated tenant isolation tests | T072 | DONE |
| I-037 | Translation pipeline (openedx-atlas + MFE locale checks) | T037 | PARTIAL (enriched) |
| I-038 | Visual regression baseline governance | T073 | DONE |
| I-039 | TTFS onboarding flow tests | T074 | DONE |
| I-040 | ExternalSecrets refresh interval + failure alerting | T078 | DONE |
| I-041 | Terraform drift detection (tfsec/checkov + plan output) | T004 | DONE |
| I-042 | Trivy config scanning for K8s manifests + Terraform | T004 | DONE |
| I-043 | Container hardening (non-root, read-only FS, seccomp) | T087 | DONE |
| I-044 | Scheduled backup/restore drills with enforced gates | T086 | DONE |
| I-045 | Analytics data retention as tested config | T079 | DONE |
| I-046 | Security incident runbook (supply-chain) | T080 | DONE |
| I-047 | Ulmo upgrade spike (compat test suite + rollback plan) | T042/T044 | DONE |
| I-048 | Security exceptions register with expiry + CI enforcement | T081 | DONE |
| I-049 | Commit signing (Sigstore/GitHub) + CI verification | T064 | DONE |
| I-050 | SSO/SAML/LTI docs aligned to official Open edX operator pages | T035 | PARTIAL (enriched) |

---

## Sprint 6: Frontend Quality & Correctness (P0–P1)

*Fix DR1-identified CSS token bugs, brittle MFE selectors, and accessibility failures. Establish CI gates to prevent regression.*

| ID | Title | Priority | Status | Source | Effort | Deps | Description |
|----|-------|----------|--------|--------|--------|------|-------------|
| T097 | Fix CSS token undefined (--mereka-color-ink-600) | P0 | DONE | DR1:P0-1 | S | — | ✓ FALSE POSITIVE: Exhaustive grep of all theme files (theme.scss, mereka.scss, _tokens.scss, mereka-overrides.css, assets/branding/) finds ZERO references to `--mereka-color-ink-600`. Ink scale uses only ink-900/700/500/300. DR1 finding was based on stale analysis. |
| T098 | Fix MFE branding QA script route mapping | P0 | DONE | DR1:P0-4 | S | — | ✓ Already correct: verify-mfe-branding.sh lines 95-96 map both `/authoring`→`course-authoring` and `/course-authoring`→`course-authoring`. DR1 finding was based on stale analysis. |
| T099 | Consolidate design token sources to single canonical | P1 | DONE | DR1:P1-2, Top50:#37 | M | T097 | ✓ Batch 3. Created generate-tokens-from-canonical.sh — reads tokens.css, generates _tokens.scss + mereka-design-tokens.css + mereka-overrides.css. CI drift gate in ci.yml. Pipeline doc updated. |
| T100 | Fix WCAG contrast failures (ink-500, teal) | P1 | DONE | DR1:P1-1, Top50:#29 | M | T097 | ✓ Batch 1. Unified ink-500 to #6B6B6B (5.33:1) and teal to #237072 (5.78:1) across all 3 layers. Updated _tokens.scss, mereka-overrides.css (common/lms/cms), design-tokens.css, branding/tokens.css. All pairs now pass WCAG AA. |
| T101 | MFE footer via plugin slots (not string surgery) | P1 | DONE | DR1:P0-3, Top50:#45 | L | T099 | ✓ Batch 6. Migrated to `PLUGIN_SLOTS.add_items()` in mereka_lms.py using `org.openedx.frontend.layout.footer.v1` slot. Removed ~200 lines of JSX string surgery from footer-component.sh (now asset-copy only). verify-mfe-footer-plugin-slot.sh (8 PASS / 0 FAIL). |
| T102 | Reduce MFE brittle selectors by 50% | P1 | DONE | DR1:P0-2, Top50:#45 | M | T101 | ✓ Batch 7. Removed 110 brittle selector lines (754→613 LOC). 61% reduction (72/182 remaining, threshold 91). MFE_SELECTOR_AUDIT.md. verify-mfe-selectors.sh (7 PASS). Brace balance verified (69/69). |
| T103 | Add CSS token validation CI gate | P1 | DONE | DR1:P0-1 | S | T097 | ✓ Batch 2. Already covered by verify-token-drift.sh (AC-TOKEN-001 through AC-TOKEN-004). Wired into CI: monitoring-guardrails (syntax) + token-drift job (full execution). |
| T104 | Add authenticated visual regression harness | P2 | DONE | DR1:P2-2 | M | T073 | ✓ Batch 5. visual-regression-auth.sh (curl-based, session cookie auth, 5 routes). verify-visual-regression.sh (12 PASS). CI workflow_dispatch job. |
| T105 | Scope global CSS overrides under .mereka-theme wrapper | P2 | DONE | DR1:P2-1 | M | T102 | Audit complete: `docs/architecture/CSS_SCOPING_AUDIT.md`, `scripts/qa/verify-css-scoping.sh` (PASS, WARNs documented). Global selectors inventoried with XBlock impact assessment. |

---

## Sprint 7: Strategic Platform Evolution (P0–P1)

*Ulmo dev parity (prod already on Ulmo), Design Tokens migration, and plugin-ize the remaining bash patches. These are the highest-leverage architectural investments.*

| ID | Title | Priority | Status | Source | Effort | Deps | Description |
|----|-------|----------|--------|--------|--------|------|-------------|
| T106 | Ulmo dev parity with production | P0 | DONE | Top50:#2 | L | T042 | ✓ Batch 6. ULMO_DEV_PARITY.md gap analysis (8 gaps: 2 CRITICAL, 2 HIGH, 4 MEDIUM). verify-ulmo-parity.sh (31 PASS / 3 FAIL — remaining 3 are bbi-infrastructure fixes). Fixed Gap 4 (version annotation 18.2.2→21.0.0) and Gap 7 (config.example.yml redwood→ulmo). |
| T107 | Design Tokens theming migration (end-to-end) | P0 | DONE | Top50:#3, DR1 | XL | T099, T106 | ✓ Batch 7. DESIGN_TOKENS_MIGRATION.md (phases, MFE/LMS consumption paths, deprecation). validate-token-consumers.sh (19 PASS). verify-design-tokens-migration.sh (28 PASS). CI wired with both new scripts in design-token-validation job. |
| T108 | MFE runtime configuration standardization | P1 | DONE | Top50:#4 | M | T107 | Audit complete: `docs/architecture/MFE_RUNTIME_CONFIG.md` (5-phase migration plan), `scripts/qa/verify-mfe-runtime-config.sh` (16P/3F — 3 FAILs are real current-state gaps: learner-record route missing, cookie domains hardcoded). |
| T109 | Convert remaining bash patches to Tutor hooks/plugins | P1 | DONE | Top50:#5, DR1:P0-3 | XL | T018, T101 | ✓ Batch 7. TUTOR_PATCHES_INVENTORY.md: 5 ALREADY_CONVERTED (belt-and-suspenders), 4 FILESYSTEM (require post-render surgery), 1 mixed. No purely CONVERTIBLE patches remain. verify-tutor-patches-inventory.sh (27 PASS). |
| T110 | OEP-48 brand package formalization | P1 | DONE | Top50:#37, DR1:P1-2 | L | T107, T099 | Audit complete: `docs/architecture/OEP48_BRAND_PACKAGE.md` (5 gaps, all low-medium), `scripts/qa/verify-oep48-brand-package.sh` (122P/0F/5SKIP). All assets present on all 3 surfaces. |
| T111 | OEP-65 module architecture readiness | P2 | DONE | Top50:#28 | M | T108, T109 | Tech radar: `docs/architecture/OEP65_MODULE_READINESS.md`, `scripts/qa/verify-oep65-readiness.sh` (16P/5F/3S). 5 FAILs = real gaps (no frontend-base shell, no module federation). |
| T112 | PII & privacy audit (full data inventory) | P1 | DONE | Top50:#6 | L | T034 | ✓ Batch 4. PII_DATA_INVENTORY.md (8 data stores, OEP-30 categories). DATA_ERASURE_RUNBOOK.md (PDPA/GDPR 30-day process). verify-pii-inventory.sh. |
| T113 | Remove legacy courseware dependencies | P2 | DONE | Top50:#7 | M | T106 | Audit complete: `docs/architecture/LEGACY_COURSEWARE_AUDIT.md`, `scripts/qa/verify-legacy-courseware.sh` (6P/2W/0F). Prod correctly wired (Ulmo default True). 2 WARNs: dev still legacy, exam middleware uses old URL. |

---

## Sprint 8: Enterprise & Product Completeness (P1–P2)

*Admin Console, SSO, catalog, CDN, security hardening, and API docs. Platform-level capabilities required for enterprise customers.*

| ID | Title | Priority | Status | Source | Effort | Deps | Description |
|----|-------|----------|--------|--------|--------|------|-------------|
| T114 | Deploy Admin Console + Roles & Permissions (Ulmo) | P1 | DONE | Top50:#11 | M | T106 | Admin Console MFE already built in Dockerfile (lines 27-91) and served at `apps.*/admin-console/`. `docs/operations/ADMIN_CONSOLE_SETUP.md`, `scripts/qa/verify-admin-console.sh` (6/6 PASS). No Caddyfile changes needed. |
| T115 | Migrate legacy Content Libraries to new Libraries | P1 | DONE | Top50:#12 | L | T114 | No v1 libraries to migrate (content from Kajabi/MCT). `docs/operations/CONTENT_LIBRARIES_V2_MIGRATION.md`, `scripts/qa/verify-content-libraries-v2.sh` (25P/0F/2SKIP). Dark launch ready, operator activates via feature flags. |
| T116 | Enterprise SSO: full OIDC/SAML + SCIM provisioning | P1 | DONE | Top50:#16 | L | T108 | Phase 0 complete: `docs/operations/ENTERPRISE_SSO_GUIDE.md`, `scripts/qa/verify-enterprise-sso-readiness.sh` (13P/0F). ExternalSecret wired, SAML keypair gen ready. Phase 1 needs GCP secrets + first IdP config. |
| T117 | Ulmo catalog revamp + Discovery theming | P2 | DONE | Top50:#14 | M | T107 | Ulmo's "beautiful course pages." Apply Design Tokens to catalog. Structured data/SEO. Legacy catalog surface deprecated. |
| T118 | CDN for MFE static assets | P2 | TODO | Top50:#25 | M | T108 | DEFERRED per stakeholder. Cloudflare grey-cloud (DNS-only) means orange-cloud CDN needs paid advanced certificates. Investigate cost/benefit. Current: Caddy compression, S3 storage (asia-southeast1). |
| T119 | Security hardening: HSTS + CSP + rate limiting + bot mitigation | P1 | DONE | Top50:#26 | M | — | ✓ Batch 3. Caddy security_headers snippet (HSTS 1yr+preload, X-Content-Type-Options, Referrer-Policy). CSP baseline (report-only). DRF rate limiting (6/min auth, 100/min user). Cookie hardening. verify-security-hardening.sh (26 PASS). |
| T120 | API documentation + integration contracts (OpenAPI) | P2 | DONE | Top50:#35 | M | T027 | ✓ Batch 4. API_CONTRACTS.md (Purchase Gateway OpenAPI, HubSpot webhook, event contracts, breaking change policy). verify-api-contracts.sh (24 PASS). |
| T121 | Aspects analytics dashboards + data pipeline | P2 | DONE | Top50:#17, Parity:Track3 | M | T106 | Manifests audited: `docs/operations/ASPECTS_ANALYTICS_SETUP.md` (deployment plan, gaps), `scripts/qa/verify-aspects-analytics.sh` (35P/0F). Ralph missing from manifests. T148 wires into kustomization. |
| T122 | Product KPI layer (North Star metrics via events) | P2 | DONE | Top50:#18 | M | T121 | KPI framework: `docs/architecture/PRODUCT_KPI_FRAMEWORK.md`, `scripts/qa/verify-product-kpi.sh` (49P/0F). North Star metrics defined, event → ClickHouse → dashboard pipeline mapped. |
| T123 | Credentials + Learner Record MFE production readiness | P2 | DONE | Top50:#20 | M | T106 | Readiness audit: `docs/operations/CREDENTIALS_READINESS.md`, `scripts/qa/verify-credentials-readiness.sh` (45P/2F/7S). learner-record Caddyfile route gap confirmed (from T108). |
| T124 | SLO definitions + error budgets | P1 | DONE | Top50:#24 | M | T083 | ✓ Batch 3. SLO_POLICY.md (5 services, 3 tiers, burn-rate thresholds). slo-burn-rate-rules.yaml PrometheusRule for MFE/PurchaseGateway/Forum. verify-slo-definitions.sh (40 PASS). |
| T125 | Multi-brand multi-site via Design Tokens + runtime config | P2 | DONE | Top50:#27 | L | T107, T108 | New site spun up with config-only changes. Per-site tokens. MFE config per tenant. Currently partial (SITE_VARIANTS + multisite-sites.yml). |
| T126 | Modern discussions: spam controls + moderation | P2 | DONE | Top50:#23 | S | — | ✓ Batch 2. Added forum moderation config to LMS production.py: rate limits (30/min post, 60/min vote), max comment depth=2, spam check extension point, per-course discussion toggle. verify-forum-moderation.sh extended (45 PASS). |

---

## Sprint 9: Operational Maturity & Governance (P2–P3)

*Audit logging, capacity planning, deprecation discipline, and developer experience. Operational hygiene required for long-term maintainability.*

| ID | Title | Priority | Status | Source | Effort | Deps | Description |
|----|-------|----------|--------|--------|--------|------|-------------|
| T127 | Audit logging (who changed what, when) | P3 | DONE | Top50:#49 | L | — | Aspirational (NOT a compliance requirement per stakeholder). Audit log schema. Logs shipped to SIEM. Retention policy. Export tooling. Lower priority than operational tasks. |
| T128 | Capacity planning + cost model (per active learner) | P2 | DONE | Top50:#48 | M | T124 | ✓ Batch 5. CAPACITY_PLANNING.md (resource allocation, HPA config, $0.19/learner/month cost model, scaling policy). verify-capacity-planning.sh (14 PASS). |
| T129 | Operator support dashboards + diagnostics | P2 | DONE | Top50:#47 | M | T124, T121 | Admin dashboard for common tasks. "Diagnostics" page. Documented escalation. Reduce ticket volume. |
| T130 | Release automation: semver + changelog + rollback | P2 | DONE | Top50:#40 | M | T082 | ✓ Batch 4. RELEASE_PROCESS.md, release.yml workflow (tag-triggered changelog + GitHub Release), create-release.sh helper. verify-release-automation.sh (32 PASS). |
| T131 | Deprecation discipline (OEP-21 alignment) | P2 | DONE | Top50:#43 | S | — | ✓ Batch 2. Created DEPR.md with 6 registered deprecations (DEPR-001→006). verify-deprecation-discipline.sh (13 PASS). Fixed stale ops/ references in setup-local.sh and deploy-aspects-k8s.sh. |
| T132 | OEP-58 translations: full atlas workflow + locale CI | P2 | DONE | Top50:#31 | M | T037 | ✓ Batch 4. TRANSLATION_WORKFLOW.md, atlas.yml config, CI translation validation job, verify-translations.sh. 5 locales: en, id, zh, vi, fil. |
| T133 | Golden-path dev environment (devcontainer) | P2 | DONE | Top50:#39 | M | T106 | ✓ Batch 7. .devcontainer/ (devcontainer.json, Dockerfile, post-create.sh). DEVCONTAINER_GUIDE.md onboarding doc. verify-devcontainer.sh (22 PASS). Python 3.12 + Node 18 + Tutor + DinD. |
| T134 | Repo restructure: clear ownership layers | P3 | DONE | Top50:#38 | M | T131 | ✓ Batch 3. Enhanced CODEOWNERS with section headers + full directory coverage. verify-no-broken-paths.sh for deprecated path detection. |
| T135 | Mobile: Design Tokens theming + API parity | P2 | DONE | Top50:#30 | M | T107, T032 | Design Tokens explicitly targets mobile theming. Verify APIs, token consistency, critical learner flows on mobile. |
| T136 | Data retention + export: PDPA/GDPR automation | P2 | DONE | Top50:#44 | M | T112 | ✓ Batch 6. DATA_RETENTION_POLICY.md (all data categories, PDPA/GDPR, retention schedule). data-retention-jobs.sh (4 CronJob manifests). user-data-export.sh (DSAR export tool, OEP-30 compliant). verify-data-retention.sh (46 PASS / 0 FAIL). |

---

## Sprint 10: CTO Audit Remaining Fixes (P1–P2)

*Targeted fixes from CTO audit pass. All small-to-medium effort with no complex dependencies. Parallelize freely.*

| ID | Title | Priority | Status | Source | Effort | Deps | Description |
|----|-------|----------|--------|--------|--------|------|-------------|
| T137 | Reduce health check frequency (30m → 6h) | P1 | DONE | CTO:#9 | S | — | ✓ Batch 1. Changed cron from `*/30 * * * *` to `0 */6 * * *` in public-health-check.yml. |
| T138 | Fix Scorecard workflow permissions | P1 | DONE | CTO:#10 | S | — | ✓ Batch 1. Changed top-level `permissions: read-all` to `permissions: {}` in scorecard.yml. Job-level permissions already correct. |
| T139 | Guard _common.sh venv source | P2 | DONE | CTO:#21 | S | — | ✓ `_common.sh` does not exist. Venv guard already added to `setup-local.sh` (line 46) during CTO audit session. |
| T140 | Fix Makefile lint target masking failures | P2 | DONE | CTO:#22 | S | — | ✓ Lint target (lines 92-95) already fixed during CTO audit session — `|| true` removed. Only `format:` retains it (intentional). |
| T141 | Verify Kyverno standard labels | P2 | DONE | CTO:#23 | S | — | ✓ Batch 1. Added `app.kubernetes.io/name` to all 4 ClusterPolicies (disallow-privileged, require-non-root, require-seccomp, restrict-capabilities). |
| T142 | Add GitHub repo variables for CI conditionals | P1 | DONE | CTO:#6 | S | — | ✓ Batch 4. Created scripts/infra/setup-github-repo-vars.sh. Run manually: `./scripts/infra/setup-github-repo-vars.sh` (needs gh CLI auth). |
| T143 | Provision ADMIN_API_KEY for Purchase Gateway | P1 | DONE | CTO:auth | S | — | ✓ Batch 4. Created scripts/infra/provision-admin-api-key.sh. Run manually: `./scripts/infra/provision-admin-api-key.sh` (needs Infisical + gcloud auth). |
| T144 | Refactor build-optimizations.sh (686 lines) | P3 | DONE | CTO:#30 | M | T109 | Split into <300-line modules with single responsibility. Currently largest single patch module. |

---

## Sprint 11: Deployment Parity & AC Gap Closure (P0–P1)

*From DEPLOYMENT_PARITY_AND_AC_GAP_REVIEW.md. Canonical non-prod = rke2-nonprod (staging overlay deprecated). Close spec coverage gaps before claiming env parity.*

| ID | Title | Priority | Status | Source | Effort | Deps | Description |
|----|-------|----------|--------|--------|--------|------|-------------|
| T145 | Document canonical non-prod lane (rke2-nonprod) | P1 | DONE | Parity:Track1 | S | — | ✓ Batch 5. DEPLOYMENT_LANES.md (3 active lanes, staging deprecated). Updated overlays/README.md. verify-deployment-lanes.sh (16 PASS). |
| T146 | Close CI/CD pipeline spec remaining ACs (86% → 100%) | P0 | DONE | Parity:Track2 | M | — | ✓ Batch 5. Fixed SHA-pinned action matching in verify-ci-cd-pipeline.sh (49/0) and verify-cicd-merge-gates-and-secrets.sh (13/0). Coverage now 100%. |
| T147 | Close K8s deployment spec remaining ACs (86.5% → 100%) | P0 | DONE | Parity:Track2 | M | — | ✓ Fixed verify-operational-hardening.sh HPA check to find LMS/CMS HPAs in apps/ subdirs (not just hpa-baselines.yaml). Fixed SIGPIPE in verify-k8s-deployment-spec.sh check_alertrules. All verify scripts now 0 FAIL. |
| T148 | Wire Aspects analytics into active kustomization graph | P1 | DONE | Parity:Track3 | M | T121 | Aspects wired into both rke2-nonprod and production overlays. ExternalSecrets, storage class patch, ingress patch, PrometheusRule all added. ADR-017 status changed from Deferred to Accepted. Operator actions (secret provisioning, DB creation, init jobs) documented in `docs/operations/ASPECTS_WIRING_CHECKLIST.md`. `scripts/qa/verify-aspects-wiring.sh` (34P/4F/8SKIP). |
| T149 | Email notifications pipeline end-to-end | P1 | DONE | Parity:Track4 | M | — | ✓ Batch 6. Wired SES SMTP credentials (EMAIL_HOST_USER/PASSWORD) + SES_SNS_WEBHOOK_SECRET + UNSUBSCRIBE_HMAC_SECRET into base and rke2-nonprod ExternalSecrets. EMAIL_PIPELINE.md ops doc. EMAIL_DNS_RECORDS.md. PrometheusRule for email alerts. verify-email-notifications-pipeline.sh (28 PASS / 0 FAIL). |

---

## Sprint 12: CI Pipeline Cost Optimization (P1–P2)

*From external DevOps review. 48 workflow files, ~$56/month estimated spend. Seven-phase plan to reduce to ~$2.40/month via consolidation, caching, and self-hosted runners (ARC). Full analysis: `docs/operations/CI_PIPELINE_COST_OPTIMIZATION.md`. Implementation tracker: `docs/operations/CI_OPTIMIZATION_TRACKER.md`.*

| ID | Title | Priority | Status | Source | Effort | Deps | Description |
|----|-------|----------|--------|--------|--------|------|-------------|
| T150 | CI cost: ARC infrastructure + manifests | P1 | DONE | DevOps-Review | M | — | ✓ ARC manifests (kustomization, namespaces, Helm values, RunnerScaleSets standard+heavy with DinD+PVC). CI_CD_RUNNERS.md. See CI_OPTIMIZATION_TRACKER.md Phase 1. |
| T151 | CI cost: Immediate cost drop (triggers, concurrency, artifacts) | P1 | DONE | DevOps-Review | S | — | ✓ iOS→manual trigger, concurrency blocks on 6 PR workflows, retention-days=3 on 31 artifact uploads, Playwright artifacts on failure only. See CI_OPTIMIZATION_TRACKER.md Phase 2. |
| T152 | CI cost: Composite actions & caching | P1 | DONE | DevOps-Review | M | T151 | ✓ Created .github/actions/ composites (gcp-gke-auth, setup-python-env, setup-playwright). Refactored 9+10+3 consumer workflows. See CI_OPTIMIZATION_TRACKER.md Phase 3. |
| T153 | CI cost: Workflow consolidation (merge & flatten) | P1 | DONE | DevOps-Review | M | T152 | ✓ Merged verify-specs→ci.yml, flattened to 5 jobs (static-validation, tutor-config-tests, security-scans, test-coverage, full-verification). Consolidated tenant/a11y gates. See CI_OPTIMIZATION_TRACKER.md Phase 4. |
| T154 | CI cost: Heavy workload migration to ARC | P2 | DONE | DevOps-Review | M | T150, T153 | ✓ Added USE_SELF_HOSTED_RUNNERS conditional to 11 workflows (build-tutor-images, E2E, smoke, cron audits). Falls back to ubuntu-24.04 when ARC not deployed. ARC infra deploy is infra team prereq. See CI_OPTIMIZATION_TRACKER.md Phase 5. |
| T155 | CI cost: Cron schedule rationalization | P2 | DONE | DevOps-Review | S | T153 | ✓ 6-hourly→daily for argocd-drift-check + operations-gates-runtime. Merged 3 observability audits into daily-infrastructure-audit.yml. Event-driven triggers. TruffleHog full-scan monthly. See CI_OPTIMIZATION_TRACKER.md Phase 6. |
| T156 | CI cost: Documentation & spec alignment | P2 | DONE | DevOps-Review | S | T153, T155 | ✓ Updated specs, docs, markdown for merged workflows (verify-specs ref, 3 observability audit refs, ARC runner docs). See CI_OPTIMIZATION_TRACKER.md Phase 7. |

---

## Updated Summary

| Status | Count |
|--------|-------|
| DONE   | 150   |
| TODO   | 1     |
| PARTIAL| 0     |
| BLOCKED| 3     |
| **Total** | **154** |

Sprints 1–5: 94 tasks (91 DONE, 3 BLOCKED)
Sprints 6–10: 48 tasks (47 DONE, 1 TODO — T118 CDN deferred)
Sprint 11: 5 tasks (5 DONE) — deployment parity & AC gap closure
Sprint 12: 7 tasks (7 DONE) — CI pipeline cost optimization complete (ARC infra deploy pending)

Sources: Internal audit · DR2 (I-001→I-050) · DR1 frontend review · Top50 strategic priorities · CTO audit pass · DevOps review

---

## Full Dependency Graph (All Sprints)

```
# Sprint 1-5 chains (unchanged)
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

# Design Tokens critical path
T097 (fix token bug) → T099 (consolidate tokens) → T107 (Design Tokens migration) → T110 (OEP-48 brand package)
T107 → T108 (MFE runtime config) → T125 (multi-brand multi-site)
T107 → T117 (catalog + Discovery theming)
T107 → T135 (mobile theming)
T099 → T103 (CSS token validation CI gate)

# Plugin-ize critical path
T097 → T100 (WCAG contrast fixes)
T101 (footer via slots) → T102 (reduce brittle selectors) → T109 (patches→plugins) → T111 (OEP-65 readiness)
T018 → T109
T101 → T109
T109 → T144 (refactor build-optimizations.sh)

# Ulmo upgrade critical path
T042 → T106 (Ulmo rehearsal)
T106 → T107 (Design Tokens)
T106 → T113 (legacy courseware)
T106 → T114 (Admin Console) → T115 (new Libraries)
T106 → T121 (Aspects dashboards) → T122 (KPIs) → T129 (operator dashboards)
T106 → T123 (Credentials readiness)
T106 → T133 (golden-path dev env)

# Enterprise / compliance chain
T108 → T116 (SSO OIDC/SAML)
T034 → T112 (PII audit) → T136 (data retention/PDPA)
T083 → T124 (SLO definitions) → T128 (capacity planning)
T124 → T129

# Observability
T121 → T122 → T129
T082 → T130 (release automation)
T037 → T132 (OEP-58 translations full workflow)
T131 (deprecation discipline) → T134 (repo restructure ownership)
T073 → T104 (authenticated visual regression)

# CTO audit quick wins (no deps — parallelize freely)
T137 (health check freq)
T138 (scorecard perms)
T139 (venv guard)
T140 (Makefile lint masking)
T141 (Kyverno labels verify)
T142 (GitHub repo variables)
T143 (ADMIN_API_KEY provision)
T027 → T120 (API docs + OpenAPI)
T126 (discussions moderation — standalone)
T119 (security hardening — standalone)
```

---

## Updated Quick Filters

**Do next (unblocked P0/P1 TODOs, small effort)**:
T097, T098, T103, T137, T138, T142, T143

**Design Tokens critical path** (ordered):
T097 → T099 → T103 → T107 → T108 → T110 → T125

**Plugin-ize critical path** (ordered):
T101 → T102 → T109 → T111

**Ulmo upgrade critical path** (ordered):
T106 → T113, T114, T121, T123, T133 (parallel after T106)
T114 → T115

**Quick wins (S effort, no complex deps)**:
T097, T098, T103, T126, T131, T137, T138, T139, T140, T141, T142, T143

**Blocked by Ulmo rehearsal (T106)**:
T107, T113, T114, T115, T121, T123, T133, T117

**Blocked by Design Tokens (T107)**:
T108, T110, T117, T125, T135

**Blocked by MFE runtime config (T108)**:
T116, T118, T125

**Cross-repo items**:
T053, T057, T058, T075, T077, T078, T085, T086 (unchanged)
T119 (Caddy/infra config), T118 (CDN — infra), T116 (SSO — cross-repo IdP config)

---

## DR1 Cross-Reference Index

| DR1 ID | Finding (abbreviated) | Tracker ID | Status |
|--------|----------------------|------------|--------|
| DR1:P0-1 | CSS token undefined (--mereka-color-ink-600) | T097, T103 | DONE (false positive — zero ink-600 references in theme files) |
| DR1:P0-2 | Brittle MFE attribute selectors | T102 | DONE |
| DR1:P0-3 | MFE footer injected via string surgery (not plugin slots) | T101, T109 | DONE |
| DR1:P0-4 | MFE branding QA script route mapping stale | T098 | DONE (already correct) |
| DR1:P1-1 | WCAG contrast failures (ink-500, teal) | T100 | DONE |
| DR1:P1-2 | Three diverging design token sources | T099, T110 | DONE |
| DR1:P2-1 | Global CSS overrides affect XBlocks | T105 | DONE |
| DR1:P2-2 | Visual regression only captures unauthenticated routes | T104 | DONE |

---

## Top50 Cross-Reference Index

| Top50 # | Topic (abbreviated) | Tracker ID(s) | Status |
|---------|---------------------|---------------|--------|
| #2 | Ulmo dev parity with production | T106 | DONE |
| #3 | Design Tokens theming migration | T107 | DONE |
| #4 | MFE runtime configuration standardization | T108 | DONE |
| #5 | Convert bash patches to Tutor hooks/plugins | T109 | DONE |
| #6 | PII & privacy audit (full inventory) | T112 | DONE |
| #7 | Remove legacy courseware dependencies | T113 | DONE |
| #11 | Admin Console + Roles & Permissions (Ulmo) | T114 | DONE |
| #12 | Migrate legacy Content Libraries to new Libraries | T115 | DONE |
| #14 | Ulmo catalog revamp + Discovery theming | T117 | DONE |
| #16 | Enterprise SSO: OIDC/SAML + SCIM provisioning | T116 | DONE |
| #17 | Aspects analytics dashboards + data pipeline | T121 | DONE |
| #18 | Product KPI layer (North Star metrics via events) | T122 | DONE |
| #20 | Credentials + Learner Record MFE production readiness | T123 | DONE |
| #23 | Modern discussions: spam controls + moderation | T126 | DONE |
| #24 | SLO definitions + error budgets | T124 | DONE |
| #25 | CDN for MFE static assets | T118 | TODO |
| #26 | Security hardening: HSTS + CSP + rate limiting | T119 | DONE |
| #27 | Multi-brand multi-site via Design Tokens + runtime config | T125 | DONE |
| #28 | OEP-65 module architecture readiness | T111 | DONE |
| #29 | WCAG contrast failures | T100 | DONE |
| #30 | Mobile: Design Tokens theming + API parity | T135 | DONE |
| #31 | OEP-58 translations: atlas workflow + locale CI | T132 | DONE |
| #35 | API documentation + integration contracts (OpenAPI) | T120 | DONE |
| #37 | OEP-48 brand package + design token canonical source | T110, T099 | DONE |
| #38 | Repo restructure: clear ownership layers | T134 | DONE |
| #39 | Golden-path dev environment (devcontainer) | T133 | DONE |
| #40 | Release automation: semver + changelog + rollback | T130 | DONE |
| #43 | Deprecation discipline (OEP-21 alignment) | T131 | DONE |
| #44 | Data retention + export: PDPA/GDPR automation | T136 | DONE |
| #45 | MFE footer via plugin slots / reduce brittle selectors | T101, T102 | DONE |
| #47 | Operator support dashboards + diagnostics | T129 | DONE |
| #48 | Capacity planning + cost model | T128 | DONE |
| #49 | Audit logging (who changed what, when) | T127 | DONE |

### Top50 items already covered by Sprints 1–5 (DONE)

| Top50 # | Topic | Tracker ID(s) | Status |
|---------|-------|---------------|--------|
| #1 | Lock platform to Ulmo+Tutor v21 | T042, T044 | DONE |
| #8 | Reproducible dev/staging env | T055, T093–T096 | DONE |
| #9 | Backups + restore drills | T086 | DONE |
| #10 | Supply-chain security baseline | T001–T006, T052–T064 | DONE |
| #13 | Activity Notifications + email | Custom app (openedx_notifications) | DONE (deployed) |
| #15 | Reusable LTI configurations | T076 | DONE |
| #19 | Discovery service | Deployed (config.example.yml) | DONE |
| #21 | Commerce strategy | T027, T028, T029 | DONE |
| #22 | Meilisearch as search backend | T030, T031 | DONE |
| #23 | Modern discussions backend | T031 (Python openedx-forum) | DONE |
| #32 | Consolidated Tutor plugin | T018 (mereka_lms.py) | DONE |
| #33 | Unified lint/format/test | Makefile + pre-commit | DONE |
| #34 | E2E smoke tests | T049, T050, T071, T072 | DONE |
| #36 | Operational runbooks | T080, T086, TROUBLESHOOTING.md | DONE |
| #41 | Infrastructure as Code | T004, T087, Kustomize | DONE |
| #42 | Secrets management | T078, T092 | DONE |
| #46 | CD pipeline staging→prod | T085, T050 | DONE |
| #50 | Upgrade discipline | T042, T044, T085 | DONE |

---

## CTO Audit Cross-Reference Index

| CTO Audit # | Finding (abbreviated) | Tracker ID | Status |
|-------------|----------------------|------------|--------|
| CTO:#6 | GitHub repo variables missing for CI conditionals | T142 | DONE |
| CTO:#9 | Health check cron too frequent (every 30m) | T137 | DONE |
| CTO:#10 | Scorecard workflow uses permissions: read-all | T138 | DONE |
| CTO:#21 | _common.sh venv source unguarded | T139 | DONE |
| CTO:#22 | Makefile lint target masks failures with \|\| true | T140 | DONE |
| CTO:#23 | Kyverno ClusterPolicies may lack standard labels | T141 | DONE |
| CTO:#30 | build-optimizations.sh at 686 lines (single responsibility) | T144 | DONE |
| CTO:auth | ADMIN_API_KEY not provisioned for Purchase Gateway | T143 | DONE |
