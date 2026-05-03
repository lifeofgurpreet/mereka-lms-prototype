// Page: Admin → Email/Notifications — manage notification templates and pipeline
// Spec: specs/email-notifications-pipeline_spec.md

export async function render(rootEl) {
  rootEl.innerHTML = `
  <main class="admin-page">
    <div class="admin-page__head">
      <div>
        <h1>Notifications & Email</h1>
        <p class="admin-page__sub">Manage notification channels, email templates, and delivery pipeline.</p>
      </div>
      <div class="admin-page__actions">
        <button class="btn btn--outline btn--sm"><span class="material-symbols-outlined" style="font-size:16px;">science</span> Test Send</button>
        <button class="btn btn--primary btn--sm"><span class="material-symbols-outlined" style="font-size:16px;">add</span> New Template</button>
      </div>
    </div>

    <div class="kpi-row">
      <div class="kpi-card"><div class="kpi-card__label">Emails Sent (30d)</div><div class="kpi-card__value">12,847</div><div class="kpi-card__hint">via SendGrid</div></div>
      <div class="kpi-card"><div class="kpi-card__label">Open Rate</div><div class="kpi-card__value">42%</div><div class="kpi-card__hint">↑ 3% vs prev</div></div>
      <div class="kpi-card"><div class="kpi-card__label">Click Rate</div><div class="kpi-card__value">18%</div><div class="kpi-card__hint">industry avg: 12%</div></div>
      <div class="kpi-card"><div class="kpi-card__label">Bounce Rate</div><div class="kpi-card__value">0.4%</div><div class="kpi-card__hint">within threshold</div></div>
    </div>

    <!-- Channels -->
    <section class="admin-section">
      <h2>Delivery Channels</h2>
      <div class="admin-card">
        <div class="toggle-row"><div class="toggle-row__body"><strong>Email (SendGrid)</strong><span>Transactional + digest emails · API key active</span></div><div class="toggle is-on"></div></div>
        <div class="toggle-row"><div class="toggle-row__body"><strong>In-App Notifications</strong><span>Real-time bell notifications within LMS</span></div><div class="toggle is-on"></div></div>
        <div class="toggle-row"><div class="toggle-row__body"><strong>Push (Web)</strong><span>Browser push via Firebase Cloud Messaging</span></div><div class="toggle is-on"></div></div>
        <div class="toggle-row"><div class="toggle-row__body"><strong>Push (Mobile)</strong><span>iOS/Android via APNs + FCM</span></div><div class="toggle"></div></div>
        <div class="toggle-row"><div class="toggle-row__body"><strong>WhatsApp (Respond.io)</strong><span>Deadline reminders via WhatsApp</span></div><div class="toggle"></div></div>
        <div class="toggle-row"><div class="toggle-row__body"><strong>Slack Integration</strong><span>Team notifications to workspace channels</span></div><div class="toggle is-on"></div></div>
      </div>
    </section>

    <!-- Templates -->
    <section class="admin-section">
      <h2>Email Templates</h2>
      <div class="admin-table-wrap">
        <table class="admin-table">
          <thead><tr><th>Template</th><th>Trigger</th><th>Last Sent</th><th>Open Rate</th><th>Status</th><th></th></tr></thead>
          <tbody>
            <tr><td><strong>Welcome Email</strong></td><td>On registration</td><td>2h ago</td><td>68%</td><td><span class="status-badge status-badge--active">Active</span></td><td><button class="btn btn--ghost btn--sm">Edit</button></td></tr>
            <tr><td><strong>Course Enrolled</strong></td><td>On enrollment</td><td>4h ago</td><td>55%</td><td><span class="status-badge status-badge--active">Active</span></td><td><button class="btn btn--ghost btn--sm">Edit</button></td></tr>
            <tr><td><strong>Deadline Reminder (24h)</strong></td><td>24h before due date</td><td>Yesterday</td><td>72%</td><td><span class="status-badge status-badge--active">Active</span></td><td><button class="btn btn--ghost btn--sm">Edit</button></td></tr>
            <tr><td><strong>Weekly Progress Digest</strong></td><td>Every Sunday 9am</td><td>Apr 27</td><td>38%</td><td><span class="status-badge status-badge--active">Active</span></td><td><button class="btn btn--ghost btn--sm">Edit</button></td></tr>
            <tr><td><strong>Certificate Issued</strong></td><td>On course completion</td><td>3d ago</td><td>82%</td><td><span class="status-badge status-badge--active">Active</span></td><td><button class="btn btn--ghost btn--sm">Edit</button></td></tr>
            <tr><td><strong>Re-engagement (7d inactive)</strong></td><td>7 days no activity</td><td>Yesterday</td><td>24%</td><td><span class="status-badge status-badge--draft">Draft</span></td><td><button class="btn btn--ghost btn--sm">Edit</button></td></tr>
            <tr><td><strong>Peer Review Request</strong></td><td>When assigned peer review</td><td>5d ago</td><td>61%</td><td><span class="status-badge status-badge--active">Active</span></td><td><button class="btn btn--ghost btn--sm">Edit</button></td></tr>
          </tbody>
        </table>
      </div>
    </section>

    <!-- Notification Rules -->
    <section class="admin-section">
      <h2>Automation Rules</h2>
      <div class="admin-card">
        <div class="rule-item">
          <div class="rule-item__trigger"><span class="material-symbols-outlined">schedule</span> When learner inactive for 5+ days</div>
          <div class="rule-item__action">→ Send "We miss you" email + push notification</div>
          <span class="status-badge status-badge--active">Active</span>
        </div>
        <div class="rule-item">
          <div class="rule-item__trigger"><span class="material-symbols-outlined">emoji_events</span> When learner completes course</div>
          <div class="rule-item__action">→ Issue certificate email + in-app celebration + LinkedIn share prompt</div>
          <span class="status-badge status-badge--active">Active</span>
        </div>
        <div class="rule-item">
          <div class="rule-item__trigger"><span class="material-symbols-outlined">group</span> When peer review assigned</div>
          <div class="rule-item__action">→ Email + in-app notification with 48h deadline</div>
          <span class="status-badge status-badge--active">Active</span>
        </div>
        <div class="rule-item">
          <div class="rule-item__trigger"><span class="material-symbols-outlined">trending_down</span> When quiz score &lt; 50%</div>
          <div class="rule-item__action">→ Suggest review materials + offer office hours booking</div>
          <span class="status-badge status-badge--draft">Draft</span>
        </div>
      </div>
    </section>
  </main>`;
  rootEl.querySelectorAll('.toggle').forEach(t => t.addEventListener('click', () => t.classList.toggle('is-on')));
}
