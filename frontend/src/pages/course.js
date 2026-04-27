// Page: Course Detail — uses .course__* classes matching prototype CSS.
// Fetches real course data from API when given a real courseId.
import { getCourse } from '../api/courses.js';
import { navigate } from '../router/router.js';

export async function render(rootEl, { params } = {}) {
  const courseId = params?.courseId || 'demo';
  const isDemo = courseId === 'demo';

  let course = null;
  if (!isDemo) {
    try {
      course = await getCourse(courseId);
    } catch (err) {
      console.warn('[course] fetch failed, using demo shell:', err);
    }
  }

  const name = course?.name || 'Freelancing 101';
  const org = course?.org || 'Soft skills & employability';
  const desc = course?.shortDescription || 'Starting a new path in your life can be difficult, and if that path is freelancing, you might find yourself being lost. In this course, you\'ll be provided with everything you need to know.';
  const pacing = course?.pacing === 'self' ? 'Self-paced' : 'Instructor-led';
  const effort = course?.effort || '8 weeks';
  const imgUrl = course?.image || '';

  const heroStyle = imgUrl
    ? `background-image:linear-gradient(0deg,rgba(26,22,35,0.7) 0%,rgba(26,22,35,0.3) 60%),url('${esc(imgUrl)}'); background-size:cover; background-position:center;`
    : '';

  rootEl.innerHTML = `
  <main style="padding: 24px; max-width: 1200px; margin: 0 auto;">
    <div class="course__hero"${heroStyle ? ` style="${heroStyle}"` : ''}>
      <div class="course__hero-body">
        <p style="font-size:13px; opacity:0.85; margin-bottom:4px;">${esc(org)}</p>
        <h1>${esc(name)}</h1>
        <p>${esc(desc)}</p>
        <div class="course__hero-meta">
          <span><span class="material-symbols-outlined" style="font-size:16px; vertical-align:middle;">schedule</span> ${esc(effort)}</span>
          <span class="dot-sep">·</span>
          <span><span class="material-symbols-outlined" style="font-size:16px; vertical-align:middle;">signal_cellular_alt</span> Beginner</span>
          <span class="dot-sep">·</span>
          <span><span class="material-symbols-outlined" style="font-size:16px; vertical-align:middle;">groups</span> ${esc(pacing)}</span>
          <span class="dot-sep">·</span>
          <span><span class="material-symbols-outlined" style="font-size:16px; vertical-align:middle;">translate</span> EN</span>
        </div>
      </div>
    </div>

    <div style="display:flex; gap:12px; margin-bottom:24px; flex-wrap:wrap;">
      <button class="btn btn--primary" id="enrollBtn"><span class="material-symbols-outlined" style="font-size:18px;">lock</span> Enroll now</button>
      <button class="btn btn--outline btn--sm"><span class="material-symbols-outlined" style="font-size:16px;">share</span> Share</button>
      <button class="btn btn--ghost btn--sm" onclick="history.back()"><span class="material-symbols-outlined" style="font-size:16px;">arrow_back</span> Back</button>
    </div>

    <div class="course__grid">
      <div>
        <section class="course__section">
          <h2>What you'll learn</h2>
          <ul class="course__learn">
            <li>Build a personal brand that attracts quality clients</li>
            <li>Set up contracts, invoicing, and payment flows</li>
            <li>Price your services for sustainable income</li>
            <li>Navigate client relationships and scope creep</li>
          </ul>
        </section>

        <section class="course__section">
          <h2>Course outline</h2>
          <div class="curriculum-module">
            <div class="curriculum-module__head"><h4>Module 1 — Getting started</h4><span>3 units · 25 min</span></div>
            <div class="curriculum-module__list">
              <div class="curriculum-unit"><span class="type-icon t-video"><span class="material-symbols-outlined" style="font-size:16px;">play_circle</span></span><span class="curriculum-unit__title">Welcome &amp; orientation</span><span class="curriculum-unit__dur">12 min</span></div>
              <div class="curriculum-unit"><span class="type-icon t-doc"><span class="material-symbols-outlined" style="font-size:16px;">description</span></span><span class="curriculum-unit__title">The freelance mindset</span><span class="curriculum-unit__dur">8 min</span></div>
              <div class="curriculum-unit"><span class="type-icon t-quiz"><span class="material-symbols-outlined" style="font-size:16px;">quiz</span></span><span class="curriculum-unit__title">Self-assessment</span><span class="curriculum-unit__dur">5 min</span></div>
            </div>
          </div>
          <div class="curriculum-module">
            <div class="curriculum-module__head"><h4>Module 2 — Personal branding</h4><span>2 units · 25 min</span></div>
            <div class="curriculum-module__list">
              <div class="curriculum-unit"><span class="type-icon t-video"><span class="material-symbols-outlined" style="font-size:16px;">play_circle</span></span><span class="curriculum-unit__title">Defining your niche</span><span class="curriculum-unit__dur">15 min</span></div>
              <div class="curriculum-unit"><span class="type-icon t-doc"><span class="material-symbols-outlined" style="font-size:16px;">description</span></span><span class="curriculum-unit__title">Portfolio essentials</span><span class="curriculum-unit__dur">10 min</span></div>
            </div>
          </div>
          <div class="curriculum-module">
            <div class="curriculum-module__head"><h4>Module 3 — Pricing &amp; proposals</h4><span>4 units</span></div>
          </div>
          <div class="curriculum-module">
            <div class="curriculum-module__head"><h4>Module 4 — Client management</h4><span>3 units</span></div>
          </div>
          <div class="curriculum-module">
            <div class="curriculum-module__head"><h4>Module 5 — Scaling your practice</h4><span>3 units</span></div>
          </div>
        </section>
      </div>

      <div class="course__side">
        <div class="card enroll-card">
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
      </div>
    </div>
  </main>`;

  wireEnroll(rootEl, courseId);
}

// Wire the enroll button to navigate with the real courseId
function wireEnroll(rootEl, courseId) {
  const btn = rootEl.querySelector('#enrollBtn');
  if (btn) {
    btn.addEventListener('click', () => {
      navigate('/checkout/' + encodeURIComponent(courseId));
    });
  }
}

function esc(s) { return (s || '').replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/'/g,'&#39;').replace(/"/g,'&quot;'); }
