// Route table — single source of truth for the 17 pages in the SPA.
//
// Each entry:
//   path: URL pattern (supports :param)
//   page: dynamic import of the page module (code-split)
//   auth: 'required' | 'optional' | 'forbidden'

export const routes = [
  { id: 'login',             path: '/login',              page: () => import('../pages/login.js'),             auth: 'forbidden' },
  { id: 'register',          path: '/register',           page: () => import('../pages/register.js'),          auth: 'forbidden' },
  { id: 'auth-callback',     path: '/auth/callback',      page: () => import('../pages/auth-callback.js'),     auth: 'optional' },

  { id: 'dashboard',         path: '/',                   page: () => import('../pages/dashboard.js'),         auth: 'required' },
  { id: 'discover',          path: '/discover',           page: () => import('../pages/discover.js'),          auth: 'optional' },
  { id: 'course',            path: '/course/:courseId',   page: () => import('../pages/course.js'),            auth: 'optional' },
  { id: 'unit',              path: '/learn/:courseId/:unitId', page: () => import('../pages/unit.js'),         auth: 'required' },

  { id: 'mylearning',        path: '/my-learning',        page: () => import('../pages/mylearning.js'),        auth: 'required' },
  { id: 'continue-learning', path: '/continue',           page: () => import('../pages/continue-learning.js'), auth: 'required' },
  { id: 'deadlines',         path: '/deadlines',          page: () => import('../pages/deadlines.js'),         auth: 'required' },
  { id: 'wishlist',          path: '/wishlist',           page: () => import('../pages/wishlist.js'),          auth: 'required' },

  { id: 'checkout',          path: '/checkout/:courseId', page: () => import('../pages/checkout.js'),          auth: 'required' },
  { id: 'enrollment-success',path: '/enrolled/:courseId', page: () => import('../pages/enrollment-success.js'),auth: 'required' },

  { id: 'certificates',      path: '/certificates',       page: () => import('../pages/certificates.js'),      auth: 'required' },
  { id: 'certificate',       path: '/certificate/:certId',page: () => import('../pages/certificate.js'),       auth: 'required' },

  { id: 'profile',           path: '/profile',            page: () => import('../pages/profile.js'),           auth: 'required' },
  { id: 'settings',          path: '/settings',           page: () => import('../pages/settings.js'),          auth: 'required' },

  { id: 'studio',            path: '/studio',             page: () => import('../pages/studio-redirect.js'),   auth: 'required' },
];

/**
 * Legacy goto(pageId) helpers — preserved so ported prototype HTML keeps working.
 * For parameterised routes we supply demo placeholder IDs so the link still works
 * (e.g. goto('course') → /course/demo, goto('unit') → /learn/demo/1).
 */
const DEMO_PARAMS = {
  course:             'demo',
  unit:               'demo/1',
  checkout:           'demo',
  'enrollment-success': 'demo',
  certificate:        'demo',
};

export const pageIdToPath = Object.fromEntries(
  routes.map((r) => {
    if (DEMO_PARAMS[r.id]) {
      // Strip the param segments and append demo values
      const base = r.path.replace(/\/:[^/]+/g, '');
      return [r.id, base + '/' + DEMO_PARAMS[r.id]];
    }
    return [r.id, r.path];
  })
);
