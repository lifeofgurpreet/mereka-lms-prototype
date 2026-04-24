---
title: MFE Plugin-Slot Audit 2026-04-19
type: evidence-bundle
owner: platform-release
observed_at: 2026-04-19T02:00Z
bead: mereka-lms-m0u5
status: active
---

# MFE Plugin-Slot Audit 2026-04-19

## Scope

**What was scanned:**

- `infrastructure/tutor/plugins/mereka_lms_mfe_slots.py` — canonical slot registration source
- `infrastructure/tutor/plugins/_mereka_lms/mfe_runtime/` — all seven split runtime modules:
  - `authoring.js`, `certificate-profile.js`, `dashboard.js`, `footer.js`,
    `header-menu.js`, `learning.js`, `tenant-resolution.js`
- `infrastructure/tutor/plugins/_mereka_lms/mfe_runtime_definitions.js` — generated
  compatibility mirror; content matches the split modules
- `infrastructure/tutor/patches/footer-component.sh` — confirms `MerekaFooter` is now
  wired via PLUGIN_SLOTS (no longer env.config.jsx string surgery)
- `infrastructure/tutor/patches/mfe-slot-ownership.sh` and `mfe_slot_ownership.py` —
  strips tutor-indigo foreign ownership from generated `env.config.jsx`
- `docs/status/active/13-MFE-PLUGIN-BACKLOG-CLASSIFICATION-2026-04-18.md` — planning
  predecessor (this file supersedes its classification claims with source evidence)

**What was out of scope:**

- Runtime browser proof (no agent-browser sessions run in this pass)
- Enterprise MFE build pipelines (`frontend-app-enterprise`, `frontend-app-admin-portal`)
  — these use separate build processes; plugin-slot reach is uncertain for those surfaces
- Slot reachability inside any MFE that is not part of the standard tutor-indigo/tutormfe
  build (e.g., learner-record, ORA2 inline)
- Any component state or prop wiring that requires a live LMS data contract to evaluate

**Count correction — the "33 components" figure is stale:**

The scoping agent that seeded bead `m0u5` cited 33 registered components. Static
inspection of the canonical source yields **65 unique callable names** across 74 unique
slot IDs:

- 54 unique `RenderWidget` component names (Direct Plugin / HideInsert operations)
- 11 unique `withMereka*` modifier function names (Modify operations)

The 33 figure likely reflects a partial pass over an earlier version of the registry
or an informal count of the "product-worthy" surface. This audit reports the actual 65.

---

## Slot-by-Slot Table

Each row is one slot ID. Where a component is reused across multiple slots, the
component name appears in each relevant row with a `(shared)` notation.

### Operation type key

- **INSERT** — `PLUGIN_OPERATIONS.Insert` with `DIRECT_PLUGIN`
- **HIDE+INSERT** — `Hide default_contents` then `Insert` custom widget
- **MODIFY** — `PLUGIN_OPERATIONS.Modify` wrapping `default_contents`

### Classification key

- **PRODUCT** — has substantive JSX source, data contract, real helper dependencies;
  renders meaningful branded UI; not a stub
- **HINT** — renders a trivial badge+text strip, aside, or micro-shell with no data
  contract; named `*Hint` in component or is functionally equivalent to a stub
- **PRODUCT (thin)** — real component but purely a CSS-class injector (className append);
  no JSX subtree of its own; needed for branding but not a full UI surface

---

### Layout / Shell

| Slot ID | Op | Component / Function | Classification | Notes |
|---|---|---|---|---|
| `org.openedx.frontend.layout.footer.v1` | HIDE+INSERT | `MerekaFooter` | **PRODUCT** | Full 4-zone footer with social, nav, 4-column body, legal row; real data contract via `getMerekaVariant` + `getMerekaPublicFooter` |
| `org.openedx.frontend.layout.header_logo.v1` | HIDE+INSERT | `MerekaHeaderLogo` | **PRODUCT** | Tenant-aware logo+lockup; responsive SVG/PNG fallback; `getMerekaVariant` data contract |
| `org.openedx.frontend.layout.header_learning.v1` | INSERT | `MerekaLearningCourseHeader` | **PRODUCT** | Branded header panel with kicker, title, subtitle, badge, support CTA |
| `org.openedx.frontend.layout.header_learning_help.v1` | HIDE+INSERT | `MerekaLearningHelpLink` | **PRODUCT** | Tenant-resolved help link; replaces platform default |
| `org.openedx.frontend.layout.studio_footer.v1` | INSERT | `MerekaStudioFooter` | **PRODUCT** | Branded footer for Studio/authoring; logo + tagline; slim but real |
| `org.openedx.frontend.layout.header_desktop.v1` | MODIFY | `withMerekaHeaderDesktopShell` | **PRODUCT (thin)** | Appends `mereka-header-desktop-shell` className; pure CSS hook |
| `org.openedx.frontend.layout.header_mobile.v1` | MODIFY | `withMerekaHeaderMobileShell` | **PRODUCT (thin)** | Appends `mereka-header-mobile-shell` className |
| `org.openedx.frontend.layout.header_learning_course_info.v1` | MODIFY | `withMerekaHeaderLearningCourseInfo` | **PRODUCT (thin)** | Appends `mereka-header-learning-course-info` className |
| `org.openedx.frontend.layout.header_learning_logged_out_items.v1` | MODIFY | `withMerekaLearningLoggedOutItems` | **PRODUCT** | Injects catalog + support buttons into logged-out header items; real data logic |
| `org.openedx.frontend.layout.header_desktop_user_menu.v1` | MODIFY | `withMerekaHeaderUserMenuSupport` | **PRODUCT** | Injects Support menu item into user menu groups; tenant-aware help URL |
| `org.openedx.frontend.layout.header_mobile_user_menu.v1` | MODIFY | `withMerekaHeaderUserMenuSupport` (shared) | **PRODUCT** | Same modifier reused; identical classification |
| `org.openedx.frontend.layout.header_learning_user_menu.v1` | MODIFY | `withMerekaLearningUserMenuSupport` | **PRODUCT** | Learning-specific user menu: injects support item with different content shape |
| `org.openedx.frontend.layout.header_desktop_user_menu_toggle.v1` | MODIFY | `withMerekaHeaderUserMenuToggle` | **PRODUCT (thin)** | Appends `mereka-header-user-menu-toggle` to button + toggle classNames |
| `org.openedx.frontend.layout.header_mobile_user_menu_trigger.v1` | MODIFY | `withMerekaMobileUserMenuTrigger` | **PRODUCT (thin)** | Appends `mereka-mobile-user-menu-trigger` |
| `org.openedx.frontend.layout.header_learning_user_menu_toggle.v1` | MODIFY | `withMerekaLearningUserMenuToggle` | **PRODUCT (thin)** | Appends `mereka-learning-user-menu-toggle` |
| `org.openedx.frontend.layout.header_desktop_main_menu.v1` | MODIFY | `withMerekaMenuItems` (logged-in items) | **PRODUCT** | Injects Dashboard + Course Catalog + Support into main menu; deduplication logic present |
| `org.openedx.frontend.layout.header_mobile_main_menu.v1` | MODIFY | `withMerekaMenuItems` (logged-in items, shared) | **PRODUCT** | Same modifier, same menu items |
| `org.openedx.frontend.layout.header_desktop_logged_out_items.v1` | MODIFY | `withMerekaMenuItems` (logged-out items) | **PRODUCT** | Course Catalog only in logged-out items |
| `org.openedx.frontend.layout.header_mobile_logged_out_items.v1` | MODIFY | `withMerekaMenuItems` (logged-out items, shared) | **PRODUCT** | Same modifier, same items |
| `org.openedx.frontend.layout.header_desktop_secondary_menu.v1` | MODIFY | `withMerekaMenuItems` (empty array) | **PRODUCT (thin)** | Empties secondary menu; intentional suppression |
| `org.openedx.frontend.layout.studio_header_search_button_slot.v1` | MODIFY | `withMerekaStudioHeaderSearchButton` | **PRODUCT (thin)** | Appends `mereka-studio-header-search-button` className to Studio search button |

---

### Authentication

| Slot ID | Op | Component | Classification | Notes |
|---|---|---|---|---|
| `org.openedx.frontend.authn.login_component.v1` | INSERT | `MerekaAuthnLoginBranding` | **PRODUCT** | Full branded login panel: tenant-aware logo, eyebrow, brand name, trust note; SVG/PNG fallback |

---

### Learner Dashboard

| Slot ID | Op | Component | Classification | Notes |
|---|---|---|---|---|
| `org.openedx.frontend.learner_dashboard.widget_sidebar.v1` | INSERT | `MerekaLearnerSidebarWidget` | **PRODUCT** | Aside panel with quick-links (dashboard, catalog, support); `getMerekaShellCopy` data contract |
| `org.openedx.frontend.learner_dashboard.course_list.v1` | INSERT | `MerekaDashboardHeader` | **PRODUCT** | Branded panel with kicker, h2 title, lead text, primary/secondary CTA links |
| `org.openedx.frontend.learner_dashboard.no_courses_view.v1` | HIDE+INSERT | `MerekaNoCoursesView` | **PRODUCT** | Empty-state replacement with tenant-specific signal copy, CTAs, help link |
| `org.openedx.frontend.learner_dashboard.course_card_banner.v1` | INSERT | `MerekaCourseCardAccent` | **PRODUCT** | Branded badge on course cards; slug-aware label (`Mereka Curated`, `Biji-Biji Pick`, `SOF Track`) |
| `org.openedx.frontend.learner_dashboard.course_card_action.v1` | INSERT | `MerekaCourseCardActionHint` | **HINT** | Renders `MerekaDashboardMicroShell` stub with hardcoded motivation copy; no data contract |
| `org.openedx.frontend.learner_dashboard.dashboard_modal.v1` | INSERT | `MerekaDashboardModalHint` | **HINT** | Renders `MerekaDashboardMicroShell` stub with hardcoded "New pathways" copy; no data contract |

---

### Learning / Courseware

| Slot ID | Op | Component | Classification | Notes |
|---|---|---|---|---|
| `org.openedx.frontend.learning.course_outline_sidebar.v1` | INSERT | `MerekaCourseOutlineSidebar` | **PRODUCT** | Branded aside with kicker, h3, body, help link; `getMerekaShellCopy` + variant data |
| `org.openedx.frontend.learning.progress_certificate_status.v1` | INSERT | `MerekaProgressCertificateStatus` | **PRODUCT** | Certificate readiness card with 3-step checklist, tenant-aware copy; `getCertificateReadinessSteps` data contract |
| `org.openedx.frontend.learning.progress_tab_certificate_status_main_body.v1` | INSERT | `MerekaProgressCertificateStatus` (shared) | **PRODUCT** | Same component; multi-slot reuse is intentional per code comments |
| `org.openedx.frontend.learning.progress_tab_certificate_status_side_panel.v1` | INSERT | `MerekaProgressCertificateStatus` (shared) | **PRODUCT** | Same component |
| `org.openedx.frontend.learning.course_tab_links.v1` | INSERT | `MerekaLearningCourseTabsHint` | **HINT** | Single `<div>` with hardcoded static text; no data contract |
| `org.openedx.frontend.learning.course_breadcrumbs.v1` | INSERT | `MerekaLearningCourseBreadcrumbsHint` | **HINT** | Badge + courseId display; very thin; no real UI logic |
| `org.openedx.frontend.learning.learner_tools.v1` | INSERT | `MerekaLearningLearnerToolsHint` | **HINT** | Badge + enrollment mode display; thin informational only |
| `org.openedx.frontend.learning.progress_tab_course_grade.v1` | INSERT | `MerekaProgressCourseGradeHint` | **HINT** | Badge + courseId display; no grade data contract |
| `org.openedx.frontend.learning.progress_tab_related_links.v1` | INSERT | `MerekaProgressRelatedLinksHint` | **HINT** | Badge + help link; minimal but has a live URL resolution |
| `org.openedx.frontend.learning.progress_tab_grade_breakdown.v1` | INSERT | `MerekaProgressGradeBreakdownHint` | **HINT** | Badge + courseId text; no grade data |
| `org.openedx.frontend.learning.unit_title.v1` | INSERT | `MerekaLearningUnitTitleHint` | **HINT** | Badge + unit.title passthrough; thin passthrough |
| `org.openedx.frontend.learning.sequence_navigation.v1` | INSERT | `MerekaLearningSequenceNavigationHint` | **HINT** | Badge + unitId display; no navigation logic |
| `org.openedx.frontend.learning.course_outline_sidebar_trigger.v1` | INSERT | `MerekaLearningOutlineSidebarTriggerHint` | **HINT** | Visually-hidden `<span>` badge on desktop only |
| `org.openedx.frontend.learning.course_outline_mobile_sidebar_trigger.v1` | INSERT | `MerekaLearningOutlineMobileSidebarTriggerHint` | **HINT** | Visually-hidden `<span>` badge on mobile only |
| `org.openedx.frontend.learning.course_home_section_outline.v1` | INSERT | `MerekaLearningCourseHomeSectionOutlineHint` | **HINT** | Badge + static text |
| `org.openedx.frontend.learning.course_recommendations.v1` | INSERT | `MerekaLearningCourseRecommendationsHint` | **HINT** | Badge + variant string passthrough; no catalog integration |
| `org.openedx.frontend.learning.content_iframe_loader.v1` | INSERT | `MerekaLearningContentIFrameLoaderHint` | **HINT** | Badge + "Preparing" static text |
| `org.openedx.frontend.learning.content_iframe_error.v1` | INSERT | `MerekaLearningContentIFrameErrorHint` | **HINT** | Badge + errorMessage passthrough; no error recovery logic |
| `org.openedx.frontend.learning.sequence_container.v1` | INSERT | `MerekaLearningSequenceContainerHint` | **HINT** | Badge + static text |
| `org.openedx.frontend.learning.gated_unit_content_message.v1` | INSERT | `MerekaLearningGatedUnitContentMessageHint` | **HINT** | Badge + static "unlock prerequisites" text |
| `org.openedx.frontend.learning.next_unit_top_nav_trigger.v1` | INSERT | `MerekaLearningNextUnitTopNavTriggerHint` | **HINT** | `<span>` badge on desktop; no nav logic |
| `org.openedx.frontend.learning.course_outline_tab_notifications.v1` | INSERT | `MerekaLearningCourseOutlineTabNotificationsHint` | **HINT** | Badge + static text |
| `org.openedx.frontend.learning.notification_widget.v1` | INSERT | `MerekaLearningNotificationWidgetHint` | **HINT** | Badge + static text |
| `org.openedx.frontend.learning.notification_tray.v1` | INSERT | `MerekaLearningNotificationTrayHint` | **HINT** | Badge + static text |
| `org.openedx.frontend.learning.notifications_discussions_sidebar_trigger.v1` | INSERT | `MerekaLearningNotificationsDiscussionsSidebarTriggerHint` | **HINT** | `<span>` badge only |
| `org.openedx.frontend.learning.notifications_discussions_sidebar.v1` | INSERT | `MerekaLearningNotificationsDiscussionsSidebarHint` | **HINT** | Badge + static text |
| `org.openedx.frontend.learning.course_exit_view_courses.v1` | INSERT | `MerekaLearningCourseExitViewCoursesHint` | **HINT** | Link to catalog; has live URL via `getCatalogHref` but body is minimal |
| `org.openedx.frontend.learning.course_exit_dashboard_footnote_link.v1` | INSERT | `MerekaLearningCourseExitDashboardFootnoteLinkHint` | **HINT** | Link to learner home; single `<a>` tag |

---

### Authoring / Studio

| Slot ID | Op | Component | Classification | Notes |
|---|---|---|---|---|
| `org.openedx.frontend.authoring.course_unit_sidebar.v1` | INSERT | `MerekaAuthoringCourseUnitSidebarHint` | **HINT** | `<aside>` with badge + static guidance text |
| `org.openedx.frontend.authoring.course_outline_sidebar.v1` | INSERT | `MerekaAuthoringCourseOutlineSidebarHint` | **HINT** | `<aside>` with badge + static text |
| `org.openedx.frontend.authoring.course_outline_header_actions.v1` | INSERT | `MerekaAuthoringCourseOutlineHeaderActionsHint` | **HINT** | `<div>` with single "Mereka Studio" badge |
| `org.openedx.frontend.authoring.course_unit_header_actions.v1` | INSERT | `MerekaAuthoringCourseUnitHeaderActionsHint` | **HINT** | `<div>` with static guidance text only |
| `org.openedx.frontend.authoring.course_outline_page_alerts.v1` | INSERT | `MerekaAuthoringCourseOutlinePageAlertsHint` | **HINT** | Badge + static quality-check text |
| `org.openedx.frontend.authoring.edit_video_alerts.v1` | INSERT | `MerekaAuthoringEditVideoAlertsHint` | **HINT** | Badge + static accessibility reminder |
| `org.openedx.frontend.authoring.edit_file_alerts.v1` | INSERT | `MerekaAuthoringEditFileAlertsHint` | **HINT** | Badge + static file-label reminder |
| `org.openedx.frontend.authoring.additional_course_plugin.v1` | INSERT | `MerekaAuthoringAdditionalCoursePluginHint` | **HINT** | Badge + static text |
| `org.openedx.frontend.authoring.additional_course_content_plugin.v1` | INSERT | `MerekaAuthoringAdditionalCourseContentPluginHint` | **HINT** | Badge + static text |
| `org.openedx.frontend.authoring.course_outline_subsection_card_extra_actions.v1` | INSERT | `MerekaAuthoringOutlineSubsectionExtraActionsHint` | **HINT** | Static text only; no action wiring |
| `org.openedx.frontend.authoring.course_outline_unit_card_extra_actions.v1` | INSERT | `MerekaAuthoringOutlineUnitExtraActionsHint` | **HINT** | Static text only |
| `org.openedx.frontend.authoring.course_unit_sidebar.v2` | INSERT | `MerekaAuthoringCourseUnitSidebarV2Hint` | **HINT** | Badge + static text; v2 placeholder |
| `org.openedx.frontend.authoring.files_upload_page_table.v1` | INSERT | `MerekaAuthoringFilesUploadPageTableHint` | **HINT** | Static text only |
| `org.openedx.frontend.authoring.videos_upload_page_table.v1` | INSERT | `MerekaAuthoringVideosUploadPageTableHint` | **HINT** | Static text only |
| `org.openedx.frontend.authoring.video_transcript_additional_translations_component.v1` | INSERT | `MerekaAuthoringVideoTranscriptTranslationsHint` | **HINT** | Static text only |

---

### Account / Profile

| Slot ID | Op | Component | Classification | Notes |
|---|---|---|---|---|
| `org.openedx.frontend.account.id_verification_page.v1` | INSERT | `MerekaAccountIdVerificationHint` | **HINT** | Renders `MerekaCertificateContextShell` stub; no identity data contract |
| `org.openedx.frontend.account.additional_profile_fields.v1` | INSERT | `MerekaAdditionalProfileFields` | **PRODUCT** | Renders org/job-title/department meta row + certificate readiness guidance; tenant-aware |
| `org.openedx.frontend.profile.additional_profile_fields.v1` | INSERT | `MerekaAdditionalProfileFields` (shared) | **PRODUCT** | Same component reused on profile MFE slot |

---

## Aggregate Summary

| Classification | Count | Description |
|---|---|---|
| **PRODUCT** | 24 | Substantive branded UI with real data contracts |
| **PRODUCT (thin)** | 8 | Real CSS-class injectors; needed for theming; no JSX subtree |
| **HINT** | 42 | Placeholder stubs; badge+text or trivial static copy |
| **UNKNOWN** | 0 | None — every component has inspectable source |

**Total unique callable names across 74 slot registrations: 65**

(54 RenderWidget component names + 11 modifier function names; some components reused
across multiple slots — `MerekaProgressCertificateStatus` on 3 slots,
`MerekaAdditionalProfileFields` on 2 slots, `withMerekaHeaderUserMenuSupport` on 2 slots,
`withMerekaMenuItems` on 5 slots.)

**Count correction:** The "33 components" figure in bead `m0u5` is stale.
Actual unique callable surface = **65** across **74** unique slot IDs.
If only `RenderWidget`-type components (not Modify modifiers) are counted: **54**.
If only non-HINT RenderWidget + non-HINT Modify: **32** — this is the closest interpretation
of "33"; one component may have been miscounted or a registration was added after the
original count.

---

## Next Executable Step Per Classification

### HINT slots (43) — burn-lane decision required

Each HINT component occupies a real slot registration but renders no production-grade UI.
Two decisions are required per HINT (not per surface — these can be batched by domain):

1. **Retire** — Remove the slot registration and component if the surface has no planned
   product feature. This frees the slot for the platform default or a future intentional
   design.
2. **Promote to PRODUCT** — If the surface is on the roadmap, replace the stub with a
   real component before it ships. Use bead `m0u5` as the parent issue; one sub-bead per
   domain batch.

Recommended HINT retirement priority order:
- Authoring/Studio hints (15 slots): lowest learner-path impact; defer until learner path
  is materially complete per `13-MFE-PLUGIN-BACKLOG-CLASSIFICATION-2026-04-18.md`
- Learning notification hints (6 slots): notification system ownership is unclear;
  retirement candidate unless notifications feature is planned
- Learning exit/footnote hints (2 slots): very thin; prime retirement candidates
- Remaining learning in-course hints (20 slots): promote to product in order of
  Sprint A → Sprint B priority sequence from `10-MFE-SPRINT-A-EXECUTION-PLAN-2026-04-18.md`

### PRODUCT (thin) slots (7) — selector-debt audit

These CSS-class injectors (`withMereka*Shell*`, `withMereka*Toggle*`) are valid but their
correctness depends on stable platform widget content shapes. Recommended action:

- Verify each modifier against the actual `default_contents` widget shape in the shipping
  MFE version (Ulmo)
- If the widget content shape changed upstream, the modifier silently no-ops; browser
  proof is the only reliable check
- Tag for the agent-browser screenshot capture lane (same pass as UNKNOWN would use)

### PRODUCT slots (25) — baseline healthy; targeted gap-close

These are proven UI surfaces. Recommended action:

- Confirm each via browser proof pass (agent-browser) to close the evidence gap that
  `MFE-EXECUTABLE-FRONTIER-QUEUE.md` Lane 5 describes
- Selector audit: verify none are compensating for platform CSS regressions via DOM
  selectors (check against `docs/policies/architecture/` selector debt docs)
- `MerekaProgressCertificateStatus` is registered on 3 slots; confirm intentional reuse
  is correct at runtime and does not cause visual duplication on the progress tab

---

## Surprises / Deviations From Prior Scoping

1. **Count is 65 callables / 74 slots, not 33.** The "33 components" figure in bead `m0u5`
   appears to have been a partial or informal count. This audit treats 65 as the correct
   baseline.

2. **No UNKNOWN classification.** Every callable has readable source in the split runtime
   modules. The original task anticipated some components being unclassifiable from static
   inspection; that was not the case here.

3. **`MerekaAccountIdVerificationHint` classified as HINT, not PRODUCT.** The planning doc
   `13-MFE-PLUGIN-BACKLOG-CLASSIFICATION-2026-04-18.md` listed it under Account/Profile C
   bucket. Confirmed: the source renders `MerekaCertificateContextShell` with no identity
   data contract. Classification is consistent with the planning doc.

4. **`MerekaCourseCardActionHint` and `MerekaDashboardModalHint` are HINT.**
   Despite non-Hint component names in some contexts, both render `MerekaDashboardMicroShell`
   with hardcoded static copy and no data contract. Classification: HINT.

5. **`MerekaStudioFooter` classified as PRODUCT (slim but real).** It renders a real footer
   with tenant-aware logo, site name from `getConfig()`, and branded tagline. Not a stub.

6. **Modify-type components (`withMereka*`) are absent from the planning doc.**
   `13-MFE-PLUGIN-BACKLOG-CLASSIFICATION-2026-04-18.md` lists them by name but treats them
   as Display components. This audit treats them as `PRODUCT` or `PRODUCT (thin)` depending
   on whether they inject real UI logic or only append a className.

---

## Related

- Bead: `mereka-lms-m0u5`
- `docs/status/active/MFE-EXECUTABLE-FRONTIER-QUEUE.md`
- `docs/status/active/MFE-ISSUE-MAP.md`
- `docs/status/active/13-MFE-PLUGIN-BACKLOG-CLASSIFICATION-2026-04-18.md`
- `infrastructure/tutor/plugins/mereka_lms_mfe_slots.py` (canonical slot registry)
- `infrastructure/tutor/plugins/_mereka_lms/mfe_runtime/` (component source)
