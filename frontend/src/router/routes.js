// Route table — single source of truth for all pages in the SPA.
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

  { id: 'programs',           path: '/programs',            page: () => import('../pages/programs.js'),           auth: 'optional' },
  { id: 'program-detail',     path: '/programs/:programId', page: () => import('../pages/program-detail.js'),    auth: 'optional' },

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

  // Admin pages
  { id: 'admin-proctoring',    path: '/admin/proctoring',    page: () => import('../pages/admin/proctoring.js'),    auth: 'required' },
  { id: 'admin-credentials',   path: '/admin/credentials',   page: () => import('../pages/admin/credentials.js'),   auth: 'required' },
  { id: 'admin-analytics',     path: '/admin/analytics',     page: () => import('../pages/admin/analytics.js'),     auth: 'required' },
  { id: 'admin-notifications', path: '/admin/notifications', page: () => import('../pages/admin/notifications.js'), auth: 'required' },
  { id: 'admin-multi-tenancy', path: '/admin/multi-tenancy', page: () => import('../pages/admin/multi-tenancy.js'), auth: 'required' },
  { id: 'admin-video-pipeline',path: '/admin/video-pipeline',page: () => import('../pages/admin/video-pipeline.js'),auth: 'required' },
  { id: 'admin-ecommerce',     path: '/admin/ecommerce',     page: () => import('../pages/admin/ecommerce.js'),     auth: 'required' },
  { id: 'admin-lti',           path: '/admin/lti',           page: () => import('../pages/admin/lti.js'),           auth: 'required' },
];

/**
 * Legacy goto(pageId) helpers — preserved so ported prototype HTML keeps working.
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
      const base = r.path.replace(/\/:[^/]+/g, '');
      return [r.id, base + '/' + DEMO_PARAMS[r.id]];
    }
    return [r.id, r.path];
  })
);
