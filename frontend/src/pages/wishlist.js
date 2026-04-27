// Page: Wishlist — saved courses
import { navigate } from '../router/router.js';

export async function render(rootEl) {
  /* Wishlist is stored in sessionStorage for now */
  const stored = sessionStorage.getItem('mereka.wishlist');
  let items = [];
  try { items = JSON.parse(stored) || []; } catch (_) {}

  const hasItems = items.length > 0;

  rootEl.innerHTML = `
  <main class="wishlist-page">
    <div class="wishlist-page__head">
      <div>
        <h1>Your wishlist</h1>
        <p class="wishlist-page__sub">Courses you saved for later — enroll when you're ready.</p>
      </div>
      <div style="display:flex;gap:8px;">
        <button class="btn btn--outline btn--sm" id="browseBtn"><span class="material-symbols-outlined" style="font-size:16px;">explore</span> Keep browsing</button>
      </div>
    </div>

    <div id="wishlistGrid" class="wishlist-page__grid mylearning__grid" style="${hasItems ? '' : 'display:none;'}">
      ${items.map(item => wishlistCard(item)).join('')}
    </div>

    <div id="wishlistEmpty" class="wishlist-empty" style="${hasItems ? 'display:none;' : ''}">
      <div class="wishlist-empty__icon"><span class="material-symbols-outlined" style="font-size:48px;color:var(--medium-grey);">favorite_border</span></div>
      <h3>No saved courses yet</h3>
      <p style="color:var(--medium-grey);margin:8px 0 20px;">Tap the heart on any course to save it here for later.</p>
      <button class="btn btn--primary" id="discoverBtn"><span class="material-symbols-outlined" style="font-size:18px;">explore</span> Browse courses</button>
    </div>
  </main>`;

  wireEvents();
}

function wishlistCard(item) {
  return `
  <article class="ml-card" data-course-id="${item.id || ''}">
    <div class="ml-card__thumb ${item.thumbClass || ''}">
      <span class="material-symbols-outlined" style="font-size:40px;">${item.icon || 'school'}</span>
      <button class="wishlist-btn is-saved js-remove-wish" data-id="${item.id || ''}" aria-label="Remove from wishlist" style="position:absolute;top:12px;right:12px;">
        <span class="material-symbols-outlined">favorite</span>
      </button>
    </div>
    <div class="ml-card__body">
      <span class="ml-card__cat">${item.cat || ''}</span>
      <h3>${item.name || 'Untitled course'}</h3>
      <p class="ml-card__meta">${item.instructor || ''} · ${item.modules || '?'} modules · ${item.duration || '?'}</p>
      <div class="ml-card__foot">
        <span style="font-weight:600;color:var(--primary);">${item.price || 'Free'}</span>
        <button class="btn btn--primary btn--sm js-enroll" data-id="${item.id || ''}">Enroll →</button>
      </div>
    </div>
  </article>`;
}

function wireEvents() {
  document.getElementById('browseBtn')?.addEventListener('click', () => navigate('/discover'));
  document.getElementById('discoverBtn')?.addEventListener('click', () => navigate('/discover'));

  document.querySelectorAll('.js-enroll').forEach(btn => {
    btn.addEventListener('click', () => {
      const id = btn.dataset.id;
      if (id) navigate('/checkout/' + encodeURIComponent(id));
    });
  });

  document.querySelectorAll('.js-remove-wish').forEach(btn => {
    btn.addEventListener('click', (e) => {
      e.stopPropagation();
      const id = btn.dataset.id;
      let items = [];
      try { items = JSON.parse(sessionStorage.getItem('mereka.wishlist')) || []; } catch (_) {}
      items = items.filter(i => i.id !== id);
      sessionStorage.setItem('mereka.wishlist', JSON.stringify(items));
      // Re-render
      const card = btn.closest('.ml-card');
      if (card) card.remove();
      // Check if empty
      const grid = document.getElementById('wishlistGrid');
      const empty = document.getElementById('wishlistEmpty');
      if (grid && !grid.children.length) {
        grid.style.display = 'none';
        if (empty) empty.style.display = '';
      }
      // Update badge
      const badge = document.querySelector('.js-wishlist-count');
      if (badge) badge.textContent = items.length || '';
    });
  });
}
