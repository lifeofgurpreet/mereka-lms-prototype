# Legacy Footer Removal

**Bead**: 1rns
**Date**: 2026-02-18
**Status**: Complete
**ACs**: AC-UI-401, AC-UI-402, AC-UI-403, AC-UI-404, AC-UI-405

---

## What Was Removed

### Before (bead 2dcy.6 state)

The Mereka footer customization used a **dual-path** approach:

1. **Primary (slot-based)**: `mereka_lms.py` registered `footer_slot` via
   `PLUGIN_SLOTS.add_item`. This is the correct, ADR-014-compliant path.
2. **Legacy (string-rewrite)**: `apply-patches.sh` replaced
   `RenderWidget: <Footer />` with `RenderWidget: <MerekaFooter />` in the
   generated `tutor_env/env/plugins/mfe/build/mfe/env.config.jsx`.

### After (bead 1rns state)

The legacy string-rewrite line in `apply-patches.sh` is **removed**.
The MerekaFooter component definition is still injected into `env.config.jsx`
(so the symbol is available), but the slot wiring is handled exclusively by
the `PLUGIN_SLOTS.add_item` call in `mereka_lms.py`.

No fallback flags or dead code paths were introduced — the plugin slot is the only path.

---

## What Replaced It

The canonical footer customization is delivered via the **Frontend Plugin Framework**
slot mechanism, registered in `infrastructure/tutor/plugins/mereka_lms.py`:

```python
PLUGIN_SLOTS.add_item(
    (
        "footer_slot",
        {
            "keepDefault": False,
            "plugins": [
                {
                    "op": "PLUGIN_OPERATIONS.Replace",
                    "widget": {
                        "id": "mereka_footer",
                        "type": "DIRECT_PLUGIN",
                        "RenderWidget": "MerekaFooter",
                    },
                }
            ],
        },
    )
)
```

The `MerekaFooter` component is defined inline in the `mfe-env-config` patch
within `mereka_lms.py` and is also injected by `apply-patches.sh` into
`env.config.jsx` (component definition only, no slot wiring).

---

## Rollback Procedure

If the slot-based footer breaks after a `tutor-mfe` upgrade:

**Step 1**: Revert the `apply-patches.sh` change with `git revert`:

```bash
# Find the 1rns commit and revert it
git log --oneline --grep="1rns" | head -1
git revert <commit-sha>
```

**Step 2**: Re-run patches and restart:

```bash
export TUTOR_ROOT="$(pwd)/tutor_env"
./infrastructure/tutor/apply-patches.sh
tutor local restart
```

**Step 3**: Verify the footer renders:

```bash
grep "MerekaFooter" tutor_env/env/plugins/mfe/build/mfe/env.config.jsx
```

The `try/except ImportError` block in `mereka_lms.py` handles the case where
`PLUGIN_SLOTS` is unavailable — it sets `_PLUGIN_SLOTS_AVAILABLE = False`
and the slot registration is silently skipped. In that case, `git revert`
restores the string-rewrite path.

---

## Route Coverage Matrix

| Surface | Footer Slot | Notes |
|---------|-------------|-------|
| LMS homepage (`/`) | Active | env.config.jsx loaded, slot fires |
| LMS course pages | Active | Same env.config.jsx bundle |
| Authn MFE (`/login`, `/register`) | Active | authn MFE loads env.config.jsx |
| Learner Dashboard (`/dashboard`) | Active | learner-dashboard MFE loads env.config.jsx |
| Learning MFE (course player) | Active | learning MFE loads env.config.jsx |
| Studio (`/studio`) | Not applicable | Studio uses Paragon, no env.config.jsx footer slot |
| Admin (`/admin/`) | Not applicable | Django admin uses built-in footer |

---

## Smoke Check Commands

```bash
# 1. Confirm legacy string-rewrite is removed (should only appear in comment)
grep -n "RenderWidget.*MerekaFooter" infrastructure/tutor/apply-patches.sh

# 2. Confirm slot registration is present
grep -n "footer_slot" infrastructure/tutor/plugins/mereka_lms.py

# 3. Confirm MerekaFooter component is still in plugin (mfe-env-config patch)
grep -n "const MerekaFooter" infrastructure/tutor/plugins/mereka_lms.py

# 4. Run full verification
./scripts/qa/verify-legacy-footer-removal.sh
```

---

## Before/After Diff Evidence

Full diff evidence at: `docs/archive/evidence/operations/footer-migration-diff.md`

---

## Related Documentation

- `docs/guides/branding/BRANDING_OPERATING_MODEL.md` — Plugin Slot Migration section
- `infrastructure/tutor/plugins/mereka_lms.py` — Canonical slot registrations
- `infrastructure/tutor/apply-patches.sh` — Patch script (footer section removed)
- `scripts/qa/verify-mfe-footer-slot-migration.sh` — Predecessor bead (2dcy.6) verify script
- `scripts/qa/verify-legacy-footer-removal.sh` — This bead (1rns) verify script
