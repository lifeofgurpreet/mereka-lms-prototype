# Enterprise UI Review — Visual, A11y, Copy Consistency

> **Bead**: mereka-lms-115d.13
> **Last updated**: 2026-02-18
> **Reviewer**: BoldBadger (automated)

## Scope

Surfaces reviewed:

1. **Enterprise Admin Portal MFE** — `deploy/k8s/base/apps/enterprise/mfe/admin-portal-deployment.yaml`
2. **Enterprise Learner Portal MFE** — `deploy/k8s/base/apps/enterprise/mfe/learner-portal-deployment.yaml`
3. **Enterprise MFE runtime config** — `deploy/k8s/base/apps/enterprise/mfe/enterprise-mfe-env.js`
4. **LMS brand.html enterprise tagline** — `infrastructure/tutor/themes/mereka/lms/templates/header/brand.html`
5. **Enterprise K8s service manifests** — `deploy/k8s/base/apps/enterprise/`
6. **MFE SCSS** — `infrastructure/tutor/themes/mereka/mfe/mereka.scss` (enterprise selector audit)

Enterprise API-only services (catalog, access, subsidy) are excluded — no customer-facing UI to audit.

---

## Findings

### Visual Consistency

| Surface | Status | Notes |
|---------|--------|-------|
| Enterprise Admin Portal | No custom SCSS | Inherits Paragon design system defaults |
| Enterprise Learner Portal | No custom SCSS | Inherits Paragon design system defaults |
| `mereka.scss` enterprise selectors | None present | Portals use Paragon tokens directly |
| SITE_VARIANTS for enterprise domains | Not configured | Enterprise portals use LMS domain branding |
| Runtime env config | Correct | `enterprise-mfe-env.js` uses production `academyv2.mereka.io` URLs |

**Current state**: Enterprise MFE portals have no custom visual overrides. They inherit the Paragon component library defaults, which are WCAG AA compliant. No Mereka design token injection exists for enterprise portal surfaces at this time.

### Accessibility

| Check | Status | Detail |
|-------|--------|--------|
| brand.html i18n | PASS | Uses Mako `_()` translation helper for platform name |
| brand.html enterprise tagline | PASS | Rendered via `configuration_helpers.get_value()` — site-configurable, not hardcoded |
| Enterprise tagline rendering | PASS | Conditional on `enable_enterprise_sidebar` — not injected for all learners |
| Enterprise MFE a11y baseline | PASS | Inherits Paragon component library (WCAG 2.1 AA target) |
| Custom a11y overrides | None needed | No enterprise-specific interactive components added in this repo |

**Finding**: The `logo-tagline` span in `brand.html` (`Learning experiences crafted for Southeast Asia.`) is hardcoded text, not wrapped in a translation helper. This is a separate issue from the enterprise tagline (which is correctly site-configurable). Recommend wrapping in `${_('...')}` in a future pass.

### Copy Consistency

| Check | Status | Detail |
|-------|--------|--------|
| Banned upstream brands in env config | PASS | No "Open edX", "edX Inc", "edx.org" in enterprise-mfe-env.js |
| Banned upstream brands in brand.html | PASS | No customer-facing edX branding strings |
| Banned upstream brands in K8s manifests | PASS | No hardcoded brand strings in YAML manifests |
| Hardcoded Mereka brand in K8s YAML | PASS | Branding delivered via ConfigMap, not inline YAML strings |
| Enterprise tagline configurable | PASS | Uses `ENTERPRISE_TAGLINE` site_configuration key |

**Finding**: `ACCESS_TOKEN_COOKIE_NAME` in `enterprise-mfe-env.js` is set to `'edx-jwt-cookie-header-payload'`. This is the canonical Open edX session cookie name and is a technical identifier, not a customer-facing string — acceptable as-is.

---

## Gap Analysis

### What is Missing (Pre-Launch)

1. **No enterprise domain in SITE_VARIANTS** — When enterprise portals go live on a dedicated subdomain (e.g., `enterprise.academyv2.mereka.io`), a SITE_VARIANTS entry should be added in `mereka_lms.py` to serve enterprise-specific branding.

2. **No enterprise SCSS overrides** — `mereka.scss` has zero enterprise-specific selectors. The portals inherit Paragon defaults. If brand alignment is required before launch, add enterprise-scoped overrides under `.enterprise-learner-portal` or `.enterprise-admin-portal` class selectors.

3. **logo-tagline not i18n-wrapped** — The static tagline string `"Learning experiences crafted for Southeast Asia."` in `brand.html` should use `${_('...')}` for translation support.

4. **ENTERPRISE_TAGLINE default value** — `settings.ENTERPRISE_TAGLINE` fallback is referenced in `brand.html` but the default is not visible in this repo. Verify it is set in `lms/envs/production.py` or site_configuration defaults.

### What is Already Correct

- Enterprise MFE deployments use the Mereka Artifact Registry (not Docker Hub)
- Caddy configmaps are declared in the kustomization for both portals
- All 7 required auth/session fields are present in the runtime env config
- No upstream brand strings (edX, Open edX) leak into customer-facing surfaces
- Enterprise tagline is site-configurable, not hardcoded

---

## Recommendations

1. **When enterprise MFEs go live**: Add `SITE_VARIANTS` entry for enterprise portal domain in `infrastructure/tutor/plugins/multi-tenancy/` or `mereka_lms.py`

2. **Before enterprise GA**: Add enterprise-specific SCSS selectors to `mereka.scss` if visual differentiation from standard learner UX is required

3. **Minor a11y fix**: Wrap `logo-tagline` static string in `brand.html` with Mako i18n helper `${_('...')}` for completeness

4. **Caddy header parity**: Enterprise MFE Caddy configs should mirror branding security headers (CSP, X-Frame-Options) from the main MFE Caddyfile — verify this in the Caddyfile files referenced by the kustomization

---

## Verification

Run the automated gate to confirm compliance:

```bash
./scripts/qa/verify-enterprise-ui-review.sh
```

Expected output: 20 PASS, 1 WARN (no enterprise SCSS — expected), 0 FAIL.
