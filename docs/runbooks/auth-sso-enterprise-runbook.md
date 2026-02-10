# Enterprise SSO Runbook
_Audience: Platform Operators • Owner: Engineering Lead • Last updated: 2026-02-10_

This runbook covers operational procedures for enterprise SSO (SAML 2.0 / OIDC) integration in Mereka Academy.

> **Status**: Enterprise per-tenant SSO is **not yet implemented** (Tier 4.2). Authentik platform-level OIDC is operational. This runbook documents target-state procedures for when enterprise SSO is deployed.

## Prerequisites

- Authentik OIDC is the platform-level identity provider (operational)
- Platform admin enforcement via `MEREKA_PLATFORM_ADMIN_EMAILS` is active
- Existing auth verification scripts pass: `./scripts/qa/verify-auth-surfaces.sh prod`

## Enterprise IdP Onboarding

### Pre-Onboarding Checklist

1. Confirm tenant has an `EnterpriseCustomer` record (Tier 4.1 multi-tenancy required)
2. Confirm tenant's IdP type: SAML 2.0 or OIDC
3. Obtain from tenant IT:
   - **SAML**: IdP metadata URL (preferred) or static XML file
   - **OIDC**: Discovery endpoint URL (`/.well-known/openid-configuration`), client ID, client secret
4. Agree on attribute/claim mapping (email, first_name, last_name, groups)
5. Generate SP SAML key pair for the tenant (if SAML):
   ```bash
   # When available:
   ./scripts/tenants/generate-saml-keys.sh --tenant=<slug>
   ```

### SAML IdP Configuration

1. Create `SAMLProviderConfig` in Django admin:
   - Entity ID: `https://academyv2.mereka.io/saml/entity/<tenant_slug>`
   - Metadata source: URL (preferred) or XML upload
   - Attribute mapping: configure per tenant requirements
2. Associate with `EnterpriseCustomer.identity_provider` field
3. Store SAML signing key in Infisical → ExternalSecrets:
   ```
   MEREKA_LMS_SAML_KEY_<TENANT_SLUG>
   MEREKA_LMS_SAML_CERT_<TENANT_SLUG>
   ```
4. Enable feature flag: `ENABLE_ENTERPRISE_SSO_<TENANT_SLUG>=true`
5. Verify: `./scripts/qa/verify-enterprise-sso.sh --tenant=<slug> --env=prod`

### OIDC IdP Configuration

1. Create `OAuth2ProviderConfig` in Django admin:
   - Provider backend: custom backend per tenant
   - Client ID and secret from tenant
   - Discovery URL: `https://<idp>/.well-known/openid-configuration`
   - Scopes: `openid profile email` (minimum)
   - Claim mapping: configure per tenant
2. Associate with `EnterpriseCustomer.identity_provider` field
3. Store OIDC client secret in Infisical → ExternalSecrets:
   ```
   MEREKA_LMS_OIDC_SECRET_<TENANT_SLUG>
   ```
4. Enable feature flag: `ENABLE_ENTERPRISE_SSO_<TENANT_SLUG>=true`
5. Verify: `./scripts/qa/verify-enterprise-sso.sh --tenant=<slug> --env=prod`

## Verification

### Per-Tenant SSO Verification

```bash
# Verify enterprise SSO for a specific tenant
./scripts/qa/verify-enterprise-sso.sh --tenant=<slug> --env=prod

# Verify all auth surfaces (platform-wide)
./scripts/qa/verify-auth-surfaces.sh prod

# Verify Authentik hardening
./scripts/infra/ensure-authentik-hardening.sh --verify
```

### Authentik Admin MFA Verification

Authentik admin MFA is independently enforced via Authentik policies:

```bash
./scripts/infra/ensure-authentik-admin-mfa.sh --verify
```

See also: `docs/operations/AUTH_AND_PERMISSIONS.md` → "Authentik Admin (Separate)"

## Troubleshooting

### Enterprise Login URL Returns 404

**Cause**: Feature flag not enabled or `EnterpriseCustomer` not configured.

```bash
# Check feature flag
kubectl exec -n mereka-lms deploy/lms -- python -c \
  "from django.conf import settings; print(getattr(settings, 'ENABLE_ENTERPRISE_SSO', False))"

# Check enterprise customer exists
kubectl exec -n mereka-lms deploy/lms -- python manage.py lms shell -c \
  "from enterprise.models import EnterpriseCustomer; print(EnterpriseCustomer.objects.filter(slug='<tenant>').exists())"
```

### SAML Assertion Rejected

**Common causes**:
- Clock skew: Check `NotBefore`/`NotOnOrAfter` timestamps vs server time
- Certificate mismatch: IdP rotated certificate; check metadata refresh
- Issuer mismatch: Verify `Issuer` in assertion matches configured entity ID

```bash
# Check LMS logs for SAML errors
kubectl logs -n mereka-lms deploy/lms --tail=100 | grep -i "saml\|assertion"
```

### JIT Provisioning Fails

**Common causes**:
- Missing required attribute (email) in IdP assertion
- Username collision exhausted suffix attempts
- Database integrity error (race condition)

```bash
# Check provisioning logs
kubectl logs -n mereka-lms deploy/lms --tail=100 | grep -i "jit\|provision"
```

## Emergency Procedures

### Disable Enterprise SSO for a Tenant

1. Set `ENABLE_ENTERPRISE_SSO_<TENANT_SLUG>=false` in LMS settings
2. Users for that tenant redirected to default login (Authentik/native)
3. Existing sessions remain active until expiry
4. No data loss — IdP config and user records preserved

### Disable All Enterprise SSO

1. Set `ENABLE_ENTERPRISE_SSO=false` in LMS settings
2. All enterprise login routes return 404 or redirect to default login
3. Authentik OIDC and native login continue working

### Suspected IdP Compromise

1. **Immediately** disable affected tenant's IdP in Django admin (`enabled=False`)
2. Invalidate all sessions for affected tenant users:
   ```bash
   kubectl exec -n mereka-lms deploy/lms -- python manage.py lms \
     clear_enterprise_sessions --enterprise-uuid=<uuid>
   ```
3. Notify affected tenant's IT team
4. Rotate SP SAML signing key or OIDC client secret
5. Audit authentication events for past 72 hours
6. Re-enable only after tenant IT confirms IdP is secured
7. File P0 incident report

## SAML Key Rotation

### SP Key Rotation (Platform-Side)

1. Generate new key pair: `./scripts/tenants/generate-saml-keys.sh --tenant=<slug> --rotate`
2. Publish new certificate in SP metadata (immediate)
3. Old key accepted for verification during grace period (default: 7 days)
4. Notify tenant IT to refresh SP metadata from `https://academyv2.mereka.io/auth/saml/metadata.xml`
5. After grace period, remove old key

### IdP Certificate Rotation (Tenant-Side)

Handled automatically if tenant provides metadata URL:
- System refreshes metadata every 24 hours (configurable)
- Both old and new certificates accepted during rollover
- Alert fires if metadata hasn't refreshed for 48+ hours

## Role Mapping

### Configuring Claim-Based Role Assignment

Per-tenant configuration in Django admin:
- SAML: Map attribute name (e.g., `groups`) and value (e.g., `academy-admin`) to `enterprise_admin` role
- OIDC: Map claim name (e.g., `roles`) and value to enterprise role

### Auto-Revocation

When `ENABLE_AUTO_ROLE_REVOCATION` is enabled per tenant:
- If user authenticates without the admin claim, downgraded to `enterprise_learner`
- Role change logged as security event
- `enterprise_openedx_operator` role NEVER assigned from IdP claims (platform-only)

## Related Documentation

- `docs/operations/AUTH_AND_PERMISSIONS.md` — Authentication and permissions overview
- `docs/operations/AUTH_HARDENING_SPEC.md` — Auth hardening operational details
- `docs/operations/AUTH_ALERT_RUNBOOK.md` — Authentication alert response
- `docs/operations/IN_CLUSTER_AUTH_VERIFICATION.md` — In-cluster auth verification
- `docs/operations/RFC_CLAIM_BASED_ROLE_SYNC.md` — Claim-based role sync RFC
- `specs/auth-sso-enterprise_spec.md` — Full specification (45 ACs)
