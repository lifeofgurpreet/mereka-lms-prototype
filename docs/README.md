# Documentation Index
_Audience: Everyone • Owner: Infra Team • Last verified: 2026-03-06 • Status: canonical_

Use this file as the front door to the Mereka Academy Open edX docs. Each link below includes a short description plus the last-known verification date so you can see freshness at a glance.

---

## 🔍 Find Docs by Your Role

**New to Mereka LMS?** Start here:
- **[INDEX_BY_AUDIENCE.md](guides/INDEX_BY_AUDIENCE.md)** - Learning paths by role (Platform Operators, SREs, Developers, Enterprise Admins, Security Auditors)
- **[onboarding/REPOSITORY_GUIDE.md](guides/onboarding/REPOSITORY_GUIDE.md)** - Repository structure and navigation
- **[onboarding/DEVELOPER_ONBOARDING.md](guides/onboarding/DEVELOPER_ONBOARDING.md)** - Complete developer onboarding
- **[onboarding/QUICK_START_LOCAL.md](guides/onboarding/QUICK_START_LOCAL.md)** - Fast 5-minute local setup

**Contributing documentation?**
- **[CONTRIBUTING.md](CONTRIBUTING.md)** - Docs contribution rules, placement policy, metadata requirements
- **[DOCS_REMEDIATION_PLAN_AND_TRACKER.md](DOCS_REMEDIATION_PLAN_AND_TRACKER.md)** - Canonical remediation operating system and tracker
- **[governance-approval-note-20260306.md](archive/reports/governance-approval-note-20260306.md)** - Governance packet and owner-map sign-off register (`GOV-01`)
- **[escalation-appendix-20260306.md](archive/reports/escalation-appendix-20260306.md)** - Deterministic escalation routing (`GOV-02`)
- **[canonical-authority-approval-matrix-20260306.md](archive/reports/canonical-authority-approval-matrix-20260306.md)** - Major-cluster canonical approval matrix
- **[program-closure-readiness-20260306.md](archive/reports/program-closure-readiness-20260306.md)** - Remaining closure gate checklist (`CLS-02`)
- **[transitional-path-deprecation-timeline-20260306.md](archive/reports/transitional-path-deprecation-timeline-20260306.md)** - Scheduled retirement timeline for transitional trees
- **[DOCUMENTATION_STANDARDS.md](guides/standards/DOCUMENTATION_STANDARDS.md)** - Documentation standards, CI automation, and style guide
- **[.github/workflows/ci.yml](../.github/workflows/ci.yml)** - Automated verification workflow (spec verification absorbed from the former `verify-specs.yml` in Phase 4 consolidation)

---

## 📂 Documentation Structure

Operations documentation is now organized into three categories for easier navigation:

### `guides/admin/` - Administration Guides
Essential guides for understanding and operating core systems:
- K8s Operations, Secrets Management, MongoDB Atlas, Multi-Site, Observability, Enterprise Services

### `ops/runbooks/` - Step-by-Step Procedures
Operational procedures organized by urgency and purpose:
- **Emergency**: site-down, emergency-rollback, performance-degradation, database-issues
- **Service-Specific**: forum, MongoDB Atlas, analytics, email, mobile apps, badges
- **Configuration**: Tutor setup, SSO, multi-tenancy, CI/CD, repository structure

### `ops/quickref/` - Quick Reference Cards
Fast lookup references for common tasks (ACCESS_URLS, OBSERVABILITY_QUICKSTART, DISCOVERY_QUICKSTART)

See [INDEX_BY_AUDIENCE.md](guides/INDEX_BY_AUDIENCE.md) for role-specific learning paths.

---

## 🎯 Start Here (Onboarding)

| Doc | Purpose | Last Verified |
| --- | --- | --- |
| [`onboarding/REPOSITORY_GUIDE.md`](guides/onboarding/REPOSITORY_GUIDE.md) | **Repository structure map** - Find files, understand organization, add new files correctly | 2026-02-11 |
| [`onboarding/AGENT_SETUP_CHECKLIST.md`](guides/onboarding/AGENT_SETUP_CHECKLIST.md) | Step-by-step setup checklist for new machines | 2025-11-12 |
| [`onboarding/QUICK_START_LOCAL.md`](guides/onboarding/QUICK_START_LOCAL.md) | Fast 5-minute setup guide | 2025-11-12 |
| [`onboarding/DEVELOPER_ONBOARDING.md`](guides/onboarding/DEVELOPER_ONBOARDING.md) | Complete developer onboarding guide | 2025-11-12 |
| [`onboarding/LOCAL_DEVELOPMENT_GUIDE.md`](guides/onboarding/LOCAL_DEVELOPMENT_GUIDE.md) | Complete local development reference | 2025-11-12 |
| [`onboarding/LOCAL_SETUP.md`](guides/onboarding/LOCAL_SETUP.md) | Detailed Tutor bootstrap guide (Ulmo) | 2025-11-09 |
| [`onboarding/WORKFLOW_LOCAL.md`](guides/onboarding/WORKFLOW_LOCAL.md) | Daily workflow commands and cheat sheet | 2025-11-09 |

## 🔧 Operations & Runbooks

### Quick Start Guides (`guides/admin/`)

Essential guides for common operational tasks:

| Doc | Purpose | Last Verified |
| --- | --- | --- |
| [`guides/admin/K8S_OPERATIONS_GUIDE.md`](guides/admin/K8S_OPERATIONS_GUIDE.md) | **K8s operations** - Deployment, scaling, monitoring, observability (ServiceMonitors), image management, security contexts | 2026-02-11 |
| [`guides/admin/SECRETS_MANAGEMENT_GUIDE.md`](guides/admin/SECRETS_MANAGEMENT_GUIDE.md) | **Secrets pipeline** - Add/rotate/validate secrets, 4-stage flow (Infisical→GCP SM→K8s), troubleshooting | 2026-02-11 |
| [`guides/admin/MONGODB_ATLAS_GUIDE.md`](guides/admin/MONGODB_ATLAS_GUIDE.md) | **MongoDB Atlas** - Connection management, monitoring, IP allowlist, password rotation, troubleshooting | 2026-02-11 |
| [`guides/admin/MULTI_SITE_GUIDE.md`](guides/admin/MULTI_SITE_GUIDE.md) | **Multi-domain config** - 3 production domains, CSRF/session management, domain add/remove, OIDC verification | 2026-02-11 |
| [`guides/admin/OBSERVABILITY_GUIDE.md`](guides/admin/OBSERVABILITY_GUIDE.md) | **Observability stack** - Prometheus, Loki, Tempo, Grafana; metrics, logs, traces, alerts, dashboards | 2026-02-11 |
| [`guides/admin/ENTERPRISE_SERVICES_GUIDE.md`](guides/admin/ENTERPRISE_SERVICES_GUIDE.md) | **Enterprise services** - Deploy and manage 5 B2B microservices (catalog, license-manager, access, subsidy, integrated-channels) | 2026-02-11 |
| [`guides/admin/ADMIN_LOGIN_GUIDE.md`](guides/admin/ADMIN_LOGIN_GUIDE.md) | Admin access and login instructions | 2026-02-06 |

### Emergency & Critical Runbooks (`ops/runbooks/`)

Step-by-step procedures for incidents and operations:

| Doc | Purpose | Last Verified |
| --- | --- | --- |
| [`ops/runbooks/site-down.md`](ops/runbooks/site-down.md) | **🚨 SITE DOWN?** Quick diagnostic checklist and fixes (5-10 min resolution) | 2025-11-11 |
| [`ops/runbooks/emergency-rollback.md`](ops/runbooks/emergency-rollback.md) | **Emergency rollback** - When to rollback, decision tree, GitOps/DB rollback, data verification | 2026-02-12 |
| [`ops/runbooks/performance-degradation.md`](ops/runbooks/performance-degradation.md) | Performance troubleshooting and latency diagnosis | 2026-02-12 |
| [`ops/runbooks/database-issues.md`](ops/runbooks/database-issues.md) | Database connection failures and MySQL/MongoDB issues | 2026-02-12 |
| [`ops/runbooks/DISASTER_RECOVERY.md`](ops/runbooks/DISASTER_RECOVERY.md) | Disaster recovery and backup restore procedures | 2026-02-12 |
| [`ops/runbooks/DEPLOYMENT_RUNBOOK.md`](ops/runbooks/DEPLOYMENT_RUNBOOK.md) | How we ship Tutor environments (local/prod/k8s) | 2025-10-30 |
| [`ops/runbooks/AUTH_ALERT_RUNBOOK.md`](ops/runbooks/AUTH_ALERT_RUNBOOK.md) | On-call remediation map for auth-related alerts and checks | 2026-02-06 |
| [`ops/runbooks/DOMAIN_CHANGE_RUNBOOK.md`](ops/runbooks/DOMAIN_CHANGE_RUNBOOK.md) | Domain/microsite change checklist with deterministic verification | 2026-02-06 |

### Service-Specific Runbooks (`ops/runbooks/`)

Operational procedures for specific services:

| Doc | Purpose | Last Verified |
| --- | --- | --- |
| [`ops/runbooks/FORUM_SERVICE_RUNBOOK.md`](ops/runbooks/FORUM_SERVICE_RUNBOOK.md) | Forum service operations and troubleshooting | 2026-02-12 |
| [`ops/runbooks/MONGODB_ATLAS_RUNBOOK.md`](ops/runbooks/MONGODB_ATLAS_RUNBOOK.md) | MongoDB Atlas operational procedures | 2026-02-12 |
| [`ops/runbooks/ANALYTICS_RUNBOOK.md`](ops/runbooks/ANALYTICS_RUNBOOK.md) | Analytics platform operations | 2026-02-12 |
| [`ops/runbooks/EMAIL_NOTIFICATIONS_RUNBOOK.md`](ops/runbooks/EMAIL_NOTIFICATIONS_RUNBOOK.md) | Email configuration and troubleshooting | 2026-02-12 |
| [`ops/runbooks/MOBILE_APPS_RUNBOOK.md`](ops/runbooks/MOBILE_APPS_RUNBOOK.md) | Mobile app operations | 2026-02-12 |
| [`ops/runbooks/BADGES_CREDENTIALS_RUNBOOK.md`](ops/runbooks/BADGES_CREDENTIALS_RUNBOOK.md) | Badges and certificates management | 2026-02-12 |

### Configuration & Setup Runbooks (`ops/runbooks/`)

Advanced configuration procedures:

| Doc | Purpose | Last Verified |
| --- | --- | --- |
| [`ops/runbooks/TUTOR_CONFIGURATION_RUNBOOK.md`](ops/runbooks/TUTOR_CONFIGURATION_RUNBOOK.md) | Advanced Tutor configuration | 2026-02-12 |
| [`ops/runbooks/TUTOR_PLUGIN_MIGRATION_RUNBOOK.md`](ops/runbooks/TUTOR_PLUGIN_MIGRATION_RUNBOOK.md) | Tutor plugin development | 2026-02-12 |
| [`ops/runbooks/AUTH_SSO_RUNBOOK.md`](ops/runbooks/AUTH_SSO_RUNBOOK.md) | SSO configuration | 2026-02-12 |
| [`ops/runbooks/MULTI_TENANCY_RUNBOOK.md`](ops/runbooks/MULTI_TENANCY_RUNBOOK.md) | Tenant provisioning and management | 2026-02-12 |
| [`ops/runbooks/CI_CD_RUNBOOK.md`](ops/runbooks/CI_CD_RUNBOOK.md) | Build and deployment automation | 2026-02-12 |
| [`ops/runbooks/REPOSITORY_STRUCTURE_RUNBOOK.md`](ops/runbooks/REPOSITORY_STRUCTURE_RUNBOOK.md) | Repository navigation and organization | 2026-02-12 |

### Quick Reference Cards (`ops/quickref/`)

Fast lookup references for common tasks:

| Doc | Purpose | Last Verified |
| --- | --- | --- |
| [`ops/quickref/access-urls.md`](ops/quickref/access-urls.md) | **All URLs** - LMS, Studio, Forum, Admin, and user management | 2026-02-06 |
| [`ops/monitoring/OBSERVABILITY_QUICKSTART.md`](ops/monitoring/OBSERVABILITY_QUICKSTART.md) | Fast health checks and observability commands | 2026-03-06 |
| [`ops/quickref/discovery-quickstart.md`](ops/quickref/discovery-quickstart.md) | Course catalog operations quick reference | 2026-03-06 |

### Additional Operations Documentation

Legacy note:
- Some links below intentionally point to `docs/operations/**` transitional docs that have no finalized `docs/ops/**` replacement yet.
- Prefer canonical `docs/ops/**` and `docs/guides/**` links when both exist.

| Doc | Purpose | Last Verified |
| --- | --- | --- |
| [`ops/security/AUTH_AND_PERMISSIONS.md`](ops/security/AUTH_AND_PERMISSIONS.md) | How Authentik SSO and Open edX permissions fit together (and what does not sync) | 2026-02-06 |
| [`ops/security/AUTH_HARDENING_SPEC.md`](ops/security/AUTH_HARDENING_SPEC.md) | Hardening spec: verification + drift prevention across the ecosystem | 2026-02-06 |
| [`ops/security/in-cluster-auth-verification.md`](ops/security/in-cluster-auth-verification.md) | Verify-only CronJob template for continuous public auth surface checks | 2026-03-06 |
| [`ops/security/OPENEDX_HOSTNAMES.md`](ops/security/OPENEDX_HOSTNAMES.md) | Canonical registry of all Open edX hostnames (prod + dev + kind-local) | 2026-02-06 |
| [`concepts/architecture/RFC_CLAIM_BASED_ROLE_SYNC.md`](concepts/architecture/RFC_CLAIM_BASED_ROLE_SYNC.md) | Draft RFC: optional claim-based role sync (Authentik -> Open edX) | 2026-02-06 |
| [`ops/quickref/local-access-info.md`](ops/quickref/local-access-info.md) | Local development URLs and credentials | 2026-03-06 |
| [`ops/quickref/local-production-parity.md`](ops/quickref/local-production-parity.md) | Local/production parity guide | 2026-03-06 |
| [`ops/quickref/local-work-remaining.md`](ops/quickref/local-work-remaining.md) | Current local development tasks | 2026-03-06 |
| ~~`operations/MFE_LOGIN_FIX.md`~~ | Archived → `archive/MFE_LOGIN_FIX.md` | — |
| ~~`operations/MFE_REBUILD_SUCCESS.md`~~ | Archived → `archive/MFE_REBUILD_SUCCESS.md` | — |
| [`ops/runbooks/DISCOVERY_DEMO_COURSE_SETUP.md`](ops/runbooks/DISCOVERY_DEMO_COURSE_SETUP.md) | Full setup guide for Discovery service and demo courses | 2026-02-03 |
| [`ops/runbooks/MONGODB_PERMISSIONS_ISSUE.md`](ops/runbooks/MONGODB_PERMISSIONS_ISSUE.md) | MongoDB Atlas permissions issue and resolution | 2026-02-03 |
| [`ops/runbooks/django-raw-sql-bypass.md`](ops/runbooks/django-raw-sql-bypass.md) | Bypass Django signals with raw SQL (when Celery broker unavailable) | 2026-03-06 |
| [`archive/reports/GCP_ROADMAP.md`](archive/reports/GCP_ROADMAP.md) | Cloud architecture plan and outstanding infra tasks | 2025-10-15 ⚠️ STALE |
| [`ops/monitoring/MONITORING.md`](ops/monitoring/MONITORING.md) | Stack monitoring and alerting strategy | 2026-03-06 |
| [`archive/reports/CLOUDFLARE_DNS.md`](archive/reports/CLOUDFLARE_DNS.md) | DNS zones plus automation via Cloudflare API | 2025-09-05 ⚠️ STALE |
| [`ops/security/SECRETS_SNAPSHOT.md`](ops/security/SECRETS_SNAPSHOT.md) | Inventory of non-git secrets and how they're stored | 2026-02-06 |
| [`concepts/architecture/MULTISITE.md`](concepts/architecture/MULTISITE.md) | Microsite strategy and shared theme tokens | 2025-09-10 ⚠️ STALE |

## 📊 Migrations

| Doc | Purpose | Last Verified |
| --- | --- | --- |
| [`migrations/README.md`](migrations/README.md) | Explains how migration domains are organized and linked | 2025-11-09 |

### Kajabi

| Doc | Purpose | Last Verified |
| --- | --- | --- |
| [`migrations/kajabi/README.md`](migrations/kajabi/README.md) | Entry point for Kajabi export/transform/import docs | 2025-11-09 |
| [`migrations/kajabi/KAJABI_MIGRATION.md`](migrations/kajabi/KAJABI_MIGRATION.md) | Canonical playbook spanning export -> transform -> import | 2025-11-09 |
| [`migrations/kajabi/KAJABI_MIGRATION_STATUS.md`](migrations/kajabi/KAJABI_MIGRATION_STATUS.md) | Progress tracker for processed courses/users | 2025-11-09 |
| [`migrations/kajabi/ROLLBACK_AND_SAFETY.md`](migrations/kajabi/ROLLBACK_AND_SAFETY.md) | Safety/rollback guidance before rerunning imports | 2025-11-09 |
| [`migrations/kajabi/KAJABI_LESSON_CONTENT_FIX.md`](migrations/kajabi/KAJABI_LESSON_CONTENT_FIX.md) | Lesson content migration fixes | 2025-11-12 |

### MCT (Microsoft Community Training)

| Doc | Purpose | Last Verified |
| --- | --- | --- |
| [`migrations/mct/README.md`](migrations/mct/README.md) | Entry point for the legacy MCT migration docs | 2025-08-31 |
| [`migrations/mct/MIGRATION_PLAN.md`](migrations/mct/MIGRATION_PLAN.md) | End-to-end plan for migrating from MCT | 2025-08-31 |
| [`migrations/mct/EXPORT_GUIDE.md`](migrations/mct/EXPORT_GUIDE.md) | How to export data from MCT | 2025-08-20 |
| [`migrations/mct/MCT_TO_OPENEDX_MAPPING.md`](migrations/mct/MCT_TO_OPENEDX_MAPPING.md) | Field mapping between MCT and Open edX | 2025-08-31 |
| [`migrations/mct/MCT_MIGRATION_STATUS.md`](migrations/mct/MCT_MIGRATION_STATUS.md) | Status tracker for the MCT effort | 2025-08-31 |

## 🏗️ Architecture

| Doc | Purpose | Last Verified |
| --- | --- | --- |
| [`concepts/architecture/DATABASE_ARCHITECTURE.md`](concepts/architecture/DATABASE_ARCHITECTURE.md) | **START HERE:** Explains all databases (MySQL, MongoDB, Redis, etc.) | 2025-11-11 |
| [`concepts/architecture/MULTISITE_ANALYSIS.md`](concepts/architecture/MULTISITE_ANALYSIS.md) | Multisite architecture analysis | 2025-11-12 |

### Component Packs (`concepts/components/`)

| Doc | Purpose | Last Verified |
| --- | --- | --- |
| [`concepts/components/tutor.md`](concepts/components/tutor.md) | Cross-cutting Tutor index (ADR + guides + runbooks + CI refs) | 2026-03-06 |
| [`concepts/components/branding.md`](concepts/components/branding.md) | Cross-cutting branding index (ADR + guides + runbooks + CI refs) | 2026-03-06 |
| [`concepts/components/mfe.md`](concepts/components/mfe.md) | Cross-cutting MFE index (ADR + guides + runbooks + CI refs) | 2026-03-06 |

## 📈 Analytics & Reporting

| Doc | Purpose | Last Verified |
| --- | --- | --- |
| [`analytics/README.md`](concepts/analytics/README.md) | Overview of analytics docs and when to use each reference | 2025-11-09 |
| [`analytics/ASPECTS_INSTALLATION.md`](concepts/analytics/ASPECTS_INSTALLATION.md) | Installing the Open edX Aspects stack | 2025-07-25 |
| [`analytics/ASPECTS_QUICKSTART.md`](concepts/analytics/ASPECTS_QUICKSTART.md) | TL;DR for verifying Aspects after install | 2025-07-25 |
| [`analytics/ASPECTS_ACCESS.md`](concepts/analytics/ASPECTS_ACCESS.md) | Access/Superset credential guide | 2025-07-25 |
| [`analytics/ASPECTS_ANALYTICS.md`](concepts/analytics/ASPECTS_ANALYTICS.md) | How we report metrics out of Aspects | 2025-07-25 |
| [`analytics/ASPECTS_VS_PANORAMA.md`](concepts/analytics/ASPECTS_VS_PANORAMA.md) | Comparison study of analytics options | 2025-07-25 |
| [`analytics/PANORAMA_ANALYTICS.md`](concepts/analytics/PANORAMA_ANALYTICS.md) | Panorama-specific dashboards/workflows | 2025-07-25 |
| [`analytics/OPENEDX_ANALYTICS.md`](concepts/analytics/OPENEDX_ANALYTICS.md) | Built-in Open edX analytics hooks and exports | 2025-07-25 |
| [`analytics/ENROLLMENT_COMPARISON_QUICKSTART.md`](concepts/analytics/ENROLLMENT_COMPARISON_QUICKSTART.md) | Quick reconciliation between Kajabi and Open edX enrollments | 2025-10-01 |
| [`analytics/ASPECTS_K8S_DEPLOYMENT.md`](concepts/analytics/ASPECTS_K8S_DEPLOYMENT.md) | Resource tuning and deployment guide for Aspects on GKE Autopilot | 2025-11-09 |

## 🔌 Integrations

| Doc | Purpose | Last Verified |
| --- | --- | --- |
| [`guides/integrations/README.md`](guides/integrations/README.md) | Integration doc index and contribution guidelines | 2025-11-09 |
| [`guides/integrations/GOOGLE_OAUTH_SETUP.md`](guides/integrations/GOOGLE_OAUTH_SETUP.md) | End-to-end OAuth setup for Google Sign-In | 2025-08-30 |
| [`guides/integrations/GOOGLE_OAUTH_QUICK_START.md`](guides/integrations/GOOGLE_OAUTH_QUICK_START.md) | TL;DR version of the OAuth guide | 2025-08-30 |

## 📋 Status & Backlog

| Doc | Purpose | Last Verified |
| --- | --- | --- |
| [`archive/reports/status/NEXT10_TASKS.md`](archive/reports/status/NEXT10_TASKS.md) | Rolling top-10 backlog for the team | 2026-02-06 |
| [`archive/reports/status/OPERATIONAL_STATUS.md`](archive/reports/status/OPERATIONAL_STATUS.md) | Current operational status | 2025-11-12 |
| [`archive/reports/status/PARITY_ISSUES_FOUND.md`](archive/reports/status/PARITY_ISSUES_FOUND.md) | Local/production parity issues | 2025-11-12 |
| [`archive/reports/status/TASK2_STATUS.md`](archive/reports/status/TASK2_STATUS.md) | Task 2 status tracker | 2025-11-12 |

## 🎨 Branding & Frontend

| Doc | Purpose | Last Verified |
| --- | --- | --- |
| [`guides/branding/BRANDING.md`](guides/branding/BRANDING.md) | **Mereka branding system** - Color palette, typography, assets, verification, MFE integration, troubleshooting | 2026-02-11 |
| [`guides/branding/README.md`](guides/branding/README.md) | Branding role-boundary index (contract, guardrails, and operational references) | 2026-03-06 |
| [`guides/branding/BRANDING_PLAN.md`](guides/branding/BRANDING_PLAN.md) | Status tracker for the cross-surface branding rollout (Phases 1-5) | 2026-02-27 |
| [`archive/reports/FRONTEND_CLOSURE_STATUS_MATRIX_2026-03-02.md`](archive/reports/FRONTEND_CLOSURE_STATUS_MATRIX_2026-03-02.md) | Frontend closure status matrix and dependency gates | 2026-03-02 |
| [`archive/reports/FRONTEND_RUNTIME_STABILITY_STATUS_2026-03-02.md`](archive/reports/FRONTEND_RUNTIME_STABILITY_STATUS_2026-03-02.md) | Runtime stability status and live blockers for frontend closure | 2026-03-02 |
| [`MFE_COMPLETE_LIST.md`](concepts/architecture/MFE_COMPLETE_LIST.md) | Complete list of 12 configured + enterprise MFEs | 2026-02-27 |
| [`guides/standards/STYLE_GUIDE.md`](guides/standards/STYLE_GUIDE.md) | Documentation conventions (metadata, folder layout, cross-links) | 2025-11-09 |

## 📚 Reference

| Doc | Purpose | Last Verified |
| --- | --- | --- |
| [`MONGODB_ATLAS.md`](guides/admin/MONGODB_ATLAS_GUIDE.md) | MongoDB Atlas migration and cutover guide | 2025-11-09 |
| ~~`KAJABI_API_ENDPOINTS.md`~~ | Archived → `archive/KAJABI_API_ENDPOINTS.md` | — |
| [`COURSE_IMPORT_GUIDE.md`](guides/onboarding/COURSE_IMPORT_GUIDE.md) | Course import procedures | 2025-11-12 |
| [`ops/runbooks/production-verification-checklist.md`](ops/runbooks/production-verification-checklist.md) | Production verification checklist | 2026-03-06 |
| [`QUICK_REFERENCE.md`](ops/quickref/QUICK_REFERENCE.md) | Quick reference guide | 2025-11-12 |
| [`DATA_SOURCES_EXPLAINED.md`](concepts/analytics/DATA_SOURCES_EXPLAINED.md) | Data sources documentation | 2025-11-12 |
| [`MULTI_DEVELOPER_WORKFLOW.md`](guides/onboarding/MULTI_DEVELOPER_WORKFLOW.md) | Multi-developer workflow guide | 2025-11-12 |
| [`ops/ci-cd/cost-estimate.md`](ops/ci-cd/cost-estimate.md) | Cost estimation guide | 2026-03-06 |
| [`ops/ci-cd/COST_OPTIMIZATION.md`](ops/ci-cd/COST_OPTIMIZATION.md) | Cost optimization strategies | 2025-11-12 |
| [`ops/runbooks/task3-ses-smtp-guide.md`](ops/runbooks/task3-ses-smtp-guide.md) | SES setup notes and SMTP execution path | 2026-03-06 |
| [`archive/reports/ASPECTS_DEPLOYMENT_STATUS.md`](archive/reports/ASPECTS_DEPLOYMENT_STATUS.md) | Aspects deployment status (historical) | 2025-11-12 |
| [`analytics/ASPECTS_ACCESS.md`](concepts/analytics/ASPECTS_ACCESS.md) | Analytics access and Superset credential guide | 2025-07-25 |
| [`archive/COMPLETE_SETUP_SYSTEM.md`](archive/COMPLETE_SETUP_SYSTEM.md) | Complete setup system documentation | 2025-11-12 |
| [`archive/SESSION_SUMMARY_2026-02-03_AWS_SECRETS.md`](archive/SESSION_SUMMARY_2026-02-03_AWS_SECRETS.md) | Session artifact (historical snapshot) | 2025-11-12 |
| [`archive/BUILD_STATUS.md`](archive/BUILD_STATUS.md) | Point-in-time build status snapshot | 2025-11-12 |
| [`archive/CLUSTER_STATUS.md`](archive/CLUSTER_STATUS.md) | Point-in-time cluster status snapshot | 2025-11-12 |
| [`archive/FRONTEND_PHASE_B_PROMPT.md`](archive/FRONTEND_PHASE_B_PROMPT.md) | Frontend phase transition prompt (historical) | 2025-11-12 |
| [`archive/FRONTEND_PHASE_C_PROMPT.md`](archive/FRONTEND_PHASE_C_PROMPT.md) | Frontend phase transition prompt (historical) | 2025-11-12 |
| [`archive/FRONTEND_PHASE_D_PROMPT.md`](archive/FRONTEND_PHASE_D_PROMPT.md) | Frontend phase transition prompt (historical) | 2025-11-12 |

## 📦 Archive

Historical and deprecated documentation (moved here during audits):

- `archive/CLICKUP_TASK_LIST.md` — Task tracking (ephemeral)
- `archive/CLICKUP_TASK_LIST_BUSINESS.md` — Task tracking (ephemeral)
- `archive/CRITICAL_FINDINGS.md` — Historical findings
- `archive/FINAL_STATUS_REPORT.md` — Historical report
- `archive/GITHUB_SECRETS_READY.md` — Setup checklist (completed)
- `archive/IMPROVEMENTS_SUMMARY.md` — Historical summary
- `archive/KAJABI_API_ENDPOINTS.md` — Kajabi API reference (migration complete)
- `archive/KAJABI_LESSON_CONTENT_FIX.md` — Kajabi fix (migration complete)
- `archive/MFE_LOGIN_FIX.md` — MFE login fix (resolved)
- `archive/MFE_REBUILD_SUCCESS.md` — MFE rebuild report (resolved)
- `archive/TASK2_COMPLETION_REPORT.md` — Sprint tracking (ephemeral)
- `archive/TASK2_STATUS.md` — Sprint tracking (ephemeral)
- `archive/TASK3_SES_SETUP_COMPLETE.md` — SES setup (completed)

---

> ⭐ **Need to add something new?** Create the doc under `docs/`, add the metadata line, link it from the relevant folder README, and then add it to this index so everyone sees it.
