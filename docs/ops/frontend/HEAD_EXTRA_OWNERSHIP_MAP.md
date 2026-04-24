# head-extra.html Ownership Correction Map

> **Status**: Generated 2026-03-18 after live proof at `academyv2.mereka.dev`
> **Branch**: `fix/libsass-css4-rgb-compat` (mereka-lms) + `76b374d1` (bbi-infrastructure)

## Purpose

`head-extra.html` serves as a **runtime bridge** — a ConfigMap that injects CSS fixes
into the live LMS without requiring an image rebuild. Every rule here should eventually
live in its permanent layer. This map tracks which rules are already redundant with the
compiled theme and which still need migration.

## Layer Hierarchy (CSS cascade order in browser)

```
Position  File                              Source
─────────────────────────────────────────────────────────────────────
  983     lms-style-vendor.css              Bootstrap/Paragon (never edit)
 1101     lms-main-v1.css                   Tutor-compiled theme — includes:
            ├── stock Open edX CSS
            ├── build-lms-v1.css (OVERRIDES many Mereka rules)
            └── _custom.scss (compiled LAST → wins at equal specificity)
 3675     mereka-overrides.css              staticfiles volume (read-only at runtime)
 3798     <style id="mereka-course-card-hotfix">  ← head-extra.html ConfigMap (LAST)
```

The head-extra `<style>` block is the **last stylesheet** in the document.
Equal-specificity rules here win in cascade order. This is why it works as a bridge.

## Rule Classification

### LEGEND
- `DUPE_SCSS` — Already in `_custom.scss`. Safe to remove from head-extra after next image rebuild.
- `SCSS_ONLY` — Only in head-extra (not in `_custom.scss`). Must be added to `_custom.scss` before removing from head-extra.
- `OVERRIDES_CSS` — Covered in `mereka-overrides.css` (staticfiles). Head-extra bridges runtime.
- `RUNTIME_ONLY` — Must stay in head-extra (env-specific or requires ConfigMap override pattern).

---

### Block 1: Course card layout fixes (lines 27–142)
**Classification**: `SCSS_ONLY` → migrate to `_custom.scss`

| Rule | Status |
|------|--------|
| `.courses-listing li, .courses-listing-item` — flex display | Not in `_custom.scss` |
| `.dashboard .listing-courses` — grid layout | Not in `_custom.scss` |
| `.dashboard .my-courses .listing-courses` — flex column | Not in `_custom.scss` |
| `.dashboard .my-courses .course-item .course` — card border/radius | Not in `_custom.scss` |
| `.dashboard .my-courses .course-item .wrapper-course-image` | Not in `_custom.scss` |
| `.course .course-image` — min-height + gradient bg | Not in `_custom.scss` |
| `.course .course-image .cover-image` — height + relative | Not in `_custom.scss` |
| `.course .course-image img` — object-fit | Not in `_custom.scss` |
| `.course .course-info` — flex column | Not in `_custom.scss` |

**Action**: Add to `_custom.scss` before removing from head-extra.

---

### Block 2: Header layout rules (lines 152–222)
**Classification**: `OVERRIDES_CSS` — authoritative rules in `mereka-overrides.css`

| Rule | Status |
|------|--------|
| `.global-header { position: sticky; overflow: visible !important; }` | `_custom.scss` has `overflow: visible` via separate rule |
| `.main-header` flex layout | In `mereka-overrides.css` |
| `.header-logo` | In `mereka-overrides.css` |
| `.nav-links` layout | In `mereka-overrides.css` |
| `.nav-item` / `.mobile-nav-item` | In `mereka-overrides.css` |
| `.hamburger-menu` | In `mereka-overrides.css` |
| `.mobile-menu` | In `mereka-overrides.css` |
| `@media (max-width: 768px)` mobile nav | In `mereka-overrides.css` |

**Note**: These are already in `mereka-overrides.css`. They're duplicated in head-extra as a
fallback for cases where the staticfiles volume serves stale content. Keep until mereka-overrides.css
is proven reliably served at runtime.

---

### Block 3: build-lms-v1 specificity overrides — nav buttons (lines 223–256)
**Classification**: `DUPE_SCSS` — already in `_custom.scss` (lines 86–120)

| Rule | `_custom.scss` | head-extra |
|------|---------------|------------|
| `.global-header .nav-links .secondary a.register-btn` | ✅ line 86 | ✅ (bridge) |
| `.global-header .nav-links .secondary a.register-btn:hover/focus` | ✅ line 97 | ✅ (bridge) |
| `.global-header .nav-links .secondary a.sign-in-btn` | ✅ line 105 | ✅ (bridge) |
| `.global-header .nav-links .secondary a.sign-in-btn:hover/focus` | ✅ line 115 | ✅ (bridge) |

**Action**: Remove from head-extra after next image rebuild. `_custom.scss` is authoritative.

---

### Block 4: Global header border-bottom (lines 247–249)
**Classification**: `DUPE_SCSS` — already in `_custom.scss` (line 67)

```css
.global-header { border-bottom: none !important; }
```

Both layers now have `!important`. `_custom.scss` is authoritative after rebuild.

**Action**: Remove from head-extra after next image rebuild.

---

### Block 5: Nav float cancels (lines 250–253)
**Classification**: `DUPE_SCSS` — already in `_custom.scss` (lines 183–193)

```css
@media (min-width: 992px) {
  .global-header .nav-links .main { float: none; margin: 0; margin-right: auto; }
  .global-header .nav-links .secondary { float: none; margin: 0; }
}
```

**Action**: Remove from head-extra after next image rebuild.

---

### Block 6: Eyebrow magenta colour (lines 255–257)
**Classification**: `DUPE_SCSS` — already in `_custom.scss` (line 132)

```css
.mereka-hero .eyebrow { color: var(--mereka-color-magenta, #ab3b78) !important; }
```

**Action**: Remove from head-extra after next image rebuild.

---

### Block 7: learn-more 0,6,0 overlay fix (lines 258–276)
**Classification**: `DUPE_SCSS` — already in `_custom.scss` (lines 210–222)

```css
.courses-container .courses .course .course-image .cover-image .learn-more {
  opacity: 1; position: absolute; top: auto; bottom: 0.75rem; left: 50%;
  transform: translateX(-50%); z-index: 2; white-space: nowrap;
  width: auto; height: auto; border-radius: 999px; box-sizing: border-box;
}
```

**Note**: `_custom.scss` currently lacks `position: absolute`, `z-index`, `white-space`, `box-sizing`.
These should be added before removing from head-extra.

**Action**: Add missing properties to `_custom.scss`, then remove from head-extra after image rebuild.

---

### Block 8: User dropdown z-index (lines 278–287)
**Classification**: `SCSS_ONLY` → migrate to `_custom.scss`

```css
.global-header .nav-links .secondary .dropdown-user-menu {
  z-index: 1001; position: absolute; top: 55px; right: 30px;
}
```

Not in `_custom.scss`. Required for logged-in user menu accessibility.

**Action**: Add to `_custom.scss` before removing from head-extra.

---

### Block 9: Dashboard logged-in shell — wrapper-course-image (lines 289–359)
**Classification**: `SCSS_ONLY` → migrate to `_custom.scss`

Overrides build-lms-v1 `display:none` on `.wrapper-course-image` at 0,6,0 specificity.
Also sets horizontal flex layout for course cards in the logged-in dashboard.

Not in `_custom.scss`. Required for the logged-in learner dashboard.

**Action**: Add to `_custom.scss` before removing from head-extra.

---

## Cleanup Checklist (After Next Governed Open edX Publish + Rollout)

After the next governed Open edX image publish and runtime rollout
(`.github/workflows/build-tutor-images.yml` plus GitOps promotion):

- [ ] Remove Block 3 (nav buttons — `DUPE_SCSS`)
- [ ] Remove Block 4 (border-bottom — `DUPE_SCSS`)
- [ ] Remove Block 5 (nav float cancels — `DUPE_SCSS`)
- [ ] Remove Block 6 (eyebrow — `DUPE_SCSS`)
- [ ] Remove Block 7 ONLY AFTER adding `position:absolute; z-index:2; white-space:nowrap; box-sizing:border-box` to `_custom.scss`

**Do NOT remove yet:**
- Block 1 (course card layout) — add to `_custom.scss` first
- Block 2 (header layout) — verify mereka-overrides.css is reliably served first
- Block 8 (dropdown z-index) — add to `_custom.scss` first
- Block 9 (dashboard cards) — add to `_custom.scss` first

## Dev Frontend Gap Matrix

Issues observed in live dev screenshots (2026-03-18):

| Surface | Issue | Severity | Owner Layer | Status |
|---------|-------|----------|-------------|--------|
| Homepage | Hero renders correctly | — | theme | ✅ PASS |
| Homepage | LEARN MORE pills at bottom-center | — | head-extra (bridge) | ✅ PASS |
| Homepage | No border separator under header | — | head-extra + `_custom.scss` | ✅ PASS |
| Homepage | Register=magenta, Sign in=teal | — | head-extra + `_custom.scss` | ✅ PASS |
| /courses | Course grid (not float layout) | — | `_custom.scss` | ✅ PASS |
| /courses | LEARN MORE pills | — | head-extra (bridge) | ✅ PASS |
| /courses | Sidebar filter text raw (modes/audit/org) | Low | stock Open edX | ⚠️ STOCK |
| /login (MFE) | Brand panel + Mereka colours | — | MFE brand | ✅ PASS |
| /login (MFE) | Submit button pre-hydration looks plain | Low | React hydration | ℹ️ EXPECTED |
| Dashboard | Course image visible, horizontal layout | — | head-extra (bridge) | ✅ PASS |
| Dashboard | User dropdown accessible | — | head-extra (bridge) | ✅ PASS |

**Sidebar filter raw text** on /courses: `modes`, `audit`, `org`, `MEREKA`, `language`, `en` appear as
plain text list rather than styled checkbox filters. This is stock Open edX behavior on the
`/courses` page (course discovery app). Not a Mereka CSS regression — stock theme behavior.
