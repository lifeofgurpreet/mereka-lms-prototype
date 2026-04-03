---
title: "Mereka LMS — Master Implementation Tracker"
status: active
owner: Platform Team
created: 2026-04-03
last_verified: 2026-04-03
review_cadence: weekly
---

# Mereka LMS — Master Implementation Tracker

> **Single source of truth for all open work across the platform.**
> Do not create parallel trackers — update this file.
>
> **Legend**:
> - Priority: `P0` critical/prod-down · `P1` sprint-blocking · `P2` scheduled · `P3` backlog · `P4` deferred
> - Status: 🔴 BLOCKED · 🟡 IN PROGRESS · 🟢 DONE · ⚪ NOT STARTED · ❄️ PARKED
> - Evidence tier: `runtime_validated` · `infra_truth` · `repo_truth` · `unverified`

---

## Section 0: Baseline Snapshot (2026-04-03)

| Dimension | Value | Source |
|-----------|-------|--------|
| Prod deployments healthy | 31/31 active (payments-gateway 0/0 intentional) | batch1 runtime |
| ArgoCD mereka-lms-dev | `Synced / Healthy` | batch1 runtime |
| ArgoCD mereka-lms-prod | `Synced / Healthy` | batch1 runtime |
| Prod image: LMS + CMS | `00ad100e` (ghcr) | batch1 runtime |
| Prod image: MFE | `e5c0c508` (ghcr) | batch1 runtime |
| Dev image: openedx | `00ad100e` (same as prod — docs were stale at `e9a3e1bb`) | batch1 runtime |
| Staging pod health | **DEGRADED** — 54/111 non-running (evicted/failed, not garbage-collected) | batch1 runtime |
| ExternalSecrets prod | All 8 SecretSynced/Ready | batch1 runtime |
| Velero backup status | **FailedValidation** — `VolumeSnapshotLocation "default" not found` | batch1 runtime |
| CronJob failures | 6 distinct failures (auth-verify, cert-verify, course-reindex, library-export, tenant-isolation-nightly, superset-init stuck 2d) | batch1 runtime |
| ARC runners | HEALTHY — controller 20d uptime · 7 standard + 2 heavy active | batch1 runtime |
| Open beads (P1) | 12 active | `br list` |
| Spec tiers complete | Tier 0–3 ~95% · Tier 4–6 partial | `IMPLEMENTATION_ORDER.md` |
| Kyverno `protect-gitops-managed-resources` policy | **ABSENT from cluster** (documented in CLAUDE.md but not deployed) | batch3 runtime |
| CI static inventory | 460 scripts, all shards current | batch2 repo_truth |

---

## Section 1: Production Runtime Health

### 1.1 ArgoCD Health — BOTH ENVS CLEAN

| Item | Status | Priority | Evidence | Next Action |
|------|--------|----------|----------|-------------|
| `mereka-lms-dev` | 🟢 HEALTHY | — | runtime (batch1) | Synced/Healthy, op phase Succeeded, rev `4f6d7c6a` |
| `mereka-lms-prod` | 🟢 HEALTHY | — | runtime (batch1) | Synced/Healthy |
| Other prod ArgoCD apps (`agent-e-prod`, `climate-exchange-prod`, `infisical-prod`) | 🟡 DEGRADED | P2 | runtime (batch1) | Outside mereka-lms scope — platform team to address |
| Stale `3bm2` bead (stale Degraded) | 🟢 RESOLVED | — | runtime (batch1) | ArgoCD health resolved; bead can be closed |

**Bead**: `mereka-lms-3bm2` → **CLOSEABLE**
**Skill**: `argocd-sync`, `k8s-diagnostics`

---

### 1.2 Velero Backup Failures — ROOT CAUSE IDENTIFIED

| Item | Status | Priority | Evidence | Next Action |
|------|--------|----------|----------|-------------|
| `VolumeSnapshotLocation "default" not found` — all prod backups FailedValidation | 🔴 BLOCKED | P0 | runtime (batch1) | Create `VolumeSnapshotLocation` CR in `velero` namespace pointing to backup backend (Longhorn/B2). No such CR exists in cluster OR in GitOps repo (batch3 confirmed). |
| `prod-mereka-lms-daily` failing silently for 2+ days | 🔴 BLOCKED | P0 | runtime (batch1) | 2026-04-01 and 2026-04-02 backups both `FailedValidation`. NO valid backup exists. |
| Velero `Schedule` + `BackupStorageLocation` not in GitOps | 🔴 BLOCKED | P1 | repo_truth (batch3) | Only a `PrometheusRule` alert is in the repo. Schedule declared outside git — config loss risk. Declare CRs in `bbi-infrastructure`. |
| ClickHouse data PVC — no backup coverage | ⚪ NOT STARTED | P2 | unverified | Separate from Velero schedule fix — add CH-specific backup after Velero is restored |
| Root cause was NOT GCP quota — was missing VolumeSnapshotLocation | 🟢 DIAGNOSED | — | runtime (batch1) | Update `BACKUP_TOOLING_STATUS.md` with correct root cause |

**Beads**: `mereka-6bi4`, `mereka-12c0`
**Skill**: `k8s-operations`, `cost-management`

---

### 1.3 Enterprise Worker Stability — PROD CLEAN

| Service | Restart Count (prod) | Status | Priority | Next Action |
|---------|---------------------|--------|----------|-------------|
| enterprise-access-worker (prod) | **0 restarts**, 21h uptime | 🟢 HEALTHY | — | No action |
| enterprise-catalog-worker (prod) | **0 restarts**, 21h uptime | 🟢 HEALTHY | — | No action |
| enterprise-subsidy-worker (prod) | **Does not exist** (by design — subsidy has no Celery) | 🟢 HEALTHY | — | Architecture correct |
| ecommerce-worker CrashLoop (nonprod) | unknown — staging DEGRADED | 🔴 BLOCKED | P1 | Bead `mereka-lms-1jsy` — diagnose in dev/staging, not prod |

> High restart counts previously documented were for dev/staging, not prod. Prod workers are fresh (21h).

**Bead**: `mereka-lms-1jsy`
**Skill**: `enterprise-services`, `k8s-diagnostics`

---

### 1.4 CronJob Failures (prod) — 6 Distinct Root Causes

| Job | Frequency | Status | Root Cause | Fix |
|-----|-----------|--------|------------|-----|
| `auth-verify-prod` | every 15m | 🔴 FAILING | `default-deny-all` NetworkPolicy blocks egress — **platform IS healthy, this is a false negative** | Add egress NetworkPolicy for auth-verify CronJob pods |
| `cert-verify-prod` | every 6h | 🔴 FAILING | Same NetworkPolicy blocks `apk add` in Alpine container | Use pre-installed image (e.g. `alpine/openssl`) or add egress rule |
| `course-reindex` | every 6h | 🔴 FAILING | JSON decode error at step 2/3 — Elasticsearch doc-count query returns empty body | Fix reindex script ES query |
| `library-export` | nightly | 🔴 FAILING | Silent failure — no pod logs | Investigate script; add error trapping |
| `tenant-isolation-nightly` | nightly | 🔴 FAILING | Logs GC'd — failure reason unknown | Re-run manually, capture logs |
| `superset-init` | one-shot | 🔴 STUCK | Terminating for **2d2h** — finalizer stuck | `kubectl delete job superset-init -n mereka-lms --force --grace-period=0` |

> ⚠️ `auth-verify` and `cert-verify` failures are **monitoring false negatives** — platform is healthy (HTTP 200 confirmed externally).

**Skill**: `k8s-diagnostics`, `k8s-operations`

---

### 1.5 Staging Namespace Cleanup

| Item | Status | Priority | Evidence | Next Action |
|------|--------|----------|----------|-------------|
| 54 non-running pods (`stg-mereka-lms`) | 🟡 DEGRADED | P2 | runtime (batch1) | Evicted/Error/ContainerStatusUnknown pods not GC'd. Run: `kubectl delete pods --field-selector=status.phase=Failed -n stg-mereka-lms && kubectl delete pods --field-selector=status.phase=Succeeded -n stg-mereka-lms` |

---

## Section 2: Frontend Runtime Closure

### 2.1 Image Build & Promotion

| Item | Status | Priority | Evidence | Next Action |
|------|--------|----------|----------|-------------|
| PR #1278 (BB/SOF tenant logos) — logos IN REPO, image rebuild needed | 🟡 IN PROGRESS | P1 | repo_truth (batch2) | `infrastructure/tutor/themes/mereka/lms/static/images/biji-biji/` + `skillourfuture/` exist. Trigger `build-tutor-images.yml` with `build_openedx=true`. |
| MFE Dockerfile Ulmo migration (bead `mereka-lms-2s47`) | 🟢 DONE | — | repo_truth (batch2) | All `ADD` lines in `mfe-build/Dockerfile` correctly pinned to `#release/ulmo.1`. Minor: README.md still shows redwood in example — cosmetic doc fix only. |
| `apply-dev-tenant-state.sh` not on main (`fix/libsass-css4-rgb-compat`) | 🔴 BLOCKED | P1 | repo_truth (batch2) | 32 commits ahead of main, no PR. Branch mixes CSS, tenancy, governance work — needs triage/break-apart before merge. |
| `feat/import-lane-closure` follow-on (5 commits past merged PR #1275) | 🔴 BLOCKED | P1 | repo_truth (batch2) | 5 commits (runbook hardening, PB→MCT32-EN remap, conflict resolution) not on a PR. Needs new PR. |
| `worktree-feat+first-class-domains` — 23 commits, no PR | 🔴 BLOCKED | P1 | repo_truth (batch2) | First-class domain realization complete on branch but not merged. PR urgently needed. |

**Bead**: `mereka-lms-2s47`
**Skill**: `image-tag-audit`, `mfe-branding-proof`, `gitops-contract-consumer`

---

### 2.2 Authenticated Surface Proof

| Surface | Status | Priority | Evidence | Next Action |
|---------|--------|----------|----------|-------------|
| `/dashboard` → MFE learner-dashboard redirect | 🟡 IN PROGRESS | P1 | infra_truth | Needs real browser login proof (waffle flag set) |
| Studio login callback round-trip | 🟡 IN PROGRESS | P1 | unverified | Browser test with SSO via Authentik |
| `next` param survival through auth chain | ⚪ NOT STARTED | P2 | unverified | End-to-end browser test |
| Learner portal `/mereka` slug | ⚪ NOT STARTED | P2 | unverified | Manual verification after login |

**Skill**: `agent-browser`, `authentik-auth`, `mfe-branding-proof`

---

### 2.3 Brand / Plugin Parity (WhiteCliff lane)

| Item | Status | Priority | Evidence | Next Action |
|------|--------|----------|----------|-------------|
| Footer convergence (plugin-first, all tenants) | 🟢 DONE | — | repo_truth (batch2) | `MEREKA_PUBLIC_FOOTER` wired in `mfe_runtime_definitions.js` (3 refs). Slot registered via `mereka_lms_mfe_slots.py`. Django LMS fallback is separate ongoing item. |
| Studio surfaces parity | 🟡 IN PROGRESS | P1 | unverified | Studio session cookie / SSO redirect loop (pre-existing). PR #1247 (`fix(theme): sync CMS overrides`) stale — open 5+ days with no review. |
| Service surfaces (credentials, discovery, catalog) | ⚪ NOT STARTED | P2 | unverified | Tenant branding on satellite services |
| `head-extra.html` debt | 🟢 RESOLVED | — | repo_truth (batch2) | LMS: 83 lines at correct path `themes/mereka/lms/templates/head-extra.html` (post #1290 fix). NOT 360 lines. CMS: 38 lines. DEV_CONVERGENCE_CONTROL.md was stale. |

**Beads**: `mereka-lms-1kwf`, `mereka-lms-1kwf.1`
**Skill**: `mfe-branding-proof`, `openedx-architecture`, `tutor-commands`

---

### 2.4 Visual / CSS Parked Items

| Item | Status | Priority | Evidence | Next Action |
|------|--------|----------|----------|-------------|
| Card border/shadow/row layout decisions | ❄️ PARKED | P3 | repo_truth | Requires user visual review — exact CSS control points documented in `DEV_CONVERGENCE_CONTROL.md` |
| Auth logo size / field spacing | ❄️ PARKED | P3 | repo_truth | Paragon `_overrides.scss` path documented |
| Studio dropdown opacity / Libraries v2 / Tagging | ❄️ PARKED | P3 | unverified | Feature flags `*_ENABLED = false` in cms/production.py |

---

## Section 3: Authentication & SSO

### 3.1 Dev Credentials Login 500

| Item | Status | Priority | Evidence | Next Action |
|------|--------|----------|----------|-------------|
| `/auth/login` 500 runtime on dev credentials flow | 🔴 BLOCKED | P1 | runtime | Bead `bd-1gx8` — investigate LMS logs for traceback |
| Studio SSO redirect loop (pre-existing) | 🟡 IN PROGRESS | P1 | runtime | CMS OAuth2 redirect chain issue; browser test needed |

**Bead**: `bd-1gx8`
**Skill**: `authentik-auth`, `k8s-diagnostics`

---

### 3.2 OIDC Provider Configs

| Item | Status | Priority | Evidence | Next Action |
|------|--------|----------|----------|-------------|
| OIDC provider verification script (`verify-oidc-provider-configs.sh`) | 🔴 BLOCKED | P1 | repo_truth (batch2) | Script has **uncommitted local changes** not pushed to any branch. PRs #1294 and #1296 are open on separate branches. Changes include: RKE2 context names, namespace handling, `domains_csv_for_env()` function. Must stage into correct PR. |
| PR #1294 (`fix/oidc-provider-verifier-surface`) | 🟡 IN PROGRESS | P1 | repo_truth (batch2) | Open 2026-04-02 |
| PR #1296 (`fix/verify-oidc-provider-domains`) | 🟡 IN PROGRESS | P1 | repo_truth (batch2) | Open 2026-04-02 |
| PR #1283 (`fix(aspects): closure phase 1`) | 🟡 IN PROGRESS | P2 | repo_truth (batch2) | Open 2026-04-02 |
| Staging SSO canary | 🟢 DONE | — | runtime_validated | Playwright works on ARC runners; LMS OIDC flow completes |

**Skill**: `authentik-auth`, `operational-guardrail-check`

---

## Section 4: RKE2 Operational Hardening (BoldBadger lane)

| Item | Status | Priority | Evidence | Next Action |
|------|--------|----------|----------|-------------|
| Nonprod smoke test matrix | 🟡 IN PROGRESS | P1 | unverified | Bead `mereka-lms-288f` |
| Tenant route matrix validation | 🟡 IN PROGRESS | P1 | unverified | All 3 tenants: Mereka / BB / SOF |
| payments-gateway parity (nonprod) | 🟡 IN PROGRESS | P1 | unverified | Bead `mereka-lms-1jsy` |
| Final hardening + handoff | 🟡 IN PROGRESS | P1 | unverified | Bead `mereka-lms-3st7` |
| RKE2 LMS migration completion | 🟡 IN PROGRESS | P1 | unverified | Bead `mereka-lms-5ngf` |

**Beads**: `mereka-lms-3st7`, `mereka-lms-288f`, `mereka-lms-5ngf`
**Skill**: `k8s-diagnostics`, `lms-migration-truth`, `argocd-sync`, `cutover-preflight`

---

## Section 5: Aspects Analytics

### 5.1 Prod Activation — ALREADY LIVE (not dormant)

| Item | Status | Priority | Evidence | Next Action |
|------|--------|----------|----------|-------------|
| `aspects-replicas-zero.yaml` patch | 🟢 RESOLVED | — | repo_truth (batch3) | **This file does NOT exist**. Prod overlay has ClickHouse + Superset at `count: 1`. Aspects stack is already running in prod. |
| ClickHouse prod | 🟢 RUNNING | — | infra_truth (batch3) | replicas: 1 in production overlay |
| Superset prod | 🟢 RUNNING | — | infra_truth (batch3) | replicas: 1 in production overlay |
| Superset-worker prod | 🟢 RUNNING | — | infra_truth (batch3) | replicas: 1 in production overlay |
| Ralph prod replica status | 🟡 UNVERIFIED | P2 | unverified (batch3) | No prod override found for ralph — defaults to base (1 replica). Verify `kubectl get deploy ralph -n mereka-lms`. |
| GCP SM secrets for CH users | 🟢 DONE | — | repo_truth (batch3) | ExternalSecret already maps `ch-report-password`, `ch-cms-password`, `ch-lrs-password`, `ralph-lms-password` from GCP SM |
| Run `init-aspects-env.sh` on prod | 🟡 UNVERIFIED | P2 | unverified | Was init run? Verify Alembic migrations + dbt models ran on prod |
| Wire tracking-logs PVC to LMS deployment | ⚪ NOT STARTED | P2 | unverified | bbi-infrastructure overlay patch |
| ClickHouse user passwords (`ALTER USER` to use Infisical values) | ⚪ NOT STARTED | P2 | unverified | Passwords flow from ESO but runtime `ALTER USER` needed |

**Skill**: `k8s-operations`, `secrets-management`, `gitops-deployment`

---

### 5.2 Operational Hardening

| Item | Status | Priority | Evidence | Next Action |
|------|--------|----------|----------|-------------|
| Retention policy (`ASPECTS_DATA_TTL_EXPRESSION`) | ⚪ NOT STARTED | P2 | unverified | Decide before data accumulates |
| Staging worker CPU unblock | ⚪ NOT STARTED | P3 | unverified | New LMS worker pod for xAPI throughput |
| Superset 5.x/6.x upgrade | ❄️ PARKED | P4 | unverified | Waiting for tutor-contrib-aspects compat |
| Historical xAPI backfill | ❄️ PARKED | P3 | unverified | After tracking log PVC active |
| ClickHouse backup schedule | ⚪ NOT STARTED | P2 | unverified | Velero or native CH backup |

**Skill**: `k8s-operations`, `cost-management`

---

## Section 6: Enterprise Services

### 6.1 Catalog / Subsidy / Access

| Item | Status | Priority | Evidence | Next Action |
|------|--------|----------|----------|-------------|
| MEREKA EC catalogs (0) | ❄️ PARKED | P3 | runtime_validated | User deferred — create via Django admin when ready |
| SOF EC catalogs (0) | ❄️ PARKED | P3 | runtime_validated | User deferred |
| Biji-Biji duplicate catalogs (3 LMS, 1 catalog service) | ❄️ PARKED | P4 | runtime_validated | Low priority cleanup |
| Enterprise admin portal thin menu | 🟡 IN PROGRESS | P2 | runtime | Expected until catalogs created |
| License manager / learner portal `/mereka` slug | ⚪ NOT STARTED | P2 | unverified | Needs browser login test |

**Skill**: `enterprise-services`, `k8s-diagnostics`

---

## Section 7: Content Migration

### 7.1 Import Lane Status

| Item | Status | Priority | Evidence | Next Action |
|------|--------|----------|----------|-------------|
| MCT courses (29 OLX tarballs in dev) | 🟢 DONE | — | runtime_validated | 39 courses in dev modulestore |
| MCT users (69K) | 🟢 DONE | — | runtime_validated | 99,928 users in dev DB |
| MCT enrollments (441K) | 🟢 DONE | — | runtime_validated | 176,320 enrollments in dev |
| Kajabi enrollments (85K) | 🟢 DONE | — | runtime_validated | Applied in dev |
| Kajabi completions (4,489 certs) | 🟢 DONE | — | runtime_validated | Applied via `post_import_completions.py` |
| **Import pipeline core — PR #1275 MERGED** | 🟢 DONE | — | repo_truth (batch2) | Merged 2026-04-01 |
| Import follow-on (5 commits past #1275) | 🔴 BLOCKED | P1 | repo_truth (batch2) | Runbook hardening + PB→MCT32-EN remap on remote branch, no PR. Open PR now. |
| Block structures (14/37 computed) | 🟡 IN PROGRESS | P2 | runtime_validated | Platform/runtime limitation — needs investigation |
| Course descriptions (30/37) | 🟡 IN PROGRESS | P2 | runtime_validated | 7 courses have no source description |
| Course images (31/37) | 🟡 IN PROGRESS | P2 | runtime_validated | 6 courses have no video content / Mux thumbnail |
| `run_full_import.sh` `EXPORTS_ROOT` hardening | 🟡 IN PROGRESS | P2 | repo_truth | Pre-flight phase needs env var hardening |
| MCT course restore (Atlas) | ❄️ PARKED | P4 | unverified | Bead `mereka-lms-hd3` — Atlas restore path |
| Kajabi dry run | ❄️ PARKED | P4 | unverified | Bead `mereka-lms-2hj` — waiting on artifacts |

**Beads**: `mereka-lms-1qo`, `mereka-lms-hd3`, `mereka-lms-2hj`
**Skill**: `lms-migration-truth`, `database-operations`

---

## Section 8: Multi-Tenancy & Domain Authority

### 8.1 First-Class Domains Program

| Item | Status | Priority | Evidence | Next Action |
|------|--------|----------|----------|-------------|
| `tenant-registry.yaml` as canonical source | 🟡 IN PROGRESS | P1 | repo_truth | Branch `worktree-feat+first-class-domains` |
| Generators replace hand-maintained files | 🟡 IN PROGRESS | P1 | repo_truth | D-01 to D-10 domains |
| CI gates for domain drift prevention | ⚪ NOT STARTED | P1 | unverified | Must follow generator completion |
| Biji-Biji.com CF token at `/shared/cloudflare` | 🟢 DONE | — | runtime_validated | Infisical path confirmed |
| `course_org_filter` for dev tenants | 🟡 IN PROGRESS | P2 | runtime | TEMP_RUNTIME — needs script merge |

**Skill**: `domain-truth-convergence`, `gitops-contract-consumer`

---

## Section 9: CI/CD Pipeline

### 9.1 ARC Self-Hosted Runners

| Item | Status | Priority | Evidence | Next Action |
|------|--------|----------|----------|-------------|
| ARC controller deployed | 🟢 DONE | — | runtime_validated | `mereka-k8s-runners` + `mereka-k8s-heavy-builders` |
| Heavy builder PVC caches (50Gi + 10Gi) | 🟢 DONE | — | runtime_validated | `arc-docker-cache` + `arc-dep-cache` |
| Job consolidation (74 → 4 jobs in ci.yml) | 🟢 DONE | — | repo_truth | `CI_OPTIMIZATION_TRACKER.md` |
| 3 composite actions eliminating boilerplate | 🟢 DONE | — | repo_truth | `.github/actions/` |
| Cost target: $56/mo → ~$0 | 🟡 IN PROGRESS | P2 | unverified | Needs runtime validation of runner utilization |
| Script registry governance (`script-registry.yaml`) | 🟢 DONE | — | repo_truth | `ci_static_inventory` + `ci_runtime_inventory` |
| verify-oidc-provider-configs.sh in CI | 🟡 IN PROGRESS | P1 | repo_truth | Modified but not yet in registry |

**Skill**: `arc-runner-ops`, `gh-actions`, `critical-script-governance`

---

### 9.2 Static Validation Gates

| Item | Status | Priority | Evidence | Next Action |
|------|--------|----------|----------|-------------|
| All `ci_static_inventory` scripts exit 0 on main | 🟡 IN PROGRESS | P1 | unverified | Need CI run on main |
| TruffleHog secrets scan (HEAD only) | 🟢 DONE | — | repo_truth | `ci.yml` security-scans job |
| pip-audit | 🟢 DONE | — | repo_truth | `ci.yml` security-scans job |
| Tutor config idempotency test | 🟢 DONE | — | repo_truth | `tutor-config-tests` job |

**Skill**: `operational-guardrail-check`, `audit-security`

---

## Section 10: Observability & Monitoring

| Item | Status | Priority | Evidence | Next Action |
|------|--------|----------|----------|-------------|
| Prometheus stack (dev + staging) | 🟢 DONE | — | runtime_validated | Metrics flowing |
| Loki + Promtail log aggregation | 🟢 DONE | — | runtime_validated | Deployed |
| Tempo distributed tracing | 🟢 DONE | — | runtime_validated | Deployed |
| Superset dashboards (18, Aspects) | 🟢 DONE | — | runtime_validated | OAuth login works |
| SLO dashboards defined | ⚪ NOT STARTED | P2 | unverified | `slo-sla-service-level-management_spec.md` |
| PagerDuty / Slack alerting wired | ⚪ NOT STARTED | P2 | unverified | Need Prometheus alert rules → routing |
| Synthetic checks for MFE/account/login | ⚪ NOT STARTED | P2 | unverified | Blackbox exporter config |
| `daily-infrastructure-audit.yml` | 🟢 DONE | — | repo_truth | Merged observability + alert routing + parity |

**Skill**: `k8s-diagnostics`, `cost-management`

---

## Section 11: Secrets & Security

| Item | Status | Priority | Evidence | Next Action |
|------|--------|----------|----------|-------------|
| All secrets in Infisical (source of truth) | 🟢 DONE | — | runtime_validated | Pipeline: Infisical → GCP SM → ESO → K8s |
| All 8 prod ExternalSecrets synced | 🟢 DONE | — | runtime (batch1) | All SecretSynced/Ready |
| JWT key drift (public/private mismatch) | 🟢 DONE | — | runtime_validated | Fixed — derive public JWK from private at startup |
| CH user passwords (ESO coverage) | 🟢 DONE | — | repo_truth (batch3) | ExternalSecret maps all 4 CH passwords; base Secret uses empty-string placeholders |
| CH user passwords (runtime `ALTER USER`) | ⚪ NOT STARTED | P2 | unverified | Must run `ALTER USER` to apply passwords from ESO secret at runtime |
| `protect-gitops-managed-resources` Kyverno policy | 🔴 MISSING | P1 | runtime (batch3) | **Policy documented in CLAUDE.md but NOT deployed**. 13 other Kyverno policies active but none protect ArgoCD-managed resources. Implement in `bbi-infrastructure`. |
| CSP nonce migration (ADR-025) | ⚪ NOT STARTED | P3 | unverified | `docs/adr/025-csp-nonce-migration.md` |
| GDPR / Data Privacy compliance | ❄️ PARKED | P4 | unverified | `data-privacy-gdpr-compliance_spec.md` (30 ACs) — Tier 9 |
| Pre-commit secret scanning hook | 🟢 DONE | — | repo_truth | `.githooks/pre-commit` |

**Skill**: `secrets-management`, `audit-security`

---

## Section 12: Epics (Long-Horizon)

| Epic | Bead | ACs | Status | Priority | ETA |
|------|------|-----|--------|----------|-----|
| Video: Full Mux + XBlock + Analytics pipeline | `mereka-lms-1bdm` | ~25 | 🟡 IN PROGRESS | P1 | TBD |
| Mobile: Enterprise iOS + Android | `mereka-lms-mci9` | 37 | ❄️ PARKED | P2 | 2027 |
| Proctoring: Enterprise proctoring | `mereka-lms-i8lo` | 38 | ❄️ PARKED | P4 | 2027 |
| Email & Notifications pipeline | — | 45 | ⚪ NOT STARTED | P3 | TBD |
| Content Libraries v2 | — | 33 | ❄️ PARKED | P3 | TBD |
| Verifiable Credentials / OBv3 | — | ~40 | ⚪ NOT STARTED | P4 | TBD |
| HubSpot Registration (K8s-native) | — | 26 | ❄️ PARKED | P3 | After MCT live |
| Ecommerce Purchase Gateway (Stripe) | — | 33 | 🟡 IN PROGRESS | P2 | TBD |
| Paragon Design Tokens Migration | — | 41 | ⚪ NOT STARTED | P3 | After OEP-48 |
| Auth/SSO Enterprise Tier 5 | — | 45 | 🟡 IN PROGRESS | P2 | TBD |

---

## Section 12b: Technical Debt in Custom Apps

| App | Debt Type | Status | Priority | Next Action |
|-----|-----------|--------|----------|-------------|
| `openedx_assessment_bulk/middleware.py` | 5 TODOs — parse, validate, filter, auth-check all **unimplemented** | 🔴 INCOMPLETE | P1 | Core functionality is stubs only; either implement or remove the app |
| `openedx_advanced_xblocks/` | 3 TODOs — LaTeX comparison, gradebook sync, Open edX gradebook API | 🟡 IN PROGRESS | P2 | Implement or defer formally |
| `credentials_vc_issuer/views.py` | Key rotation registry unimplemented | 🟡 IN PROGRESS | P2 | Security gap if VC issuance is active — implement rotation |
| Plugin files (`infrastructure/tutor/plugins/`) | 0 TODOs | 🟢 CLEAN | — | No action |

> batch3 found 14 TODOs across 8 files in `infrastructure/tutor/custom-apps/` (not plugins — plugins are clean).

---

## Section 13: Governance Debt

| Item | Status | Priority | Evidence | Next Action |
|------|--------|----------|----------|-------------|
| Worktree sprawl prevention hook | ⚪ NOT STARTED | P2 | repo_truth | Post-cleanup (was 160→3 worktrees) |
| `apply-dev-tenant-state.sh` merge to main | 🔴 BLOCKED | P1 | repo_truth (batch2) | 32 commits ahead, no PR. Multi-domain branch needs triage/split. |
| Architecture Convergence Program (WS-0 done, WS-1) | 🟡 IN PROGRESS | P1 | repo_truth | 7 workstreams total |
| CRLF normalization | 🟢 DONE | — | repo_truth | PR #1139 |
| `head-extra.html` — 83 lines, 1 CSS block | 🟢 RESOLVED | — | repo_truth (batch2+batch3) | 83 lines (NOT 360 — docs were stale). Single `<style>` block; CSS migration to SCSS is backlog. |
| Legacy `tools/` and `ops/` directories | 🟢 DONE | — | repo_truth | Deprecated with README redirects |
| Velero `Schedule` + `BackupStorageLocation` not in GitOps | 🔴 MISSING | P1 | repo_truth (batch3) | Only a PrometheusRule alerting rule exists. Schedule config lives outside git. Add CRs to `bbi-infrastructure`. |
| `generate-ci-static-inventory.py --dry-run` incomplete | 🟡 IN PROGRESS | P3 | repo_truth (batch3) | Flag exits 0 with no output — drift detection requires manual `--write` + `git diff`. |
| `protect-gitops-managed-resources` Kyverno policy | 🔴 NOT DEPLOYED | P1 | runtime (batch3) | See Section 11 — documented but absent. |
| `DEV_CONVERGENCE_CONTROL.md` image SHA stale | 🟡 STALE | P2 | runtime (batch1) | Says `e9a3e1bb` (2026-03-20). Actual: `00ad100e` (same as prod). Update the doc. |
| `stale-PR` — #1247 (CMS overrides sync) | 🟡 STALE | P2 | repo_truth (batch2) | Open 5+ days with no review. Either merge or close. |

**Skill**: `codebase-audit`, `techdebt`, `critical-script-governance`

---

## Tracker Update Log

| Date | Batch | Skills Used | Key Findings |
|------|-------|-------------|--------------|
| 2026-04-03 | Seed | Manual synthesis from status docs | Initial tracker created |
| 2026-04-03 | Batch 1 | live cluster diagnostics (ArgoCD, pods, images, workers, CronJobs, ARC, ESO, Velero, dev image drift) | **COMPLETE** — ArgoCD both envs Healthy; prod 31/31; staging 54 failed pods; Velero FailedValidation (VolumeSnapshotLocation missing); 6 CronJob failures with distinct root causes; ARC healthy; ESO all synced; dev image `00ad100e` (same as prod, docs were stale) |
| 2026-04-03 | Batch 2 | frontend/branding/gitops (MFE Dockerfile, branch states, tenant logos, footer, open PRs, OIDC script, first-class-domains, CI inventory) | **COMPLETE** — MFE Ulmo done; logos in repo; head-extra 83L; footer wired; import #1275 merged + 5 follow-on unPRed; first-class-domains 23 commits no PR; OIDC uncommitted local changes; CI inventory PASS |
| 2026-04-03 | Batch 3 | security/infra/debt (secrets, ESO completeness, worker limits, Velero manifest, ARC dry-run, Kyverno, script registry, tech debt, Aspects prod, head-extra) | **COMPLETE** — Secrets CLEAN; CH user ESO mappings DONE; Kyverno `protect-gitops-managed-resources` NOT DEPLOYED (critical gap); Aspects prod NOT dormant (replicas=1); `openedx_assessment_bulk` has 5 unimplemented TODOs; Velero Schedule not in GitOps |
