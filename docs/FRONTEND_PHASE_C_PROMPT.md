# Frontend Phase C: Token Grounding + BEM Hardening — Implementor Prompt

**Date**: 2026-02-28 (revised)
**Prerequisite**: Phase B complete + **Phase B deep audit fixes** (see below)
**Specs**: `specs/paragon-design-tokens-migration_spec.md`, `specs/mfe-plugin-slots_spec.md`

---

## BLOCKING Prerequisites (From Deep Audit)

**Read `docs/reviews/FRONTEND_PHASE_AB_DEEP_AUDIT.md` FIRST.** It identifies critical architecture issues that must be fixed before Phase C work is meaningful.

### Must Fix Before Starting Phase C

| ID | What | Why | Est. |
|----|------|-----|------|
| **C1** | Create 4 missing OEP-48 files (`_overrides.scss`, `card-imagecap-fallback.png`, `logo-trademark.svg/png`) + update `package.json` exports | MFE components import these at build time — missing = build errors or broken images | 30 min |
| **C2** | Split `theme.scss` — stop importing ~600 lines of LMS/Studio CSS into MFEs | Every MFE currently ships ~20KB of dead CSS (`.dashboard`, `.courseware`, `.wrapper-view` selectors) | 2 hr |
| **C3** | Move `_tokens.scss` lines 205-244 (CSS rules) to separate `_base.scss` partial | `_tokens.scss` should define tokens only, not apply styles. Rules risk loss on regeneration | 30 min |
| **C4** | Remove duplicate `:root` block from `theme.scss` (duplicates _tokens.scss) | Emits 11 identical CSS variables twice | 15 min |
| **C5** | Remove duplicate `.mereka-badge` from `theme.scss` (tokenized version in mereka.scss is correct) | Conflicting definitions with hardcoded vs tokenized values | 15 min |
| **C6** | Remove or align `exports` in `package.json` (reference brand-openedx has no exports field) | Exports field blocks unlisted path imports | 15 min |

### Critical Context

**The brand package SCSS is dead in Ulmo.** Paragon v23+ MFEs do NOT `@import` from `@edx/brand`. The `_variables.scss` SCSS variables (`$primary`, `$secondary`) have zero effect. Our actual theming works through `mereka.scss` → `_tokens.scss` CSS custom properties (`:root { --pgn-color-primary-base: ... }`).

The brand package is an **asset container** (logos, images, favicon). Keep SCSS files for OEP-48 compliance but do not treat them as the color/font source of truth.

---

## Key Insight: Paragon v22 Token Reality

The original Phase C assumed most BEM overrides could be replaced with `--pgn-*` component tokens. **This is wrong for Paragon v22.**

A comprehensive audit of the compiled Paragon CSS (`core.min.css`, 2,310 tokens) reveals:

- Paragon v22 exposes **2,310 CSS custom properties**, but component-level tokens are incomplete
- It **DOES** consume: semantic colors (`--pgn-color-primary-base`, `--pgn-btn-bg`), typography, spacing, button radius
- It **DOES NOT** consume: card shadow/border-radius, form control padding/height, modal shadows, dropdown shadows, breadcrumb/tab styling

**Bottom line**: Only ~12 of the 35 BEM overrides can be replaced with tokens. The rest MUST remain as CSS rules. Attempting to define tokens Paragon doesn't read creates dead CSS that silently fails.

This revised Phase C is restructured around this reality.

---

## Objective

1. **Audit** which `--pgn-*` tokens Paragon v22 actually reads (Task C1 — required first)
2. **Replace** BEM overrides where Paragon reads the token (Task C2 — safe replacements only)
3. **Harden** remaining BEM overrides with `var()` references instead of hex (Task C3 — from Phase B3)
4. **Wire** PARAGON_THEME_URLS for runtime theming (Task C4 — only after tokens are stable)
5. **Verify** with CI script (Task C5)

---

## Task C1: Paragon v22 Token Audit (REQUIRED FIRST)

### Why this must come first

The original prompt listed ~60 `--pgn-*` component tokens to add. Most of these are **aspirational** — Paragon v22 doesn't read them. Adding tokens Paragon ignores is worse than useless: it gives a false sense of coverage and makes the BEM override removal fail silently (no visual effect, but the override is gone).

### What to do

1. **Read** the compiled Paragon CSS at `infrastructure/tutor/themes/mereka/mfe/theme/core.min.css`
2. **Extract** every `var(--pgn-*)` reference — these are the properties Paragon actually reads
3. **Cross-reference** against our `_tokens.scss` `:root` block to find gaps
4. **Produce** a definitive list of tokens in three categories:

| Category | Description | Action |
|----------|-------------|--------|
| **CONSUMED & DEFINED** | Paragon reads it, we define it | No action needed |
| **CONSUMED & MISSING** | Paragon reads it, we don't define it (using Paragon default) | Evaluate: does Mereka need a different value? |
| **DEFINED & IGNORED** | We define it, Paragon doesn't read it | Remove or document as "for custom CSS only" |

### Expected findings (from preliminary analysis)

**Tokens Paragon v22 DOES consume** (we should ensure these are correct):

```
--pgn-color-primary-base     ← our #ab3b78 (magenta)
--pgn-color-secondary-base   ← our #237072 (teal)
--pgn-color-success-base     ← our #2c6e49 (forest)
--pgn-color-info-base        ← our #295cad (blue)
--pgn-color-warning-base     ← our #f4be48 (gold)
--pgn-color-danger-base      ← our #8c002f (burgundy)
--pgn-typography-font-family-sans-serif ← our Poppins/Lato stack
--pgn-typography-headings-font-family   ← our Lato/Poppins stack
--pgn-btn-border-radius      ← our 999px (pill buttons)
--pgn-link-color             ← our #295cad
--pgn-link-hover-color       ← our #237072
--pgn-body-bg                ← our #FBFAFB
--pgn-body-color             ← our #000000
--pgn-border-color           ← our #DDDDDE
--pgn-btn-bg                 ← consumed for button backgrounds
--pgn-btn-border-color       ← consumed for button borders
--pgn-btn-color              ← consumed for button text
--pgn-alert-bg               ← consumed for alert backgrounds
--pgn-alert-border-color     ← consumed for alert borders
--pgn-form-control-*         ← extensive form control tokens
```

**Tokens Paragon v22 DOES NOT consume** (BEM overrides must remain):

```
--pgn-card-border-radius     ← NOT consumed (card uses hardcoded SCSS)
--pgn-card-box-shadow        ← NOT consumed
--pgn-modal-border-radius    ← NOT consumed
--pgn-dropdown-box-shadow    ← NOT consumed
--pgn-tab-border-radius      ← NOT consumed
```

### Output artifact

Create `docs/architecture/PARAGON_V22_TOKEN_AUDIT.md` with the full three-category list. This becomes the source of truth for all subsequent token work.

---

## Task C2: Replace BEM Overrides Where Tokens Are Consumed (~12 overrides)

### Decision framework

For each of the 35 BEM overrides in `mereka.scss`:

```
IF Paragon reads the token (confirmed in C1 audit)
  → Define the token in _tokens.scss
  → Remove the BEM override from mereka.scss
  → Test visually

ELSE IF the override only uses colors/shadows (not structural)
  → Keep the BEM override
  → Replace hardcoded hex with var(--mereka-*) references (Task C3)

ELSE (structural: display, flex, padding, sizing)
  → Keep the BEM override as-is
```

### Likely safe replacements (confirm with C1 audit)

| # | Override | Replacement Token | Confidence |
|---|---------|-------------------|-----------|
| 1 | `.pgn__page-container` background | `--pgn-body-bg` | HIGH — Paragon reads this |
| 4 | `.pgn__btn--secondary` color | `--pgn-btn-color` variants | HIGH |
| 5 | `.pgn__btn--secondary:hover` color | `--pgn-btn-hover-color` | HIGH |
| 6 | `.pgn__form-control` border-color | `--pgn-form-control-border-color` | HIGH |
| 7 | `.pgn__form-control:focus` border-color, box-shadow | `--pgn-form-control-focus-*` | HIGH |
| 8 | `.pgn__form-label` font-weight, color | `--pgn-form-label-*` | MEDIUM — verify |
| 12 | `.pgn__alert` border-color | `--pgn-alert-border-color` | HIGH |
| 13-16 | `.pgn__alert--{variant}` bg, border | `--pgn-alert-{variant}-bg/border` | HIGH |

### Likely NOT replaceable (keep as BEM + var())

| # | Override | Why | Action |
|---|---------|-----|--------|
| 2 | `.pgn__btn--primary` gradient | Paragon has no gradient token | Keep BEM, use var(--mereka-*) for colors |
| 3 | `.pgn__btn--primary:hover` transform | Not tokenizable | Keep BEM |
| 9 | `.pgn__card` border-radius, shadow | No card component tokens in v22 | Keep BEM, use var(--mereka-*) |
| 10-11 | `.pgn__card-header/footer` | No card section tokens | Keep BEM, use var(--mereka-*) |
| 17 | `.pgn__modal-content` border-radius | No modal component tokens | Keep BEM, use var(--mereka-*) |
| 18 | `.pgn__dropdown-menu` | No dropdown component tokens | Keep BEM, use var(--mereka-*) |
| 19-20 | `.pgn__tabs` | No tab component tokens | Keep BEM, use var(--mereka-*) |
| 21-25 | Authn scoped overrides | Surface-specific, must remain | Keep BEM, use var(--mereka-*) |
| 31-33 | Learning scoped overrides | Structural sizing | Keep as-is |

---

## Task C3: Harden Remaining BEM Overrides with var() References

This is the **practical alternative** to token replacement for the ~23 overrides that must stay as BEM rules. Instead of:

```scss
/* BAD: hardcoded hex in BEM override */
.pgn__card {
  border-radius: 24px;
  border: 1px solid rgba(26, 22, 35, 0.08);
  box-shadow: 0 25px 60px rgba(26, 22, 35, 0.08);
}
```

Use:

```scss
/* GOOD: var() references — single source of truth, brand changes propagate */
.pgn__card {
  border-radius: var(--mereka-card-radius, 24px);
  border: 1px solid var(--mereka-mfe-border);
  box-shadow: var(--mereka-mfe-card-shadow);
}
```

### What this achieves

- **Single source of truth**: All brand values in `_tokens.scss` `:root` block
- **Runtime changeable**: Changing `--mereka-mfe-card-shadow` in `:root` updates all cards
- **Upgrade-safe**: When Paragon v23+ adds component tokens, we can remove BEM overrides one-by-one
- **No risk**: The BEM override still applies, just reads from a variable instead of hardcoding

### New tokens to add to _tokens.scss

Add these to the `:root` block for use by hardened BEM overrides:

```scss
:root {
  /* ... existing tokens ... */

  /* Component-specific tokens for BEM override hardening.
     These are NOT consumed by Paragon v22 — they're for our own CSS overrides.
     When Paragon v23+ adds native support, migrate from BEM → token. */
  --mereka-card-radius: 24px;
  --mereka-card-border: 1px solid var(--mereka-mfe-border);
  --mereka-card-shadow: var(--mereka-mfe-card-shadow);
  --mereka-modal-radius: 24px;
  --mereka-dropdown-radius: 16px;
  --mereka-dropdown-shadow: 0 16px 40px rgb(var(--mereka-color-ink-deep-rgb) / 0.12);
  --mereka-form-radius: 16px;
  --mereka-alert-radius: 16px;
  --mereka-tab-radius: 999px;
  --mereka-btn-gradient: linear-gradient(120deg, var(--mereka-color-magenta) 0%, var(--mereka-color-teal) 60%, var(--mereka-color-blue) 100%);
  --mereka-btn-shadow: 0 12px 30px rgb(var(--mereka-color-blue-rgb) / 0.3);
  --mereka-btn-shadow-hover: 0 18px 40px rgb(var(--mereka-color-blue-rgb) / 0.4);
}
```

**Naming convention**: `--mereka-*` (not `--pgn-*`) because these are OUR tokens for OUR overrides, not Paragon-consumed properties.

### Rules for the implementor

1. Every hex value in `mereka.scss` must become a `var()` reference
2. Use `--mereka-*` tokens (our namespace) for values Paragon doesn't read
3. Use `--pgn-*` tokens for values Paragon DOES read (confirmed by C1 audit)
4. Add fallback values: `var(--mereka-card-radius, 24px)` so the override works even if the token isn't loaded
5. DO NOT remove any BEM selectors in this task — only swap literal values for var() references
6. Run `grep -nE '#[0-9a-fA-F]{3,8}' infrastructure/tutor/themes/mereka/mfe/mereka.scss` after — target: 0 matches outside comments

---

## Task C4: Configure PARAGON_THEME_URLS (FE-015) — After C1-C3 Are Stable

### Why deferred

PARAGON_THEME_URLS serves compiled CSS containing `--pgn-*` tokens at runtime. This only makes sense AFTER:
- C1 confirms which tokens Paragon reads
- C2 defines the correct token values
- C3 ensures all BEM overrides use var() (so they're runtime-changeable)

### What to do

1. **Add config defaults** to `mereka_lms.py`:
   ```python
   ("MEREKA_PARAGON_THEME_ENABLED", True),
   ("MEREKA_PARAGON_THEME_CDN_BASE", "/theme"),
   ```

2. **Inject PARAGON_THEME_URLS** into `MFE_CONFIG` dict in LMS production settings:
   ```python
   if {{ MEREKA_PARAGON_THEME_ENABLED }}:
       _theme_base = "{{ MEREKA_PARAGON_THEME_CDN_BASE }}"
       MFE_CONFIG["PARAGON_THEME_URLS"] = {
           "core": {
               "urls": {
                   "default": f"{_theme_base}/core.min.css",
                   "brandOverride": f"{_theme_base}/mereka-brand.min.css",
               }
           },
           "variants": {
               "light": {
                   "urls": {
                       "default": f"{_theme_base}/light.min.css",
                       "brandOverride": f"{_theme_base}/mereka-brand-light.min.css",
                   }
               }
           },
       }
   ```

3. **Caddy route** already exists: `@mfe_theme_assets` handler in MFE Caddyfile serves `/theme/*` from `/openedx/dist` (fixed in Phase B review). No changes needed.

4. **Generate `mereka-brand.min.css`**: Update `scripts/branding/build-tokens.sh` to extract all `--pgn-*` properties from `_tokens.scss` into a standalone CSS file. This is the `brandOverride` CSS.

5. **`mereka-brand-light.min.css`** is identical to `mereka-brand.min.css` because we only support light mode. Add a comment in the file and in the build script explaining this.

6. **Feature flag**: Runtime theme is now default-on (`MEREKA_PARAGON_THEME_ENABLED: true`). Keep the toggle for controlled rollback and environment overrides.

### Rollback

Set `MEREKA_PARAGON_THEME_ENABLED: false` in Tutor config. MFEs fall back to build-time SCSS branding. No image rebuild needed.

---

## Task C5: Verification Script + CI

Create `scripts/qa/verify-paragon-token-coverage.sh`:

```bash
#!/usr/bin/env bash
# @covers AC-TKN-016, AC-TKN-017, AC-TKN-020, AC-TKN-021
# @spec: paragon-design-tokens-migration_spec
set -euo pipefail

PASS=0; FAIL=0; SKIP=0
pass() { PASS=$((PASS + 1)); echo "  PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "  FAIL: $1"; }
skip() { SKIP=$((SKIP + 1)); echo "  SKIP: $1"; }

TOKENS="infrastructure/tutor/themes/mereka/scss/_tokens.scss"
MFE_CSS="infrastructure/tutor/themes/mereka/mfe/mereka.scss"
PLUGIN="infrastructure/tutor/plugins/mereka_lms.py"

echo "=== Paragon Token Coverage ==="

# 1. _tokens.scss defines core semantic tokens
for token in '--pgn-color-primary-base' '--pgn-color-secondary-base' \
             '--pgn-typography-font-family-sans-serif' '--pgn-btn-border-radius'; do
  if grep -qF "$token" "$TOKENS"; then
    pass "$token defined in _tokens.scss"
  else
    fail "$token MISSING from _tokens.scss"
  fi
done

# 2. mereka.scss has zero hardcoded hex values (outside comments)
HEX_COUNT=$(grep -vE '^\s*//' "$MFE_CSS" | grep -cE '#[0-9a-fA-F]{3,8}' || true)
if [ "$HEX_COUNT" -eq 0 ]; then
  pass "No hardcoded hex values in mereka.scss"
else
  fail "$HEX_COUNT hardcoded hex values remain in mereka.scss"
fi

# 3. mereka.scss uses var() for all color/shadow values
VAR_COUNT=$(grep -c 'var(--' "$MFE_CSS" || true)
if [ "$VAR_COUNT" -ge 30 ]; then
  pass "mereka.scss uses $VAR_COUNT var() references (target: >= 30)"
else
  fail "mereka.scss has only $VAR_COUNT var() references (target: >= 30)"
fi

# 4. Plugin has PARAGON_THEME_URLS infrastructure
if grep -q 'PARAGON_THEME' "$PLUGIN"; then
  pass "PARAGON_THEME config exists in plugin"
else
  skip "PARAGON_THEME not yet configured (Phase C4)"
fi

# 5. Token audit doc exists
if [ -f "docs/architecture/PARAGON_V22_TOKEN_AUDIT.md" ]; then
  pass "Paragon v22 token audit document exists"
else
  fail "Missing docs/architecture/PARAGON_V22_TOKEN_AUDIT.md"
fi

# 6. No --pgn-* tokens that Paragon doesn't consume (dead tokens)
DEAD_TOKENS=0
for token in '--pgn-card-box-shadow' '--pgn-modal-box-shadow' \
             '--pgn-dropdown-box-shadow' '--pgn-tab-border-radius'; do
  if grep -qF "$token:" "$TOKENS"; then
    echo "  WARN: $token defined but Paragon v22 doesn't consume it"
    DEAD_TOKENS=$((DEAD_TOKENS + 1))
  fi
done
if [ "$DEAD_TOKENS" -eq 0 ]; then
  pass "No dead --pgn-* tokens (Paragon v22 doesn't consume them)"
else
  fail "$DEAD_TOKENS dead --pgn-* tokens found — use --mereka-* namespace instead"
fi

echo ""
echo "=== Summary: $PASS PASS, $FAIL FAIL, $SKIP SKIP ==="
[ "$FAIL" -eq 0 ]
```

Add to `.github/ci-scripts-static.txt`.

---

## Files to Modify

| File | Action | Task |
|------|--------|------|
| `docs/architecture/PARAGON_V22_TOKEN_AUDIT.md` | CREATE | C1 |
| `infrastructure/tutor/themes/mereka/scss/_tokens.scss` | MODIFY (add `--mereka-*` component tokens) | C2, C3 |
| `infrastructure/tutor/themes/mereka/mfe/mereka.scss` | MODIFY (remove tokenizable BEM, harden rest with var()) | C2, C3 |
| `infrastructure/tutor/plugins/mereka_lms.py` | MODIFY (add PARAGON_THEME_URLS config) | C4 |
| `scripts/branding/build-tokens.sh` | MODIFY (output mereka-brand.min.css) | C4 |
| `scripts/qa/verify-paragon-token-coverage.sh` | CREATE | C5 |
| `.github/ci-scripts-static.txt` | MODIFY (add new script) | C5 |

## Files to READ First

| File | Why |
|------|-----|
| `infrastructure/tutor/themes/mereka/mfe/theme/core.min.css` | **THE** source of truth for what Paragon v22 consumes (2,310 tokens) |
| `infrastructure/tutor/themes/mereka/mfe/mereka.scss` | All BEM overrides to evaluate |
| `infrastructure/tutor/themes/mereka/scss/_tokens.scss` | Current token bridge |
| `specs/paragon-design-tokens-migration_spec.md` | Spec acceptance criteria |
| `specs/mfe-plugin-slots_spec.md` | FPF slots for Phase D header branding |
| `docs/architecture/MFE_RUNTIME_CONFIG.md` | MFE config API mechanics |

---

## Commit Strategy

5 commits (one per task):

1. `docs: Paragon v22 token audit — consumed vs aspirational tokens (FE-010)`
2. `refactor: replace BEM overrides with Paragon tokens where consumed (FE-010)`
3. `refactor: harden remaining BEM overrides with var() references (FE-011)`
4. `feat: configure PARAGON_THEME_URLS in Tutor plugin (FE-015)`
5. `test: add Paragon token coverage verification script`

---

## CRITICAL WARNING: Dead Selectors (2026-02-28)

**~60% of scoped `[class*="..."]` selectors in `mereka.scss` are DEAD** — they match no
DOM elements in Ulmo MFEs. See `docs/architecture/MFE_SELECTOR_OVERRIDE_INVENTORY.md`
§Dead Selector Audit for the full table.

**Implication for Phase C**: Do NOT spend time hardening dead selectors with `var()`.
Task C3 should only apply to LIVE selectors (currently explicit `.page__account-settings`
and all `.pgn__*` component selectors are confirmed live). Dead selectors should be
deferred to Phase D for rewrite or slot migration.

---

## Token Naming Status (2026-02-28)

Canonical Paragon v22 naming is now the enforced source of truth in frontend token gates.
See `docs/architecture/PARAGON_V22_TOKEN_AUDIT.md` and
`scripts/qa/verify-design-tokens-migration.sh`.

Current policy:
- Use canonical names only (for example, `--pgn-color-primary-base` and
  `--pgn-typography-font-family-sans-serif`)
- Do not define or reference short-form legacy names (`--pgn-color-primary`,
  `--pgn-font-family-sans-serif`, `--pgn-border-radius`)
- Keep work focused on the "Consumed & Defined" token set that Paragon actually reads

---

## Phase D Preview (NOT in scope for Phase C)

The following are identified but deferred to Phase D:

- **Dead Selector Rewrite**: ~60% of `[class*="..."]` selectors are phantom CSS. Phase D must inspect actual DOM class names and rewrite selectors or migrate to plugin slots. See `docs/architecture/FPF_PLUGIN_SLOT_REGISTRY.md` for the 98 available FPF slots.
- **FPF Plugin Slots**: Use `header_slot` and `footer_slot` to inject custom React header/footer components. This replaces the most fragile BEM overrides (header gradient, logo injection, nav styling) with a supported extension mechanism. See `specs/mfe-plugin-slots_spec.md`. Full slot inventory at `docs/architecture/FPF_PLUGIN_SLOT_REGISTRY.md`.
- **style-dictionary JSON pipeline**: Replace the SCSS-to-CSS extraction in `build-tokens.sh` with a proper JSON → CSS pipeline using `style-dictionary`. This enables multi-format output (CSS, SCSS, JSON, iOS, Android).
- **Dark mode**: Add `variants.dark` to PARAGON_THEME_URLS. Currently out of scope (light mode only).
- **Performance budgets in CI**: Add Lighthouse CI with LCP < 2.5s, bundle < 300KB gzipped, theme CSS < 50KB targets.

---

## Audit Intelligence (2026-02-27)

### Dependency Constraints
- **React**: MFEs are locked to React 17 by Paragon v22. Do NOT attempt React 18+ features (concurrent mode, useTransition, etc.)
- **Webpack 5**: Asset pipeline uses webpack 5 (not Vite). All build optimizations must target webpack.
- **Paragon v22 (Ulmo)**: This is the version bundled with Tutor v21. Do NOT upgrade Paragon independently — it's tied to the Open edX release.

### Caching Architecture (FIXED in Phase B review)
- Outer Caddy now has tiered caching: `immutable` for `/static/*` and `/theming/asset/*`, `no-cache` default, `no-store` for `/api/*`/`/oauth2/*`/`/login*`/`/admin*`
- MFE Caddy already has its own tiered caching (lines 28-42 in MFE Caddyfile)
- Theme CSS files served via `/theme/*` will get the MFE Caddy's `@hashed` matcher — add `.css` to the hashed extensions if not already present
- Verification: `scripts/qa/verify-caddy-cache-policy.sh` (12 checks)

### brand-core.css vs brand-light.css Identity
- `brand-core.css` and `brand-light.css` are byte-identical. This is expected because we only support light mode. When generating `mereka-brand.min.css` and `mereka-brand-light.min.css`, it's OK for them to be identical for now. Add a comment explaining this.

### Accessibility Constraints
- All color tokens MUST pass WCAG 2.1 AA contrast (4.5:1 for text, 3:1 for large text/UI)
- The Mereka palette has known contrast challenges:
  - `#f4be48` (gold/warning) on white fails AA — use on dark backgrounds only or darken to `#c99a00`
  - `#94d1e4` (sky/info-soft) on white fails AA — use as background only, not text
- Run contrast checks on any new token color values before committing

### Performance Budget Targets
- LCP (Largest Contentful Paint): < 2.5s on 4G mobile
- Total JS bundle per MFE: < 300KB gzipped
- Theme CSS: < 50KB (ideally < 20KB — just custom properties)
- Font loading: woff2 only, `font-display: swap`, preconnect to font origin
