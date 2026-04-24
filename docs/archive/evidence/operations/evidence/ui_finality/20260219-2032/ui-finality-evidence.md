# UI Finality Evidence — 3449

> **Bead**: mereka-lms-3449 (AC-BRD-001..004)
> **Date**: 2026-02-19T20:32 UTC
> **Branch**: feat/23ry2-spec-dedupe-normalize
> **Operator**: WhiteCliff

---

## Summary

| AC | Result | Notes |
|----|--------|-------|
| AC-BRD-001 | **PASS** | Route matrix — all 8 prod surfaces 200 (auth redirects expected) |
| AC-BRD-002 | **PASS** | Deep branding gates stable — exit 0, gaps=4 (MFE revision drift only, strict=0) |
| AC-BRD-003 | **PASS** | DOM evidence captured for all 8 surfaces; footer parity confirmed |
| AC-BRD-004 | **PASS** | No unplanned hacks — all fixes via source canonical paths |

**Non-strict PASS. Strict (STRICT_MFE_BRANDING_REV=1) exits 1 with 4 known MFE revision gaps.**

---

## Route Matrix

| Surface | Status | Final | Notes |
|---------|--------|-------|-------|
| `academyv2.mereka.io/` | 200 | 200 | LMS homepage — 208KB, fully branded |
| `academyv2.mereka.io/dashboard` | 302 | 200 | → `/authn/login?next=/dashboard` (expected auth) |
| `admin.academyv2.mereka.io/` | 200 | 200 | Authn shell (`<div id="root">`) |
| `studio.academyv2.mereka.io/` | 200 | 200 | Studio — 13KB, branded |
| `apps.academyv2.mereka.io/authn/login` | 200 | 200 | Authn shell |
| `ecommerce.academyv2.mereka.io/dashboard/` | 200 | 200 | Authn shell |
| `credentials.academyv2.mereka.io/admin/login/` | 200 | 200 | Authn shell |
| `skillourfuture.academy.mereka.io/` | 200 | 200 | Microsite — 10KB, branded |
| `academy.biji-biji.com/` | 200 | 200 | Microsite — 12KB, branded |

---

## Branding Gate Results

### Non-strict (`BRANDING_LEVEL=deep`)
```
verify-public-branding.sh prod      → All branding checks passed (EXIT 0)
audit-branding-surfaces.sh prod     → gaps=4 strict=0 (EXIT 0)
verify-studio-authoring-branding.sh → failures=0 (EXIT 0)
run-branding-gates.sh prod (deep)   → EXIT 0
```

### Strict (`STRICT_MFE_BRANDING_REV=1 BRANDING_LEVEL=deep`)
```
run-branding-gates.sh prod (strict) → 4 branding checks failed (EXIT 1)
Failures: all MFE authn CSS revision mismatch
  deployed=2026-02-08-pass4, source=2026-02-18-us7
  Root cause documented in: docs/archive/evidence/operations/evidence/2qpt/mfe-revision-parity-evidence.md
  Resolution: rebuild MFE image
```

---

## DOM Evidence Signals

All captures saved to `docs/archive/evidence/operations/evidence/ui_finality/20260219-2032/dom-*.html`

| Surface | DOM size | `<div id="root">` | Mereka refs | Logo refs | Google fonts | Tracking |
|---------|----------|-------------------|-------------|-----------|--------------|---------|
| academy | 208KB | — (LMS full page) | 568 | 3 | **0** | no-op stub only |
| admin | 838B | **1** (authn shell) | 0 | 0 | **0** | none |
| studio | 13KB | — (Studio full page) | 15 | 3 | **0** | no-op stub only |
| authn | 1.4KB | **1** (authn shell) | 0 | 0 | **0** | none |
| ecommerce-dashboard | 1.4KB | **1** (authn shell) | 0 | 0 | **0** | none |
| credentials-admin | 1.4KB | **1** (authn shell) | 0 | 0 | **0** | none |
| skillourfuture | 10KB | — (LMS full page) | 21 | 3 | **0** | no-op stub only |
| biji-biji | 12KB | — (LMS full page) | 19 | 3 | **0** | no-op stub only |

**No Google fonts on any surface** ✓

**Analytics note**: LMS pages (academy/studio/microsites) contain upstream `<!-- dummy Segment -->` stub
from edx-platform base template. This is a no-op shim (`analytics = { track: function() {} }`).
No external analytics requests are made. This is upstream default behavior when `SEGMENT_KEY` is not
configured — not a regression from our 2k6k footer cleanup.

---

## Footer Parity Check

Deployed footer HTML on `academyv2.mereka.io/`:

```html
<div class="wrapper wrapper-footer mereka-footer">
  <footer id="footer" class="tutor-container" ...>
    <div class="footer-primary">
      <div class="footer-brand">
        <img src="...logo.png" alt="Mereka Academy logo" />
        <p>Mereka Academy blends community, craftsmanship, and technology to help learners master
        the creative, digital, and entrepreneurial skills powering Southeast Asia.</p>
        <div class="footer-tags">
          <span>Future of Work</span>
          <span>Creative Tech</span>
          <span>Impact</span>
        </div>
      </div>
      <div class="footer-links">
        <h6>Explore</h6>
        <ul>
          <li><a href="/courses">Courses</a></li>
          <li><a href="/dashboard">My learning</a></li>
          <li><a href="https://mereka.my" ...>Mereka main site</a></li>
          <li><a href="mailto:team@mereka.io">team@mereka.io</a></li>
        </ul>
      </div>
      <!-- Support + Partners columns present -->
    </div>
    <div class="footer-bottom">
      <span>© 2026 Biji-Biji Initiative · Mereka Academy</span>
      <span>Powered by Open edX and Tutor</span>
    </div>
  </footer>
</div>
```

**Footer matches spec** ✓ — brand copy, navigation links, and colophon all correct.
**No Segment include in footer** ✓ — 2k6k cleanup confirmed deployed.

---

## DR1.md P0 Finding Status

| Finding | Status | Notes |
|---------|--------|-------|
| `--mereka-color-ink-600` undefined | **RESOLVED** | theme.scss uses only ink-500/700/900 (no ink-600) |
| MFE theming brittle selectors | **KNOWN** | Documented in DR1.md; tactical bridge, migration to slots out of scope |
| Routing + QA contract mismatch | **KNOWN** | separate track |

---

## Evidence Files

```
docs/archive/evidence/operations/evidence/ui_finality/20260219-2032/
├── ui-finality-evidence.md          (this file)
├── route-matrix.txt                  (route status for all 8 surfaces)
├── verify-public-branding.log        (verify-public-branding.sh prod output)
├── audit-branding-surfaces.log       (audit-branding-surfaces.sh prod output)
├── verify-studio-authoring.log       (verify-studio-authoring-branding.sh prod output)
├── strict-gates.log                  (STRICT_MFE_BRANDING_REV=1 output)
├── dom-academy.html                  (208KB LMS homepage DOM)
├── dom-admin.html                    (authn shell)
├── dom-studio.html                   (Studio page DOM)
├── dom-authn.html                    (authn shell)
├── dom-ecommerce-dashboard.html      (authn shell)
├── dom-credentials-admin.html        (authn shell)
├── dom-skillourfuture.html           (microsite DOM)
├── dom-biji-biji.html                (microsite DOM)
└── dom-evidence-summary.txt          (per-surface signal summary)
```
