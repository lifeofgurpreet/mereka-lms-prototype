// ---------------------------------------------------------------------------
// Discover page — first real end-to-end feature wired to academyv2.mereka.dev.
//
// Public course catalog, no auth required. Supports:
//   - Server-side search (?search_term=…)
//   - Pagination (Load more)
//   - Org filter pills derived from the response
//
// Brand tokens (--mereka-primary, --mereka-gradient, etc.) come from
// globals.scss. The markup is intentionally prototype-flavoured so the
// existing prototype CSS keeps working once Faiz points the class names
// at the real cards.
// ---------------------------------------------------------------------------

import { listCourses } from '../api/courses.js';

const PAGE_SIZE = 12;

const state = {
  page: 1,
  search: '',
  org: null,
  loading: false,
  courses: [],
  pagination: null,
  orgs: new Set(),
};

export async function render(rootEl, { query } = {}) {
  // Preserve deep-link query params on first render.
  state.search = (query && query.q) || '';
  state.org = (query && query.org) || null;
  state.page = 1;
  state.courses = [];
  state.orgs = new Set();

  rootEl.innerHTML = shell();
  wireControls(rootEl);
  await loadPage(rootEl, { replace: true });
}

function shell() {
  return `
    <section class="mereka-discover">
      <header class="mereka-discover__hero">
        <p class="mereka-eyebrow">Mereka Academy</p>
        <h1 class="mereka-discover__title">Discover your next learning journey</h1>
        <p class="mereka-discover__subtitle">
          Mentor-calibrated tracks for product, design, craft, and entrepreneurship.
        </p>
        <form class="mereka-discover__search" data-role="search-form">
          <input
            type="search"
            name="q"
            placeholder="Search courses, skills, mentors…"
            aria-label="Search courses"
            data-role="search-input"
          />
          <button type="submit" class="mereka-btn mereka-btn--primary">Search</button>
        </form>
      </header>

      <nav class="mereka-discover__filters" data-role="org-filters" aria-label="Filter by organization"></nav>

      <div class="mereka-discover__status" data-role="status" role="status" aria-live="polite"></div>

      <ul class="mereka-discover__grid" data-role="grid"></ul>

      <div class="mereka-discover__pagination">
        <button type="button" class="mereka-btn mereka-btn--ghost" data-role="load-more" hidden>
          Load more courses
        </button>
      </div>
    </section>
  `;
}

function wireControls(rootEl) {
  const form = rootEl.querySelector('[data-role="search-form"]');
  const input = rootEl.querySelector('[data-role="search-input"]');
  const loadMore = rootEl.querySelector('[data-role="load-more"]');

  input.value = state.search;

  form.addEventListener('submit', (e) => {
    e.preventDefault();
    state.search = input.value.trim();
    state.page = 1;
    state.courses = [];
    loadPage(rootEl, { replace: true });
  });

  loadMore.addEventListener('click', () => {
    state.page += 1;
    loadPage(rootEl, { replace: false });
  });
}

async function loadPage(rootEl, { replace }) {
  if (state.loading) return;
  state.loading = true;

  const statusEl = rootEl.querySelector('[data-role="status"]');
  const gridEl = rootEl.querySelector('[data-role="grid"]');
  const loadMore = rootEl.querySelector('[data-role="load-more"]');

  statusEl.textContent = state.page === 1 ? 'Loading courses…' : 'Loading more…';

  try {
    const { courses, pagination } = await listCourses({
      page: state.page,
      pageSize: PAGE_SIZE,
      search: state.search || undefined,
      org: state.org || undefined,
    });

    if (replace) gridEl.innerHTML = '';
    state.pagination = pagination;

    courses.forEach((course) => {
      if (course.org) state.orgs.add(course.org);
      gridEl.appendChild(cardEl(course));
    });
    state.courses.push(...courses);

    renderOrgFilters(rootEl);

    const total = pagination?.count ?? state.courses.length;
    const shown = state.courses.length;
    statusEl.textContent =
      total === 0
        ? 'No courses matched your search yet.'
        : `Showing ${shown} of ${total} course${total === 1 ? '' : 's'}`;

    const hasMore =
      pagination && pagination.num_pages && state.page < pagination.num_pages;
    loadMore.hidden = !hasMore;
  } catch (err) {
    console.error('[discover] load failed', err);
    statusEl.innerHTML = `
      <div class="mereka-error">
        <strong>Couldn't reach academyv2.mereka.dev.</strong>
        <span>${escapeHtml(err.message || 'Unknown error')}</span>
      </div>
    `;
  } finally {
    state.loading = false;
  }
}

function renderOrgFilters(rootEl) {
  const container = rootEl.querySelector('[data-role="org-filters"]');
  const orgs = [...state.orgs].sort();
  if (!orgs.length) {
    container.innerHTML = '';
    return;
  }

  container.innerHTML = `
    <button type="button" class="mereka-chip ${!state.org ? 'is-active' : ''}" data-org="">
      All organizations
    </button>
    ${orgs
      .map(
        (org) => `
          <button type="button" class="mereka-chip ${state.org === org ? 'is-active' : ''}" data-org="${escapeHtml(org)}">
            ${escapeHtml(org)}
          </button>
        `,
      )
      .join('')}
  `;

  container.querySelectorAll('.mereka-chip').forEach((btn) => {
    btn.addEventListener('click', () => {
      state.org = btn.dataset.org || null;
      state.page = 1;
      state.courses = [];
      loadPage(rootEl, { replace: true });
    });
  });
}

function cardEl(course) {
  const li = document.createElement('li');
  li.className = 'mereka-course-card';

  const href = `/courses/${encodeURIComponent(course.id)}`;
  const imageStyle = course.image
    ? `background-image: url('${escapeAttr(course.image)}')`
    : 'background: var(--mereka-gradient, linear-gradient(120deg,#AB3B78,#1E5A8E));';

  li.innerHTML = `
    <a class="mereka-course-card__link" href="${href}">
      <div class="mereka-course-card__media" style="${imageStyle}" aria-hidden="true"></div>
      <div class="mereka-course-card__body">
        <p class="mereka-course-card__org">${escapeHtml(course.org || 'Mereka')} · ${escapeHtml(course.number || '')}</p>
        <h3 class="mereka-course-card__title">${escapeHtml(course.name)}</h3>
        <p class="mereka-course-card__desc">${escapeHtml(course.shortDescription || '')}</p>
        <div class="mereka-course-card__meta">
          <span class="mereka-tag">${escapeHtml(course.pacing === 'instructor' ? 'Instructor-paced' : 'Self-paced')}</span>
          ${course.startDisplay ? `<span class="mereka-tag">Starts ${escapeHtml(course.startDisplay)}</span>` : ''}
          ${course.mobileAvailable ? `<span class="mereka-tag">Mobile</span>` : ''}
        </div>
      </div>
    </a>
  `;
  return li;
}

function escapeHtml(s) {
  return String(s ?? '').replace(/[&<>"']/g, (c) => ({
    '&': '&amp;',
    '<': '&lt;',
    '>': '&gt;',
    '"': '&quot;',
    "'": '&#39;',
  }[c]));
}

function escapeAttr(s) {
  return escapeHtml(s).replace(/\n/g, ' ');
}
