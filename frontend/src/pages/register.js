// Page: Register — ported from prototype screen-register
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
          <a href="/register" role="tab" class="is-active" aria-selected="true">Register</a>
          <a href="/login" role="tab">Sign in</a>
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

        <div class="field">
          <div class="float-label">
            <input id="reg-name" type="text" placeholder=" " autocomplete="name" />
            <label for="reg-name">Full name</label>
          </div>
        </div>

        <div class="field">
          <div class="float-label">
            <input id="reg-email" type="email" placeholder=" " autocomplete="email" />
            <label for="reg-email">Email address</label>
          </div>
        </div>

        <div class="field">
          <div class="float-label password-wrap">
            <input id="reg-password" type="password" placeholder=" " autocomplete="new-password" />
            <label for="reg-password">Create a password</label>
            <button type="button" class="show-toggle" aria-label="Show password"
              onclick="var i=document.getElementById('reg-password'); i.type = i.type==='password' ? 'text' : 'password';">
              <span class="material-symbols-outlined" style="font-size:22px;">visibility</span>
            </button>
          </div>
        </div>

        <div class="login__actions">
          <button class="btn btn--primary" onclick="goto('dashboard')">Create account</button>
          <a class="forgot" href="/login">Already have an account?</a>
        </div>

        <p class="login__sso-label">Or continue with:</p>
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
