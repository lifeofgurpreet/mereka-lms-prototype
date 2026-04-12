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
  themeBrandUrl: '../theme/mereka-brand.min.css',
  themeBrandLightUrl: '../theme/mereka-brand-light.min.css',
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
