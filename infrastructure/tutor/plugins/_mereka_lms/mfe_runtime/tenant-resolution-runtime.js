// Tenant branding data contracts and runtime resolution logic.
// The live MFE runtime must consume backend-provided tenant config rather than
// carrying its own hostname map inside env.config.jsx.

const normalizeHostname = (hostname) => {
  return (typeof hostname === 'string' ? hostname.toLowerCase() : '').replace(/^www\./, '');
};

const MEREKA_BASE_VARIANT = {
  slug: 'mereka',
  logoUrl: '/theme/logo-horizontal.svg',
  mobileLogoUrl: '/theme/logo.svg',
  themeBrandUrl: '/theme/mereka-brand.min.css',
  themeBrandLightUrl: '/theme/mereka-brand-light.min.css',
  helpUrl: 'https://help.mereka.io/',
  whatsapp: '601135271981',
  privacyUrl: 'https://legal.mereka.io/privacy-policy/',
  termsUrl: 'https://legal.mereka.io/',
  cookiesUrl: 'https://legal.mereka.io/#cookie-policy',
  supportEmail: 'support@mereka.io',
};

const getConfiguredMerekaVariant = (config) => {
  return config && typeof config.MEREKA_SITE_VARIANT === 'object' && config.MEREKA_SITE_VARIANT !== null
    ? config.MEREKA_SITE_VARIANT
    : {};
};

const getMerekaVariant = (_hostname, config) => {
  const fallbackBrand = (typeof config !== 'undefined' && config.SITE_NAME) || 'Mereka Academy';
  const fallbackPlatform = (typeof config !== 'undefined' && config.PLATFORM_NAME) || 'MEREKA';
  const configuredVariant = getConfiguredMerekaVariant(config);

  return {
    ...MEREKA_BASE_VARIANT,
    ...configuredVariant,
    slug: configuredVariant.slug || 'mereka',
    brand: configuredVariant.brand || (fallbackBrand === 'My Open edX' ? 'Mereka Academy' : fallbackBrand),
    copyrightHolder: configuredVariant.copyrightHolder || (fallbackPlatform === 'My Open edX' ? 'MEREKA' : fallbackPlatform),
    supportEmail: configuredVariant.supportEmail || MEREKA_BASE_VARIANT.supportEmail,
  };
};

const getMerekaPublicFooter = (config) => {
  const footer = config && typeof config.MEREKA_FOOTER_CONFIG === 'object' && config.MEREKA_FOOTER_CONFIG !== null
    ? config.MEREKA_FOOTER_CONFIG
    : (config && typeof config.MEREKA_PUBLIC_FOOTER === 'object' && config.MEREKA_PUBLIC_FOOTER !== null
      ? config.MEREKA_PUBLIC_FOOTER
      : {});

  return {
    brand: footer.brand || {},
    socialLinks: Array.isArray(footer.socialLinks) ? footer.socialLinks : [],
    navLinks: Array.isArray(footer.navLinks) ? footer.navLinks : [],
    support: footer.support || {},
    sections: footer.sections || {},
    legal: footer.legal || {},
  };
};

const getLearnerHomeHref = () => '/learner-dashboard/';

const getCatalogHref = (baseUrl) => {
  return baseUrl ? `${baseUrl}/courses` : '/courses';
};

const getMerekaBaseUrl = (config) => {
  return (config && typeof config.LMS_BASE_URL === 'string' ? config.LMS_BASE_URL : '').replace(/\/$/, '');
};

const getMerekaThemeAssetUrl = (config, assetPath) => {
  const normalizedPath = typeof assetPath === 'string' ? assetPath.trim() : '';
  if (!normalizedPath) {
    return '';
  }
  if (!normalizedPath.startsWith('/')) {
    return normalizedPath;
  }
  if (normalizedPath.startsWith('/theme/') && typeof window !== 'undefined') {
    return `${window.location.origin}${normalizedPath}`;
  }
  const baseUrl = getMerekaBaseUrl(config);
  return baseUrl ? `${baseUrl}${normalizedPath}` : normalizedPath;
};

const getMerekaShellCopy = (variant) => {
  const brand = variant && variant.brand ? variant.brand : 'Mereka Academy';
  const slug = variant && variant.slug ? variant.slug : 'mereka';

  if (slug === 'biji-biji') {
    return {
      authn: {
        eyebrow: 'Community-powered learning',
        title: 'Step back into the makerspace',
        subtitle: `Sign in to continue with ${brand} pathways, cohorts, and practical studio work.`,
        supportCtaLabel: 'Talk to support',
        trustNote: 'Built for creative communities, practical making, and shared learning momentum.',
      },
      dashboard: {
        eyebrow: 'Maker dashboard',
        title: `Your ${brand} makerspace is live`,
        subtitle: 'Pick up cohort work, studio sessions, and project-based pathways without losing context.',
        primaryCtaLabel: 'Browse pathways',
        secondaryCtaLabel: 'Community support',
      },
      learning: {
        eyebrow: 'Studio session',
        title: `${brand} learning flow`,
        subtitle: 'Keep the session tactile, collaborative, and grounded in the work you are building.',
        supportCtaLabel: 'Get help',
      },
    };
  }

  if (slug === 'skillourfuture') {
    return {
      authn: {
        eyebrow: 'Career acceleration workspace',
        title: 'Return to your next breakthrough',
        subtitle: `Sign in to continue with ${brand} career pathways, coaching, and employability tracks.`,
        supportCtaLabel: 'Career support',
        trustNote: 'Designed for confident career moves, employer-aligned learning, and verified progress.',
      },
      dashboard: {
        eyebrow: 'Career dashboard',
        title: `Your ${brand} growth plan is ready`,
        subtitle: 'See your next milestone, keep progress visible, and move quickly between coaching and coursework.',
        primaryCtaLabel: 'Explore programs',
        secondaryCtaLabel: 'Career support',
      },
      learning: {
        eyebrow: 'Career session',
        title: `${brand} learning flow`,
        subtitle: 'Stay focused on the next capability, credential, or career move without losing momentum.',
        supportCtaLabel: 'Get help',
      },
    };
  }

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

if (typeof window !== 'undefined') {
  window.getMerekaVariant = getMerekaVariant;
  window.getMerekaBaseUrl = getMerekaBaseUrl;
  window.getMerekaThemeAssetUrl = getMerekaThemeAssetUrl;
  window.getMerekaShellCopy = getMerekaShellCopy;
  window.getMerekaPublicFooter = getMerekaPublicFooter;
  window.getLogoHref = getLogoHref;
  window.getLearnerHomeHref = getLearnerHomeHref;
  window.getCatalogHref = getCatalogHref;
}

const normalizeTenantPaletteValue = (value) => {
  return typeof value === 'string' ? value.trim() : '';
};

const applyMerekaTenantIdentity = () => {
  if (typeof document === 'undefined' || typeof getConfig !== 'function') {
    return;
  }

  const config = getConfig() || {};
  const hostname = typeof window !== 'undefined' ? window.location.hostname : '';
  const variant = getMerekaVariant(hostname, config);
  const tenantSlug = variant && variant.slug ? variant.slug : 'mereka';
  const root = document.documentElement;
  const body = document.body;

  if (root && typeof root.setAttribute === 'function') {
    root.setAttribute('data-mereka-tenant', tenantSlug);
  }
  if (body && body.classList && typeof body.classList.add === 'function') {
    body.classList.remove('mereka-tenant--mereka', 'mereka-tenant--biji-biji', 'mereka-tenant--skillourfuture');
    body.classList.add(`mereka-tenant--${tenantSlug}`);
  }
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
  const variant = getMerekaVariant(typeof window !== 'undefined' ? window.location.hostname : '', config);
  const primary = normalizeTenantPaletteValue(config.PRIMARY_COLOR);
  const secondary = normalizeTenantPaletteValue(config.SECONDARY_COLOR);
  const accent = normalizeTenantPaletteValue(config.ACCENT_COLOR);
  const textOnPrimary = normalizeTenantPaletteValue(config.TEXT_ON_PRIMARY);
  const tenantSlug = variant && variant.slug ? variant.slug : 'mereka';

  const paletteBridge = {
    '--tenant-color-primary': primary,
    '--tenant-color-secondary': secondary,
    '--tenant-color-accent': accent,
    '--tenant-color-text-on-primary': textOnPrimary,
    '--tenant-shell-identity': tenantSlug,
    '--mereka-color-magenta': primary,
    '--mereka-color-magenta-dark': primary,
    '--mereka-color-teal': secondary,
    '--mereka-color-blue': accent,
    '--mereka-color-info': accent,
    '--pgn-color-primary-base': primary,
    '--pgn-color-primary-400': primary,
    '--pgn-color-primary-500': primary,
    '--pgn-color-primary-700': primary,
    '--pgn-color-brand-base': primary,
    '--pgn-color-brand-700': primary,
    '--pgn-color-secondary-base': secondary,
    '--pgn-color-info-base': accent,
    '--pgn-link-color': primary,
    '--pgn-link-hover-color': secondary,
    '--pgn-btn-color': primary,
    '--pgn-btn-hover-color': primary,
  };

  for (const [propertyName, value] of Object.entries(paletteBridge)) {
    if (value) {
      rootStyle.setProperty(propertyName, value);
    }
  }
};

(function _deferPaletteBridge() {
  const _tryApply = () => {
    if (typeof getConfig !== 'function') return false;
    const cfg = getConfig() || {};
    if (!cfg.PRIMARY_COLOR) return false;
    applyMerekaTenantIdentity();
    applyMerekaTenantPaletteBridge();
    return true;
  };
  if (_tryApply()) return;
  let attempts = 0;
  const _interval = setInterval(() => {
    if (_tryApply() || ++attempts > 50) clearInterval(_interval);
  }, 200);
})();
