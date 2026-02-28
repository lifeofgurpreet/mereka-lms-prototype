# MFE Selector Override Inventory

> Tracks CSS/JS selectors that override MFE default behavior. These are brittle
> because MFE DOM structure changes on every Open edX release.
>
> **AC-MFE-005** — Document risky selector overrides and migration priority.
> **Spec**: `mfe-branding-customization_spec.md`
> **Last scanned**: 2026-02-28 (T102 alignment)

---

## Risk Levels

| Level | Definition | Action |
|-------|-----------|--------|
| **HIGH** | Targets auto-generated hash-based class names (e.g., `.css-1abc2de`) | Migrate to plugin-slot immediately |
| **MEDIUM** | Targets Paragon component internals (`pgn__*`) or `[class*="..."]` wildcards that can shift | Track upstream; migrate when slot is available |
| **LOW** | Targets stable semantic IDs, data attributes, or CSS custom properties | Monitor only |

---

## Current Overrides

### 1. `infrastructure/tutor/themes/mereka/mfe/mereka.scss` (MFE-specific overrides)

This is the primary risk file. It is injected into all MFEs via Tutor's MFE build hook.

| Selector Pattern | Target MFE(s) | Risk | Notes |
|-----------------|---------------|------|-------|
| `.pgn__page-container`, `.pgn__btn--primary`, `.pgn__card`, `.pgn__modal-content`, etc. | All MFEs | **MEDIUM** | Paragon component classes are stable within a Paragon major version but change across major bumps |
| `[class*="authn"]` | Authn/login-route surfaces | **MEDIUM** | Class-based fallback retained where route-level data attributes are not available. |
| `[class*="authn"] .pgn__btn--primary` | Authn MFE | **MEDIUM** | Wildcard class match; tracked as `SELECTOR-EXCEPTION` in source |
| `[class*="account-settings"] .pgn__form-control` | Account MFE | **MEDIUM** | Wildcard class match; tracked as `SELECTOR-EXCEPTION` in source |
| `[class*="learner-dashboard"] [class*="course"]` | Learner Dashboard MFE | **MEDIUM** | Class-based fallback retained until dedicated wrapper slots are available |
| `[class*="learning"] :is(.pgn__card, .card) :is(.pgn__card-image-cap, [class*="image-cap"])` | Learning MFE | **MEDIUM** | Class-based fallback retained; no stable testid for this structure |
**Total selector exception annotations**: 34 comment blocks in `mereka.scss` (`SELECTOR-EXCEPTION`).

**Hash-based selectors** (`css-XXXXXXX`): **0 found** — good, none present.

### Phase D Classification (Task D1)

| Selector/Surface | Classification | Rationale |
|------------------|----------------|-----------|
| `org.openedx.frontend.layout.header_logo.v1` slot output (`MerekaHeaderLogo`) | **SAFE_TO_SLOT** | Header logo shell is now owned by plugin-slot rendering, not brittle DOM-targeted CSS overrides. |
| `.mereka-header-logo`, `.mereka-header-logo img` in `mereka.scss` | **NEEDS_KEEP** | Minimal token-driven presentation layer for the slot output; no upstream DOM dependency beyond our own class names. |
| `org.openedx.frontend.layout.footer.v1` slot output (`MerekaFooter`) | **SAFE_TO_SLOT** | Footer shell structure is injected via FPF slot and default footer is hidden, eliminating dependence on upstream footer DOM. |
| `.footer-*` classes in `mereka.scss` (`_mfe-footer.scss`) | **NEEDS_KEEP** | Styling contract for our own slot-rendered markup; retained as tokenized presentation rules. |
| `[class*="authn"]` fallback block | **NEEDS_KEEP** | No stable upstream authn wrapper slot/semantic hooks cover all route entrypoints yet; kept with explicit selector-exception comments. |
| `[class*="discussions"]` fallback block | **DEAD_SELECTOR** | Removed from `mereka.scss` on 2026-02-28 after dead-selector audit confirmed no live DOM matches. |
| `.pgn__*` component overrides in `mereka.scss` | **NEEDS_KEEP** | Paragon v22 does not expose complete component token coverage for all visual requirements; retained with `var(--mereka-*)` hardening. |

---

### 2. `infrastructure/tutor/themes/mereka/lms/static/css/mereka-overrides.css` (LMS shell overrides)

Applied to the LMS shell page that wraps MFEs (header/footer regions visible before MFE hydration).

| Selector Pattern | Target Surface | Risk | Notes |
|-----------------|----------------|------|-------|
| `.header-global`, `.nav-global` | LMS shell header | **MEDIUM** | These are LMS legacy class names; subject to Open edX template refactors |
| `.find-courses .search-facets .header-search-facets` | Course discovery | **MEDIUM** | 3-level nesting into LMS template structure |
| `.footer-container`, `.footer-social`, `.footer-nav`, `.footer-logo-link`, `.footer-logo-img`, `.footer-brand-name`, etc. | LMS legacy footer | **MEDIUM** | ~30 selectors in legacy Mako footer shell; MFE shell now uses slot replacement, LMS shell selectors retained until LMS migration is completed. |
| `--mereka-*` CSS custom properties | All surfaces | **LOW** | Stable design token contract; no DOM coupling |

---

### 3. `infrastructure/tutor/themes/mereka/common/static/css/mereka-overrides.css` (Common overrides)

Identical content to `lms/static/css/mereka-overrides.css` (dual-path deployment). Same risk profile applies.

---

### 4. `infrastructure/tutor/themes/mereka/common/static/css/mereka-design-tokens.css` (Design tokens)

| Selector Pattern | Target | Risk | Notes |
|-----------------|--------|------|-------|
| `:root { --color-* }` | All surfaces | **LOW** | Pure CSS custom properties; no DOM coupling; stable contract |

---

### 5. `infrastructure/tutor/plugins/mereka_lms.py` (FPF slot injection)

| Override Method | Target | Risk | Notes |
|----------------|--------|------|-------|
| `org.openedx.frontend.layout.footer.v1` via `PLUGIN_OPERATIONS.Insert`/`Hide` | MFE shells | **LOW** | Plugin-slot API is stable; this is the recommended migration path |
| `org.openedx.frontend.layout.header_logo.v1` via `PLUGIN_OPERATIONS.Replace` | MFE shells | **LOW** | Header branding is moved from static CSS overrides to runtime slot output |
| Inline `MerekaFooter` React component emitting `.footer-social`, `.footer-container`, etc. | All MFEs | **MEDIUM** | The emitted class names in the JSX are custom (not Paragon), so they are stable as long as we own the component |
| `org.openedx.frontend.authn.login_component.v1`, learner/learning/account/profile slots | All MFEs | **LOW** | Additional high-value brand surfaces are now injected via dedicated slots |

---

## Migration Priority

### Immediate (before next Tutor upgrade)

1. **`[class*="..."]` wildcard fallbacks in `mereka.scss`** — tracked as `SELECTOR-EXCEPTION` with explicit expiry and rationale.
   These are fallback selectors used where surface-level plugin slots or stable `data-testid`/semantic hooks are not yet available.
   **Action**: Audit each fallback block; keep only where upstream contract is not yet available.

2. **`.header-global` / `.nav-global` in LMS overrides** — LMS template classes.
   **Action**: Verify these class names still exist in the Tutor 21 (Ulmo) LMS templates.
   If removed upstream, the selector is a no-op (silent regression).

### Next release cycle

3. **`pgn__*` selectors in `mereka.scss`** — Paragon 22 → 23 can rename component classes.
   **Action**: Pin selectors to the Paragon version range tested. Add a CI check that fails if `pgn__` class names in use are not present in the installed Paragon package.

4. **LMS legacy footer selectors** (`.footer-container`, `.footer-social`, etc.) — MFE shell now uses slot-inserted footer content.
   **Action**: Keep LMS shell selectors until shell-level equivalent slots are available, then remove these ~30 selectors from `mereka-overrides.css`.

### Monitor only

5. **CSS custom properties (`--mereka-*`, `--color-*`)** — stable; no action needed.

6. **`footer_slot` plugin wiring in `mereka_lms.py`** — plugin-slot API is stable across Tutor versions.

---

## Plugin-Slot Migration Status

| Component | Current Method | Target Method | Status |
|-----------|---------------|---------------|--------|
| Footer (MFE) | `org.openedx.frontend.layout.footer.v1` slot | `footer-slot` plugin only | Implemented in `mereka_lms.py` |
| Header logo (MFE) | `org.openedx.frontend.layout.header_logo.v1` slot | `header-logo-slot` | Implemented in `mereka_lms.py` |
| Logo paths | LMS/MFE theme asset + CSS overrides in shell / `mereka.scss` | `logo-slot` (MFE), theme asset fallback (LMS) | Planned for LMS shell; plugin is in MFE shell |
| Auth page layout | `[class*="authn"]` CSS overrides in `mereka.scss` | Authn MFE plugin slot (when available) | Blocked — no slot exposed upstream yet |

---

## Verification Commands

```bash
# Find all CSS overrides targeting MFE components (Paragon + wildcard patterns)
grep -rn 'pgn__\|paragon\|\[class\*=' \
  infrastructure/tutor/themes/ \
  --include="*.css" --include="*.scss"

# Find selector-exception annotations in the codebase
grep -rn 'SELECTOR-EXCEPTION' infrastructure/tutor/themes/

# Check plugin-slot registration status
grep -rn 'footer_slot\|header_slot\|PLUGIN_OPERATIONS\|registerPlugin' \
  infrastructure/tutor/plugins/

# Run the MFE route smoke + branding gate
./scripts/qa/verify-mfe-route-smoke.sh --env prod

# Run the selector hardening check
./scripts/qa/verify-mfe-selector-hardening.sh
```

---

## CRITICAL: Dead Selector Audit (2026-02-28)

> **Finding**: A DOM class audit of Ulmo MFEs reveals that most `[class*="..."]` scoped
> selectors in `mereka.scss` are **PHANTOM** — they match **no actual DOM element** in
> the running MFEs. The CSS compiles and ships, but the rules never apply.

### Methodology

Inspected the actual top-level wrapper class names emitted by each Ulmo MFE at runtime
(DOM inspection of built MFE bundles). Compared against `[class*="..."]` selectors in
`mereka.scss` lines 250-570.

### Results

| Selector | Target MFE | Status | Actual DOM class | Lines |
|----------|-----------|--------|------------------|-------|
| `[class*="authn"]` | Authn | **DEAD** | No element has "authn" in its class attribute. Authn MFE uses Paragon layout components with `pgn__` classes. | 258-314 |
| `[class*="login-register"]` | Authn | **DEAD** | Same — no element contains "login-register" substring. | 258-314 |
| `[class*="account-settings"]` | Account | **LIVE** | Matches `page__account-settings` wrapper div. | 324-384 |
| `[class*="account-page"]` | Account | **DEAD** | No element contains "account-page" substring in Ulmo Account MFE. | 324-384 |
| `[class*="learner-dashboard"]` | Learner Dashboard | **DEAD** | Dashboard MFE uses Paragon `pgn__page-container` — no "learner-dashboard" class. | 324-522 |
| `[class*="learning"]` | Learning | **DEAD** | Learning MFE uses generic Paragon layout — no element has "learning" in class. | 429-504 |
| `[class*="my-courses"]` | Learning | **DEAD** | Not present as a class in the DOM. | 449, 496 |
| `[class*="discover"]` | Learning | **DEAD** | Not present as a class in the DOM. | 496-503 |
| `[class*="course-grid"]` | Learner Dashboard / Learning | **DEAD** | Nested under dead parent scope — even if this class existed, parent match fails. | 407, 437 |
| `[class*="course-list"]` | Learner Dashboard / Learning | **DEAD** | Same — nested under dead parent. | 407, 437 |
| `[class*="discussions"]` | Discussions | **DEAD** | Discussions MFE uses `pgn__` layout — no "discussions" class on any element. | 545-568 |

### Impact Assessment

- **~60% of mereka.scss lines 250-570 are dead CSS** — they compile, ship in every MFE bundle, but apply to nothing.
- **Only `[class*="account-settings"]`** is confirmed LIVE (matches `page__account-settings`).
- **Estimated dead CSS weight**: ~5-8KB uncompressed per MFE build.
- **Risk**: Zero runtime risk (dead CSS is harmless). But it creates a false sense of branding coverage — developers think these surfaces are styled when they are not.

### Implications for Phase C/D

1. **Do NOT spend time hardening dead selectors** — they need to be replaced, not var()-ified.
2. **Phase D must find the ACTUAL class names** on each MFE surface and rewrite selectors accordingly, OR migrate entirely to FPF plugin slots.
3. **Authn MFE** is the highest priority — login/register is the first page users see, and ALL authn selectors are dead.
4. **Learner Dashboard** is second priority — course cards, grid layout, status badges are all dead.

### Recommended Actions

| Priority | Action | Est. |
|----------|--------|------|
| **P0** | Inspect live Authn MFE DOM, find actual wrapper classes, rewrite selectors | 2 hr |
| **P0** | Inspect live Learner Dashboard DOM, find actual wrapper classes | 2 hr |
| **P1** | Inspect Learning MFE DOM for course card/grid classes | 1 hr |
| **P1** | Inspect Discussions MFE DOM | 30 min |
| **P2** | Remove dead `[class*="account-page"]` selector (account-settings is sufficient) | 15 min |
| **P3** | Consider replacing ALL scoped selectors with FPF plugin slot injection | Phase D |

---

## Changelog

| Date | Author | Change |
|------|--------|--------|
| 2026-02-18 | 8jao.5 | Initial inventory from live codebase scan (AC-MFE-005) |
| 2026-02-25 | 2dcy.6 | T102 selector hardening audit baseline captured in `MFE_SELECTOR_AUDIT.md` (data-testid selectors removed) |
| 2026-02-28 | codex | Realigned inventory with live T102 state and updated migration rationale |
| 2026-02-28 | codex | Added Phase D `SAFE_TO_SLOT` / `NEEDS_KEEP` classification for header/footer/authn selectors and slot-owned surfaces |
| 2026-02-28 | opus | **CRITICAL**: Dead selector audit — ~60% of scoped selectors are phantom CSS matching no DOM elements |
