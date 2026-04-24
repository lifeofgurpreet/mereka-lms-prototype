// Thin fetch() wrapper — handles base URL, auth headers, 401 retry, errors.
//
// Usage:
//   import { apiGet, apiPost } from './client.js';
//   const courses = await apiGet('/api/courses/v1/courses/');

import { config } from '../config.js';
import { getSession, clearSession } from '../auth/session.js';

class ApiError extends Error {
  constructor(status, body, url) {
    super(`API ${status} ${url}`);
    this.status = status;
    this.body = body;
    this.url = url;
  }
}

async function request(method, path, { body, query, skipAuth } = {}) {
  const url = new URL(path, config.openedx.baseUrl);
  if (query) {
    for (const [k, v] of Object.entries(query)) {
      if (v !== undefined && v !== null && v !== '') url.searchParams.set(k, v);
    }
  }

  const headers = {
    'Accept': 'application/json',
    'Content-Type': 'application/json',
  };

  if (!skipAuth) {
    const session = getSession();
    if (session) {
      headers.Authorization = `${session.tokenType} ${session.accessToken}`;
    }
  }

  const res = await fetch(url.toString(), {
    method,
    headers,
    body: body ? JSON.stringify(body) : undefined,
    credentials: 'include', // cookies for CSRF
  });

  // 401 → session is stale; clear it and force re-login.
  if (res.status === 401 && !skipAuth) {
    clearSession();
    window.dispatchEvent(new CustomEvent('mereka:auth-expired'));
    throw new ApiError(401, null, url.toString());
  }

  const text = await res.text();
  const data = text ? safeParseJson(text) : null;

  if (!res.ok) {
    throw new ApiError(res.status, data, url.toString());
  }
  return data;
}

function safeParseJson(text) {
  try { return JSON.parse(text); } catch { return text; }
}

export const apiGet    = (path, opts = {}) => request('GET',    path, opts);
export const apiPost   = (path, opts = {}) => request('POST',   path, opts);
export const apiPatch  = (path, opts = {}) => request('PATCH',  path, opts);
export const apiPut    = (path, opts = {}) => request('PUT',    path, opts);
export const apiDelete = (path, opts = {}) => request('DELETE', path, opts);

export { ApiError };
