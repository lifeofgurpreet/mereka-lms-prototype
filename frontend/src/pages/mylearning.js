// Page: My Learning — enrolled courses with real images from API
// Falls back to demo data when API unavailable

import { listCourses, normalizeCourse } from '../api/courses.js';
import { listMyEnrollments } from '../api/enrollment.js';
import { navigate } from '../router/router.js';

/* ── demo fallback data ─────────────────────────────────────── */
const DEMO_COURSES = [
  { id:'demo-strategy',  name:'Strategic thinking for modern leaders', cat:'Strategy',   icon:'play_circle',        status:'progress',   pct:60,  modules:12, instructor:'Mei Lin Tan',  meta:'Started Mar 28', next:'Frameworks for ambiguity', est:'3h remaining',  theme:''},
  { id:'demo-data',      name:'Analytics for non-analysts',           cat:'Data',       icon:'bar_chart',          status:'progress',   pct:30,  modules:6,  instructor:'Priya Menon',  meta:'Started Apr 02', next:'Metrics that matter',      est:'5h remaining',  theme:'t-data'},
  { id:'demo-design',    name:'Design thinking fundamentals',         cat:'Design',     icon:'design_services',    status:'progress',   pct:15,  modules:8,  instructor:'Amira Yusof',  meta:'Started Apr 10', next:'Empathy interviews',       est:'8h remaining',  theme:'t-design'},
  { id:'demo-people',    name:'High-performing remote teams',         cat:'People ops', icon:'workspace_premium',  status:'completed',  pct:100, modules:10, instructor:'Daniel Wong',  meta:'Completed Apr 18', score:'92%',                   theme:'t-people'},
  { id:'demo-okr',       name:'OKRs that actually work',              cat:'Strategy',   icon:'workspace_premium',  status:'completed',  pct:100, modules:5,  instructor:'Raj Patel',    meta:'Completed Mar 04', score:'88%',                   theme:''},
  { id:'demo-finance',   name:'Financial literacy for founders',      cat:'Finance',    icon:'trending_up',        status:'bookmarked', pct:0,   modules:7,  instructor:'Nadira Ahmad',  meta:'Bookmarked Apr 15',                               theme:'t-data'},
];

let STATE = { courses: [], filter: 'all' };

export async function render(rootEl) {
  rootEl.innerHTML = skeleton();
  // Try to load real data in background
  loadRealData(rootEl);
}

function skeleton() {
  return `
  <main class="mylearning">
    <div class="mylearning__head">
      <div>
        <h1>My Learning</h1>
        <p>Everything you're enrolled in, in one place.</p>
      </div>
      <button class="btn btn--outline" data-action="discover"><span class="material-symbols-outlined" style="font-size:16px;">add</span> Find a new course</button>
    </div>
    <div class="mylearning__summary" data-role="summary">
      <div class="mylearning__stat"><span>Enrolled</span><strong>—</strong><em>Loading…</em></div>
      <div class="mylearning__stat"><span>In progress</span><strong>—</strong></div>
      <div class="mylearning__stat"><span>Completed</span><strong>—</strong></div>
      <div class="mylearning__stat"><span>Hours this month</span><strong>—</strong></div>
    </div>
    <div class="mylearning__filters" role="tablist" aria-label="Filter" data-role="filters"></div>
    <div class="mylearning__grid" data-role="grid">
      <div style="grid-column:1/-1;text-align:center;padding:48px 0;color:var(--medium-grey);">
        <span class="material-symbols-outlined" style="font-size:48px;">hourglass_top</span>
        <p>Loading your courses…</p>
      </div>
    </div>
  </main>`;
}

async function loadRealData(rootEl) {
  let courses = [];

  try {
    // Try fetching real enrollments + course catalog in parallel
    const [enrollments, catalogRes] = await Promise.allSettled([
      listMyEnrollments(),
      listCourses({ pageSize: 50 }),
    ]);

    const catalog = catalogRes.status === 'fulfilled' ? catalogRes.value : { results: [] };
    const catalogMap = new Map();
    (catalog.results || []).forEach(c => {
      const norm = normalizeCourse(c);
      catalogMap.set(norm.courseId, norm);
    });

    if (enrollments.status === 'fulfilled' && Array.isArray(enrollments.value) && enrollments.value.length > 0) {
      // Real enrollments — merge with catalog for images
      courses = enrollments.value.map(e => {
        const courseId = e.course_details?.course_id || e.course_id || '';
        const catalogCourse = catalogMap.get(courseId);
        const isActive = e.is_active !== false;
        return {
          id: courseId,
          name: catalogCourse?.name || e.course_details?.course_name || courseId,
          cat: catalogCourse?.org || e.course_details?.org || '',
          image: catalogCourse?.image || null,
          icon: 'school',
          status: isActive ? 'progress' : 'completed',
          pct: 0, // Real progress would need progress API
          modules: 0,
          instructor: catalogCourse?.org || '',
          meta: e.created ? `Enrolled ${new Date(e.created).toLocaleDateString('en-MY',{month:'short',day:'numeric'})}` : '',
          theme: '',
          courseId,
        };
      });
    }

    // Also add catalog courses that have images to demo courses if we're using demo
    if (courses.length === 0) {
      // Use demo data but try to add images from catalog
      const catalogArr = Array.from(catalogMap.values());
      courses = DEMO_COURSES.map((d, i) => {
        // Try to match a catalog course to get its image
        const match = catalogArr[i] || null;
        return { ...d, image: match?.image || null, courseId: match?.courseId || d.id };
      });
    }
  } catch (_) {
    courses = DEMO_COURSES.map(d => ({ ...d, image: null, courseId: d.id }));
  }

  STATE.courses = courses;
  renderContent(rootEl);
}

function renderContent(rootEl) {
  const courses = STATE.courses;
  const inProgress = courses.filter(c => c.status === 'progress').length;
  const completed = courses.filter(c => c.status === 'completed').length;
  const bookmarked = courses.filter(c => c.status === 'bookmarked').length;

  // Summary
  const summary = rootEl.querySelector('[data-role="summary"]');
  if (summary) {
    summary.innerHTML = `
      <div class="mylearning__stat"><span>Enrolled</span><strong>${courses.length}</strong><em>${inProgress} in progress</em></div>
      <div class="mylearning__stat"><span>In progress</span><strong>${inProgress}</strong></div>
      <div class="mylearning__stat"><span>Completed</span><strong>${completed}</strong><em>${completed} certificates</em></div>
      <div class="mylearning__stat"><span>Bookmarked</span><strong>${bookmarked}</strong></div>
    `;
  }

  // Filters
  const filters = rootEl.querySelector('[data-role="filters"]');
  if (filters) {
    filters.innerHTML = `
      <button class="mylearning__chip is-active" data-filter="all">All <span class="count">(${courses.length})</span></button>
      <button class="mylearning__chip" data-filter="progress">In progress <span class="count">(${inProgress})</span></button>
      <button class="mylearning__chip" data-filter="completed">Completed <span class="count">(${completed})</span></button>
      ${bookmarked ? `<button class="mylearning__chip" data-filter="bookmarked">Bookmarked <span class="count">(${bookmarked})</span></button>` : ''}
    `;
  }

  // Grid
  const grid = rootEl.querySelector('[data-role="grid"]');
  if (grid) {
    grid.innerHTML = courses.map(c => cardHTML(c)).join('');
  }

  wireEvents(rootEl);
}

function cardHTML(c) {
  const imgContent = c.image
    ? `<img src="${esc(c.image)}" alt="${esc(c.name)}" style="width:100%;height:100%;object-fit:cover;position:absolute;top:0;left:0;" />`
    : `<span class="material-symbols-outlined" style="font-size:40px;">${c.icon || 'school'}</span>`;

  const statusLabel = c.status === 'progress' ? 'In progress'
    : c.status === 'completed' ? 'Completed'
    : c.status === 'bookmarked' ? 'Not started' : '';

  let progressRow = '';
  let footRow = '';

  if (c.status === 'progress') {
    progressRow = `<div class="ml-card__progress-row"><span>${c.pct}% complete</span>${c.next ? `<span>Next: ${esc(c.next)}</span>` : ''}</div>
      <div class="progress"><div class="progress__fill" style="width:${c.pct}%;"></div></div>`;
    footRow = `<span style="font-size:12px; color:var(--medium-grey);">${c.est ? `Est. ${esc(c.est)}` : ''}</span>
      <button class="btn btn--primary btn--sm" data-goto-course="${esc(c.courseId || c.id)}">Continue →</button>`;
  } else if (c.status === 'completed') {
    progressRow = `<div class="ml-card__progress-row"><span>100% complete</span>${c.score ? `<span>Score ${esc(c.score)}</span>` : ''}</div>
      <div class="progress"><div class="progress__fill" style="width:100%;"></div></div>`;
    footRow = `<span style="font-size:12px; color:var(--primary); font-weight:600;">Certificate issued</span>
      <button class="btn btn--outline btn--sm" data-goto-course="${esc(c.courseId || c.id)}">View →</button>`;
  } else {
    progressRow = `<div class="ml-card__progress-row"><span>0% complete</span><span>Starts anytime</span></div>
      <div class="progress"><div class="progress__fill" style="width:0%;"></div></div>`;
    footRow = `<span style="font-size:12px; color:var(--medium-grey);">Self-paced</span>
      <button class="btn btn--primary btn--sm" data-goto-course="${esc(c.courseId || c.id)}">Start →</button>`;
  }

  return `
    <article class="ml-card" data-ml-status="${c.status}">
      <div class="ml-card__thumb ${c.theme || ''}" style="position:relative;overflow:hidden;">
        ${imgContent}
        <span class="ml-card__status">${statusLabel}</span>
      </div>
      <div class="ml-card__body">
        <span class="ml-card__cat">${esc(c.cat)}</span>
        <h3>${esc(c.name)}</h3>
        <p class="ml-card__meta">${esc(c.instructor)}${c.modules ? ` · ${c.modules} modules` : ''} · ${esc(c.meta)}</p>
        <div style="margin-top:auto;">
          ${progressRow}
          <div class="ml-card__foot">
            ${footRow}
          </div>
        </div>
      </div>
    </article>`;
}

function wireEvents(rootEl) {
  // Filter chips
  const chips = rootEl.querySelectorAll('.mylearning__chip');
  const cards = rootEl.querySelectorAll('.ml-card');
  chips.forEach(chip => {
    chip.addEventListener('click', () => {
      chips.forEach(c => c.classList.remove('is-active'));
      chip.classList.add('is-active');
      const filter = chip.dataset.filter;
      cards.forEach(card => {
        card.style.display = (filter === 'all' || card.dataset.mlStatus === filter) ? '' : 'none';
      });
    });
  });

  // Course navigation buttons
  rootEl.querySelectorAll('[data-goto-course]').forEach(btn => {
    btn.addEventListener('click', (e) => {
      e.preventDefault();
      const courseId = btn.dataset.gotoCourse;
      navigate(`/learn/${encodeURIComponent(courseId)}`);
    });
  });

  // Discover button
  const discBtn = rootEl.querySelector('[data-action="discover"]');
  if (discBtn) discBtn.addEventListener('click', () => navigate('/discover'));
}

function esc(s) { return (s||'').replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;'); }
