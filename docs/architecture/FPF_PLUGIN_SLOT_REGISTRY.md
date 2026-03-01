# FPF Plugin Slot Registry — Ulmo (Tutor v21 / Open edX Ulmo)

> Complete inventory of Frontend Plugin Framework (FPF) plugin slots available in Ulmo MFEs.
> Use this registry to plan Phase D slot-based branding migration.
>
> **Last audited**: 2026-02-28
> **Source**: `@openedx/frontend-plugin-framework` v1.x, MFE source code scan
>
> **Validation note (2026-02-28)**: Active slot wiring in `mereka_lms.py` is now constrained to slot IDs confirmed in local Ulmo MFE source checkouts under `tutor_env/dev/frontend-app-*` and `frontend-component-header` (layout/header slots). Legacy IDs retired from wiring: `learning.course_header.v1`, `learning.course_tabs.v1`, `account.account_settings_tab.v1`, `account.account_settings_field.v1`, `authoring.course_outline_header.v1`.

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
| Learner Dashboard | 6 | `course_list`, `course_card_banner`, `widget_sidebar` |
| Authoring (Studio) | 15 | `course_outline_sidebar`, `course_outline_header_actions`, `course_unit_header_actions`, `course_outline_page_alerts` |
| Catalog (Course Discovery) | 22 (legacy inventory) | `catalog_header`, `catalog_card`, `catalog_filters`, `catalog_search`, `catalog_sort`, `catalog_pagination` |
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
| `org.openedx.frontend.learner_dashboard.course_card_action.v1` | Course card action controls | Resume, view |
| `org.openedx.frontend.learner_dashboard.course_card_banner.v1` | Course card banner | Course-level banner surface |
| `org.openedx.frontend.learner_dashboard.course_list.v1` | Course list container | Primary post-login learner surface |
| `org.openedx.frontend.learner_dashboard.dashboard_modal.v1` | Dashboard modal | Global modal surface |
| `org.openedx.frontend.learner_dashboard.no_courses_view.v1` | Empty state | No courses enrolled |
| `org.openedx.frontend.learner_dashboard.widget_sidebar.v1` | Sidebar widgets | Right-rail widget surface |

---

## Authoring (Studio) MFE Slots (15)

| Slot Name | Component | Notes |
|-----------|-----------|-------|
| `org.openedx.frontend.authoring.additional_course_content_plugin.v1` | Additional course content plugin | |
| `org.openedx.frontend.authoring.additional_course_plugin.v1` | Additional course plugin | |
| `org.openedx.frontend.authoring.course_outline_header_actions.v1` | Outline header action area | |
| `org.openedx.frontend.authoring.course_outline_page_alerts.v1` | Outline page alerts | |
| `org.openedx.frontend.authoring.course_outline_sidebar.v1` | Outline sidebar | |
| `org.openedx.frontend.authoring.course_outline_subsection_card_extra_actions.v1` | Subsection card extra actions | |
| `org.openedx.frontend.authoring.course_outline_unit_card_extra_actions.v1` | Unit card extra actions | |
| `org.openedx.frontend.authoring.course_unit_header_actions.v1` | Unit header action area | |
| `org.openedx.frontend.authoring.course_unit_sidebar.v1` | Unit sidebar (v1) | |
| `org.openedx.frontend.authoring.course_unit_sidebar.v2` | Unit sidebar (v2) | Successor slot for newer unit experience |
| `org.openedx.frontend.authoring.edit_file_alerts.v1` | File editor alerts | |
| `org.openedx.frontend.authoring.edit_video_alerts.v1` | Video editor alerts | |
| `org.openedx.frontend.authoring.files_upload_page_table.v1` | Files upload table | |
| `org.openedx.frontend.authoring.video_transcript_additional_translations_component.v1` | Transcript translations component | |
| `org.openedx.frontend.authoring.videos_upload_page_table.v1` | Videos upload table | |

---

## Catalog (Course Discovery) MFE Slots (22)

> **Source-of-truth note (2026-03-01):** `frontend-app-catalog@release/ulmo` source scan currently exposes `org.openedx.frontend.layout.footer.v1` only. The catalog namespace list below is retained as legacy inventory reference and is intentionally not wired in `mereka_lms.py`.

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

**Current wiring state (2026-03-01): 64 slots active in `infrastructure/tutor/plugins/mereka_lms.py`.**

| Slot Group | Slots |
|------------|-------|
| Layout core | `layout.header_logo.v1`, `layout.footer.v1`, `layout.studio_footer.v1`, `layout.header_desktop_main_menu.v1`, `layout.header_mobile_main_menu.v1`, `layout.header_desktop_logged_out_items.v1`, `layout.header_mobile_logged_out_items.v1`, `layout.header_desktop_secondary_menu.v1`, `layout.header_learning_help.v1`, `layout.header_learning_logged_out_items.v1` |
| Authn | `authn.login_component.v1` |
| Learner dashboard | `learner_dashboard.widget_sidebar.v1`, `learner_dashboard.no_courses_view.v1`, `learner_dashboard.course_list.v1`, `learner_dashboard.course_card_banner.v1`, `learner_dashboard.course_card_action.v1`, `learner_dashboard.dashboard_modal.v1` |
| Learning | `learning.course_outline_sidebar.v1`, `learning.progress_certificate_status.v1`, `layout.header_learning.v1`, `learning.course_tab_links.v1`, `learning.course_breadcrumbs.v1`, `learning.learner_tools.v1`, `learning.progress_tab_course_grade.v1`, `learning.progress_tab_related_links.v1`, `learning.progress_tab_certificate_status_main_body.v1`, `learning.progress_tab_certificate_status_side_panel.v1`, `learning.progress_tab_grade_breakdown.v1`, `learning.unit_title.v1`, `learning.sequence_navigation.v1`, `learning.course_outline_sidebar_trigger.v1`, `learning.course_outline_mobile_sidebar_trigger.v1`, `learning.course_home_section_outline.v1`, `learning.course_recommendations.v1`, `learning.content_iframe_loader.v1`, `learning.content_iframe_error.v1`, `learning.sequence_container.v1`, `learning.gated_unit_content_message.v1`, `learning.next_unit_top_nav_trigger.v1`, `learning.course_outline_tab_notifications.v1`, `learning.notification_widget.v1`, `learning.notification_tray.v1`, `learning.notifications_discussions_sidebar_trigger.v1`, `learning.notifications_discussions_sidebar.v1`, `learning.course_exit_view_courses.v1`, `learning.course_exit_dashboard_footnote_link.v1` |
| Catalog | none (`frontend-app-catalog@release/ulmo` currently exposes only `layout.footer.v1`) |
| Account/Profile | `account.id_verification_page.v1`, `account.additional_profile_fields.v1`, `profile.additional_profile_fields.v1` |
| Authoring | `authoring.course_unit_sidebar.v1`, `authoring.course_unit_sidebar.v2`, `authoring.course_outline_sidebar.v1`, `authoring.course_outline_header_actions.v1`, `authoring.course_outline_page_alerts.v1`, `authoring.course_outline_subsection_card_extra_actions.v1`, `authoring.course_outline_unit_card_extra_actions.v1`, `authoring.additional_course_plugin.v1`, `authoring.additional_course_content_plugin.v1`, `authoring.edit_video_alerts.v1`, `authoring.edit_file_alerts.v1`, `authoring.files_upload_page_table.v1`, `authoring.videos_upload_page_table.v1`, `authoring.video_transcript_additional_translations_component.v1`, `authoring.course_unit_header_actions.v1` |

---

## Phase D Slot Migration Opportunities

Based on the dead selector audit (see `MFE_SELECTOR_OVERRIDE_INVENTORY.md`), these slots
can replace dead CSS selectors:

| Dead Selector | Replacement Slot | Priority |
|---------------|-----------------|----------|
| `[class*="authn"]` (DEAD) | `org.openedx.frontend.authn.login_component.v1` | **P0** — only 1 slot, limited coverage |
| `[class*="learner-dashboard"]` course cards (DEAD) | `org.openedx.frontend.learner_dashboard.course_card_banner.v1` | **P0** — high-value brand surface |
| `[class*="learner-dashboard"]` header/list shell (DEAD) | `org.openedx.frontend.learner_dashboard.course_list.v1` | **P1** |
| `[class*="learning"]` course cards (DEAD) | Use `org.openedx.frontend.layout.header_learning.v1` + `org.openedx.frontend.learning.course_tab_links.v1` + global CSS | **P2** |
| `[class*="discussions"]` (DEAD) | No slot — discussions MFE has no FPF slots | **P3** — CSS-only path |
| `[class*="account-page"]` (DEAD) | `org.openedx.frontend.account.id_verification_page.v1` + `org.openedx.frontend.account.additional_profile_fields.v1` | **P2** |

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
