// Page: Programs — learning pathways listing
// Shows all available programs/learning pathways with course counts and progress

import { listPrograms } from '../api/programs.js';
import { listCourses, normalizeCourse } from '../api/courses.js';
import { navigate } from '../router/router.js';

let STATE = { programs: [], catalogMap: new Map(), filter: 'all' };

export async function render(rootEl) {
  rootEl.innerHTML = skeleton();
  await loadData(rootEl);
}

function skeleton() {
  return `
  <main class="programs-page">
    <div class="programs-page__hero">
      <div class="programs-page__hero-inner">
        <span class="eyebrow"><span class="material-symbols-outlined" style="font-size:14px;">route</span> Learning Pathways</span>
        <h1>Structured programs to build real skills</h1>
        <p>Each program is a curated sequence of courses designed to take you from fundamentals to job-ready competence. Pick a pathway that matches your goals.</p>
      </div>
    </div>

    <div class="programs-page__filters" data-role="filters">
      <button class="chip is-active" data-filter="all">All programs</button>
      <button class="chip" data-filter="Beginner">Beginner</button>
      <button class="chip" data-filter="Intermediate">Intermediate</button>
    </div>

    <div class="programs-page__grid" data-role="grid">
      <div style="grid-column:1/-1;text-align:center;padding:48px 0;color:var(--medium-grey);">
        <span class="material-symbols-outlined" style="font-size:48px;">hourglass_top</span>
        <p>Loading programs…</p>
      </div>
    </div>
  </main>`;
}

async function loadData(rootEl) {
  try {
    const [programs, catalogRes] = await Promise.all([
      listPrograms(),
      listCourses({ pageSize: 50 }),
    ]);

    // Build catalog map for course details
    const catalogMap = new Map();
    (catalogRes.courses || []).forEach(c => {
      catalogMap.set(c.courseId, c);
    });

    STATE.programs = programs;
    STATE.catalogMap = catalogMap;
    renderGrid(rootEl);
  } catch (err) {
    console.error('[programs] load failed:', err);
    const grid = rootEl.querySelector('[data-role="grid"]');
    if (grid) grid.innerHTML = `<div style="grid-column:1/-1;text-align:center;padding:48px;"><p>Failed to load programs. Please try again.</p></div>`;
  }
}

function renderGrid(rootEl) {
  const grid = rootEl.querySelector('[data-role="grid"]');
  if (!grid) return;

  grid.innerHTML = STATE.programs.map(prog => programCard(prog)).join('');
  wireEvents(rootEl);
}

function programCard(prog) {
  const courseCount = prog.courses.length;
  const resolvedCourses = prog.courses
    .map(id => STATE.catalogMap.get(id))
    .filter(Boolean);

  // Get first 3 course images for preview
  const previewImages = resolvedCourses
    .filter(c => c.image)
    .slice(0, 3);

  const imageStack = previewImages.length > 0
    ? `<div class="prog-card__img-stack">
        ${previewImages.map((c, i) => `<img src="${esc(c.image)}" alt="" class="prog-card__img-item" style="--i:${i};" />`).join('')}
       </div>`
    : `<div class="prog-card__icon-wrap" style="--prog-color:${prog.color};">
        <span class="material-symbols-outlined">${prog.icon}</span>
       </div>`;

  const levelTag = prog.level.includes('Intermediate') ? 'intermediate' : 'beginner';

  return `
    <article class="prog-card" data-program-id="${esc(prog.id)}" data-level="${levelTag}">
      <div class="prog-card__visual" style="--prog-color:${prog.color};">
        ${imageStack}
      </div>
      <div class="prog-card__body">
        <div class="prog-card__meta">
          <span class="prog-card__level"><span class="material-symbols-outlined" style="font-size:12px;">signal_cellular_alt</span> ${esc(prog.level)}</span>
          <span class="prog-card__duration"><span class="material-symbols-outlined" style="font-size:12px;">schedule</span> ${esc(prog.duration)}</span>
        </div>
        <h3 class="prog-card__title">${esc(prog.title)}</h3>
        <p class="prog-card__subtitle">${esc(prog.subtitle)}</p>
        <div class="prog-card__courses-count">
          <span class="material-symbols-outlined" style="font-size:14px;">menu_book</span>
          ${courseCount} course${courseCount !== 1 ? 's' : ''} in this pathway
        </div>
        <div class="prog-card__tags">
          ${prog.tags.slice(0, 3).map(t => `<span class="prog-card__tag">${esc(t)}</span>`).join('')}
        </div>
        <button class="btn btn--primary btn--sm prog-card__cta" data-goto-program="${esc(prog.id)}">View pathway →</button>
      </div>
    </article>`;
}

function wireEvents(rootEl) {
  // Filter chips
  const chips = rootEl.querySelectorAll('.programs-page__filters .chip');
  chips.forEach(chip => {
    chip.addEventListener('click', () => {
      chips.forEach(c => c.classList.remove('is-active'));
      chip.classList.add('is-active');
      const filter = chip.dataset.filter;
      rootEl.querySelectorAll('.prog-card').forEach(card => {
        if (filter === 'all') {
          card.style.display = '';
        } else {
          const level = card.dataset.level;
          card.style.display = level === filter.toLowerCase() ? '' : 'none';
        }
      });
    });
  });

  // Program navigation
  rootEl.querySelectorAll('[data-goto-program]').forEach(btn => {
    btn.addEventListener('click', (e) => {
      e.preventDefault();
      e.stopPropagation();
      navigate(`/programs/${btn.dataset.gotoProgram}`);
    });
  });

  // Card click
  rootEl.querySelectorAll('.prog-card').forEach(card => {
    card.addEventListener('click', () => {
      navigate(`/programs/${card.dataset.programId}`);
    });
  });
}

function esc(s) { return (s||'').replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;'); }
