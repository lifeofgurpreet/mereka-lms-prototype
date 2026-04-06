# Branch/Capability Convergence Inventory

> Generated: 2026-04-04
> Repo: mereka-lms | Current branch: `fix/remove-course-about-template` | Default: `main`

---

## Executive Summary

| Metric | Count |
|---|---|
| **Open PRs** | 17 |
| **Unmerged remote branches** | 241 |
| **Git stash entries** | 44 |
| **Uncommitted local deltas** | 15 (7 modified, 8 untracked) |
| **Launch-critical PRs** | 5 |
| **Hygiene-only PRs** | 12 |
| **Recommended kills (branches)** | ~130 |
| **Recommended defers (branches)** | ~45 |
| **Stale branches (>30 days)** | 1 (`fix/ci-tutor-ulmo-upgrade`, Mar 4) |

---

## Section 1: Open Pull Requests

| PR | Title | Finish-Line | Action | Launch-Critical? | Current Blocker |
|---|---|---|---|---|---|
| #1325 | fix(caddy): route apps edge API traffic through MFE | Product | **merge** | **Yes** | None — active, updated Apr 3 |
| #1324 | fix(runtime-proof): reject empty tenant host responses | Governance | **merge** | No | None — ready |
| #1323 | fix(qa): align baseline verification guards | Governance | **merge** | No | None — ready |
| #1322 | chore(specs): normalize markdownlint baseline | Governance | **merge** | No | None — trivial housekeeping |
| #1321 | fix(qa): respect explicit vendored settings target | Governance | **merge** | No | None — ready |
| #1320 | fix(ci): classify promtail deployment check as runtime | Governance | **merge** | No | None — CI inventory reclassification |
| #1319 | fix(ci): verify certificate branding from canonical partials | Governance | **merge** | No | None — ready |
| #1318 | fix(proof): stabilize staging routing-core authority | Governance | **merge** | No | Staging-only; no prod blocker |
| #1315 | refactor(tenants): route seed-siteconfigs through canonical apply flow | Product | **merge** | **Yes** | None — canonical tenant config flow |
| #1305 | fix(release): detect vendored caddy drift | Delivery | **keep** | No | **DRAFT** — still in progress |
| #1301 | chore: bump lodash 4.17.23→4.18.1 (dependabot) | Operations | **merge** | No | None — security dep bump |
| #1296 | fix(auth): canonicalize OIDC verifier domains | Product | **merge** | **Yes** | None — auth domain normalization |
| #1294 | fix(auth): verify full LMS OIDC provider surface | Governance | **merge** | **Yes** | None — auth verification gate |
| #1288 | docs(import): truthful status doc — single file, import-only | Governance | **merge** | No | None — documentation |
| #1283 | fix(aspects): closure phase 1 — forensic proof + config ownership | Operations | **merge** | No | Aspects subsystem — non-blocking |
| #1280 | docs: complete dev closure tracker — all phases | Governance | **merge** | No | None — documentation |
| #1247 | fix(theme): sync CMS overrides to match LMS/common — unblock build | Product | **merge** | **Yes** | Blocks CMS theme build parity |

### PR Observations

- **All 17 PRs are fresh** (created Apr 1–3). No stale PRs.
- **1 DRAFT**: #1305 (vendored caddy drift detection) — keep open, not merge-ready.
- **1 dependabot**: #1301 (lodash) — auto-mergeable.
- **1 external contributor**: #1294 (mirandaprm21) — needs review.
- **5 launch-critical**: #1325 (Caddy MFE routing), #1315 (tenant siteconfigs), #1296 (OIDC domains), #1294 (OIDC surface), #1247 (CMS theme build).

---

## Section 2: Unmerged Remote Branches (241 total)

### 2a. Branch Distribution by Prefix

| Prefix | Count | Dominant Finish-Line | Bulk Action |
|---|---|---|---|
| `fix/` | 158 | Mixed (Product, Governance, Delivery) | Kill ~100 merged-equivalent; keep ~40 active |
| `feat/` | 22 | Product / Delivery | Defer ~15; keep ~7 active |
| `codex/` | 15 | Governance / Operations | Kill all — AI-generated, superseded |
| `docs/` | 13 | Governance | Kill ~10 — point-in-time snapshots |
| `perf/` | 5 | Delivery | Defer all — optimization, not launch-blocking |
| `refactor/` | 4 | Product | Defer 3; keep 1 (seed-siteconfigs has open PR) |
| `convergence/` | 4 | Governance | Kill all — from Mar 11, superseded |
| `truth/` | 3 | Governance | Kill all — staging canary era, superseded |
| `test/` | 3 | Governance | Kill all — experiment branches |
| `lane-*/` | 6 | Governance | Kill all — Mar 12–16, superseded by later work |
| `dependabot/` | 2 | Operations | Merge 1 (#1301 lodash); kill 1 (actions/cache) |
| `chore/` | 2 | Governance | Kill — normalize LF, register mako verifier |
| `dev/` | 1 | Strategic | Kill — `dev/next-phase` (Mar 25), stale planning |
| `workstream-*` | 1 | Governance | Kill — Mar 11 cleanup prep |
| `worktree-*` | 1 | Product | Kill — Apr 2 worktree artifact |

### 2b. Stale Branches (>30 days since last commit)

| Branch | Last Commit | Category | Action |
|---|---|---|---|
| `fix/ci-tutor-ulmo-upgrade` | 2026-03-04 | Delivery | **Kill** — 31 days stale, Ulmo upgrade work superseded |

### 2c. Superseded Convergence/Lane Branches (All Mar 11–16)

These represent a prior convergence sprint and are all superseded by later work:

| Branch | Last Commit | Action |
|---|---|---|
| `convergence/lane-b-verifier-fixes` | Mar 11 | **Kill** |
| `convergence/lane-c-governance` | Mar 11 | **Kill** |
| `convergence/ws0-authority-matrix` | Mar 11 | **Kill** |
| `convergence/ws6-cleanup-stale-todos` | Mar 11 | **Kill** |
| `lane-a1/settings-ownership` | Mar 16 | **Kill** |
| `lane-i/convergence-evidence-bundle` | Mar 12 | **Kill** |
| `lane-m/frontend-route-slot-proof` | Mar 12 | **Kill** |
| `lane-p3/frontend-truth` | Mar 16 | **Kill** |
| `lane-p4/governed-frontend-closure` | Mar 16 | **Kill** |
| `lane-p5/self-reconciling-settings` | Mar 16 | **Kill** |
| `lane-p51/settings-delivery-proof` | Mar 16 | **Kill** |
| `workstream-e-cleanup-prep` | Mar 11 | **Kill** |

### 2d. Codex (AI-Generated) Branches — All Killable

All 15 `codex/` branches date from Mar 20–25 and represent AI-generated fixes that were either merged via different branches or superseded:

| Branch | Last Commit | Description | Action |
|---|---|---|---|
| `codex/branch-protection-trust-closure` | Mar 20 | Governance | **Kill** |
| `codex/cache-node24-fix` | Mar 20 | CI | **Kill** |
| `codex/enterprise-migrate-force-sync` | Mar 25 | Operations | **Kill** |
| `codex/ghcr-rke2-truth-clean` | Mar 24 | Delivery | **Kill** |
| `codex/purchase-gateway-pyproject-deps` | Mar 24 | Delivery | **Kill** |
| `codex/register-atlas-audit` | Mar 21 | Governance | **Kill** |
| `codex/register-atlas-cron` | Mar 21 | Governance | **Kill** |
| `codex/register-atlas-ensure` | Mar 21 | Governance | **Kill** |
| `codex/register-atlas-monitor-clean` | Mar 21 | Governance | **Kill** |
| `codex/repin-reusable-build-push` | Mar 24 | Delivery | **Kill** |
| `codex/rke2-truth-accuracy` | Mar 24 | Governance | **Kill** |
| `codex/staging-purchase-gateway-guard` | Mar 25 | Delivery | **Kill** |
| `codex/tenant-admin-surface-truth` | Mar 24 | Governance | **Kill** |
| `codex/trivy-disable-cache` | Mar 20 | CI | **Kill** |
| `codex/tutor-openedx-cache-reliability` | Mar 24 | Delivery | **Kill** |

### 2e. Documentation Snapshot Branches — Mostly Killable

| Branch | Last Commit | Action | Reason |
|---|---|---|---|
| `docs/closure-tracker-final` | Apr 2 | **Keep** — has open PR #1280 | Active |
| `docs/finishline-authority-tracker` | Apr 3 | **Keep** — very recent | May become PR |
| `docs/prod-realization-proof` | Apr 2 | **Defer** | Proof artifact |
| `docs/e2e-testing-guide-new` | Mar 25 | **Kill** | Stale guide draft |
| `docs/evidence-bundle-enterprise-correction` | Mar 26 | **Kill** | Point-in-time |
| `docs/stabilization-board-advance` | Mar 26 | **Kill** | Superseded |
| `docs/staging-canary-green` | Mar 26 | **Kill** | Superseded |
| `docs/staging-convergence-evidence-bundle` | Mar 26 | **Kill** | Superseded |
| `docs/staging-truth-refresh` | Mar 26 | **Kill** | Superseded |
| `docs/status-board-2026-03-26` | Mar 26 | **Kill** | Date-stamped, stale |
| `docs/truth-board-2026-03-30` | Mar 30 | **Kill** | Date-stamped, stale |
| `docs/two-week-truth-control-point-4` | Mar 28 | **Kill** | Superseded |
| `docs/two-week-truth-followup` | Mar 28 | **Kill** | Superseded |

### 2f. Active Fix Branches With Open PRs (Already Tracked Above)

These branches have associated open PRs and are tracked in Section 1:

| Branch | PR | Action |
|---|---|---|
| `fix/apps-edge-proxy-through-mfe` | #1325 | Via PR |
| `fix/runtime-proof-empty-host-detection` | #1324 | Via PR |
| `fix/static-baseline-guards` | #1323 | Via PR |
| `fix/spec-markdownlint-baseline` | #1322 | Via PR |
| `fix/vendored-settings-drift-guard` | #1321 | Via PR |
| `fix/observability-runtime-inventory` | #1320 | Via PR |
| `fix/certificate-verifier-partials` | #1319 | Via PR |
| `fix/runtime-routing-proof-surface` | #1318 | Via PR |
| `refactor/seed-siteconfigs-shim` | #1315 | Via PR |
| `fix/runtime-release-chain` | #1305 | Via PR (Draft) |
| `fix/verify-oidc-provider-domains` | #1296 | Via PR |
| `fix/oidc-provider-verifier-surface` | #1294 | Via PR |
| `feat/import-status-doc-v3` | #1288 | Via PR |
| `fix/aspects-closure-phase1` | #1283 | Via PR |
| `docs/closure-tracker-final` | #1280 | Via PR |
| `fix/sync-overrides-parity` | #1247 | Via PR |

### 2g. High-Value Non-PR Branches (Keep/Defer)

Recent branches without open PRs that may contain valuable work:

| Branch | Last Commit | Finish-Line | Action | Reason |
|---|---|---|---|---|
| `feat/runtime-routing-accept` | Apr 3 | Delivery | **Keep** | Very recent routing work |
| `feat/runtime-truth-ledger` | Apr 3 | Governance | **Keep** | Very recent truth work |
| `feat/ci-baseline-control` | Apr 3 | Governance | **Keep** | CI baseline controls |
| `feat/ci-baseline-severity-policy` | Apr 3 | Governance | **Keep** | CI severity policy |
| `feat/release-object-foundation` | Apr 3 | Delivery | **Keep** | Release object architecture |
| `feat/release-object-proof-binding` | Apr 3 | Delivery | **Keep** | Release proof binding |
| `feat/acceptance-release-clarity` | Apr 3 | Delivery | **Keep** | Acceptance criteria |
| `fix/nonprimary-lms-caddy` | Apr 3 | Product | **Keep** | Multi-tenant Caddy routing |
| `fix/build-postpush-docker-runtime` | Apr 3 | Delivery | **Keep** | Build pipeline |
| `fix/mfe-host-forwarding` | Apr 3 | Product | **Keep** | MFE routing |
| `fix/baseline-secret-classification` | Apr 3 | Governance | **Keep** | Secret classification |
| `fix/dev-mfe-siteconfig-runtime-data` | Apr 3 | Product | **Keep** | Dev MFE config |
| `fix/tenant-dashboard-routing` | Apr 3 | Product | **Defer** | Routing, likely superseded by #1325 |
| `fix/tenant-cache-convergence` | Apr 2 | Product | **Defer** | Tenant caching |
| `fix/tenant-shell-branding` | Apr 2 | Product | **Defer** | Branding |
| `fix/prod-sof-mfe-host` | Apr 2 | Product | **Defer** | SOF MFE host config |

### 2h. Bulk Kill Candidates — Superseded Fix Branches (Older than Mar 26)

The following **~100 fix branches** from before Mar 26 are highly likely superseded by later work. Sampling by domain:

**Theme/Branding/CSS (~30 branches)**: `fix/branding-css-parity`, `fix/branding-gate-svg-support`, `fix/branding-tenant-logos-palette`, `fix/branding-truth-reconciliation`, `fix/card-specificity-final`, `fix/cms-footer-mako-crash`, `fix/consolidate-footer-templates`, `fix/course-cards-float-override`, `fix/footer-convergence`, `fix/footer-links-and-cards`, `fix/footer-mobile-tap-targets`, `fix/footer-title-specificity`, `fix/frontend-polish-batch`, `fix/lms-css-actual`, `fix/libsass-css4-rgb-compat`, `fix/p1-logo-sso-branding`, `fix/p2-auth-brand-alignment`, `fix/p2-card-layout-runtime`, `fix/p2-dev-branding-cleanup`, `fix/restore-head-extra-css`, `fix/sass-all-mixed-units`, `fix/sass-mixed-units-build`, `fix/visual-polish-badges-buttons-sof`, `fix/visual-polish-full-pass`, `fix/visual-regressions-all`, `fix/seed-path-tenant-branding`, `fix/palette-bridge-timing`, `fix/sof-dev-variant-map`

**Enterprise/Auth (~12 branches)**: `fix/cookie-middleware-jwt-signature`, `fix/enterprise-auth-staging-support`, `fix/enterprise-jwt-configgen`, `fix/enterprise-learner-cors`, `fix/enterprise-mfe-caddyfile-backport`, `fix/enterprise-mfe-config-runtime`, `fix/enterprise-mfe-theme-config`, `fix/enterprise-runtime-staging-truth`, `fix/jwt-public-key-derivation`, `fix/authn-header-menu-module`, `fix/authn-login-cleanup`

**Build/CI (~15 branches)**: `fix/build-remove-load`, `fix/build-workflow-fixes`, `fix/ci-arc-no-new-privs`, `fix/ci-static-validation-fixes`, `fix/ci-tutor-ulmo-upgrade`, `fix/codeql-arc-heavy`, `fix/cosign-unbound-var`, `fix/ghcr-org-token`, `fix/make-main-green`, `fix/mfe-build-cache-bust`, `fix/mfe-build-cache-layer-order`, `fix/openedx-buildx-driver`, `fix/serialize-main-builds`, `fix/static-validation-ci-skip`, `fix/trivy-iac-scan-action-pin`, `fix/update-reusable-workflow-pin`, `fix/playwright-arc-no-with-deps`

**Aspects/Analytics (~6 branches)**: `fix/aspects-job-hooks`, `fix/aspects-operational-closure`, `fix/aspects-phase-c-xapi-pipeline`, `fix/aspects-ralph-deployment`, `fix/aspects-role-mapping`, `fix/aspects-stack-modernization`, `fix/aspects-sync-job-fix`

**Tenant/MFE Config (~15 branches)**: `fix/mfe-caddy-routing-consolidation`, `fix/mfe-config-features-sync`, `fix/mfe-logo-theme-content-type`, `fix/mfe-oauth-learner-home-contract`, `fix/mfe-paragon-light-tokens`, `fix/mfe-plugin-hide-insert`, `fix/mfe-runtime-contract-gate`, `fix/mfe-slot-ownership-balance`, `fix/mfe-tenant-theme-host-normalization`, `fix/staging-mfe-config-parity`, `fix/tenant-mfe-config-rewrite-v2`, `fix/tenant-spec-alignment`, `fix/notifications-tenant-isolation`, `fix/email-preferences-honest-hooks`, `fix/honest-stubs`

**Other fix branches**: `fix/convergence-docs-and-superset`, `fix/demote-monolith-runtime-defs`, `fix/dev-closure-phase1`, `fix/docs-*` (10 canonical docs branches), `fix/f4-static-residual-v2`, `fix/forum-*` (3 branches), `fix/gitops-guard-paths`, `fix/head-extra-slsa-prod-sync`, `fix/learner-home-discovery-contract`, `fix/mobile-api-installed-apps`, `fix/post-deploy-e2e-secret-contract`, `fix/post-push-scans-heavy-runners`, `fix/register-branding-scripts`, `fix/register-infra-scripts`, `fix/register-qa-scripts`, `fix/release-bundle-contract-cleanup`, `fix/release-bundle-cosign-v3`, `fix/release-orchestrator-newname-v2`, `fix/release-trust-and-registration`, `fix/smoke-authenticated-concurrency`, `fix/sso-canary-timeout-and-cache`, `fix/staging-proof-and-mfe-contract`, `fix/staging-remaining-linter-fixes`, `fix/staging-smoke-proof-truth`, `fix/staging-sof-studio-allowed-host`, `fix/strict-shell-verifier-pipefail`, `fix/sync-overrides-v2`, `fix/verification-catalog-auto-regen`, `fix/xblock-lazy-imports`, `fix/xblock-lazy-imports-clean`, `fix/course-about-header-scope`, `fix/course-about-language-code`, `fix/main-html-language-code`, `fix/navbar-logo-undefined`, `fix/remove-course-about-template`, `fix/cms-tenant-studio-host`, `fix/credentials-zoneinfo-runtime`, `fix/staging-sof-studio-allowed-host`

### 2i. Feature Branches Without PRs — Defer/Kill

| Branch | Last Commit | Finish-Line | Action | Reason |
|---|---|---|---|---|
| `feat/frontend-runtime-closure-2026-04-01` | Apr 1 | Product | **Defer** | Superseded by batch-v2 |
| `feat/frontend-runtime-closure` | Not in PR set | Product | **Kill** | Likely merged or replaced |
| `feat/import-lane-closure` | Apr 1 | Product | **Kill** | Superseded by v2 (#1288) |
| `feat/import-lane-closure-v2` | Apr 2 | Product | **Defer** | Related to #1288 |
| `feat/staging-sso-canary` | Mar 25 | Operations | **Kill** | Staging canary era, superseded |
| `feat/tenant-palette-bridge` | Mar 28 | Product | **Kill** | Branding sprint, superseded |
| `feat/tenant-runtime-palette-truth` | Mar 28 | Product | **Kill** | Branding sprint, superseded |
| `feat/worldclass-catalog-surface` | Mar 28 | Product | **Defer** | Catalog improvements |
| `feat/worldclass-discovery-surfaces` | Mar 28 | Product | **Defer** | Discovery improvements |
| `feat/dashboard-style-ownership` | Mar 28 | Product | **Defer** | Dashboard styling |
| `feat/dashboard-surface-ownership` | Mar 28 | Product | **Defer** | Dashboard surface |
| `feat/enrolled-companion-surfaces` | Mar 28 | Product | **Defer** | Companion UX |
| `feat/openedx-cache-layering` | Mar 28 | Delivery | **Defer** | Build caching strategy |
| `feat/target-aware-heavy-builds` | Mar 28 | Delivery | **Defer** | ARC runner optimization |
| `feat/gha-build-cache` | Mar 24 | Delivery | **Kill** | Superseded by cache-layering |

---

## Section 3: Git Stash (44 entries)

| Stash | Branch Context | Age | Action |
|---|---|---|---|
| @{0} | `feat/import-lane-closure-v2` | Recent | **Keep** — active work |
| @{1}–@{2} | `main` | Mid-range | **Drop** — main WIP, likely stale |
| @{3} | `fix/aspects-dev-login-correction` | Old | **Drop** |
| @{4} | `fix/aspects-ralph-deployment` | Old | **Drop** |
| @{5} | `refactor/mfe-scss-split-v2` | Old | **Drop** |
| @{6}–@{7} | `test/video-pipeline-baseline` | Old | **Drop** |
| @{8}–@{43} | Various (36 entries) | Old | **Drop** — accumulated debris from rebase/switch cycles |

**Recommendation**: `git stash drop` entries @{2}–@{43}. Keep @{0}–@{1} if import-lane-closure-v2 work is ongoing.

---

## Section 4: Uncommitted Local Deltas (15 files)

| File | Status | Finish-Line | Action |
|---|---|---|---|
| `deploy/k8s/base/apps/caddy/Caddyfile` | Modified (staged) | Product | **Commit** — likely related to #1325 |
| `docs/concepts/architecture/CONTROL_PLANES.md` | Modified | Governance | **Commit or stash** |
| `docs/concepts/architecture/README.md` | Modified | Governance | **Commit or stash** |
| `docs/status/active/README.md` | Modified | Governance | **Commit or stash** |
| `scripts/qa/verify-oidc-provider-configs.sh` | Modified | Governance | **Commit** — OIDC verification |
| `verification/catalogs/VERIFICATION_CATALOG.md` | Modified | Governance | **Commit** — catalog regen |
| `verification/catalogs/verification_catalog.json` | Modified | Governance | **Commit** — catalog regen |
| `docs/concepts/architecture/TENANT_OPERATING_SYSTEM.md` | Untracked | Strategic | **Commit or defer** |
| `docs/proposals/UNDP_SOF_PLATFORM_BRIEF.md` | Untracked | Strategic | **Commit or defer** |
| `docs/reference/architecture/DOMAIN_AUTHORITY_END_STATE.md` | Untracked | Governance | **Commit or defer** |
| `docs/status/active/DOMAIN_TRUTH_*.md` (2 files) | Untracked | Governance | **Commit or defer** |
| `docs/status/active/REVIEWER_OPERATOR_BOARD_2026-04-02.md` | Untracked | Governance | **Commit or defer** |
| `docs/status/active/TENANT_OPERATING_SYSTEM_BLUEPRINT_2026-04-03.md` | Untracked | Strategic | **Commit or defer** |
| `infrastructure/tutor/themes/mereka/mfe/theme/favicon.ico` | Untracked | Product | **Commit** — theme asset |

---

## Section 5: Finish-Line Distribution

| Finish-Line | Open PRs | Unmerged Branches (est.) | Total Weight |
|---|---|---|---|
| **Product** | 5 (#1325, #1315, #1296, #1247, + caddy) | ~60 (theme, MFE, tenant, routing) | Heavy — most branches |
| **Delivery** | 1 (#1305 draft) | ~35 (build, release, cache, deploy) | Medium |
| **Operations** | 2 (#1301, #1283) | ~15 (aspects, monitoring, backups) | Light |
| **Governance** | 9 (#1324,#1323,#1322,#1321,#1320,#1319,#1318,#1288,#1280) | ~80 (CI, proof, truth, docs, verification) | Heavy — most PRs |
| **Strategic** | 0 | ~5 (scope reduction, platform brief) | Minimal |

---

## Section 6: Recommended Immediate Actions

### Priority 1 — Merge Launch-Critical PRs
1. **#1325** — Caddy MFE API routing (Product)
2. **#1296** — OIDC verifier domain canonicalization (Product/Auth)
3. **#1294** — OIDC provider surface verification (Governance/Auth)
4. **#1315** — Tenant seed-siteconfigs canonical flow (Product)
5. **#1247** — CMS theme override sync / build unblock (Product)

### Priority 2 — Merge Hygiene PRs (batch)
- #1324, #1323, #1322, #1321, #1320, #1319, #1318, #1301, #1288, #1283, #1280

### Priority 3 — Branch Cleanup (delete ~130 branches)
- All 15 `codex/` branches
- All 4 `convergence/` branches
- All 6 `lane-*/` branches
- All 3 `truth/` branches
- All 3 `test/` branches
- 10 of 13 `docs/` branches (keep `docs/closure-tracker-final`, `docs/finishline-authority-tracker`, `docs/prod-realization-proof`)
- `workstream-e-cleanup-prep`, `dev/next-phase`, `worktree-feat+first-class-domains`
- ~80 superseded `fix/` branches (theme/branding, enterprise/auth, build/CI groups from before Mar 26)

### Priority 4 — Stash Cleanup
- Drop stash entries @{2}–@{43} (42 entries of accumulated debris)

### Priority 5 — Resolve Local Deltas
- Commit or stash the 15 uncommitted files on the current branch before switching
