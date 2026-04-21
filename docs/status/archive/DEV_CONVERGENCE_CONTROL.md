# DEV Convergence Control
_Owner: Platform Team | Last verified: 2026-03-20 | Status: active_

> Single source of truth for the DEV convergence program.
> Do not create parallel tracking docs. Update this file.

## Current State

| Property | Value | Verified |
|----------|-------|----------|
| openedx image | `e9a3e1bb` | 2026-03-20 |
| mfe image | `53e5014d` | 2026-03-20 |
| ArgoCD mereka-lms-dev | Synced/Healthy | 2026-03-20 |
| All 11 DEV domains | Responding (200/302) | 2026-03-20 |
| All enterprise services | OK (health endpoints) | 2026-03-20 |
| MEREKA EC | exists, admin role present, reporting=True, 0 catalogs | 2026-03-20 |
| apply-dev-tenant-state.sh | NOT ON MAIN (branch fix/libsass-css4-rgb-compat) | 2026-03-20 |

## Parked Issues — Visual/CSS

These require the user's visual review to decide priority. Each has exact CSS control points documented.

### A. Public LMS (homepage, /courses)

| Issue | Control File | Control Point | Current Value |
|-------|-------------|---------------|---------------|
| Card border softness | `scss/theme.scss:400` | `.course { border-radius }` | `28px` |
| Cards per row | `scss/theme.scss:385` | `.courses-listing { grid-template-columns }` | `repeat(auto-fit, minmax(260px, 1fr))` ~4 at 1280px |
| Card shadow | `scss/_tokens.scss` | `--mereka-shadow-card` | `0 20px 60px rgba(26,22,35,0.08)` |
| Card image height | `scss/theme.scss:418` | `.course .course-image .cover-image { height }` | `180px` |
| Learn-more button | `scss/theme.scss:433-504` | `.learn-more` | Pill, gradient, absolute positioned |
| /courses search styling | `lms/static/css/mereka-overrides.css:294-504` | `.find-courses` selectors | Fully styled (24px radius, pill buttons) |
| /courses filter pills | `lms/static/css/mereka-overrides.css:425-447` | `.facet-option` | Pill shape, gradient on active |

### B. Dashboard (logged-in)

| Issue | Control File | Control Point | Current Value |
|-------|-------------|---------------|---------------|
| Dashboard card styling | `scss/theme.scss:532-606` | `.dashboard .my-courses .course-item .course` | 28px radius, gradient enter-course button |
| Dashboard layout (horizontal) | `head-extra.html:289-359` | `.dashboard .main-container .my-courses` | Horizontal cards (image left, details right) |
| Dashboard grid vs vertical | `head-extra.html:52-65` | `.dashboard .my-courses .listing-courses` | Vertical flex layout |

### C. Auth/MFE

| Issue | Control File | Control Point |
|-------|-------------|---------------|
| Auth logo size/position | `mfe/mereka.scss` | `.mereka-authn-login-branding__logo-img { max-height: 72px; max-width: min(320px, 75%) }` |
| Auth field spacing | Paragon defaults | Would need brand-mereka/paragon/_overrides.scss changes |
| MFE footer content | `plugins/_mereka_lms/mfe_runtime_definitions.js` | `MerekaFooter` component (~line 800+) |
| MFE menu items | `plugins/_mereka_lms/mereka_lms_mfe_slots.py:353-374` | Menu slot insertions |

### D. Studio

| Issue | Control File | Control Point |
|-------|-------------|---------------|
| Dropdown opacity | No Studio-specific CSS found | Inherits MFE theme tokens |
| Libraries v2 | `cms/production.py:596-731` | All `*_ENABLED = false` (env overridable) |
| Tagging/taxonomy | Not configured | No feature flag found |
| Logout route | `cms/production.py` | No explicit LOGOUT_URL (inherits upstream) |
| Course Authoring MFE | `cms/production.py:518` | `COURSE_AUTHORING_MICROFRONTEND_URL = {MFE_BASE}/authoring` |

## Parked Issues — Data/Enterprise

| Issue | Current State | Blocker | Next Action |
|-------|--------------|---------|-------------|
| MEREKA EC catalogs | 0 catalogs | User deferred | Create via Django admin when ready |
| skillourfuture EC catalogs | 0 catalogs | User deferred | Create via Django admin when ready |
| biji-biji duplicate catalogs | 3 in LMS, 1 in catalog service | Low priority | Cleanup |
| Enterprise admin portal thin menu | Expected (no catalogs) | Data gap | Will resolve with catalog creation |
| Learner portal /mereka slug | Untested | Needs browser login test | Manual verification |

## Parked Issues — Governance/Debt

| Issue | Current State | Blocker | Next Action |
|-------|--------------|---------|-------------|
| head-extra.html 360 lines | ~100 lines duplicate compiled theme, ~260 unique | Requires governed openedx image rebuild + rollout to reduce | Move rules to _custom.scss, publish via build workflow, then strip head-extra |
| apply-dev-tenant-state.sh not on main | On branch fix/libsass-css4-rgb-compat | PR merge needed | Merge branch or cherry-pick script |
| course_org_filter for dev tenants | TEMP_RUNTIME (set via kubectl) | Script not on main | Add to apply script, merge |
| MEREKA reporting flag | TEMP_RUNTIME | Script not on main | Add to apply script, merge |
| Aspects/analytics | Not deployed on DEV | Unknown | Separate investigation |
| Prod Site records in dev DB (IDs 4,6,7) | Harmless but confusing | Low priority | Cleanup when convenient |
| Site ID=1 lms-dev.mereka.dev | Legacy profiles-dev remnant | Low priority | Remove when convenient |

## TEMP_RUNTIME Register

| Item | Set By | Durable Home | Removal Trigger |
|------|--------|-------------|-----------------|
| course_org_filter for biji-biji.dev | kubectl exec (2026-03-20) | apply-dev-tenant-state.sh | Merge branch + re-run script |
| course_org_filter for skillourfuture.dev | kubectl exec (2026-03-20) | apply-dev-tenant-state.sh | Merge branch + re-run script |
| MEREKA enable_portal_reporting_config_screen=True | kubectl exec (2026-03-20) | apply-dev-tenant-state.sh | Merge branch + re-run script |

## How to Resume This Lane

1. Review this file for current state
2. Check `deploy/k8s/tenancy/tenant-registry.yaml` for domain truth
3. Check `docs/reference/operations/DOMAIN_MATRIX.md` for operational status
4. All visual CSS tuning starts at the control points documented above
5. Any openedx image change requires a governed `.github/workflows/build-tutor-images.yml` run with `build_openedx=true`, then GitOps promotion before closure claims
6. Any MFE change requires a governed `.github/workflows/build-tutor-images.yml` run with `build_mfe=true`, then GitOps promotion before closure claims
7. head-extra debt reduction requires: move rules to `_custom.scss` + governed openedx build/promotion + strip `head-extra`
