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
