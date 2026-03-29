// Learning and courseware surface components.
// Includes course outline sidebar, learning header, progress helpers, and in-course slot hints.

// Learning course-outline sidebar branding card inserted into course-outline-sidebar slot.
// Wired into org.openedx.frontend.learning.course_outline_sidebar.v1.
const MerekaCourseOutlineSidebar = () => {
  const config = getConfig();
  const variant = getMerekaVariant(typeof window !== 'undefined' ? window.location.hostname : '', config);
  const shellCopy = getMerekaShellCopy(variant);
  const helpPath = variant.helpUrl || '/help/';

  return (
    <aside className="mereka-course-outline-sidebar mereka-shell-panel mb-3">
      <div className="mereka-shell-panel__content">
        <p className="mereka-shell-kicker">{shellCopy.learning.eyebrow}</p>
        <h3 className="mereka-course-outline-sidebar__title h6 mb-2">{variant.brand} course hub</h3>
        <p className="mereka-course-outline-sidebar__body mb-3">
          Keep pacing, support, and the next decision close while you move through each unit.
        </p>
        <a href={helpPath} className="mereka-shell-link mereka-shell-link--quiet" target="_blank" rel="noopener noreferrer">
          Visit help centre
        </a>
      </div>
    </aside>
  );
};

// Learning header slot for branded in-course context.
// Wired into org.openedx.frontend.layout.header_learning.v1.
const MerekaLearningCourseHeader = () => {
  const config = getConfig();
  const variant = getMerekaVariant(typeof window !== 'undefined' ? window.location.hostname : '', config);
  const shellCopy = getMerekaShellCopy(variant);

  return (
    <div className="mereka-learning-course-header mereka-shell-panel mb-3">
      <div className="mereka-shell-panel__content">
        <p className="mereka-shell-kicker">{shellCopy.learning.eyebrow}</p>
        <p className="mereka-learning-course-header__title mb-1">{shellCopy.learning.title}</p>
        <p className="mereka-learning-course-header__text mb-0">{shellCopy.learning.subtitle}</p>
        <div className="mereka-learning-course-header__meta">
          <span className="mereka-badge">Focus mode</span>
          <span className="mereka-learning-course-header__status">Stay oriented, keep your pace visible, and move forward deliberately.</span>
        </div>
      </div>
      <div className="mereka-learning-course-header__actions">
        <a href={variant.helpUrl} className="mereka-shell-link mereka-shell-link--quiet" target="_blank" rel="noopener noreferrer">
          {shellCopy.learning.supportCtaLabel}
        </a>
      </div>
    </div>
  );
};

// Learning tabs slot helper strip.
// Wired into org.openedx.frontend.learning.course_tab_links.v1.
const MerekaLearningCourseTabsHint = () => {
  return (
    <div className="mereka-learning-course-tabs-hint mb-2">
      <span>Track your progress, discussions, and key dates in one place.</span>
    </div>
  );
};

// Learning course breadcrumbs slot helper.
// Wired into org.openedx.frontend.learning.course_breadcrumbs.v1.
const MerekaLearningCourseBreadcrumbsHint = ({ courseId }) => {
  const safeCourseId = typeof courseId === 'string' ? courseId : '';
  return (
    <div className="mereka-learning-course-breadcrumbs-hint mb-2">
      <span className="mereka-badge me-2">Course</span>
      <span className="small text-muted">
        {safeCourseId ? `ID: ${safeCourseId}` : 'Track your pathway and continue with confidence.'}
      </span>
    </div>
  );
};

// Learning learner-tools slot helper.
// Wired into org.openedx.frontend.learning.learner_tools.v1.
const MerekaLearningLearnerToolsHint = ({ enrollmentMode, isStaff }) => {
  const mode = typeof enrollmentMode === 'string' && enrollmentMode ? enrollmentMode : 'audit';
  return (
    <div className="mereka-learning-learner-tools-hint mb-2">
      <span className="mereka-badge me-2">Learner tools</span>
      <span className="small text-muted">
        Mode: {mode}{isStaff ? ' · Staff utilities enabled' : ''}
      </span>
    </div>
  );
};

// Learning progress course-grade slot helper.
// Wired into org.openedx.frontend.learning.progress_tab_course_grade.v1.
const MerekaProgressCourseGradeHint = ({ courseId }) => {
  const safeCourseId = typeof courseId === 'string' ? courseId : '';
  return (
    <div className="mereka-progress-course-grade-hint mb-2">
      <span className="mereka-badge me-2">Grade</span>
      <span className="small text-muted">
        Keep progressing in {safeCourseId || 'your active course'} to strengthen outcomes.
      </span>
    </div>
  );
};

// Learning progress related-links slot helper.
// Wired into org.openedx.frontend.learning.progress_tab_related_links.v1.
const MerekaProgressRelatedLinksHint = () => {
  const config = getConfig();
  const variant = getMerekaVariant(typeof window !== 'undefined' ? window.location.hostname : '', config);
  const helpPath = variant.helpUrl || '/help/';
  return (
    <div className="mereka-progress-related-links-hint mb-2">
      <span className="mereka-badge me-2">Resources</span>
      <a href={helpPath} className="small">Need support? Visit the help centre.</a>
    </div>
  );
};

// Learning progress grade-breakdown slot helper.
// Wired into org.openedx.frontend.learning.progress_tab_grade_breakdown.v1.
const MerekaProgressGradeBreakdownHint = ({ courseId }) => {
  const safeCourseId = typeof courseId === 'string' ? courseId : '';
  return (
    <div className="mereka-progress-grade-breakdown-hint mb-2">
      <span className="mereka-badge me-2">Grade details</span>
      <span className="small text-muted">
        {safeCourseId ? `Review assessment trends for ${safeCourseId}.` : 'Review assessment trends and retry weak areas.'}
      </span>
    </div>
  );
};

// Learning unit-title slot helper.
// Wired into org.openedx.frontend.learning.unit_title.v1.
const MerekaLearningUnitTitleHint = ({ unit }) => {
  const title = unit && typeof unit.title === 'string' ? unit.title : '';
  return (
    <div className="mereka-learning-unit-title-hint mb-2">
      <span className="mereka-badge me-2">Unit</span>
      {title ? <span className="small text-muted">{title}</span> : null}
    </div>
  );
};

// Learning sequence-navigation slot helper.
// Wired into org.openedx.frontend.learning.sequence_navigation.v1.
const MerekaLearningSequenceNavigationHint = ({ unitId }) => {
  const safeUnitId = typeof unitId === 'string' ? unitId : '';
  return (
    <div className="mereka-learning-sequence-navigation-hint mb-2">
      <span className="mereka-badge me-2">Navigation</span>
      <span className="small text-muted">
        {safeUnitId ? `Current unit: ${safeUnitId}` : 'Move through each unit step by step.'}
      </span>
    </div>
  );
};

// Learning desktop outline-trigger slot helper.
// Wired into org.openedx.frontend.learning.course_outline_sidebar_trigger.v1.
const MerekaLearningOutlineSidebarTriggerHint = () => {
  return (
    <span className="mereka-learning-outline-sidebar-trigger-hint mereka-badge d-none d-xl-inline-block">
      Outline
    </span>
  );
};

// Learning mobile outline-trigger slot helper.
// Wired into org.openedx.frontend.learning.course_outline_mobile_sidebar_trigger.v1.
const MerekaLearningOutlineMobileSidebarTriggerHint = () => {
  return (
    <span className="mereka-learning-outline-mobile-sidebar-trigger-hint mereka-badge d-xl-none">
      Outline
    </span>
  );
};

// Learning course-home section-outline slot helper.
// Wired into org.openedx.frontend.learning.course_home_section_outline.v1.
const MerekaLearningCourseHomeSectionOutlineHint = () => {
  return (
    <div className="mereka-learning-course-home-section-outline-hint mb-2">
      <span className="mereka-badge me-2">Course home</span>
      <span className="small text-muted">Follow each section in sequence for best outcomes.</span>
    </div>
  );
};

// Learning course-recommendations slot helper.
// Wired into org.openedx.frontend.learning.course_recommendations.v1.
const MerekaLearningCourseRecommendationsHint = ({ variant }) => {
  const safeVariant = typeof variant === 'string' && variant ? variant : 'default';
  return (
    <div className="mereka-learning-course-recommendations-hint mb-2">
      <span className="mereka-badge me-2">Next step</span>
      <span className="small text-muted">Explore recommended pathways ({safeVariant}).</span>
    </div>
  );
};

// Learning iframe-loader slot helper.
// Wired into org.openedx.frontend.learning.content_iframe_loader.v1.
const MerekaLearningContentIFrameLoaderHint = () => {
  return (
    <div className="mereka-learning-content-iframe-loader-hint mb-2">
      <span className="mereka-badge me-2">Loading</span>
      <span className="small text-muted">Preparing learning content.</span>
    </div>
  );
};

// Learning iframe-error slot helper.
// Wired into org.openedx.frontend.learning.content_iframe_error.v1.
const MerekaLearningContentIFrameErrorHint = ({ errorMessage }) => {
  const message = typeof errorMessage === 'string' && errorMessage ? errorMessage : 'If this persists, contact support.';
  return (
    <div className="mereka-learning-content-iframe-error-hint mb-2">
      <span className="mereka-badge me-2">Content issue</span>
      <span className="small text-muted">{message}</span>
    </div>
  );
};

// Learning sequence-container slot helper.
// Wired into org.openedx.frontend.learning.sequence_container.v1.
const MerekaLearningSequenceContainerHint = () => {
  return (
    <div className="mereka-learning-sequence-container-hint mb-2">
      <span className="mereka-badge me-2">Sequence</span>
      <span className="small text-muted">Continue through the next unit to maintain momentum.</span>
    </div>
  );
};

// Learning gated-unit message slot helper.
// Wired into org.openedx.frontend.learning.gated_unit_content_message.v1.
const MerekaLearningGatedUnitContentMessageHint = () => {
  return (
    <div className="mereka-learning-gated-unit-content-message-hint mb-2">
      <span className="mereka-badge me-2">Access</span>
      <span className="small text-muted">Unlock this unit by completing the required prerequisites.</span>
    </div>
  );
};

// Learning next-unit top-nav trigger slot helper.
// Wired into org.openedx.frontend.learning.next_unit_top_nav_trigger.v1.
const MerekaLearningNextUnitTopNavTriggerHint = () => {
  return (
    <span className="mereka-learning-next-unit-top-nav-trigger-hint mereka-badge d-none d-lg-inline-block">
      Next unit
    </span>
  );
};

// Learning course-outline tab notifications slot helper.
// Wired into org.openedx.frontend.learning.course_outline_tab_notifications.v1.
const MerekaLearningCourseOutlineTabNotificationsHint = () => {
  return (
    <div className="mereka-learning-course-outline-tab-notifications-hint mb-2">
      <span className="mereka-badge me-2">Updates</span>
      <span className="small text-muted">Review announcements and due dates before you continue.</span>
    </div>
  );
};

// Learning notification-widget slot helper.
// Wired into org.openedx.frontend.learning.notification_widget.v1.
const MerekaLearningNotificationWidgetHint = () => {
  return (
    <div className="mereka-learning-notification-widget-hint mb-2">
      <span className="mereka-badge me-2">Alert</span>
      <span className="small text-muted">Stay on top of important learning notifications.</span>
    </div>
  );
};

// Learning notification-tray slot helper.
// Wired into org.openedx.frontend.learning.notification_tray.v1.
const MerekaLearningNotificationTrayHint = () => {
  return (
    <div className="mereka-learning-notification-tray-hint mb-2">
      <span className="mereka-badge me-2">Notification tray</span>
      <span className="small text-muted">Your recent course updates are grouped here.</span>
    </div>
  );
};

// Learning discussions/sidebar trigger slot helper.
// Wired into org.openedx.frontend.learning.notifications_discussions_sidebar_trigger.v1.
const MerekaLearningNotificationsDiscussionsSidebarTriggerHint = () => {
  return (
    <span className="mereka-learning-notifications-discussions-sidebar-trigger-hint mereka-badge">
      Discussions
    </span>
  );
};

// Learning discussions/sidebar slot helper.
// Wired into org.openedx.frontend.learning.notifications_discussions_sidebar.v1.
const MerekaLearningNotificationsDiscussionsSidebarHint = () => {
  return (
    <div className="mereka-learning-notifications-discussions-sidebar-hint mb-2">
      <span className="mereka-badge me-2">Community</span>
      <span className="small text-muted">Join discussions and track replies in one panel.</span>
    </div>
  );
};

// Learning course-exit view-courses slot helper.
// Wired into org.openedx.frontend.learning.course_exit_view_courses.v1.
const MerekaLearningCourseExitViewCoursesHint = () => {
  const config = getConfig();
  const baseUrl = (config.LMS_BASE_URL || '').replace(/\/$/, '');
  const variant = getMerekaVariant(typeof window !== 'undefined' ? window.location.hostname : '', config);
  return (
    <div className="mereka-learning-course-exit-view-courses-hint mb-2">
      <a href={getCatalogHref(baseUrl)} className="small">Browse more courses from {variant.brand}.</a>
    </div>
  );
};

// Learning course-exit dashboard-footnote slot helper.
// Wired into org.openedx.frontend.learning.course_exit_dashboard_footnote_link.v1.
const MerekaLearningCourseExitDashboardFootnoteLinkHint = () => {
  return (
    <div className="mereka-learning-course-exit-dashboard-footnote-link-hint mb-2">
      <a href={getLearnerHomeHref()} className="small">Return to your learning home for next actions.</a>
    </div>
  );
};
