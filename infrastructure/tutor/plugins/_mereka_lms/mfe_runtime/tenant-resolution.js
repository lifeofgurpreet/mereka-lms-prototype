// Tenant branding data contracts and resolution logic.
// Used by all surface modules to look up per-tenant branding, URLs, and copy.

const normalizeHostname = (hostname) => {
  return (typeof hostname === 'string' ? hostname.toLowerCase() : '').replace(/^www\./, '');
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

// Shared tenant configs — reused for prod and dev hostname entries.
const _MEREKA_ACADEMY = {
  ...MEREKA_BASE_VARIANT,
  brand: 'Mereka Academy',
  copyrightHolder: 'MEREKA',
  supportEmail: 'support@mereka.io',
};

const _BIJI_BIJI = {
  ...MEREKA_BASE_VARIANT,
  logoUrl: '/theme/biji-biji/logo-horizontal.svg',
  mobileLogoUrl: '/theme/biji-biji/logo.svg',
  themeBrandUrl: '../theme/biji-biji-brand.min.css',
  themeBrandLightUrl: '../theme/biji-biji-brand-light.min.css',
  brand: 'Biji-Biji Academy',
  copyrightHolder: 'Biji-Biji Initiative',
  supportEmail: 'techadmin@biji-biji.com',
};

const _SKILL_OUR_FUTURE = {
  ...MEREKA_BASE_VARIANT,
  logoUrl: '/theme/skillourfuture/logo-horizontal.svg',
  mobileLogoUrl: '/theme/skillourfuture/logo.svg',
  themeBrandUrl: '../theme/sof-brand.min.css',
  themeBrandLightUrl: '../theme/sof-brand-light.min.css',
  brand: 'Skill Our Future Academy',
  copyrightHolder: 'MEREKA',
  supportEmail: 'support@mereka.io',
};

const MEREKA_SITE_VARIANTS = {
  // Production hostnames
  'academyv2.mereka.io': _MEREKA_ACADEMY,
  'academy.biji-biji.com': _BIJI_BIJI,
  'skillourfuture.academy.mereka.io': _SKILL_OUR_FUTURE,
  // Dev hostnames (academyv2.mereka.dev zone)
  'academyv2.mereka.dev': _MEREKA_ACADEMY,
  'biji-biji.academyv2.mereka.dev': _BIJI_BIJI,
  'skillourfuture.academyv2.mereka.dev': _SKILL_OUR_FUTURE,
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
