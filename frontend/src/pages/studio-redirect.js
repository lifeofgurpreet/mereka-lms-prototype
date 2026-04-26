// Page: Studio Redirect
import { config } from '../config.js';
export async function render(rootEl) {
  const studioUrl = config.openedx.studioUrl || 'https://studio.academyv2.mereka.dev';
  rootEl.innerHTML = `
  <main style="max-width:600px; margin:0 auto; padding:80px 20px; text-align:center;">
    <span class="material-symbols-outlined" style="font-size:48px; color:var(--primary);">edit_note</span>
    <h1 style="margin:16px 0 8px;">Mereka Studio</h1>
    <p style="color:var(--medium-grey);">Course authoring and content management.</p>
    <a href="${studioUrl}" target="_blank" class="btn btn--primary" style="margin-top:24px;">Open Studio <span class="material-symbols-outlined" style="font-size:16px;">open_in_new</span></a>
  </main>`;
}
