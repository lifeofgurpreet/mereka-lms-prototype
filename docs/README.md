# Documentation Index
_Audience: Everyone • Owner: Infra Team • Last verified: 2026-02-12_

Use this file as the front door to the Mereka Academy Open edX docs. Each link below includes a short description plus the last-known verification date so you can see freshness at a glance.

---

## 🔍 Find Docs by Your Role

**New to Mereka LMS?** Start here:
- **[INDEX_BY_AUDIENCE.md](INDEX_BY_AUDIENCE.md)** - Learning paths by role (Platform Operators, SREs, Developers, Enterprise Admins, Security Auditors)
- **[onboarding/REPOSITORY_GUIDE.md](onboarding/REPOSITORY_GUIDE.md)** - Repository structure and navigation
- **[onboarding/DEVELOPER_ONBOARDING.md](onboarding/DEVELOPER_ONBOARDING.md)** - Complete developer onboarding
- **[onboarding/QUICK_START_LOCAL.md](onboarding/QUICK_START_LOCAL.md)** - Fast 5-minute local setup

**Contributing documentation?**
- **[DOCUMENTATION_STANDARDS.md](DOCUMENTATION_STANDARDS.md)** - Documentation standards, CI automation, and style guide
- **[.github/workflows/verify-specs.yml](../.github/workflows/verify-specs.yml)** - Automated verification workflow

---

## 📂 Documentation Structure

Operations documentation is now organized into three categories for easier navigation:

### `operations/guides/` - Comprehensive Guides
Essential guides for understanding and operating core systems:
- K8s Operations, Secrets Management, MongoDB Atlas, Multi-Site, Observability, Enterprise Services

### `operations/runbooks/` - Step-by-Step Procedures
Operational procedures organized by urgency and purpose:
- **Emergency**: site-down, emergency-rollback, performance-degradation, database-issues
- **Service-Specific**: forum, MongoDB Atlas, analytics, email, mobile apps, badges
- **Configuration**: Tutor setup, SSO, multi-tenancy, CI/CD, repository structure

### `operations/quickref/` - Quick Reference Cards
Fast lookup references for common tasks (ACCESS_URLS, OBSERVABILITY_QUICKSTART, DISCOVERY_QUICKSTART)

See [INDEX_BY_AUDIENCE.md](INDEX_BY_AUDIENCE.md) for role-specific learning paths.

---

## 🎯 Start Here (Onboarding)

| Doc | Purpose | Last Verified |
| --- | --- | --- |
| [`onboarding/REPOSITORY_GUIDE.md`](onboarding/REPOSITORY_GUIDE.md) | **Repository structure map** - Find files, understand organization, add new files correctly | 2026-02-11 |
| [`onboarding/AGENT_SETUP_CHECKLIST.md`](onboarding/AGENT_SETUP_CHECKLIST.md) | Step-by-step setup checklist for new machines | 2025-11-12 |
| [`onboarding/QUICK_START_LOCAL.md`](onboarding/QUICK_START_LOCAL.md) | Fast 5-minute setup guide | 2025-11-12 |
| [`onboarding/DEVELOPER_ONBOARDING.md`](onboarding/DEVELOPER_ONBOARDING.md) | Complete developer onboarding guide | 2025-11-12 |
| [`onboarding/LOCAL_DEVELOPMENT_GUIDE.md`](onboarding/LOCAL_DEVELOPMENT_GUIDE.md) | Complete local development reference | 2025-11-12 |
| [`onboarding/LOCAL_SETUP.md`](onboarding/LOCAL_SETUP.md) | Detailed Tutor 18.2.2 bootstrap guide | 2025-11-09 |
| [`onboarding/WORKFLOW_LOCAL.md`](onboarding/WORKFLOW_LOCAL.md) | Daily workflow commands and cheat sheet | 2025-11-09 |

## 🔧 Operations & Runbooks

### Quick Start Guides (`operations/guides/`)

Essential guides for common operational tasks:

| Doc | Purpose | Last Verified |
| --- | --- | --- |
| [`operations/guides/K8S_OPERATIONS_GUIDE.md`](operations/guides/K8S_OPERATIONS_GUIDE.md) | **K8s operations** - Deployment, scaling, monitoring, observability (ServiceMonitors), image management, security contexts | 2026-02-11 |
| [`operations/guides/SECRETS_MANAGEMENT_GUIDE.md`](operations/guides/SECRETS_MANAGEMENT_GUIDE.md) | **Secrets pipeline** - Add/rotate/validate secrets, 4-stage flow (Infisical→GCP SM→K8s), troubleshooting | 2026-02-11 |
| [`operations/guides/MONGODB_ATLAS_GUIDE.md`](operations/guides/MONGODB_ATLAS_GUIDE.md) | **MongoDB Atlas** - Connection management, monitoring, IP allowlist, password rotation, troubleshooting | 2026-02-11 |
| [`operations/guides/MULTI_SITE_GUIDE.md`](operations/guides/MULTI_SITE_GUIDE.md) | **Multi-domain config** - 3 production domains, CSRF/session management, domain add/remove, OIDC verification | 2026-02-11 |
| [`operations/guides/OBSERVABILITY_GUIDE.md`](operations/guides/OBSERVABILITY_GUIDE.md) | **Observability stack** - Prometheus, Loki, Tempo, Grafana; metrics, logs, traces, alerts, dashboards | 2026-02-11 |
| [`operations/guides/ENTERPRISE_SERVICES_GUIDE.md`](operations/guides/ENTERPRISE_SERVICES_GUIDE.md) | **Enterprise services** - Deploy and manage 5 B2B microservices (catalog, license-manager, access, subsidy, integrated-channels) | 2026-02-11 |
| [`operations/guides/ADMIN_LOGIN_GUIDE.md`](operations/guides/ADMIN_LOGIN_GUIDE.md) | Admin access and login instructions | 2026-02-06 |

### Emergency & Critical Runbooks (`operations/runbooks/`)

Step-by-step procedures for incidents and operations:

| Doc | Purpose | Last Verified |
| --- | --- | --- |
| [`operations/runbooks/site-down.md`](operations/runbooks/site-down.md) | **🚨 SITE DOWN?** Quick diagnostic checklist and fixes (5-10 min resolution) | 2025-11-11 |
| [`operations/runbooks/emergency-rollback.md`](operations/runbooks/emergency-rollback.md) | **Emergency rollback** - When to rollback, decision tree, GitOps/DB rollback, data verification | 2026-02-12 |
| [`operations/runbooks/performance-degradation.md`](operations/runbooks/performance-degradation.md) | Performance troubleshooting and latency diagnosis | 2026-02-12 |
| [`operations/runbooks/database-issues.md`](operations/runbooks/database-issues.md) | Database connection failures and MySQL/MongoDB issues | 2026-02-12 |
| [`operations/runbooks/DISASTER_RECOVERY.md`](operations/runbooks/DISASTER_RECOVERY.md) | Disaster recovery and backup restore procedures | 2026-02-12 |
| [`operations/runbooks/DEPLOYMENT_RUNBOOK.md`](operations/runbooks/DEPLOYMENT_RUNBOOK.md) | How we ship Tutor environments (local/prod/k8s) | 2025-10-30 |
| [`operations/runbooks/AUTH_ALERT_RUNBOOK.md`](operations/runbooks/AUTH_ALERT_RUNBOOK.md) | On-call remediation map for auth-related alerts and checks | 2026-02-06 |
| [`operations/runbooks/DOMAIN_CHANGE_RUNBOOK.md`](operations/runbooks/DOMAIN_CHANGE_RUNBOOK.md) | Domain/microsite change checklist with deterministic verification | 2026-02-06 |

### Service-Specific Runbooks (`operations/runbooks/`)

Operational procedures for specific services:

| Doc | Purpose | Last Verified |
| --- | --- | --- |
| [`operations/runbooks/FORUM_SERVICE_RUNBOOK.md`](operations/runbooks/FORUM_SERVICE_RUNBOOK.md) | Forum service operations and troubleshooting | 2026-02-12 |
| [`operations/runbooks/MONGODB_ATLAS_RUNBOOK.md`](operations/runbooks/MONGODB_ATLAS_RUNBOOK.md) | MongoDB Atlas operational procedures | 2026-02-12 |
| [`operations/runbooks/ANALYTICS_RUNBOOK.md`](operations/runbooks/ANALYTICS_RUNBOOK.md) | Analytics platform operations | 2026-02-12 |
| [`operations/runbooks/EMAIL_NOTIFICATIONS_RUNBOOK.md`](operations/runbooks/EMAIL_NOTIFICATIONS_RUNBOOK.md) | Email configuration and troubleshooting | 2026-02-12 |
| [`operations/runbooks/MOBILE_APPS_RUNBOOK.md`](operations/runbooks/MOBILE_APPS_RUNBOOK.md) | Mobile app operations | 2026-02-12 |
| [`operations/runbooks/BADGES_CREDENTIALS_RUNBOOK.md`](operations/runbooks/BADGES_CREDENTIALS_RUNBOOK.md) | Badges and certificates management | 2026-02-12 |

### Configuration & Setup Runbooks (`operations/runbooks/`)

Advanced configuration procedures:

| Doc | Purpose | Last Verified |
| --- | --- | --- |
| [`operations/runbooks/TUTOR_CONFIGURATION_RUNBOOK.md`](operations/runbooks/TUTOR_CONFIGURATION_RUNBOOK.md) | Advanced Tutor configuration | 2026-02-12 |
| [`operations/runbooks/TUTOR_PLUGIN_MIGRATION_RUNBOOK.md`](operations/runbooks/TUTOR_PLUGIN_MIGRATION_RUNBOOK.md) | Tutor plugin development | 2026-02-12 |
| [`operations/runbooks/AUTH_SSO_RUNBOOK.md`](operations/runbooks/AUTH_SSO_RUNBOOK.md) | SSO configuration | 2026-02-12 |
| [`operations/runbooks/MULTI_TENANCY_RUNBOOK.md`](operations/runbooks/MULTI_TENANCY_RUNBOOK.md) | Tenant provisioning and management | 2026-02-12 |
| [`operations/runbooks/CI_CD_RUNBOOK.md`](operations/runbooks/CI_CD_RUNBOOK.md) | Build and deployment automation | 2026-02-12 |
| [`operations/runbooks/REPOSITORY_STRUCTURE_RUNBOOK.md`](operations/runbooks/REPOSITORY_STRUCTURE_RUNBOOK.md) | Repository navigation and organization | 2026-02-12 |

### Quick Reference Cards (`operations/quickref/`)

Fast lookup references for common tasks:

| Doc | Purpose | Last Verified |
| --- | --- | --- |
| [`operations/ACCESS_URLS.md`](operations/ACCESS_URLS.md) | **All URLs** - LMS, Studio, Forum, Admin, and user management | 2026-02-06 |
| [`operations/OBSERVABILITY_QUICKSTART.md`](operations/OBSERVABILITY_QUICKSTART.md) | Fast health checks and observability commands | 2026-02-09 |
| [`operations/DISCOVERY_QUICKSTART.md`](operations/DISCOVERY_QUICKSTART.md) | Course catalog operations quick reference | 2026-02-03 |

### Additional Operations Documentation

| Doc | Purpose | Last Verified |
| --- | --- | --- |
| [`operations/AUTH_AND_PERMISSIONS.md`](operations/AUTH_AND_PERMISSIONS.md) | How Authentik SSO and Open edX permissions fit together (and what does not sync) | 2026-02-06 |
| [`operations/AUTH_HARDENING_SPEC.md`](operations/AUTH_HARDENING_SPEC.md) | Hardening spec: verification + drift prevention across the ecosystem | 2026-02-06 |
| [`operations/IN_CLUSTER_AUTH_VERIFICATION.md`](operations/IN_CLUSTER_AUTH_VERIFICATION.md) | Verify-only CronJob template for continuous public auth surface checks | 2026-02-06 |
| [`operations/OPENEDX_HOSTNAMES.md`](operations/OPENEDX_HOSTNAMES.md) | Canonical registry of all Open edX hostnames (prod + dev + kind-local) | 2026-02-06 |
| [`operations/RFC_CLAIM_BASED_ROLE_SYNC.md`](operations/RFC_CLAIM_BASED_ROLE_SYNC.md) | Draft RFC: optional claim-based role sync (Authentik -> Open edX) | 2026-02-06 |
| [`operations/LOCAL_ACCESS_INFO.md`](operations/LOCAL_ACCESS_INFO.md) | Local development URLs and credentials | 2025-11-12 |
| [`operations/LOCAL_PRODUCTION_PARITY.md`](operations/LOCAL_PRODUCTION_PARITY.md) | Local/production parity guide | 2025-11-12 |
| [`operations/LOCAL_WORK_REMAINING.md`](operations/LOCAL_WORK_REMAINING.md) | Current local development tasks | 2025-11-12 |
| [`operations/MFE_LOGIN_FIX.md`](operations/MFE_LOGIN_FIX.md) | MFE authentication troubleshooting | 2025-11-12 |
| [`operations/MFE_REBUILD_SUCCESS.md`](operations/MFE_REBUILD_SUCCESS.md) | MFE rebuild documentation | 2025-11-12 |
| [`operations/DISCOVERY_DEMO_COURSE_SETUP.md`](operations/DISCOVERY_DEMO_COURSE_SETUP.md) | Full setup guide for Discovery service and demo courses | 2026-02-03 |
| [`operations/MONGODB_PERMISSIONS_ISSUE.md`](operations/MONGODB_PERMISSIONS_ISSUE.md) | MongoDB Atlas permissions issue and resolution | 2026-02-03 |
| [`operations/DJANGO_RAW_SQL_BYPASS.md`](operations/DJANGO_RAW_SQL_BYPASS.md) | Bypass Django signals with raw SQL (when Celery broker unavailable) | 2025-12-29 |
| [`operations/GCP_ROADMAP.md`](operations/GCP_ROADMAP.md) | Cloud architecture plan and outstanding infra tasks | 2025-10-15 |
| [`operations/MONITORING.md`](operations/MONITORING.md) | Stack monitoring and alerting strategy | 2026-02-06 |
| [`operations/CLOUDFLARE_DNS.md`](operations/CLOUDFLARE_DNS.md) | DNS zones plus automation via Cloudflare API | 2025-09-05 |
| [`operations/SECRETS_SNAPSHOT.md`](operations/SECRETS_SNAPSHOT.md) | Inventory of non-git secrets and how they're stored | 2025-08-22 |
| [`operations/MULTISITE.md`](operations/MULTISITE.md) | Microsite strategy and shared theme tokens | 2025-09-10 |

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
| [`architecture/DATABASE_ARCHITECTURE.md`](architecture/DATABASE_ARCHITECTURE.md) | **START HERE:** Explains all databases (MySQL, MongoDB, Redis, etc.) | 2025-11-11 |
| [`architecture/MULTISITE_ANALYSIS.md`](architecture/MULTISITE_ANALYSIS.md) | Multisite architecture analysis | 2025-11-12 |

## 📈 Analytics & Reporting

| Doc | Purpose | Last Verified |
| --- | --- | --- |
| [`analytics/README.md`](analytics/README.md) | Overview of analytics docs and when to use each reference | 2025-11-09 |
| [`analytics/ASPECTS_INSTALLATION.md`](analytics/ASPECTS_INSTALLATION.md) | Installing the Open edX Aspects stack | 2025-07-25 |
| [`analytics/ASPECTS_QUICKSTART.md`](analytics/ASPECTS_QUICKSTART.md) | TL;DR for verifying Aspects after install | 2025-07-25 |
| [`analytics/ASPECTS_ACCESS.md`](analytics/ASPECTS_ACCESS.md) | Access/Superset credential guide | 2025-07-25 |
| [`analytics/ASPECTS_ANALYTICS.md`](analytics/ASPECTS_ANALYTICS.md) | How we report metrics out of Aspects | 2025-07-25 |
| [`analytics/ASPECTS_VS_PANORAMA.md`](analytics/ASPECTS_VS_PANORAMA.md) | Comparison study of analytics options | 2025-07-25 |
| [`analytics/PANORAMA_ANALYTICS.md`](analytics/PANORAMA_ANALYTICS.md) | Panorama-specific dashboards/workflows | 2025-07-25 |
| [`analytics/OPENEDX_ANALYTICS.md`](analytics/OPENEDX_ANALYTICS.md) | Built-in Open edX analytics hooks and exports | 2025-07-25 |
| [`analytics/ENROLLMENT_COMPARISON_QUICKSTART.md`](analytics/ENROLLMENT_COMPARISON_QUICKSTART.md) | Quick reconciliation between Kajabi and Open edX enrollments | 2025-10-01 |
| [`analytics/ASPECTS_K8S_DEPLOYMENT.md`](analytics/ASPECTS_K8S_DEPLOYMENT.md) | Resource tuning and deployment guide for Aspects on GKE Autopilot | 2025-11-09 |

## 🔌 Integrations

| Doc | Purpose | Last Verified |
| --- | --- | --- |
| [`integrations/README.md`](integrations/README.md) | Integration doc index and contribution guidelines | 2025-11-09 |
| [`integrations/GOOGLE_OAUTH_SETUP.md`](integrations/GOOGLE_OAUTH_SETUP.md) | End-to-end OAuth setup for Google Sign-In | 2025-08-30 |
| [`integrations/GOOGLE_OAUTH_QUICK_START.md`](integrations/GOOGLE_OAUTH_QUICK_START.md) | TL;DR version of the OAuth guide | 2025-08-30 |

## 📋 Status & Backlog

| Doc | Purpose | Last Verified |
| --- | --- | --- |
| [`status/NEXT10_TASKS.md`](status/NEXT10_TASKS.md) | Rolling top-10 backlog for the team | 2026-02-06 |
| [`status/OPERATIONAL_STATUS.md`](status/OPERATIONAL_STATUS.md) | Current operational status | 2025-11-12 |
| [`status/PARITY_ISSUES_FOUND.md`](status/PARITY_ISSUES_FOUND.md) | Local/production parity issues | 2025-11-12 |
| [`status/TASK2_STATUS.md`](status/TASK2_STATUS.md) | Task 2 status tracker | 2025-11-12 |

## 🎨 Branding & Style

| Doc | Purpose | Last Verified |
| --- | --- | --- |
| [`BRANDING.md`](BRANDING.md) | **Mereka branding system** - Color palette, typography, assets, verification, MFE integration, troubleshooting | 2026-02-11 |
| [`BRANDING_PLAN.md`](BRANDING_PLAN.md) | Status tracker for the cross-surface branding rollout | 2025-11-08 |
| [`STYLE_GUIDE.md`](STYLE_GUIDE.md) | Documentation conventions (metadata, folder layout, cross-links) | 2025-11-09 |

## 📚 Reference

| Doc | Purpose | Last Verified |
| --- | --- | --- |
| [`MONGODB_ATLAS.md`](MONGODB_ATLAS.md) | MongoDB Atlas migration and cutover guide | 2025-11-09 |
| [`KAJABI_API_ENDPOINTS.md`](KAJABI_API_ENDPOINTS.md) | Kajabi API endpoint reference | 2025-11-12 |
| [`MFE_COMPLETE_LIST.md`](MFE_COMPLETE_LIST.md) | Complete list of micro-frontends | 2025-11-12 |
| [`COURSE_IMPORT_GUIDE.md`](COURSE_IMPORT_GUIDE.md) | Course import procedures | 2025-11-12 |
| [`PRODUCTION_VERIFICATION_CHECKLIST.md`](PRODUCTION_VERIFICATION_CHECKLIST.md) | Production verification checklist | 2025-11-12 |
| [`QUICK_REFERENCE.md`](QUICK_REFERENCE.md) | Quick reference guide | 2025-11-12 |
| [`DATA_SOURCES_EXPLAINED.md`](DATA_SOURCES_EXPLAINED.md) | Data sources documentation | 2025-11-12 |
| [`MULTI_DEVELOPER_WORKFLOW.md`](MULTI_DEVELOPER_WORKFLOW.md) | Multi-developer workflow guide | 2025-11-12 |
| [`COMPLETE_SETUP_SYSTEM.md`](COMPLETE_SETUP_SYSTEM.md) | Complete setup system documentation | 2025-11-12 |
| [`COST_ESTIMATE.md`](COST_ESTIMATE.md) | Cost estimation guide | 2025-11-12 |
| [`COST_OPTIMIZATION.md`](COST_OPTIMIZATION.md) | Cost optimization strategies | 2025-11-12 |
| [`CLUSTER_STATUS.md`](CLUSTER_STATUS.md) | Cluster status documentation | 2025-11-12 |
| [`ASPECTS_DEPLOYMENT_STATUS.md`](ASPECTS_DEPLOYMENT_STATUS.md) | Aspects deployment status | 2025-11-12 |
| [`ASPECTS_K8S_DEPLOYMENT.md`](ASPECTS_K8S_DEPLOYMENT.md) | Aspects Kubernetes deployment | 2025-11-12 |
| [`ANALYTICS_ACCESS.md`](ANALYTICS_ACCESS.md) | Analytics access guide | 2025-11-12 |

## 📦 Archive

Historical and deprecated documentation:

- [`archive/CRITICAL_FINDINGS.md`](archive/CRITICAL_FINDINGS.md)
- [`archive/FINAL_STATUS_REPORT.md`](archive/FINAL_STATUS_REPORT.md)
- [`archive/IMPROVEMENTS_SUMMARY.md`](archive/IMPROVEMENTS_SUMMARY.md)

---

> ⭐ **Need to add something new?** Create the doc under `docs/`, add the metadata line, link it from the relevant folder README, and then add it to this index so everyone sees it.
