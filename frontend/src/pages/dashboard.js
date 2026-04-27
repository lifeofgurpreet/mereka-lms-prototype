// Page: Dashboard — ported from prototype screen-dashboard
export async function render(rootEl) {
  rootEl.innerHTML = `
  <main class="dash">
    <div class="dash__hero">
      <div class="avatar-lg">FF</div>
      <div>
        <h1>Welcome back, Faiz</h1>
        <p>You're on a 7-day streak · 3 courses in progress</p>
        <button class="btn btn--discover" onclick="goto('discover')">Discover courses <span class="material-symbols-outlined">arrow_forward</span></button>
      </div>
      <div class="dash__hero-spacer"></div>
    </div>

    <div class="dash__grid">
      <div>
        <div class="section-head"><h2>Continue learning</h2><a href="/continue">View all →</a></div>
        <div class="card continue-card">
          <div class="continue-card__img"><span class="material-symbols-outlined" style="font-size:40px;">play_circle</span></div>
          <div class="continue-card__body">
            <span class="continue-card__cat">Strategy</span>
            <h3>Strategic thinking for modern leaders</h3>
            <p class="continue-card__meta">Module 3 of 5 · Next unit: Frameworks for ambiguity</p>
            <div class="progress"><div class="progress__fill" style="width:60%;"></div></div>
            <div class="continue-card__foot">
              <span class="continue-card__progress-label">60% complete</span>
              <button class="btn btn--primary btn--sm" onclick="goto('unit')">Continue →</button>
            </div>
          </div>
        </div>
        <div class="card continue-card" style="margin-top:16px;">
          <div class="continue-card__img" style="background: linear-gradient(135deg,#237072 0%,#295CAD 100%);"><span class="material-symbols-outlined" style="font-size:40px;">description</span></div>
          <div class="continue-card__body">
            <span class="continue-card__cat">Data</span>
            <h3>Analytics for non-analysts</h3>
            <p class="continue-card__meta">Module 2 of 6 · Next: Reading material — metrics that matter</p>
            <div class="progress"><div class="progress__fill" style="width:30%;"></div></div>
            <div class="continue-card__foot">
              <span class="continue-card__progress-label">30% complete</span>
              <button class="btn btn--primary btn--sm" onclick="goto('unit')">Continue →</button>
            </div>
          </div>
        </div>
      </div>
      <div>
        <div class="section-head"><h3>Upcoming deadlines</h3><a href="/deadlines">All →</a></div>
        <div class="card deadlines">
          <div class="deadline"><div class="deadline__dot is-warn"></div><div class="deadline__body"><div class="deadline__title">Quiz — Market sizing</div><div class="deadline__meta">Due Apr 23 · 15 min</div></div></div>
          <div class="deadline"><div class="deadline__dot"></div><div class="deadline__body"><div class="deadline__title">Reading — OKR principles</div><div class="deadline__meta">Due Apr 25 · 20 min</div></div></div>
          <div class="deadline"><div class="deadline__dot is-err"></div><div class="deadline__body"><div class="deadline__title">Peer review — case study</div><div class="deadline__meta">Due tomorrow</div></div></div>
        </div>
        <div class="section-head" style="margin-top:20px;"><h3>Recent certificates</h3><a href="/certificates">All →</a></div>
        <div class="card" style="padding:0;">
          <div style="display:flex; align-items:center; gap:12px; padding:14px 16px; border-bottom:1px solid var(--border);">
            <div style="width:36px; height:36px; border-radius:50%; background:var(--brand-gradient); color:var(--white); display:flex; align-items:center; justify-content:center; flex-shrink:0;"><span class="material-symbols-outlined" style="font-size:20px;">workspace_premium</span></div>
            <div style="flex:1; min-width:0;"><div style="font-family:var(--font-display); font-weight:600; font-size:13px; line-height:1.2;">Strategic thinking</div><div style="font-size:11px; color:var(--medium-grey); margin-top:2px;">Apr 18, 2026</div></div>
            <button class="btn btn--ghost btn--sm" onclick="goto('certificate')">View</button>
          </div>
          <div style="display:flex; align-items:center; gap:12px; padding:14px 16px;">
            <div style="width:36px; height:36px; border-radius:50%; background:var(--brand-gradient); color:var(--white); display:flex; align-items:center; justify-content:center; flex-shrink:0;"><span class="material-symbols-outlined" style="font-size:20px;">workspace_premium</span></div>
            <div style="flex:1; min-width:0;"><div style="font-family:var(--font-display); font-weight:600; font-size:13px; line-height:1.2;">Analytics for non-analysts</div><div style="font-size:11px; color:var(--medium-grey); margin-top:2px;">Mar 04, 2026</div></div>
            <button class="btn btn--ghost btn--sm" onclick="goto('certificate')">View</button>
          </div>
        </div>
      </div>
    </div>
  </main>`;
}
