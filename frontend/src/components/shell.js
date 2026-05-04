// Shared app shell — header (logo, nav, actions) + footer.
// Mobile hamburger menu + accessibility skip link + admin nav support.

const LOGO_SVG = `<img src="/mereka-logo.svg" alt="Mereka" style="height:28px;width:auto;display:block;" />`;

const NAV_ITEMS = [
  { id: 'dashboard', label: 'Dashboard', path: '/' },
  { id: 'discover', label: 'Discover', path: '/discover' },
  { id: 'programs', label: 'Programs', path: '/programs' },
  { id: 'mylearning', label: 'My Learning', path: '/my-learning' },
];

const ADMIN_NAV_ITEMS = [
  { id: 'admin-proctoring', label: 'Proctoring', path: '/admin/proctoring' },
  { id: 'admin-credentials', label: 'Credentials', path: '/admin/credentials' },
  { id: 'admin-analytics', label: 'Analytics', path: '/admin/analytics' },
  { id: 'admin-notifications', label: 'Notifications', path: '/admin/notifications' },
  { id: 'admin-multi-tenancy', label: 'Tenants', path: '/admin/multi-tenancy' },
  { id: 'admin-video-pipeline', label: 'Video', path: '/admin/video-pipeline' },
  { id: 'admin-ecommerce', label: 'E-commerce', path: '/admin/ecommerce' },
  { id: 'admin-lti', label: 'LTI Tools', path: '/admin/lti' },
];

let _activeNav = 'dashboard';
let _headerEl = null;
let _mobileMenuOpen = false;

function headerHtml() {
  return `
  <a class="skip-link" href="#main-content">Skip to main content</a>
  <header class="lms-header" role="banner">
    <a class="lms-logo" href="/" aria-label="Mereka Home">${LOGO_SVG}</a>

    <!-- Mobile hamburger -->
    <button class="lms-hamburger js-hamburger" aria-label="Open navigation menu" aria-expanded="false" aria-controls="mobile-nav">
      <span class="material-symbols-outlined">menu</span>
    </button>

    <!-- Desktop nav -->
    <nav class="lms-nav" aria-label="Main navigation">
      ${NAV_ITEMS.map(n => `<a href="${n.path}" class="${n.id === _activeNav ? 'is-active' : ''}" ${n.id === _activeNav ? 'aria-current="page"' : ''}>${n.label}</a>`).join('')}
    </nav>
    <div class="lms-header__spacer"></div>
    <div class="lms-header__actions">
      <a href="/studio" class="btn btn--ghost btn--sm"><span class="material-symbols-outlined" style="font-size:16px;">edit_note</span> Studio</a>
      <a href="/admin/analytics" class="btn btn--ghost btn--sm lms-admin-link"><span class="material-symbols-outlined" style="font-size:16px;">admin_panel_settings</span> Admin</a>
      <a href="/wishlist" class="icon-btn" aria-label="Wishlist"><span class="material-symbols-outlined">favorite</span></a>
      <button class="icon-btn js-notif-toggle" aria-label="Notifications"><span class="material-symbols-outlined">notifications</span><span class="badge">3</span></button>
      <a href="/profile" class="avatar" role="button" aria-label="Profile" style="text-decoration:none;">FF</a>
    </div>
  </header>

  <!-- Mobile nav drawer -->
  <nav class="lms-mobile-nav" id="mobile-nav" aria-label="Mobile navigation" hidden>
    <div class="lms-mobile-nav__backdrop js-mobile-nav-close"></div>
    <div class="lms-mobile-nav__panel">
      <div class="lms-mobile-nav__header">
        ${LOGO_SVG}
        <button class="icon-btn js-mobile-nav-close" aria-label="Close menu"><span class="material-symbols-outlined">close</span></button>
      </div>
      <div class="lms-mobile-nav__links">
        ${NAV_ITEMS.map(n => `<a href="${n.path}" class="${n.id === _activeNav ? 'is-active' : ''}">${n.label}</a>`).join('')}
        <hr />
        <a href="/studio"><span class="material-symbols-outlined">edit_note</span> Studio</a>
        <a href="/wishlist"><span class="material-symbols-outlined">favorite</span> Wishlist</a>
        <a href="/profile"><span class="material-symbols-outlined">person</span> Profile</a>
        <a href="/settings"><span class="material-symbols-outlined">settings</span> Settings</a>
        <hr />
        <span class="lms-mobile-nav__section-label">Admin</span>
        ${ADMIN_NAV_ITEMS.map(n => `<a href="${n.path}">${n.label}</a>`).join('')}
      </div>
    </div>
  </nav>`;
}

function footerHtml() {
  return `<footer class="lms-footer" role="contentinfo"><img src="/mereka-logo.svg" alt="Mereka" style="height:20px;width:auto;display:inline-block;vertical-align:middle;margin-right:8px;opacity:0.6;" /> &copy; ${new Date().getFullYear()} &middot; Academy v2</footer>`;
}

function wireHamburger() {
  const btn = document.querySelector('.js-hamburger');
  const nav = document.getElementById('mobile-nav');
  if (!btn || !nav) return;

  btn.addEventListener('click', () => toggleMobileNav(true));
  nav.querySelectorAll('.js-mobile-nav-close').forEach(el => {
    el.addEventListener('click', () => toggleMobileNav(false));
  });
  // Close on link click
  nav.querySelectorAll('.lms-mobile-nav__links a').forEach(a => {
    a.addEventListener('click', () => toggleMobileNav(false));
  });
  // Close on Escape
  document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape' && _mobileMenuOpen) toggleMobileNav(false);
  });
}

function toggleMobileNav(open) {
  _mobileMenuOpen = open;
  const nav = document.getElementById('mobile-nav');
  const btn = document.querySelector('.js-hamburger');
  if (!nav || !btn) return;
  nav.hidden = !open;
  btn.setAttribute('aria-expanded', String(open));
  if (open) {
    document.body.classList.add('mobile-nav-open');
    nav.querySelector('.js-mobile-nav-close')?.focus();
  } else {
    document.body.classList.remove('mobile-nav-open');
    btn.focus();
  }
}

export function mount(appEl) {
  appEl.innerHTML = `
    ${headerHtml()}
    <main class="app-content" id="main-content" role="main"></main>
    ${footerHtml()}
  `;
  _headerEl = appEl.querySelector('.lms-header');
  wireHamburger();
  return appEl.querySelector('.app-content');
}

export function setActiveNav(pageId) {
  _activeNav = pageId;
  if (!_headerEl) return;
  _headerEl.querySelectorAll('.lms-nav a').forEach(a => {
    const item = NAV_ITEMS.find(n => n.path === a.getAttribute('href'));
    if (item) {
      a.classList.toggle('is-active', item.id === pageId);
      if (item.id === pageId) a.setAttribute('aria-current', 'page');
      else a.removeAttribute('aria-current');
    }
  });
}

export function showShell(show) {
  if (_headerEl) _headerEl.style.display = show ? '' : 'none';
  const footer = document.querySelector('.lms-footer');
  if (footer) footer.style.display = show ? '' : 'none';
  const skipLink = document.querySelector('.skip-link');
  if (skipLink) skipLink.style.display = show ? '' : 'none';
  const mobileNav = document.getElementById('mobile-nav');
  if (mobileNav && !show) mobileNav.hidden = true;
}

export function getContentEl() {
  return document.querySelector('.app-content');
}
