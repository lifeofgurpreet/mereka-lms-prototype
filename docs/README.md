# Documentation Index
_Audience: Everyone • Owner: Infra Team • Last verified: 2025-11-09_

Use this file as the front door to the Mereka Academy Open edX docs. Each link below includes a short description plus the last-known verification date so you can see freshness at a glance.

## Quick Start

| Doc | Purpose | Last Verified |
| --- | --- | --- |
| [`quickstart/README.md`](quickstart/README.md) | Directory overview + how to contribute new onboarding docs. | 2025-11-09 |
| [`quickstart/LOCAL_SETUP.md`](quickstart/LOCAL_SETUP.md) | Full bootstrap for the Tutor 18.2.2 sandbox (venv, Tutor, theming). | 2025-11-09 |
| [`quickstart/WORKFLOW_LOCAL.md`](quickstart/WORKFLOW_LOCAL.md) | Daily start/stop, applying patches, and data import cheat sheet. | 2025-11-09 |

## Branding & Style

| Doc | Purpose | Last Verified |
| --- | --- | --- |
| [`BRANDING.md`](BRANDING.md) | Mereka palette, fonts, and LMS/MFE implementation details. | 2025-11-08 |
| [`BRANDING_PLAN.md`](BRANDING_PLAN.md) | Status tracker for the cross-surface branding rollout. | 2025-11-08 |
| [`STYLE_GUIDE.md`](STYLE_GUIDE.md) | Documentation conventions (metadata, folder layout, cross-links). | 2025-11-09 |

## Operations & Infrastructure

| Doc | Purpose | Last Verified |
| --- | --- | --- |
| [`ops/README.md`](ops/README.md) | Index for deployment, monitoring, and secrets guidance. | 2025-11-11 |
| [`ops/TROUBLESHOOTING.md`](ops/TROUBLESHOOTING.md) | **🚨 SITE DOWN?** Quick diagnostic checklist and fixes for common Kubernetes service issues. | 2025-11-11 |
| [`ops/DEPLOYMENT_RUNBOOK.md`](ops/DEPLOYMENT_RUNBOOK.md) | How we ship Tutor environments (local/prod/k8s). | 2025-10-30 |
| [`ops/GCP_ROADMAP.md`](ops/GCP_ROADMAP.md) | Cloud architecture plan and outstanding infra tasks. | 2025-10-15 |
| [`ops/MONITORING.md`](ops/MONITORING.md) | Stack monitoring and alerting strategy. | 2025-09-28 |
| [`ops/CLOUDFLARE_DNS.md`](ops/CLOUDFLARE_DNS.md) | DNS zones plus automation via Cloudflare API. | 2025-09-05 |
| [`ops/SECRETS_SNAPSHOT.md`](ops/SECRETS_SNAPSHOT.md) | Inventory of non-git secrets and how they're stored. | 2025-08-22 |
| [`ops/MULTISITE.md`](ops/MULTISITE.md) | Microsite strategy and shared theme tokens. | 2025-09-10 |

## Migrations

| Doc | Purpose | Last Verified |
| --- | --- | --- |
| [`migrations/README.md`](migrations/README.md) | Explains how migration domains are organized and linked. | 2025-11-09 |

### Kajabi

| Doc | Purpose | Last Verified |
| --- | --- | --- |
| [`migrations/kajabi/README.md`](migrations/kajabi/README.md) | Entry point for Kajabi export/transform/import docs. | 2025-11-09 |
| [`migrations/kajabi/KAJABI_MIGRATION.md`](migrations/kajabi/KAJABI_MIGRATION.md) | Canonical playbook spanning export -> transform -> import. | 2025-11-09 |
| [`migrations/kajabi/KAJABI_MIGRATION_STATUS.md`](migrations/kajabi/KAJABI_MIGRATION_STATUS.md) | Progress tracker for processed courses/users. | 2025-11-09 |
| [`migrations/kajabi/ROLLBACK_AND_SAFETY.md`](migrations/kajabi/ROLLBACK_AND_SAFETY.md) | Safety/rollback guidance before rerunning imports. | 2025-11-09 |

### MCT (Microsoft Community Training)

| Doc | Purpose | Last Verified |
| --- | --- | --- |
| [`migrations/mct/README.md`](migrations/mct/README.md) | Entry point for the legacy MCT migration docs. | 2025-08-31 |
| [`migrations/mct/MIGRATION_PLAN.md`](migrations/mct/MIGRATION_PLAN.md) | End-to-end plan for migrating from MCT. | 2025-08-31 |
| [`migrations/mct/EXPORT_GUIDE.md`](migrations/mct/EXPORT_GUIDE.md) | How to export data from MCT. | 2025-08-20 |
| [`migrations/mct/MCT_TO_OPENEDX_MAPPING.md`](migrations/mct/MCT_TO_OPENEDX_MAPPING.md) | Field mapping between MCT and Open edX. | 2025-08-31 |
| [`migrations/mct/MCT_MIGRATION_STATUS.md`](migrations/mct/MCT_MIGRATION_STATUS.md) | Status tracker for the MCT effort. | 2025-08-31 |

## Analytics & Reporting

| Doc | Purpose | Last Verified |
| --- | --- | --- |
| [`analytics/README.md`](analytics/README.md) | Overview of analytics docs and when to use each reference. | 2025-11-09 |
| [`analytics/ASPECTS_INSTALLATION.md`](analytics/ASPECTS_INSTALLATION.md) | Installing the Open edX Aspects stack. | 2025-07-25 |
| [`analytics/ASPECTS_QUICKSTART.md`](analytics/ASPECTS_QUICKSTART.md) | TL;DR for verifying Aspects after install. | 2025-07-25 |
| [`analytics/ASPECTS_ACCESS.md`](analytics/ASPECTS_ACCESS.md) | Access/Superset credential guide. | 2025-07-25 |
| [`analytics/ASPECTS_ANALYTICS.md`](analytics/ASPECTS_ANALYTICS.md) | How we report metrics out of Aspects. | 2025-07-25 |
| [`analytics/ASPECTS_VS_PANORAMA.md`](analytics/ASPECTS_VS_PANORAMA.md) | Comparison study of analytics options. | 2025-07-25 |
| [`analytics/PANORAMA_ANALYTICS.md`](analytics/PANORAMA_ANALYTICS.md) | Panorama-specific dashboards/workflows. | 2025-07-25 |
| [`analytics/OPENEDX_ANALYTICS.md`](analytics/OPENEDX_ANALYTICS.md) | Built-in Open edX analytics hooks and exports. | 2025-07-25 |
| [`analytics/ENROLLMENT_COMPARISON_QUICKSTART.md`](analytics/ENROLLMENT_COMPARISON_QUICKSTART.md) | Quick reconciliation between Kajabi and Open edX enrollments. | 2025-10-01 |
| [`analytics/ASPECTS_K8S_DEPLOYMENT.md`](analytics/ASPECTS_K8S_DEPLOYMENT.md) | Resource tuning and deployment guide for Aspects on GKE Autopilot. | 2025-11-09 |

## Integrations

| Doc | Purpose | Last Verified |
| --- | --- | --- |
| [`integrations/README.md`](integrations/README.md) | Integration doc index and contribution guidelines. | 2025-11-09 |
| [`integrations/GOOGLE_OAUTH_SETUP.md`](integrations/GOOGLE_OAUTH_SETUP.md) | End-to-end OAuth setup for Google Sign-In. | 2025-08-30 |
| [`integrations/GOOGLE_OAUTH_QUICK_START.md`](integrations/GOOGLE_OAUTH_QUICK_START.md) | TL;DR version of the OAuth guide. | 2025-08-30 |

## Reference & Backlog

| Doc | Purpose | Last Verified |
| --- | --- | --- |
| [`DATABASE_ARCHITECTURE.md`](DATABASE_ARCHITECTURE.md) | **START HERE:** Explains all databases (MySQL, MongoDB, Redis, etc.) and what they're for. | 2025-11-11 |
| [`ACCESS_URLS.md`](ACCESS_URLS.md) | **QUICK REFERENCE:** All URLs (LMS, Studio, Forum, Admin) and user management guide. | 2025-11-11 |
| [`MONGODB_ATLAS.md`](MONGODB_ATLAS.md) | MongoDB Atlas migration and cutover guide. | 2025-11-09 |
| [`NEXT10_TASKS.md`](NEXT10_TASKS.md) | Rolling top-10 backlog for the team. | 2025-11-11 |

> ⭐ **Need to add something new?** Create the doc under `docs/`, add the metadata line, link it from the relevant folder README, and then add it to this index so everyone sees it.
