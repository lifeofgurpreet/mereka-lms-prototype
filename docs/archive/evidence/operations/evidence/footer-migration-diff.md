# Footer Migration Diff Evidence

**Bead**: 1rns
**Date**: 2026-02-18
**ACs**: AC-UI-401, AC-UI-402, AC-UI-403, AC-UI-404, AC-UI-405

---

## Before State (bead 2dcy.6 — MIGRATED-TO-SLOT annotation only)

In `infrastructure/tutor/apply-patches.sh`, the footer was wired via a string-rewrite
applied directly to the generated `env.config.jsx`:

```python
# MIGRATED-TO-SLOT: footer_slot (bead 2dcy.6, AC-FRONT-063)
updated = updated.replace("RenderWidget: <Footer />", "RenderWidget: <MerekaFooter />")
```

The `MIGRATED-TO-SLOT` comment was added by bead 2dcy.6 to signal intent, but the
actual string-rewrite was still **active** — meaning the legacy patch was still
executing on every `apply-patches.sh` run.

---

## After State (bead 1rns — legacy patch removed)

In `infrastructure/tutor/apply-patches.sh`, the string-rewrite is **removed**,
replaced by a one-line comment:

```python
# Legacy footer string-rewrite removed (bead 1rns). Footer now via plugin slot only.
```

The MerekaFooter component definition is still injected (so the symbol exists in scope),
but the slot wiring is exclusively via `PLUGIN_SLOTS.add_item` in `mereka_lms.py`.

No fallback flags or dead code paths were introduced.

---

## Key Differences

| Aspect | Before | After |
|--------|--------|-------|
| Footer wiring mechanism | Dual-path (slot + string-rewrite active) | Single-path (slot only) |
| `apply-patches.sh` string-rewrite | ACTIVE (annotated but running) | REMOVED |
| MerekaFooter component injection | Via both plugin patch + apply-patches.sh | Component defined in plugin; slot wires it |
| Rollback path | Remove annotation, revert is messy | `git revert <1rns-commit>` restores old behavior |

---

## Slot Registration (canonical path)

The footer is now registered exclusively via `PLUGIN_SLOTS.add_item` in
`infrastructure/tutor/plugins/mereka_lms.py`:

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

---

## Route Coverage

| Route | Footer Slot Active | Notes |
|-------|-------------------|-------|
| LMS (`academyv2.mereka.io`) | Yes | env.config.jsx loaded by all MFEs |
| Apps (`apps.academyv2.mereka.io`) | Yes | authn, learner-dashboard, learning MFEs |
| Studio (`studio.academyv2.mereka.io`) | N/A | Studio uses Paragon, not MFE footer slot |
| Admin (`/admin/`) | N/A | Django admin default footer |

---

## Smoke Check Commands

```bash
# Verify legacy patch is removed
grep -n "RenderWidget.*MerekaFooter" infrastructure/tutor/apply-patches.sh
# Expected: only in comments

# Verify slot is registered
grep -n "footer_slot" infrastructure/tutor/plugins/mereka_lms.py

# Run verify script
./scripts/qa/verify-legacy-footer-removal.sh
```
