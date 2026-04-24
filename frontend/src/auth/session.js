// Session storage — holds OAuth2 tokens in sessionStorage.
//
// Why sessionStorage and not localStorage:
//   - Scoped to the tab (closing the tab clears the session — good for shared devices)
//   - Not accessible to third-party iframes
//   - Refresh tokens live in an httpOnly cookie (set by our Netlify Edge Fn),
//     not here, so XSS can only grab the short-lived access token.

const KEY = 'mereka.session.v1';

/** @typedef {{ accessToken: string, expiresAt: number, tokenType: string }} Session */

/** @returns {Session | null} */
export function getSession() {
  try {
    const raw = sessionStorage.getItem(KEY);
    if (!raw) return null;
    const s = JSON.parse(raw);
    if (!s.accessToken || s.expiresAt < Date.now()) {
      clearSession();
      return null;
    }
    return s;
  } catch {
    return null;
  }
}

/** @param {Session} session */
export function setSession(session) {
  sessionStorage.setItem(KEY, JSON.stringify(session));
}

export function clearSession() {
  sessionStorage.removeItem(KEY);
}

export function isAuthenticated() {
  return getSession() !== null;
}
