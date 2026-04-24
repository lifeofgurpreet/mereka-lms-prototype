// History API router — replaces the prototype's goto(pageId) function.
//
// Usage:
//   import { initRouter, navigate } from './router.js';
//   initRouter(document.getElementById('app'));
//   navigate('/course/course-v1:Mereka+DESIGN101+2026');
//
// Legacy compatibility:
//   window.goto = (pageId) => navigate(pageIdToPath[pageId]);
// ...is installed by initRouter() so existing inline onclick handlers still work.

import { routes, pageIdToPath } from './routes.js';
import { isAuthenticated } from '../auth/session.js';

let rootEl = null;

function matchRoute(pathname) {
  for (const route of routes) {
    const pattern = route.path
      .replace(/:[^/]+/g, '([^/]+)')
      .replace(/\//g, '\\/');
    const re = new RegExp(`^${pattern}$`);
    const m = pathname.match(re);
    if (m) {
      const paramNames = (route.path.match(/:[^/]+/g) || []).map((s) => s.slice(1));
      const params = Object.fromEntries(paramNames.map((n, i) => [n, m[i + 1]]));
      return { route, params };
    }
  }
  return null;
}

async function render(pathname) {
  const match = matchRoute(pathname);
  if (!match) {
    rootEl.innerHTML = '<main style="padding:80px 20px;text-align:center;"><h1>404</h1><p>Page not found.</p><a href="/">Back to dashboard</a></main>';
    return;
  }

  const { route, params } = match;

  if (route.auth === 'required' && !isAuthenticated()) {
    navigate('/login?next=' + encodeURIComponent(pathname));
    return;
  }
  if (route.auth === 'forbidden' && isAuthenticated()) {
    navigate('/');
    return;
  }

  rootEl.innerHTML = '<main style="padding:80px 20px;text-align:center;opacity:0.5">Loading…</main>';
  try {
    const mod = await route.page();
    await mod.render(rootEl, { params, query: queryFromLocation() });
  } catch (err) {
    console.error('[router] render failed:', err);
    rootEl.innerHTML = `<main style="padding:80px 20px;"><h1>Something went wrong</h1><pre>${err.message}</pre></main>`;
  }
}

function queryFromLocation() {
  return Object.fromEntries(new URL(window.location.href).searchParams);
}

export function navigate(path, { replace = false } = {}) {
  if (replace) window.history.replaceState(null, '', path);
  else window.history.pushState(null, '', path);
  render(window.location.pathname);
}

export function initRouter(mountEl) {
  rootEl = mountEl;
  window.addEventListener('popstate', () => render(window.location.pathname));
  window.addEventListener('mereka:auth-expired', () => navigate('/login'));

  // Intercept internal <a href="/..."> clicks for SPA navigation.
  document.addEventListener('click', (e) => {
    const a = e.target.closest('a[href]');
    if (!a) return;
    const href = a.getAttribute('href');
    if (!href || href.startsWith('http') || href.startsWith('#') || a.target === '_blank') return;
    e.preventDefault();
    navigate(href);
  });

  // Legacy compat for ported prototype HTML.
  window.goto = (pageId) => {
    const path = pageIdToPath[pageId];
    if (path) navigate(path);
    else console.warn('[router] unknown pageId:', pageId);
  };

  render(window.location.pathname);
}
