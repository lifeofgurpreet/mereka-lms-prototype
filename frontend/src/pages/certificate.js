// Page: Certificate — single certificate view with download/share
import { navigate } from '../router/router.js';
import { listMyCertificates } from '../api/certificates.js';

export async function render(rootEl, { params } = {}) {
  const certId = params?.certId || 'demo';

  /* Try to find a matching cert from API */
  let cert = null;
  try {
    const certs = await listMyCertificates('me');
    if (Array.isArray(certs) && certs.length) {
      cert = certs.find(c => c.course_id?.includes(certId)) || certs[0];
    }
  } catch (_) {}

  if (!cert) cert = mockCert();

  const issuedDate = new Date(cert.created_date || cert.issued || '2026-04-18');
  const fmtDate = issuedDate.toLocaleDateString('en-US', { year: 'numeric', month: 'long', day: 'numeric' });
  const courseName = cert.course_display_name || cert.name || 'Strategic Thinking for Modern Leaders';
  const credential = cert.credential || 'MRK-2026-48291';

  rootEl.innerHTML = `
  <main class="cert">
    <div class="cert__head">
      <a href="/certificates" id="backLink" style="font-size:13px;color:var(--medium-grey);text-decoration:none;display:inline-flex;align-items:center;gap:4px;margin-bottom:12px;">
        <span class="material-symbols-outlined" style="font-size:16px;">arrow_back</span> All certificates
      </a>
      <h1>Your certificate is ready</h1>
      <p>Verified on the Mereka Academy registry · Issued ${fmtDate}</p>
    </div>
    <div class="cert-card">
      <div class="seal"><span class="material-symbols-outlined" style="font-size:36px;">workspace_premium</span></div>
      <div class="eyebrow">Mereka Academy · Certificate of completion</div>
      <h1>${courseName.split(' ').slice(0, 3).join(' ')}</h1>
      <div class="course-for">This certificate is awarded to</div>
      <div class="recipient">Faiz Fadhillah</div>
      <div class="course-for">for successfully completing</div>
      <div class="course-title">${courseName}</div>
      <div class="foot">
        <div class="foot-col">
          <div class="sig-name">${cert.instructor || 'Amira Yusof'}</div>
          <div class="sig-role">Lead instructor</div>
        </div>
        <div class="foot-col">
          <div class="sig-name">${fmtDate}</div>
          <div class="sig-role">Credential ID · ${credential}</div>
        </div>
      </div>
    </div>
    <div class="cert__actions">
      <button class="btn btn--primary" id="downloadPdf"><span class="material-symbols-outlined" style="font-size:18px;">download</span> Download PDF</button>
      <button class="btn btn--outline" id="shareLinkedIn"><span class="material-symbols-outlined" style="font-size:18px;">share</span> Share to LinkedIn</button>
      <button class="btn btn--ghost" id="copyLink"><span class="material-symbols-outlined" style="font-size:18px;">link</span> Copy verify link</button>
    </div>
  </main>`;

  wireEvents(cert, courseName);
}

function mockCert() {
  return {
    course_display_name: 'Strategic Thinking for Modern Leaders',
    course_id: 'course-v1:Mereka+STRAT301+2026',
    certificate_type: 'verified',
    created_date: '2026-04-18T00:00:00Z',
    credential: 'MRK-2026-48291',
    instructor: 'Amira Yusof',
    download_url: '#',
  };
}

function wireEvents(cert, courseName) {
  document.getElementById('backLink')?.addEventListener('click', e => {
    e.preventDefault(); navigate('/certificates');
  });

  document.getElementById('downloadPdf')?.addEventListener('click', () => {
    if (cert.download_url && cert.download_url !== '#') {
      window.open(cert.download_url, '_blank');
    } else {
      alert('PDF download will be available once connected to the Open edX certificate service.');
    }
  });

  document.getElementById('shareLinkedIn')?.addEventListener('click', () => {
    const url = encodeURIComponent(window.location.href);
    const title = encodeURIComponent('I earned a certificate in ' + courseName + ' on Mereka Academy!');
    window.open(`https://www.linkedin.com/sharing/share-offsite/?url=${url}&title=${title}`, '_blank', 'width=600,height=400');
  });

  document.getElementById('copyLink')?.addEventListener('click', () => {
    navigator.clipboard?.writeText(window.location.href).then(() => {
      const btn = document.getElementById('copyLink');
      btn.innerHTML = '<span class="material-symbols-outlined" style="font-size:18px;">check</span> Copied!';
      setTimeout(() => {
        btn.innerHTML = '<span class="material-symbols-outlined" style="font-size:18px;">link</span> Copy verify link';
      }, 2000);
    });
  });
}
