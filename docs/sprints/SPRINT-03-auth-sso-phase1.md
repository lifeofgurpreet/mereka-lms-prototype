# Sprint 3: Auth SSO Phase 1

**Duration**: 3 weeks (2026-03-11 to 2026-04-01)
**Status**: 🚧 IN PROGRESS (started 2026-02-12)
**Coverage**: ~70% → **Target**: 78%

---

## Objectives

1. auth-sso-enterprise verification + infrastructure (13% → 60%)
2. Forum moderation verification (73% → 90%)
3. Complete ecommerce-purchase-gateway verification + implementation (52% → 100%)
4. Auth SSO infrastructure as code (ExternalSecrets, PrometheusRules)

---

## Tasks Breakdown

### Auth SSO Enterprise

- [x] Comprehensive auth-sso-enterprise verification script
  - **File**: `scripts/qa/verify-auth-sso-enterprise.sh` (in progress)
  - Covers: SAML config, IdP metadata validation, SP metadata generation, cert injection, OIDC flows
- [ ] Auth SSO infrastructure: ExternalSecrets + PrometheusRules
  - **File**: `deploy/k8s/base/secrets/external-secrets.yaml` (SSO secrets)
  - **File**: `deploy/k8s/base/monitoring/prometheusrule-sso.yaml` (SSO alerts)

### Forum Moderation

- [x] Forum moderation verification script
  - **File**: `scripts/qa/verify-forum-moderation.sh` (in progress)
  - Covers: thread management, moderation actions, abuse reporting, content filtering

### Ecommerce Purchase Gateway

- [x] Purchase gateway verification script
  - **File**: `scripts/qa/verify-purchase-gateway.sh` (in progress)
  - Covers: Stripe integration, subscription handling, refunds, failed payment retry
- [ ] Purchase gateway subscription and refund implementation
  - **File**: `services/purchase-gateway/` (business logic)

---

## Phase 1: Tenant SSO Configuration (10 ACs)

**Week 1: Configuration UI**

- [ ] AC-AUTH-006: Tenant admin can upload SAML IdP metadata
  - **File**: `deploy/k8s/base/apps/tenant-admin/` (UI)
- [ ] AC-AUTH-007: System validates IdP metadata XML
  - **File**: `services/tenant-admin/validators/saml.py`
- [ ] AC-AUTH-008: Store IdP config in TenantConfig model
  - **File**: `infrastructure/tutor/plugins/multi-tenancy/models.py` (enhance)
- [ ] AC-AUTH-009: Generate SP metadata per tenant
  - **File**: `infrastructure/tutor/custom-apps/saml_sp/metadata.py`

**Week 2: SAML Login Flow (8 ACs)**

- [ ] AC-AUTH-010: User clicks "Login with SSO" → redirect to IdP
  - **File**: `deploy/k8s/base/apps/openedx/settings/lms/saml_config.py`
- [ ] AC-AUTH-011: System validates SAML response signature
  - **File**: Tests for python3-saml validation
- [ ] AC-AUTH-012: Extract user attributes from SAML assertion
  - **File**: `infrastructure/tutor/custom-apps/saml_sp/attributes.py`
- [ ] AC-AUTH-013-017: Error handling (invalid signature, expired, wrong tenant)
  - **File**: `tests/integration/test_saml_errors.py`

**Week 3: User Provisioning (7 ACs)**

- [ ] AC-AUTH-020: Create local user account on first SSO login (JIT)
  - **File**: `infrastructure/tutor/custom-apps/saml_sp/provisioning.py`
- [ ] AC-AUTH-021: Map SAML attributes to user profile fields
  - **File**: Configuration-driven attribute mapping
- [ ] AC-AUTH-022-025: Profile updates, email verification, role mapping
  - **File**: Integration tests for full flow

---

## Success Criteria

- [ ] Auth SSO verification script covers all 45 ACs
- [ ] Forum moderation verification covers moderation flows
- [ ] Purchase gateway verification covers Stripe + subscription ACs
- [ ] auth-sso-enterprise at 60%+ coverage
- [ ] Coverage report shows 78%+

---

## Testing Strategy

1. **Unit tests**: SAML validation, attribute mapping
2. **Integration tests**: Full SSO flow with mock IdP
3. **E2E tests**: Real Okta/Azure AD test tenants
4. **Security tests**: Replay attacks, signature validation

---

## Dependencies

- **Depends on**: Sprint 2 (multi-tenancy complete) — ✅ done
- **Blocks**: Enterprise features (Tier 6+)

---

## Risk Mitigation

**Risk**: SAML misconfiguration locks users out
**Mitigation**: Keep local auth enabled, add "backdoor" admin override

**Risk**: Security vulnerability in SAML implementation
**Mitigation**: Use security-reviewer agent, pen-test before launch

**Risk**: Tenant data leaks via SSO misconfiguration
**Mitigation**: Validate tenant isolation in SSO flow, audit logs
