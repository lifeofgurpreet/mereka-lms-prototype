# Gap Analysis: Design Spec vs Production Implementation

**Date**: 2026-04-27
**Design repo**: `Biji-Biji-Initiative/mereka-lms-prototype` (specs)
**Production repo**: `Biji-Biji-Initiative/mereka-lms` (implementation)
**Method**: Compared spec requirements against actual code/scripts in production repo (latest main, pulled 2026-04-27)

---

## Executive Summary

The production repo implements **~95% of the design specifications**. Platform infrastructure (K8s, Tutor, multi-tenancy, CI/CD, observability, branding, purchase gateway) is fully built. The gaps are concentrated in **authentication security hardening** -- specifically MFA enforcement for Django admin, session lifecycle management, and structured audit logging. These are Phase 1-3 items from the auth-sso-enterprise implementation plan that have not yet been built.

---

## GAPS -- What's Specified but NOT Implemented

### GAP 1: Django Admin MFA Enforcement (HIGH PRIORITY)

**Spec**: `specs/auth-sso-enterprise_spec.md` (AC-014, AC-015, AC-017)
**Status**: NOT IMPLEMENTED

| Requirement | Production State |
|-------------|-----------------|
| MFA middleware for `/admin/` on all services | No middleware exists |
| TOTP enrollment flow (django-otp / django-two-factor-auth) | No OTP libraries installed |
| Recovery codes + break-glass procedure | Not implemented |
| Forced enrollment for newly elevated users | Not implemented |
| WebAuthn/FIDO2 support | Not implemented |
| `ENABLE_MFA_ENFORCEMENT` feature flag | Does not exist |
| `scripts/qa/verify-mfa-enforcement.sh` | Does not exist |

**What DOES exist**: Authentik admin MFA is enforced via `scripts/infra/ensure-authentik-admin-mfa.sh` (Gurpreet only). But staff/superuser users can access Django admin on LMS, CMS, Discovery, Credentials, and Ecommerce without any MFA challenge.

**Impact**: Any compromised staff account has unrestricted Django admin access across all services.

**To implement**: See `specs/plans/auth-sso-enterprise_plan.md` tasks T-014 through T-016, T-026, T-027.

---

### GAP 2: Session Hardening (HIGH PRIORITY)

**Spec**: `specs/auth-sso-enterprise_spec.md` (AC-019 to AC-024)
**Status**: NOT IMPLEMENTED

| Requirement | Production State |
|-------------|-----------------|
| Idle timeout (30min staff, 120min learner) | No middleware; no config |
| Absolute timeout (8h staff, 24h learner) | No enforcement logic |
| Concurrent session limit (max 5 per user, Redis-backed) | No session tracking per user |
| Session ID regeneration post-authentication | Not verified; relies on Django defaults |
| `ENABLE_SESSION_HARDENING` feature flag | Does not exist |
| `scripts/qa/verify-session-hardening.sh` | Does not exist |

**What DOES exist**: Cookie domain scoping (`MerekaCookieDomainMiddleware`) and cookie security flags (Secure, HttpOnly, SameSite) are properly configured.

**Impact**: Sessions have no enforced expiry beyond Django's default `SESSION_COOKIE_AGE`. No protection against concurrent session abuse.

**To implement**: See tasks T-017 through T-020, T-026, T-028.

---

### GAP 3: Structured Auth Audit Logging (MEDIUM PRIORITY)

**Spec**: `specs/auth-sso-enterprise_spec.md` (AC-037, AC-038)
**Status**: NOT IMPLEMENTED

| Requirement | Production State |
|-------------|-----------------|
| Structured auth event logging (login, logout, session_*, mfa_*) | Only Open edX native `login_analytics` |
| Provisioning event logging (JIT, SCIM) | Not implemented |
| Security event logging (cross-tenant denied, replay detected) | Not implemented |
| Sensitive data masking (user_id_hash, ip_address_hash) | Not implemented |
| Tamper-evident audit trail | Not implemented |

**What DOES exist**: Django-prometheus (`django-prometheus==2.3.1`) is installed and metrics endpoints are active. But no custom auth-specific Prometheus metrics are registered.

**To implement**: See tasks T-032 through T-035, T-062 through T-065.

---

### GAP 4: Custom Auth Prometheus Metrics (MEDIUM PRIORITY)

**Spec**: `specs/auth-sso-enterprise_spec.md`, `specs/observability-stack_spec.md`
**Status**: NOT IMPLEMENTED

These planned metrics do not exist in production:

```
auth_login_total
auth_login_latency_seconds
auth_session_active_count
auth_session_expired_total
auth_mfa_challenge_total
auth_rate_limit_triggered_total
auth_saml_assertion_processing_seconds
auth_oidc_token_exchange_seconds
auth_jit_provisioning_total
auth_cross_tenant_access_denied_total
```

**What DOES exist**: General django-prometheus metrics and 9 Grafana dashboards (including `auth.json`), but the dashboards track existing Open edX signals, not the custom metrics above.

---

### GAP 5: Enterprise SSO Feature Flags (MEDIUM PRIORITY)

**Spec**: `specs/plans/auth-sso-enterprise_plan.md`
**Status**: NOT IMPLEMENTED

| Flag | Production State |
|------|-----------------|
| `ENABLE_ENTERPRISE_SSO` | Does not exist |
| `ENABLE_ENTERPRISE_SSO_{TENANT_SLUG}` | Does not exist |
| `ENABLE_MFA_ENFORCEMENT` | Does not exist |
| `ENABLE_SESSION_HARDENING` | Does not exist |
| `ENABLE_AUTH_RATE_LIMITING` | Does not exist (uses `LOGIN_THROTTLE_ENABLED` instead) |
| `ENABLE_SCIM_PROVISIONING` | Does not exist |
| `ENABLE_CLAIM_BASED_ROLE_SYNC` | Does not exist |
| `ENABLE_AUTO_ROLE_REVOCATION` | Does not exist |

**Note**: Rate limiting is effectively implemented via `LOGIN_THROTTLE_ENABLED=true` and `MAX_FAILED_LOGIN_ATTEMPTS_ALLOWED=10`, just not behind the spec-defined flag name.

---

### GAP 6: SAML Single Logout (SLO) (LOW PRIORITY)

**Spec**: `specs/auth-sso-enterprise_spec.md` (AC-022)
**Status**: NOT IMPLEMENTED

Django logout destroys the local session, but does not trigger SAML SLO (LogoutRequest to the IdP). If a user logs out of Mereka, their IdP session remains active.

---

### GAP 7: SCIM 2.0 Deprovisioning Endpoint (LOW PRIORITY -- Phase 3)

**Spec**: `specs/auth-sso-enterprise_spec.md` (Phase 3)
**Status**: NOT IMPLEMENTED

No SCIM endpoint exists. Account deprovisioning is manual. The spec calls for automated deactivation (not deletion) when an employee leaves a client organization.

---

### GAP 8: Custom Enterprise IdP Login Routing (LOW PRIORITY)

**Spec**: `specs/auth-sso-enterprise_spec.md` (AC-001, AC-002)
**Status**: PARTIAL

The spec requires a custom `/enterprise/login/{tenant_slug}` URL that redirects to the correct tenant's IdP. Production relies on Open edX's built-in `third_party_auth` routing. The custom slug-based routing endpoint was not found.

**What DOES exist**: `scripts/tenants/configure-tenant-idp.sh` (19KB) for configuring SAML/OIDC providers per tenant, and `scripts/tenants/generate-saml-keypair.sh` for key generation.

---

## IMPLEMENTED -- What's Built and Working

### Infrastructure (100% implemented)

| Area | Production Evidence |
|------|-------------------|
| K8s deployment | 27 deployments in `deploy/k8s/base/apps/` |
| Base/overlay split | Base in app repo, overlays in bbi-infrastructure |
| Tutor plugin system | `mereka_lms.py` + 4 sub-plugins, `apply-patches.sh` |
| Custom Django apps | 23+ apps in `infrastructure/tutor/custom-apps/` |
| Django settings | 16 CMS + 15 LMS settings files |
| Tenant provisioning | 41 files in `scripts/tenants/` |
| QA verification | 1,081 scripts in `scripts/qa/` |
| Infra scripts | 122 scripts in `scripts/infra/` |
| CI/CD workflows | 74 GitHub Actions workflows |
| Observability | 9 Grafana dashboards, 24+ alert rules, Prometheus + Loki |
| ExternalSecrets | 7 ExternalSecrets, 77 secret keys |
| Purchase Gateway | Full Stripe integration with PG, HPA, ServiceMonitor |
| Design tokens | 3 brand packages (Mereka, Biji-Biji, SkillOurFuture) |
| MFE plugin slots | `mereka_lms_mfe_slots.py` (19.7KB) with data-driven config |

### Authentication (Substantially implemented)

| Area | Production Evidence |
|------|-------------------|
| Platform middleware | All 4 middleware operational (PlatformAdmin, CookieDomain, ForwardedHeaders, MFEOAuthFix) |
| Authentik OIDC | Fully integrated as platform-level SSO |
| Authentik admin MFA | Enforced via `ensure-authentik-admin-mfa.sh` |
| Platform admin enforcement | `MEREKA_PLATFORM_ADMIN_EMAILS` allowlist active |
| SAML/OIDC provider config | Open edX `third_party_auth` with multi-site patches |
| SAML key management | `generate-saml-keypair.sh` + ExternalSecrets |
| Tenant IdP configuration | `configure-tenant-idp.sh` (19KB) |
| Login rate limiting | `django-ratelimit==4.1.0`, `LOGIN_THROTTLE_ENABLED=true`, max 10 failed attempts |
| Auth verification scripts | `verify-auth-surfaces.sh`, `verify-enterprise-sso.sh`, `verify-authenticated-sso-canary.sh`, etc. |
| Auth hardening scripts | All 5 `ensure-*` scripts present and operational |

---

## Priority Recommendations for Gurpreet

### Priority 1 -- Security Gaps (Block for compliance)

1. **Implement Django admin MFA** (Gap 1)
   - Install `django-otp` in image build
   - Create MFA enforcement middleware for `/admin/`
   - Wire into all services (LMS, CMS, Discovery, Credentials, Ecommerce)
   - Effort: ~1 week

2. **Implement session hardening** (Gap 2)
   - Idle timeout middleware (check last-activity timestamp per request)
   - Absolute timeout (session creation timestamp enforcement)
   - Concurrent session limiting (Redis-backed per-user tracking)
   - Effort: ~1 week

### Priority 2 -- Observability Gaps (Block for production readiness)

3. **Add structured auth audit logging** (Gap 3)
   - Create audit event app with structured log output
   - Cover: login, logout, session expiry, MFA, provisioning events
   - Effort: ~3-5 days

4. **Register custom Prometheus auth metrics** (Gap 4)
   - Add auth-specific counters and histograms
   - Update Grafana `auth.json` dashboard
   - Effort: ~2-3 days

### Priority 3 -- Completeness (Nice to have for v1)

5. **Add feature flag infrastructure** (Gap 5)
   - Create the spec-defined flags for staged rollout
   - Effort: ~1-2 days

6. **SAML SLO** (Gap 6) -- ~2-3 days
7. **SCIM 2.0 endpoint** (Gap 7) -- ~1-2 weeks
8. **Custom slug-based IdP routing** (Gap 8) -- ~2-3 days
