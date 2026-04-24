// Page: Course
// Phase 0 stub. Port from docs/design-reference/mereka-ux-prototype/index.html
// and wire to API modules as the feature ticket lands.

export async function render(rootEl, { params, query } = {}) {
  rootEl.innerHTML = `
    <main style="padding:80px 20px;max-width:900px;margin:0 auto;">
      <div style="padding:40px;border:2px dashed #e5e7eb;border-radius:12px;text-align:center;">
        <h1 style="margin:0 0 12px;font-family:'Poppins',sans-serif;color:#AB3B78;">Course</h1>
        <p style="color:#6b7280;margin:0 0 16px;">Phase 0 stub — port prototype content + wire API.</p>
        <code style="color:#6b7280;font-size:12px;">params: ${JSON.stringify(params || {})}</code>
      </div>
    </main>
  `;
}
