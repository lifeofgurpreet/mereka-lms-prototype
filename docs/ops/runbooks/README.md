# Operator Runbooks
_Audience: Operators • Owner: Platform Team • Last verified: 2026-03-09 • Status: canonical_

This directory contains canonical operator procedures for runtime incidents, deployments, recovery, tenant operations, and service-specific troubleshooting.

## Use this directory for

- step-by-step operational procedures
- recovery and rollback instructions
- deployment and release execution runbooks
- service troubleshooting and runtime checks

## Do not use this directory for

- living architecture standards, which belong in `docs/concepts/architecture/**`
- policy decisions, which belong in `docs/policies/**`
- historical status reporting, which belongs in `docs/status/**` or archive surfaces

## Core runtime and deployment

- [`BUILD_PIPELINE_RUNBOOK.md`](BUILD_PIPELINE_RUNBOOK.md)
- [`RELEASE_EXECUTE_RUNBOOK.md`](RELEASE_EXECUTE_RUNBOOK.md)
- [`DEPLOYMENT_RUNBOOK.md`](DEPLOYMENT_RUNBOOK.md)
- [`K8S_DEPLOYMENT_RUNBOOK.md`](K8S_DEPLOYMENT_RUNBOOK.md)
- [`GITOPS_WORKFLOW.md`](GITOPS_WORKFLOW.md)
- [`DISASTER_RECOVERY.md`](DISASTER_RECOVERY.md)
- [`site-down.md`](site-down.md)
- [`emergency-rollback.md`](emergency-rollback.md)

## Service and platform operations

- [`AUTH_SSO_RUNBOOK.md`](AUTH_SSO_RUNBOOK.md)
- [`FORUM_RUNBOOK.md`](FORUM_RUNBOOK.md)
- [`ENTERPRISE_SERVICES_RUNBOOK.md`](ENTERPRISE_SERVICES_RUNBOOK.md)
- [`MOBILE_APPS_RUNBOOK.md`](MOBILE_APPS_RUNBOOK.md)
- [`MONGODB_ATLAS_RUNBOOK.md`](MONGODB_ATLAS_RUNBOOK.md)
- [`MULTI_TENANCY_RUNBOOK.md`](MULTI_TENANCY_RUNBOOK.md)
- [`PROCTORING_RUNBOOK.md`](PROCTORING_RUNBOOK.md)
- [`XQUEUE_HEALTH_RUNBOOK.md`](XQUEUE_HEALTH_RUNBOOK.md)

## Specialized procedures

- [`ACCESSIBILITY_CONFORMANCE_RUNBOOK.md`](ACCESSIBILITY_CONFORMANCE_RUNBOOK.md)
- [`ANALYTICS_RUNBOOK.md`](ANALYTICS_RUNBOOK.md)
- [`AUTH_ALERT_RUNBOOK.md`](AUTH_ALERT_RUNBOOK.md)
- [`BADGES_CREDENTIALS_RUNBOOK.md`](BADGES_CREDENTIALS_RUNBOOK.md)
- [`BRANDING_RELEASE_RUNBOOK.md`](BRANDING_RELEASE_RUNBOOK.md)
- [`BUILD_CACHE_PIPELINE_RUNBOOK.md`](BUILD_CACHE_PIPELINE_RUNBOOK.md)
- [`CI_CD_RUNBOOK.md`](CI_CD_RUNBOOK.md)
- [`COST_MONITORING_RUNBOOK.md`](COST_MONITORING_RUNBOOK.md)
- [`CSP_REPORTING_RUNBOOK.md`](CSP_REPORTING_RUNBOOK.md)
- [`DATA_ERASURE_RUNBOOK.md`](DATA_ERASURE_RUNBOOK.md)
- [`DISCOVERY_DEMO_COURSE_SETUP.md`](DISCOVERY_DEMO_COURSE_SETUP.md)
- [`DOMAIN_CHANGE_RUNBOOK.md`](DOMAIN_CHANGE_RUNBOOK.md)
- [`EMAIL_NOTIFICATIONS_RUNBOOK.md`](EMAIL_NOTIFICATIONS_RUNBOOK.md)
- [`FORUM_SERVICE_RUNBOOK.md`](FORUM_SERVICE_RUNBOOK.md)
- [`MFE_PLUGIN_SLOTS_RUNBOOK.md`](MFE_PLUGIN_SLOTS_RUNBOOK.md)
- [`MODULE_SURFACE_VALIDATION_RUNBOOK.md`](MODULE_SURFACE_VALIDATION_RUNBOOK.md)
- [`MONGODB_PERMISSIONS_ISSUE.md`](MONGODB_PERMISSIONS_ISSUE.md)
- [`PRIVACY_RUNBOOK.md`](PRIVACY_RUNBOOK.md)
- [`REPOSITORY_STRUCTURE_RUNBOOK.md`](REPOSITORY_STRUCTURE_RUNBOOK.md)
- [`TENANT_BRANDING_QA_RUNBOOK.md`](TENANT_BRANDING_QA_RUNBOOK.md)
- [`TUTOR_CONFIGURATION_RUNBOOK.md`](TUTOR_CONFIGURATION_RUNBOOK.md)
- [`TUTOR_PLUGIN_MIGRATION_RUNBOOK.md`](TUTOR_PLUGIN_MIGRATION_RUNBOOK.md)
- [`VISUAL_REGRESSION_RUNBOOK.md`](VISUAL_REGRESSION_RUNBOOK.md)

## Incident and recovery references

- [`credential-backfill-runbook.md`](credential-backfill-runbook.md)
- [`credential-issuance-failure-runbook.md`](credential-issuance-failure-runbook.md)
- [`credential-key-rotation-runbook.md`](credential-key-rotation-runbook.md)
- [`credential-verification-failure-runbook.md`](credential-verification-failure-runbook.md)
- [`database-issues.md`](database-issues.md)
- [`django-raw-sql-bypass.md`](django-raw-sql-bypass.md)
- [`performance-degradation.md`](performance-degradation.md)
- [`prod-park-mode.md`](prod-park-mode.md)
- [`production-verification-checklist.md`](production-verification-checklist.md)
- [`scaling.md`](scaling.md)
- [`task3-ses-smtp-guide.md`](task3-ses-smtp-guide.md)
