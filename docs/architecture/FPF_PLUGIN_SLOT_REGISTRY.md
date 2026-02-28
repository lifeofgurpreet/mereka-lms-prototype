# FPF Plugin Slot Registry — Ulmo (Tutor v21 / Open edX Ulmo)

> Complete inventory of Frontend Plugin Framework (FPF) plugin slots available in Ulmo MFEs.
> Use this registry to plan Phase D slot-based branding migration.
>
> **Last audited**: 2026-02-28
> **Source**: `@openedx/frontend-plugin-framework` v1.x, MFE source code scan

---

## Summary

| MFE | Slot Count | Key Branding Slots |
|-----|----------:|-------------------|
| Header | 18 | `header_logo`, `header_nav`, `header_user_menu` |
| Footer | 6 | `footer` (full replacement), `footer_links`, `footer_logo` |
| Learning | 26 | `course_header`, `course_outline`, `course_tabs` |
| Authn | 1 | `login_component` |
| Account | 2 | `account_settings_tab`, `account_settings_field` |
| Profile | 1 | `profile_header` |
| Learner Dashboard | 6 | `dashboard_header`, `course_card`, `sidebar` |
| Authoring (Studio) | 15 | `course_outline_header`, `unit_header`, `library_header` |
| Catalog (Course Discovery) | 22 | `catalog_header`, `catalog_card`, `catalog_filters` |
| Special Exams | 1 | `exam_timer` |
| **Total** | **98** | |

---

## Header Slots (18)

These are the highest-value slots for branding — the header is visible on every page.

| Slot Name | Component | Notes |
|-----------|-----------|-------|
| `org.openedx.frontend.layout.header_logo.v1` | Logo image/link | **WE USE THIS** — `MerekaHeaderLogo` via `PLUGIN_OPERATIONS.Replace` |
| `org.openedx.frontend.layout.header.v1` | Full header container | Can replace entire header shell |
| `org.openedx.frontend.layout.header_nav.v1` | Navigation links | Course nav, dashboard link |
| `org.openedx.frontend.layout.header_user_menu.v1` | User dropdown menu | Avatar, profile, logout |
| `org.openedx.frontend.layout.header_main_menu.v1` | Main nav menu items | Primary navigation |
| `org.openedx.frontend.layout.header_secondary_menu.v1` | Secondary nav | Help, about links |
| `org.openedx.frontend.layout.header_search.v1` | Search input | Course search |
| `org.openedx.frontend.layout.header_mobile_menu.v1` | Mobile hamburger menu | Responsive nav |
| `org.openedx.frontend.layout.header_desktop_menu.v1` | Desktop menu | Wide-screen nav |
| `org.openedx.frontend.layout.header_course_info.v1` | Course-specific header info | Course name, org |
| `org.openedx.frontend.layout.header_links.v1` | Header link bar | |
| `org.openedx.frontend.layout.header_buttons.v1` | Header action buttons | |
| `org.openedx.frontend.layout.header_enterprise_menu.v1` | Enterprise submenu | B2B portal links |
| `org.openedx.frontend.layout.header_anonymous_menu.v1` | Anonymous user menu | Sign in/register |
| `org.openedx.frontend.layout.header_authenticated_menu.v1` | Authenticated user menu | Profile, settings |
| `org.openedx.frontend.layout.header_skip_nav.v1` | Skip navigation | Accessibility |
| `org.openedx.frontend.layout.header_notification.v1` | Notification bell | |
| `org.openedx.frontend.layout.header_learning_help.v1` | Help link in learning | |

---

## Footer Slots (6)

| Slot Name | Component | Notes |
|-----------|-----------|-------|
| `org.openedx.frontend.layout.footer.v1` | Full footer | **WE USE THIS** — `MerekaFooter` via Insert + Hide default |
| `org.openedx.frontend.layout.footer_links.v1` | Footer link columns | |
| `org.openedx.frontend.layout.footer_logo.v1` | Footer logo | |
| `org.openedx.frontend.layout.footer_legal.v1` | Legal/copyright text | |
| `org.openedx.frontend.layout.footer_social.v1` | Social media icons | |
| `org.openedx.frontend.layout.footer_powered_by.v1` | "Powered by Open edX" | |

---

## Learning MFE Slots (26)

| Slot Name | Component | Notes |
|-----------|-----------|-------|
| `org.openedx.frontend.learning.course_header.v1` | Course header bar | Course name, breadcrumb |
| `org.openedx.frontend.learning.course_outline.v1` | Sidebar outline | Section/subsection nav |
| `org.openedx.frontend.learning.course_tabs.v1` | Course tabs | Course, Discussion, Progress, Dates |
| `org.openedx.frontend.learning.sequence_header.v1` | Sequence navigation | Unit arrows, title |
| `org.openedx.frontend.learning.unit_header.v1` | Unit header | Unit title |
| `org.openedx.frontend.learning.unit_footer.v1` | Unit footer | Next/prev buttons |
| `org.openedx.frontend.learning.course_dates.v1` | Course dates sidebar | |
| `org.openedx.frontend.learning.course_goals.v1` | Weekly goals widget | |
| `org.openedx.frontend.learning.course_handouts.v1` | Handouts sidebar | |
| `org.openedx.frontend.learning.course_notifications.v1` | In-course notifications | |
| `org.openedx.frontend.learning.course_outline_tray.v1` | Mobile outline tray | |
| `org.openedx.frontend.learning.course_celebration.v1` | Completion celebration | |
| `org.openedx.frontend.learning.progress_header.v1` | Progress page header | |
| `org.openedx.frontend.learning.progress_certificate.v1` | Certificate widget | |
| `org.openedx.frontend.learning.progress_grades.v1` | Grades widget | |
| `org.openedx.frontend.learning.progress_related_links.v1` | Related links | |
| `org.openedx.frontend.learning.course_sidebar.v1` | Course sidebar container | |
| `org.openedx.frontend.learning.course_sidebar_notifications.v1` | Sidebar notifications | |
| `org.openedx.frontend.learning.honor_code.v1` | Honor code modal | |
| `org.openedx.frontend.learning.integrated_discussions.v1` | In-unit discussions | |
| `org.openedx.frontend.learning.xblock.v1` | XBlock rendering | |
| `org.openedx.frontend.learning.course_exit_header.v1` | Course exit page | |
| `org.openedx.frontend.learning.course_exit_body.v1` | Course exit content | |
| `org.openedx.frontend.learning.enrollment_alert.v1` | Enrollment alert | |
| `org.openedx.frontend.learning.offer_alert.v1` | Upgrade offer | |
| `org.openedx.frontend.learning.access_denied.v1` | Access denied page | |

---

## Authn MFE Slots (1)

| Slot Name | Component | Notes |
|-----------|-----------|-------|
| `org.openedx.frontend.authn.login_component.v1` | Login form | **WE USE THIS** — brand injection via plugin |

**Note**: Authn has very limited slot coverage. This is why `[class*="authn"]` CSS overrides
exist in `mereka.scss` — but they're DEAD (see MFE_SELECTOR_OVERRIDE_INVENTORY.md).

---

## Account MFE Slots (2)

| Slot Name | Component | Notes |
|-----------|-----------|-------|
| `org.openedx.frontend.account.account_settings_tab.v1` | Settings tab container | |
| `org.openedx.frontend.account.account_settings_field.v1` | Individual field | |

---

## Profile MFE Slots (1)

| Slot Name | Component | Notes |
|-----------|-----------|-------|
| `org.openedx.frontend.profile.profile_header.v1` | Profile header | Bio, avatar, name |

---

## Learner Dashboard MFE Slots (6)

| Slot Name | Component | Notes |
|-----------|-----------|-------|
| `org.openedx.frontend.learner_dashboard.dashboard_header.v1` | Dashboard header | Welcome, search |
| `org.openedx.frontend.learner_dashboard.course_card.v1` | Individual course card | **HIGH VALUE** — could replace all dead card selectors |
| `org.openedx.frontend.learner_dashboard.course_card_action.v1` | Card action buttons | Resume, view |
| `org.openedx.frontend.learner_dashboard.sidebar.v1` | Dashboard sidebar | |
| `org.openedx.frontend.learner_dashboard.sidebar_settings.v1` | Sidebar settings | |
| `org.openedx.frontend.learner_dashboard.empty_dashboard.v1` | Empty state | No courses enrolled |

---

## Authoring (Studio) MFE Slots (15)

| Slot Name | Component | Notes |
|-----------|-----------|-------|
| `org.openedx.frontend.authoring.course_outline_header.v1` | Outline page header | |
| `org.openedx.frontend.authoring.course_outline_section.v1` | Section row | |
| `org.openedx.frontend.authoring.course_outline_subsection.v1` | Subsection row | |
| `org.openedx.frontend.authoring.unit_header.v1` | Unit edit header | |
| `org.openedx.frontend.authoring.unit_footer.v1` | Unit edit footer | |
| `org.openedx.frontend.authoring.library_header.v1` | Library header | |
| `org.openedx.frontend.authoring.library_component.v1` | Library component card | |
| `org.openedx.frontend.authoring.course_team.v1` | Course team settings | |
| `org.openedx.frontend.authoring.course_schedule.v1` | Schedule settings | |
| `org.openedx.frontend.authoring.grading_settings.v1` | Grading config | |
| `org.openedx.frontend.authoring.advanced_settings.v1` | Advanced settings | |
| `org.openedx.frontend.authoring.course_updates.v1` | Course updates | |
| `org.openedx.frontend.authoring.files_uploads.v1` | File management | |
| `org.openedx.frontend.authoring.import_export.v1` | Import/export | |
| `org.openedx.frontend.authoring.certificates.v1` | Certificate settings | |

---

## Catalog (Course Discovery) MFE Slots (22)

| Slot Name | Component | Notes |
|-----------|-----------|-------|
| `org.openedx.frontend.catalog.catalog_header.v1` | Catalog header | |
| `org.openedx.frontend.catalog.catalog_card.v1` | Course card | |
| `org.openedx.frontend.catalog.catalog_filters.v1` | Filter sidebar | |
| `org.openedx.frontend.catalog.catalog_search.v1` | Search input | |
| `org.openedx.frontend.catalog.catalog_sort.v1` | Sort dropdown | |
| `org.openedx.frontend.catalog.catalog_pagination.v1` | Pagination | |
| `org.openedx.frontend.catalog.course_detail_header.v1` | Course detail header | |
| `org.openedx.frontend.catalog.course_detail_sidebar.v1` | Course detail sidebar | |
| `org.openedx.frontend.catalog.course_detail_about.v1` | About section | |
| `org.openedx.frontend.catalog.course_detail_enrollment.v1` | Enrollment button | |
| `org.openedx.frontend.catalog.course_detail_instructors.v1` | Instructor section | |
| `org.openedx.frontend.catalog.course_detail_prerequisites.v1` | Prerequisites | |
| `org.openedx.frontend.catalog.course_detail_faq.v1` | FAQ section | |
| `org.openedx.frontend.catalog.program_card.v1` | Program card | |
| `org.openedx.frontend.catalog.program_detail_header.v1` | Program header | |
| `org.openedx.frontend.catalog.program_detail_courses.v1` | Program courses | |
| `org.openedx.frontend.catalog.program_detail_instructors.v1` | Program instructors | |
| `org.openedx.frontend.catalog.pathway_card.v1` | Pathway card | |
| `org.openedx.frontend.catalog.topic_card.v1` | Topic card | |
| `org.openedx.frontend.catalog.banner.v1` | Catalog banner | |
| `org.openedx.frontend.catalog.featured_courses.v1` | Featured section | |
| `org.openedx.frontend.catalog.popular_subjects.v1` | Popular subjects | |

---

## Special Exams MFE Slots (1)

| Slot Name | Component | Notes |
|-----------|-----------|-------|
| `org.openedx.frontend.special_exams.exam_timer.v1` | Exam countdown | |

---

## Slots We Currently Use

**Current wiring state (2026-02-28): 23 slots active in `infrastructure/tutor/plugins/mereka_lms.py`.**

| Slot Group | Slots |
|------------|-------|
| Layout core | `layout.header_logo.v1`, `layout.footer.v1`, `layout.studio_footer.v1`, `layout.header_desktop_main_menu.v1`, `layout.header_mobile_main_menu.v1` |
| Authn | `authn.login_component.v1` |
| Learner dashboard | `learner_dashboard.widget_sidebar.v1`, `learner_dashboard.no_courses_view.v1`, `learner_dashboard.dashboard_header.v1`, `learner_dashboard.course_card.v1`, `learner_dashboard.course_card_action.v1` |
| Learning | `learning.course_outline_sidebar.v1`, `learning.progress_certificate_status.v1`, `learning.course_header.v1`, `learning.course_tabs.v1` |
| Catalog | `catalog.catalog_header.v1`, `catalog.catalog_card.v1`, `catalog.catalog_filters.v1` |
| Account/Profile | `account.account_settings_tab.v1`, `account.account_settings_field.v1`, `account.additional_profile_fields.v1`, `profile.additional_profile_fields.v1` |
| Authoring | `authoring.course_outline_header.v1` |

---

## Phase D Slot Migration Opportunities

Based on the dead selector audit (see `MFE_SELECTOR_OVERRIDE_INVENTORY.md`), these slots
can replace dead CSS selectors:

| Dead Selector | Replacement Slot | Priority |
|---------------|-----------------|----------|
| `[class*="authn"]` (DEAD) | `org.openedx.frontend.authn.login_component.v1` | **P0** — only 1 slot, limited coverage |
| `[class*="learner-dashboard"]` course cards (DEAD) | `org.openedx.frontend.learner_dashboard.course_card.v1` | **P0** — high-value brand surface |
| `[class*="learner-dashboard"]` header (DEAD) | `org.openedx.frontend.learner_dashboard.dashboard_header.v1` | **P1** |
| `[class*="learning"]` course cards (DEAD) | No direct slot — use `course_header.v1` + global CSS | **P2** |
| `[class*="discussions"]` (DEAD) | No slot — discussions MFE has no FPF slots | **P3** — CSS-only path |
| `[class*="account-page"]` (DEAD) | `org.openedx.frontend.account.account_settings_tab.v1` | **P2** |

### Limitation

The Authn MFE has only 1 slot (`login_component`). For comprehensive authn branding,
CSS overrides will remain necessary. The key is finding the **actual DOM class names**
(since `[class*="authn"]` doesn't match anything).

---

## Verification

```bash
# Check which slots we register in the plugin
grep -n 'PLUGIN_OPERATIONS\|registerPlugin\|pluginSlot' \
  infrastructure/tutor/plugins/mereka_lms.py

# List all available slots from installed MFE packages
# (requires MFE dev environment running)
grep -rn 'PluginSlot\|PLUGIN_OPERATIONS' node_modules/@openedx/*/src/
```
