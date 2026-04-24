# Complete MFE List & Status
_Last updated: 2026-02-27_

> **Canonical version info**: [MFE_VERSIONS.md](MFE_VERSIONS.md)
> **Related**: [FRONTEND_TRACKER.md](../../archive/superseded/FRONTEND_TRACKER.md), [MFE_FIRST_POLICY.md](../../policies/architecture/MFE_FIRST_POLICY.md)

## Currently Configured MFEs (12)

All these MFEs are built into the `openedx-mfe` Docker image and routed via Caddy:

| # | MFE | Route | Purpose | Branding Status |
|---|-----|-------|---------|-----------------|
| 1 | **authn** | `/authn/login` | Login, registration, password reset | SCSS overrides applied |
| 2 | **account** | `/account` | Account settings, preferences | SCSS overrides applied |
| 3 | **profile** | `/profile` | User profile viewing/editing | SCSS overrides applied |
| 4 | **learning** | `/learning` | Course content viewing, navigation | SCSS overrides applied |
| 5 | **learner-dashboard** | `/learner-dashboard` | Student dashboard, course overview | SCSS overrides applied |
| 6 | **course-authoring** | `/course-authoring` | Course authoring tools (Studio integration) | SCSS overrides applied |
| 7 | **gradebook** | `/gradebook` | Gradebook for instructors | SCSS overrides applied |
| 8 | **discussions** | `/discussions` | Course discussions and forums | SCSS overrides applied |
| 9 | **communications** | `/communications` | Instructor-to-learner messaging | SCSS overrides applied |
| 10 | **orders** | `/orders` | Ecommerce order history | SCSS overrides applied |
| 11 | **payment** | `/payment` | Payment forms and processing | SCSS overrides applied |
| 12 | **ora-grading** | `/ora-grading` | Open Response Assessment grading | SCSS overrides applied |

## Enterprise MFEs (Deployed In App Base, Runtime Truth Split)

These MFEs are represented in the app repo base manifests and workload
inventory. They are not "not deployed"; the stronger truth is:

- `mereka-lms` owns the base deployments, services, and default env config
  package for enterprise portals.
- `bbi-infrastructure` owns the authoritative `dev`, `staging`, and `prod`
  lane realization for non-local overlays.
- Live runtime truth also depends on LMS `/api/mfe_config/v1` behavior and
  `SiteConfiguration.site_values["MFE_CONFIG"]` for site-specific overrides.

Repo-only review can therefore prove that enterprise MFEs are part of the app
package, but it cannot by itself prove lane parity or runtime-valid branding
for `dev`/`staging`/`prod`.

| MFE | Purpose | Depends On | Status |
|-----|---------|-----------|--------|
| **frontend-app-enterprise-public-catalog** | Public course catalog browsing | Enterprise Catalog service | Not deployed |
| **frontend-app-admin-portal** | Enterprise admin dashboard | Enterprise services stack | Base deployment defined; lane/runtime proof split across app repo, infra repo, and live LMS config |
| **frontend-app-learner-portal-enterprise** | Enterprise learner portal | Enterprise services stack | Base deployment defined; lane/runtime proof split across app repo, infra repo, and live LMS config |
| **frontend-app-support-tools** | Support/admin tools | Staff access | Not deployed |

### Enterprise Truth Boundaries

Enterprise admin and learner portals are parity-sensitive deep-route surfaces.
They should not be treated as "just another themed MFE" because their final
runtime behavior depends on multiple truth sources:

1. `deploy/k8s/base/apps/enterprise/mfe/enterprise-mfe-env.js`
   Base defaults owned by `mereka-lms`.
2. `deploy/k8s/overlays/*/enterprise-mfe-env.js`
   Deprecated reference overlays in this repo; authoritative lane overlays live
   in `bbi-infrastructure/apps/mereka-lms/overlays/{dev,staging,prod}/`.
3. `infrastructure/tutor/plugins/_mereka_lms/lms_settings.py`
   LMS global `MFE_CONFIG` defaults returned by `/api/mfe_config/v1`.
4. `SiteConfiguration.site_values["MFE_CONFIG"]`
   Live per-site overrides provisioned at runtime.

Until all four surfaces are consistent, repo-only proof must remain weaker than
`runtime_validated`.

## Other Available MFEs (Upstream)

| MFE | Purpose | Relevant? |
|-----|---------|-----------|
| **frontend-app-library-authoring** | Content library management | Yes — when Content Libraries v2 is enabled |
| **frontend-app-credentials** | Credentials/badges display | Yes — when Badges & Credentials spec is implemented |
| **frontend-app-publisher** | Course discovery publisher | Maybe — depends on Discovery service setup |

## Open edX Release: Ulmo (Tutor v21)

- **Default Node.js**: 24.11.0 (active rendered build contract)
- **Paragon version**: v23+ (supports JSON design tokens)
- **Frontend Plugin Framework**: ~130+ plugin slots available across MFEs
- **PARAGON_THEME_URLS**: Runtime CDN theming supported (not yet enabled)

## Verification

> Boundary note: the commands below check only part of the truth surface unless
> they are paired with authoritative GitOps overlays and live `/api/mfe_config/v1`
> evidence. For non-local lanes, repo-only checks are not sufficient to claim
> `dev`/`staging` parity.

**Check available MFEs:**
```bash
# Local
tutor local exec mfe sh -lc 'for path in /openedx/dist/*; do [ -d "$path" ] && basename "$path"; done'

# Production
kubectl exec -n mereka-lms deploy/mfe -- ls -la /openedx/dist/ | grep "^d"
```

**Check MFE config:**
```bash
# Local
curl http://localhost/api/mfe_config/v1?mfe=authn | jq .

# Production
curl https://academyv2.mereka.io/api/mfe_config/v1?mfe=authn | jq .
```

**Check image versions:**
```bash
# See MFE_VERSIONS.md for canonical version baseline
cat deploy/k8s/base/kustomization.yaml | grep -A2 "openedx-mfe"
```

## References

- Canonical version tracking: [MFE_VERSIONS.md](MFE_VERSIONS.md)
- Open edX MFE repos: `https://github.com/openedx/frontend-app-*`
- Tutor MFE Plugin: https://github.com/overhangio/tutor-mfe
- Caddy routing: `deploy/k8s/base/apps/caddy/Caddyfile`
