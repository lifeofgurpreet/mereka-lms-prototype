# mereka-lms Implementation Tracker

**Last updated**: 2026-02-24
**Branch**: main

## Summary

| Status | Count |
|--------|-------|
| TODO   | 44    |
| PARTIAL| 17    |
| BLOCKED| 5     |
| **Total** | **66** |

Audit baseline: 33 EXISTS (not tracked here) · 10 PARTIAL · 6 MISSING · 17 repo-specific

---

## Phase 0: Foundation & Security

*Do these first. Unblocks CI reliability, prevents security incidents.*

| ID | Title | Priority | Status | Source | Effort | Deps | Description |
|----|-------|----------|--------|--------|--------|------|-------------|
| T001 | Create SECURITY.md | P0 | TODO | I04 | S | — | Vulnerability disclosure policy: contact, timeline, scope. No file exists at all. |
| T002 | Add pip-audit to CI | P0 | TODO | I10 | S | — | Trivy covers container layers but pyproject.toml deps (ruff, pytest, fastapi) have no Python-level audit step in CI. |
| T003 | Add .tool-versions for Python | P0 | TODO | I07 | S | — | CI pins `python-version: '3.12'` ad hoc in each job. Add `.tool-versions` (asdf/rtx) so local dev matches CI exactly. |
| T004 | Pin Terraform provider versions | P0 | TODO | I14 | S | — | Add tfsec or checkov as a CI job against `infrastructure/terraform/`. No IaC scanning exists today. |
| T005 | Add SBOM generation to CI | P0 | TODO | I09 | M | — | Add syft step to `build-tutor-images.yml` to generate CycloneDX SBOM per image build. No SBOM today. |
| T006 | Configure OpenSSF Scorecard | P0 | TODO | I12 | S | — | Add `.github/workflows/scorecard.yml`. Scorecard GitHub Action is free; gives supply-chain signal. |
| T007 | Fix RKE2 ecommerce-worker CrashLoop | P0 | PARTIAL | 1jsy | M | — | ecommerce-worker crashes on nonprod; payments-gateway parity gap. Partially investigated. |
| T008 | Resolve Argo app stale Degraded | P0 | PARTIAL | 3bm2 | M | — | ArgoCD shows Degraded for fully-synced apps. Root cause in health check config; partially traced. |
| T009 | RKE2 operational hardening | P0 | PARTIAL | aza7 | L | T007, T008 | PodDisruptionBudgets, resource limits, HPA baselines, runbook links for all critical workloads. |

---

## Phase 1: Stability & Testing

*Builds confidence in the deployment pipeline and active workloads.*

### 1a — Active RKE2 Migration

| ID | Title | Priority | Status | Source | Effort | Deps | Description |
|----|-------|----------|--------|--------|--------|------|-------------|
| T010 | MFE Dockerfile Ulmo migration | P1 | PARTIAL | 2s47 | L | — | Systematically update all MFE source refs from `release/nutmeg` / `release/palm` to `release/ulmo.1`. Tracked in bead 2s47. |
| T011 | Validate LMS on rke2-nonprod | P1 | PARTIAL | 5ngf.2 | M | T010 | Smoke tests, routing checks, cutover readiness gate. Evidence partially collected. |
| T012 | RKE2 nonprod smoke + tenant route matrix | P1 | PARTIAL | 288f | M | T011 | Full tenant route matrix (all hostnames × HTTP methods × auth states). Partially captured. |
| T013 | RKE2 LMS migration completion plan | P1 | PARTIAL | 5ngf | L | T011, T012 | Final cutover plan: DNS flip, rollback criteria, on-call schedule, post-cutover verification. |
| T014 | BoldBadger: RKE2 end-to-end rollout | P1 | PARTIAL | 3st7 | L | T009, T013 | Final hardening and handoff checklist for RKE2-nonprod as production-ready lane. |

### 1b — Branding & Multi-site

| ID | Title | Priority | Status | Source | Effort | Deps | Description |
|----|-------|----------|--------|--------|--------|------|-------------|
| T015 | Footer parity: port v2 footer into LMS/MFEs | P1 | TODO | 1kwf.1 | M | — | Plugin-first approach. Mereka Frontend v2 footer not yet ported into Tutor plugin or MFE slot. |
| T016 | WhiteCliff brand/plugin parity lane | P1 | PARTIAL | 1kwf | L | T015 | Studio surfaces, footer, all MFE surfaces. Superset of T015. |
| T017 | Validate SITE_VARIANTS + multisite config | P1 | TODO | NEW | M | — | `multisite-sites.dev.yml` and `SITE_VARIANTS` dict in branding code need a CI validation job that catches schema drift. |

### 1c — apply-patches.sh Refactor

| ID | Title | Priority | Status | Source | Effort | Deps | Description |
|----|-------|----------|--------|--------|--------|------|-------------|
| T018 | Refactor apply-patches.sh into composable units | P1 | TODO | NEW | L | — | Script is 1666 lines. Split into per-concern patch files (mysql-auth, mfe-node, domains, etc.) called from a thin orchestrator. Reduces diff noise and merge conflicts. |
| T019 | Add patch idempotency tests | P1 | TODO | NEW | M | T018 | Each patch module should be testable in isolation (run twice, same result). Add to `tests/tutor/`. |

### 1d — Image Tag Drift

| ID | Title | Priority | Status | Source | Effort | Deps | Description |
|----|-------|----------|--------|--------|--------|------|-------------|
| T020 | Automate image tag promotion in Kustomize | P1 | TODO | NEW | M | — | Production Kustomize overlays have manually managed image tags. Add a CI step or script to bump tags from the built SHA on merge to main. |
| T021 | Verify no `latest` tags in production overlays | P1 | TODO | NEW | S | T020 | `verify-no-latest-prod-tags.sh` exists but is not wired into CI as a blocking gate. Wire it. |

### 1e — Python Test Coverage

| ID | Title | Priority | Status | Source | Effort | Deps | Description |
|----|-------|----------|--------|--------|--------|------|-------------|
| T022 | Add pytest coverage gate to CI | P1 | TODO | I24 | S | — | `pytest-cov` is in dev deps but no `--cov --cov-fail-under` in CI. Add a coverage job with a floor (suggest 60% to start). |
| T023 | Add purchase-gateway unit tests | P1 | TODO | NEW | M | T022 | `services/purchase-gateway/tests/` exists but coverage unknown. Add tests for Stripe webhook handler and order model. |

### 1f — Park/Unpark

| ID | Title | Priority | Status | Source | Effort | Deps | Description |
|----|-------|----------|--------|--------|--------|------|-------------|
| T024 | Scheduled park/unpark validation | P1 | TODO | NEW | S | — | Park/unpark scripts exist but need a monthly dry-run CI job to confirm they still work after cluster changes. |

---

## Phase 2: Enterprise & Features

*Active product work. Depends on cluster stability from Phase 1.*

### 2a — Video Pipeline

| ID | Title | Priority | Status | Source | Effort | Deps | Description |
|----|-------|----------|--------|--------|--------|------|-------------|
| T025 | Video: full Mux + XBlock + Analytics pipeline | P1 | PARTIAL | 1bdm | L | — | Mux upload, XBlock playback, analytics events. 37 ACs tracked in epic 1bdm. Partially implemented. |
| T026 | Mux alert wiring | P2 | TODO | NEW | S | T025 | `verify-mux-alerts.sh` exists but Mux asset-status webhook → Alertmanager route needs validation in nonprod. |

### 2b — Purchase Gateway

| ID | Title | Priority | Status | Source | Effort | Deps | Description |
|----|-------|----------|--------|--------|--------|------|-------------|
| T027 | Purchase gateway: complete Stripe integration | P2 | PARTIAL | NEW | L | — | FastAPI scaffold exists (`services/purchase-gateway/`). Stripe webhook handler, order lifecycle, and refund flow need completion per `specs/ecommerce-purchase-gateway_spec.md`. |
| T028 | Purchase gateway: K8s production deployment | P2 | TODO | NEW | M | T027 | `k8s/` dir inside purchase-gateway exists but no ArgoCD Application manifest. Wire into `deploy/k8s/base/`. |
| T029 | Deprecate Oscar ecommerce references | P2 | TODO | NEW | S | T028 | Audit and remove Oscar-era config from Tutor env and docs once purchase-gateway is live. |

### 2c — Forum & Search

| ID | Title | Priority | Status | Source | Effort | Deps | Description |
|----|-------|----------|--------|--------|--------|------|-------------|
| T030 | Forum service: Meilisearch dependency validation | P2 | TODO | NEW | S | — | openedx-forum v0.3.8 depends on Meilisearch. Confirm Meilisearch is deployed in RKE2 nonprod and indexed. No evidence file exists. |
| T031 | Forum service: smoke test in RKE2 | P2 | TODO | NEW | S | T030, T011 | Add forum to post-deploy smoke matrix (create thread, reply, search). |

### 2d — Mobile

| ID | Title | Priority | Status | Source | Effort | Deps | Description |
|----|-------|----------|--------|--------|--------|------|-------------|
| T032 | Mobile: deploy enterprise mobile apps | P2 | PARTIAL | mci9 | L | T011 | 37 ACs in epic mci9. iOS TestFlight CI exists (`build-ios-app.yml`). Backend API and push notifications need completion. |
| T033 | Mobile secrets runtime validation | P2 | TODO | NEW | S | T032 | `verify-mobile-secrets-runtime.sh` exists but not in CI. Wire as a post-deploy gate. |

### 2e — Security & Compliance

| ID | Title | Priority | Status | Source | Effort | Deps | Description |
|----|-------|----------|--------|--------|--------|------|-------------|
| T034 | GDPR cookie consent UI | P2 | PARTIAL | I21 | M | — | Spec (`specs/data-privacy-gdpr-compliance_spec.md`) and policy exist. No cookie banner/consent UI implemented in LMS or MFEs. |
| T035 | LTI integration guide | P2 | PARTIAL | I17 | S | — | LTI referenced in specs. Write a concrete `docs/integrations/LTI.md` with Open edX LTI consumer config steps and verification. |
| T036 | Accessibility: axe-core in CI | P2 | PARTIAL | I44 | M | — | Policy doc and manual scripts exist (`verify-a11y-*.sh`). Wire axe-core (or pa11y) as an automated CI check on key routes. |

### 2f — Localization

| ID | Title | Priority | Status | Source | Effort | Deps | Description |
|----|-------|----------|--------|--------|--------|------|-------------|
| T037 | Atlas/Transifex translation management | P2 | PARTIAL | I42 | M | — | Bilingual (EN/MS) mentioned in cross-cutting spec. No atlas CLI config or Transifex project wired. Add `scripts/infra/sync-translations.sh`. |

---

## Phase 3: Polish & Scale

*Lower urgency. Do after platform is stable on RKE2.*

### 3a — Data & Migrations

| ID | Title | Priority | Status | Source | Effort | Deps | Description |
|----|-------|----------|--------|--------|--------|------|-------------|
| T038 | Course data recovery (MCT + Kajabi) | P4 | BLOCKED | 1qo | L | T039 | Recovery plan blocked on artifact availability. See bead 1qo. |
| T039 | Restore MCT/Kajabi courses into Atlas | P4 | BLOCKED | hd3 | L | — | Prerequisite artifacts needed. See bead hd3. |
| T040 | Run Kajabi dry-run import | P4 | BLOCKED | 2hj | M | T039 | Blocked on T039. See bead 2hj. |

### 3b — Proctoring

| ID | Title | Priority | Status | Source | Effort | Deps | Description |
|----|-------|----------|--------|--------|--------|------|-------------|
| T041 | Proctoring: integrate enterprise proctoring | P4 | TODO | i8lo | L | T011 | 38 ACs in epic i8lo. Requires stable RKE2 production cluster first. |

### 3c — Release & Upgrade Policy

| ID | Title | Priority | Status | Source | Effort | Deps | Description |
|----|-------|----------|--------|--------|--------|------|-------------|
| T042 | Document Tutor upgrade cadence + EOL policy | P3 | TODO | I05 | S | — | Repo references Tutor 21.0.0 (Ulmo) but no doc states when to upgrade, who decides, or EOL date. Add `docs/adr/002-tutor-upgrade-policy.md`. |
| T043 | Pin requirements with uv lockfile | P3 | TODO | I08 | S | — | Main repo has no `requirements.lock`. Generate with `uv pip compile pyproject.toml -o requirements.lock` and commit. |
| T044 | Clarify Tutor 21.0.0 patch level | P3 | TODO | NEW | S | T042 | Tutor Ulmo may have patch releases. Confirm pinned patch version in CI and document update process. |

### 3d — MongoDB Atlas

| ID | Title | Priority | Status | Source | Effort | Deps | Description |
|----|-------|----------|--------|--------|--------|------|-------------|
| T045 | MongoDB Atlas: dev seed script | P3 | TODO | NEW | M | — | Atlas is the only MongoDB option (no local fallback). Add a `scripts/infra/seed-mongo-dev.sh` that populates a dev Atlas cluster from fixtures so new devs don't need prod access. |
| T046 | MongoDB Atlas: connection health in CI | P3 | TODO | NEW | S | — | Add a lightweight CI job that validates Atlas SRV connectivity using a test-only account. Currently no CI signal for Atlas reachability. |

### 3e — Observability

| ID | Title | Priority | Status | Source | Effort | Deps | Description |
|----|-------|----------|--------|--------|--------|------|-------------|
| T047 | Wire Credential/Notes service into smoke matrix | P3 | TODO | NEW | S | T011 | Both services are deployed but not in the post-deploy smoke checklist. Add to `scripts/qa/smoke-test.sh`. |
| T048 | preview.academyv2.mereka.io redirect | P3 | TODO | bims | S | — | Add /dashboard redirect and explanation page per bead bims. |

### 3f — E2E Testing

| ID | Title | Priority | Status | Source | Effort | Deps | Description |
|----|-------|----------|--------|--------|--------|------|-------------|
| T049 | E2E test framework (Playwright) | P3 | TODO | I26 | L | T011 | Only shell smoke tests exist. Add Playwright framework with 5 critical-path tests: login, enroll, play video, forum post, certificate. |
| T050 | Wire E2E into post-deploy gate | P3 | TODO | NEW | S | T049 | Once Playwright exists, add as a blocking step in `release-evidence.yml`. |

### 3g — Enterprise MFE

| ID | Title | Priority | Status | Source | Effort | Deps | Description |
|----|-------|----------|--------|--------|--------|------|-------------|
| T051 | Enterprise MFE Dockerfile maintenance process | P3 | TODO | NEW | S | T010 | Custom Dockerfiles for enterprise portals diverge from upstream on each Ulmo patch. Add a `docs/operations/ENTERPRISE_MFE_MAINTENANCE.md` with diff-and-rebase checklist. |

---

## Dependency Graph (key chains)

```
T003 (tool-versions)
T002 (pip-audit) → T022 (coverage gate) → T023 (pg tests)

T007 + T008 → T009 (hardening) → T014 (BoldBadger rollout)
T010 (MFE migration) → T011 (validate LMS) → T012 (smoke matrix) → T013 (cutover plan) → T014

T015 (footer) → T016 (WhiteCliff parity)
T018 (refactor patches) → T019 (idempotency tests)
T020 (image tag automation) → T021 (no-latest gate)
T027 (purchase gateway) → T028 (K8s deploy) → T029 (deprecate Oscar)
T030 (Meilisearch) → T031 (forum smoke)
T039 (Atlas restore) → T040 (Kajabi dry-run) ← T038
T049 (Playwright) → T050 (E2E gate)
```

---

## Quick Filters

**Do next (unblocked P0/P1 TODOs, small effort)**:
T001, T002, T003, T006, T021, T022, T024, T042, T043

**Active bead work (PARTIAL)**:
T007, T008, T009, T010, T011, T012, T013, T014, T015, T016, T025, T027, T032, T034

**Blocked — waiting on cluster**:
T028, T031, T033, T041, T047, T050

**Blocked — waiting on data artifacts**:
T038, T039, T040
