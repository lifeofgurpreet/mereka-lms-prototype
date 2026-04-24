---
title: "Authentication & SSO Enterprise Integration"
type: "feature_spec"
id: "SPEC-AUTH-SSO-ENTERPRISE"
status: "approved"
spec_class: "domain"
owner: "engineering"
vehicle: "talent_platform"
created: "2026-02-10"
last_reviewed: "2026-03-09"
review_due: "2026-06-09"
domain: "auth"
normativity: "normative"
last_updated: "2026-02-10"
version: "1.0.0"
depends_on:
  - "specs/multi-tenancy-architecture_spec.md"
  - "specs/secrets-management_spec.md"
supersedes: []
superseded_by: null
verification_sources:
  - "scripts/qa/verify-auth-hardening.sh"
  - "scripts/qa/verify-auth-surfaces.sh"
  - "scripts/qa/verify-authenticated-sso-canary.sh"
interfaces:
  - "saml"
  - "oidc"
tags:
  - "auth.oidc"
  - "auth.authorization.roles"
  - "tenant.isolation"
summary: "Normative contract for enterprise SSO, tenant-scoped identity federation, session behavior, and privileged-auth hardening across Mereka LMS."
links:
  related_docs:
    - "docs/ops/security/AUTH_HARDENING_SPEC.md"
    - "docs/reference/operations/AUTH_AND_PERMISSIONS.md"
    - "docs/ops/security/in-cluster-auth-verification.md"
    - "docs/adr/rfc/RFC-claim-based-role-sync.md"
    - "docs/guides/integrations/GOOGLE_OAUTH_SETUP.md"
    - "docs/ops/runbooks/TROUBLESHOOTING.md"
    - "docs/ops/security/ENTERPRISE_SSO_GUIDE.md"
  related_specs:
    - "specs/multi-tenancy-architecture_spec.md"
    - "specs/enterprise-microservices_spec.md"
    - "specs/secrets-management_spec.md"
    - "specs/multi-site-domains_spec.md"
    - "specs/k8s-deployment_spec.md"
    - "specs/observability-stack_spec.md"
    - "specs/disaster-recovery-business-continuity_spec.md"
    - "specs/cross-cutting-requirements_spec.md"
---

# Human Summary

## What we're building

A comprehensive enterprise authentication and Single Sign-On (SSO) integration layer for Mereka Academy that enables corporate clients to authenticate their learners and administrators through their own identity providers. The system federates identity management across SAML 2.0 and OpenID Connect (OIDC) protocols, supports per-tenant identity provider configuration, enforces multi-factor authentication for privileged operations, manages session lifecycles with configurable timeout policies, automates account provisioning and deprovisioning through identity provider signals, and maintains a complete audit trail for compliance.

Today, Mereka Academy uses Authentik as its central OIDC identity provider for platform-level SSO, with platform admin enforcement via an allowlist (`MEREKA_PLATFORM_ADMIN_EMAILS`) and idempotent hardening scripts. This spec extends the authentication architecture to support enterprise multi-tenancy: each enterprise client (tenant) can bring their own identity provider (Active Directory Federation Services, Okta, Azure AD/Entra ID, Google Workspace, PingFederate, or any standards-compliant SAML 2.0/OIDC provider), and the platform federates authentication while maintaining strict cross-tenant identity isolation.

The system builds on Open edX's native `third_party_auth` Django app and `EnterpriseCustomer` model (as specified in `specs/multi-tenancy-architecture_spec.md` and `specs/enterprise-microservices_spec.md`). It does not replace Authentik as the platform identity provider; rather, it positions Authentik as one of several identity sources, alongside per-tenant enterprise IdPs. The architecture follows a "hub-and-spoke" model: each tenant's IdP connects to the Open edX LMS directly via SAML or OIDC, and the `EnterpriseCustomer` model governs which IdP is authoritative for which tenant.

## Why it matters

Enterprise client onboarding cannot scale without SSO integration. Corporate IT departments require that their employees authenticate through their organization's identity infrastructure -- they will not accept individual username/password accounts managed by a third-party LMS. Without formal SAML/OIDC federation, every enterprise deal requires manual account creation, password distribution, and ongoing credential lifecycle management -- all of which are operationally expensive, error-prone, and non-compliant with enterprise security policies.

This spec also addresses critical security gaps: there is no formal contract for session timeout behavior, no specification for MFA enforcement beyond Authentik admins, no defined account deprovisioning workflow when an employee leaves a client organization, and no formalized role mapping from IdP claims to Open edX authorization. The existing auth hardening work (`docs/policies/operations/AUTH_HARDENING_SPEC.md`) is operational documentation describing what was built; this spec defines what must be true, with testable acceptance criteria.

## Success looks like

- An enterprise client's IT team can configure their IdP (ADFS, Okta, Azure AD, or OIDC-compliant provider) and have their employees authenticate to Mereka Academy within one business day of receiving the SAML/OIDC metadata exchange
- Learners authenticated via their enterprise IdP are automatically provisioned in the LMS and linked to their `EnterpriseCustomer`, with zero manual account creation
- When an employee is deactivated in the client's IdP, their Mereka Academy session is invalidated within the configured timeout window, and their account is marked inactive within 24 hours (via SCIM or scheduled sync)
- Platform administrators are required to complete MFA before accessing Django admin or any privileged endpoint
- All authentication events (login, logout, session creation, session expiry, IdP assertion processing, MFA challenges, account provisioning, account deprovisioning) are logged in a tamper-evident audit trail
- Cross-tenant identity isolation is absolute: an IdP assertion from tenant A's identity provider cannot create or link an account to tenant B
- The system passes penetration testing for OWASP Top 10 authentication and session management vulnerabilities

---

# Agent Contract

## Scope

- In scope:
  - SAML 2.0 Service Provider (SP) configuration for per-tenant enterprise IdPs
  - OIDC Relying Party (RP) configuration for per-tenant enterprise IdPs
  - Identity provider federation model: hub-and-spoke with per-tenant IdP routing
  - Multi-factor authentication (MFA) requirements by role and operation
  - Session management: creation, timeout, renewal, invalidation, and cross-domain behavior
  - Account provisioning: Just-In-Time (JIT) provisioning from IdP assertions
  - Account deprovisioning: SCIM 2.0 integration and scheduled sync deactivation
  - Role-based access control (RBAC): mapping IdP claims/attributes to Open edX roles
  - Audit logging: authentication events, authorization decisions, session lifecycle
  - Security hardening: token validation, assertion verification, replay prevention, CSRF/session binding
  - Threat modeling: attack vectors, mitigations, residual risk
  - Integration with existing Authentik OIDC setup (platform-level SSO)
  - Integration with existing platform admin enforcement (`MEREKA_PLATFORM_ADMIN_EMAILS`)
  - Secrets management for IdP credentials (SAML signing keys, OIDC client secrets)
  - Observability: authentication metrics, alerts, dashboards
  - Rollout plan for phased enterprise IdP onboarding

- Out of scope:
  - Building a custom identity provider (Mereka is always the Service Provider / Relying Party)
  - Replacing Authentik as the platform-level OIDC provider (Authentik remains for non-enterprise users and platform admins)
  - User self-registration flows for non-enterprise users (existing Open edX registration continues unchanged)
  - Social login providers (Google, Facebook, Apple) beyond what Open edX supports natively (already documented in `docs/integrations/GOOGLE_OAUTH_SETUP.md`)
  - Payment/billing integration for SSO-provisioned users (handled by ecommerce service)
  - Mobile app SSO flows (covered by `specs/proposals/mobile-apps-enterprise_spec.md`)
  - Biometric authentication or hardware token-specific implementation details

## Non-goals

- Building a centralized identity brokering layer that proxies all enterprise IdP connections through Authentik (each tenant IdP connects directly to the LMS via `third_party_auth`)
- Supporting IdP-initiated SSO flows at launch (SP-initiated only; IdP-initiated is a future enhancement due to CSRF complexity)
- Implementing real-time cross-IdP session synchronization (if a user is deactivated in IdP A, session in LMS is not immediately killed; it expires at the configured timeout)
- Supporting per-tenant MFA policies (MFA requirements are platform-wide by role, not per-tenant configurable)
- Building a self-service IdP configuration portal for tenant admins (IdP configuration is admin-mediated via Django admin and provisioning scripts)
- Implementing delegated administration where tenant admins manage their IdP settings directly (platform operators handle IdP configuration for v1)
- Supporting SAML artifact binding (only HTTP-POST and HTTP-Redirect bindings)
- Implementing OAuth 2.0 Device Authorization Grant for IoT/kiosk scenarios

## Assumptions

- The Open edX `third_party_auth` Django app supports multiple simultaneous SAML and OIDC providers with per-site configuration (confirmed in Open edX Redwood)
- Each enterprise client has an existing SAML 2.0 or OIDC-compliant identity provider that their IT team can configure (metadata exchange, redirect URIs, attribute mapping)
- Authentik (`auth0.mereka.io`) remains the platform-level identity provider for non-enterprise users and platform administrators
- Enterprise IdP linkage is represented by either `EnterpriseCustomerIdentityProvider` (preferred on newer enterprise builds) or the legacy `EnterpriseCustomer.identity_provider` field, and each tenant resolves to exactly one default IdP slug for login routing
- Open edX's `python-social-auth` pipeline supports custom steps for tenant-scoped JIT provisioning and role mapping
- The existing K8s secrets management pipeline (Infisical -> GCP Secret Manager -> ExternalSecrets -> K8s Secrets) can handle per-tenant SAML signing certificates and OIDC client secrets
- Enterprise clients will provide SAML metadata URLs (preferred) or static XML files; OIDC clients will provide discovery endpoint URLs
- The platform runs behind Cloudflare and Caddy, with SSL termination before the LMS application layer
- All assertion/token processing occurs server-side; no client-side token validation is performed for SSO flows

---

## Requirements

### Functional

#### Identity Provider Federation

- The system MUST support configuring multiple independent SAML 2.0 Identity Providers, one per enterprise tenant, using the Open edX `third_party_auth` `SAMLProviderConfig` model
- The system MUST support configuring multiple independent OIDC providers, one per enterprise tenant, using the Open edX `third_party_auth` `OAuth2ProviderConfig` model
- The system MUST support the following enterprise IdP platforms: Active Directory Federation Services (ADFS), Microsoft Entra ID (Azure AD), Okta, Google Workspace, PingFederate, and any standards-compliant SAML 2.0 or OIDC provider
- The system MUST associate each enterprise IdP configuration with exactly one `EnterpriseCustomer` via enterprise linkage models (`EnterpriseCustomerIdentityProvider` when available, with legacy `identity_provider` field compatibility)
- The system MUST support SP-initiated SAML SSO: the LMS generates an `AuthnRequest`, redirects the user to the tenant's IdP, and processes the `Response` at the Assertion Consumer Service (ACS) endpoint
- The system MUST support slug-based IdP routing: `https://{lms_host}/enterprise/login/{tenant_slug}` MUST redirect the user to the correct tenant's IdP (SAML or OIDC)
- The system MUST support the Open edX third-party-auth login hint mechanism: `/auth/login/{backend}/?auth_entry=login&next=...` with the correct backend name for each tenant's provider
- The system MUST maintain Authentik as the default OIDC provider for non-enterprise users, accessible via `/auth/login/oidc/`
- The system SHOULD support IdP-initiated SAML SSO in a future phase, with appropriate CSRF protections (unsolicited response handling)
- The system MAY support OIDC backchannel logout notifications (RFC 7009) for real-time session revocation when supported by the tenant's IdP

#### SAML 2.0 Specifics

- The system MUST generate and publish SP metadata at `https://{lms_host}/auth/saml/metadata.xml` containing the ACS endpoint, entity ID, signing certificate, and NameID format requirements
- The system MUST validate all incoming SAML assertions: XML signature verification, issuer validation against the configured `entity_id`, audience restriction matching the SP entity ID, and `NotBefore`/`NotOnOrAfter` time window enforcement
- The system MUST reject SAML assertions with a `NotOnOrAfter` timestamp in the past (clock skew tolerance: configurable, default 120 seconds)
- The system MUST support SAML attribute mapping: the administrator MUST be able to configure which SAML attributes map to Open edX user fields (email, first_name, last_name, username) per IdP
- The system MUST support encrypted SAML assertions (the SP MUST be able to decrypt assertions encrypted with the SP's public key)
- The system MUST support SAML assertion signing with RSA-SHA256 (minimum) and SHOULD support RSA-SHA384 and RSA-SHA512
- The system MUST reject assertions signed with SHA-1 (deprecated and insecure)
- The system MUST support both HTTP-POST and HTTP-Redirect bindings for the `AuthnRequest`
- The system MUST support automatic SAML metadata refresh: when a tenant provides a metadata URL (rather than static XML), the system MUST periodically fetch updated metadata (configurable interval, default: every 24 hours)
- The system MUST store per-tenant SAML signing/encryption private keys as K8s secrets via ExternalSecrets (per `specs/secrets-management_spec.md`)
- The system MUST generate unique SP entity IDs per tenant if multiple tenants share the same LMS host (entity ID format: `https://{lms_host}/saml/entity/{tenant_slug}`)
- The system MUST NOT reuse SAML signing keys across tenants; each tenant MUST have a dedicated key pair

#### OIDC Specifics

- The system MUST support OIDC Authorization Code Flow with PKCE (Proof Key for Code Exchange) for all enterprise OIDC integrations
- The system MUST validate OIDC ID tokens: signature verification using the IdP's JWKS endpoint, `iss` (issuer) claim matching the configured IdP issuer URL, `aud` (audience) claim matching the configured client ID, `exp` (expiration) claim enforcement, and `nonce` claim verification
- The system MUST support OIDC discovery via the `/.well-known/openid-configuration` endpoint from each tenant's IdP
- The system MUST store per-tenant OIDC client secrets as K8s secrets via ExternalSecrets (per `specs/secrets-management_spec.md`)
- The system MUST request the `openid`, `profile`, and `email` scopes at minimum; additional scopes (e.g., `groups`) SHOULD be configurable per tenant
- The system MUST support OIDC claim mapping: the administrator MUST be able to configure which claims map to Open edX user fields and enterprise roles per IdP
- The system MUST refresh OIDC tokens before expiry when the user has an active session (using the refresh token grant)
- The system MUST NOT store raw OIDC tokens in browser-accessible storage (cookies or localStorage); tokens MUST be managed server-side

#### Multi-Factor Authentication (MFA)

- The system MUST require MFA for all users with `is_staff=True` or `is_superuser=True` before accessing Django admin (`/admin/`) on any service (LMS, CMS, Discovery, Credentials, Ecommerce)
- The system MUST require MFA for Authentik admin access (already implemented via `scripts/infra/ensure-authentik-admin-mfa.sh`; this spec formalizes the requirement)
- The system SHOULD support MFA for enterprise admin portal access (users with `enterprise_admin` role) when the tenant's security policy requires it
- The system MUST support at minimum TOTP (Time-based One-Time Password, RFC 6238) as an MFA method
- The system SHOULD support WebAuthn/FIDO2 as an MFA method for hardware security keys
- The system MAY support push notification MFA via integration with enterprise MFA solutions (Duo, Microsoft Authenticator) in a future phase
- MFA enrollment MUST be enforced at next login for newly elevated users (when `is_staff` or `is_superuser` is set for the first time)
- The system MUST NOT allow MFA bypass for privileged accounts; there MUST be a documented break-glass procedure for MFA recovery
- The system MUST log all MFA challenge events: method used, success/failure, timestamp, IP address, user agent

#### Session Management

- The system MUST enforce session idle timeout: sessions MUST expire after a configurable period of inactivity (default: 30 minutes for staff/admin, 120 minutes for learners)
- The system MUST enforce absolute session timeout: sessions MUST expire after a configurable maximum duration regardless of activity (default: 8 hours for staff/admin, 24 hours for learners)
- The system MUST invalidate sessions on explicit logout: clicking "Sign Out" MUST destroy the server-side session, clear all session cookies, and redirect to the IdP's logout endpoint (SAML SLO or OIDC RP-initiated logout) if supported
- The system MUST support SAML Single Logout (SLO) when the enterprise tenant's IdP supports it (HTTP-Redirect binding)
- The system MUST support OIDC RP-initiated logout (redirect to the IdP's `end_session_endpoint`) when the enterprise tenant's IdP supports it
- The system MUST scope session cookies to the LMS domain (no wildcard domain that could leak to sibling subdomains), per the existing multisite cookie domain middleware (`MerekaCookieDomainMiddleware`)
- The system MUST set the `Secure`, `HttpOnly`, and `SameSite=None` flags on all session cookies when served over HTTPS (already implemented; this spec formalizes)
- The system MUST prevent concurrent session abuse: a user SHOULD be limited to a configurable maximum number of active sessions (default: 5) per platform; the oldest session MUST be invalidated when the limit is exceeded
- The system MUST regenerate the session ID after successful authentication to prevent session fixation attacks
- The system MUST bind CSRF tokens to sessions: CSRF token validation MUST fail if the session has expired or been invalidated
- Session data MUST be stored server-side in Redis (existing configuration); the system MUST NOT store sensitive session data in client-side cookies

#### Account Provisioning

- The system MUST support Just-In-Time (JIT) account provisioning: when a user authenticates via an enterprise IdP for the first time, the system MUST automatically create an LMS user account and link it to the enterprise tenant's `EnterpriseCustomer` via an `EnterpriseCustomerUser` record
- JIT provisioning MUST populate the following user fields from the IdP assertion/token: email, first_name, last_name; username MUST be derived from email (local part) with collision avoidance (append numeric suffix if taken)
- The system MUST support `PendingEnterpriseCustomerUser` resolution: if a pending invitation exists for the email address in the IdP assertion, the pending record MUST be resolved and the user linked to the enterprise tenant on first login
- The system MUST NOT auto-provision `is_staff` or `is_superuser` from IdP assertions; staff/superuser privileges MUST be granted only through the platform admin allowlist or explicit Django admin actions
- The system SHOULD support SCIM 2.0 (System for Cross-domain Identity Management) for automated user provisioning and deprovisioning from enterprise IdPs that support it (Azure AD, Okta)
- SCIM provisioning MUST support the following operations: `POST /Users` (create), `PUT /Users/{id}` (replace), `PATCH /Users/{id}` (update), `DELETE /Users/{id}` (deactivate)
- The system MUST validate that JIT-provisioned users are linked to the correct enterprise tenant based on the IdP that authenticated them; cross-tenant linking from JIT provisioning MUST be impossible
- The system MUST deduplicate accounts: if a user with the same email already exists in the LMS (from a prior registration or different tenant), JIT provisioning MUST link the existing account to the new tenant via a new `EnterpriseCustomerUser` record rather than creating a duplicate account

#### Account Deprovisioning

- The system MUST support account deactivation (not deletion) when an enterprise IdP signals user removal (via SCIM `DELETE` or scheduled sync)
- Account deactivation MUST set `is_active=False` on the LMS user, invalidate all active sessions, and remove the `EnterpriseCustomerUser` record linking the user to the tenant
- Account deactivation MUST NOT delete the user's LMS enrollments, progress, or completion records (these are LMS-level, not tenant-level; per `specs/multi-tenancy-architecture_spec.md`)
- The system MUST support scheduled deprovisioning sync: a daily job MUST compare the tenant's active user list (from the IdP, if available) against `EnterpriseCustomerUser` records and deactivate users no longer present in the IdP
- Deprovisioned users MUST NOT be able to re-authenticate via the tenant's IdP without re-provisioning (the `EnterpriseCustomerUser` record must be re-created)
- The system MUST log all deprovisioning actions with: user_id_hash, enterprise_customer_uuid, deprovisioning_source (SCIM, scheduled_sync, manual), timestamp, actor

#### Role-Based Access Control (RBAC)

- The system MUST support the following enterprise roles (per `specs/multi-tenancy-architecture_spec.md`):
  - `enterprise_admin`: full administrative access to a specific tenant's resources
  - `enterprise_learner`: learner-level access to a specific tenant's catalog and enrollment features
  - `enterprise_openedx_operator`: cross-tenant administrative access for platform operators
- The system MUST support IdP claim-based role assignment: when an IdP assertion/token includes a configured role claim (e.g., SAML attribute `groups` or OIDC claim `roles`), the system MUST map the claim value to the appropriate enterprise role
- Claim-based role assignment MUST be configurable per tenant: the administrator MUST be able to specify which claim name and which claim values map to `enterprise_admin` vs `enterprise_learner` for each IdP
- The system MUST NOT auto-elevate any user to `enterprise_openedx_operator` from IdP claims; this role MUST be assignable only by platform operators (superuser)
- The system MUST support role revocation: if a user's IdP claim no longer includes the admin role claim value on subsequent logins, the system SHOULD downgrade them to `enterprise_learner` (configurable: enable/disable auto-revocation per tenant)
- The system MUST maintain the existing platform admin enforcement mechanism (`MEREKA_PLATFORM_ADMIN_EMAILS` + `MerekaPlatformAdminMiddleware`) as a hard backstop, independent of IdP claim-based roles
- The system MUST enforce that role changes from IdP claims are logged as security events

#### Identity Verification Workflows

- The system MUST support email verification for JIT-provisioned accounts: if the IdP assertion does not include a verified email attribute (`email_verified=true` or equivalent), the system MUST send a verification email before granting full access
- The system SHOULD support identity proofing integration for high-stakes assessments (proctored exams) via the Open edX identity verification framework (per `specs/proposals/proctoring-integration_spec.md`)
- The system MUST support administrator-initiated identity verification: a platform operator MUST be able to manually verify a user's identity in Django admin and record the verification method and date
- The system MUST NOT allow unverified accounts to access enterprise-subsidized content (content gated behind subscription/license access policies)

### Non-Functional Requirements

#### Performance

- SAML assertion processing (XML parsing, signature verification, attribute extraction) MUST complete within 500ms at p95
- OIDC token exchange (authorization code for tokens) MUST complete within 1000ms at p95, excluding IdP response time
- JIT account provisioning (from assertion receipt to user record creation and enterprise linking) MUST complete within 2000ms at p95
- Session validation (check session exists, not expired, load user) MUST complete within 10ms at p95
- The system MUST support at least 100 concurrent SSO login flows without degraded performance
- SAML metadata refresh MUST NOT block authentication flows; metadata MUST be cached locally and refreshed asynchronously

#### Security

- All SAML assertions MUST be validated for XML signature, schema conformance, audience restriction, time validity, and replay prevention (via one-time assertion ID tracking)
- SAML assertion IDs MUST be tracked in a replay prevention cache (Redis, TTL = assertion validity window + clock skew tolerance) to prevent assertion replay attacks
- OIDC tokens MUST be validated for signature, issuer, audience, expiration, and nonce
- The system MUST NOT log raw SAML assertions, OIDC tokens, session IDs, passwords, or MFA secrets in any log stream
- All authentication-related secrets (SAML signing keys, OIDC client secrets, JWT signing keys) MUST be rotated at least annually, with a documented rotation procedure
- The system MUST enforce HTTPS for all authentication endpoints; HTTP requests to authentication endpoints MUST be redirected to HTTPS or rejected
- The system MUST implement rate limiting on authentication endpoints: maximum 20 failed login attempts per IP per 5-minute window, with exponential backoff lockout (5 minutes, 15 minutes, 60 minutes)
- The system MUST implement CSRF protection on all authentication state-changing endpoints (login form submission, logout, SAML ACS)
- The system MUST sanitize all user-supplied redirect URLs (`next` parameter) to prevent open redirect attacks: redirect targets MUST be validated against `ALLOWED_HOSTS` and `LOGIN_REDIRECT_WHITELIST`
- Cross-tenant IdP linking MUST be cryptographically prevented: the SAML `Issuer` or OIDC `iss` claim MUST be validated against the expected value for the target tenant before creating any `EnterpriseCustomerUser` record

#### Availability

- Authentication infrastructure (LMS auth endpoints, Authentik) MUST have availability of >= 99.9% (measured monthly)
- SAML metadata endpoints MUST respond within 5 seconds at p99
- If Authentik is unavailable, enterprise IdP SSO flows (SAML/OIDC direct to LMS) MUST continue to function independently (Authentik is not in the critical path for enterprise SSO)
- The system MUST support graceful degradation: if an enterprise IdP is unreachable, the user MUST see a clear error message rather than a 500 error, and the failure MUST NOT affect other tenants' authentication

#### Compliance

- All authentication events MUST be logged in a tamper-evident audit trail retained for at least 2 years
- The system MUST support generating per-tenant authentication activity reports (logins, logouts, failed attempts, MFA events) on demand for compliance audits
- The system MUST comply with OWASP Authentication and Session Management best practices (OWASP ASVS v4.0, sections V2 and V3)
- PII in authentication logs MUST be hashed or pseudonymized (user_id_hash, not raw email) per `specs/enterprise-microservices_spec.md`

---

## Acceptance Criteria

### Identity Provider Federation

- [ ] AC-001: Given an enterprise tenant "Acme Corp" with an Okta SAML IdP configured, when a user navigates to `https://academyv2.mereka.io/enterprise/login/acme-corp`, then they are redirected to Acme's Okta IdP login page
- [ ] AC-002: Given an enterprise tenant "Beta Inc" with an Azure AD OIDC provider configured, when a user navigates to `https://academyv2.mereka.io/enterprise/login/beta-inc`, then they are redirected to Beta's Azure AD authorization endpoint with PKCE parameters
- [ ] AC-003: Given two enterprise tenants with different IdPs, when a user authenticates via Acme's IdP, then the resulting `EnterpriseCustomerUser` record links to Acme only; no link to Beta is created
- [ ] AC-004: Given Authentik is configured as the default OIDC provider, when a non-enterprise user navigates to `/auth/login/oidc/`, then they are redirected to Authentik's authorize endpoint (existing behavior preserved)
- [ ] AC-005: Given a tenant with SAML IdP configured, when the LMS SP metadata is requested at `/auth/saml/metadata.xml`, then valid SP metadata is returned containing the ACS URL, entity ID, and signing certificate

### SAML Security

- [ ] AC-006: Given a valid SAML assertion from Acme's IdP, when the assertion signature is verified and time window is valid, then the user is authenticated and a session is created
- [ ] AC-007: Given a SAML assertion with an expired `NotOnOrAfter` timestamp (beyond clock skew tolerance), when processed, then the assertion is rejected and a security event is logged
- [ ] AC-008: Given a SAML assertion that has already been processed (replay), when the same assertion ID is submitted again, then the assertion is rejected with "Assertion replay detected" and a security event is logged
- [ ] AC-009: Given a SAML assertion signed with SHA-1, when processed, then the assertion is rejected and a security event is logged indicating weak signature algorithm
- [ ] AC-010: Given a SAML assertion with an `Issuer` that does not match any configured tenant IdP entity ID, when processed, then the assertion is rejected and a security event is logged

### OIDC Security

- [ ] AC-011: Given an OIDC authorization code from Beta's Azure AD, when the token exchange is performed, then the ID token `iss` claim matches Beta's configured issuer URL and the `aud` claim matches the configured client ID
- [ ] AC-012: Given an OIDC ID token with an expired `exp` claim, when validated, then the token is rejected and authentication fails with a clear error message
- [ ] AC-013: Given an OIDC flow, when the authorization request is sent, then it includes `code_challenge` and `code_challenge_method=S256` parameters (PKCE)

### Multi-Factor Authentication

- [ ] AC-014: Given a user with `is_staff=True`, when they attempt to access `/admin/` on the LMS, then they are prompted for MFA before gaining access
- [ ] AC-015: Given a user with `is_superuser=True`, when they attempt to access `/admin/` on any service (LMS, CMS, Discovery, Credentials, Ecommerce), then they are prompted for MFA before gaining access
- [ ] AC-016: Given an Authentik admin, when they attempt to access the Authentik admin UI, then they are required to complete MFA (verified by `scripts/infra/ensure-authentik-admin-mfa.sh --verify`)
- [ ] AC-017: Given a newly elevated staff user, when they next log in, then they are forced to enroll in MFA before accessing any staff-only functionality
- [ ] AC-018: Given an MFA challenge, when the user submits a correct TOTP code, then access is granted and the MFA event is logged with method=TOTP, outcome=success

### Session Management

- [ ] AC-019: Given a staff user session, when the session has been idle for more than 30 minutes (configurable), then the next request returns HTTP 302 to the login page
- [ ] AC-020: Given a learner session, when the session has been idle for more than 120 minutes (configurable), then the next request returns HTTP 302 to the login page
- [ ] AC-021: Given a staff user session, when the session has been active for more than 8 hours (configurable) regardless of activity, then the next request returns HTTP 302 to the login page
- [ ] AC-022: Given a user clicks "Sign Out", when the logout completes, then: (a) the server-side session is destroyed, (b) session cookies are cleared, (c) the user is redirected to the IdP's logout endpoint if SLO/RP-initiated logout is supported
- [ ] AC-023: Given a user with 5 active sessions, when they log in a 6th time, then the oldest session is invalidated
- [ ] AC-024: Given a successful authentication, when the session is created, then the session ID is regenerated (different from any pre-authentication session ID)

### Account Provisioning

- [ ] AC-025: Given a first-time user authenticating via Acme's SAML IdP with email `alice@acme.com`, when the assertion is processed, then: (a) an LMS user account is created with email=`alice@acme.com`, (b) an `EnterpriseCustomerUser` record links the user to Acme's `EnterpriseCustomer`, (c) no manual admin action is required
- [ ] AC-026: Given an existing LMS user `bob@acme.com` (registered previously), when Bob authenticates via Acme's IdP for the first time, then the existing account is linked to Acme via a new `EnterpriseCustomerUser` record (no duplicate account created)
- [ ] AC-027: Given a `PendingEnterpriseCustomerUser` for `carol@acme.com` in Acme's tenant, when Carol authenticates via Acme's IdP and her LMS account is created, then the pending record is resolved and she is linked to Acme
- [ ] AC-028: Given JIT provisioning of a user via Acme's IdP, when the `EnterpriseCustomerUser` record is created, then the user is NOT granted `is_staff` or `is_superuser` regardless of IdP assertion content

### Account Deprovisioning

- [ ] AC-029: Given an active user `alice@acme.com` linked to Acme, when a SCIM `DELETE /Users/{alice_id}` request is received from Acme's IdP, then: (a) `alice.is_active` is set to `False`, (b) all of Alice's active sessions are invalidated, (c) the `EnterpriseCustomerUser` record is removed
- [ ] AC-030: Given Alice has been deactivated, when Alice attempts to authenticate via Acme's IdP, then authentication fails with "Your account has been deactivated. Contact your organization administrator."
- [ ] AC-031: Given a daily deprovisioning sync job runs for Acme, when Alice is no longer in Acme's active user list, then Alice is deactivated within 24 hours

### Role-Based Access Control

- [ ] AC-032: Given Acme's IdP is configured to map SAML attribute `groups=["academy-admin"]` to `enterprise_admin`, when a user authenticates with that attribute, then they are granted `enterprise_admin` role for Acme's tenant
- [ ] AC-033: Given a user previously had `enterprise_admin` role via IdP claim, when they next authenticate without the admin claim (auto-revocation enabled for Acme), then they are downgraded to `enterprise_learner` and the role change is logged
- [ ] AC-034: Given any IdP assertion, when it includes claims that would map to `enterprise_openedx_operator`, then the claim is ignored and the user is NOT elevated to operator (operator role is platform-only)
- [ ] AC-035: Given the platform admin allowlist includes `gurpreet@biji-biji.com`, when Gurpreet authenticates via any IdP, then `is_staff` and `is_superuser` are enforced by the `MerekaPlatformAdminMiddleware` regardless of IdP claims

### Identity Verification

- [ ] AC-036: Given a JIT-provisioned user whose IdP assertion does not include `email_verified=true`, when they first access the platform, then they are prompted to verify their email before accessing enterprise-subsidized content

### Audit Logging

- [ ] AC-037: Given any authentication event (login, logout, failed attempt, MFA challenge, JIT provisioning, deprovisioning), when it occurs, then an audit log entry is written with: event_type, user_id_hash, enterprise_customer_uuid (if applicable), ip_address_hash, user_agent_hash, timestamp, outcome, idp_slug
- [ ] AC-038: Given a cross-tenant access attempt (user from tenant A's IdP attempting to link to tenant B), when the attempt is blocked, then a security audit event is logged with severity=CRITICAL

### Security Hardening

- [ ] AC-039: Given 20 failed login attempts from the same IP within 5 minutes, when the 21st attempt is made, then it is rejected with HTTP 429 and the IP is locked out for 5 minutes
- [ ] AC-040: Given a login redirect URL (`next` parameter) pointing to an external domain not in `ALLOWED_HOSTS`, when the login completes, then the redirect is blocked and the user is sent to the default dashboard instead
- [ ] AC-041: Given authentication endpoints, when accessed over HTTP (non-TLS), then the request is redirected to HTTPS (HTTP 301)

### Verification Scripts

- [ ] AC-042: Given all enterprise IdPs are configured, when `./scripts/qa/verify-auth-surfaces.sh prod` runs, then all existing checks pass plus new checks for enterprise SAML/OIDC endpoints
- [ ] AC-043: Given enterprise SSO is configured for a tenant, when `./scripts/qa/verify-enterprise-sso.sh --tenant=acme-corp --env=prod` runs, then: (a) the tenant's IdP metadata is reachable, (b) the enterprise login URL redirects correctly, (c) SP metadata is valid
- [ ] AC-044: Given Authentik is the default OIDC provider, when Authentik policies execute during `/application/o/authorize` for `client_id=mereka-lms`, then there are **zero** `policy_exception` events in the last 6 hours (verified by `./scripts/qa/audit-authentik-policy-exceptions.sh --since 6h`)
- [ ] AC-045: Given valid canary credentials exist for both a learner user and a Studio-access staff user, when the credentialed canary runs, then: (a) LMS session validates (`/api/user/v1/me=200`), (b) MFEs do not loop back to `/authn/login`, and (c) Studio `/home/` loads without `500` or error page (verified by `./scripts/qa/verify-authenticated-sso-canary.sh --env prod` and workflow `authenticated-sso-canary.yml`)

---

## Edge Cases

### SAML/OIDC Processing Failures

- **IdP unreachable during login**: If a tenant's IdP is unreachable (DNS failure, timeout, HTTP error), the system MUST display a user-friendly error message: "Your organization's login service is temporarily unavailable. Please try again later or contact your IT administrator." The system MUST NOT fall back to a different IdP or show a generic 500 error. The failure MUST be logged with the IdP slug and error details. Other tenants' authentication MUST NOT be affected
- **Malformed SAML assertion**: If the SAML assertion XML is malformed (invalid XML, missing required elements), the system MUST reject it, log the raw error (without the full assertion content), and display: "Authentication failed. Please try again or contact your IT administrator." The system MUST NOT crash or expose XML parsing errors to the user
- **Clock skew beyond tolerance**: If the IdP's clock is skewed beyond the configured tolerance (default 120 seconds), assertions will be rejected. The system MUST log the skew amount (difference between assertion timestamp and server time) to aid troubleshooting. Platform operators MUST be able to increase the tolerance per tenant via Django admin
- **Missing required attributes in assertion**: If the IdP assertion is missing required attributes (email at minimum), the system MUST reject the authentication, log the available attributes (names only, not values), and display: "Your organization's identity provider did not supply the required information (email). Please contact your IT administrator."
- **Email domain mismatch**: If a user authenticates via Acme's IdP but their email domain does not match Acme's configured allowed domains (if configured), the system SHOULD log a warning but MUST still process the authentication (enterprise employees may use personal email addresses or subsidiary domains). A strict mode that rejects domain mismatches SHOULD be configurable per tenant

### Session Edge Cases

- **Session store failure (Redis down)**: If Redis is unavailable, the system MUST fail open for existing authenticated sessions cached in the application layer but MUST reject new login attempts (cannot create sessions). The system MUST alert immediately (Redis availability is a dependency of all session operations)
- **Cross-domain session behavior**: Sessions are domain-scoped. A user authenticated on `academyv2.mereka.io` is NOT authenticated on `academy.biji-biji.com`. This is expected behavior. If a tenant has multiple domains, the user must authenticate separately on each root domain unless they are subdomains of the same root (where cookie domain scoping applies)
- **Concurrent MFA enrollment**: If a user has MFA enrollment forced and attempts to log in from multiple devices simultaneously, each device MUST independently complete MFA enrollment. The system MUST NOT create duplicate TOTP devices; if the enrollment race condition is detected, the second device MUST use the already-enrolled TOTP device
- **Session invalidation during active request**: If a user's session is invalidated (by admin action, deprovisioning, or concurrent session limit) while they have an in-flight request, the response MUST complete normally but subsequent requests MUST redirect to login

### Provisioning Edge Cases

- **JIT provisioning race condition**: If the same user authenticates via the same IdP simultaneously from two devices, JIT provisioning MUST be idempotent. The system MUST handle the race condition where two threads attempt to create the same user account; the second thread MUST detect the already-created account and link it rather than raising a database integrity error
- **Email collision across tenants**: If `alice@example.com` exists as a user and authenticates via tenant A's IdP, then later authenticates via tenant B's IdP (same email, different tenant), the system MUST link the existing user to tenant B via a new `EnterpriseCustomerUser` record (not create a duplicate). The user will have dual-tenant membership
- **Username collision during JIT provisioning**: If the derived username (from email local part) is already taken, the system MUST append a numeric suffix (e.g., `alice1`, `alice2`) until a unique username is found. The system MUST NOT fail provisioning due to username collision
- **SCIM user not found**: If a SCIM `DELETE` request references a user ID that does not exist in the LMS, the system MUST return HTTP 404 (per SCIM 2.0 spec) and log a warning. The system MUST NOT return 500

### IdP Configuration Edge Cases

- **Duplicate IdP entity IDs**: If two tenants attempt to configure the same IdP entity ID (which should not happen in practice), the system MUST reject the second configuration with a clear error: "This IdP entity ID is already configured for another tenant"
- **IdP metadata rotation**: When an IdP rotates its signing certificate, the system MUST support a rollover period where both the old and new certificates are accepted (via automatic metadata refresh). The system MUST NOT reject assertions signed with the new certificate before the metadata refresh cycle completes
- **SAML signing key rotation**: When the SP's SAML signing key is rotated, the new key MUST be published in the SP metadata immediately. The old key SHOULD continue to be accepted for verification (not signing) for a configurable grace period (default: 7 days) to allow IdPs to fetch updated metadata

### Rate Limiting Edge Cases

- **Legitimate high-volume login (e.g., training event)**: If a tenant has a scheduled event where 500+ users log in within 5 minutes, the per-IP rate limit MUST NOT block legitimate users behind a corporate NAT/proxy. The system SHOULD support IP allowlisting per tenant for known corporate egress IPs
- **Brute force from distributed IPs**: Per-IP rate limiting does not protect against distributed brute force attacks. The system SHOULD implement per-account rate limiting (maximum 10 failed attempts per account per hour) in addition to per-IP limits

### Retry/Timeout Behavior

- **SAML metadata refresh timeout**: If the metadata URL times out, the system MUST continue using the cached metadata. The system MUST NOT delete cached metadata on refresh failure. A warning alert MUST fire if metadata has not been successfully refreshed for more than 48 hours
- **OIDC token exchange timeout**: If the IdP's token endpoint times out (>5 seconds), the system MUST display: "Login is taking longer than expected. Please try again." The system MUST NOT retry the token exchange automatically (to avoid double-spending authorization codes)

### Idempotency

- **JIT provisioning idempotency**: Repeated authentication with the same IdP assertion data MUST NOT create duplicate users or duplicate `EnterpriseCustomerUser` records
- **SCIM provisioning idempotency**: Repeated SCIM `POST /Users` with the same `externalId` MUST return the existing user (HTTP 409 or idempotent 200, per SCIM spec) rather than creating duplicates
- **Role sync idempotency**: Processing the same role claim value multiple times MUST NOT create duplicate role assignments; role assignment MUST be idempotent

---

## Observability

### Logs

- **Authentication event log**: Every authentication attempt MUST be logged with: `event_type` (login_attempt, login_success, login_failure, logout, session_created, session_expired, session_invalidated), `user_id_hash`, `enterprise_customer_uuid`, `idp_slug`, `auth_method` (saml, oidc, native, authentik), `ip_address_hash`, `timestamp`, `outcome` (success, failure, error), `failure_reason` (if applicable: expired_assertion, invalid_signature, replay_detected, mfa_failed, account_disabled, rate_limited)
- **MFA event log**: Every MFA event MUST be logged with: `event_type` (mfa_challenge, mfa_success, mfa_failure, mfa_enrollment, mfa_recovery), `user_id_hash`, `mfa_method` (totp, webauthn), `timestamp`, `ip_address_hash`
- **Provisioning event log**: Every provisioning/deprovisioning action MUST be logged with: `event_type` (jit_provision, scim_create, scim_update, scim_delete, scheduled_deactivation), `user_id_hash`, `enterprise_customer_uuid`, `source` (idp_assertion, scim, manual, scheduled_sync), `timestamp`, `outcome`
- **Security event log**: Cross-tenant access attempts, assertion replay attempts, weak signature rejections, rate limit triggers, and open redirect blocks MUST be logged at WARN or ERROR level with structured fields for alerting
- **Sensitive data rule**: Logs MUST NOT contain raw SAML assertions, OIDC tokens, passwords, MFA secrets, session IDs, or unmasked email addresses. User identification MUST use `user_id_hash` (SHA-256 of user ID)

### Metrics

- `auth_login_total` (counter, labels: `auth_method`, `enterprise_customer_uuid`, `outcome`, `idp_slug`) -- total login attempts by method and outcome
- `auth_login_latency_seconds` (histogram, labels: `auth_method`, `idp_slug`) -- end-to-end login latency (from redirect to session creation)
- `auth_saml_assertion_processing_seconds` (histogram, labels: `idp_slug`) -- SAML assertion processing time
- `auth_oidc_token_exchange_seconds` (histogram, labels: `idp_slug`) -- OIDC token exchange latency
- `auth_jit_provisioning_total` (counter, labels: `enterprise_customer_uuid`, `outcome`) -- JIT provisioning events
- `auth_jit_provisioning_latency_seconds` (histogram) -- JIT provisioning latency
- `auth_session_active_count` (gauge, labels: `user_role` [staff, learner]) -- number of active sessions by role
- `auth_session_expired_total` (counter, labels: `expiry_type` [idle, absolute, manual, concurrent_limit]) -- session expiry events by type
- `auth_mfa_challenge_total` (counter, labels: `mfa_method`, `outcome`) -- MFA challenge events
- `auth_rate_limit_triggered_total` (counter, labels: `limit_type` [per_ip, per_account]) -- rate limit trigger events
- `auth_saml_metadata_refresh_total` (counter, labels: `idp_slug`, `outcome` [success, failure]) -- SAML metadata refresh outcomes
- `auth_scim_operations_total` (counter, labels: `enterprise_customer_uuid`, `operation` [create, update, delete], `outcome`) -- SCIM operation events
- `auth_deprovisioning_total` (counter, labels: `enterprise_customer_uuid`, `source` [scim, scheduled_sync, manual]) -- deprovisioning events
- `auth_cross_tenant_access_denied_total` (counter) -- cross-tenant access denial events (any non-zero value is investigation-worthy)

### Alerts

- **Critical**: `auth_cross_tenant_access_denied_total` rate > 0 in any 5-minute window -- potential cross-tenant attack or misconfiguration; investigate immediately
- **Critical**: `auth_saml_assertion_processing_seconds` p95 > 2 seconds -- SAML processing degradation affecting user experience
- **Critical**: `auth_login_total{outcome="failure",failure_reason="account_disabled"}` rate > 10/minute for any tenant -- mass account deactivation or misconfiguration
- **Warning**: `auth_saml_metadata_refresh_total{outcome="failure"}` for any IdP for > 48 hours -- stale metadata may cause authentication failures after IdP certificate rotation
- **Warning**: `auth_rate_limit_triggered_total{limit_type="per_ip"}` > 50/hour -- potential brute force attack in progress
- **Warning**: `auth_mfa_challenge_total{outcome="failure"}` > 5 for a single user in 10 minutes -- potential account compromise or user lockout
- **Warning**: `auth_session_active_count{user_role="staff"}` > 20 -- unusual number of concurrent staff sessions; may indicate credential compromise
- **Info**: `auth_jit_provisioning_total` increases for any tenant -- new users being provisioned (expected during onboarding)

### Dashboards

- **Authentication Overview**: Login volume by method (SAML, OIDC, Authentik, native), success/failure rates, login latency distribution, active session count, MFA adoption rate
- **Enterprise SSO Health**: Per-tenant IdP status (metadata freshness, login success rate, provisioning volume), SAML/OIDC error breakdown, IdP latency comparison
- **Security Posture**: Rate limit triggers, cross-tenant access denials, assertion replay attempts, weak signature rejections, MFA failure rates, brute force indicators
- **Account Lifecycle**: JIT provisioning volume, SCIM operations, deprovisioning events, pending user resolution, multi-tenant user count

---

## Rollout & Rollback

### Rollout Plan

#### Phase 0: Foundation (Week 1-2)

1. Audit existing `third_party_auth` configuration and ensure all SAML/OIDC infrastructure is present in the Tutor build
2. Create per-tenant SAML key pair generation script (`scripts/tenants/generate-saml-keypair.sh`)
3. Create IdP configuration helper script (`scripts/tenants/configure-tenant-idp.sh`) wrapping Django management commands
4. Extend `scripts/qa/verify-auth-surfaces.sh` with enterprise SSO endpoint checks
5. Create `scripts/qa/verify-enterprise-sso.sh` for per-tenant SSO verification
6. Document SAML metadata exchange process for enterprise client IT teams
7. Create ExternalSecret templates for per-tenant SAML/OIDC secrets

#### Phase 1: MFA and Session Hardening (Week 3-4)

1. Implement MFA enforcement middleware for Django admin on all services
2. Configure session idle and absolute timeout policies
3. Implement concurrent session limiting
4. Deploy session ID regeneration on authentication
5. Deploy rate limiting on authentication endpoints
6. Verify all existing auth hardening checks pass (`scripts/qa/verify-auth-hardening.sh --env both`)
7. Run OWASP authentication verification checklist

#### Phase 2: First Enterprise IdP (Week 5-6)

1. Onboard pilot enterprise client's IdP (SAML or OIDC) in dev environment
2. Configure JIT provisioning pipeline for the pilot tenant
3. Configure role claim mapping for the pilot tenant
4. Test SP-initiated SSO end-to-end
5. Test JIT provisioning with new and existing users
6. Test session behavior (idle timeout, absolute timeout, logout)
7. Deploy to production for the pilot tenant behind feature flag (`ENABLE_ENTERPRISE_SSO_{TENANT_SLUG}`)
8. Monitor for 1 week

#### Phase 3: SCIM and Deprovisioning (Week 7-8)

1. Implement SCIM 2.0 endpoint (`/scim/v2/`) if pilot tenant's IdP supports SCIM
2. Implement scheduled deprovisioning sync job
3. Test account deactivation and session invalidation
4. Test re-provisioning after deactivation
5. Deploy deprovisioning features behind feature flag

#### Phase 4: Scale (Week 9+)

1. Onboard 2-3 additional enterprise clients
2. Run cross-tenant isolation tests (per `specs/multi-tenancy-architecture_spec.md`)
3. Load test with simulated concurrent SSO flows from multiple tenants
4. Enable all enterprise SSO observability alerts and dashboards
5. Remove per-tenant feature flags for stable integrations
6. Document enterprise SSO runbook (`docs/runbooks/auth-sso-enterprise-runbook.md`)

### Feature Flags

- `ENABLE_ENTERPRISE_SSO` -- global gate for enterprise SSO features (default: off; enable after Phase 1)
- `ENABLE_ENTERPRISE_SSO_{TENANT_SLUG}` -- per-tenant gate for individual IdP integrations (default: off; enable per tenant after Phase 2 testing)
- `ENABLE_MFA_ENFORCEMENT` -- gate for MFA enforcement on Django admin (default: off; enable after Phase 1 step 1)
- `ENABLE_SESSION_HARDENING` -- gate for idle/absolute timeout and concurrent session limits (default: off; enable after Phase 1 step 2-4)
- `ENABLE_AUTH_RATE_LIMITING` -- gate for authentication endpoint rate limiting (default: off; enable after Phase 1 step 5)
- `ENABLE_SCIM_PROVISIONING` -- gate for SCIM 2.0 endpoint (default: off; enable after Phase 3)
- `ENABLE_CLAIM_BASED_ROLE_SYNC` -- gate for IdP claim-to-role mapping (default: off; enable after Phase 2 role testing)
- `ENABLE_AUTO_ROLE_REVOCATION` -- gate for auto-revoking admin role when claim disappears (default: off; enable cautiously)

### Backward Compatibility

- Existing Authentik OIDC SSO (`/auth/login/oidc/`) MUST continue to function unchanged for non-enterprise users
- Existing native Open edX login (`/login`) MUST continue to function for users without enterprise IdP
- Existing platform admin enforcement (`MEREKA_PLATFORM_ADMIN_EMAILS` + `MerekaPlatformAdminMiddleware`) MUST remain active as a hard backstop
- Existing session behavior for non-enterprise users MUST NOT change until `ENABLE_SESSION_HARDENING` is enabled
- All existing verification scripts (`verify-auth-surfaces.sh`, `verify-auth-hardening.sh`, `audit-auth-access.sh`) MUST continue to pass after enterprise SSO is enabled
- The `MFE_CONFIG["DISABLE_ENTERPRISE_LOGIN"]` setting MUST be toggled to `False` when enterprise SSO is ready for the first tenant; until then, the authn MFE hides enterprise login buttons

### Rollback Steps

#### Disable Enterprise SSO for a Specific Tenant

1. Set `ENABLE_ENTERPRISE_SSO_{TENANT_SLUG}=false` in LMS settings
2. Users for that tenant will be redirected to the default login page (Authentik or native)
3. Existing sessions remain active until they expire
4. No data loss; `EnterpriseCustomerUser` records and IdP configuration are preserved
5. Re-enable when issues are resolved

#### Disable All Enterprise SSO

1. Set `ENABLE_ENTERPRISE_SSO=false` in LMS settings
2. All enterprise SSO login routes will return 404 or redirect to default login
3. Authentik OIDC and native login continue to work
4. Users can log in via `/auth/login/oidc/` (Authentik) or `/login` (native)
5. Re-enable after investigation

#### Disable MFA Enforcement

1. Set `ENABLE_MFA_ENFORCEMENT=false` in LMS settings
2. Django admin access no longer requires MFA
3. Authentik admin MFA remains independently enforced (via Authentik policies, not LMS)
4. Re-enable after resolving MFA infrastructure issues

#### Disable Session Hardening

1. Set `ENABLE_SESSION_HARDENING=false` in LMS settings
2. Sessions revert to Open edX default timeout behavior
3. Concurrent session limits are removed
4. Re-enable after tuning timeout values

#### Emergency: Suspected IdP Compromise

1. Immediately disable the affected tenant's IdP: set `enabled=False` on the `SAMLProviderConfig` or `OAuth2ProviderConfig` in Django admin
2. Invalidate all sessions for users linked to the affected tenant: `python manage.py lms clear_enterprise_sessions --enterprise-uuid={uuid}`
3. Notify the affected tenant's IT team
4. Rotate the SP SAML signing key or OIDC client secret
5. Audit all authentication events for the tenant in the past 72 hours
6. Re-enable after the tenant's IT team confirms their IdP is secured
7. File a P0 incident report

---

## Threat Model

### STRIDE Analysis

| Threat | Category | Attack Vector | Mitigation | Residual Risk |
|--------|----------|---------------|------------|---------------|
| TM-001: Forged SAML assertion | Spoofing | Attacker crafts a SAML assertion with a valid-looking structure but invalid signature | Mandatory XML signature verification on every assertion; reject unsigned assertions; reject SHA-1 signatures | Low: requires compromising the IdP's signing key |
| TM-002: SAML assertion replay | Spoofing | Attacker captures a valid assertion and replays it | One-time assertion ID tracking in Redis cache (TTL = validity window + skew); reject duplicate assertion IDs | Low: requires real-time interception and replay within validity window |
| TM-003: Cross-tenant IdP linking | Spoofing | Attacker configures a rogue IdP to emit assertions that link users to a different tenant | Validate SAML `Issuer` and OIDC `iss` against the expected value for the target tenant; reject mismatches before any user record creation | Very low: requires access to tenant IdP configuration in Django admin |
| TM-004: Session hijacking | Tampering | Attacker steals session cookie via XSS or network interception | `HttpOnly`, `Secure`, `SameSite=None` flags on session cookies; HTTPS enforcement; CSP headers; session regeneration on auth | Low: requires XSS vulnerability or MITM |
| TM-005: CSRF on auth endpoints | Tampering | Attacker tricks authenticated user into performing auth state changes | CSRF token validation on all state-changing auth endpoints; CSRF bound to session; `SameSite` cookie policy | Very low: standard Django CSRF protection |
| TM-006: Open redirect via `next` param | Tampering | Attacker crafts login URL with malicious redirect target | Validate redirect URLs against `ALLOWED_HOSTS` and `LOGIN_REDIRECT_WHITELIST`; reject external domains | Very low: standard mitigation |
| TM-007: Brute force login | Elevation of Privilege | Attacker attempts many password combinations | Per-IP rate limiting (20/5min); per-account rate limiting (10/hour); exponential backoff lockout; MFA for privileged accounts | Low: distributed brute force harder to stop; MFA is the primary defense |
| TM-008: Privilege escalation via IdP claims | Elevation of Privilege | Compromised IdP emits claims that grant `is_superuser` | IdP claims MUST NOT map to `is_superuser` or `is_staff`; operator role assignable only by platform operators; platform admin allowlist is independent of IdP claims | Very low: defense-in-depth with hard backstop |
| TM-009: Denial of service on SAML/OIDC endpoints | Denial of Service | Attacker floods authentication endpoints | Rate limiting; WAF rules at Cloudflare; SAML metadata caching (async refresh); IdP-specific rate limits | Medium: sustained DDoS requires Cloudflare-level mitigation |
| TM-010: IdP metadata poisoning | Tampering | Attacker compromises the tenant's metadata URL and serves malicious metadata | Metadata refresh should validate certificate chain; alert on metadata content changes; manual approval for significant metadata changes (new signing cert) | Medium: requires compromising the metadata URL |
| TM-011: SCIM endpoint abuse | Elevation of Privilege | Attacker discovers SCIM endpoint and sends unauthorized provisioning requests | SCIM endpoint MUST require authentication (bearer token per tenant); rate limit SCIM operations; log all SCIM requests | Low: requires stealing SCIM bearer token |
| TM-012: Token leakage in logs/URLs | Information Disclosure | Tokens or assertions accidentally logged or passed in URL query strings | Assertions/tokens MUST NOT be logged; OIDC authorization codes transmitted via POST (not GET where possible); sensitive fields redacted in error responses | Very low: addressed by design |

---

## Open Questions

1. **MFA provider choice**: Should MFA be enforced via Authentik's MFA capabilities (for users who authenticate through Authentik), via a Django-native TOTP app (for all users regardless of auth path), or via both? Authentik MFA only protects users who authenticate through Authentik; enterprise SSO users bypass Authentik entirely. A Django-native MFA layer (e.g., `django-otp` or `django-two-factor-auth`) would cover all authentication paths but adds operational complexity. Need security team input.

2. **SCIM endpoint authentication**: Should the SCIM endpoint use per-tenant bearer tokens (simplest), mutual TLS, or OAuth 2.0 client credentials? Different enterprise IdPs support different SCIM authentication methods. Okta uses bearer tokens; Azure AD supports both bearer tokens and OAuth 2.0. Need to survey pilot tenant requirements.

3. **IdP-initiated SSO timeline**: Several enterprise clients may require IdP-initiated SSO (user clicks a tile in their IdP dashboard and lands directly in the LMS). This has CSRF implications because the SAML assertion arrives without a prior `AuthnRequest`. When should this be implemented, and what CSRF mitigations are acceptable (e.g., per-IdP CSRF exemption with replay prevention)?

4. **Session timeout granularity**: Should session timeouts be configurable per tenant (e.g., financial services client wants 15-minute idle timeout, education client wants 4-hour idle timeout), or are platform-wide role-based timeouts sufficient? Per-tenant timeouts add complexity to the session middleware. Need product input.

5. **Account deprovisioning grace period**: When a user is deprovisioned via SCIM or scheduled sync, should there be a configurable grace period (e.g., 7 days) before the account is actually deactivated, to handle temporary IdP removals (employee on leave, IdP maintenance)? Need product and HR workflow input.

6. **Google Workspace as enterprise IdP**: Several potential enterprise clients use Google Workspace. Should we support Google OAuth2 as an enterprise IdP (using the existing `SOCIAL_AUTH_GOOGLE_OAUTH2` backend) with enterprise tenant linking, or should Google Workspace clients use the standard OIDC federation path? The existing Google OAuth setup (`docs/integrations/GOOGLE_OAUTH_SETUP.md`) is platform-wide; per-tenant Google OAuth requires separate client IDs per tenant.

7. **Certificate management for SAML signing keys**: Should SAML SP signing certificates be managed via Let's Encrypt (automated rotation but short-lived), a dedicated internal CA, or self-signed long-lived certificates? Enterprise IdPs typically prefer long-lived certificates (1-3 years) to avoid frequent metadata updates. Need infra team input.

8. **Break-glass MFA recovery**: What is the break-glass procedure when a platform administrator loses their MFA device? Options: (a) recovery codes generated at enrollment, (b) a second administrator can reset MFA, (c) direct database intervention. Need security policy decision.
