// Page: My Learning — ported from prototype
export async function render(rootEl) {
  rootEl.innerHTML = `
  <main class="mylearn">
    <div class="mylearn__head">
      <h1>My Learning</h1>
      <div class="mylearn__tabs">
        <button class="btn btn--primary btn--sm">In progress</button>
        <button class="btn btn--outline btn--sm">Completed</button>
        <button class="btn btn--outline btn--sm">Wishlist</button>
      </div>
    </div>

    <div class="mylearn__grid">
      <div class="card continue-card">
        <div class="continue-card__img"><span class="material-symbols-outlined" style="font-size:40px;">play_circle</span></div>
        <div class="continue-card__body">
          <span class="continue-card__cat">Strategy</span>
          <h3>Strategic thinking for modern leaders</h3>
          <p class="continue-card__meta">Module 3 of 5 · Last accessed 2 hours ago</p>
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
          <p class="continue-card__meta">Module 2 of 6 · Last accessed yesterday</p>
          <div class="progress"><div class="progress__fill" style="width:30%;"></div></div>
          <div class="continue-card__foot">
            <span class="continue-card__progress-label">30% complete</span>
            <button class="btn btn--primary btn--sm" onclick="goto('unit')">Continue →</button>
          </div>
        </div>
      </div>

      <div class="card continue-card" style="margin-top:16px;">
        <div class="continue-card__img" style="background: linear-gradient(135deg,#AB3B78 0%,#8F2F65 100%);"><span class="material-symbols-outlined" style="font-size:40px;">rocket_launch</span></div>
        <div class="continue-card__body">
          <span class="continue-card__cat">Freelancing</span>
          <h3>Freelancing 101</h3>
          <p class="continue-card__meta">Module 1 of 5 · Just started</p>
          <div class="progress"><div class="progress__fill" style="width:10%;"></div></div>
          <div class="continue-card__foot">
            <span class="continue-card__progress-label">10% complete</span>
            <button class="btn btn--primary btn--sm" onclick="goto('unit')">Continue →</button>
          </div>
        </div>
      </div>
    </div>
  </main>`;
}
