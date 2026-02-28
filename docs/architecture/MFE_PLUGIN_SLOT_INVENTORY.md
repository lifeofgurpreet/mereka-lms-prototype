# MFE Plugin-Slot Inventory & Migration Map

**Purpose**: Comprehensive inventory of all FPF (Frontend Plugin Framework) plugin slots available in Open edX Tutor 21 (Ulmo), with Mereka Academy's current wiring status and migration roadmap.
**Last verified**: 2026-02-28
**Related**: [ADR-014: MFE Branding Strategy](../adr/014-mfe-branding-strategy.md), [OEP-65: FPF](https://open-edx-proposals.readthedocs.io/en/latest/architectural-decisions/oep-0065-frontend-plugin-framework.html), [mfe-plugin-slots_spec.md](../../specs/mfe-plugin-slots_spec.md)

---

## How Plugin Slots Work

Plugin slots are named extension points in MFE React components. Operators inject custom components via `env.config.jsx` using three operations:

| Operation | Effect |
|-----------|--------|
| `PLUGIN_OPERATIONS.Insert` | Add widget before/after default content |
| `PLUGIN_OPERATIONS.Replace` | Replace default content entirely |
| `PLUGIN_OPERATIONS.Hide` | Hide default content |

**Wiring path**: `mereka_lms.py` → Tutor hook → `env.config.jsx` → MFE runtime

---

## Mereka Wiring Status Summary

| Status | Count | Meaning |
|--------|-------|---------|
| ACTIVE | 12 | They override or extend default components |
| INDIGO | 3 | Indigo theme wires it; we inherit |
| AVAILABLE | 100+ | Slot exists upstream; not wired |

---

## 1. Slots We Override (ACTIVE)

### `org.openedx.frontend.layout.header_logo.v1` — Header Logo

| Property | Value |
|----------|-------|
| **Scope** | Shared header shell (`frontend-component-header`) |
| **Our component** | `MerekaHeaderLogo` |
| **Wiring mechanism** | `tutormfe.hooks.PLUGIN_SLOTS` registration in `mereka_lms.py` |
| **Forward-compat** | Keeps override stable while inheriting Indigo header structure |
| **Operation** | `PLUGIN_OPERATIONS.Replace` |
| **Verification** | `scripts/qa/verify-plugin-slot-wiring.sh` |
| **Key files** | `infrastructure/tutor/plugins/mereka_lms.py` |

### `org.openedx.frontend.layout.footer.v1` — Footer

| Property | Value |
|----------|-------|
| **Scope** | All MFEs (shared `frontend-component-footer`) |
| **Our component** | `MerekaFooter` |
| **Wiring mechanism** | `tutormfe.hooks.PLUGIN_SLOTS` registration in `mereka_lms.py` |
| **Forward-compat** | `PLUGIN_SLOTS.add_items` registration in `mereka_lms.py` (active on Tutor 21+/Ulmo) |
| **Operation** | `PLUGIN_OPERATIONS.Hide` + `PLUGIN_OPERATIONS.Insert` |
| **Verification** | `scripts/qa/verify-mfe-footer-slot.sh` (16 PASS) |
| **Key files** | `infrastructure/tutor/plugins/mereka_lms.py:760-840` |

### `org.openedx.frontend.layout.header_desktop_main_menu.v1` — Desktop Main Menu

| Property | Value |
|----------|-------|
| **Scope** | Shared header shell (`frontend-component-header`) |
| **Our behavior** | Append branded links while preserving defaults |
| **Wiring mechanism** | `tutormfe.hooks.PLUGIN_SLOTS` registration in `mereka_lms.py` |
| **Forward-compat** | Uses `PLUGIN_OPERATIONS.Modify` on `default_contents` to merge links |
| **Operation** | `PLUGIN_OPERATIONS.Modify` |
| **Verification** | `scripts/qa/verify-plugin-slot-wiring.sh` |
| **Key files** | `infrastructure/tutor/plugins/mereka_lms.py` |

### `org.openedx.frontend.layout.header_mobile_main_menu.v1` — Mobile Main Menu

| Property | Value |
|----------|-------|
| **Scope** | Shared header shell (`frontend-component-header`) |
| **Our behavior** | Append branded links while preserving defaults |
| **Wiring mechanism** | `tutormfe.hooks.PLUGIN_SLOTS` registration in `mereka_lms.py` |
| **Forward-compat** | Uses `PLUGIN_OPERATIONS.Modify` on `default_contents` to merge links |
| **Operation** | `PLUGIN_OPERATIONS.Modify` |
| **Verification** | `scripts/qa/verify-plugin-slot-wiring.sh` |
| **Key files** | `infrastructure/tutor/plugins/mereka_lms.py` |

### `org.openedx.frontend.learner_dashboard.widget_sidebar.v1` — Learner Sidebar Widget

| Property | Value |
|----------|-------|
| **Scope** | Learner dashboard sidebar |
| **Our component** | `MerekaLearnerSidebarWidget` |
| **Wiring mechanism** | `tutormfe.hooks.PLUGIN_SLOTS` registration in `mereka_lms.py` |
| **Operation** | `PLUGIN_OPERATIONS.Insert` |
| **Verification** | `scripts/qa/verify-plugin-slot-wiring.sh` |
| **Key files** | `infrastructure/tutor/plugins/mereka_lms.py` |

### `org.openedx.frontend.learner_dashboard.no_courses_view.v1` — Learner Empty-State View

| Property | Value |
|----------|-------|
| **Scope** | Learner dashboard no-courses route |
| **Our component** | `MerekaNoCoursesView` |
| **Wiring mechanism** | `tutormfe.hooks.PLUGIN_SLOTS` registration in `mereka_lms.py` |
| **Operation** | `PLUGIN_OPERATIONS.Replace` |
| **Verification** | `scripts/qa/verify-plugin-slot-wiring.sh` |
| **Key files** | `infrastructure/tutor/plugins/mereka_lms.py` |

### `org.openedx.frontend.learning.course_outline_sidebar.v1` — Learning Sidebar Slot

| Property | Value |
|----------|-------|
| **Scope** | Learning sidebar panel |
| **Our component** | `MerekaCourseOutlineSidebar` |
| **Wiring mechanism** | `tutormfe.hooks.PLUGIN_SLOTS` registration in `mereka_lms.py` |
| **Operation** | `PLUGIN_OPERATIONS.Insert` |
| **Verification** | `scripts/qa/verify-plugin-slot-wiring.sh` |
| **Key files** | `infrastructure/tutor/plugins/mereka_lms.py` |

### `org.openedx.frontend.learning.progress_certificate_status.v1` — Learning Certificate Progress Slot

| Property | Value |
|----------|-------|
| **Scope** | Learning progress + certificate display |
| **Our component** | `MerekaProgressCertificateStatus` |
| **Wiring mechanism** | `tutormfe.hooks.PLUGIN_SLOTS` registration in `mereka_lms.py` |
| **Operation** | `PLUGIN_OPERATIONS.Insert` |
| **Verification** | `scripts/qa/verify-plugin-slot-wiring.sh` |
| **Key files** | `infrastructure/tutor/plugins/mereka_lms.py` |

### `org.openedx.frontend.account.additional_profile_fields.v1` — Account Profile Fields

| Property | Value |
|----------|-------|
| **Scope** | Account profile UI |
| **Our component** | `MerekaAdditionalProfileFields` |
| **Wiring mechanism** | `tutormfe.hooks.PLUGIN_SLOTS` registration in `mereka_lms.py` |
| **Operation** | `PLUGIN_OPERATIONS.Insert` |
| **Verification** | `scripts/qa/verify-plugin-slot-wiring.sh` |
| **Key files** | `infrastructure/tutor/plugins/mereka_lms.py` |

### `org.openedx.frontend.profile.additional_profile_fields.v1` — Profile Additional Fields

| Property | Value |
|----------|-------|
| **Scope** | Profile page |
| **Our component** | `MerekaAdditionalProfileFields` |
| **Wiring mechanism** | `tutormfe.hooks.PLUGIN_SLOTS` registration in `mereka_lms.py` |
| **Operation** | `PLUGIN_OPERATIONS.Insert` |
| **Verification** | `scripts/qa/verify-plugin-slot-wiring.sh` |
| **Key files** | `infrastructure/tutor/plugins/mereka_lms.py` |

### `org.openedx.frontend.layout.studio_footer.v1` — Studio Footer

| Property | Value |
|----------|-------|
| **Scope** | Studio footer |
| **Our component** | `MerekaStudioFooter` |
| **Wiring mechanism** | `tutormfe.hooks.PLUGIN_SLOTS` registration in `mereka_lms.py` |
| **Operation** | `PLUGIN_OPERATIONS.Insert` |
| **Verification** | `scripts/qa/verify-plugin-slot-wiring.sh` |
| **Key files** | `infrastructure/tutor/plugins/mereka_lms.py` |

### `org.openedx.frontend.authn.login_component.v1` — Authn Login Banner

| Property | Value |
|----------|-------|
| **Scope** | Authn login page |
| **Our component** | `MerekaAuthnLoginBranding` |
| **Wiring mechanism** | `tutormfe.hooks.PLUGIN_SLOTS` registration in `mereka_lms.py` |
| **Operation** | `PLUGIN_OPERATIONS.Insert` |
| **Verification** | `scripts/qa/verify-plugin-slot-wiring.sh` |
| **Key files** | `infrastructure/tutor/plugins/mereka_lms.py` |

---

## 2. Slots Wired by Indigo (Inherited)

These slots are configured by the Indigo theme in the generated `env.config.jsx`. We inherit them without overriding.

### `desktop_secondary_menu_slot`
- **Scope**: account, discussions, learner-dashboard, profile
- **Indigo wires**: `ToggleThemeButton` (dark mode toggle)
- **Mereka status**: Inherited as-is

### `mobile_header_slot`
- **Scope**: account, discussions, learner-dashboard, profile
- **Indigo wires**: `MobileViewHeader` with theme toggle
- **Mereka status**: Inherited as-is

### `learning_help_slot`
- **Scope**: frontend-app-learning only
- **Indigo wires**: `ToggleThemeButton`
- **Mereka status**: Inherited as-is
- **Note**: ADR-014 listed this as `learning_help_sidebar_slot` — actual runtime ID is `learning_help_slot`

---

## 3. Complete Upstream Slot Inventory

### Header Component (`frontend-component-header`) — 18 slots

| Slot ID | Controls |
|---------|----------|
| `org.openedx.frontend.layout.header_logo.v1` | Logo image in header |
| `org.openedx.frontend.layout.header_desktop.v1` | Entire desktop header |
| `org.openedx.frontend.layout.header_desktop_logged_out_items.v1` | Sign in/register links |
| `org.openedx.frontend.layout.header_desktop_main_menu.v1` | Primary navigation menu |
| `org.openedx.frontend.layout.header_desktop_secondary_menu.v1` | Secondary menu area |
| `org.openedx.frontend.layout.header_desktop_user_menu.v1` | User dropdown menu |
| `org.openedx.frontend.layout.header_desktop_user_menu_toggle.v1` | User menu trigger button |
| `org.openedx.frontend.layout.header_learning_course_info.v1` | Course info in learning header |
| `org.openedx.frontend.layout.header_learning_help.v1` | Help button in learning header |
| `org.openedx.frontend.layout.header_learning_logged_out_items.v1` | Logged-out items in learning |
| `org.openedx.frontend.layout.header_learning_user_menu.v1` | User menu in learning header |
| `org.openedx.frontend.layout.header_learning_user_menu_toggle.v1` | User menu toggle in learning |
| `org.openedx.frontend.layout.header_mobile.v1` | Entire mobile header |
| `org.openedx.frontend.layout.header_mobile_logged_out_items.v1` | Mobile logged-out items |
| `org.openedx.frontend.layout.header_mobile_main_menu.v1` | Mobile navigation menu |
| `org.openedx.frontend.layout.header_mobile_user_menu.v1` | Mobile user menu |
| `org.openedx.frontend.layout.header_mobile_user_menu_trigger.v1` | Mobile user menu trigger |
| `org.openedx.frontend.layout.studio_header_search_button_slot.v1` | Studio search button |

### Footer Component (`frontend-component-footer`) — 6 slots

| Slot ID | Controls |
|---------|----------|
| `org.openedx.frontend.layout.footer.v1` | Main site footer (**ACTIVE — MerekaFooter**) |
| `org.openedx.frontend.layout.studio_footer.v1` | Studio footer |
| `org.openedx.frontend.layout.studio_footer_help_button.v1` | Studio help button |
| `org.openedx.frontend.layout.studio_footer_help-content.v1` | Studio help content |
| `org.openedx.frontend.layout.studio_footer_help_section.v1` | Studio help section |
| `org.openedx.frontend.layout.studio_footer_logo.v1` | Studio footer logo |

### Learning MFE (`frontend-app-learning`) — 28 slots

| Slot ID | Controls |
|---------|----------|
| `ContentIFrameErrorSlot` | Error display for content iframes |
| `ContentIFrameLoaderSlot` | Loading indicator for content iframes |
| `CourseBreadcrumbsSlot` | Courseware top-navigation breadcrumbs |
| `CourseExitPluginSlots` | Course exit/completion area |
| `CourseHomeSectionOutlineSlot` | Course home section outline |
| `CourseOutlineMobileSidebarTriggerSlot` | Mobile sidebar trigger |
| `CourseOutlineSidebarSlot` | Course outline sidebar |
| `CourseOutlineSidebarTriggerSlot` | Sidebar trigger button |
| `CourseOutlineTabNotificationsSlot` | Outline tab notification area |
| `CourseTabLinksSlot` | Course tab navigation links |
| `FooterSlot` | Footer (shared, = `org.openedx.frontend.layout.footer.v1`) |
| `GatedUnitContentMessageSlot` | Gated content message |
| `HeaderSlot` | Header (shared) |
| `LearnerToolsSlot` | Learner tools panel |
| `NextUnitTopNavTriggerSlot` | Next unit navigation trigger |
| `NotificationTraySlot` | Notification tray |
| `NotificationWidgetSlot` | Notification widget |
| `NotificationsDiscussionsSidebarSlot` | Discussions sidebar |
| `NotificationsDiscussionsSidebarTriggerSlot` | Discussions sidebar trigger |
| `ProgressCertificateStatusSlot` | Certificate status on progress page |
| `ProgressTabCertificateStatusMainBodySlot` | Certificate main body |
| `ProgressTabCertificateStatusSidePanelSlot` | Certificate side panel |
| `ProgressTabCourseGradeSlot` | Course grade display |
| `ProgressTabGradeBreakdownSlot` | Grade breakdown details |
| `ProgressTabRelatedLinksSlot` | Related links on progress page |
| `SequenceContainerSlot` | Unit sequence container |
| `SequenceNavigationSlot` | Sequence navigation bar |
| `UnitTitleSlot` | Unit title display |

### Authn MFE (`frontend-app-authn`) — 1 slot

| Slot ID | Controls |
|---------|----------|
| `org.openedx.frontend.authn.login_component.v1` | Entire login page component |

### Account MFE (`frontend-app-account`) — 3 slots

| Slot ID | Controls |
|---------|----------|
| `org.openedx.frontend.account.additional_profile_fields.v1` | Extra profile fields |
| `org.openedx.frontend.account.id_verification_page.v1` | ID verification page |
| `FooterSlot` | Footer (shared) |

### Authoring MFE (`frontend-app-authoring`) — 16 slots

| Slot ID | Controls |
|---------|----------|
| `AdditionalCourseContentPluginSlot` | Extra course content area |
| `AdditionalCoursePluginSlot` | Extra card in pages & resources |
| `AdditionalTranslationsComponentSlot` | Video transcription settings |
| `CourseAuthoringOutlineSidebarSlot` | Course outline sidebar |
| `CourseAuthoringUnitSidebarSlot` | Unit editor sidebar |
| `CourseFilesSlot` | Course files management |
| `CourseOutlineHeaderActionsSlot` | Outline page header actions |
| `CourseOutlinePageAlertsSlot` | Outline page alerts |
| `CourseOutlineSubsectionCardExtraActionsSlot` | Subsection card actions |
| `CourseOutlineUnitCardExtraActionsSlot` | Unit card actions |
| `CourseUnitHeaderActionsSlot` | Unit editor header actions |
| `CourseVideosSlot` | Course videos management |
| `EditFileAlertsSlot` | File edit alerts |
| `EditVideoAlertsSlot` | Video edit alerts |
| `PageBannerSlot` | Page-level banner |
| `StudioFooterSlot` | Studio footer (shared) |

### Learner Dashboard MFE (`frontend-app-learner-dashboard`) — 7 slots

| Slot ID | Controls |
|---------|----------|
| `org.openedx.frontend.learner_dashboard.course_card_action.v1` | Course card action buttons |
| `org.openedx.frontend.learner_dashboard.course_list.v1` | Course list component |
| `org.openedx.frontend.learner_dashboard.no_courses_view.v1` | Empty state (no courses) |
| `org.openedx.frontend.learner_dashboard.dashboard_modal.v1` | Dashboard modal |
| `org.openedx.frontend.learner_dashboard.widget_sidebar.v1` | Sidebar widgets |
| `CourseBannerSlot` | Course card banner |
| `FooterSlot` | Footer (shared) |

### Profile MFE (`frontend-app-profile`) — 2 slots

| Slot ID | Controls |
|---------|----------|
| `AdditionalProfileFieldsSlot` | Extra profile fields |
| `FooterSlot` | Footer (shared) |

### Discussions MFE (`frontend-app-discussions`) — 1 slot

| Slot ID | Controls |
|---------|----------|
| `FooterSlot` | Footer (shared) |

### Communications MFE (`frontend-app-communications`) — 1 slot

| Slot ID | Controls |
|---------|----------|
| `FooterSlot` | Footer (shared) |

### Gradebook MFE (`frontend-app-gradebook`) — 1 slot

| Slot ID | Controls |
|---------|----------|
| `FooterSlot` | Footer (shared) |

### ORA Grading MFE (`frontend-app-ora-grading`) — 1 slot

| Slot ID | Controls |
|---------|----------|
| `FooterSlot` | Footer (shared) |

### Special Exams Library (`frontend-lib-special-exams`) — 1 slot

| Slot ID | Controls |
|---------|----------|
| `org.openedx.frontend.special_exams.submitted_timed_exam_instructions.v1` | Post-submission instructions |

### Catalog MFE (`frontend-app-catalog`) — 19 slots

| Slot ID | Controls |
|---------|----------|
| `CourseAboutCourseImageSlot` | Course about page image |
| `CourseAboutCourseMediaSlot` | Course about page media |
| `CourseAboutEnrollmentButtonSlot` | Enrollment button |
| `CourseAboutIntroSlot` | Course introduction section |
| `CourseAboutIntroVideoSlots` | Intro video area |
| `CourseAboutOverviewSlot` | Course overview section |
| `CourseAboutSidebarCoursePriceSlot` | Price in sidebar |
| `CourseAboutSidebarSlot` | Course about sidebar |
| `CourseAboutSidebarSocialSlot` | Social sharing in sidebar |
| `CourseCatalogDataTableSlots` | Catalog data table |
| `CourseCatalogIntroSlot` | Catalog intro section |
| `CourseCatalogSearchFieldSlot` | Catalog search field |
| `FooterSlot` | Footer (shared) |
| `HomeBannerSlot` | Home page banner |
| `HomeCourseCardSlot` | Home page course cards |
| `HomeCoursesListSlot` | Home page course list |
| `HomeOverlayHtmlSlot` | Home page overlay HTML |
| `HomePromoVideoSlots` | Home page promo videos |
| `LoaderSlot` | Loading indicator |

---

## 4. Migration Map — What Mereka Should Wire Next

### Priority 1: High-Impact Branding (recommended for qp0k)

| Slot | MFE | Why | Effort |
|------|-----|-----|--------|
| `org.openedx.frontend.layout.header_logo.v1` | Header (all MFEs) | Replace Open edX logo with Mereka logo globally | ✅ Completed |
| `org.openedx.frontend.layout.studio_footer.v1` | Footer (Studio) | Extend MerekaFooter to Studio authoring | ✅ Completed |
| `org.openedx.frontend.authn.login_component.v1` | Authn | Add Mereka branding banner to login page | ✅ Completed |

### Priority 2: Learner Experience Enhancement

| Slot | MFE | Why | Effort |
|------|-----|-----|-----|
| `org.openedx.frontend.learner_dashboard.widget_sidebar.v1` | Learner Dashboard | Custom sidebar widgets (announcements, progress) | ✅ Completed |
| `org.openedx.frontend.learner_dashboard.no_courses_view.v1` | Learner Dashboard | Branded empty state with course recommendations | ✅ Completed |
| `org.openedx.frontend.learning.progress_certificate_status.v1` | Learning | Custom certificate display with Mereka branding | ✅ Completed |

### Priority 3: Studio Customization (operator-facing)

| Slot | MFE | Why | Effort |
|------|-----|-----|--------|
| `CourseOutlineHeaderActionsSlot` | Authoring | Custom outline actions | Medium |
| `PageBannerSlot` | Authoring | Operator notifications/banners | Low |

### Not Recommended (low ROI for Mereka)

- `SequenceContainerSlot` / `SequenceNavigationSlot` — Core learning UX, high risk of regressions
- `CourseCatalogDataTableSlots` — Catalog MFE not deployed
- `AdditionalTranslationsComponentSlot` — No current i18n requirements

---

## 5. Slot Name Conventions

Two naming conventions exist in the codebase:

| Convention | Example | Where Used |
|-----------|---------|------------|
| **Namespaced** (official) | `org.openedx.frontend.layout.footer.v1` | Source code `<PluginSlot id="...">`, `env.config.jsx` |
| **Shorthand** | `footer_slot` | `tutormfe.hooks.PLUGIN_SLOTS`, Indigo `env.config.jsx` |

**Rule**: Always use the **namespaced ID** in `env.config.jsx` pluginSlots configuration. The shorthand form is only for the Python-side `PLUGIN_SLOTS` Tutor hook registration.

---

## 6. Discovery Commands

```bash
# List all slots in a running MFE container
docker exec <mfe-container> grep -r "PluginSlot" /openedx/dist/*/static/js/*.js

# List slots from MFE source (during build)
grep -r "PluginSlot" node_modules/@openedx/*/src/ 2>/dev/null

# Check our current wiring
grep -r "pluginSlots" tutor_env/env/plugins/mfe/build/mfe/env.config.jsx

# Verify footer slot specifically
./scripts/qa/verify-mfe-footer-slot.sh
```

---

## 7. References

- [OEP-65: Frontend Plugin Framework](https://open-edx-proposals.readthedocs.io/en/latest/architectural-decisions/oep-0065-frontend-plugin-framework.html)
- [Open edX Plugin Slots Browser](https://discuss.openedx.org/t/open-edx-plugin-slots-browser/18407)
- [How to Use Frontend Plugin Slots](https://docs.openedx.org/en/latest/site_ops/how-tos/use-frontend-plugin-slots.html)
- [Frontend Plugin Framework](https://github.com/openedx/frontend-plugin-framework)
- [ADR-014: MFE Branding Strategy](../adr/014-mfe-branding-strategy.md)
