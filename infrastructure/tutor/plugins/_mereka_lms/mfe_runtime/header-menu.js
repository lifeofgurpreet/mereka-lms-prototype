// Header and menu components.
// Includes MerekaHeaderLogo, withMerekaMenuItems, and all header/menu widget helpers.

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
  const baseTokens = typeof baseValue === 'string' ? baseValue.split(/\s+/).filter(Boolean) : [];
  const appendTokens = typeof classNameToAppend === 'string' ? classNameToAppend.split(/\s+/).filter(Boolean) : [];
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
  const shellCopy = getMerekaShellCopy(variant);

  return (
    <div className="mereka-authn-login-branding mereka-shell-panel mereka-shell-panel--authn">
      <p className="mereka-shell-kicker mereka-authn-login-branding__eyebrow">{shellCopy.authn.eyebrow}</p>
      <a href="/" className="mereka-authn-login-branding__logo">
        <img
          src={getMerekaThemeAssetUrl(config, variant.logoUrl)}
          alt={`${variant.brand} logo`}
          className="mereka-authn-login-branding__logo-img"
        />
      </a>
      <h2 className="mereka-authn-login-branding__title">{shellCopy.authn.title}</h2>
      <p className="mereka-authn-login-branding__subtitle">
        {shellCopy.authn.subtitle}
      </p>
      <div className="mereka-authn-login-branding__actions">
        <a
          href={variant.helpUrl}
          className="mereka-shell-link mereka-shell-link--quiet"
          target="_blank"
          rel="noopener noreferrer"
        >
          {shellCopy.authn.supportCtaLabel}
        </a>
        <span className="mereka-authn-login-branding__trust-note">{shellCopy.authn.trustNote}</span>
      </div>
    </div>
  );
};
