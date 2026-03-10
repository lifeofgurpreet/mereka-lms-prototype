---
id: ADR-013
title: Studio SSO Bypass Middleware
decision_status: accepted
decision_type: exception
rollout_state: temporary
owner: auth-platform
created: '2026-02-12'
last_reviewed: '2026-03-07'
review_due: '2026-06-30'
supersedes: []
amends: []
depends_on:
- ADR-029
- ADR-031
read_next:
- ADR-022
- ADR-029
governs:
- auth.oidc
does_not_govern:
- long-term authn frontend architecture
related_oep: []
related_tutor_docs:
- https://docs.openedx.org
- https://docs.tutor.edly.io
related_specs: []
related_runbooks:
- docs/runbooks/operations/AUTHENTICATED_SMOKE_A11Y.md
related_evidence: []
fitness_functions:
- scripts/qa/verify-auth-surfaces.sh prod
expiry_date: 2026-09-30
removal_condition: Upstream/frontend authn flow preserves OAuth next state without
  middleware bypass.
---

# ADR-013: Studio SSO Bypass Middleware

**Status**: Accepted
**Date**: 2026-02-12
**Deciders**: Platform Engineering

<!-- Last verified: 2026-02-13 -->

## Context

When Studio (CMS) initiates SSO login via the LMS OAuth provider, the redirect chain is:
1. Studio /login/ → /login/edx-oauth2/ → LMS /oauth2/authorize?client_id=cms-sso&...
2. LMS (unauthenticated) → /login?next=/oauth2/authorize?client_id=cms-sso&...
3. LMS → MFE authn page at apps.academyv2.mereka.io/authn/login?next=%2Foauth2%2Fauthorize%3F...
4. MFE authn fetches /api/third_party_auth_context WITHOUT passing the `next` parameter
5. API returns loginUrl with `next=%2Fdashboard` (hardcoded default)
6. User clicks "Sign in with Mereka" → OIDC login with next=/dashboard
7. After OIDC login, user lands on /dashboard instead of /oauth2/authorize

The root cause is the MFE authn React app not passing the URL's `next` query parameter to the third_party_auth_context API. This is a known gap in the Open edX frontend-app-authn when using third-party auth providers.

## Decision

Add `StudioSSOBypassMiddleware` to the LMS Django middleware stack that:
- Detects GET requests to `/login` or `/login/` where the `next` parameter starts with `/oauth2/authorize`
- Redirects directly to `/auth/login/oidc/?next=<encoded-oauth-authorize-url>`
- Bypasses the MFE authn page entirely for service-to-service OAuth flows
- Preserves normal MFE authn for direct user logins

The middleware is positioned early in the stack (index 1, after forwarded-headers hardening).

Location: `StudioSSOBypassMiddleware` class in infrastructure production-prod.py (the LMS settings overlay).

## Scope

This ADR governs the decision boundary described by ADR-013.

## Non-goals

This document does not replace broader platform standards, runbooks, or implementation evidence.

## Verification

- `scripts/qa/verify-auth-surfaces.sh prod`

## Consequences

### Positive
- Studio SSO login works in a single flow (no two-step workaround)
- Ecommerce SSO also benefits (same /oauth2/authorize pattern)
- No MFE image rebuild required
- Normal LMS login flow unchanged
- Minimal code (< 15 lines of middleware logic)

### Negative
- Service-to-service OAuth bypasses the MFE login page UI entirely
- If OIDC provider is down, user sees Authentik error page (no friendly MFE error)
- Future MFE authn fixes that properly pass `next` would make this middleware redundant (but harmless)

## Alternatives Considered

1. **Fix the MFE authn React app** - Would require modifying frontend-app-authn source and rebuilding the MFE image. More correct long-term but slower to deploy and would need to be maintained across upstream updates.

2. **Caddy redirect rule** - Caddy cannot easily inspect query parameters for conditional redirects.

3. **Two-step login workaround** - Tell users to log into LMS first, then visit Studio. Poor UX.

4. **Set skipHintedLogin on OIDC provider** - Would auto-redirect ALL logins to OIDC, removing the option for username/password login entirely.
