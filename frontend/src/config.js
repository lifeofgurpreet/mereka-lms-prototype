// ---------------------------------------------------------------------------
// Frozen runtime config, sourced from Vite's import.meta.env.
// Phase 0.5: adds authnUrl + studioUrl so the auth module can redirect
// to the MFE login without hard-coding URLs.
//
// When VITE_OPENEDX_BASE_URL is empty the SPA makes same-origin requests
// (e.g. /api/courses/v1/courses/) which Netlify proxies to academyv2.
// This avoids all CORS issues without touching the Open edX server.
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

// If the env var is explicitly present (even if empty), honour it.
// Only fall back to academyv2 when the key is truly absent.
function pickBaseUrl() {
  const key = 'VITE_OPENEDX_BASE_URL';
  const raw = import.meta.env[key];
  // Vite always stringifies env vars. If the key exists, raw is a string.
  if (raw !== undefined) return raw;          // '' is valid → same-origin proxy
  return 'https://academyv2.mereka.dev';      // local dev without .env
}

export const config = Object.freeze({
  openedx: Object.freeze({
    baseUrl: pickBaseUrl(),
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
