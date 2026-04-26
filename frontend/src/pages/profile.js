// Page: Profile — ported from static prototype with full layout
export async function render(rootEl) {
  rootEl.innerHTML = `
  <main class="profile">
    <div class="profile__head">
      <div class="profile__banner">
        <div class="profile__banner-actions">
          <button class="btn btn--ghost btn--sm"><span class="material-symbols-outlined" style="font-size:16px;">share</span> Share</button>
          <a href="/settings" class="btn btn--outline btn--sm"><span class="material-symbols-outlined" style="font-size:16px;">edit</span> Edit profile</a>
        </div>
      </div>
      <div class="profile__head-body">
        <div class="profile__avatar">FF</div>
        <div class="profile__info">
          <h1>Faiz Fadhillah</h1>
          <div class="role">Founder &amp; CEO · Mereka</div>
          <div class="meta-row">
            <span><span class="material-symbols-outlined" style="font-size:16px;">location_on</span> Kuala Lumpur, MY</span>
            <span><span class="material-symbols-outlined" style="font-size:16px;">calendar_today</span> Joined Jan 2024</span>
            <span><span class="material-symbols-outlined" style="font-size:16px;">local_fire_department</span> 7-day streak</span>
          </div>
        </div>
      </div>
      <div class="profile__stats-strip">
        <div class="profile__stat"><strong>12</strong><span>Courses completed</span></div>
        <div class="profile__stat"><strong>3</strong><span>In progress</span></div>
        <div class="profile__stat"><strong>8</strong><span>Certificates</span></div>
        <div class="profile__stat"><strong>98</strong><span>Hours learned</span></div>
      </div>
    </div>

    <div class="profile__grid">
      <div>
        <section class="profile__section">
          <h3>Recent certificates</h3>
          <div class="card" style="padding:18px; display:flex; gap:14px; align-items:center;">
            <div style="width:52px; height:52px; border-radius:50%; background:var(--brand-gradient); color:var(--white); display:flex; align-items:center; justify-content:center; flex-shrink:0;"><span class="material-symbols-outlined">workspace_premium</span></div>
            <div style="flex:1;"><h4 style="margin:0;">Strategic thinking for modern leaders</h4><p style="color:var(--medium-grey); font-size:13px; margin:2px 0 0;">Issued Apr 18, 2026 · Credential MRK-2026-48291</p></div>
            <a href="/certificate/demo" class="btn btn--primary btn--sm">View</a>
          </div>
          <div class="card" style="padding:18px; display:flex; gap:14px; align-items:center; margin-top:10px;">
            <div style="width:52px; height:52px; border-radius:50%; background:var(--brand-gradient); color:var(--white); display:flex; align-items:center; justify-content:center; flex-shrink:0;"><span class="material-symbols-outlined">workspace_premium</span></div>
            <div style="flex:1;"><h4 style="margin:0;">Analytics for non-analysts</h4><p style="color:var(--medium-grey); font-size:13px; margin:2px 0 0;">Issued Mar 04, 2026 · Credential MRK-2026-39814</p></div>
            <button class="btn btn--outline btn--sm">View</button>
          </div>
          <div class="card" style="padding:18px; display:flex; gap:14px; align-items:center; margin-top:10px;">
            <div style="width:52px; height:52px; border-radius:50%; background:var(--brand-gradient); color:var(--white); display:flex; align-items:center; justify-content:center; flex-shrink:0;"><span class="material-symbols-outlined">workspace_premium</span></div>
            <div style="flex:1;"><h4 style="margin:0;">High-performing remote teams</h4><p style="color:var(--medium-grey); font-size:13px; margin:2px 0 0;">Issued Apr 18, 2026 · Credential MRK-2026-48290</p></div>
            <button class="btn btn--outline btn--sm">View</button>
          </div>
        </section>

        <section class="profile__section">
          <h3>Learning activity</h3>
          <div class="card" style="padding:24px;">
            <div style="display:flex; justify-content:space-between; align-items:center; margin-bottom:14px;">
              <div>
                <strong style="font-family:var(--font-display); font-size:18px;">98 units completed</strong>
                <div style="font-size:13px; color:var(--medium-grey);">in the last 14 weeks</div>
              </div>
              <select style="width:auto; padding:6px 12px; font-size:13px; border:1px solid var(--border); border-radius:var(--r-pill); background:var(--white);">
                <option>Last 14 weeks</option><option>Last 26 weeks</option><option>Last year</option>
              </select>
            </div>
            <div id="heatmap-target" class="heatmap-grid"></div>
            <div class="heatmap-legend">
              <span>Less</span>
              <span class="heatmap-cell"></span><span class="heatmap-cell l1"></span><span class="heatmap-cell l2"></span><span class="heatmap-cell l3"></span><span class="heatmap-cell l4"></span>
              <span>More</span>
              <span style="margin-left:auto; font-size:12px;">14 weeks ago → today</span>
            </div>
          </div>
        </section>

        <section class="profile__section">
          <h3>Skills &amp; interests</h3>
          <div class="card" style="padding:20px;">
            <div style="display:flex; flex-wrap:wrap; gap:8px;">
              <span class="chip chip--tag is-strategy">Strategy</span>
              <span class="chip chip--tag is-data">Data analytics</span>
              <span class="chip chip--tag is-design">Design thinking</span>
              <span class="chip chip--tag is-people">People ops</span>
              <span class="chip chip--tag">OKRs</span>
              <span class="chip chip--tag">Product management</span>
              <span class="chip chip--tag">Remote work</span>
            </div>
          </div>
        </section>
      </div>

      <aside>
        <section class="profile__section">
          <h3>Upcoming sessions</h3>
          <div class="card" style="padding:0;">
            <div style="display:flex; gap:12px; padding:14px 16px; border-bottom:1px solid var(--border);">
              <div style="flex:0 0 44px; text-align:center;"><div style="font-family:var(--font-display); font-weight:700; font-size:18px; color:var(--primary); line-height:1;">23</div><div style="font-size:10px; color:var(--medium-grey); text-transform:uppercase; letter-spacing:0.5px; margin-top:2px;">Apr</div></div>
              <div style="flex:1; min-width:0;"><div style="font-family:var(--font-display); font-weight:600; font-size:14px; line-height:1.2;">Facilitation masterclass</div><div style="font-size:12px; color:var(--medium-grey); margin-top:2px;">10:00 — 11:30 MYT · with Shu Lin</div></div>
            </div>
            <div style="display:flex; gap:12px; padding:14px 16px; border-bottom:1px solid var(--border);">
              <div style="flex:0 0 44px; text-align:center;"><div style="font-family:var(--font-display); font-weight:700; font-size:18px; color:var(--primary); line-height:1;">29</div><div style="font-size:10px; color:var(--medium-grey); text-transform:uppercase; letter-spacing:0.5px; margin-top:2px;">Apr</div></div>
              <div style="flex:1; min-width:0;"><div style="font-family:var(--font-display); font-weight:600; font-size:14px; line-height:1.2;">Strategy cohort — week 4</div><div style="font-size:12px; color:var(--medium-grey); margin-top:2px;">19:00 — 20:30 MYT · with Amira</div></div>
            </div>
            <div style="display:flex; gap:12px; padding:14px 16px;">
              <div style="flex:0 0 44px; text-align:center;"><div style="font-family:var(--font-display); font-weight:700; font-size:18px; color:var(--primary); line-height:1;">05</div><div style="font-size:10px; color:var(--medium-grey); text-transform:uppercase; letter-spacing:0.5px; margin-top:2px;">May</div></div>
              <div style="flex:1; min-width:0;"><div style="font-family:var(--font-display); font-weight:600; font-size:14px; line-height:1.2;">Office hours — Data analytics</div><div style="font-size:12px; color:var(--medium-grey); margin-top:2px;">14:00 — 15:00 MYT · with Priya</div></div>
            </div>
          </div>
        </section>

        <section class="profile__section">
          <h3>Following</h3>
          <div class="card" style="padding:16px;">
            <div style="display:flex; align-items:center; gap:12px; padding:8px 0; border-bottom:1px solid var(--border);">
              <div class="avatar" style="width:36px; height:36px; font-size:13px;">ML</div>
              <div style="flex:1;"><strong style="font-family:var(--font-display); font-size:14px;">Mei Lin Tan</strong><div style="font-size:12px; color:var(--medium-grey);">Strategy instructor</div></div>
              <button class="btn btn--ghost btn--sm">Following</button>
            </div>
            <div style="display:flex; align-items:center; gap:12px; padding:8px 0; border-bottom:1px solid var(--border);">
              <div class="avatar" style="width:36px; height:36px; font-size:13px;">AY</div>
              <div style="flex:1;"><strong style="font-family:var(--font-display); font-size:14px;">Amira Yusof</strong><div style="font-size:12px; color:var(--medium-grey);">Design thinking</div></div>
              <button class="btn btn--ghost btn--sm">Following</button>
            </div>
            <div style="display:flex; align-items:center; gap:12px; padding:8px 0;">
              <div class="avatar" style="width:36px; height:36px; font-size:13px;">PM</div>
              <div style="flex:1;"><strong style="font-family:var(--font-display); font-size:14px;">Priya Menon</strong><div style="font-size:12px; color:var(--medium-grey);">Data analytics</div></div>
              <button class="btn btn--ghost btn--sm">Following</button>
            </div>
          </div>
        </section>
      </aside>
    </div>
  </main>`;

  // Generate heatmap
  const target = rootEl.querySelector('#heatmap-target');
  if (target) {
    const levels = ['', 'l1', 'l2', 'l3', 'l4'];
    let html = '';
    for (let i = 0; i < 98; i++) {
      const lvl = levels[Math.floor(Math.random() * 5)];
      html += '<span class="heatmap-cell ' + lvl + '"></span>';
    }
    target.innerHTML = html;
  }
}
