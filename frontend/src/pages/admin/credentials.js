// Page: Admin → Verifiable Credentials — issue and verify blockchain credentials
// Spec: specs/verifiable-credentials-issuer_spec.md

export async function render(rootEl) {
  rootEl.innerHTML = `
  <main class="admin-page">
    <div class="admin-page__head">
      <div>
        <h1>Verifiable Credentials</h1>
        <p class="admin-page__sub">Issue W3C-compliant verifiable credentials, manage DID identities, and track verification requests.</p>
      </div>
      <div class="admin-page__actions">
        <button class="btn btn--outline btn--sm"><span class="material-symbols-outlined" style="font-size:16px;">key</span> DID Settings</button>
        <button class="btn btn--primary btn--sm"><span class="material-symbols-outlined" style="font-size:16px;">verified</span> Issue Credential</button>
      </div>
    </div>

    <div class="kpi-row">
      <div class="kpi-card"><div class="kpi-card__label">Credentials Issued</div><div class="kpi-card__value">1,247</div><div class="kpi-card__hint">all time</div></div>
      <div class="kpi-card"><div class="kpi-card__label">Verified This Month</div><div class="kpi-card__value">89</div><div class="kpi-card__hint">↑ 12% vs last month</div></div>
      <div class="kpi-card"><div class="kpi-card__label">Revoked</div><div class="kpi-card__value">3</div><div class="kpi-card__hint">0.2% revocation rate</div></div>
      <div class="kpi-card"><div class="kpi-card__label">DID Methods</div><div class="kpi-card__value">2</div><div class="kpi-card__hint">did:web, did:key</div></div>
    </div>

    <!-- Issuer Identity -->
    <section class="admin-section">
      <h2>Issuer Identity (DID)</h2>
      <div class="admin-card">
        <div class="did-display">
          <div class="did-display__label">Organization DID</div>
          <code class="did-display__value">did:web:credentials.mereka.dev</code>
          <button class="btn btn--ghost btn--sm">Copy</button>
        </div>
        <div class="did-display" style="margin-top:12px;">
          <div class="did-display__label">Signing Key</div>
          <code class="did-display__value">Ed25519 · Created Jan 15, 2026 · Expires Jan 2028</code>
          <button class="btn btn--ghost btn--sm">Rotate</button>
        </div>
        <div style="margin-top:16px;">
          <div class="toggle-row"><div class="toggle-row__body"><strong>Auto-issue on course completion</strong><span>Automatically issue VC when learner passes all requirements</span></div><div class="toggle is-on"></div></div>
          <div class="toggle-row"><div class="toggle-row__body"><strong>Include transcript data</strong><span>Embed grades and module completion in credential</span></div><div class="toggle is-on"></div></div>
          <div class="toggle-row"><div class="toggle-row__body"><strong>Publish to blockchain</strong><span>Anchor credential hash to Polygon for tamper-proofing</span></div><div class="toggle"></div></div>
        </div>
      </div>
    </section>

    <!-- Credential Templates -->
    <section class="admin-section">
      <h2>Credential Templates</h2>
      <div class="credential-grid">
        <div class="credential-template-card">
          <div class="credential-template-card__icon"><span class="material-symbols-outlined">school</span></div>
          <h3>Course Completion</h3>
          <p>Issued when a learner completes all mandatory units and passes the final assessment.</p>
          <div class="credential-template-card__meta">Schema: OpenBadges v3 · 1,089 issued</div>
          <button class="btn btn--outline btn--sm">Configure</button>
        </div>
        <div class="credential-template-card">
          <div class="credential-template-card__icon"><span class="material-symbols-outlined">workspace_premium</span></div>
          <h3>Professional Certificate</h3>
          <p>Extended credential with skills attestation, valid for employer verification.</p>
          <div class="credential-template-card__meta">Schema: VC-EDU v1 · 158 issued</div>
          <button class="btn btn--outline btn--sm">Configure</button>
        </div>
        <div class="credential-template-card">
          <div class="credential-template-card__icon"><span class="material-symbols-outlined">military_tech</span></div>
          <h3>Skill Badge</h3>
          <p>Micro-credential for individual skill mastery (e.g. "Data Visualization").</p>
          <div class="credential-template-card__meta">Schema: OpenBadges v3 · 0 issued</div>
          <button class="btn btn--outline btn--sm">Configure</button>
        </div>
      </div>
    </section>

    <!-- Recent Issuance -->
    <section class="admin-section">
      <h2>Recent Issuance</h2>
      <div class="admin-table-wrap">
        <table class="admin-table">
          <thead><tr><th>Recipient</th><th>Credential</th><th>Course</th><th>Issued</th><th>Status</th><th></th></tr></thead>
          <tbody>
            <tr><td>Faiz Fadhillah</td><td>Course Completion</td><td>Strategic Thinking</td><td>Apr 18, 2026</td><td><span class="status-badge status-badge--active">Valid</span></td><td><button class="btn btn--ghost btn--sm">View</button></td></tr>
            <tr><td>Priya Menon</td><td>Professional Certificate</td><td>Data Analytics</td><td>Apr 15, 2026</td><td><span class="status-badge status-badge--active">Valid</span></td><td><button class="btn btn--ghost btn--sm">View</button></td></tr>
            <tr><td>Daniel Wong</td><td>Course Completion</td><td>Design Thinking</td><td>Apr 12, 2026</td><td><span class="status-badge status-badge--active">Valid</span></td><td><button class="btn btn--ghost btn--sm">View</button></td></tr>
            <tr><td>Alex Bin Ismail</td><td>Course Completion</td><td>Remote Teams</td><td>Mar 28, 2026</td><td><span class="status-badge status-badge--revoked">Revoked</span></td><td><button class="btn btn--ghost btn--sm">View</button></td></tr>
          </tbody>
        </table>
      </div>
    </section>

    <!-- Verification Log -->
    <section class="admin-section">
      <h2>Verification Requests (last 7 days)</h2>
      <div class="admin-table-wrap">
        <table class="admin-table">
          <thead><tr><th>Verifier</th><th>Credential</th><th>Recipient</th><th>Result</th><th>Time</th></tr></thead>
          <tbody>
            <tr><td>LinkedIn</td><td>Professional Certificate</td><td>Priya Menon</td><td><span class="status-badge status-badge--active">✓ Valid</span></td><td>2h ago</td></tr>
            <tr><td>Grab HR</td><td>Course Completion</td><td>Faiz Fadhillah</td><td><span class="status-badge status-badge--active">✓ Valid</span></td><td>1d ago</td></tr>
            <tr><td>Unknown</td><td>Course Completion</td><td>Alex Bin Ismail</td><td><span class="status-badge status-badge--revoked">✗ Revoked</span></td><td>3d ago</td></tr>
          </tbody>
        </table>
      </div>
    </section>
  </main>`;
  rootEl.querySelectorAll('.toggle').forEach(t => t.addEventListener('click', () => t.classList.toggle('is-on')));
}
