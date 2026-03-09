# MFE Footer / Slot Migration

_Audience: Platform Engineering_
_Last updated: 2026-02-18 (bead 2dcy.6)_
_Owner: Mereka Frontend_

This document tracks the migration of MFE structural customizations from brittle
CSS selector blocks to the Frontend Plugin Framework (FPF) slot system. It
complements `docs/guides/branding/BRANDING_OPERATING_MODEL.md § Plugin Slot Migration`.

---

## Selector Risk Inventory

Selector blocks in `infrastructure/tutor/themes/mereka/mfe/mereka.scss` are
tagged with `/* RISK: HIGH */`, `/* RISK: MEDIUM */`, or `/* RISK: LOW */`.

### Summary (2026-02-18 baseline)

| Risk Level | Count | Description |
|------------|-------|-------------|
| HIGH | 13 | Structural selectors — layout, surface scoping, image sizing |
| MEDIUM | 9 | Component selectors — spacing, sizing that degrades visually |
| LOW | 20 | Color/spacing/font only — graceful degradation |
| **Total** | **42** | Selector blocks tagged in mereka.scss |

### HIGH-Risk Selector Inventory

| Selector Pattern | Surface | Reason | Slot Migration Status |
|-----------------|---------|--------|-----------------------|
| `.navbar` | Global nav | Structural layout; Bootstrap rename breaks nav layout | NOT MIGRATED — `header_logo_slot` registered (pending slot availability) |
| `.navbar .navbar-brand` | Global nav | Structural nav slot; Bootstrap rename loses brand layout | NOT MIGRATED — CSS fallback only |
| `[data-testid*="authn"] .pgn__card-header` | Authn | Gradient branding lost if authn MFE renames wrapper | NOT MIGRATED — no authn header slot upstream |
| `[class*="authn"]` (fallback) | Authn | Structural surface scoping; breaks on MFE rename | NOT MIGRATED — no upstream authn slot |
| `[class*="login-register"]` (fallback) | Authn | Structural surface scoping; breaks on MFE rename | NOT MIGRATED — no upstream slot |
| `[class*="learner-dashboard"]` (fallback) | Dashboard | Structural surface scoping; breaks on dashboard rename | NOT MIGRATED — `learner_dashboard.sidebar.v1` registered |
| `[class*="learner-dashboard"] [class*="course"]` | Dashboard | Card layout; overflow:hidden breaks on class rename | NOT MIGRATED — no course card slot |
| `[class*="learner-dashboard"] [class*="course-grid/list"]` | Dashboard | Grid/list gap; layout collapses on class rename | NOT MIGRATED — no grid slot |
| `[class*="learner-dashboard"] [class*="course"] img` | Dashboard | Image aspect-ratio; layout breaks if img wrapper renames | NOT MIGRATED — no slot |
| `[class*="learning"]` (fallback) | Learning MFE | Broadest structural scoping; highest breakage risk | NOT MIGRATED — P2 upstream request filed |
| `[class*="learning"] [class*="course-grid/list"]` | Learning MFE | Layout gap; breaks on class rename | NOT MIGRATED — no slot |
| `[class*="learning"] :is(.pgn__card) :is([class*="image-cap"])` | Learning MFE | Flex image-cap sizing; layout collapses on rename | NOT MIGRATED — no slot |
| `[class*="learning"] :is(.pgn__card) [class*="image/media"]` | Learning MFE | Media column min-width; too-broad selector | NOT MIGRATED — no slot |

---

## Slot ID Mapping Table

| Slot ID | What It Replaces | Migration Status | Fallback |
|---------|-----------------|-----------------|----------|
| `footer_slot` | Default Indigo `<Footer />` | MIGRATED (dual-path) | `apply-patches.sh` RenderWidget replacement |
| `header_logo_slot` | Default MFE header logo | REGISTERED (pending slot availability) | CSS `.navbar .navbar-brand img` (RISK: HIGH) |
| `learner_dashboard.sidebar.v1` | Dashboard sidebar (append) | REGISTERED (pending) | SCSS `[data-testid*="learner-dashboard"]` scoped rules |

### Slot Registration Pattern (mereka_lms.py)

Slots are registered in `infrastructure/tutor/plugins/mereka_lms.py` inside a
`try/except ImportError` block that guards `from tutormfe.hooks import PLUGIN_SLOTS`.
This makes registration forward-compatible: it activates when the Tutor version
exposes the hook, and falls back to SCSS/apply-patches.sh otherwise.

```python
# Forward-compatible slot registration pattern
try:
    from tutormfe.hooks import PLUGIN_SLOTS
    PLUGIN_SLOTS.add_item(("footer_slot", { ... }))
    PLUGIN_SLOTS.add_item(("header_logo_slot", { ... }))
    PLUGIN_SLOTS.add_item(("learner_dashboard.sidebar.v1", { ... }))
    _PLUGIN_SLOTS_AVAILABLE = True
except ImportError:
    _PLUGIN_SLOTS_AVAILABLE = False
```

---

## Migration Status Tracker

| Customization | Risk | Slot ID | Status | Target Date | Notes |
|---------------|------|---------|--------|-------------|-------|
| Footer component | HIGH | `footer_slot` | MIGRATED (dual-path) | Done | Fallback kept for Tutor compat |
| Header logo | HIGH | `header_logo_slot` | REGISTERED | 2026-Q3 | Slot not yet exposed by tutormfe |
| Dashboard sidebar CTA | HIGH | `learner_dashboard.sidebar.v1` | REGISTERED | 2026-Q3 | Append mode, preserves defaults |
| Authn card header gradient | HIGH | — | BLOCKED | 2026-Q4 | No authn slot upstream; P2 request pending |
| Authn surface scoping | HIGH | — | BLOCKED | 2026-Q4 | No upstream authn wrapper slot |
| Learning MFE layout | HIGH | — | BLOCKED | 2026-Q4 | No upstream slot; P2 upstream request filed |
| Course card grid layout | HIGH | — | BLOCKED | 2026-Q4 | No upstream course-grid slot |
| Image-cap flex sizing | HIGH | — | BLOCKED | 2026-Q4 | Paragon ImageCap internal; no slot |
| Dashboard course card | HIGH | — | BLOCKED | 2026-Q4 | No course card slot |
| Dashboard list spacing | HIGH | — | BLOCKED | 2026-Q4 | No list slot |
| Course card image | HIGH | — | BLOCKED | 2026-Q4 | No slot; CSS workaround stable |
| Dashboard list vertical rhythm | HIGH | — | BLOCKED | 2026-Q4 | No slot; * + * sibling safe |
| Navbar structure | HIGH | — | TRACKED | 2026-Q3 | Bootstrap .navbar is upstream concern |

---

## Regression Check Procedure

Use these checks after any slot or SCSS change affecting authn or learner-dashboard routes.

### Offline (No Live Cluster Required)

```bash
# 1. Verify script syntax
bash -n scripts/qa/verify-mfe-footer-slot-migration.sh

# 2. Run offline verification
./scripts/qa/verify-mfe-footer-slot-migration.sh

# 3. Verify SCSS risk tags present
grep -c 'RISK: HIGH' infrastructure/tutor/themes/mereka/mfe/mereka.scss

# 4. Verify slot registrations in plugin
grep -c 'PLUGIN_SLOTS.add_item' infrastructure/tutor/plugins/mereka_lms.py

# 5. Verify no structural footer HTML string-rewrites remain (only MIGRATED-TO-SLOT comments)
grep -n 'sed.*footer\|sed.*Footer\|replace.*<footer\|replace.*<Footer' \
  infrastructure/tutor/apply-patches.sh || echo "CLEAN"
```

### With Built MFE Environment

```bash
# Verify footer slot in generated env.config.jsx
grep 'MerekaFooter' tutor_env/env/plugins/mfe/build/mfe/env.config.jsx

# Verify footer_slot registration in generated env.config.jsx
grep 'footer_slot' tutor_env/env/plugins/mfe/build/mfe/env.config.jsx
```

### Authn Route Spot Checks

Log-based (no browser needed):

```bash
# Check authn MFE config references mereka.scss
grep 'mereka.scss' tutor_env/env/plugins/mfe/build/mfe/env.config.jsx

# Check authn MFE config has footer component
grep 'MerekaFooter' tutor_env/env/plugins/mfe/build/mfe/env.config.jsx
```

### Learner Dashboard Route Spot Checks

```bash
# Confirm SCSS has dashboard selectors (structural coverage)
grep -c 'learner-dashboard' infrastructure/tutor/themes/mereka/mfe/mereka.scss
# Should be > 10
```

---

## Rollback Procedure

If slot injection causes MFE build failure or runtime slot not rendering:

### Step 1 — Immediate Fallback (No Rebuild)

SCSS selectors in `mereka.scss` already cover all HIGH-risk surfaces via scoped
`[data-testid*="..."]` and `[class*="..."]` rules. These CSS fallbacks work without
any build change. Verify:

```bash
./scripts/qa/verify-mfe-selector-hardening.sh
```

### Step 2 — Footer Slot Specific

The `apply-patches.sh` fallback (`RenderWidget: <MerekaFooter />` replacement)
is always active regardless of `_PLUGIN_SLOTS_AVAILABLE`. Verify:

```bash
grep 'MerekaFooter' tutor_env/env/plugins/mfe/build/mfe/env.config.jsx
```

If the MFE env was built before the slot was registered, this is already the
active path.

### Step 3 — Disable Slot Registration

Force fallback-only mode by ensuring `PLUGIN_SLOTS` import fails. The existing
`try/except ImportError` in `mereka_lms.py` handles this automatically if
`tutormfe` is not installed or does not expose `PLUGIN_SLOTS`.

```bash
# Verify fallback is active
python3 -c "
try:
    from tutormfe.hooks import PLUGIN_SLOTS
    print('SLOTS AVAILABLE — canonical path active')
except ImportError:
    print('SLOTS UNAVAILABLE — fallback path active')
"
```

### Step 4 — Rebuild After Rollback

```bash
./infrastructure/tutor/apply-patches.sh
tutor images build mfe
./scripts/qa/verify-mfe-image-branding.sh tutor_local/openedx-mfe:latest
```

---

## Related Files

- `infrastructure/tutor/themes/mereka/mfe/mereka.scss` — SCSS with `/* RISK: */` tags
- `infrastructure/tutor/plugins/mereka_lms.py` — Slot registrations
- `infrastructure/tutor/apply-patches.sh` — Fallback RenderWidget patch (MIGRATED-TO-SLOT comment)
- `docs/guides/branding/BRANDING_OPERATING_MODEL.md` — § Plugin Slot Migration
- `docs/reference/architecture/MFE_PLUGIN_SLOT_MIGRATION_REGISTER.md` — Exception register
- `scripts/qa/verify-mfe-footer-slot-migration.sh` — Verification script (bead 2dcy.6)
- `scripts/qa/verify-mfe-footer-slot.sh` — Footer slot wiring check
- `scripts/qa/verify-mfe-selector-hardening.sh` — Selector compliance (bead 115d.18)
