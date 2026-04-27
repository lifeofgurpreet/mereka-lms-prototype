// Page: My Learning — enrolled courses, progress, filters
// Uses .mylearning, .ml-card classes from prototype CSS

export async function render(rootEl) {
  rootEl.innerHTML = `
  <main class="mylearning">
    <div class="mylearning__head">
      <div>
        <h1>My Learning</h1>
        <p>Everything you're enrolled in, in one place.</p>
      </div>
      <button class="btn btn--outline" onclick="goto('discover')"><span class="material-symbols-outlined" style="font-size:16px;">add</span> Find a new course</button>
    </div>

    <div class="mylearning__summary">
      <div class="mylearning__stat"><span>Enrolled</span><strong>6</strong><em>2 new this month</em></div>
      <div class="mylearning__stat"><span>In progress</span><strong>3</strong><em>Avg. 47% complete</em></div>
      <div class="mylearning__stat"><span>Completed</span><strong>12</strong><em>8 certificates earned</em></div>
      <div class="mylearning__stat"><span>Hours this month</span><strong>14.5</strong><em>↑ 32% vs last month</em></div>
    </div>

    <div class="mylearning__filters" role="tablist" aria-label="Filter">
      <button class="mylearning__chip is-active" data-filter="all">All <span class="count">(6)</span></button>
      <button class="mylearning__chip" data-filter="progress">In progress <span class="count">(3)</span></button>
      <button class="mylearning__chip" data-filter="completed">Completed <span class="count">(2)</span></button>
      <button class="mylearning__chip" data-filter="bookmarked">Bookmarked <span class="count">(1)</span></button>
    </div>

    <div class="mylearning__grid">
      <!-- Card 1: In progress -->
      <article class="ml-card" data-ml-status="progress">
        <div class="ml-card__thumb">
          <span class="material-symbols-outlined" style="font-size:40px;">play_circle</span>
          <span class="ml-card__status">In progress</span>
        </div>
        <div class="ml-card__body">
          <span class="ml-card__cat">Strategy</span>
          <h3>Strategic thinking for modern leaders</h3>
          <p class="ml-card__meta">Mei Lin Tan · 12 modules · Started Mar 28</p>
          <div style="margin-top:auto;">
            <div class="ml-card__progress-row"><span>60% complete</span><span>Next: Frameworks for ambiguity</span></div>
            <div class="progress"><div class="progress__fill" style="width:60%;"></div></div>
            <div class="ml-card__foot">
              <span style="font-size:12px; color:var(--medium-grey);">Est. 3h remaining</span>
              <button class="btn btn--primary btn--sm" onclick="goto('unit')">Continue →</button>
            </div>
          </div>
        </div>
      </article>

      <!-- Card 2: In progress -->
      <article class="ml-card" data-ml-status="progress">
        <div class="ml-card__thumb t-data">
          <span class="material-symbols-outlined" style="font-size:40px;">bar_chart</span>
          <span class="ml-card__status">In progress</span>
        </div>
        <div class="ml-card__body">
          <span class="ml-card__cat">Data</span>
          <h3>Analytics for non-analysts</h3>
          <p class="ml-card__meta">Priya Menon · 6 modules · Started Apr 02</p>
          <div style="margin-top:auto;">
            <div class="ml-card__progress-row"><span>30% complete</span><span>Next: Metrics that matter</span></div>
            <div class="progress"><div class="progress__fill" style="width:30%;"></div></div>
            <div class="ml-card__foot">
              <span style="font-size:12px; color:var(--medium-grey);">Est. 5h remaining</span>
              <button class="btn btn--primary btn--sm" onclick="goto('unit')">Continue →</button>
            </div>
          </div>
        </div>
      </article>

      <!-- Card 3: In progress -->
      <article class="ml-card" data-ml-status="progress">
        <div class="ml-card__thumb t-design">
          <span class="material-symbols-outlined" style="font-size:40px;">design_services</span>
          <span class="ml-card__status">In progress</span>
        </div>
        <div class="ml-card__body">
          <span class="ml-card__cat">Design</span>
          <h3>Design thinking fundamentals</h3>
          <p class="ml-card__meta">Amira Yusof · 8 modules · Started Apr 10</p>
          <div style="margin-top:auto;">
            <div class="ml-card__progress-row"><span>15% complete</span><span>Next: Empathy interviews</span></div>
            <div class="progress"><div class="progress__fill" style="width:15%;"></div></div>
            <div class="ml-card__foot">
              <span style="font-size:12px; color:var(--medium-grey);">Est. 8h remaining</span>
              <button class="btn btn--primary btn--sm" onclick="goto('unit')">Continue →</button>
            </div>
          </div>
        </div>
      </article>

      <!-- Card 4: Completed -->
      <article class="ml-card" data-ml-status="completed">
        <div class="ml-card__thumb t-people">
          <span class="material-symbols-outlined" style="font-size:40px;">workspace_premium</span>
          <span class="ml-card__status">Completed</span>
        </div>
        <div class="ml-card__body">
          <span class="ml-card__cat">People ops</span>
          <h3>High-performing remote teams</h3>
          <p class="ml-card__meta">Daniel Wong · 10 modules · Completed Apr 18</p>
          <div style="margin-top:auto;">
            <div class="ml-card__progress-row"><span>100% complete</span><span>Score 92%</span></div>
            <div class="progress"><div class="progress__fill" style="width:100%;"></div></div>
            <div class="ml-card__foot">
              <span style="font-size:12px; color:var(--primary); font-weight:600;">Certificate issued</span>
              <button class="btn btn--outline btn--sm" onclick="goto('certificate')">View →</button>
            </div>
          </div>
        </div>
      </article>

      <!-- Card 5: Completed -->
      <article class="ml-card" data-ml-status="completed">
        <div class="ml-card__thumb">
          <span class="material-symbols-outlined" style="font-size:40px;">workspace_premium</span>
          <span class="ml-card__status">Completed</span>
        </div>
        <div class="ml-card__body">
          <span class="ml-card__cat">Strategy</span>
          <h3>OKRs that actually work</h3>
          <p class="ml-card__meta">Raj Patel · 5 modules · Completed Mar 04</p>
          <div style="margin-top:auto;">
            <div class="ml-card__progress-row"><span>100% complete</span><span>Score 88%</span></div>
            <div class="progress"><div class="progress__fill" style="width:100%;"></div></div>
            <div class="ml-card__foot">
              <span style="font-size:12px; color:var(--primary); font-weight:600;">Certificate issued</span>
              <button class="btn btn--outline btn--sm" onclick="goto('certificate')">View →</button>
            </div>
          </div>
        </div>
      </article>

      <!-- Card 6: Bookmarked -->
      <article class="ml-card" data-ml-status="bookmarked">
        <div class="ml-card__thumb t-data">
          <span class="material-symbols-outlined" style="font-size:40px;">trending_up</span>
          <span class="ml-card__status">Not started</span>
        </div>
        <div class="ml-card__body">
          <span class="ml-card__cat">Finance</span>
          <h3>Financial literacy for founders</h3>
          <p class="ml-card__meta">Nadira Ahmad · 7 modules · Bookmarked Apr 15</p>
          <div style="margin-top:auto;">
            <div class="ml-card__progress-row"><span>0% complete</span><span>Starts anytime</span></div>
            <div class="progress"><div class="progress__fill" style="width:0%;"></div></div>
            <div class="ml-card__foot">
              <span style="font-size:12px; color:var(--medium-grey);">Self-paced · 6h</span>
              <button class="btn btn--primary btn--sm" onclick="goto('course')">Start →</button>
            </div>
          </div>
        </div>
      </article>
    </div>
  </main>`;

  wireMyLearning(rootEl);
}

function wireMyLearning(rootEl) {
  const chips = rootEl.querySelectorAll('.mylearning__chip');
  const cards = rootEl.querySelectorAll('.ml-card');

  chips.forEach(chip => {
    chip.addEventListener('click', () => {
      chips.forEach(c => c.classList.remove('is-active'));
      chip.classList.add('is-active');
      const filter = chip.dataset.filter;
      cards.forEach(card => {
        if (filter === 'all') {
          card.style.display = '';
        } else {
          card.style.display = card.dataset.mlStatus === filter ? '' : 'none';
        }
      });
    });
  });
}
