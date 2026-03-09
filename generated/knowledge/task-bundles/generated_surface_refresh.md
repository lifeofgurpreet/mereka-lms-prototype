# Task Bundle: generated_surface_refresh

- Intent: Refresh generated catalogs, graphs, manifests, bundles, and indexes without changing governing policy.

## Read First
- `docs/meta/docs-program/WAVE4_REVIEW_FRONT_DOOR.md` priority `1`: Generated surfaces still derive from Wave 4 topology.

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
- `deploy/contracts/infra-crosswalk.yaml`
- `deploy/contracts/service-contracts/enterprise-services.yaml`
- `deploy/contracts/service-contracts/mfe.yaml`
- `deploy/contracts/service-contracts/observability-runtime.yaml`
- `deploy/contracts/service-contracts/openedx.yaml`
- `deploy/contracts/service-contracts/purchase-gateway.yaml`
- `deploy/contracts/service-contracts/runner-ci.yaml`

## Related Specs
- `specs/IMPLEMENTATION_ORDER.md`
- `specs/INDEX.md`
- `specs/README.md`
- `specs/_TEMPLATE.md`
- `specs/_generated/bundles/00-spec-hot-path.md`
- `specs/_generated/graph.json`
- `specs/_generated/indexes/spec-read-first.md`
- `specs/_generated/testmaps/README.md`
- `specs/_generated/testmaps/mobile-apps-enterprise_spec.testmap.yml`
- `specs/_generated/testmaps/mobile-apps-secrets-management_spec.testmap.yml`
- `specs/_generated/testmaps/paragon-design-tokens-migration_spec.testmap.yml`
- `specs/analytics-pipeline_spec.md`
- `specs/auth-sso-enterprise_spec.md`
- `specs/brand-pack-schema.json`
- `specs/branding-system_spec.md`
- `specs/catalog.json`
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
- `specs/k8s-deployment_spec.md`
- `specs/manual_verifications.yaml`
- `specs/mongodb-atlas-integration_spec.md`
- `specs/multi-site-domains_spec.md`
- `specs/multi-tenancy-architecture_spec.md`
- `specs/plans/IMPLEMENTATION_ORDER.md`
- `specs/plans/README.md`
- `specs/plans/analytics-pipeline_testplan.md`
- `specs/plans/auth-sso-enterprise_testplan.md`
- `specs/plans/badges-credentials-enterprise_testplan.md`
- `specs/plans/branding-system_testplan.md`
- `specs/plans/ci-cd-pipeline_plan.md`
- `specs/plans/ci-cd-pipeline_testplan.md`
- `specs/plans/content-libraries-v2_plan.md`
- `specs/plans/content-libraries-v2_testplan.md`
- `specs/plans/cross-cutting-requirements_testplan.md`
- `specs/plans/data-migrations-kajabi-mct_testplan.md`
- `specs/plans/data-privacy-gdpr-compliance_testplan.md`
- `specs/plans/design-tokens-system_testplan.md`
- `specs/plans/disaster-recovery-business-continuity_testplan.md`
- `specs/plans/ecommerce-purchase-gateway_testplan.md`
- `specs/plans/email-notifications-pipeline_testplan.md`
- `specs/plans/enterprise-microservices_testplan.md`
- `specs/plans/external-registration-hubspot_plan.md`
- `specs/plans/external-registration-hubspot_testplan.md`
- `specs/plans/forum-service-migration_plan.md`
- `specs/plans/forum-service-migration_testplan.md`
- `specs/plans/k8s-deployment_testplan.md`
- `specs/plans/manual_verifications.yaml`
- `specs/plans/mobile-apps-enterprise_plan.md`
- `specs/plans/mobile-apps-enterprise_testplan.md`
- `specs/plans/mongodb-atlas-integration_testplan.md`
- `specs/plans/multi-site-domains_testplan.md`
- `specs/plans/multi-tenancy-architecture_plan.md`
- `specs/plans/paragon-design-tokens-migration_spec.md`
- `specs/plans/platform-middleware-custom-apps_plan.md`
- `specs/plans/platform-middleware-custom-apps_testplan.md`
- `specs/plans/proctoring-integration_plan.md`
- `specs/plans/proctoring-integration_testplan.md`
- `specs/plans/repository-structure_plan.md`
- `specs/plans/repository-structure_testplan.md`
- `specs/plans/secrets-management_testplan.md`
- `specs/plans/slo-sla-service-level-management_plan.md`
- `specs/plans/slo-sla-service-level-management_testplan.md`
- `specs/plans/video-pipeline-delivery_testplan.md`
- `specs/platform-middleware-custom-apps_spec.md`
- `specs/proposals/README.md`
- `specs/repository-structure_spec.md`
- `specs/secrets-management_spec.md`
- `specs/slo-sla-service-level-management_spec.md`
- `specs/standards/DOCS_SPECS_BOUNDARY.md`
- `specs/standards/SPEC_AUTHORING_STANDARD.md`
- `specs/standards/SPEC_METADATA_MODEL.md`
- `specs/standards/SPEC_SYSTEM_CHARTER.md`
- `specs/standards/brand-pack-schema.json`
- `specs/standards/spec-taxonomy.yaml`
- `specs/templates/plan-template.md`
- `specs/templates/proposal-template.md`
- `specs/templates/spec-template.md`
- `specs/video-pipeline-delivery_spec.md`

## Related Runbooks
- `generated/knowledge/task-bundles/runbook_or_ops_change.json`
- `generated/knowledge/task-bundles/runbook_or_ops_change.md`

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
- `docs/archive/**`
- `specs/archive/**`

## Escalation Conditions
- generated output drifts after source updates
