// Page: Settings — full settings UI ported from static prototype
export async function render(rootEl) {
  rootEl.innerHTML = settingsHtml();
  wireSettings(rootEl);
}

function settingsHtml() {
  return `
  <main class="settings">
    <div class="settings__head">
      <h1>Settings</h1>
      <p>Manage your account, notifications, privacy, and billing.</p>
    </div>
    <div class="settings__layout">
      <aside class="settings__side">
        <ul class="settings__nav" id="settingsNav">
          <li class="is-active" data-pane="account"><span class="material-symbols-outlined">person</span> Account</li>
          <li data-pane="notifications"><span class="material-symbols-outlined">notifications</span> Notifications</li>
          <li data-pane="privacy"><span class="material-symbols-outlined">lock</span> Privacy &amp; security</li>
          <li data-pane="billing"><span class="material-symbols-outlined">credit_card</span> Billing</li>
          <li data-pane="appearance"><span class="material-symbols-outlined">palette</span> Appearance</li>
          <li data-pane="language"><span class="material-symbols-outlined">language</span> Language &amp; region</li>
          <li data-pane="connected"><span class="material-symbols-outlined">hub</span> Connected apps</li>
          <li data-pane="danger"><span class="material-symbols-outlined">warning</span> Danger zone</li>
        </ul>
      </aside>
      <div class="settings__main">
        ${accountPane()}
        ${notificationsPane()}
        ${privacyPane()}
        ${billingPane()}
        ${appearancePane()}
        ${languagePane()}
        ${connectedPane()}
        ${dangerPane()}
      </div>
    </div>
  </main>`;
}

function accountPane() {
  return `
        <div class="settings-pane" data-pane="account">
          <div class="settings-card">
            <h2>Profile information</h2>
            <p class="settings-card__desc">This is how you appear across Mereka Academy.</p>
            <div class="settings-avatar-row">
              <div class="avatar-lg">FF</div>
              <div>
                <button class="btn btn--outline btn--sm">Upload new</button>
                <button class="btn btn--ghost btn--sm">Remove</button>
                <div style="font-size:12px; color:var(--medium-grey); margin-top:6px;">JPG or PNG · max 2MB · square recommended</div>
              </div>
            </div>
            <div class="settings-field-row">
              <div class="settings-field"><label>First name</label><input value="Faiz" /></div>
              <div class="settings-field"><label>Last name</label><input value="Fadhillah" /></div>
            </div>
            <div class="settings-field"><label>Display name</label><input value="Faiz Fadhillah" /></div>
            <div class="settings-field"><label>Email</label><input value="faiz.fadhillah@gmail.com" /></div>
            <div class="settings-field"><label>Headline / role</label><input value="Founder & CEO · Mereka" /></div>
            <div class="settings-field"><label>Bio</label><textarea rows="3">Building the future of work and learning in Southeast Asia.</textarea></div>
            <div class="settings-card__foot">
              <button class="btn btn--ghost btn--sm">Cancel</button>
              <button class="btn btn--primary btn--sm js-settings-save">Save changes</button>
            </div>
          </div>
        </div>`;
}

function notificationsPane() {
  return `
        <div class="settings-pane" data-pane="notifications" style="display:none;">
          <div class="settings-card">
            <h2>Notification preferences</h2>
            <p class="settings-card__desc">Choose what you want to hear about, and where.</p>
            <div class="toggle-row"><div class="toggle-row__body"><strong>Course progress reminders</strong><span>Weekly nudge when you haven't studied in 5+ days</span></div><div class="toggle is-on"></div></div>
            <div class="toggle-row"><div class="toggle-row__body"><strong>Assignment due dates</strong><span>Email + in-app, 24h and 1h before deadlines</span></div><div class="toggle is-on"></div></div>
            <div class="toggle-row"><div class="toggle-row__body"><strong>Discussion replies</strong><span>When someone replies to your thread or @mentions you</span></div><div class="toggle is-on"></div></div>
            <div class="toggle-row"><div class="toggle-row__body"><strong>New course releases</strong><span>Monthly digest of new cohorts</span></div><div class="toggle"></div></div>
            <div class="toggle-row"><div class="toggle-row__body"><strong>Marketing &amp; tips</strong><span>Occasional product updates and learning tips</span></div><div class="toggle"></div></div>
            <div class="settings-card__foot"><button class="btn btn--primary btn--sm js-settings-save">Save preferences</button></div>
          </div>
        </div>`;
}

function privacyPane() {
  return `
        <div class="settings-pane" data-pane="privacy" style="display:none;">
          <div class="settings-card">
            <h2>Password</h2>
            <p class="settings-card__desc">Last changed Feb 12, 2026.</p>
            <div class="settings-field"><label>Current password</label><input type="password" value="••••••••••" /></div>
            <div class="settings-field-row">
              <div class="settings-field"><label>New password</label><input type="password" placeholder="Min. 12 characters" /></div>
              <div class="settings-field"><label>Confirm new password</label><input type="password" /></div>
            </div>
            <div class="settings-card__foot"><button class="btn btn--primary btn--sm js-settings-save">Update password</button></div>
          </div>
          <div class="settings-card">
            <h2>Two-factor authentication</h2>
            <p class="settings-card__desc">Add a second step when signing in from a new device.</p>
            <div class="toggle-row"><div class="toggle-row__body"><strong>Authenticator app</strong><span>Google Authenticator, 1Password, Authy…</span></div><button class="btn btn--outline btn--sm">Set up</button></div>
            <div class="toggle-row"><div class="toggle-row__body"><strong>SMS backup codes</strong><span>Get a one-time code via text</span></div><div class="toggle"></div></div>
          </div>
          <div class="settings-card">
            <h2>Profile visibility</h2>
            <div class="toggle-row"><div class="toggle-row__body"><strong>Show my profile to other learners</strong><span>Lets peers find you in discussions and peer reviews</span></div><div class="toggle is-on"></div></div>
            <div class="toggle-row"><div class="toggle-row__body"><strong>Show earned certificates publicly</strong><span>Displayed on your Mereka profile URL</span></div><div class="toggle is-on"></div></div>
          </div>
        </div>`;
}

function billingPane() {
  return `
        <div class="settings-pane" data-pane="billing" style="display:none;">
          <div class="settings-card">
            <h2>Payment method</h2>
            <div style="display:flex; justify-content:space-between; align-items:center; padding:14px; background:var(--surface); border-radius:12px;">
              <div style="display:flex; align-items:center; gap:12px;">
                <span class="material-symbols-outlined" style="color:var(--primary);">credit_card</span>
                <div><strong style="font-family:var(--font-display);">Visa ending 4411</strong><div style="font-size:12px; color:var(--medium-grey);">Expires 09/2028</div></div>
              </div>
              <button class="btn btn--ghost btn--sm">Update</button>
            </div>
          </div>
          <div class="settings-card">
            <h2>Billing history</h2>
            <div style="display:flex; justify-content:space-between; padding:12px 0; border-bottom:1px solid var(--border); font-size:14px;"><span>Feb 12, 2026 · Academy Pro annual</span><span>RM 1,068 <a href="#" style="margin-left:12px; color:var(--primary);">PDF</a></span></div>
            <div style="display:flex; justify-content:space-between; padding:12px 0; border-bottom:1px solid var(--border); font-size:14px;"><span>Feb 12, 2025 · Academy Pro annual</span><span>RM 1,068 <a href="#" style="margin-left:12px; color:var(--primary);">PDF</a></span></div>
            <div style="display:flex; justify-content:space-between; padding:12px 0; font-size:14px;"><span>Feb 12, 2024 · Academy Basic annual</span><span>RM 588 <a href="#" style="margin-left:12px; color:var(--primary);">PDF</a></span></div>
          </div>
        </div>`;
}

function appearancePane() {
  return `
        <div class="settings-pane" data-pane="appearance" style="display:none;">
          <div class="settings-card">
            <h2>Theme</h2>
            <p class="settings-card__desc">Choose how Mereka looks to you.</p>
            <div style="display:grid; grid-template-columns:repeat(3,1fr); gap:12px;">
              <label style="display:block; border:2px solid var(--primary); border-radius:12px; padding:14px; cursor:pointer; background:var(--white);"><input type="radio" name="theme" checked style="margin-right:6px;"/><strong style="font-family:var(--font-display);">Light</strong><div style="height:40px; background:linear-gradient(180deg,#fff 50%,#f3f3f5 50%); border-radius:6px; margin-top:10px; border:1px solid var(--border);"></div></label>
              <label style="display:block; border:1px solid var(--border); border-radius:12px; padding:14px; cursor:pointer; background:var(--white);"><input type="radio" name="theme" style="margin-right:6px;"/><strong style="font-family:var(--font-display);">Dark</strong><div style="height:40px; background:linear-gradient(180deg,#1a1a1e 50%,#2b2b33 50%); border-radius:6px; margin-top:10px;"></div></label>
              <label style="display:block; border:1px solid var(--border); border-radius:12px; padding:14px; cursor:pointer; background:var(--white);"><input type="radio" name="theme" style="margin-right:6px;"/><strong style="font-family:var(--font-display);">System</strong><div style="height:40px; background:linear-gradient(90deg,#fff 50%,#2b2b33 50%); border-radius:6px; margin-top:10px; border:1px solid var(--border);"></div></label>
            </div>
          </div>
          <div class="settings-card">
            <h2>Density</h2>
            <div class="toggle-row"><div class="toggle-row__body"><strong>Compact mode</strong><span>Tighter spacing across lists and cards</span></div><div class="toggle"></div></div>
            <div class="toggle-row"><div class="toggle-row__body"><strong>Reduce motion</strong><span>Disable non-essential animations</span></div><div class="toggle"></div></div>
          </div>
        </div>`;
}

function languagePane() {
  return `
        <div class="settings-pane" data-pane="language" style="display:none;">
          <div class="settings-card">
            <h2>Language &amp; region</h2>
            <div class="settings-field"><label>Interface language</label><select><option selected>English (Malaysia)</option><option>English (United States)</option><option>Bahasa Malaysia</option><option>Bahasa Indonesia</option><option>中文 (简体)</option></select></div>
            <div class="settings-field-row">
              <div class="settings-field"><label>Time zone</label><select><option selected>Asia/Kuala_Lumpur (GMT+8)</option><option>Asia/Jakarta (GMT+7)</option><option>Asia/Singapore (GMT+8)</option></select></div>
              <div class="settings-field"><label>Date format</label><select><option selected>DD MMM YYYY</option><option>MMM DD, YYYY</option><option>YYYY-MM-DD</option></select></div>
            </div>
            <div class="settings-card__foot"><button class="btn btn--primary btn--sm js-settings-save">Save</button></div>
          </div>
        </div>`;
}

function connectedPane() {
  return `
        <div class="settings-pane" data-pane="connected" style="display:none;">
          <div class="settings-card">
            <h2>Connected apps</h2>
            <p class="settings-card__desc">Apps that have access to your Mereka account.</p>
            <div class="toggle-row"><div class="toggle-row__body"><strong>Google Calendar</strong><span>Adds deadlines and live sessions to your calendar</span></div><button class="btn btn--outline btn--sm">Disconnect</button></div>
            <div class="toggle-row"><div class="toggle-row__body"><strong>Slack</strong><span>Delivers discussion notifications to a channel</span></div><button class="btn btn--outline btn--sm">Disconnect</button></div>
            <div class="toggle-row"><div class="toggle-row__body"><strong>LinkedIn</strong><span>Auto-post earned certificates</span></div><button class="btn btn--primary btn--sm">Connect</button></div>
            <div class="toggle-row"><div class="toggle-row__body"><strong>Zoom</strong><span>Join live sessions with one click</span></div><button class="btn btn--primary btn--sm">Connect</button></div>
          </div>
        </div>`;
}

function dangerPane() {
  return `
        <div class="settings-pane" data-pane="danger" style="display:none;">
          <div class="settings-card settings-danger">
            <h2>Export your data</h2>
            <p class="settings-card__desc">Download everything: profile, certificates, assignments, discussion posts.</p>
            <button class="btn btn--outline btn--sm">Request export</button>
          </div>
          <div class="settings-card settings-danger">
            <h2>Deactivate account</h2>
            <p class="settings-card__desc">Temporarily hides your profile and pauses notifications. You can reactivate anytime.</p>
            <button class="btn btn--outline btn--sm">Deactivate</button>
          </div>
          <div class="settings-card settings-danger">
            <h2>Delete account</h2>
            <p class="settings-card__desc">Permanently delete your account and all associated data. This cannot be undone.</p>
            <button class="btn btn--outline btn--sm" style="color:#C23636; border-color:#C23636;">Delete account</button>
          </div>
        </div>`;
}

function wireSettings(rootEl) {
  // Tab switching
  const navItems = rootEl.querySelectorAll('.settings__nav li[data-pane]');
  const panes = rootEl.querySelectorAll('.settings-pane[data-pane]');
  navItems.forEach(li => li.addEventListener('click', () => {
    const key = li.dataset.pane;
    navItems.forEach(n => n.classList.toggle('is-active', n === li));
    panes.forEach(p => p.style.display = (p.dataset.pane === key ? '' : 'none'));
  }));

  // Toggle switches
  rootEl.querySelectorAll('.toggle').forEach(tog => {
    tog.addEventListener('click', () => tog.classList.toggle('is-on'));
  });

  // Save buttons — show toast-like feedback
  rootEl.querySelectorAll('.js-settings-save').forEach(btn => {
    btn.addEventListener('click', () => {
      const orig = btn.textContent;
      btn.textContent = 'Saved!';
      btn.disabled = true;
      setTimeout(() => { btn.textContent = orig; btn.disabled = false; }, 1500);
    });
  });
}
