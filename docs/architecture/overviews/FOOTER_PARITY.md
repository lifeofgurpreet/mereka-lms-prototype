# Footer Parity Architecture

**Status**: Implemented (dual-path, migration in progress)
**Created**: 2026-02-24
**Related**:
- [FOOTER_SLOT_MIGRATION.md](./FOOTER_SLOT_MIGRATION.md) — migration lifecycle from dual-path to single-source
- [ADR-014: MFE Branding Strategy](../../adr/014-mfe-branding-strategy.md)
- [branding-system_spec.md](../../../specs/branding-system_spec.md)
**Verification**: `scripts/qa/verify-footer-parity.sh`

---

## Overview

The Mereka v2 footer (5-zone dark footer with social icons, nav strip, 4-column body, and legal bottom) is injected into the Open edX LMS and all React MFEs. It replaces the upstream Indigo/Open edX default footer across all learner-facing surfaces.

This document describes **what surfaces have the footer**, **how it is injected on each surface**, and **how to update footer content**.

---

## Surfaces with the Mereka Footer

| Surface | Mechanism | Status |
|---------|-----------|--------|
| **LMS** (learner pages, course views) | Django Mako template override | Implemented |
| **MFE: authn** (login/registration) | React component via env.config.jsx | Implemented |
| **MFE: account** (user account settings) | React component via env.config.jsx | Implemented |
| **MFE: profile** (user profile) | React component via env.config.jsx | Implemented |
| **MFE: learning** (courseware) | React component via env.config.jsx | Implemented |
| **MFE: discussions** | React component via env.config.jsx | Implemented |
| **Studio (CMS)** | Django Mako template override (widgets/footer.html) | Implemented |
| **Enterprise admin portal** | Default Open edX footer (no MerekaFooter wiring) | Gap — see below |
| **Enterprise learner portal** | Default Open edX footer (no MerekaFooter wiring) | Gap — see below |

### Known Gap: Enterprise MFE Portals

The enterprise admin and learner portals (`deploy/k8s/base/apps/enterprise/mfe/`) are deployed as separate Docker images that are not built via Tutor's MFE image pipeline. They do not receive the `env.config.jsx` patch that injects `MerekaFooter`. These portals currently render the Open edX default footer.

**Priority**: P4 backlog. Enterprise portals are accessed by B2B clients; white-labeling is tracked separately from the standard learner footer parity work.

---

## Injection Mechanisms

### LMS (Mako Template)

**Path**: `infrastructure/tutor/themes/mereka/lms/templates/footer.html`

The Mereka comprehensive theme overrides the upstream `footer.html` Mako template. Open edX's template loading resolves theme overrides before the platform defaults, so this file is always used when `DEFAULT_SITE_THEME = "mereka"` is active.

The LMS footer is a multi-column Django-rendered template. It uses:
- `configuration_helpers.get_value()` to read `SUPPORT_EMAIL`, `HELP_CENTER_URL`, and `PRIVACY_POLICY_URL` from SiteConfiguration, enabling per-domain customization.
- `static.get_platform_name()` for the dynamic copyright holder (multi-site safe).
- `datetime.now().year` for the copyright year.

**When to rebuild**: LMS footer changes require `tutor images build openedx` + `tutor k8s restart lms` + `collectstatic`. The Mako template is baked into the Docker image.

### Studio (CMS — Mako Template)

**Path**: `infrastructure/tutor/themes/mereka/cms/templates/widgets/footer.html`

Studio renders `widgets/footer.html` (not `footer.html`). The theme override lives at this path. Without this override, Studio shows the upstream Open edX footer including the "Powered by Open edX" badge.

**When to rebuild**: Same as LMS above.

### MFEs (React Component via env.config.jsx)

**Canonical source**: `infrastructure/tutor/plugins/mereka_lms.py`

The `MerekaFooter` React component is defined inline in the Tutor plugin's `mfe-env-config` hook. The component is injected into `env.config.jsx` at MFE Docker image build time. All MFEs built via `tutor images build mfe` receive the footer.

The injection uses two redundant paths (defense-in-depth):

#### Path 1: Tutor Plugin (canonical)

`mereka_lms.py` registers a `mfe-env-config` hook that injects the full `MerekaFooter` component into `env.config.jsx`. When `tutormfe.hooks.PLUGIN_SLOTS` becomes available in a future Tutor version, the plugin also registers a `footer_slot` entry that wires `MerekaFooter` through the Frontend Plugin Framework slot system.

#### Path 2: apply-patches.sh (fallback)

`infrastructure/tutor/patches/footer-component.sh` contains a copy of the `MerekaFooter` component. `apply-patches.sh` applies this as a string-surgery fallback on the rendered `env.config.jsx` files in `tutor_env/`. If the plugin path succeeds, this fallback is a no-op (idempotent patch). See [FOOTER_SLOT_MIGRATION.md](./FOOTER_SLOT_MIGRATION.md) for the planned removal timeline.

**When to rebuild**: MFE footer changes require `tutor images build mfe` + `tutor k8s restart mfe`. No collectstatic needed.

---

## Footer Component Architecture (MFE)

The `MerekaFooter` React component (`const MerekaFooter = () => { ... }`) is structured into 4 zones:

| Zone | Content |
|------|---------|
| Zone 1: Social Row | Logo, brand name, 5 social icons (TikTok, Instagram, Facebook, LinkedIn, YouTube) |
| Zone 2: Nav Strip | 8 nav links (About, Andragogy, Portfolio, Team, Careers, Ecosystem, Blog, Help Centre) + WhatsApp CTA |
| Zone 3: 4-Column Body | Corporate, Marketplace (Users + Business + App badges), Academy, Space link columns |
| Zone 4: Legal Bottom | Copyright year + holder, Terms of Use, Privacy Policy, Cookies Policy |

### Multi-site Variants

The component reads `window.location.hostname` at runtime and selects from `SITE_VARIANTS`:

| Domain | Brand | Copyright Holder |
|--------|-------|-----------------|
| `academyv2.mereka.io` | Mereka Academy | MEREKA |
| `academy.biji-biji.com` | Biji-Biji Academy | Biji-Biji Initiative |
| `skillourfuture.academy.mereka.io` | Skill Our Future Academy | MEREKA |
| (fallback) | `config.SITE_NAME` | MEREKA |

---

## Updating Footer Content

### Updating Links or Text in the MFE Footer

1. Edit the `MerekaFooter` component in **both** canonical locations (keep them in sync until the dual-path is retired):
   - `infrastructure/tutor/plugins/mereka_lms.py` (search for `const MerekaFooter = () => {`)
   - `infrastructure/tutor/patches/footer-component.sh` (search for the same)
2. Rebuild the MFE image:
   ```bash
   export TUTOR_ROOT="$(pwd)/tutor_env"
   tutor images build mfe
   tutor k8s restart mfe
   ```
3. Verify with `scripts/qa/verify-footer-parity.sh`.

### Updating Links or Text in the LMS/Studio Footer

1. Edit `infrastructure/tutor/themes/mereka/lms/templates/footer.html`
2. For Studio, edit `infrastructure/tutor/themes/mereka/cms/templates/widgets/footer.html`
3. Rebuild:
   ```bash
   export TUTOR_ROOT="$(pwd)/tutor_env"
   tutor images build openedx
   tutor k8s restart lms cms
   tutor k8s exec lms ./manage.py lms collectstatic --noinput
   tutor k8s exec cms ./manage.py cms collectstatic --noinput
   ```

### Adding a New Multi-site Variant

1. Add the domain to `SITE_VARIANTS` in **both** plugin and patch module.
2. Add the domain to the `LIVE_DOMAINS` array in `scripts/qa/verify-footer-parity.sh`.
3. Ensure the domain is also in `MEREKA_LMS_EXTRA_HOSTS` / `MEREKA_LMS_EXTRA_CSRF_ORIGINS` in the Tutor plugin config.
4. Rebuild and verify.

### Updating Legal Link URLs

Legal links (`legal.mereka.io`) are hardcoded in the MFE component. If the legal domain changes:
1. Update `TERMS OF USE`, `PRIVACY POLICY`, and `COOKIES POLICY` hrefs in both plugin and patch module.
2. Update the URL checks in `scripts/qa/verify-footer-parity.sh`.
3. Rebuild MFE.

---

## Gap Analysis: Implemented vs Still Needed

| Item | Status | Notes |
|------|--------|-------|
| LMS footer template (Mako) | Implemented | `lms/templates/footer.html` |
| Studio footer template (Mako) | Implemented (needs CMS widget path) | Must be at `cms/templates/widgets/footer.html` |
| MFE footer component (React) | Implemented | Via dual-path (plugin + apply-patches.sh) |
| Multi-site SITE_VARIANTS (3 domains) | Implemented | academyv2, biji-biji, skillourfuture |
| Self-hosted fonts (no Google Fonts) | Implemented | Poppins + Lato in `mfe/fonts/` |
| Responsive CSS (media queries) | Implemented | Via `mereka.scss` and imported SCSS files |
| Footer slot migration (FPF) | In progress | Waiting for `tutormfe.hooks.PLUGIN_SLOTS` |
| Enterprise portal footer | Not implemented | P4 backlog — enterprise portals use default footer |
| Tenant-override footer content | Partial | `configuration_helpers` used in LMS; MFE runtime-reads hostname |
| Per-tenant privacy/terms URLs | Partial | LMS reads from SiteConfiguration; MFE has hardcoded legal.mereka.io |
| Footer WCAG 2.1 AA contrast audit | Not verified | Manual review needed for dark footer color combinations |

---

## Verification

Run the footer parity check to confirm all surfaces and assets are in place:

```bash
# Offline (file-level checks, no network):
./scripts/qa/verify-footer-parity.sh

# Online (live URL checks against production):
./scripts/qa/verify-footer-parity.sh --online --lms-url https://academyv2.mereka.io

# Full live domain sweep:
./scripts/qa/verify-footer-parity.sh --live
```

Expected output on a healthy repository: all file-level checks PASS, rendered-file checks SKIP (if `tutor_env/` not present), online checks require network access to production.

---

## Related Files

| File | Role |
|------|------|
| `infrastructure/tutor/plugins/mereka_lms.py` | Canonical MerekaFooter component + PLUGIN_SLOTS registration |
| `infrastructure/tutor/patches/footer-component.sh` | Fallback patch for env.config.jsx (apply-patches.sh) |
| `infrastructure/tutor/themes/mereka/lms/templates/footer.html` | LMS Mako footer template |
| `infrastructure/tutor/themes/mereka/cms/templates/widgets/footer.html` | Studio Mako footer widget |
| `infrastructure/tutor/themes/mereka/mfe/mereka.scss` | MFE theme SCSS (includes footer styles) |
| `infrastructure/tutor/themes/mereka/mfe/fonts/` | Self-hosted font files for MFEs |
| `scripts/qa/verify-footer-parity.sh` | Footer parity verification script |
| `docs/runbooks/architecture/FOOTER_SLOT_MIGRATION.md` | Migration lifecycle (dual-path → single-source) |
| `specs/branding-system_spec.md` | Acceptance criteria (AC-003, AC-007, AC-008) |
