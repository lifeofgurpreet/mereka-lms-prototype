# Operations Reference
_Audience: Operators and reviewers • Owner: Platform Team • Last verified: 2026-03-09 • Status: canonical_

This directory contains operator-facing reference material for the current runtime surface.

## Use this directory for

- route, host, and capability matrices
- deployment/reference contracts
- runtime reference tables and inventories
- operator-facing configuration and environment reference material

## Runtime and deployment reference

- [`BACKUP_COVERAGE_MATRIX.md`](BACKUP_COVERAGE_MATRIX.md) for backup coverage reference
- [`CANONICAL_DEPLOY_CONTRACT.md`](CANONICAL_DEPLOY_CONTRACT.md) for deployment contract reference
- [`DEPLOYMENT_LANES.md`](DEPLOYMENT_LANES.md) for lane ownership across deployments
- [`CAPABILITY_MATRIX.md`](CAPABILITY_MATRIX.md) for current platform capability reference
- [`CAPACITY_PLANNING.md`](CAPACITY_PLANNING.md) for capacity posture
- [`RELEASE_BUNDLE.md`](RELEASE_BUNDLE.md) for release bundle reference
- [`RELEASE_EVIDENCE.md`](RELEASE_EVIDENCE.md) for release proof reference
- [`RELEASE_PROCESS.md`](RELEASE_PROCESS.md) for release reference flow
- [`SLSA_PROVENANCE.md`](SLSA_PROVENANCE.md) for provenance expectations

## Routing, hostnames, and tenancy

- [`ROUTE_MATRIX.md`](ROUTE_MATRIX.md) for runtime routing reference
- [`DOMAIN_MATRIX.md`](DOMAIN_MATRIX.md) for domain ownership mapping
- [`OPENEDX_HOSTNAMES.md`](OPENEDX_HOSTNAMES.md) for hostname inventory
- [`USER_FACING_URLS.md`](USER_FACING_URLS.md) for user-facing URL reference
- [`ENTERPRISE_MULTI_TENANCY_NAVIGATION.md`](ENTERPRISE_MULTI_TENANCY_NAVIGATION.md) for enterprise navigation reference
- [`MULTITENANT_BRAND_PLATFORM.md`](MULTITENANT_BRAND_PLATFORM.md) for tenant branding/reference surface
- [`TENANT_BRANDING_MATRIX.md`](TENANT_BRANDING_MATRIX.md) for tenant branding matrix
- [`TENANT_BRANDING_SURFACE_MATRIX.md`](TENANT_BRANDING_SURFACE_MATRIX.md) for branding surface mapping
- [`FOOTER_VARIANT_MATRIX.md`](FOOTER_VARIANT_MATRIX.md) for footer variant reference

## Authentication, secrets, and environment reference

- [`AUTHENTICATED_SMOKE_CREDENTIALS.md`](AUTHENTICATED_SMOKE_CREDENTIALS.md) for smoke credential reference
- [`AUTH_AND_PERMISSIONS.md`](AUTH_AND_PERMISSIONS.md) for operator auth reference
- [`AUTH_INTEGRATION_CONTRACT.md`](AUTH_INTEGRATION_CONTRACT.md) for auth integration contract
- [`SECRET_SCANNING.md`](SECRET_SCANNING.md) for secret-scanning reference
- [`SECRETS_SNAPSHOT.md`](SECRETS_SNAPSHOT.md) for secret inventory snapshots
- [`INFISICAL_MEREKA_LMS_KEYS.md`](INFISICAL_MEREKA_LMS_KEYS.md) for secret key inventory
- [`GITHUB_APP_TOKEN.md`](GITHUB_APP_TOKEN.md) for GitHub app token reference
- [`COMMIT_SIGNING.md`](COMMIT_SIGNING.md) for signing requirements
- [`SSO_CANARY.md`](SSO_CANARY.md) for SSO canary reference
- [`TTFS_ONBOARDING.md`](TTFS_ONBOARDING.md) for onboarding environment expectations

## Observability and service reference

- [`ALERT_NOISE_CLASSIFICATION_FEED.md`](ALERT_NOISE_CLASSIFICATION_FEED.md) for alert classification
- [`ALERT_SEVERITY_MATRIX.md`](ALERT_SEVERITY_MATRIX.md) for severity mapping
- [`LOGGING_AND_SENTRY.md`](LOGGING_AND_SENTRY.md) for logging and Sentry reference
- [`MONITORING.md`](MONITORING.md) for monitoring reference
- [`OBSERVABILITY_PARITY_MATRIX.md`](OBSERVABILITY_PARITY_MATRIX.md) for parity reference
- [`OBSERVABILITY_TRACING_PILOT_CONTRACT.md`](OBSERVABILITY_TRACING_PILOT_CONTRACT.md) for tracing pilot contract
- [`SLO_JOURNEY_SLI_MAPPING.md`](SLO_JOURNEY_SLI_MAPPING.md) for SLI journey mapping
- [`OPERATOR_DASHBOARD_GUIDE.md`](OPERATOR_DASHBOARD_GUIDE.md) for dashboard reference

## Service-specific and build reference

- [`ADMIN_CONSOLE_SETUP.md`](ADMIN_CONSOLE_SETUP.md) for admin console reference
- [`ASPECTS_ANALYTICS_SETUP.md`](ASPECTS_ANALYTICS_SETUP.md) for Aspects setup reference
- [`CI_CD_SETUP.md`](CI_CD_SETUP.md) for CI/CD environment reference
- [`ECOMMERCE_DEPRECATION_INVENTORY.md`](ECOMMERCE_DEPRECATION_INVENTORY.md) for legacy commerce inventory
- [`ECOMMERCE_THEMING.md`](ECOMMERCE_THEMING.md) for ecommerce theming reference
- [`EMAIL_DNS_RECORDS.md`](EMAIL_DNS_RECORDS.md) for mail DNS reference
- [`EMAIL_PIPELINE.md`](EMAIL_PIPELINE.md) for email pipeline reference
- [`FORUM_MEILISEARCH.md`](FORUM_MEILISEARCH.md) for forum search reference
- [`FRONTEND_BRANDING_METHOD.md`](FRONTEND_BRANDING_METHOD.md) for branding method reference
- [`GITHUB_ACTIONS_COST_MONITORING.md`](GITHUB_ACTIONS_COST_MONITORING.md) for CI cost monitoring
- [`LIBRARIES_GCS_SETUP.md`](LIBRARIES_GCS_SETUP.md) for content library storage setup
- [`MFE_ANALYTICS_PLUGIN_PARITY.md`](MFE_ANALYTICS_PLUGIN_PARITY.md) for MFE analytics parity
- [`MFE_PLUGIN_SLOT_MATRIX.md`](MFE_PLUGIN_SLOT_MATRIX.md) for plugin-slot runtime mapping
- [`MOBILE_SECRETS_MANAGEMENT.md`](MOBILE_SECRETS_MANAGEMENT.md) for mobile secret reference
- [`PRODUCTION_INFRASTRUCTURE_PLAN.md`](PRODUCTION_INFRASTRUCTURE_PLAN.md) for infrastructure reference

## Do not use this directory for

- step-by-step procedures, which belong in `docs/ops/runbooks/**`
- active status reporting, which belongs in `docs/status/**`
- policy decisions, which belong in `docs/policies/**`
