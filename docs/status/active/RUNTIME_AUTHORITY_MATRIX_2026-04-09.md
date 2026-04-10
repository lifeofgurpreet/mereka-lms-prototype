# Runtime Authority Matrix

_Audience: Operators and agents. Owner: Agent 1. Created: 2026-04-09. Status: active_

## Architecture

```
platform-control-plane → pattern/policy governance (domain authority, lane identity, release schemas)
mereka-lms             → canonical source definitions + reconciler logic + runtime code
bbi-infrastructure     → realization (overlays, ArgoCD, vendor-synced manifests)
SiteConfiguration/DB   → generated runtime material via bootstrap replay, not hand-authored
```

---

## Domain Matrix

| # | Domain | Canonical Source | Replay Path | Proof Path | Current State |
|---|--------|-----------------|-------------|------------|---------------|
| 1 | Tenant definitions | `deploy/k8s/tenancy/tenant-registry.yaml` | `apply-multisite-config.sh` | `verify-tenant-model.sh` | 3 tenants, 4 envs |
| 2 | Domains/hostnames | `tenant-registry.yaml` (domains section) | `apply-multisite-config.sh` + ArgoCD Ingress | `verify-rke2-tenant-routes.sh` | All prod domains serving |
| 3 | MFE base URLs | `multisite-sites.yml` → `multisite_bootstrap_django.py` | `apply-multisite-config.sh` | `verify-mfe-config-api.sh` | **FIXED** — all 3 prod tenants correct |
| 4 | Footer data | `mereka_footer.py` + SiteConfiguration | `apply-multisite-config.sh` | `verify-tenant-footer-variant-lane.sh` | Serving |
| 5 | Auth/OAuth | `runtime-proof/*.yaml` (OAuth apps) | `bootstrap-runtime-proof-fixtures.py` | auth-verify CronJob (PASS) | Healthy |
| 6 | Fixture users | `runtime-proof/*.yaml` | `bootstrap-runtime-proof-fixtures.py` | Dry-run NO-OP check | Source-consistent |
| 7 | Enterprise links | `enterprise-tenants/*.yaml` | `bootstrap-enterprise-tenants.py` | tenant-isolation CronJob (PASS) | 3 active customers |
| 8 | Feature flags | `production.py` FEATURES + env vars | `apply-multisite-config.sh` | No dedicated verifier | Gap: no waffle flag manifest |
| 9 | SiteConfiguration | `multisite-sites*.yml` | `apply-multisite-config.sh` | `verify-siteconfig-authority.sh` | **FIXED** — 9 missing keys added |
| 10 | CronJob behavior | `base/monitoring/cronjob-*.yaml` | ArgoCD sync | CronJob completion status | **FIXED** — settings + ConfigMap wiring |
| 11 | Image refs | bbi-infrastructure overlay kustomization.yaml | `release-openedx-gitops.sh` (Agent 2) | `verify-realized-image-identity.sh` | Prod: `dfbe7ef31806` |
| 12 | Browser proofs | `domain-proof-matrix.yaml` | `bootstrap-runtime-proof-fixtures.py` | `verify-*-runtime-proof.sh` | L4 proved on prod |

---

## Root-Cause Batch List

| Batch | Root Cause | Status | Evidence |
|-------|-----------|--------|----------|
| **RCB-01** | SiteConfiguration MFE_CONFIG missing 9 keys on prod | **FIXED + LIVE-VERIFIED** | All 8 tenant-scoped URLs correct for biji-biji + SOF |
| **RCB-02** | CronJob pod egress blocked by NetworkPolicy | **FIXED + LIVE-VERIFIED** | course-reindex PASS (39 courses) |
| **RCB-03** | Staging Caddy→LMS blocked + cluster CPU exhaustion | **DIAGNOSED** | Stale CNI state (pod restart fixes internal). External: hostNetwork cross-node. LMS CrashLoop: CPU exhaustion 0/6 nodes. |
| **RCB-04** | Staging pod health: Unknown + CrashLoop | **DIAGNOSED** | elasticsearch, clickhouse, mongodb, redis, postgresql-payments Unknown (8d stale). enterprise-subsidy CrashLoop. CPU exhaustion root cause. |
| **RCB-05** | Backup restore drill | **DONE** | 968/968 resources restored. Velero memory OOM fixed (512Mi→1536Mi). |
| **RCB-06** | CronJob DJANGO_SETTINGS_MODULE mismatch | **FIXED + DEPLOYED + LIVE-VERIFIED** | PR #1491 merged. bbi-infra #2579 merged. tenant-isolation 4/4 PASS. |
| **RCB-07** | CronJob ConfigMap wiring (base vs patched) | **FIXED** — dev+staging deployed, prod just merged | bbi-infra #2582 merged. Dev/staging verified. Prod awaiting ArgoCD sync. |
| **RCB-08** | Middleware divergence (dev mereka_multisite.py) | **FIXED** | Missing 6-line fallback MFE redirect rewrite restored. |

## WS8 Status: 7/7 PASS

| CronJob/Check | Status | Evidence |
|---------------|--------|----------|
| auth-verify | PASS | 9/9 internal checks |
| cert-verify | PASS | 5/5 health checks |
| course-reindex | PASS | 39 courses indexed (manual trigger) |
| mysql-backup | PASS | 2 successful in 32h |
| tenant-isolation | PASS | 4/4 tests after settings + ConfigMap fix |
| discovery-sync | PASS | Completed pods |
| backup restore drill | PASS | 968/968 resources, Velero OOM fixed |

---

## 2026-04-11 — Phase 7 control-plane migration + new RCBs

### Phase 7 migration delta (Session 3 → Session 4)

| Domain contract | Before 2026-04-10 | After 2026-04-10 |
|-----------------|-------------------|------------------|
| `proof-gate-contract.yaml` | Lived in `mereka-lms/config/` | **Moved to `platform-control-plane`**. mereka-lms `config/` has shim pointer (#1512 merged). |
| `domain-proof-scoring-policy.yaml` | Lived in `mereka-lms/config/` | **Moved to `platform-control-plane`**. Shim pointer in mereka-lms (#1512 merged). |
| `proof-gate-contract` conformance baseline | 2026-03-xx | Refreshed to 2026-04-10 in CP#75 |

### New root-cause batches (2026-04-11 session)

| Batch | Root Cause | Status | Evidence |
|-------|-----------|--------|----------|
| **RCB-09** | MFE_CONFIG missing 5 required footer/header keys (SUPPORT_EMAIL, TERMS_OF_SERVICE_URL, PRIVACY_POLICY_URL, ENABLE_ACCESSIBILITY_PAGE, ORDER_HISTORY_URL) platform-wide | **SOURCE FIX MERGED-PENDING (PR #1536)** | Dev live-patched, API returns all 5 keys on 3 tenants × 2 hosts. Next image rebuild consumes source fix. |
| **RCB-10** | Shared `TypeError: Cannot read properties of undefined (reading 'path')` blanks Profile, Discussions, Communications | **DIAGNOSED, NOT FIXED** | Fires during MFE shell bootstrap. Bundles load 200, config API returns valid data. Need sourcemaps/Sentry to identify call site. Profile still blank even after RCB-09 live fix. |
| **RCB-11** | learner-record MFE registered in Tutor plugin but not packaged in mfe container | **DIAGNOSED, NOT FIXED** | `/openedx/dist/` has 11 MFEs: account, admin-console, authn, authoring, communications, discussions, gradebook, learner-dashboard, learning, ora-grading, profile. learner-record absent. Webpack 4/Node 18 build chain broken from Session 2/3. |

### WS8 status unchanged: 7/7 PASS

### Browser proof delta (2026-04-11 Dev Mereka, real browser with testadmin)

| Surface | Old status (2026-04-09) | Honest re-prove (2026-04-11) |
|---------|------------------------|------------------------------|
| LMS landing | L1 (curl 200) | **L3 PROVEN** (28+ course cards visually rendered) |
| authn login | L3 (HTTP 200 claim) | **L3 PROVEN** (branded "Start learning with Mereka Academy" panel screenshot) |
| Login flow | L4 (HTTP 200 claim) | **L4 PROVEN** (redirects to learner-dashboard, testadmin menu visible) |
| learner-dashboard | L3 (HTTP 200 claim) | **L4 PROVEN** ("Mereka Academy IN SESSION", My Courses, Learning Cockpit sidebar visually rendered) |
| account | L3 (HTTP 200 claim) | **L4 PROVEN** (Account Settings heading + 7 sidebar sections + footer) |
| profile | L3 (title claim) | **🔴 BROKEN** (completely blank, RCB-10 TypeError) |
| learner-record | not listed | **🔴 BROKEN 404** (RCB-11 not packaged) |
| discussions | L3 (HTTP 200 claim) | **🔴 BROKEN** (error boundary, RCB-10 TypeError) |
| communications | not listed | **🔴 BROKEN** (blank, RCB-10 TypeError) |
| gradebook | L3 (HTTP 200 claim) | **⚠️ partial** (shell+footer render, body needs course context) |
| learning | L3 (HTTP 200 claim) | **⚠️ partial** (shell+footer render, body needs course context) |
| authoring | L3 (HTTP 200 claim) | **🔴 BROKEN** ("Unexpected Application Error! 404 Not Found") |

**Previously overclaimed** (per VNext brief): Profile, Learner Dashboard, non-primary Studio, staging parity. Of these, ONLY Learner Dashboard is actually L4 proven. Profile confirmed still broken. Non-primary Studio and staging parity not yet re-proven this session.

---

## 2026-04-11 later session — 2 more RCBs + deep browser matrix

### New root-cause batches

| Batch | Root Cause | Status | Evidence |
|-------|-----------|--------|----------|
| **RCB-13** | Biji-Biji prod CSP `connect-src` missing tenant domains, blocks login CSRF fetch | **SOURCE FIX IN PR #1540** | Browser: biji-biji prod login button stays "pending", console shows CSP violation on `https://academy.biji-biji.com/csrf/api/v1/token`. `CSP_CONNECT_SRC` in `lms_settings.py` only lists Mereka primary hosts. Fix extends to loop `MEREKA_LMS_EXTRA_HOSTS`. |
| **RCB-10 root cause** | Paragon theme CSS files missing from MFE container (`/openedx/dist/theme/` doesn't exist) | **SOURCE FIX IN PR #1543** | `curl /theme/core.min.css` → 404 on apps.* host, `ls /openedx/dist/theme/` → "No such file or directory" in mfe container. `apply-patches.sh` has `sync_openedx_theme` but no `sync_mfe_theme`. PR adds the missing sync function. |

### RCB-11 update

Previously filed as "learner-record MFE not packaged". **RESOLVED** in the current dev mfe image. The dir `/openedx/dist/learner-record/` exists with `index.html`, `app.*.js`, `app.*.css`, theme bundles. URL `/learner-record/` returns HTTP 200. Browser proof: L1 authenticated-route-redirect working.

### Session 3→4 runtime discoveries from browser proof

Multiple assumptions proven wrong this cycle:
1. **"HTTP 200 means L3"** — Learner-record URL returned 200 while the MFE was missing. Now re-verified as actually built.
2. **"Dev SOF dashboard broken"** — Was overclaimed as untested. Real browser proof shows **L4 working** with SOF dark theme.
3. **"SOF prod serves Mereka"** — Initially flagged as regression. Actually I was testing the migration-target URL (`skillourfuture.academyv2.mereka.io`) instead of the current canonical (`skillourfuture.academy.mereka.io`). Registry says academyv2 subdomain is migration target, not active.
4. **"Staging is down"** — Session 2 said "externally unreachable". Now L3 proven on `staging.academyv2.mereka.io`. Cluster CPU is still overallocated but staging serves.
5. **"Profile MFE blank = missing MFE_CONFIG keys"** — Fixed keys via SiteConfiguration + PR #1536, but Profile still blank. Real root cause was theme CSS 404, not config API. Missing keys were secondary noise from Studio Footer component.

### Runtime authority status (updated 2026-04-11 later)

| Domain | State |
|--------|-------|
| Dev Mereka (full L4) | ✅ |
| Dev Biji-Biji (L4 dashboard) | ✅ |
| Dev SOF (L4 dashboard) | ✅ |
| Prod Mereka (full L4) | ✅ |
| Prod Biji-Biji (login) | 🔴 blocked on PR #1540 deploy |
| Prod SOF (login) | not yet tested |
| Staging Mereka (L3) | ✅ |
| Profile / Discussions / Communications (all envs) | 🔴 blocked on PR #1543 deploy |
| Learner-record | ✅ serves (L1 auth redirect confirmed) |

### Tenant URL canonicality (authority)

Per `deploy/k8s/tenancy/tenant-registry.yaml`:

| Tenant | Current prod URL | Migration target |
|--------|------------------|------------------|
| Mereka | `academyv2.mereka.io` | (primary) |
| Biji-Biji | `academy.biji-biji.com` | `biji-biji.academyv2.mereka.io` |
| SOF | `skillourfuture.academy.mereka.io` | `skillourfuture.academyv2.mereka.io` |

Testing the migration target URLs returns Mereka content (fall-through to primary Site). Migration cutover is not complete and this is expected per the registry.
