// Runtime configuration for Enterprise MFEs
// Injected via ConfigMap at /openedx/dist/env.config.js
window.ENV_CONFIG = {
  LMS_BASE_URL: 'https://academyv2.mereka.io',
  STUDIO_BASE_URL: 'https://studio.academyv2.mereka.io',
  LOGIN_URL: 'https://academyv2.mereka.io/login',
  LOGOUT_URL: 'https://academyv2.mereka.io/logout',
  REFRESH_ACCESS_TOKEN_ENDPOINT: 'https://academyv2.mereka.io/login_refresh',
  ACCESS_TOKEN_COOKIE_NAME: 'edx-jwt-cookie-header-payload',
  CSRF_TOKEN_API_PATH: '/csrf/api/v1/token',
  ENTERPRISE_CATALOG_API_BASE_URL: 'https://admin.academyv2.mereka.io/api/enterprise-catalog',
  ENTERPRISE_ACCESS_BASE_URL: 'https://admin.academyv2.mereka.io/api/enterprise-access',
  LICENSE_MANAGER_URL: 'https://admin.academyv2.mereka.io/api/license-manager',
  ENTERPRISE_SUBSIDY_BASE_URL: 'https://admin.academyv2.mereka.io/api/enterprise-subsidy',
  FEATURE_ENROLL_WITH_CODES: true,
  FEATURE_BROWSE_AND_REQUEST: true,
};
