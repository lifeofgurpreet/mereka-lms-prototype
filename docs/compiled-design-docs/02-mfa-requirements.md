# MFA (Multi-Factor Authentication) Requirements

**Source**: `specs/auth-sso-enterprise_spec.md` (AC-014 to AC-018), `docs/policies/operations/AUTH_HARDENING_SPEC.md`
**Date**: 2026-04-27

---

## Current State

| Area | Status | Detail |
|------|--------|--------|
| Authentik admin MFA | **Operational** | Enforced via `scripts/infra/ensure-authentik-admin-mfa.sh`; Gurpreet only |
| LMS/CMS Django admin MFA | **Not implemented** | No MFA enforcement for staff/superuser accessing `/admin/` |
| MFE/learner MFA | **Not planned (v1)** | Not in scope for initial implementation |
| MFA method | **TOTP specified** | RFC 6238 TOTP minimum; WebAuthn future; Push notification optional |

---

## Requirements Summary

### Who Needs MFA

| Role | MFA Required | When |
|------|-------------|------|
| Authentik admins | Yes (already enforced) | Always (Authentik admin group membership) |
| Platform admins (`is_superuser=true`) | Yes (Phase 1) | When accessing `/admin/` on any service |
| Staff users (`is_staff=true`) | Yes (Phase 1) | When accessing `/admin/` on any service |
| Enterprise admins (tenant-level) | Recommended | Per-tenant policy (future) |
| Learners | No | Not required |

### MFA Methods (Priority Order)

| Method | Requirement Level | Standard |
|--------|------------------|----------|
| TOTP (Time-based One-Time Password) | **MUST** implement | RFC 6238 |
| WebAuthn / FIDO2 | **SHOULD** implement (future) | W3C WebAuthn |
| Push notification | **MAY** implement (future) | Vendor-specific |

---

## Implementation Requirements

### Phase 1 Tasks (Week 3-4 of auth-sso plan)

#### 1. MFA Enforcement Middleware

**What**: New middleware that intercepts `/admin/` requests on ALL services (LMS, CMS, Discovery, Credentials, Ecommerce) and checks if the user has MFA enrolled.

**Behavior**:
- If user is `is_staff=True` or `is_superuser=True` AND has no MFA device enrolled -> redirect to MFA enrollment page
- If user has MFA enrolled but hasn't verified in current session -> redirect to MFA challenge page
- If user has verified MFA in current session -> pass through

**Acceptance Criteria**:
- AC-014: System MUST require MFA for all users with `is_staff=True` or `is_superuser=True` before granting access to Django admin
- AC-015: System MUST redirect unenrolled users to MFA enrollment flow on first `/admin/` access
- AC-017: MFA enforcement MUST apply to LMS, CMS, Discovery, Credentials, and Ecommerce `/admin/` paths

**Target files**:
- New middleware module in `deploy/k8s/base/apps/openedx/settings/lms/`
- Registration in `infrastructure/tutor/patches/` and `apply-patches.sh`
- Feature flag: `ENABLE_MFA_ENFORCEMENT`

#### 2. TOTP Integration

**What**: Integrate `django-otp` or `django-two-factor-auth` for TOTP enrollment and verification.

**Behavior**:
- Enrollment: Generate TOTP secret, display QR code, require confirmation code
- Verification: Prompt for 6-digit code on login challenge
- Recovery: Generate one-time recovery codes at enrollment

**Acceptance Criteria**:
- AC-018: System MUST support TOTP (RFC 6238) as the minimum MFA method

**Target files**:
- New dependency in image build (`requirements.txt` or Tutor plugin)
- TOTP enrollment views and templates
- Integration with `python-social-auth` pipeline

#### 3. MFA Enrollment Enforcement

**What**: Force MFA enrollment for newly elevated users.

**Behavior**:
- When a user is elevated to `is_staff` or `is_superuser`, they MUST enroll MFA at their next login
- Recovery: Break-glass procedure via second admin resetting MFA device

#### 4. Authentik Admin MFA (Already Operational)

**Scripts** (already exist):
- `scripts/infra/ensure-authentik-admin-mfa.sh --verify` -- Check MFA policy
- `scripts/infra/ensure-authentik-admin-mfa.sh --apply` -- Apply MFA policy
- `scripts/infra/ensure-authentik-hardening.sh --verify` -- Unified check (includes MFA)

**Policy**: Only Gurpreet is in `authentik Admins` group. MFA is gated by group membership -- normal LMS users are NOT forced into MFA.

---

## Open Questions (From Spec)

These need decisions before implementation:

| Question | Options | Impact |
|----------|---------|--------|
| MFA provider | Authentik-managed vs Django-native (`django-otp`) vs both | Determines implementation approach |
| Break-glass recovery | Second admin reset vs recovery codes only vs time-locked bypass | Affects recovery workflow |
| Per-tenant MFA policies | Platform-wide only (v1) vs per-tenant configurable (future) | Scoping decision |
| MFA for API access | Session-only vs API token MFA requirement | API security posture |

---

## Verification Scripts

### Existing (Operational)

| Script | Purpose |
|--------|---------|
| `scripts/infra/ensure-authentik-admin-mfa.sh --verify` | Verify Authentik admin MFA policy |
| `scripts/infra/ensure-authentik-hardening.sh --verify` | Unified Authentik hardening check |
| `scripts/qa/verify-auth-hardening.sh --env both --mode all` | Full auth hardening suite |

### Planned (Phase 1)

| Script | Purpose |
|--------|---------|
| `scripts/qa/verify-mfa-enforcement.sh` | Verify staff/superuser prompted for MFA on `/admin/` |
| MFA enrollment test | Verify TOTP enrollment flow works |
| MFA challenge test | Verify MFA challenge blocks unauthenticated admin access |

---

## Observability

### Planned Metrics

| Metric | Description |
|--------|-------------|
| `auth_mfa_challenge_total` | Total MFA challenges issued (by method, outcome) |
| `auth_mfa_enrollment_total` | Total MFA enrollments completed |

### Planned Log Events

| Event Type | Fields |
|-----------|--------|
| `mfa_enrollment_started` | user_id_hash, mfa_method, timestamp |
| `mfa_enrollment_completed` | user_id_hash, mfa_method, timestamp |
| `mfa_challenge_issued` | user_id_hash, mfa_method, timestamp |
| `mfa_challenge_success` | user_id_hash, mfa_method, timestamp, ip_address_hash |
| `mfa_challenge_failure` | user_id_hash, mfa_method, timestamp, ip_address_hash, failure_reason |
| `mfa_recovery_used` | user_id_hash, timestamp, ip_address_hash |

---

## Implementation Timeline

```
Phase 1 (Week 3-4 of auth-sso plan):
  T-014: [L] MFA enforcement middleware (all services)
  T-015: [M] TOTP integration (django-otp / django-two-factor-auth)
  T-016: [S] Formalize Authentik admin MFA in CI
  T-026: [S] Add ENABLE_MFA_ENFORCEMENT feature flag
  T-027: [M] MFA enforcement verification script
  T-032: [M] Auth event structured logging
  T-033: [S] MFA event structured logging
  T-034: [M] Prometheus metrics registration
  T-036: [S] Staged rollout (staging -> production)
```

**Estimated effort**: 2 weeks (within the 10-14 week auth-sso plan)

**Dependencies**: Requires `ENABLE_ENTERPRISE_SSO` feature flag infrastructure (Phase 0) and multi-tenancy architecture to be substantially complete.
