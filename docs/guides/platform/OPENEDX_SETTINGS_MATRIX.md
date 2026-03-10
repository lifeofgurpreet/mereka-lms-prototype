# Open edX Settings Matrix

Use this matrix to decide which layer owns a change before anyone edits anything.

| Setting class | Who can change it | Where it lives | Tenant-specific or global | Approval needed | Examples | Official reference |
| --- | --- | --- | --- | --- | --- | --- |
| Course outline and content | Course team | Studio course authoring UI | Tenant-scoped by course | Course owner approval | sections, subsections, units, problems, handouts | `https://docs.openedx.org/en/release-teak/educators/quickstarts/build_a_course.html` |
| Course team membership | Course admin | Studio `Settings -> Course Team` | Tenant-scoped by site access | Course admin approval | add course creators, staff roles | `https://docs.openedx.org/en/open-release-palm.master/educators/how-tos/add_course_creators.html` |
| Course identifiers and schedule | Course admin with platform awareness | Studio at course creation and course settings | Tenant-scoped, learner-visible | Yes | Organization, Course Number, Course Run, pacing | `https://docs.openedx.org/en/latest/educators/how-tos/set_up_course/create_new_course.html` |
| Site configuration | Tenant admin or platform admin depending on ownership | Django admin Site Configuration plus platform governance | Tenant-specific override over global defaults | Yes | `course_org_filter`, `SITE_NAME`, per-site email/support settings | `https://docs.openedx.org/en/latest/site_ops/install_configure_run_guide/configuration/sites/configure_site.html` |
| Theme and branding configuration | Platform-admin workflow | tenant/site branding flows and platform-controlled assets | Tenant-specific presentation on shared platform | Yes | logos, palette, footer, site theme application | `https://docs.openedx.org/en/latest/site_ops/install_configure_run_guide/configuration/changing_appearance/theming/enable_themes.html`, `https://docs.openedx.org/en/latest/site_ops/install_configure_run_guide/configuration/changing_appearance/theming/create_theme.html` |
| Tutor runtime configuration | Platform operators and engineers | Tutor config, plugins, patches, infra overlays | Platform-wide unless explicitly scoped | Yes | runtime secrets, service enablement, deployment config | `https://docs.tutor.edly.io/local.html`, `https://docs.tutor.edly.io/tutorials/plugin.html`, `https://docs.tutor.edly.io/reference/api/hooks/catalog.html` |
| Release-control and service identity contracts | Platform engineering | platform-control-plane and cross-repo contract inputs | Platform-wide | Yes | service IDs, release lanes, evidence obligations | internal contracts only |
| Generated handbook/reference surfaces | No one by hand | generated outputs and their generators | Generated projection of tenant and platform truth | Always regenerate | domain access reference, team topology reference | internal generators only |

## Use This Matrix

- If the change is inside a course shell, it is usually a course-team action.
- If the change affects which courses or branding appear on a site, it is usually a tenant or platform-admin action.
- If the change affects runtime behavior, deployment, or shared services, it is a platform action.
- If the change touches generated references, edit the generator or canonical source, not the generated file.

## Metadata

- Canonical internal sources: `docs/guides/admin/MULTI_SITE_GUIDE.md`, `docs/reference/platform/TEAM_TOPOLOGY_REFERENCE.md`, `docs/reference/platform/DOMAIN_AND_ACCESS_REFERENCE.md`, `docs/ops/quickref/README.md`
- Official external references: `https://docs.openedx.org/en/latest/educators/how-tos/set_up_course/create_new_course.html`, `https://docs.openedx.org/en/latest/site_ops/install_configure_run_guide/configuration/sites/configure_site.html`, `https://docs.openedx.org/en/latest/site_ops/install_configure_run_guide/configuration/changing_appearance/theming/enable_themes.html`, `https://docs.tutor.edly.io/local.html`, `https://docs.tutor.edly.io/tutorials/plugin.html`, `https://docs.tutor.edly.io/reference/api/hooks/catalog.html`
- Owner: Platform Team
- Last reviewed: 2026-03-10
- Applies to: change triage for course teams, tenant admins, operators, and engineers
- What is tenant-specific: site configuration overrides, branding behavior, tenant-facing domains and course visibility rules
- What is platform-wide: Tutor runtime configuration, shared services, cross-repo contracts, generated references
- What must be escalated: anything that crosses ownership layers, affects shared services, or requires direct edits to generated surfaces
