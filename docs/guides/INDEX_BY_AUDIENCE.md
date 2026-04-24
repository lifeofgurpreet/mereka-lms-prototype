# Documentation Index by Audience
_Audience: Humans choosing a starting point • Owner: Documentation Team • Last verified: 2026-03-10 • Status: canonical_

This is a role router, not a global catalog. Start with the closest role below, then follow the linked root or high-signal guide.

Use this page when the first question is "which docs path matches my role?"
If you already know you are inheriting the repo, start with `docs/README.md`.
If you already know you are designing or landing a change, start with `docs/architecture/README.md`.

## Platform Operators

- Start here:
  - [`admin/README.md`](admin/README.md)
- Daily references:
  - [`admin/K8S_OPERATIONS_GUIDE.md`](admin/K8S_OPERATIONS_GUIDE.md)
  - [`admin/SECRETS_MANAGEMENT_GUIDE.md`](admin/SECRETS_MANAGEMENT_GUIDE.md)
  - [`../ops/quickref/README.md`](../ops/quickref/README.md)
  - [`../reference/platform/DOMAIN_AND_ACCESS_REFERENCE.md`](../reference/platform/DOMAIN_AND_ACCESS_REFERENCE.md)
- High-stakes / escalation:
  - [`../ops/runbooks/DEPLOYMENT_RUNBOOK.md`](../ops/runbooks/DEPLOYMENT_RUNBOOK.md)
  - [`../ops/runbooks/INCIDENT_RESPONSE.md`](../ops/runbooks/INCIDENT_RESPONSE.md)

## SRE / On-call

- Start here:
  - [`../ops/runbooks/ONCALL_OBSERVABILITY_PLAYBOOK.md`](../ops/runbooks/ONCALL_OBSERVABILITY_PLAYBOOK.md)
- Daily references:
  - [`../ops/runbooks/site-down.md`](../ops/runbooks/site-down.md)
  - [`../ops/runbooks/performance-degradation.md`](../ops/runbooks/performance-degradation.md)
  - [`../reference/operations/ALERT_SEVERITY_MATRIX.md`](../reference/operations/ALERT_SEVERITY_MATRIX.md)
  - [`admin/OBSERVABILITY_GUIDE.md`](admin/OBSERVABILITY_GUIDE.md)
- High-stakes / escalation:
  - [`../ops/runbooks/DISASTER_RECOVERY.md`](../ops/runbooks/DISASTER_RECOVERY.md)
  - [`../policies/operations/ONCALL_ROTATION.md`](../policies/operations/ONCALL_ROTATION.md)

## Developers

- Start here:
  - [`onboarding/README.md`](onboarding/README.md)
- Daily references:
  - [`onboarding/QUICK_START_LOCAL.md`](onboarding/QUICK_START_LOCAL.md)
  - [`onboarding/LOCAL_SETUP.md`](onboarding/LOCAL_SETUP.md)
  - [`onboarding/WORKFLOW_LOCAL.md`](onboarding/WORKFLOW_LOCAL.md)
  - [`onboarding/REPOSITORY_GUIDE.md`](onboarding/REPOSITORY_GUIDE.md)
  - [`../README.md`](../README.md)
  - [`../ops/quickref/README.md`](../ops/quickref/README.md)
- High-stakes / escalation:
  - [`../README.md`](../README.md)
  - [`../architecture/README.md`](../architecture/README.md)
  - [`../adr/README.md`](../adr/README.md)

## Course Teams / Authors

- Start here:
  - [`platform/COURSE_AUTHORING_QUICKSTART.md`](platform/COURSE_AUTHORING_QUICKSTART.md)
- Daily references:
  - [`platform/PLATFORM_START_HERE.md`](platform/PLATFORM_START_HERE.md)
  - [`admin/ADMIN_LOGIN_GUIDE.md`](admin/ADMIN_LOGIN_GUIDE.md)
  - [`platform/OPENEDX_FOR_TEAM_MEMBERS.md`](platform/OPENEDX_FOR_TEAM_MEMBERS.md)
  - [`platform/OPENEDX_SETTINGS_MATRIX.md`](platform/OPENEDX_SETTINGS_MATRIX.md)
  - [`platform/Content Libraries Authoring`](../concepts/architecture/content-libraries-overview.md)
- High-stakes / escalation:
  - [`platform/SUPPORT_AND_ESCALATION.md`](platform/SUPPORT_AND_ESCALATION.md)
  - [`../ops/runbooks/TENANT_PROVISIONING.md`](../ops/runbooks/TENANT_PROVISIONING.md)

## Enterprise / Tenant Admins

- Start here:
  - [`platform/PLATFORM_START_HERE.md`](platform/PLATFORM_START_HERE.md)
- Daily references:
  - [`admin/ADMIN_LOGIN_GUIDE.md`](admin/ADMIN_LOGIN_GUIDE.md)
  - [`admin/MULTI_SITE_GUIDE.md`](admin/MULTI_SITE_GUIDE.md)
  - [`admin/ENTERPRISE_SERVICES_GUIDE.md`](admin/ENTERPRISE_SERVICES_GUIDE.md)
  - [`admin/Content Libraries Enterprise Onboarding`](../ops/runbooks/CONTENT_LIBRARIES_V2_MIGRATION.md)
  - [`../reference/platform/DOMAIN_AND_ACCESS_REFERENCE.md`](../reference/platform/DOMAIN_AND_ACCESS_REFERENCE.md)
  - [`../reference/operations/AUTH_AND_PERMISSIONS.md`](../reference/operations/AUTH_AND_PERMISSIONS.md)
- High-stakes / escalation:
  - [`platform/SUPPORT_AND_ESCALATION.md`](platform/SUPPORT_AND_ESCALATION.md)
  - [`../ops/runbooks/TENANT_PROVISIONING.md`](../ops/runbooks/TENANT_PROVISIONING.md)

## Learners / Support-Facing Teammates

- Start here:
  - [`platform/PLATFORM_START_HERE.md`](platform/PLATFORM_START_HERE.md)
- Daily references:
  - [`../reference/platform/DOMAIN_AND_ACCESS_REFERENCE.md`](../reference/platform/DOMAIN_AND_ACCESS_REFERENCE.md)
  - [`platform/SUPPORT_AND_ESCALATION.md`](platform/SUPPORT_AND_ESCALATION.md)
  - [`platform/OPENEDX_FOR_TEAM_MEMBERS.md`](platform/OPENEDX_FOR_TEAM_MEMBERS.md)
- Keep distinct:
  - learner/support routing lives in platform handbook pages
  - operator/runtime authority lives in `docs/ops/**` and `docs/reference/**`
- Escalate when:
  - a documented learner URL is broken
  - tenant branding or access differs from the generated reference
  - the request needs a platform-owned change rather than a course-team action

## Security / Compliance

- Start here:
  - [`admin/SECRETS_MANAGEMENT_GUIDE.md`](admin/SECRETS_MANAGEMENT_GUIDE.md)
- Daily references:
  - [`../ops/runbooks/SECRET_ROTATION_CHECKLIST.md`](../ops/runbooks/SECRET_ROTATION_CHECKLIST.md)
  - [`../reference/operations/AUTH_AND_PERMISSIONS.md`](../reference/operations/AUTH_AND_PERMISSIONS.md)
  - [`../architecture/PLATFORM_AUTHORITY_MAP.md`](../architecture/PLATFORM_AUTHORITY_MAP.md)
  - [`../policies/operations/README.md`](../policies/operations/README.md)
- High-stakes / escalation:
  - [`../ops/runbooks/SECURITY_INCIDENT_SUPPLY_CHAIN.md`](../ops/runbooks/SECURITY_INCIDENT_SUPPLY_CHAIN.md)
  - [`../ops/runbooks/INCIDENT_RESPONSE.md`](../ops/runbooks/INCIDENT_RESPONSE.md)

## Cross-cutting references

- Platform handbook:
  - [`platform/PLATFORM_START_HERE.md`](platform/PLATFORM_START_HERE.md)
- Canonical guide root:
  - [`README.md`](README.md)
- Architecture standards:
  - [`../architecture/README.md`](../architecture/README.md)
- Documentation standards:
  - [`standards/README.md`](standards/README.md)

## What This Index Does Not Do

- It does not replace canonical runbooks, architecture docs, or active status boards.
- It does not act as a learner-facing product manual.
- It does not imply that every role should use engineering docs directly; use escalation routing when the issue is platform-owned.
