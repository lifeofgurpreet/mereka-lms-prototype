---
spec: auth-sso-enterprise_spec.md
tier: 4
order: 4.2
status: draft
estimated_effort: "10-14 weeks (Phase 0-4)"
depends_on:
  - multi-tenancy-architecture_spec.md
blocks:
  - enterprise-microservices_spec.md
last_updated: "2026-02-10"
---

# Implementation Plan: Authentication & SSO Enterprise Integration

**Source Spec**: `specs/auth-sso-enterprise_spec.md`
**Tier**: 4 (Enterprise Foundation) -- Sequential dependency:multi-tenancy -> auth-sso -> enterprise-microservices
**Prerequisite**: `specs/multi-tenancy-architecture_spec.md`must be substantially complete (EnterpriseCustomer model, tenant isolation, identity_provider field all operational)

---

## Summary

This plan covers the full implementation of enterprise SSO federation (SAML 2.0 + OIDC), MFA enforcement for privileged users, session hardening (idle/absolute timeouts, concurrent limits), JIT account provisioning/deprovisioning (including SCIM 2.0), IdP claim-based role mapping, audit logging, securityhardening (rate limiting, replay prevention, open redirect protection), and observability (metrics, alerts, dashboards).The rollout follows four phases as defined in the spec, gatedby feature flags.

---

## Prerequisites Checklist

Before starting Phase 0, confirm:

- [ ] `EnterpriseCustomer` model deployed with `identity_provider` field (from multi-tenancy spec)
- [ ] `EnterpriseCustomerUser` model and `PendingEnterpriseCustomerUser` model operational
- [ ] Enterprise roles (`enterprise_admin`, `enterprise_learner`, `enterprise_openedx_operator`) defined
- [ ] Observability stack operational (Prometheus, Loki, Grafana) per `specs/observability-stack_spec.md`
- [ ] Secrets pipeline operational (Infisical -> GCP SM -> ExternalSecrets -> K8s Secrets)
- [ ] `MerekaPlatformAdminMiddleware` and `MEREKA_PLATFORM_ADMIN_EMAILS` enforcement active
- [ ] `MerekaCookieDomainMiddleware` deployed and tested

---

## Phase 0: Foundation (Week 1-2)

### Build

- [ ] **[M]** T-001: Audit existing `third_party_auth` configuration in Tutor build; ensure SAML and OIDC backend dependencies are installed in the openedx image (`infrastructure/tutor/apply-patches.sh`, `infrastructure/tutor/patches/`) | AC: AC-005 | Depends: None
- [ ] **[M]** T-002: Create per-tenant SAML key pair generation script (`scripts/tenants/generate-saml-keys.sh`) -- generates RSA-2048+ key pairs, stores via Infisical, creates ExternalSecret manifests | AC: AC-005, SAML specifics (signing keys) | Depends: None
- [ ] **[M]** T-003: Create IdP configuration helper script (`scripts/tenants/configure-tenant-idp.sh`) wrapping Django management commands for SAMLProviderConfig and OAuth2ProviderConfig creation | AC: AC-001, AC-002 | Depends: T-001
- [ ] **[S]** T-004: Create ExternalSecret templates for per-tenant SAML/OIDC secrets (`deploy/k8s/base/secrets/tenant-idp-secrets-template.yaml`) | AC: SAML/OIDC secrets management |Depends: None
- [ ] **[M]** T-005: Implement slug-based enterprise IdP routing -- create or configure the `/enterprise/login/{tenant_slug}` URL to redirect to the correct IdP backend via `third_party_auth` (`infrastructure/tutor/patches/`, LMS settings via Tutor config) | AC: AC-001, AC-002 | Depends: T-001, T-003
- [ ] **[S]** T-006: Validate SP metadata generation at `/auth/saml/metadata.xml` -- verify ACS URL, entity ID, signing certificate are correct (`scripts/qa/verify-enterprise-sso.sh`)| AC: AC-005 | Depends: T-001
- [ ] **[M]** T-007: Implement unique SP entity ID per tenantif sharing LMS host -- configure entity ID format `https://{lms_host}/saml/entity/{tenant_slug}` in SAMLProviderConfig |AC: SAML entity ID uniqueness | Depends: T-003
- [ ] **[S]** T-008: Document SAML metadata exchange processfor enterprise client IT teams (`docs/onboarding/ENTERPRISE_IDP_SETUP.md`) | AC: Phase 0 documentation | Depends: T-002, T-003

### Test

- [ ] **[M]** T-009: Extend `scripts/qa/verify-auth-surfaces.sh` with enterprise SAML/OIDC endpoint checks (SP metadata endpoint, enterprise login URL pattern) | AC: AC-042 | Depends:T-005, T-006
- [ ] **[M]** T-010: Create `scripts/qa/verify-enterprise-sso.sh` for per-tenant SSO verification (IdP metadata reachable,enterprise login redirect, SP metadata valid) | AC: AC-043 |Depends: T-005, T-006

### Docs

- [ ] **[S]** T-011: Create enterprise IdP onboarding guide for client IT teams (`docs/onboarding/ENTERPRISE_IDP_SETUP.md`) | AC: — | Depends: T-002, T-003

### Rollout

- [ ] **[S]** T-012: Add `ENABLE_ENTERPRISE_SSO` global feature flag to LMS settings via Tutor config (`infrastructure/tutor/patches/`, `deploy/k8s/overlays/production/`) | AC: Feature flags | Depends: None
- [ ] **[S]** T-013: Add `ENABLE_ENTERPRISE_SSO_{TENANT_SLUG}` per-tenant feature flag mechanism | AC: Feature flags | Depends: T-012

---

## Phase 1: MFA and Session Hardening (Week 3-4)

### Build

- [ ] **[L]** T-014: Implement MFA enforcement middleware forDjango admin on all services (LMS, CMS, Discovery, Credentials, Ecommerce) -- intercept `/admin/` requests for `is_staff`or `is_superuser` users without MFA enrolled; redirect to MFA enrollment/challenge | AC: AC-014, AC-015, AC-017 | Depends: T-012 (feature flag)
- [ ] **[M]** T-015: Integrate TOTP MFA via `django-otp` or `django-two-factor-auth` -- TOTP enrollment flow, verificationchallenge, recovery codes generation | AC: AC-018, MFA TOTPrequirement | Depends: T-014
- [ ] **[S]** T-016: Formalize Authentik admin MFA enforcement -- verify `scripts/infra/ensure-authentik-admin-mfa.sh --verify` passes; add to CI | AC: AC-016 | Depends: None
- [ ] **[L]** T-017: Implement session idle timeout middleware -- configurable per role (default: 30min staff, 120min learner); check last activity timestamp on each request; redirectexpired sessions to login | AC: AC-019, AC-020 | Depends: T-012
- [ ] **[M]** T-018: Implement absolute session timeout -- configurable per role (default: 8h staff, 24h learner); store session creation time; enforce maximum duration | AC: AC-021 |Depends: T-017
- [ ] **[M]** T-019: Implement concurrent session limiting --store per-user active session list in Redis; enforce configurable max (default: 5); invalidate oldest on overflow | AC: AC-023 | Depends: T-017
- [ ] **[S]** T-020: Implement session ID regeneration on authentication -- call `request.session.cycle_key()` after successful auth in social-auth pipeline | AC: AC-024 | Depends: None
- [ ] **[M]** T-021: Implement rate limiting on authentication endpoints -- 20 failed attempts per IP per 5 minutes with exponential backoff (5min, 15min, 60min) using `django-ratelimit` or Redis-backed limiter | AC: AC-039 | Depends: None
- [ ] **[S]** T-022: Implement open redirect protection -- validate `next` parameter against `ALLOWED_HOSTS` and `LOGIN_REDIRECT_WHITELIST`; reject external domains | AC: AC-040 | Depends: None
- [ ] **[S]** T-023: Verify HTTPS enforcement on all auth endpoints -- confirm Caddy/Cloudflare configuration redirects HTTP to HTTPS | AC: AC-041 | Depends: None
- [ ] **[S]** T-024: Verify session cookie flags (`Secure`, `HttpOnly`, `SameSite=None`) are correctly set; verify `MerekaCookieDomainMiddleware` scopes cookies to LMS domain | AC: Session cookie security | Depends: None
- [ ] **[S]** T-025: Implement CSRF token binding to session-- verify CSRF validation fails on expired/invalidated sessions (standard Django behavior; verify no custom code breaks it) | AC: CSRF/session binding | Depends: None
- [ ] **[S]** T-026: Add `ENABLE_MFA_ENFORCEMENT`, `ENABLE_SESSION_HARDENING`, `ENABLE_AUTH_RATE_LIMITING` feature flags |AC: Feature flags | Depends: T-012

### Test

- [ ] **[M]** T-027: Create MFA enforcement verification script (`scripts/qa/verify-mfa-enforcement.sh`) -- verify staff/superuser users are prompted for MFA on `/admin/` | AC: AC-014, AC-015, AC-017 | Depends: T-014, T-015
- [ ] **[M]** T-028: Create session hardening verification script (`scripts/qa/verify-session-hardening.sh`) -- verify idle timeout, absolute timeout, concurrent session limit, session regeneration | AC: AC-019, AC-020, AC-021, AC-023, AC-024 |Depends: T-017, T-018, T-019, T-020
- [ ] **[M]** T-029: Create rate limiting verification script(`scripts/qa/verify-auth-rate-limiting.sh`) -- verify 429 returned after 20 failed attempts | AC: AC-039 | Depends: T-021
- [ ] **[S]** T-030: Add open redirect test to `scripts/qa/verify-auth-surfaces.sh` -- verify external redirect URLs are blocked | AC: AC-040 | Depends: T-022
- [ ] **[S]** T-031: Verify existing `verify-auth-hardening.sh` still passes with all new middleware | AC: AC-042 backwardcompat | Depends: T-014 through T-025

### Observability

- [ ] **[M]** T-032: Implement authentication event structured logging -- log `event_type`, `user_id_hash`, `enterprise_customer_uuid`, `idp_slug`, `auth_method`, `ip_address_hash`, `timestamp`, `outcome`, `failure_reason` for all auth events |AC: AC-037 | Depends: T-014, T-017, T-021
- [ ] **[S]** T-033: Implement MFA event structured logging -- log `event_type`, `user_id_hash`, `mfa_method`, `timestamp`, `ip_address_hash` | AC: AC-018 (logging) | Depends: T-015
- [ ] **[M]** T-034: Register Prometheus metrics for auth events: `auth_login_total`, `auth_login_latency_seconds`, `auth_session_active_count`, `auth_session_expired_total`, `auth_mfa_challenge_total`, `auth_rate_limit_triggered_total` | AC: Observability metrics | Depends: T-032
- [ ] **[S]** T-035: Add auth metric scraping to Prometheus config (`infrastructure/monitoring/prometheus/`) | AC: Observability metrics | Depends: T-034

### Rollout

- [ ] **[S]** T-036: Enable `ENABLE_MFA_ENFORCEMENT` flag instaging, test for 1 week, then enable in production | AC: Phase 1 rollout | Depends: T-014, T-027
- [ ] **[S]** T-037: Enable `ENABLE_SESSION_HARDENING` flag in staging, test for 1 week, then enable in production | AC: Phase 1 rollout | Depends: T-017, T-028
- [ ] **[S]** T-038: Enable `ENABLE_AUTH_RATE_LIMITING` flagin staging, test for 1 week, then enable in production | AC:Phase 1 rollout | Depends: T-021, T-029

---

## Phase 2: First Enterprise IdP (Week 5-6)

### Build

- [ ] **[L]** T-039: Implement custom `python-social-auth` pipeline steps for tenant-scoped JIT provisioning -- create LMSuser, create `EnterpriseCustomerUser`, resolve `PendingEnterpriseCustomerUser`, collision avoidance for username, deduplicate by email | AC: AC-025, AC-026, AC-027, AC-028 | Depends:T-001, T-003, T-005
- [ ] **[M]** T-040: Implement SAML assertion validation hardening -- XML signature verification, issuer validation, audience restriction, NotBefore/NotOnOrAfter enforcement, clock skew tolerance (configurable, default 120s), SHA-1 rejection |AC: AC-006, AC-007, AC-009, AC-010 | Depends: T-001
- [ ] **[M]** T-041: Implement SAML assertion replay prevention -- track assertion IDs in Redis with TTL = validity window+ clock skew; reject duplicates | AC: AC-008 | Depends: T-040
- [ ] **[M]** T-042: Implement OIDC validation hardening -- ID token signature verification via JWKS, `iss`/`aud`/`exp`/`nonce` validation, PKCE enforcement (code_challenge + code_challenge_method=S256) | AC: AC-011, AC-012, AC-013 | Depends: T-001
- [ ] **[S]** T-043: Implement cross-tenant IdP isolation --validate SAML `Issuer` and OIDC `iss` against expected tenantbefore creating `EnterpriseCustomerUser`; reject mismatches| AC: AC-003, AC-038 | Depends: T-039
- [ ] **[M]** T-044: Implement IdP claim-based role assignment -- configurable per-tenant claim name/value mapping to `enterprise_admin` / `enterprise_learner`; reject `enterprise_openedx_operator` from IdP claims | AC: AC-032, AC-033, AC-034 |Depends: T-039
- [ ] **[S]** T-045: Implement auto-role revocation (configurable per tenant) -- downgrade to `enterprise_learner` when admin claim disappears on subsequent login | AC: AC-033 | Depends: T-044
- [ ] **[S]** T-046: Verify platform admin allowlist backstopis independent of IdP claims -- `MerekaPlatformAdminMiddleware` enforces `is_staff`/`is_superuser` regardless | AC: AC-03| Depends: None
- [ ] **[M]** T-047: Implement SAML SLO and OIDC RP-initiatedlogout -- on Sign Out, destroy session, clear cookies, redirect to IdP logout endpoint if supported | AC: AC-022 | Depends: T-017
- [ ] **[S]** T-048: Implement email verification gate for JIT-provisioned accounts without `email_verified=true` in assertion | AC: AC-036 | Depends: T-039
- [ ] **[S]** T-049: Implement automatic SAML metadata refresh -- async periodic fetch from metadata URL (configurable interval, default 24h); cache locally; do not block auth flows |AC: SAML metadata refresh | Depends: T-001
- [ ] **[M]** T-050: Implement encrypted SAML assertion support -- SP decryption using tenant-specific private key | AC: SAML encrypted assertions | Depends: T-002
- [ ] **[S]** T-051: Verify OIDC token storage is server-sideonly -- confirm no raw tokens in cookies or localStorage | AC: OIDC token storage | Depends: T-042
- [ ] **[S]** T-052: Implement OIDC token refresh before expiry for active sessions | AC: OIDC token refresh | Depends: T-042
- [ ] **[S]** T-053: Verify Authentik remains default OIDC provider at `/auth/login/oidc/` -- backward compatibility | AC:AC-004 | Depends: T-005
- [ ] **[S]** T-054: Add `ENABLE_CLAIM_BASED_ROLE_SYNC` and `ENABLE_AUTO_ROLE_REVOCATION` feature flags | AC: Feature flags | Depends: T-012

### Test

- [ ] **[L]** T-055: Create enterprise SSO end-to-end smoke test script (`scripts/qa/smoke-enterprise-sso.sh`) -- configure a test SAML/OIDC IdP (e.g., mock IdP or Authentik acting asenterprise IdP), verify full flow: login redirect -> IdP auth -> callback -> session created -> user provisioned | AC: AC-001, AC-002, AC-006, AC-025 | Depends: T-039, T-040, T-042
- [ ] **[M]** T-056: Create SAML security verification script(`scripts/qa/verify-saml-security.sh`) -- test assertion expiry rejection, replay rejection, SHA-1 rejection, issuer mismatch rejection | AC: AC-007, AC-008, AC-009, AC-010 | Depends: T-040, T-041
- [ ] **[M]** T-057: Create OIDC security verification script(`scripts/qa/verify-oidc-security.sh`) -- test token expiryrejection, PKCE parameter presence, issuer/audience validation | AC: AC-011, AC-012, AC-013 | Depends: T-042
- [ ] **[M]** T-058: Create JIT provisioning verification script (`scripts/qa/verify-jit-provisioning.sh`) -- test new user creation, existing user linking, pending user resolution, no staff/superuser escalation | AC: AC-025, AC-026, AC-027, AC-028 | Depends: T-039
- [ ] **[M]** T-059: Create cross-tenant isolation test (`scripts/qa/verify-cross-tenant-isolation.sh`) -- verify IdP assertion from tenant A cannot link to tenant B | AC: AC-003, AC-| Depends: T-043
- [ ] **[M]** T-060: Create role mapping verification script(`scripts/qa/verify-role-mapping.sh`) -- test claim-based role assignment, auto-revocation, operator role rejection, platform admin backstop | AC: AC-032, AC-033, AC-034, AC-035 | Depends: T-044, T-045, T-046
- [ ] **[S]** T-061: Verify logout flow (`scripts/qa/verify-logout-flow.sh`) -- session destroyed, cookies cleared, IdP logout redirect | AC: AC-022 | Depends: T-047

### Observability

- [ ] **[M]** T-062: Implement provisioning event structuredlogging -- `event_type`, `user_id_hash`, `enterprise_customer_uuid`, `source`, `timestamp`, `outcome` for JIT/SCIM/manualevents | AC: AC-037 (provisioning) | Depends: T-039
- [ ] **[S]** T-063: Implement security event logging -- cross-tenant access denied, replay detected, weak signature rejected, rate limited, open redirect blocked; log at WARN/ERROR with structured fields | AC: AC-038, AC-037 | Depends: T-041,T-043
- [ ] **[M]** T-064: Register additional Prometheus metrics:`auth_saml_assertion_processing_seconds`, `auth_oidc_token_exchange_seconds`, `auth_jit_provisioning_total`, `auth_jit_provisioning_latency_seconds`, `auth_cross_tenant_access_denied_total`, `auth_saml_metadata_refresh_total` | AC: Observability metrics | Depends: T-034
- [ ] **[S]** T-065: Implement sensitive data scrubbing -- verify logs never contain raw SAML assertions, OIDC tokens, passwords, MFA secrets, session IDs, or unmasked emails; use `user_id_hash` | AC: Sensitive data rule | Depends: T-032, T-062

### Rollout

- [ ] **[M]** T-066: Onboard pilot enterprise client IdP in dev environment -- configure SAMLProviderConfig or OAuth2ProviderConfig, test full flow | AC: Phase 2 rollout | Depends: T-through T-053
- [ ] **[S]** T-067: Enable `ENABLE_ENTERPRISE_SSO_{PILOT_SLUG}` in production behind feature flag; monitor for 1 week | AC: Phase 2 rollout | Depends: T-066, T-055
- [ ] **[S]** T-068: Toggle `MFE_CONFIG["DISABLE_ENTERPRISE_LOGIN"]` to `False` for pilot tenant | AC: Backward compatibility | Depends: T-067

---

## Phase 3: SCIM and Deprovisioning (Week 7-8)

### Build

- [ ] **[L]** T-069: Implement SCIM 2.0 endpoint (`/scim/v2/`) -- support `POST /Users`, `PUT /Users/{id}`, `PATCH /Users/{id}`, `DELETE /Users/{id}`; per-tenant bearer token authentication; rate limiting | AC: AC-029 (SCIM delete) | Depends: T-039
- [ ] **[M]** T-070: Implement account deactivation on SCIM DELETE -- set `is_active=False`, invalidate all sessions, remove `EnterpriseCustomerUser` record; preserve enrollments/progress | AC: AC-029, AC-030 | Depends: T-069
- [ ] **[M]** T-071: Implement scheduled deprovisioning syncjob -- daily Celery beat task comparing tenant active user list against `EnterpriseCustomerUser` records; deactivate usersno longer in IdP | AC: AC-031 | Depends: T-039
- [ ] **[S]** T-072: Implement re-authentication block for deactivated users -- return "Your account has been deactivated"error | AC: AC-030 | Depends: T-070
- [ ] **[S]** T-073: Add `ENABLE_SCIM_PROVISIONING` feature flag | AC: Feature flags | Depends: T-012

### Test

- [ ] **[M]** T-074: Create SCIM endpoint verification script(`scripts/qa/verify-scim-endpoint.sh`) -- test CRUD operations, bearer token auth, rate limiting, 404 for unknown user |AC: AC-029 | Depends: T-069
- [ ] **[M]** T-075: Create deprovisioning verification script (`scripts/qa/verify-deprovisioning.sh`) -- test account deactivation, session invalidation, ECU removal, enrollment preservation, re-auth block | AC: AC-029, AC-030, AC-031 | Depends: T-070, T-071, T-072
- [ ] **[S]** T-076: Verify SCIM idempotency -- repeated POSTwith same externalId returns existing user; repeated DELETEis idempotent | AC: Idempotency edge cases | Depends: T-069

### Observability

- [ ] **[S]** T-077: Register Prometheus metrics: `auth_scim_operations_total`, `auth_deprovisioning_total` | AC: Observability metrics | Depends: T-064
- [ ] **[S]** T-078: Implement deprovisioning event logging -- `event_type`, `user_id_hash`, `enterprise_customer_uuid`, `deprovisioning_source`, `timestamp`, `actor` | AC: Deprovisioning audit | Depends: T-062

### Rollout

- [ ] **[S]** T-079: Enable `ENABLE_SCIM_PROVISIONING` for pilot tenant in production | AC: Phase 3 rollout | Depends: T-069, T-074

---

## Phase 4: Scale (Week 9+)

### Build

- [ ] **[M]** T-080: Onboard 2-3 additional enterprise clients -- repeat IdP configuration, JIT provisioning setup, role mapping per tenant | AC: Scale rollout | Depends: T-067
- [ ] **[S]** T-081: Implement per-tenant IP allowlisting forrate limiting exceptions (corporate NAT/proxy) | AC: Rate limiting edge case (training events) | Depends: T-021
- [ ] **[S]** T-082: Implement per-account rate limiting (10failed per account per hour) in addition to per-IP | AC: Distributed brute force edge case | Depends: T-021

### Test

- [ ] **[M]** T-083: Run cross-tenant isolation tests with multiple active tenants | AC: AC-003, AC-038 | Depends: T-080
- [ ] **[M]** T-084: Load test with 100+ concurrent SSO loginflows from multiple tenants | AC: Performance NFR (100 concurrent) | Depends: T-080
- [ ] **[S]** T-085: Verify backward compatibility -- Authentik OIDC, native login, platform admin enforcement, all existing QA scripts pass | AC: Backward compatibility | Depends: T-080

### Observability

- [ ] **[M]** T-086: Create Grafana dashboard: AuthenticationOverview (login volume, success/failure, latency, sessions,MFA adoption) | AC: Dashboards | Depends: T-034, T-064
- [ ] **[M]** T-087: Create Grafana dashboard: Enterprise SSOHealth (per-tenant IdP status, metadata freshness, provisioning volume) | AC: Dashboards | Depends: T-064
- [ ] **[M]** T-088: Create Grafana dashboard: Security Posture (rate limits, cross-tenant denials, replay attempts, MFA failures) | AC: Dashboards | Depends: T-064
- [ ] **[S]** T-089: Create Grafana dashboard: Account Lifecycle (JIT provisioning, SCIM ops, deprovisioning events) | AC:Dashboards | Depends: T-077
- [ ] **[M]** T-090: Configure Prometheus/Alertmanager alertsper spec (Critical: cross-tenant access, SAML degradation, mass deactivation; Warning: stale metadata, brute force, MFA failures, staff sessions) | AC: Alerts | Depends: T-064

### Docs

- [ ] **[M]** T-091: Create enterprise SSO runbook (`docs/runbooks/auth-sso-enterprise-runbook.md`) -- operational procedures, troubleshooting, rollback steps, break-glass MFA recovery, IdP compromise response | AC: Docs gate | Depends: T-080
- [ ] **[S]** T-092: Update `docs/operations/AUTH_HARDENING_SPEC.md` to reference this spec as the authoritative contract| AC: Docs | Depends: None
- [ ] **[S]** T-093: Update `docs/operations/TROUBLESHOOTING.md` with enterprise SSO troubleshooting section | AC: Docs |Depends: T-091
- [ ] **[S]** T-094: Document SAML signing key rotation procedure | AC: Security (annual rotation) | Depends: T-002
- [ ] **[S]** T-095: Document break-glass MFA recovery procedure | AC: MFA recovery | Depends: T-015

### Rollout

- [ ] **[S]** T-096: Remove per-tenant feature flags for stable integrations | AC: Phase 4 rollout | Depends: T-083, T-084, T-085
- [ ] **[S]** T-097: Enable all enterprise SSO observabilityalerts | AC: Phase 4 rollout | Depends: T-090

---

## Milestones

| Milestone | Target | Gate Criteria |
|-----------|--------|---------------|
| M1: Foundation complete | End of Week 2 | T-001 through T-0done; `verify-enterprise-sso.sh` passes on dev IdP metadata |
| M2: MFA + Session hardening live | End of Week 4 | T-014 through T-038 done; `verify-mfa-enforcement.sh` and `verify-session-hardening.sh` pass; `verify-auth-hardening.sh` backwardcompat passes |
| M3: Pilot enterprise IdP live | End of Week 6 | T-039 through T-068 done; pilot tenant SSO flow works end-to-end in production; `smoke-enterprise-sso.sh` passes |
| M4: SCIM + Deprovisioning live | End of Week 8 | T-069 through T-079 done; `verify-scim-endpoint.sh` and `verify-deprovisioning.sh` pass |
| M5: Multi-tenant scale | Week 9+ | T-080 through T-097 done; 3+ tenants live; dashboards and alerts operational; runbookpublished |

---

## Risks

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Open edX `third_party_auth` does not support per-tenant SPentity IDs natively | High | Medium | Investigate upstream; may need custom SAMLProvider subclass or monkey-patch |
| `django-otp` or `django-two-factor-auth` conflicts with Open edX's existing auth pipeline | High | Medium | Test in isolated dev environment first; fallback to Authentik-proxied MFA|
| SAML assertion replay cache (Redis) adds latency to authentication | Medium | Low | Benchmark Redis round-trip; use pipeline/batch if needed; p95 target is 500ms |
| Enterprise IdP metadata rotation causes authentication failures during refresh window | High | Medium | Support dual-cert acceptance during rollover; alert on stale metadata > 48h |
| JIT provisioning race condition under concurrent login fromsame user | Medium | Low | Use database-level `get_or_create` with unique constraint on email; handle IntegrityError gracefully |
| Per-tenant SAML key management complexity grows with tenantcount | Medium | Medium | Automate key generation + ExternalSecret creation in `configure-tenant-idp.sh`; document rotation |
| Session hardening timeout values may cause user experiencecomplaints | Medium | High | Start with generous defaults; make configurable; gather feedback in Phase 1 staging |
| Rate limiting may block legitimate users behind corporate NAT | Medium | Medium | Implement per-tenant IP allowlisting (T-081); monitor rate limit triggers closely |
| MFA enrollment forced on existing staff may cause access disruption | High | Medium | Communicate in advance; provide recovery codes at enrollment; break-glass procedure documented|
| Multi-tenancy spec not complete when auth-sso implementation starts | Critical | Low | Strict dependency ordering enforced in IMPLEMENTATION_ORDER.md; verify prerequisites checklistbefore Phase 0 |

---

## Open Questions to Resolve Before Implementation

These map to the Open Questions in the spec. Each must be resolved before the dependent phase begins.

| # | Question | Blocks Phase | Proposed Resolution |
|---|----------|-------------|---------------------|
| 1 | MFA provider choice (Authentik vs Django-native vs both) | Phase 1 | Recommend Django-native (`django-otp`) for universal coverage; Authentik MFA remains for Authentik-only users |
| 2 | SCIM endpoint authentication method | Phase 3 | Start with per-tenant bearer tokens (simplest, Okta/Azure AD both support); add OAuth2 client credentials later if needed |
| 3 | IdP-initiated SSO timeline | Phase 4+ | Defer to futurephase; SP-initiated only for v1 |
| 4 | Session timeout granularity (per-tenant vs role-based)| Phase 1 | Start with role-based (simpler); add per-tenant override if client demand materializes |
| 5 | Account deprovisioning grace period | Phase 3 | Default(immediate); configurable grace period per tenant as enhancement |
| 6 | Google Workspace as enterprise IdP | Phase 2 | Use standard OIDC federation path with separate client ID per tenant;do not reuse platform-wide Google OAuth |
| 7 | Certificate management for SAML signing keys | Phase 0| Self-signed long-lived certificates (2 years); document rotation procedure |
| 8 | Break-glass MFA recovery | Phase 1 | Recovery codes atenrollment + second admin can reset; document in runbook |
