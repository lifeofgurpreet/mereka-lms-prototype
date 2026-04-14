# MFE Selector Audit — T102

> **Authoritative**: This is the canonical selector audit. It supersedes the earlier selector hardening audit from 2026-02-18.
>
> **2026-02-28 Update**: Parts of this document are now historical. For current selector reality (including dead-selector removals for `authn`, `learner-dashboard`, `learning`, `discussions`, and migration of account scope to explicit `.page__account-settings`), use:
> - [MFE_SELECTOR_OVERRIDE_INVENTORY.md](./MFE_SELECTOR_OVERRIDE_INVENTORY.md)
> - [FPF_PLUGIN_SLOT_REGISTRY.md](./FPF_PLUGIN_SLOT_REGISTRY.md)

**Date**: 2026-02-25
**Task**: T102 — Reduce MFE brittle selectors by 50%
**Author**: Automated (Claude / implementor agent)
**Related**: [SELECTOR_HARDENING_POLICY.md](../../policies/architecture/SELECTOR_HARDENING_POLICY.md)

---

## Summary

| Metric | Before (pre-T102) | After (T102) | Change |
|--------|-------------------|--------------|--------|
| Total brittle selector lines | 182 | 72 | -110 (-60%) |
| `[class*=...]` lines | 101 | 72 | -29 (-29%) |
| `[data-testid*=...]` lines | 81 | 0 | -81 (-100%) |
| Stable selector lines (approx) | ~58 | ~58 | 0 |
| Target threshold (50% of 182) | — | 91 | PASS (72 ≤ 91) |

**Result**: 60% reduction in brittle selectors, exceeding the 50% target.

---

## What Changed

### Strategy

The `SELECTOR_HARDENING_POLICY.md` states:

> `data-testid` SHOULD only be used when no class-based alternative exists. It is intended for testing, not production styling.

Before T102, every rule block had **two sets of selectors** for the same target:
1. `[data-testid*="X"]` selectors (labeled "primary")
2. `[class*="X"]` selectors (labeled "fallback")

This was redundant. Since both selector types target the same DOM regions and the class-based form is more aligned with the hardening policy, the `[data-testid*=]` lines were removed entirely. The class-based selectors now serve as the single, canonical selectors.

Additionally, compound selectors of the form `[class*="outer"] [data-testid*="inner"]` were consolidated to the class-based inner equivalents where a class-based alternative was already present in the same rule block.

### Changes Made

1. **Removed all 81 `[data-testid*=]` outer-scope selector lines** across all MFE surface sections:
   - Authn (login/register) surface
   - Account/settings surface
   - Learner dashboard surface
   - Learning MFE surface
   - Discussions/forum surface

2. **Consolidated compound selectors** — lines like `[class*="learning"] [data-testid*="course-grid"]` were dropped where `[class*="learning"] [class*="course-grid"]` already existed in the same rule.

3. **Updated section comments** to note the removal of data-testid selectors and reference T102.

4. **Updated branding revision token** from `2026-02-18-us7` to `2026-02-25-t102`.

5. **Cleaned up `/* BRITTLE: ... */` section headers** — the remaining brittle selectors are already documented via `SELECTOR-EXCEPTION` inline comments.

### What Was NOT Changed

- Visual appearance is unchanged. The class-based selectors already provided identical coverage.
- No Paragon BEM selectors (`.pgn__*`) were modified.
- No Bootstrap class selectors (`.btn-*`, `.card`, `.navbar`, etc.) were modified.
- All `SELECTOR-EXCEPTION` comments and their `expires: YYYY-QN` annotations are preserved.
- The two `SELECTOR-KEPT-BRITTLE` cases for `[class*="image"]` and `[class*="media"]` are retained with explanatory comments.

---

## Selector Classification (Post-T102)

### STABLE selectors (not brittle)

These selectors use official class names, Paragon BEM, Bootstrap classes, or custom `.mereka-*` classes that we control. They do not break on upstream MFE class renames.

| Selector pattern | Count (approx) | Notes |
|-----------------|----------------|-------|
| `.pgn__*` (Paragon BEM) | ~22 | Semi-stable; Paragon maintains backward compat |
| `.btn-primary`, `.btn-outline-primary` | ~6 | Bootstrap; stable |
| `.navbar`, `.navbar-brand`, `.nav-link` | ~8 | Bootstrap; stable |
| `.card`, `.card-header`, `.card-footer` | ~6 | Bootstrap; stable |
| `.mereka-badge` | ~4 | Our class; fully stable |
| `:root`, `body`, `@media` | ~4 | Element/pseudo; stable |
| `.dropdown-menu`, `.nav-tabs`, `.row` | ~5 | Bootstrap; stable |

### BRITTLE selectors remaining (72 lines)

All remaining brittle selectors use `[class*="X"]` attribute substring matching. Each is documented with a `SELECTOR-EXCEPTION` or `SELECTOR-KEPT-BRITTLE` comment.

| Surface / selector pattern | Lines | Risk | Justification |
|---------------------------|-------|------|---------------|
| `[class*="authn"]`, `[class*="login-register"]` | 14 | HIGH | Authn MFE emits these wrapper classes; no stable slot exists for route-level scoping |
| `[class*="account-settings"]`, `[class*="account-page"]` | 18 | HIGH | Account MFE top-level wrappers; no stable slot |
| `[class*="learner-dashboard"]` | 18 | HIGH | Dashboard top-level wrapper; no stable slot |
| `[class*="learning"]` | 12 | HIGH | Learning MFE top-level; P2 upstream slot request filed |
| `[class*="discussions"]` | 8 | HIGH | Discussions MFE wrapper; P3/cosmetic |
| `[class*="image"]`, `[class*="media"]` | 4 | HIGH | Paragon ImageCap uses dynamic CSS module class names; no stable alternative exists |
| `[class*="course"]`, `[class*="course-card"]` | ~8 | MEDIUM | Learner dashboard course card components; no stable slot |
| `[class*="course-grid"]`, `[class*="course-list"]` | 4 | MEDIUM | Layout containers; data-testid primary removed, class-based retained |
| `[class*="status"]` | 2 | MEDIUM | Status badge pill; no testid for this element |
| `[class*="col"]` | 1 | LOW | Bootstrap `.col-*` prefix match; `.col` itself is stable but `[class*="col"]` catches all breakpoint variants |

---

## Remaining Brittle Selectors — Justification

### Cannot be eliminated without upstream changes

| Selector | Reason retained |
|---------|-----------------|
| `[class*="authn"]` | Authn MFE emits a CSS-module-hashed class containing "authn" on the route root; no `data-testid` exists on all route entry points. Slot `org.openedx.frontend.authn.login.top.v1` exists but requires content injection, not background styling. |
| `[class*="learner-dashboard"]` | Learner Dashboard MFE top-level wrapper. No upstream slot for background/surface scoping. |
| `[class*="account-settings"]`, `[class*="account-page"]` | Account MFE top-level wrappers. No stable slot for surface scoping. |
| `[class*="learning"]` | Learning MFE top-level. Upstream slot request filed (P2). |
| `[class*="discussions"]` | Discussions MFE. Slot `org.openedx.frontend.discussions.post.v1` exists but scopes individual posts, not the surface container. |
| `[class*="image"]`, `[class*="media"]` | Paragon `Card.ImageCap` renders with dynamic CSS module class names that contain "image" or "imagecap". `.pgn__card-image-cap` is the preferred stable selector and is already used; `[class*="image"]` and `[class*="media"]` remain as a broader safety net for layouts that render outside Paragon's ImageCap. |

### Could be eliminated with plugin slot work (future)

| Selector | Replacement strategy | Priority |
|---------|---------------------|----------|
| `[class*="authn"] .pgn__card` | Inject a wrapper with `.mereka-authn-surface` via `org.openedx.frontend.authn.login.top.v1` slot | MEDIUM |
| `[class*="learner-dashboard"]` | Use `org.openedx.frontend.learner-dashboard.course-card.v1` slot to inject `.mereka-dashboard` wrapper class | MEDIUM |
| `[class*="learning"] :is(...)` | Wait for upstream learning layout slot (P2 request) | LOW |
| `[class*="discussions"]` | Inject wrapper class via `org.openedx.frontend.discussions.post.v1` | LOW |

---

## Plugin Slot Opportunities (Future Work)

These are out of scope for T102 (T102 = selector hardening only). Tracked for future tasks.

| Slot ID | Surface | What it enables |
|---------|---------|-----------------|
| `org.openedx.frontend.authn.login.top.v1` | Authn MFE | Inject `.mereka-authn-surface` wrapper → remove all `[class*="authn"]` rules |
| `org.openedx.frontend.learner-dashboard.course-card.v1` | Learner Dashboard | Inject stable class on course cards → remove `[class*="course"]` rules |
| TBD (P2) | Learning MFE | Surface-level slot → remove `[class*="learning"]` rules |
| `org.openedx.frontend.discussions.post.v1` | Discussions MFE | Post-level injection → can partially replace `[class*="discussions"]` |

---

## Verification

**Script**: `scripts/qa/verify-mfe-selectors.sh`

Run:
```bash
./scripts/qa/verify-mfe-selectors.sh
```

Expected output (post-T102):
```
[PASS] AC-UISEL-001: Brittle selector count (72) is within threshold (<= 91)
[PASS] AC-UISEL-001: No [data-testid*=] selectors in production CSS (T102 complete)
[PASS] AC-UISEL-002: 58 SELECTOR-EXCEPTION/KEPT-BRITTLE comment(s) document remaining brittle selectors
```

The threshold is **91** (50% of the original 182). If new brittle selectors are added and the count exceeds 91, the gate will FAIL.

---

## Revision History

| Date | Change |
|------|--------|
| 2026-02-25 | Initial audit (T102) — removed 110 brittle selector lines (60% reduction) |
