/**
 * Admin — E-commerce & Purchase Gateway
 * Manages payment providers, course pricing, coupons, revenue dashboards
 */

export async function render(rootEl) {
  rootEl.innerHTML = `
  <div class="admin-page">
    <header class="admin-page__header">
      <div class="admin-page__title-row">
        <span class="material-symbols-outlined admin-page__icon">payments</span>
        <div>
          <h1 class="admin-page__title">E-commerce & Payments</h1>
          <p class="admin-page__subtitle">Payment providers, course pricing, coupons & revenue</p>
        </div>
      </div>
    </header>

    <!-- KPI Row -->
    <div class="admin-kpi-row">
      <div class="admin-kpi-card">
        <span class="admin-kpi-card__label">Monthly Revenue</span>
        <span class="admin-kpi-card__value">RM 42,850</span>
        <span class="admin-kpi-card__trend is-up">+18% vs last month</span>
      </div>
      <div class="admin-kpi-card">
        <span class="admin-kpi-card__label">Active Subscriptions</span>
        <span class="admin-kpi-card__value">312</span>
        <span class="admin-kpi-card__trend is-up">+24 this week</span>
      </div>
      <div class="admin-kpi-card">
        <span class="admin-kpi-card__label">Conversion Rate</span>
        <span class="admin-kpi-card__value">4.7%</span>
        <span class="admin-kpi-card__trend is-up">+0.3% vs last month</span>
      </div>
      <div class="admin-kpi-card">
        <span class="admin-kpi-card__label">Refund Rate</span>
        <span class="admin-kpi-card__value">1.2%</span>
        <span class="admin-kpi-card__trend is-down">-0.1%</span>
      </div>
    </div>

    <!-- Payment Providers -->
    <section class="admin-section">
      <div class="admin-section__header">
        <h2>Payment Providers</h2>
        <button class="btn btn--sm btn--outline"><span class="material-symbols-outlined">add</span> Add Provider</button>
      </div>
      <div class="admin-card-grid">
        <div class="admin-provider-card is-active">
          <div class="admin-provider-card__header">
            <span class="admin-provider-card__name">Stripe</span>
            <span class="badge badge--success">Active</span>
          </div>
          <div class="admin-provider-card__details">
            <div class="admin-provider-card__row"><span>Mode</span><span>Live</span></div>
            <div class="admin-provider-card__row"><span>Currencies</span><span>MYR, USD, SGD</span></div>
            <div class="admin-provider-card__row"><span>Methods</span><span>Card, FPX, GrabPay</span></div>
            <div class="admin-provider-card__row"><span>Webhook</span><span class="badge badge--success">Connected</span></div>
          </div>
          <div class="admin-provider-card__actions">
            <button class="btn btn--xs btn--ghost">Configure</button>
            <button class="btn btn--xs btn--ghost">Test</button>
          </div>
        </div>
        <div class="admin-provider-card">
          <div class="admin-provider-card__header">
            <span class="admin-provider-card__name">Revenue Monster</span>
            <span class="badge badge--warning">Sandbox</span>
          </div>
          <div class="admin-provider-card__details">
            <div class="admin-provider-card__row"><span>Mode</span><span>Sandbox</span></div>
            <div class="admin-provider-card__row"><span>Currencies</span><span>MYR</span></div>
            <div class="admin-provider-card__row"><span>Methods</span><span>FPX, Boost, TnG</span></div>
            <div class="admin-provider-card__row"><span>Webhook</span><span class="badge badge--neutral">Not set</span></div>
          </div>
          <div class="admin-provider-card__actions">
            <button class="btn btn--xs btn--ghost">Configure</button>
            <button class="btn btn--xs btn--ghost">Go Live</button>
          </div>
        </div>
        <div class="admin-provider-card is-disabled">
          <div class="admin-provider-card__header">
            <span class="admin-provider-card__name">Manual / Bank Transfer</span>
            <span class="badge badge--neutral">Disabled</span>
          </div>
          <div class="admin-provider-card__details">
            <div class="admin-provider-card__row"><span>Account</span><span>Maybank ***4821</span></div>
            <div class="admin-provider-card__row"><span>Verification</span><span>Manual approval</span></div>
          </div>
          <div class="admin-provider-card__actions">
            <button class="btn btn--xs btn--ghost">Enable</button>
          </div>
        </div>
      </div>
    </section>

    <!-- Course Pricing -->
    <section class="admin-section">
      <div class="admin-section__header">
        <h2>Course Pricing</h2>
        <div class="admin-section__actions">
          <button class="btn btn--sm btn--outline">Bulk Update</button>
          <button class="btn btn--sm btn--primary"><span class="material-symbols-outlined">add</span> New Price</button>
        </div>
      </div>
      <div class="admin-table-wrap">
        <table class="admin-table">
          <thead>
            <tr>
              <th>Course</th>
              <th>Price (MYR)</th>
              <th>Price (USD)</th>
              <th>Type</th>
              <th>Enrolled</th>
              <th>Revenue</th>
              <th>Actions</th>
            </tr>
          </thead>
          <tbody>
            <tr>
              <td><strong>Hospitality Management Foundations</strong></td>
              <td>RM 199</td>
              <td>$49</td>
              <td><span class="badge badge--primary">One-time</span></td>
              <td>142</td>
              <td>RM 28,258</td>
              <td><button class="btn btn--xs btn--ghost">Edit</button></td>
            </tr>
            <tr>
              <td><strong>F&B Service Excellence</strong></td>
              <td>RM 149</td>
              <td>$35</td>
              <td><span class="badge badge--primary">One-time</span></td>
              <td>89</td>
              <td>RM 13,261</td>
              <td><button class="btn btn--xs btn--ghost">Edit</button></td>
            </tr>
            <tr>
              <td><strong>Pro Membership (All Access)</strong></td>
              <td>RM 79/mo</td>
              <td>$19/mo</td>
              <td><span class="badge badge--accent">Subscription</span></td>
              <td>312</td>
              <td>RM 24,648/mo</td>
              <td><button class="btn btn--xs btn--ghost">Edit</button></td>
            </tr>
            <tr>
              <td><strong>Kitchen Safety Certification</strong></td>
              <td>Free</td>
              <td>Free</td>
              <td><span class="badge badge--neutral">Free</span></td>
              <td>567</td>
              <td>—</td>
              <td><button class="btn btn--xs btn--ghost">Edit</button></td>
            </tr>
          </tbody>
        </table>
      </div>
    </section>

    <!-- Coupons & Promos -->
    <section class="admin-section">
      <div class="admin-section__header">
        <h2>Coupons & Promotions</h2>
        <button class="btn btn--sm btn--primary"><span class="material-symbols-outlined">add</span> Create Coupon</button>
      </div>
      <div class="admin-table-wrap">
        <table class="admin-table">
          <thead>
            <tr>
              <th>Code</th>
              <th>Discount</th>
              <th>Usage</th>
              <th>Valid Until</th>
              <th>Status</th>
              <th>Actions</th>
            </tr>
          </thead>
          <tbody>
            <tr>
              <td><code>WELCOME50</code></td>
              <td>50% off first course</td>
              <td>234 / 500</td>
              <td>30 Jun 2026</td>
              <td><span class="badge badge--success">Active</span></td>
              <td><button class="btn btn--xs btn--ghost">Edit</button> <button class="btn btn--xs btn--ghost">Disable</button></td>
            </tr>
            <tr>
              <td><code>HOTEL2026</code></td>
              <td>RM 30 off</td>
              <td>45 / 100</td>
              <td>31 May 2026</td>
              <td><span class="badge badge--success">Active</span></td>
              <td><button class="btn btn--xs btn--ghost">Edit</button> <button class="btn btn--xs btn--ghost">Disable</button></td>
            </tr>
            <tr>
              <td><code>EARLYBIRD</code></td>
              <td>25% off</td>
              <td>100 / 100</td>
              <td>15 Apr 2026</td>
              <td><span class="badge badge--neutral">Exhausted</span></td>
              <td><button class="btn btn--xs btn--ghost">Clone</button></td>
            </tr>
          </tbody>
        </table>
      </div>
    </section>

    <!-- Recent Transactions -->
    <section class="admin-section">
      <div class="admin-section__header">
        <h2>Recent Transactions</h2>
        <button class="btn btn--sm btn--outline">Export CSV</button>
      </div>
      <div class="admin-table-wrap">
        <table class="admin-table">
          <thead>
            <tr>
              <th>Date</th>
              <th>Student</th>
              <th>Course</th>
              <th>Amount</th>
              <th>Method</th>
              <th>Status</th>
            </tr>
          </thead>
          <tbody>
            <tr>
              <td>4 May 2026, 14:23</td>
              <td>Ahmad Razak</td>
              <td>Hospitality Management</td>
              <td>RM 199.00</td>
              <td>FPX (Maybank)</td>
              <td><span class="badge badge--success">Paid</span></td>
            </tr>
            <tr>
              <td>4 May 2026, 11:07</td>
              <td>Siti Aminah</td>
              <td>Pro Membership</td>
              <td>RM 79.00</td>
              <td>Card (Visa)</td>
              <td><span class="badge badge--success">Paid</span></td>
            </tr>
            <tr>
              <td>3 May 2026, 22:15</td>
              <td>David Tan</td>
              <td>F&B Service Excellence</td>
              <td>RM 149.00</td>
              <td>GrabPay</td>
              <td><span class="badge badge--success">Paid</span></td>
            </tr>
            <tr>
              <td>3 May 2026, 18:42</td>
              <td>Priya Kumar</td>
              <td>Hospitality Management</td>
              <td>RM 99.50</td>
              <td>FPX (CIMB)</td>
              <td><span class="badge badge--warning">Pending</span></td>
            </tr>
            <tr>
              <td>2 May 2026, 09:30</td>
              <td>James Wong</td>
              <td>Pro Membership</td>
              <td>RM 79.00</td>
              <td>Card (Mastercard)</td>
              <td><span class="badge badge--error">Refunded</span></td>
            </tr>
          </tbody>
        </table>
      </div>
    </section>
  </div>`;
}
