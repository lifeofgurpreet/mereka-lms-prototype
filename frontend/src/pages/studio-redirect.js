// Page: Studio — full course authoring UI ported from static prototype
export async function render(rootEl) {
  rootEl.innerHTML = studioHtml();
  wireStudioNav(rootEl);
}

function studioHtml() {
  return `
  <main class="studio">
    ${sidebarHtml()}
    <div class="studio__main">
      ${headerHtml()}
      ${outlinePane()}
      ${coursesPane()}
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
  return `
      <div class="studio__head" data-studio-head>
        <div style="flex:1; min-width:260px;">
          <div style="font-size:11px; color:var(--medium-grey); text-transform:uppercase; letter-spacing:0.04em; margin-bottom:6px;">Now editing</div>
          <h2 style="font-size:20px; margin:0;">Strategic thinking for modern leaders</h2>
          <p style="font-size:12px; color:var(--medium-grey); margin:4px 0 0;">STRAT-101 · Cohort May 2026 · 12 modules · Amira Yusof</p>
        </div>
        <div style="display:flex; gap:8px; align-items:center;">
          <span style="font-size:12px; color:var(--medium-grey);"><span style="display:inline-block; width:6px; height:6px; border-radius:50%; background:var(--success); margin-right:4px;"></span> Auto-saved 8s ago</span>
          <button class="btn btn--outline btn--sm"><span class="material-symbols-outlined" style="font-size:16px;">file_copy</span> Duplicate</button>
          <button class="btn btn--outline btn--sm"><span class="material-symbols-outlined" style="font-size:16px;">download</span> Export</button>
          <button class="btn btn--primary btn--sm"><span class="material-symbols-outlined" style="font-size:16px;">rocket_launch</span> Publish</button>
        </div>
      </div>`;
}

function outlinePane() {
  return `
      <div class="studio-pane" data-studio-pane="outline">
        <div class="studio__stats">
          <div class="studio__stat"><span>Enrolled learners</span><strong>1,208</strong><span class="trend">↑ 42 this week</span></div>
          <div class="studio__stat"><span>Avg. completion</span><strong>67%</strong><span class="trend">↑ 5% vs last cohort</span></div>
          <div class="studio__stat"><span>Avg. quiz score</span><strong>82%</strong><span class="trend" style="color:var(--medium-grey);">— flat</span></div>
          <div class="studio__stat"><span>Course rating</span><strong>★ 4.8</strong><span class="trend">↑ 0.1 vs last cohort</span></div>
        </div>

        <div class="studio__grid">
          <div>
            <div style="display:flex; justify-content:space-between; align-items:center; margin-bottom:14px;">
              <h3 style="font-size:18px;">Course outline</h3>
              <div style="display:flex; gap:6px;">
                <button class="btn btn--ghost btn--sm"><span class="material-symbols-outlined" style="font-size:16px;">unfold_more</span> Expand all</button>
                <button class="btn btn--primary btn--sm"><span class="material-symbols-outlined" style="font-size:16px;">add</span> New section</button>
              </div>
            </div>

            <div class="outline-section">
              <div class="outline-section__head">
                <h3><span class="material-symbols-outlined drag" style="font-size:18px;">drag_indicator</span> Module 1 — Foundations</h3>
                <div class="handle-group"><span class="visibility">Published</span><button class="btn btn--ghost btn--sm"><span class="material-symbols-outlined" style="font-size:16px;">more_horiz</span></button></div>
              </div>
              <div class="outline-subsection">
                <div class="outline-subsection__head"><span>Subsection 1.1 — Welcome &amp; orientation</span><span style="font-size:11px; color:var(--medium-grey);">3 units · 45 min</span></div>
                <div class="outline-unit"><div class="type-icon t-video"><span class="material-symbols-outlined" style="font-size:13px;">play_circle</span></div><span class="unit-title">Welcome &amp; course overview</span><span class="unit-dur">8 min</span><button class="btn btn--ghost btn--sm unit-edit"><span class="material-symbols-outlined" style="font-size:14px;">edit</span> Edit</button></div>
                <div class="outline-unit"><div class="type-icon t-doc"><span class="material-symbols-outlined" style="font-size:13px;">description</span></div><span class="unit-title">What strategy is (and isn't)</span><span class="unit-dur">15 min</span><button class="btn btn--ghost btn--sm unit-edit"><span class="material-symbols-outlined" style="font-size:14px;">edit</span> Edit</button></div>
                <div class="outline-unit"><div class="type-icon t-quiz"><span class="material-symbols-outlined" style="font-size:13px;">quiz</span></div><span class="unit-title">Diagnostic — where are you today</span><span class="unit-dur">10 min · 5 questions</span><button class="btn btn--ghost btn--sm unit-edit"><span class="material-symbols-outlined" style="font-size:14px;">edit</span> Edit</button></div>
                <button class="add-unit-btn"><span class="material-symbols-outlined" style="font-size:14px;">add</span> Add unit</button>
              </div>
            </div>

            <div class="outline-section" style="border: 2px solid var(--primary);">
              <div class="outline-section__head">
                <h3><span class="material-symbols-outlined drag" style="font-size:18px;">drag_indicator</span> Module 3 — Frameworks for ambiguity</h3>
                <div class="handle-group"><span class="visibility is-draft">Draft</span><button class="btn btn--ghost btn--sm"><span class="material-symbols-outlined" style="font-size:16px;">more_horiz</span></button></div>
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
                <div class="handle-group"><span class="visibility is-hidden">Hidden</span><button class="btn btn--ghost btn--sm"><span class="material-symbols-outlined" style="font-size:16px;">more_horiz</span></button></div>
              </div>
            </div>
          </div>

          <aside class="unit-editor">
            <h4><span>Edit unit</span><span class="close material-symbols-outlined" style="cursor:pointer;">close</span></h4>
            <div class="field"><label class="form-label">Unit title</label><input class="form-input" value="Frameworks for ambiguity" /></div>
            <div class="field"><label class="form-label">Content type</label><div class="xblock-picker"><div class="xblock-pill is-selected"><span class="material-symbols-outlined">play_circle</span> Video</div><div class="xblock-pill"><span class="material-symbols-outlined">description</span> Reading</div><div class="xblock-pill"><span class="material-symbols-outlined">quiz</span> Quiz</div><div class="xblock-pill"><span class="material-symbols-outlined">forum</span> Discussion</div><div class="xblock-pill"><span class="material-symbols-outlined">assignment</span> Assignment</div><div class="xblock-pill"><span class="material-symbols-outlined">extension</span> Embed (LTI)</div></div></div>
            <div class="field"><label class="form-label">Video source</label><input class="form-input" placeholder="Paste YouTube, Vimeo, or upload" value="mux://strat-101-m3-u2.mp4" /></div>
            <div style="display:grid; grid-template-columns:1fr 1fr; gap:12px;" class="field"><div><label class="form-label">Est. duration</label><input class="form-input" value="10 min" /></div><div><label class="form-label">Visibility</label><select class="form-input"><option>Published</option><option selected>Draft</option><option>Hidden</option></select></div></div>
            <div class="field"><label class="form-label">Completion rule</label><select class="form-input"><option>Watch ≥ 90%</option><option>Mark as complete (manual)</option><option>Required before next unit</option></select></div>
            <div class="field"><label class="form-label">Instructor notes</label><textarea class="form-input" rows="3">Tighten the 2x2 walkthrough around the 4:20 mark — too slow.</textarea></div>
            <div style="display:flex; gap:8px; margin-top:8px;"><button class="btn btn--outline btn--sm" style="flex:1; justify-content:center;">Cancel</button><button class="btn btn--primary btn--sm" style="flex:1; justify-content:center;">Save unit</button></div>
          </aside>
        </div>
      </div>`;
}

function coursesPane() {
  return `
      <div class="studio-pane" data-studio-pane="courses" style="display:none;">
        <div style="display:flex; justify-content:space-between; align-items:center; margin-bottom:18px;">
          <div><h3 style="font-size:20px; margin-bottom:4px;">My courses</h3><p style="font-size:13px; color:var(--medium-grey); margin:0;">5 courses · 3 published · 1 draft · 1 in review</p></div>
          <button class="btn btn--primary btn--sm"><span class="material-symbols-outlined" style="font-size:16px;">add</span> Create new course</button>
        </div>
        <div style="display:flex; gap:8px; margin-bottom:18px;">
          <button class="btn btn--outline btn--sm is-active">All</button>
          <button class="btn btn--outline btn--sm">Published</button>
          <button class="btn btn--outline btn--sm">Drafts</button>
          <button class="btn btn--outline btn--sm">In review</button>
          <button class="btn btn--outline btn--sm">Archived</button>
        </div>
        <div style="display:grid; grid-template-columns:repeat(auto-fill,minmax(280px,1fr)); gap:14px;">
          <div class="card" style="padding:18px;"><h4 style="margin:0 0 6px;">Strategic thinking for modern leaders</h4><p style="font-size:12px; color:var(--medium-grey); margin:0 0 10px;">STRAT-101 · 1,208 enrolled · <span style="color:var(--success);">Published</span></p><button class="btn btn--outline btn--sm">Edit course</button></div>
          <div class="card" style="padding:18px;"><h4 style="margin:0 0 6px;">Freelancing 101</h4><p style="font-size:12px; color:var(--medium-grey); margin:0 0 10px;">FREE-101 · 842 enrolled · <span style="color:var(--success);">Published</span></p><button class="btn btn--outline btn--sm">Edit course</button></div>
          <div class="card" style="padding:18px;"><h4 style="margin:0 0 6px;">Analytics for non-analysts</h4><p style="font-size:12px; color:var(--medium-grey); margin:0 0 10px;">DATA-201 · 364 enrolled · <span style="color:var(--success);">Published</span></p><button class="btn btn--outline btn--sm">Edit course</button></div>
          <div class="card" style="padding:18px;"><h4 style="margin:0 0 6px;">Leadership in crisis</h4><p style="font-size:12px; color:var(--medium-grey); margin:0 0 10px;">LEAD-301 · Draft · <span style="color:#C88A00;">In review</span></p><button class="btn btn--outline btn--sm">Edit course</button></div>
          <div class="card" style="padding:18px;"><h4 style="margin:0 0 6px;">Southeast Asia market entry</h4><p style="font-size:12px; color:var(--medium-grey); margin:0 0 10px;">SEAM-101 · <span style="color:var(--medium-grey);">Draft</span></p><button class="btn btn--outline btn--sm">Edit course</button></div>
        </div>
      </div>`;
}

function libraryPane() {
  return `
      <div class="studio-pane" data-studio-pane="library" style="display:none;">
        <div style="display:flex; justify-content:space-between; align-items:center; margin-bottom:18px;">
          <div><h3 style="font-size:20px; margin:0;">Content library</h3><p style="color:var(--medium-grey); font-size:13px; margin:2px 0 0;">Reusable xblocks and question banks. Drop them into any unit.</p></div>
          <div style="display:flex; gap:6px;"><button class="btn btn--ghost btn--sm"><span class="material-symbols-outlined" style="font-size:16px;">search</span> Search</button><button class="btn btn--primary btn--sm"><span class="material-symbols-outlined" style="font-size:16px;">add</span> New library</button></div>
        </div>
        <div style="display:grid; grid-template-columns:repeat(auto-fill,minmax(260px,1fr)); gap:14px;">
          <div class="card" style="padding:18px;"><div class="type-icon t-quiz" style="width:36px; height:36px; margin-bottom:10px;"><span class="material-symbols-outlined">quiz</span></div><h4 style="margin:0 0 4px;">Strategy question bank</h4><p style="font-size:13px; color:var(--medium-grey); margin:0 0 10px;">48 questions · last updated Apr 12</p><button class="btn btn--outline btn--sm">Open</button></div>
          <div class="card" style="padding:18px;"><div class="type-icon t-video" style="width:36px; height:36px; margin-bottom:10px;"><span class="material-symbols-outlined">play_circle</span></div><h4 style="margin:0 0 4px;">Shared intro videos</h4><p style="font-size:13px; color:var(--medium-grey); margin:0 0 10px;">12 videos · reusable across cohorts</p><button class="btn btn--outline btn--sm">Open</button></div>
          <div class="card" style="padding:18px;"><div class="type-icon t-doc" style="width:36px; height:36px; margin-bottom:10px;"><span class="material-symbols-outlined">description</span></div><h4 style="margin:0 0 4px;">Case study readings</h4><p style="font-size:13px; color:var(--medium-grey); margin:0 0 10px;">24 readings · 7 translations</p><button class="btn btn--outline btn--sm">Open</button></div>
          <div class="card" style="padding:18px;"><div class="type-icon t-assign" style="width:36px; height:36px; margin-bottom:10px;"><span class="material-symbols-outlined">assignment</span></div><h4 style="margin:0 0 4px;">Peer-review rubrics</h4><p style="font-size:13px; color:var(--medium-grey); margin:0 0 10px;">9 rubrics · ORA-compatible</p><button class="btn btn--outline btn--sm">Open</button></div>
        </div>
      </div>`;
}

function filesPane() {
  return `
      <div class="studio-pane" data-studio-pane="files" style="display:none;">
        <div style="display:flex; justify-content:space-between; align-items:center; margin-bottom:18px;">
          <div><h3 style="font-size:20px; margin:0;">Files &amp; assets</h3><p style="color:var(--medium-grey); font-size:13px; margin:2px 0 0;">Images, PDFs, video masters. 2.4 GB of 10 GB used.</p></div>
          <button class="btn btn--primary btn--sm"><span class="material-symbols-outlined" style="font-size:16px;">upload</span> Upload files</button>
        </div>
        <div class="card" style="padding:0; overflow:hidden;">
          <table style="width:100%; border-collapse:collapse; font-size:14px;">
            <thead><tr style="background:var(--surface); text-align:left;">${thCell('Name')}${thCell('Type')}${thCell('Size')}${thCell('Uploaded')}<th></th></tr></thead>
            <tbody>
              ${fileRow('course-hero.jpg','Image','482 KB','Apr 18')}
              ${fileRow('strat-101-m1-reading.pdf','PDF','1.1 MB','Apr 16')}
              ${fileRow('m3-frameworks-master.mp4','Video','142 MB','Apr 14')}
              ${fileRow('capstone-rubric.docx','Document','68 KB','Apr 10')}
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
          ${dateField('Course start date','2026-05-05')}
          ${dateField('Course end date','2026-07-28')}
          ${dateField('Enrollment deadline','2026-05-03')}
          <div style="margin-bottom:16px;"><label style="font-family:var(--font-display); font-size:12px; text-transform:uppercase; letter-spacing:0.5px; color:var(--dark-grey); display:block; margin-bottom:6px;">Content release</label><select style="width:100%; padding:11px 14px; border:1px solid var(--border); border-radius:10px;"><option>Self-paced · all modules unlocked</option><option selected>Weekly drip · one module per week</option><option>Custom schedule</option></select></div>
          ${toggleRow('Allow late submissions','Accept work after deadlines with 10% penalty',true)}
          <div style="margin-top:16px;"><button class="btn btn--primary btn--sm">Save schedule</button></div>
        </div>
      </div>`;
}

function gradingPane() {
  return `
      <div class="studio-pane" data-studio-pane="grading" style="display:none;">
        <div style="margin-bottom:18px;"><h3 style="font-size:20px; margin:0;">Grading</h3><p style="color:var(--medium-grey); font-size:13px; margin:2px 0 0;">Define how final grades are calculated and what counts as passing.</p></div>
        <div class="card" style="padding:22px;">
          <h4 style="margin:0 0 14px;">Grading weights</h4>
          ${gradeRow('Quizzes',30)}
          ${gradeRow('Peer-reviewed assignments',40)}
          ${gradeRow('Capstone project',25)}
          ${gradeRow('Participation',5)}
          <div style="margin-top:14px; padding:12px 16px; background:var(--surface); border-radius:10px; font-size:14px;"><strong>Total: 100%</strong> · Pass mark set at 70%</div>
          <div style="margin-top:16px;"><button class="btn btn--primary btn--sm">Save grading policy</button></div>
        </div>
      </div>`;
}

function teamPane() {
  return `
      <div class="studio-pane" data-studio-pane="team" style="display:none;">
        <div style="display:flex; justify-content:space-between; align-items:center; margin-bottom:18px;">
          <div><h3 style="font-size:20px; margin:0;">Course team</h3><p style="color:var(--medium-grey); font-size:13px; margin:2px 0 0;">Manage instructors, TAs, and observers.</p></div>
          <button class="btn btn--primary btn--sm"><span class="material-symbols-outlined" style="font-size:16px;">person_add</span> Invite member</button>
        </div>
        <div class="card" style="padding:0; overflow:hidden;">
          <table style="width:100%; border-collapse:collapse; font-size:14px;">
            <thead><tr style="background:var(--surface); text-align:left;">${thCell('Name')}${thCell('Role')}${thCell('Added')}<th></th></tr></thead>
            <tbody>
              ${teamRow('AY','Amira Yusof','Course admin','Jan 12',true)}
              ${teamRow('ML','Mei Lin Tan','Instructor','Jan 15',false)}
              ${teamRow('RP','Raj Patel','Teaching assistant','Feb 02',false)}
              ${teamRow('SK','Sarah Kim','Observer','Mar 08',false)}
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
            ${toggleRow('Enabled','Currently available to all learners',true)}
          </div>
          <div class="card" style="padding:22px;">
            <h4 style="margin:0 0 10px;">Paid track</h4>
            <div style="margin-bottom:12px;"><label style="font-family:var(--font-display); font-size:12px; text-transform:uppercase; letter-spacing:0.5px; color:var(--dark-grey); display:block; margin-bottom:6px;">Price (MYR)</label><input value="249" style="width:100%; padding:11px 14px; border:1px solid var(--border); border-radius:10px;"/></div>
            ${toggleRow('Includes verified certificate','Issued on completion + pass mark',true)}
            ${toggleRow('Financial aid available','Allow learners to apply for reduced price',true)}
          </div>
        </div>
        <div class="card" style="padding:22px; margin-top:14px;">
          <h4 style="margin:0 0 10px;">Promotion codes</h4>
          <div style="display:flex; justify-content:space-between; padding:10px 0; border-bottom:1px solid var(--border); font-size:14px;"><span><code style="background:var(--surface); padding:2px 8px; border-radius:6px;">EARLYBIRD</code> — 30% off · 48 redemptions</span><button class="btn btn--ghost btn--sm">Edit</button></div>
          <div style="display:flex; justify-content:space-between; padding:10px 0; font-size:14px;"><span><code style="background:var(--surface); padding:2px 8px; border-radius:6px;">TEAMSOF10</code> — 20% off · 12 redemptions</span><button class="btn btn--ghost btn--sm">Edit</button></div>
        </div>
      </div>`;
}

function advancedPane() {
  return `
      <div class="studio-pane" data-studio-pane="advanced" style="display:none;">
        <div style="margin-bottom:18px;"><h3 style="font-size:20px; margin:0;">Advanced settings</h3><p style="color:var(--medium-grey); font-size:13px; margin:2px 0 0;">Expert controls. Changes here affect the whole course.</p></div>
        <div class="card" style="padding:22px;">
          ${toggleRow('Enable LTI tool support','Allow embedding external tools (Jupyter, Figma, etc.)',true)}
          ${toggleRow('Open response assessments (ORA)','Peer-reviewed submissions with rubrics',true)}
          ${toggleRow('Proctored exams','Require webcam + ID verification for graded quizzes',false)}
          ${toggleRow('Certificate signatory override','Use a custom signatory instead of default instructor',false)}
          ${toggleRow('Raw HTML blocks','Allow instructors to author raw HTML in units (security review required)',false)}
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
          ${completionBar('Module 1 — Foundations',94,'var(--primary)')}
          ${completionBar('Module 2 — Markets',82,'var(--primary)')}
          ${completionBar('Module 3 — Frameworks',64,'#C23636')}
          ${completionBar('Module 4 — Choosing bets',52,'var(--primary)')}
          ${completionBar('Module 5 — Execution',38,'var(--primary)')}
        </div>
      </div>`;
}

function submissionsPane() {
  return `
      <div class="studio-pane" data-studio-pane="submissions" style="display:none;">
        <div style="display:flex; justify-content:space-between; align-items:center; margin-bottom:18px;">
          <div><h3 style="font-size:20px; margin:0;">Submissions</h3><p style="color:var(--medium-grey); font-size:13px; margin:2px 0 0;">38 pending · 14 awaiting peer review · 2 flagged</p></div>
        </div>
        <div class="card" style="padding:0; overflow:hidden;">
          <table style="width:100%; border-collapse:collapse; font-size:14px;">
            <thead><tr style="background:var(--surface); text-align:left;">${thCell('Learner')}${thCell('Assignment')}${thCell('Status')}${thCell('Submitted')}<th></th></tr></thead>
            <tbody>
              <tr style="border-top:1px solid var(--border);"><td style="padding:14px 16px;">Faiz Fadhillah</td><td style="padding:14px 16px;">Capstone — strategic memo</td><td style="padding:14px 16px;"><span style="color:#C88A00; font-weight:600;">Pending review</span></td><td style="padding:14px 16px;">Apr 19 · 2 days ago</td><td style="padding:14px 16px;"><button class="btn btn--outline btn--sm">Open</button></td></tr>
              <tr style="border-top:1px solid var(--border);"><td style="padding:14px 16px;">Priya Menon</td><td style="padding:14px 16px;">M3 · Knowledge check</td><td style="padding:14px 16px;"><span style="color:var(--primary); font-weight:600;">Peer review (2/3)</span></td><td style="padding:14px 16px;">Apr 18</td><td style="padding:14px 16px;"><button class="btn btn--outline btn--sm">Open</button></td></tr>
              <tr style="border-top:1px solid var(--border);"><td style="padding:14px 16px;">Daniel Wong</td><td style="padding:14px 16px;">Capstone — strategic memo</td><td style="padding:14px 16px;"><span style="color:#237072; font-weight:600;">Graded (88%)</span></td><td style="padding:14px 16px;">Apr 16</td><td style="padding:14px 16px;"><button class="btn btn--ghost btn--sm">View</button></td></tr>
              <tr style="border-top:1px solid var(--border);"><td style="padding:14px 16px;">Alex Bin Ismail</td><td style="padding:14px 16px;">M3 · Discussion</td><td style="padding:14px 16px;"><span style="color:#C23636; font-weight:600;">Flagged · plagiarism</span></td><td style="padding:14px 16px;">Apr 15</td><td style="padding:14px 16px;"><button class="btn btn--outline btn--sm">Review</button></td></tr>
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
          <button class="btn btn--primary btn--sm"><span class="material-symbols-outlined" style="font-size:16px;">campaign</span> Pin announcement</button>
        </div>
        <div class="card" style="padding:0;">
          ${discussionThread('Which 2x2 did you use for your capstone?','48 replies','Module 3 · started by Mei Lin (instructor) · last reply 2h ago')}
          ${discussionThread('Getting stuck on "ambiguity" vs. "uncertainty"','12 replies · 1 unresolved','Module 3 · started by Faiz · last reply 6h ago')}
          ${discussionThread('Malaysia-specific examples?','22 replies','General · started by Priya · last reply yesterday')}
          <div style="padding:18px 22px;"><div style="display:flex; justify-content:space-between; margin-bottom:4px;"><strong style="font-family:var(--font-display);">Capstone peer review slot swaps</strong><span style="font-size:12px; color:var(--medium-grey);">7 replies</span></div><div style="font-size:13px; color:var(--medium-grey);">Module 5 · started by Raj (TA) · last reply Apr 18</div></div>
        </div>
      </div>`;
}

// ---- Helper functions ----

function thCell(label) {
  return `<th style="padding:12px 16px; font-family:var(--font-display); font-weight:600; font-size:12px; text-transform:uppercase; letter-spacing:0.5px; color:var(--dark-grey);">${label}</th>`;
}

function fileRow(name,type,size,date) {
  return `<tr style="border-top:1px solid var(--border);"><td style="padding:14px 16px;">${name}</td><td style="padding:14px 16px;">${type}</td><td style="padding:14px 16px;">${size}</td><td style="padding:14px 16px;">${date}</td><td style="padding:14px 16px;"><button class="btn btn--ghost btn--sm">•••</button></td></tr>`;
}

function dateField(label,value) {
  return `<div style="margin-bottom:16px;"><label style="font-family:var(--font-display); font-size:12px; text-transform:uppercase; letter-spacing:0.5px; color:var(--dark-grey); display:block; margin-bottom:6px;">${label}</label><input type="date" value="${value}" style="width:100%; padding:11px 14px; border:1px solid var(--border); border-radius:10px;"/></div>`;
}

function toggleRow(title,desc,isOn) {
  return `<div style="display:flex; justify-content:space-between; align-items:center; padding:12px 0; border-bottom:1px solid var(--border);"><div style="flex:1;"><strong style="font-size:14px;">${title}</strong><br/><span style="font-size:12px; color:var(--medium-grey);">${desc}</span></div><div class="toggle${isOn ? ' is-on' : ''}" style="width:44px; height:24px; border-radius:12px; background:${isOn ? 'var(--primary)' : 'var(--border)'}; position:relative; cursor:pointer; flex-shrink:0;" onclick="this.classList.toggle('is-on'); this.style.background=this.classList.contains('is-on')?'var(--primary)':'var(--border)';"><div style="width:20px; height:20px; border-radius:50%; background:white; position:absolute; top:2px; transition:left 0.15s; left:${isOn ? '22px' : '2px'};"></div></div></div>`;
}

function gradeRow(label,value) {
  return `<div style="display:grid; grid-template-columns:1fr 100px 1fr; gap:14px; align-items:center; margin-bottom:10px;"><span>${label}</span><input type="number" value="${value}" style="padding:8px 12px; border:1px solid var(--border); border-radius:8px; text-align:right;"/><span style="color:var(--medium-grey);">% of final grade</span></div>`;
}

function teamRow(initials,name,role,date,isOwner) {
  const ownerBadge = isOwner ? ` <span style="font-size:11px; color:var(--primary); background:rgba(171,59,120,0.1); padding:2px 8px; border-radius:var(--r-pill); margin-left:4px;">Owner</span>` : '';
  return `<tr style="border-top:1px solid var(--border);"><td style="padding:14px 16px;"><span style="display:inline-flex; align-items:center; gap:10px;"><span class="avatar" style="width:30px; height:30px; font-size:12px;">${initials}</span> ${name}${ownerBadge}</span></td><td style="padding:14px 16px;">${role}</td><td style="padding:14px 16px;">${date}</td><td style="padding:14px 16px;"><button class="btn btn--ghost btn--sm">•••</button></td></tr>`;
}

function completionBar(label,pct,color) {
  return `<div style="display:flex; align-items:center; gap:12px; margin-bottom:10px;"><span style="width:160px; font-size:13px;">${label}</span><div style="flex:1; height:8px; background:var(--surface); border-radius:4px; overflow:hidden;"><div style="height:100%; width:${pct}%; background:${color};"></div></div><span style="font-size:13px; font-family:var(--font-display); font-weight:600; width:40px; text-align:right;">${pct}%</span></div>`;
}

function discussionThread(title,replies,meta) {
  return `<div style="padding:18px 22px; border-bottom:1px solid var(--border);"><div style="display:flex; justify-content:space-between; margin-bottom:4px;"><strong style="font-family:var(--font-display);">${title}</strong><span style="font-size:12px; color:var(--medium-grey);">${replies}</span></div><div style="font-size:13px; color:var(--medium-grey);">${meta}</div></div>`;
}

// ---- Tab switching ----
function wireStudioNav(rootEl) {
  const navItems = rootEl.querySelectorAll('.studio__nav li[data-studio-pane]');
  const panes = rootEl.querySelectorAll('.studio-pane[data-studio-pane]');
  const studioHead = rootEl.querySelector('[data-studio-head]');

  navItems.forEach(li => {
    li.addEventListener('click', () => {
      const key = li.dataset.studioPane;
      // Toggle active nav
      navItems.forEach(n => n.classList.toggle('is-active', n === li));
      // Show/hide panes
      panes.forEach(p => p.style.display = (p.dataset.studioPane === key) ? '' : 'none');
      // Hide header when viewing "My courses"
      if (studioHead) studioHead.style.display = (key === 'courses') ? 'none' : '';
    });
  });
}
