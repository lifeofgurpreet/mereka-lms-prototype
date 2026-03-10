# Platform Start Here

Use this page when you need the fastest safe path into the Mereka LMS platform handbook.

## Who This Is For

- Course teams who need the right Studio or learner URL and a short path to course creation.
- Tenant or program admins who need to understand what they can change per site.
- Platform operators who need the current topology and access references.
- Engineers who need to trace handbook guidance back to canonical machine-backed inputs.

## Start With The Generated References

- [Domain And Access Reference](../../reference/platform/DOMAIN_AND_ACCESS_REFERENCE.md)
- [Team Topology Reference](../../reference/platform/TEAM_TOPOLOGY_REFERENCE.md)

These two references carry the volatile facts. Do not copy URLs or topology claims out of them into ad hoc notes.

## Role Chooser

- Course team: start with [Course Authoring Quickstart](COURSE_AUTHORING_QUICKSTART.md), then use the current Studio URL from the generated domain reference.
- Tenant or program admin: start with [Multi-Tenancy Explained](MULTI_TENANCY_EXPLAINED.md), then review [Open edX Settings Matrix](OPENEDX_SETTINGS_MATRIX.md).
- Platform operator: start with [Support And Escalation](SUPPORT_AND_ESCALATION.md), then use the generated references plus [ops quick reference](../../ops/quickref/README.md).
- Engineer: start with [Open edX For Team Members](OPENEDX_FOR_TEAM_MEMBERS.md), then read [Source Map](SOURCE_MAP.md).

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
- [Support And Escalation](SUPPORT_AND_ESCALATION.md)

## Metadata

- Canonical internal sources: `docs/README.md`, `docs/guides/README.md`, `docs/guides/INDEX_BY_AUDIENCE.md`, `docs/reference/platform/DOMAIN_AND_ACCESS_REFERENCE.md`, `docs/reference/platform/TEAM_TOPOLOGY_REFERENCE.md`
- Official external references: `https://docs.openedx.org/en/latest/index.html`, `https://docs.tutor.edly.io/`
- Owner: Platform Team
- Last reviewed: 2026-03-10
- Applies to: teammates using Mereka LMS handbook surfaces across `dev`, `staging`, and `prod`
- What is tenant-specific: learner URLs, Studio URLs, tenant/domain mapping, branding expectations
- What is platform-wide: handbook routing rules, generated reference usage, escalation expectations
- What must be escalated: unresolved generated-reference fields, broken environment access, cross-tenant behavior that conflicts with the generated topology
