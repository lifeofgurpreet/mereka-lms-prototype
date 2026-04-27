// Page: Studio — full course authoring UI with real Open edX data
// Fetches courses from /api/courses/v1/courses/ (academyv2.mereka.dev)

import { listCourses, normalizeCourse } from '../api/courses.js';
import { getCourseOutline } from '../api/courses.js';

let COURSES = [];
let currentCourseId = null;

/** Map an Open edX course record into the shape Studio UI expects */
function mapCourse(c) {
  const startDate = c.start ? new Date(c.start) : null;
  const now = new Date();
  // Infer status from dates: future start → draft, past end → archived, else published
  let status = 'published';
  if (startDate && startDate.getFullYear() >= 2030) status = 'draft';
  else if (c.end && new Date(c.end) < now) status = 'archived';
  // Pacing as cohort label
  const cohort = c.startDisplay || (startDate ? startDate.toLocaleDateString('en-MY', { month:'short', year:'numeric' }) : '—');
  return {
    id: c.courseId || c.id,
    title: c.name || '(Untitled)',
    code: c.number || c.courseId?.split('+')[1] || '—',
    cohort,
    modules: 0,    // not available from public API
    status,
    enrolled: 0,   // needs auth
    completion: 0,  // needs auth
    rating: 0,      // not available
    owner: c.org || 'MEREKA',
    updated: '—',
    pacing: c.pacing || 'instructor',
    image: c.image || null,
    _raw: c._raw || c,
  };
}

async function fetchCourses() {
  try {
    const { courses } = await listCourses({ pageSize: 50 });
    COURSES = courses.map(mapCourse);
    // Try to get enrollment counts if user is logged in
    try {
      const { apiGet } = await import('../api/client.js');
      const enrollments = await apiGet('/api/enrollment/v1/enrollment');
      if (Array.isArray(enrollments)) {
        const countMap = {};
        enrollments.forEach(e => {
          const cid = e.course_details?.course_id || e.course_id;
          if (cid) countMap[cid] = (countMap[cid] || 0) + 1;
        });
        COURSES.forEach(c => { if (countMap[c.id]) c.enrolled = countMap[c.id]; });
      }
    } catch (_) { /* auth not available, skip enrollment data */ }
  } catch (err) {
    console.warn('[studio] Failed to fetch courses from API, using empty list:', err);
    COURSES = [];
  }
  if (COURSES.length > 0) currentCourseId = COURSES[0].id;
}

/** Try to load real course blocks for the outline. Falls back to demo outline if auth fails. */
async function tryLoadOutline(rootEl, courseId) {
  const container = rootEl.querySelector('#outlineColumn');
  if (!container) return;
  try {
    const data = await getCourseOutline(courseId, { depth: 'all' });
    const blocks = data.blocks || {};
    const root = blocks[data.root];
    if (!root || !root.children || root.children.length === 0) return; // keep demo
    // Build outline from real blocks
    let html = '<div style="display:flex; justify-content:space-between; align-items:center; margin-bottom:14px;"><h3 style="font-size:18px;">Course outline</h3><div class="row"><button class="btn btn--ghost btn--sm js-outline-expand-toggle"><span class="material-symbols-outlined" style="font-size:16px;">unfold_more</span> Expand all</button><button class="btn btn--primary btn--sm js-outline-new-section"><span class="material-symbols-outlined" style="font-size:16px;">add</span> New section</button></div></div>';
    root.children.forEach((chapterId, i) => {
      const chapter = blocks[chapterId];
      if (!chapter) return;
      const name = chapter.display_name || 'Section ' + (i + 1);
      html += '<div class="outline-section"><div class="outline-section__head"><h3><span class="material-symbols-outlined drag" style="font-size:18px;">drag_indicator</span> ' + name + '</h3><div class="handle-group"><span class="visibility">Published</span><button class="btn btn--ghost btn--sm js-section-menu"><span class="material-symbols-outlined" style="font-size:16px;">more_horiz</span></button></div></div>';
      if (chapter.children) {
        chapter.children.forEach(seqId => {
          const seq = blocks[seqId];
          if (!seq) return;
          const seqName = seq.display_name || 'Subsection';
          const unitCount = seq.children ? seq.children.length : 0;
          html += '<div class="outline-subsection"><div class="outline-subsection__head"><span>' + seqName + '</span><span style="font-size:11px; color:var(--medium-grey);">' + unitCount + ' units</span></div>';
          if (seq.children) {
            seq.children.forEach(vertId => {
              const vert = blocks[vertId];
              if (!vert) return;
              const vName = vert.display_name || 'Unit';
              const typeIcon = vert.type === 'vertical' ? 'view_agenda' : 'description';
              html += '<div class="outline-unit"><div class="type-icon"><span class="material-symbols-outlined" style="font-size:13px;">' + typeIcon + '</span></div><span class="unit-title">' + vName + '</span><button class="btn btn--ghost btn--sm unit-edit"><span class="material-symbols-outlined" style="font-size:14px;">edit</span> Edit</button></div>';
            });
          }
          html += '<button class="add-unit-btn"><span class="material-symbols-outlined" style="font-size:14px;">add</span> Add unit</button></div>';
        });
      }
      html += '</div>';
    });
    container.innerHTML = html;
    // Re-wire section menus and unit edit buttons
    container.querySelectorAll('.unit-edit').forEach(btn => {
      btn.addEventListener('click', () => {
        const unitTitle = btn.closest('.outline-unit')?.querySelector('.unit-title')?.textContent || 'Unit';
        const editor = rootEl.querySelector('#unitEditor');
        const titleInput = rootEl.querySelector('#unitEditorTitleInput');
        const titleSpan = rootEl.querySelector('#unitEditorTitle');
        if (editor) editor.classList.add('is-open');
        if (titleInput) titleInput.value = unitTitle;
        if (titleSpan) titleSpan.textContent = 'Edit: ' + unitTitle;
      });
    });
    console.log('[studio] Loaded real outline for', courseId, '— ' + root.children.length + ' sections');
  } catch (err) {
    console.log('[studio] Could not load real outline (auth needed?), keeping demo outline:', err.message);
  }
}
const statusLabel = { published:'Published', draft:'Draft', review:'In Review', archived:'Archived' };
const statusClass = { published:'is-published', draft:'is-draft', review:'is-review', archived:'is-archived' };

export async function render(rootEl) {
  rootEl.innerHTML = '<main class="studio" style="display:flex; align-items:center; justify-content:center; min-height:60vh;"><div style="text-align:center;"><div class="spinner" style="width:32px; height:32px; border:3px solid var(--border); border-top-color:var(--primary); border-radius:50%; animation:spin .8s linear infinite; margin:0 auto 16px;"></div><p style="color:var(--medium-grey);">Loading courses from Mereka Academy…</p></div></main><style>@keyframes spin{to{transform:rotate(360deg)}}</style>';
  await fetchCourses();
  rootEl.innerHTML = studioHtml();
  wireStudio(rootEl);
  if (currentCourseId) tryLoadOutline(rootEl, currentCourseId);
}

function studioHtml() {
  return `
  <div id="studio-toast-stack" style="position:fixed; bottom:24px; right:24px; z-index:9999; display:flex; flex-direction:column-reverse; gap:8px;"></div>
  <main class="studio">
    ${sidebarHtml()}
    <div class="studio__main">
      ${headerHtml()}
      ${coursesPane()}
      ${outlinePane()}
      ${libraryPane()}
      ${filesPane()}
      ${schedulePane()}
      ${gradingPane()}
      ${teamPane()}
      ${pricingPane()}
      ${advancedPane()}
      ${analyticsPane()}
      ${submissionsPane()}
      ${discussionsPane()}
    </div>
  </main>`;
}

function sidebarHtml() {
  return `
    <aside class="studio__side">
      <span class="studio__mode"><span class="material-symbols-outlined" style="font-size:14px;">edit</span> Author mode</span>
      <div class="studio__nav-label">Workspace</div>
      <ul class="studio__nav">
        <li data-studio-pane="courses"><span class="material-symbols-outlined">dashboard</span> My courses</li>
      </ul>
      <div class="studio__nav-label">Editing this course</div>
      <ul class="studio__nav">
        <li class="is-active" data-studio-pane="outline"><span class="material-symbols-outlined">list_alt</span> Course outline</li>
        <li data-studio-pane="library"><span class="material-symbols-outlined">library_books</span> Content library</li>
        <li data-studio-pane="files"><span class="material-symbols-outlined">upload_file</span> Files &amp; assets</li>
      </ul>
      <div class="studio__nav-label">Course settings</div>
      <ul class="studio__nav">
        <li data-studio-pane="schedule"><span class="material-symbols-outlined">schedule</span> Schedule</li>
        <li data-studio-pane="grading"><span class="material-symbols-outlined">grading</span> Grading</li>
        <li data-studio-pane="team"><span class="material-symbols-outlined">groups</span> Course team</li>
        <li data-studio-pane="pricing"><span class="material-symbols-outlined">payments</span> Pricing</li>
        <li data-studio-pane="advanced"><span class="material-symbols-outlined">tune</span> Advanced</li>
      </ul>
      <div class="studio__nav-label">Reporting</div>
      <ul class="studio__nav">
        <li data-studio-pane="analytics"><span class="material-symbols-outlined">bar_chart</span> Analytics</li>
        <li data-studio-pane="submissions"><span class="material-symbols-outlined">assignment_turned_in</span> Submissions</li>
        <li data-studio-pane="discussions"><span class="material-symbols-outlined">forum</span> Discussions</li>
      </ul>
    </aside>`;
}

function headerHtml() {
  const firstCourse = COURSES.find(c => c.id === currentCourseId) || COURSES[0] || { title:'No courses', code:'—', cohort:'—', owner:'—' };
  return `
      <div class="studio__head" data-studio-head>
        <div style="flex:1; min-width:260px;">
          <div style="font-size:11px; color:var(--medium-grey); text-transform:uppercase; letter-spacing:0.04em; margin-bottom:6px;">Now editing</div>
          <div class="course-switcher" id="courseSwitcher">
            <button class="course-switcher__btn" id="courseSwitcherBtn" aria-haspopup="true" aria-expanded="false">
              <span class="material-symbols-outlined">school</span>
              <span class="course-switcher__btn-text">
                <span id="courseSwitcherTitle">${firstCourse.title}</span>
                <span class="course-switcher__btn-code" id="courseSwitcherSub">${firstCourse.code} · ${firstCourse.cohort} · ${firstCourse.owner}</span>
              </span>
              <span class="material-symbols-outlined">unfold_more</span>
            </button>
            <div class="course-switcher__menu" id="courseSwitcherMenu" role="listbox">
              <div class="course-switcher__search">
                <input type="text" id="courseSwitcherSearch" placeholder="Search your courses…" />
              </div>
              <div class="course-switcher__list" id="courseSwitcherList"></div>
              <div class="course-switcher__foot">
                <button class="btn btn--ghost btn--sm" id="courseSwitcherAll"><span class="material-symbols-outlined" style="font-size:16px;">dashboard</span> See all courses</button>
                <button class="btn btn--primary btn--sm" id="courseSwitcherNew"><span class="material-symbols-outlined" style="font-size:16px;">add</span> Create new</button>
              </div>
            </div>
          </div>
        </div>
        <div class="studio__actions">
          <span class="studio__status ${firstCourse.status === 'published' ? 'is-live' : ''}" id="studioStatus"><span class="dot"></span> ${statusLabel[firstCourse.status] || 'Draft'} · auto-saved just now</span>
          <button class="btn btn--outline btn--sm js-studio-duplicate"><span class="material-symbols-outlined" style="font-size:16px;">file_copy</span> Duplicate</button>
          <button class="btn btn--outline btn--sm js-studio-export"><span class="material-symbols-outlined" style="font-size:16px;">download</span> Export</button>
          <button class="btn btn--primary btn--sm js-studio-publish" id="studioPublishBtn"><span class="material-symbols-outlined" style="font-size:16px;">rocket_launch</span> Publish</button>
        </div>
      </div>`;
}

function coursesPane() {
  return `
      <div class="studio-pane" data-studio-pane="courses" style="display:none;">
        <div class="courses-pane__head">
          <div>
            <h3 style="font-size:20px; margin-bottom:4px;">My courses <span style="font-weight:400; color:var(--medium-grey);">(${COURSES.length})</span></h3>
            <p style="font-size:13px; color:var(--medium-grey); margin:0;"><span id="coursesCount">5</span> courses · <span id="coursesCountPublished">3</span> published · <span id="coursesCountDraft">1</span> draft · <span id="coursesCountReview">1</span> in review</p>
          </div>
          <div class="courses-pane__head-actions">
            <button class="btn btn--primary btn--sm" id="coursesCreateBtn"><span class="material-symbols-outlined" style="font-size:16px;">add</span> Create new course</button>
          </div>
        </div>
        <div class="courses-pane__filters-row">
          <div class="courses-pane__filters">
            <button class="btn btn--outline btn--sm js-courses-filter is-active" data-courses-filter="all">All</button>
            <button class="btn btn--outline btn--sm js-courses-filter" data-courses-filter="published">Published</button>
            <button class="btn btn--outline btn--sm js-courses-filter" data-courses-filter="draft">Drafts</button>
            <button class="btn btn--outline btn--sm js-courses-filter" data-courses-filter="review">In review</button>
            <button class="btn btn--outline btn--sm js-courses-filter" data-courses-filter="archived">Archived</button>
          </div>
          <div class="courses-pane__search">
            <span class="material-symbols-outlined" style="font-size:16px; color:var(--medium-grey);">search</span>
            <input type="text" id="coursesSearch" placeholder="Search courses…" />
          </div>
        </div>
        <div class="courses-pane__grid" id="coursesGrid"></div>
      </div>`;
}

function outlinePane() {
  const firstCourse = COURSES.find(c => c.id === currentCourseId) || COURSES[0] || { title:'No courses', code:'—', cohort:'—', owner:'—', enrolled:0, completion:0, rating:0, status:'draft' };
  return `
      <div class="studio-pane" data-studio-pane="outline">
        <div class="studio__stats">
          <div class="studio__stat"><span>Enrolled learners</span><strong id="statEnrolled">${firstCourse.enrolled ? firstCourse.enrolled.toLocaleString() : '—'}</strong><span class="trend" style="color:var(--medium-grey);">via API</span></div>
          <div class="studio__stat"><span>Avg. completion</span><strong id="statCompletion">${firstCourse.completion ? firstCourse.completion + '%' : '—'}</strong><span class="trend" style="color:var(--medium-grey);">via API</span></div>
          <div class="studio__stat"><span>Avg. quiz score</span><strong>82%</strong><span class="trend" style="color:var(--medium-grey);">— flat</span></div>
          <div class="studio__stat"><span>Course rating</span><strong id="statRating">${firstCourse.rating ? '★ ' + firstCourse.rating.toFixed(1) : '—'}</strong><span class="trend" style="color:var(--medium-grey);">via API</span></div>
        </div>

        <div class="studio__grid">
          <div id="outlineColumn">
            <div style="display:flex; justify-content:space-between; align-items:center; margin-bottom:14px;">
              <h3 style="font-size:18px;">Course outline</h3>
              <div class="row">
                <button class="btn btn--ghost btn--sm js-outline-expand-toggle"><span class="material-symbols-outlined" style="font-size:16px;">unfold_more</span> Expand all</button>
                <button class="btn btn--primary btn--sm js-outline-new-section"><span class="material-symbols-outlined" style="font-size:16px;">add</span> New section</button>
              </div>
            </div>

            <div class="outline-section">
              <div class="outline-section__head">
                <h3><span class="material-symbols-outlined drag" style="font-size:18px;">drag_indicator</span> Module 1 — Foundations</h3>
                <div class="handle-group"><span class="visibility">Published</span><button class="btn btn--ghost btn--sm js-section-menu"><span class="material-symbols-outlined" style="font-size:16px;">more_horiz</span></button></div>
              </div>
              <div class="outline-subsection">
                <div class="outline-subsection__head"><span>Subsection 1.1 — Welcome &amp; orientation</span><span style="font-size:11px; color:var(--medium-grey);">3 units · 45 min</span></div>
                <div class="outline-unit"><div class="type-icon t-video"><span class="material-symbols-outlined" style="font-size:13px;">play_circle</span></div><span class="unit-title">Welcome &amp; course overview</span><span class="unit-dur">8 min</span><button class="btn btn--ghost btn--sm unit-edit"><span class="material-symbols-outlined" style="font-size:14px;">edit</span> Edit</button></div>
                <div class="outline-unit"><div class="type-icon t-doc"><span class="material-symbols-outlined" style="font-size:13px;">description</span></div><span class="unit-title">What strategy is (and isn't)</span><span class="unit-dur">15 min</span><button class="btn btn--ghost btn--sm unit-edit"><span class="material-symbols-outlined" style="font-size:14px;">edit</span> Edit</button></div>
                <div class="outline-unit"><div class="type-icon t-quiz"><span class="material-symbols-outlined" style="font-size:13px;">quiz</span></div><span class="unit-title">Diagnostic — where are you today</span><span class="unit-dur">10 min · 5 questions</span><button class="btn btn--ghost btn--sm unit-edit"><span class="material-symbols-outlined" style="font-size:14px;">edit</span> Edit</button></div>
                <button class="add-unit-btn"><span class="material-symbols-outlined" style="font-size:14px;">add</span> Add unit</button>
              </div>
            </div>

            <div class="outline-section" style="border:2px solid var(--primary);">
              <div class="outline-section__head">
                <h3><span class="material-symbols-outlined drag" style="font-size:18px;">drag_indicator</span> Module 3 — Frameworks for ambiguity</h3>
                <div class="handle-group"><span class="visibility is-draft">Draft</span><button class="btn btn--ghost btn--sm js-section-menu"><span class="material-symbols-outlined" style="font-size:16px;">more_horiz</span></button></div>
              </div>
              <div class="outline-subsection">
                <div class="outline-subsection__head"><span>Subsection 3.1 — The 2x2 matrix</span><span style="font-size:11px; color:var(--medium-grey);">5 units · 1h 10min</span></div>
                <div class="outline-unit"><div class="type-icon t-video"><span class="material-symbols-outlined" style="font-size:13px;">play_circle</span></div><span class="unit-title">Intro to 2x2s</span><span class="unit-dur">6 min</span><button class="btn btn--ghost btn--sm unit-edit"><span class="material-symbols-outlined" style="font-size:14px;">edit</span> Edit</button></div>
                <div class="outline-unit" style="background:rgba(171,59,120,0.08); border-radius:10px;"><div class="type-icon t-video"><span class="material-symbols-outlined" style="font-size:13px;">play_circle</span></div><span class="unit-title" style="color:var(--off-black); font-weight:600;">Frameworks for ambiguity <span style="color:var(--primary); font-size:11px;">· editing</span></span><span class="unit-dur">10 min</span><button class="btn btn--outline btn--sm"><span class="material-symbols-outlined" style="font-size:14px;">edit</span> Editing</button></div>
                <div class="outline-unit"><div class="type-icon t-discuss"><span class="material-symbols-outlined" style="font-size:13px;">forum</span></div><span class="unit-title">Discussion — pick a framework</span><span class="unit-dur">Participation</span><button class="btn btn--ghost btn--sm unit-edit"><span class="material-symbols-outlined" style="font-size:14px;">edit</span> Edit</button></div>
                <div class="outline-unit"><div class="type-icon t-quiz"><span class="material-symbols-outlined" style="font-size:13px;">quiz</span></div><span class="unit-title">Knowledge check</span><span class="unit-dur">8 min · 4 questions</span><button class="btn btn--ghost btn--sm unit-edit"><span class="material-symbols-outlined" style="font-size:14px;">edit</span> Edit</button></div>
                <div class="outline-unit"><div class="type-icon t-assign"><span class="material-symbols-outlined" style="font-size:13px;">assignment</span></div><span class="unit-title">Capstone — strategic memo</span><span class="unit-dur">Peer reviewed</span><button class="btn btn--ghost btn--sm unit-edit"><span class="material-symbols-outlined" style="font-size:14px;">edit</span> Edit</button></div>
                <button class="add-unit-btn"><span class="material-symbols-outlined" style="font-size:14px;">add</span> Add unit</button>
              </div>
            </div>

            <div class="outline-section">
              <div class="outline-section__head">
                <h3><span class="material-symbols-outlined drag" style="font-size:18px;">drag_indicator</span> Module 4 — Choosing bets</h3>
                <div class="handle-group"><span class="visibility is-hidden">Hidden</span><button class="btn btn--ghost btn--sm js-section-menu"><span class="material-symbols-outlined" style="font-size:16px;">more_horiz</span></button></div>
              </div>
            </div>
          </div>

          <aside class="unit-editor" id="unitEditor">
            <h4><span id="unitEditorTitle">Edit unit</span><span class="close material-symbols-outlined js-unit-editor-close">close</span></h4>
            <div class="field"><label class="form-label">Unit title</label><input class="form-input" id="unitEditorTitleInput" value="Frameworks for ambiguity" /></div>
            <div class="field"><label class="form-label">Content type</label><div class="xblock-picker"><div class="xblock-pill is-selected"><span class="material-symbols-outlined">play_circle</span> Video</div><div class="xblock-pill"><span class="material-symbols-outlined">description</span> Reading</div><div class="xblock-pill"><span class="material-symbols-outlined">quiz</span> Quiz</div><div class="xblock-pill"><span class="material-symbols-outlined">forum</span> Discussion</div><div class="xblock-pill"><span class="material-symbols-outlined">assignment</span> Assignment</div><div class="xblock-pill"><span class="material-symbols-outlined">extension</span> Embed (LTI)</div></div></div>
            <div class="field"><label class="form-label">Video source</label><input class="form-input" placeholder="Paste YouTube, Vimeo, or upload" value="mux://strat-101-m3-u2.mp4" /></div>
            <div class="row-2 field"><div><label class="form-label">Est. duration</label><input class="form-input" value="10 min" /></div><div><label class="form-label">Visibility</label><select class="form-input"><option>Published</option><option selected>Draft</option><option>Hidden</option></select></div></div>
            <div class="field"><label class="form-label">Completion rule</label><select class="form-input"><option>Watch ≥ 90%</option><option>Mark as complete (manual)</option><option>Required before next unit</option></select></div>
            <div class="field"><label class="form-label">Instructor notes (not shown to learner)</label><textarea class="form-input" rows="3" placeholder="Notes for co-instructors or future-you…">Tighten the 2x2 walkthrough around the 4:20 mark — too slow.</textarea></div>
            <div style="display:flex; gap:8px; margin-top:8px;"><button class="btn btn--outline btn--sm js-unit-editor-cancel" style="flex:1; justify-content:center;">Cancel</button><button class="btn btn--primary btn--sm js-unit-editor-save" style="flex:1; justify-content:center;">Save unit</button></div>
          </aside>
        </div>
      </div>`;
}

function libraryPane() {
  return `
      <div class="studio-pane" data-studio-pane="library" style="display:none;">
        <div style="display:flex; justify-content:space-between; align-items:center; margin-bottom:18px;">
          <div><h3 style="font-size:20px; margin:0;">Content library</h3><p style="color:var(--medium-grey); font-size:13px; margin:2px 0 0;">Reusable xblocks and question banks. Drop them into any unit.</p></div>
          <div class="row"><button class="btn btn--ghost btn--sm js-lib-search"><span class="material-symbols-outlined" style="font-size:16px;">search</span> Search library</button><button class="btn btn--primary btn--sm js-lib-new"><span class="material-symbols-outlined" style="font-size:16px;">add</span> New library</button></div>
        </div>
        <div style="display:grid; grid-template-columns:repeat(auto-fill,minmax(260px,1fr)); gap:14px;">
          <div class="card" style="padding:18px;"><div class="type-icon t-quiz" style="width:36px; height:36px; margin-bottom:10px;"><span class="material-symbols-outlined">quiz</span></div><h4 style="margin:0 0 4px;">Strategy question bank</h4><p style="font-size:13px; color:var(--medium-grey); margin:0 0 10px;">48 questions · last updated Apr 12</p><button class="btn btn--outline btn--sm js-lib-open">Open</button></div>
          <div class="card" style="padding:18px;"><div class="type-icon t-video" style="width:36px; height:36px; margin-bottom:10px;"><span class="material-symbols-outlined">play_circle</span></div><h4 style="margin:0 0 4px;">Shared intro videos</h4><p style="font-size:13px; color:var(--medium-grey); margin:0 0 10px;">12 videos · reusable across cohorts</p><button class="btn btn--outline btn--sm js-lib-open">Open</button></div>
          <div class="card" style="padding:18px;"><div class="type-icon t-doc" style="width:36px; height:36px; margin-bottom:10px;"><span class="material-symbols-outlined">description</span></div><h4 style="margin:0 0 4px;">Case study readings</h4><p style="font-size:13px; color:var(--medium-grey); margin:0 0 10px;">24 readings · 7 translations</p><button class="btn btn--outline btn--sm js-lib-open">Open</button></div>
          <div class="card" style="padding:18px;"><div class="type-icon t-assign" style="width:36px; height:36px; margin-bottom:10px;"><span class="material-symbols-outlined">assignment</span></div><h4 style="margin:0 0 4px;">Peer-review rubrics</h4><p style="font-size:13px; color:var(--medium-grey); margin:0 0 10px;">9 rubrics · ORA-compatible</p><button class="btn btn--outline btn--sm js-lib-open">Open</button></div>
        </div>
      </div>`;
}

function filesPane() {
  return `
      <div class="studio-pane" data-studio-pane="files" style="display:none;">
        <div style="display:flex; justify-content:space-between; align-items:center; margin-bottom:18px;">
          <div><h3 style="font-size:20px; margin:0;">Files &amp; assets</h3><p style="color:var(--medium-grey); font-size:13px; margin:2px 0 0;">Images, PDFs, video masters. 2.4 GB of 10 GB used.</p></div>
          <button class="btn btn--primary btn--sm js-files-upload"><span class="material-symbols-outlined" style="font-size:16px;">upload</span> Upload files</button>
        </div>
        <div class="card" style="padding:0; overflow:hidden;">
          <table style="width:100%; border-collapse:collapse; font-size:14px;">
            <thead><tr style="background:var(--surface); text-align:left;"><th style="padding:12px 16px; font-family:var(--font-display); font-weight:600; font-size:12px; text-transform:uppercase; letter-spacing:0.5px; color:var(--dark-grey);">Name</th><th style="padding:12px 16px; font-family:var(--font-display); font-weight:600; font-size:12px; text-transform:uppercase; letter-spacing:0.5px; color:var(--dark-grey);">Type</th><th style="padding:12px 16px; font-family:var(--font-display); font-weight:600; font-size:12px; text-transform:uppercase; letter-spacing:0.5px; color:var(--dark-grey);">Size</th><th style="padding:12px 16px; font-family:var(--font-display); font-weight:600; font-size:12px; text-transform:uppercase; letter-spacing:0.5px; color:var(--dark-grey);">Uploaded</th><th></th></tr></thead>
            <tbody id="filesBody">
              <tr style="border-top:1px solid var(--border);"><td style="padding:14px 16px;">course-hero.jpg</td><td style="padding:14px 16px;">Image</td><td style="padding:14px 16px;">482 KB</td><td style="padding:14px 16px;">Apr 18</td><td style="padding:14px 16px;"><button class="btn btn--ghost btn--sm js-file-menu">•••</button></td></tr>
              <tr style="border-top:1px solid var(--border);"><td style="padding:14px 16px;">strat-101-m1-reading.pdf</td><td style="padding:14px 16px;">PDF</td><td style="padding:14px 16px;">1.1 MB</td><td style="padding:14px 16px;">Apr 16</td><td style="padding:14px 16px;"><button class="btn btn--ghost btn--sm js-file-menu">•••</button></td></tr>
              <tr style="border-top:1px solid var(--border);"><td style="padding:14px 16px;">m3-frameworks-master.mp4</td><td style="padding:14px 16px;">Video</td><td style="padding:14px 16px;">142 MB</td><td style="padding:14px 16px;">Apr 14</td><td style="padding:14px 16px;"><button class="btn btn--ghost btn--sm js-file-menu">•••</button></td></tr>
              <tr style="border-top:1px solid var(--border);"><td style="padding:14px 16px;">capstone-rubric.docx</td><td style="padding:14px 16px;">Document</td><td style="padding:14px 16px;">68 KB</td><td style="padding:14px 16px;">Apr 10</td><td style="padding:14px 16px;"><button class="btn btn--ghost btn--sm js-file-menu">•••</button></td></tr>
            </tbody>
          </table>
        </div>
      </div>`;
}

function schedulePane() {
  return `
      <div class="studio-pane" data-studio-pane="schedule" style="display:none;">
        <div style="margin-bottom:18px;"><h3 style="font-size:20px; margin:0;">Schedule</h3><p style="color:var(--medium-grey); font-size:13px; margin:2px 0 0;">Set cohort dates, enrollment windows, and release cadence.</p></div>
        <div class="card" style="padding:22px; max-width:640px;">
          <div class="settings-field"><label>Course start date</label><input type="date" value="2026-05-05" /></div>
          <div class="settings-field"><label>Course end date</label><input type="date" value="2026-07-28" /></div>
          <div class="settings-field"><label>Enrollment deadline</label><input type="date" value="2026-05-03" /></div>
          <div class="settings-field"><label>Content release</label><select><option>Self-paced · all modules unlocked</option><option selected>Weekly drip · one module per week</option><option>Custom schedule</option></select></div>
          <div class="toggle-row"><div class="toggle-row__body"><strong>Allow late submissions</strong><span>Accept work after deadlines with 10% penalty</span></div><div class="toggle is-on"></div></div>
          <div class="settings-card__foot"><button class="btn btn--primary btn--sm js-schedule-save">Save schedule</button></div>
        </div>
      </div>`;
}

function gradingPane() {
  return `
      <div class="studio-pane" data-studio-pane="grading" style="display:none;">
        <div style="margin-bottom:18px;"><h3 style="font-size:20px; margin:0;">Grading</h3><p style="color:var(--medium-grey); font-size:13px; margin:2px 0 0;">Define how final grades are calculated and what counts as passing.</p></div>
        <div class="card" style="padding:22px;">
          <h4 style="margin:0 0 14px;">Grading weights</h4>
          <div style="display:grid; grid-template-columns:1fr 100px 1fr; gap:14px; align-items:center; margin-bottom:10px;"><span>Quizzes</span><input class="js-grade-weight" type="number" value="30" style="padding:8px 12px; border:1px solid var(--border); border-radius:8px; text-align:right;"/><span style="color:var(--medium-grey);">% of final grade</span></div>
          <div style="display:grid; grid-template-columns:1fr 100px 1fr; gap:14px; align-items:center; margin-bottom:10px;"><span>Peer-reviewed assignments</span><input class="js-grade-weight" type="number" value="40" style="padding:8px 12px; border:1px solid var(--border); border-radius:8px; text-align:right;"/><span style="color:var(--medium-grey);">% of final grade</span></div>
          <div style="display:grid; grid-template-columns:1fr 100px 1fr; gap:14px; align-items:center; margin-bottom:10px;"><span>Capstone project</span><input class="js-grade-weight" type="number" value="25" style="padding:8px 12px; border:1px solid var(--border); border-radius:8px; text-align:right;"/><span style="color:var(--medium-grey);">% of final grade</span></div>
          <div style="display:grid; grid-template-columns:1fr 100px 1fr; gap:14px; align-items:center; margin-bottom:14px;"><span>Participation</span><input class="js-grade-weight" type="number" value="5" style="padding:8px 12px; border:1px solid var(--border); border-radius:8px; text-align:right;"/><span style="color:var(--medium-grey);">% of final grade</span></div>
          <div class="grading-total" id="gradingTotal" style="padding:12px 16px; background:var(--surface); border-radius:10px; font-size:14px;"><strong>Total: <span id="gradingTotalValue">100</span>%</strong> · Pass mark set at 70%</div>
          <div class="settings-card__foot"><button class="btn btn--primary btn--sm js-grading-save">Save grading policy</button></div>
        </div>
      </div>`;
}

function teamPane() {
  return `
      <div class="studio-pane" data-studio-pane="team" style="display:none;">
        <div style="display:flex; justify-content:space-between; align-items:center; margin-bottom:18px;">
          <div><h3 style="font-size:20px; margin:0;">Course team</h3><p style="color:var(--medium-grey); font-size:13px; margin:2px 0 0;">Manage instructors, TAs, and observers.</p></div>
          <button class="btn btn--primary btn--sm js-team-invite"><span class="material-symbols-outlined" style="font-size:16px;">person_add</span> Invite member</button>
        </div>
        <div class="card" style="padding:0; overflow:hidden;">
          <table style="width:100%; border-collapse:collapse; font-size:14px;">
            <thead><tr style="background:var(--surface); text-align:left;"><th style="padding:12px 16px; font-family:var(--font-display); font-weight:600; font-size:12px; text-transform:uppercase; letter-spacing:0.5px; color:var(--dark-grey);">Name</th><th style="padding:12px 16px; font-family:var(--font-display); font-weight:600; font-size:12px; text-transform:uppercase; letter-spacing:0.5px; color:var(--dark-grey);">Role</th><th style="padding:12px 16px; font-family:var(--font-display); font-weight:600; font-size:12px; text-transform:uppercase; letter-spacing:0.5px; color:var(--dark-grey);">Added</th><th></th></tr></thead>
            <tbody id="teamBody">
              <tr style="border-top:1px solid var(--border);"><td style="padding:14px 16px; display:flex; align-items:center; gap:10px;"><div class="avatar" style="width:30px; height:30px; font-size:12px;">AY</div> Amira Yusof <span style="font-size:11px; color:var(--primary); background:rgba(171,59,120,0.1); padding:2px 8px; border-radius:var(--r-pill); margin-left:4px;">Owner</span></td><td style="padding:14px 16px;">Course admin</td><td style="padding:14px 16px;">Jan 12</td><td style="padding:14px 16px;"><button class="btn btn--ghost btn--sm js-team-menu">•••</button></td></tr>
              <tr style="border-top:1px solid var(--border);"><td style="padding:14px 16px; display:flex; align-items:center; gap:10px;"><div class="avatar" style="width:30px; height:30px; font-size:12px;">ML</div> Mei Lin Tan</td><td style="padding:14px 16px;">Instructor</td><td style="padding:14px 16px;">Jan 15</td><td style="padding:14px 16px;"><button class="btn btn--ghost btn--sm js-team-menu">•••</button></td></tr>
              <tr style="border-top:1px solid var(--border);"><td style="padding:14px 16px; display:flex; align-items:center; gap:10px;"><div class="avatar" style="width:30px; height:30px; font-size:12px;">RP</div> Raj Patel</td><td style="padding:14px 16px;">Teaching assistant</td><td style="padding:14px 16px;">Feb 02</td><td style="padding:14px 16px;"><button class="btn btn--ghost btn--sm js-team-menu">•••</button></td></tr>
              <tr style="border-top:1px solid var(--border);"><td style="padding:14px 16px; display:flex; align-items:center; gap:10px;"><div class="avatar" style="width:30px; height:30px; font-size:12px;">SK</div> Sarah Kim</td><td style="padding:14px 16px;">Observer</td><td style="padding:14px 16px;">Mar 08</td><td style="padding:14px 16px;"><button class="btn btn--ghost btn--sm js-team-menu">•••</button></td></tr>
            </tbody>
          </table>
        </div>
      </div>`;
}

function pricingPane() {
  return `
      <div class="studio-pane" data-studio-pane="pricing" style="display:none;">
        <div style="margin-bottom:18px;"><h3 style="font-size:20px; margin:0;">Pricing</h3><p style="color:var(--medium-grey); font-size:13px; margin:2px 0 0;">Set access tiers and promotion codes.</p></div>
        <div style="display:grid; grid-template-columns:1fr 1fr; gap:14px;">
          <div class="card" style="padding:22px;">
            <h4 style="margin:0 0 10px;">Free audit</h4>
            <p style="font-size:13px; color:var(--medium-grey); margin:0 0 14px;">Lectures &amp; readings only · no grading · no certificate</p>
            <div class="toggle-row"><div class="toggle-row__body"><strong>Enabled</strong><span>Currently available to all learners</span></div><div class="toggle is-on"></div></div>
          </div>
          <div class="card" style="padding:22px;">
            <h4 style="margin:0 0 10px;">Paid track</h4>
            <div class="settings-field"><label>Price (MYR)</label><input value="249" /></div>
            <div class="toggle-row"><div class="toggle-row__body"><strong>Includes verified certificate</strong><span>Issued on completion + pass mark</span></div><div class="toggle is-on"></div></div>
            <div class="toggle-row"><div class="toggle-row__body"><strong>Financial aid available</strong><span>Allow learners to apply for reduced price</span></div><div class="toggle is-on"></div></div>
          </div>
        </div>
        <div class="card" style="padding:22px; margin-top:14px;">
          <h4 style="margin:0 0 10px;">Promotion codes</h4>
          <div style="display:flex; justify-content:space-between; padding:10px 0; border-bottom:1px solid var(--border); font-size:14px;"><span><code style="background:var(--surface); padding:2px 8px; border-radius:6px;">EARLYBIRD</code> — 30% off · 48 redemptions</span><button class="btn btn--ghost btn--sm js-promo-edit">Edit</button></div>
          <div style="display:flex; justify-content:space-between; padding:10px 0; font-size:14px;"><span><code style="background:var(--surface); padding:2px 8px; border-radius:6px;">TEAMSOF10</code> — 20% off · 12 redemptions</span><button class="btn btn--ghost btn--sm js-promo-edit">Edit</button></div>
        </div>
      </div>`;
}

function advancedPane() {
  return `
      <div class="studio-pane" data-studio-pane="advanced" style="display:none;">
        <div style="margin-bottom:18px;"><h3 style="font-size:20px; margin:0;">Advanced settings</h3><p style="color:var(--medium-grey); font-size:13px; margin:2px 0 0;">Expert controls. Changes here affect the whole course.</p></div>
        <div class="card" style="padding:22px;">
          <div class="toggle-row"><div class="toggle-row__body"><strong>Enable LTI tool support</strong><span>Allow embedding external tools (Jupyter, Figma, etc.)</span></div><div class="toggle is-on"></div></div>
          <div class="toggle-row"><div class="toggle-row__body"><strong>Open response assessments (ORA)</strong><span>Peer-reviewed submissions with rubrics</span></div><div class="toggle is-on"></div></div>
          <div class="toggle-row"><div class="toggle-row__body"><strong>Proctored exams</strong><span>Require webcam + ID verification for graded quizzes</span></div><div class="toggle"></div></div>
          <div class="toggle-row"><div class="toggle-row__body"><strong>Certificate signatory override</strong><span>Use a custom signatory instead of default instructor</span></div><div class="toggle"></div></div>
          <div class="toggle-row"><div class="toggle-row__body"><strong>Raw HTML blocks</strong><span>Allow instructors to author raw HTML in units (security review required)</span></div><div class="toggle"></div></div>
        </div>
      </div>`;
}

function analyticsPane() {
  return `
      <div class="studio-pane" data-studio-pane="analytics" style="display:none;">
        <div style="margin-bottom:18px;"><h3 style="font-size:20px; margin:0;">Analytics</h3><p style="color:var(--medium-grey); font-size:13px; margin:2px 0 0;">Insights into engagement, completion, and quiz performance.</p></div>
        <div class="studio__stats">
          <div class="studio__stat"><span>Active learners (7d)</span><strong>864</strong><span class="trend">↑ 12% vs last week</span></div>
          <div class="studio__stat"><span>Module 1 completion</span><strong>94%</strong><span class="trend">↑ 2%</span></div>
          <div class="studio__stat"><span>Module 3 drop-off</span><strong>18%</strong><span class="trend" style="color:#C23636;">↑ 4% · needs attention</span></div>
          <div class="studio__stat"><span>Avg. session length</span><strong>28 min</strong><span class="trend">↑ 3 min</span></div>
        </div>
        <div class="card" style="padding:22px; margin-top:14px;">
          <h4 style="margin:0 0 14px;">Completion by module</h4>
          <div style="display:flex; align-items:center; gap:12px; margin-bottom:10px;"><span style="width:160px; font-size:13px;">Module 1 — Foundations</span><div style="flex:1; height:8px; background:var(--surface); border-radius:4px; overflow:hidden;"><div style="height:100%; width:94%; background:var(--primary);"></div></div><span style="font-size:13px; font-family:var(--font-display); font-weight:600; width:40px; text-align:right;">94%</span></div>
          <div style="display:flex; align-items:center; gap:12px; margin-bottom:10px;"><span style="width:160px; font-size:13px;">Module 2 — Markets</span><div style="flex:1; height:8px; background:var(--surface); border-radius:4px; overflow:hidden;"><div style="height:100%; width:82%; background:var(--primary);"></div></div><span style="font-size:13px; font-family:var(--font-display); font-weight:600; width:40px; text-align:right;">82%</span></div>
          <div style="display:flex; align-items:center; gap:12px; margin-bottom:10px;"><span style="width:160px; font-size:13px;">Module 3 — Frameworks</span><div style="flex:1; height:8px; background:var(--surface); border-radius:4px; overflow:hidden;"><div style="height:100%; width:64%; background:#C23636;"></div></div><span style="font-size:13px; font-family:var(--font-display); font-weight:600; width:40px; text-align:right;">64%</span></div>
          <div style="display:flex; align-items:center; gap:12px; margin-bottom:10px;"><span style="width:160px; font-size:13px;">Module 4 — Choosing bets</span><div style="flex:1; height:8px; background:var(--surface); border-radius:4px; overflow:hidden;"><div style="height:100%; width:52%; background:var(--primary);"></div></div><span style="font-size:13px; font-family:var(--font-display); font-weight:600; width:40px; text-align:right;">52%</span></div>
          <div style="display:flex; align-items:center; gap:12px;"><span style="width:160px; font-size:13px;">Module 5 — Execution</span><div style="flex:1; height:8px; background:var(--surface); border-radius:4px; overflow:hidden;"><div style="height:100%; width:38%; background:var(--primary);"></div></div><span style="font-size:13px; font-family:var(--font-display); font-weight:600; width:40px; text-align:right;">38%</span></div>
        </div>
      </div>`;
}

function submissionsPane() {
  return `
      <div class="studio-pane" data-studio-pane="submissions" style="display:none;">
        <div style="display:flex; justify-content:space-between; align-items:center; margin-bottom:18px;">
          <div><h3 style="font-size:20px; margin:0;">Submissions</h3><p style="color:var(--medium-grey); font-size:13px; margin:2px 0 0;">38 pending · 14 awaiting peer review · 2 flagged</p></div>
          <div class="row"><button class="btn btn--primary btn--sm js-sub-filter is-active" data-sub-filter="all">All</button><button class="btn btn--ghost btn--sm js-sub-filter" data-sub-filter="pending">Pending</button><button class="btn btn--ghost btn--sm js-sub-filter" data-sub-filter="flagged">Flagged</button></div>
        </div>
        <div class="card" style="padding:0; overflow:hidden;">
          <table style="width:100%; border-collapse:collapse; font-size:14px;">
            <thead><tr style="background:var(--surface); text-align:left;"><th style="padding:12px 16px; font-family:var(--font-display); font-weight:600; font-size:12px; text-transform:uppercase; letter-spacing:0.5px; color:var(--dark-grey);">Learner</th><th style="padding:12px 16px; font-family:var(--font-display); font-weight:600; font-size:12px; text-transform:uppercase; letter-spacing:0.5px; color:var(--dark-grey);">Assignment</th><th style="padding:12px 16px; font-family:var(--font-display); font-weight:600; font-size:12px; text-transform:uppercase; letter-spacing:0.5px; color:var(--dark-grey);">Status</th><th style="padding:12px 16px; font-family:var(--font-display); font-weight:600; font-size:12px; text-transform:uppercase; letter-spacing:0.5px; color:var(--dark-grey);">Submitted</th><th></th></tr></thead>
            <tbody>
              <tr data-sub-status="pending" style="border-top:1px solid var(--border);"><td style="padding:14px 16px;">Faiz Fadhillah</td><td style="padding:14px 16px;">Capstone — strategic memo</td><td style="padding:14px 16px;"><span style="color:#C88A00; font-weight:600;">Pending review</span></td><td style="padding:14px 16px;">Apr 19 · 2 days ago</td><td style="padding:14px 16px;"><button class="btn btn--outline btn--sm js-sub-open">Open</button></td></tr>
              <tr data-sub-status="pending" style="border-top:1px solid var(--border);"><td style="padding:14px 16px;">Priya Menon</td><td style="padding:14px 16px;">M3 · Knowledge check</td><td style="padding:14px 16px;"><span style="color:var(--primary); font-weight:600;">Peer review (2/3)</span></td><td style="padding:14px 16px;">Apr 18</td><td style="padding:14px 16px;"><button class="btn btn--outline btn--sm js-sub-open">Open</button></td></tr>
              <tr data-sub-status="graded" style="border-top:1px solid var(--border);"><td style="padding:14px 16px;">Daniel Wong</td><td style="padding:14px 16px;">Capstone — strategic memo</td><td style="padding:14px 16px;"><span style="color:#237072; font-weight:600;">Graded (88%)</span></td><td style="padding:14px 16px;">Apr 16</td><td style="padding:14px 16px;"><button class="btn btn--ghost btn--sm js-sub-open">View</button></td></tr>
              <tr data-sub-status="flagged" style="border-top:1px solid var(--border);"><td style="padding:14px 16px;">Alex Bin Ismail</td><td style="padding:14px 16px;">M3 · Discussion</td><td style="padding:14px 16px;"><span style="color:#C23636; font-weight:600;">Flagged · plagiarism</span></td><td style="padding:14px 16px;">Apr 15</td><td style="padding:14px 16px;"><button class="btn btn--outline btn--sm js-sub-open">Review</button></td></tr>
            </tbody>
          </table>
        </div>
      </div>`;
}

function discussionsPane() {
  return `
      <div class="studio-pane" data-studio-pane="discussions" style="display:none;">
        <div style="display:flex; justify-content:space-between; align-items:center; margin-bottom:18px;">
          <div><h3 style="font-size:20px; margin:0;">Discussions</h3><p style="color:var(--medium-grey); font-size:13px; margin:2px 0 0;">Course-wide threads. Instructor replies appear with a verified badge.</p></div>
          <button class="btn btn--primary btn--sm js-disc-pin"><span class="material-symbols-outlined" style="font-size:16px;">campaign</span> Pin announcement</button>
        </div>
        <div class="card" style="padding:0;">
          <div class="js-disc-thread" style="padding:18px 22px; border-bottom:1px solid var(--border); cursor:pointer;"><div style="display:flex; justify-content:space-between; margin-bottom:4px;"><strong style="font-family:var(--font-display);">Which 2x2 did you use for your capstone?</strong><span style="font-size:12px; color:var(--medium-grey);">48 replies</span></div><div style="font-size:13px; color:var(--medium-grey);">Module 3 · started by Mei Lin (instructor) · last reply 2h ago</div></div>
          <div class="js-disc-thread" style="padding:18px 22px; border-bottom:1px solid var(--border); cursor:pointer;"><div style="display:flex; justify-content:space-between; margin-bottom:4px;"><strong style="font-family:var(--font-display);">Getting stuck on "ambiguity" vs. "uncertainty"</strong><span style="font-size:12px; color:var(--medium-grey);">12 replies · 1 unresolved</span></div><div style="font-size:13px; color:var(--medium-grey);">Module 3 · started by Faiz · last reply 6h ago</div></div>
          <div class="js-disc-thread" style="padding:18px 22px; border-bottom:1px solid var(--border); cursor:pointer;"><div style="display:flex; justify-content:space-between; margin-bottom:4px;"><strong style="font-family:var(--font-display);">Malaysia-specific examples?</strong><span style="font-size:12px; color:var(--medium-grey);">22 replies</span></div><div style="font-size:13px; color:var(--medium-grey);">General · started by Priya · last reply yesterday</div></div>
          <div class="js-disc-thread" style="padding:18px 22px; cursor:pointer;"><div style="display:flex; justify-content:space-between; margin-bottom:4px;"><strong style="font-family:var(--font-display);">Capstone peer review slot swaps</strong><span style="font-size:12px; color:var(--medium-grey);">7 replies</span></div><div style="font-size:13px; color:var(--medium-grey);">Module 5 · started by Raj (TA) · last reply Apr 18</div></div>
        </div>
      </div>`;
}

// =============================================
// INTERACTIVE WIRING
// =============================================

function wireStudio(rootEl) {
  // ---- Toast system ----
  function showToast(message, kind) {
    const stack = rootEl.querySelector('#studio-toast-stack');
    if (!stack) return;
    const t = document.createElement('div');
    t.className = 'studio-toast' + (kind ? ' is-' + kind : '');
    const iconName = kind === 'success' ? 'check_circle' : kind === 'warning' ? 'warning' : kind === 'error' ? 'error' : 'info';
    t.innerHTML = '<span class="material-symbols-outlined">' + iconName + '</span><span>' + message + '</span><span class="material-symbols-outlined dismiss">close</span>';
    stack.appendChild(t);
    requestAnimationFrame(() => t.classList.add('is-in'));
    const remove = () => { t.classList.remove('is-in'); setTimeout(() => t.remove(), 220); };
    t.querySelector('.dismiss').addEventListener('click', remove);
    setTimeout(remove, 3200);
  }

  // ---- Context menu system ----
  let openMenu = null;
  function closeMenu() { if (openMenu) { openMenu.remove(); openMenu = null; } }
  document.addEventListener('click', (e) => { if (openMenu && !openMenu.contains(e.target)) closeMenu(); });
  function openMenuAt(anchor, items) {
    closeMenu();
    const m = document.createElement('div');
    m.className = 'studio-menu';
    items.forEach(it => {
      if (it.divider) { const d = document.createElement('div'); d.className = 'studio-menu__divider'; m.appendChild(d); return; }
      const el = document.createElement('div');
      el.className = 'studio-menu__item' + (it.danger ? ' is-danger' : '');
      el.innerHTML = (it.icon ? '<span class="material-symbols-outlined">' + it.icon + '</span>' : '') + '<span>' + it.label + '</span>';
      el.addEventListener('click', () => { closeMenu(); if (it.onClick) it.onClick(); });
      m.appendChild(el);
    });
    const r = anchor.getBoundingClientRect();
    m.style.top = (window.scrollY + r.bottom + 6) + 'px';
    m.style.left = (window.scrollX + Math.max(12, r.right - 200)) + 'px';
    document.body.appendChild(m);
    openMenu = m;
  }

  // ---- Toggle switches ----
  rootEl.querySelectorAll('.toggle').forEach(tog => {
    tog.addEventListener('click', () => tog.classList.toggle('is-on'));
  });

  // ---- Tab switching ----
  const navItems = rootEl.querySelectorAll('.studio__nav li[data-studio-pane]');
  const panes = rootEl.querySelectorAll('.studio-pane[data-studio-pane]');
  const studioHead = rootEl.querySelector('[data-studio-head]');
  navItems.forEach(li => li.addEventListener('click', () => {
    const key = li.dataset.studioPane;
    navItems.forEach(n => n.classList.toggle('is-active', n === li));
    panes.forEach(p => p.style.display = (p.dataset.studioPane === key ? '' : 'none'));
    if (studioHead) studioHead.style.display = (key === 'courses' ? 'none' : '');
    // Render courses grid on first visit
    if (key === 'courses') renderCoursesGrid();
  }));

  // ---- Header: Publish ----
  rootEl.querySelectorAll('.js-studio-publish').forEach(btn => {
    btn.addEventListener('click', () => {
      const orig = btn.innerHTML;
      btn.disabled = true;
      btn.innerHTML = '<span class="material-symbols-outlined" style="font-size:16px; animation:spin 1s linear infinite;">progress_activity</span> Publishing…';
      setTimeout(() => {
        btn.disabled = false;
        btn.innerHTML = orig;
        const status = rootEl.querySelector('#studioStatus');
        if (status) { status.classList.add('is-live'); status.innerHTML = '<span class="dot"></span> Published · all changes live'; }
        showToast('Course published to the May 2026 cohort', 'success');
      }, 900);
    });
  });
  rootEl.querySelectorAll('.js-studio-duplicate').forEach(btn => btn.addEventListener('click', () => showToast('Duplicated course as "' + (COURSES.find(x=>x.id===currentCourseId)||{title:'course'}).title + ' — copy"', 'success')));
  rootEl.querySelectorAll('.js-studio-export').forEach(btn => btn.addEventListener('click', () => showToast('Preparing OLX export — we\'ll email the download link', 'info')));

  // ---- Course switcher ----
  const switcher = rootEl.querySelector('#courseSwitcher');
  const switcherBtn = rootEl.querySelector('#courseSwitcherBtn');
  const switcherSearch = rootEl.querySelector('#courseSwitcherSearch');
  if (switcher && switcherBtn) {
    switcherBtn.addEventListener('click', (e) => {
      e.stopPropagation();
      switcher.classList.toggle('is-open');
      if (switcher.classList.contains('is-open')) {
        renderSwitcherList('');
        if (switcherSearch) { switcherSearch.value = ''; switcherSearch.focus(); }
      }
    });
    document.addEventListener('click', (e) => {
      if (switcher.classList.contains('is-open') && !switcher.contains(e.target)) switcher.classList.remove('is-open');
    });
    if (switcherSearch) switcherSearch.addEventListener('input', () => renderSwitcherList(switcherSearch.value));
    const allBtn = rootEl.querySelector('#courseSwitcherAll');
    if (allBtn) allBtn.addEventListener('click', () => {
      switcher.classList.remove('is-open');
      navItems.forEach(n => n.classList.toggle('is-active', n.dataset.studioPane === 'courses'));
      panes.forEach(p => p.style.display = (p.dataset.studioPane === 'courses' ? '' : 'none'));
      if (studioHead) studioHead.style.display = 'none';
      renderCoursesGrid();
    });
    const newBtn = rootEl.querySelector('#courseSwitcherNew');
    if (newBtn) newBtn.addEventListener('click', () => { switcher.classList.remove('is-open'); showToast('Creating new course — fill in the basics to get started', 'info'); });
  }

  function renderSwitcherList(query) {
    const list = rootEl.querySelector('#courseSwitcherList');
    if (!list) return;
    const q = (query || '').toLowerCase().trim();
    list.innerHTML = '';
    COURSES.filter(c => !q || c.title.toLowerCase().includes(q) || c.code.toLowerCase().includes(q))
      .filter(c => c.status !== 'archived')
      .forEach(c => {
        const row = document.createElement('div');
        row.className = 'course-switcher__item' + (c.id === currentCourseId ? ' is-current' : '');
        row.setAttribute('role', 'option');
        const initials = c.title.split(' ').slice(0, 2).map(w => w[0]).join('').toUpperCase();
        row.innerHTML =
          '<div class="thumb">' + initials + '</div>' +
          '<div style="flex:1; min-width:0;"><strong>' + c.title + '</strong>' +
          '<div class="meta"><span class="status-pill ' + statusClass[c.status] + '">' + statusLabel[c.status] + '</span>' +
          '<span>' + c.code + '</span><span>·</span><span>' + c.modules + ' modules</span>' +
          (c.id === currentCourseId ? '<span>·</span><span style="color:var(--primary); font-weight:600;">Editing now</span>' : '') +
          '</div></div>';
        row.addEventListener('click', () => selectCourseById(c.id));
        list.appendChild(row);
      });
    if (!list.children.length) list.innerHTML = '<div style="padding:20px; text-align:center; color:var(--medium-grey); font-size:13px;">No courses match</div>';
  }

  function selectCourseById(id) {
    const c = COURSES.find(x => x.id === id);
    if (!c) return;
    currentCourseId = id;
    const titleEl = rootEl.querySelector('#courseSwitcherTitle');
    const subEl = rootEl.querySelector('#courseSwitcherSub');
    if (titleEl) titleEl.textContent = c.title;
    if (subEl) subEl.textContent = c.code + ' · Cohort ' + c.cohort + ' · ' + c.modules + ' modules · ' + c.owner;
    // Update stats
    const enrolled = rootEl.querySelector('#statEnrolled');
    const completion = rootEl.querySelector('#statCompletion');
    const rating = rootEl.querySelector('#statRating');
    if (enrolled) enrolled.textContent = c.enrolled ? c.enrolled.toLocaleString() : '—';
    if (completion) completion.textContent = c.completion ? c.completion + '%' : '—';
    if (rating) rating.textContent = c.rating ? '★ ' + c.rating.toFixed(1) : '—';
    // Update status
    const studioStatus = rootEl.querySelector('#studioStatus');
    if (studioStatus) {
      studioStatus.classList.toggle('is-live', c.status === 'published');
      studioStatus.innerHTML = '<span class="dot"></span> ' + statusLabel[c.status] + ' · auto-saved just now';
    }
    if (switcher) switcher.classList.remove('is-open');
    showToast('Now editing: ' + c.title, 'success');
    renderCoursesGrid();
    tryLoadOutline(rootEl, id);
  }

  // ---- Courses grid (My courses pane) ----
  function renderCoursesGrid() {
    const grid = rootEl.querySelector('#coursesGrid');
    if (!grid) return;
    const filterBtn = rootEl.querySelector('.js-courses-filter.is-active');
    const filter = filterBtn ? filterBtn.dataset.coursesFilter : 'all';
    const searchQ = (rootEl.querySelector('#coursesSearch')?.value || '').toLowerCase().trim();
    grid.innerHTML = '';
    const filtered = COURSES.filter(c => {
      if (filter !== 'all' && c.status !== filter) return false;
      if (searchQ && !c.title.toLowerCase().includes(searchQ) && !c.code.toLowerCase().includes(searchQ)) return false;
      return true;
    });
    filtered.forEach(c => {
      const card = document.createElement('div');
      card.className = 'studio-course-card' + (c.id === currentCourseId ? ' is-current' : '');
      const initials = c.title.split(' ').slice(0, 2).map(w => w[0]).join('').toUpperCase();
      card.innerHTML =
        '<div class="studio-course-card__head">' +
          '<div><div class="studio-course-card__title">' + c.title + '</div>' +
          '<div class="studio-course-card__code">' + c.code + ' · ' + c.cohort + '</div></div>' +
          '<button class="studio-course-card__menu-btn" aria-label="More" data-action="menu"><span class="material-symbols-outlined" style="font-size:18px;">more_horiz</span></button>' +
        '</div>' +
        '<div class="studio-course-card__stats">' +
          '<div class="studio-course-card__stat"><strong>' + (c.enrolled ? c.enrolled.toLocaleString() : '—') + '</strong><span>Learners</span></div>' +
          '<div class="studio-course-card__stat"><strong>' + (c.completion ? c.completion + '%' : '—') + '</strong><span>Completion</span></div>' +
          '<div class="studio-course-card__stat"><strong>' + (c.rating ? '★ ' + c.rating.toFixed(1) : '—') + '</strong><span>Rating</span></div>' +
        '</div>' +
        '<div class="studio-course-card__foot">' +
          '<span class="meta"><span class="status-pill ' + statusClass[c.status] + '">' + statusLabel[c.status] + '</span> Updated ' + c.updated + '</span>' +
          '<button class="btn btn--primary btn--sm" data-action="open">' + (c.id === currentCourseId ? 'Currently editing' : 'Open in Studio') + '</button>' +
        '</div>';
      // Wire card actions
      card.querySelector('[data-action="open"]').addEventListener('click', (e) => {
        e.stopPropagation();
        selectCourseById(c.id);
        // Switch to outline pane
        navItems.forEach(n => n.classList.toggle('is-active', n.dataset.studioPane === 'outline'));
        panes.forEach(p => p.style.display = (p.dataset.studioPane === 'outline' ? '' : 'none'));
        if (studioHead) studioHead.style.display = '';
      });
      card.querySelector('[data-action="menu"]').addEventListener('click', (e) => {
        e.stopPropagation();
        openMenuAt(e.currentTarget, [
          { label: 'Open in Studio', icon: 'edit', onClick: () => selectCourseById(c.id) },
          { label: 'Duplicate', icon: 'file_copy', onClick: () => showToast('Duplicated "' + c.title + '"', 'success') },
          { label: 'Export (OLX)', icon: 'download', onClick: () => showToast('Exporting ' + c.code + '…', 'info') },
          { divider: true },
          { label: 'Archive', icon: 'archive', danger: true, onClick: () => showToast(c.title + ' archived', 'warning') },
        ]);
      });
      grid.appendChild(card);
    });
    // New course tile
    const newTile = document.createElement('div');
    newTile.className = 'studio-course-card is-new';
    newTile.innerHTML = '<span class="material-symbols-outlined" style="font-size:36px;">add</span><strong>Create new course</strong>';
    newTile.addEventListener('click', () => showToast('Creating new course — fill in the basics', 'info'));
    grid.appendChild(newTile);
  }

  // Wire course filter buttons
  rootEl.querySelectorAll('.js-courses-filter').forEach(b => b.addEventListener('click', () => {
    rootEl.querySelectorAll('.js-courses-filter').forEach(x => x.classList.toggle('is-active', x === b));
    renderCoursesGrid();
  }));
  const coursesSearchInput = rootEl.querySelector('#coursesSearch');
  if (coursesSearchInput) coursesSearchInput.addEventListener('input', () => renderCoursesGrid());
  const coursesCreateBtn = rootEl.querySelector('#coursesCreateBtn');
  if (coursesCreateBtn) coursesCreateBtn.addEventListener('click', () => showToast('Creating new course — fill in the basics', 'info'));

  // ---- Outline: Expand/Collapse all ----
  const expandBtn = rootEl.querySelector('.js-outline-expand-toggle');
  if (expandBtn) {
    let allOpen = true;
    expandBtn.addEventListener('click', () => {
      allOpen = !allOpen;
      rootEl.querySelectorAll('#outlineColumn .outline-subsection').forEach(sub => sub.classList.toggle('is-collapsed', !allOpen));
      expandBtn.innerHTML = allOpen
        ? '<span class="material-symbols-outlined" style="font-size:16px;">unfold_less</span> Collapse all'
        : '<span class="material-symbols-outlined" style="font-size:16px;">unfold_more</span> Expand all';
    });
  }

  // ---- Outline: Subsection header click toggles collapse ----
  rootEl.querySelectorAll('.outline-subsection__head').forEach(head => {
    head.style.cursor = 'pointer';
    head.addEventListener('click', () => head.closest('.outline-subsection')?.classList.toggle('is-collapsed'));
  });

  // ---- Outline: New section ----
  rootEl.querySelectorAll('.js-outline-new-section').forEach(btn => {
    btn.addEventListener('click', () => {
      const col = rootEl.querySelector('#outlineColumn');
      if (!col) return;
      const section = document.createElement('div');
      section.className = 'outline-section';
      section.innerHTML =
        '<div class="outline-section__head"><h3><span class="material-symbols-outlined drag" style="font-size:18px;">drag_indicator</span> New section</h3>' +
        '<div class="handle-group"><span class="visibility is-draft">Draft</span><button class="btn btn--ghost btn--sm js-section-menu"><span class="material-symbols-outlined" style="font-size:16px;">more_horiz</span></button></div></div>' +
        '<div class="outline-subsection"><div class="outline-subsection__head"><span>Subsection 1</span><span style="font-size:11px; color:var(--medium-grey);">0 units</span></div>' +
        '<button class="add-unit-btn"><span class="material-symbols-outlined" style="font-size:14px;">add</span> Add unit</button></div>';
      col.appendChild(section);
      wireSection(section);
      showToast('New section added — start adding units', 'success');
    });
  });

  // ---- Outline: Wire section interactions ----
  function wireSection(section) {
    // Section menu
    section.querySelectorAll('.js-section-menu').forEach(btn => {
      if (btn.dataset.wired) return;
      btn.dataset.wired = '1';
      btn.addEventListener('click', (e) => {
        e.stopPropagation();
        openMenuAt(btn, [
          { label: 'Rename section', icon: 'edit', onClick: () => showToast('Rename coming up', 'info') },
          { label: 'Duplicate section', icon: 'file_copy', onClick: () => showToast('Section duplicated', 'success') },
          { label: 'Toggle visibility', icon: 'visibility', onClick: () => {
            const vis = section.querySelector('.visibility');
            if (!vis) return;
            if (vis.classList.contains('is-hidden')) { vis.className = 'visibility is-draft'; vis.textContent = 'Draft'; }
            else if (vis.classList.contains('is-draft')) { vis.className = 'visibility'; vis.textContent = 'Published'; }
            else { vis.className = 'visibility is-hidden'; vis.textContent = 'Hidden'; }
            showToast('Visibility updated: ' + vis.textContent, 'info');
          }},
          { divider: true },
          { label: 'Delete section', icon: 'delete', danger: true, onClick: () => {
            if (confirm('Delete this section? Learners will lose access to its units.')) { section.remove(); showToast('Section deleted', 'warning'); }
          }}
        ]);
      });
    });
    // Edit unit buttons
    section.querySelectorAll('.outline-unit .unit-edit, .outline-unit .btn--outline').forEach(btn => {
      if (btn.dataset.wired) return;
      btn.dataset.wired = '1';
      btn.addEventListener('click', (e) => { e.stopPropagation(); openUnitEditor(btn.closest('.outline-unit')); });
    });
    // Add unit buttons
    section.querySelectorAll('.add-unit-btn').forEach(btn => {
      if (btn.dataset.wired) return;
      btn.dataset.wired = '1';
      btn.addEventListener('click', (e) => {
        e.stopPropagation();
        const sub = btn.closest('.outline-subsection');
        const unit = document.createElement('div');
        unit.className = 'outline-unit';
        unit.innerHTML =
          '<div class="type-icon t-doc"><span class="material-symbols-outlined" style="font-size:13px;">description</span></div>' +
          '<span class="unit-title">New unit</span><span class="unit-dur">Untimed</span>' +
          '<button class="btn btn--ghost btn--sm unit-edit"><span class="material-symbols-outlined" style="font-size:14px;">edit</span> Edit</button>';
        sub.insertBefore(unit, btn);
        wireSection(sub.closest('.outline-section'));
        openUnitEditor(unit);
        showToast('Unit added — now editing', 'success');
      });
    });
  }
  rootEl.querySelectorAll('#outlineColumn .outline-section').forEach(wireSection);

  // ---- Unit editor ----
  let activeUnit = null;
  function openUnitEditor(unitEl) {
    if (!unitEl) return;
    rootEl.querySelectorAll('.outline-unit.is-editing').forEach(u => u.classList.remove('is-editing'));
    unitEl.classList.add('is-editing');
    activeUnit = unitEl;
    const title = unitEl.querySelector('.unit-title')?.textContent.trim().replace(/·.*$/, '').trim() || 'Unit';
    const input = rootEl.querySelector('#unitEditorTitleInput');
    if (input) input.value = title;
    const editor = rootEl.querySelector('#unitEditor');
    if (editor) { editor.style.display = ''; editor.scrollIntoView({ behavior: 'smooth', block: 'nearest' }); }
  }
  function closeUnitEditor() {
    const editor = rootEl.querySelector('#unitEditor');
    if (editor) editor.style.display = 'none';
    rootEl.querySelectorAll('.outline-unit.is-editing').forEach(u => u.classList.remove('is-editing'));
    activeUnit = null;
  }
  rootEl.querySelectorAll('.js-unit-editor-close, .js-unit-editor-cancel').forEach(el => el.addEventListener('click', closeUnitEditor));
  const saveUnitBtn = rootEl.querySelector('.js-unit-editor-save');
  if (saveUnitBtn) {
    saveUnitBtn.addEventListener('click', () => {
      const input = rootEl.querySelector('#unitEditorTitleInput');
      if (activeUnit && input) {
        const titleEl = activeUnit.querySelector('.unit-title');
        if (titleEl) titleEl.textContent = input.value || 'Unit';
      }
      showToast('Unit saved · changes auto-published on publish', 'success');
      closeUnitEditor();
    });
  }

  // ---- Xblock picker ----
  rootEl.querySelectorAll('.xblock-picker .xblock-pill').forEach(pill => {
    pill.addEventListener('click', () => {
      rootEl.querySelectorAll('.xblock-picker .xblock-pill').forEach(p => p.classList.remove('is-selected'));
      pill.classList.add('is-selected');
    });
  });

  // ---- Library pane ----
  rootEl.querySelectorAll('.js-lib-new').forEach(btn => btn.addEventListener('click', () => showToast('Created new library — drop in your first xblock', 'success')));
  rootEl.querySelectorAll('.js-lib-search').forEach(btn => btn.addEventListener('click', () => showToast('Showing library search — try "quiz" or "case"', 'info')));
  rootEl.querySelectorAll('.js-lib-open').forEach(btn => btn.addEventListener('click', () => showToast('Opening library preview', 'info')));

  // ---- Files pane ----
  rootEl.querySelectorAll('.js-files-upload').forEach(btn => {
    btn.addEventListener('click', () => {
      const tbody = rootEl.querySelector('#filesBody');
      if (tbody) {
        const tr = document.createElement('tr');
        tr.style.borderTop = '1px solid var(--border)';
        tr.innerHTML = '<td style="padding:14px 16px;">session-notes-apr20.pdf</td><td style="padding:14px 16px;">PDF</td><td style="padding:14px 16px;">242 KB</td><td style="padding:14px 16px;">Just now</td><td style="padding:14px 16px;"><button class="btn btn--ghost btn--sm js-file-menu">•••</button></td>';
        tbody.insertBefore(tr, tbody.firstChild);
        tr.querySelector('.js-file-menu').addEventListener('click', (e) => wireFileMenu(e));
      }
      showToast('Uploaded "session-notes-apr20.pdf"', 'success');
    });
  });
  function wireFileMenu(e) {
    const btn = e.currentTarget;
    e.stopPropagation();
    openMenuAt(btn, [
      { label: 'Rename', icon: 'edit', onClick: () => showToast('Rename coming up', 'info') },
      { label: 'Download', icon: 'download', onClick: () => showToast('Downloading file', 'info') },
      { label: 'Copy link', icon: 'link', onClick: () => showToast('Link copied to clipboard', 'success') },
      { divider: true },
      { label: 'Delete', icon: 'delete', danger: true, onClick: () => { const tr = btn.closest('tr'); if (tr) tr.remove(); showToast('File deleted', 'warning'); } }
    ]);
  }
  rootEl.querySelectorAll('.js-file-menu').forEach(btn => btn.addEventListener('click', wireFileMenu));

  // ---- Schedule ----
  rootEl.querySelectorAll('.js-schedule-save').forEach(btn => btn.addEventListener('click', () => showToast('Schedule saved · learners notified 48h before start', 'success')));

  // ---- Grading: live total + save ----
  (function wireGrading() {
    const inputs = rootEl.querySelectorAll('.js-grade-weight');
    const total = rootEl.querySelector('#gradingTotal');
    const totalVal = rootEl.querySelector('#gradingTotalValue');
    if (!inputs.length || !total || !totalVal) return;
    function recalc() {
      let sum = 0;
      inputs.forEach(i => { sum += parseFloat(i.value) || 0; });
      totalVal.textContent = sum;
      total.classList.toggle('is-invalid', Math.round(sum) !== 100);
      total.style.background = Math.round(sum) !== 100 ? 'rgba(214,69,69,0.08)' : 'var(--surface)';
      total.style.color = Math.round(sum) !== 100 ? '#C23636' : '';
    }
    inputs.forEach(i => i.addEventListener('input', recalc));
    recalc();
    rootEl.querySelectorAll('.js-grading-save').forEach(btn => {
      btn.addEventListener('click', () => {
        if (total.classList.contains('is-invalid')) showToast('Weights must total 100% before saving', 'error');
        else showToast('Grading policy saved', 'success');
      });
    });
  })();

  // ---- Team ----
  rootEl.querySelectorAll('.js-team-invite').forEach(btn => btn.addEventListener('click', () => showToast('Invite sent · email and Slack DM delivered', 'success')));
  rootEl.querySelectorAll('.js-team-menu').forEach(btn => {
    btn.addEventListener('click', (e) => {
      e.stopPropagation();
      const name = btn.closest('tr')?.querySelector('td')?.textContent.trim().split('  ')[0] || 'member';
      openMenuAt(btn, [
        { label: 'Change role', icon: 'swap_horiz', onClick: () => showToast('Role change panel opened', 'info') },
        { label: 'Resend invite', icon: 'outgoing_mail', onClick: () => showToast('Invite re-sent to ' + name, 'success') },
        { divider: true },
        { label: 'Remove from course', icon: 'person_remove', danger: true, onClick: () => { const tr = btn.closest('tr'); if (tr) tr.remove(); showToast(name + ' removed', 'warning'); } }
      ]);
    });
  });

  // ---- Pricing ----
  rootEl.querySelectorAll('.js-promo-edit').forEach(btn => btn.addEventListener('click', () => showToast('Promo code editor opened', 'info')));

  // ---- Submissions: filters + open ----
  const subFilters = rootEl.querySelectorAll('.js-sub-filter');
  const subRows = rootEl.querySelectorAll('[data-studio-pane="submissions"] tbody tr');
  subFilters.forEach(f => f.addEventListener('click', () => {
    const k = f.dataset.subFilter;
    subFilters.forEach(x => { x.classList.toggle('is-active', x === f); x.classList.toggle('btn--primary', x === f); x.classList.toggle('btn--ghost', x !== f); });
    subRows.forEach(r => { const s = r.dataset.subStatus; r.style.display = (k === 'all' || s === k) ? '' : 'none'; });
  }));
  rootEl.querySelectorAll('.js-sub-open').forEach(btn => btn.addEventListener('click', () => {
    const learner = btn.closest('tr')?.querySelector('td')?.textContent.trim() || 'submission';
    showToast('Opening submission from ' + learner, 'info');
  }));

  // ---- Discussions ----
  rootEl.querySelectorAll('.js-disc-pin').forEach(btn => btn.addEventListener('click', () => showToast('Announcement pinned to top of course feed', 'success')));
  rootEl.querySelectorAll('.js-disc-thread').forEach(row => {
    row.addEventListener('click', () => {
      const title = row.querySelector('strong')?.textContent || 'thread';
      showToast('Opening thread: ' + title, 'info');
    });
  });
}
