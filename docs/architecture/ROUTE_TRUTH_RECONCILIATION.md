# Route Truth Reconciliation
_Audience: Platform Engineering, Frontend Engineering, Runtime Owners • Owner: Platform Team • Last updated: 2026-03-11 • Status: canonical_

## Purpose

Map the current route-truth split across repo-owned routing surfaces so future runtime work can see exactly where route ownership, proof, and drift risk are divided.

This is a reconciliation artifact, not a mutation plan. It records the current state in `mereka-lms` only.

## Truth Surfaces Considered

- Platform Caddy:
  - `deploy/k8s/base/apps/caddy/Caddyfile`
- MFE gateway Caddy:
  - `deploy/k8s/base/plugins/mfe/apps/mfe/Caddyfile`
- Enterprise portal Caddy shells:
  - `deploy/k8s/base/apps/enterprise/mfe/admin-portal-Caddyfile`
  - `deploy/k8s/base/apps/enterprise/mfe/learner-portal-Caddyfile`
- Ingress:
  - `deploy/k8s/overlays/staging/ingress-openedx-mfe.yaml`
  - `deploy/k8s/overlays/staging/ingress-enterprise-admin.yaml`
  - `deploy/k8s/overlays/staging/ingress-enterprise-learner.yaml`
  - production equivalents under `deploy/k8s/overlays/production/`
- Verifier scripts:
  - `scripts/qa/verify-mfe-config-api.sh`
  - `scripts/qa/verify-mfe-routing-parity.sh`
  - `scripts/qa/verify-auth-surfaces.sh`
  - `scripts/qa/verify-public-branding.sh`
  - `scripts/qa/verify-enterprise-ui-review.sh`
- Docs references:
  - `docs/runtime-proof/ENTERPRISE_MFE_RUNTIME_CONFIG_TRUTH_CONTRACT.md`
  - `docs/guides/branding/TENANT_BRANDING_CONTRACT.md`
  - `docs/reference/architecture/MFE_RUNTIME_CONFIG.md`
  - `docs/reference/operations/ROUTE_MATRIX.md`

## Route Family Matrix

| Route family | Current owner | Current implementation location(s) | Current proof location(s) | Drift risk | Duplicated? | Lane/env semantic differences | Recommended cleanup path |
|---|---|---|---|---|---|---|---|
| `/api/mfe_config/v1*` | LMS API, surfaced through multiple proxies | platform Caddy on `apps`, credentials host, enterprise hosts; MFE gateway Caddy; ingress compatibility routes | `verify-mfe-config-api.sh`, `verify-auth-surfaces.sh`, enterprise truth contract | High | Yes | Non-local ingress/overlay ownership differs by lane | Consolidate around one declared public route contract and one verifier authority |
| `/login_refresh*` | LMS auth refresh endpoint | platform Caddy on `apps`; MFE gateway Caddy; enterprise ingresses route directly to LMS | `verify-auth-surfaces.sh`, `verify-mfe-routing-parity.sh`, `verify-enterprise-ui-review.sh` | High | Yes | Enterprise domains use ingress-to-LMS path; `apps.*` uses gateway/Caddy path | Consolidate route contract and explicitly document enterprise vs shared-MFE flow |
| `/csrf` and `/csrf/*` | LMS CSRF/token endpoints | enterprise ingresses route directly to LMS; staging `openedx-mfe` ingress routes `/csrf`; MFE gateway Caddy base does not own it | `verify-auth-surfaces.sh`, security/cookie verifiers | High | Yes | Shared-MFE vs enterprise-host handling differs; repo proof is split between ingress and Caddy | Record as ingress-owned auth surface until runtime team consolidates |
| `/oauth2` and `/oauth2/*` | LMS OAuth/OIDC endpoints | enterprise ingresses route directly to LMS; staging `openedx-mfe` ingress routes `/oauth2`; MFE gateway Caddy base does not own it | `verify-auth-surfaces.sh`, enterprise UI review, auth runbooks | High | Yes | Same split as CSRF; semantics depend on domain and auth redirect flow | Treat as auth-route family, not portal-owned route |
| `/login` and `/login*` | LMS login endpoint | enterprise ingresses route to LMS; staging `openedx-mfe` ingress routes `/login`; platform Caddy uses `/authn/*` on credentials host | `verify-auth-surfaces.sh`, docs runbooks | High | Yes | Shared MFE shell uses `/authn/*`; enterprise and ingress-auth flows still rely on `/login` | Make authn redirect policy explicit and unify docs language |
| `/api/*` generic | Mixed: LMS for shared APIs; enterprise services for admin-specific APIs | staging `openedx-mfe` ingress routes `/api` to LMS; enterprise admin ingress splits `/api/enterprise-*` to dedicated services and generic `/api` to LMS; MFE gateway Caddy only owns selected API paths | `verify-auth-surfaces.sh`, `verify-mfe-routing-parity.sh`, enterprise runtime verifiers | Very high | Yes | Enterprise admin has service fan-out; learner portal and shared MFEs do not share the same route map | Promote to explicit route-contract inventory with owner by prefix |
| `/api/v1/bffs/*` | Implicit LMS/BFF catch-all, not explicitly declared in base gateway docs | covered indirectly by ingress `/api` prefixes; not explicitly called out in base Caddy | no dedicated verifier; only implicit coverage through broader `/api` checks | Very high | Implicitly | Semantics hidden behind generic `/api` rules | Add explicit route-contract entry later; do not leave it as an implicit side effect |
| Enterprise learner root `/` | enterprise learner portal SPA shell | enterprise learner ingress `/` to `enterprise-learner-portal`; learner portal Caddy `try_files {path} /index.html` | `verify-enterprise-ui-review.sh`, enterprise runtime docs | Medium | No | Domain and config differ by lane; runtime config split | Keep as dedicated enterprise shell surface with browser-proof requirement |
| Enterprise admin root `/` | enterprise admin portal SPA shell | enterprise admin ingress `/` to `enterprise-admin-portal`; admin portal Caddy `try_files {path} /index.html` | `verify-enterprise-ui-review.sh`, enterprise runtime docs | Medium | No | Domain and backend service fan-out differ by lane | Keep as dedicated enterprise shell surface with browser-proof requirement |
| `/authn/*` | shared MFE authn SPA | MFE gateway Caddy serves `authn` dist; credentials host proxies `/authn/*` to MFE | `verify-auth-surfaces.sh`, branding/public verifiers | Medium | Yes | Credentials service host proxies authn shell while enterprise hosts do not | Explicitly document that enterprise auth is redirect-driven, not portal-local `authn` routing |
| `/profile/api/*` | LMS profile API behind MFE profile surface | MFE gateway Caddy has dedicated profile API reverse proxy with ordering workaround | `verify-mfe-routing-parity.sh` only indirectly | Medium | No | This is a special-case route inside the shared MFE gateway | Preserve as explicit exception until route cleanup work happens |
| `/orders*` | payments gateway | MFE gateway Caddy proxies `/orders*`; not present on enterprise ingresses; adjacent LMS `/payments/*` path exists on platform Caddy | very limited proof; mostly route/parity scripts | High | Conceptually yes | Shared-MFE route name differs from LMS host route name | Document as non-core route with split semantics |
| `/payment*` | payments gateway | MFE gateway Caddy proxies `/payment*`; LMS host uses `/payments/*` | limited proof; mostly route/parity scripts | High | Conceptually yes | Singular vs plural path families differ by host surface | Same as `/orders*`: treat as non-core route requiring explicit future parity policy |
| Credentials root `/` | credentials host bespoke shell | platform Caddy returns inline HTML for `/`; `/authn/*` proxied to MFE; `/admin/login` rewritten to authn | `verify-credentials-*` scripts, auth surface checks | Medium | No | Credentials host is not a standard MFE shell | Keep documented as adjacent non-core surface, not hidden infrastructure |

## Primary Findings

1. Route truth is not in one place.
   Shared frontend routing is split between platform Caddy, MFE gateway Caddy, ingress, and enterprise-specific ingress objects.

2. Enterprise portals are not route-identical to the main MFE host.
   Their roots are simple SPA shells, but auth and API path handling is delegated to ingress and LMS/service backends.

3. `/api/*` is the highest-drift family.
   The same prefix means different things depending on host:
   - generic LMS API on shared MFE hosts
   - enterprise service fan-out on admin host
   - implicit catch-all for BFF-like paths

4. Non-core routes are visible but weakly unified.
   `/orders*`, `/payment*`, and credentials do exist in repo route surfaces, but they are not governed under one clean frontend route contract.

## Owner Split Summary

| Surface | Primary repo owner |
|---|---|
| Shared MFE shell routes (`/authn`, `/account`, `/learning`, etc.) | `deploy/k8s/base/plugins/mfe/apps/mfe/Caddyfile` |
| Enterprise shell roots | enterprise ingress + enterprise portal Caddy |
| Auth/API passthroughs for enterprise hosts | enterprise ingress |
| Auth/API passthroughs for `apps.*` | mix of staging/prod ingress and platform/MFE Caddy |
| Non-core routes (`/orders*`, `/payment*`, credentials) | split across MFE gateway and platform Caddy |

## Immediate Planning Guidance

This reconciliation produces the following planning constraints:

1. Do not assume `apps.*` route behavior tells you anything definitive about `admin.*` or `learner.*`.
2. Do not assume Caddy alone is route authority for enterprise hosts; ingress owns part of the truth.
3. Do not add new verifier assertions without first choosing which route surface is authoritative.
4. Treat `/api/*` and auth redirects as parity surfaces, not just transport details.

## Recommended Future Cleanup Paths

These are planning directions only, not changes made here:

- publish one explicit route contract for shared MFE host routes
- publish one explicit route contract for enterprise portal host routes
- split generic `/api/*` documentation into named owned prefixes
- add a future drift gate that compares:
  - route contract
  - ingress
  - Caddy
  - verifier assumptions

## What This Artifact Does Not Claim

This document does **not** prove:

- that runtime ingress matches the repo in live clusters
- that enterprise API routes are healthy live
- that browser flows are working
- that non-core routes have acceptable UX

It only reconciles the repo-owned route truth surfaces so future work can proceed cleanly.
