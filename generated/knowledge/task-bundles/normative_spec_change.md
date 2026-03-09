# Task Bundle: normative_spec_change

- Intent: Change normative product or platform contract truth.
- Range: `origin/main...HEAD`

## Authority Order
- `source_normative_truth`
- `runtime_policy_truth`
- `generated_read_models`
- `reviewer_handoff_surfaces`

## Read First
- `specs/standards/SPEC_SYSTEM_CHARTER.md`
- `specs/standards/SPEC_METADATA_MODEL.md`
- `specs/standards/SPEC_AUTHORING_STANDARD.md`
- `generated/knowledge/change-manifest.json`
- `generated/knowledge/truth-impact-report.json`
- `generated/knowledge/review-bundle.md`

## Generated Surfaces To Refresh
- `generated/knowledge/change-manifest.json`
- `generated/knowledge/review-bundle.md`
- `generated/knowledge/truth-impact-report.json`
- `generated/catalogs/knowledge-catalog.json`
- `generated/graphs/knowledge-graph.json`

## Affected Truth Surfaces
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
- `specs/mongodb-atlas-integration_spec.md`
- `specs/multi-site-domains_spec.md`
- `specs/multi-tenancy-architecture_spec.md`
- `specs/observability-stack_spec.md`
- `specs/observability-validation-requirements_spec.md`
- `specs/oep48-brand-package_spec.md`
- `specs/plans/advanced-assessment-xqueue_plan.md`
- `specs/plans/advanced-assessment-xqueue_testplan.md`
- `specs/plans/analytics-pipeline_plan.md`
- `specs/plans/analytics-pipeline_testplan.md`
- `specs/plans/auth-sso-enterprise_plan.md`
- `specs/plans/auth-sso-enterprise_testplan.md`
- `specs/plans/branding-system_plan.md`
- `specs/plans/branding-system_testplan.md`
- `specs/plans/ci-cd-pipeline_plan.md`
- `specs/plans/ci-cd-pipeline_testplan.md`
- `specs/plans/content-libraries-v2_plan.md`
- `specs/plans/content-libraries-v2_testplan.md`
- `specs/plans/cross-cutting-requirements_testplan.md`
- `specs/plans/data-migrations-kajabi-mct_plan.md`
- `specs/plans/data-migrations-kajabi-mct_testplan.md`
- `specs/plans/data-privacy-gdpr-compliance_plan.md`
- `specs/plans/data-privacy-gdpr-compliance_testplan.md`
- `specs/plans/design-tokens-system_plan.md`
- `specs/plans/design-tokens-system_testplan.md`
- `specs/plans/disaster-recovery-business-continuity_plan.md`
- `specs/plans/disaster-recovery-business-continuity_testplan.md`
- `specs/plans/ecommerce-purchase-gateway_plan.md`
- `specs/plans/ecommerce-purchase-gateway_testplan.md`
- `specs/plans/email-notifications-pipeline_plan.md`
- `specs/plans/email-notifications-pipeline_testplan.md`
- `specs/plans/enterprise-microservices_plan.md`
- `specs/plans/enterprise-microservices_testplan.md`
- `specs/plans/forum-service-migration_plan.md`
- `specs/plans/forum-service-migration_testplan.md`
- `specs/plans/k8s-deployment_plan.md`
- `specs/plans/k8s-deployment_testplan.md`
- `specs/plans/mongodb-atlas-integration_plan.md`
- `specs/plans/mongodb-atlas-integration_testplan.md`
- `specs/plans/multi-site-domains_plan.md`
- `specs/plans/multi-site-domains_testplan.md`
- `specs/plans/multi-tenancy-architecture_plan.md`
- `specs/plans/multi-tenancy-architecture_testplan.md`
- `specs/plans/observability-stack_plan.md`
- `specs/plans/observability-stack_testplan.md`
- `specs/plans/platform-middleware-custom-apps_plan.md`
- `specs/plans/platform-middleware-custom-apps_testplan.md`
- `specs/plans/repository-structure_plan.md`
- `specs/plans/repository-structure_testplan.md`
- `specs/plans/secrets-management_plan.md`
- `specs/plans/secrets-management_testplan.md`
- `specs/plans/slo-sla-service-level-management_plan.md`
- `specs/plans/slo-sla-service-level-management_testplan.md`
- `specs/plans/tutor-configuration-resilience_plan.md`
- `specs/plans/tutor-configuration-resilience_testplan.md`
- `specs/plans/tutor-configuration_plan.md`
- `specs/plans/tutor-configuration_testplan.md`
- `specs/plans/video-pipeline-delivery_plan.md`
- `specs/plans/video-pipeline-delivery_testplan.md`
- `specs/platform-middleware-custom-apps_spec.md`
- `specs/repository-structure_spec.md`
- `specs/secrets-management_spec.md`
- `specs/slo-sla-service-level-management_spec.md`
- `specs/studio-customization_spec.md`
- `specs/tutor-configuration-resilience_spec.md`
- `specs/tutor-configuration_spec.md`
- `specs/verifiable-credentials-issuance_spec.md`
- `specs/verifiable-credentials-issuer_spec.md`
- `specs/verifiable-credentials-ops_spec.md`
- `specs/verifiable-credentials-types_spec.md`
- `specs/verifiable-credentials-verification_spec.md`
- `specs/video-pipeline-delivery_spec.md`

## Required Reviewers
- `architecture`
- `platform`

## Required Evidence
- `require_adr_update`
- `require_evidence_pack`
- `require_plan_refresh`
- `require_runbook_update`
- `require_status_update`
- `require_testplan_refresh`

## Required Commands
- `bash scripts/qa/run-knowledge-runtime-gates.sh`
- `python3 tools/docs/verify/verify-doc-catalog-governance.py --range origin/main...HEAD`
- `python3 tools/specs/verify_spec_frontmatter.py --repo-root .`
- `python3 tools/specs/verify_spec_taxonomy.py --repo-root .`
- `python3 tools/specs/verify_spec_paths.py --repo-root .`
- `python3 tools/specs/verify_docs_specs_boundary.py --repo-root .`
- `python3 tools/knowledge/build_task_bundle.py --repo-root . --range origin/main...HEAD`
- `python3 tools/knowledge/build_task_bundle.py --check --repo-root . --range origin/main...HEAD`
- `python3 tools/knowledge/build_skill_index.py --repo-root .`
- `python3 tools/knowledge/build_skill_index.py --check --repo-root .`
- `python3 tools/knowledge/verify_task_runtime.py --repo-root . --range origin/main...HEAD`
- `bash scripts/qa/run-task-runtime-gates.sh`

## Likely Cross-Repo Dependencies
- `enterprise-services` -> verdict `manual_review_required`; reviewers: architecture, platform, release, tenancy_auth
- `mfe` -> verdict `manual_review_required`; reviewers: architecture, platform, release
- `observability-runtime` -> verdict `infra_counterpart_required`; reviewers: platform, release
- `openedx` -> verdict `manual_review_required`; reviewers: architecture, platform, release
- `purchase-gateway` -> verdict `infra_counterpart_required`; reviewers: architecture, platform, release, security
- `runner-ci` -> verdict `infra_counterpart_required`; reviewers: platform, release, security

## Out Of Scope
- proposal-lane reshaping without contract change
- cross-repo deployment realization unless the task also changes contracts
- generated-surface-only cleanup

## Escalation Conditions
- mixed task overlaps with cross_repo_contract_change
- mixed task overlaps with release_or_runtime_change
- human review required if architecture and runtime truth move together
