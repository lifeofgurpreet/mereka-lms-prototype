// Page: Auth Callback — handles post-SSO redirect from Authentik/Open edX
import { navigate } from '../router/router.js';
import { setSession } from '../auth/session.js';

const LMS_BASE = 'https://academyv2.mereka.dev';

export async function render(rootEl, { params, query } = {}) {
  rootEl.innerHTML = `
  <main style="padding:80px 20px;max-width:480px;margin:0 auto;text-align:center;">
    <div id="cb-loading">
      <div style="margin-bottom:24px;">
        <svg viewBox="0 0 120 28" fill="none" xmlns="http://www.w3.org/2000/svg" style="height:32px;width:auto;">
          <text x="0" y="22" font-family="Poppins,sans-serif" font-weight="700" font-size="22" fill="#AB3B78" letter-spacing="-0.5">mereka.</text>
        </svg>
      </div>
      <div class="spinner" style="width:40px;height:40px;border:4px solid #e5e7eb;border-top-color:var(--primary,#AB3B78);border-radius:50%;animation:spin .8s linear infinite;margin:0 auto 16px;"></div>
      <p style="color:#6b7280;font-size:15px;">Completing sign-in…</p>
    </div>
    <div id="cb-error" style="display:none;">
      <div style="padding:24px;border:1px solid #fca5a5;border-radius:12px;background:#fef2f2;">
        <p style="color:#991b1b;font-size:15px;margin:0 0 16px;" id="cb-error-msg">Something went wrong during sign-in.</p>
        <a href="/login" id="cb-back" style="color:var(--primary,#AB3B78);font-weight:600;text-decoration:underline;">Back to sign in</a>
      </div>
    </div>
    <style>@keyframes spin{to{transform:rotate(360deg)}}</style>
  </main>`;

  wireAndProcess(query);
}

async function wireAndProcess(query) {
  const backLink = document.getElementById('cb-back');
  if (backLink) {
    backLink.addEventListener('click', (e) => { e.preventDefault(); navigate('/login'); });
  }

  try {
    // After SSO, the user lands back on the SPA. The session cookie is set by
    // the LMS during the OIDC flow. We verify the session by hitting the
    // user account API through our proxy.
    const res = await fetch('/api/user/v1/account/login_session/', {
      method: 'GET',
      credentials: 'include',
    });

    // Also try the user account endpoint to see if we have an active session
    const accountRes = await fetch('/api/user/v2/account/me', {
      credentials: 'include',
    });

    if (accountRes.ok) {
      const account = await accountRes.json();
      // We have an authenticated session
      setSession({
        accessToken: 'session-cookie',
        expiresAt: Date.now() + 86400000, // 24h
        tokenType: 'session',
        username: account.username || '',
        email: account.email || '',
        name: account.name || '',
      });
      // Redirect to dashboard
      navigate('/');
      return;
    }

    // If the account endpoint doesn't work, check if there's an error in the URL
    const urlParams = new URLSearchParams(window.location.search);
    const error = urlParams.get('error') || urlParams.get('error_description');

    if (error) {
      showCallbackError('Sign-in was cancelled or failed: ' + error);
      return;
    }

    // No session found — maybe the redirect flow isn't complete yet.
    // Give the user a path forward.
    showCallbackError(
      'Could not verify your session. ' +
      '<a href="' + LMS_BASE + '/dashboard" target="_blank" rel="noopener" ' +
      'style="color:#991b1b;font-weight:600;text-decoration:underline;">Go to Mereka Academy directly</a> ' +
      'or <a href="/login" style="color:#991b1b;font-weight:600;text-decoration:underline;">try signing in again</a>.'
    );
  } catch (err) {
    console.error('Auth callback error:', err);
    showCallbackError('Network error while completing sign-in. Please try again.');
  }
}

function showCallbackError(html) {
  const loading = document.getElementById('cb-loading');
  const errorEl = document.getElementById('cb-error');
  const msgEl   = document.getElementById('cb-error-msg');
  if (loading) loading.style.display = 'none';
  if (errorEl) errorEl.style.display = 'block';
  if (msgEl) msgEl.innerHTML = html;
}
