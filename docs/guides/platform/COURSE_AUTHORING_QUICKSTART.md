# Course Authoring Quickstart

Use this page when you need to get from "I need a course" to "I am in the correct Studio and can start safely."

This page is for course-start and staffing flow.
It is not the authority for current URLs, tenant topology, or platform ownership boundaries; those stay in the generated references and the settings/extension guides.

## 1. Pick The Correct Studio URL

Do not guess the Studio hostname.

1. Open [Domain And Access Reference](../../reference/platform/DOMAIN_AND_ACCESS_REFERENCE.md).
2. Find the current lane and tenant.
3. Use the listed `Studio URL`.
4. If the Studio field is unresolved for your tenant, escalate before creating the course.

Do not fall back to older support docs or assume a tenant “just shares main Studio” unless the current generated access reference proves it.

## 2. Confirm Permissions First

Before course creation, confirm that:

- you can sign in to the correct Studio
- your user already exists on the site
- you have course-creator or equivalent admin rights for that site

If you can open Studio but cannot add team members or create courses, that is a platform-admin issue, not a course-outline issue.

## 3. Decide The Irreversible Identifiers Before Creation

Treat these values as approval-gated:

- Organization
- Course Number
- Course Run

They become part of the learner-visible course URL and cannot be changed later in normal Studio workflows. In this platform, they also interact with tenant-scoping and site configuration rules, so do not improvise naming late.

## 4. Create The Course

1. Sign in to the correct Studio.
2. Create the new course.
3. Enter the public course name.
4. Enter the Organization, Course Number, and Course Run carefully.
5. Create the course shell.

Then immediately record:

- which tenant or site owns the course
- which lane you are working in
- who should be on the course team

## 5. Add Course Team Members

1. Open the course in Studio.
2. Go to `Settings -> Course Team`.
3. Add users by email.
4. Only grant elevated roles where needed.

Users must already exist on the site before you can add them to the course team.

## 6. Go Next To Build Content

- official course build flow: Open edX quick start and Studio docs
- internal tenant/platform context: [Open edX For Team Members](OPENEDX_FOR_TEAM_MEMBERS.md)
- reusable content authoring:
  [Content Libraries Authoring Guide](../../concepts/architecture/content-libraries-overview.md)
- advanced assessment authoring boundary:
  [Advanced Assessment Authoring Guide](ADVANCED_ASSESSMENT_AUTHORING_GUIDE.md)
- settings ownership boundaries: [Open edX Settings Matrix](OPENEDX_SETTINGS_MATRIX.md)
- repo or platform implementation changes: [Docs Root](../../README.md) and [Architecture Root](../../architecture/README.md)

## 7. Escalate When

- the generated reference does not prove the correct Studio URL
- tenant ownership or organization filtering is unclear
- you need a platform-wide configuration change rather than a course-level change
- you need a new domain, theme, or site configuration rather than course content work

## Metadata

- Canonical internal sources: `docs/reference/platform/DOMAIN_AND_ACCESS_REFERENCE.md`, `docs/reference/platform/TEAM_TOPOLOGY_REFERENCE.md`, `docs/guides/admin/ADMIN_LOGIN_GUIDE.md`, `docs/reference/operations/OPENEDX_HOSTNAMES.md`
- Official external references: `https://docs.openedx.org/en/latest/educators/how-tos/set_up_course/create_new_course.html`, `https://docs.openedx.org/en/release-teak/educators/quickstarts/build_a_course.html`, `https://docs.openedx.org/en/open-release-palm.master/educators/how-tos/add_course_creators.html`
- Owner: Platform Team
- Last reviewed: 2026-04-09
- Applies to: course teams creating or staffing courses in Mereka LMS tenants
- What is tenant-specific: which Studio URL to use, which organization scope is valid for the tenant, which admins can approve access
- What is platform-wide: account provisioning, Studio availability, site configuration, domain routing
- What must be escalated: unresolved Studio URL, missing permissions, unclear organization scope, any request that needs site/domain/platform changes
