// Runtime configuration for Enterprise MFEs
// Injected via ConfigMap at /openedx/dist/env.config.js
//
// BASE DEFAULTS: This file uses localhost placeholders so the base package
// is environment-neutral. Overlays MUST replace this ConfigMap with the
// correct environment-specific URLs via configMapGenerator behavior: replace.
//
// See: deploy/k8s/overlays/local/kustomization.yaml for the local override.
//
// Branding: LOGO_URL, FAVICON_URL, SITE_NAME configure @edx/frontend-platform.
// PARAGON_THEME: points MFE shell to Mereka theme CSS served from /theme/ in the
// same container (COPY'd into /openedx/dist/theme/ at Docker build time).
window.ENV_CONFIG = {
  LMS_BASE_URL: 'http://localhost',
  STUDIO_BASE_URL: 'http://studio.localhost',
  LOGIN_URL: 'http://localhost/login',
  LOGOUT_URL: 'http://localhost/logout',
  REFRESH_ACCESS_TOKEN_ENDPOINT: 'http://localhost/login_refresh',
  ACCESS_TOKEN_COOKIE_NAME: 'edx-jwt-cookie-header-payload',
  INTEGRATION_WARNING_DISMISSED_COOKIE_NAME: 'integration-warning-dismissed',
  CSRF_TOKEN_API_PATH: '/csrf/api/v1/token',
  ENTERPRISE_CATALOG_API_BASE_URL: 'http://admin.localhost/api/enterprise-catalog',
  ENTERPRISE_ACCESS_BASE_URL: 'http://admin.localhost/api/enterprise-access',
  LICENSE_MANAGER_URL: 'http://admin.localhost/api/license-manager',
  ENTERPRISE_SUBSIDY_BASE_URL: 'http://admin.localhost/api/enterprise-subsidy',
  FEATURE_ENROLL_WITH_CODES: true,
  FEATURE_BROWSE_AND_REQUEST: true,

  // Mereka branding — served from /theme/ and / in the MFE container
  LOGO_URL: '/logo.svg',
  LOGO_WHITE_URL: '/logo-white.svg',
  LOGO_TRADEMARK_URL: '/logo-trademark.svg',
  FAVICON_URL: '/favicon.ico',
  SITE_NAME: 'Mereka Academy',
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
      core: { fileName: './theme/mereka-brand.min.css' },
      defaults: { light: 'light' },
      variants: {
        light: { fileName: './theme/mereka-brand-light.min.css' },
      },
    },
  },
};
