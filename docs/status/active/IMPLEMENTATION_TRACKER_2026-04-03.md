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

### 1.3 Enterprise Worker Stability — ROOT CAUSE FOUND (batch4j)

| Service | Restart Count (prod) | Status | Priority | Next Action |
|---------|---------------------|--------|----------|-------------|
| enterprise-access-worker (prod) | **0 restarts**, 21h uptime | 🟢 HEALTHY | — | No action |
| enterprise-catalog-worker (prod) | **0 restarts**, 21h uptime | 🟢 HEALTHY | — | No action |
| enterprise-subsidy-worker (prod) | **Does not exist** (by design — subsidy has no Celery) | 🟢 HEALTHY | — | Architecture correct |
| ecommerce-worker CrashLoop (nonprod) | **DOES NOT EXIST** — Oscar stack absent from `mereka-lms-dev` entirely | 🟢 NOT APPLICABLE | — | Bead `mereka-lms-1jsy` may be stale — verify |
| **LMS Celery Beat (scheduler)** | **NOT DEPLOYED** | 🔴 MISSING | P1 | `CELERYBEAT_SCHEDULE` is defined (4h integrated channel syncs) but no Beat deployment exists in any overlay. Degreed/Canvas/Cornerstone syncs are silently not running. Either deploy `lms-beat` Deployment or convert to CronJobs. |

> **Root cause for ALL historical Celery crashes (batch4j)**: Redis `rdb_last_bgsave_status: err` on 2026-03-31 21:29 UTC. `stop-writes-on-bgsave-error` was `yes` → Redis rejected all writes → 100 Celery reconnect retries exhausted → workers crashed. Now mitigated (`stop-writes-on-bgsave-error: no`) but **483K uncommitted changes** remain unsynced — Redis has not successfully persisted to disk. This is a latent data-loss risk if Redis restarts.

| Redis Health Risk | Status | Priority | Next Action |
|---|---|---|---|
| `rdb_last_bgsave_status: err` | 🟡 LATENT RISK | P1 | Investigate why bgsave is failing; ensure Redis disk has space; run `BGSAVE` manually to verify |
| 483K uncommitted changes | 🟡 LATENT RISK | P1 | If Redis pod restarts, all in-memory state lost |
| `stop-writes-on-bgsave-error: no` | 🟢 MITIGATED | — | Crash loop stopped; workers now restart cleanly |
| **CRITICAL: `maxmemory 4gb` in redis.conf vs 128Mi prod memory limit** | 🔴 CRITICAL | P0 | `deploy/k8s/overlays/production/patches/resource-limits.yaml` sets Redis limit to **128Mi** but `redis.conf` configures `maxmemory 4gb`. OOM kill guaranteed. Fix: raise prod limit to 512Mi minimum. | 
| **PVC 1Gi too small** for 4GB maxmemory + AOF growth | 🔴 CRITICAL | P0 | `deploy/k8s/base/volumes.yml` Redis PVC is 1Gi. Expand to 5Gi minimum. |
| AOF persistence: `appendonly yes`, `appendfsync everysec` | 🟢 CONFIGURED | — | Hybrid RDB+AOF enabled — better durability than RDB-only |
| No PodDisruptionBudget for Redis | 🟡 RISK | P2 | Pod can be evicted mid-bgsave. Add PDB at `deploy/k8s/base/apps/redis/pdb.yaml` |
| No Redis persistence Prometheus alerts | 🔴 UNMONITORED | P1 | No alert for `rdb_last_bgsave_status`, memory fragmentation, or AOF rewrite. Add to `prometheusrule-lms.yaml` |

**Bead**: `mereka-lms-1jsy`
**Skill**: `enterprise-services`, `k8s-diagnostics`, `system-performance-remediation`

---

### 1.4 CronJob Failures (prod) — Root Causes + Fixes (batch4c)

| Job | Status | Root Cause (confirmed) | Fix | Effort | PR needed? |
|-----|--------|----------------------|-----|--------|------------|
| `auth-verify-prod` | 🔴 FALSE NEGATIVE | `default-deny-all` blocks port 443 egress. Platform IS healthy. | Add `allow-monitoring-jobs-external-egress` NetworkPolicy for `auth-verify`+`cert-verify` pods | 5 min | Yes — `deploy/k8s/base/network-policies/` |
| `cert-verify-prod` | 🔴 FALSE NEGATIVE | Same NetworkPolicy blocks `apk add` on Alpine container | Same NP fix above covers both | 5 min | Yes — same PR |
| `course-reindex` | 🔴 BROKEN | `curl -sf \| python3` — empty body on ES down/cold → `JSONDecodeError`. Step 1 (reindex) succeeds; step 2 (count verify) crashes. | Guard with: `ES_BODY=$(curl ... \|\| echo '{"count":0}')` in `cronjob-course-reindex.yaml:57-58` | 5 min | Yes — this repo |
| `library-export` | 🔴 BROKEN | Zero `envFrom` secretRefs + zero volume mounts → Django can't init, silent exit 1 | Add `envFrom: openedx-secrets, database-secrets, mereka-lms-runtime-secrets` + volume mounts (settings ConfigMaps) to `cronjob-library-export.yaml` | 30 min | Yes — this repo |
| `tenant-isolation-nightly` | 🔴 BROKEN | `lms` SA lacks `pods/exec` RBAC → `kubectl exec` returns 403 → empty `LMS_POD` var → job exits "No LMS pod found" | Create `Role/RoleBinding` granting `pods` list + `pods/exec` create for monitoring jobs | 30 min | Yes — `deploy/k8s/base/monitoring/rbac.yaml` |
| `superset-init` | 🔴 STUCK 2d+ | `argocd.argoproj.io/hook-delete-policy: HookSucceeded` — ArgoCD only deletes on success; failed job lingers + stuck `Terminating` pod prevents TTL cleanup | **Now**: `kubectl delete pod -n mereka-lms -l app.kubernetes.io/name=superset-init --force --grace-period=0 && kubectl delete job superset-init -n mereka-lms` **Then**: change hook policy to `HookSucceeded,HookFailed` + add `activeDeadlineSeconds: 600` in `deploy/k8s/base/plugins/aspects/jobs.yml:13` | 5 min kubectl + 5 min PR | kubectl now; PR for manifest |

> All 5 PR changes are in **this repo** (`mereka-lms`), not `bbi-infrastructure`.

**Skill**: `k8s-diagnostics`, `k8s-operations`

---

### 1.5 Staging Namespace Cleanup

| Item | Status | Priority | Evidence | Next Action |
|------|--------|----------|----------|-------------|
| 54 non-running pods (`stg-mereka-lms`) | 🟡 DEGRADED | P2 | runtime (batch1) | Evicted/Error/ContainerStatusUnknown pods not GC'd. Run: `kubectl delete pods --field-selector=status.phase=Failed -n stg-mereka-lms && kubectl delete pods --field-selector=status.phase=Succeeded -n stg-mereka-lms` |

---

### 1.6 Main Branch CI — Systemic Failures (batch4a)

> ⚠️ Main branch CI has been failing across Static Validation shards for 24+ hours. All open PRs inherit these failures — not PR-caused.

| Failing Check | Root Cause | Fix Needed |
|---|---|---|
| `verify-secret-classification` | Missing Aspects ClickHouse passwords in classification coverage | Add CH passwords to secret classification map |
| `verify-catalog-discovery` | 13 sub-checks failing | Investigate discovery service health checks |
| `verify-theming-generated-artifacts` | `favicon.ico` missing for mereka theme | Add `favicon.ico` to theme static (file exists in git status as untracked!) |
| `verify-catalog-discovery` (13 sub-checks) | **ROOT CAUSE: checks for `course_about.html` which was intentionally deleted** (commit `b4ae5333a`, 2026-04-02) to fix Mako scope bug causing 500 errors. Script enforces a file that no longer exists by design. | Update `scripts/qa/verify-catalog-discovery.sh` — remove 10 stale `course_about.html` checks; document the SEO gap (no JSON-LD schema on course-about pages) |
| `verify-brand-asset-drift` | Asset drift detected | Re-run brand asset generation |
| `verify-mfe-reduced-motion` | Missing `@media (prefers-reduced-motion: no-preference)` guard | Add motion guard to MFE SCSS |
| `verify-migration-lock` | 2 locked items open | Investigate migration lock file |
| `verify-aspects-analytics` | 2 checks failing | Check aspects pipeline state |
| `verify-phase7-selector-list-coverage` | Phase 7 selectors incomplete | Update selector coverage |

**Priority**: Fix these on `main` before merging any PR — they block clean CI assessment.

---

## Section 2: Frontend Runtime Closure

### 2.1 Image Build & Promotion

| Item | Status | Priority | Evidence | Next Action |
|------|--------|----------|----------|-------------|
| PR #1278 (BB/SOF tenant logos) — logos IN REPO, image rebuild needed | 🟡 IN PROGRESS | P1 | repo_truth (batch2) | `infrastructure/tutor/themes/mereka/lms/static/images/biji-biji/` + `skillourfuture/` exist. Trigger `build-tutor-images.yml` with `build_openedx=true`. |
| MFE Dockerfile Ulmo migration (bead `mereka-lms-2s47`) | 🟢 DONE | — | repo_truth (batch2) | All `ADD` lines in `mfe-build/Dockerfile` correctly pinned to `#release/ulmo.1`. Minor: README.md still shows redwood in example — cosmetic doc fix only. |
| `fix/libsass-css4-rgb-compat` — 32 commits, 15 days old, no PR | 🔴 BLOCKED | P1 | repo_truth (b5-branches) | MUST SPLIT: 17 theme CSS commits + 3 tenancy commits + 3 QA commits + 9 other. Open 4-5 separate PRs by domain; CSS theming first (fast-track). 22 files changed. |
| `feat/import-lane-closure` follow-on (5 commits post-merge PR #1275) | 🔴 BLOCKED | P1 | repo_truth (b5-branches) | 5 post-merge commits (runbook hardening, PB→MCT32-EN remap). Needs new PR. |
| `worktree-feat+first-class-domains` — 23 post-merge commits, no PR | 🔴 BLOCKED | P1 | repo_truth (b5-branches) | **CLARIFICATION**: Original PR #1262 was merged 2026-03-31. These 23 commits are NEW work pushed AFTER the merge (last: 2026-04-02). 11 merge conflicts with main. Needs a new follow-on PR. |
| PRs #1297, #1298, #1299, #1300 | 🟢 MERGED | — | repo_truth (b5-branches) | 4 PRs merged in last 2 days — good velocity |
| PRs #1288, #1280, #1301, #1245 | 🟢 READY | P1 | repo_truth (b5-branches) | All passing CI, zero risk — merge now |
| PRs #1296, #1294, #1283 | 🔴 CI_FAIL | P1 | repo_truth (b5-branches) | Static Validation Scripts + Postchecks failures — likely need inventory regeneration. Rebase from main. |

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

### 2.5 Open PR Action Queue (batch4a)

| PR | Title | Merge State | Recommendation | Action |
|----|-------|-------------|----------------|--------|
| #1288 | docs(import): truthful status doc | ✅ Mergeable, CI PASS | **MERGE NOW** | Zero risk, docs-only |
| #1280 | docs: complete dev closure tracker | ✅ Mergeable, CI PASS | **MERGE NOW** | Zero risk, docs-only |
| #1301 | bump lodash 4.18.1 | ✅ Mergeable | **MERGE NOW** | Systemic CI failures not caused by this PR |
| #1245 | bump actions/cache 5.0.4 | ✅ Mergeable | **MERGE NOW** | 1-line CI dependency update |
| #1296 | fix(auth): OIDC verifier domain canonicalization | ❌ CONFLICTING | NEEDS_REBASE | Supersedes #1294; rebase then review |
| #1283 | fix(aspects): closure phase 1 | ❌ CONFLICTING | NEEDS_REBASE | Migration script conflicts; rebase needed |
| #1247 | fix(theme): sync CMS overrides | ❌ CONFLICTING | NEEDS_REBASE | 3 days stale; trivial rebase |
| #1294 | fix(auth): verify OIDC provider surface | ✅ Mergeable | CLOSE (superseded by #1296) | Narrower scope, #1296 covers it all |
| #1302 | feat(acceptance): runtime-routing control plane | DRAFT | HOLD | CI still running; opened today |
| bbi-infra #2245 | docs(domains): D-05 domain-registry boundary | Unknown | NEEDS_REVIEW | 3 days inactive; ping author |

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
| `openedx_tenant_cache 0001_initial` — UNAPPLIED (LMS + CMS) | 🔴 BLOCKED | P0 | runtime (batch4b) | App signals registered at startup; any write → `ProgrammingError: relation does not exist`. Run `lms-migrate` + `cms-migrate` Jobs immediately. |
| `lms-migrate` Job manifest | 🟢 EXISTS | — | repo_truth (batch4b) | `deploy/k8s/base/jobs/lms-migrate.yaml` — apply before next LMS rollout |
| `cms-migrate` Job manifest | 🟢 EXISTS | — | repo_truth (batch4b) | `deploy/k8s/base/jobs/cms-migrate.yaml` — apply before next CMS rollout |
| `credentials-migrate.yaml` manifest | 🔴 MISSING | P1 | repo_truth (b5-credentials-notes confirmed) | No manifest exists. Copy pattern from `lms-migrate.yaml`; image `overhangio/openedx-credentials:21.0.0`, settings `credentials.settings.tutor.production`. |
| `notes-migrate.yaml` manifest | 🔴 MISSING | P2 | repo_truth (b5-credentials-notes) | No manifest exists. Copy pattern from `lms-migrate.yaml`; image `overhangio/openedx-notes:21.0.0`, settings `notesserver.settings.tutor`. |
| Credentials VC issuer key rotation registry (AC-CRED-013/014) | 🔴 STUB | P2 | repo_truth (b5-credentials-notes) | `credentials_vc_issuer/views.py:101` — TODO unimplemented. Only single key served. No rotation mechanism. |
| Enterprise catalog/access/subsidy migrations | 🟢 CLEAN | — | runtime (batch4b) | All applied 14h ago via migrate Jobs |
| Nonprod smoke test matrix | 🟡 IN PROGRESS | P1 | unverified | Bead `mereka-lms-288f` |
| Tenant route matrix validation | 🟡 IN PROGRESS | P1 | unverified | All 3 tenants: Mereka / BB / SOF |
| payments-gateway parity (nonprod) | 🟢 DEPLOYED | — | runtime (batch4j) | Running in both dev (9 restarts/bgsave) and staging (35d uptime) |
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

### 6.1 Catalog / Subsidy / Access (dev state — batch4j)

| Item | Status | Priority | Evidence | Next Action |
|------|--------|----------|----------|-------------|
| enterprise-catalog (dev) | 🟢 HEALTHY | — | runtime (batch4j) | 6 catalogs, 4 queries, 109 content objects |
| enterprise-access (dev) | 🟢 HEALTHY | — | runtime (batch4j) | 0 LicenseRequests (expected for dev) |
| enterprise-subsidy (dev) | 🟢 HEALTHY | — | runtime (batch4j) | 0 Subsidies (expected for dev) |
| license-manager (dev) | 🟢 HEALTHY | — | runtime (batch4j) | 0 SubscriptionPlans; 0 restarts |
| enterprise-admin-portal (dev) | 🟡 NO INGRESS | P2 | runtime (batch4j) | Pod running but no ingress rule for `admin.academyv2.mereka.dev` — not browser-accessible |
| enterprise-learner-portal (dev) | 🟡 NO INGRESS | P2 | runtime (batch4j) | Pod running but no ingress rule — not browser-accessible |
| ecommerce (Oscar) in dev | 🟢 INTENTIONALLY ABSENT | — | runtime (batch4j) | Oscar stack not deployed in `mereka-lms-dev` at all |
| payments-gateway (dev + staging) | 🟡 RUNNING (9 restarts) | P2 | runtime (batch4j) | Dev: 9 restarts (Redis bgsave root cause). Staging: 35d uptime. |
| payments-gateway (prod) | 🟡 REPLICA COUNT UNCLEAR | P1 | repo_truth (b5-purchase-gateway) | Prod overlay shows `count: 1` with "dark launch" comment — but 0/0 was expected. Clarify intent and set explicitly. File: `overlays/production/kustomization.yaml` |
| Stripe keys: staging uses dev test key | 🟡 CONFIG GAP | P2 | repo_truth (b5-purchase-gateway) | Staging references `STRIPE_SECRET_KEY_DEV` (same as dev). Create dedicated `STRIPE_SECRET_KEY_STAGING` in Infisical. |
| Purchase Gateway CI test step | 🔴 MISSING | P1 | repo_truth (b5-purchase-gateway) | 229 async tests in 38 test files — **never run in CI**. `build-purchase-gateway.yml` has no pytest step. |
| PostgreSQL-payments ServiceMonitor | 🔴 MISSING | P2 | repo_truth (b5-purchase-gateway) | No SM for the payments PostgreSQL. Create `servicemonitor-postgresql-payments.yaml`. |
| Purchase Gateway Alembic migrations | 🟢 DONE | — | repo_truth (b5-purchase-gateway) | 2 migrations (`001_initial_schema`, `002_fulfillment_outbox_jobs`). Init container runs `alembic upgrade head` at pod start. |
| Purchase Gateway health endpoints | 🟢 DONE | — | repo_truth (b5-purchase-gateway) | `/health/` (DB+Redis+Stripe check), `/ready/` (lightweight), `/metrics` (Prometheus) all implemented. |
| MEREKA EC catalogs on prod | ❄️ PARKED | P3 | runtime_validated | User deferred — create via Django admin when ready |
| SOF EC catalogs | ❄️ PARKED | P3 | runtime_validated | User deferred |
| Biji-Biji duplicate catalogs | ❄️ PARKED | P4 | runtime_validated | Low priority cleanup |
| License manager `/mereka` slug | ⚪ NOT STARTED | P2 | unverified | Needs browser login test |

> Enterprise service ports: catalog:8160, access:18270, subsidy:18280, license-manager:18170 — NOT 8000. Health probes must use these ports.

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

### 8.2 Tenant Runtime Gaps (batch4h — runtime verified)

| Item | Status | Priority | Evidence | Next Action |
|------|--------|----------|----------|-------------|
| **Staging SOF SiteConfig MISSING** — `staging.skillourfuture.academyv2.mereka.io` | 🔴 BLOCKED | P1 | runtime (batch4h) | DB query confirmed: `SiteConfiguration` row does NOT exist for SOF in staging DB. SOF courses would bleed through Mereka `course_org_filter`. Create via Django admin or migration on `stg-mereka-lms`. |
| **`MEREKA_SITE_VARIANTS` SOF entry MISSING** in `tenant-resolution.js` | 🔴 BLOCKED | P1 | repo_truth (batch4h) | `infrastructure/tutor/plugins/_mereka_lms/mfe_runtime/tenant-resolution.js` has `'biji-biji.academyv2.mereka.io': _BIJI_BIJI` but NO `'skillourfuture.academyv2.mereka.io': _SKILL_OUR_FUTURE`. SOF MFE returns incorrect tenant config. |
| Dev Mereka org filter | 🟢 COMPLETE | — | runtime (batch4h) | `MEREKA` org filter verified in dev DB |
| Dev Biji-Biji org filter | 🟢 COMPLETE | — | runtime (batch4h) | `BIJI_BIJI` org filter verified in dev DB |
| Dev SOF org filter | 🟢 COMPLETE | — | runtime (batch4h) | `SOF` org filter verified in dev DB |
| Multi-tenancy spec (`multi-tenancy-architecture_spec.md`, 33 ACs) | 🟡 PARTIAL | P2 | repo_truth (b4-spec-gap) | ~8 ACs runtime proven (3-tenant routing). 17 ACs skipped (enterprise isolation). Full runtime proof incomplete. |

> **Fix for `tenant-resolution.js`** (1-line change):
> Add to `MEREKA_SITE_VARIANTS` in `infrastructure/tutor/plugins/_mereka_lms/mfe_runtime/tenant-resolution.js`:
> ```js
> 'skillourfuture.academyv2.mereka.io': _SKILL_OUR_FUTURE,
> ```

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

## Section 10: Observability & Monitoring (batch4g — full audit)

### 10.1 PrometheusRules

| Item | Status | Priority | Evidence | Next Action |
|------|--------|----------|----------|-------------|
| 12 active rules (auth, caddy, credentials, enterprise, ESO, libraries, LMS, services, velero, video, SLO×2) | 🟢 ACTIVE | — | repo_truth (batch4g) | Deployed via kustomization |
| `prometheusrule-email.yaml` | ❄️ QUARANTINED | P3 | repo_truth | SES exporter not deployed — `ses_bounce_total` metric missing. Deploy SES exporter to un-quarantine. |
| `prometheusrule-ora2.yaml` | ❄️ QUARANTINED | P4 | repo_truth | ORA2 custom instrumentation not emitted by stock Open edX |
| `prometheusrule-tenant-isolation.yaml` | ❄️ QUARANTINED | P3 | repo_truth | Depends on Pushgateway (not deployed) |
| SMTP pod — no active alert | 🔴 UNMONITORED | P2 | runtime (batch4g) | `smtp` deploy running but email rule quarantined; no alert if SMTP dies |
| Meilisearch — no PrometheusRule | 🔴 UNMONITORED | P2 | runtime (batch4g) | Forum search degradation completely invisible |

### 10.2 ServiceMonitors

| Item | Status | Priority | Evidence | Next Action |
|------|--------|----------|----------|-------------|
| 11 SMs active (caddy, LMS, CMS, credentials, discovery, mysql, redis, enterprise, notes, mux-monitor, mongodb-exporter) | 🟢 ACTIVE | — | repo_truth (batch4g) | |
| `servicemonitor-purchase-gateway.yaml` namespace mismatch | 🔴 BROKEN | P1 | repo_truth (batch4g) | Targets `namespaceSelector: mereka-lms` but deploy is in `mereka-lms-dev`. Add kustomize patch per env. |
| `meilisearch` — no ServiceMonitor | 🔴 MISSING | P2 | repo_truth (b5-meilisearch) | Meilisearch v1.8.4 exposes `/metrics` on port 7700 but port has no `metrics` annotation. Create `servicemonitor-meilisearch.yaml`. |
| `meilisearch` — `servicemonitor-forum.yaml` QUARANTINED | ℹ️ BY DESIGN | — | repo_truth (b5-meilisearch) | Forum v2 runs in-process in LMS pod — would duplicate LMS time-series. Correct to keep quarantined. |
| `mongodb-exporter` — no ServiceMonitor | 🔴 MISSING | P2 | repo_truth (b5-mongodb) | `mongodb-exporter` deployment IS running (1/1, 43h) but has no SM. Either add SM or remove the deployment if vestigial. |
| `postgresql-payments` — no SM | 🔴 MISSING | P2 | repo_truth (b5-purchase-gateway) | Purchase gateway DB unmonitored. Create `servicemonitor-postgresql-payments.yaml`. |
| Worker pods (cms-worker, lms-worker, enterprise-*-worker) — no /metrics | ⚪ DEFERRED | P3 | repo_truth | Workers have no HTTP endpoint — kube-state coverage only |

### 10.3 SLO Coverage

| Item | Status | Priority | Evidence |
|------|--------|----------|----------|
| SLO recording rules (7 journeys: LMS login/course, CMS authoring, checkout, webhook, forum, MFE) | 🟢 COMPLETE | — | repo_truth (batch4g) |
| SLO burn-rate rules | 🟢 COMPLETE | — | repo_truth (batch4g) |
| SLO overview Grafana dashboard (`slo-overview.json`, 22 panels) | 🔴 NOT DEPLOYED | P1 | runtime (batch4g) | File exists in repo but NOT loaded as Grafana configmap. Add to monitoring namespace with `grafana_dashboard=1` label. |

### 10.4 Alert Routing

| Item | Status | Priority | Evidence | Next Action |
|------|--------|----------|----------|-------------|
| Slack webhook wired (`#nonprod-alerts`) | 🟢 DONE | — | runtime (batch4g) | ESO-managed `alertmanager-slack-webhook` |
| Critical + warning both → same Slack channel | 🟡 PARTIAL | P2 | runtime (batch4g) | No severity-based routing; critical alerts don't page anyone |
| No production-specific receiver | 🔴 MISSING | P1 | runtime (batch4g) | All envs go to `#nonprod-alerts` — prod alerts mixed with dev noise |
| No PagerDuty / OpsGenie escalation | 🔴 MISSING | P2 | runtime (batch4g) | Critical alerts can be missed if Slack is not actively watched |
| No dead-man's switch (heartbeat) | ⚪ NOT STARTED | P3 | unverified | No probe verifying alertmanager pipeline end-to-end |

### 10.5 Synthetic / Blackbox Checks

| Item | Status | Priority | Evidence | Next Action |
|------|--------|----------|----------|-------------|
| Blackbox exporter deployed | 🔴 NOT DEPLOYED | P1 | runtime (batch4g) | Zero `Probe` CRD objects in cluster. No blackbox exporter deployment. |
| Synthetic probe for `academyv2.mereka.io` | 🔴 MISSING | P1 | runtime (batch4g) | No external HTTP/HTTPS probe hitting production URL |
| Certificate validity synthetic check | 🔴 MISSING | P2 | runtime (batch4g) | `cert-verify-prod` CronJob fails (see §1.4) — no replacement |

### 10.6 Grafana

| Item | Status | Priority | Evidence | Next Action |
|------|--------|----------|----------|-------------|
| 36 infrastructure dashboards loaded (kube, ARC, ArgoCD, cert-manager, Velero) | 🟢 LOADED | — | runtime (batch4g) | |
| `slo-overview.json` (22-panel LMS SLO dashboard) | 🔴 NOT LOADED | P1 | runtime (batch4g) | Must add as ConfigMap with `grafana_dashboard=1` label |
| `daily-infrastructure-audit.yml` | 🟢 DONE | — | repo_truth | Merged observability + parity workflows |

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
| `protect-gitops-managed-resources` Kyverno policy | 🔴 MISSING | P1 | runtime (b5-kyverno) | NOT deployed, NOT in repo. Security runbook at `docs/ops/runbooks/SECURITY_INCIDENT_SUPPLY_CHAIN.md:61` assumes it blocks mutations — creates false confidence. Implement in `bbi-infrastructure`. |
| All 13 Kyverno policies in **AUDIT mode** (none enforced) | 🟡 AUDIT_ONLY | P2 | runtime (b5-kyverno) | 408 violations across 22 namespaces — none blocked. stg-mereka-lms: 98, mereka-lms-dev: 96. Phase to Enforce after fixing violations. |
| 4 app-repo policy files should move to `bbi-infrastructure` | 🟡 OWNERSHIP_GAP | P3 | repo_truth (b5-kyverno) | `deploy/k8s/base/policies/*.yaml` — DEPLOYMENT_CONTRACT.md says these belong in GitOps infra repo. Migrate when other moves proceed. |
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
| Email & Notifications pipeline | — | 45 | 🟢 DONE (all 6 phases) | — | CLOSED |
| Content Libraries v2 | — | 33 | ❄️ PARKED | P3 | TBD |
| Verifiable Credentials / OBv3 | — | ~40 | ⚪ NOT STARTED | P4 | TBD |
| HubSpot Registration (K8s-native) | — | 26 | ❄️ PARKED | P3 | After MCT live |
| Ecommerce Purchase Gateway (Stripe) | — | 33 | 🟡 IN PROGRESS | P2 | TBD |
| Paragon Design Tokens Migration | — | 41 | ⚪ NOT STARTED | P3 | After OEP-48 |
| Auth/SSO Enterprise Tier 5 | — | 45 | 🟡 IN PROGRESS | P2 | TBD |

---

### 12.1 Video Pipeline Phase Status (batch4f — runtime verified)

> **Mux API credentials are LIVE and verified working** (`MUX_TOKEN_ID`/`MUX_TOKEN_SECRET` from ESO).

| Phase | Description | Status | Priority | Blocker |
|-------|-------------|--------|----------|---------|
| Phase 1 | Mux API integration + upload infrastructure | 🟢 DONE | — | — |
| Phase 2 | MCT video mapping (503 videos) | 🟢 DONE | — | `exports/mct/video_mapping_openedx.json` complete |
| Phase 3 | Mux delivery monitor deployment | 🟡 AT_ZERO_REPLICAS | P1 | `kubectl scale deploy mux-delivery-monitor -n mereka-lms --replicas=1` — pod manifest exists, 0/0 replicas |
| Phase 4 | Custom video apps in `INSTALLED_APPS` | 🔴 BLOCKED | P0 | Apps (`mux_upload`, `video_analytics`, `video_protection`, `video_pipeline`) **installed in Docker image** but NOT in `INSTALLED_APPS` in running pod's `production.py`. Tutor `lms_settings` patch is MISSING from the deployed config. Must add via `apply-patches.sh`. |
| Phase 5 | Mux signing keys (signed playback URLs) | ⚪ NOT STARTED | P2 | Blocked on Phase 4 + key provisioning in Infisical |
| Phase 6 | XBlock integration (in-course video) | ⚪ NOT STARTED | P3 | Blocked on Phase 4–5 |
| Phase 7 | Analytics (xAPI events → ClickHouse) | ⚪ NOT STARTED | P3 | Blocked on Phase 4 + Aspects tracking-log PVC |

> **Video mapping**: 503 MCT videos fully mapped at `exports/mct/video_mapping_openedx.json`. ServiceMonitor `servicemonitor-mux-monitor.yaml` exists in repo.
>
> **Critical path**: Phase 4 (INSTALLED_APPS patch) unblocks all remaining phases. Fix is 1 line in `apply-patches.sh` / `mereka_lms.py` plugin.

---

## Section 11b: Dependency Security (batch4e)

| Package / Area | Status | Priority | Issue | Action |
|---|---|---|---|---|
| **pip-audit CI scan scope** | 🔴 BROKEN | P1 | CI scans only pip-audit's own deps (no `-r` flag) — `requirements-tutor.txt` and `kajabi-webhook/requirements.txt` are **never audited** | Add `-r requirements-tutor.txt` to `pip-audit` invocation in `ci.yml:862` |
| `.devcontainer/Dockerfile` | 🔴 STALE | P1 | Tutor `18.2.2` (Quince) vs project's `21.0.2` (Ulmo) — any dev using devcontainer has incompatible CLI | Update to `tutor[full]==21.0.2` |
| `tutor-contrib-aspects` | 🟡 UNPINNED | P2 | Installed in `.venv` (`3.0.3`) but absent from `requirements-tutor.txt` — CI won't install it | Add `tutor-contrib-aspects==3.0.3` to `requirements-tutor.txt` |
| `requirements-ci.txt` | 🟡 UNPINNED | P2 | `pyyaml`, `ruff`, `yamllint`, `jinja2` all unpinned — CI tools can break silently on new releases | Add version bounds (`ruff>=0.9,<1`, etc.) |
| `uvicorn` in kajabi-webhook | 🟡 OUTDATED | P2 | `0.30.6` vs current `0.34.x` — `0.32+` includes security and HTTP/2 fixes | Bump to `>=0.32.0` |
| `moment.js` in hubspot-webhook | 🟡 DEPRECATED | P2 | Officially deprecated library; `^` semver = silent major upgrades | Replace with `dayjs`; run `npm audit` |
| Tutor venv drift (21.0.0 vs 21.0.2) | 🟡 STALE | P2 | Local `.venv` two patch versions behind CI pin | `pip install -r requirements-tutor.txt` |
| `django-prometheus==2.3.1` | 🟡 OUTDATED | P3 | ~2022 release; current is 2.5.0 (adds Django 5.x support) | Update to `>=2.3.1,<3` |
| `brand-mereka` Paragon loose pin | 🟡 AT_RISK | P3 | `^23.19.1` = any 23.x pulled at build time; no lockfile | Add `package-lock.json` |
| `Pygments` CVE-2026-4539 | 🟡 SUPPRESSED | P3 | ReDoS in AdlLexer; local-only; no upstream fix; correctly suppressed in CI | Monitor for ≥2.19.3 release |
| `platform-plugin-aspects<1.1.3` | ℹ️ INTENTIONAL | — | Python 3.12 requirement in 1.1.3+; cap is intentional | Unblock when platform → Python 3.12 |
| `edx-event-routing-backends>=9.3.5,<9.4` | ℹ️ RANGE PIN | — | Non-hermetic; could resolve to different patch in CI vs prod | Consider exact `==9.3.5` pin |

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

## Section 13b: Test Coverage (batch4-testing)

| Area | Tests | CI-Enforced | Blocking | Status | Gap |
|------|-------|------------|---------|--------|-----|
| `tests/` (core) | 185 across 15 files | Yes (pytest) | **No** — `continue-on-error: true` | 🟡 | `.coverage` artifact missing from last CI run — gate is invisible |
| `custom-apps/` (21 apps) | **1,318 tests** | **No** | — | 🔴 | Tests exist and NEVER run in CI |
| K8s multisite (LMS settings) | 52 tests | Partial (path-gated) | Yes | 🟢 | No CMS equivalent |
| purchase-gateway | 229 tests (unit + integration) | **No** | — | 🔴 | `build-purchase-gateway.yml` skips test step entirely |
| E2E Playwright | 5 spec files | **No** (manual dispatch only) | — | 🔴 | Daily schedule cron commented out |
| QA shell scripts | 775 scripts (~177K lines) | Partial (static shard) | Yes | 🟡 | Runtime scripts never run in CI |
| Tutor shell tests | 6 scripts | Yes | Yes | 🟢 | Requires real Tutor — can't mock |
| Spec coverage gate | 80% threshold | Yes | **Yes** | 🟢 | Measures AC linkage, not code coverage |

**Top 3 CI test gaps to close (batch4-testing):**
1. 🔴 **Wire `custom-apps/` to CI** — 1,318 tests in 21 apps, zero CI execution, regressions completely invisible
2. 🔴 **Wire `purchase-gateway` tests** — 229 async tests, `build-purchase-gateway.yml` has no test job
3. 🟡 **Remove `continue-on-error: true` from `test-coverage` job** — currently swallows failures silently; `.coverage` artifact missing from latest run means actual % unknown

**Skill**: `test-coverage-enhancer`, `gh-actions`

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

---

## Section 17: Email / SMTP Pipeline (b5-smtp)

> **Correction to Section 12**: Email & Notifications pipeline is **FULLY COMPLETE** (all 6 phases merged). Was incorrectly listed as NOT STARTED.

| Item | Status | Priority | Evidence | Next Action |
|------|--------|----------|----------|-------------|
| SMTP service (exim-relay) | 🟢 RUNNING | — | repo_truth (b5-smtp) | `devture/exim-relay:4.96-r1-0`; relays to AWS SES `email-smtp.ap-southeast-1.amazonaws.com:587` via STARTTLS |
| LMS email delivery path | 🟢 WORKING | — | repo_truth (b5-smtp) | LMS → `smtp:8025` (exim) → AWS SES. SES credentials from ExternalSecrets. |
| Email Phase 1–6 (45 ACs) | 🟢 COMPLETE | — | repo_truth (b5-smtp) | All 6 phases merged to main: SES infra, bounce handling, ACE channels, in-app tray, push (FCM), multi-lang templates, bulk campaigns, digests, analytics. |
| `prometheusrule-email.yaml` quarantined | 🔴 QUARANTINED | P1 | repo_truth (b5-smtp) | 7/8 rules non-functional (depend on SES exporter). `SMTPRelayPodDown` alert CAN fire but is quarantined. Un-quarantine at minimum to get pod-down alerting. |
| SES exporter NOT deployed | 🔴 MISSING | P1 | repo_truth (b5-smtp) | No SES CloudWatch metrics exporter → no visibility into bounce/complaint rates, quota, delivery latency. Build or source SES → Prometheus exporter. |
| `DEFAULT_FROM_EMAIL` — base config is `contact@localhost` | 🟡 VERIFY | P2 | repo_truth (b5-smtp) | Likely overridden by overlay `MEREKA_CONTACT_EMAIL`. Confirm production uses `contact@academyv2.mereka.io` or similar. |
| SES account sandbox vs production mode | ⚪ UNVERIFIED | P2 | unverified | If still in sandbox mode, delivery only goes to verified recipients. Verify DKIM/SPF/DMARC for `academyv2.mereka.io` and `academy.biji-biji.com`. |
| Phase 6 analytics → ClickHouse | 🟡 UNVERIFIED | P2 | unverified | Phase 6 engagement analytics needs ClickHouse for durable storage. Verify xAPI flow from email events. |

---

## Section 18: MySQL Health (b5-mysql)

| Item | Status | Priority | Evidence | Next Action |
|------|--------|----------|----------|-------------|
| MySQL 8.4.0, PVC 5Gi | 🟢 HEALTHY | — | repo_truth (b5-mysql) | `mysql_native_password=ON` enforced via deployment arg. `mysqld_exporter` sidecar on port 9104. |
| ServiceMonitor + 5 PrometheusRules | 🟢 ACTIVE | — | repo_truth (b5-mysql) | Rules: MySQLPodDown, MySQLExporterDown, MySQLHighConnectionUtilization, MySQLSlowQueriesSpike, HighPVCUtilization. Plus GCP Cloud Monitoring alerts. |
| Production CPU request reduced to 10m | 🟡 WATCH | P2 | repo_truth (b5-mysql) | Prod overlay sets MySQL CPU request to `10m` (from base `500m`). Same aggressive reduction as Redis. Risk: throttling under peak. |
| 5Gi PVC with 99K users + 176K enrollments | 🟡 WATCH | P2 | repo_truth (b5-mysql) | Alert at 80% (4Gi used). With import data growing, may need expansion. Add 90% CRITICAL alert. |
| InnoDB buffer pool hit rate — no alert | ⚪ MISSING | P3 | repo_truth (b5-mysql) | Add to `prometheusrule-lms.yaml` — target >99% hit rate |
| Slow query log | ⚪ NOT CONFIGURED | P3 | repo_truth (b5-mysql) | Enable `--slow-query-log=ON --long-query-time=1.0` in deployment args |
| Single MySQL pod — SPOF | 🟡 ARCH_RISK | P4 | repo_truth (b5-mysql) | No read replica. Read replica strategy needed for HA. |

---

## Section 19: Celery Workers (b5-celery)

| Worker | Replicas | Concurrency | Status | Restarts |
|--------|----------|-------------|--------|----------|
| lms-worker (prod) | 2 | 2 | 🟢 HEALTHY | 0 |
| cms-worker (prod) | 1 | 2 | 🟢 HEALTHY | 0 |
| enterprise-catalog-worker | 1 | 2 | 🟢 HEALTHY | 0 |
| enterprise-access-worker | 1 | 2 | 🟢 HEALTHY | 0 |
| **lms-beat (scheduler)** | **0** | — | 🔴 NOT DEPLOYED | — |

> Total capacity: 4 pods, 10 maximum concurrent tasks.

| Item | Status | Priority | Evidence | Next Action |
|------|--------|----------|----------|-------------|
| **Celery Beat NOT deployed** | 🔴 MISSING | P1 | repo_truth (b5-celery) | `CELERYBEAT_SCHEDULE` defines 4h syncs (`integrated_channels_content_metadata_sync`, `integrated_channels_learner_data_sync`) but no Beat Deployment in any overlay. Channel syncs silently not running. Deploy `lms-beat` or convert to CronJobs. |
| Production worker CPU request: 10m | 🟡 WATCH | P2 | repo_truth (b5-celery) | Prod overlay sets worker CPU request to `10m` (same aggressive reduction pattern as MySQL + Redis). Risk: task starvation at high cluster load. |
| Redis DB allocation (8/16 used) | 🟢 ADEQUATE | — | repo_truth (b5-celery) | DBs 0,8,9,10,11,12,13,14 allocated. 8 free for future services. Document in runbook to prevent collisions. |
| Queue depth monitoring | ⚪ NOT STARTED | P2 | unverified | No alert for queue depth >1000 pending tasks for >5min. Add to PrometheusRules. |
| Task fan-out for integrated channels | ⚪ UNVERIFIED | P2 | unverified | Verify if Degreed/Canvas/Cornerstone channel integrations are configured — if yes, they're not syncing. |

---

## Section 15: MongoDB Atlas (b5-mongodb)

| Item | Status | Priority | Evidence | Next Action |
|------|--------|----------|----------|-------------|
| Atlas connectivity configuration | 🟢 DONE | — | repo_truth (b5-mongodb) | SRV protocol, SSL auto-detect, `pymongo[srv]` installed. ExternalSecrets map all 4 Atlas keys. |
| `mongodb-exporter` deployment (43h uptime) | 🟡 VESTIGIAL RISK | P2 | runtime (b5-mongodb) | Running 1/1 but no ServiceMonitor. Is this legacy from pre-Atlas? If not used: `kubectl delete deployment mongodb-exporter -n mereka-lms`. |
| `verify-mongodb-atlas-integration.sh` — 3 failing checks | 🟡 FALSE POSITIVES | P2 | repo_truth (b5-mongodb) | 2 checks incorrectly flag env injection as missing (env IS injected). 1 check fails because mongodb-exporter deployment exists. Fix script assertions. |
| `dnspython` not explicitly pinned | 🟡 RISK | P2 | repo_truth (b5-mongodb) | SRV resolution requires `dnspython>=2.0`. Not in `OPENEDX_EXTRA_PIP_REQUIREMENTS`. Add it explicitly; verify with `python -c "import dns"` in LMS pod. |
| Forum + modulestore share same MongoDB password | 🟡 ISOLATION GAP | P3 | repo_truth (b5-mongodb) | `MEREKA_LMS_MONGODB_PASSWORD` used for both. Create separate Atlas users: `modulestore-user` (openedx DB) + `forum-user` (cs_comments_service). |
| No Atlas metrics in Prometheus | 🔴 UNMONITORED | P2 | repo_truth (b5-mongodb) | Cannot alert on connection pool exhaustion, replication lag, or query latency. Integrate Atlas API metrics or Atlas Prometheus integration. |
| Atlas backups | ⚪ NOT STARTED | P3 | unverified | Verify point-in-time recovery enabled in Atlas console; set 7d retention |

---

## Section 16: Meilisearch Operations (b5-meilisearch)

| Item | Status | Priority | Evidence | Next Action |
|------|--------|----------|----------|-------------|
| Meilisearch v1.8.4 — running | 🟢 DEPLOYED | — | repo_truth (b5-meilisearch) | Image pinned; 2Gi PVC; health probe on `/health` port 7700. |
| Forum search configured | 🟢 DONE | — | repo_truth (b5-meilisearch) | `MEILISEARCH_ENABLED=True`, `SEARCH_ENGINE=search.meilisearch.MeilisearchEngine`, index prefix `tutor_`. |
| Content Libraries v2 search | 🟢 DONE | — | repo_truth (b5-meilisearch) | `content_libraries` + `library_components` indexes used. |
| No ServiceMonitor | 🔴 MISSING | P1 | repo_truth (b5-meilisearch) | Meilisearch v1.8.4 exposes `/metrics` on port 7700. Create `servicemonitor-meilisearch.yaml` + add `metrics` port annotation to Service. |
| No PrometheusRule | 🔴 MISSING | P1 | repo_truth (b5-meilisearch) | No alert for MeilisearchDown, search latency, or PVC usage. Create `prometheusrule-meilisearch.yaml`. |
| No forum reindex CronJob | 🟡 MISSING | P2 | repo_truth (b5-meilisearch) | `cronjob-course-reindex.yaml` covers ES course_info but no equivalent for forum discussion indexes. Add weekly forum reindex job. |
| PVC only 2Gi | 🟡 WATCH | P3 | repo_truth (b5-meilisearch) | With forum + content-libraries indexes growing, 2Gi may need expansion. Alert when >85% full. |

---

## Section 14: Spec-to-Reality Gap Analysis — Tier 4–6 (b4-spec-gap)

> **Coverage tool inflation warning**: `spec_coverage_report.py` reports 100% mapped / 85.7% automated.
> "Automated" = `@covers` annotation exists in a script on disk. It does NOT mean the check passes,
> runs in CI, or has browser proof. True implementation rate for Tier 4–6 is **~40–55%** of ACs.

| Spec | Tier | ACs | @covers | Runtime Proven | Deferred | Real Status |
|------|------|-----|---------|----------------|----------|-------------|
| `design-tokens-system` | 4 | 12 | 12 (100%) | ~12 (repo-truth only) | 0 | CI-complete; no browser proof |
| `multi-tenancy-architecture` | 4 | 33 | 33 (100%) | ~8 (3-tenant routing) | 17 | Partial runtime; enterprise isolation unfiled |
| `oep48-brand-package` | 4 | 37 | 28 (76%) | ~20 (MFE login) | 9 | Partial; Studio branding stalled |
| `mfe-plugin-slots` | 4 | 29 | 29 (100%) | ~1 (footer only) | 28 (manual) | Source verified; browser proof absent |
| `slo-sla-service-level-management` | 4 | 53 | 53 (100%) | rules deployed; dashboard NOT | 10 | Rules live; Grafana dashboard P1 missing |
| `frontend-accessibility` | 4 | 27 | 5 (19%) | 0 | 23 | **FILED-ONLY** — 23 ACs have zero scripts |
| `studio-customization` | 4 | 28 | 8 (29%) | 0 | 20 | **FILED-ONLY** — SSO loop blocks all proof |
| `frontend-performance-budgets` | 4 | 30 | 7 (23%) | 0 | 18 | **FILED-ONLY** — no CI enforcement |
| `auth-sso-enterprise` | 5 | 45 | 45 (100%) | 18 (static config) | 27 | Config foundations only; enterprise IdP = business blocker |
| `enterprise-microservices` | 6 | 37 | 37 (100%) | ~25 (prod deployments) | 3 | Best coverage; SSO federation + channels gaps |
| `paragon-design-tokens-migration` | 5 | 41 | 0 (0%) | 0 | 41 | **NOT STARTED** — blocked on OEP-48 |

### Critical Spec Gaps (b4-spec-gap)

| Finding | Status | Priority | Action |
|---------|--------|----------|--------|
| **Three specs filed-only** (`accessibility`, `studio-customization`, `perf-budgets`) | 🔴 PAPER_SPEC | P2 | Either build scripts + CI coverage, or formally defer with rationale |
| **Auth/SSO Tier 5 — 27/45 ACs need enterprise IdP** | 🔴 BUSINESS_BLOCKER | P2 | Cannot implement SAML federation, SCIM, MFA enforcement without real enterprise customer IdP. Not a technical blocker. |
| **SLO Grafana dashboard not deployed** (`slo-overview.json`) | 🔴 P1 UNDEPLOYED | P1 | Already in §10.3. File exists, not loaded as Grafana ConfigMap. Blocks AC-008, AC-009. |
| **Testmaps have NO `status` field on any AC** | 🟡 FORMAT_DEBT | P3 | All 29 testmap YAMLs in `specs/plans/` adopted format but never populated `status:` field. Every AC shows `NO_STATUS`. |
| **Coverage inflation**: `@covers` ≠ CI-bound ≠ passing | 🟡 MISLEADING | P2 | Document in spec governance: coverage tool measures annotation density, not behavioral proof. |
| Enterprise microservices SSO (AC-026..029) | 🔴 BLOCKED | P2 | SAML/OIDC federation ACs share the enterprise IdP blocker with auth-sso spec |
| Enterprise integrated channels (AC-030..032: Degreed, Canvas) | ⚪ NOT STARTED | P3 | Not in current deployment manifest; no connector exists |

---

## Tracker Update Log

| Date | Batch | Skills Used | Key Findings |
|------|-------|-------------|--------------|
| 2026-04-03 | Seed | Manual synthesis from status docs | Initial tracker created |
| 2026-04-03 | Batch 1 | live cluster diagnostics (ArgoCD, pods, images, workers, CronJobs, ARC, ESO, Velero, dev image drift) | **COMPLETE** — ArgoCD both envs Healthy; prod 31/31; staging 54 failed pods; Velero FailedValidation (VolumeSnapshotLocation missing); 6 CronJob failures with distinct root causes; ARC healthy; ESO all synced; dev image `00ad100e` (same as prod, docs were stale) |
| 2026-04-03 | Batch 2 | frontend/branding/gitops (MFE Dockerfile, branch states, tenant logos, footer, open PRs, OIDC script, first-class-domains, CI inventory) | **COMPLETE** — MFE Ulmo done; logos in repo; head-extra 83L; footer wired; import #1275 merged + 5 follow-on unPRed; first-class-domains 23 commits no PR; OIDC uncommitted local changes; CI inventory PASS |
| 2026-04-03 | Batch 3 | security/infra/debt (secrets, ESO completeness, worker limits, Velero manifest, ARC dry-run, Kyverno, script registry, tech debt, Aspects prod, head-extra) | **COMPLETE** — Secrets CLEAN; CH user ESO mappings DONE; Kyverno `protect-gitops-managed-resources` NOT DEPLOYED (critical gap); Aspects prod NOT dormant (replicas=1); `openedx_assessment_bulk` has 5 unimplemented TODOs; Velero Schedule not in GitOps |
| 2026-04-03 | Batch 4 (10 agents) | PRs, testing, CronJobs, observability, deps, enterprise-nonprod, migrations, tenancy, video, spec-gaps | **COMPLETE (10/10)** — CI has 8 systemic failures on main; 1,318 custom-app tests never run in CI; `openedx_tenant_cache` unapplied (P0 blocked); SOF staging SiteConfig MISSING + `tenant-resolution.js` SOF entry MISSING; Mux creds LIVE but INSTALLED_APPS patch absent (critical path); delivery monitor at 0 replicas; spec coverage tool inflated (real ~40-55% Tier 4-6); 3 specs filed-only with no CI; enterprise IdP = business blocker for 27/45 auth ACs |
| 2026-04-03 | Batch 5 (10 agents) | Redis, Purchase Gateway, Discovery, Meilisearch, MongoDB, Credentials/Notes, SMTP, Branches, Kyverno, MySQL, Celery | **COMPLETE (10/10)** — Redis P0: maxmemory 4gb vs 128Mi prod limit + 1Gi PVC (OOM guaranteed); Discovery CI failures = stale checks for deleted course_about.html; Email pipeline ALL 6 PHASES DONE (was wrongly NOT STARTED); Celery Beat NOT deployed (channel syncs silently broken); all 13 Kyverno policies AUDIT mode + 408 violations; purchase-gateway test step missing; `notes-migrate.yaml` also missing; mongodb-exporter vestigial; Meilisearch /metrics unconfigured; 60 commits backlogged in 3 stale branches |
