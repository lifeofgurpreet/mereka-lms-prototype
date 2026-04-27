// Page: Checkout — Stripe Payment Element mockup
// Fetches real course data from API, simulates payment flow

import { listCourses } from '../api/courses.js';

export async function render(rootEl, { params } = {}) {
  const courseId = params?.courseId || 'demo';
  
  // Try to load real course data
  let course = null;
  if (courseId !== 'demo') {
    try {
      const { courses } = await listCourses({ pageSize: 50 });
      course = courses.find(c => c.courseId === courseId || c.id === courseId);
    } catch (e) { console.warn('[checkout] course fetch failed:', e); }
  }

  const name = course?.name || 'Strategic thinking for modern leaders';
  const code = course?.number || 'STRAT-101';
  const org = course?.org || 'MEREKA';
  const start = course?.startDisplay || (course?.start ? new Date(course.start).toLocaleDateString('en-MY', { month:'short', day:'numeric' }) : 'May 5');
  const pacing = course?.pacing || 'instructor';
  const image = course?.image || null;

  // Price mock (Open edX public API doesn't expose price)
  const fee = 640;
  const discount = 160;
  const subtotal = fee - discount;
  const tax = Math.round(subtotal * 0.06 * 100) / 100;
  const total = subtotal + tax;
  const fmt = v => 'RM ' + v.toFixed(2);

  rootEl.innerHTML = `
  <main class="checkout-wrap">
    <div class="checkout-crumb">
      <a onclick="history.back(); return false;" style="cursor:pointer;">&larr; Back to course</a>
    </div>

    <div class="checkout-grid">
      <!-- LEFT: Payment form -->
      <div class="checkout-card">
        <h2>Secure checkout</h2>
        <p class="checkout-card__sub">Complete your enrollment in under 60 seconds. <span class="stripe-badge">Powered by <strong>stripe</strong></span></p>

        <form id="checkoutForm">
          <!-- Method picker -->
          <div class="pay-method">
            <div class="pay-method__opt is-active" data-method="card">
              <span class="material-symbols-outlined">credit_card</span>
              <span>Card</span>
            </div>
            <div class="pay-method__opt" data-method="fpx">
              <span class="material-symbols-outlined">account_balance</span>
              <span>FPX</span>
            </div>
            <div class="pay-method__opt" data-method="grabpay">
              <span class="material-symbols-outlined">qr_code</span>
              <span>GrabPay</span>
            </div>
          </div>

          <!-- Card fields -->
          <div class="stripe-field">
            <label>Card number</label>
            <div class="stripe-input">
              <input type="text" value="4242 4242 4242 4242" placeholder="1234 1234 1234 1234" autocomplete="cc-number" />
              <span class="card-brands"><span>VISA</span><span>MC</span><span>AMEX</span></span>
            </div>
          </div>
          <div class="stripe-row">
            <div class="stripe-field">
              <label>Expiration</label>
              <div class="stripe-input"><input type="text" value="12 / 28" placeholder="MM / YY" autocomplete="cc-exp" /></div>
            </div>
            <div class="stripe-field">
              <label>CVC</label>
              <div class="stripe-input"><input type="text" value="123" placeholder="CVC" autocomplete="cc-csc" /></div>
            </div>
          </div>

          <div class="stripe-field">
            <label>Name on card</label>
            <div class="stripe-input"><input type="text" value="Faiz Fadhillah" placeholder="Full name" autocomplete="cc-name" /></div>
          </div>

          <div class="stripe-row">
            <div class="stripe-field">
              <label>Country</label>
              <div class="stripe-input">
                <input type="text" value="Malaysia" placeholder="Country" />
                <span class="material-symbols-outlined" style="color:var(--medium-grey);">expand_more</span>
              </div>
            </div>
            <div class="stripe-field">
              <label>Postal code</label>
              <div class="stripe-input"><input type="text" value="50480" placeholder="ZIP / Postcode" /></div>
            </div>
          </div>

          <label class="stripe-check">
            <input type="checkbox" checked />
            <span>Save this card securely for future purchases (encrypted by Stripe).</span>
          </label>
          <label class="stripe-check">
            <input type="checkbox" checked />
            <span>I agree to Mereka Academy's <a href="#" onclick="return false;">Terms of Enrolment</a> and <a href="#" onclick="return false;">Refund Policy</a>.</span>
          </label>

          <button type="submit" class="pay-now" id="payNowBtn">
            <span class="material-symbols-outlined">lock</span>
            Pay <span id="payAmount">${fmt(total)}</span> &amp; enrol
          </button>

          <div class="pay-secure">
            <span class="material-symbols-outlined" style="font-size:14px;">shield</span>
            256-bit TLS · PCI DSS compliant · Processed by Stripe
          </div>
        </form>
      </div>

      <!-- RIGHT: Order summary -->
      <aside class="checkout-card order-summary">
        <div class="order-summary__head">
          <div class="order-summary__thumb" id="orderThumb">${image ? '<img src="' + image + '" alt="" style="width:100%; height:100%; object-fit:cover; border-radius:10px;" />' : '<span class="material-symbols-outlined">insights</span>'}</div>
          <div>
            <p class="order-summary__title">${esc(name)}</p>
            <span class="order-summary__meta">${esc(org)} · ${pacing === 'instructor' ? 'Cohort starts ' + start : 'Self-paced'}</span>
          </div>
        </div>

        <div class="order-summary__line"><span>Course fee</span><span>${fmt(fee)}</span></div>
        <div class="order-summary__line"><span>Early-cohort discount</span><span style="color:var(--success);">− ${fmt(discount)}</span></div>
        <div class="order-summary__line"><span>Subtotal</span><span>${fmt(subtotal)}</span></div>
        <div class="order-summary__line"><span>SST (6%)</span><span>${fmt(tax)}</span></div>

        <div class="order-summary__coupon">
          <input type="text" placeholder="Add coupon or voucher" id="couponInput" />
          <button type="button" id="couponBtn">Apply</button>
        </div>

        <div class="order-summary__line is-total">
          <span>Total due today</span><span id="sumTotal">${fmt(total)}</span>
        </div>

        <div class="order-summary__guarantee">
          <span class="material-symbols-outlined">verified</span>
          <div>
            <strong>14-day refund guarantee.</strong> If the cohort isn't right for you, we'll refund every cent — no questions asked.
          </div>
        </div>
      </aside>
    </div>
  </main>`;

  wireCheckout(rootEl, courseId);
}

function wireCheckout(rootEl, courseId) {
  // Payment method switcher
  const opts = rootEl.querySelectorAll('.pay-method__opt');
  opts.forEach(o => o.addEventListener('click', () => {
    opts.forEach(x => x.classList.toggle('is-active', x === o));
  }));

  // Coupon apply
  const couponBtn = rootEl.querySelector('#couponBtn');
  const couponInput = rootEl.querySelector('#couponInput');
  if (couponBtn && couponInput) {
    couponBtn.addEventListener('click', () => {
      const code = couponInput.value.trim();
      if (!code) return;
      couponBtn.textContent = 'Applied!';
      couponBtn.style.color = 'var(--success)';
      setTimeout(() => { couponBtn.textContent = 'Apply'; couponBtn.style.color = ''; }, 2000);
    });
  }

  // Form submit — simulate payment
  const form = rootEl.querySelector('#checkoutForm');
  if (form) {
    form.addEventListener('submit', (e) => {
      e.preventDefault();
      const btn = rootEl.querySelector('#payNowBtn');
      if (!btn || btn.disabled) return;
      const orig = btn.innerHTML;
      btn.disabled = true;
      btn.style.opacity = '0.7';
      btn.innerHTML = '<span class="material-symbols-outlined" style="font-size:18px; animation:spin 1s linear infinite;">progress_activity</span> Processing payment…';
      setTimeout(() => {
        btn.disabled = false;
        btn.style.opacity = '';
        btn.innerHTML = orig;
        window.goto ? window.goto('enrollment-success') : (window.location.href = '/enrolled/' + encodeURIComponent(courseId));
      }, 1500);
    });
  }
}

function esc(s) { return String(s || '').replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;'); }
