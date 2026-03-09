---
title: OEP-48 Brand Package (@edx/brand for Mereka Academy)
type: feature_spec
status: draft
version: 1.0.0
owner: engineering
vehicle: talent_platform
depends_on:
- specs/branding-system_spec.md
- specs/design-tokens-system_spec.md
links:
  related_docs:
  - docs/BRANDING.md
  - docs/branding/BRANDING_OPERATING_MODEL.md
  related_specs:
  - specs/cross-cutting-requirements_spec.md
  - specs/branding-system_spec.md
  - specs/design-tokens-system_spec.md
  - specs/multi-tenancy-architecture_spec.md
  - specs/tutor-configuration_spec.md
id: SPEC-OEP48-BRAND-PACKAGE
spec_class: domain
created: '2026-02-27'
last_reviewed: '2026-02-27'
review_due: '2026-05-28'
domain: frontend
normativity: normative
summary: Normative contract for the OEP-48 brand package used by Mereka Academy frontends.
---

# Human Summary

## What is changing

We are creating an `@edx/brand` npm package for Mereka Academy following the OEP-48 brand package interface specification. The package will live at `infrastructure/tutor/brand-mereka/` in the monorepo and be installed into MFE builds via npm alias (`@edx/brand@file:./brand-mereka`). This replaces the current state where MFEs use stock Open edX branding because no brand package exists.

The package bundles:
- Logo SVGs and PNGs (`logo.svg`, `logo-white.svg`, `logo.png`, `logo-white.png`)
- Favicon (`favicon.ico`)
- Self-hosted Poppins and Lato web fonts with a `paragon/fonts.scss` entrypoint
- A backward-compatible `paragon/_variables.scss` (deprecated in Ulmo but required for older MFE versions)
- A `paragon/tokens.json` placeholder (full token pipeline defined in `design-tokens-system_spec.md`)

The Tutor plugin (`infrastructure/tutor/plugins/mereka_lms.py`) will be updated to install this package during the MFE Docker build via the `mfe-dockerfile-pre-npm-install` hook, using an npm alias that maps `@edx/brand` to the local package path.

## Why

Every Open edX MFE imports branding from the `@edx/brand` package. Without a Mereka-specific brand package, all MFEs render with stock Open edX logos, default system fonts, and no visual connection to the Mereka Academy brand. OEP-48 defines the canonical interface that MFEs expect -- if we conform to it, branding applies automatically across all current and future MFEs without per-MFE patching. This is the upstream-endorsed approach; our current theme-level branding (comprehensive theming via `infrastructure/tutor/themes/mereka/`) only covers LMS/Studio server-rendered pages, not the React-based micro-frontends.

The forcing function is Ulmo (Tutor v21 / Open edX Dec 2025 release), which deprecated SCSS-based branding (`_variables.scss`) in favor of JSON design tokens (`tokens.json`). We need the package structure in place now so we can incrementally adopt tokens without a disruptive migration later.

## Success looks like

- All MFEs (authn, account, profile, learning, gradebook, discussions) display the Mereka logo, Mereka favicon, and self-hosted Poppins/Lato fonts.
- Zero external font CDN requests (Google Fonts, Adobe Fonts) from any MFE page.
- `scripts/qa/verify-brand-package/verify-brand-package-structure.sh` passes in CI on every build.
- A developer can update a logo by replacing a file in `infrastructure/tutor/brand-mereka/` and rebuilding the MFE image -- no other changes required.
- The brand package structure validates against the OEP-48 interface, confirmed by automated checks.

---

# Agent Contract

## Scope

### In Scope

- Brand package directory structure at `infrastructure/tutor/brand-mereka/`
- `package.json` with name `@edx/brand-mereka`, appropriate exports, and version field
- Logo files: `logo.svg`, `logo-white.svg`, `logo.png`, `logo-white.png` (copied from existing theme assets)
- Favicon: `favicon.ico` (copied from existing theme assets)
- `paragon/fonts.scss` with `@font-face` declarations for self-hosted Poppins and Lato woff2 files
- `paragon/_variables.scss` with backward-compatible SCSS variable overrides (colors, font families)
- `paragon/tokens.json` placeholder with minimal required structure
- Font files: Poppins (Regular, SemiBold, Bold) and Lato (Regular, Bold, Italic, BoldItalic, Black, BlackItalic) in woff2 format
- Tutor plugin update: npm alias install of the brand package during MFE build
- Verification script: `scripts/qa/verify-brand-package/verify-brand-package-structure.sh`
- CI integration: add verification script to `.github/ci-scripts-static.txt`

### Out of Scope

- Multi-tenant brand switching (per-tenant brand packages) -- covered by `specs/multi-tenancy-architecture_spec.md`
- Full JSON design token pipeline (`tokens.json` populated with all Paragon tokens) -- covered by a future `paragon-design-tokens-migration_spec.md`
- Custom React components (footers, headers) -- covered by `specs/branding-system_spec.md`
- Publishing to npm registry (package is local/monorepo only)
- Dark mode token variants
- MFE-specific brand overrides (all MFEs share a single brand package)

## Non-goals

- We are NOT building a multi-brand switching system. One brand package serves all MFEs.
- We are NOT implementing the full Paragon design token pipeline. `tokens.json` is a placeholder with minimal structure; the full token migration is a separate spec.
- We are NOT publishing this package to any npm registry. It is consumed via file path alias only.
- We are NOT replacing the comprehensive theme system (Django/SASS). The brand package and the comprehensive theme are complementary: brand package covers MFEs, comprehensive theme covers LMS/Studio server-rendered pages.
- We are NOT building automated Figma-to-package sync. Asset updates are manual (copy files, rebuild).

## Requirements

### Functional

#### Package Structure

The brand package MUST conform to the OEP-48 interface:

```
infrastructure/tutor/brand-mereka/
├── package.json
├── logo.svg
├── logo-white.svg
├── logo.png
├── logo-white.png
├── favicon.ico
├── paragon/
│   ├── fonts.scss
│   ├── _variables.scss
│   └── tokens.json
└── fonts/
    ├── Poppins-Regular.woff2
    ├── Poppins-SemiBold.woff2
    ├── Poppins-Bold.woff2
    ├── Lato-Regular.woff2
    ├── Lato-Bold.woff2
    ├── Lato-Italic.woff2
    ├── Lato-BoldItalic.woff2
    ├── Lato-Black.woff2
    └── Lato-BlackItalic.woff2
```

#### package.json

- The `package.json` MUST set `"name"` to `"@edx/brand-mereka"`.
- The `package.json` MUST include a `"version"` field following semver (initial: `"1.0.0"`).
- The `package.json` MUST include a `"description"` field identifying it as the Mereka Academy OEP-48 brand package.
- The `package.json` SHOULD include an `"exports"` or `"main"` field if required by consuming MFEs.
- The `package.json` MUST NOT declare any `"dependencies"` (brand packages are asset-only).
- The `package.json` MAY declare `"peerDependencies"` on `@openedx/paragon` to signal Paragon version compatibility.

#### Logo Files

- The package MUST include `logo.svg` as the primary brand mark (horizontal Mereka logo).
- The package MUST include `logo-white.svg` as the white/inverted variant for dark backgrounds.
- The package MUST include `logo.png` as a raster fallback (minimum 200px wide).
- The package MUST include `logo-white.png` as a raster fallback for the white variant.
- The package MUST include `favicon.ico` containing at least 16x16 and 32x32 pixel sizes.
- Logo SVG files MUST be optimized (no embedded raster images, no unnecessary metadata).
- Logo SVG files MUST include a `viewBox` attribute for responsive scaling.
- All logo files MUST be sourced from `infrastructure/tutor/themes/mereka/lms/static/images/`.

#### Font Files and fonts.scss

- The package MUST include self-hosted woff2 font files for Poppins (Regular, SemiBold, Bold) and Lato (Regular, Bold, Italic, BoldItalic, Black, BlackItalic).
- The `paragon/fonts.scss` file MUST declare `@font-face` rules for each font weight/style variant.
- Each `@font-face` rule MUST use `font-display: swap` to prevent invisible text during font loading.
- Each `@font-face` rule MUST reference the font file via a relative path from the package root (`../fonts/Poppins-Regular.woff2`).
- The `paragon/fonts.scss` MUST NOT import from any external CDN (Google Fonts, Adobe Fonts, etc.).
- Font files MUST be sourced from `infrastructure/tutor/themes/mereka/lms/static/fonts/`.

#### _variables.scss (Backward Compatibility)

- The `paragon/_variables.scss` file MUST define `$font-family-sans-serif` using Poppins as primary, with system font stack fallback.
- The file MUST define `$font-family-heading` using Lato as primary, with system font stack fallback.
- The file MUST define `$primary` color variable matching the Mereka magenta (`#ab3b78`).
- The file MUST define `$secondary` color variable matching the Mereka teal (`#237072`).
- The file SHOULD include a deprecation comment stating that SCSS variables are deprecated in Ulmo and will be replaced by `tokens.json`.
- The file MUST NOT override variables that break Paragon component rendering (e.g., `$grid-breakpoints`, `$spacers`).

#### tokens.json (Placeholder)

- The `paragon/tokens.json` file MUST exist and contain valid JSON.
- The file MUST include at minimum a `"colors"` key with `"primary"` set to the Mereka magenta hex value.
- The file MUST include a `"typography"` key with `"font-family-sans-serif"` set to the Poppins font stack.
- The file SHOULD include a comment (via `"_comment"` key) indicating this is a placeholder pending full token migration.
- The file MUST be parseable by Paragon's token consumer without errors.

#### Tutor Plugin Integration

- The Tutor plugin MUST install the brand package via npm alias during the MFE Docker build.
- The installation MUST use the `mfe-dockerfile-pre-npm-install` hook to ensure the package is available before `npm install` runs.
- The Dockerfile patch MUST copy the `brand-mereka/` directory into the MFE build context.
- The Dockerfile patch MUST run `npm install @edx/brand@file:./brand-mereka` (or equivalent alias) to register the package.
- The installation MUST NOT break existing MFE npm dependency resolution.
- The installation SHOULD use `--legacy-peer-deps` if Paragon peer dependency conflicts arise.

#### Asset Provenance

- Logo files in the brand package MUST be byte-identical copies of the corresponding files in `infrastructure/tutor/themes/mereka/lms/static/images/`.
- Font files in the brand package MUST be byte-identical copies of the corresponding files in `infrastructure/tutor/themes/mereka/lms/static/fonts/`.
- A sync script (`scripts/branding/sync-brand-package.sh`) SHOULD exist to copy assets from the theme directory to the brand package directory, ensuring consistency.

### Non-Functional Requirements

- [ ] AC-BRAND-NFR-001: The total brand package size (all files) MUST be under 3 MB to avoid excessive MFE build time increase.
- [ ] AC-BRAND-NFR-002: Installing the brand package during MFE build SHOULD add no more than 15 seconds to the total build time.
- [ ] AC-BRAND-NFR-003: The brand package MUST NOT introduce any runtime JavaScript dependencies (asset-only package).
- [ ] AC-BRAND-NFR-004: Font files MUST load within 2 seconds on a 4G connection (woff2 compression).

**Cross-Cutting Inheritance**: This spec inherits requirements from `specs/cross-cutting-requirements_spec.md` including:
- Observability baseline (build logs, CI verification)
- Secrets management (no secrets in brand package)

Only domain-specific NFRs are listed above.

## Acceptance Criteria

### Package Structure

- [ ] AC-BRAND-001: Given the directory `infrastructure/tutor/brand-mereka/` exists, when its contents are listed, then it contains exactly these files: `package.json`, `logo.svg`, `logo-white.svg`, `logo.png`, `logo-white.png`, `favicon.ico`, `paragon/fonts.scss`, `paragon/_variables.scss`, `paragon/tokens.json`, and a `fonts/` directory with 9 woff2 files.
- [ ] AC-BRAND-002: Given `infrastructure/tutor/brand-mereka/package.json`, when parsed as JSON, then `name` is `"@edx/brand-mereka"`, `version` matches semver pattern `\d+\.\d+\.\d+`, and `dependencies` is either absent or an empty object.
- [ ] AC-BRAND-003: Given `infrastructure/tutor/brand-mereka/package.json`, when inspected, then `description` is non-empty and contains "Mereka" or "OEP-48".

### Logo Files

- [ ] AC-BRAND-004: Given `infrastructure/tutor/brand-mereka/logo.svg`, when opened, then it is a valid SVG file containing a `viewBox` attribute and no embedded `<image>` elements with base64 data.
- [ ] AC-BRAND-005: Given `infrastructure/tutor/brand-mereka/logo-white.svg`, when opened, then it is a valid SVG file containing a `viewBox` attribute.
- [ ] AC-BRAND-006: Given `infrastructure/tutor/brand-mereka/logo.png`, when inspected with `file` or `identify`, then it is a valid PNG image with width >= 200 pixels.
- [ ] AC-BRAND-007: Given `infrastructure/tutor/brand-mereka/logo-white.png`, when inspected, then it is a valid PNG image.
- [ ] AC-BRAND-008: Given `infrastructure/tutor/brand-mereka/favicon.ico`, when inspected, then it is a valid ICO file containing at least one icon layer.
- [ ] AC-BRAND-009: Given the logo files in the brand package, when compared byte-for-byte with `infrastructure/tutor/themes/mereka/lms/static/images/logo.svg`, `logo-white.svg`, `logo.png`, `logo-white.png`, and `favicon.ico`, then they are identical (sha256 match).

### Font Files

- [ ] AC-BRAND-010: Given `infrastructure/tutor/brand-mereka/fonts/`, when listed, then it contains exactly: `Poppins-Regular.woff2`, `Poppins-SemiBold.woff2`, `Poppins-Bold.woff2`, `Lato-Regular.woff2`, `Lato-Bold.woff2`, `Lato-Italic.woff2`, `Lato-BoldItalic.woff2`, `Lato-Black.woff2`, `Lato-BlackItalic.woff2`.
- [ ] AC-BRAND-011: Given each woff2 file in `infrastructure/tutor/brand-mereka/fonts/`, when inspected with `file`, then it is identified as a Web Open Font Format (Version 2) file.
- [ ] AC-BRAND-012: Given the font files in the brand package, when compared byte-for-byte with the corresponding files in `infrastructure/tutor/themes/mereka/lms/static/fonts/`, then they are identical (sha256 match).

### fonts.scss

- [ ] AC-BRAND-013: Given `infrastructure/tutor/brand-mereka/paragon/fonts.scss`, when parsed, then it contains at least 9 `@font-face` declarations (one per font file).
- [ ] AC-BRAND-014: Given each `@font-face` declaration in `fonts.scss`, when inspected, then it includes `font-display: swap`.
- [ ] AC-BRAND-015: Given each `@font-face` declaration in `fonts.scss`, when inspected, then the `src` URL references a relative path starting with `../fonts/` pointing to a file that exists in the `fonts/` directory.
- [ ] AC-BRAND-016: Given `fonts.scss`, when searched for external URLs, then it contains zero references to `googleapis.com`, `gstatic.com`, `typekit.net`, or any other external font CDN.

### _variables.scss

- [ ] AC-BRAND-017: Given `infrastructure/tutor/brand-mereka/paragon/_variables.scss`, when parsed, then it defines `$font-family-sans-serif` containing "Poppins".
- [ ] AC-BRAND-018: Given `_variables.scss`, when parsed, then it defines `$primary` with value `#ab3b78` (case-insensitive match).
- [ ] AC-BRAND-019: Given `_variables.scss`, when inspected, then it contains a comment indicating SCSS variables are deprecated in favor of `tokens.json`.

### tokens.json

- [ ] AC-BRAND-020: Given `infrastructure/tutor/brand-mereka/paragon/tokens.json`, when parsed as JSON, then it is valid JSON containing at minimum a `"colors"` key with a `"primary"` value.
- [ ] AC-BRAND-021: Given `tokens.json`, when parsed, then `colors.primary` equals `"#ab3b78"` (Mereka magenta).
- [ ] AC-BRAND-022: Given `tokens.json`, when parsed, then it contains a `"typography"` key with `"font-family-sans-serif"` containing "Poppins".

### Tutor Plugin Integration

- [ ] AC-BRAND-023: Given `infrastructure/tutor/plugins/mereka_lms.py`, when inspected, then it contains a `mfe-dockerfile-pre-npm-install` patch that copies the `brand-mereka/` directory into the MFE build context.
- [ ] AC-BRAND-024: Given the Tutor plugin MFE Dockerfile patches, when the MFE image is built, then `npm ls @edx/brand` inside the built container resolves to the brand-mereka package (exit 0, shows `@edx/brand-mereka`).
- [ ] AC-BRAND-025: Given the brand package is installed via npm alias, when `tutor images build mfe` completes, then the build exits 0 without npm peer dependency errors related to `@edx/brand`.

### Verification Gates

- [ ] AC-BRAND-026: Given `scripts/qa/verify-brand-package/verify-brand-package-structure.sh` exists, when executed, then it validates all structural requirements (directory layout, file existence, package.json fields, fonts.scss declarations, SVG viewBox, logo pixel width, font file types) and exits 0.
- [ ] AC-BRAND-027: Given `scripts/qa/verify-brand-package/verify-brand-package-structure.sh`, when a required file is missing from the brand package, then the script exits non-zero with a message identifying the missing file.
- [ ] AC-BRAND-028: Given `.github/ci-scripts-static.txt`, when inspected, then it contains the path `scripts/qa/verify-brand-package/verify-brand-package-structure.sh`.

### Cross-Spec Integration

#### Branding System (branding-system_spec.md)

- [ ] AC-BRAND-INT-001: Given the brand package logo files and the comprehensive theme logo files in `infrastructure/tutor/themes/mereka/lms/static/images/`, when compared, then the brand package logos are identical copies (ensuring visual consistency between MFEs and LMS/Studio).
- [ ] AC-BRAND-INT-002: Given the brand package font files and the comprehensive theme font files in `infrastructure/tutor/themes/mereka/lms/static/fonts/`, when compared, then the brand package fonts are identical copies.

#### Design Tokens System (design-tokens-system_spec.md)

- [ ] AC-BRAND-INT-003: Given `paragon/tokens.json` in the brand package and `assets/branding/tokens.css`, when the primary color is compared, then both define the same Mereka magenta value (`#ab3b78`).
- [ ] AC-BRAND-INT-004: Given `paragon/_variables.scss` in the brand package, when the `$primary` value is compared with `--color-magenta` from `assets/branding/tokens.css`, then both resolve to the same hex value.

#### Multi-Tenancy Architecture (multi-tenancy-architecture_spec.md -- Future)

- [ ] AC-BRAND-INT-005: Given the current single-brand package structure, when multi-tenant brand switching is implemented in the future, then the package structure is compatible with being parameterized per tenant (directory-based brand selection).

## Dependencies

### Upstream

- **specs/branding-system_spec.md**: Theme assets (logos, fonts) in `infrastructure/tutor/themes/mereka/` must exist. These are the source files copied into the brand package.
- **specs/design-tokens-system_spec.md**: Token values (`#237072` teal, Poppins/Lato font families) must be defined. The brand package's `_variables.scss` and `tokens.json` must align with canonical token definitions.
- **specs/tutor-configuration_spec.md**: The Tutor plugin hook system (`mfe-dockerfile-pre-npm-install`) must be functional. The brand package installation depends on this hook firing during MFE builds.

### Downstream

- **Future: paragon-design-tokens-migration_spec.md**: Will fully populate `paragon/tokens.json` with all Paragon token overrides. Currently a placeholder.
- **specs/multi-tenancy-architecture_spec.md**: Multi-tenant brand switching will need to extend this package structure to support per-tenant brand directories.

## Edge Cases

### npm Peer Dependency Conflict with Paragon

**Symptom**: `npm install @edx/brand@file:./brand-mereka` fails with `ERESOLVE` error about Paragon version mismatch.

**Cause**: The brand package declares a `peerDependencies` range on `@openedx/paragon` that does not include the version used by the MFE.

**Recovery**:
```bash
# Option 1: Use --legacy-peer-deps (already in Tutor plugin)
npm install @edx/brand@file:./brand-mereka --legacy-peer-deps

# Option 2: Widen the peerDependencies range in brand-mereka/package.json
# e.g., "@openedx/paragon": ">=21.0.0"

# Option 3: Remove peerDependencies entirely (brand packages are asset-only)
```

### Brand Package Not Found During MFE Build

**Symptom**: MFE build fails with `npm ERR! Could not install from "brand-mereka" as it does not contain a package.json`.

**Cause**: The `COPY` directive in the Dockerfile patch did not copy the brand-mereka directory, or the path is wrong.

**Recovery**:
```bash
# Verify the Tutor plugin patch copies the directory
grep -A5 "brand-mereka" infrastructure/tutor/plugins/mereka_lms.py

# Verify the directory exists in the build context
tutor config render --extra-config "MFE_DOCKERFILE" | grep brand-mereka

# Rebuild with verbose output
tutor images build mfe --no-cache 2>&1 | grep -i brand
```

### SVG Logo Missing viewBox

**Symptom**: Logo renders at wrong size in some MFE contexts, or `verify-brand-package-structure.sh` fails.

**Cause**: SVG exported from design tool without `viewBox` attribute.

**Recovery**:
```bash
# Check SVG for viewBox
grep -i "viewBox" infrastructure/tutor/brand-mereka/logo.svg

# Add viewBox if missing (use actual dimensions)
# <svg viewBox="0 0 200 50" ...>

# Re-export from Figma with "Include viewBox" option enabled
```

### Font Not Loading (404 in Browser)

**Symptom**: Browser console shows 404 for woff2 font files from MFE pages. Text renders in system fallback fonts.

**Cause**: The relative path in `fonts.scss` does not resolve correctly after webpack bundling.

**Recovery**:
```bash
# Check the built MFE for font files
docker run --rm <mfe-image> ls -la /openedx/dist/fonts/ 2>/dev/null
docker run --rm <mfe-image> find /openedx/dist -name "*.woff2" 2>/dev/null

# If fonts are missing from the bundle, the webpack file-loader/asset module
# may not be resolving the relative path. Try using an absolute path in fonts.scss:
# url('/static/brand-mereka/fonts/Poppins-Regular.woff2')
```

### tokens.json Parse Error in Future Paragon Version

**Symptom**: MFE build fails with JSON parse error in Paragon token consumer.

**Cause**: Future Paragon version expects a different `tokens.json` schema than the placeholder structure.

**Recovery**:
```bash
# Check Paragon's expected schema
npm info @openedx/paragon | grep -i token

# Update tokens.json to match the expected schema
# This is tracked in the future paragon-design-tokens-migration spec
```

### Stale Brand Package After Theme Asset Update

**Symptom**: LMS/Studio shows updated logo but MFEs still show old logo.

**Cause**: Assets were updated in `infrastructure/tutor/themes/mereka/` but not synced to `infrastructure/tutor/brand-mereka/`.

**Recovery**:
```bash
# Run the sync script
./scripts/branding/sync-brand-package.sh

# Rebuild MFE image
tutor images build mfe

# Restart MFE pods
tutor k8s restart mfe
```

## Observability

### Logs

- MFE build logs MUST show the npm alias installation of `@edx/brand`: look for `+ @edx/brand@file:brand-mereka` in `tutor images build mfe` output.
- The verification script MUST output PASS/FAIL per check with the AC ID: `PASS AC-BRAND-001: Package structure valid`.
- The sync script (`sync-brand-package.sh`) MUST log which files were copied and their sha256 checksums.

### Metrics

- CI SHOULD track brand package verification pass/fail rate over time.
- MFE build time SHOULD be monitored for regression after brand package installation is added (baseline: current build time + acceptable delta of 15 seconds).

### Alerts

- CI MUST fail if `verify-brand-package-structure.sh` exits non-zero (blocking merge).
- CI SHOULD warn if brand package total size exceeds 2.5 MB (approaching 3 MB limit).

### Dashboards

- No dedicated dashboard required. Brand package health is visible via CI pipeline status.

## Rollout & Rollback

### Initial Rollout

```bash
# 1. Create the brand package directory
mkdir -p infrastructure/tutor/brand-mereka/paragon infrastructure/tutor/brand-mereka/fonts

# 2. Copy assets from theme directory
./scripts/branding/sync-brand-package.sh

# 3. Create package.json, fonts.scss, _variables.scss, tokens.json
# (see implementation for file contents)

# 4. Update Tutor plugin with mfe-dockerfile-pre-npm-install patch
# Edit infrastructure/tutor/plugins/mereka_lms.py

# 5. Verify package structure
./scripts/qa/verify-brand-package/verify-brand-package-structure.sh

# 6. Build MFE image
tutor images build mfe

# 7. Deploy and verify
tutor k8s restart mfe
curl -sI https://apps.academyv2.mereka.io/authn/login | head -5
```

### Updating Brand Assets

```bash
# 1. Update source assets in theme directory
cp new-logo.svg infrastructure/tutor/themes/mereka/lms/static/images/logo.svg

# 2. Sync to brand package
./scripts/branding/sync-brand-package.sh

# 3. Verify
./scripts/qa/verify-brand-package/verify-brand-package-structure.sh

# 4. Rebuild and deploy
tutor images build mfe
tutor k8s restart mfe
```

### Rollback

```bash
# Option 1: Revert the Tutor plugin patch (MFEs fall back to stock branding)
git checkout HEAD~1 -- infrastructure/tutor/plugins/mereka_lms.py
tutor images build mfe
tutor k8s restart mfe

# Option 2: Revert a specific brand asset change
git checkout HEAD~1 -- infrastructure/tutor/brand-mereka/
tutor images build mfe
tutor k8s restart mfe
```

### Feature Flag

No feature flag is needed. The brand package is installed at build time. To disable, remove the npm alias patch from the Tutor plugin and rebuild.

## Risks and Mitigations

| Risk | Impact | Probability | Mitigation |
|------|--------|-------------|------------|
| Paragon version incompatibility (brand package tokens.json schema changes) | Medium -- MFE build failure | Low (Ulmo is current release) | Pin peerDependencies range; tokens.json is a placeholder so schema mismatch is unlikely until full migration |
| MFE build time increase from npm install of brand package | Low -- adds ~10s to 15-20 min build | High (guaranteed overhead) | Package is small (<3 MB asset-only); overhead is negligible compared to total build time |
| Asset drift between theme directory and brand package | Medium -- visual inconsistency between LMS and MFEs | Medium | Sync script + CI verification that compares checksums; AC-BRAND-009 and AC-BRAND-012 enforce byte-identical copies |
| npm alias resolution failure in Docker build context | High -- MFE build completely fails | Low | Tested during implementation; COPY directive ensures package is in build context before npm install |
| Future Paragon breaking change to brand package interface | High -- all MFE branding breaks | Low (OEP-48 is stable) | Monitor Paragon changelogs; tokens.json placeholder allows incremental adoption |

## Verification

### Automated Verification

Add verification script to `scripts/qa/verify-brand-package/verify-brand-package-structure.sh` with `@covers` annotations:

```bash
#!/usr/bin/env bash
# @covers AC-BRAND-001, AC-BRAND-002, AC-BRAND-003, AC-BRAND-004, AC-BRAND-005
# @covers AC-BRAND-006, AC-BRAND-007, AC-BRAND-008, AC-BRAND-009, AC-BRAND-010
# @covers AC-BRAND-011, AC-BRAND-012, AC-BRAND-013, AC-BRAND-014, AC-BRAND-015
# @covers AC-BRAND-016, AC-BRAND-017, AC-BRAND-018, AC-BRAND-019, AC-BRAND-020
# @covers AC-BRAND-021, AC-BRAND-022, AC-BRAND-026, AC-BRAND-027
# @covers AC-BRAND-NFR-001, AC-BRAND-NFR-003
# @covers AC-BRAND-INT-001, AC-BRAND-INT-002, AC-BRAND-INT-003, AC-BRAND-INT-004
# @spec: oep48-brand-package_spec

set -euo pipefail
BRAND_DIR="infrastructure/tutor/brand-mereka"
THEME_DIR="infrastructure/tutor/themes/mereka"
# Verification logic: structure, file existence, package.json fields,
# fonts.scss declarations, SVG viewBox, logo pixel width, font file types,
# sha256 cross-checks with theme directory, tokens.json parsing, size checks
```

Tutor plugin integration checks:

```bash
#!/usr/bin/env bash
# @covers AC-BRAND-023, AC-BRAND-028
# @spec: oep48-brand-package_spec

set -euo pipefail
# Verify mereka_lms.py contains brand-mereka COPY + npm install
# Verify ci-scripts-static.txt includes the verification script
```

MFE build integration (manual or post-build):

```bash
#!/usr/bin/env bash
# @covers AC-BRAND-024, AC-BRAND-025
# @spec: oep48-brand-package_spec

set -euo pipefail
# Run inside built MFE container:
# npm ls @edx/brand (must resolve)
# Verify no ERESOLVE errors in build log
```

Run coverage report:
```bash
scripts/qa/spec-tools/ac-coverage-report.py
```

### Manual Verification

1. After MFE build + deploy, visually confirm Mereka logo appears on the authn login page (`https://apps.academyv2.mereka.io/authn/login`).
2. Open browser DevTools Network tab, filter by "font", and confirm woff2 files load from the MFE bundle (not from Google Fonts or any external CDN).
3. Inspect favicon in browser tab -- should show Mereka icon, not Open edX default.

### Test Plan

See `specs/plans/oep48-brand-package_test_plan.md` for comprehensive test scenarios (to be created during implementation).

## Configuration

### Environment Variables

No new environment variables are required. The brand package is installed at build time via Tutor plugin patches.

### Feature Flags

No feature flags. The brand package is active once installed. To disable, revert the Tutor plugin patch.

## Open Questions

- [ ] Should `paragon/tokens.json` follow a specific JSON schema from Paragon, or is a minimal freeform structure acceptable for the placeholder? Need to check upstream Paragon source for schema validation.
- [ ] Should we add a `paragon/images.scss` or similar entrypoint for logo imports, or is the bare `logo.svg` at package root sufficient per OEP-48?
- [ ] What is the minimum Paragon version we need to support? This affects `peerDependencies` range and `_variables.scss` content.
- [ ] Should `sync-brand-package.sh` be run automatically as part of `apply-patches.sh`, or remain a separate manual step?
