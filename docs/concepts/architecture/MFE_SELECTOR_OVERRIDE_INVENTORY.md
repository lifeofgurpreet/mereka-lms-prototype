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
| `.page__account-settings .pgn__form-control` | Account MFE | **MEDIUM** | Explicit wrapper class match; tracked as `SELECTOR-EXCEPTION` in source |
**Total selector exception annotations**: 2 comment blocks in `mereka.scss` (`SELECTOR-EXCEPTION`).

**Hash-based selectors** (`css-XXXXXXX`): **0 found** — good, none present.

### Phase D Classification (Task D1)

| Selector/Surface | Classification | Rationale |
|------------------|----------------|-----------|
| `org.openedx.frontend.layout.header_logo.v1` slot output (`MerekaHeaderLogo`) | **SAFE_TO_SLOT** | Header logo shell is now owned by plugin-slot rendering, not brittle DOM-targeted CSS overrides. |
| `.mereka-header-logo`, `.mereka-header-logo img` in `mereka.scss` | **NEEDS_KEEP** | Minimal token-driven presentation layer for the slot output; no upstream DOM dependency beyond our own class names. |
| `org.openedx.frontend.layout.footer.v1` slot output (`MerekaFooter`) | **SAFE_TO_SLOT** | Footer shell structure is injected via FPF slot and default footer is hidden, eliminating dependence on upstream footer DOM. |
| `.footer-*` classes in `mereka.scss` (`_mfe-footer.scss`) | **NEEDS_KEEP** | Styling contract for our own slot-rendered markup; retained as tokenized presentation rules. |
| `[class*="authn"]` fallback block | **DEAD_SELECTOR** | Removed from `mereka.scss` on 2026-02-28 after dead-selector audit confirmed no live DOM matches. |
| `[class*="learner-dashboard"]` fallback block | **DEAD_SELECTOR** | Removed from `mereka.scss` on 2026-02-28 after dead-selector audit confirmed no live DOM matches. |
| `[class*="learning"]` fallback block | **DEAD_SELECTOR** | Removed from `mereka.scss` on 2026-02-28 after dead-selector audit confirmed no live DOM matches. |
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
| Auth page layout | Dead selectors removed; `login_component.v1` slot active | Authn MFE plugin slot injection | Implemented in `mereka_lms.py` via `MerekaAuthnLoginBranding` |

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

| Selector | Target MFE | Status | Actual DOM class | Resolution |
|----------|-----------|--------|------------------|------------|
| `[class*="authn"]` | Authn | **REMOVED** | No element has "authn" in its class attribute. Authn MFE uses Paragon layout components with `pgn__` classes. | Tombstone comment at line 307 |
| `[class*="login-register"]` | Authn | **REMOVED** | Same — no element contains "login-register" substring. | Removed with authn block |
| `.page__account-settings` | Account | **LIVE** | Matches the Account MFE wrapper div directly. | Retained as explicit class scope (no wildcard) |
| `[class*="account-page"]` | Account | **REMOVED** | No element contains "account-page" substring in Ulmo Account MFE. | Replaced by explicit `.page__account-settings` |
| `[class*="learner-dashboard"]` | Learner Dashboard | **REMOVED** | Dashboard MFE uses Paragon `pgn__page-container` — no "learner-dashboard" class. | Tombstone comment at line 352 |
| `[class*="learning"]` | Learning | **REMOVED** | Learning MFE uses generic Paragon layout — no element has "learning" in class. | Tombstone comment at line 353 |
| `[class*="my-courses"]` | Learning | **REMOVED** | Not present as a class in the DOM. | Removed with learning block |
| `[class*="discover"]` | Learning | **REMOVED** | Not present as a class in the DOM. | Removed with learning block |
| `[class*="course-grid"]` | Learner Dashboard / Learning | **REMOVED** | Nested under dead parent scope — parent match fails. | Removed with dashboard/learning blocks |
| `[class*="course-list"]` | Learner Dashboard / Learning | **REMOVED** | Same — nested under dead parent. | Removed with dashboard/learning blocks |
| `[class*="discussions"]` | Discussions | **REMOVED** | Discussions MFE uses `pgn__` layout — no "discussions" class on any element. | Tombstone comment at line 365 |

### Impact Assessment

- **All dead selectors have been removed** from `mereka.scss` (10 of 11 selectors).
- **Only `.page__account-settings`** is retained as a LIVE explicit class scope (no wildcard).
- **Estimated CSS weight savings**: ~5-8KB uncompressed per MFE build.
- **Tombstone comments** left at removal points for future reference.

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
| **P2** | Keep explicit `.page__account-settings` scope and prevent wildcard regressions | Ongoing |
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
| 2026-02-28 | opus | Post-implementation review: Updated audit table from DEAD→REMOVED status, fixed stale line references, updated authn migration status |
