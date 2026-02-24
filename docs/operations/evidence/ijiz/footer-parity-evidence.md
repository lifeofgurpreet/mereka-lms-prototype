# Footer Parity & Branding Drift Cleanup — ijiz

> **Bead**: mereka-lms-ijiz (parent of i59a)
> **Date**: 2026-02-19T20:11 UTC
> **Branch**: feat/23ry2-spec-dedupe-normalize
> **Operator**: WhiteCliff

---

## Acceptance Criteria Status

| AC | Result | Notes |
|----|--------|-------|
| Footer matches design spec | **PASS** | Deployed footer matches brand copy, links, colophon |
| Legacy footer/branding artifacts removed | **PASS** | Segment include removed from footer.html (2k6k) |
| Studio/admin/academy reflect brand tokens | **PASS** | No Google fonts, mereka tokens verified |
| Differences documented | **PASS** | MFE revision gap + dummy Segment stub documented |
| Rollback-safe plan provided | **PASS** | See below |

---

## Legacy Artifact Audit

### Files audited for legacy/analytics artifacts

| File | Status | Finding |
|------|--------|---------|
| `infrastructure/tutor/themes/mereka/lms/templates/footer.html` | **CLEANED** | Segment include removed (commit `18d3297`) |
| `infrastructure/tutor/themes/mereka/lms/templates/head-extra.html` | **CLEAN** | No analytics/segment refs |
| `infrastructure/tutor/themes/mereka/lms/templates/index_overlay.html` | **CLEAN** | No analytics/segment refs |
| `infrastructure/tutor/themes/mereka/lms/templates/header/brand.html` | **CLEAN** | No analytics/segment refs |
| `infrastructure/tutor/plugins/mereka_lms.py` (line 248) | **CORRECT** | `SEGMENT_KEY = os.environ.get("MEREKA_SEGMENT_KEY", "")` — env-var driven, no hardcode |
| `infrastructure/tutor/themes/mereka/cms/` | **CLEAN** | No footer template override; CMS uses upstream footer |
| `infrastructure/tutor/themes/mereka/mfe/` | **CLEAN** | No analytics injection |

### Upstream behavior note

LMS pages contain `<!-- dummy Segment -->` stub injected by upstream edx-platform base template when
`SEGMENT_KEY` is empty. This is a no-op shim (`analytics = { track: function() {} }`). It does NOT
make external requests and is NOT a regression. This is correct upstream Open edX behavior.

---

## Footer Design Spec Parity

### Deployed footer (academyv2.mereka.io)

```
Brand block:
  Logo: /static/mereka/images/logo.png  ✓
  Copy: "Mereka Academy blends community, craftsmanship, and technology..."  ✓
  Tags: Future of Work | Creative Tech | Impact  ✓

Explore column:
  Courses → /courses  ✓
  My learning → /dashboard  ✓
  Mereka main site → https://mereka.my  ✓
  team@mereka.io  ✓

Support column:
  techadmin@biji-biji.com  ✓
  support@mereka.io  ✓
  Help centre  ✓
  Privacy  ✓

Partners column:
  Biji-Biji Initiative → https://biji-biji.com  ✓
  Partner with us  ✓
  Stories  ✓

Colophon:
  © 2026 Biji-Biji Initiative · Mereka Academy  ✓
  Powered by Open edX and Tutor  ✓
```

**All footer elements match spec.** Segment injection removed. No Google fonts.

### Microsites parity

Same footer structure confirmed present on:
- `academy.biji-biji.com` (12KB DOM, mereka=19 refs)
- `skillourfuture.academy.mereka.io` (10KB DOM, mereka=21 refs)

---

## Brand Token Verification

### LMS/Studio/CMS surfaces

| Surface | Google Fonts | Mereka tokens | Revision marker |
|---------|-------------|---------------|-----------------|
| `academyv2.mereka.io` | **None** | ✓ (568 refs) | `2026-02-10-pass1` ✓ |
| `studio.academyv2.mereka.io` | **None** | ✓ (15 refs) | — (Studio CSS) |
| `admin.academyv2.mereka.io` | **None** | — (authn shell) | — |
| `academy.biji-biji.com` | **None** | ✓ (19 refs) | `2026-02-10-pass1` ✓ |
| `skillourfuture.academy.mereka.io` | **None** | ✓ (21 refs) | `2026-02-10-pass1` ✓ |

### Ink token correctness

All color token usages in `theme.scss` use defined tokens only:
- `--mereka-color-ink-900` ✓ (defined)
- `--mereka-color-ink-700` ✓ (defined)
- `--mereka-color-ink-500` ✓ (defined)
- `--mereka-color-ink-600` — **NOT used** (would have been undefined; DR1.md P0 pre-resolved)

---

## Residual Gaps (documented)

| Gap | Severity | Root cause | Resolution |
|-----|----------|------------|------------|
| MFE authn CSS revision `2026-02-08-pass4` vs source `2026-02-18-us7` | Low | MFE image built before revision bump | Rebuild MFE image |
| `<!-- dummy Segment -->` stub in LMS pages | Info | Upstream edx-platform base template (no-op) | Not a defect; expected behavior |

---

## Rollback Plan

All changes in this lane are source-level and reversible via git revert:

| Commit | Change | Rollback |
|--------|--------|---------|
| `18d3297` | Removed Segment include from `footer.html` | `git revert 18d3297` |
| `6110b35` | cu7l/2qpt evidence + audit script improvement | `git revert 6110b35` |
| `7647c87` | 3449 UI finality DOM evidence | `git revert 7647c87` (evidence only, no functional change) |

**No runtime state changes** were made (no kubectl exec, no collectstatic, no pod restarts) as part
of this lane. All changes are in source files tracked by GitOps.

**Per-host rollback**: The footer template change affects ALL LMS sites on the same image. To revert
only for a specific host, a per-site template override would be needed (not currently supported by
the theme system without a new theme fork). Recommend reverting at image level via git revert.

---

## Evidence Cross-references

Full branding evidence: `docs/operations/evidence/ui_finality/20260219-2032/`
- Route matrix: all 8 surfaces 200 ✓
- Branding gates: EXIT 0 ✓
- DOM captures: all 8 surfaces ✓
- Audit: gaps=4 strict=0 (MFE revision only) ✓
