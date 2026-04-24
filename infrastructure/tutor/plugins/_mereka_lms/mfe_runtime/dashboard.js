// Dashboard surface components.
// Includes MerekaDashboardHeader, course-card slots, sidebar widget, and no-courses view.

// Custom learner-dashboard sidebar widget for branded links and support prompts.
// Registered via org.openedx.frontend.learner_dashboard.widget_sidebar.v1.
const MerekaLearnerSidebarWidget = () => {
  const config = getConfig();
  const baseUrl = (config.LMS_BASE_URL || '').replace(/\/$/, '');
  const variant = getMerekaVariant(typeof window !== 'undefined' ? window.location.hostname : '', config);
  const shellCopy = getMerekaShellCopy(variant);
  const learnerHomePath = getLearnerHomeHref();
  const coursesPath = getCatalogHref(baseUrl);
  const helpPath = variant.helpUrl || '/help/';
  const quickLinks = [
    { href: learnerHomePath, label: 'Learning home', meta: 'Resume active pathways' },
    { href: coursesPath, label: 'Course catalog', meta: 'Browse new learning options' },
    { href: helpPath, label: 'Support', meta: 'Get help without losing context' },
  ];

  return (
    <aside className="mereka-learner-sidebar-widget mereka-shell-panel">
      <div className="mereka-shell-panel__content">
        <p className="mereka-shell-kicker">{shellCopy.dashboard.eyebrow}</p>
        <h3 className="mereka-learner-sidebar-widget__title h5 mb-2">{variant.brand} quick links</h3>
        <p className="mereka-shell-panel__lead mb-3">
          Keep your next action visible while moving between the dashboard, catalog, and support.
        </p>
        <div className="mereka-learner-sidebar-widget__links">
          {quickLinks.map((link) => (
            <a key={link.label} href={link.href} className="mereka-learner-sidebar-widget__link">
              <span className="mereka-learner-sidebar-widget__label">{link.label}</span>
              <span className="mereka-learner-sidebar-widget__meta">{link.meta}</span>
            </a>
          ))}
        </div>
      </div>
    </aside>
  );
};

// Learner-dashboard empty-state override for no enrolled courses.
// Wired into org.openedx.frontend.learner_dashboard.no_courses_view.v1.
const MerekaNoCoursesView = () => {
  const config = getConfig();
  const baseUrl = (config.LMS_BASE_URL || '').replace(/\/$/, '');
  const variant = getMerekaVariant(typeof window !== 'undefined' ? window.location.hostname : '', config);
  const shellCopy = getMerekaShellCopy(variant);
  const emptyStateSignals = {
    'biji-biji': [
      'Start with hands-on pathways built around community making and creative practice.',
      'Return here to keep cohort work, events, and projects in one visible workspace.',
      'Reach support quickly if you need help joining the right makerspace track.',
    ],
    skillourfuture: [
      'Start with career pathways aligned to employability, confidence, and verified progress.',
      'Return here to keep coaching, coursework, and milestones in one clear runway.',
      'Reach support quickly if you need help choosing the next program or pathway.',
    ],
  };
  const variantSlug = variant && variant.slug ? variant.slug : 'mereka';
  const discoverPath = getCatalogHref(baseUrl);
  const helpPath = variant.helpUrl || '/help/';
  const noCourseSignals = emptyStateSignals[variantSlug] || [
    'Start with curated pathways tailored to your goals.',
    'Return here anytime to keep momentum visible.',
    'Reach support fast if you need enrollment help.',
  ];

  return (
    <section className="mereka-no-courses-view mereka-shell-panel">
      <div className="mereka-shell-panel__content">
        <p className="mereka-shell-kicker">{shellCopy.dashboard.eyebrow}</p>
        <h2 className="h3 mb-3">Your {variant.brand} dashboard is ready</h2>
        <p className="mereka-no-courses-view__message mb-4">
          You are not enrolled in any courses yet, but your learner space is ready for the next pathway you start.
        </p>
        <ul className="mereka-no-courses-view__signals list-unstyled mb-4">
          {noCourseSignals.map((signal) => (
            <li key={signal} className="mereka-no-courses-view__signal">
              {signal}
            </li>
          ))}
        </ul>
        <div className="mereka-no-courses-view__actions">
          <a href={discoverPath} className="btn btn-primary me-2 mb-2">Browse course catalog</a>
          <a href={helpPath} className="btn btn-outline-primary mb-2">Get support</a>
        </div>
      </div>
    </section>
  );
};

// Learner-dashboard course-list slot surface (high-visibility post-login branding).
// Wired into org.openedx.frontend.learner_dashboard.course_list.v1.
const MerekaDashboardHeader = () => {
  const config = getConfig();
  const baseUrl = getMerekaBaseUrl(config);
  const variant = getMerekaVariant(typeof window !== 'undefined' ? window.location.hostname : '', config);
  const shellCopy = getMerekaShellCopy(variant);

  return (
    <section className="mereka-dashboard-header-slot mereka-shell-panel mb-3">
      <div className="mereka-shell-panel__content">
        <p className="mereka-shell-kicker">{shellCopy.dashboard.eyebrow}</p>
        <h2 className="h4 mb-2">{shellCopy.dashboard.title}</h2>
        <p className="mereka-shell-panel__lead mb-0">{shellCopy.dashboard.subtitle}</p>
      </div>
      <div className="mereka-dashboard-header-slot__actions">
        <a href={getCatalogHref(baseUrl)} className="mereka-shell-link">
          {shellCopy.dashboard.primaryCtaLabel}
        </a>
        <a href={variant.helpUrl} className="mereka-shell-link mereka-shell-link--quiet" target="_blank" rel="noopener noreferrer">
          {shellCopy.dashboard.secondaryCtaLabel}
        </a>
      </div>
    </section>
  );
};

const MerekaDashboardMicroShell = ({
  eyebrow,
  title,
  body,
  badge,
  className = '',
}) => {
  const shellClassName = ['mereka-dashboard-micro-shell', 'mereka-shell-panel', className].filter(Boolean).join(' ');

  return (
    <div className={shellClassName}>
      <div className="mereka-shell-panel__content">
        {eyebrow ? <p className="mereka-shell-kicker mb-1">{eyebrow}</p> : null}
        <div className="mereka-dashboard-micro-shell__header">
          <div className="mereka-dashboard-micro-shell__copy">
            <p className="mereka-dashboard-micro-shell__title mb-0">{title}</p>
            {body ? <p className="mereka-dashboard-micro-shell__body mb-0">{body}</p> : null}
          </div>
          {badge ? <span className="mereka-badge mereka-dashboard-micro-shell__badge">{badge}</span> : null}
        </div>
      </div>
    </div>
  );
};

// Learner-dashboard course-card banner accent slot.
// Wired into org.openedx.frontend.learner_dashboard.course_card_banner.v1.
const MerekaCourseCardAccent = ({ cardId }) => {
  const safeCardId = typeof cardId === 'string' ? cardId : '';
  const config = getConfig();
  const variant = getMerekaVariant(typeof window !== 'undefined' ? window.location.hostname : '', config);
  const badgeLabelMap = {
    'biji-biji': 'Biji-Biji Pick',
    skillourfuture: 'SOF Track',
  };
  const badgeLabel = badgeLabelMap[variant && variant.slug ? variant.slug : 'mereka'] || 'Mereka Curated';
  return (
    <div className="mereka-course-card-accent">
      <span className="mereka-badge">{badgeLabel}</span>
      {safeCardId ? <span className="mereka-course-card-accent__meta">{safeCardId}</span> : null}
    </div>
  );
};

// Learner-dashboard course-card action slot helper.
// Wired into org.openedx.frontend.learner_dashboard.course_card_action.v1.
const MerekaCourseCardActionHint = () => {
  return (
    <MerekaDashboardMicroShell
      title="Keep your weekly learning streak active"
      body="A short, deliberate session this week keeps momentum visible."
      badge="Momentum"
      className="mereka-course-card-action-hint mereka-dashboard-micro-shell--inline"
    />
  );
};

// Learner-dashboard modal helper slot.
// Wired into org.openedx.frontend.learner_dashboard.dashboard_modal.v1.
const MerekaDashboardModalHint = () => {
  return (
    <MerekaDashboardMicroShell
      eyebrow="Mereka update"
      title="New curated pathways are available"
      body="Review the latest pathways aligned to your active learning goals before you leave the dashboard."
      badge="Update"
      className="mereka-dashboard-modal-hint"
    />
  );
};
