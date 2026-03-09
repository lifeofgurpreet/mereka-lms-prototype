# Task Bundle: compatibility_or_wrapper_cleanup

- Intent: Retire or adjust compatibility-only surfaces without restoring them as primary truth.

## Read First
- `docs/meta/docs-program/WAVE4_WRAPPER_RETIREMENT_LEDGER.md` priority `1`: Governs compatibility retirement policy and holdouts.

## Commands
- `bash scripts/qa/run-knowledge-runtime-gates.sh`
- `bash scripts/qa/run-cross-repo-contract-gates.sh`
- `python3 tools/docs/verify/verify-doc-catalog-governance.py --range origin/main...HEAD`
- `python3 tools/knowledge/resolve_task_context.py --repo-root . --range origin/main...HEAD --output generated/knowledge/task-context-report.json`
- `python3 tools/knowledge/resolve_task_context.py --check --repo-root . --range origin/main...HEAD --output generated/knowledge/task-context-report.json`
- `python3 tools/knowledge/build_task_bundle.py --repo-root . --range origin/main...HEAD --all --output-dir generated/knowledge/task-bundles`
- `python3 tools/knowledge/build_task_bundle.py --check --repo-root . --range origin/main...HEAD --all --output-dir generated/knowledge/task-bundles`
- `python3 tools/knowledge/build_skill_index.py --repo-root .`
- `python3 tools/knowledge/build_skill_index.py --check --repo-root .`
- `python3 tools/knowledge/verify_task_runtime.py --repo-root . --range origin/main...HEAD`
- `bash scripts/qa/run-task-runtime-gates.sh`

## Related Contracts
- `none`

## Related Specs
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
- `specs/plans/external-registration-hubspot_plan.md`
- `specs/plans/external-registration-hubspot_testplan.md`
- `specs/plans/forum-service-migration_plan.md`
- `specs/plans/forum-service-migration_testplan.md`
- `specs/plans/k8s-deployment_plan.md`
- `specs/plans/k8s-deployment_testplan.md`
- `specs/plans/mobile-apps-enterprise_plan.md`
- `specs/plans/mobile-apps-enterprise_testplan.md`
- `specs/plans/mongodb-atlas-integration_plan.md`
- `specs/plans/mongodb-atlas-integration_testplan.md`
- `specs/plans/multi-site-domains_plan.md`
- `specs/plans/multi-site-domains_testplan.md`
- `specs/plans/multi-tenancy-architecture_plan.md`
- `specs/plans/multi-tenancy-architecture_testplan.md`
- `specs/plans/observability-stack_plan.md`
- `specs/plans/observability-stack_testplan.md`
- `specs/plans/paragon-design-tokens-migration_spec.md`
- `specs/plans/platform-middleware-custom-apps_plan.md`
- `specs/plans/platform-middleware-custom-apps_testplan.md`
- `specs/plans/proctoring-integration_plan.md`
- `specs/plans/proctoring-integration_testplan.md`
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
- `specs/proposals/external-registration-hubspot_spec.md`
- `specs/proposals/mobile-apps-enterprise_spec.md`
- `specs/proposals/mobile-apps-secrets-management_spec.md`
- `specs/proposals/proctoring-integration_spec.md`
- `specs/repository-structure_spec.md`
- `specs/secrets-management_spec.md`
- `specs/slo-sla-service-level-management_spec.md`
- `specs/standards/DOCS_SPECS_BOUNDARY.md`
- `specs/standards/SPEC_AUTHORING_STANDARD.md`
- `specs/standards/SPEC_METADATA_MODEL.md`
- `specs/standards/SPEC_SYSTEM_CHARTER.md`
- `specs/standards/brand-pack-schema.json`
- `specs/standards/spec-taxonomy.yaml`
- `specs/studio-customization_spec.md`
- `specs/templates/plan-template.md`
- `specs/templates/proposal-template.md`
- `specs/templates/spec-template.md`
- `specs/tutor-configuration-resilience_spec.md`
- `specs/tutor-configuration_spec.md`
- `specs/verifiable-credentials-issuance_spec.md`
- `specs/verifiable-credentials-issuer_spec.md`
- `specs/verifiable-credentials-ops_spec.md`
- `specs/verifiable-credentials-types_spec.md`
- `specs/verifiable-credentials-verification_spec.md`
- `specs/video-pipeline-delivery_spec.md`

## Related Runbooks
- `none`

## Reviewers And Evidence
-
 
r
e
v
i
e
w
e
r
s
:
 
a
r
c
h
i
t
e
c
t
u
r
e
,
 
d
o
c
s
,
 
p
l
a
t
f
o
r
m
-
 
e
v
i
d
e
n
c
e
:
 
r
e
q
u
i
r
e
_
a
d
r
_
u
p
d
a
t
e
,
 
r
e
q
u
i
r
e
_
e
v
i
d
e
n
c
e
_
p
a
c
k
,
 
r
e
q
u
i
r
e
_
p
l
a
n
_
r
e
f
r
e
s
h
,
 
r
e
q
u
i
r
e
_
r
u
n
b
o
o
k
_
u
p
d
a
t
e
,
 
r
e
q
u
i
r
e
_
s
t
a
t
u
s
_
u
p
d
a
t
e
,
 
r
e
q
u
i
r
e
_
t
e
s
t
p
l
a
n
_
r
e
f
r
e
s
h

## Cross-Repo Dependencies
- `enterprise-services` -> `manual_review_required`; reviewers: architecture, platform, release, tenancy_auth
- `mfe` -> `manual_review_required`; reviewers: architecture, platform, release
- `observability-runtime` -> `infra_counterpart_required`; reviewers: platform, release
- `openedx` -> `manual_review_required`; reviewers: architecture, platform, release
- `purchase-gateway` -> `infra_counterpart_required`; reviewers: architecture, platform, release, security
- `runner-ci` -> `infra_counterpart_required`; reviewers: platform, release, security

## Out Of Scope
- `specs/archive/**`

## Escalation Conditions
- wrapper retirement would remove the last live path
