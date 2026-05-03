/**
 * Admin — LTI Tool Configuration
 * Manages LTI 1.3 tool integrations, platform keys, content items
 */

export async function render(rootEl) {
  rootEl.innerHTML = `
  <div class="admin-page">
    <header class="admin-page__header">
      <div class="admin-page__title-row">
        <span class="material-symbols-outlined admin-page__icon">extension</span>
        <div>
          <h1 class="admin-page__title">LTI Tool Integration</h1>
          <p class="admin-page__subtitle">Manage external tool connections via LTI 1.3 / Deep Linking</p>
        </div>
      </div>
    </header>

    <!-- Platform Config -->
    <section class="admin-section">
      <div class="admin-section__header">
        <h2>Platform Configuration</h2>
        <button class="btn btn--sm btn--outline"><span class="material-symbols-outlined">content_copy</span> Copy Config</button>
      </div>
      <div class="admin-config-block">
        <div class="admin-config-block__row">
          <span class="admin-config-block__label">Issuer</span>
          <code class="admin-config-block__value">https://academyv2.mereka.dev</code>
        </div>
        <div class="admin-config-block__row">
          <span class="admin-config-block__label">Authorization URL</span>
          <code class="admin-config-block__value">https://academyv2.mereka.dev/lti/1.3/authorize</code>
        </div>
        <div class="admin-config-block__row">
          <span class="admin-config-block__label">Token URL</span>
          <code class="admin-config-block__value">https://academyv2.mereka.dev/lti/1.3/token</code>
        </div>
        <div class="admin-config-block__row">
          <span class="admin-config-block__label">JWKS URL</span>
          <code class="admin-config-block__value">https://academyv2.mereka.dev/lti/1.3/jwks</code>
        </div>
        <div class="admin-config-block__row">
          <span class="admin-config-block__label">Deployment ID</span>
          <code class="admin-config-block__value">mereka-lms-001</code>
        </div>
      </div>
    </section>

    <!-- Registered Tools -->
    <section class="admin-section">
      <div class="admin-section__header">
        <h2>Registered Tools</h2>
        <button class="btn btn--sm btn--primary"><span class="material-symbols-outlined">add</span> Register Tool</button>
      </div>
      <div class="admin-card-grid">
        <div class="admin-lti-card is-active">
          <div class="admin-lti-card__header">
            <span class="admin-lti-card__icon">🎯</span>
            <div>
              <span class="admin-lti-card__name">Turnitin</span>
              <span class="badge badge--success">Connected</span>
            </div>
          </div>
          <div class="admin-lti-card__details">
            <div class="admin-lti-card__row"><span>Type</span><span>LTI 1.3 + Deep Linking</span></div>
            <div class="admin-lti-card__row"><span>Client ID</span><span><code>tii-mereka-2026</code></span></div>
            <div class="admin-lti-card__row"><span>Scopes</span><span>AGS, NRPS, Deep Linking</span></div>
            <div class="admin-lti-card__row"><span>Courses Using</span><span>8 courses</span></div>
            <div class="admin-lti-card__row"><span>Last Launch</span><span>3 May 2026, 16:45</span></div>
          </div>
          <div class="admin-lti-card__actions">
            <button class="btn btn--xs btn--ghost">Configure</button>
            <button class="btn btn--xs btn--ghost">Test Launch</button>
            <button class="btn btn--xs btn--ghost">Logs</button>
          </div>
        </div>

        <div class="admin-lti-card is-active">
          <div class="admin-lti-card__header">
            <span class="admin-lti-card__icon">📐</span>
            <div>
              <span class="admin-lti-card__name">GeoGebra</span>
              <span class="badge badge--success">Connected</span>
            </div>
          </div>
          <div class="admin-lti-card__details">
            <div class="admin-lti-card__row"><span>Type</span><span>LTI 1.3</span></div>
            <div class="admin-lti-card__row"><span>Client ID</span><span><code>geo-mereka-01</code></span></div>
            <div class="admin-lti-card__row"><span>Scopes</span><span>AGS</span></div>
            <div class="admin-lti-card__row"><span>Courses Using</span><span>3 courses</span></div>
            <div class="admin-lti-card__row"><span>Last Launch</span><span>1 May 2026, 10:12</span></div>
          </div>
          <div class="admin-lti-card__actions">
            <button class="btn btn--xs btn--ghost">Configure</button>
            <button class="btn btn--xs btn--ghost">Test Launch</button>
            <button class="btn btn--xs btn--ghost">Logs</button>
          </div>
        </div>

        <div class="admin-lti-card">
          <div class="admin-lti-card__header">
            <span class="admin-lti-card__icon">🔬</span>
            <div>
              <span class="admin-lti-card__name">Labster</span>
              <span class="badge badge--warning">Pending Setup</span>
            </div>
          </div>
          <div class="admin-lti-card__details">
            <div class="admin-lti-card__row"><span>Type</span><span>LTI 1.3 + Deep Linking</span></div>
            <div class="admin-lti-card__row"><span>Client ID</span><span><code>—</code></span></div>
            <div class="admin-lti-card__row"><span>Scopes</span><span>Not configured</span></div>
            <div class="admin-lti-card__row"><span>Courses Using</span><span>0 courses</span></div>
          </div>
          <div class="admin-lti-card__actions">
            <button class="btn btn--xs btn--primary">Complete Setup</button>
            <button class="btn btn--xs btn--ghost">Remove</button>
          </div>
        </div>

        <div class="admin-lti-card is-active">
          <div class="admin-lti-card__header">
            <span class="admin-lti-card__icon">📹</span>
            <div>
              <span class="admin-lti-card__name">Zoom (Meetings)</span>
              <span class="badge badge--success">Connected</span>
            </div>
          </div>
          <div class="admin-lti-card__details">
            <div class="admin-lti-card__row"><span>Type</span><span>LTI 1.3</span></div>
            <div class="admin-lti-card__row"><span>Client ID</span><span><code>zoom-mereka-lti</code></span></div>
            <div class="admin-lti-card__row"><span>Scopes</span><span>AGS, NRPS</span></div>
            <div class="admin-lti-card__row"><span>Courses Using</span><span>12 courses</span></div>
            <div class="admin-lti-card__row"><span>Last Launch</span><span>4 May 2026, 09:00</span></div>
          </div>
          <div class="admin-lti-card__actions">
            <button class="btn btn--xs btn--ghost">Configure</button>
            <button class="btn btn--xs btn--ghost">Test Launch</button>
            <button class="btn btn--xs btn--ghost">Logs</button>
          </div>
        </div>
      </div>
    </section>

    <!-- Deep Linking Content Items -->
    <section class="admin-section">
      <div class="admin-section__header">
        <h2>Content Items (Deep Linking)</h2>
      </div>
      <div class="admin-table-wrap">
        <table class="admin-table">
          <thead>
            <tr>
              <th>Title</th>
              <th>Tool</th>
              <th>Type</th>
              <th>Used In</th>
              <th>Created</th>
              <th>Actions</th>
            </tr>
          </thead>
          <tbody>
            <tr>
              <td><strong>Plagiarism Check — Final Essay</strong></td>
              <td>Turnitin</td>
              <td>Assignment</td>
              <td>Hospitality Mgmt, F&B Excellence</td>
              <td>12 Apr 2026</td>
              <td><button class="btn btn--xs btn--ghost">Edit</button></td>
            </tr>
            <tr>
              <td><strong>Weekly Zoom Session</strong></td>
              <td>Zoom</td>
              <td>Live Session</td>
              <td>All Pro courses (12)</td>
              <td>1 Mar 2026</td>
              <td><button class="btn btn--xs btn--ghost">Edit</button></td>
            </tr>
            <tr>
              <td><strong>Geometry of Space Design</strong></td>
              <td>GeoGebra</td>
              <td>Interactive</td>
              <td>Interior Design Basics</td>
              <td>20 Mar 2026</td>
              <td><button class="btn btn--xs btn--ghost">Edit</button></td>
            </tr>
          </tbody>
        </table>
      </div>
    </section>

    <!-- Launch Logs -->
    <section class="admin-section">
      <div class="admin-section__header">
        <h2>Recent Launch Logs</h2>
        <button class="btn btn--sm btn--outline">View All Logs</button>
      </div>
      <div class="admin-table-wrap">
        <table class="admin-table">
          <thead>
            <tr>
              <th>Time</th>
              <th>User</th>
              <th>Tool</th>
              <th>Course</th>
              <th>Status</th>
              <th>Duration</th>
            </tr>
          </thead>
          <tbody>
            <tr>
              <td>4 May, 16:45</td>
              <td>student_ahmad</td>
              <td>Turnitin</td>
              <td>Hospitality Mgmt</td>
              <td><span class="badge badge--success">Success</span></td>
              <td>320ms</td>
            </tr>
            <tr>
              <td>4 May, 14:20</td>
              <td>student_siti</td>
              <td>Zoom</td>
              <td>F&B Excellence</td>
              <td><span class="badge badge--success">Success</span></td>
              <td>180ms</td>
            </tr>
            <tr>
              <td>4 May, 11:03</td>
              <td>student_david</td>
              <td>GeoGebra</td>
              <td>Interior Design</td>
              <td><span class="badge badge--success">Success</span></td>
              <td>245ms</td>
            </tr>
            <tr>
              <td>3 May, 22:10</td>
              <td>student_priya</td>
              <td>Labster</td>
              <td>—</td>
              <td><span class="badge badge--error">Failed</span></td>
              <td>—</td>
            </tr>
          </tbody>
        </table>
      </div>
    </section>
  </div>`;
}
