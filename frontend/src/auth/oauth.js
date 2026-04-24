// OAuth2 Authorization Code + PKCE flow against Open edX.
//
// Uses `oauth4webapi` for spec-compliant PKCE generation. Open edX's
// OAuth2 provider (django-oauth-toolkit) supports PKCE when the
// OAuth app is registered with `PKCE required = true`.
//
// Flow:
//   1. login() — redirect to {baseUrl}/oauth2/authorize with code_challenge
//   2. Open edX logs the user in, redirects back to {redirectUri}?code=XXX
//   3. handleCallback() — exchange code for tokens at /oauth2/access_token
//   4. setSession(tokens) — access token in sessionStorage
//
// Refresh tokens: handled by a Netlify Edge Function that sets an
// httpOnly cookie. Not yet wired — STUB for now. See infra/netlify-edge/.

import * as oauth from 'oauth4webapi';
import { config } from '../config.js';
import { setSession, clearSession, getSession } from './session.js';

const PKCE_KEY = 'mereka.pkce.v1';

function openedxAuthServer() {
  return {
    issuer: config.openedx.baseUrl,
    authorization_endpoint: config.openedx.baseUrl + config.oauth.authorizeEndpoint,
    token_endpoint: config.openedx.baseUrl + config.oauth.tokenEndpoint,
    revocation_endpoint: config.openedx.baseUrl + config.oauth.revokeEndpoint,
  };
}

function client() {
  return { client_id: config.oauth.clientId, token_endpoint_auth_method: 'none' };
}

/**
 * Kick off the login redirect. Stores PKCE verifier + state in sessionStorage
 * so handleCallback() can verify the round-trip.
 */
export async function login() {
  const verifier = oauth.generateRandomCodeVerifier();
  const challenge = await oauth.calculatePKCECodeChallengeFromVerifier(verifier);
  const state = oauth.generateRandomState();

  sessionStorage.setItem(PKCE_KEY, JSON.stringify({ verifier, state }));

  const url = new URL(openedxAuthServer().authorization_endpoint);
  url.searchParams.set('response_type', 'code');
  url.searchParams.set('client_id', config.oauth.clientId);
  url.searchParams.set('redirect_uri', config.oauth.redirectUri);
  url.searchParams.set('scope', config.oauth.scopes);
  url.searchParams.set('state', state);
  url.searchParams.set('code_challenge', challenge);
  url.searchParams.set('code_challenge_method', 'S256');

  window.location.assign(url.toString());
}

/**
 * Called on /auth/callback — exchanges ?code= for access token.
 * Returns true on success, throws on failure.
 */
export async function handleCallback() {
  const stored = JSON.parse(sessionStorage.getItem(PKCE_KEY) || '{}');
  sessionStorage.removeItem(PKCE_KEY);

  const params = oauth.validateAuthResponse(
    openedxAuthServer(),
    client(),
    new URL(window.location.href),
    stored.state,
  );
  if (oauth.isOAuth2Error(params)) {
    throw new Error(`OAuth error: ${params.error} ${params.error_description}`);
  }

  const response = await oauth.authorizationCodeGrantRequest(
    openedxAuthServer(),
    client(),
    params,
    config.oauth.redirectUri,
    stored.verifier,
  );
  const result = await oauth.processAuthorizationCodeOAuth2Response(
    openedxAuthServer(),
    client(),
    response,
  );
  if (oauth.isOAuth2Error(result)) {
    throw new Error(`Token exchange failed: ${result.error}`);
  }

  setSession({
    accessToken: result.access_token,
    expiresAt: Date.now() + (result.expires_in ?? 3600) * 1000,
    tokenType: result.token_type ?? 'Bearer',
  });
  return true;
}

export async function logout() {
  const s = getSession();
  if (s) {
    // Best-effort revoke; ignore errors.
    try {
      await fetch(openedxAuthServer().revocation_endpoint, {
        method: 'POST',
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
        body: new URLSearchParams({
          token: s.accessToken,
          client_id: config.oauth.clientId,
        }),
      });
    } catch {}
  }
  clearSession();
  window.location.assign('/');
}
