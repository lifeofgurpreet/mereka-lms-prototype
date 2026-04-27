// Users API — Open edX User Accounts REST v1
// https://{base}/api/user/v1/

import { apiGet, apiPatch, apiPost } from './client.js';
import { config } from '../config.js';
import { mockUser } from './mocks/users.js';

export async function getCurrentUser() {
  if (config.flags.useMockData) return mockUser();
  return apiGet('/api/user/v1/me/');
}

export async function getAccount(username) {
  if (config.flags.useMockData) return mockUser();
  return apiGet(`/api/user/v1/accounts/${encodeURIComponent(username)}`);
}

export async function updateAccount(username, patch) {
  return apiPatch(`/api/user/v1/accounts/${encodeURIComponent(username)}`, {
    body: patch,
  });
}

export async function registerAccount({ email, username, password, name }) {
  return apiPost('/api/user/v1/account/registration/', {
    body: { email, username, password, name, honor_code: 'true' },
    skipAuth: true,
  });
}
