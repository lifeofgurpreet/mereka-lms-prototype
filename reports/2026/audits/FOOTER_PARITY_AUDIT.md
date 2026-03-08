# Footer Parity Audit — Cross-Surface Consistency

> **Bead**: mereka-lms-115d.14
> **Last updated**: 2026-02-18

## Surfaces Audited

| # | Surface | Footer Source | Branded | Per-Domain | Notes |
|---|---------|---------------|---------|------------|-------|
| 1 | MFE (all) | `MerekaFooter` via `footer.v1` slot | YES | YES — `SITE_VARIANTS` | React component inline in `mfe-env-config` patch |
| 2 | LMS pages | Mako template `lms/templates/footer.html` | PARTIAL | NO | Hard-coded "Biji-Biji Initiative" in copyright; "Powered by Open edX" present |
| 3 | Studio/CMS | No custom Mako footer template | N/A | N/A | Falls back to Open edX default footer; no Mereka theme override |
| 4 | Enterprise Admin Portal | Inherits standard MFE runtime env (`enterprise-mfe-env` ConfigMap) | PARTIAL | NO | No `MerekaFooter` wired; uses Open edX default footer component |
| 5 | Enterprise Learner Portal | Same as Admin Portal | PARTIAL | NO | Same as Admin Portal |

## MFE Footer (Canonical)

- **Component**: `MerekaFooter` defined inline inside `mfe-env-config` patch in
  `infrastructure/tutor/plugins/mereka_lms.py`
- **Slot**: `org.openedx.frontend.layout.footer.v1` (registered via `tutormfe.hooks.PLUGIN_SLOTS`
  when available; fallback via `apply-patches.sh` `RenderWidget` string replacement)
- **Per-domain**: `SITE_VARIANTS` map keyed by `window.location.hostname`
  - `academyv2.mereka.io` → brand: "Mereka Academy", copyrightHolder: "MEREKA", whatsapp: "601135271981"
  - `academy.biji-biji.com` → brand: "Biji-Biji Academy", copyrightHolder: "Biji-Biji Initiative", whatsapp: "601135271981"
  - `skillourfuture.academy.mereka.io` → brand: "Skill Our Future Academy", copyrightHolder: "MEREKA", whatsapp: "601135271981"
  - Fallback → `config.SITE_NAME` / `config.PLATFORM_NAME`
- **Fields rendered**: brand name, logo, social icons, nav links, WhatsApp CTA, 4-column body,
  copyright + legal links
- **"Powered by Open edX"**: NOT present — fully replaced by Mereka branding

## LMS Mako Footer

- **Template path**: `infrastructure/tutor/themes/mereka/lms/templates/footer.html`
- **Mereka branding**: YES — `mereka-footer` CSS class, Mereka logo, Mereka copy ("Mereka Academy
  blends community...")
- **Copyright holder**: Hard-coded `© ${datetime.now().year} Biji-Biji Initiative · ${static.get_platform_name()}` — does NOT adapt per domain; always shows "Biji-Biji Initiative" regardless of hostname
- **WhatsApp**: NOT present
- **"Powered by Open edX and Tutor"**: PRESENT (line 73) — parity gap vs MFE footer

## Studio/CMS Footer

- **Template path**: `infrastructure/tutor/themes/mereka/cms/templates/footer.html` — **DOES NOT EXIST**
- Only `head-extra.html` is present in the CMS templates directory
- Studio falls back to the Open edX default footer (no Mereka branding)
- Studio is a single-domain internal tool; this is acceptable for the current release

## Enterprise MFE Footers

- **Config file**: `deploy/k8s/base/apps/enterprise/mfe/enterprise-mfe-env.js`
- **Footer wiring**: The enterprise ConfigMap defines `LMS_BASE_URL`, auth endpoints, and feature
  flags but does NOT inject a custom footer component or reference `MerekaFooter`
- Enterprise MFEs (admin-portal, learner-portal) are separate deployments that use the standard
  Open edX `@edx/frontend-component-footer` unless explicitly overridden
- No `env.config.jsx` / plugin-slot wiring found in the enterprise MFE manifests

## Parity Gaps

| Gap | Surface | Severity | Detail |
|-----|---------|----------|--------|
| Hard-coded copyright holder | LMS Mako footer | MEDIUM | Always "Biji-Biji Initiative"; MFE varies by domain |
| "Powered by Open edX and Tutor" string | LMS Mako footer | LOW | MFE removes this entirely; Mako footer shows it |
| No WhatsApp CTA | LMS Mako footer | LOW | MFE footer has WhatsApp button; Mako does not |
| No Mereka footer in Studio | CMS | LOW | Studio is internal; not learner-facing |
| No MerekaFooter wiring in enterprise MFEs | Enterprise Admin + Learner Portal | MEDIUM | Enterprise MFEs show Open edX default footer |

## Recommendations

1. **LMS Mako footer — copyright holder**: Replace the hard-coded `Biji-Biji Initiative` with
   `${static.get_platform_name()}` or add a Django setting (`MEREKA_COPYRIGHT_HOLDER`) that can be
   overridden per-site via `SiteConfiguration`. This brings Mako parity with `SITE_VARIANTS`.

2. **LMS Mako footer — "Powered by" string**: Remove or replace line 73 with a co-branded string
   (e.g., "Powered by Open edX — Hosted by Mereka") to match the MFE footer which omits this
   entirely.

3. **LMS Mako footer — WhatsApp**: Add a WhatsApp contact link using a configurable setting
   (`MEREKA_WHATSAPP_NUMBER`) to match the MFE footer's WhatsApp CTA.

4. **Enterprise MFEs — footer override**: Extend `enterprise-mfe-env.js` with a `FOOTER_COMPONENT`
   or equivalent config, or add a `MerekaFooter` plugin-slot override to the enterprise MFE build
   configuration. This requires coordinating with the enterprise MFE build pipeline.

5. **CMS footer**: Low priority (Studio is internal). If Studio becomes learner-accessible, add
   `infrastructure/tutor/themes/mereka/cms/templates/footer.html` mirroring the LMS version.

## Verification

Run `scripts/qa/verify-footer-parity.sh` to check all 5 ACs programmatically.
