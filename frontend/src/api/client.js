// ---------------------------------------------------------------------------
// Thin fetch wrapper around the Open edX REST API.
//
// Two key changes from the Phase-0 stub:
//   1. `auth: false` skips the Authorization header AND the
//      `credentials: 'include'` — useful for public endpoints where sending
//      cookies can trigger CORS preflights unnecessarily.
//   2. On 401, we emit `mereka:auth-expired` so the router can bounce the
//      user to the MFE login screen.
// ---------------------------------------------------------------------------

import { config } from '../config.js';
import { getSession, clearSession } from '../auth/session.js';

export class ApiError extends Error {
  constructor(message, { status, statusText, body, url } = {}) {
    super(message);
    this.name = 'ApiError';
    this.status = status;
    this.statusText = statusText;
    this.body = body;
    this.url = url;
  }
}

function buildUrl(path) {
  if (/^https?:\/\//i.test(path)) return path;
  const base = config.openedx.baseUrl.replace(/\/+$/, '');
  return base + (path.startsWith('/') ? path : '/' + path);
}

async function parseBody(res) {
  const ct = res.headers.get('content-type') || '';
  if (ct.includes('application/json')) {
    try { return await res.json(); } catch { return null; }
  }
  try { return await res.text(); } catch { return null; }
}

async function request(method, path, { body, auth = true, headers = {} } = {}) {
  const url = buildUrl(path);
  const finalHeaders = new Headers(headers);
  finalHeaders.set('Accept', 'application/json');
  if (body !== undefined && !(body instanceof FormData)) {
    finalHeaders.set('Content-Type', 'application/json');
  }

  const session = getSession();
  if (auth && session?.accessToken) {
    finalHeaders.set('Authorization', `Bearer ${session.accessToken}`);
  }

  const init = {
    method,
    headers: finalHeaders,
    credentials: auth ? 'include' : 'omit',
    mode: 'cors',
  };
  if (body !== undefined) {
    init.body = body instanceof FormData ? body : JSON.stringify(body);
  }

  let res;
  try {
    res = await fetch(url, init);
  } catch (err) {
    throw new ApiError(`Network error calling ${url}`, { url, body: String(err) });
  }

  if (res.status === 401 && auth) {
    clearSession();
    window.dispatchEvent(new CustomEvent('mereka:auth-expired', { detail: { url } }));
  }

  if (!res.ok) {
    const payload = await parseBody(res);
    throw new ApiError(`API ${res.status} on ${path}`, {
      status: res.status,
      statusText: res.statusText,
      body: payload,
      url,
    });
  }

  return parseBody(res);
}

export const apiGet    = (path, opts)       => request('GET',    path, opts);
export const apiPost   = (path, body, opts) => request('POST',   path, { ...opts, body });
export const apiPatch  = (path, body, opts) => request('PATCH',  path, { ...opts, body });
export const apiPut    = (path, body, opts) => request('PUT',    path, { ...opts, body });
export const apiDelete = (path, opts)       => request('DELETE', path, opts);
