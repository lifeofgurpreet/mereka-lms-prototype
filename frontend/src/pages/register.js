// Page: Register — real Open edX registration + Authentik SSO
import { navigate } from '../router/router.js';
import { config } from '../config.js';
import { setSession } from '../auth/session.js';

const LMS_BASE = 'https://academyv2.mereka.dev';

export async function render(rootEl) {
  rootEl.innerHTML = `
  <div class="login">
    <aside class="login__visual">
      <a class="login__logo" href="/" aria-label="Mereka">
        <svg viewBox="0 0 120 28" fill="none" xmlns="http://www.w3.org/2000/svg" style="height:32px;width:auto;">
          <text x="0" y="22" font-family="Poppins,sans-serif" font-weight="700" font-size="22" fill="white" letter-spacing="-0.5">mereka.</text>
        </svg>
      </a>
      <div class="login__hero">
        <h1>Join the Mereka Academy community</h1>
      </div>
    </aside>

    <div class="login__form-wrap">
      <div class="login__form-card login__form">
        <nav class="login__tabs" role="tablist">
          <a href="/register" role="tab" class="is-active" aria-selected="true" id="tabRegister">Register</a>
          <a href="/login" role="tab" id="tabLogin">Sign in</a>
        </nav>

        <div class="login__workspace">
          <div class="login__workspace-logo">
            <svg viewBox="0 0 120 28" fill="none" xmlns="http://www.w3.org/2000/svg" style="height:28px;width:auto;">
              <text x="0" y="22" font-family="Poppins,sans-serif" font-weight="700" font-size="22" fill="#1A1623" letter-spacing="-0.5">mereka.</text>
            </svg>
          </div>
          <p class="login__eyebrow">Learning workspace</p>
          <h1 class="login__title">Create your account</h1>
          <p class="login__sub">Takes under a minute. No credit card required.</p>
        </div>

        <!-- Error box (hidden by default) -->
        <div id="registerError" style="display:none;padding:12px 16px;border-radius:8px;background:#fef2f2;border:1px solid #fca5a5;color:#991b1b;font-size:14px;margin-bottom:16px;"></div>

        <form id="registerForm" autocomplete="on">
          <div class="field">
            <div class="float-label">
              <input id="reg-name" name="name" type="text" placeholder=" " autocomplete="name" required />
              <label for="reg-name">Full name</label>
            </div>
          </div>

          <div class="field">
            <div class="float-label">
              <input id="reg-username" name="username" type="text" placeholder=" " autocomplete="username" required />
              <label for="reg-username">Public username</label>
            </div>
          </div>

          <div class="field">
            <div class="float-label">
              <input id="reg-email" name="email" type="email" placeholder=" " autocomplete="email" required />
              <label for="reg-email">Email address</label>
            </div>
          </div>

          <div class="field">
            <div class="float-label password-wrap">
              <input id="reg-password" name="password" type="password" placeholder=" " autocomplete="new-password" required minlength="8" />
              <label for="reg-password">Create a password</label>
              <button type="button" class="show-toggle" id="pwToggle" aria-label="Show password">
                <span class="material-symbols-outlined" style="font-size:22px;">visibility</span>
              </button>
            </div>
            <p style="font-size:12px;color:#6b7280;margin:4px 0 0 2px;">At least 8 characters</p>
          </div>

          <div class="login__actions">
            <button type="submit" class="btn btn--primary" id="registerBtn">Create account</button>
            <a class="forgot" href="/login" id="haveAccount">Already have an account?</a>
          </div>
        </form>

        <p class="login__sso-label">Or continue with:</p>
        <div class="login__sso">
          <button type="button" class="login__sso-btn" id="ssoBtn">
            <span class="sso-icon"><span class="material-symbols-outlined">login</span></span>
            <span class="sso-label">Mereka SSO</span>
          </button>
        </div>

        <p style="font-size:13px;color:#6b7280;text-align:center;margin-top:12px;">
          You can also <a href="${LMS_BASE}/authn/register" target="_blank" rel="noopener" style="color:var(--primary);text-decoration:underline;">register directly on Mereka Academy</a>
        </p>
      </div>
    </div>
  </div>`;

  wireInteractions();
}

/* ---- Interaction wiring ---- */
function wireInteractions() {
  // Password toggle
  const pwToggle = document.getElementById('pwToggle');
  if (pwToggle) {
    pwToggle.addEventListener('click', () => {
      const inp = document.getElementById('reg-password');
      const isHidden = inp.type === 'password';
      inp.type = isHidden ? 'text' : 'password';
      pwToggle.querySelector('.material-symbols-outlined').textContent =
        isHidden ? 'visibility_off' : 'visibility';
    });
  }

  // Tab navigation (SPA)
  const tabLogin = document.getElementById('tabLogin');
  if (tabLogin) {
    tabLogin.addEventListener('click', (e) => { e.preventDefault(); navigate('/login'); });
  }

  const haveAccount = document.getElementById('haveAccount');
  if (haveAccount) {
    haveAccount.addEventListener('click', (e) => { e.preventDefault(); navigate('/login'); });
  }

  // SSO button → Authentik OIDC
  const ssoBtn = document.getElementById('ssoBtn');
  if (ssoBtn) {
    ssoBtn.addEventListener('click', () => {
      window.location.href = LMS_BASE + '/auth/login/oidc/?next=/dashboard';
    });
  }

  // Auto-generate username from name
  const nameInput = document.getElementById('reg-name');
  const usernameInput = document.getElementById('reg-username');
  let userTouchedUsername = false;

  if (usernameInput) {
    usernameInput.addEventListener('input', () => { userTouchedUsername = true; });
  }
  if (nameInput && usernameInput) {
    nameInput.addEventListener('input', () => {
      if (!userTouchedUsername) {
        usernameInput.value = nameInput.value
          .toLowerCase()
          .replace(/[^a-z0-9]+/g, '_')
          .replace(/^_|_$/g, '')
          .slice(0, 30);
      }
    });
  }

  // Form submission
  const form = document.getElementById('registerForm');
  if (form) {
    form.addEventListener('submit', handleRegister);
  }
}

/* ---- Registration handler ---- */
async function handleRegister(e) {
  e.preventDefault();
  const errBox = document.getElementById('registerError');
  const btn    = document.getElementById('registerBtn');
  errBox.style.display = 'none';

  const name     = document.getElementById('reg-name').value.trim();
  const username = document.getElementById('reg-username').value.trim();
  const email    = document.getElementById('reg-email').value.trim();
  const password = document.getElementById('reg-password').value;

  if (!name || !username || !email || !password) {
    showError('Please fill in all fields.');
    return;
  }
  if (password.length < 8) {
    showError('Password must be at least 8 characters.');
    return;
  }

  btn.disabled = true;
  btn.textContent = 'Creating account…';

  try {
    // 1. Get CSRF token
    const csrfRes = await fetch('/csrf/api/v1/token', { credentials: 'include' });
    let csrfToken = '';
    if (csrfRes.ok) {
      const csrfData = await csrfRes.json();
      csrfToken = csrfData.csrfToken || '';
    }

    // 2. POST registration
    const body = new URLSearchParams({
      name,
      username,
      email,
      password,
      honor_code: 'true',
      terms_of_service: 'true',
    });

    const res = await fetch('/api/user/v1/account/registration/', {
      method: 'POST',
      credentials: 'include',
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
        ...(csrfToken ? { 'X-CSRFToken': csrfToken } : {}),
      },
      body: body.toString(),
    });

    if (res.ok || res.status === 200) {
      // Registration successful — user may need to verify email
      const data = await res.json().catch(() => ({}));
      if (data.redirect_url) {
        window.location.href = data.redirect_url;
      } else {
        // Show success, then redirect to login
        errBox.style.display = 'block';
        errBox.style.background = '#f0fdf4';
        errBox.style.borderColor = '#86efac';
        errBox.style.color = '#166534';
        errBox.innerHTML = 'Account created! Check your email to verify, then <a href="/login" style="color:#166534;font-weight:600;text-decoration:underline;">sign in</a>.';
        const loginLink = errBox.querySelector('a');
        if (loginLink) {
          loginLink.addEventListener('click', (ev) => { ev.preventDefault(); navigate('/login'); });
        }
      }
    } else {
      // Parse error response
      let msg = 'Registration failed. Please try again.';
      try {
        const errData = await res.json();
        // Open edX returns field-level errors like {email: [{user_message: "..."}], ...}
        const messages = [];
        for (const [field, errors] of Object.entries(errData)) {
          if (Array.isArray(errors)) {
            errors.forEach(err => messages.push(err.user_message || err));
          } else if (typeof errors === 'string') {
            messages.push(errors);
          }
        }
        if (messages.length) msg = messages.join('<br>');
      } catch (_) {}
      showError(msg);
    }
  } catch (err) {
    console.error('Registration error:', err);
    showError(
      'Could not reach the registration server. ' +
      '<a href="' + LMS_BASE + '/authn/register" target="_blank" rel="noopener" ' +
      'style="color:#991b1b;font-weight:600;text-decoration:underline;">Register directly on Mereka Academy</a> instead.'
    );
  } finally {
    btn.disabled = false;
    btn.textContent = 'Create account';
  }
}

function showError(html) {
  const errBox = document.getElementById('registerError');
  errBox.style.display = 'block';
  errBox.style.background = '#fef2f2';
  errBox.style.borderColor = '#fca5a5';
  errBox.style.color = '#991b1b';
  errBox.innerHTML = html;
}
