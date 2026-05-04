// Page: Program Detail — shows a single learning pathway with its courses
// Displays program info, outcomes, and the ordered list of courses

import { getProgram, getProgramsForCourse } from '../api/programs.js';
import { listCourses, normalizeCourse } from '../api/courses.js';
import { navigate } from '../router/router.js';

export async function render(rootEl, { params }) {
  const programId = params.programId;
  rootEl.innerHTML = loadingState();

  const [program, catalogRes] = await Promise.all([
    getProgram(programId),
    listCourses({ pageSize: 50 }),
  ]);

  if (!program) {
    rootEl.innerHTML = notFound();
    return;
  }

  // Build catalog map
  const catalogMap = new Map();
  (catalogRes.courses || []).forEach(c => catalogMap.set(c.courseId, c));

  // Resolve courses in program order
  const courses = program.courses.map((id, idx) => {
    const c = catalogMap.get(id);
    return c ? { ...c, order: idx + 1 } : { courseId: id, name: id.split('+')[1] || id, order: idx + 1, image: null, org: '', shortDescription: '' };
  });

  rootEl.innerHTML = renderPage(program, courses);
  wireEvents(rootEl, program, courses);
}

function loadingState() {
  return `<main style="padding:80px 20px;text-align:center;opacity:0.5;">
    <span class="material-symbols-outlined" style="font-size:48px;">hourglass_top</span>
    <p>Loading program…</p>
  </main>`;
}

function notFound() {
  return `<main style="padding:80px 20px;text-align:center;">
    <span class="material-symbols-outlined" style="font-size:64px;color:var(--medium-grey);">error_outline</span>
    <h2>Program not found</h2>
    <p>This learning pathway doesn't exist or has been removed.</p>
    <a href="/programs" class="btn btn--primary" style="margin-top:16px;">Browse all programs</a>
  </main>`;
}

function renderPage(program, courses) {
  return `
  <main class="program-detail">
    <div class="program-detail__hero" style="--prog-color:${program.color};">
      <div class="program-detail__hero-inner">
        <a href="/programs" class="program-detail__back"><span class="material-symbols-outlined">arrow_back</span> All programs</a>
        <div class="program-detail__hero-content">
          <div class="program-detail__icon-wrap">
            <span class="material-symbols-outlined">${program.icon}</span>
          </div>
          <div>
            <h1>${esc(program.title)}</h1>
            <p class="program-detail__subtitle">${esc(program.subtitle)}</p>
            <div class="program-detail__meta">
              <span><span class="material-symbols-outlined" style="font-size:14px;">signal_cellular_alt</span> ${esc(program.level)}</span>
              <span><span class="material-symbols-outlined" style="font-size:14px;">schedule</span> ${esc(program.duration)}</span>
              <span><span class="material-symbols-outlined" style="font-size:14px;">menu_book</span> ${courses.length} courses</span>
            </div>
          </div>
        </div>
      </div>
    </div>

    <div class="program-detail__content">
      <div class="program-detail__main">
        <section class="program-detail__section">
          <h2>About this pathway</h2>
          <p>${esc(program.description)}</p>
        </section>

        <section class="program-detail__section">
          <h2>What you'll achieve</h2>
          <ul class="program-detail__outcomes">
            ${program.outcomes.map(o => `<li><span class="material-symbols-outlined" style="font-size:16px;color:${program.color};">check_circle</span> ${esc(o)}</li>`).join('')}
          </ul>
        </section>

        <section class="program-detail__section">
          <h2>Courses in this pathway</h2>
          <p class="program-detail__courses-note">Complete courses in order for the best learning experience. Each course can also be taken independently.</p>
          <div class="program-detail__course-list">
            ${courses.map(c => courseRow(c, program)).join('')}
          </div>
        </section>
      </div>

      <aside class="program-detail__sidebar">
        <div class="program-detail__sidebar-card">
          <h3>Start this pathway</h3>
          <p>Enroll in the first course to begin your learning journey.</p>
          <button class="btn btn--primary btn--block" data-enroll-first="${esc(courses[0]?.courseId || '')}">
            <span class="material-symbols-outlined" style="font-size:16px;">play_arrow</span> Begin pathway
          </button>
          <div class="program-detail__sidebar-stats">
            <div><strong>${courses.length}</strong><span>Courses</span></div>
            <div><strong>${esc(program.duration)}</strong><span>Duration</span></div>
            <div><strong>${esc(program.level)}</strong><span>Level</span></div>
          </div>
        </div>

        <div class="program-detail__sidebar-card">
          <h3>Skills you'll gain</h3>
          <div class="program-detail__tags">
            ${program.tags.map(t => `<span class="prog-tag">${esc(t)}</span>`).join('')}
          </div>
        </div>
      </aside>
    </div>
  </main>`;
}

function courseRow(c, program) {
  const img = c.image
    ? `<img src="${esc(c.image)}" alt="${esc(c.name)}" />`
    : `<span class="material-symbols-outlined">school</span>`;

  return `
    <div class="program-detail__course-row" data-course-id="${esc(c.courseId)}">
      <div class="program-detail__course-num" style="--prog-color:${program.color};">${c.order}</div>
      <div class="program-detail__course-img">${img}</div>
      <div class="program-detail__course-info">
        <h4>${esc(c.name)}</h4>
        <p>${esc(c.shortDescription || c.org || '')}</p>
      </div>
      <button class="btn btn--outline btn--sm" data-goto-course="${esc(c.courseId)}">View →</button>
    </div>`;
}

function wireEvents(rootEl, program, courses) {
  // Course row clicks
  rootEl.querySelectorAll('[data-goto-course]').forEach(btn => {
    btn.addEventListener('click', (e) => {
      e.preventDefault();
      e.stopPropagation();
      navigate(`/course/${encodeURIComponent(btn.dataset.gotoCourse)}`);
    });
  });

  rootEl.querySelectorAll('.program-detail__course-row').forEach(row => {
    row.style.cursor = 'pointer';
    row.addEventListener('click', () => {
      navigate(`/course/${encodeURIComponent(row.dataset.courseId)}`);
    });
  });

  // Begin pathway button
  const enrollBtn = rootEl.querySelector('[data-enroll-first]');
  if (enrollBtn) {
    enrollBtn.addEventListener('click', () => {
      const courseId = enrollBtn.dataset.enrollFirst;
      if (courseId) navigate(`/course/${encodeURIComponent(courseId)}`);
    });
  }

  // Back link
  const back = rootEl.querySelector('.program-detail__back');
  if (back) {
    back.addEventListener('click', (e) => {
      e.preventDefault();
      navigate('/programs');
    });
  }
}

function esc(s) { return (s||'').replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;'); }
