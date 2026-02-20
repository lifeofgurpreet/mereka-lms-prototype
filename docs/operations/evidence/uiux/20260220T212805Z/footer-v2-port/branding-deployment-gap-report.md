# Branding Deployment Gap Report

Generated: 2026-02-20T21:28Z
Source: `docs/operations/evidence/uiux/20260220T182026Z-strict-public-branding-prod.txt`
Branch: `feat/23ry2-spec-dedupe-normalize`

## Summary

All 14 branding check failures in the strict production report are **deployment gaps** —
the source is correct but the running image predates the latest theme commits.

**No source-level bugs exist.** All verifiers pass `--source-only`.

---

## Gap Analysis

### 1. Homepage fonts/theming CSS link missing (`/static/mereka/css/mereka-overrides.css`)

| | Status |
|---|---|
| **Source** | CORRECT — `lms/templates/head-extra.html` uses `static.url('mereka/css/mereka-overrides.css')` → `/static/mereka/css/mereka-overrides.css` |
| **Live** | FAILS — HTML contains `/static/css/mereka-overrides.css` (old path, pre-theme prefix) |
| **Root cause** | Deployed LMS image predates commit `28559b4` (`fix: make branding and hostnames verifiable`) |
| **Fix** | `tutor images build openedx` → push → rolling restart (WhiteCliff lane) |

### 2. Studio themed CSS link missing (`/static/studio/mereka/css/studio-main-v1.*.css`)

| | Status |
|---|---|
| **Source** | CORRECT — `cms/static/sass/studio-main-v1.scss` compiles to `/static/studio/mereka/css/studio-main-v1.<hash>.css` with theming |
| **Source check** | `verify-studio-authoring-branding.sh --source-only`: 5/5 PASS |
| **Live** | FAILS — Studio HTML doesn't contain themed CSS link |
| **Root cause** | Same deployment gap as above |
| **Fix** | `tutor images build openedx` → push → rolling restart (WhiteCliff lane) |

### 3. Homepage logo not themed (`/static/images/logo.b6c374d66d57.png` instead of `/static/mereka/images/logo*.png`)

| | Status |
|---|---|
| **Source** | CORRECT — `lms/templates/header/brand.html` uses `static.url('images/logo.png')` which theming resolves to `/static/mereka/images/logo.png` |
| **Live** | FAILS — Default Indigo logo served; `brand.html` override not applied |
| **Root cause** | Deployed image predates `brand.html` template addition |
| **Fix** | Image rebuild (WhiteCliff lane) |

### 4. logo-horizontal.png 404

| | Status |
|---|---|
| **Source** | CORRECT — File exists at `lms/static/images/logo-horizontal.png` |
| **Live** | FAILS — Both `/theming/asset/mereka/images/logo-horizontal.png` and `/static/mereka/images/logo-horizontal.png` return 404 |
| **Root cause** | Deployed image predates this asset being added to the theme |
| **Fix** | Image rebuild (WhiteCliff lane) |

### 5. MFE auth CSS missing branding revision `2026-02-18-us7`

| | Status |
|---|---|
| **Source** | CORRECT — `mfe/mereka.scss` line 6: `--mereka-mfe-branding-rev: "2026-02-18-us7"` |
| **Live** | FAILS — Deployed MFE CSS was built from an older version |
| **Root cause** | MFE image predates commit `d8a1070` (`fix(mfe): patch branding revision 2026-02-08-pass4 → 2026-02-18-us7`) |
| **Fix** | `tutor images build mfe` → push → rolling restart (WhiteCliff lane) |

### 6–14. Microsite font/logo gaps (academy.biji-biji.com, skillourfuture.academy.mereka.io, studio)

Same root cause as items 1–3. All three microsites route to the same LMS/CMS pod — a single image rebuild resolves all microsite gaps simultaneously.

---

## What Is NOT a Deployment Gap (source-correct + deployed)

| Check | Status |
|-------|--------|
| LMS footer content (mereka-footer class, sections) | ✅ DEPLOYED — Live footer has correct structure |
| Studio footer white-label (no "Powered by Open edX") | ✅ DEPLOYED |
| MFE config (Mereka site + logo branding) | ✅ DEPLOYED |
| Favicon asset (favicon.ico) | ✅ DEPLOYED |
| Logo asset (logo.png) | ✅ DEPLOYED (200, 570 bytes) |
| Credentials health | ✅ DEPLOYED |
| Ecommerce branding | ✅ DEPLOYED |

---

## WhiteCliff Handoff Items

These items require image rebuild (NOT source changes):

1. LMS/CMS image rebuild: `tutor images build openedx -a PIP_COMMAND=pip`
2. MFE image rebuild: `tutor images build mfe`
3. Push to `asia-southeast1-docker.pkg.dev/mereka-lms/openedx`
4. Update image tags in `deploy/k8s/overlays/production/kustomization.yaml`
5. ArgoCD rolling restart → re-run strict branding verifier to confirm 0 failures
