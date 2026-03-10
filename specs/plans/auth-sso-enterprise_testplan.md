---
title: Authentication & SSO Enterprise Integration Test Plan
spec: auth-sso-enterprise_spec.md
last_updated: '2026-02-13'
plan: auth-sso-enterprise_plan.md
status: draft
---

# Authentication & SSO Enterprise Integration Test Plan

## Test Strategy

This test plan covers SAML 2.0/OIDC federation, MFA enforcement, session management, JIT provisioning, SCIM deprovisioning, and role-based access control. Testing emphasizes security (signature validation, replay prevention, cross-tenant isolation) and compliance (audit logging, OWASP ASVS).

## Test Matrix

| AC ID | Description | Method | Priority | Automation |
|-------|-------------|--------|----------|------------|
| AC-001 | Enterprise login redirects to Okta SAML IdP | integration | P0 | automated |
| AC-002 | Enterprise login redirects to Azure AD OIDC | integration | P0 | automated |
| AC-003 | Cross-tenant IdP linking prevented (HTTP 403) | integration | P0 | automated |
| AC-004 | Default Authentik OIDC login preserved | integration | P0 | automated |
| AC-005 | SAML SP metadata endpoint returns valid XML | integration | P0 | automated |
| AC-006 | Valid SAML assertion creates session | integration | P0 | automated |
| AC-007 | Expired SAML assertion rejected | integration | P0 | automated |
| AC-008 | SAML assertion replay detected and blocked | integration | P0 | automated |
| AC-009 | SAML assertion signed with SHA-1 rejected | integration | P0 | automated |
| AC-010 | SAML assertion issuer mismatch rejected | integration | P0 | automated |
| AC-011 | OIDC token issuer and audience validated | integration | P0 | automated |
| AC-012 | Expired OIDC ID token rejected | integration | P0 | automated |
| AC-013 | OIDC authorization request includes PKCE | integration | P0 | automated |
| AC-014 | is_staff user requires MFA for /admin/ access | integration | P0 | automated |
| AC-015 | is_superuser requires MFA for all admin services | integration | P0 | automated |
| AC-016 | Authentik admin requires MFA | manual | P0 | manual |
| AC-017 | Newly elevated staff forced to enroll MFA | integration | P1 | automated |
| AC-018 | TOTP MFA challenge logged with method and outcome | integration | P1 | automated |
| AC-019 | Staff session expires after 30 min idle | integration | P0 | automated |
| AC-020 | Learner session expires after 120 min idle | integration | P1 | automated |
| AC-021 | Staff session expires after 8 hours absolute | integration | P0 | automated |
| AC-022 | Logout clears session and redirects to IdP logout | integration | P0 | automated |
| AC-023 | 6th concurrent session invalidates oldest | integration | P1 | automated |
| AC-024 | Session ID regenerated on authentication | integration | P0 | automated |
| AC-025 | JIT provisioning creates user and EnterpriseCustomerUser | integration | P0 | automated |
| AC-026 | Existing user linked to enterprise on first IdP login | integration | P0 | automated |
| AC-027 | PendingEnterpriseCustomerUser resolved on JIT provision | integration | P1 | automated |
| AC-028 | JIT provisioning does NOT grant is_staff from IdP | integration | P0 | automated |
| AC-029 | SCIM DELETE deactivates user and invalidates sessions | integration | P1 | automated |
| AC-030 | Deactivated user cannot re-authenticate | integration | P1 | automated |
| AC-031 | Scheduled deprovisioning sync deactivates removed users | integration | P1 | automated |
| AC-032 | IdP claim "academy-admin" grants enterprise_admin role | integration | P1 | automated |
| AC-033 | Role auto-revocation downgrades admin to learner | integration | P2 | semi |
| AC-034 | enterprise_openedx_operator role NOT granted by IdP | integration | P0 | automated |
| AC-035 | Platform admin allowlist enforced regardless of IdP | integration | P0 | automated |
| AC-036 | Unverified email triggers verification before access | integration | P2 | automated |
| AC-037 | All auth events logged with audit trail | integration | P0 | automated |
| AC-038 | Cross-tenant access attempt logged with severity=CRITICAL | integration | P0 | automated |
| AC-039 | 20 failed logins trigger rate limit and lockout | integration | P0 | automated |
| AC-040 | Open redirect blocked (next param validation) | integration | P0 | automated |
| AC-041 | HTTP auth endpoints redirect to HTTPS | integration | P0 | automated |
| AC-042 | verify-auth-surfaces.sh passes all checks | manual | P0 | manual |
| AC-043 | verify-enterprise-sso.sh validates tenant SSO config | manual | P1 | manual |
| AC-044 | Authentik policy_exception count is zero | manual | P0 | manual |
| AC-045 | Authenticated SSO canary succeeds for LMS and Studio | e2e | P0 | automated |

## Unit Tests

- SAML assertion XML signature verification logic
- SAML assertion timestamp validation (NotBefore, NotOnOrAfter, clock skew)
- SAML assertion ID replay prevention (cache lookup)
- SAML attribute mapping (email, first_name, last_name, username derivation)
- OIDC ID token signature verification (JWKS lookup)
- OIDC claim validation (iss, aud, exp, nonce)
- OIDC PKCE code_challenge generation and verification
- MFA TOTP code generation and validation
- Session idle timeout calculation
- Session absolute timeout enforcement
- Concurrent session limit enforcement
- JIT username collision resolution (append numeric suffix)
- SCIM user payload validation
- IdP claim-to-role mapping logic
- Platform admin allowlist enforcement
- Rate limiting per-IP bucket logic
- Rate limiting per-account bucket logic
- Open redirect URL validation (ALLOWED_HOSTS check)
- CSRF token generation and validation
- Session ID regeneration on login
- Password hashing (PBKDF2 or Argon2)

## Integration Tests

- SAML SP metadata endpoint accessibility
- SAML SP-initiated flow (AuthnRequest → IdP → Response → ACS → session)
- OIDC Authorization Code Flow with PKCE (authorize → token exchange → session)
- SAML assertion processing: valid signature, valid timestamps, correct issuer
- SAML assertion rejection: expired, replay, weak signature (SHA-1)
- OIDC token validation: valid signature, issuer, audience, expiration
- OIDC discovery endpoint (.well-known/openid-configuration)
- MFA enforcement on Django admin access (is_staff, is_superuser)
- MFA enrollment flow for newly elevated staff
- Session idle timeout (30 min staff, 120 min learner)
- Session absolute timeout (8 hours staff, 24 hours learner)
- Logout flow: session destroyed, cookies cleared, IdP logout redirect
- Concurrent session limit (6th login invalidates oldest)
- JIT provisioning: new user creation, EnterpriseCustomerUser linking
- JIT provisioning: existing user linking (no duplicate account)
- JIT provisioning: PendingEnterpriseCustomerUser resolution
- SCIM provisioning: POST /Users (create), PATCH /Users (update), DELETE /Users (deactivate)
- Scheduled deprovisioning sync (compare IdP user list → deactivate removed users)
- IdP claim-based role assignment (enterprise_admin, enterprise_learner)
- Role auto-revocation on claim removal
- Platform admin allowlist enforcement (overrides IdP claims)
- Cross-tenant access attempt (tenant A user tries tenant B resource → 403)
- Rate limiting: per-IP (20 failed logins → lockout), per-account (10 failed/hour)
- Open redirect prevention (malicious next param → default dashboard)
- HTTPS enforcement (HTTP → HTTPS redirect)
- Audit log generation for all auth events
- SAML metadata refresh (periodic task, 24-hour interval)
- OIDC token refresh before expiry
- Enterprise SSO canary test (LMS + Studio session validation)

## E2E Tests

- Enterprise user logs in via SAML IdP → authenticated session → accesses LMS
- Enterprise user logs in via OIDC IdP → authenticated session → accesses LMS
- Staff user logs in → MFA challenge → correct TOTP → Django admin access granted
- Newly promoted staff logs in → forced MFA enrollment → admin access after enrollment
- User with 5 active sessions logs in 6th time → oldest session invalidated
- User idle for 35 minutes → next request → session expired → redirected to login
- User clicks "Sign Out" → session destroyed → redirected to IdP logout → logged out everywhere
- New enterprise user (first-time login via IdP) → JIT provisioning → account created → linked to enterprise
- Enterprise user deactivated in IdP → scheduled sync runs → user marked inactive → cannot log in
- Enterprise admin claim added in IdP → user logs in → granted enterprise_admin role
- Enterprise admin claim removed in IdP → user logs in → downgraded to enterprise_learner
- Attacker attempts 21 failed logins → rate limit triggered → HTTP 429 → lockout for 5 minutes
- Attacker crafts open redirect URL → login succeeds → redirected to default dashboard (not malicious URL)
- Cross-tenant attack: user from tenant A's IdP attempts to access tenant B's data → HTTP 403 → logged with severity=CRITICAL

## Manual Verification

- Authentik MFA enforcement verification (scripts/infra/ensure-authentik-admin-mfa.sh --verify)
- SAML metadata exchange with pilot enterprise client (XML format, entity ID, ACS URL)
- OIDC discovery endpoint accessibility (.well-known/openid-configuration)
- IdP configuration in Django admin (SAML provider config, OIDC provider config)
- MFA enrollment UX (QR code display, backup codes, enrollment confirmation)
- Break-glass MFA recovery procedure (documented runbook test)
- SAML Single Logout (SLO) flow (logout → IdP logout redirect → logged out everywhere)
- OIDC RP-initiated logout flow (logout → end_session_endpoint redirect)
- Enterprise SSO verification script (verify-enterprise-sso.sh --tenant=acme-corp --env=prod)
- Authenticated SSO canary script (verify-authenticated-sso-canary.sh --env prod)
- Platform admin allowlist enforcement (MEREKA_PLATFORM_ADMIN_EMAILS)
- Session cookie flags (Secure, HttpOnly, SameSite=None)
- CSRF token validation (state-changing endpoints)
- Clock skew tolerance configuration (default 120 seconds)
- SAML assertion replay cache TTL (assertion validity window + skew)
- OIDC refresh token usage (before token expiry)

## Monitoring Verification

- Alert fires when cross-tenant access denial rate > 0 in 5 minutes
- Alert fires when SAML assertion processing p95 latency > 2 seconds
- Alert fires when mass account deactivation rate > 10/minute
- Warning fires when SAML metadata refresh fails for > 48 hours
- Warning fires when per-IP rate limit triggers > 50/hour
- Warning fires when MFA challenge failure rate > 5 in 10 minutes for single user
- Warning fires when concurrent staff session count > 20
- Info alert when JIT provisioning volume increases for any tenant
- Grafana dashboard "Authentication Overview" displays login volume by method
- Grafana dashboard "Enterprise SSO Health" displays per-tenant IdP status
- Grafana dashboard "Security Posture" displays rate limit triggers and cross-tenant denials
- Grafana dashboard "Account Lifecycle" displays JIT provisioning and deprovisioning events
- Prometheus scrapes auth-specific metrics (login_total, saml_assertion_processing_seconds, mfa_challenge_total)
