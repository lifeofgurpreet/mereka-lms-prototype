# Footer Slot-Only Policy

> **Bead**: mereka-lms-115d.19
> **Last updated**: 2026-03-27
> **Status**: ENFORCED — CI gate active (`footer-slot-only` job)

---

## Policy

**MFE footer customization MUST only be achieved via the FPF (Frontend Plugin Framework) slot `org.openedx.frontend.layout.footer.v1`.**

No raw HTML footer injection, `innerHTML` manipulation, `document.querySelector` footer targeting, or direct footer file rewrites are permitted. The active MFE footer path is:

- footer runtime/component truth in `infrastructure/tutor/plugins/_mereka_lms/mfe_runtime_definitions.js`
- slot wiring truth in `infrastructure/tutor/plugins/mereka_lms_mfe_slots.py`
- Tutor build assembly in `infrastructure/tutor/plugins/mereka_lms.py`

The legacy `apply-patches.sh` / `footer-component.sh` path no longer swaps `RenderWidget` or injects `MerekaFooter`. It only syncs build-time assets.

---

## Canonical Wiring Path

```text
_mereka_lms/mfe_runtime_definitions.js
  └── const MerekaFooter = () => { ... }          ← canonical footer component
  └── const MEREKA_SITE_VARIANTS = { ... }        ← canonical tenant footer data
  └── getMerekaVariant(hostname, config)          ← exact + derived-host + fallback resolution

mereka_lms_mfe_slots.py
  └── PLUGIN_SLOTS.add_items(items)
      └── org.openedx.frontend.layout.footer.v1
          ├── Hide default_contents
          └── Insert MerekaFooter

mereka_lms.py
  └── assembles/imports the runtime definitions into generated MFE config

footer-component.sh
  └── asset sync only (copies env.config.jsx + SCSS/fonts into build context)
```

### Primary Path (FPF PLUGIN_SLOTS)

The current slot registration is defined in `mereka_lms_mfe_slots.py`:

```python
items.append(
    (
        "all",
        "org.openedx.frontend.layout.footer.v1",
        """
            {
                op: PLUGIN_OPERATIONS.Hide,
                widgetId: 'default_contents',
            },
            {
                op: PLUGIN_OPERATIONS.Insert,
                widget: {
                    id: 'mereka_footer',
                    type: DIRECT_PLUGIN,
                    priority: 1,
                    RenderWidget: MerekaFooter,
                },
            },
            """,
    )
)

PLUGIN_SLOTS.add_items(items)
```

### Component Path

The footer component itself lives in `infrastructure/tutor/plugins/_mereka_lms/mfe_runtime_definitions.js` and is compiled into generated `env.config.jsx` at build time:

```jsx
const MerekaFooter = () => (
  <footer className="mereka-footer mereka-footer--v2" role="contentinfo">
    {/* Zone 1: social row */}
    {/* Zone 2: nav strip */}
    {/* Zone 3: column body */}
    {/* Zone 4: legal row */}
  </footer>
);
```

---

## Banned Patterns

The following patterns are explicitly forbidden anywhere in `infrastructure/` or `scripts/`:

| Pattern | Why Banned |
|---------|-----------|
| `innerHTML.*footer` | Bypasses slot system, breaks React lifecycle |
| `document.querySelector.*footer` | Direct DOM mutation, breaks MFE hydration |
| `document.getElementById.*footer` | Same as above |
| `sed` targeting `footer.html` directly | File rewrite bypasses Tutor/template lifecycle |
| Raw `<footer>` HTML string written outside JSX | Bypasses slot contract entirely |
| Writing to footer template path via `echo`/`cat` | Bypasses Tutor/template lifecycle |
| `RenderWidget.*Footer` swap in `apply-patches.sh` | Reintroduces a deprecated fallback path without explicit review |

These patterns are checked by `scripts/qa/verify-footer-slot-only.sh` (AC-FTR-304).

---

## Exception Register

**No active exceptions.**

Historical note:
- Earlier migrations used a temporary `apply-patches.sh` RenderWidget swap while the slot path was being stabilized.
- That fallback has been removed from the active codebase.
- If a future emergency exception is introduced, it must be documented here with `Owner`, `Expiry`, and `Rollback`.

### Exception Renewal Policy

- Any new exception must be temporary, reviewable, and narrowly scoped.
- Required metadata: `Owner`, `Expiry`, `Rollback`.
- Expired exceptions that are not renewed must be removed within one sprint.

---

## What NOT to Do

```jsx
// BANNED: Direct DOM mutation
document.querySelector('footer').innerHTML = '<div>Mereka footer</div>';

// BANNED: innerHTML injection
const el = document.getElementById('site-footer');
el.innerHTML = footerHtml;
```

```python
# BANNED: direct footer template rewrite
os.system("sed -i 's/<footer>.*<\\/footer>/MEREKA_FOOTER/' tutor_env/env/.../footer.html")
```

---

## What TO Do

```python
# CORRECT: register footer slot operations via PLUGIN_SLOTS
PLUGIN_SLOTS.add_items([
    (
        "all",
        "org.openedx.frontend.layout.footer.v1",
        """
            {
                op: PLUGIN_OPERATIONS.Hide,
                widgetId: 'default_contents',
            },
            {
                op: PLUGIN_OPERATIONS.Insert,
                widget: {
                    id: 'mereka_footer',
                    type: DIRECT_PLUGIN,
                    RenderWidget: MerekaFooter,
                },
            },
        """,
    )
])
```

```jsx
// CORRECT: define the footer component in the runtime definitions module
const MerekaFooter = () => (
  <footer className="mereka-footer mereka-footer--v2" role="contentinfo">
    {/* ... */}
  </footer>
);
```

---

## Verification Commands

Run these commands to confirm footer slot-only policy compliance. Results are PASS/WARN/FAIL.

### Primary gate (covers AC-FTR-301 through AC-FTR-305)

```bash
./scripts/qa/verify-footer-slot-only.sh
```

Expected output: `0 FAIL / 0 WARN`.

### Supporting checks

```bash
# Footer parity — MFE component + Mako template consistency
./scripts/qa/verify-footer-parity.sh

# Footer variant matrix — MEREKA_SITE_VARIANTS ↔ docs sync
./scripts/qa/verify-footer-variant-matrix.sh

# MFE footer slot wiring
./scripts/qa/verify-mfe-footer-slot.sh

# Tenant footer lane truth
./scripts/qa/verify-tenant-footer-variant-lane.sh
```

### Evidence (last verified: 2026-03-27)

| Script | Result | Notes |
|--------|--------|-------|
| `verify-footer-slot-only.sh` | PASS | No active exceptions, no legacy footer swap |
| `verify-footer-parity.sh` | PASS | MFE footer + LMS/CMS footer surfaces are present and classified |
| `verify-footer-variant-matrix.sh` | PASS | 3 production domains + derived-host fallback verified |
| `verify-mfe-footer-slot.sh` | PASS | Slot wiring confirmed |
| `verify-tenant-footer-variant-lane.sh` | PASS | Operator lane docs aligned with runtime helper |

**Next action**: Keep policy and verifier aligned with `_mereka_lms/mfe_runtime_definitions.js` and `mereka_lms_mfe_slots.py`. Treat any reintroduced `apply-patches.sh` footer swap as a regression until explicitly reviewed.

---

## References

- [`docs/reference/operations/FOOTER_VARIANT_MATRIX.md`](../../reference/operations/FOOTER_VARIANT_MATRIX.md) — per-domain footer config
- [`infrastructure/tutor/plugins/_mereka_lms/mfe_runtime_definitions.js`](../../../infrastructure/tutor/plugins/_mereka_lms/mfe_runtime_definitions.js) — `MerekaFooter`, `MEREKA_SITE_VARIANTS`, `getMerekaVariant`
- [`infrastructure/tutor/plugins/mereka_lms_mfe_slots.py`](../../../infrastructure/tutor/plugins/mereka_lms_mfe_slots.py) — footer slot registration
- [`infrastructure/tutor/patches/footer-component.sh`](../../../infrastructure/tutor/patches/footer-component.sh) — asset sync only
- [`scripts/qa/verify-footer-slot-only.sh`](../../../scripts/qa/verify-footer-slot-only.sh) — policy gate
- [OEP-65: Frontend Plugin Framework](https://open-edx-proposals.readthedocs.io/en/latest/architectural-decisions/oep-0065-frontend-plugin-framework.html) — upstream slot spec
