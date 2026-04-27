// Shared app shell — header (logo, nav, actions) + footer.
// Ported from the static prototype's lms-header / lms-footer.
//
// The router calls shell.mount(appEl) once, then injects page content
// into the .app-content container. shell.setActiveNav(pageId) highlights
// the current nav item.

const LOGO_SVG = `<svg viewBox="0 0 120 28" fill="none" xmlns="http://www.w3.org/2000/svg" style="height:26px;width:auto;display:block;">
  <text x="0" y="22" font-family="Poppins,sans-serif" font-weight="700" font-size="22" fill="currentColor" letter-spacing="-0.5">mereka.</text>
</svg>`;

const NAV_ITEMS = [
  { id: 'dashboard', label: 'Dashboard', path: '/' },
  { id: 'discover', label: 'Discover', path: '/discover' },
  { id: 'mylearning', label: 'My Learning', path: '/my-learning' },
];

let _activeNav = 'dashboard';
let _headerEl = null;
let _isLoggedIn = false;

function headerHtml() {
  return `
  <header class="lms-header">
    <a class="lms-logo" href="/" aria-label="Mereka">${LOGO_SVG}</a>
    <nav class="lms-nav">
      ${NAV_ITEMS.map(n => `<a href="${n.path}" class="${n.id === _activeNav ? 'is-active' : ''}">${n.label}</a>`).join('')}
    </nav>
    <div class="lms-header__spacer"></div>
    <div class="lms-header__actions">
      <a href="/studio" class="btn btn--ghost btn--sm"><span class="material-symbols-outlined" style="font-size:16px;">edit_note</span> Studio</a>
      <a href="/wishlist" class="icon-btn" aria-label="Wishlist"><span class="material-symbols-outlined">favorite</span></a>
      <button class="icon-btn js-notif-toggle" aria-label="Notifications"><span class="material-symbols-outlined">notifications</span><span class="badge">3</span></button>
      <a href="/profile" class="avatar" role="button" aria-label="Profile" style="text-decoration:none;">FF</a>
    </div>
  </header>`;
}

function footerHtml() {
  return `<footer class="lms-footer"><strong>mereka.</strong> © ${new Date().getFullYear()} · Academy v2</footer>`;
}

export function mount(appEl) {
  appEl.innerHTML = `
    ${headerHtml()}
    <div class="app-content"></div>
    ${footerHtml()}
  `;
  _headerEl = appEl.querySelector('.lms-header');
  return appEl.querySelector('.app-content');
}

export function setActiveNav(pageId) {
  _activeNav = pageId;
  if (!_headerEl) return;
  _headerEl.querySelectorAll('.lms-nav a').forEach(a => {
    const item = NAV_ITEMS.find(n => n.path === a.getAttribute('href'));
    if (item) {
      a.classList.toggle('is-active', item.id === pageId);
    }
  });
}

export function showShell(show) {
  if (_headerEl) _headerEl.style.display = show ? '' : 'none';
  const footer = document.querySelector('.lms-footer');
  if (footer) footer.style.display = show ? '' : 'none';
}

export function getContentEl() {
  return document.querySelector('.app-content');
}
