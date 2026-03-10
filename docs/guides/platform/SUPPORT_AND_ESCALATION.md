# Support And Escalation

Use this page to decide whether to self-serve with docs or escalate to the platform team.

## Use Docs First When

- you need the current URL or lane and can get it from [Domain And Access Reference](../../reference/platform/DOMAIN_AND_ACCESS_REFERENCE.md)
- you need to understand whether a surface is shared or tenant-specific and can get it from [Team Topology Reference](../../reference/platform/TEAM_TOPOLOGY_REFERENCE.md)
- you need generic Open edX authoring steps and an official doc already covers them

## Escalate When

- a generated reference field is unresolved
- a documented URL does not work in the lane you are using
- a course-team request actually requires site configuration, branding, or platform changes
- the current topology evidence conflicts across sources

## What Evidence To Include

Always include:

- lane: `dev`, `staging`, or `prod`
- tenant or site
- exact learner or Studio URL you tried
- whether the problem is authoring, login, branding, topology, or runtime
- the generated reference page and field that you used
- screenshots or error text if the problem is runtime-visible

## Course-Team Issue Versus Platform Issue

- course-team issue: content, outline, team membership inside an already-working course/site
- tenant-admin issue: site-scoped settings, organization filtering, tenant presentation changes
- platform issue: broken environment access, unresolved topology, missing runtime/service behavior, generated-reference mismatch

## Recommended Escalation Sequence

1. Verify the current lane and tenant in the generated references.
2. Check whether the issue is already explained in [Open edX Settings Matrix](OPENEDX_SETTINGS_MATRIX.md).
3. If still unresolved, escalate with the evidence list above.

## Metadata

- Canonical internal sources: `docs/reference/platform/DOMAIN_AND_ACCESS_REFERENCE.md`, `docs/reference/platform/TEAM_TOPOLOGY_REFERENCE.md`, `docs/ops/quickref/README.md`, `docs/ops/runbooks/README.md`
- Official external references: `https://docs.openedx.org/en/latest/index.html`, `https://docs.tutor.edly.io/`
- Owner: Platform Team
- Last reviewed: 2026-03-10
- Applies to: anyone reporting access, topology, or configuration issues in Mereka LMS
- What is tenant-specific: tenant-facing URLs, site configuration behavior, branding-specific breakage
- What is platform-wide: runtime outages, shared services, generated-reference mismatches, deployment and contract issues
- What must be escalated: unresolved reference fields, broken lane access, topology contradictions, and requests that require platform-owned changes
