// Page: Unit Player — ported from prototype screen-unit
// Uses .player grid layout: main (left) + side (right)
export async function render(rootEl, { params } = {}) {
  rootEl.innerHTML = `
  <div class="player">
    <div class="player__main">
      <div class="player__content">
        <div class="player__video">
          <div style="background:#1A1623; border-radius:12px; aspect-ratio:16/9; display:flex; align-items:center; justify-content:center;">
            <span class="material-symbols-outlined" style="font-size:64px; color:var(--white); opacity:0.6;">play_circle</span>
          </div>
        </div>
        <div class="player__info" style="padding:24px 0;">
          <h2>Frameworks for ambiguity</h2>
          <p style="color:var(--medium-grey);">Learn how to navigate uncertainty using mental models that help leaders make better decisions with incomplete information.</p>
          <div style="display:flex; gap:12px; margin-top:16px; flex-wrap:wrap;">
            <button class="btn btn--outline btn--sm"><span class="material-symbols-outlined" style="font-size:16px;">bookmark</span> Bookmark</button>
            <button class="btn btn--outline btn--sm"><span class="material-symbols-outlined" style="font-size:16px;">download</span> Resources</button>
            <div style="flex:1;"></div>
            <button class="btn btn--primary btn--sm">Next unit <span class="material-symbols-outlined" style="font-size:16px;">arrow_forward</span></button>
          </div>
        </div>
      </div>
    </div>
    <div class="player__side">
      <div class="player__side-head">
        <a href="/" class="btn btn--ghost btn--sm" style="margin-bottom:8px;"><span class="material-symbols-outlined" style="font-size:16px;">arrow_back</span> Back</a>
        <h4>Strategic thinking for modern leaders</h4>
        <div class="progress"><div class="progress__fill" style="width:60%;"></div></div>
      </div>
      <div class="side-module">
        <div class="side-unit is-done"><span class="material-symbols-outlined" style="font-size:16px;">check_circle</span> Welcome &amp; orientation</div>
        <div class="side-unit is-done"><span class="material-symbols-outlined" style="font-size:16px;">check_circle</span> Strategic vs tactical thinking</div>
        <div class="side-unit is-active"><span class="material-symbols-outlined" style="font-size:16px;">play_circle</span> Frameworks for ambiguity</div>
        <div class="side-unit"><span class="material-symbols-outlined" style="font-size:16px;">description</span> Case study: Grab's pivot</div>
        <div class="side-unit"><span class="material-symbols-outlined" style="font-size:16px;">quiz</span> Module quiz</div>
      </div>
    </div>
  </div>`;
}
