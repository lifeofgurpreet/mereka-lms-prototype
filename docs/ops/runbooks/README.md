# Operator Runbooks
_Audience: Operators • Owner: Platform Team • Last verified: 2026-03-10 • Status: canonical_

This directory contains the active operator runbook surface for incidents, deployments, recovery, tenant operations, and service troubleshooting.

## Start here

- Site is down or degraded:
  - [`site-down.md`](site-down.md)
  - [`TROUBLESHOOTING.md`](TROUBLESHOOTING.md)
- Need release or deployment execution:
  - [`DEPLOYMENT_RUNBOOK.md`](DEPLOYMENT_RUNBOOK.md)
  - [`RELEASE_EXECUTE_RUNBOOK.md`](RELEASE_EXECUTE_RUNBOOK.md)
- Need observability or on-call routing:
  - [`OBSERVABILITY_QUICKSTART.md`](OBSERVABILITY_QUICKSTART.md)
  - [`ONCALL_OBSERVABILITY_PLAYBOOK.md`](ONCALL_OBSERVABILITY_PLAYBOOK.md)
- Need tenant or enterprise operations:
  - [`MULTI_TENANCY_RUNBOOK.md`](MULTI_TENANCY_RUNBOOK.md)
  - [`ENTERPRISE_SERVICES_RUNBOOK.md`](ENTERPRISE_SERVICES_RUNBOOK.md)

## Core runtime and deployment

- [`DEPLOYMENT_RUNBOOK.md`](DEPLOYMENT_RUNBOOK.md)
- [`K8S_DEPLOYMENT_RUNBOOK.md`](K8S_DEPLOYMENT_RUNBOOK.md)
- [`GITOPS_WORKFLOW.md`](GITOPS_WORKFLOW.md)
- [`RELEASE_CHECKLIST.md`](RELEASE_CHECKLIST.md)
- [`RELEASE_EXECUTE_RUNBOOK.md`](RELEASE_EXECUTE_RUNBOOK.md)
- [`POST_DEPLOY_GATE.md`](POST_DEPLOY_GATE.md)
- [`DEPLOY_EVIDENCE_GATES.md`](DEPLOY_EVIDENCE_GATES.md)
- [`DISASTER_RECOVERY.md`](DISASTER_RECOVERY.md)
- [`site-down.md`](site-down.md)
- [`emergency-rollback.md`](emergency-rollback.md)
- [`migrations/README.md`](migrations/README.md)

## Service and platform operations

- [`ARGOCD_DRIFT.md`](ARGOCD_DRIFT.md)
- [`ARGOCD_HEALTH_TROUBLESHOOTING.md`](ARGOCD_HEALTH_TROUBLESHOOTING.md)
- [`AUTH_SSO_RUNBOOK.md`](AUTH_SSO_RUNBOOK.md)
- [`ENTERPRISE_SERVICES_RUNBOOK.md`](ENTERPRISE_SERVICES_RUNBOOK.md)
- [`FORUM_RUNBOOK.md`](FORUM_RUNBOOK.md)
- [`MOBILE_APPS_RUNBOOK.md`](MOBILE_APPS_RUNBOOK.md)
- [`MONGODB_ATLAS_RUNBOOK.md`](MONGODB_ATLAS_RUNBOOK.md)
- [`MULTI_TENANCY_RUNBOOK.md`](MULTI_TENANCY_RUNBOOK.md)
- [`OBSERVABILITY_QUICKSTART.md`](OBSERVABILITY_QUICKSTART.md)
- [`ONCALL_OBSERVABILITY_PLAYBOOK.md`](ONCALL_OBSERVABILITY_PLAYBOOK.md)
- [`PROCTORING_RUNBOOK.md`](PROCTORING_RUNBOOK.md)
- [`XQUEUE_HEALTH_RUNBOOK.md`](XQUEUE_HEALTH_RUNBOOK.md)

## Specialized procedures

- [`ACCESSIBILITY_CONFORMANCE_RUNBOOK.md`](ACCESSIBILITY_CONFORMANCE_RUNBOOK.md)
- [`A11Y_CONTRAST_FOCUS_GATE.md`](A11Y_CONTRAST_FOCUS_GATE.md)
- [`A11Y_REGRESSION_LANE.md`](A11Y_REGRESSION_LANE.md)
- [`A11Y_TENANT_BRANDING_GATE.md`](A11Y_TENANT_BRANDING_GATE.md)
- [`ALERT_TUNING_SOP.md`](ALERT_TUNING_SOP.md)
- [`ANALYTICS_RUNBOOK.md`](ANALYTICS_RUNBOOK.md)
- [`AUTH_ALERT_RUNBOOK.md`](AUTH_ALERT_RUNBOOK.md)
- [`AUTH_CHANGE_CHECKLIST.md`](AUTH_CHANGE_CHECKLIST.md)
- [`BRANDING_RELEASE_RUNBOOK.md`](BRANDING_RELEASE_RUNBOOK.md)
- [`CI_CD_RUNBOOK.md`](CI_CD_RUNBOOK.md)
- [`DATA_ERASURE_RUNBOOK.md`](DATA_ERASURE_RUNBOOK.md)
- [`DOMAIN_CHANGE_RUNBOOK.md`](DOMAIN_CHANGE_RUNBOOK.md)
- [`DOMAIN_MANAGEMENT.md`](DOMAIN_MANAGEMENT.md)
- [`EMAIL_NOTIFICATIONS_RUNBOOK.md`](EMAIL_NOTIFICATIONS_RUNBOOK.md)
- [`FRONTEND_REGRESSION_CHECKLIST.md`](FRONTEND_REGRESSION_CHECKLIST.md)
- [`GDPR_COMPLIANCE.md`](GDPR_COMPLIANCE.md)
- [`PRIVACY_RUNBOOK.md`](PRIVACY_RUNBOOK.md)
- [`TENANT_BRANDING_QA_RUNBOOK.md`](TENANT_BRANDING_QA_RUNBOOK.md)
- [`TENANT_BRANDING_TROUBLESHOOTING.md`](TENANT_BRANDING_TROUBLESHOOTING.md)
- [`TENANT_PROVISIONING.md`](TENANT_PROVISIONING.md)
- [`TROUBLESHOOTING.md`](TROUBLESHOOTING.md)
- [`TUTOR_CONFIGURATION_RUNBOOK.md`](TUTOR_CONFIGURATION_RUNBOOK.md)
- [`VISUAL_PARITY_CHECKPOINTS.md`](VISUAL_PARITY_CHECKPOINTS.md)
- [`VISUAL_REGRESSION_RUNBOOK.md`](VISUAL_REGRESSION_RUNBOOK.md)

## Incident and recovery references

- [`credential-backfill-runbook.md`](credential-backfill-runbook.md)
- [`credential-issuance-failure-runbook.md`](credential-issuance-failure-runbook.md)
- [`credential-key-rotation-runbook.md`](credential-key-rotation-runbook.md)
- [`credential-verification-failure-runbook.md`](credential-verification-failure-runbook.md)
- [`database-issues.md`](database-issues.md)
- [`DEV_DB_REBUILD_CANONICAL.md`](DEV_DB_REBUILD_CANONICAL.md)
- [`django-raw-sql-bypass.md`](django-raw-sql-bypass.md)
- [`performance-degradation.md`](performance-degradation.md)
- [`prod-park-mode.md`](prod-park-mode.md)
- [`production-verification-checklist.md`](production-verification-checklist.md)
- [`scaling.md`](scaling.md)

## What this directory is not

Do not use this directory for:
- policy rules that belong in `docs/policies/**`
- factual inventories that belong in `docs/reference/**`
- active proof that belongs in `docs/evidence/**`
- active reporting that belongs in `docs/status/**`
