# Task Bundle: release_or_runtime_change

- Intent: Change release, deployment, runtime, or validator behavior affecting shipped reality.

## Read First
- `docs/meta/contracts/RELEASE_OBLIGATIONS.yaml` priority `1`: Governs release evidence and reviewer requirements.
- `docs/meta/contracts/INFRA_CROSSWALK.md` priority `2`: Shows what else must move in GitOps.
- `docs/meta/knowledge/REVIEW_HANDOFF_MODEL.md` priority `3`: Keeps runtime changes aligned with reviewer flow.

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
- `docs/meta/contracts/CHANGE_RUNTIME_CLOSEOUT.md`
- `docs/meta/contracts/CONTRACT_RUNTIME_MODEL.md`
- `docs/meta/contracts/CROSS_REPO_OWNERSHIP.yaml`
- `docs/meta/contracts/ENVIRONMENT_SURFACES.yaml`
- `docs/meta/contracts/INFRA_CROSSWALK.md`
- `docs/meta/contracts/RELEASE_OBLIGATIONS.yaml`
- `docs/meta/contracts/REVIEW_HANDOFF_MODEL.md`
- `docs/meta/contracts/WAVE6_EXECUTION_TRACKER.md`

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
- `specs/testmaps/RETIREMENT_PLAN.md`
- `specs/testmaps/mobile-apps-enterprise_spec.testmap.yml`
- `specs/testmaps/mobile-apps-secrets-management_spec.testmap.yml`
- `specs/tutor-configuration-resilience_spec.md`
- `specs/tutor-configuration_spec.md`
- `specs/verifiable-credentials-issuance_spec.md`
- `specs/verifiable-credentials-issuer_spec.md`
- `specs/verifiable-credentials-ops_spec.md`
- `specs/verifiable-credentials-types_spec.md`
- `specs/verifiable-credentials-verification_spec.md`
- `specs/video-pipeline-delivery_spec.md`

## Related Runbooks
- `docs/ops/quickref/verification-scripts.md`
- `docs/ops/runbooks/BADGES_CREDENTIALS_RUNBOOK.md`
- `docs/ops/runbooks/DOMAIN_MANAGEMENT.md`
- `docs/ops/runbooks/EMAIL_NOTIFICATIONS_RUNBOOK.md`
- `docs/ops/runbooks/FORUM_SERVICE_RUNBOOK.md`
- `docs/ops/runbooks/MOBILE_APPS_RUNBOOK.md`
- `docs/ops/runbooks/TENANT_PROVISIONING.md`
- `docs/ops/runbooks/TUTOR_PLUGIN_MIGRATION_RUNBOOK.md`

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
,
 
r
e
l
e
a
s
e
,
 
s
e
c
u
r
i
t
y
,
 
t
e
n
a
n
c
y
_
a
u
t
h
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
l
e
a
s
e
_
o
b
l
i
g
a
t
i
o
n
s
,
 
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
,
 
r
e
v
i
e
w
e
r
_
b
u
n
d
l
e
,
 
r
u
n
b
o
o
k
_
r
e
f
e
r
e
n
c
e
,
 
s
e
c
u
r
i
t
y
_
r
e
v
i
e
w
_
n
o
t
e
,
 
t
r
u
t
h
_
i
m
p
a
c
t
_
r
e
p
o
r
t

## Cross-Repo Dependencies
- `enterprise-services` -> `manual_review_required`; reviewers: architecture, platform, release, tenancy_auth
- `mfe` -> `manual_review_required`; reviewers: architecture, platform, release
- `observability-runtime` -> `infra_counterpart_required`; reviewers: platform, release
- `openedx` -> `manual_review_required`; reviewers: architecture, platform, release
- `purchase-gateway` -> `infra_counterpart_required`; reviewers: architecture, platform, release, security
- `runner-ci` -> `infra_counterpart_required`; reviewers: platform, release, security

## Out Of Scope
- `docs/archive/**`
- `specs/archive/**`

## Escalation Conditions
- deployment-affecting services span multiple review groups
- security review is implicated
