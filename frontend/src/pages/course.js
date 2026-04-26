// Page: Course Detail — ported from prototype screen-course
export async function render(rootEl, { params } = {}) {
  const courseId = params?.courseId || '';

  rootEl.innerHTML = `
  <main class="course-detail">
    <div class="course-detail__hero">
      <div class="course-detail__hero-inner">
        <span class="course-detail__cat">Soft skills &amp; employability</span>
        <h1>Freelancing 101</h1>
        <p class="course-detail__sub">Starting a new path in your life can be difficult, and if that path is freelancing, you might find yourself being lost. In this course, you'll be provided with everything you need to know.</p>
        <div class="course-detail__meta-row">
          <span><span class="material-symbols-outlined" style="font-size:16px;">schedule</span> 8 weeks</span>
          <span><span class="material-symbols-outlined" style="font-size:16px;">signal_cellular_alt</span> Beginner</span>
          <span><span class="material-symbols-outlined" style="font-size:16px;">groups</span> Instructor-led</span>
          <span><span class="material-symbols-outlined" style="font-size:16px;">translate</span> EN · ID</span>
        </div>
        <div class="course-detail__actions">
          <button class="btn btn--primary" onclick="goto('checkout')">Enroll now — RM 180</button>
          <button class="btn btn--outline btn--sm js-course-share"><span class="material-symbols-outlined" style="font-size:16px;">share</span> Share</button>
          <button class="btn btn--ghost btn--sm js-course-preview"><span class="material-symbols-outlined" style="font-size:16px;">play_circle</span> Preview</button>
        </div>
      </div>
    </div>

    <div class="course-detail__body">
      <div class="course-detail__main">
        <section class="course-detail__section">
          <h2>What you'll learn</h2>
          <div class="course-detail__outcomes">
            <div class="outcome"><span class="material-symbols-outlined">check_circle</span> Build a personal brand that attracts quality clients</div>
            <div class="outcome"><span class="material-symbols-outlined">check_circle</span> Set up contracts, invoicing, and payment flows</div>
            <div class="outcome"><span class="material-symbols-outlined">check_circle</span> Price your services for sustainable income</div>
            <div class="outcome"><span class="material-symbols-outlined">check_circle</span> Navigate client relationships and scope creep</div>
          </div>
        </section>

        <section class="course-detail__section">
          <h2>Course outline</h2>
          <div class="outline">
            <div class="outline__section">
              <div class="outline__section-head"><span class="material-symbols-outlined">expand_more</span> Module 1 — Getting started</div>
              <div class="outline__units">
                <div class="outline__unit"><span class="material-symbols-outlined" style="font-size:16px;">play_circle</span> Welcome &amp; orientation <span class="outline__dur">12 min</span></div>
                <div class="outline__unit"><span class="material-symbols-outlined" style="font-size:16px;">description</span> The freelance mindset <span class="outline__dur">8 min</span></div>
                <div class="outline__unit"><span class="material-symbols-outlined" style="font-size:16px;">quiz</span> Self-assessment <span class="outline__dur">5 min</span></div>
              </div>
            </div>
            <div class="outline__section">
              <div class="outline__section-head"><span class="material-symbols-outlined">expand_more</span> Module 2 — Personal branding</div>
              <div class="outline__units">
                <div class="outline__unit"><span class="material-symbols-outlined" style="font-size:16px;">play_circle</span> Defining your niche <span class="outline__dur">15 min</span></div>
                <div class="outline__unit"><span class="material-symbols-outlined" style="font-size:16px;">description</span> Portfolio essentials <span class="outline__dur">10 min</span></div>
              </div>
            </div>
            <div class="outline__section">
              <div class="outline__section-head"><span class="material-symbols-outlined">chevron_right</span> Module 3 — Pricing &amp; proposals</div>
            </div>
            <div class="outline__section">
              <div class="outline__section-head"><span class="material-symbols-outlined">chevron_right</span> Module 4 — Client management</div>
            </div>
            <div class="outline__section">
              <div class="outline__section-head"><span class="material-symbols-outlined">chevron_right</span> Module 5 — Scaling your practice</div>
            </div>
          </div>
        </section>
      </div>

      <aside class="course-detail__sidebar">
        <div class="card" style="padding:20px;">
          <h3 style="margin:0 0 12px;">Instructor</h3>
          <div style="display:flex; gap:12px; align-items:center;">
            <div class="avatar">AM</div>
            <div><strong>Aisha M.</strong><br/><span style="font-size:12px; color:var(--medium-grey);">Senior Freelance Consultant</span></div>
          </div>
        </div>
        <div class="card" style="padding:20px; margin-top:16px;">
          <h3 style="margin:0 0 8px;">Includes</h3>
          <div style="font-size:13px; color:var(--dark-grey); display:flex; flex-direction:column; gap:8px;">
            <span><span class="material-symbols-outlined" style="font-size:16px; vertical-align:middle;">play_circle</span> 12 video lessons</span>
            <span><span class="material-symbols-outlined" style="font-size:16px; vertical-align:middle;">description</span> 8 readings</span>
            <span><span class="material-symbols-outlined" style="font-size:16px; vertical-align:middle;">quiz</span> 5 quizzes</span>
            <span><span class="material-symbols-outlined" style="font-size:16px; vertical-align:middle;">workspace_premium</span> Certificate of completion</span>
          </div>
        </div>
      </aside>
    </div>
  </main>`;
}
