# Lane P2 — Prod Wake-Up Rehearsal

Date: 2026-03-16

## Parity Analysis

### Root cause: openedx_prometheus crash
The prod overlay (`production-prod.py`) unconditionally added
`openedx_prometheus` to `INSTALLED_APPS`. The governed prod
image (`e5c0c508`) predates the plugin that bakes this custom
app into the Docker image. LMS crashed on startup.

**Why dev works**: Dev image (`8a7f2476`) was built after the
modular plugin was introduced, which copies `openedx_prometheus`
into the image at build time.

**Fix**: Guard the import (PR #1836, merged). The module is
optional — Prometheus metrics work via `django_prometheus`
alone; `openedx_prometheus` adds custom endpoints.

### Dependency chain for prod wake-up
1. Redis (in-cluster) — must be up first
2. MySQL (in-cluster) — must be up for LMS to start
3. LMS — depends on Redis + MySQL
4. Node pool capacity — GKE cluster must have enough CPU

### Blockers found in sequence
| # | Blocker | Fix | Status |
|---|---------|-----|--------|
| 1 | ECOMMERCE_API_SIGNING_KEY empty | PR #1828 (optional) | MERGED |
| 2 | openedx_prometheus not in image | PR #1836 (guard import) | MERGED |
| 3 | MySQL can't schedule (Insufficient CPU) | Node pool size increase | INFRA OWNER |

## Changes Made

### Infra PRs
- PR #1836: Guard openedx_prometheus import in prod overlay

### Manual actions
- Applied rendered kustomize ConfigMaps + deployment to GKE prod
- Scaled Redis, LMS, MySQL for rehearsal
- Re-parked all to 0 replicas after hitting CPU blocker

## Rehearsal Proof

| Step | Result |
|------|--------|
| Redis scale-up | SUCCESS (2/2 Running) |
| LMS scale-up (first attempt) | CRASH: openedx_prometheus |
| LMS scale-up (after PR #1836) | CRASH: MySQL connection refused |
| MySQL scale-up | PENDING: Insufficient CPU |
| Public route check | NOT REACHED |

## Prod Wake Prerequisites (updated runbook)

Before scaling prod:
1. Ensure GKE node pool has capacity (or increase max nodes)
2. ArgoCD is either running or manual kustomize apply is used
3. Scale order: Redis -> MySQL -> wait for ready -> LMS -> CMS -> MFE
4. All governed ConfigMaps must be applied from latest infra main

## Re-Park Result

Parked-state verifier: 15/15 PASS

## Remaining Blockers

| Blocker | Owner | Blocks Wake? |
|---------|-------|--------------|
| GKE node pool max size too small for MySQL+LMS+Redis | Infra/GKE owner | YES |
| Prod image older than prod config | Image build owner (pre May 1st) | NO (guarded) |
| ArgoCD parked (can't auto-apply) | Infra owner | Manual apply works |

## Final Verdict

**PROD_WAKE_PATH_BLOCKED**

The code/config parity gaps are fixed (PRs #1828 + #1836). The
remaining blocker is infrastructure capacity: the GKE node pool
max size is too small to schedule MySQL + LMS + Redis simultaneously.
This requires increasing the node pool max before the May 1st
launch target.
