# Content Libraries Authoring Guide

Use this guide when a course team or library author needs the current safe path
for creating, publishing, and reusing Content Libraries v2 material.

This guide complements, but does not replace:

- [COURSE_AUTHORING_QUICKSTART.md](COURSE_AUTHORING_QUICKSTART.md)
- [../../concepts/architecture/content-libraries-overview.md](../../concepts/architecture/content-libraries-overview.md)
- [../../ops/runbooks/CONTENT_LIBRARIES_V2_RUNBOOK.md](../../ops/runbooks/CONTENT_LIBRARIES_V2_RUNBOOK.md)
- [../../ops/runbooks/TROUBLESHOOTING.md](../../ops/runbooks/TROUBLESHOOTING.md)
- [../../../specs/content-libraries-v2_spec.md](../../../specs/content-libraries-v2_spec.md)

## Current Boundary

As of 2026-04-10:

- Content Libraries v2 is a real platform authoring surface.
- Libraries are Blockstore-backed and use draft/published lifecycle semantics.
- Course teams can reuse published library content across courses.
- Search, analytics, and bulk import remain companion or gated lanes; do not
  assume they are universally enabled in every environment.

Do not promise self-serve bulk import, tenant-to-tenant migration, or library
analytics dashboards as default author workflows unless the current lane has
explicit proof.

There is intentionally no separate self-serve bulk-operations guide today. The
author-facing boundary stays here, and the operator bulk-ops boundary stays in
[../../ops/runbooks/CONTENT_LIBRARIES_V2_RUNBOOK.md](../../ops/runbooks/CONTENT_LIBRARIES_V2_RUNBOOK.md)
until a real self-serve workflow exists.

## Before You Start

1. Use [COURSE_AUTHORING_QUICKSTART.md](COURSE_AUTHORING_QUICKSTART.md) to get
   into the correct Studio and course shell.
2. Confirm the tenant and Studio URL from
   [../../reference/platform/DOMAIN_AND_ACCESS_REFERENCE.md](../../reference/platform/DOMAIN_AND_ACCESS_REFERENCE.md).
3. Confirm whether the library should be:
   - course-team scoped
   - tenant-scoped reusable content
   - platform-shared reusable content
4. Confirm who will own authoring, publishing, and permission management.

## When To Use A Library

Use a content library when the same component or pattern should be maintained in
one place and reused across courses.

Typical good fits:

- shared assessment templates
- reusable HTML or policy blocks
- common tenant or program learning components
- content that will need controlled versioning over time

Do not use a library just to avoid creating a normal one-off course block.

## Create And Configure A Library

Before creating the library, decide:

- owning organization
- stable slug / library key pattern
- title and description
- whether the library should be tenant-private or intentionally shareable

Then:

1. Create the library in Studio / authoring flows.
2. Record the owning organization and intended audience.
3. Set the title and description so the reuse purpose is obvious.
4. Confirm the initial team assignments before authors start editing.

Treat library ownership as an approval decision, not something to improvise
after components already exist.

## Add And Edit Components

Current safe posture:

- create components in draft first
- keep component names and descriptions reusable, not course-specific
- verify the needed XBlock type is actually available before promising it to a
  course team

For advanced assessment content, use
[ADVANCED_ASSESSMENT_AUTHORING_GUIDE.md](ADVANCED_ASSESSMENT_AUTHORING_GUIDE.md)
for the lane boundary before embedding ORA2, timed exams, or other gated
assessment types into a shared library.

## Publish And Versioning

Draft and published state are different truths.

- draft state is author work in progress
- published state is the reusable version other courses can safely adopt

Before publishing:

- confirm the draft is the intended shared version
- confirm owners know which downstream courses may adopt it
- capture a short change summary if the update is material

Do not tell downstream course teams that a change is available until it is
published.

## Reuse Across Courses

Library content becomes meaningful to learners only after a course references or
syncs the published state.

Use this rule:

- publish in the library first
- then confirm the destination course references or syncs the published state

Do not confuse “draft saved” with “learner-visible.”

## Team And Permission Boundaries

Keep these roles distinct:

- Library Admin: full control, including permissions and lifecycle changes
- Library Author: can create and edit library content
- Library Reader / consumer: can view or reference content without changing it

Before launch, verify:

- the owning organization is correct
- stale users are not still attached
- tenant-scoped libraries are not visible outside the intended organization

## Search And Discovery

Search is helpful, but it is not the source of truth.

- if search finds a component, still verify the published library state
- if search does not find a component, that may be search-index lag rather than
  missing content

If search behavior is blocking work, use
[../../ops/runbooks/TROUBLESHOOTING.md](../../ops/runbooks/TROUBLESHOOTING.md)
instead of assuming the library is lost.

## Best Practices

- keep one clear reuse purpose per library
- keep ownership explicit
- publish intentionally, not continuously
- treat tenant-private and platform-shared libraries as different governance
  classes
- verify downstream course adoption after material library updates

## Escalate When

Escalate to platform operators when:

- the library is not visible in the expected Studio scope
- component rendering differs between library view and destination course
- publish operations fail or time out
- cross-tenant visibility looks wrong
- the workflow depends on bulk import, bulk migration, or analytics that are
  not explicitly enabled in the current lane

## Metadata

- Owner: Platform Team
- Last reviewed: 2026-04-10
- Applies to: course teams, content authors, and tenant content owners using
  Content Libraries v2
