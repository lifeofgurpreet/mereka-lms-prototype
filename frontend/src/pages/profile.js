// Page: Profile — ported from prototype
export async function render(rootEl) {
  rootEl.innerHTML = `
  <main class="profile-page">
    <div class="profile-page__hero">
      <div class="avatar-lg" style="width:80px; height:80px; font-size:28px;">FF</div>
      <div>
        <h1>Faiz Fadhillah</h1>
        <p style="color:var(--medium-grey);">Founder & CEO at Mereka · Kuala Lumpur, Malaysia</p>
        <p style="color:var(--medium-grey); font-size:13px;">Member since Mar 2025 · 3 courses · 2 certificates</p>
      </div>
    </div>
    <div class="profile-page__body" style="max-width:800px; margin:0 auto; padding:32px 40px;">
      <div class="section-head"><h2>Achievements</h2></div>
      <div style="display:flex; gap:16px; flex-wrap:wrap; margin-bottom:32px;">
        <div class="card" style="flex:1; min-width:200px; padding:20px; text-align:center;">
          <span class="material-symbols-outlined" style="font-size:32px; color:var(--primary);">workspace_premium</span>
          <h3 style="margin:8px 0 4px; font-size:14px;">2 Certificates</h3>
          <p style="font-size:12px; color:var(--medium-grey);">Earned across all tracks</p>
        </div>
        <div class="card" style="flex:1; min-width:200px; padding:20px; text-align:center;">
          <span class="material-symbols-outlined" style="font-size:32px; color:var(--accent-teal);">local_fire_department</span>
          <h3 style="margin:8px 0 4px; font-size:14px;">7-Day Streak</h3>
          <p style="font-size:12px; color:var(--medium-grey);">Current learning streak</p>
        </div>
        <div class="card" style="flex:1; min-width:200px; padding:20px; text-align:center;">
          <span class="material-symbols-outlined" style="font-size:32px; color:var(--link);">schedule</span>
          <h3 style="margin:8px 0 4px; font-size:14px;">42 Hours</h3>
          <p style="font-size:12px; color:var(--medium-grey);">Total learning time</p>
        </div>
      </div>
      <div class="section-head"><h2>Recent activity</h2></div>
      <div class="card" style="padding:16px;">
        <p style="margin:0; color:var(--dark-grey); font-size:13px;">Completed <strong>Module 3</strong> of Strategic thinking · 2 hours ago</p>
      </div>
    </div>
  </main>`;
}
