# Complete MFE List & Status
_Last updated: 2026-02-27_

> **Canonical version info**: [MFE_VERSIONS.md](architecture/MFE_VERSIONS.md)
> **Related**: [FRONTEND_TRACKER.md](FRONTEND_TRACKER.md), [MFE_FIRST_POLICY.md](architecture/MFE_FIRST_POLICY.md)

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

## Enterprise MFEs (Not Yet Configured)

These MFEs exist in Open edX but are not yet deployed. They become relevant when enterprise microservices are activated:

| MFE | Purpose | Depends On | Status |
|-----|---------|-----------|--------|
| **frontend-app-enterprise-public-catalog** | Public course catalog browsing | Enterprise Catalog service | Not deployed |
| **frontend-app-admin-portal** | Enterprise admin dashboard | Enterprise services stack | Not deployed |
| **frontend-app-learner-portal-enterprise** | Enterprise learner portal | Enterprise services stack | Not deployed |
| **frontend-app-support-tools** | Support/admin tools | Staff access | Not deployed |

## Other Available MFEs (Upstream)

| MFE | Purpose | Relevant? |
|-----|---------|-----------|
| **frontend-app-library-authoring** | Content library management | Yes — when Content Libraries v2 is enabled |
| **frontend-app-credentials** | Credentials/badges display | Yes — when Badges & Credentials spec is implemented |
| **frontend-app-publisher** | Course discovery publisher | Maybe — depends on Discovery service setup |

## Open edX Release: Ulmo (Tutor v21)

- **Default Node.js**: 24.11.0 (we currently patch to Node 18.20.5 — upgrade planned)
- **Paragon version**: v23+ (supports JSON design tokens)
- **Frontend Plugin Framework**: ~130+ plugin slots available across MFEs
- **PARAGON_THEME_URLS**: Runtime CDN theming supported (not yet enabled)

## Verification

**Check available MFEs:**
```bash
# Local
docker exec tutor_local-mfe-1 ls -la /openedx/dist/ | grep "^d"

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

- Canonical version tracking: [MFE_VERSIONS.md](architecture/MFE_VERSIONS.md)
- Open edX MFE repos: `https://github.com/openedx/frontend-app-*`
- Tutor MFE Plugin: https://github.com/overhangio/tutor-mfe
- Caddy routing: `deploy/k8s/base/apps/caddy/Caddyfile`
