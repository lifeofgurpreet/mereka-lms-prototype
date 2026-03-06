# Transitional Operations Link Gap Register 2026-03-06
_Audience: Docs Lead + Domain Owners • Owner: Platform Team • Last verified: 2026-03-06 • Status: supporting_

## Scope
- Source: `docs/README.md` primary index.
- Finding: 11 links still target `docs/operations/**` transitional paths.
- Policy: no forced moves in this task; publish migration queue + owner approvals required.

## Migration Queue

| Transitional Link | Purpose | Last Verified | Proposed Target Domain | Required Approval | Status |
|---|---|---|---|---|---|
| `operations/DISCOVERY_QUICKSTART.md` | Course catalog operations quick reference | 2026-02-03 | `docs/ops/quickref/discovery-quickstart.md` | Ops Domain Owner | DONE (moved 2026-03-06 with superseded stub retained) |
| `operations/AUTH_AND_PERMISSIONS.md` | How Authentik SSO and Open edX permissions fit together (and what does not sync) | 2026-02-06 | `docs/ops/security/**` | Ops/Security Domain Owner | DONE |
| `operations/IN_CLUSTER_AUTH_VERIFICATION.md` | Verify-only CronJob template for continuous public auth surface checks | 2026-02-06 | `docs/ops/security/in-cluster-auth-verification.md` | Ops/Security Domain Owner | DONE (moved 2026-03-06 with superseded stub retained) |
| `operations/OPENEDX_HOSTNAMES.md` | Canonical registry of all Open edX hostnames (prod + dev + kind-local) | 2026-02-06 | `docs/ops/security/**` | Ops/Security Domain Owner | DONE |
| `operations/RFC_CLAIM_BASED_ROLE_SYNC.md` | Draft RFC: optional claim-based role sync (Authentik -> Open edX) | 2026-02-06 | `docs/concepts/architecture/** or docs/archive/reports/**` | Docs Lead + Domain Owner | DONE |
| `operations/LOCAL_ACCESS_INFO.md` | Local development URLs and credentials | 2025-11-12 | `docs/ops/quickref/local-access-info.md` | Ops Domain Owner | DONE (moved 2026-03-06 with superseded stub retained) |
| `operations/LOCAL_PRODUCTION_PARITY.md` | Local/production parity guide | 2025-11-12 | `docs/ops/quickref/local-production-parity.md` | Ops Domain Owner | DONE (moved 2026-03-06 with superseded stub retained) |
| `operations/LOCAL_WORK_REMAINING.md` | Current local development tasks | 2025-11-12 | `docs/ops/quickref/local-work-remaining.md` | Ops Domain Owner | DONE (moved 2026-03-06 with superseded stub retained) |
| `operations/DISCOVERY_DEMO_COURSE_SETUP.md` | Full setup guide for Discovery service and demo courses | 2026-02-03 | `docs/ops/** (domain split pending)` | Domain Owner | DONE |
| `operations/MONGODB_PERMISSIONS_ISSUE.md` | MongoDB Atlas permissions issue and resolution | 2026-02-03 | `docs/ops/** (domain split pending)` | Domain Owner | DONE |
| `operations/DJANGO_RAW_SQL_BYPASS.md` | Bypass Django signals with raw SQL (when Celery broker unavailable) | 2025-12-29 | `docs/ops/runbooks/django-raw-sql-bypass.md` | Ops Domain Owner | DONE (moved 2026-03-06 with superseded stub retained) |
| `operations/GCP_ROADMAP.md` | Cloud architecture plan and outstanding infra tasks | 2025-10-15 ⚠️ STALE | `docs/concepts/architecture/** or docs/archive/reports/**` | Docs Lead + Domain Owner | DONE |
| `operations/CLOUDFLARE_DNS.md` | DNS zones plus automation via Cloudflare API | 2025-09-05 ⚠️ STALE | `docs/ops/** (domain split pending)` | Domain Owner | DONE |
| `operations/MULTISITE.md` | Microsite strategy and shared theme tokens | 2025-09-10 ⚠️ STALE | `docs/concepts/architecture/** or docs/archive/reports/**` | Docs Lead + Domain Owner | DONE |
| `operations/FRONTEND_CLOSURE_STATUS_MATRIX_2026-03-02.md` | Frontend closure status matrix and dependency gates | 2026-03-02 | `docs/ops/** (domain split pending)` | Domain Owner | DONE |
| `operations/FRONTEND_RUNTIME_STABILITY_STATUS_2026-03-02.md` | Runtime stability status and live blockers for frontend closure | 2026-03-02 | `docs/ops/** (domain split pending)` | Domain Owner | DONE |
| `operations/PRODUCTION_VERIFICATION_CHECKLIST.md` | Production verification checklist | 2025-11-12 | `docs/ops/runbooks/production-verification-checklist.md` | Ops Domain Owner | DONE (moved 2026-03-06 with superseded stub retained) |
| `operations/COST_ESTIMATE.md` | Cost estimation guide | 2025-11-12 | `docs/ops/ci-cd/cost-estimate.md` | Ops Domain Owner | DONE (moved 2026-03-06 with superseded stub retained) |
| `operations/COST_OPTIMIZATION.md` | Cost optimization strategies | 2025-11-12 | `docs/ops/runbooks/** or docs/ops/ci-cd/**` | Ops Domain Owner | DONE |
| `operations/TASK3_SES_SMTP_GUIDE.md` | SES setup notes and SMTP execution path | 2025-11-12 | `docs/ops/runbooks/task3-ses-smtp-guide.md` | Ops Domain Owner | DONE (moved 2026-03-06 with superseded stub retained) |

## Execution Rule
1. Confirm canonical destination per row with domain owner.
2. Move/update doc path and links in same change set.
3. Keep redirect stub only when inbound references still exist.
4. Re-run `./docs/qa/verify-docs-policy.sh` after each batch.
