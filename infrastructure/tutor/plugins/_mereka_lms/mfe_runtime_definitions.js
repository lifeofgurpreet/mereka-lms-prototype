{% raw %}
const normalizeHostname = (hostname) => {
  return (typeof hostname === 'string' ? hostname.toLowerCase() : '').replace(/^www\\./, '');
};

// Tenant branding + footer data contract.
// Base config shared by all tenants; per-tenant overrides below.
const MEREKA_BASE_VARIANT = {
  logoUrl: '/theme/logo-horizontal.svg',
  mobileLogoUrl: '/theme/logo.svg',
  themeBrandUrl: '../theme/mereka-brand.min.css',
  themeBrandLightUrl: '../theme/mereka-brand-light.min.css',
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
    logoUrl: '/theme/biji-biji/logo-horizontal.svg',
    mobileLogoUrl: '/theme/biji-biji/logo.svg',
    themeBrandUrl: '../theme/biji-biji-brand.min.css',
    themeBrandLightUrl: '../theme/biji-biji-brand-light.min.css',
    brand: 'Biji-Biji Academy',
    copyrightHolder: 'Biji-Biji Initiative',
    supportEmail: 'techadmin@biji-biji.com',
  },
  'skillourfuture.academy.mereka.io': {
    ...MEREKA_BASE_VARIANT,
    logoUrl: '/theme/skillourfuture/logo-horizontal.svg',
    mobileLogoUrl: '/theme/skillourfuture/logo.svg',
    themeBrandUrl: '../theme/sof-brand.min.css',
    themeBrandLightUrl: '../theme/sof-brand-light.min.css',
    brand: 'Skill Our Future Academy',
    copyrightHolder: 'MEREKA',
    supportEmail: 'support@mereka.io',
  },
};

const deriveVariantCandidates = (hostname) => {
  const normalizedHostname = normalizeHostname(hostname);
  if (!normalizedHostname) {
    return [];
  }

  const candidates = [];
  const queue = [normalizedHostname];
  const enqueue = (candidate) => {
    if (candidate && !candidates.includes(candidate)) {
      candidates.push(candidate);
      queue.push(candidate);
    }
  };

  while (queue.length > 0) {
    const candidate = queue.shift();
    if (!candidate) {
      continue;
    }

    enqueue(candidate.replace(/^(?:staging\.)?apps\./, ''));
    enqueue(candidate.replace(/^apps\./, ''));
    enqueue(candidate.replace(/^staging\./, ''));
    enqueue(candidate.replace(/\.mereka\.dev$/, '.mereka.io'));
  }

  return candidates;
};

const getMerekaVariant = (hostname, config) => {
  const normalizedHostname = normalizeHostname(hostname);
  const fallbackBrand = (typeof config !== 'undefined' && config.SITE_NAME) || 'Mereka Academy';
  const fallbackPlatform = (typeof config !== 'undefined' && config.PLATFORM_NAME) || 'MEREKA';

  // 1. Exact match (LMS homepage hostnames).
  const exactVariant = MEREKA_SITE_VARIANTS[normalizedHostname];
  if (exactVariant) {
    return exactVariant;
  }

  // 2. MFE/staging prefix stripping — MFEs are served from apps.{domain},
  //    apps.staging.{domain}, or staging.apps.{domain}, while branding is keyed
  //    by the canonical LMS domain.
  for (const candidate of deriveVariantCandidates(normalizedHostname)) {
    const variant = MEREKA_SITE_VARIANTS[candidate];
    if (variant) {
      return variant;
    }
  }

  // 3. Unknown host fallback: keep shell rendering deterministic for new tenants.
  //    Prefer hardcoded 'Mereka Academy' over SITE_NAME which may be the stock
  //    Open edX default ('My Open edX').
  return {
    ...MEREKA_BASE_VARIANT,
    brand: fallbackBrand === 'My Open edX' ? 'Mereka Academy' : fallbackBrand,
    copyrightHolder: fallbackPlatform === 'My Open edX' ? 'MEREKA' : fallbackPlatform,
    supportEmail: 'support@mereka.io',
  };
};

const getMerekaPublicFooter = (config) => {
  const footer = config && typeof config.MEREKA_PUBLIC_FOOTER === 'object' && config.MEREKA_PUBLIC_FOOTER !== null
    ? config.MEREKA_PUBLIC_FOOTER
    : {};

  return {
    brand: footer.brand || {},
    socialLinks: Array.isArray(footer.socialLinks) ? footer.socialLinks : [],
    navLinks: Array.isArray(footer.navLinks) ? footer.navLinks : [],
    support: footer.support || {},
    sections: footer.sections || {},
    legal: footer.legal || {},
  };
};

const normalizeTenantPaletteValue = (value) => {
  return typeof value === 'string' ? value.trim() : '';
};

const applyMerekaTenantPaletteBridge = () => {
  if (typeof document === 'undefined' || typeof getConfig !== 'function') {
    return;
  }

  const rootStyle = document.documentElement && document.documentElement.style;
  if (!rootStyle || typeof rootStyle.setProperty !== 'function') {
    return;
  }

  const config = getConfig() || {};
  const primary = normalizeTenantPaletteValue(config.PRIMARY_COLOR);
  const secondary = normalizeTenantPaletteValue(config.SECONDARY_COLOR);
  const accent = normalizeTenantPaletteValue(config.ACCENT_COLOR);
  const textOnPrimary = normalizeTenantPaletteValue(config.TEXT_ON_PRIMARY);

  const paletteBridge = {
    '--tenant-color-primary': primary,
    '--tenant-color-secondary': secondary,
    '--tenant-color-accent': accent,
    '--tenant-color-text-on-primary': textOnPrimary,
    '--mereka-color-magenta': primary,
    '--mereka-color-teal': secondary,
    '--mereka-color-blue': accent,
    '--mereka-color-info': accent,
    '--pgn-color-primary-base': primary,
    '--pgn-color-secondary-base': secondary,
    '--pgn-color-info-base': accent,
    '--pgn-color-brand-base': primary,
    '--pgn-link-color': primary,
    '--pgn-link-hover-color': secondary,
  };

  for (const [propertyName, value] of Object.entries(paletteBridge)) {
    if (value) {
      rootStyle.setProperty(propertyName, value);
    }
  }
};

applyMerekaTenantPaletteBridge();

const getLearnerHomeHref = () => '/learner-dashboard/';

const getCatalogHref = (baseUrl) => {
  return baseUrl ? `${baseUrl}/courses` : '/courses';
};

const getMerekaBaseUrl = (config) => {
  return (config && typeof config.LMS_BASE_URL === 'string' ? config.LMS_BASE_URL : '').replace(/\/$/, '');
};

const getMerekaThemeAssetUrl = (config, assetPath) => {
  const normalizedPath = typeof assetPath === 'string' ? assetPath.trim() : '';
  const baseUrl = getMerekaBaseUrl(config);
  if (!normalizedPath) {
    return '';
  }
  if (!normalizedPath.startsWith('/')) {
    return normalizedPath;
  }
  return baseUrl ? `${baseUrl}${normalizedPath}` : normalizedPath;
};

const getMerekaShellCopy = (variant) => {
  const brand = variant && variant.brand ? variant.brand : 'Mereka Academy';
  return {
    authn: {
      eyebrow: 'Learning workspace',
      title: 'Welcome back',
      subtitle: `Sign in to continue with ${brand}.`,
      supportCtaLabel: 'Support',
      trustNote: 'Secure access for your active learning environment.',
    },
    dashboard: {
      eyebrow: 'Learning cockpit',
      title: `Welcome back to ${brand}`,
      subtitle: 'Resume your work, explore what is next, and keep momentum across every active pathway.',
      primaryCtaLabel: 'Explore courses',
      secondaryCtaLabel: 'Support',
    },
    learning: {
      eyebrow: 'In session',
      title: `${brand} learning flow`,
      subtitle: 'Stay oriented, keep your progress visible, and reach support without breaking context.',
      supportCtaLabel: 'Get help',
    },
  };
};

const getLogoHref = () => getLearnerHomeHref();

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

  const catalogHref = getCatalogHref((config.LMS_BASE_URL || '').replace(/\/$/, ''));
  if (!existingHrefs.has(catalogHref)) {
    nextButtons.push({
      href: catalogHref,
      message: 'Course Catalog',
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
  const hostname = typeof window !== 'undefined' ? window.location.hostname : '';
  const variant = getMerekaVariant(hostname, config);
  const isMobileViewport = typeof window !== 'undefined' ? window.matchMedia('(max-width: 767px)').matches : false;
  const selectedLogo = isMobileViewport && variant.mobileLogoUrl ? variant.mobileLogoUrl : variant.logoUrl;
  const shellCopy = getMerekaShellCopy(variant);

  return (
    <a href={getLogoHref()} aria-label={`${variant.brand} learning home`} className="mereka-header-logo">
      <img src={getMerekaThemeAssetUrl(config, selectedLogo)} alt={`${variant.brand} logo`} />
      <span className="mereka-header-logo__lockup">
        <span className="mereka-header-logo__brand">{variant.brand}</span>
        <span className="mereka-header-logo__meta">{shellCopy.learning.eyebrow}</span>
      </span>
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
          src={getMerekaThemeAssetUrl(config, variant.logoUrl)}
          alt={`${variant.brand} logo`}
          className="mereka-authn-login-branding__logo-img"
        />
        <span className="mereka-authn-login-branding__brand">{variant.brand}</span>
      </a>
    </div>
  );
};

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
  const discoverPath = getCatalogHref(baseUrl);
  const helpPath = variant.helpUrl || '/help/';
  const noCourseSignals = [
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

const getCertificateReadinessSteps = (variantBrand) => ([
  {
    label: '01',
    title: 'Finish the learning plan',
    body: `Complete the remaining units, graded work, and required activities so ${variantBrand} can issue a complete completion record.`,
  },
  {
    label: '02',
    title: 'Confirm profile details',
    body: 'Keep your profile name, organization context, and supporting details current so certificate records stay accurate.',
  },
  {
    label: '03',
    title: 'Clear identity checks if required',
    body: 'Some programs require ID review before release. Treat it as the final gate, not a surprise after you finish the course.',
  },
]);

const MerekaCertificateReadinessSteps = ({ steps }) => (
  <ol className="mereka-certificate-readiness__steps list-unstyled mb-0">
    {steps.map((step) => (
      <li key={step.label} className="mereka-certificate-readiness__step">
        <span className="mereka-certificate-readiness__step-index" aria-hidden="true">{step.label}</span>
        <div className="mereka-certificate-readiness__step-copy">
          <p className="mereka-certificate-readiness__step-title mb-1">{step.title}</p>
          <p className="mereka-certificate-readiness__step-body mb-0">{step.body}</p>
        </div>
      </li>
    ))}
  </ol>
);

const MerekaCertificateContextMetaItem = ({ label, value }) => (
  <li className="mereka-additional-profile-fields__item">
    <span className="mereka-additional-profile-fields__label">{label}</span>
    <strong className="mereka-additional-profile-fields__value">{value}</strong>
  </li>
);

const MerekaCertificateContextShell = ({
  className,
  eyebrow,
  title,
  titleClassName = 'mereka-progress-certificate-status__title mb-1',
  body,
  bodyClassName = 'mereka-progress-certificate-status__body mb-0',
  status,
  steps,
  meta,
  hint,
  hintClassName = 'mereka-progress-certificate-status__hint mb-0',
}) => (
  <section className={className}>
    <div className="mereka-shell-panel__content">
      <div className="mereka-progress-certificate-status__header">
        <div>
          <p className="mereka-shell-kicker mb-2">{eyebrow}</p>
          <p className={titleClassName}>{title}</p>
        </div>
        {status ? <span className="mereka-progress-certificate-status__status">{status}</span> : null}
      </div>
      {body ? <p className={bodyClassName}>{body}</p> : null}
      {steps}
      {meta}
      {hint ? <p className={hintClassName}>{hint}</p> : null}
    </div>
  </section>
);

// Learning progress certificate status branding and context card.
// Wired into org.openedx.frontend.learning.progress_certificate_status.v1.
const MerekaProgressCertificateStatus = ({ courseId }) => {
  const config = getConfig();
  const variant = getMerekaVariant(typeof window !== 'undefined' ? window.location.hostname : '', config);
  const safeCourseId = typeof courseId === 'string' ? courseId : '';
  const steps = getCertificateReadinessSteps(variant.brand);

  return (
    <MerekaCertificateContextShell
      className="mereka-progress-certificate-status mereka-shell-panel my-3"
      eyebrow="Certificate readiness"
      title="Keep your certificate within reach"
      body={`${variant.brand} Learning${safeCourseId ? ` course ${safeCourseId}` : ''} is active. Use the checklist below to move from course progress to certificate release without guesswork.`}
      status="In progress"
      steps={<MerekaCertificateReadinessSteps steps={steps} />}
      hint="Completion unlocks the certificate, but clean profile and verification data keep the release path fast and predictable."
    />
  );
};

// Account ID verification helper slot.
// Wired into org.openedx.frontend.account.id_verification_page.v1.
const MerekaAccountIdVerificationHint = () => {
  return (
    <MerekaCertificateContextShell
      className="mereka-account-id-verification-hint mereka-shell-panel mb-3"
      eyebrow="Identity review"
      title="Identity review protects certificate trust"
      titleClassName="mereka-account-id-verification-hint__title mb-1"
      body="ID verification details are reviewed by your learning administrator for secure certificate issuance. Finish this step before course completion so certificate release does not stall at the last mile."
      bodyClassName="mereka-account-id-verification-hint__body mb-0"
    />
  );
};

// Enterprise profile section for account/profile additional profile field slots.
// Wired into org.openedx.frontend.account.additional_profile_fields.v1 and
// org.openedx.frontend.profile.additional_profile_fields.v1.
const MerekaAdditionalProfileFields = () => {
  const config = getConfig();
  const variant = getMerekaVariant(typeof window !== 'undefined' ? window.location.hostname : '', config);
  const profileMeta = (
    <ul className="mereka-additional-profile-fields__list list-unstyled mb-0">
      <MerekaCertificateContextMetaItem label="Organization" value={variant.brand} />
      <MerekaCertificateContextMetaItem label="Job title" value="Required before certificate export" />
      <MerekaCertificateContextMetaItem label="Department" value="Used for enterprise reporting" />
    </ul>
  );

  return (
    <MerekaCertificateContextShell
      className="mereka-additional-profile-fields mereka-shell-panel mb-3"
      eyebrow="Certificate readiness"
      title="Finish the profile details certificates depend on"
      titleClassName="mereka-additional-profile-fields__title h5 mb-2"
      body={`For ${variant.brand} workplace setups, these fields anchor certificate identity, reporting, and downstream enterprise records. Keep them aligned before you request a certificate.`}
      bodyClassName="mereka-additional-profile-fields__body mb-3"
      meta={profileMeta}
      hint="Match these details to the learner name and ID context you expect to appear alongside your certificate record."
      hintClassName="mereka-additional-profile-fields__hint mb-0"
    />
  );
};

// Custom Mereka footer component (Direct plugin — registered via footer_slot)
// Wired into org.openedx.frontend.layout.footer.v1 by PLUGIN_SLOTS in mereka_lms.py
const MerekaFooter = () => {
  const config = getConfig();
  const baseUrl = getMerekaBaseUrl(config);
  const currentYear = new Date().getFullYear();
  const hostname = typeof window !== 'undefined' ? window.location.hostname : '';
  const variant = getMerekaVariant(hostname, config);
  const footerContent = getMerekaPublicFooter(config);
  const footerSupport = footerContent.support || {};
  const footerSections = footerContent.sections || {};
  const footerMarketplace = footerSections.marketplace || {};
  const footerLegal = footerContent.legal || {};
  const logoPath = variant.logoUrl || '/theme/logo-horizontal.svg';
  const logoUrl = getMerekaThemeAssetUrl(config, logoPath);
  const socialLinks = footerContent.socialLinks;
  const navLinks = [
    ...footerContent.navLinks,
    { label: footerSupport.helpLabel || 'Help Centre', url: variant.helpUrl },
    { label: footerSupport.contactSupportLabel || 'Contact Support', url: 'mailto:' + variant.supportEmail },
  ];
  const corporateLinks = (footerSections.corporate && footerSections.corporate.links) || [];
  const marketplaceUserLinks = footerMarketplace.userLinks || [];
  const marketplaceBusinessLinks = footerMarketplace.businessLinks || [];
  const academyLinks = (footerSections.academy && footerSections.academy.links) || [];
  const spaceLinks = (footerSections.space && footerSections.space.links) || [];

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
            <span className="footer-brand-name">{(footerContent.brand && footerContent.brand.logoText) || 'mereka'}</span>
          </a>
          <div className="footer-social-icons">
            {socialLinks.map(s => (
              <a key={s.name} href={s.url} target="_blank" rel="noopener noreferrer" aria-label={s.name} className="footer-social-link">
                <SocialIcon d={s.iconPath} />
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
          <a href={'https://wa.me/' + (variant.whatsapp || footerSupport.whatsapp || '601135271981')} target="_blank" rel="noopener noreferrer" className="footer-whatsapp-btn">
            <WhatsAppIcon /> {footerSupport.contactCtaLabel || 'Contact Us'}
          </a>
        </div>
      </div>

      {/* Zone 3: 4-Column Body */}
      <div className="footer-body">
        <div className="footer-container footer-columns">
          <div className="footer-column">
            <h4 className="footer-column-title">{(footerSections.corporate && footerSections.corporate.title) || 'Corporate'}</h4>
            <ul>{corporateLinks.map(l => <li key={l.label}><a href={l.url} target="_blank" rel="noopener noreferrer">{l.label}</a></li>)}</ul>
          </div>
          <div className="footer-column footer-column--wide">
            <h4 className="footer-column-title">{footerMarketplace.title || 'Marketplace'}</h4>
            <div className="footer-marketplace-grid">
              <div>
                <p className="footer-sub-heading">{footerMarketplace.usersHeading || 'USERS'}</p>
                <ul>{marketplaceUserLinks.map(l => <li key={l.label}><a href={l.url} target="_blank" rel="noopener noreferrer">{l.label}</a></li>)}</ul>
              </div>
              <div>
                <p className="footer-sub-heading">{footerMarketplace.businessHeading || 'BUSINESS'}</p>
                <ul>{marketplaceBusinessLinks.map(l => <li key={l.label}><a href={l.url} target="_blank" rel="noopener noreferrer">{l.label}</a></li>)}</ul>
                <p className="footer-app-label">{footerMarketplace.appLabel || 'Manage your bookings'}</p>
                <div className="footer-app-badges">
                  {(footerMarketplace.appBadges || []).map(badge => (
                    <a key={badge.label} href={badge.url} target="_blank" rel="noopener noreferrer" className="footer-badge">
                      {/apple|app.store/i.test(badge.url || badge.label) && <svg width="16" height="16" viewBox="0 0 24 24" fill="currentColor" style={{marginRight:'0.4rem',verticalAlign:'middle'}}><path d="M18.71 19.5c-.83 1.24-1.71 2.45-3.05 2.47-1.34.03-1.77-.79-3.29-.79-1.53 0-2 .77-3.27.82-1.31.05-2.3-1.32-3.14-2.53C4.25 17 2.94 12.45 4.7 9.39c.87-1.52 2.43-2.48 4.12-2.51 1.28-.02 2.5.87 3.29.87.78 0 2.26-1.07 3.8-.91.65.03 2.47.26 3.64 1.98-.09.06-2.17 1.28-2.15 3.81.03 3.02 2.65 4.03 2.68 4.04-.03.07-.42 1.44-1.38 2.83M13 3.5c.73-.83 1.94-1.46 2.94-1.5.13 1.17-.34 2.35-1.04 3.19-.69.85-1.83 1.51-2.95 1.42-.15-1.15.41-2.35 1.05-3.11z"/></svg>}
                      {/google|play/i.test(badge.url || badge.label) && <svg width="16" height="16" viewBox="0 0 24 24" fill="currentColor" style={{marginRight:'0.4rem',verticalAlign:'middle'}}><path d="M3.609 1.814L13.792 12 3.61 22.186a.996.996 0 01-.61-.92V2.734a1 1 0 01.609-.92zm10.89 10.893l2.302 2.302-10.937 6.333 8.635-8.635zm3.199-3.2l2.807 1.626a1 1 0 010 1.734l-2.808 1.626L15.206 12l2.492-2.493zM5.864 2.658L16.8 8.99l-2.3 2.3-8.636-8.632z"/></svg>}
                      {badge.label}
                    </a>
                  ))}
                </div>
                <a href={(footerMarketplace.cta && footerMarketplace.cta.url) || 'https://mereka.io/welcome/hub'} target="_blank" rel="noopener noreferrer" className="footer-cta-btn">{(footerMarketplace.cta && footerMarketplace.cta.label) || 'Become a Hub'}</a>
              </div>
            </div>
          </div>
          <div className="footer-column">
            <h4 className="footer-column-title">{(footerSections.academy && footerSections.academy.title) || 'Academy'}</h4>
            <ul>{academyLinks.map(l => <li key={l.label}><a href={l.url} target="_blank" rel="noopener noreferrer">{l.label}</a></li>)}</ul>
          </div>
          <div className="footer-column">
            <h4 className="footer-column-title">{(footerSections.space && footerSections.space.title) || 'Space'}</h4>
            <ul>{spaceLinks.map(l => <li key={l.label}><a href={l.url} target="_blank" rel="noopener noreferrer">{l.label}</a></li>)}</ul>
          </div>
        </div>
      </div>

      {/* Zone 4: Legal Bottom — URLs resolved from tenant data contract (variant) */}
      <div className="footer-legal">
        <div className="footer-container footer-legal-row">
          <span className="footer-copyright">&copy; {currentYear} {variant.copyrightHolder}</span>
          <a href={variant.termsUrl} target="_blank" rel="noopener noreferrer">{footerLegal.termsLabel || 'TERMS OF USE'}</a>
          <a href={variant.privacyUrl} target="_blank" rel="noopener noreferrer">{footerLegal.privacyLabel || 'PRIVACY POLICY'}</a>
          <a href={variant.cookiesUrl} target="_blank" rel="noopener noreferrer">{footerLegal.cookiesLabel || 'COOKIES POLICY'}</a>
        </div>
      </div>
    </footer>
  );
};
{% endraw %}
