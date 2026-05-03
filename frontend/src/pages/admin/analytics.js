// Page: Admin → Analytics — learning analytics pipeline dashboard
// Spec: specs/plans/analytics-pipeline_plan.md

export async function render(rootEl) {
  rootEl.innerHTML = `
  <main class="admin-page">
    <div class="admin-page__head">
      <div>
        <h1>Analytics Pipeline</h1>
        <p class="admin-page__sub">Real-time learning analytics, engagement tracking, and outcome measurement.</p>
      </div>
      <div class="admin-page__actions">
        <select class="select-sm" id="dateRange">
          <option value="7d">Last 7 days</option>
          <option value="30d" selected>Last 30 days</option>
          <option value="90d">Last 90 days</option>
          <option value="all">All time</option>
        </select>
        <button class="btn btn--outline btn--sm"><span class="material-symbols-outlined" style="font-size:16px;">download</span> Export</button>
      </div>
    </div>

    <div class="kpi-row">
      <div class="kpi-card"><div class="kpi-card__label">Active Learners</div><div class="kpi-card__value">2,847</div><div class="kpi-card__hint">↑ 14% vs prev period</div></div>
      <div class="kpi-card"><div class="kpi-card__label">Avg. Session</div><div class="kpi-card__value">28 min</div><div class="kpi-card__hint">↑ 3 min</div></div>
      <div class="kpi-card"><div class="kpi-card__label">Completion Rate</div><div class="kpi-card__value">67%</div><div class="kpi-card__hint">↑ 4% vs prev period</div></div>
      <div class="kpi-card"><div class="kpi-card__label">NPS Score</div><div class="kpi-card__value">72</div><div class="kpi-card__hint">Promoters: 78%</div></div>
    </div>

    <!-- Engagement Chart (placeholder) -->
    <section class="admin-section">
      <h2>Engagement Over Time</h2>
      <div class="chart-placeholder">
        <div class="chart-placeholder__bars">
          ${Array.from({length:30}, (_, i) => {
            const h = 20 + Math.random() * 60;
            return `<div class="chart-bar" style="height:${h}%;opacity:${0.5 + (i/30)*0.5};"></div>`;
          }).join('')}
        </div>
        <div class="chart-placeholder__labels"><span>Apr 4</span><span>Apr 11</span><span>Apr 18</span><span>Apr 25</span><span>May 3</span></div>
      </div>
    </section>

    <!-- Course Performance -->
    <section class="admin-section">
      <h2>Course Performance</h2>
      <div class="admin-table-wrap">
        <table class="admin-table">
          <thead><tr><th>Course</th><th>Enrolled</th><th>Active (7d)</th><th>Completion</th><th>Avg Score</th><th>Drop-off Module</th><th>Rating</th></tr></thead>
          <tbody>
            <tr><td><strong>Strategic Thinking</strong></td><td>342</td><td>127</td><td>72%</td><td>84%</td><td>Module 3 (18%)</td><td>★ 4.6</td></tr>
            <tr><td><strong>Analytics for Non-Analysts</strong></td><td>289</td><td>98</td><td>64%</td><td>79%</td><td>Module 4 (22%)</td><td>★ 4.4</td></tr>
            <tr><td><strong>Design Thinking</strong></td><td>201</td><td>76</td><td>58%</td><td>81%</td><td>Module 2 (15%)</td><td>★ 4.7</td></tr>
            <tr><td><strong>Remote Teams</strong></td><td>167</td><td>43</td><td>81%</td><td>88%</td><td>Module 5 (8%)</td><td>★ 4.8</td></tr>
            <tr><td><strong>Freelancing 101</strong></td><td>124</td><td>31</td><td>45%</td><td>72%</td><td>Module 1 (32%)</td><td>★ 3.9</td></tr>
          </tbody>
        </table>
      </div>
    </section>

    <!-- Learning Patterns -->
    <section class="admin-section">
      <h2>Learning Patterns</h2>
      <div class="analytics-grid">
        <div class="admin-card">
          <h3>Peak Study Hours</h3>
          <div class="heatmap-mini">
            <div class="heatmap-row"><span class="heatmap-label">Mon</span>${heatCells()}</div>
            <div class="heatmap-row"><span class="heatmap-label">Tue</span>${heatCells()}</div>
            <div class="heatmap-row"><span class="heatmap-label">Wed</span>${heatCells()}</div>
            <div class="heatmap-row"><span class="heatmap-label">Thu</span>${heatCells()}</div>
            <div class="heatmap-row"><span class="heatmap-label">Fri</span>${heatCells()}</div>
            <div class="heatmap-row"><span class="heatmap-label">Sat</span>${heatCells()}</div>
            <div class="heatmap-row"><span class="heatmap-label">Sun</span>${heatCells()}</div>
          </div>
          <div class="heatmap-legend"><span>6am</span><span>12pm</span><span>6pm</span><span>12am</span></div>
        </div>
        <div class="admin-card">
          <h3>Content Type Engagement</h3>
          <div class="bar-list">
            <div class="bar-list__item"><span class="bar-list__label">Video</span><div class="bar-list__track"><div class="bar-list__fill" style="width:78%;background:var(--video);"></div></div><span class="bar-list__val">78%</span></div>
            <div class="bar-list__item"><span class="bar-list__label">Quiz</span><div class="bar-list__track"><div class="bar-list__fill" style="width:65%;background:var(--quiz);"></div></div><span class="bar-list__val">65%</span></div>
            <div class="bar-list__item"><span class="bar-list__label">Reading</span><div class="bar-list__track"><div class="bar-list__fill" style="width:52%;background:var(--doc);"></div></div><span class="bar-list__val">52%</span></div>
            <div class="bar-list__item"><span class="bar-list__label">Discussion</span><div class="bar-list__track"><div class="bar-list__fill" style="width:41%;background:var(--discuss);"></div></div><span class="bar-list__val">41%</span></div>
            <div class="bar-list__item"><span class="bar-list__label">Assignment</span><div class="bar-list__track"><div class="bar-list__fill" style="width:35%;background:var(--assign);"></div></div><span class="bar-list__val">35%</span></div>
          </div>
        </div>
      </div>
    </section>

    <!-- Pipeline Status -->
    <section class="admin-section">
      <h2>Pipeline Health</h2>
      <div class="admin-card">
        <div class="toggle-row"><div class="toggle-row__body"><strong>Event Tracking (xAPI)</strong><span>Capturing learner interactions → ClickHouse</span></div><span class="status-badge status-badge--active">Healthy</span></div>
        <div class="toggle-row"><div class="toggle-row__body"><strong>ETL Jobs</strong><span>Last run: 15 min ago · Next: in 45 min</span></div><span class="status-badge status-badge--active">Running</span></div>
        <div class="toggle-row"><div class="toggle-row__body"><strong>Aggregation Workers</strong><span>3/3 workers active · Queue depth: 0</span></div><span class="status-badge status-badge--active">Healthy</span></div>
        <div class="toggle-row"><div class="toggle-row__body"><strong>Dashboard Cache</strong><span>Hit rate: 94% · TTL: 5 min</span></div><span class="status-badge status-badge--active">Healthy</span></div>
      </div>
    </section>
  </main>`;
}

function heatCells() {
  return Array.from({length:24}, () => {
    const intensity = Math.random();
    const opacity = intensity < 0.2 ? 0.1 : intensity < 0.5 ? 0.3 : intensity < 0.75 ? 0.6 : 0.9;
    return `<div class="heatmap-cell" style="opacity:${opacity};"></div>`;
  }).join('');
}
