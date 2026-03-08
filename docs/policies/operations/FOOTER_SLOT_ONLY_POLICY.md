# Footer Slot-Only Policy

> **Bead**: mereka-lms-115d.19
> **Last updated**: 2026-02-18
> **Status**: ENFORCED — CI gate active (`footer-slot-only` job)

---

## Policy

**Footer customization MUST only be achieved via the FPF (Frontend Plugin Framework) plugin slot `org.openedx.frontend.layout.footer.v1`.**

No raw HTML footer injection, `innerHTML` manipulation, `document.querySelector` footer targeting, or direct footer file rewrites are permitted. All footer customization flows through `MerekaFooter` (defined in `infrastructure/tutor/plugins/mereka_lms.py`) and wired into the MFE via the slot system.

---

## Canonical Wiring Path

```
mereka_lms.py
  └── PLUGIN_SLOTS.add_item("footer_slot", ...)    ← preferred (FPF slot-driven)
  └── mfe-env-config patch: MerekaFooter component  ← canonical component definition
  └── apply-patches.sh: RenderWidget swap           ← registered fallback (see Exception Register)
```

### Primary Path (FPF PLUGIN_SLOTS)

When `tutormfe.hooks.PLUGIN_SLOTS` is available, `mereka_lms.py` registers the footer slot directly:

```python
PLUGIN_SLOTS.add_item((
    "footer_slot",
    {
        "keepDefault": False,
        "plugins": [{
            "op": "PLUGIN_OPERATIONS.Replace",
            "widget": {
                "id": "mereka_footer",
                "type": "DIRECT_PLUGIN",
                "RenderWidget": "MerekaFooter",
            },
        }],
    },
))
```

### Fallback Path (Registered Exception)

When `PLUGIN_SLOTS` is not available in the running Tutor/MFE version, `apply-patches.sh` performs a deterministic string swap in `env.config.jsx`:

```python
updated = updated.replace("RenderWidget: <Footer />", "RenderWidget: <MerekaFooter />")
```

This fallback is registered in the Exception Register below. It does not inject raw HTML — it swaps a JSX widget reference inside the existing plugin slot config structure.

---

## Banned Patterns

The following patterns are explicitly forbidden anywhere in `infrastructure/` or `scripts/`:

| Pattern | Why Banned |
|---------|-----------|
| `innerHTML.*footer` | Bypasses slot system, breaks React lifecycle |
| `document.querySelector.*footer` | Direct DOM mutation, breaks MFE hydration |
| `document.getElementById.*footer` | Same as above |
| `sed` targeting `footer.html` directly | File rewrite bypasses Tutor template system |
| Raw `<footer>` HTML string written outside JSX | Bypasses slot contract entirely |
| Writing to footer template path via `echo`/`cat` | Bypasses Tutor template lifecycle |

These patterns are checked by `scripts/qa/verify-footer-slot-only.sh` (AC-FTR-304).

---

## Exception Register

> Temporary exceptions to the slot-only policy. All exceptions require an expiry date and owner.
> Any exception that reaches its expiry without renewal MUST be removed at the next sprint.

| Exception ID | Path | Pattern | Rationale | Owner | Expiry | Rollback |
|-------------|------|---------|-----------|-------|--------|---------|
| `FTRE-001` | `infrastructure/tutor/apply-patches.sh` | `updated.replace("RenderWidget: <Footer />", "RenderWidget: <MerekaFooter />")` | Dual-path fallback for Tutor versions where `tutormfe.hooks.PLUGIN_SLOTS` is not yet available. The swap targets a JSX widget reference inside the existing plugin slot config structure — not raw HTML injection. | Mereka platform team | 2026-Q3 | Remove when all deployment targets run Tutor MFE ≥ the version that exposes `PLUGIN_SLOTS`. Set `_PLUGIN_SLOTS_AVAILABLE` guard to always-true. |
| `FTRE-002` | `infrastructure/tutor/apply-patches.sh` | `updated.replace("import Footer from '@edly-io/indigo-frontend-component-footer';\n", "")` | Removes the default Indigo footer import so `MerekaFooter` can replace it cleanly. Import-removal is not a footer injection — it prevents the default from loading. | Mereka platform team | 2026-Q3 | Remove when Indigo template no longer imports the default footer component, or when PLUGIN_SLOTS `keepDefault: False` suppresses it without import removal. |

### Exception Renewal Policy

- Exceptions must be reviewed at expiry (2026-Q3 = end of September 2026).
- Renewal requires: (1) updated rationale, (2) updated expiry, (3) PR approval from platform lead.
- Expired exceptions that are not renewed must be removed within one sprint.

---

## What NOT to Do

```jsx
// BANNED: Direct DOM mutation
document.querySelector('footer').innerHTML = '<div>Mereka footer</div>';

// BANNED: innerHTML injection
const el = document.getElementById('site-footer');
el.innerHTML = footerHtml;

// BANNED: Raw string written to footer.html via shell
echo '<footer>Mereka</footer>' > tutor_env/env/themes/mereka/lms/templates/footer.html
```

```python
# BANNED: sed-based footer file rewrite
os.system("sed -i 's/<footer>.*<\/footer>/MEREKA_FOOTER/' tutor_env/env/.../footer.html")
```

---

## What TO Do

```python
# CORRECT: Register via PLUGIN_SLOTS (preferred)
PLUGIN_SLOTS.add_item(("footer_slot", {
    "keepDefault": False,
    "plugins": [{"op": "PLUGIN_OPERATIONS.Replace", "widget": {
        "id": "mereka_footer",
        "type": "DIRECT_PLUGIN",
        "RenderWidget": "MerekaFooter",
    }}],
}))
```

```jsx
// CORRECT: Define MerekaFooter as a React component in env.config.jsx (via mfe-env-config patch)
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

Expected output: `0 FAIL` (WARNs for registered exceptions are acceptable).

### Supporting checks

```bash
# Footer parity — MFE component + Mako template consistency
./scripts/qa/verify-footer-parity.sh

# Slot migration register — confirms footer shows MIGRATED status
./scripts/qa/verify-plugin-slot-migration-register.sh

# Footer variant matrix — SITE_VARIANTS ↔ docs sync
./scripts/qa/verify-footer-variant-matrix.sh

# MFE footer slot wiring
./scripts/qa/verify-mfe-footer-slot.sh

# No DOM overrides (broader check including footer)
./scripts/qa/verify-no-dom-overrides.sh
```

### Evidence (last verified: 2026-02-18)

| Script | Result | Notes |
|--------|--------|-------|
| `verify-footer-slot-only.sh` | PASS (0 FAIL, 2 WARN) | WARNs are registered exceptions FTRE-001 and FTRE-002 |
| `verify-footer-parity.sh` | PASS | MFE MerekaFooter + Mako footer consistent |
| `verify-plugin-slot-migration-register.sh` | PASS | Footer status: MIGRATED |
| `verify-footer-variant-matrix.sh` | PASS | 3 production domains in SITE_VARIANTS |
| `verify-mfe-footer-slot.sh` | PASS | Slot wiring confirmed |
| `verify-no-dom-overrides.sh` | PASS | No forbidden DOM overrides |

**Next action**: No action required. Monitor exception register expiry at 2026-Q3.

---

## References

- [`docs/reference/architecture/MFE_PLUGIN_SLOT_MIGRATION_REGISTER.md`](MFE_PLUGIN_SLOT_MIGRATION_REGISTER.md) — Full migration register (Footer row: MIGRATED)
- [`docs/reference/operations/FOOTER_VARIANT_MATRIX.md`](FOOTER_VARIANT_MATRIX.md) — Per-domain footer config
- [`infrastructure/tutor/plugins/mereka_lms.py`](../../infrastructure/tutor/plugins/mereka_lms.py) — `MerekaFooter` component + `PLUGIN_SLOTS` registration
- [`infrastructure/tutor/apply-patches.sh`](../../infrastructure/tutor/apply-patches.sh) — Registered fallback (`FTRE-001`, `FTRE-002`)
- [`scripts/qa/verify-footer-slot-only.sh`](../../scripts/qa/verify-footer-slot-only.sh) — Policy gate script
- [OEP-65: Frontend Plugin Framework](https://open-edx-proposals.readthedocs.io/en/latest/architectural-decisions/oep-0065-frontend-plugin-framework.html) — Upstream slot spec
