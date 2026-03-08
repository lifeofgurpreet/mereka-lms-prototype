---
id: ADR-022
title: Session Cookie SameSite Policy and Stale Cookie Mitigation
decision_status: accepted
decision_type: exception
rollout_state: temporary
owner: auth-platform
created: 2026-03-04
last_reviewed: 2026-03-07
review_due: 2026-06-30
supersedes: []
amends: ["ADR-002", "ADR-013"]
depends_on: ["ADR-029", "ADR-031"]
read_next: []
governs: ["session-cookie-samesite-exception", "stale-cookie-dedup-workaround"]
does_not_govern: ["final steady-state cross-domain identity architecture"]
related_oep: []
related_tutor_docs: ["https://docs.openedx.org", "https://docs.tutor.edly.io"]
related_specs: []
related_runbooks: ["docs/runbooks/operations/FORUM_AUTH_E2E.md"]
related_evidence: []
fitness_functions: ["scripts/qa/verify-auth-surfaces.sh prod", "scripts/qa/verify-mfe-config-contract.sh --env prod"]
expiry_date: 2026-09-30
removal_condition: SameSite and dedup exception removed after stable federated auth flow without stale-cookie reliance.
---

# ADR-022: Session Cookie SameSite Policy and Stale Cookie Mitigation

**Status**: Accepted
**Date**: 2026-03-04
**Deciders**: Gurpreet Singh (Founder / Platform Owner)

<!-- Last verified: 2026-03-04 -->

## Context

During OIDC login through Authentik (`auth0.mereka.dev`), Django's `SafeSessionMiddleware` intermittently raised "Session value state missing" errors on the `/auth/complete/oidc/` callback. The session cookie set during `/auth/login/oidc/` was not being reliably returned when Authentik redirected back to `/auth/complete/oidc/`.

Two independent bugs combined to produce the failure.

### Bug 1: Stale host-only cookie taking precedence over domain cookie

`MerekaCookieDomainMiddleware` was added to rewrite the session cookie's domain attribute to `.academyv2.mereka.io` so that subdomain services (Studio, MFEs) share the session. Before this middleware existed, however, users who had logged in received a host-only `sessionid` cookie (no `Domain=` attribute) issued by the vanilla Django session backend.

RFC 6265 §5.4 states that when the browser holds both a host-only cookie and a domain cookie with the same name for the same path, the host-only cookie takes precedence in the `Cookie:` request header. Django reads the first matching name from the request, which is the stale host-only cookie. That cookie refers to an older or now-invalid session, so the OIDC state stored in the new session is absent when the callback arrives.

### Bug 2: SameSite=Lax blocks the cross-origin callback

The OIDC redirect chain passes through `auth0.mereka.dev` (Authentik), which is a different registrable domain from `academyv2.mereka.io`. A POST or redirect that originates from a cross-site context is classified as a cross-site navigation by browsers. With `SameSite=Lax`, cookies are withheld on cross-site POST requests; some browsers also suppress them on cross-site top-level navigations when the cookie age is above a threshold. This is specification-correct behaviour, but it is incompatible with a redirect chain that crosses domain boundaries.

The upstream LMS sets `DCS_SESSION_COOKIE_SAMESITE="None"` in `lms/envs/common.py`. Our production overlay had deviated from this default.

## Decision

### 1. SESSION_COOKIE_SAMESITE = "None"

`SESSION_COOKIE_SAMESITE` is set to `"None"` in the LMS production settings overlay (`infrastructure production-staging.py` and `production-prod.py`). This matches the upstream LMS default and eliminates the SameSite-related suppression across the Authentik redirect chain.

`SameSite=None` requires `Secure=True`. `SESSION_COOKIE_SECURE = True` is already enforced in both overlays (all traffic arrives over HTTPS). No additional change is needed for this requirement.

CSRF protection is not weakened by this change. Django's CSRF middleware validates the `csrftoken` cookie independently, and `CSRF_COOKIE_SAMESITE` is separately set to `"None"` with `CSRF_COOKIE_SECURE = True`. The CSRF token itself (a cryptographic secret in the cookie value, compared against the `X-CSRFToken` header or POST field) provides the anti-forgery guarantee that `SameSite=Lax` would otherwise assist with.

### 2. _dedup_session_cookie() in MerekaCookieDomainMiddleware

`MerekaCookieDomainMiddleware` gains a request-side method `_dedup_session_cookie()` that runs in `process_request`, before `SafeSessionMiddleware` reads the session:

- It inspects all cookies named `sessionid` in the incoming `Cookie:` header.
- If more than one value is present, it keeps only the one whose value matches the `SafeSessionMiddleware` format (contains `|` — the format is `session_key|user_id|hash`).
- The kept value is written back to `request.COOKIES["sessionid"]`.

This ensures Django always reads the current authenticated session, not the stale host-only cookie from before domain-rewriting was in place.

The deduplication is a transitional measure. Once all active users have rotated their cookies (session TTL + a grace period of 90 days), the logic can be removed. It is cheap (a single dict scan on every request) and safe to leave in place indefinitely.

### 3. SESSION_COOKIE_NAME = "studio_session_id" (Studio only)

Studio's session cookie name remains `"studio_session_id"` (set in `infrastructure production-staging.py` for the CMS overlay). This decision predates this ADR and is preserved:

- The LMS sets `Domain=.academyv2.mereka.io` on its `sessionid` cookie. If Studio used the same name, the browser would send the LMS cookie to Studio, and `SafeSessionMiddleware` would read a session belonging to the LMS process — causing authentication inconsistency.
- A distinct name means the two cookies coexist without interference.

### Files changed

| File | Change |
|---|---|
| `infrastructure production-staging.py` | `SESSION_COOKIE_SAMESITE = "None"`, `_dedup_session_cookie()` method added to `MerekaCookieDomainMiddleware` |
| `infrastructure production-prod.py` | Same |
| `deploy/k8s/base/apps/openedx/settings/lms/mereka_multisite.py` | Base class for middleware (not deployed via ConfigMap; serves as canonical reference) |

## Consequences

### Positive

- OIDC login through Authentik completes reliably without "Session value state missing" errors.
- Stale host-only cookies from pre-domain-rewrite sessions no longer cause silent authentication failures for returning users.
- Aligns with upstream LMS default (`DCS_SESSION_COOKIE_SAMESITE="None"`), reducing drift from the reference configuration.

### Negative

- `SameSite=None` cookies are sent on all cross-site requests, including those initiated by third-party pages embedding resources from the LMS. This is acceptable because the LMS does not embed as a third-party resource in untrusted contexts, and CSRF protection via the CSRF middleware is unaffected.
- Older browsers (pre-2020) that ignore `SameSite=None` or treat it as `SameSite=Strict` will behave as if `SameSite` were absent. This is the same behaviour as before the policy was explicitly set and is not a regression.
- The deduplication logic in `_dedup_session_cookie()` adds a small amount of code that is time-bounded (90-day TTL window) but must be explicitly removed rather than expiring automatically.

### Risks

- **Cookie name conflict recurrence**: If a future middleware or plugin introduces another response-side cookie rewrite (e.g., name change), the request-side deduplication would need to be updated to match the new name. Mitigation: `_dedup_session_cookie()` is tested in the middleware unit tests and will fail fast if the format assumption breaks.
- **`SameSite=None` in future browser policy changes**: Browser vendors have discussed restricting `SameSite=None` in certain third-party contexts (e.g., Privacy Sandbox). If restrictions land, the OIDC redirect chain may need to move to a same-site flow (e.g., Authentik proxied under `academyv2.mereka.io`). Mitigation: monitor browser vendor announcements; the fix path (subdomain proxy) is known.

## Alternatives Considered

1. **Keep SameSite=Lax** — Specification-correct and aligned with the web platform direction. However, browsers behave inconsistently across versions on cross-site redirects, and the Authentik redirect chain is cross-domain by construction. Rejected: too fragile in practice even when theoretically correct.

2. **response_mode=query (already in use)** — Setting `response_mode=query` in the OIDC provider configuration ensures the authorization code arrives via GET (not POST). GET requests are not blocked by `SameSite=Lax` as cross-site navigations. This is already configured and helps with the SameSite problem but does not address the stale cookie precedence issue (Bug 1). Rejected as a standalone fix: necessary but not sufficient.

3. **SESSION_COOKIE_DOMAIN=None (host-only for LMS too)** — Would eliminate the domain cookie vs host-only cookie conflict by never issuing a domain cookie. Rejected: breaking subdomain session sharing is a hard requirement for Studio OAuth2 and MFE authn flows.

4. **Force session rotation on first login post-migration** — Invalidate all existing sessions on deploy, forcing re-login. Eliminates stale cookies instantly. Rejected: poor UX for current learners; a 90-day TTL-based expiry achieves the same result without a forced logout event.

## References

- [ADR-013: Studio SSO Bypass Middleware](013-studio-sso-bypass-middleware.md)
- [ADR-002: Multisite Architecture](002-multisite-architecture.md)
- [RFC 6265 §5.4 — The Cookie Header](https://datatracker.ietf.org/doc/html/rfc6265#section-5.4)
- [Django SafeSessionMiddleware](https://github.com/openedx/edx-django-utils/blob/master/edx_django_utils/sessions/middleware.py)
- [upstream `DCS_SESSION_COOKIE_SAMESITE` default in lms/envs/common.py](https://github.com/openedx/edx-platform/blob/open-release/ulmo.1/lms/envs/common.py)
