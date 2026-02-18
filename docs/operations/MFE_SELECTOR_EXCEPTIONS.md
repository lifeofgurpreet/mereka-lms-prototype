# MFE Selector Exceptions

**Bead**: 2dcy.2 (AC-FRONT-023)
**Last updated**: 2026-02-18
**Status**: Active — reviewed and approved

This document records the CSS selectors in `infrastructure/tutor/themes/mereka/mfe/mereka.scss`
that **cannot** be migrated to frontend-plugin-framework slot overrides. Each entry explains:

- The selector and its current risk level
- Why it cannot be replaced by a plugin slot
- Upgrade monitoring / expiry note

---

## What "Cannot Be Migrated" Means

Frontend plugin slots (`PLUGIN_SLOTS`) replace or inject **React components** at defined slot
boundaries. They cannot:

1. Override CSS colour tokens, typography, or spacing (those are design-token concerns)
2. Target stable HTML elements (`body`, `:root`) that have no slot equivalent
3. Patch layout rules on Paragon BEM classes without also replacing the component

CSS overrides remain acceptable for **cosmetic, non-structural** changes that degrade gracefully
when upstream renames happen. Structural overrides that would **break layout** on upstream rename
are the migration priority — those are handled via plugin slots (see
`MFE_PLUGIN_SLOT_MIGRATION_REGISTER.md`).

---

## Exception Inventory

### EX-01 — `:root` CSS custom properties

```scss
/* RISK: LOW — CSS custom properties, no structural dependency */
:root {
  --mereka-mfe-branding-rev: "2026-02-18-us7";
  --mereka-mfe-gradient: ...;
  ...
}
```

**Cannot be migrated**: Plugin slots inject React components; `:root` CSS vars are design-token
infrastructure. There is no slot for "add a CSS variable". The variables are consumed by all
other selectors across every MFE surface.

**Rationale**: CSS-only concern; no upstream rename risk (`:root` is a CSS standard element).
This must remain as CSS.

**Upgrade monitoring**: None required. `:root` is immutable by the CSS specification.

---

### EX-02 — `body` background styling

```scss
/* RISK: LOW — html element selector, cannot be renamed */
body {
  min-height: 100vh;
  background-color: var(--mereka-color-surface-primary);
  background-image: ...;
}
```

**Cannot be migrated**: Plugin slots inject into specific MFE component trees, not into the
browser document root. There is no Open edX slot for "set the document body background".

**Rationale**: CSS-only, applies to the HTML `body` element which is guaranteed stable. Gracefully
degrades (removes brand background) but does not break layout or functionality.

**Upgrade monitoring**: None required.

---

### EX-03 — `.navbar` structural nav styling (RISK: HIGH)

```scss
/* RISK: HIGH — .navbar is a structural layout class; breaks on Bootstrap or Paragon rename */
.navbar {
  background: #fff;
  border-bottom: ...;
  ...
}
```

**Cannot be migrated**: There is no `org.openedx.frontend.plugin_slot.header_navbar.v1` slot
that would let us replace navbar layout. The `header_logo_slot` (already registered) covers only
the logo sub-component. The full navbar structure is owned by `@edx/frontend-component-header`.

**Rationale**: Structural styling that cannot be isolated to a plugin slot without replacing the
entire header component. The `.navbar` class is Bootstrap 5-stable but would break on a major
Bootstrap upgrade.

**Upgrade monitoring**: Review when upgrading Bootstrap major versions or
`@edx/frontend-component-header`. Tagged `/* RISK: HIGH */` in the SCSS for grep-based auditing.

**Expiry**: Review at Bootstrap 6 or Paragon v23+.

---

### EX-04 — `.navbar .navbar-brand` logo fallback (RISK: HIGH)

```scss
/* RISK: HIGH — .navbar .navbar-brand is a structural nav slot; breaks if Bootstrap renames it */
.navbar .navbar-brand {
  display: flex;
  align-items: center;
  ...
}
```

**Cannot be migrated immediately**: The `header_logo_slot` plugin slot (registered in
`mereka_lms.py`) is the **primary** path for logo replacement. This CSS rule is a **fallback** for
MFE builds where `tutormfe.hooks.PLUGIN_SLOTS` is not yet available (graceful degradation path).

**Rationale**: Keep as CSS fallback until `PLUGIN_SLOTS` is confirmed live in all MFE builds. The
CSS is structural (flex layout) but degrades to unstyled logo if Bootstrap renames `.navbar-brand`.

**Upgrade monitoring**: Remove this exception once `_PLUGIN_SLOTS_AVAILABLE = True` is the
guaranteed runtime path. Tagged `/* RISK: HIGH */` for visibility.

**Expiry**: 2026-Q3 or when `PLUGIN_SLOTS` availability is confirmed.

---

### EX-05 — Authn surface scoping selectors (RISK: HIGH)

```scss
/* RISK: HIGH — structural authn surface scoping */
[data-testid*="login-page"],
[data-testid*="register-page"],
[data-testid*="authn"],
[class*="authn"],
[class*="login-register"] {
  background: transparent;
}
```

**Cannot be migrated**: The authn MFE (`frontend-app-authn`) does not expose
`org.openedx.frontend.plugin_slot.*` slots for the login/register page wrapper. The P2 upstream
request to add a slot for authn surface scoping has been filed but not yet merged.

**Rationale**: These selectors scope branding overrides (background transparency, card styling,
header gradient) to the authn surface. The `data-testid` primary paths are stable; the
`[class*="authn"]` fallbacks are brittle. Documented inline with `// SELECTOR-EXCEPTION` comments.

**Upgrade monitoring**: Track `frontend-app-authn` slot availability. When an `authn_page_slot`
is available upstream, migrate the structural rules and demote the CSS to cosmetic-only.

**Expiry**: 2026-Q3 review point. See inline `// SELECTOR-EXCEPTION` comments in `mereka.scss`.

---

### EX-06 — Learner-dashboard course card layout (RISK: HIGH)

```scss
/* RISK: HIGH — structural course card scoping; layout breaks if dashboard or course class renames */
[data-testid*="learner-dashboard"] [data-testid*="course"],
[class*="learner-dashboard"] [class*="course"] {
  border-radius: 20px;
  ...
}
```

**Cannot be migrated**: The `learner_dashboard.sidebar.v1` slot (registered in `mereka_lms.py`)
covers the **sidebar**, not individual course card styling. There is no upstream slot for
"course card appearance in the main grid". A `course_card.v1` slot has been proposed upstream
but is not yet available.

**Rationale**: Course card border-radius/overflow are structural layout rules. The `data-testid`
primary paths are moderately stable; the `[class*="course"]` fallbacks are brittle.

**Upgrade monitoring**: Track `frontend-app-learner-dashboard` slot additions. When a
`course_card.v1` slot lands upstream, migrate border-radius/overflow to a slot-injected wrapper.

**Expiry**: 2026-Q3 review point.

---

### EX-07 — Learning MFE image-cap layout (RISK: HIGH)

```scss
/* RISK: HIGH — structural image-cap flex sizing; layout collapses if ImageCap class renames */
[data-testid*="learning"] :is(.pgn__card, .card)
  :is(.pgn__card-image-cap, [class*="image-cap"], [class*="imagecap"]) {
  flex: 0 0 180px;
  ...
}
```

**Cannot be migrated**: The Paragon `Card.ImageCap` component does not expose a plugin slot.
The image-cap flex sizing is structural — without it, horizontal course cards collapse their
thumbnail column to zero width.

**Rationale**: Layout-critical rule; no slot available for Paragon sub-component internals.
`.pgn__card-image-cap` is semi-stable (Paragon major version guard applies).

**Upgrade monitoring**: Review on Paragon major version bumps. Tagged `/* RISK: HIGH */`.

**Expiry**: Review at Paragon v22+.

---

### EX-08 — Learning MFE media-column width guard (RISK: HIGH)

```scss
/* RISK: HIGH — structural media column sizing; too broad selector */
[data-testid*="learning"] :is(.pgn__card, .card) [class*="image"],
[data-testid*="learning"] :is(.pgn__card, .card) [class*="media"] {
  min-width: 180px;
  flex-shrink: 0;
}
```

**Cannot be migrated**: This is a layout guardrail for course card image/media columns in the
learning MFE. No upstream slot for inner card media layout. The `[class*="image"]` /
`[class*="media"]` pattern is intentionally broad — too broad is acknowledged in the inline
comment — but there is no stable alternative without upstream slot support.

**Rationale**: Layout-critical guardrail. When removed, course thumbnails collapse in some MFE
build variants. No slot available for this sub-component.

**Upgrade monitoring**: Monitor for Paragon `Card` or `CourseCard` slot additions.

**Expiry**: 2026-Q3 review point.

---

### EX-09 — Learner-dashboard list vertical rhythm (RISK: HIGH)

```scss
/* RISK: HIGH — structural list vertical rhythm */
[data-testid*="learner-dashboard"] [data-testid*="course-list"] > * + *,
[class*="learner-dashboard"] [class*="course-list"] > * + * {
  margin-top: 1rem;
}
```

**Cannot be migrated**: List vertical spacing is a CSS layout concern with no equivalent slot.
The `* + * { margin-top }` lobotomised owl pattern is the only reliable spacing method when
the parent container does not emit `gap` styles.

**Rationale**: Spacing-only rule; gracefully degrades (removes consistent rhythm) but does not
break functionality. No slot available for container layout.

**Expiry**: 2026-Q3 review point.

---

### EX-10 — Button / form / card cosmetic overrides (RISK: LOW / MEDIUM)

Many selectors in `mereka.scss` override Paragon BEM classes (`.pgn__btn--primary`,
`.pgn__form-control`, `.pgn__card`, `.pgn__modal-content`, etc.) for **colour, border-radius,
and shadow only**. These are classified RISK: LOW or RISK: MEDIUM and are excluded from
migration because:

1. They are purely cosmetic — degrading to default Paragon styles does not break functionality.
2. Plugin slots inject components; they cannot selectively restyle a component's existing
   colour palette.
3. Paragon BEM classes (`.pgn__*`) are semi-stable across minor versions.

**Rationale**: Design-token overrides belong in CSS. These will be reclassified to use
`--mereka-*` custom properties where possible as the design token pipeline matures.

**Upgrade monitoring**: Review on Paragon major versions. Replace with design-token injections
once Paragon exposes CSS custom property hooks for all component variants.

---

## Risk Summary Matrix

| Exception | Selector pattern | Risk | Migration blocker | Expiry |
|-----------|-----------------|------|-------------------|--------|
| EX-01 | `:root` CSS vars | LOW | No slot for CSS vars | Never |
| EX-02 | `body` background | LOW | No slot for document root | Never |
| EX-03 | `.navbar` full styling | HIGH | No full-navbar slot | Bootstrap 6 |
| EX-04 | `.navbar-brand` fallback | HIGH | PLUGIN_SLOTS not guaranteed live yet | 2026-Q3 |
| EX-05 | Authn surface scoping | HIGH | No authn surface slot upstream | 2026-Q3 |
| EX-06 | Dashboard course cards | HIGH | No course_card.v1 slot upstream | 2026-Q3 |
| EX-07 | Learning image-cap | HIGH | No Paragon Card.ImageCap slot | Paragon v22 |
| EX-08 | Learning media column | HIGH | No inner card media slot | 2026-Q3 |
| EX-09 | List vertical rhythm | HIGH | CSS spacing concern; no slot | 2026-Q3 |
| EX-10 | Btn/form/card cosmetics | LOW–MED | CSS-only; design-token concern | Paragon major |

---

## What Was Successfully Migrated

See `docs/operations/evidence/selector-to-slot-migration-diff.md` for the full
before/after record of which selectors were migrated to plugin slots.

| Surface | Migrated via | Slot ID |
|---------|-------------|---------|
| MFE Footer | `PLUGIN_SLOTS.add_item` | `footer_slot` |
| Header Logo | `PLUGIN_SLOTS.add_item` | `header_logo_slot` |
| Dashboard Sidebar CTA | `PLUGIN_SLOTS.add_item` | `learner_dashboard.sidebar.v1` |

---

## Related Documents

- `docs/operations/MFE_PLUGIN_SLOT_MIGRATION_REGISTER.md` — Full migration inventory
- `docs/operations/MFE_PLUGIN_SLOT_MATRIX.md` — Available slot inventory
- `docs/operations/MFE_SELECTOR_HARDENING_AUDIT.md` — Selector risk audit
- `docs/operations/evidence/selector-to-slot-migration-diff.md` — Before/after diff evidence
- `infrastructure/tutor/themes/mereka/mfe/mereka.scss` — Source of truth for CSS selectors
- `infrastructure/tutor/plugins/mereka_lms.py` — Plugin slot registrations
