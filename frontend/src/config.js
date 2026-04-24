// ---------------------------------------------------------------------------
// Frozen runtime config, sourced from Vite's import.meta.env.
// Phase 0.5: adds authnUrl + studioUrl so the auth module can redirect
// to the MFE login without hard-coding URLs.
// ---------------------------------------------------------------------------

function pick(key, fallback = '') {
  const v = import.meta.env[key];
  if (v === undefined || v === '') return fallback;
  return v;
}

function required(key) {
  const v = pick(key, '');
  if (!v) {
    console.warn(`[config] ${key} is not set. Using safe default; expect reduced functionality.`);
  }
  return v;
}

function bool(key, fallback = false) {
  const v = pick(key, '');
  if (v === '') return fallback;
  return /^(1|true|yes|on)$/i.test(String(v));
}

export const config = Object.freeze({
  openedx: Object.freeze({
    baseUrl: required('VITE_OPENEDX_BASE_URL') || 'https://academyv2.mereka.dev',
    authnUrl:
      pick('VITE_OPENEDX_AUTHN_URL') || 'https://apps.academyv2.mereka.dev',
    studioUrl:
      pick('VITE_OPENEDX_STUDIO_URL') || 'https://studio.academyv2.mereka.dev',
  }),
  oauth: Object.freeze({
    clientId: pick('VITE_OAUTH_CLIENT_ID', ''),
    redirectUri:
      pick('VITE_OAUTH_REDIRECT_URI') ||
      (typeof window !== 'undefined'
        ? window.location.origin + '/auth/callback'
        : 'http://localhost:5173/auth/callback'),
  }),
  flags: Object.freeze({
    useMockData: bool('VITE_USE_MOCK_DATA', false),
    showCrossDomainAuthNotice: bool('VITE_SHOW_CROSS_DOMAIN_AUTH_NOTICE', true),
  }),
});
