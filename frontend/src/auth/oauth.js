// ---------------------------------------------------------------------------
// Auth module — cookie-first, OAuth2-PKCE-capable.
//
// Strategy (see docs/AUTH_STRATEGY.md for the full write-up):
//
//   Tier A  PUBLIC              No auth at all. Discover, course detail
//                               preview, outline for public blocks.
//
//   Tier B  COOKIE (preferred)  When the SPA is hosted under *.mereka.dev
//                               we reuse the JWT cookies that Open edX's
//                               MFEs already set after signing in at
//                               apps.academyv2.mereka.dev/authn/login.
//                               No OAuth app registration is needed.
//
//   Tier C  PKCE (optional)     Once Gurpreet registers a public OAuth2
//                               client for this SPA, flip the flag on and
//                               we run a standard PKCE auth-code flow.
//
// This file exposes one public API: { login, handleCallback, logout,
// isAuthenticated, fetchCurrentUser }. The router calls login() / logout();
// pages call fetchCurrentUser() when they need to personalize content.
// ---------------------------------------------------------------------------

import { config } from '../config.js';
import { apiGet, ApiError } from '../api/client.js';
import { getSession, setSession, clearSession, isAuthenticated } from './session.js';

export { isAuthenticated };

/** Is the current hostname under *.mereka.dev? Controls cookie-mode eligibility. */
function canUseCookieAuth() {
  try {
    const host = window.location.hostname || '';
    return host === 'mereka.dev' || host.endsWith('.mereka.dev');
  } catch {
    return false;
  }
}

/** Fetch /api/user/v1/me — the canonical "who am I" probe for Open edX. */
export async function fetchCurrentUser() {
  try {
    const me = await apiGet('/api/user/v1/me', { auth: true });
    return me;
  } catch (err) {
    if (err instanceof ApiError && err.status === 401) return null;
    throw err;
  }
}

/** Kick off login. */
export async function login({ returnTo } = {}) {
  const target = returnTo || window.location.pathname + window.location.search;

  // If cookie auth is available, do the MFE redirect dance — no PKCE needed.
  if (canUseCookieAuth() || !config.oauth.clientId) {
    const next = encodeURIComponent(window.location.origin + target);
    const url = `${config.openedx.authnUrl}/authn/login?next=${next}`;
    window.location.assign(url);
    return;
  }

  // PKCE flow — only when a client id is configured.
  const { codeVerifier, codeChallenge } = await makePkcePair();
  const stateToken = crypto.randomUUID();
  sessionStorage.setItem('mereka.oauth.verifier', codeVerifier);
  sessionStorage.setItem('mereka.oauth.state', stateToken);
  sessionStorage.setItem('mereka.oauth.return_to', target);

  const params = new URLSearchParams({
    response_type: 'code',
    client_id: config.oauth.clientId,
    redirect_uri: config.oauth.redirectUri,
    scope: 'read write profile email',
    state: stateToken,
    code_challenge: codeChallenge,
    code_challenge_method: 'S256',
  });
  window.location.assign(`${config.openedx.baseUrl}/oauth2/authorize/?${params.toString()}`);
}

/** Handle the /auth/callback round-trip. */
export async function handleCallback() {
  const url = new URL(window.location.href);
  const code = url.searchParams.get('code');
  const stateParam = url.searchParams.get('state');
  const savedState = sessionStorage.getItem('mereka.oauth.state');
  const verifier = sessionStorage.getItem('mereka.oauth.verifier');
  const returnTo = sessionStorage.getItem('mereka.oauth.return_to') || '/';

  sessionStorage.removeItem('mereka.oauth.state');
  sessionStorage.removeItem('mereka.oauth.verifier');
  sessionStorage.removeItem('mereka.oauth.return_to');

  if (!code || !stateParam || stateParam !== savedState) {
    throw new Error('OAuth callback: invalid state or missing code.');
  }

  const body = new URLSearchParams({
    grant_type: 'authorization_code',
    code,
    redirect_uri: config.oauth.redirectUri,
    client_id: config.oauth.clientId,
    code_verifier: verifier,
  });

  const res = await fetch(`${config.openedx.baseUrl}/oauth2/access_token/`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body,
  });
  if (!res.ok) {
    const text = await res.text();
    throw new Error(`Token exchange failed: ${res.status} ${text.slice(0, 160)}`);
  }
  const tok = await res.json();
  setSession({
    accessToken: tok.access_token,
    refreshToken: tok.refresh_token || null,
    expiresAt: Date.now() + (tok.expires_in || 3600) * 1000,
    scope: tok.scope || '',
  });
  return returnTo;
}

/** Clear local state + best-effort revoke. */
export async function logout() {
  const session = getSession();
  clearSession();
  if (canUseCookieAuth()) {
    // Hop through the LMS logout so the shared cookies on .mereka.dev clear.
    window.location.assign(`${config.openedx.baseUrl}/logout?next=${encodeURIComponent(window.location.origin)}`);
    return;
  }
  if (session?.accessToken && config.oauth.clientId) {
    try {
      await fetch(`${config.openedx.baseUrl}/oauth2/revoke_token/`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
        body: new URLSearchParams({
          token: session.accessToken,
          client_id: config.oauth.clientId,
        }),
      });
    } catch { /* best-effort */ }
  }
}

// ---------------------------------------------------------------------------
// PKCE helpers
// ---------------------------------------------------------------------------
async function makePkcePair() {
  const bytes = crypto.getRandomValues(new Uint8Array(32));
  const codeVerifier = base64url(bytes);
  const digest = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(codeVerifier));
  const codeChallenge = base64url(new Uint8Array(digest));
  return { codeVerifier, codeChallenge };
}

function base64url(bytes) {
  let s = btoa(String.fromCharCode(...bytes));
  return s.replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}
