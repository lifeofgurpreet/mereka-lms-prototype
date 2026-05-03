// Page: Admin → Video Pipeline — transcoding, CDN delivery, and captions
// Spec: specs/plans/video-pipeline-delivery_plan.md

export async function render(rootEl) {
  rootEl.innerHTML = `
  <main class="admin-page">
    <div class="admin-page__head">
      <div>
        <h1>Video Pipeline</h1>
        <p class="admin-page__sub">Upload, transcode, caption, and deliver video content via CDN.</p>
      </div>
      <div class="admin-page__actions">
        <button class="btn btn--outline btn--sm"><span class="material-symbols-outlined" style="font-size:16px;">settings</span> CDN Settings</button>
        <button class="btn btn--primary btn--sm"><span class="material-symbols-outlined" style="font-size:16px;">upload</span> Upload Video</button>
      </div>
    </div>

    <div class="kpi-row">
      <div class="kpi-card"><div class="kpi-card__label">Total Videos</div><div class="kpi-card__value">342</div><div class="kpi-card__hint">across all courses</div></div>
      <div class="kpi-card"><div class="kpi-card__label">Storage Used</div><div class="kpi-card__value">1.8 TB</div><div class="kpi-card__hint">of 5 TB quota</div></div>
      <div class="kpi-card"><div class="kpi-card__label">Views (30d)</div><div class="kpi-card__value">48.2K</div><div class="kpi-card__hint">↑ 22% vs prev</div></div>
      <div class="kpi-card"><div class="kpi-card__label">Avg. Watch %</div><div class="kpi-card__value">74%</div><div class="kpi-card__hint">completion rate</div></div>
    </div>

    <!-- Processing Queue -->
    <section class="admin-section">
      <h2>Processing Queue</h2>
      <div class="admin-table-wrap">
        <table class="admin-table">
          <thead><tr><th>Video</th><th>Course</th><th>Status</th><th>Progress</th><th>ETA</th></tr></thead>
          <tbody>
            <tr><td><strong>Module 5 — Final lecture</strong></td><td>Strategic Thinking</td><td><span class="status-badge status-badge--active">Transcoding</span></td><td><div class="progress-bar"><div class="progress-bar__fill" style="width:67%"></div></div> 67%</td><td>~4 min</td></tr>
            <tr><td><strong>Expert interview — Priya</strong></td><td>Data Analytics</td><td><span class="status-badge status-badge--warning">Captioning</span></td><td><div class="progress-bar"><div class="progress-bar__fill" style="width:45%"></div></div> 45%</td><td>~8 min</td></tr>
            <tr><td><strong>Design sprint walkthrough</strong></td><td>Design Thinking</td><td><span class="status-badge status-badge--draft">Queued</span></td><td>—</td><td>~15 min</td></tr>
          </tbody>
        </table>
      </div>
    </section>

    <!-- Transcoding Profiles -->
    <section class="admin-section">
      <h2>Transcoding Profiles</h2>
      <div class="admin-card">
        <div class="toggle-row"><div class="toggle-row__body"><strong>1080p (Full HD)</strong><span>H.264 · 4500 kbps · Primary quality</span></div><div class="toggle is-on"></div></div>
        <div class="toggle-row"><div class="toggle-row__body"><strong>720p (HD)</strong><span>H.264 · 2500 kbps · Mobile-friendly</span></div><div class="toggle is-on"></div></div>
        <div class="toggle-row"><div class="toggle-row__body"><strong>480p (SD)</strong><span>H.264 · 1000 kbps · Low bandwidth fallback</span></div><div class="toggle is-on"></div></div>
        <div class="toggle-row"><div class="toggle-row__body"><strong>360p (Low)</strong><span>H.264 · 500 kbps · Offline download quality</span></div><div class="toggle"></div></div>
        <div class="toggle-row"><div class="toggle-row__body"><strong>Audio-only (MP3)</strong><span>128 kbps · For podcast-mode playback</span></div><div class="toggle is-on"></div></div>
      </div>
    </section>

    <!-- Caption/Subtitle -->
    <section class="admin-section">
      <h2>Auto-Captioning</h2>
      <div class="admin-card">
        <div class="toggle-row"><div class="toggle-row__body"><strong>Auto-generate captions</strong><span>Whisper AI transcription on upload · English, Malay, Indonesian</span></div><div class="toggle is-on"></div></div>
        <div class="toggle-row"><div class="toggle-row__body"><strong>Auto-translate subtitles</strong><span>Generate subtitles in all supported languages</span></div><div class="toggle"></div></div>
        <div class="toggle-row"><div class="toggle-row__body"><strong>Human review queue</strong><span>Flag AI captions for instructor review before publishing</span></div><div class="toggle is-on"></div></div>
      </div>
      <div style="margin-top:16px;">
        <h3>Caption Languages</h3>
        <div style="display:flex;gap:8px;flex-wrap:wrap;margin-top:8px;">
          <span class="chip chip--active">English</span>
          <span class="chip chip--active">Bahasa Malaysia</span>
          <span class="chip chip--active">Bahasa Indonesia</span>
          <span class="chip">中文</span>
          <span class="chip">Tiếng Việt</span>
          <span class="chip">日本語</span>
          <button class="btn btn--ghost btn--sm">+ Add language</button>
        </div>
      </div>
    </section>

    <!-- CDN Performance -->
    <section class="admin-section">
      <h2>CDN Performance</h2>
      <div class="admin-card">
        <div class="toggle-row"><div class="toggle-row__body"><strong>Provider</strong><span>Cloudflare Stream + R2 Storage</span></div><span class="status-badge status-badge--active">Connected</span></div>
        <div class="toggle-row"><div class="toggle-row__body"><strong>Edge Locations</strong><span>KUL, SIN, JKT, HCM, BKK, SYD</span></div><span>6 PoPs active</span></div>
        <div class="toggle-row"><div class="toggle-row__body"><strong>Cache Hit Rate</strong><span>96.2% — last 24h</span></div><span class="status-badge status-badge--active">Excellent</span></div>
        <div class="toggle-row"><div class="toggle-row__body"><strong>P95 Latency</strong><span>First byte: 42ms (SEA region)</span></div><span class="status-badge status-badge--active">Good</span></div>
      </div>
    </section>
  </main>`;
  rootEl.querySelectorAll('.toggle').forEach(t => t.addEventListener('click', () => t.classList.toggle('is-on')));
}
