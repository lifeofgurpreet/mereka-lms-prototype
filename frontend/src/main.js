// Mereka LMS SPA — entry point.
//
// Bootstraps the router, handles auth callback, and mounts the app into #app.

import { initRouter } from './router/router.js';
import { handleCallback } from './auth/oauth.js';
import { config } from './config.js';
import './styles/globals.scss';

async function boot() {
  console.info('[mereka-lms] booting', {
    openedx: config.openedx.baseUrl,
    mockData: config.flags.useMockData,
  });

  const app = document.getElementById('app');
  if (!app) throw new Error('No #app element in index.html');

  // Auth callback must run BEFORE router mount so the token is ready.
  if (window.location.pathname === '/auth/callback') {
    try {
      await handleCallback();
      const next = new URL(window.location.href).searchParams.get('next') || '/';
      window.history.replaceState(null, '', next);
    } catch (err) {
      console.error('[auth] callback failed', err);
      window.history.replaceState(null, '', '/login?error=callback_failed');
    }
  }

  initRouter(app);
}

boot();
