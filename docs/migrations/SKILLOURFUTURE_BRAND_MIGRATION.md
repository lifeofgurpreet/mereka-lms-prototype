# SkillOurFuture Brand Migration Guide

_Bead: mereka-lms-115d.26 | Last updated: 2026-02-18_

This guide covers the step-by-step process for importing the SkillOurFuture brand profile into the Mereka LMS multi-tenant brand platform. It maps existing branding assets to the `brand-config-schema.json` fields and provides a validation checklist.

---

## Background

SkillOurFuture (`skillourfuture`) is currently provisioned as a tenant domain at `skillourfuture.academy.mereka.io`. Its `TenantConfig.branding_config` is currently `{}`, which means it inherits all branding from the platform-default `mereka` tenant.

The migration promotes SkillOurFuture to a fully-specified brand profile with its own:
- Logo assets
- Colour palette
- Footer variant
- Legal document URLs
- Typography (if distinct from Mereka)

---

## Step 0: Prerequisites

Before starting, confirm:

```bash
# 1. Tenant config exists
kubectl exec -n mereka-lms deploy/lms -- \
  python manage.py shell -c \
  "from mereka_tenancy.models import TenantConfig; print(TenantConfig.objects.get(slug='skillourfuture'))"

# 2. Schema validator is available
bash -n scripts/tenants/validate-tenant-brand-pack.sh

# 3. You have write access to the brand asset CDN / theme directory
ls infrastructure/tutor/themes/mereka/common/static/images/
```

---

## Step 1: Collect Brand Assets

Obtain the following assets from the SkillOurFuture design brief or brand kit:

| Asset | Format | Min Size | Target Filename |
|-------|--------|----------|-----------------|
| Primary logo (colour) | PNG or SVG | 400 × 120 px | `sof-logo-primary.png` |
| White / reversed logo | PNG or SVG | 400 × 120 px | `sof-logo-white.png` |
| Favicon | ICO or PNG | 64 × 64 px | `sof-favicon.ico` |
| Footer logo | PNG or SVG | 200 × 60 px | `sof-logo-footer.png` |

Place assets in:

```
assets/branding/tenants/skillourfuture/
├── sof-logo-primary.png
├── sof-logo-white.png
├── sof-favicon.ico
└── sof-logo-footer.png
```

Copy to theme static directory (served by LMS):

```bash
cp assets/branding/tenants/skillourfuture/* \
  infrastructure/tutor/themes/mereka/common/static/images/
```

---

## Step 2: Gather Colour Palette

From the brand kit, record the hex values for:

| Token | Description | Source in Brand Kit |
|-------|-------------|---------------------|
| `palette.primary` | Primary CTA colour | "Primary Brand Colour" |
| `palette.secondary` | Secondary / hover | "Secondary Colour" |
| `palette.accent` | Highlight / badge | "Accent Colour" |
| `palette.background` | Page background | Usually `#ffffff` |
| `palette.text` | Body text | Usually `#1a1a1a` or `#333333` |

Run contrast check before proceeding:

```bash
# Check palette.text against palette.background meets WCAG AA (4.5:1 for normal text)
python3 -c "
def relative_luminance(hex_color):
    hex_color = hex_color.lstrip('#')
    r, g, b = (int(hex_color[i:i+2], 16) / 255.0 for i in (0, 2, 4))
    def lin(c):
        return c / 12.92 if c <= 0.03928 else ((c + 0.055) / 1.055) ** 2.4
    return 0.2126 * lin(r) + 0.7152 * lin(g) + 0.0722 * lin(b)

text_lum = relative_luminance('#1a1a1a')
bg_lum = relative_luminance('#ffffff')
contrast = (max(text_lum, bg_lum) + 0.05) / (min(text_lum, bg_lum) + 0.05)
print(f'Contrast ratio: {contrast:.2f}:1')
print('PASS' if contrast >= 4.5 else 'FAIL — must be >= 4.5:1 for WCAG AA')
"
```

---

## Step 3: Determine Footer Variant

SkillOurFuture uses a dedicated footer variant (`skillourfuture`) to display:
- The SkillOurFuture logo (not Mereka logo)
- SkillOurFuture copyright text
- SkillOurFuture WhatsApp support number
- SkillOurFuture legal links

Confirm the variant name is registered in `infrastructure/tutor/plugins/mereka_lms.py` under `SITE_VARIANTS`:

```bash
grep -A5 "skillourfuture.academy.mereka.io" \
  infrastructure/tutor/plugins/mereka_lms.py
```

---

## Step 4: Create the Brand Profile JSON

Create the file:

```
scripts/tenants/brand-pack-template.json
```

Use this template (fill in actual values from steps 1–3):

```json
{
  "tenant_id": "skillourfuture",
  "display_name": "Skill Our Future Academy",
  "logos": {
    "primary": "https://skillourfuture.academy.mereka.io/theming/asset/mereka/images/sof/sof-logo-primary.png",
    "white": "https://skillourfuture.academy.mereka.io/theming/asset/mereka/images/sof/sof-logo-white.png",
    "favicon": "https://skillourfuture.academy.mereka.io/theming/asset/mereka/images/sof/sof-favicon.ico",
    "footer": "https://skillourfuture.academy.mereka.io/theming/asset/mereka/images/sof/sof-logo-footer.png"
  },
  "palette": {
    "primary": "#REPLACE_WITH_PRIMARY_HEX",
    "secondary": "#REPLACE_WITH_SECONDARY_HEX",
    "accent": "#REPLACE_WITH_ACCENT_HEX",
    "background": "#ffffff",
    "text": "#1a1a1a"
  },
  "typography": {
    "font_family": "\"Nunito\", sans-serif",
    "heading_font": "\"Nunito\", sans-serif",
    "font_source_url": "https://fonts.googleapis.com/css2?family=Nunito:wght@400;600;700&display=swap"
  },
  "footer": {
    "variant": "skillourfuture",
    "copyright_holder": "Skill Our Future Sdn. Bhd.",
    "whatsapp": "+60XXXXXXXXX",
    "legal_links": [
      {
        "label": "Terms of Use",
        "url": "https://skillourfuture.academy.mereka.io/terms"
      },
      {
        "label": "Privacy Policy",
        "url": "https://skillourfuture.academy.mereka.io/privacy"
      }
    ],
    "social_links": [
      {
        "platform": "linkedin",
        "url": "https://linkedin.com/company/REPLACE_WITH_ORG_SLUG"
      }
    ]
  },
  "legal_doc_urls": {
    "terms": "https://skillourfuture.academy.mereka.io/terms",
    "privacy": "https://skillourfuture.academy.mereka.io/privacy"
  },
  "_meta": {
    "schema_version": "1.0",
    "approved_by": "REPLACE_WITH_GITHUB_USERNAME",
    "approved_at": "REPLACE_WITH_ISO8601_DATETIME",
    "source_pr": "REPLACE_WITH_PR_URL"
  }
}
```

---

## Step 5: Validate the Brand Profile

```bash
# Validate against JSON Schema
scripts/tenants/validate-tenant-brand-pack.sh skillourfuture

# Run full offline contract verification
./scripts/qa/verify-multitenant-brand-platform.sh

# Check contrast compliance
./scripts/qa/verify-contrast-compliance.sh
```

All checks must return `PASS` or `WARN` (no `FAIL`) before proceeding.

---

## Step 6: Open a Pull Request

Open a PR with:
- **Title**: must contain `tenant` and `branding` (triggers all tenant brand gates in CI)
- **Files**: `scripts/tenants/brand-pack-template.json`, logo assets, any `mereka_lms.py` footer variant updates
- **Reviewer**: at least one member of `@Biji-Biji-Initiative/platform`

Required CI gates that must pass:
- `tenant-branding-contract`
- `footer-variant-matrix`
- `contrast-compliance`
- `monitoring-guardrails` (syntax check)
- `multitenant-brand-platform`

---

## Step 7: Apply to Production

After PR merge:

```bash
# Apply brand profile update (requires kubectl access to mereka-lms namespace)
scripts/tenants/provision-tenant.sh --update-brand skillourfuture

# Verify the brand profile is live
kubectl exec -n mereka-lms deploy/lms -- \
  python manage.py shell -c "
from mereka_tenancy.models import TenantConfig
tc = TenantConfig.objects.get(slug='skillourfuture')
import json
print(json.dumps(tc.branding_config, indent=2))
"
```

---

## Step 8: Smoke Test and Screenshot

```bash
# Capture branded screenshots for all SkillOurFuture smoke paths
./scripts/qa/capture-branding-screenshots.sh --tenant skillourfuture

# Manual smoke paths (verify in browser):
# https://skillourfuture.academy.mereka.io/
# https://apps.skillourfuture.academy.mereka.io/authn/login
# https://apps.skillourfuture.academy.mereka.io/learner-dashboard/
# https://studio.academyv2.mereka.io/home  (shared Studio)
```

Store screenshots in `var/branding-screenshots/skillourfuture/` as release evidence.

---

## Validation Checklist

Complete before marking the migration as done:

- [ ] Brand assets uploaded to `assets/branding/tenants/skillourfuture/`
- [ ] Assets copied to `infrastructure/tutor/themes/mereka/common/static/images/`
- [ ] `skillourfuture-brand.json` created and `_meta` block filled in
- [ ] `validate-tenant-brand-pack.sh skillourfuture` passes
- [ ] Contrast ratio for `palette.text` / `palette.background` >= 4.5:1 (WCAG AA)
- [ ] CI gates pass on PR (contract, footer, contrast, monitoring-guardrails)
- [ ] PR approved by Platform Engineering member
- [ ] `provision-tenant.sh --update-brand skillourfuture` applied to production
- [ ] `TenantConfig.branding_config` verified non-empty in live cluster
- [ ] Smoke screenshots captured and stored in `var/branding-screenshots/skillourfuture/`
- [ ] Logo URL resolves with HTTP 200: `curl -I https://skillourfuture.academy.mereka.io/theming/asset/mereka/images/sof/sof-logo-primary.png`
- [ ] MFE footer renders SkillOurFuture copyright text (not "Mereka (M) Sdn. Bhd.")
- [ ] Page title shows "Skill Our Future Academy" (not "Mereka Academy")
- [ ] Entry added to `docs/operations/DOMAIN_MANAGEMENT.md` under "Tenant Brand Profiles"

---

## Field Mapping: Existing Assets → Schema

If SkillOurFuture has existing web assets (website, Kajabi, or MCT), use this mapping to locate the correct source:

| Schema Field | Where to Find in Existing Assets |
|--------------|----------------------------------|
| `display_name` | Page `<title>` tag on existing site |
| `logos.primary` | Site header logo (`<img>` in `<header>`) |
| `logos.favicon` | `<link rel="shortcut icon">` in `<head>` |
| `palette.primary` | CSS of primary CTA buttons (`background-color`) |
| `palette.text` | CSS body text colour (`color` on `body`) |
| `footer.copyright_holder` | Footer copyright notice `©` text |
| `footer.whatsapp` | Contact page or footer WhatsApp link |
| `legal_doc_urls.terms` | Footer "Terms" link |
| `legal_doc_urls.privacy` | Footer "Privacy" link |

---

## Rollback

If the brand profile causes rendering issues:

```bash
# Revert to empty config (falls back to platform defaults)
kubectl exec -n mereka-lms deploy/lms -- \
  python manage.py shell -c "
from mereka_tenancy.models import TenantConfig
tc = TenantConfig.objects.get(slug='skillourfuture')
tc.branding_config = {}
tc.save()
print('Reverted to platform defaults')
"

# Restart MFE to clear config cache
kubectl rollout restart deployment/mfe -n mereka-lms
```
