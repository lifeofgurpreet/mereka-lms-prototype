// History API router — uses the shared shell for header/footer/nav.
import { routes, pageIdToPath } from './routes.js';
import { isAuthenticated } from '../auth/session.js';
import { mount as mountShell, setActiveNav, showShell, getContentEl } from '../components/shell.js';

let rootEl = null;
let contentEl = null;

// Pages that should NOT show the app shell (header/footer)
const NO_SHELL_PAGES = ['login', 'register', 'auth-callback'];

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
    showShell(true);
    setActiveNav(null);
    contentEl.innerHTML = '<main style="padding:80px 20px;text-align:center;"><h1>404</h1><p>Page not found.</p><a href="/">Back to dashboard</a></main>';
    return;
  }

  const { route, params } = match;

  // Auth guard — skip for now since we don't have real auth yet.
  // In Phase 0, all pages are accessible for prototyping purposes.
  // if (route.auth === 'required' && !isAuthenticated()) {
  //   navigate('/login?next=' + encodeURIComponent(pathname));
  //   return;
  // }

  // Shell visibility
  const hideShell = NO_SHELL_PAGES.includes(route.id);
  showShell(!hideShell);

  // Set active nav
  setActiveNav(route.id);

  // Render into the right container
  const target = hideShell ? rootEl : contentEl;
  if (hideShell) {
    // For full-page screens (login/register), render directly in root
    rootEl.innerHTML = '';
  }

  const loadingEl = hideShell ? rootEl : contentEl;
  loadingEl.innerHTML = '<main style="padding:80px 20px;text-align:center;opacity:0.5">Loading…</main>';

  try {
    const mod = await route.page();
    await mod.render(loadingEl, { params, query: queryFromLocation() });
  } catch (err) {
    console.error('[router] render failed:', err);
    loadingEl.innerHTML = `<main style="padding:80px 20px;"><h1>Something went wrong</h1><pre>${err.message}</pre></main>`;
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
  // Mount the shell and get the content container
  contentEl = mountShell(mountEl);

  window.addEventListener('popstate', () => render(window.location.pathname));
  window.addEventListener('mereka:auth-expired', () => navigate('/login'));

  // Intercept internal <a href="/..."> clicks for SPA navigation
  document.addEventListener('click', (e) => {
    const a = e.target.closest('a[href]');
    if (!a) return;
    const href = a.getAttribute('href');
    if (!href || href.startsWith('http') || href.startsWith('#') || a.target === '_blank') return;
    e.preventDefault();
    navigate(href);
  });

  // Legacy compat
  window.goto = (pageId) => {
    const path = pageIdToPath[pageId];
    if (path) navigate(path);
    else console.warn('[router] unknown pageId:', pageId);
  };

  render(window.location.pathname);
}
