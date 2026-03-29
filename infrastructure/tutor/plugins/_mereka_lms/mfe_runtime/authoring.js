// Studio/authoring hint components.
// All MerekaAuthoring* components wired into Studio frontend plugin slots.

const MerekaStudioFooter = () => {
  const config = getConfig();
  const baseUrl = (config.LMS_BASE_URL || '').replace(/\/$/, '');
  const hostname = typeof window !== 'undefined' ? window.location.hostname : '';
  const variant = getMerekaVariant(hostname, config);
  const siteName = config.SITE_NAME || variant.brand || 'Mereka Studio';

  return (
    <footer className="mereka-studio-footer" role="contentinfo">
      <div className="mereka-studio-footer__inner">
        <a href={baseUrl || '/'} className="mereka-studio-footer__logo-link">
          <img
            src={baseUrl ? `${baseUrl}${variant.logoUrl}` : variant.logoUrl}
            alt={`${siteName} logo`}
            className="mereka-studio-footer__logo"
          />
        </a>
        <p className="mereka-studio-footer__tagline">
          Built for creators. Built for teams. Built for growth.
        </p>
      </div>
    </footer>
  );
};

// Studio authoring course-unit sidebar helper.
// Wired into org.openedx.frontend.authoring.course_unit_sidebar.v1.
const MerekaAuthoringCourseUnitSidebarHint = () => {
  return (
    <aside className="mereka-authoring-course-unit-sidebar-hint p-3 rounded">
      <p className="mereka-badge mb-2">Studio Unit</p>
      <p className="mb-0 small text-muted">Use this sidebar to keep activities and outcomes aligned with your learning goals.</p>
    </aside>
  );
};

// Studio authoring course-outline sidebar helper.
// Wired into org.openedx.frontend.authoring.course_outline_sidebar.v1.
const MerekaAuthoringCourseOutlineSidebarHint = () => {
  return (
    <aside className="mereka-authoring-course-outline-sidebar-hint p-3 rounded">
      <p className="mereka-badge mb-2">Outline Guide</p>
      <p className="mb-0 small text-muted">Use this panel to keep weekly objectives and sequencing decisions aligned.</p>
    </aside>
  );
};

// Studio outline header actions helper.
// Wired into org.openedx.frontend.authoring.course_outline_header_actions.v1.
const MerekaAuthoringCourseOutlineHeaderActionsHint = () => {
  return (
    <div className="mereka-authoring-course-outline-header-actions-hint">
      <span className="mereka-badge">Mereka Studio</span>
    </div>
  );
};

// Studio unit header actions helper.
// Wired into org.openedx.frontend.authoring.course_unit_header_actions.v1.
const MerekaAuthoringCourseUnitHeaderActionsHint = () => {
  return (
    <div className="mereka-authoring-course-unit-header-actions-hint">
      <span className="small">Keep unit activities outcomes-focused for your learner path.</span>
    </div>
  );
};

// Studio outline page alerts helper.
// Wired into org.openedx.frontend.authoring.course_outline_page_alerts.v1.
const MerekaAuthoringCourseOutlinePageAlertsHint = () => {
  return (
    <div className="mereka-authoring-course-outline-page-alerts-hint">
      <span className="mereka-badge me-2">Quality Check</span>
      <span className="small">Review pacing and prerequisites before publishing this outline.</span>
    </div>
  );
};

// Studio video editor alerts helper.
// Wired into org.openedx.frontend.authoring.edit_video_alerts.v1.
const MerekaAuthoringEditVideoAlertsHint = () => {
  return (
    <div className="mereka-authoring-edit-video-alerts-hint">
      <span className="mereka-badge me-2">Video Ready</span>
      <span className="small">Confirm captions and transcript quality for accessibility.</span>
    </div>
  );
};

// Studio file editor alerts helper.
// Wired into org.openedx.frontend.authoring.edit_file_alerts.v1.
const MerekaAuthoringEditFileAlertsHint = () => {
  return (
    <div className="mereka-authoring-edit-file-alerts-hint">
      <span className="mereka-badge me-2">File Review</span>
      <span className="small">Check filename clarity and learner-facing download labels.</span>
    </div>
  );
};

// Studio additional course plugin helper.
// Wired into org.openedx.frontend.authoring.additional_course_plugin.v1.
const MerekaAuthoringAdditionalCoursePluginHint = () => {
  return (
    <div className="mereka-authoring-additional-course-plugin-hint">
      <span className="mereka-badge me-2">Course Plugin</span>
      <span className="small">Add external tools that match your program outcomes.</span>
    </div>
  );
};

// Studio additional course content plugin helper.
// Wired into org.openedx.frontend.authoring.additional_course_content_plugin.v1.
const MerekaAuthoringAdditionalCourseContentPluginHint = () => {
  return (
    <div className="mereka-authoring-additional-course-content-plugin-hint">
      <span className="mereka-badge me-2">Content Plugin</span>
      <span className="small">Use reusable content blocks to keep experiences consistent.</span>
    </div>
  );
};

// Studio outline subsection extra-actions helper.
// Wired into org.openedx.frontend.authoring.course_outline_subsection_card_extra_actions.v1.
const MerekaAuthoringOutlineSubsectionExtraActionsHint = () => {
  return (
    <div className="mereka-authoring-outline-subsection-extra-actions-hint">
      <span className="small">Subsection actions are available for sequencing and visibility controls.</span>
    </div>
  );
};

// Studio outline unit-card extra-actions helper.
// Wired into org.openedx.frontend.authoring.course_outline_unit_card_extra_actions.v1.
const MerekaAuthoringOutlineUnitExtraActionsHint = () => {
  return (
    <div className="mereka-authoring-outline-unit-extra-actions-hint">
      <span className="small">Unit-level actions help you align assessments with outcomes.</span>
    </div>
  );
};

// Studio course-unit sidebar v2 helper.
// Wired into org.openedx.frontend.authoring.course_unit_sidebar.v2.
const MerekaAuthoringCourseUnitSidebarV2Hint = () => {
  return (
    <div className="mereka-authoring-course-unit-sidebar-v2-hint">
      <span className="mereka-badge me-2">Studio Unit v2</span>
      <span className="small">Use quick controls to refine component flow and accessibility.</span>
    </div>
  );
};

// Studio files-upload page table helper.
// Wired into org.openedx.frontend.authoring.files_upload_page_table.v1.
const MerekaAuthoringFilesUploadPageTableHint = () => {
  return (
    <div className="mereka-authoring-files-upload-page-table-hint">
      <span className="small">Label files clearly so learners can discover the right assets fast.</span>
    </div>
  );
};

// Studio videos-upload page table helper.
// Wired into org.openedx.frontend.authoring.videos_upload_page_table.v1.
const MerekaAuthoringVideosUploadPageTableHint = () => {
  return (
    <div className="mereka-authoring-videos-upload-page-table-hint">
      <span className="small">Prioritize transcripts and descriptive titles for each uploaded video.</span>
    </div>
  );
};

// Studio video transcript translations helper.
// Wired into org.openedx.frontend.authoring.video_transcript_additional_translations_component.v1.
const MerekaAuthoringVideoTranscriptTranslationsHint = () => {
  return (
    <div className="mereka-authoring-video-transcript-translations-hint">
      <span className="small">Add multilingual transcript tracks to improve inclusivity and completion.</span>
    </div>
  );
};
