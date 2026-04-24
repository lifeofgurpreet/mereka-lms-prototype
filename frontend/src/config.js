// Runtime configuration — read from Vite env vars, validated on boot.
//
// All backend-talking code imports from here. When we migrate between
// staging and prod, only env vars change — no code edits.

const required = (key, fallback = undefined) => {
  const value = import.meta.env[key] ?? fallback;
  if (value === undefined || value === 'REPLACE_ME') {
    console.warn(
      `[config] ${key} is not set. Set it in frontend/.env.local or Netlify env vars.`,
    );
  }
  return value;
};

export const config = Object.freeze({
  openedx: {
    baseUrl: required('VITE_OPENEDX_BASE_URL', 'https://staging-learn.mereka.org'),
  },
  oauth: {
    clientId: required('VITE_OAUTH_CLIENT_ID', 'REPLACE_ME'),
    redirectUri: required(
      'VITE_OAUTH_REDIRECT_URI',
      `${window.location.origin}/auth/callback`,
    ),
    authorizeEndpoint: '/oauth2/authorize/',
    tokenEndpoint: '/oauth2/access_token/',
    revokeEndpoint: '/oauth2/revoke_token/',
    scopes: 'read write profile email',
  },
  flags: {
    useMockData:
      import.meta.env.VITE_USE_MOCK_DATA === 'true' || import.meta.env.DEV,
  },
});
