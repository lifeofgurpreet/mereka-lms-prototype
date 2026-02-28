# CSS Scoping Audit — Mereka Theme Global Overrides

**Status**: AUDIT COMPLETE (living reference for T105/T106 follow-ups)
**Audited**: 2026-02-25
**Last updated**: 2026-02-28
**Scope**: All SCSS/CSS in `infrastructure/tutor/themes/mereka/`

---

## 2026-02-28 Addendum (Dead Selector Cleanup)

- `[class*="authn"]`, `[class*="learner-dashboard"]`, `[class*="learning"]`, and `[class*="discussions"]` fallback blocks were removed from `mereka.scss` after live DOM verification showed they were dead selectors.
- Remaining wildcard scope is `"[class*=\"account-settings\"]"` with explicit `SELECTOR-EXCEPTION` annotations and expiry notes in source.
- QA contract now enforces this directly in active selectors (comments are ignored by the gate):
  - live scope present: `class*="account-settings"`
  - dead scopes absent: `authn`, `learner-dashboard`, `learning`, `discussions`
- Global runtime/base selector hardening (`body`, headings, links, primary buttons) was completed on 2026-02-28 via `body:not(.courseware)` scoping in `common/mereka-overrides.css` and `scss/_base.scss`.
- Sections 1.2–1.6 and older gap notes are historical context from the pre-hardening snapshot; rely on Section 5 summary + `verify-css-scoping.sh` as current truth.

---

## Files Audited

| File | Role |
|------|------|
| `scss/_tokens.scss` | SCSS variable bridge + `:root` custom props + global element rules |
| `scss/theme.scss` | LMS/CMS component rules (imports _tokens) |
| `mfe/mereka.scss` | MFE-specific overrides (imports scss/theme) |
| `common/static/css/mereka-overrides.css` | Runtime CSS for both LMS + Studio (no build step) |
| `lms/static/css/mereka-overrides.css` | LMS-only copy of common overrides (parity file) |
| `cms/static/css/mereka-overrides.css` | CMS-only copy of common overrides (parity file) |

---

## Scoping Definitions

| Term | Meaning |
|------|---------|
| **Global** | Selector matches any element on the page, regardless of context |
| **Page-scoped** | Selector is prefixed with a page-context class (`.dashboard`, `.courseware`, `.find-courses`) |
| **XBlock-adjacent** | Selector could match inside an XBlock's rendered output |
| **`.mereka-theme` candidate** | Could be safely re-scoped without changing applied surface |

---

## Section 1 — `_tokens.scss` Global Overrides

### 1.1 `:root` custom property block (lines 37–74)

**Selector**: `:root`
**Properties**: `--mereka-*` and `--pgn-*` CSS custom properties
**XBlock impact**: None — custom props do not apply rules; XBlocks read them only if they use `var()`.
**Scopeable under `.mereka-theme`?**: No — `:root` is the correct scope for design tokens that must be inherited everywhere. Moving to `.mereka-theme` would break MFE components that read `--pgn-*` variables from `:root`.
**Recommendation**: KEEP as `:root`.

---

### 1.2 `body` rule (lines 97–101)

```scss
body {
  font-family: $mereka-body-font;
  background-color: $color-neutral-100;
  color: $color-ink-900;
}
```

**Selector**: `body`
**XBlock impact**: Indirect — sets font and color cascade that flows into XBlocks.
**Risk if left global**: XBlocks that set their own `font-family` internally are unaffected. For XBlocks that do not set their own fonts (most text-content XBlocks), this is the intended brand application.
**Scopeable under `.mereka-theme`?**: Technically no — `body` cannot be nested under another class. If the LMS `<body>` were given class `mereka-theme`, an equivalent rule `body.mereka-theme` could replace it. This is a **future work** item (requires template change).
**Recommendation**: KEEP global. Document as a known gap — see Section 5.

---

### 1.3 Heading elements `h1`–`h6` (lines 103–112)

```scss
h1, h2, h3, h4, h5, h6 {
  font-family: $mereka-heading-font;
  font-weight: 600;
  color: $color-ink-900;
}
```

**Selector**: Element-level, global
**XBlock impact**: **HIGH** — This rule applies the Mereka heading font and ink-900 colour to ALL headings, including headings inside XBlock rendered content, discussion threads, video transcripts, and problem XBlocks.
**Scopeable under `.mereka-theme`?**: Yes, if `body` or a wrapping container gets the `mereka-theme` class. The equivalent scoped rule would be `.mereka-theme h1, .mereka-theme h2, ...`. In practice, XBlocks are rendered inside `.courseware .xblock` which already exists in `lms/static/css/mereka-overrides.css` and scopes headings correctly with `color: var(--mereka-color-ink-900)`. The global `_tokens.scss` rule is therefore **redundant** for XBlocks — it only risks overriding XBlock custom heading colours if an XBlock relies on browser defaults.
**Recommendation**: CANDIDATE FOR SCOPING. Priority P2.

---

### 1.4 Anchor `a` rule (lines 114–123)

```scss
a {
  color: $color-info;
  text-decoration-thickness: 2px;
  text-underline-offset: 3px;
  &:hover, &:focus { color: $color-teal; }
}
```

**Selector**: Element-level, global
**XBlock impact**: **HIGH** — Overrides link colour in ALL XBlocks (problem feedback links, video links, discussion links). XBlocks that rely on the browser's default blue link colour for embedded `<a>` tags will receive Mereka blue instead.
**Scopeable under `.mereka-theme`?**: Yes. The `lms/static/css/mereka-overrides.css` already scopes link colour correctly under `.courseware .xblock a`. The global rule in `_tokens.scss` is applied to SCSS-built output where XBlocks are inside `.courseware`, making the global rule cascade into XBlocks.
**Recommendation**: CANDIDATE FOR SCOPING. Priority P2. The `text-decoration-thickness` and `text-underline-offset` are purely cosmetic and safe to apply globally if desired; the colour override is the higher-risk part.

---

### 1.5 `.btn-primary`, `.btn-outline-primary` (lines 125–129)

```scss
.btn-primary, .btn-outline-primary {
  letter-spacing: 0.01em;
  text-transform: none;
}
```

**Selector**: Bootstrap button class, global
**XBlock impact**: **MEDIUM** — Many XBlocks render submit, hint, and show-answer buttons with `.btn-primary`. This override applies `letter-spacing` and `text-transform: none` to all of them.
**Scopeable under `.mereka-theme`?**: Yes. However, the effect is cosmetic (no layout-breaking change). XBlocks with custom `letter-spacing` would have their value overridden.
**Recommendation**: CANDIDATE FOR SCOPING. Priority P3 (cosmetic only).

---

### 1.6 `.card` (lines 131–135)

```scss
.card {
  border-radius: 24px;
  border-color: rgba(26, 22, 35, 0.08);
  box-shadow: var(--mereka-shadow-card);
}
```

**Selector**: Bootstrap card class, global
**XBlock impact**: **HIGH** — XBlocks that use Bootstrap's `.card` component (e.g. some problem XBlocks, discussion XBlocks) will receive a 24px border-radius and Mereka box-shadow. This can visually break XBlocks designed with a flat card aesthetic.
**Scopeable under `.mereka-theme`?**: Yes. The MFE SCSS already applies `.card` styling under `[class*="learning"]` and `[class*="discussions"]` scopes. The global rule in `_tokens.scss` is the most dangerous one.
**Recommendation**: PRIORITY CANDIDATE FOR SCOPING. P1 within T105 scope.

---

## Section 2 — `scss/theme.scss` Overrides

### 2.1 `:root` gradient + radius variables (lines 4–7)

**Selector**: `:root`
**Properties**: `--mereka-gradient-primary`, `--mereka-radius-xl`
**XBlock impact**: None — CSS custom props only.
**Recommendation**: KEEP as `:root`.

---

### 2.2 `.global-header`, `.wrapper-header`, `.nav-wrapper` (lines 51–57)

```scss
.global-header, .wrapper-header, .nav-wrapper {
  background: #fff;
  border-bottom: 1px solid rgba(26, 22, 35, 0.08);
  box-shadow: 0 10px 30px rgba(26, 22, 35, 0.05);
}
```

**Selector**: Open edX LMS-specific layout classes
**XBlock impact**: None — these are page-chrome classes, not rendered inside XBlocks.
**Recommendation**: KEEP. These are LMS-specific slots that do not appear in XBlocks.

---

### 2.3 `.home.style-logout header` (lines 96–102)

**Selector**: LMS homepage context `.home.style-logout` prefixing `header`
**XBlock impact**: None — logged-out homepage only, no XBlock context.
**Recommendation**: KEEP. Already page-scoped.

---

### 2.4 `.courses-container`, `.course`, `.courses-listing` etc. (lines 176–300)

**Selector**: LMS course discovery and catalogue classes
**XBlock impact**: **MEDIUM** for `.course` — the `.course` class is fairly broad and could match `.course` children inside an XBlock that happens to render a nested "course" widget (rare, but possible in some content XBlocks).
**Scopeable under `.mereka-theme`?**: The `lms/static/css/mereka-overrides.css` scopes all `.course` rules correctly under `.dashboard .course` or `.courses-listing .course`. The naked `.course` rules in `theme.scss` are redundant and extend globally.
**Recommendation**: CANDIDATE FOR SCOPING. Low urgency (the `.course` class is unlikely inside an XBlock), but best practice suggests removing the duplication.

---

### 2.5 `.dashboard .listing-courses`, `.dashboard .course ...` (lines 302–381)

**Selector**: `.dashboard` prefixed — page-scoped
**XBlock impact**: None — `.dashboard` is the LMS learner dashboard page wrapper; XBlocks do not appear here.
**Recommendation**: KEEP. Already page-scoped.

---

### 2.6 `.courseware .xblock` (lines 427–433)

```scss
.courseware .xblock {
  background: #fff;
  border-radius: 18px;
  border: 1px solid rgba(26, 22, 35, 0.08);
  padding: 1.25rem;
  margin-bottom: 1.25rem;
}
```

**Selector**: `.courseware .xblock` — page-scoped to courseware, targets XBlock container
**XBlock impact**: **INTENTIONAL** — This styles the outer shell of every XBlock rendered in the courseware. It does NOT penetrate inside the XBlock's internal DOM. This is the correct approach: branding the XBlock chrome, not the XBlock content.
**Recommendation**: KEEP. This is intentional scoping and the correct pattern.

---

### 2.7 `.wrapper-view`, `body[class*="view-"]` Studio rules (lines 783–860)

**Selector**: Studio view-class prefixed
**XBlock impact**: `.view-container .xblock-render .xblock` — applies border-radius and box-shadow to the Studio preview of XBlocks. Same rationale as 2.6: this is the XBlock chrome shell, not the XBlock content.
**Recommendation**: KEEP. Intentional Studio chrome scoping.

---

### 2.8 `.wrapper-content .action-secondary`, `.btn-default` (lines 844–860)

```scss
.wrapper-content .action-secondary, ...
.btn-default {
  border-radius: 999px;
  ...
}
.btn-default:hover, .btn-default:focus { ... }
```

**Selector**: `.btn-default` is **global** — no page-scope prefix
**XBlock impact**: **MEDIUM** — `.btn-default` is a Bootstrap 3 class used by some older XBlocks and Open edX problem components for secondary/cancel buttons. Applying `border-radius: 999px` to it globally will pill-ify all such buttons across all XBlocks.
**Scopeable under `.mereka-theme`?**: Yes. The `.wrapper-content .action-secondary` half is already scoped. Only the bare `.btn-default` rules need scoping.
**Recommendation**: CANDIDATE FOR SCOPING. Priority P2.

---

## Section 3 — `mfe/mereka.scss` Overrides

### 3.1 `body` (lines 16–22)

```scss
body {
  min-height: 100vh;
  background-color: var(--mereka-color-surface-primary);
  background-image: radial-gradient(...), ...;
}
```

**Selector**: Element-level, global within MFE context
**XBlock impact**: MFEs do not render XBlocks (they are separate React apps). No XBlock impact.
**Recommendation**: KEEP. MFE context only.

---

### 3.2 `.navbar` and `.navbar .navbar-brand` (lines 31–53)

**Selector**: Bootstrap navbar classes, global within MFE
**XBlock impact**: MFEs do not render XBlocks. No impact.
**Scopeable under `.mereka-theme`?**: Not necessary — MFE pages have a single `<body>` with one navbar; there is no multi-context risk.
**Recommendation**: KEEP. MFE context only.

---

### 3.3 `.btn-primary`, `.pgn__btn--primary` (lines 72–92)

**Selector**: Global within MFE
**XBlock impact**: MFEs do not render XBlocks. No impact.
**Recommendation**: KEEP. MFE context only.

---

### 3.4 `.card`, `.shadow-lg`, `.pgn__card` (lines 145–151)

```scss
.card, .shadow-lg, .pgn__card {
  border-radius: 24px;
  border: 1px solid rgba(26, 22, 35, 0.08);
  box-shadow: var(--mereka-mfe-card-shadow);
}
```

**Selector**: Global within MFE; `.shadow-lg` is a Bootstrap utility
**XBlock impact**: MFEs do not render XBlocks. However, `.shadow-lg` is an extremely broad utility class — anything in the MFE with `shadow-lg` will receive Mereka's card border-radius, which may break components that use `shadow-lg` for non-card purposes (e.g. tooltips, overlays).
**Scopeable under `.mereka-theme`?**: The `.shadow-lg` part is the most problematic. This should be removed from this rule group, or scoped to `.pgn__card.shadow-lg`.
**Recommendation**: CANDIDATE FOR REFINEMENT. Low priority (MFE only), but `.shadow-lg` overapplication is a risk. Priority P3.

---

### 3.5 `.pgn__form-control`, `.form-control` (lines 122–135)

**Selector**: Global within MFE
**XBlock impact**: MFEs do not render XBlocks. No impact in MFE context.
**Recommendation**: KEEP. MFE context only.

---

### 3.6 `label` (lines 138–142)

```scss
.pgn__form-label, label {
  font-weight: 600;
  color: var(--mereka-color-ink-700);
}
```

**Selector**: Element-level `label`, global within MFE
**XBlock impact**: MFEs do not render XBlocks. No impact in MFE context.
**Recommendation**: KEEP. MFE context only. Note: `label` here only affects MFE pages.

---

### 3.7 `.nav-tabs .nav-link`, `.pgn__tabs .nav-link` (lines 213–224)

**Selector**: Global within MFE
**XBlock impact**: MFE context only.
**Recommendation**: KEEP. MFE context only.

---

### 3.8 MFE Surface Scopes (post-cleanup baseline)

Active wildcard scope is now limited to `[class*="account-settings"]` (with documented `SELECTOR-EXCEPTION` annotations in source). Dead wildcard scopes (`authn`, `learner-dashboard`, `learning`, `discussions`) were removed.

**XBlock impact**: None — MFE route-level wrappers are outside LMS XBlock rendering.
**Recommendation**: KEEP `account-settings` temporarily (exception-tracked), continue Phase D migration toward slot/explicit wrapper replacements.

---

## Section 4 — `common/static/css/mereka-overrides.css` (Runtime CSS)

### 4.1 `html, body` (lines 165–170)

```css
html, body {
  font-family: var(--mereka-font-body);
  background-color: var(--mereka-color-surface-primary);
  color: var(--mereka-black);
}
```

**Selector**: Element-level, global
**XBlock impact**: Same as `_tokens.scss` body rule — sets cascade that flows into XBlocks.
**Scopeable under `.mereka-theme`?**: Requires body-level class change (template modification).
**Recommendation**: KNOWN GAP. Document for T106+ (requires Tutor template patch). Priority P3.

---

### 4.2 `h1`–`h6`, `.hd-1`–`.hd-4` (lines 172–184)

```css
h1, h2, h3, h4, h5, h6, .hd-1, .hd-2, .hd-3, .hd-4 {
  font-family: var(--mereka-font-heading);
  font-weight: 600;
}
```

**Selector**: Element-level, global
**XBlock impact**: **HIGH** — Same as `_tokens.scss` heading rule. Applies Mereka heading font to ALL headings, including those inside XBlocks.
**Scopeable under `.mereka-theme`?**: Yes, with template change OR by adding `.courseware` / `.dashboard` prefix to all heading rules (content is already in page-scoped variants in the same file).
**Recommendation**: CANDIDATE FOR SCOPING. Priority P2. Note: The `lms/static/css/mereka-overrides.css` already scopes heading font inside `.courseware .xblock` (lines 999–1009). The global rule at the top of the file is therefore partially redundant for XBlock context.

---

### 4.3 `a`, `a:hover`, `a:focus` (lines 186–195)

```css
a { color: var(--mereka-blue); ... }
a:hover, a:focus { color: var(--mereka-teal); }
```

**Selector**: Element-level, global
**XBlock impact**: **HIGH** — Overrides default link colour in ALL XBlocks.
**Scopeable under `.mereka-theme`?**: Yes. Already scoped correctly under `.courseware .xblock a` (lines 1021–1028). The global rule is redundant for XBlock context.
**Recommendation**: CANDIDATE FOR SCOPING. Priority P2.

---

### 4.4 `.btn-primary`, `.btn-brand`, `.btn-outline-primary` (lines 197–217)

```css
.btn-primary, .btn-brand, button.btn.btn-primary {
  background-color: var(--mereka-magenta);
  border-color: var(--mereka-magenta);
  border-radius: 999px;
}
.btn-outline-primary { border-radius: 999px; }
```

**Selector**: Bootstrap button classes, global
**XBlock impact**: **HIGH** — Problem XBlocks (capa), video XBlocks, and custom XBlocks all render `<button class="btn btn-primary">` for submit/hint/action buttons. These will receive pill-shaped Mereka magenta styling.
**Scopeable under `.mereka-theme`?**: Yes. The courseware context scopes `.courseware .xblock .problem button` correctly (lines 1030–1034). The global `.btn-primary` rule overrides this from above.
**Recommendation**: **TOP PRIORITY CANDIDATE FOR SCOPING**. P1. This is the most impactful global override for XBlocks.

---

### 4.5 `.header-global`, `.nav-global` (lines 219–222)

**Selector**: Open edX-specific header classes
**XBlock impact**: None — these are page-chrome slots.
**Recommendation**: KEEP.

---

### 4.6 `.find-courses` subtree (lines 228–447)

**Selector**: All rules prefixed with `.find-courses`
**XBlock impact**: None — course discovery page, no XBlocks.
**Recommendation**: KEEP. Already page-scoped.

---

### 4.7 `.course-info`, `.course-about` subtrees (lines 449–567)

**Selector**: Page-scoped to course about/info pages
**XBlock impact**: None — course marketing pages, no XBlocks.
**Recommendation**: KEEP. Already page-scoped.

---

### 4.8 `.courses-listing`, `.courses-listing li`, `.courses-listing-item` (lines 569–582)

**Selector**: Global — no page-scope prefix
**XBlock impact**: Very low — `.courses-listing` is an LMS catalogue class. It is extremely unlikely to appear inside an XBlock.
**Scopeable under `.mereka-theme`?**: Yes, but risk is minimal.
**Recommendation**: LOW PRIORITY. Could be prefixed with `.find-courses` or `.home` but XBlock risk is negligible.

---

### 4.9 `.course` (lines 584–605)

```css
.course {
  background: #fff;
  border-radius: 28px;
  border: 1px solid rgba(26, 22, 35, 0.08);
  box-shadow: var(--mereka-shadow-card);
  overflow: hidden;
  transition: transform 180ms ease, box-shadow 180ms ease;
}
```

**Selector**: Global `.course` class — no page prefix
**XBlock impact**: **MEDIUM** — Some XBlocks use `.course` internally (e.g. course XBlocks in nested contexts). Applying `overflow: hidden` and `border-radius: 28px` globally to `.course` can clip XBlock content.
**Scopeable under `.mereka-theme`?**: Yes. The file already has correctly-scoped variants under `.dashboard .my-courses .course-item .course` and `.courses-listing-item > .course`.
**Recommendation**: CANDIDATE FOR SCOPING. Priority P2.

---

### 4.10 `.wrapper-content` (lines 1041–1063) — LMS-side Studio chrome

```css
.wrapper-content {
  background: var(--mereka-color-surface-primary);
}
.wrapper-content .content-primary, ...
```

**Selector**: `.wrapper-content` is prefixed — Studio-scoped
**XBlock impact**: `.view-container .xblock-render .xblock` rules apply border-radius to Studio XBlock previews (intentional chrome).
**Recommendation**: KEEP. Intentional Studio chrome.

---

### 4.11 `.courseware .xblock` overrides (lines 991–1034)

All rules are prefixed with `.courseware .xblock`. This is the **correct scoping pattern** — styling the XBlock chrome shell and controlling font/colour inheritance within XBlock content intentionally.

**Recommendation**: KEEP. This is the reference pattern for XBlock-safe CSS scoping.

---

## Section 5 — Summary: Global Overrides with XBlock Impact

| # | Selector | File | XBlock Impact | Priority | Action |
|---|----------|------|--------------|----------|--------|
| G1 | `body` | `_base.scss` + `common/mereka-overrides.css` | Indirect (cascade) | RESOLVED | Scoped to `body:not(.courseware)` on 2026-02-28 |
| G2 | `h1`–`h6` | `_base.scss` + `common/mereka-overrides.css` | HIGH | RESOLVED | Scoped to `body:not(.courseware)` on 2026-02-28 |
| G3 | `a` | `_base.scss` + `common/mereka-overrides.css` | HIGH | RESOLVED | Scoped to `body:not(.courseware)` on 2026-02-28 |
| G4 | `.btn-primary`, `.btn-brand` | `_base.scss` + `common/mereka-overrides.css` | HIGH | RESOLVED | Scoped to `body:not(.courseware)` on 2026-02-28 |
| G5 | `.card` | `_tokens.scss` | HIGH | P1 | Scope under page wrappers or `.mereka-theme` |
| G6 | `.btn-default` | `scss/theme.scss` | MEDIUM | P2 | Scope to `.wrapper-content .btn-default` |
| G7 | `.course` (bare) | `common/mereka-overrides.css` + `scss/theme.scss` | MEDIUM | P2 | Prefix with `.find-courses` or `.dashboard` |
| G8 | `.btn-primary`, `.btn-outline-primary` (letter-spacing) | `_base.scss` | LOW | RESOLVED | Scoped to `body:not(.courseware)` on 2026-02-28 |
| G9 | `.shadow-lg` grouped with `.card` | `mfe/mereka.scss` | N/A (MFE only) | P3 | Separate `.shadow-lg` from `.card` rule group |
| G10 | `.courses-listing` (bare) | `common/mereka-overrides.css` | Very low | P3 | Prefix with `.find-courses` |

---

## Section 6 — Rules That Are Correctly Scoped (Reference Patterns)

These rules demonstrate the correct approach and should be used as templates when re-scoping the candidates above:

| Pattern | Example | Why It's Safe |
|---------|---------|---------------|
| XBlock chrome | `.courseware .xblock { border-radius: 18px; }` | Targets the shell, not XBlock internals |
| XBlock content control | `.courseware .xblock p, li, label { color: ... }` | Intentional cascade into XBlock content with brand colours |
| Page-scoped buttons | `.courseware .xblock .problem button { border-radius: 999px; }` | Scoped to problem XBlock action area |
| Studio views | `.view-container .xblock-render .xblock { ... }` | Scoped to Studio editor context |
| Discovery page | `.find-courses .discovery-button { ... }` | Scoped to /courses page only |
| Dashboard | `.dashboard .listing-courses { ... }` | Scoped to learner dashboard only |
| MFE surface | `[class*="account-settings"] .pgn__card { ... }` | Scoped to active MFE route wrapper |

---

## Section 7 — .mereka-theme Wrapper: Feasibility Assessment

The task references adding a `.mereka-theme` wrapper class as a scoping mechanism. Here is the assessment:

### What `.mereka-theme` would require

1. **Template modification**: The LMS `<body>` or a page wrapper element must be given `class="mereka-theme"` via Tutor templates. This requires a patch in `apply-patches.sh`.
2. **Selector migration**: Every global element selector (`h1`, `a`, `.btn-primary`, `.card`) would need to be prefixed with `.mereka-theme`.
3. **Custom property bridge**: `:root` rules for `--mereka-*` and `--pgn-*` must remain at `:root` — they cannot be moved under `.mereka-theme` because CSS custom properties are inherited, and MFE bundles read them from `:root`.

### What can be safely scoped TODAY (without template change)

The following re-scopings can happen without any template change, using existing page-context classes that are already in the Open edX markup:

| Current global | Safe scope target | Notes |
|---------------|-------------------|-------|
| `.btn-primary` | `.header-global .btn-primary`, `.wrapper-content .btn-primary`, `.courseware .btn-primary` | Leaves XBlock problem buttons unstyled (uses `.courseware .xblock .problem button` instead) |
| `.card` | `.dashboard .card`, `.find-courses .card`, `.courseware .card` | The LMS renders `.card` in dashboard and discovery contexts |
| `.course` (bare) | `.find-courses .course`, `.dashboard .course` | Both variants already exist in the file |
| `h1`–`h6` | Remove from global; rely on `.courseware .xblock .hd` + `.dashboard` heading rules | Already present in `lms/static/css` |
| `a` | Remove from global; rely on `.courseware .xblock a` + `.dashboard a` + `.find-courses a` | Already present or addable |

### What requires a template change

- Scoping `body` font/background requires `body.mereka-theme { ... }` which requires adding the class to the `<body>` template. This is low-risk and can be done in `apply-patches.sh` as a Jinja2 patch on `templates/lms/static/html/header.html` or equivalent.

---

## Section 8 — Implementation Roadmap (for T106+)

| Phase | Tasks | Est. Effort |
|-------|-------|-------------|
| P1 (blocking) | Scope `.btn-primary` and `.card` away from XBlocks | 2h |
| P2 | Scope `h1`–`h6`, `a`, `.btn-default`, bare `.course` | 4h |
| P3 | Template patch for `body.mereka-theme`; separate `.shadow-lg` | 3h |
| P4 | Automated regression test in `verify-css-scoping.sh` for new rules | 1h |

---

## Section 9 — Decision Log

| Decision | Rationale |
|----------|-----------|
| `:root` custom props stay global | CSS custom props cannot be scoped to a class without losing inheritance in child trees including MFE bundles reading from `:root` |
| `.courseware .xblock` rules are intentional XBlock chrome | These style the outer shell only; XBlock internal DOM is not accessed |
| Studio view-class rules kept | `.view-*` classes are Studio-specific; they do not appear in LMS context |
| MFE overrides (mereka.scss) out of scope for `.mereka-theme` wrapper | MFEs are separate React apps with their own bundle boundary; the `.mereka-theme` concept applies to the legacy LMS/Studio Django templates only |

---

*Audited by: Claude (Sonnet 4.6) per T105 task brief — 2026-02-25*
*Next action: T106 — implement re-scoping for P1 candidates based on this audit*
