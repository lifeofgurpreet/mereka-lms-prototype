// Page: Login — real Open edX auth + Authentik SSO
import { navigate } from '../router/router.js';
import { config } from '../config.js';
import { setSession } from '../auth/session.js';

const LMS_BASE = 'https://academyv2.mereka.dev';

export async function render(rootEl) {
  rootEl.innerHTML = `
  <div class="login">
    <aside class="login__visual">
      <a class="login__logo" href="/" aria-label="Mereka">
        <img src="/mereka-logo.svg" alt="Mereka" style="height:32px;width:auto;filter:brightness(0) invert(1);" />
      </a>
      <div class="login__hero">
        <h1>Start learning with Mereka Academy</h1>
      </div>
    </aside>

    <div class="login__form-wrap">
      <div class="login__form-card login__form">
        <nav class="login__tabs" role="tablist">
          <a href="/register" role="tab">Register</a>
          <a href="/login" role="tab" class="is-active" aria-selected="true">Sign in</a>
        </nav>

        <div class="login__workspace">
          <div class="login__workspace-logo">
            <img src="/mereka-logo.svg" alt="Mereka" style="height:28px;width:auto;" />
          </div>
          <p class="login__eyebrow">Learning workspace</p>
          <h1 class="login__title">Mereka Academy</h1>
          <p class="login__sub">Secure access for your active learning environment.</p>
        </div>

        <div id="loginError" style="display:none; background:rgba(220,38,38,0.08); border:1px solid rgba(220,38,38,0.2); border-radius:8px; padding:12px 16px; margin-bottom:16px; font-size:13px; color:#dc2626;">
        </div>

        <form id="loginForm" autocomplete="on">
          <div class="field">
            <div class="float-label">
              <input id="login-email" name="email" type="text" placeholder=" " autocomplete="username" required />
              <label for="login-email">Email or username</label>
            </div>
          </div>

          <div class="field">
            <div class="float-label password-wrap">
              <input id="login-password" name="password" type="password" placeholder=" " autocomplete="current-password" required />
              <label for="login-password">Password</label>
              <button type="button" class="show-toggle" aria-label="Show password" id="togglePw">
                <span class="material-symbols-outlined" style="font-size:22px;">visibility</span>
              </button>
            </div>
          </div>

          <div class="login__actions">
            <button type="submit" class="btn btn--primary" id="signInBtn">Sign in</button>
            <a class="forgot" href="${LMS_BASE}/password_assistance" target="_blank" rel="noopener">Forgot password?</a>
          </div>
        </form>

        <p class="login__sso-label">Or sign in with:</p>
        <div class="login__sso">
          <button type="button" class="login__sso-btn" id="ssoBtn">
            <span class="sso-icon"><span class="material-symbols-outlined">login</span></span>
            <span class="sso-label">Mereka SSO (Authentik)</span>
          </button>
        </div>

        <div style="margin-top:16px; text-align:center;">
          <a href="${LMS_BASE}/authn/login" target="_blank" rel="noopener" style="font-size:12px; color:var(--medium-grey); text-decoration:underline;">
            Sign in directly on Mereka Academy →
          </a>
        </div>
      </div>
    </div>
  </div>`;

  wireLogin(rootEl);
}

async function wireLogin(rootEl) {
  const form = rootEl.querySelector('#loginForm');
  const emailInput = rootEl.querySelector('#login-email');
  const pwInput = rootEl.querySelector('#login-password');
  const signInBtn = rootEl.querySelector('#signInBtn');
  const errorBox = rootEl.querySelector('#loginError');
  const togglePw = rootEl.querySelector('#togglePw');
  const ssoBtn = rootEl.querySelector('#ssoBtn');

  // Tab navigation
  rootEl.querySelectorAll('.login__tabs a').forEach(a => {
    a.addEventListener('click', e => {
      e.preventDefault();
      navigate(a.getAttribute('href'));
    });
  });

  // Password toggle
  togglePw.addEventListener('click', () => {
    const isPassword = pwInput.type === 'password';
    pwInput.type = isPassword ? 'text' : 'password';
    togglePw.querySelector('.material-symbols-outlined').textContent = isPassword ? 'visibility_off' : 'visibility';
  });

  // SSO button → redirect to Open edX OIDC login
  ssoBtn.addEventListener('click', () => {
    ssoBtn.innerHTML = '<span class="sso-icon"><span class="material-symbols-outlined">hourglass_empty</span></span><span class="sso-label">Redirecting…</span>';
    ssoBtn.disabled = true;
    // Redirect to Open edX SSO which goes to Authentik
    window.location.href = LMS_BASE + '/auth/login/oidc/?next=/dashboard';
  });

  // Form submit → try login via Open edX API
  form.addEventListener('submit', async (e) => {
    e.preventDefault();
    const email = emailInput.value.trim();
    const password = pwInput.value;

    if (!email || !password) {
      showError(errorBox, 'Please enter your email and password.');
      return;
    }

    signInBtn.disabled = true;
    signInBtn.innerHTML = '<span class="material-symbols-outlined" style="font-size:18px;animation:spin 1s linear infinite;">progress_activity</span> Signing in…';
    hideError(errorBox);

    try {
      // Step 1: Get CSRF token
      const csrfRes = await fetch('/csrf/api/v1/token', { credentials: 'include' });
      const csrfData = await csrfRes.json();
      const csrfToken = csrfData.csrfToken;

      // Step 2: POST to login_session API
      const loginRes = await fetch('/api/user/v1/account/login_session/', {
        method: 'POST',
        credentials: 'include',
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'X-CSRFToken': csrfToken,
        },
        body: new URLSearchParams({ email, password }).toString(),
      });

      if (loginRes.ok) {
        const data = await loginRes.json();
        if (data.success) {
          // Login succeeded! Store session info
          setSession({
            accessToken: 'session-cookie-auth',
            expiresAt: Date.now() + 24 * 60 * 60 * 1000,
            tokenType: 'session',
            email: email,
          });
          navigate('/');
          return;
        }
        // API returned ok but login failed
        showError(errorBox, data.value || data.error_description || 'Invalid email or password. Please try again.');
      } else if (loginRes.status === 403) {
        // CSRF or cross-origin issue — fall back to redirect
        showError(errorBox, 'Direct login is not available from this domain. Please use the SSO button or sign in directly on Mereka Academy.');
        showDirectLink(errorBox);
      } else {
        const errText = await loginRes.text();
        let msg = 'Invalid email or password.';
        try {
          const errJson = JSON.parse(errText);
          msg = errJson.value || errJson.error_description || errJson.detail || msg;
        } catch (_) {}
        showError(errorBox, msg);
      }
    } catch (err) {
      console.error('[login] error:', err);
      showError(errorBox, 'Connection error. Please use the SSO button or sign in directly on Mereka Academy.');
      showDirectLink(errorBox);
    }

    signInBtn.disabled = false;
    signInBtn.innerHTML = 'Sign in';
  });
}

function showError(box, msg) {
  box.style.display = 'block';
  box.innerHTML = '<span class="material-symbols-outlined" style="font-size:16px;vertical-align:middle;margin-right:6px;">error</span>' + escHtml(msg);
}
function hideError(box) { box.style.display = 'none'; box.innerHTML = ''; }
function showDirectLink(box) {
  box.innerHTML += '<br><a href="' + LMS_BASE + '/authn/login" target="_blank" rel="noopener" style="color:#dc2626;text-decoration:underline;font-weight:600;">Open Mereka Academy login →</a>';
}
function escHtml(s) { return (s||'').replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;'); }
