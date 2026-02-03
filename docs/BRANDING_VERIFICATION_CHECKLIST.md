# Branding Verification Checklist - 2026-02-03

## Summary

**Overall Status: PARTIALLY IMPLEMENTED** - LMS has Mereka branding but critical issues exist

| Component | Status | Issues |
|-----------|--------|--------|
| LMS Homepage | ⚠️ Partial | Hero background missing, footer logo broken |
| LMS Footer | ⚠️ Partial | Logo shows alt text, image path issue |
| LMS Header | ✅ Working | Mereka logo displays correctly |
| Studio | ❌ Broken | Shows "My Open edX - Studio" instead of Mereka |
| MFE (Login) | ❌ Broken | Error page, API routing issue |
| MFE (Other) | ❌ Broken | All MFEs affected by same issue |
| Courses Page | ✅ Working | Header/footer consistent |
| Brand Colors | ⚠️ Partial | Teal visible, full palette not applied |

---

## Critical Issues (P0)

### 1. MFE Login Page Completely Broken
**URL**: https://apps.academyv2.mereka.io/authn/login
**Symptom**: Shows "An unexpected error occurred. Please click the button below to refresh the page."

**Root Cause**:
- MFE is calling `/api/mfe_config/v1?mfe=authn` on the MFE domain (apps.academyv2.mereka.io)
- This routes to mfe:8002 (Caddy static server) which returns 400
- Should call LMS domain (academyv2.mereka.io) for API

**Console Errors**:
```
SESSION_COOKIE_DOMAIN is required by ProcessEnvConfigService
Error with config API Request failed with status code 400
```

**Fix Required**: Update MFE build configuration to use correct API base URL

### 2. Studio Shows Generic Open edX Branding
**URL**: https://studio.academyv2.mereka.io
**Symptom**: Page title "Welcome to My Open edX - Studio"

**Root Cause**: Studio is using default Open edX theme, not Mereka theme

**Evidence**:
- Header shows generic gray circle icon
- Title says "My Open edX - Studio"
- Footer links to "edX Inc." and "Powered by Open edX"
- No Mereka colors or fonts

**Fix Required**: Apply Mereka theme to CMS configuration

---

## High Priority Issues (P1)

### 3. Footer Logo Broken
**Location**: LMS homepage footer
**Symptom**: Shows "Mereka Academy logo" alt text instead of image

**Root Cause**:
- Template uses `${static.url('images/logo-horizontal.png')}`
- Image may not be deployed to theming assets path
- Or path resolution differs between environments

**Verification Command**:
```bash
curl -sI https://academyv2.mereka.io/theming/asset/images/logo-horizontal.png
```

### 4. Hero Background Missing
**Location**: LMS homepage hero section
**Symptom**: Gray solid color instead of branded background

**Expected**: Gradient or branded imagery
**Actual**: Plain gray (#808080 approximately)

---

## Medium Priority Issues (P2)

### 5. Course Cards Missing Thumbnails
**Location**: /courses page
**Symptom**: Blank gray area where course cards should show images/thumbnails

### 6. Font Loading Not Verified
**Expected Fonts**: Lato, Poppins
**Status**: Theme files exist but visual confirmation needed

---

## Working Elements ✅

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

## Screenshots Captured

| Screenshot | Location | Description |
|------------|----------|-------------|
| /tmp/lms-homepage.png | LMS | Header with Mereka logo, gray hero |
| /tmp/lms-footer2.png | LMS | Full page with footer issues |
| /tmp/studio-homepage.png | Studio | Generic Open edX branding |
| /tmp/mfe-login.png | MFE | Error page with "Try again" |
| /tmp/courses.png | LMS | Courses page, empty cards |

---

## Recommended Fix Order

1. **MFE API Routing** (P0) - Fix environment config for MFE builds
2. **Studio Theme** (P0) - Apply Mereka theme to CMS
3. **Footer Logo** (P1) - Verify/fix static file path
4. **Hero Background** (P1) - Add CSS or image
5. **Course Thumbnails** (P2) - May require course content update

---

## Verification Commands

```bash
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

1. [ ] Fix MFE API routing configuration
2. [ ] Apply theme to Studio (CMS)
3. [ ] Debug and fix footer logo path
4. [ ] Add hero section background styling
5. [ ] Rebuild MFE images with correct config
6. [ ] Redeploy and verify all components
