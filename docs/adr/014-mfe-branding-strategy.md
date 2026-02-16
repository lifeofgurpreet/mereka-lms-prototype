# ADR-014: MFE Branding Strategy - Migration Path Analysis

**Status**: ✅ **ACCEPTED**
**Date**: 2026-02-12
**Deciders**: Platform Team (Decision Owner: Gurpreet)
**Related**: [ADR-012: No Runtime CSS Overlay](012-no-runtime-css-overlay.md), [FRONTEND_BRANDING_METHOD.md](../operations/FRONTEND_BRANDING_METHOD.md), [ADR-006: Tutor Plugin-Based Configuration](006-tutor-plugin-based-configuration.md)

<!-- Last verified: 2026-02-16 -->

---

## Executive Summary

**Current State**: We use a custom SCSS-based theming approach that works but doesn't follow Open edX industry standards (OEP-48).

**Question**: Should we migrate to the standard npm brand package pattern (`@mereka/brand`)?

**Decision**: **Option C: Phased Migration** — Plugin-first for configuration and component injection via Tutor hooks. Asset sync (logos, fonts, SCSS files) remains in apply-patches.sh as a complementary step. Migration to OEP-48 brand package deferred until next major Open edX release.

**Rationale**: Current approach works reliably. Plugin handles configuration automatically via Tutor hooks. Script handles file-system operations (asset sync, theme directories). Migration to full OEP-48 standard provides benefits but is not urgent given stable branding and low change frequency.

---

## Current State Analysis

### What We Have (As of 2026-02-12)

**Approach**: Hybrid 2-layer theming
1. **Base layer**: MFEs use default `@edx/brand` → `@openedx/brand-openedx@^1.2.2`
2. **Override layer**: Custom SCSS injected via `scripts/branding/setup-mfe-branding.sh`

**MFE Coverage**:
| MFE | Branding Applied | Usage |
|-----|:----------------:|-------|
| `frontend-app-learning` | ✅ | Course learning experience |
| `frontend-app-authn` | ✅ | Login/registration |
| `frontend-app-account` | ✅ | Account settings |
| `frontend-app-profile` | ✅ | User profiles |
| `frontend-app-gradebook` | ✅ | Instructor gradebook |
| `frontend-app-course-authoring` | ❌ | Studio course authoring (NOT branded) |

**Custom Components**:
- ✅ **LMS footer**: Heavily customized Django template (`infrastructure/tutor/themes/mereka/lms/templates/footer.html`)
  - Custom structure, links, branding copy
  - 95 lines of custom HTML
  - Partners section, custom support links, tagline

**Theming Mechanism**:
```scss
// Injected into each MFE's src/styles/mereka.scss
$mereka-font-path: "/fonts";
@import "../../../../../infrastructure/tutor/themes/mereka/scss/theme";
```

**Paragon Variable Bridge** (`scss/_tokens.scss`):
- Manually maps Mereka colors → Paragon CSS variables
- Example: `--pgn-color-primary: #ab3b78` (magenta)
- Works at runtime, no rebuild needed for CSS var changes

**Asset Sync**: `scripts/branding/sync-brand-assets.sh`
- Copies fonts, logos, favicons to all theme directories
- Must run after design system updates

---

## Industry Standard (OEP-48)

### What Open edX Recommends

**Pattern**: Create custom brand package as npm module

**Structure**:
```
@mereka/brand/
├── logo.svg
├── logo-white.svg
├── favicon.ico
├── paragon/
│   ├── fonts.scss
│   ├── _variables.scss
│   ├── _overrides.scss
│   └── tokens/          # Design tokens (JSON)
│       ├── colors.json
│       ├── typography.json
│       └── spacing.json
```

**Installation**:
```json
{
  "dependencies": {
    "@edx/brand": "npm:@mereka/brand@^1.0.0"
  }
}
```

**Compilation**: Design tokens → Style Dictionary → CSS variables (automated)

**Sources**: [OEP-48](https://open-edx-proposals.readthedocs.io/en/latest/architectural-decisions/oep-0048-brand-customization.html), [Paragon Design Tokens](https://github.com/openedx/paragon/blob/master/docs/decisions/0019-scaling-styles-with-design-tokens.rst)

---

## Comparison Analysis

### Current Approach vs. OEP-48

| Dimension | Current (SCSS Overlay) | OEP-48 (Brand Package) | Winner |
|-----------|------------------------|------------------------|:------:|
| **Setup Complexity** | HIGH<br/>- Run `setup-mfe-branding.sh` after clone<br/>- Manual SCSS injection<br/>- Script must know all MFEs | LOW<br/>- Just `npm install`<br/>- No post-clone scripts | 🏆 OEP-48 |
| **Maintainability** | MEDIUM<br/>- Manual `_tokens.scss` updates<br/>- Must sync 5-6 MFE repos | HIGH<br/>- Automated token compilation<br/>- Single npm package | 🏆 OEP-48 |
| **Version Control** | MIXED<br/>- SCSS in git repo<br/>- MFE clones not versioned | CLEAN<br/>- npm versioning (`@mereka/brand@1.2.0`)<br/>- Semantic versioning | 🏆 OEP-48 |
| **Token Management** | MANUAL<br/>- Hand-edit `_tokens.scss`<br/>- CSS + SCSS duplication | AUTOMATED<br/>- Figma Tokens plugin → JSON<br/>- Style Dictionary compilation | 🏆 OEP-48 |
| **Team Knowledge** | TRIBAL<br/>- Custom workflow<br/>- "How does our theming work?" | STANDARD<br/>- Open edX best practice<br/>- Well-documented | 🏆 OEP-48 |
| **Build Time** | SAME (SCSS compilation) | SAME (SCSS compilation) | 🤝 TIE |
| **Runtime Theming** | POSSIBLE<br/>- CSS vars in SCSS<br/>- Manual setup | NATIVE<br/>- Paragon 23+ design tokens<br/>- Built-in support | 🏆 OEP-48 |
| **Custom Footers (React)** | ❌ NOT POSSIBLE | ❌ NOT POSSIBLE | 🤝 TIE |
| **Custom Footers (Django)** | ✅ YES (LMS templates) | ✅ YES (LMS templates) | 🤝 TIE |
| **Migration Cost** | N/A (current state) | 2-3 days (initial package creation) | - |
| **Current Functionality** | ✅ WORKS | 🟡 REQUIRES MIGRATION | 🏆 CURRENT |

**Score**: OEP-48 wins 7/11 dimensions

---

## What Brand Package CAN and CANNOT Do

### ✅ Capabilities (Static Assets + Styling)

**Includes**:
- Logos, favicons, brand images
- Colors, fonts, spacing (SCSS variables or design tokens)
- Button styles, card styles, typography
- Any CSS/SCSS styling
- Design token compilation (JSON → CSS variables)

**Zero JavaScript dependencies** - it's a static asset bundle.

---

### ❌ Limitations (No React/Angular Code)

**Does NOT include**:
- React components (`.jsx`, `.tsx`)
- JavaScript code
- Custom footers as React components
- Custom headers as React components
- Angular components
- Page layouts or structure

**Why**: Brand packages are compiled into CSS during build, not code libraries.

---

### 🎨 How to Do Custom Headers/Footers

**For React components** (MFEs), use **Plugin Framework**:

**Example**: Custom footer via plugin
```javascript
// @mereka/footer-plugin/src/CustomFooter.jsx
export const CustomFooter = () => (
  <footer className="mereka-footer">
    <p>🌟 Powered by Mereka Academy</p>
  </footer>
);

// Configure in MFE env.config.jsx
import { PLUGIN_OPERATIONS } from '@openedx/frontend-plugin-framework';

const config = {
  pluginSlots: {
    footer_slot: {
      plugins: [{
        op: PLUGIN_OPERATIONS.Replace,
        widget: { id: 'custom_footer', RenderWidget: CustomFooter }
      }]
    }
  }
};
```

**For Django templates** (LMS/Studio):
- ✅ Already doing this! See: `infrastructure/tutor/themes/mereka/lms/templates/footer.html`
- No change needed regardless of brand package decision

**Sources**: [Frontend Component Footer](https://github.com/openedx/frontend-component-footer), [How to customize MFE footer](https://discuss.openedx.org/t/how-to-customize-header-and-footer-in-devstack-mfe/10362)

---

## Migration Paths

### Option A: Status Quo (Do Nothing)

**Keep current SCSS overlay approach**

**Pros**:
- ✅ Zero migration effort
- ✅ Currently working well
- ✅ Team familiar with workflow

**Cons**:
- ❌ Diverges from Open edX standards
- ❌ Manual maintenance burden
- ❌ Complex onboarding for new developers
- ❌ Tribal knowledge required

**When to choose**: If branding is stable and rarely changes.

---

### Option B: Full Migration (All-In)

**Create `@mereka/brand` npm package, migrate all MFEs at once**

**Steps**:
1. Create `@mereka/brand` package structure
2. Generate design tokens from Figma (Figma Tokens plugin → JSON)
3. Set up Style Dictionary compilation
4. Publish to npm (private registry or GitHub Packages)
5. Update all 6 MFE package.json files
6. Remove `setup-mfe-branding.sh` script
7. Update build/deploy workflows
8. Document new workflow

**Effort**: 2-3 days

**Pros**:
- ✅ Clean break from custom approach
- ✅ Immediate benefits (automated tokens, versioning)
- ✅ One-time migration pain

**Cons**:
- ❌ Upfront effort when branding is stable
- ❌ Risk if migration has issues
- ❌ All-or-nothing approach

**When to choose**: If planning major branding changes or team scaling.

---

## Decision

**ACCEPTED**: Option C — Phased Migration

Plugin delivers configuration and component injection via Tutor hooks. Asset sync (logos, fonts, SCSS files) remains in apply-patches.sh as a complementary step. Migration to OEP-48 brand package deferred until next major Open edX release.

### Implementation Approach

**Migrate incrementally as branding needs arise**

**Phase 1**: Create `@mereka/brand` package structure (empty skeleton)
- Set up npm package
- Document structure
- No MFE changes yet
- **Effort**: 4 hours

**Phase 2**: Migrate design tokens when Figma updates
- Next time design system changes in Figma
- Export tokens to `@mereka/brand` package
- Migrate 1-2 MFEs as pilot
- **Effort**: 1 day per design system update

**Phase 3**: Migrate remaining MFEs opportunistically
- When touching an MFE for other reasons
- Gradually reduce `setup-mfe-branding.sh` scope
- **Effort**: 2 hours per MFE

**Phase 4**: Retire SCSS overlay
- Once all MFEs migrated
- Delete `setup-mfe-branding.sh`
- Update docs
- **Effort**: 2 hours

**Total timeline**: 3-6 months (opportunistic)

**Pros**:
- ✅ Low risk (incremental)
- ✅ No dedicated migration project
- ✅ Learn as you go
- ✅ Can pause/resume anytime

**Cons**:
- ❌ Longer timeline
- ❌ Temporary dual-mode complexity

**When to choose**: When branding is stable but you want to move toward standards eventually.

---

## Decision Criteria

### Choose Status Quo (Option A) IF:
- Branding changes are rare (< 2x per year)
- Team size is stable (< 3 devs)
- No immediate pain with current approach
- Other priorities are higher

### Choose Full Migration (Option B) IF:
- Planning major branding overhaul
- Frequent design system updates (> 4x per year)
- Team scaling planned
- Want to align with Open edX standards now

### Choose Phased Migration (Option C) IF:
- Want best practice alignment but no urgency
- Prefer incremental change over big-bang
- Can tolerate temporary dual-mode
- Branding changes 2-3x per year

---

## Recommendation

**Option C: Phased Migration** starting when next branding change happens.

**Rationale**:
1. Current approach works - no urgent pain
2. Incremental migration is lower risk
3. Aligns with Open edX standards eventually
4. No dedicated migration project needed
5. Learn from pilot before full rollout

**Trigger**: Start Phase 1 when:
- Next Figma design system update
- Adding new MFE
- Team scaling begins
- OR 6 months from now (2026-08-12)

---

## Open Questions (Needs User Input)

### 🔴 Must Answer Before Migration

1. **Do we plan major branding changes in next 6 months?**
   - Yes → Full Migration (Option B)
   - No → Phased Migration (Option C) or Status Quo (Option A)

2. **How often does Figma design system change?**
   - > 4x/year → Full Migration
   - 2-3x/year → Phased Migration
   - < 2x/year → Status Quo

3. **Do we need custom React footers in MFEs?**
   - Yes → Investigate Plugin Framework (separate from brand package)
   - No → LMS footer template sufficient

4. **Are we satisfied with current MFE branding coverage?**
   - Need more customization → Consider Plugin Framework
   - Current level fine → Brand package sufficient

5. **Team scaling planned in next 12 months?**
   - Yes → Lean toward migration (easier onboarding)
   - No → Status quo acceptable

---

## Next Steps (After Decision)

### If Choosing Option A (Status Quo):
1. ✅ Document current approach (already done: `FRONTEND_BRANDING_METHOD.md`)
2. ✅ Create runbook for `setup-mfe-branding.sh` usage
3. ✅ Add to onboarding checklist
4. ✅ Revisit in 6 months

### If Choosing Option B (Full Migration):
1. 📋 Create `@mereka/brand` package structure
2. 📋 Set up Figma → JSON token export
3. 📋 Configure Style Dictionary
4. 📋 Publish to npm
5. 📋 Update all MFE package.json files
6. 📋 Delete `setup-mfe-branding.sh`
7. 📋 Update CI/CD workflows
8. 📋 Document in `FRONTEND_BRANDING_METHOD.md`

### If Choosing Option C (Phased):
1. ✅ Create skeleton `@mereka/brand` package (Phase 1) - defer until trigger
2. ⏳ Wait for next branding change
3. 📋 Migrate 1-2 MFEs as pilot (Phase 2)
4. 📋 Migrate remaining MFEs opportunistically (Phase 3)
5. 📋 Retire SCSS overlay (Phase 4)

---

## Related Documentation

- **Current Method**: [FRONTEND_BRANDING_METHOD.md](../operations/FRONTEND_BRANDING_METHOD.md)
- **CSS Delivery**: [ADR-012: No Runtime CSS Overlay](012-no-runtime-css-overlay.md)
- **Branding Assets**: `infrastructure/tutor/themes/mereka/README.md`
- **LMS Footer**: `infrastructure/tutor/themes/mereka/lms/templates/footer.html`
- **MFE Setup**: `scripts/branding/setup-mfe-branding.sh`

---

## References

- [OEP-48: Brand Customization](https://open-edx-proposals.readthedocs.io/en/latest/architectural-decisions/oep-0048-brand-customization.html)
- [Paragon Design Tokens ADR](https://github.com/openedx/paragon/blob/master/docs/decisions/0019-scaling-styles-with-design-tokens.rst)
- [Brand Package Structure](https://github.com/openedx/brand-openedx)
- [Frontend Component Footer](https://github.com/openedx/frontend-component-footer)
- [MFE Customization Discussion](https://discuss.openedx.org/t/how-to-customize-header-and-footer-in-devstack-mfe/10362)
- [Paragon Theming Guide](https://openedx.atlassian.net/wiki/spaces/BPL/pages/3630923811/Scaling+Paragon+s+styles+architecture+with+design+tokens)

---

**Last Updated**: 2026-02-16
**Decision Owner**: Gurpreet
**Status**: ✅ ACCEPTED - Plugin-first configuration, SCSS overlay for visual branding
**Revisit Date**: 2026-08-12 (6 months) or when next branding change occurs
