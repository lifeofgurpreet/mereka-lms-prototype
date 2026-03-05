{% raw %}
const normalizeHostname = (hostname) => {
  return (typeof hostname === 'string' ? hostname.toLowerCase() : '').replace(/^www\\./, '');
};

// Tenant branding + footer data contract.
// Base config shared by all tenants; per-tenant overrides below.
const MEREKA_BASE_VARIANT = {
  logoUrl: '/theme/logo-horizontal.svg',
  mobileLogoUrl: '/theme/logo.svg',
  helpUrl: 'https://help.mereka.io/',
  whatsapp: '601135271981',
  privacyUrl: 'https://legal.mereka.io/privacy-policy/',
  termsUrl: 'https://legal.mereka.io/',
  cookiesUrl: 'https://legal.mereka.io/#cookie-policy',
};

const MEREKA_SITE_VARIANTS = {
  'academyv2.mereka.io': {
    ...MEREKA_BASE_VARIANT,
    brand: 'Mereka Academy',
    copyrightHolder: 'MEREKA',
    supportEmail: 'support@mereka.io',
  },
  'academy.biji-biji.com': {
    ...MEREKA_BASE_VARIANT,
    brand: 'Biji-Biji Academy',
    copyrightHolder: 'Biji-Biji Initiative',
    supportEmail: 'techadmin@biji-biji.com',
  },
  'skillourfuture.academy.mereka.io': {
    ...MEREKA_BASE_VARIANT,
    brand: 'Skill Our Future Academy',
    copyrightHolder: 'MEREKA',
    supportEmail: 'support@mereka.io',
  },
};

const getMerekaVariant = (hostname, config) => {
  const normalizedHostname = normalizeHostname(hostname);
  const fallbackBrand = (typeof config !== 'undefined' && config.SITE_NAME) || 'Mereka Academy';
  const fallbackPlatform = (typeof config !== 'undefined' && config.PLATFORM_NAME) || 'MEREKA';
  const knownVariant = MEREKA_SITE_VARIANTS[normalizedHostname];

  if (knownVariant) {
    return knownVariant;
  }

  // Unknown host fallback: keep shell rendering deterministic for dev/staging/new tenants.
  return {
    ...MEREKA_BASE_VARIANT,
    brand: fallbackBrand,
    copyrightHolder: fallbackPlatform,
    supportEmail: 'support@mereka.io',
  };
};

const getLogoHref = (baseUrl) => {
  return baseUrl ? `${baseUrl}/dashboard` : '/dashboard';
};

const withMerekaMenuItems = (widget, menuItems = []) => {
  const widgetProps = (widget && widget.RenderWidget && widget.RenderWidget.props) || {};
  const defaultMenu = widgetProps.menu;
  const config = getConfig();
  const hostname = typeof window !== 'undefined' ? window.location.hostname : '';
  const variant = getMerekaVariant(hostname, config);
  const menuItemsWithSupport = [
    ...menuItems,
    ...(typeof variant?.helpUrl === 'string' && variant.helpUrl
      ? [{ type: 'item', href: variant.helpUrl, content: 'Support' }]
      : []),
  ];

  if (!Array.isArray(defaultMenu) || !Array.isArray(menuItems)) {
    return widget;
  }

  if (defaultMenu.length === 0) {
    return {
      ...widget,
      content: {
        ...(widget.content || {}),
        menu: menuItemsWithSupport,
      },
    };
  }

  const existingHrefs = new Set(defaultMenu.map((item) => (item && item.href ? item.href : item)));
  const sanitizedMenuItems = menuItemsWithSupport.filter((item) => item && item.href && !existingHrefs.has(item.href));
  if (sanitizedMenuItems.length === 0) {
    return widget;
  }

  return {
    ...widget,
    content: {
      ...(widget.content || {}),
      menu: [...defaultMenu, ...sanitizedMenuItems],
    },
  };
};

const withMerekaLearningLoggedOutItems = (widget) => {
  const widgetContent = (widget && widget.content) || {};
  const defaultButtons = Array.isArray(widgetContent.buttonsInfo) ? widgetContent.buttonsInfo : null;
  if (!Array.isArray(defaultButtons)) {
    return widget;
  }

  const config = getConfig();
  const hostname = typeof window !== 'undefined' ? window.location.hostname : '';
  const variant = getMerekaVariant(hostname, config);
  const existingHrefs = new Set(defaultButtons.map((item) => (item && item.href ? item.href : '')));
  const nextButtons = [...defaultButtons];

  if (!existingHrefs.has('/dashboard/courses')) {
    nextButtons.push({
      href: '/dashboard/courses',
      message: 'Discover Courses',
    });
  }

  if (typeof variant?.helpUrl === 'string' && variant.helpUrl && !existingHrefs.has(variant.helpUrl)) {
    nextButtons.push({
      href: variant.helpUrl,
      message: 'Support',
    });
  }

  return {
    ...widget,
    content: {
      ...widgetContent,
      buttonsInfo: nextButtons,
    },
  };
};

const withMerekaHeaderUserMenuSupport = (widget) => {
  const widgetContent = (widget && widget.content) || {};
  const defaultMenuGroups = Array.isArray(widgetContent.menu) ? widgetContent.menu : null;
  if (!Array.isArray(defaultMenuGroups)) {
    return widget;
  }

  const config = getConfig();
  const hostname = typeof window !== 'undefined' ? window.location.hostname : '';
  const variant = getMerekaVariant(hostname, config);
  const helpUrl = (typeof variant?.helpUrl === 'string' && variant.helpUrl) ? variant.helpUrl : '';
  if (!helpUrl) {
    return widget;
  }

  const supportItem = { type: 'item', href: helpUrl, content: 'Support' };
  const existingHrefs = new Set(
    defaultMenuGroups.flatMap((group) =>
      Array.isArray(group?.items)
        ? group.items.map((item) => (item && item.href ? item.href : ''))
        : []
    )
  );
  if (existingHrefs.has(helpUrl)) {
    return widget;
  }

  const nextGroups = [...defaultMenuGroups];
  const lastIndex = nextGroups.length - 1;
  if (lastIndex >= 0 && Array.isArray(nextGroups[lastIndex]?.items)) {
    nextGroups[lastIndex] = {
      ...nextGroups[lastIndex],
      items: [...nextGroups[lastIndex].items, supportItem],
    };
  } else {
    nextGroups.push({ items: [supportItem] });
  }

  return {
    ...widget,
    content: {
      ...widgetContent,
      menu: nextGroups,
    },
  };
};

const withMerekaLearningUserMenuSupport = (widget) => {
  const widgetContent = (widget && widget.content) || {};
  const defaultItems = Array.isArray(widgetContent.items) ? widgetContent.items : null;
  if (!Array.isArray(defaultItems)) {
    return widget;
  }

  const config = getConfig();
  const hostname = typeof window !== 'undefined' ? window.location.hostname : '';
  const variant = getMerekaVariant(hostname, config);
  const helpUrl = (typeof variant?.helpUrl === 'string' && variant.helpUrl) ? variant.helpUrl : '';
  if (!helpUrl) {
    return widget;
  }

  const existingHrefs = new Set(defaultItems.map((item) => (item && item.href ? item.href : '')));
  if (existingHrefs.has(helpUrl)) {
    return widget;
  }

  return {
    ...widget,
    content: {
      ...widgetContent,
      items: [
        ...defaultItems,
        {
          href: helpUrl,
          message: 'Support',
        },
      ],
    },
  };
};

const appendClassName = (baseValue, classNameToAppend) => {
  const baseTokens = typeof baseValue === 'string' ? baseValue.split(/\\s+/).filter(Boolean) : [];
  const appendTokens = typeof classNameToAppend === 'string' ? classNameToAppend.split(/\\s+/).filter(Boolean) : [];
  const merged = [...new Set([...baseTokens, ...appendTokens])];
  return merged.join(' ');
};

const withMerekaHeaderShellClass = (widget, classNameToAppend) => {
  const widgetContent = (widget && widget.content) || {};
  if (!widgetContent || typeof widgetContent !== 'object') {
    return widget;
  }

  const nextClassName = appendClassName(widgetContent.className, classNameToAppend);
  if (!nextClassName || nextClassName === widgetContent.className) {
    return widget;
  }

  return {
    ...widget,
    content: {
      ...widgetContent,
      className: nextClassName,
    },
  };
};

const withMerekaUserMenuToggleClass = (widget, classNameToAppend) => {
  const widgetContent = (widget && widget.content) || {};
  if (!widgetContent || typeof widgetContent !== 'object') {
    return widget;
  }

  let touched = false;
  const nextContent = { ...widgetContent };
  const nextClassName = appendClassName(nextContent.className, classNameToAppend);
  if (nextClassName && nextClassName !== nextContent.className) {
    nextContent.className = nextClassName;
    touched = true;
  }

  if (nextContent.buttonProps && typeof nextContent.buttonProps === 'object') {
    const nextButtonProps = { ...nextContent.buttonProps };
    const nextButtonClassName = appendClassName(nextButtonProps.className, classNameToAppend);
    if (nextButtonClassName && nextButtonClassName !== nextButtonProps.className) {
      nextButtonProps.className = nextButtonClassName;
      touched = true;
    }
    if (touched) {
      nextContent.buttonProps = nextButtonProps;
    }
  }

  if (!touched) {
    return widget;
  }

  return {
    ...widget,
    content: nextContent,
  };
};

const withMerekaHeaderUserMenuToggle = (widget) => {
  return withMerekaUserMenuToggleClass(widget, 'mereka-header-user-menu-toggle');
};

const withMerekaMobileUserMenuTrigger = (widget) => {
  return withMerekaUserMenuToggleClass(widget, 'mereka-mobile-user-menu-trigger');
};

const withMerekaLearningUserMenuToggle = (widget) => {
  return withMerekaUserMenuToggleClass(widget, 'mereka-learning-user-menu-toggle');
};

const withMerekaHeaderDesktopShell = (widget) => {
  return withMerekaHeaderShellClass(widget, 'mereka-header-desktop-shell');
};

const withMerekaHeaderMobileShell = (widget) => {
  return withMerekaHeaderShellClass(widget, 'mereka-header-mobile-shell');
};

const withMerekaHeaderLearningCourseInfo = (widget) => {
  return withMerekaHeaderShellClass(widget, 'mereka-header-learning-course-info');
};

const withMerekaStudioHeaderSearchButton = (widget) => {
  return withMerekaUserMenuToggleClass(widget, 'mereka-studio-header-search-button');
};

// Custom Mereka header-logo component (Direct plugin — registered via header_logo slot)
// Wired into org.openedx.frontend.layout.header_logo.v1 by PLUGIN_SLOTS in mereka_lms.py
const MerekaHeaderLogo = () => {
  const config = getConfig();
  const baseUrl = (typeof config !== 'undefined' && typeof config.LMS_BASE_URL === 'string' ? config.LMS_BASE_URL : '').replace(/\\/$/, '');
  const hostname = typeof window !== 'undefined' ? window.location.hostname : '';
  const variant = getMerekaVariant(hostname, config);
  const isMobileViewport = typeof window !== 'undefined' ? window.matchMedia('(max-width: 767px)').matches : false;
  const selectedLogo = isMobileViewport && variant.mobileLogoUrl ? variant.mobileLogoUrl : variant.logoUrl;

  return (
    <a href={getLogoHref(baseUrl)} aria-label={`${variant.brand} dashboard`} className="mereka-header-logo">
      <img src={baseUrl ? `${baseUrl}${selectedLogo}` : selectedLogo} alt={`${variant.brand} logo`} />
    </a>
  );
};

// Learning-header help link replacement for org.openedx.frontend.layout.header_learning_help.v1.
const MerekaLearningHelpLink = () => {
  const config = getConfig();
  const hostname = typeof window !== 'undefined' ? window.location.hostname : '';
  const variant = getMerekaVariant(hostname, config);
  const helpUrl = (typeof variant?.helpUrl === 'string' && variant.helpUrl) ? variant.helpUrl : 'https://help.mereka.io/';
  return (
    <a href={helpUrl} className="mereka-learning-help-link" target="_blank" rel="noopener noreferrer">
      Support
    </a>
  );
};

const MerekaAuthnLoginBranding = () => {
  const config = getConfig();
  const hostname = typeof window !== 'undefined' ? window.location.hostname : '';
  const variant = getMerekaVariant(hostname, config);

  return (
    <div className="mereka-authn-login-branding">
      <a href="/" className="mereka-authn-login-branding__logo">
        <img
          src={variant.logoUrl}
          alt={`${variant.brand} logo`}
          className="mereka-authn-login-branding__logo-img"
        />
      </a>
      <h2 className="mereka-authn-login-branding__title">Welcome back</h2>
      <p className="mereka-authn-login-branding__subtitle">
        Sign in to continue with your {variant.brand} workspace.
      </p>
    </div>
  );
};

const MerekaStudioFooter = () => {
  const config = getConfig();
  const baseUrl = (config.LMS_BASE_URL || '').replace(/\\/$/, '');
  const siteName = config.SITE_NAME || 'Mereka Studio';

  return (
    <footer className="mereka-studio-footer" role="contentinfo">
      <div className="mereka-studio-footer__inner">
        <a href={baseUrl || '/'} className="mereka-studio-footer__logo-link">
          <img
            src="/theme/logo-horizontal.svg"
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

// Custom learner-dashboard sidebar widget for branded links and support prompts.
// Registered via org.openedx.frontend.learner_dashboard.widget_sidebar.v1.
const MerekaLearnerSidebarWidget = () => {
  const config = getConfig();
  const baseUrl = (config.LMS_BASE_URL || '').replace(/\\/$/, '');
  const variant = getMerekaVariant(typeof window !== 'undefined' ? window.location.hostname : '', config);
  const dashboardPath = baseUrl ? `${baseUrl}/dashboard` : '/dashboard';
  const coursesPath = baseUrl ? `${baseUrl}/dashboard/courses` : '/dashboard/courses';
  const helpPath = variant.helpUrl || '/help/';

  return (
    <div className="mereka-learner-sidebar-widget">
      <p className="h5 mb-2">{variant.brand} quick links</p>
      <a href={dashboardPath} className="d-block mb-1">Dashboard</a>
      <a href={coursesPath} className="d-block mb-1">My Courses</a>
      <a href={helpPath} className="d-block">Support</a>
    </div>
  );
};

// Learner-dashboard empty-state override for no enrolled courses.
// Wired into org.openedx.frontend.learner_dashboard.no_courses_view.v1.
const MerekaNoCoursesView = () => {
  const config = getConfig();
  const baseUrl = (config.LMS_BASE_URL || '').replace(/\\/$/, '');
  const dashboardPath = baseUrl ? `${baseUrl}/dashboard` : '/dashboard';
  const discoverPath = baseUrl ? `${baseUrl}/dashboard/courses` : '/dashboard/courses';

  return (
    <div className="mereka-no-courses-view p-4 text-center">
      <h2 className="h4 mb-3">Welcome to your learner dashboard</h2>
      <p className="mereka-no-courses-view__message mb-3">
        Your dashboard is ready, but you are not enrolled in any courses yet.
      </p>
      <div className="mereka-no-courses-view__actions">
        <a href={discoverPath} className="btn btn-brand me-2 mb-2">Discover courses</a>
        <a href={dashboardPath} className="btn btn-outline-primary mb-2">Back to dashboard</a>
      </div>
    </div>
  );
};

// Learner-dashboard course-list slot surface (high-visibility post-login branding).
// Wired into org.openedx.frontend.learner_dashboard.course_list.v1.
const MerekaDashboardHeader = () => {
  const config = getConfig();
  const variant = getMerekaVariant(typeof window !== 'undefined' ? window.location.hostname : '', config);

  return (
    <section className="mereka-dashboard-header-slot mb-3">
      <p className="mereka-badge mb-2">Mereka Learning</p>
      <h2 className="h4 mb-1">Welcome back to {variant.brand}</h2>
      <p className="mb-0 small text-muted">Pick up where you left off and keep your momentum.</p>
    </section>
  );
};

// Learner-dashboard course-card banner accent slot.
// Wired into org.openedx.frontend.learner_dashboard.course_card_banner.v1.
const MerekaCourseCardAccent = ({ cardId }) => {
  const safeCardId = typeof cardId === 'string' ? cardId : '';
  return (
    <div className="mereka-course-card-accent">
      <span className="mereka-badge">Mereka Curated</span>
      {safeCardId ? <span className="mereka-course-card-accent__meta">{safeCardId}</span> : null}
    </div>
  );
};

// Learner-dashboard course-card action slot helper.
// Wired into org.openedx.frontend.learner_dashboard.course_card_action.v1.
const MerekaCourseCardActionHint = () => {
  return (
    <div className="mereka-course-card-action-hint">
      <span>Keep your weekly learning streak active.</span>
    </div>
  );
};

// Learner-dashboard modal helper slot.
// Wired into org.openedx.frontend.learner_dashboard.dashboard_modal.v1.
const MerekaDashboardModalHint = () => {
  return (
    <div className="mereka-dashboard-modal-hint">
      <p className="mereka-badge mb-2">Mereka update</p>
      <p className="small mb-0">New curated pathways are available for your active learning goals.</p>
    </div>
  );
};

// Learning course-outline sidebar branding card inserted into course-outline-sidebar slot.
// Wired into org.openedx.frontend.learning.course_outline_sidebar.v1.
const MerekaCourseOutlineSidebar = () => {
  const config = getConfig();
  const variant = getMerekaVariant(typeof window !== 'undefined' ? window.location.hostname : '', config);
  const helpPath = variant.helpUrl || '/help/';

  return (
    <aside className="mereka-course-outline-sidebar mb-3 border rounded p-3">
      <h3 className="h6 mb-2">{variant.brand} Course Hub</h3>
      <p className="small text-muted mb-3">
        Use this area to find support resources while learning.
      </p>
      <a href={helpPath} className="d-inline-block">Help centre</a>
    </aside>
  );
};

// Learning header slot for branded in-course context.
// Wired into org.openedx.frontend.layout.header_learning.v1.
const MerekaLearningCourseHeader = () => {
  const config = getConfig();
  const variant = getMerekaVariant(typeof window !== 'undefined' ? window.location.hostname : '', config);

  return (
    <div className="mereka-learning-course-header mb-3">
      <span className="mereka-badge">Learning</span>
      <p className="mereka-learning-course-header__text mb-0">
        You are learning with {variant.brand}.
      </p>
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
  const variant = getMerekaVariant(typeof window !== 'undefined' ? window.location.hostname : '', config);
  return (
    <div className="mereka-learning-course-exit-view-courses-hint mb-2">
      <a href="/dashboard/courses" className="small">Browse more courses from {variant.brand}.</a>
    </div>
  );
};

// Learning course-exit dashboard-footnote slot helper.
// Wired into org.openedx.frontend.learning.course_exit_dashboard_footnote_link.v1.
const MerekaLearningCourseExitDashboardFootnoteLinkHint = () => {
  return (
    <div className="mereka-learning-course-exit-dashboard-footnote-link-hint mb-2">
      <a href="/dashboard" className="small">Return to your dashboard for next actions.</a>
    </div>
  );
};

// Learning progress certificate status branding and context card.
// Wired into org.openedx.frontend.learning.progress_certificate_status.v1.
const MerekaProgressCertificateStatus = ({ courseId }) => {
  const config = getConfig();
  const variant = getMerekaVariant(typeof window !== 'undefined' ? window.location.hostname : '', config);
  const safeCourseId = typeof courseId === 'string' ? courseId : '';

  return (
    <div className="mereka-progress-certificate-status my-3 p-3 rounded">
      <p className="mb-1 fw-semibold">Progress snapshot</p>
      <p className="mb-0 small text-muted">
        {variant.brand} Learning —{safeCourseId ? ` course ${safeCourseId}` : ''} is active. Keep completing units to unlock your certificate.
      </p>
    </div>
  );
};

// Account ID verification helper slot.
// Wired into org.openedx.frontend.account.id_verification_page.v1.
const MerekaAccountIdVerificationHint = () => {
  return (
    <p className="mereka-account-id-verification-hint mb-2">
      ID verification details are reviewed by your learning administrator for secure certificate issuance.
    </p>
  );
};

// Enterprise profile section for account/profile additional profile field slots.
// Wired into org.openedx.frontend.account.additional_profile_fields.v1 and
// org.openedx.frontend.profile.additional_profile_fields.v1.
const MerekaAdditionalProfileFields = () => {
  const config = getConfig();
  const variant = getMerekaVariant(typeof window !== 'undefined' ? window.location.hostname : '', config);

  return (
    <section className="mereka-additional-profile-fields mb-3">
      <h2 className="h5 mb-2">Enterprise profile details</h2>
      <p className="small mb-3">For {variant.brand} workplace setups, these fields are preconfigured by your admin team.</p>
      <ul className="mereka-additional-profile-fields__list list-unstyled mb-0">
        <li className="mb-2">Organization: <strong>{variant.brand}</strong></li>
        <li className="mb-2">Job title: <strong>—</strong></li>
        <li className="mb-2">Department: <strong>—</strong></li>
      </ul>
    </section>
  );
};

// Custom Mereka footer component (Direct plugin — registered via footer_slot)
// Wired into org.openedx.frontend.layout.footer.v1 by PLUGIN_SLOTS in mereka_lms.py
const MerekaFooter = () => {
  const config = getConfig();
  const baseUrl = (config.LMS_BASE_URL || '').replace(/\\/$/, '');
  const currentYear = new Date().getFullYear();
  const hostname = typeof window !== 'undefined' ? window.location.hostname : '';
  const variant = getMerekaVariant(hostname, config);
  const logoPath = variant.logoUrl || '/theme/logo-horizontal.svg';
  const logoUrl = baseUrl ? `${baseUrl}${logoPath}` : logoPath;

  const socialLinks = [
    { name: 'TikTok', url: 'https://www.tiktok.com/@mereka.io', icon: 'M19.59 6.69a4.83 4.83 0 0 1-3.77-4.25V2h-3.45v13.67a2.89 2.89 0 0 1-5.2 1.74 2.89 2.89 0 0 1 2.31-4.64 2.93 2.93 0 0 1 .88.13V9.4a6.84 6.84 0 0 0-1-.05A6.33 6.33 0 0 0 5 20.1a6.34 6.34 0 0 0 10.86-4.43v-7a8.16 8.16 0 0 0 4.77 1.52v-3.4a4.85 4.85 0 0 1-1-.1z' },
    { name: 'Instagram', url: 'https://www.instagram.com/mereka.io/', icon: 'M12 2.163c3.204 0 3.584.012 4.85.07 3.252.148 4.771 1.691 4.919 4.919.058 1.265.069 1.645.069 4.849 0 3.205-.012 3.584-.069 4.849-.149 3.225-1.664 4.771-4.919 4.919-1.266.058-1.644.07-4.85.07-3.204 0-3.584-.012-4.849-.07-3.26-.149-4.771-1.699-4.919-4.92-.058-1.265-.07-1.644-.07-4.849 0-3.204.013-3.583.07-4.849.149-3.227 1.664-4.771 4.919-4.919 1.266-.057 1.645-.069 4.849-.069zm0-2.163c-3.259 0-3.667.014-4.947.072-4.358.2-6.78 2.618-6.98 6.98-.059 1.281-.073 1.689-.073 4.948 0 3.259.014 3.668.072 4.948.2 4.358 2.618 6.78 6.98 6.98 1.281.058 1.689.072 4.948.072 3.259 0 3.668-.014 4.948-.072 4.354-.2 6.782-2.618 6.979-6.98.059-1.28.073-1.689.073-4.948 0-3.259-.014-3.667-.072-4.947-.196-4.354-2.617-6.78-6.979-6.98-1.281-.059-1.69-.073-4.949-.073zm0 5.838c-3.403 0-6.162 2.759-6.162 6.162s2.759 6.163 6.162 6.163 6.162-2.759 6.162-6.163c0-3.403-2.759-6.162-6.162-6.162zm0 10.162c-2.209 0-4-1.79-4-4 0-2.209 1.791-4 4-4s4 1.791 4 4c0 2.21-1.791 4-4 4zm6.406-11.845c-.796 0-1.441.645-1.441 1.44s.645 1.44 1.441 1.44c.795 0 1.439-.645 1.439-1.44s-.644-1.44-1.439-1.44z' },
    { name: 'Facebook', url: 'https://www.facebook.com/mereka.io', icon: 'M24 12.073c0-6.627-5.373-12-12-12s-12 5.373-12 12c0 5.99 4.388 10.954 10.125 11.854v-8.385H7.078v-3.47h3.047V9.43c0-3.007 1.792-4.669 4.533-4.669 1.312 0 2.686.235 2.686.235v2.953H15.83c-1.491 0-1.956.925-1.956 1.874v2.25h3.328l-.532 3.47h-2.796v8.385C19.612 23.027 24 18.062 24 12.073z' },
    { name: 'LinkedIn', url: 'https://www.linkedin.com/company/mereka/', icon: 'M20.447 20.452h-3.554v-5.569c0-1.328-.027-3.037-1.852-3.037-1.853 0-2.136 1.445-2.136 2.939v5.667H9.351V9h3.414v1.561h.046c.477-.9 1.637-1.85 3.37-1.85 3.601 0 4.267 2.37 4.267 5.455v6.286zM5.337 7.433c-1.144 0-2.063-.926-2.063-2.065 0-1.138.92-2.063 2.063-2.063 1.14 0 2.064.925 2.064 2.063 0 1.139-.925 2.065-2.064 2.065zm1.782 13.019H3.555V9h3.564v11.452zM22.225 0H1.771C.792 0 0 .774 0 1.729v20.542C0 23.227.792 24 1.771 24h20.451C23.2 24 24 23.227 24 22.271V1.729C24 .774 23.2 0 22.222 0h.003z' },
    { name: 'YouTube', url: 'https://www.youtube.com/channel/UCCyMH5KIZeCMchjMKl7RWxg', icon: 'M23.498 6.186a3.016 3.016 0 0 0-2.122-2.136C19.505 3.545 12 3.545 12 3.545s-7.505 0-9.377.505A3.017 3.017 0 0 0 .502 6.186C0 8.07 0 12 0 12s0 3.93.502 5.814a3.016 3.016 0 0 0 2.122 2.136c1.871.505 9.376.505 9.376.505s7.505 0 9.377-.505a3.015 3.015 0 0 0 2.122-2.136C24 15.93 24 12 24 12s0-3.93-.502-5.814zM9.545 15.568V8.432L15.818 12l-6.273 3.568z' },
  ];

  // navLinks: corporate-global links are the same for all tenants.
  // Help Centre and Support email are resolved from the tenant data contract (variant).
  const navLinks = [
    { label: 'About', url: 'https://corporate.mereka.io/about-us' },
    { label: 'Andragogy', url: 'https://corporate.mereka.io/andragogy' },
    { label: 'Portfolio', url: 'https://corporate.mereka.io/portfolio' },
    { label: 'Team', url: 'https://corporate.mereka.io/our-team' },
    { label: 'Careers', url: 'https://corporate.mereka.io/work-with-us' },
    { label: 'Ecosystem', url: 'https://corporate.mereka.io/ecosystem' },
    { label: 'Blog', url: 'https://corporate.mereka.io/blog' },
    { label: 'Help Centre', url: variant.helpUrl },
    { label: 'Contact Support', url: 'mailto:' + variant.supportEmail },
  ];

  const corporateLinks = [
    { label: 'Accelerate Talent', url: 'https://corporate.mereka.io/academy/funders' },
    { label: 'Create Online Course', url: 'https://corporate.mereka.io/academy/create-online-courses' },
    { label: 'Build a Makerspace', url: 'https://corporate.mereka.io/academy/makerspace' },
  ];

  const marketplaceUserLinks = [
    { label: 'Experiences', url: 'https://mereka.io/experiences' },
    { label: 'Experts', url: 'https://mereka.io/experts' },
    { label: 'Expertise', url: 'https://mereka.io/expertise' },
    { label: 'Hubs', url: 'https://mereka.io/hubs' },
    { label: 'Spaces', url: 'https://corporate.mereka.io/space' },
  ];

  const marketplaceBusinessLinks = [
    { label: 'Pricing', url: 'https://hubs.mereka.io/pricing' },
    { label: 'Solutions', url: 'https://hubs.mereka.io/howitworks' },
  ];

  const academyLinks = [
    { label: 'Future of Work', url: 'https://corporate.mereka.io/academy/future-of-work' },
    { label: 'Digital Entrepreneur', url: 'https://corporate.mereka.io/academy/digital-entrepreneur' },
    { label: 'All Courses', url: 'https://corporate.mereka.io/academy/all-courses' },
  ];

  const spaceLinks = [
    { label: 'Mereka @ Publika', url: 'https://corporate.mereka.io/publika' },
    { label: 'Our Labs', url: 'https://corporate.mereka.io/space#labs' },
    { label: 'Bespoke Design', url: 'https://corporate.mereka.io/space/innovate#products' },
    { label: 'Host Events', url: 'https://corporate.mereka.io/space#event-cta' },
  ];

  const SocialIcon = ({ d }) => (
    <svg
      className="mereka-footer__social-icon"
      style={socialIconStyle}
      fill="currentColor"
      viewBox="0 0 24 24"
    >
      <path d={d} />
    </svg>
  );

  const WhatsAppIcon = () => (
    <svg
      className="mereka-footer__social-icon"
      style={whatsappIconStyle}
      fill="currentColor"
      viewBox="0 0 24 24"
    >
      <path d="M.057 24l1.687-6.163c-1.041-1.804-1.588-3.849-1.587-5.946.003-6.556 5.338-11.891 11.893-11.891 3.181.001 6.167 1.24 8.413 3.488 2.245 2.248 3.481 5.236 3.48 8.414-.003 6.557-5.338 11.892-11.893 11.892-1.99-.001-3.951-.5-5.688-1.448l-6.305 1.654zm6.597-3.807c1.676.995 3.276 1.591 5.392 1.592 5.448 0 9.886-4.434 9.889-9.885.002-5.462-4.415-9.89-9.881-9.892-5.452 0-9.887 4.434-9.889 9.884-.001 2.225.651 3.891 1.746 5.634l-.999 3.648 3.742-.981zm11.387-5.464c-.074-.124-.272-.198-.57-.347-.297-.149-1.758-.868-2.031-.967-.272-.099-.47-.149-.669.149-.198.297-.768.967-.941 1.165-.173.198-.347.223-.644.074-.297-.149-1.255-.462-2.39-1.475-.883-.788-1.48-1.761-1.653-2.059-.173-.297-.018-.458.13-.606.134-.133.297-.347.446-.521.151-.172.2-.296.3-.495.099-.198.05-.372-.025-.521-.075-.148-.669-1.611-.916-2.206-.242-.579-.487-.501-.669-.51l-.57-.01c-.198 0-.52.074-.792.372s-1.04 1.016-1.04 2.479 1.065 2.876 1.213 3.074c.149.198 2.095 3.2 5.076 4.487.709.306 1.263.489 1.694.626.712.226 1.36.194 1.872.118.571-.085 1.758-.719 2.006-1.413.248-.695.248-1.29.173-1.414z" />
    </svg>
  );

  const socialIconStyle = {
    width: '20px',
    height: '20px',
  };

  const whatsappIconStyle = {
    width: '20px',
    height: '20px',
    color: '#25D366',
  };

  return (
    <footer className="mereka-footer mereka-footer--v2" role="contentinfo">
      {/* Zone 1: Social Row */}
      <div className="footer-social">
        <div className="footer-container">
          <a href={baseUrl || '/'} className="footer-logo-link">
            {logoUrl ? <img src={logoUrl} alt={variant.brand + ' logo'} className="footer-logo-img" /> : null}
            <span className="footer-brand-name">mereka</span>
          </a>
          <div className="footer-social-icons">
            {socialLinks.map(s => (
              <a key={s.name} href={s.url} target="_blank" rel="noopener noreferrer" aria-label={s.name} className="footer-social-link">
                <SocialIcon d={s.icon} />
              </a>
            ))}
          </div>
        </div>
      </div>

      {/* Zone 2: Nav Strip */}
      <div className="footer-nav">
        <div className="footer-container">
          <nav className="footer-nav-links">
            {navLinks.map(l => (
              <a key={l.label} href={l.url} target="_blank" rel="noopener noreferrer">{l.label}</a>
            ))}
          </nav>
          <a href={'https://wa.me/' + variant.whatsapp} target="_blank" rel="noopener noreferrer" className="footer-whatsapp-btn">
            <WhatsAppIcon /> Contact Us
          </a>
        </div>
      </div>

      {/* Zone 3: 4-Column Body */}
      <div className="footer-body">
        <div className="footer-container footer-columns">
          <div className="footer-column">
            <h4 className="footer-column-title">Corporate</h4>
            <ul>{corporateLinks.map(l => <li key={l.label}><a href={l.url} target="_blank" rel="noopener noreferrer">{l.label}</a></li>)}</ul>
          </div>
          <div className="footer-column footer-column--wide">
            <h4 className="footer-column-title">Marketplace</h4>
            <div className="footer-marketplace-grid">
              <div>
                <p className="footer-sub-heading">USERS</p>
                <ul>{marketplaceUserLinks.map(l => <li key={l.label}><a href={l.url} target="_blank" rel="noopener noreferrer">{l.label}</a></li>)}</ul>
              </div>
              <div>
                <p className="footer-sub-heading">BUSINESS</p>
                <ul>{marketplaceBusinessLinks.map(l => <li key={l.label}><a href={l.url} target="_blank" rel="noopener noreferrer">{l.label}</a></li>)}</ul>
                <p className="footer-app-label">Manage your bookings</p>
                <div className="footer-app-badges">
                  <a href="https://apps.apple.com/id/app/mereka-hubs/id6473277964" target="_blank" rel="noopener noreferrer" className="footer-badge">App Store</a>
                  <a href="https://play.google.com/store/apps/details?id=io.mereka.hubs" target="_blank" rel="noopener noreferrer" className="footer-badge">Google Play</a>
                </div>
                <a href="https://mereka.io/welcome/hub" target="_blank" rel="noopener noreferrer" className="footer-cta-btn">Become a Hub</a>
              </div>
            </div>
          </div>
          <div className="footer-column">
            <h4 className="footer-column-title">Academy</h4>
            <ul>{academyLinks.map(l => <li key={l.label}><a href={l.url} target="_blank" rel="noopener noreferrer">{l.label}</a></li>)}</ul>
          </div>
          <div className="footer-column">
            <h4 className="footer-column-title">Space</h4>
            <ul>{spaceLinks.map(l => <li key={l.label}><a href={l.url} target="_blank" rel="noopener noreferrer">{l.label}</a></li>)}</ul>
          </div>
        </div>
      </div>

      {/* Zone 4: Legal Bottom — URLs resolved from tenant data contract (variant) */}
      <div className="footer-legal">
        <div className="footer-container footer-legal-row">
          <span className="footer-copyright">&copy; {currentYear} {variant.copyrightHolder}</span>
          <a href={variant.termsUrl} target="_blank" rel="noopener noreferrer">TERMS OF USE</a>
          <a href={variant.privacyUrl} target="_blank" rel="noopener noreferrer">PRIVACY POLICY</a>
          <a href={variant.cookiesUrl} target="_blank" rel="noopener noreferrer">COOKIES POLICY</a>
        </div>
      </div>
    </footer>
  );
};
{% endraw %}
