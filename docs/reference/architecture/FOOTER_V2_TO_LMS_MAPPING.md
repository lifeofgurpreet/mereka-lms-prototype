# Footer v2 → LMS Mapping

_Audience: Frontend Engineering • Last updated: 2026-02-17_

## Purpose

Maps the Angular v2 footer design to Open edX MFE React implementation via the FPF plugin-slot system.

## Architecture

The `MerekaFooter` React component is injected into all MFEs via the `footer_slot` plugin-slot:

| Path | Role | Priority |
|------|------|----------|
| `infrastructure/tutor/plugins/mereka_lms_mfe_slots.py` | Primary and ONLY definition; registered to slot `org.openedx.frontend.layout.footer.v1` via `PLUGIN_OPERATIONS.Replace` | 1 (Tutor plugin) |

Single source of truth. The prior `apply-patches.sh` fallback JSX
duplicate has been removed; `verify-footer-parity.sh` now asserts the
plugin slot registration directly.

## Zone Mapping

| Zone | Angular Class | React Class | Content |
|------|--------------|-------------|---------|
| 1. Social Row | `border-b border-white/10` (top section) | `.footer-social` | Logo + 5 social icons |
| 2. Nav Strip | `border-b border-white/10` (nav section) | `.footer-nav` | 8 nav links + WhatsApp CTA |
| 3. Column Body | `border-b border-white/10` (main grid) | `.footer-body` | 4 columns: Corporate, Marketplace, Academy, Space |
| 4. Legal Bottom | bottom section | `.footer-legal` | Copyright + 3 legal links |

## Per-Site Variant Mapping (AC-FOOTER-203)

The footer adapts branding per hostname:

| Hostname | Brand Name | Copyright Holder |
|----------|-----------|-----------------|
| `academyv2.mereka.io` | Mereka Academy | MEREKA |
| `academy.biji-biji.com` | Biji-Biji Academy | Biji-Biji Initiative |
| `skillourfuture.academy.mereka.io` | Skill Our Future Academy | MEREKA |

Implemented via `SITE_VARIANTS[window.location.hostname]` with fallback to config `SITE_NAME`.

## App Store Badges (AC-FOOTER-204)

App store links use styled text badges (no external hotlinks):
- Apple App Store: `https://apps.apple.com/id/app/mereka-hubs/id6473277964`
- Google Play: `https://play.google.com/store/apps/details?id=io.mereka.hubs`

## WCAG AA Compliance (AC-FOOTER-205)

| Pair | Foreground | Background | Ratio | Pass? |
|------|-----------|------------|-------|-------|
| Body text | #FFFFFF | #1A1623 | 17.3:1 | Yes (AA requires 4.5:1) |
| Muted text | rgba(255,255,255,0.8) | #1A1623 | 13.2:1 | Yes |
| Legal text | rgba(255,255,255,0.6) | #1A1623 | 9.5:1 | Yes |
| Sub-headings | rgba(255,255,255,0.5) | #1A1623 | 7.6:1 | Yes |

## Editing Workflow (AC-FOOTER-207)

To update footer content:

1. Edit the `MerekaFooter` JSX in
   `infrastructure/tutor/plugins/mereka_lms_mfe_slots.py` — the footer
   is registered to `org.openedx.frontend.layout.footer.v1` via
   `PLUGIN_OPERATIONS.Replace`. This is the single source of truth.
2. Run verification: `./scripts/qa/verify-footer-parity.sh`
3. For local parity, rebuild MFE with `tutor images build mfe`
4. For shared environments, publish via
   `.github/workflows/build-tutor-images.yml` and promote with
   `./scripts/infra/release-openedx-gitops.sh --require-digests`

**Single-source JSX.** A prior workflow required duplicating the JSX
into `infrastructure/tutor/apply-patches.sh` as a fallback; that
duplication is removed. The `sync-footer-assets.sh` script (renamed
from `footer-component.sh` for clarity) now only copies SCSS/font
assets into the MFE build tree — it no longer writes JSX.

## Related Files

- **SCSS**: `infrastructure/tutor/themes/mereka/scss/theme.scss` (`.mereka-footer--v2` styles)
- **Verifier**: `scripts/qa/verify-mfe-footer-slot.sh`
- **Angular Source**: `projects/mereka/ui/src/lib/components/footer/` (design reference)
- **Plugin-Slot Inventory**: `docs/reference/architecture/MFE_PLUGIN_SLOT_INVENTORY.md`
