# Wave 5 Review Bundle

- Range: `origin/main...HEAD`
- Changes classified: `308`
- Roots touched: `docs`, `specs`
- Required reviewers: `architecture`, `docs`, `platform`

## What Changed

### Change Classes
- `archival_only_change`: 7
- `docs_support_change`: 98
- `evidence_only_change`: 3
- `generated_surface_refresh`: 116
- `normative_contract_change`: 39
- `plan_only`: 36
- `proposal_only`: 4
- `reviewer_handoff_only`: 5

### Lanes
- `adr`: 21
- `archive`: 7
- `concept`: 26
- `evidence`: 3
- `generated`: 8
- `index`: 1
- `normative`: 39
- `other`: 129
- `plan`: 10
- `proposal`: 4
- `reference`: 9
- `review`: 17
- `runbook`: 8
- `testplan`: 26

## Read First
- `specs/advanced-assessment-xqueue_spec.md` [normative_contract_change; risk=high]
- `specs/analytics-pipeline_spec.md` [normative_contract_change; risk=high]
- `specs/auth-sso-enterprise_spec.md` [normative_contract_change; risk=high]
- `specs/branding-system_spec.md` [normative_contract_change; risk=high]
- `specs/ci-cd-pipeline_spec.md` [normative_contract_change; risk=high]
- `specs/content-libraries-v2_spec.md` [normative_contract_change; risk=high]
- `specs/cross-cutting-requirements_spec.md` [normative_contract_change; risk=high]
- `specs/data-migrations-kajabi-mct_spec.md` [normative_contract_change; risk=high]
- `specs/data-privacy-gdpr-compliance_spec.md` [normative_contract_change; risk=high]
- `specs/design-tokens-system_spec.md` [normative_contract_change; risk=high]
- `specs/disaster-recovery-business-continuity_spec.md` [normative_contract_change; risk=high]
- `specs/ecommerce-purchase-gateway_spec.md` [normative_contract_change; risk=high]

## Safe To Triage Later
- `.github/workflows/ci.yml` [generated_surface_refresh]
- `Makefile` [generated_surface_refresh]
- `deploy/contracts/infra-crosswalk.yaml` [generated_surface_refresh]
- `deploy/contracts/service-contracts/enterprise-services.yaml` [generated_surface_refresh]
- `deploy/contracts/service-contracts/mfe.yaml` [generated_surface_refresh]
- `deploy/contracts/service-contracts/observability-runtime.yaml` [generated_surface_refresh]
- `deploy/contracts/service-contracts/openedx.yaml` [generated_surface_refresh]
- `deploy/contracts/service-contracts/purchase-gateway.yaml` [generated_surface_refresh]
- `deploy/contracts/service-contracts/runner-ci.yaml` [generated_surface_refresh]
- `docs/_generated/bundles/60-docs-specs-contract.md` [generated_surface_refresh]
- `docs/archive/FRONTEND_PHASE_B_PROMPT.md` [archival_only_change]
- `docs/archive/FRONTEND_PHASE_C_PROMPT.md` [archival_only_change]

## Required Evidence And Follow-Up
- status update: `.github/workflows/docs-policy.yml`, `docs/adr/011-convention-based-spec-verification.md`, `docs/adr/013-studio-sso-bypass-middleware.md`, +177 more
- evidence pack: `specs/advanced-assessment-xqueue_spec.md`, `specs/analytics-pipeline_spec.md`, `specs/auth-sso-enterprise_spec.md`, +75 more
- runbook update: `.github/workflows/docs-policy.yml`, `docs/adr/011-convention-based-spec-verification.md`, `docs/adr/013-studio-sso-bypass-middleware.md`, +170 more
- ADR update: `.github/workflows/docs-policy.yml`, `docs/adr/011-convention-based-spec-verification.md`, `docs/adr/013-studio-sso-bypass-middleware.md`, +138 more
- plan refresh: `specs/advanced-assessment-xqueue_spec.md`, `specs/analytics-pipeline_spec.md`, `specs/auth-sso-enterprise_spec.md`, +76 more
- testplan refresh: `specs/advanced-assessment-xqueue_spec.md`, `specs/analytics-pipeline_spec.md`, `specs/auth-sso-enterprise_spec.md`, +72 more

## Impacted Truth Surfaces
- `.github/workflows/ci.yml`
- `.github/workflows/docs-policy.yml`
- `Makefile`
- `deploy/contracts/infra-crosswalk.yaml`
- `deploy/contracts/service-contracts/enterprise-services.yaml`
- `deploy/contracts/service-contracts/mfe.yaml`
- `deploy/contracts/service-contracts/observability-runtime.yaml`
- `deploy/contracts/service-contracts/openedx.yaml`
- `deploy/contracts/service-contracts/purchase-gateway.yaml`
- `deploy/contracts/service-contracts/runner-ci.yaml`
- `docs/_generated/bundles/60-docs-specs-contract.md`
- `docs/adr/011-convention-based-spec-verification.md`
- `docs/adr/013-studio-sso-bypass-middleware.md`
- `docs/adr/015-mobile-push-notification-provider.md`
- `docs/adr/016-android-app-support-decision.md`
- `docs/adr/018-purchase-gateway-replaces-oscar-ecommerce.md`
- `docs/adr/022-session-cookie-samesite-policy.md`
- `docs/adr/028-platform-sources-of-truth-and-control-planes.md`
- `docs/adr/029-identity-session-and-domain-boundary-strategy.md`
- `docs/adr/030-feature-flag-and-rollout-lifecycle.md`

## Owner Teams By Change Class
- `normative_contract_change` -> `architecture`
- `proposal_only` -> `architecture`
- `plan_only` -> `delivery`, `qa`
- `docs_support_change` -> `architecture`, `docs-program`, `platform-operations`
- `evidence_only_change` -> `qa`
- `generated_surface_refresh` -> `architecture`, `docs-program`
- `reviewer_handoff_only` -> `docs-program`
- `archival_only_change` -> `docs-program`

## Changed Files By Lane
### adr
- `docs/adr/011-convention-based-spec-verification.md`
- `docs/adr/013-studio-sso-bypass-middleware.md`
- `docs/adr/015-mobile-push-notification-provider.md`
- `docs/adr/016-android-app-support-decision.md`
- `docs/adr/018-purchase-gateway-replaces-oscar-ecommerce.md`
- `docs/adr/022-session-cookie-samesite-policy.md`
- `docs/adr/028-platform-sources-of-truth-and-control-planes.md`
- `docs/adr/029-identity-session-and-domain-boundary-strategy.md`
- `docs/adr/030-feature-flag-and-rollout-lifecycle.md`
- `docs/adr/031-deprecation-and-removal-policy.md`
- `docs/adr/032-data-governance-pii-retention-and-deletion.md`
- `docs/adr/033-tenant-lifecycle-contract.md`
- `docs/adr/manifest.yaml`
- `docs/adr/rfc/034-event-contract-and-transport-independence.md`
- `docs/adr/rfc/035-frontend-runtime-composition-and-dependency-alignment.md`
- `docs/adr/rfc/036-cache-topology-and-invalidation-strategy.md`
- `docs/adr/rfc/037-async-task-user-facing-contract.md`
- `docs/adr/rfc/038-commerce-system-of-record-and-reconciliation.md`
- `docs/adr/rfc/039-translations-and-internationalization-strategy.md`
- `docs/adr/rfc/040-internal-packages-plugins-and-versioning-policy.md`
- `... 1 more`

### archive
- `docs/archive/FRONTEND_PHASE_B_PROMPT.md`
- `docs/archive/FRONTEND_PHASE_C_PROMPT.md`
- `docs/archive/FRONTEND_PHASE_D_PROMPT.md`
- `docs/archive/evidence/operations/evidence/spec-dedupe-normalize-report.md`
- `docs/archive/superseded/ROADMAP.md`
- `docs/archive/superseded/runbooks/external-registration-runbook.md`
- `docs/archive/superseded/runbooks/proctoring-operations-runbook.md`

### concept
- `docs/concepts/architecture/ARCHITECTURE_CHARTER.md`
- `docs/concepts/architecture/AUTHORIZATION_MODEL.md`
- `docs/concepts/architecture/CONTROL_PLANES.md`
- `docs/concepts/architecture/DATA_GOVERNANCE.md`
- `docs/concepts/architecture/README.md`
- `docs/concepts/architecture/TENANT_LIFECYCLE.md`
- `docs/concepts/architecture/TUTOR_AND_EXTENSION_MODEL.md`
- `docs/concepts/architecture/notification-pipeline-overview.md`
- `docs/concepts/architecture/proctoring-architecture-overview.md`
- `docs/guides/admin/DOCS_CMDREF_BACKLOG_20260313.md`
- `docs/guides/branding/BRANDING_PLAN.md`
- `docs/guides/branding/TENANT_BRANDING_CONTRACT.md`
- `docs/guides/branding/TENANT_BRAND_PACK_SCHEMA.md`
- `docs/guides/onboarding/REPOSITORY_GUIDE.md`
- `docs/guides/onboarding/TEAM_SCALING_GUIDE.md`
- `docs/guides/standards/ADR_LANGUAGE_STYLE.md`
- `docs/guides/standards/ADR_NUMBERING_AND_NAMING.md`
- `docs/guides/standards/DOCS_SPECS_CONTRACT.md`
- `docs/guides/standards/DOCUMENTATION_STANDARDS.md`
- `docs/guides/standards/EVIDENCE_PACK_STANDARD.md`
- `... 6 more`

### evidence
- `specs/testmaps/RETIREMENT_PLAN.md`
- `specs/testmaps/mobile-apps-enterprise_spec.testmap.yml`
- `specs/testmaps/mobile-apps-secrets-management_spec.testmap.yml`

### generated
- `docs/_generated/bundles/60-docs-specs-contract.md`
- `specs/_generated/bundles/00-spec-hot-path.md`
- `specs/_generated/graph.json`
- `specs/_generated/indexes/spec-read-first.md`
- `specs/_generated/testmaps/README.md`
- `specs/_generated/testmaps/mobile-apps-enterprise_spec.testmap.yml`
- `specs/_generated/testmaps/mobile-apps-secrets-management_spec.testmap.yml`
- `specs/_generated/testmaps/paragon-design-tokens-migration_spec.testmap.yml`

### index
- `docs/catalog.json`

### normative
- `specs/advanced-assessment-xqueue_spec.md`
- `specs/analytics-pipeline_spec.md`
- `specs/auth-sso-enterprise_spec.md`
- `specs/branding-system_spec.md`
- `specs/ci-cd-pipeline_spec.md`
- `specs/content-libraries-v2_spec.md`
- `specs/cross-cutting-requirements_spec.md`
- `specs/data-migrations-kajabi-mct_spec.md`
- `specs/data-privacy-gdpr-compliance_spec.md`
- `specs/design-tokens-system_spec.md`
- `specs/disaster-recovery-business-continuity_spec.md`
- `specs/ecommerce-purchase-gateway_spec.md`
- `specs/email-notifications-pipeline_spec.md`
- `specs/enterprise-microservices_spec.md`
- `specs/forum-service-migration_spec.md`
- `specs/frontend-accessibility_spec.md`
- `specs/frontend-performance-budgets_spec.md`
- `specs/github-actions-cost-monitoring_spec.md`
- `specs/k8s-deployment_spec.md`
- `specs/mfe-plugin-slots_spec.md`
- `... 19 more`

### other
- `.github/workflows/ci.yml`
- `.github/workflows/docs-policy.yml`
- `Makefile`
- `deploy/contracts/infra-crosswalk.yaml`
- `deploy/contracts/service-contracts/enterprise-services.yaml`
- `deploy/contracts/service-contracts/mfe.yaml`
- `deploy/contracts/service-contracts/observability-runtime.yaml`
- `deploy/contracts/service-contracts/openedx.yaml`
- `deploy/contracts/service-contracts/purchase-gateway.yaml`
- `deploy/contracts/service-contracts/runner-ci.yaml`
- `docs/meta/contracts/CHANGE_RUNTIME_CLOSEOUT.md`
- `docs/meta/contracts/CONTRACT_RUNTIME_MODEL.md`
- `docs/meta/contracts/CROSS_REPO_OWNERSHIP.yaml`
- `docs/meta/contracts/ENVIRONMENT_SURFACES.yaml`
- `docs/meta/contracts/INFRA_CROSSWALK.md`
- `docs/meta/contracts/RELEASE_OBLIGATIONS.yaml`
- `docs/meta/contracts/REVIEW_HANDOFF_MODEL.md`
- `docs/meta/contracts/WAVE6_EXECUTION_TRACKER.md`
- `docs/meta/knowledge/CHANGE_CLASSES.yaml`
- `docs/meta/knowledge/CHANGE_RUNTIME_CLOSEOUT.md`
- `... 109 more`

### plan
- `specs/plans/ci-cd-pipeline_plan.md`
- `specs/plans/content-libraries-v2_plan.md`
- `specs/plans/external-registration-hubspot_plan.md`
- `specs/plans/forum-service-migration_plan.md`
- `specs/plans/mobile-apps-enterprise_plan.md`
- `specs/plans/multi-tenancy-architecture_plan.md`
- `specs/plans/platform-middleware-custom-apps_plan.md`
- `specs/plans/proctoring-integration_plan.md`
- `specs/plans/repository-structure_plan.md`
- `specs/plans/slo-sla-service-level-management_plan.md`

### proposal
- `specs/proposals/external-registration-hubspot_spec.md`
- `specs/proposals/mobile-apps-enterprise_spec.md`
- `specs/proposals/mobile-apps-secrets-management_spec.md`
- `specs/proposals/proctoring-integration_spec.md`

### reference
- `specs/standards/DOCS_SPECS_BOUNDARY.md`
- `specs/standards/SPEC_AUTHORING_STANDARD.md`
- `specs/standards/SPEC_METADATA_MODEL.md`
- `specs/standards/SPEC_SYSTEM_CHARTER.md`
- `specs/standards/brand-pack-schema.json`
- `specs/standards/spec-taxonomy.yaml`
- `specs/templates/plan-template.md`
- `specs/templates/proposal-template.md`
- `specs/templates/spec-template.md`

### review
- `docs/meta/docs-program/IMPLEMENTATION_ROADMAP.md`
- `docs/meta/docs-program/README.md`
- `docs/meta/docs-program/SPEC_COVERAGE.md`
- `docs/meta/docs-program/WAVE3_CLOSEOUT.md`
- `docs/meta/docs-program/WAVE3_EXECUTION_TRACKER.md`
- `docs/meta/docs-program/WAVE3_REVIEW_HANDOFF.md`
- `docs/meta/docs-program/WAVE4_CHARTER.md`
- `docs/meta/docs-program/WAVE4_CLOSEOUT.md`
- `docs/meta/docs-program/WAVE4_EXECUTION_TRACKER.md`
- `docs/meta/docs-program/WAVE4_REVIEWER_CHECKLIST.md`
- `docs/meta/docs-program/WAVE4_REVIEW_FRONT_DOOR.md`
- `docs/meta/docs-program/WAVE4_REVIEW_HANDOFF.md`
- `docs/meta/docs-program/WAVE4_WRAPPER_RETIREMENT_LEDGER.md`
- `docs/meta/docs-program/metadata/METADATA_MODEL.md`
- `docs/meta/docs-program/metadata/doc-class-schema-map.yaml`
- `docs/meta/docs-program/metadata/frontmatter-schema.json`
- `docs/meta/docs-program/metadata/governs-taxonomy.yaml`

### runbook
- `docs/ops/quickref/verification-scripts.md`
- `docs/ops/runbooks/BADGES_CREDENTIALS_RUNBOOK.md`
- `docs/ops/runbooks/DOMAIN_MANAGEMENT.md`
- `docs/ops/runbooks/EMAIL_NOTIFICATIONS_RUNBOOK.md`
- `docs/ops/runbooks/FORUM_SERVICE_RUNBOOK.md`
- `docs/ops/runbooks/MOBILE_APPS_RUNBOOK.md`
- `docs/ops/runbooks/TENANT_PROVISIONING.md`
- `docs/ops/runbooks/TUTOR_PLUGIN_MIGRATION_RUNBOOK.md`

### testplan
- `specs/plans/analytics-pipeline_testplan.md`
- `specs/plans/auth-sso-enterprise_testplan.md`
- `specs/plans/badges-credentials-enterprise_testplan.md`
- `specs/plans/branding-system_testplan.md`
- `specs/plans/ci-cd-pipeline_testplan.md`
- `specs/plans/content-libraries-v2_testplan.md`
- `specs/plans/cross-cutting-requirements_testplan.md`
- `specs/plans/data-migrations-kajabi-mct_testplan.md`
- `specs/plans/data-privacy-gdpr-compliance_testplan.md`
- `specs/plans/design-tokens-system_testplan.md`
- `specs/plans/disaster-recovery-business-continuity_testplan.md`
- `specs/plans/ecommerce-purchase-gateway_testplan.md`
- `specs/plans/email-notifications-pipeline_testplan.md`
- `specs/plans/enterprise-microservices_testplan.md`
- `specs/plans/external-registration-hubspot_testplan.md`
- `specs/plans/forum-service-migration_testplan.md`
- `specs/plans/k8s-deployment_testplan.md`
- `specs/plans/mobile-apps-enterprise_testplan.md`
- `specs/plans/mongodb-atlas-integration_testplan.md`
- `specs/plans/multi-site-domains_testplan.md`
- `... 6 more`
