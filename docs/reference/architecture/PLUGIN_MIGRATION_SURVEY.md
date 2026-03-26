# Plugin Migration Survey

> Full inventory of LMS/Studio/MFE overrides with migration status and closure plans.
>
> **Bead**: mereka-lms-8jao.25
> **AC**: AC-WC-007, AC-WC-008
> **Last updated**: 2026-02-20
> **Related**: `docs/reference/architecture/MFE_PLUGIN_SLOT_MIGRATION_REGISTER.md` (MFE-only subset)

## Scope

This document covers ALL customization surfaces — not just MFE plugin slots.
It inventories every place where Mereka diverges from upstream Open edX and tracks
the migration path toward plugin/theme-first architecture.

## Risk Legend

| Risk | Meaning |
|------|---------|
| **HIGH** | Build or runtime failure if removed; no alternative path today |
| **MEDIUM** | Functional but brittle; alternative path exists but not yet wired |
| **LOW** | Correct mechanism; no migration needed |

## Status Legend

| Status | Meaning |
|--------|---------|
| MIGRATED | Already on plugin/theme-first path |
| DUAL-PATH | Both plugin and script active (transitional) |
| SCRIPT-ONLY | Exists only in `apply-patches.sh`; not yet in plugin |
| THEME | Uses Comprehensive Theming (correct mechanism) |
| EXCEPTION | Documented exception with expiry date |

---

## A. LMS/Studio Mako Template Overrides

These live in `infrastructure/tutor/themes/mereka/` and use Open edX Comprehensive Theming.

| # | Override | File | Status | Risk | Owner | Migration Plan |
|---|----------|------|--------|------|-------|----------------|
| A1 | LMS head-extra (fonts + CSS) | `lms/templates/head-extra.html` | THEME | Low | Mereka | Correct mechanism. No migration needed. |
| A2 | LMS footer (full Mako replacement) | `lms/templates/footer.html` | THEME | Medium | Mereka | **Updated 2026-02-20 (1kwf)**: Copyright now dynamic via `get_platform_name()`; "Powered by Open edX" removed. Remaining gap: nav links (emails, help URLs) still Mereka-specific → bead 2rcf. |
| A3 | LMS homepage hero | `lms/templates/index_overlay.html` | THEME | Medium | Mereka | Hardcoded "150+/45/18k" → drive from `SiteConfiguration` or CMS page. |
| A4 | LMS header brand/logo | `lms/templates/header/brand.html` | THEME | Medium | Mereka | Hardcoded tagline → `configuration_helpers.get_value()`. |
| A5 | Common head-extra (defensive copy) | `common/templates/head-extra.html` | THEME | Low | Mereka | Required for Mako namespace resolution. Keep in sync with A1. |
| A6 | CMS head-extra (Studio fonts) | `cms/templates/head-extra.html` | THEME | Low | Mereka | Required copy for Studio. Keep in sync with A1. |
| A7 | CMS footer widget (Studio white-label) | `cms/templates/widgets/footer.html` | THEME | Medium | Mereka | **Added 2026-02-20 (1kwf/bz9p)**: Override of upstream `widgets/footer.html` which contains "Powered by Open edX". This is the canonical Studio footer renderer. No "Powered by" in override. Awaiting image rebuild to go live. |

**Summary**: All template overrides use the correct Comprehensive Theming mechanism. Items A2 (partial) and A3–A4 have hardcoded brand copy that should become config-driven (P2 priority). A7 is new — blocks Studio white-label completion.

---

## B. Theme SASS/CSS Overrides

| # | Override | File | Status | Risk | Owner | Migration Plan |
|---|----------|------|--------|------|-------|----------------|
| B1 | LMS SASS entry point | `lms/static/sass/theme.scss` | THEME | Low | Mereka | Correct SASS override mechanism. |
| B2 | CMS SASS entry point | `cms/static/sass/theme.scss` | THEME | Low | Mereka | Correct SASS override mechanism. |
| B3 | Studio main CSS | `cms/static/sass/studio-main-v1.scss` | THEME | Low | Mereka | Correct. |
| B4 | Design tokens (SCSS vars) | `scss/_tokens.scss` | THEME | Low | Mereka | Correct. Design-token driven. |
| B5 | Font declarations | `scss/_fonts.scss` | THEME | Low | Mereka | Correct. |
| B6 | CSS custom properties | `common/static/css/mereka-design-tokens.css` | THEME | Low | Mereka | Synced by `sync-brand-assets.sh`. Verify loaded in `head-extra.html`. |
| B7 | MFE theme SCSS | `mfe/mereka.scss` | THEME | Low | Mereka | Correct. Referenced via `env.config.jsx` import. |

**Summary**: All SASS/CSS overrides use correct mechanisms. No migration needed.

---

## C. apply-patches.sh — Script-Only Patches (Not in Plugin)

These patches exist exclusively in `apply-patches.sh` and MUST be migrated to `mereka_lms.py` or documented as exceptions.

| # | Patch | Target | Status | Risk | Expiry | Migration Plan |
|---|-------|--------|--------|------|--------|----------------|
| C1 | `PIPELINE['JS_COMPRESSOR'] = None` | `assets.py` | SCRIPT-ONLY | HIGH | 2026-Q3 | Add to plugin `openedx-lms-assets-settings` hook |
| C2 | Node 18 base image pin | `mfe/Dockerfile` | SCRIPT-ONLY | HIGH | 2026-Q3 | Add to plugin or resolve via `DOCKER_IMAGE_OPENEDX_MFE_NODE` config |
| C3 | Node cache reuse from upstream | `Dockerfile` | EXCEPTION | HIGH | 2026-Q4 | Requires Tutor hook for pre-npm-install Dockerfile lines. File exception. |
| C4 | Course authoring directory fix | `mfe/Dockerfile` | SCRIPT-ONLY | HIGH | 2026-Q3 | Add symlink to plugin `mfe-dockerfile-post-npm-install` hook |
| C5 | MFE theme COPY (`indigo/mereka`) | `mfe/Dockerfile` | SCRIPT-ONLY | HIGH | 2026-Q3 | Add to plugin `mfe-dockerfile-post-npm-install` hook |
| C6 | Admin console Redux deps | `mfe/Dockerfile` | SCRIPT-ONLY | MEDIUM | 2026-Q3 | Add to plugin `mfe-dockerfile-post-npm-install` hook |
| C7 | Indigo footer package removal | `env.config.jsx` | SCRIPT-ONLY | MEDIUM | 2026-Q3 | Add to plugin `mfe-env-config` hook |
| C8 | `REQUIRE_BUILD_PROFILE_OPTIMIZE=none` | `Dockerfile` | SCRIPT-ONLY | MEDIUM | 2026-Q3 | Add to plugin `openedx-dockerfile-pre-assets` hook |
| C9 | MFE cache headers | `Caddyfile` | SCRIPT-ONLY | MEDIUM | 2026-Q3 | Add to plugin `caddy-caddyfile` hook |
| C10 | New Relic ENV propagation | `mfe/Dockerfile` | SCRIPT-ONLY | LOW | 2026-Q4 | Add to plugin `mfe-dockerfile-post-npm-install` hook |

**Summary**: 10 patches remain script-only. 5 are HIGH risk (build failure without script). Target migration: 2026-Q3.

---

## D. apply-patches.sh — Dual-Path Patches (In Both Script and Plugin)

These patches exist in BOTH `apply-patches.sh` AND `mereka_lms.py`. The script runs as safety net; plugin handles the canonical path. Once plugin coverage is verified, script copies can be removed.

| # | Patch | Status | Risk | Action |
|---|-------|--------|------|--------|
| D1 | `ALLOWED_HOSTS` extra domains | DUAL-PATH | Low | Remove from script after plugin-only build verified |
| D2 | CSRF trusted origins | DUAL-PATH | Low | Same as D1 |
| D3 | `DISCUSSIONS_MFE_ENABLED` | DUAL-PATH | Low | Same as D1 |
| D4 | `DEFAULT_SITE_THEME = "mereka"` | DUAL-PATH | Low | Same as D1 |
| D5 | `mfe_oauth_fix` app + middleware | DUAL-PATH | Low | Same as D1 |
| D6 | `django_prometheus` integration | DUAL-PATH | Low | Same as D1 |
| D7 | `mereka_tenancy` middleware | DUAL-PATH | Low | Same as D1 |
| D8 | `safe_join` monkey-patch | DUAL-PATH | Low | Same as D1 |
| D9 | Custom apps COPY + pip install | DUAL-PATH | Medium | Same as D1 |
| D10 | Google Fonts stripping | DUAL-PATH | Low | Same as D1 |
| D11 | SASS compile with `--theme mereka` | DUAL-PATH | Low | Same as D1 |
| D12 | Webpack parallel: false | DUAL-PATH | Low | Same as D1 |
| D13 | pip retry resilience | DUAL-PATH | Low | Same as D1 |
| D14 | Multi-domain Caddy blocks | DUAL-PATH | Low | Same as D1 |
| D15 | MFE profile API proxy | DUAL-PATH | Low | Same as D1 |
| D16 | Nginx extra config | DUAL-PATH | Low | Same as D1 |
| D17 | MySQL `MYSQL_ROOT_HOST` | DUAL-PATH | Low | Same as D1 |
| D18 | MFE footer (`MerekaFooter`) | DUAL-PATH | Medium | String replacement is live fallback; slot registration is forward-compatible |
| D19 | MFE SCSS import injection | DUAL-PATH | Low | Same as D1 |
| D20 | MFE cookie ENV vars | DUAL-PATH | Low | Same as D1 |
| D21 | Plugin framework dep install | DUAL-PATH | Low | Same as D1 |

**Summary**: 21 dual-path patches. All low risk. Can be retired from script after a plugin-only build is validated end-to-end.

---

## E. MFE Plugin Slot Overrides

Detailed in `docs/reference/architecture/MFE_PLUGIN_SLOT_MIGRATION_REGISTER.md`. Summary:

| # | Override | Status | Slot Available | Priority |
|---|----------|--------|----------------|----------|
| E1 | Footer (all MFEs) | MIGRATED | Yes | Done — **Updated 2026-02-20 (bz9p)**: SITE_VARIANTS verified in source; per-tenant `copyrightHolder` confirmed. Awaiting MFE image `1c66529-20260220023917` ArgoCD deploy for live-complete. |
| E2 | Header logo | CSS OVERRIDE | Yes | P1 |
| E3 | Auth page branding | CSS OVERRIDE | Yes | P1 |
| E4 | Learner dashboard cards | CSS OVERRIDE | Partial | P2 |
| E5 | Course outline header | CSS OVERRIDE | No | P3 |
| E6 | Discussion forum header | CSS OVERRIDE | No | P3 |
| E7 | Account settings layout | CSS OVERRIDE | No | P3 |
| E8 | Course cards grid | CSS OVERRIDE | Partial | P2 |
| E9 | Profile page hero | CSS OVERRIDE | Partial | P2 |
| E10 | Gradebook header | CSS OVERRIDE | No | P3 |

See full details in `MFE_PLUGIN_SLOT_MIGRATION_REGISTER.md`.

---

## F. Branding Scripts — Direct File Manipulation

| # | Script | What it Does | Migration Needed? | Risk |
|---|--------|--------------|-------------------|------|
| F1 | `scripts/branding/sync-brand-assets.sh` | Copies assets into theme dirs | No (asset distribution) | Low |
| F2 | `scripts/branding/setup-mfe-branding.sh` | Dev-only: injects `@import` into MFE `src/index.scss` | Dev-only exception | Medium |
| F3 | `scripts/branding/repair-mfe-authn-branding.sh` | Repairs authn branding | Review for retirement | Medium |

---

## Migration Priority Matrix

| Priority | Count | Items |
|----------|-------|-------|
| **Immediate (Q2 2026)** | 0 | — |
| **Q3 2026** | 9 | C1, C2, C4, C5, C6, C7, C8, C9, D-retirement |
| **Q4 2026** | 2 | C3, C10 |
| **Backlog** | 4 | A2→config (nav links remain; bead 2rcf), A3→config, A4→config, Enterprise MFE footer wiring |
| **No action** | 29 | All THEME/MIGRATED items (incl. new A7) |

## Debt Cleared (2026-02-20, bead 1kwf/bz9p)

| Item | What Changed | Result |
|------|-------------|--------|
| A2 (LMS footer) | Copyright holder made dynamic (`get_platform_name()`); "Powered by Open edX" removed with OEP-11 comment | `verify-footer-parity.sh` AC-FTPAR-002/005 now PASS |
| A7 (CMS footer widget) | Added `widgets/footer.html` override — Studio now shows Mereka footer, no "Powered by Open edX" | AC-FTPAR-005 CMS check now PASS (source); live on next image build |
| E1 (MFE footer) | SITE_VARIANTS verified: 3 tenants, `copyrightHolder` per-tenant confirmed | AC-FTPAR-001/003 PASS; live pending ArgoCD sync |
| verify-footer-parity.sh | Added Mako comment exclusion (`grep -v '^\s*##'`) to prevent false WARN on removed strings | 32 PASS / 0 FAIL / 1 WARN (down from 2 WARNs) |

## Retirement Criteria for apply-patches.sh

The script can be retired (or reduced to asset-sync only) when:

1. All Section C items are migrated to `mereka_lms.py` plugin hooks
2. Local parity remains reproducible without `apply-patches.sh` (`tutor images build openedx` + `mfe` may still be used as a debug/local check)
3. The governed publish lane (`.github/workflows/build-tutor-images.yml`) ships the same plugin-only sources without `apply-patches.sh`, and all verification gates pass there
4. Section D items are verified as redundant (plugin handles them)

**Target**: 2026-Q3 for script-only patches; 2026-Q4 for full retirement to asset-sync stub.

---

## Non-Plugin Exception Evidence Pack (AC-UI-004)

Every item in Section C (SCRIPT-ONLY) that is not yet migrated requires evidence
documenting the rationale for the exception and before/after gate outputs.

### How to generate evidence

```bash
# 1. Run gates BEFORE any migration change
./scripts/qa/verify-plugin-surface-matrix.sh \
  --evidence-dir var/evidence/migration-before-$(date +%Y%m%d)

# 2. Make the migration change (e.g., move C1 to plugin)

# 3. Run gates AFTER the change
./scripts/qa/verify-plugin-surface-matrix.sh \
  --evidence-dir var/evidence/migration-after-$(date +%Y%m%d)

# 4. Compare: diff the summary files
diff var/evidence/migration-before-*/plugin-surface-matrix-summary.md \
     var/evidence/migration-after-*/plugin-surface-matrix-summary.md
```

### Current exception rationale

| Item | Rationale | Evidence |
|------|-----------|---------|
| C3 (Node cache reuse) | No Tutor hook for pre-npm-install Dockerfile lines. Build time 30+ min vs seconds. | `check-forbidden-overrides.sh` WARN on script size |
| C10 (New Relic ENV) | Low priority; instrumentation optional | N/A — no gate failure |
| F2 (setup-mfe-branding.sh) | Dev-only; production uses Dockerfile COPY | Verified: script not called in CI or production builds |

See `docs/guides/branding/BRANDING_OPERATING_MODEL.md` for the full exception policy with expiry dates.

---

## Related Documents

- `docs/reference/architecture/MFE_PLUGIN_SLOT_MIGRATION_REGISTER.md` — MFE slot details
- `docs/guides/branding/BRANDING_OPERATING_MODEL.md` — Operating model + exception policy
- `docs/guides/branding/BRANDING_GUARDRAILS.md` — Verification gates
- `infrastructure/tutor/plugins/mereka_lms.py` — Tutor plugin
- `infrastructure/tutor/apply-patches.sh` — Legacy patch script
