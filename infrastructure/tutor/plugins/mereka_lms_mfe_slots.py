"""Mereka LMS Tutor plugin slot registrations for MFEs."""

from __future__ import annotations

from tutormfe.hooks import PLUGIN_SLOTS


def register_mfe_plugin_slots() -> None:
    """Register all Mereka MFE slot overrides."""
    for _mfe in [
        "all",
    ]:
        PLUGIN_SLOTS.add_items([
            (
                _mfe,
                "org.openedx.frontend.layout.header_logo.v1",
                """
                {
                    op: PLUGIN_OPERATIONS.Replace,
                    widget: {
                        id: 'mereka_header_logo',
                        type: DIRECT_PLUGIN,
                        priority: 1,
                        RenderWidget: MerekaHeaderLogo,
                    },
                },
                """,
            ),
            (
                _mfe,
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
            ),
            (
                _mfe,
                "org.openedx.frontend.layout.studio_footer.v1",
                """
                {
                    op: PLUGIN_OPERATIONS.Insert,
                    widget: {
                        id: 'mereka_studio_footer',
                        type: DIRECT_PLUGIN,
                        priority: 1,
                        RenderWidget: MerekaStudioFooter,
                    },
                },
                """,
            ),
            (
                _mfe,
                "org.openedx.frontend.layout.studio_header_search_button_slot.v1",
                """
                {
                    op: PLUGIN_OPERATIONS.Modify,
                    widgetId: 'default_contents',
                    fn: (widget) => withMerekaStudioHeaderSearchButton(widget),
                },
                """,
            ),
            (
                _mfe,
                "org.openedx.frontend.authoring.course_unit_sidebar.v1",
                """
                {
                    op: PLUGIN_OPERATIONS.Insert,
                    widget: {
                        id: 'mereka_authoring_course_unit_sidebar_hint',
                        type: DIRECT_PLUGIN,
                        priority: 1,
                        RenderWidget: MerekaAuthoringCourseUnitSidebarHint,
                    },
                },
                """,
            ),
            (
                _mfe,
                "org.openedx.frontend.authoring.course_outline_sidebar.v1",
                """
                {
                    op: PLUGIN_OPERATIONS.Insert,
                    widget: {
                        id: 'mereka_authoring_course_outline_sidebar_hint',
                        type: DIRECT_PLUGIN,
                        priority: 1,
                        RenderWidget: MerekaAuthoringCourseOutlineSidebarHint,
                    },
                },
                """,
            ),
            (
                _mfe,
                "org.openedx.frontend.authoring.course_outline_header_actions.v1",
                """
                {
                    op: PLUGIN_OPERATIONS.Insert,
                    widget: {
                        id: 'mereka_authoring_course_outline_header_actions_hint',
                        type: DIRECT_PLUGIN,
                        priority: 1,
                        RenderWidget: MerekaAuthoringCourseOutlineHeaderActionsHint,
                    },
                },
                """,
            ),
            (
                _mfe,
                "org.openedx.frontend.authoring.course_unit_header_actions.v1",
                """
                {
                    op: PLUGIN_OPERATIONS.Insert,
                    widget: {
                        id: 'mereka_authoring_course_unit_header_actions_hint',
                        type: DIRECT_PLUGIN,
                        priority: 1,
                        RenderWidget: MerekaAuthoringCourseUnitHeaderActionsHint,
                    },
                },
                """,
            ),
            (
                _mfe,
                "org.openedx.frontend.authoring.course_outline_page_alerts.v1",
                """
                {
                    op: PLUGIN_OPERATIONS.Insert,
                    widget: {
                        id: 'mereka_authoring_course_outline_page_alerts_hint',
                        type: DIRECT_PLUGIN,
                        priority: 1,
                        RenderWidget: MerekaAuthoringCourseOutlinePageAlertsHint,
                    },
                },
                """,
            ),
            (
                _mfe,
                "org.openedx.frontend.authoring.edit_video_alerts.v1",
                """
                {
                    op: PLUGIN_OPERATIONS.Insert,
                    widget: {
                        id: 'mereka_authoring_edit_video_alerts_hint',
                        type: DIRECT_PLUGIN,
                        priority: 1,
                        RenderWidget: MerekaAuthoringEditVideoAlertsHint,
                    },
                },
                """,
            ),
            (
                _mfe,
                "org.openedx.frontend.authoring.edit_file_alerts.v1",
                """
                {
                    op: PLUGIN_OPERATIONS.Insert,
                    widget: {
                        id: 'mereka_authoring_edit_file_alerts_hint',
                        type: DIRECT_PLUGIN,
                        priority: 1,
                        RenderWidget: MerekaAuthoringEditFileAlertsHint,
                    },
                },
                """,
            ),
            (
                _mfe,
                "org.openedx.frontend.authoring.additional_course_plugin.v1",
                """
                {
                    op: PLUGIN_OPERATIONS.Insert,
                    widget: {
                        id: 'mereka_authoring_additional_course_plugin_hint',
                        type: DIRECT_PLUGIN,
                        priority: 1,
                        RenderWidget: MerekaAuthoringAdditionalCoursePluginHint,
                    },
                },
                """,
            ),
            (
                _mfe,
                "org.openedx.frontend.authoring.additional_course_content_plugin.v1",
                """
                {
                    op: PLUGIN_OPERATIONS.Insert,
                    widget: {
                        id: 'mereka_authoring_additional_course_content_plugin_hint',
                        type: DIRECT_PLUGIN,
                        priority: 1,
                        RenderWidget: MerekaAuthoringAdditionalCourseContentPluginHint,
                    },
                },
                """,
            ),
            (
                _mfe,
                "org.openedx.frontend.authoring.course_outline_subsection_card_extra_actions.v1",
                """
                {
                    op: PLUGIN_OPERATIONS.Insert,
                    widget: {
                        id: 'mereka_authoring_outline_subsection_extra_actions_hint',
                        type: DIRECT_PLUGIN,
                        priority: 1,
                        RenderWidget: MerekaAuthoringOutlineSubsectionExtraActionsHint,
                    },
                },
                """,
            ),
            (
                _mfe,
                "org.openedx.frontend.authoring.course_outline_unit_card_extra_actions.v1",
                """
                {
                    op: PLUGIN_OPERATIONS.Insert,
                    widget: {
                        id: 'mereka_authoring_outline_unit_extra_actions_hint',
                        type: DIRECT_PLUGIN,
                        priority: 1,
                        RenderWidget: MerekaAuthoringOutlineUnitExtraActionsHint,
                    },
                },
                """,
            ),
            (
                _mfe,
                "org.openedx.frontend.authoring.course_unit_sidebar.v2",
                """
                {
                    op: PLUGIN_OPERATIONS.Insert,
                    widget: {
                        id: 'mereka_authoring_course_unit_sidebar_v2_hint',
                        type: DIRECT_PLUGIN,
                        priority: 1,
                        RenderWidget: MerekaAuthoringCourseUnitSidebarV2Hint,
                    },
                },
                """,
            ),
            (
                _mfe,
                "org.openedx.frontend.authoring.files_upload_page_table.v1",
                """
                {
                    op: PLUGIN_OPERATIONS.Insert,
                    widget: {
                        id: 'mereka_authoring_files_upload_page_table_hint',
                        type: DIRECT_PLUGIN,
                        priority: 1,
                        RenderWidget: MerekaAuthoringFilesUploadPageTableHint,
                    },
                },
                """,
            ),
            (
                _mfe,
                "org.openedx.frontend.authoring.videos_upload_page_table.v1",
                """
                {
                    op: PLUGIN_OPERATIONS.Insert,
                    widget: {
                        id: 'mereka_authoring_videos_upload_page_table_hint',
                        type: DIRECT_PLUGIN,
                        priority: 1,
                        RenderWidget: MerekaAuthoringVideosUploadPageTableHint,
                    },
                },
                """,
            ),
            (
                _mfe,
                "org.openedx.frontend.authoring.video_transcript_additional_translations_component.v1",
                """
                {
                    op: PLUGIN_OPERATIONS.Insert,
                    widget: {
                        id: 'mereka_authoring_video_transcript_translations_hint',
                        type: DIRECT_PLUGIN,
                        priority: 1,
                        RenderWidget: MerekaAuthoringVideoTranscriptTranslationsHint,
                    },
                },
                """,
            ),
            (
                _mfe,
                "org.openedx.frontend.authn.login_component.v1",
                """
                {
                    op: PLUGIN_OPERATIONS.Insert,
                    widget: {
                        id: 'mereka_authn_login_component',
                        type: DIRECT_PLUGIN,
                        priority: 1,
                        RenderWidget: MerekaAuthnLoginBranding,
                    },
                },
                """,
            ),
            (
                _mfe,
                "org.openedx.frontend.learner_dashboard.widget_sidebar.v1",
                """
                {
                    op: PLUGIN_OPERATIONS.Insert,
                    widget: {
                        id: 'mereka_learner_sidebar_widget',
                        type: DIRECT_PLUGIN,
                        priority: 1,
                        RenderWidget: MerekaLearnerSidebarWidget,
                    },
                },
                """,
            ),
            (
                _mfe,
                "org.openedx.frontend.learner_dashboard.no_courses_view.v1",
                """
                {
                    op: PLUGIN_OPERATIONS.Replace,
                    widget: {
                        id: 'mereka_no_courses_view',
                        type: DIRECT_PLUGIN,
                        priority: 1,
                        RenderWidget: MerekaNoCoursesView,
                    },
                },
                """,
            ),
            (
                _mfe,
                "org.openedx.frontend.learner_dashboard.course_list.v1",
                """
                {
                    op: PLUGIN_OPERATIONS.Insert,
                    widget: {
                        id: 'mereka_dashboard_course_list_context',
                        type: DIRECT_PLUGIN,
                        priority: 1,
                        RenderWidget: MerekaDashboardHeader,
                    },
                },
                """,
            ),
            (
                _mfe,
                "org.openedx.frontend.learner_dashboard.course_card_banner.v1",
                """
                {
                    op: PLUGIN_OPERATIONS.Insert,
                    widget: {
                        id: 'mereka_dashboard_course_card_banner_accent',
                        type: DIRECT_PLUGIN,
                        priority: 1,
                        RenderWidget: MerekaCourseCardAccent,
                    },
                },
                """,
            ),
            (
                _mfe,
                "org.openedx.frontend.learner_dashboard.course_card_action.v1",
                """
                {
                    op: PLUGIN_OPERATIONS.Insert,
                    widget: {
                        id: 'mereka_dashboard_course_card_action_hint',
                        type: DIRECT_PLUGIN,
                        priority: 1,
                        RenderWidget: MerekaCourseCardActionHint,
                    },
                },
                """,
            ),
            (
                _mfe,
                "org.openedx.frontend.learner_dashboard.dashboard_modal.v1",
                """
                {
                    op: PLUGIN_OPERATIONS.Insert,
                    widget: {
                        id: 'mereka_dashboard_modal_hint',
                        type: DIRECT_PLUGIN,
                        priority: 1,
                        RenderWidget: MerekaDashboardModalHint,
                    },
                },
                """,
            ),
            (
                _mfe,
                "org.openedx.frontend.learning.course_outline_sidebar.v1",
                """
                {
                    op: PLUGIN_OPERATIONS.Insert,
                    widget: {
                        id: 'mereka_course_outline_sidebar',
                        type: DIRECT_PLUGIN,
                        priority: 1,
                        RenderWidget: MerekaCourseOutlineSidebar,
                    },
                },
                """,
            ),
            (
                _mfe,
                "org.openedx.frontend.learning.progress_certificate_status.v1",
                """
                {
                    op: PLUGIN_OPERATIONS.Insert,
                    widget: {
                        id: 'mereka_progress_certificate_status',
                        type: DIRECT_PLUGIN,
                        priority: 1,
                        RenderWidget: MerekaProgressCertificateStatus,
                    },
                },
                """,
            ),
            (
                _mfe,
                "org.openedx.frontend.layout.header_learning.v1",
                """
                {
                    op: PLUGIN_OPERATIONS.Insert,
                    widget: {
                        id: 'mereka_layout_header_learning_context',
                        type: DIRECT_PLUGIN,
                        priority: 1,
                        RenderWidget: MerekaLearningCourseHeader,
                    },
                },
                """,
            ),
            (
                _mfe,
                "org.openedx.frontend.learning.course_tab_links.v1",
                """
                {
                    op: PLUGIN_OPERATIONS.Insert,
                    widget: {
                        id: 'mereka_learning_course_tab_links_hint',
                        type: DIRECT_PLUGIN,
                        priority: 1,
                        RenderWidget: MerekaLearningCourseTabsHint,
                    },
                },
                """,
            ),
            (
                _mfe,
                "org.openedx.frontend.learning.course_breadcrumbs.v1",
                """
                {
                    op: PLUGIN_OPERATIONS.Insert,
                    widget: {
                        id: 'mereka_learning_course_breadcrumbs_hint',
                        type: DIRECT_PLUGIN,
                        priority: 1,
                        RenderWidget: MerekaLearningCourseBreadcrumbsHint,
                    },
                },
                """,
            ),
            (
                _mfe,
                "org.openedx.frontend.learning.learner_tools.v1",
                """
                {
                    op: PLUGIN_OPERATIONS.Insert,
                    widget: {
                        id: 'mereka_learning_learner_tools_hint',
                        type: DIRECT_PLUGIN,
                        priority: 1,
                        RenderWidget: MerekaLearningLearnerToolsHint,
                    },
                },
                """,
            ),
            (
                _mfe,
                "org.openedx.frontend.learning.progress_tab_course_grade.v1",
                """
                {
                    op: PLUGIN_OPERATIONS.Insert,
                    widget: {
                        id: 'mereka_learning_progress_course_grade_hint',
                        type: DIRECT_PLUGIN,
                        priority: 1,
                        RenderWidget: MerekaProgressCourseGradeHint,
                    },
                },
                """,
            ),
            (
                _mfe,
                "org.openedx.frontend.learning.progress_tab_related_links.v1",
                """
                {
                    op: PLUGIN_OPERATIONS.Insert,
                    widget: {
                        id: 'mereka_learning_progress_related_links_hint',
                        type: DIRECT_PLUGIN,
                        priority: 1,
                        RenderWidget: MerekaProgressRelatedLinksHint,
                    },
                },
                """,
            ),
            (
                _mfe,
                "org.openedx.frontend.learning.progress_tab_certificate_status_main_body.v1",
                """
                {
                    op: PLUGIN_OPERATIONS.Insert,
                    widget: {
                        id: 'mereka_learning_progress_certificate_status_main_body',
                        type: DIRECT_PLUGIN,
                        priority: 1,
                        RenderWidget: MerekaProgressCertificateStatus,
                    },
                },
                """,
            ),
            (
                _mfe,
                "org.openedx.frontend.learning.progress_tab_certificate_status_side_panel.v1",
                """
                {
                    op: PLUGIN_OPERATIONS.Insert,
                    widget: {
                        id: 'mereka_learning_progress_certificate_status_side_panel',
                        type: DIRECT_PLUGIN,
                        priority: 1,
                        RenderWidget: MerekaProgressCertificateStatus,
                    },
                },
                """,
            ),
            (
                _mfe,
                "org.openedx.frontend.learning.progress_tab_grade_breakdown.v1",
                """
                {
                    op: PLUGIN_OPERATIONS.Insert,
                    widget: {
                        id: 'mereka_learning_progress_grade_breakdown_hint',
                        type: DIRECT_PLUGIN,
                        priority: 1,
                        RenderWidget: MerekaProgressGradeBreakdownHint,
                    },
                },
                """,
            ),
            (
                _mfe,
                "org.openedx.frontend.learning.unit_title.v1",
                """
                {
                    op: PLUGIN_OPERATIONS.Insert,
                    widget: {
                        id: 'mereka_learning_unit_title_hint',
                        type: DIRECT_PLUGIN,
                        priority: 1,
                        RenderWidget: MerekaLearningUnitTitleHint,
                    },
                },
                """,
            ),
            (
                _mfe,
                "org.openedx.frontend.learning.sequence_navigation.v1",
                """
                {
                    op: PLUGIN_OPERATIONS.Insert,
                    widget: {
                        id: 'mereka_learning_sequence_navigation_hint',
                        type: DIRECT_PLUGIN,
                        priority: 1,
                        RenderWidget: MerekaLearningSequenceNavigationHint,
                    },
                },
                """,
            ),
            (
                _mfe,
                "org.openedx.frontend.learning.course_outline_sidebar_trigger.v1",
                """
                {
                    op: PLUGIN_OPERATIONS.Insert,
                    widget: {
                        id: 'mereka_learning_outline_sidebar_trigger_hint',
                        type: DIRECT_PLUGIN,
                        priority: 1,
                        RenderWidget: MerekaLearningOutlineSidebarTriggerHint,
                    },
                },
                """,
            ),
            (
                _mfe,
                "org.openedx.frontend.learning.course_outline_mobile_sidebar_trigger.v1",
                """
                {
                    op: PLUGIN_OPERATIONS.Insert,
                    widget: {
                        id: 'mereka_learning_outline_mobile_sidebar_trigger_hint',
                        type: DIRECT_PLUGIN,
                        priority: 1,
                        RenderWidget: MerekaLearningOutlineMobileSidebarTriggerHint,
                    },
                },
                """,
            ),
            (
                _mfe,
                "org.openedx.frontend.learning.course_home_section_outline.v1",
                """
                {
                    op: PLUGIN_OPERATIONS.Insert,
                    widget: {
                        id: 'mereka_learning_course_home_section_outline_hint',
                        type: DIRECT_PLUGIN,
                        priority: 1,
                        RenderWidget: MerekaLearningCourseHomeSectionOutlineHint,
                    },
                },
                """,
            ),
            (
                _mfe,
                "org.openedx.frontend.learning.course_recommendations.v1",
                """
                {
                    op: PLUGIN_OPERATIONS.Insert,
                    widget: {
                        id: 'mereka_learning_course_recommendations_hint',
                        type: DIRECT_PLUGIN,
                        priority: 1,
                        RenderWidget: MerekaLearningCourseRecommendationsHint,
                    },
                },
                """,
            ),
            (
                _mfe,
                "org.openedx.frontend.learning.content_iframe_loader.v1",
                """
                {
                    op: PLUGIN_OPERATIONS.Insert,
                    widget: {
                        id: 'mereka_learning_content_iframe_loader_hint',
                        type: DIRECT_PLUGIN,
                        priority: 1,
                        RenderWidget: MerekaLearningContentIFrameLoaderHint,
                    },
                },
                """,
            ),
            (
                _mfe,
                "org.openedx.frontend.learning.content_iframe_error.v1",
                """
                {
                    op: PLUGIN_OPERATIONS.Insert,
                    widget: {
                        id: 'mereka_learning_content_iframe_error_hint',
                        type: DIRECT_PLUGIN,
                        priority: 1,
                        RenderWidget: MerekaLearningContentIFrameErrorHint,
                    },
                },
                """,
            ),
            (
                _mfe,
                "org.openedx.frontend.learning.sequence_container.v1",
                """
                {
                    op: PLUGIN_OPERATIONS.Insert,
                    widget: {
                        id: 'mereka_learning_sequence_container_hint',
                        type: DIRECT_PLUGIN,
                        priority: 1,
                        RenderWidget: MerekaLearningSequenceContainerHint,
                    },
                },
                """,
            ),
            (
                _mfe,
                "org.openedx.frontend.learning.gated_unit_content_message.v1",
                """
                {
                    op: PLUGIN_OPERATIONS.Insert,
                    widget: {
                        id: 'mereka_learning_gated_unit_content_message_hint',
                        type: DIRECT_PLUGIN,
                        priority: 1,
                        RenderWidget: MerekaLearningGatedUnitContentMessageHint,
                    },
                },
                """,
            ),
            (
                _mfe,
                "org.openedx.frontend.learning.next_unit_top_nav_trigger.v1",
                """
                {
                    op: PLUGIN_OPERATIONS.Insert,
                    widget: {
                        id: 'mereka_learning_next_unit_top_nav_trigger_hint',
                        type: DIRECT_PLUGIN,
                        priority: 1,
                        RenderWidget: MerekaLearningNextUnitTopNavTriggerHint,
                    },
                },
                """,
            ),
            (
                _mfe,
                "org.openedx.frontend.learning.course_outline_tab_notifications.v1",
                """
                {
                    op: PLUGIN_OPERATIONS.Insert,
                    widget: {
                        id: 'mereka_learning_course_outline_tab_notifications_hint',
                        type: DIRECT_PLUGIN,
                        priority: 1,
                        RenderWidget: MerekaLearningCourseOutlineTabNotificationsHint,
                    },
                },
                """,
            ),
            (
                _mfe,
                "org.openedx.frontend.learning.notification_widget.v1",
                """
                {
                    op: PLUGIN_OPERATIONS.Insert,
                    widget: {
                        id: 'mereka_learning_notification_widget_hint',
                        type: DIRECT_PLUGIN,
                        priority: 1,
                        RenderWidget: MerekaLearningNotificationWidgetHint,
                    },
                },
                """,
            ),
            (
                _mfe,
                "org.openedx.frontend.learning.notification_tray.v1",
                """
                {
                    op: PLUGIN_OPERATIONS.Insert,
                    widget: {
                        id: 'mereka_learning_notification_tray_hint',
                        type: DIRECT_PLUGIN,
                        priority: 1,
                        RenderWidget: MerekaLearningNotificationTrayHint,
                    },
                },
                """,
            ),
            (
                _mfe,
                "org.openedx.frontend.learning.notifications_discussions_sidebar_trigger.v1",
                """
                {
                    op: PLUGIN_OPERATIONS.Insert,
                    widget: {
                        id: 'mereka_learning_notifications_discussions_sidebar_trigger_hint',
                        type: DIRECT_PLUGIN,
                        priority: 1,
                        RenderWidget: MerekaLearningNotificationsDiscussionsSidebarTriggerHint,
                    },
                },
                """,
            ),
            (
                _mfe,
                "org.openedx.frontend.learning.notifications_discussions_sidebar.v1",
                """
                {
                    op: PLUGIN_OPERATIONS.Insert,
                    widget: {
                        id: 'mereka_learning_notifications_discussions_sidebar_hint',
                        type: DIRECT_PLUGIN,
                        priority: 1,
                        RenderWidget: MerekaLearningNotificationsDiscussionsSidebarHint,
                    },
                },
                """,
            ),
            (
                _mfe,
                "org.openedx.frontend.learning.course_exit_view_courses.v1",
                """
                {
                    op: PLUGIN_OPERATIONS.Insert,
                    widget: {
                        id: 'mereka_learning_course_exit_view_courses_hint',
                        type: DIRECT_PLUGIN,
                        priority: 1,
                        RenderWidget: MerekaLearningCourseExitViewCoursesHint,
                    },
                },
                """,
            ),
            (
                _mfe,
                "org.openedx.frontend.learning.course_exit_dashboard_footnote_link.v1",
                """
                {
                    op: PLUGIN_OPERATIONS.Insert,
                    widget: {
                        id: 'mereka_learning_course_exit_dashboard_footnote_link_hint',
                        type: DIRECT_PLUGIN,
                        priority: 1,
                        RenderWidget: MerekaLearningCourseExitDashboardFootnoteLinkHint,
                    },
                },
                """,
            ),
            (
                _mfe,
                "org.openedx.frontend.account.id_verification_page.v1",
                """
                {
                    op: PLUGIN_OPERATIONS.Insert,
                    widget: {
                        id: 'mereka_account_id_verification_hint',
                        type: DIRECT_PLUGIN,
                        priority: 1,
                        RenderWidget: MerekaAccountIdVerificationHint,
                    },
                },
                """,
            ),
            (
                _mfe,
                "org.openedx.frontend.account.additional_profile_fields.v1",
                """
                {
                    op: PLUGIN_OPERATIONS.Insert,
                    widget: {
                        id: 'mereka_additional_profile_fields',
                        type: DIRECT_PLUGIN,
                        priority: 1,
                        RenderWidget: MerekaAdditionalProfileFields,
                    },
                },
                """,
            ),
            (
                _mfe,
                "org.openedx.frontend.profile.additional_profile_fields.v1",
                """
                {
                    op: PLUGIN_OPERATIONS.Insert,
                    widget: {
                        id: 'mereka_profile_additional_fields',
                        type: DIRECT_PLUGIN,
                        priority: 1,
                        RenderWidget: MerekaAdditionalProfileFields,
                    },
                },
                """,
            ),
            (
                _mfe,
                "org.openedx.frontend.layout.header_desktop_main_menu.v1",
                """
                {
                    op: PLUGIN_OPERATIONS.Modify,
                    widgetId: 'default_contents',
                    fn: (widget) => withMerekaMenuItems(
                        widget,
                        [
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
                        ],
                    ),
                },
                """,
            ),
            (
                _mfe,
                "org.openedx.frontend.layout.header_mobile_main_menu.v1",
                """
                {
                    op: PLUGIN_OPERATIONS.Modify,
                    widgetId: 'default_contents',
                    fn: (widget) => withMerekaMenuItems(
                        widget,
                        [
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
                        ],
                    ),
                },
                """,
            ),
            (
                _mfe,
                "org.openedx.frontend.layout.header_desktop_logged_out_items.v1",
                """
                {
                    op: PLUGIN_OPERATIONS.Modify,
                    widgetId: 'default_contents',
                    fn: (widget) => withMerekaMenuItems(
                        widget,
                        [
                            {
                                type: 'item',
                                href: '/dashboard/courses',
                                content: 'Discover Courses',
                            },
                        ],
                    ),
                },
                """,
            ),
            (
                _mfe,
                "org.openedx.frontend.layout.header_mobile_logged_out_items.v1",
                """
                {
                    op: PLUGIN_OPERATIONS.Modify,
                    widgetId: 'default_contents',
                    fn: (widget) => withMerekaMenuItems(
                        widget,
                        [
                            {
                                type: 'item',
                                href: '/dashboard/courses',
                                content: 'Discover Courses',
                            },
                        ],
                    ),
                },
                """,
            ),
            (
                _mfe,
                "org.openedx.frontend.layout.header_desktop_secondary_menu.v1",
                """
                {
                    op: PLUGIN_OPERATIONS.Modify,
                    widgetId: 'default_contents',
                    fn: (widget) => withMerekaMenuItems(widget, []),
                },
                """,
            ),
            (
                _mfe,
                "org.openedx.frontend.layout.header_desktop.v1",
                """
                {
                    op: PLUGIN_OPERATIONS.Modify,
                    widgetId: 'default_contents',
                    fn: (widget) => withMerekaHeaderDesktopShell(widget),
                },
                """,
            ),
            (
                _mfe,
                "org.openedx.frontend.layout.header_mobile.v1",
                """
                {
                    op: PLUGIN_OPERATIONS.Modify,
                    widgetId: 'default_contents',
                    fn: (widget) => withMerekaHeaderMobileShell(widget),
                },
                """,
            ),
            (
                _mfe,
                "org.openedx.frontend.layout.header_learning_course_info.v1",
                """
                {
                    op: PLUGIN_OPERATIONS.Modify,
                    widgetId: 'default_contents',
                    fn: (widget) => withMerekaHeaderLearningCourseInfo(widget),
                },
                """,
            ),
            (
                _mfe,
                "org.openedx.frontend.layout.header_learning_help.v1",
                """
                {
                    op: PLUGIN_OPERATIONS.Replace,
                    widget: {
                        id: 'mereka_layout_header_learning_help_link',
                        type: DIRECT_PLUGIN,
                        priority: 10,
                        RenderWidget: MerekaLearningHelpLink,
                    },
                },
                """,
            ),
            (
                _mfe,
                "org.openedx.frontend.layout.header_learning_logged_out_items.v1",
                """
                {
                    op: PLUGIN_OPERATIONS.Modify,
                    widgetId: 'default_contents',
                    fn: (widget) => withMerekaLearningLoggedOutItems(widget),
                },
                """,
            ),
            (
                _mfe,
                "org.openedx.frontend.layout.header_desktop_user_menu.v1",
                """
                {
                    op: PLUGIN_OPERATIONS.Modify,
                    widgetId: 'default_contents',
                    fn: (widget) => withMerekaHeaderUserMenuSupport(widget),
                },
                """,
            ),
            (
                _mfe,
                "org.openedx.frontend.layout.header_mobile_user_menu.v1",
                """
                {
                    op: PLUGIN_OPERATIONS.Modify,
                    widgetId: 'default_contents',
                    fn: (widget) => withMerekaHeaderUserMenuSupport(widget),
                },
                """,
            ),
            (
                _mfe,
                "org.openedx.frontend.layout.header_learning_user_menu.v1",
                """
                {
                    op: PLUGIN_OPERATIONS.Modify,
                    widgetId: 'default_contents',
                    fn: (widget) => withMerekaLearningUserMenuSupport(widget),
                },
                """,
            ),
            (
                _mfe,
                "org.openedx.frontend.layout.header_desktop_user_menu_toggle.v1",
                """
                {
                    op: PLUGIN_OPERATIONS.Modify,
                    widgetId: 'default_contents',
                    fn: (widget) => withMerekaHeaderUserMenuToggle(widget),
                },
                """,
            ),
            (
                _mfe,
                "org.openedx.frontend.layout.header_mobile_user_menu_trigger.v1",
                """
                {
                    op: PLUGIN_OPERATIONS.Modify,
                    widgetId: 'default_contents',
                    fn: (widget) => withMerekaMobileUserMenuTrigger(widget),
                },
                """,
            ),
            (
                _mfe,
                "org.openedx.frontend.layout.header_learning_user_menu_toggle.v1",
                """
                {
                    op: PLUGIN_OPERATIONS.Modify,
                    widgetId: 'default_contents',
                    fn: (widget) => withMerekaLearningUserMenuToggle(widget),
                },
                """,
            ),
        ])
