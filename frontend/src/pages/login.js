// Page: Login — ported from prototype screen-login
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
            <svg viewBox="0 0 120 28" fill="none" xmlns="http://www.w3.org/2000/svg" style="height:28px;width:auto;">
              <text x="0" y="22" font-family="Poppins,sans-serif" font-weight="700" font-size="22" fill="#1A1623" letter-spacing="-0.5">mereka.</text>
            </svg>
          </div>
          <p class="login__eyebrow">Learning workspace</p>
          <h1 class="login__title">Mereka Academy</h1>
          <p class="login__sub">Secure access for your active learning environment.</p>
        </div>

        <div class="field">
          <div class="float-label">
            <input id="login-email" type="text" placeholder=" " autocomplete="username" />
            <label for="login-email">Username or email</label>
          </div>
        </div>

        <div class="field">
          <div class="float-label password-wrap">
            <input id="login-password" type="password" placeholder=" " autocomplete="current-password" />
            <label for="login-password">Password</label>
            <button type="button" class="show-toggle" aria-label="Show password"
              onclick="var i=document.getElementById('login-password'); i.type = i.type==='password' ? 'text' : 'password';">
              <span class="material-symbols-outlined" style="font-size:22px;">visibility</span>
            </button>
          </div>
        </div>

        <div class="login__actions">
          <button class="btn btn--primary" onclick="goto('dashboard')">Sign in</button>
          <a class="forgot" href="#">Forgot password</a>
        </div>

        <p class="login__sso-label">Or sign in with:</p>
        <div class="login__sso">
          <button type="button" class="login__sso-btn" onclick="goto('dashboard')">
            <span class="sso-icon"><span class="material-symbols-outlined">login</span></span>
            <span class="sso-label">Mereka</span>
          </button>
        </div>
      </div>
    </div>
  </div>`;
}
