// Discover page — prototype UI + live academyv2.mereka.dev API.
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
  <main class="disc">
    <div class="disc__hero">
      <div class="disc__hero-inner">
        <span class="eyebrow"><span class="material-symbols-outlined" style="font-size:14px;">auto_awesome</span> Mereka Academy</span>
        <h1>Train teams that can ship what Southeast Asia needs next.</h1>
        <p>Strategy-grade learning journeys, hands-on pathways, and industry mentors — built for operators, creators, and curious builders across the region.</p>
        <div class="disc__hero-cta">
          <button class="btn btn--primary" onclick="goto('register')">Join the community</button>
          <button class="btn btn--outline" data-role="scroll-courses">Browse courses</button>
        </div>
        <form class="disc__search" data-role="search-form">
          <span class="disc__search-icon"><span class="material-symbols-outlined">search</span></span>
          <input data-role="search-input" placeholder="Search for a course" value="${escapeAttr(state.search)}" />
          <button type="submit" class="btn btn--primary">Search</button>
        </form>
        <div class="disc__stats">
          <div class="disc__stat"><strong data-role="stat-count">—</strong><span>Academy courses</span></div>
          <div class="disc__stat"><strong>45</strong><span>Industry mentors</span></div>
          <div class="disc__stat"><strong>18k</strong><span>Learners empowered</span></div>
          <div class="disc__stat"><strong>4</strong><span>Languages · EN · ID · VI · ZH</span></div>
        </div>
      </div>
    </div>

    <div class="disc__chips" data-role="org-chips">
      <span class="chip is-active" data-org="">All tracks</span>
    </div>

    <div class="disc__toolbar">
      <span class="disc__count" data-role="count-label">Loading courses…</span>
    </div>

    <div class="disc__grid" data-role="courses-grid" style="scroll-margin-top: 96px;"></div>

    <div style="text-align:center; padding:24px 0 48px;" data-role="load-more-wrap"></div>
  </main>`;
}

function courseCard(c) {
  const img = c.image
    ? `<img src="${escapeAttr(c.image)}" alt="${escapeAttr(c.name)}" style="width:100%;height:100%;object-fit:cover;" />`
    : `<span class="material-symbols-outlined" style="font-size:48px;">school</span>`;

  const topicClass = (c.org || '').toLowerCase().replace(/[^a-z]/g, '') || 'general';

  return `
    <article class="card course-card" data-course-id="${escapeAttr(c.courseId)}" style="cursor:pointer;">
      <div class="course-card__img course-art" data-topic="${topicClass}">
        <span class="course-card__type"><span class="material-symbols-outlined" style="font-size:12px;">workspace_premium</span> ${c.pacing === 'self' ? 'Self-paced' : 'Instructor-led'}</span>
        <button class="wishlist-btn" aria-label="Save to wishlist" onclick="event.stopPropagation();"><span class="material-symbols-outlined">favorite</span></button>
        ${img}
      </div>
      <div class="course-card__body">
        <span class="course-card__track">${escapeHtml(c.org)} ${escapeHtml(c.number)}</span>
        <h3>${escapeHtml(c.name)}</h3>
        <p class="course-card__meta">${escapeHtml(c.shortDescription || 'Explore the course syllabus, content, and schedule.')}</p>
        <div class="course-card__foot">
          <span class="course-card__price">${c.startDisplay || 'Open enrollment'}</span>
          <button class="btn btn--primary btn--sm">View course</button>
        </div>
      </div>
    </article>`;
}

async function loadPage(rootEl, { replace } = {}) {
  if (state.loading) return;
  state.loading = true;

  const grid = rootEl.querySelector('[data-role="courses-grid"]');
  const countEl = rootEl.querySelector('[data-role="count-label"]');
  const loadMoreWrap = rootEl.querySelector('[data-role="load-more-wrap"]');
  const statCount = rootEl.querySelector('[data-role="stat-count"]');

  try {
    const result = await listCourses({
      page: state.page,
      pageSize: PAGE_SIZE,
      search: state.search || undefined,
      org: state.org || undefined,
    });

    if (replace) {
      state.courses = result.courses;
    } else {
      state.courses = state.courses.concat(result.courses);
    }
    state.pagination = result.pagination;

    // Update org chips
    result.courses.forEach(c => { if (c.org) state.orgs.add(c.org); });
    renderOrgChips(rootEl);

    // Render cards
    grid.innerHTML = state.courses.map(courseCard).join('');

    // Wire course card clicks → navigate to /course/:id
    grid.querySelectorAll('.course-card[data-course-id]').forEach(card => {
      card.addEventListener('click', (e) => {
        if (e.target.closest('.wishlist-btn')) return;
        const id = card.dataset.courseId;
        if (id) {
          window.history.pushState(null, '', '/course/' + encodeURIComponent(id));
          window.dispatchEvent(new PopStateEvent('popstate'));
        }
      });
    });

    // Update count
    const total = state.pagination.count || state.courses.length;
    if (statCount) statCount.textContent = String(total);
    if (countEl) {
      countEl.textContent = state.search
        ? `Showing ${state.courses.length} of ${total} results for "${state.search}"`
        : `Showing ${state.courses.length} of ${total} curated pathways`;
    }

    // Load more button
    if (state.pagination.next && state.courses.length < total) {
      loadMoreWrap.innerHTML = `<button class="btn btn--outline" data-role="load-more">Show more courses</button>`;
      loadMoreWrap.querySelector('[data-role="load-more"]').addEventListener('click', () => {
        state.page++;
        loadPage(rootEl);
      });
    } else {
      loadMoreWrap.innerHTML = '';
    }

  } catch (err) {
    console.warn('[discover] course fetch failed:', err);
    grid.innerHTML = `
      <div style="grid-column:1/-1; text-align:center; padding:48px 24px;">
        <span class="material-symbols-outlined" style="font-size:48px; color:var(--medium-grey);">cloud_off</span>
        <h3 style="margin:16px 0 8px;">Couldn't load courses</h3>
        <p style="color:var(--medium-grey);">The Mereka Academy API isn't reachable right now.</p>
        <button class="btn btn--outline btn--sm" onclick="location.reload()">Try again</button>
      </div>`;
    if (countEl) countEl.textContent = 'Unable to load courses from Mereka Academy';
  }

  state.loading = false;
}

function renderOrgChips(rootEl) {
  const container = rootEl.querySelector('[data-role="org-chips"]');
  if (!container) return;
  const chips = [`<span class="chip ${!state.org ? 'is-active' : ''}" data-org="">All tracks</span>`];
  for (const org of state.orgs) {
    chips.push(`<span class="chip ${state.org === org ? 'is-active' : ''}" data-org="${escapeAttr(org)}">${escapeHtml(org)}</span>`);
  }
  container.innerHTML = chips.join('');

  container.querySelectorAll('.chip').forEach(chip => {
    chip.addEventListener('click', () => {
      state.org = chip.dataset.org || null;
      state.page = 1;
      loadPage(rootEl, { replace: true });
    });
  });
}

function wireControls(rootEl) {
  const form = rootEl.querySelector('[data-role="search-form"]');
  const input = rootEl.querySelector('[data-role="search-input"]');
  if (form) {
    form.addEventListener('submit', (e) => {
      e.preventDefault();
      state.search = input.value.trim();
      state.page = 1;
      loadPage(rootEl, { replace: true });
    });
  }
  const scrollBtn = rootEl.querySelector('[data-role="scroll-courses"]');
  if (scrollBtn) {
    scrollBtn.addEventListener('click', () => {
      const grid = rootEl.querySelector('[data-role="courses-grid"]');
      if (grid) grid.scrollIntoView({ behavior: 'smooth', block: 'start' });
    });
  }
}

function escapeHtml(str) { return (str || '').replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;'); }
function escapeAttr(str) { return (str || '').replace(/&/g,'&amp;').replace(/"/g,'&quot;'); }
