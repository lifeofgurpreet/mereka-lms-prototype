// Page: Continue Learning — ported from prototype
export async function render(rootEl, { params, query } = {}) {
  rootEl.innerHTML = `
  <main style="max-width:900px; margin:0 auto; padding:40px 20px;">
    <h1>Continue Learning</h1>
    <p style="color:var(--medium-grey);">This page is being connected to the Mereka Academy backend. Check back soon.</p>
    <a href="/" class="btn btn--primary btn--sm" style="margin-top:16px;">Back to Dashboard</a>
  </main>`;
}
