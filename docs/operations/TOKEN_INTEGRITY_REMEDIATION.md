# Token Integrity Remediation Guide

> Reference: DR1 gap findings (P0/P1), bead mereka-lms-8jao.4

## Token Architecture

```
assets/branding/tokens.css          ← Canonical design system (Figma export)
       │
       ▼ (manual sync)
scss/_tokens.scss                   ← SCSS bridge ($vars + :root --mereka-*)
       │
       ├──▶ mereka-overrides.css    ← Runtime CSS (common/lms/cms)
       └──▶ mfe/mereka.scss         ← MFE theme (imports via @import)
```

## Verification Scripts

| Script | ACs | Purpose |
|--------|-----|---------|
| `verify-branding-token-integrity.sh` | AC-TOK-001..005 | Canonical cross-check + contrast |
| `verify-token-reference-integrity.sh` | AC-UITKN-001..004 | Reference resolution + drift |
| `verify-token-definitions.sh` | — | Token definition correctness |
| `verify-contrast-compliance.sh` | — | Full WCAG contrast matrix |

## Common Issues

### Undefined Token Reference
**Symptom**: CSS property uses `var(--mereka-color-X)` but X is not defined.
**Fix**: Add definition to `_tokens.scss` `:root` block AND mirror in all `mereka-overrides.css` files.

### Token Value Drift
**Symptom**: Same token has different hex values in different files.
**Fix**: Update all files to match `_tokens.scss` as source of truth.

### Contrast Failure
**Symptom**: Text color on background fails WCAG AA (4.5:1).
**Fix**: Darken the text color or lighten the background. Check with `verify-branding-token-integrity.sh`.

## ink Token Scale

| Token | Value | Use |
|-------|-------|-----|
| `--mereka-color-ink-900` | #000000 | Body text, headings |
| `--mereka-color-ink-700` | #4A494A | Secondary text, labels |
| `--mereka-color-ink-500` | #737373 | Placeholder, disabled |
| `--mereka-color-ink-300` | #929092 | Borders, dividers |

**Note**: `--mereka-color-ink-600` is intentionally NOT defined. If needed, add to `_tokens.scss` first.

## Contrast Quick Reference

Body text pairs that MUST meet WCAG AA (4.5:1):
- ink-900 (#000000) on surface-primary (#FBFAFB) → 19.9:1 ✅
- ink-700 (#4A494A) on surface-primary (#FBFAFB) → 7.8:1 ✅
- ink-500 (#737373) on surface-primary (#FBFAFB) → check required

## Remediation Workflow

1. **Identify issue**: Run `./scripts/qa/verify-branding-token-integrity.sh`
2. **Locate first failure**: Script reports first undefined token with file:line
3. **Add definition**: Add token to `_tokens.scss` `:root` block
4. **Mirror to overrides**: Copy token to all `mereka-overrides.css` files
5. **Verify**: Re-run script to confirm PASS

## Example: Adding Missing Token

If script reports:
```
[FAIL] AC-TOK-001: 1 undefined token(s) — first: --mereka-color-ink-600 in mereka.scss:42
```

Fix:
1. Add to `_tokens.scss`:
   ```scss
   :root {
     --mereka-color-ink-600: #5B5B5C;  // Between ink-700 and ink-500
   }
   ```
2. Mirror to `common/static/css/mereka-overrides.css`:
   ```css
   :root {
     --mereka-color-ink-600: #5B5B5C;
   }
   ```
3. Repeat for `lms/static/css/mereka-overrides.css` and `cms/static/css/mereka-overrides.css`
4. Verify: `./scripts/qa/verify-branding-token-integrity.sh`

## Contrast Remediation

If script reports:
```
[FAIL] AC-TOK-004: ink-900 on surface-primary = 3.2:1 (FAILS 4.5:1 AA threshold)
```

Fix options:
1. **Darken text**: Change ink-900 from #4A494A to #000000
2. **Lighten background**: Change surface-primary from #F0F0F0 to #FFFFFF
3. **Use different token**: Switch to ink-900 instead of ink-700

Verify with:
```bash
./scripts/qa/verify-branding-token-integrity.sh
./scripts/qa/verify-contrast-compliance.sh  # Full matrix
```

## CI Integration

The script is integrated into `.github/workflows/ci.yml` as `branding-token-integrity` job.

Pull requests will fail if:
- Any `var(--mereka-*)` reference is undefined
- Body text contrast falls below WCAG AA (4.5:1)
- Token definitions are missing

## Related Documentation

- Architecture: `docs/architecture/TOKEN_REFERENCE_INTEGRITY.md`
- Branding: `docs/BRANDING.md`
- Design tokens spec: `specs/ui-ux-design-tokens_spec.md`
