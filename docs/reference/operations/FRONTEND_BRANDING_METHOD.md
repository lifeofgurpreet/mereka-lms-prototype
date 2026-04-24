# Frontend Branding & Theming Method
_Audience: Developers + Operations • Owner: Platform Team • Last updated: 2026-02-12_

## 🎯 Summary

**Question**: Are we using the tutor-contrib-paragon plugin for MFE theming?

**Answer**: **NO**. We use a two-layer approach:

1. **Tutor Plugin** (`infrastructure/tutor/plugins/mereka_lms.py`) — Handles MFE footer component injection and Google Fonts stripping via Tutor hooks
2. **SCSS Overlay** — Custom SCSS-based approach that manually bridges Mereka design tokens to Paragon CSS variables

**Visual branding** via SCSS overlay; **component injection** via Tutor plugin.

---

## Current Approach

### Architecture

```
Figma Design System
       ↓
mereka-design-tokens.css (CSS custom properties)
       ↓
scss/_tokens.scss (SCSS variables + Paragon bridge)
       ↓                                ↓
LMS/Studio/MFE assets (compiled CSS)   Tutor Plugin (MFE footer, Google Fonts stripping)
```

**Two-Layer System**:
- **Plugin** (`mereka_lms.py`): Configuration and component injection (MFE footer, Google Fonts stripping, build config)
- **SCSS Overlay**: Visual branding (colors, typography, spacing via Paragon CSS variables)

### Key Files

| File | Purpose |
|------|---------|
| `common/static/css/mereka-design-tokens.css` | Source of truth: CSS custom properties from Figma |
| `scss/_tokens.scss` | SCSS variables + Paragon variable bridge (`--pgn-*`) |
| `scss/_fonts.scss` | Font-face declarations (Lato, Poppins) |
| `scss/theme.scss` | Minimal utility classes, gradient helpers |

### Paragon Variable Bridge

The `scss/_tokens.scss` file manually maps Mereka brand tokens to Paragon CSS variables:

```scss
:root {
  // Mereka brand colors
  --mereka-color-teal: #2d898b;
  --mereka-color-magenta: #ab3b78;

  // Map to canonical Paragon v22 variables (used by MFEs)
  --pgn-color-primary-base: #{$color-magenta};
  --pgn-color-secondary-base: #{$color-teal};
  --pgn-typography-font-family-sans-serif: #{$mereka-body-font};
  --pgn-typography-headings-font-family: #{$mereka-heading-font};
  --pgn-border-color: #{$color-border};
  --pgn-btn-border-radius: 999px;
}
```

**Why this works**: Paragon components consume canonical CSS variables like `--pgn-color-primary-base`. By setting these in our SCSS, we theme all MFEs without needing the plugin.

---

## Asset Sync Workflow

### 1. Update Design Tokens
```bash
# Edit CSS custom properties from Figma updates
vim infrastructure/tutor/themes/mereka/common/static/css/mereka-design-tokens.css
```

### 2. Sync Assets
```bash
# Sync logos, fonts, favicons to all theme directories
./scripts/branding/sync-brand-assets.sh

# OR
make branding-sync
```

### 3. Rebuild & Deploy

**Local reproduction / design review**
```bash
# Rebuild LMS/Studio images
./scripts/infra/build-openedx-image.sh --local-defaults --build-profile fast

# Rebuild MFE images
./scripts/infra/build-mfe-image.sh --local-defaults --build-profile fast

# Deploy locally
tutor local restart
```

**Production**
- Publish the updated Open edX / MFE images through `.github/workflows/build-tutor-images.yml`
- Promote the resulting digests with `./scripts/infra/release-openedx-gitops.sh --require-digests`
- Do not use `tutor k8s restart` as the normal production rollout path

### 4. Verify
```bash
# Verify CSS tokens
./scripts/branding/verify-branding-css.sh

# Verify logos and fonts
./scripts/branding/verify-logo-setup.sh

# Full branding health check
./scripts/branding/verify-branding-health.sh
```

---

## tutor-contrib-paragon Plugin (NOT USED)

### What It Does
- Compiles Paragon design tokens using Paragon CLI
- Generates CSS themes from JSON design token files
- Automatically applies to all MFEs

### Why We Don't Use It
1. **Manual control**: We want explicit control over SCSS compilation
2. **Existing workflow**: Asset sync scripts already established
3. **Custom bridge**: Our `_tokens.scss` provides fine-grained control
4. **No migration needed**: Current approach works well

**Reference**: [tutor-contrib-paragon](https://github.com/openedx/openedx-tutor-plugins/tree/main/plugins/tutor-contrib-paragon)

---

## LMS/Studio Theming

### Tutor Theme Pipeline

1. Tutor copies `infrastructure/tutor/themes/` → `tutor_env/build/openedx/themes/`
2. LMS/Studio entrypoints include `scss/theme.scss`
3. Compilation happens during `collectstatic`

**Setup**:
```bash
export TUTOR_ROOT="$(pwd)/tutor_env"
./scripts/infra/tutor-config-save.sh --set THEME_DIR="$(pwd)/infrastructure/tutor/themes" --set THEME_NAME=mereka
./scripts/infra/build-openedx-image.sh --local-defaults --build-profile fast
```

**Force asset rebuild** (local dev):
```bash
tutor local run lms ./manage.py lms collectstatic --noinput
```

---

## MFE Theming

### Import Pattern

Inside each `frontend-app-*` MFE:

```scss
// src/styles/mereka.scss
$mereka-font-path: "~@mereka/theme/fonts";
@import "./scss/fonts";
@import "./scss/tokens";
@import "./scss/base";
```

Then import from `src/index.scss`:

```scss
@import './styles/mereka.scss';
```

### Font Path Variable

The `$mereka-font-path` variable ensures correct font paths:
- **MFEs**: `/public/fonts` (when building standalone)
- **LMS/Studio**: `/static/mereka/fonts` (when running under Tutor)

---

## Verification Scripts

| Script | Purpose |
|--------|---------|
| `sync-brand-assets.sh` | Copy fonts/logos/favicons to all theme directories |
| `verify-branding-css.sh` | Verify CSS token compilation |
| `verify-logo-setup.sh` | Verify logo files present and accessible |
| `verify-branding-health.sh` | Full branding health check |
| `verify-token-drift.sh` | Check for drift between CSS and SCSS tokens |
| `update-token-provenance.sh` | Update token provenance metadata |

---

## Design Token Update Process

### When Figma Design System Changes

1. **Export from Figma** → `mereka-design-tokens.css`
2. **Update SCSS bridge** → `scss/_tokens.scss` (if new tokens added)
3. **Sync assets** → `./scripts/branding/sync-brand-assets.sh`
4. **Verify** → Run verification scripts
5. **Commit both locations** → `assets/branding/` + `infrastructure/tutor/themes/mereka/`
6. **Rebuild images** → LMS/Studio + MFEs
7. **Deploy** → Push to production

---

## Common Issues

### Fonts Not Loading
**Symptom**: MFEs show system fonts instead of Lato/Poppins

**Fix**:
```bash
# Verify fonts exist
ls -la infrastructure/tutor/themes/mereka/mfe/fonts/

# Sync assets
./scripts/branding/sync-brand-assets.sh

# Rebuild MFE image
./scripts/infra/build-mfe-image.sh --local-defaults --build-profile fast
```

### CSS Variables Not Applied
**Symptom**: MFEs use default Paragon colors (blue instead of magenta)

**Fix**:
```bash
# Verify canonical Paragon variable bridge
grep "pgn-color-primary-base" infrastructure/tutor/themes/mereka/scss/_tokens.scss

# Should show: --pgn-color-primary-base: #ab3b78;

# If missing, add to :root block in _tokens.scss
```

### Logo Not Showing
**Symptom**: Default Open edX logo instead of Mereka logo

**Fix**:
```bash
# Run logo verification
./scripts/branding/verify-logo-setup.sh

# Run logo fix script if needed
./scripts/branding/fix-logo-static-files.sh
```

---

## Related Documentation

- **Theme README**: `infrastructure/tutor/themes/mereka/README.md`
- **Branding Guide**: `docs/guides/branding/BRANDING.md`
- **Asset Sync**: `scripts/branding/sync-brand-assets.sh`
- **Design System**: https://www.figma.com/design/jBO2FrTslM4wocrRzwQaPo/mereka.io-Design-System

---

## Current MFE Branding Coverage

**6 MFEs Total**:
| MFE | Branding | Usage |
|-----|:--------:|-------|
| `frontend-app-learning` | ✅ | Course learning experience |
| `frontend-app-authn` | ✅ | Login/registration |
| `frontend-app-account` | ✅ | Account settings |
| `frontend-app-profile` | ✅ | User profiles |
| `frontend-app-gradebook` | ✅ | Instructor gradebook |
| `frontend-app-course-authoring` | ❌ | Studio course authoring (NOT branded) |

**Custom Components**:
- ✅ **LMS Footer**: Heavily customized (`infrastructure/tutor/themes/mereka/lms/templates/footer.html`)
  - 95 lines of custom HTML
  - Custom structure, links, partners section

---

## Future Considerations

### Migration to OEP-48 Brand Package (@mereka/brand)

**Status**: 🔴 **DECISION PENDING** - See [ADR-014](../../programs/frontend/MFE_BRANDING_MIGRATION_DECISION.md)

**Current Analysis** (2026-02-12):
- OEP-48 brand package approach is industry standard
- Our custom SCSS overlay works but diverges from best practices
- Three migration options documented (Status Quo, Full Migration, Phased)
- **Recommendation**: Phased migration starting at next branding change

**Key Questions** (needs user input):
1. How often does Figma design system change?
2. Do we plan major branding changes in next 6 months?
3. Team scaling planned?
4. Need custom React footers in MFEs?

**Read full analysis**: [ADR-014: MFE Branding Strategy](../../programs/frontend/MFE_BRANDING_MIGRATION_DECISION.md)

---

**Last Updated**: 2026-02-12
**Maintained By**: Platform Team
**Review Cadence**: When design system changes
