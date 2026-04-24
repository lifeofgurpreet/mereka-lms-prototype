# Platform Start Here

Use this page when you need the fastest safe path into the Mereka LMS platform handbook.

This page is for platform-facing handbook navigation after role routing.
If you are inheriting the repo itself, use `docs/README.md`.
If you are planning an implementation or ownership change, use `docs/architecture/README.md`.

## Who This Is For

- Course teams who need the right Studio or learner URL and a short path to course creation.
- Tenant or program admins who need to understand what they can change per site.
- Platform operators who need the current topology and access references.
- Engineers who need to trace handbook guidance back to canonical machine-backed inputs.

This page is a role router for platform-facing handbook users. It is not a repo-inheritance guide and it is not a product-help manual for learners.
If a user-facing workflow needs screenshots, step-by-step UX help, or support copy, that belongs in a separate product-help lane with its own maintenance contract.
If you are inheriting the repo, changing platform behavior, or deciding where implementation work belongs, switch to [Docs Root](../../README.md) and [Architecture Root](../../architecture/README.md) instead of staying in the handbook lane.

## Start With The Generated References

- [Domain And Access Reference](../../reference/platform/DOMAIN_AND_ACCESS_REFERENCE.md)
- [Team Topology Reference](../../reference/platform/TEAM_TOPOLOGY_REFERENCE.md)

These two references carry the volatile facts. Do not copy URLs or topology claims out of them into ad hoc notes, and do not route around them with handbook prose when access or lane truth is unresolved.

## Role Chooser

- Course team: start with [Course Authoring Quickstart](COURSE_AUTHORING_QUICKSTART.md), then use [Content Libraries Authoring Guide](../../concepts/architecture/content-libraries-overview.md) when the workflow depends on reusable library content.
- Tenant or program admin: start with [Multi-Tenancy Explained](MULTI_TENANCY_EXPLAINED.md), then review [Open edX Settings Matrix](OPENEDX_SETTINGS_MATRIX.md) and [Content Libraries Enterprise Onboarding](../../ops/runbooks/CONTENT_LIBRARIES_V2_MIGRATION.md) if tenant-scoped shared content is in scope.
- Learner or support teammate: start with [Domain And Access Reference](../../reference/platform/DOMAIN_AND_ACCESS_REFERENCE.md) for the right learner URL, then use [Support And Escalation](SUPPORT_AND_ESCALATION.md) if the issue is platform-owned.
- Platform operator: start with [Domain And Access Reference](../../reference/platform/DOMAIN_AND_ACCESS_REFERENCE.md) and [Team Topology Reference](../../reference/platform/TEAM_TOPOLOGY_REFERENCE.md), then move to [ops quick reference](../../ops/quickref/README.md) for the shortest command path. Use [Support And Escalation](SUPPORT_AND_ESCALATION.md) only when the issue needs handbook-facing triage language.
- Engineer consuming handbook guidance: start with [Open edX For Team Members](OPENEDX_FOR_TEAM_MEMBERS.md).
- Handbook maintainer tracing source/authority inputs: use [Source Map](SOURCE_MAP.md) after the generated references.

## Use This URL Flow

1. Open [Domain And Access Reference](../../reference/platform/DOMAIN_AND_ACCESS_REFERENCE.md).
2. Pick the lane first: `dev`, `staging`, or `prod`.
3. Pick the tenant or site second.
4. Use the listed learner or Studio URL from that generated reference.
5. If a field is marked unresolved, escalate instead of guessing.

## Escalation Path

- Broken or missing URL in the generated reference: treat as a platform issue and include the lane, tenant, and expected surface.
- Tenant-specific behavior mismatch: check [Team Topology Reference](../../reference/platform/TEAM_TOPOLOGY_REFERENCE.md) first, then escalate if the generated topology still does not prove the behavior.
- Generic Open edX usage question: use the linked official docs before opening a platform escalation.

## Read Next

- [Open edX For Team Members](OPENEDX_FOR_TEAM_MEMBERS.md)
- [Course Authoring Quickstart](COURSE_AUTHORING_QUICKSTART.md)
- [Content Libraries Authoring Guide](../../concepts/architecture/content-libraries-overview.md)
- [Support And Escalation](SUPPORT_AND_ESCALATION.md)
- [Documentation Index by Audience](../INDEX_BY_AUDIENCE.md)

## Boundary Reminder

- Use this page to choose the right handbook or generated-reference path by role.
- Use [docs/README.md](../../README.md) when you are routing between canonical docs roots.
- Use [Architecture Root](../../architecture/README.md) when you are inheriting or extending the repo as a maintainer rather than consuming handbook guidance.

## Metadata

- Canonical internal sources: `docs/README.md`, `docs/guides/README.md`, `docs/guides/INDEX_BY_AUDIENCE.md`, `docs/reference/platform/DOMAIN_AND_ACCESS_REFERENCE.md`, `docs/reference/platform/TEAM_TOPOLOGY_REFERENCE.md`
- Official external references: `https://docs.openedx.org/en/latest/index.html`, `https://docs.tutor.edly.io/`
- Owner: Platform Team
- Last reviewed: 2026-04-09
- Applies to: teammates using Mereka LMS handbook surfaces across `dev`, `staging`, and `prod`
- What is tenant-specific: learner URLs, Studio URLs, tenant/domain mapping, branding expectations
- What is platform-wide: handbook routing rules, generated reference usage, escalation expectations
- What must be escalated: unresolved generated-reference fields, broken environment access, cross-tenant behavior that conflicts with the generated topology
