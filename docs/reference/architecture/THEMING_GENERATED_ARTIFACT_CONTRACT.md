# Theming Generated Artifact Contract

## Purpose
Define a deterministic governance contract for the Open edX transitional theming stack in this repo.

This contract removes ambiguity around which files are source-of-truth, which are generated, and how CI enforces drift prevention.

## Source vs Generated

| Layer | File(s) | Classification | Generation Path | Manual Edit Policy |
|---|---|---|---|---|
| Canonical design tokens | `assets/branding/tokens.css` | **Source** | Upstream sync / maintained canonical file | Allowed (through token workflow) |
| SCSS bridge for comprehensive theming | `infrastructure/tutor/themes/mereka/scss/_tokens.scss` | **Generated (partial block)** | `scripts/branding/generate-tokens-from-canonical.sh` | **Disallowed** inside generated block |
| Runtime token CSS | `infrastructure/tutor/themes/mereka/common/static/css/mereka-design-tokens.css` | **Generated** | `scripts/branding/generate-tokens-from-canonical.sh` | **Disallowed** |
| Runtime overrides CSS | `infrastructure/tutor/themes/mereka/{common,lms,cms}/static/css/mereka-overrides.css` | **Generated (token block) + curated selectors** | `scripts/branding/generate-tokens-from-canonical.sh` + `sync-brand-assets.sh` | Allowed only outside generated block |
| MFE runtime theme delta | `infrastructure/tutor/themes/mereka/mfe/theme/mereka-brand.min.css` | **Generated** | `scripts/branding/build-tokens.sh` | **Disallowed** |
| MFE runtime light baseline | `infrastructure/tutor/themes/mereka/mfe/theme/light.min.css` | **Generated** | `scripts/branding/build-tokens.sh` | **Disallowed** |
| MFE runtime brand-light delta | `infrastructure/tutor/themes/mereka/mfe/theme/mereka-brand-light.min.css` | **Generated** | `scripts/branding/build-tokens.sh` | **Disallowed** |
| MFE Paragon baseline | `infrastructure/tutor/themes/mereka/mfe/theme/core.min.css` | **Vendored baseline artifact** | `scripts/branding/build-tokens.sh` | Disallowed unless refreshed via script |
| Runtime loader shims | `deploy/k8s/base/apps/openedx/theme/head-extra.html`, `infrastructure/tutor/themes/mereka/{common,lms,cms}/templates/head-extra.html` | **Hand-maintained runtime shim** | Manual, mirrored intentionally across surfaces | Allowed only for loader semantics; token values and override rules do not belong here |

## CI Drift Gates

The following checks are required for generated artifact integrity:

1. `./scripts/branding/generate-tokens-from-canonical.sh --check`
2. `./scripts/branding/build-tokens.sh --check`
3. `./scripts/qa/verify-theming-generated-artifacts.sh`

These checks fail when generated files diverge from deterministic regeneration.

## Transitional Compatibility Matrix

| Surface | Why It Exists Now | Current Dependency | Removal Prerequisite |
|---|---|---|---|
| Django comprehensive theming (`_tokens.scss`) | Legacy/Open edX LMS-CMS Sass compatibility | LMS/CMS theme build paths | Django theming no longer requires SCSS bridge tokens |
| Runtime `PARAGON_THEME_URLS` minified CSS | MFE runtime theming contract | `/theme/*.min.css` served by Caddy | Unified runtime token delivery removes dedicated min.css artifacts |
| OEP-48 brand package (`brand-*`) | Logo/favicons for MFEs | `@edx/brand@file:./brand-*` | Replaced only when upstream brand package strategy changes |

## Manual Edit Rules

- Files marked generated in this contract MUST NOT be edited by hand.
- Regenerate with scripts, then commit outputs.
- Any PR that edits generated artifacts without corresponding source change + regeneration evidence is invalid.

## Runtime Shim Ownership

`head-extra.html` exists in more than one place because the runtime lookup paths
and delivery surfaces differ. Those files are not token sources of truth. They
must stay thin and only do loader work:

- preload fonts
- load prebuilt runtime CSS
- carry narrowly documented surface-specific preload differences

They MUST NOT become a second authority for:

- token values
- runtime override selectors
- arbitrary frontend hotfix logic

Token truth still starts at `assets/branding/tokens.css`. Runtime override truth
still lives in generated + curated `mereka-overrides.css` outputs governed by
the branding scripts.

## Exit Criteria

The transitional stack can be simplified only after all criteria are met:

1. MFE runtime no longer depends on `/theme/*.min.css` artifacts.
2. LMS/CMS theming no longer depends on generated SCSS bridge tokens.
3. Brand package responsibilities are fully covered by a single upstream runtime-compatible theming contract.
4. CI contracts are updated to remove obsolete generated outputs and enforce the new pipeline.
