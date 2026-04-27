// Page: Enrollment Success — confirmation after checkout
// Shows course card, next steps, and CTA to start learning

import { listCourses } from '../api/courses.js';

export async function render(rootEl, { params } = {}) {
  const courseId = params?.courseId || 'demo';

  // Try to load real course data
  let course = null;
  if (courseId !== 'demo') {
    try {
      const { courses } = await listCourses({ pageSize: 50 });
      course = courses.find(c => c.courseId === courseId || c.id === courseId);
    } catch (e) { console.warn('[enrollment-success] course fetch failed:', e); }
  }

  const name = course?.name || 'Strategic thinking for modern leaders';
  const org = course?.org || 'MEREKA';
  const start = course?.startDisplay || (course?.start ? new Date(course.start).toLocaleDateString('en-MY', { month:'short', day:'numeric', year:'numeric' }) : 'May 5, 2026');
  const image = course?.image || null;

  rootEl.innerHTML = `
  <style>@keyframes successPop { 0% { transform:scale(0.5); opacity:0; } 60% { transform:scale(1.15); } 100% { transform:scale(1); opacity:1; } }</style>
  <main class="success-wrap">
    <div class="success-check" style="animation:successPop 0.5s ease-out;"><span class="material-symbols-outlined">check</span></div>
    <h1>You're enrolled!</h1>
    <p>Payment received. A receipt has been sent to <strong>faiz.fadhillah@gmail.com</strong>.</p>

    <div class="success-card">
      <div class="success-card__thumb">${image ? '<img src="' + image + '" alt="" style="width:100%; height:100%; object-fit:cover; border-radius:10px;" />' : '<span class="material-symbols-outlined">insights</span>'}</div>
      <div>
        <p class="success-card__title">${esc(name)}</p>
        <span class="success-card__meta">${esc(org)} · Cohort starts ${esc(start)} · Certificate on completion</span>
      </div>
    </div>

    <div class="success-actions">
      <button class="btn btn--primary" onclick="goto('unit')"><span class="material-symbols-outlined" style="font-size:18px;">play_arrow</span> Start learning</button>
      <button class="btn btn--outline" onclick="goto('mylearning')"><span class="material-symbols-outlined" style="font-size:18px;">school</span> Go to My Learning</button>
    </div>

    <div class="success-checklist">
      <h3>What happens next</h3>
      <ul>
        <li><span class="material-symbols-outlined">mark_email_read</span> Receipt and enrolment confirmation emailed (check spam if missing)</li>
        <li><span class="material-symbols-outlined">event</span> Calendar invite for the live kickoff on ${esc(start)} · 8:00 PM MYT</li>
        <li><span class="material-symbols-outlined">group</span> You'll be added to the private cohort channel within 24 hours</li>
        <li><span class="material-symbols-outlined">download</span> All readings &amp; worksheets are ready to download inside the course</li>
      </ul>
    </div>
  </main>`;
}

function esc(s) { return String(s || '').replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;'); }
