// Page: Continue Learning — active courses with progress
import { navigate } from '../router/router.js';
import { listMyEnrollments } from '../api/enrollment.js';
import { getCourseProgress } from '../api/progress.js';

export async function render(rootEl) {
  /* ── Try real API, fall back to mock ── */
  let courses = [];
  try {
    const enrollments = await listMyEnrollments();
    if (Array.isArray(enrollments) && enrollments.length) {
      courses = enrollments.filter(e => e.is_active).map(e => ({
        id: e.course_id || e.course_details?.course_id,
        name: e.course_details?.course_name || e.course_id,
        mode: e.mode,
        created: e.created,
      }));
    }
  } catch (_) {}

  if (!courses.length) courses = mockCourses();

  rootEl.innerHTML = `
  <main class="mylearning">
    <div style="font-size:12px;color:var(--medium-grey);margin-bottom:14px;">
      <a href="/" id="bcHome" style="color:var(--medium-grey);text-decoration:none;">Dashboard</a>
      <span style="margin:0 8px;">/</span>
      <span style="color:var(--off-black);font-weight:500;">Continue learning</span>
    </div>

    <div class="mylearning__head">
      <div>
        <h1>Continue where you left off</h1>
        <p>Jump back into everything you're actively learning.</p>
      </div>
      <button class="btn btn--outline" id="viewAllBtn"><span class="material-symbols-outlined" style="font-size:16px;">list</span> View all courses</button>
    </div>

    <div class="mylearning__summary">
      <div class="mylearning__stat"><span>Active courses</span><strong>${courses.length}</strong><em>Avg. ${avgProgress(courses)}% complete</em></div>
      <div class="mylearning__stat"><span>Hours this week</span><strong>4.5</strong><em>↑ 18% vs last week</em></div>
      <div class="mylearning__stat"><span>Current streak</span><strong>7</strong><em>days learning</em></div>
      <div class="mylearning__stat"><span>Next milestone</span><strong>2</strong><em>units to next certificate</em></div>
    </div>

    <div class="mylearning__filters" role="tablist" aria-label="Filter">
      <button class="mylearning__chip is-active">All <span class="count">(${courses.length})</span></button>
      ${buildFilterChips(courses)}
    </div>

    <div class="mylearning__grid" id="courseGrid">
      ${courses.map(c => courseCard(c)).join('')}
    </div>

    <div class="card" style="margin-top:28px;padding:22px;display:flex;align-items:center;gap:16px;background:linear-gradient(135deg,rgba(171,59,120,0.06),rgba(41,92,173,0.06));border:1px solid var(--border);">
      <div style="width:52px;height:52px;border-radius:12px;background:var(--brand-gradient);color:var(--white);display:flex;align-items:center;justify-content:center;flex-shrink:0;">
        <span class="material-symbols-outlined">auto_awesome</span>
      </div>
      <div style="flex:1;">
        <h3 style="margin:0 0 4px;font-size:16px;">Ready for something new?</h3>
        <p style="margin:0;color:var(--medium-grey);font-size:13px;">Browse 150+ hands-on modules across strategy, data, design, and more.</p>
      </div>
      <button class="btn btn--primary" id="discoverBtn">Discover courses →</button>
    </div>
  </main>`;

  wireEvents();
}

/* ── Mock data ── */
function mockCourses() {
  return [
    { id: 'course-v1:Mereka+STRAT301+2026', name: 'Strategic thinking for modern leaders', cat: 'Strategy', instructor: 'Mei Lin Tan', module: '3 of 5', lastOpened: '2h ago', pct: 60, next: 'Frameworks for ambiguity', est: '3h', thumbClass: '', icon: 'play_circle', status: 'Active today' },
    { id: 'course-v1:Mereka+DATA201+2026', name: 'Analytics for non-analysts', cat: 'Data', instructor: 'Priya Menon', module: '2 of 6', lastOpened: 'Apr 21', pct: 30, next: 'Metrics that matter', est: '5h', thumbClass: 't-data', icon: 'bar_chart', status: 'Active yesterday' },
    { id: 'course-v1:Mereka+DESIGN101+2026', name: 'Design thinking fundamentals', cat: 'Design', instructor: 'Amira Yusof', module: '1 of 8', lastOpened: 'Apr 19', pct: 15, next: 'Empathy interviews', est: '8h', thumbClass: 't-design', icon: 'design_services', status: 'Started Apr 10' },
  ];
}

function avgProgress(courses) {
  const pcts = courses.map(c => c.pct || 0);
  return pcts.length ? Math.round(pcts.reduce((a, b) => a + b, 0) / pcts.length) : 0;
}

function buildFilterChips(courses) {
  const cats = {};
  courses.forEach(c => { const cat = c.cat || 'Other'; cats[cat] = (cats[cat] || 0) + 1; });
  return Object.entries(cats).map(([cat, n]) =>
    `<button class="mylearning__chip">${cat} <span class="count">(${n})</span></button>`
  ).join('') + `<button class="mylearning__chip">Recent activity</button>`;
}

function courseCard(c) {
  return `
  <article class="ml-card" data-course-id="${c.id}">
    <div class="ml-card__thumb ${c.thumbClass || ''}">
      <span class="material-symbols-outlined" style="font-size:40px;">${c.icon || 'play_circle'}</span>
      <span class="ml-card__status">${c.status || ''}</span>
    </div>
    <div class="ml-card__body">
      <span class="ml-card__cat">${c.cat || ''}</span>
      <h3>${c.name}</h3>
      <p class="ml-card__meta">${c.instructor || ''} · Module ${c.module || '?'} · Last opened ${c.lastOpened || '—'}</p>
      <div style="margin-top:auto;">
        <div class="ml-card__progress-row"><span>${c.pct || 0}% complete</span><span>Next: ${c.next || '—'}</span></div>
        <div class="progress"><div class="progress__fill" style="width:${c.pct || 0}%;"></div></div>
        <div class="ml-card__foot">
          <span style="font-size:12px;color:var(--medium-grey);">Est. ${c.est || '?'} remaining</span>
          <button class="btn btn--primary btn--sm js-continue" data-id="${c.id}">Continue →</button>
        </div>
      </div>
    </div>
  </article>`;
}

function wireEvents() {
  document.getElementById('bcHome')?.addEventListener('click', e => { e.preventDefault(); navigate('/'); });
  document.getElementById('viewAllBtn')?.addEventListener('click', () => navigate('/my-learning'));
  document.getElementById('discoverBtn')?.addEventListener('click', () => navigate('/discover'));

  document.querySelectorAll('.js-continue').forEach(btn => {
    btn.addEventListener('click', () => {
      const id = btn.dataset.id;
      navigate('/course/' + encodeURIComponent(id));
    });
  });

  // Filter chips toggle
  document.querySelectorAll('.mylearning__chip').forEach(chip => {
    chip.addEventListener('click', () => {
      document.querySelectorAll('.mylearning__chip').forEach(c => c.classList.remove('is-active'));
      chip.classList.add('is-active');
    });
  });
}
