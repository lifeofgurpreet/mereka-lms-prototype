# Enterprise and Multi-Tenancy Navigation Hub

_Last verified: 2026-02-17_

This is the one-page starting point for platform-level multi-tenancy, enterprise, branding, and licensing work.

## 1) Core Operational Entry Points

- [`Operations quick reference`](../../ops/quickref/README.md) - Operations documentation index.
- [`docs/reference/operations/USER_FACING_URLS.md`](USER_FACING_URLS.md) - Complete URL matrix for production/dev/local and tenant-specific hosts.
- [`docs/reference/operations/OPENEDX_HOSTNAMES.md`](OPENEDX_HOSTNAMES.md) - Generated hostname registry used by infrastructure.
- [`docs/concepts/architecture/multi-tenancy-overview.md`](../../concepts/architecture/multi-tenancy-overview.md) - Domain + platform configuration details for tenant deployment.
- [`docs/policies/operations/MULTISITE_GOVERNANCE.md`](../../policies/operations/MULTISITE_GOVERNANCE.md) - Governance checks and recurring controls.
- [`docs/ops/runbooks/DOMAIN_CHANGE_RUNBOOK.md`](../../ops/runbooks/DOMAIN_CHANGE_RUNBOOK.md) - Domain update and validation sequence.
- [`docs/ops/runbooks/RELEASE_CHECKLIST_DOMAIN_SECRETS.md`](../../ops/runbooks/RELEASE_CHECKLIST_DOMAIN_SECRETS.md) - Domain/secret change safety checks.

## 2) Multi-Tenant Architecture & Provisioning

- [`docs/concepts/architecture/multi-tenancy-overview.md`](../../concepts/architecture/multi-tenancy-overview.md) - Architecture model and data isolation.
- [`docs/concepts/architecture/enterprise-services-overview.md`](../../concepts/architecture/enterprise-services-overview.md) - Enterprise services design.
- [`docs/concepts/architecture/multi-tenancy-overview.md`](../../concepts/architecture/multi-tenancy-overview.md) - Tenant model (shared services vs per-tenant domains).
- [`docs/ops/runbooks/MULTI_TENANCY_RUNBOOK.md`](../../ops/runbooks/MULTI_TENANCY_RUNBOOK.md) - Runbook for verification and isolation checks.
- [`docs/ops/runbooks/TENANT_PROVISIONING.md`](../../ops/runbooks/TENANT_PROVISIONING.md) - Provisioning command and brand-pack path.
- [`docs/archive/superseded/runbooks/tenant-provisioning-runbook.md`](../../archive/superseded/runbooks/tenant-provisioning-runbook.md) - Full provision + offboarding workflow.
- [`scripts/qa/verify-multisite-config.sh`](../../../scripts/qa/verify-multisite-config.sh) / [`scripts/qa/verify-org-role-ownership.sh`](../../../scripts/qa/verify-org-role-ownership.sh) - Readiness checks.

## 3) Enterprise Features, Licensing, and Admin Surfaces

- [`docs/ops/runbooks/ENTERPRISE_SERVICES_RUNBOOK.md`](../../ops/runbooks/ENTERPRISE_SERVICES_RUNBOOK.md) - Operational surface for enterprise microservices.
- [`docs/archive/superseded/runbooks/enterprise-services-runbook.md`](../../archive/superseded/runbooks/enterprise-services-runbook.md) - End-user runbook for onboarding, allocations, and service health.
- [`docs/concepts/architecture/enterprise-services-overview.md`](../../concepts/architecture/enterprise-services-overview.md) - Data flow and component model.
- `specs/enterprise-microservices_spec.md` - Formal acceptance criteria.
- `specs/multi-tenancy-architecture_spec.md` - Multi-tenancy ACs.

### Enterprise URLs (important)
- LMS admin (enterprise records): `https://academyv2.mereka.io/admin/enterprise/`
- Enterprise admin portal: `https://admin.academyv2.mereka.io`
- Enterprise learner portal: `https://learner.academyv2.mereka.io`

## 4) Branding, Theme, and Tenant Identity

- [`../guides/branding/BRANDING_OPERATING_MODEL.md`](../../guides/branding/BRANDING_OPERATING_MODEL.md) - Brand execution model.
- [`../guides/branding/TENANT_BRANDING_CONTRACT.md`](../../guides/branding/TENANT_BRANDING_CONTRACT.md) - Required branding inputs + ownership.
- [`TENANT_BRAND_PACK_SCHEMA.md`](TENANT_BRAND_PACK_SCHEMA.md) - JSON schema for tenant brand packs.
- [`docs/status/readiness/TENANT_BRANDING_READINESS_RAG.md`](../../status/readiness/TENANT_BRANDING_READINESS_RAG.md) - Branding readiness state and gaps.
- [`../guides/branding/BRANDING_GUARDRAILS.md`](../../guides/branding/BRANDING_GUARDRAILS.md) - Guardrails and regression checks.
- [`../architecture/FOOTER_V2_TO_LMS_MAPPING.md`](../architecture/FOOTER_V2_TO_LMS_MAPPING.md) - Footer mapping for LMS/MFE alignment.
- [`docs/ops/runbooks/TENANT_BRANDING_TROUBLESHOOTING.md`](../../ops/runbooks/TENANT_BRANDING_TROUBLESHOOTING.md) - Branding breakages and fixes.
- [`docs/ops/runbooks/TUTOR_PLUGIN_MIGRATION_RUNBOOK.md`](../../ops/runbooks/TUTOR_PLUGIN_MIGRATION_RUNBOOK.md) - Plugin strategy for Tutor/MFE customization.

## 5) Deployment, Verification, and Gates to Run

- [`scripts/branding/run-branding-gates.sh`](../../../scripts/branding/run-branding-gates.sh) - Canonical branding verification flow.
- [`scripts/branding/sync-brand-assets.sh`](../../../scripts/branding/sync-brand-assets.sh) - Brand asset sync process.
- [`scripts/qa/public-health-check.sh`](../../../scripts/qa/public-health-check.sh) - Full platform health check.
- [`scripts/qa/run-multisite-governance-gates.sh`](../../../scripts/qa/run-multisite-governance-gates.sh) - Multi-tenancy governance gates.
- [`scripts/qa/verify-mfe-build-prereqs.sh`](../../../scripts/qa/verify-mfe-build-prereqs.sh) - Required checks before MFE builds.
- [`scripts/qa/verify-mfe-image-branding.sh`](../../../scripts/qa/verify-mfe-image-branding.sh) - Image-level branding contract.
- [`scripts/qa/verify-gitops-image-overrides.sh`](../../../scripts/qa/verify-gitops-image-overrides.sh) - GitOps image/tag/override guardrails.

## 6) Suggested Work Sequence

1. Start with `docs/ops/runbooks/TENANT_PROVISIONING.md` before making portal/branding changes.
2. Validate domain + auth boundaries using `MULTISITE.md`, `MULTISITE_GOVERNANCE.md`, then run
   `STRICT=1 ./scripts/qa/run-multisite-governance-gates.sh --env both`.
3. Apply branding changes in `../guides/branding/` flows and verify with
   `CHECK_BRANDING=1 ./scripts/qa/public-health-check.sh prod`.
4. Verify enterprise services health with `docs/ops/runbooks/ENTERPRISE_SERVICES_RUNBOOK.md`.
5. Use `docs/ops/runbooks/ENTERPRISE_SERVICES_RUNBOOK.md` and the enterprise portals for license/tier lifecycle ops.
