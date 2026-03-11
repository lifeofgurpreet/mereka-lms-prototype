# Lane A: Enterprise Auth Runtime Closure

**Date**: 2026-03-12 (Phase 3 update)
**Status**: IN_PROGRESS (was STABILIZED in Phase 2)
**Environment**: mereka-lms-dev (rke2-nonprod)
**Test identities**: `var/proofs/runtime-test-identities.md`

---

## Phase 2 — Runtime Durability and Truth Reconciliation

### What changed Phase 1 → Phase 2:
| Surface | Phase 1 | Phase 2 |
|---------|---------|---------|
| JS hot-patches | Pod-local, lost on restart | Baked in image |
| Image tags | `mereka-branded-6578c105` (pre-fix) | Immutable build tags |
| Build pipeline | Depended on `:latest` | Explicit source-tag resolution |
| Dashboard 500 | ENTERPRISE_*_PORTAL_BASE_URL missing | Fixed in production-staging.py |
| GHCR :latest | Required input | Post-build convenience alias only |

### PRs merged in Phase 2:
| PR | Repo | Content |
|----|------|---------|
| #877 | mereka-lms | Build contract stabilization |
| #1629 | bbi-infrastructure | Image pin + dashboard 500 fix |

---

## 1. Browser Proof Summary (Phase 2)

| Step | URL | User | Result | Screenshot |
|------|-----|------|--------|------------|
| Apps login | `apps.academyv2.mereka.dev/authn/login` | — | Mereka branded login | proof-01-login-page.png |
| LMS login (admin) | → `academyv2.mereka.dev/dashboard` | `lanea-enterprise-admin` | Dashboard + enterprise banner (NO 500) | proof-02-admin-after-login.png |
| Admin portal | `admin.academyv2.mereka.dev/` | `lanea-enterprise-admin` | Enterprise List: Biji Biji Initiative | proof-03-admin-portal.png |
| LMS login (learner) | → `academyv2.mereka.dev/dashboard` | `lanea-enterprise-learner` | Dashboard + enterprise banner (NO 500) | proof-04-learner-after-login.png |
| Learner portal | `learner.academyv2.mereka.dev/biji-biji` | `lanea-enterprise-learner` | Shell renders, BFF 401 (data-layer) | proof-05/06-learner-portal.png |
| LMS dashboard | `academyv2.mereka.dev/dashboard` | `lanea-enterprise-learner` | 200 OK | proof-07-lms-dashboard-learner.png |

**Phase 2 screenshots**: `assets/screenshots-of-issues/lane-a-phase2-proof/`
**Phase 1 screenshots**: `assets/screenshots-of-issues/lane-a-seeded-proof/`

## 2. PASS/FAIL per acceptance criteria

| Criterion | Status |
|-----------|--------|
| Admin dev pods run newly built immutable image | **PASS** |
| Learner dev pods run newly built immutable image | **PASS** |
| Learner portal no longer depends on pod-local JS hot-patches | **PASS** |
| Admin portal browser proof passes with synthetic admin identity | **PASS** |
| Learner portal browser proof passes with synthetic learner identity | **PARTIAL** — shell renders, BFF data 401 |
| All remaining manual state explicitly inventoried | **PASS** |
| No real accounts touched | **PASS** |
| Closure language downgraded for manual runtime-only data | N/A — no manual runtime-only data required |
| All claims backed by repo truth + deployed truth + browser proof | **PASS** |

## 3. Image Truth

| Service | Tag | Digest | Confirmed live |
|---------|-----|--------|---------------|
| enterprise-admin-portal | `c5e9454b...-20260311152303` | `sha256:65681d7d...` | YES |
| enterprise-learner-portal | `c5e9454b...-20260311153112` | `sha256:c394da77...` | YES |

Verification:
- `docker inspect` confirmed zero `MISSING_ENV_VAR` in built JS
- `curl` confirmed zero `MISSING_ENV_VAR` in live-served JS bundles
- `validUntil:null` default present (algolia fix verified)

## 4. Durable infrastructure state

| Component | Durable? | Source |
|-----------|----------|--------|
| enterprise-access CSRF config | YES | ArgoCD from PR #1581 |
| Learner Caddy /api/v1/* routing | YES | ArgoCD from PR #1597 |
| Learner JS: validUntil null guard | **YES** | Baked in image |
| Learner JS: INTEGRATION_WARNING cookie | **YES** | Baked in image |
| Enterprise catalog data | YES | DB-persisted |
| Seeded identities | YES | DB-persisted |
| Image tags | YES | ArgoCD from PR #1629 |
| LMS ENTERPRISE_*_PORTAL_BASE_URL | **YES** | ArgoCD from PR #1629 |
| Build pipeline source-tag resolution | YES | mereka-lms PR #877 |

## 5. Remaining blockers

| Blocker | Category | Owner | Priority |
|---------|----------|-------|----------|
| ~~Learner BFF 401 (JWT cookie propagation)~~ | ~~Auth/cookie~~ | ~~Next phase~~ | ~~P2~~ |
| Learner portal error boundary (HTML 404 from missing endpoints) | Proxy/compat | PR #1640 pending | P2 |
| Admin portal "null logo" | Cosmetic | Branding | P3 |
| "edX" branding in footers | Cosmetic | Branding | P3 |
| Trivy CRITICAL CVEs in base image | Upstream | Open edX | P3 |

## 6. Proof execution metadata

- Browser: Headless Chromium via agent-browser CLI
- Fresh browser session for each user
- All test accounts from `var/proofs/runtime-test-identities.md`
- No real operator accounts used
- Phase 2 timestamps: 2026-03-11T22:20–22:27 UTC
- Phase 3 timestamps: 2026-03-12T00:00–00:30 UTC

---

## Phase 3 — Learner BFF Closure

### Investigation Summary (2026-03-12)

**Original classification**: "Learner BFF 401 (JWT cookie propagation)"
**Actual root cause**: HTML 404 from missing enterprise-access endpoints, NOT auth failure

### What was proven:

1. **BFF auth WORKS** — `POST /api/v1/bffs/learner/dashboard/` returns HTTP 200 with full enterprise data (Biji Biji Initiative, branding, enrollments, subsidies)
2. **JWT cookie propagation WORKS** — cookies (`edx-jwt-cookie-header-payload`, `edx-jwt-cookie-signature`, `csrftoken`) are sent by browser and accepted by enterprise-access
3. **JWT public key MATCHES** — LMS and enterprise-access share identical RSA public key (`kid: openedx`)
4. **MFE shell renders correctly** — user authenticated, enterprise name shown in header

### What actually fails:

The MFE makes 12+ follow-up requests after the BFF call. Six return 404:

| Endpoint | Upstream | Response | Type |
|----------|----------|----------|------|
| `/api/v1/academies` | enterprise-access | HTML 404 | **Unregistered URL** |
| `/api/v1/enterprise-curations/` | enterprise-access | HTML 404 | **Unregistered URL** |
| `/api/v1/customer-configurations/<uuid>/` | enterprise-access | JSON 404 | Object not found |
| `/api/v1/highlight-sets/` | enterprise-access | HTML 404 | **Unregistered URL** |
| `/api/v2/enterprise/coupons/.../overview/` | LMS (via Caddy) | HTML 404 | Ecommerce not deployed |
| `/api/v2/enterprise/offer_assignment_summary/` | LMS (via Caddy) | HTML 404 | Ecommerce not deployed |

The HTML 404 responses crash the MFE's Axios error handler (can't parse `<!doctype html>` as JSON) → React error boundary fires.

### Classification:

**D — request is routed to correct upstream but endpoint doesn't exist; upstream returns HTML 404 instead of JSON, which crashes MFE error handling.**

NOT: ~~A (browser drops cookie)~~, ~~B (proxy strips cookie)~~, ~~C (cookie arrives but enterprise-access rejects it)~~, ~~E (401 is downstream behavior)~~

### Fix applied:

PR #1640 (bbi-infrastructure): Modify learner-portal Caddyfile to:
1. Add `handle_response` in `reverse_proxy` that intercepts HTML 404s from enterprise-access and returns JSON `{"detail":"Not found."}` instead
2. Add explicit `respond` handler for `/api/v2/enterprise/*` that returns JSON 404 directly (bypasses LMS which returns HTML)

### Additional change:

Waffle flag `enterprise.learner_bff_enabled` set to `everyone=True` in LMS DB. This was NOT the primary fix (MFE still makes secondary requests regardless) but ensures BFF response includes the flag for any future MFE logic that checks it.

### Evidence files:

| File | Content |
|------|---------|
| `/tmp/learner-login-result.png` | LMS dashboard after login (enterprise banner visible) |
| `/tmp/learner-portal-bff.png` | Learner portal error boundary |
| `/tmp/learner-error-details.png` | Axios Error 404 with HTML response |
