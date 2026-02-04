# Branding Verification Checklist - 2026-02-04

## Summary

**Overall Status: IMPLEMENTED (runtime verification pending)** - repo wiring + assets are in place; confirm via checks below

| Component | Status | Issues |
|-----------|--------|--------|
| LMS Homepage | ✅ Expected | Verify hero + footer in runtime |
| LMS Footer | ✅ Expected | Custom footer + logo in runtime |
| LMS Header | ✅ Expected | Mereka logo + nav chrome |
| Studio | ✅ Expected | Theme applied, “Mereka Academy - Studio” |
| MFE (Login) | ✅ Expected | Authn loads via LMS config |
| MFE (Other) | ✅ Expected | Same config path as login |
| Courses Page | ✅ Expected | Header/footer consistent |
| Brand Colors | ⚠️ Review | Align with official palette if needed |

---

## Resolved Issues (Historical)

### 1. MFE Login Page Config API
**Fix shipped**: Caddy `Host` header override + MFE config alignment.
**Verify**: `curl -s "https://academyv2.mereka.io/api/mfe_config/v1?mfe=authn" | jq .`

### 2. Studio Theme
**Fix shipped**: Theme wiring applied via Tutor patches and theme assets sync.
**Verify**: `scripts/qa/verify-studio-branding.sh`

---

## Remaining Follow-ups

### 1. Palette Alignment Review
The official palette calls for teal/magenta/blue accents. Confirm whether the current token set
matches brand intent and adjust `_tokens.scss` if needed.

---

## Working Elements (Expected)

### LMS Header
- Mereka logo displays correctly in navigation
- "Explore courses" link present
- "Register for free" and "Sign in" buttons styled
- Teal accent color visible on search button

### LMS Footer Content
- Footer text is correct ("Mereka Academy blends community...")
- Sections (Explore, Support, Partners) populated
- Links point to correct URLs
- Copyright shows "2026 Biji-Biji Initiative · Mereka Academy"
- "Powered by Open edX and Tutor" attribution present

### LMS Courses Page
- Same header/footer as homepage
- Search functionality present
- "Refine Your Search" sidebar visible

---

## Theme Files Inventory

### Present in Repository
```
infrastructure/tutor/themes/mereka/
├── common/static/
│   ├── fonts/ (Lato, Poppins woff2 files)
│   └── images/ (logos, favicons)
├── lms/
│   ├── static/sass/theme.scss
│   ├── static/images/logo.png
│   └── templates/ (footer.html, header/brand.html, index_overlay.html)
├── cms/static/sass/theme.scss
├── mfe/ (fonts, images, mereka.scss)
└── scss/ (_fonts.scss, _tokens.scss, theme.scss)
```

### Theming Configuration Required
- `ENABLE_COMPREHENSIVE_THEMING: true`
- `DEFAULT_SITE_THEME: "mereka"`
- `COMPREHENSIVE_THEME_DIRS: ["/openedx/themes"]`

---

## Screenshots to Capture (Post-Verification)

| Screenshot | Location | Description |
|------------|----------|-------------|
| /tmp/lms-homepage.png | LMS | Hero + header + footer branded |
| /tmp/lms-footer.png | LMS | Footer links + logo visible |
| /tmp/studio-homepage.png | Studio | “Mereka Academy - Studio” header |
| /tmp/mfe-login.png | MFE | Authn login page rendered correctly |
| /tmp/courses.png | LMS | Courses page with cards |

---

## Recommended Verification Order

1. Run `./scripts/branding/verify-branding-health.sh`
2. Run `scripts/qa/verify-studio-branding.sh` (cluster)
3. Visual check LMS/MFE pages for hero, footer, and cards

---

## Verification Commands

```bash
# Offline asset wiring check
./scripts/branding/verify-branding-health.sh

# Check theme is applied
curl -s https://academyv2.mereka.io | grep -i "mereka"

# Check MFE config API (LMS)
curl -s "https://academyv2.mereka.io/api/mfe_config/v1?mfe=authn" | jq .

# Check static assets
curl -sI https://academyv2.mereka.io/theming/asset/images/logo.png
curl -sI https://academyv2.mereka.io/theming/asset/images/logo-horizontal.png

# Check Studio theme
curl -s https://studio.academyv2.mereka.io | grep -E "(Mereka|My Open edX)"

# Visual verification with agent-browser
agent-browser open https://academyv2.mereka.io && agent-browser screenshot homepage.png
```

---

## Next Steps

1. [ ] Run the verification steps above in GKE + dev
2. [ ] Confirm hero gradient + footer logos visually
3. [ ] Review token palette vs official brand colors
