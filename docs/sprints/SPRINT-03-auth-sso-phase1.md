# Sprint 3: Auth SSO Phase 1

**Duration**: 3 weeks (2026-03-11 to 2026-04-01)
**Goal**: Implement tenant SSO configuration + basic SAML flows
**Current**: 72% → **Target**: 78%

---

## Objectives

1. auth-sso-enterprise Phase 1 (13% → 60%)
2. Close forum-service gaps (73% → 90%)
3. Complete ecommerce-purchase-gateway (52% → 100%)

---

## Phase 1: Tenant SSO Configuration (10 ACs)

**Week 1: Configuration UI**

- [ ] AC-AUTH-006: Tenant admin can upload SAML IdP metadata
  - **File**: `deploy/k8s/base/apps/tenant-admin/` (UI)
  - **Estimated**: 2 days
- [ ] AC-AUTH-007: System validates IdP metadata XML
  - **File**: `services/tenant-admin/validators/saml.py`
  - **Estimated**: 1 day
- [ ] AC-AUTH-008: Store IdP config in TenantConfig model
  - **File**: `infrastructure/tutor/plugins/multi-tenancy/models.py` (enhance)
  - **Estimated**: 1 day
- [ ] AC-AUTH-009: Generate SP metadata per tenant
  - **File**: `infrastructure/tutor/custom-apps/saml_sp/metadata.py`
  - **Estimated**: 1 day

**Week 2: SAML Login Flow (8 ACs)**

- [ ] AC-AUTH-010: User clicks "Login with SSO" → redirect to IdP
  - **File**: `deploy/k8s/base/apps/openedx/settings/lms/saml_config.py`
  - **Estimated**: 2 days
- [ ] AC-AUTH-011: System validates SAML response signature
  - **File**: Tests for python3-saml validation
  - **Estimated**: 1 day
- [ ] AC-AUTH-012: Extract user attributes from SAML assertion
  - **File**: `infrastructure/tutor/custom-apps/saml_sp/attributes.py`
  - **Estimated**: 1 day
- [ ] AC-AUTH-013-017: Error handling (invalid signature, expired, wrong tenant)
  - **File**: `tests/integration/test_saml_errors.py`
  - **Estimated**: 2 days

**Week 3: User Provisioning (7 ACs)**

- [ ] AC-AUTH-020: Create local user account on first SSO login (JIT)
  - **File**: `infrastructure/tutor/custom-apps/saml_sp/provisioning.py`
  - **Estimated**: 2 days
- [ ] AC-AUTH-021: Map SAML attributes to user profile fields
  - **File**: Configuration-driven attribute mapping
  - **Estimated**: 1 day
- [ ] AC-AUTH-022-025: Profile updates, email verification, role mapping
  - **File**: Integration tests for full flow
  - **Estimated**: 2 days

---

## Additional Work

**forum-service-migration** (6 ACs unmapped)
- [ ] AC-017-022: Forum moderation, thread management tests
  - **File**: `tests/forum/test_moderation.py`
  - **Estimated**: 2 days

**ecommerce-purchase-gateway** (16 ACs unmapped)
- [ ] AC-017-033: Subscription handling, failed payment retry, refunds
  - **File**: `services/purchase-gateway/services/subscription.py`
  - **Estimated**: 3 days

---

## Success Criteria

- [ ] Tenant can configure SAML SSO via UI
- [ ] Users can login via SSO with their corporate IdP
- [ ] User accounts auto-created on first login (JIT)
- [ ] SAML attribute mapping works (email, name, role)
- [ ] All error cases handled gracefully
- [ ] Coverage report shows 78%+
- [ ] auth-sso-enterprise at 60%+ coverage

---

## Testing Strategy

1. **Unit tests**: SAML validation, attribute mapping
2. **Integration tests**: Full SSO flow with mock IdP
3. **E2E tests**: Real Okta/Azure AD test tenants
4. **Security tests**: Replay attacks, signature validation

---

## Dependencies

- **Depends on**: Sprint 2 (multi-tenancy complete)
- **Blocks**: Enterprise features (Tier 6+)

---

## Risk Mitigation

**Risk**: SAML misconfiguration locks users out
**Mitigation**: Keep local auth enabled, add "backdoor" admin override

**Risk**: Security vulnerability in SAML implementation
**Mitigation**: Use security-reviewer agent, pen-test before launch

**Risk**: Tenant data leaks via SSO misconfiguration
**Mitigation**: Validate tenant isolation in SSO flow, audit logs
