// Page: Certificates — verified credentials gallery
import { navigate } from '../router/router.js';
import { listMyCertificates } from '../api/certificates.js';

export async function render(rootEl) {
  let certs = [];
  try {
    const data = await listMyCertificates('me');
    if (Array.isArray(data) && data.length) {
      certs = data.map(c => ({
        id: c.certificate_type + '-' + c.course_id,
        courseId: c.course_id,
        name: c.course_display_name || c.course_id,
        type: c.certificate_type,
        issued: c.created_date,
        downloadUrl: c.download_url,
      }));
    }
  } catch (_) {}

  if (!certs.length) certs = mockCerts();

  const byYear = {};
  certs.forEach(c => {
    const y = new Date(c.issued).getFullYear();
    byYear[y] = (byYear[y] || 0) + 1;
  });

  rootEl.innerHTML = `
  <main class="mylearning">
    <div style="font-size:12px;color:var(--medium-grey);margin-bottom:14px;">
      <a href="/" id="bcHome" style="color:var(--medium-grey);text-decoration:none;">Dashboard</a>
      <span style="margin:0 8px;">/</span>
      <span style="color:var(--off-black);font-weight:500;">Certificates</span>
    </div>

    <div class="mylearning__head">
      <div>
        <h1>Your certificates</h1>
        <p>Verified credentials for every course you've completed on Mereka.</p>
      </div>
      <div style="display:flex;gap:8px;">
        <button class="btn btn--outline" id="profileBtn"><span class="material-symbols-outlined" style="font-size:16px;">verified</span> Public profile</button>
        <button class="btn btn--primary" id="downloadAllBtn"><span class="material-symbols-outlined" style="font-size:16px;">download</span> Download all</button>
      </div>
    </div>

    <div class="mylearning__summary">
      <div class="mylearning__stat"><span>Total earned</span><strong>${certs.length}</strong><em>since ${minYear(certs)}</em></div>
      <div class="mylearning__stat"><span>This year</span><strong>${byYear[new Date().getFullYear()] || 0}</strong><em>${recentCount(certs)} in the last 60 days</em></div>
      <div class="mylearning__stat"><span>Average score</span><strong>89%</strong><em>Top 12% of learners</em></div>
      <div class="mylearning__stat"><span>Verified by</span><strong style="font-size:18px;padding-top:6px;">Mereka</strong><em>Blockchain-backed</em></div>
    </div>

    <div class="mylearning__filters" role="tablist" aria-label="Filter">
      <button class="mylearning__chip is-active">All <span class="count">(${certs.length})</span></button>
      ${Object.entries(byYear).sort((a,b) => b[0]-a[0]).map(([y,n]) => `<button class="mylearning__chip">${y} <span class="count">(${n})</span></button>`).join('')}
      ${buildCatChips(certs)}
    </div>

    <div class="mylearning__grid" id="certGrid">
      ${certs.map(c => certCard(c)).join('')}
    </div>
  </main>`;

  wireEvents();
}

/* ── Mock certificates ── */
function mockCerts() {
  return [
    { id: 'c1', courseId: 'course-v1:Mereka+STRAT301+2026', name: 'Strategic thinking for modern leaders', cat: 'Strategy', instructor: 'Mei Lin Tan', issued: '2026-04-18T00:00:00Z', credential: 'MRK-2026-48291', score: 92, modules: 12, thumbClass: '', downloadUrl: '#' },
    { id: 'c2', courseId: 'course-v1:Mereka+PPL201+2026', name: 'High-performing remote teams', cat: 'People ops', instructor: 'Daniel Wong', issued: '2026-04-18T00:00:00Z', credential: 'MRK-2026-48290', score: 92, modules: 10, thumbClass: 't-people', downloadUrl: '#' },
    { id: 'c3', courseId: 'course-v1:Mereka+DATA201+2026', name: 'Analytics for non-analysts', cat: 'Data', instructor: 'Priya Menon', issued: '2026-03-04T00:00:00Z', credential: 'MRK-2026-39814', score: 88, modules: 6, thumbClass: 't-data', downloadUrl: '#' },
    { id: 'c4', courseId: 'course-v1:Mereka+STRAT201+2026', name: 'OKRs that actually work', cat: 'Strategy', instructor: 'Raj Patel', issued: '2026-03-04T00:00:00Z', credential: 'MRK-2026-39795', score: 88, modules: 5, thumbClass: '', downloadUrl: '#' },
    { id: 'c5', courseId: 'course-v1:Mereka+DES301+2026', name: 'Facilitation for creative teams', cat: 'Design', instructor: 'Shu Lin', issued: '2026-02-12T00:00:00Z', credential: 'MRK-2026-31208', score: 86, modules: 4, thumbClass: 't-design', downloadUrl: '#' },
    { id: 'c6', courseId: 'course-v1:Mereka+PPL101+2025', name: 'Giving effective feedback', cat: 'People ops', instructor: 'Daniel Wong', issued: '2025-12-08T00:00:00Z', credential: 'MRK-2025-87104', score: 91, modules: 5, thumbClass: 't-people', downloadUrl: '#' },
    { id: 'c7', courseId: 'course-v1:Mereka+DATA101+2025', name: 'SQL for decision-makers', cat: 'Data', instructor: 'Priya Menon', issued: '2025-10-22T00:00:00Z', credential: 'MRK-2025-74921', score: 85, modules: 8, thumbClass: 't-data', downloadUrl: '#' },
    { id: 'c8', courseId: 'course-v1:Mereka+STRAT101+2025', name: 'First-principles problem solving', cat: 'Strategy', instructor: 'Mei Lin Tan', issued: '2025-08-15T00:00:00Z', credential: 'MRK-2025-62330', score: 90, modules: 6, thumbClass: '', downloadUrl: '#' },
  ];
}

function minYear(certs) {
  if (!certs.length) return new Date().getFullYear();
  return Math.min(...certs.map(c => new Date(c.issued).getFullYear()));
}

function recentCount(certs) {
  const cutoff = new Date(); cutoff.setDate(cutoff.getDate() - 60);
  return certs.filter(c => new Date(c.issued) >= cutoff).length;
}

function buildCatChips(certs) {
  const cats = {};
  certs.forEach(c => { const cat = c.cat || 'Other'; cats[cat] = (cats[cat] || 0) + 1; });
  return Object.entries(cats).map(([cat, n]) =>
    `<button class="mylearning__chip">${cat} <span class="count">(${n})</span></button>`
  ).join('');
}

function fmtDate(iso) {
  const d = new Date(iso);
  const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
  return `${months[d.getMonth()]} ${d.getDate()}, ${d.getFullYear()}`;
}

function certCard(c) {
  const gradientBg = (!c.thumbClass || c.thumbClass === '') ? 'background:var(--brand-gradient);' : '';
  return `
  <article class="ml-card" data-cert-id="${c.id}">
    <div class="ml-card__thumb ${c.thumbClass || ''}" style="min-height:160px;flex-direction:column;gap:8px;${gradientBg}">
      <span class="material-symbols-outlined" style="font-size:48px;">workspace_premium</span>
      <div style="font-family:var(--font-display);font-weight:600;font-size:12px;letter-spacing:1px;text-transform:uppercase;">Certificate of Completion</div>
    </div>
    <div class="ml-card__body">
      <span class="ml-card__cat">${c.cat || ''}</span>
      <h3>${c.name}</h3>
      <p class="ml-card__meta">${c.instructor || ''} · Issued ${fmtDate(c.issued)}</p>
      <div style="display:flex;justify-content:space-between;font-size:12px;color:var(--dark-grey);margin-top:6px;padding:8px 0;border-top:1px dashed var(--border);border-bottom:1px dashed var(--border);">
        <span>Credential</span><span style="font-family:var(--font-mono,monospace);font-size:11px;">${c.credential || '—'}</span>
      </div>
      <div style="display:flex;justify-content:space-between;font-size:12px;color:var(--dark-grey);margin-top:8px;">
        <span style="color:var(--primary);font-weight:600;">Score ${c.score || '—'}%</span>
        <span>${c.modules || '—'} modules</span>
      </div>
      <div class="ml-card__foot">
        <button class="btn btn--ghost btn--sm js-share" data-name="${c.name}"><span class="material-symbols-outlined" style="font-size:16px;">share</span> Share</button>
        <button class="btn btn--outline btn--sm js-view-cert" data-course="${c.courseId || ''}">View →</button>
      </div>
    </div>
  </article>`;
}

function wireEvents() {
  document.getElementById('bcHome')?.addEventListener('click', e => { e.preventDefault(); navigate('/'); });
  document.getElementById('profileBtn')?.addEventListener('click', () => navigate('/profile'));
  document.getElementById('downloadAllBtn')?.addEventListener('click', () => {
    alert('Bulk download coming soon! For now, view and download individual certificates.');
  });

  document.querySelectorAll('.js-view-cert').forEach(btn => {
    btn.addEventListener('click', () => {
      const cid = btn.dataset.course;
      if (cid) navigate('/course/' + encodeURIComponent(cid));
    });
  });

  document.querySelectorAll('.js-share').forEach(btn => {
    btn.addEventListener('click', () => {
      const name = btn.dataset.name;
      if (navigator.share) {
        navigator.share({ title: 'Mereka Certificate', text: `I earned a certificate in ${name} on Mereka Academy!`, url: window.location.href });
      } else {
        navigator.clipboard?.writeText(window.location.href);
        alert('Link copied to clipboard!');
      }
    });
  });

  document.querySelectorAll('.mylearning__chip').forEach(chip => {
    chip.addEventListener('click', () => {
      document.querySelectorAll('.mylearning__chip').forEach(c => c.classList.remove('is-active'));
      chip.classList.add('is-active');
    });
  });
}
