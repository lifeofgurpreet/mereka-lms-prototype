// Page: Admin → Multi-Tenancy — manage sites, tenants, and org isolation
// Spec: specs/multi-tenancy-architecture_spec.md

export async function render(rootEl) {
  rootEl.innerHTML = `
  <main class="admin-page">
    <div class="admin-page__head">
      <div>
        <h1>Multi-Tenancy</h1>
        <p class="admin-page__sub">Manage organizations, branded sites, and data isolation across tenants.</p>
      </div>
      <div class="admin-page__actions">
        <button class="btn btn--primary btn--sm"><span class="material-symbols-outlined" style="font-size:16px;">add</span> Add Tenant</button>
      </div>
    </div>

    <div class="kpi-row">
      <div class="kpi-card"><div class="kpi-card__label">Active Tenants</div><div class="kpi-card__value">4</div><div class="kpi-card__hint">across 3 domains</div></div>
      <div class="kpi-card"><div class="kpi-card__label">Total Learners</div><div class="kpi-card__value">18,420</div><div class="kpi-card__hint">all tenants combined</div></div>
      <div class="kpi-card"><div class="kpi-card__label">Courses</div><div class="kpi-card__value">47</div><div class="kpi-card__hint">12 shared, 35 tenant-specific</div></div>
      <div class="kpi-card"><div class="kpi-card__label">Storage Used</div><div class="kpi-card__value">84 GB</div><div class="kpi-card__hint">of 200 GB quota</div></div>
    </div>

    <!-- Tenant List -->
    <section class="admin-section">
      <h2>Tenants</h2>
      <div class="tenant-grid">
        ${tenantCard('Mereka Academy', 'academyv2.mereka.dev', 'Primary', 12400, 28, true)}
        ${tenantCard('Biji-Biji Academy', 'academy.biji-biji.com', 'Enterprise', 4200, 12, true)}
        ${tenantCard('SEAM Program', 'seam.mereka.dev', 'Program', 1820, 7, true)}
        ${tenantCard('Partner Demo', 'demo.mereka.dev', 'Sandbox', 0, 2, false)}
      </div>
    </section>

    <!-- Site Configuration -->
    <section class="admin-section">
      <h2>Site Configuration</h2>
      <div class="admin-card">
        <div class="toggle-row"><div class="toggle-row__body"><strong>Shared course catalog</strong><span>Courses marked "shared" appear in all tenant catalogs</span></div><div class="toggle is-on"></div></div>
        <div class="toggle-row"><div class="toggle-row__body"><strong>Cross-tenant enrollment</strong><span>Learners can enroll in courses from other tenants</span></div><div class="toggle"></div></div>
        <div class="toggle-row"><div class="toggle-row__body"><strong>Unified SSO</strong><span>Single Authentik realm across all tenants</span></div><div class="toggle is-on"></div></div>
        <div class="toggle-row"><div class="toggle-row__body"><strong>Data isolation (strict)</strong><span>Tenant data never visible to other tenant admins</span></div><div class="toggle is-on"></div></div>
        <div class="toggle-row"><div class="toggle-row__body"><strong>Custom branding per tenant</strong><span>Each tenant can set logo, colors, footer</span></div><div class="toggle is-on"></div></div>
      </div>
    </section>

    <!-- Resource Allocation -->
    <section class="admin-section">
      <h2>Resource Allocation</h2>
      <div class="admin-table-wrap">
        <table class="admin-table">
          <thead><tr><th>Tenant</th><th>Storage</th><th>Bandwidth</th><th>API Calls (30d)</th><th>Video Hours</th><th>Plan</th></tr></thead>
          <tbody>
            <tr><td><strong>Mereka Academy</strong></td><td>52 GB / 100 GB</td><td>1.2 TB / 5 TB</td><td>2.4M</td><td>180h</td><td>Enterprise</td></tr>
            <tr><td><strong>Biji-Biji</strong></td><td>24 GB / 50 GB</td><td>480 GB / 2 TB</td><td>890K</td><td>65h</td><td>Enterprise</td></tr>
            <tr><td><strong>SEAM</strong></td><td>8 GB / 25 GB</td><td>120 GB / 1 TB</td><td>340K</td><td>28h</td><td>Standard</td></tr>
            <tr><td><strong>Demo</strong></td><td>0.1 GB / 5 GB</td><td>2 GB / 50 GB</td><td>1.2K</td><td>0h</td><td>Free</td></tr>
          </tbody>
        </table>
      </div>
    </section>
  </main>`;
  rootEl.querySelectorAll('.toggle').forEach(t => t.addEventListener('click', () => t.classList.toggle('is-on')));
}

function tenantCard(name, domain, tier, learners, courses, active) {
  return `
  <div class="tenant-card ${active ? '' : 'tenant-card--inactive'}">
    <div class="tenant-card__header">
      <h3>${name}</h3>
      <span class="status-badge ${active ? 'status-badge--active' : 'status-badge--draft'}">${active ? 'Active' : 'Inactive'}</span>
    </div>
    <div class="tenant-card__domain"><span class="material-symbols-outlined" style="font-size:14px;">language</span> ${domain}</div>
    <div class="tenant-card__stats">
      <div><strong>${learners.toLocaleString()}</strong> learners</div>
      <div><strong>${courses}</strong> courses</div>
      <div class="tenant-card__tier">${tier}</div>
    </div>
    <div class="tenant-card__foot">
      <button class="btn btn--ghost btn--sm">Configure</button>
      <button class="btn btn--ghost btn--sm">Branding</button>
    </div>
  </div>`;
}
