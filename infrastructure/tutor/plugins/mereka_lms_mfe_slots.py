"""Mereka LMS Tutor plugin slot registrations for MFEs.

Data-driven slot configuration. Each slot is declared as structured data
and expanded into the JS config objects that tutormfe expects.

Operation types:
  - Insert:      Add a new widget to a slot (DIRECT_PLUGIN, priority 1)
  - Hide+Insert: Replace default content without relying on unsupported Replace op
  - Modify:      Wrap the default widget with a higher-order function
  - Custom:      Raw JS for slots that don't fit the above patterns
"""

from __future__ import annotations

from tutormfe.hooks import PLUGIN_SLOTS

# ─── Slot Declarations ────────────────────────────────────────────────────────
# Each tuple: (slot_name, widget_id, RenderWidget)
# All target MFE "all" with DIRECT_PLUGIN type and priority 1.

_INSERT_SLOTS: list[tuple[str, str, str]] = [
    # ── Authoring (Studio) ────────────────────────────────────────────────
    (
        "org.openedx.frontend.authoring.course_unit_sidebar.v1",
        "mereka_authoring_course_unit_sidebar_hint",
        "MerekaAuthoringCourseUnitSidebarHint",
    ),
    (
        "org.openedx.frontend.authoring.course_outline_sidebar.v1",
        "mereka_authoring_course_outline_sidebar_hint",
        "MerekaAuthoringCourseOutlineSidebarHint",
    ),
    (
        "org.openedx.frontend.authoring.course_outline_header_actions.v1",
        "mereka_authoring_course_outline_header_actions_hint",
        "MerekaAuthoringCourseOutlineHeaderActionsHint",
    ),
    (
        "org.openedx.frontend.authoring.course_unit_header_actions.v1",
        "mereka_authoring_course_unit_header_actions_hint",
        "MerekaAuthoringCourseUnitHeaderActionsHint",
    ),
    (
        "org.openedx.frontend.authoring.course_outline_page_alerts.v1",
        "mereka_authoring_course_outline_page_alerts_hint",
        "MerekaAuthoringCourseOutlinePageAlertsHint",
    ),
    (
        "org.openedx.frontend.authoring.edit_video_alerts.v1",
        "mereka_authoring_edit_video_alerts_hint",
        "MerekaAuthoringEditVideoAlertsHint",
    ),
    (
        "org.openedx.frontend.authoring.edit_file_alerts.v1",
        "mereka_authoring_edit_file_alerts_hint",
        "MerekaAuthoringEditFileAlertsHint",
    ),
    (
        "org.openedx.frontend.authoring.additional_course_plugin.v1",
        "mereka_authoring_additional_course_plugin_hint",
        "MerekaAuthoringAdditionalCoursePluginHint",
    ),
    (
        "org.openedx.frontend.authoring.additional_course_content_plugin.v1",
        "mereka_authoring_additional_course_content_plugin_hint",
        "MerekaAuthoringAdditionalCourseContentPluginHint",
    ),
    (
        "org.openedx.frontend.authoring.course_outline_subsection_card_extra_actions.v1",
        "mereka_authoring_outline_subsection_extra_actions_hint",
        "MerekaAuthoringOutlineSubsectionExtraActionsHint",
    ),
    (
        "org.openedx.frontend.authoring.course_outline_unit_card_extra_actions.v1",
        "mereka_authoring_outline_unit_extra_actions_hint",
        "MerekaAuthoringOutlineUnitExtraActionsHint",
    ),
    (
        "org.openedx.frontend.authoring.course_unit_sidebar.v2",
        "mereka_authoring_course_unit_sidebar_v2_hint",
        "MerekaAuthoringCourseUnitSidebarV2Hint",
    ),
    (
        "org.openedx.frontend.authoring.files_upload_page_table.v1",
        "mereka_authoring_files_upload_page_table_hint",
        "MerekaAuthoringFilesUploadPageTableHint",
    ),
    (
        "org.openedx.frontend.authoring.videos_upload_page_table.v1",
        "mereka_authoring_videos_upload_page_table_hint",
        "MerekaAuthoringVideosUploadPageTableHint",
    ),
    (
        "org.openedx.frontend.authoring.video_transcript_additional_translations_component.v1",
        "mereka_authoring_video_transcript_translations_hint",
        "MerekaAuthoringVideoTranscriptTranslationsHint",
    ),
    # ── Authentication ────────────────────────────────────────────────────
    (
        "org.openedx.frontend.authn.login_component.v1",
        "mereka_authn_login_component",
        "MerekaAuthnLoginBranding",
    ),
    # ── Learner Dashboard ─────────────────────────────────────────────────
    (
        "org.openedx.frontend.learner_dashboard.widget_sidebar.v1",
        "mereka_learner_sidebar_widget",
        "MerekaLearnerSidebarWidget",
    ),
    (
        "org.openedx.frontend.learner_dashboard.course_list.v1",
        "mereka_dashboard_course_list_context",
        "MerekaDashboardHeader",
    ),
    (
        "org.openedx.frontend.learner_dashboard.course_card_banner.v1",
        "mereka_dashboard_course_card_banner_accent",
        "MerekaCourseCardAccent",
    ),
    (
        "org.openedx.frontend.learner_dashboard.course_card_action.v1",
        "mereka_dashboard_course_card_action_hint",
        "MerekaCourseCardActionHint",
    ),
    (
        "org.openedx.frontend.learner_dashboard.dashboard_modal.v1",
        "mereka_dashboard_modal_hint",
        "MerekaDashboardModalHint",
    ),
    # ── Learning (Courseware) ─────────────────────────────────────────────
    (
        "org.openedx.frontend.learning.course_outline_sidebar.v1",
        "mereka_course_outline_sidebar",
        "MerekaCourseOutlineSidebar",
    ),
    (
        "org.openedx.frontend.learning.progress_certificate_status.v1",
        "mereka_progress_certificate_status",
        "MerekaProgressCertificateStatus",
    ),
    (
        "org.openedx.frontend.learning.course_tab_links.v1",
        "mereka_learning_course_tab_links_hint",
        "MerekaLearningCourseTabsHint",
    ),
    (
        "org.openedx.frontend.learning.course_breadcrumbs.v1",
        "mereka_learning_course_breadcrumbs_hint",
        "MerekaLearningCourseBreadcrumbsHint",
    ),
    (
        "org.openedx.frontend.learning.learner_tools.v1",
        "mereka_learning_learner_tools_hint",
        "MerekaLearningLearnerToolsHint",
    ),
    (
        "org.openedx.frontend.learning.progress_tab_course_grade.v1",
        "mereka_learning_progress_course_grade_hint",
        "MerekaProgressCourseGradeHint",
    ),
    (
        "org.openedx.frontend.learning.progress_tab_related_links.v1",
        "mereka_learning_progress_related_links_hint",
        "MerekaProgressRelatedLinksHint",
    ),
    (
        "org.openedx.frontend.learning.progress_tab_certificate_status_main_body.v1",
        "mereka_learning_progress_certificate_status_main_body",
        "MerekaProgressCertificateStatus",
    ),
    (
        "org.openedx.frontend.learning.progress_tab_certificate_status_side_panel.v1",
        "mereka_learning_progress_certificate_status_side_panel",
        "MerekaProgressCertificateStatus",
    ),
    (
        "org.openedx.frontend.learning.progress_tab_grade_breakdown.v1",
        "mereka_learning_progress_grade_breakdown_hint",
        "MerekaProgressGradeBreakdownHint",
    ),
    (
        "org.openedx.frontend.learning.unit_title.v1",
        "mereka_learning_unit_title_hint",
        "MerekaLearningUnitTitleHint",
    ),
    (
        "org.openedx.frontend.learning.sequence_navigation.v1",
        "mereka_learning_sequence_navigation_hint",
        "MerekaLearningSequenceNavigationHint",
    ),
    (
        "org.openedx.frontend.learning.course_outline_sidebar_trigger.v1",
        "mereka_learning_outline_sidebar_trigger_hint",
        "MerekaLearningOutlineSidebarTriggerHint",
    ),
    (
        "org.openedx.frontend.learning.course_outline_mobile_sidebar_trigger.v1",
        "mereka_learning_outline_mobile_sidebar_trigger_hint",
        "MerekaLearningOutlineMobileSidebarTriggerHint",
    ),
    (
        "org.openedx.frontend.learning.course_home_section_outline.v1",
        "mereka_learning_course_home_section_outline_hint",
        "MerekaLearningCourseHomeSectionOutlineHint",
    ),
    (
        "org.openedx.frontend.learning.course_recommendations.v1",
        "mereka_learning_course_recommendations_hint",
        "MerekaLearningCourseRecommendationsHint",
    ),
    (
        "org.openedx.frontend.learning.content_iframe_loader.v1",
        "mereka_learning_content_iframe_loader_hint",
        "MerekaLearningContentIFrameLoaderHint",
    ),
    (
        "org.openedx.frontend.learning.content_iframe_error.v1",
        "mereka_learning_content_iframe_error_hint",
        "MerekaLearningContentIFrameErrorHint",
    ),
    (
        "org.openedx.frontend.learning.sequence_container.v1",
        "mereka_learning_sequence_container_hint",
        "MerekaLearningSequenceContainerHint",
    ),
    (
        "org.openedx.frontend.learning.gated_unit_content_message.v1",
        "mereka_learning_gated_unit_content_message_hint",
        "MerekaLearningGatedUnitContentMessageHint",
    ),
    (
        "org.openedx.frontend.learning.next_unit_top_nav_trigger.v1",
        "mereka_learning_next_unit_top_nav_trigger_hint",
        "MerekaLearningNextUnitTopNavTriggerHint",
    ),
    (
        "org.openedx.frontend.learning.course_outline_tab_notifications.v1",
        "mereka_learning_course_outline_tab_notifications_hint",
        "MerekaLearningCourseOutlineTabNotificationsHint",
    ),
    (
        "org.openedx.frontend.learning.notification_widget.v1",
        "mereka_learning_notification_widget_hint",
        "MerekaLearningNotificationWidgetHint",
    ),
    (
        "org.openedx.frontend.learning.notification_tray.v1",
        "mereka_learning_notification_tray_hint",
        "MerekaLearningNotificationTrayHint",
    ),
    (
        "org.openedx.frontend.learning.notifications_discussions_sidebar_trigger.v1",
        "mereka_learning_notifications_discussions_sidebar_trigger_hint",
        "MerekaLearningNotificationsDiscussionsSidebarTriggerHint",
    ),
    (
        "org.openedx.frontend.learning.notifications_discussions_sidebar.v1",
        "mereka_learning_notifications_discussions_sidebar_hint",
        "MerekaLearningNotificationsDiscussionsSidebarHint",
    ),
    (
        "org.openedx.frontend.learning.course_exit_view_courses.v1",
        "mereka_learning_course_exit_view_courses_hint",
        "MerekaLearningCourseExitViewCoursesHint",
    ),
    (
        "org.openedx.frontend.learning.course_exit_dashboard_footnote_link.v1",
        "mereka_learning_course_exit_dashboard_footnote_link_hint",
        "MerekaLearningCourseExitDashboardFootnoteLinkHint",
    ),
    # ── Layout ────────────────────────────────────────────────────────────
    ("org.openedx.frontend.layout.studio_footer.v1", "mereka_studio_footer", "MerekaStudioFooter"),
    (
        "org.openedx.frontend.layout.header_learning.v1",
        "mereka_layout_header_learning_context",
        "MerekaLearningCourseHeader",
    ),
    # ── Account & Profile ─────────────────────────────────────────────────
    (
        "org.openedx.frontend.account.id_verification_page.v1",
        "mereka_account_id_verification_hint",
        "MerekaAccountIdVerificationHint",
    ),
    (
        "org.openedx.frontend.account.additional_profile_fields.v1",
        "mereka_additional_profile_fields",
        "MerekaAdditionalProfileFields",
    ),
    (
        "org.openedx.frontend.profile.additional_profile_fields.v1",
        "mereka_profile_additional_fields",
        "MerekaAdditionalProfileFields",
    ),
]

# Each tuple: (slot_name, widget_id, RenderWidget, priority)
# frontend-plugin-framework in shipped learning/dashboard MFEs does not support
# a direct replace operation. These surfaces must hide default_contents and insert
# the replacement widget instead.
_HIDE_INSERT_SLOTS: list[tuple[str, str, str, int]] = [
    ("org.openedx.frontend.layout.header_logo.v1", "mereka_header_logo", "MerekaHeaderLogo", 1),
    (
        "org.openedx.frontend.learner_dashboard.no_courses_view.v1",
        "mereka_no_courses_view",
        "MerekaNoCoursesView",
        1,
    ),
    (
        "org.openedx.frontend.layout.header_learning_help.v1",
        "mereka_layout_header_learning_help_link",
        "MerekaLearningHelpLink",
        10,
    ),
]

# Each tuple: (slot_name, modifier_fn_name)
# All use: op: Modify, widgetId: 'default_contents', fn: (widget) => fnName(widget)
_MODIFY_SLOTS: list[tuple[str, str]] = [
    (
        "org.openedx.frontend.layout.studio_header_search_button_slot.v1",
        "withMerekaStudioHeaderSearchButton",
    ),
    ("org.openedx.frontend.layout.header_desktop.v1", "withMerekaHeaderDesktopShell"),
    ("org.openedx.frontend.layout.header_mobile.v1", "withMerekaHeaderMobileShell"),
    (
        "org.openedx.frontend.layout.header_learning_course_info.v1",
        "withMerekaHeaderLearningCourseInfo",
    ),
    (
        "org.openedx.frontend.layout.header_learning_logged_out_items.v1",
        "withMerekaLearningLoggedOutItems",
    ),
    ("org.openedx.frontend.layout.header_desktop_user_menu.v1", "withMerekaHeaderUserMenuSupport"),
    ("org.openedx.frontend.layout.header_mobile_user_menu.v1", "withMerekaHeaderUserMenuSupport"),
    (
        "org.openedx.frontend.layout.header_learning_user_menu.v1",
        "withMerekaLearningUserMenuSupport",
    ),
    (
        "org.openedx.frontend.layout.header_desktop_user_menu_toggle.v1",
        "withMerekaHeaderUserMenuToggle",
    ),
    (
        "org.openedx.frontend.layout.header_mobile_user_menu_trigger.v1",
        "withMerekaMobileUserMenuTrigger",
    ),
    (
        "org.openedx.frontend.layout.header_learning_user_menu_toggle.v1",
        "withMerekaLearningUserMenuToggle",
    ),
]

# Menu items shared by desktop and mobile main menus (logged-in)
_LOGGED_IN_MENU_ITEMS = """[
                            {
                                type: 'item',
                                href: '/dashboard',
                                content: 'Dashboard',
                            },
                            {
                                type: 'item',
                                href: '/dashboard/courses',
                                content: 'Discover Courses',
                            },
                        ]"""

# Menu items for logged-out menus
_LOGGED_OUT_MENU_ITEMS = """[
                            {
                                type: 'item',
                                href: '/dashboard/courses',
                                content: 'Discover Courses',
                            },
                        ]"""


# ─── JS Template Generators ──────────────────────────────────────────────────


def _insert_js(widget_id: str, render_widget: str, priority: int = 1) -> str:
    return f"""
                {{
                    op: PLUGIN_OPERATIONS.Insert,
                    widget: {{
                        id: '{widget_id}',
                        type: DIRECT_PLUGIN,
                        priority: {priority},
                        RenderWidget: {render_widget},
                    }},
                }},
                """


def _hide_insert_js(widget_id: str, render_widget: str, priority: int = 1) -> str:
    return f"""
                {{
                    op: PLUGIN_OPERATIONS.Hide,
                    widgetId: 'default_contents',
                }},
                {{
                    op: PLUGIN_OPERATIONS.Insert,
                    widget: {{
                        id: '{widget_id}',
                        type: DIRECT_PLUGIN,
                        priority: {priority},
                        RenderWidget: {render_widget},
                    }},
                }},
                """


def _modify_js(fn_name: str) -> str:
    return f"""
                {{
                    op: PLUGIN_OPERATIONS.Modify,
                    widgetId: 'default_contents',
                    fn: (widget) => {fn_name}(widget),
                }},
                """


def _modify_menu_js(fn_name: str, menu_items: str) -> str:
    return f"""
                {{
                    op: PLUGIN_OPERATIONS.Modify,
                    widgetId: 'default_contents',
                    fn: (widget) => {fn_name}(
                        widget,
                        {menu_items},
                    ),
                }},
                """


# ─── Registration ─────────────────────────────────────────────────────────────


def register_mfe_plugin_slots() -> None:
    """Register all Mereka MFE slot overrides."""
    items: list[tuple[str, str, str]] = []

    # Insert slots (54 slots)
    for slot_name, widget_id, render_widget in _INSERT_SLOTS:
        items.append(("all", slot_name, _insert_js(widget_id, render_widget)))

    # Hide+insert slots (3 slots)
    for slot_name, widget_id, render_widget, priority in _HIDE_INSERT_SLOTS:
        items.append(("all", slot_name, _hide_insert_js(widget_id, render_widget, priority)))

    # Simple Modify slots (11 slots)
    for slot_name, fn_name in _MODIFY_SLOTS:
        items.append(("all", slot_name, _modify_js(fn_name)))

    # Footer: Hide default + Insert custom (1 slot, 2 operations)
    items.append(
        (
            "all",
            "org.openedx.frontend.layout.footer.v1",
            """
                {
                    op: PLUGIN_OPERATIONS.Hide,
                    widgetId: 'default_contents',
                },
                {
                    op: PLUGIN_OPERATIONS.Insert,
                    widget: {
                        id: 'mereka_footer',
                        type: DIRECT_PLUGIN,
                        priority: 1,
                        RenderWidget: MerekaFooter,
                    },
                },
                """,
        )
    )

    # Menu Modify slots with inline menu items (5 slots)
    for slot_name, menu_items in [
        ("org.openedx.frontend.layout.header_desktop_main_menu.v1", _LOGGED_IN_MENU_ITEMS),
        ("org.openedx.frontend.layout.header_mobile_main_menu.v1", _LOGGED_IN_MENU_ITEMS),
        ("org.openedx.frontend.layout.header_desktop_logged_out_items.v1", _LOGGED_OUT_MENU_ITEMS),
        ("org.openedx.frontend.layout.header_mobile_logged_out_items.v1", _LOGGED_OUT_MENU_ITEMS),
    ]:
        items.append(("all", slot_name, _modify_menu_js("withMerekaMenuItems", menu_items)))

    # Secondary menu: Modify with empty array
    items.append(
        (
            "all",
            "org.openedx.frontend.layout.header_desktop_secondary_menu.v1",
            """
                {
                    op: PLUGIN_OPERATIONS.Modify,
                    widgetId: 'default_contents',
                    fn: (widget) => withMerekaMenuItems(widget, []),
                },
                """,
        )
    )

    PLUGIN_SLOTS.add_items(items)
