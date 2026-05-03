// Page: Admin → Proctoring — configure and monitor proctored exams
// Spec: specs/proctoring-integration_spec.md

export async function render(rootEl) {
  rootEl.innerHTML = `
  <main class="admin-page">
    <div class="admin-page__head">
      <div>
        <h1>Proctored Exams</h1>
        <p class="admin-page__sub">Configure exam integrity settings, monitor live sessions, and review flagged attempts.</p>
      </div>
      <div class="admin-page__actions">
        <button class="btn btn--outline btn--sm"><span class="material-symbols-outlined" style="font-size:16px;">settings</span> Provider Settings</button>
        <button class="btn btn--primary btn--sm"><span class="material-symbols-outlined" style="font-size:16px;">add</span> New Proctored Exam</button>
      </div>
    </div>

    <!-- KPI Row -->
    <div class="kpi-row">
      <div class="kpi-card"><div class="kpi-card__label">Active Exams</div><div class="kpi-card__value">12</div><div class="kpi-card__hint">across 4 courses</div></div>
      <div class="kpi-card"><div class="kpi-card__label">Live Sessions</div><div class="kpi-card__value">3</div><div class="kpi-card__hint">in progress now</div></div>
      <div class="kpi-card"><div class="kpi-card__label">Flagged</div><div class="kpi-card__value">7</div><div class="kpi-card__hint">requires review</div></div>
      <div class="kpi-card"><div class="kpi-card__label">Pass Rate</div><div class="kpi-card__value">94%</div><div class="kpi-card__hint">last 30 days</div></div>
    </div>

    <!-- Provider Config -->
    <section class="admin-section">
      <h2>Proctoring Provider</h2>
      <div class="admin-card">
        <div class="toggle-row">
          <div class="toggle-row__body"><strong>Proctorio</strong><span>Browser lockdown + webcam monitoring · API key configured</span></div>
          <div class="toggle is-on"></div>
        </div>
        <div class="toggle-row">
          <div class="toggle-row__body"><strong>ProctorU (RPNow)</strong><span>Live human proctor + AI review · Not configured</span></div>
          <div class="toggle"></div>
        </div>
        <div class="toggle-row">
          <div class="toggle-row__body"><strong>Open edX Native</strong><span>Basic webcam + ID verification · Built-in</span></div>
          <div class="toggle is-on"></div>
        </div>
      </div>
    </section>

    <!-- Exam List -->
    <section class="admin-section">
      <h2>Configured Exams</h2>
      <div class="admin-table-wrap">
        <table class="admin-table">
          <thead><tr><th>Exam</th><th>Course</th><th>Provider</th><th>Duration</th><th>Attempts</th><th>Status</th><th></th></tr></thead>
          <tbody>
            <tr><td><strong>Final Assessment</strong></td><td>Strategic Thinking</td><td>Proctorio</td><td>90 min</td><td>127</td><td><span class="status-badge status-badge--active">Active</span></td><td><button class="btn btn--ghost btn--sm">Edit</button></td></tr>
            <tr><td><strong>Midterm Quiz</strong></td><td>Analytics 101</td><td>Native</td><td>45 min</td><td>89</td><td><span class="status-badge status-badge--active">Active</span></td><td><button class="btn btn--ghost btn--sm">Edit</button></td></tr>
            <tr><td><strong>Certification Exam</strong></td><td>Data Science</td><td>Proctorio</td><td>120 min</td><td>54</td><td><span class="status-badge status-badge--draft">Draft</span></td><td><button class="btn btn--ghost btn--sm">Edit</button></td></tr>
            <tr><td><strong>Module 3 Check</strong></td><td>Design Thinking</td><td>Native</td><td>30 min</td><td>201</td><td><span class="status-badge status-badge--active">Active</span></td><td><button class="btn btn--ghost btn--sm">Edit</button></td></tr>
          </tbody>
        </table>
      </div>
    </section>

    <!-- Flagged Attempts -->
    <section class="admin-section">
      <h2>Flagged Attempts <span class="badge" style="margin-left:8px;">7</span></h2>
      <div class="admin-table-wrap">
        <table class="admin-table">
          <thead><tr><th>Learner</th><th>Exam</th><th>Flag Reason</th><th>Confidence</th><th>Time</th><th></th></tr></thead>
          <tbody>
            <tr><td>Ahmad Rizal</td><td>Final Assessment</td><td><span class="flag-reason">Multiple faces detected</span></td><td>92%</td><td>2h ago</td><td><button class="btn btn--outline btn--sm">Review</button></td></tr>
            <tr><td>Siti Nurhaliza</td><td>Midterm Quiz</td><td><span class="flag-reason">Tab switch (3x)</span></td><td>87%</td><td>5h ago</td><td><button class="btn btn--outline btn--sm">Review</button></td></tr>
            <tr><td>Daniel Wong</td><td>Final Assessment</td><td><span class="flag-reason">Audio anomaly</span></td><td>68%</td><td>1d ago</td><td><button class="btn btn--outline btn--sm">Review</button></td></tr>
            <tr><td>Priya Menon</td><td>Certification Exam</td><td><span class="flag-reason">Missing webcam feed</span></td><td>95%</td><td>1d ago</td><td><button class="btn btn--outline btn--sm">Review</button></td></tr>
          </tbody>
        </table>
      </div>
    </section>

    <!-- Integrity Settings -->
    <section class="admin-section">
      <h2>Integrity Rules</h2>
      <div class="admin-card">
        <div class="toggle-row"><div class="toggle-row__body"><strong>Require webcam</strong><span>Learner must enable camera before starting</span></div><div class="toggle is-on"></div></div>
        <div class="toggle-row"><div class="toggle-row__body"><strong>Require ID verification</strong><span>Photo ID check before exam start</span></div><div class="toggle is-on"></div></div>
        <div class="toggle-row"><div class="toggle-row__body"><strong>Browser lockdown</strong><span>Prevent tab switching, copy/paste, screen sharing</span></div><div class="toggle is-on"></div></div>
        <div class="toggle-row"><div class="toggle-row__body"><strong>AI face matching</strong><span>Verify same person throughout exam</span></div><div class="toggle"></div></div>
        <div class="toggle-row"><div class="toggle-row__body"><strong>Environment scan</strong><span>360° room scan before exam</span></div><div class="toggle"></div></div>
      </div>
    </section>
  </main>`;
  wireToggles(rootEl);
}

function wireToggles(rootEl) {
  rootEl.querySelectorAll('.toggle').forEach(t => t.addEventListener('click', () => t.classList.toggle('is-on')));
}
