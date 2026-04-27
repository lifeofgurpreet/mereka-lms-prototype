// Page: Deadlines — upcoming quizzes, assignments, readings, peer reviews
import { navigate } from '../router/router.js';
import { listMyEnrollments } from '../api/enrollment.js';
import { getCourseDates } from '../api/progress.js';

export async function render(rootEl) {
  /* Try real API dates, fall back to mock */
  let items = [];
  try {
    const enrollments = await listMyEnrollments();
    if (Array.isArray(enrollments)) {
      for (const e of enrollments.filter(en => en.is_active).slice(0, 5)) {
        const cid = e.course_id || e.course_details?.course_id;
        try {
          const dates = await getCourseDates(cid);
          if (dates?.course_date_blocks?.length) {
            dates.course_date_blocks.forEach(b => {
              if (b.assignment_type || b.link) {
                items.push({
                  date: new Date(b.date),
                  title: b.title || b.assignment_type || 'Untitled',
                  type: b.assignment_type || 'Task',
                  course: e.course_details?.course_name || cid,
                  courseId: cid,
                  link: b.link,
                  overdue: new Date(b.date) < new Date(),
                });
              }
            });
          }
        } catch (_) {}
      }
    }
  } catch (_) {}

  if (!items.length) items = mockDeadlines();
  items.sort((a, b) => a.date - b.date);

  const overdue = items.filter(i => i.overdue).length;
  const thisWeek = items.filter(i => {
    const d = i.date, now = new Date(), end = new Date();
    end.setDate(now.getDate() + 7);
    return d >= now && d <= end;
  }).length;

  rootEl.innerHTML = `
  <main class="mylearning">
    <div style="font-size:12px;color:var(--medium-grey);margin-bottom:14px;">
      <a href="/" id="bcHome" style="color:var(--medium-grey);text-decoration:none;">Dashboard</a>
      <span style="margin:0 8px;">/</span>
      <span style="color:var(--off-black);font-weight:500;">Deadlines</span>
    </div>

    <div class="mylearning__head">
      <div>
        <h1>Upcoming deadlines</h1>
        <p>Quizzes, assignments, readings, and peer reviews — all in one place.</p>
      </div>
      <button class="btn btn--outline" id="syncCalBtn"><span class="material-symbols-outlined" style="font-size:16px;">calendar_month</span> Sync to calendar</button>
    </div>

    <div class="mylearning__summary">
      <div class="mylearning__stat"><span>Due this week</span><strong>${thisWeek}</strong><em>${overdue ? overdue + ' high priority' : 'All on track'}</em></div>
      <div class="mylearning__stat"><span>Overdue</span><strong>${overdue}</strong><em style="${overdue ? 'color:#B04636;' : ''}">${overdue ? 'Needs attention' : 'None — nice!'}</em></div>
      <div class="mylearning__stat"><span>Due today</span><strong>0</strong><em>Plan ahead</em></div>
      <div class="mylearning__stat"><span>On-time rate</span><strong>92%</strong><em>Last 3 months</em></div>
    </div>

    <div class="mylearning__filters" role="tablist" aria-label="Filter">
      <button class="mylearning__chip is-active">All <span class="count">(${items.length})</span></button>
      ${overdue ? `<button class="mylearning__chip">Overdue <span class="count">(${overdue})</span></button>` : ''}
      ${buildTypeChips(items)}
    </div>

    <div class="card" style="padding:0;" id="deadlineList">
      ${items.map((item, i) => deadlineRow(item, i === items.length - 1)).join('')}
    </div>

    <p style="margin-top:20px;font-size:12px;color:var(--medium-grey);text-align:center;">Need to change a deadline? Reach out to your instructor from the course page.</p>
  </main>`;

  wireEvents();
}

/* ── Mock deadlines ── */
function mockDeadlines() {
  const now = new Date();
  const d = (offset) => { const dt = new Date(); dt.setDate(now.getDate() + offset); return dt; };
  return [
    { date: d(-2), title: 'Peer review — Market-entry case study', type: 'Peer review', course: 'Strategic thinking for modern leaders', courseId: 'course-v1:Mereka+STRAT301+2026', detail: 'Review 2 submissions · Est. 30 min · 1 day overdue', overdue: true, action: 'Start now →', primary: true },
    { date: d(1), title: 'Quiz — Market sizing frameworks', type: 'Quiz', course: 'Strategic thinking for modern leaders', courseId: 'course-v1:Mereka+STRAT301+2026', detail: '10 questions · Est. 15 min · 2 attempts allowed', overdue: false, action: 'Start quiz →', primary: true },
    { date: d(3), title: 'Reading — OKR principles & anti-patterns', type: 'Reading', course: 'Strategic thinking for modern leaders', courseId: 'course-v1:Mereka+STRAT301+2026', detail: '4 chapters · Est. 20 min · Prepares you for Mod 4', overdue: false, action: 'Open reading', primary: false },
    { date: d(5), title: 'Assignment — Build a weekly metrics dashboard', type: 'Assignment', course: 'Analytics for non-analysts', courseId: 'course-v1:Mereka+DATA201+2026', detail: 'Submit a link or file · Est. 1.5h · Counts toward certificate', overdue: false, action: 'Open brief', primary: false },
    { date: d(7), title: 'Assignment — Run 3 empathy interviews', type: 'Assignment', course: 'Design thinking fundamentals', courseId: 'course-v1:Mereka+DESIGN101+2026', detail: 'Upload notes + audio · Est. 2.5h · Peer-reviewed', overdue: false, action: 'Open brief', primary: false },
    { date: d(11), title: 'Quiz — Spotting misleading charts', type: 'Quiz', course: 'Analytics for non-analysts', courseId: 'course-v1:Mereka+DATA201+2026', detail: '8 questions · Est. 12 min · Unlimited attempts', overdue: false, action: 'Preview', primary: false },
  ];
}

function buildTypeChips(items) {
  const types = {};
  items.forEach(i => { types[i.type] = (types[i.type] || 0) + 1; });
  return Object.entries(types).map(([t, n]) =>
    `<button class="mylearning__chip">${t}s <span class="count">(${n})</span></button>`
  ).join('');
}

function deadlineRow(item, isLast) {
  const dt = item.date;
  const day = String(dt.getDate()).padStart(2, '0');
  const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
  const days = ['Sun','Mon','Tue','Wed','Thu','Fri','Sat'];
  const mon = months[dt.getMonth()];
  const dayName = days[dt.getDay()];

  let dateColor = 'var(--primary)';
  let dateSub = `${mon} · ${dayName}`;
  if (item.overdue) { dateColor = '#B04636'; dateSub = `${mon} · Late`; }
  else {
    const diff = Math.ceil((dt - new Date()) / 86400000);
    if (diff <= 1) { dateColor = '#C87700'; dateSub = `${mon} · Tomorrow`; }
  }

  const bgStyle = item.overdue ? 'background:#FFF5F3;' : '';
  const chipStyle = item.overdue ? 'background:#FDECE8;color:#B04636;' : '';
  const catClass = item.type === 'Quiz' ? 'is-strategy' : item.type === 'Assignment' ? 'is-data' : '';

  return `
  <div class="deadline-row" style="display:flex;align-items:center;gap:16px;padding:18px 20px;${isLast ? '' : 'border-bottom:1px solid var(--border);'}${bgStyle}" data-course="${item.courseId || ''}">
    <div style="flex:0 0 56px;text-align:center;">
      <div style="font-family:var(--font-display);font-weight:700;font-size:22px;color:${dateColor};line-height:1;">${day}</div>
      <div style="font-size:10px;color:${dateColor};text-transform:uppercase;letter-spacing:0.5px;margin-top:2px;font-weight:600;">${dateSub}</div>
    </div>
    <div style="flex:1;min-width:0;">
      <div style="display:flex;align-items:center;gap:8px;margin-bottom:4px;">
        <span class="chip chip--tag ${catClass}" style="font-size:10px;${chipStyle}">${item.type}</span>
        <span style="font-size:11px;color:var(--medium-grey);">${item.course}</span>
      </div>
      <div style="font-family:var(--font-display);font-weight:600;font-size:15px;line-height:1.3;">${item.title}</div>
      <div style="font-size:12px;color:var(--medium-grey);margin-top:4px;">${item.detail || ''}</div>
    </div>
    <button class="btn ${item.primary ? 'btn--primary' : 'btn--outline'} btn--sm js-deadline-action" data-course="${item.courseId || ''}">${item.action || 'Open'}</button>
  </div>`;
}

function wireEvents() {
  document.getElementById('bcHome')?.addEventListener('click', e => { e.preventDefault(); navigate('/'); });
  document.getElementById('syncCalBtn')?.addEventListener('click', () => {
    alert('Calendar sync coming soon! For now, add deadlines manually or check this page regularly.');
  });

  document.querySelectorAll('.js-deadline-action').forEach(btn => {
    btn.addEventListener('click', () => {
      const cid = btn.dataset.course;
      if (cid) navigate('/course/' + encodeURIComponent(cid));
    });
  });

  document.querySelectorAll('.mylearning__chip').forEach(chip => {
    chip.addEventListener('click', () => {
      document.querySelectorAll('.mylearning__chip').forEach(c => c.classList.remove('is-active'));
      chip.classList.add('is-active');
    });
  });
}
