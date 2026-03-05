// Runtime configuration for SkillOurFuture Enterprise MFEs
// Injected via ConfigMap at /openedx/dist/env.config.js
//
// Branding: LOGO_URL, FAVICON_URL, SITE_NAME configure @edx/frontend-platform.
// PARAGON_THEME: points MFE shell to SkillOurFuture theme CSS served from /theme/ in the
// same container (COPY'd into /openedx/dist/theme/ at Docker build time).
window.ENV_CONFIG = {
  LMS_BASE_URL: 'https://skillourfuture.academy.mereka.io',
  STUDIO_BASE_URL: 'https://studio.skillourfuture.academy.mereka.io',
  LOGIN_URL: 'https://skillourfuture.academy.mereka.io/login',
  LOGOUT_URL: 'https://skillourfuture.academy.mereka.io/logout',
  REFRESH_ACCESS_TOKEN_ENDPOINT: 'https://skillourfuture.academy.mereka.io/login_refresh',
  ACCESS_TOKEN_COOKIE_NAME: 'edx-jwt-cookie-header-payload',
  CSRF_TOKEN_API_PATH: '/csrf/api/v1/token',
  ENTERPRISE_CATALOG_API_BASE_URL: 'https://admin.skillourfuture.academy.mereka.io/api/enterprise-catalog',
  ENTERPRISE_ACCESS_BASE_URL: 'https://admin.skillourfuture.academy.mereka.io/api/enterprise-access',
  LICENSE_MANAGER_URL: 'https://admin.skillourfuture.academy.mereka.io/api/license-manager',
  ENTERPRISE_SUBSIDY_BASE_URL: 'https://admin.skillourfuture.academy.mereka.io/api/enterprise-subsidy',
  FEATURE_ENROLL_WITH_CODES: true,
  FEATURE_BROWSE_AND_REQUEST: true,

  // SkillOurFuture branding — served from /theme/ and / in the MFE container
  LOGO_URL: '/logo.svg',
  LOGO_WHITE_URL: '/logo-white.svg',
  LOGO_TRADEMARK_URL: '/logo-trademark.svg',
  FAVICON_URL: '/favicon.ico',
  SITE_NAME: 'SkillOurFuture Academy',
};

// Runtime Paragon theme — tells the MFE shell which CSS files to load.
// These are served by Caddy from /openedx/dist/theme/ (same container).
window.PARAGON_THEME = {
  paragon: {
    version: '23.19.1',
    themeUrls: {
      core: { fileName: './theme/core.min.css' },
      variants: {
        light: { fileName: './theme/light.min.css' },
      },
    },
  },
  brand: {
    version: '1.0.0',
    themeUrls: {
      core: { fileName: './theme/sof-brand.min.css' },
      defaults: { light: 'light' },
      variants: {
        light: { fileName: './theme/sof-brand-light.min.css' },
      },
    },
  },
};
