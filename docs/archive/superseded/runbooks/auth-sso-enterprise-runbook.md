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

See also: `docs/reference/operations/AUTH_AND_PERMISSIONS.md` → "Authentik Admin (Separate)"

## Alert Response Procedures

### AuthFailureRateHigh (Critical)

**Severity**: Critical | **Threshold**: >10% auth failures in 5m | **For**: 5m

**Description**: A significant portion of authentication requests are returning 401/403.

**Investigation**:
1. Check which auth endpoint is failing:
   ```bash
   kubectl logs -n mereka-lms deploy/lms --tail=200 | grep -E "401|403" | grep -i "auth\|login\|saml\|oauth"
   ```
2. Determine if failure is concentrated on one tenant or platform-wide:
   ```bash
   kubectl logs -n mereka-lms deploy/lms --tail=500 | grep -i "saml\|oidc" | awk '{print $NF}' | sort | uniq -c | sort -rn
   ```
3. Check for credential stuffing or brute force patterns:
   ```bash
   kubectl logs -n mereka-lms deploy/lms --tail=1000 | grep "401" | awk '{print $1}' | sort | uniq -c | sort -rn | head -20
   ```

**Resolution**:
- **Single tenant**: Check IdP configuration, certificate expiry, attribute mapping
- **Platform-wide**: Check Authentik health, Redis session store, LMS auth middleware
- **Credential stuffing**: Enable rate limiting, block offending IPs via Cloudflare WAF
- **SAML cert expired**: Rotate SP certificate (see SAML Key Rotation section below)

**Escalation**: If unresolved in 15 minutes, page on-call engineer. If suspected attack, invoke "Suspected IdP Compromise" emergency procedure.

---

### SSOLoginLatencyHigh (Warning)

**Severity**: Warning | **Threshold**: p95 > 2s | **For**: 10m

**Description**: SSO login flow is slow, degrading user experience.

**Investigation**:
1. Check if latency is on the IdP or platform side:
   ```bash
   kubectl logs -n mereka-lms deploy/lms --tail=200 | grep -i "saml\|oauth" | grep -E "took|latency|duration"
   ```
2. Check database query performance for auth tables:
   ```bash
   kubectl exec -n mereka-lms deploy/lms -- python manage.py lms dbshell -c \
     "SELECT * FROM information_schema.processlist WHERE TIME > 1 AND INFO LIKE '%auth%';"
   ```
3. Check Redis latency:
   ```bash
   kubectl exec -n mereka-lms deploy/redis -- redis-cli --latency-history
   ```

**Resolution**:
- **IdP slow**: Contact tenant IT; nothing platform-side can fix external IdP latency
- **Database slow**: Check for missing indexes on `social_auth_*`, `third_party_auth_*` tables
- **Redis slow**: Check memory usage, consider eviction policy or scaling
- **Metadata fetch slow**: Cache SAML metadata more aggressively

**Escalation**: If persistent, create P3 ticket for performance investigation.

---

### MFAChallengeFailureRate (Warning)

**Severity**: Warning | **Threshold**: >20% MFA failures in 15m | **For**: 15m

**Description**: MFA challenges are failing at an elevated rate.

**Investigation**:
1. Check MFA-related logs:
   ```bash
   kubectl logs -n mereka-lms deploy/lms --tail=200 | grep -iE "mfa|2fa|totp|otp"
   ```
2. Check Authentik MFA policy status:
   ```bash
   # Via Authentik admin API if available
   kubectl logs -n mereka-lms deploy/authentik-server --tail=100 | grep -i "mfa\|totp"
   ```

**Resolution**:
- **TOTP clock drift**: Verify server NTP sync (`timedatectl status`)
- **Recovery code exhaustion**: Users need admin reset via Django admin
- **Authentik policy change**: Review recent Authentik policy changes in audit log

**Escalation**: If affecting multiple users, notify platform admin for bulk investigation.

---

### SessionStoreUnavailable (Critical)

**Severity**: Critical | **Threshold**: Redis errors or down | **For**: 2m

**Description**: Redis session backend is unreachable. Users cannot log in or maintain sessions.

**Investigation**:
1. Check Redis pod status:
   ```bash
   kubectl get pods -n mereka-lms -l app=redis
   kubectl logs -n mereka-lms -l app=redis --tail=50
   ```
2. Check Redis connectivity from LMS:
   ```bash
   kubectl exec -n mereka-lms deploy/lms -- python -c "import redis; r = redis.from_url('redis://redis:6379'); print(r.ping())"
   ```
3. Check Redis memory:
   ```bash
   kubectl exec -n mereka-lms deploy/redis -- redis-cli INFO memory | grep used_memory_human
   ```

**Resolution**:
- **Pod down**: Restart Redis: `kubectl rollout restart -n mereka-lms deploy/redis`
- **OOM**: Increase memory limit or review eviction policy
- **Network issue**: Check NetworkPolicy and Service endpoints
- **Disk full**: Check PVC usage if persistence is enabled

**Escalation**: Immediate P1 — all users affected. Page on-call.

---

### SCIMWebhookErrors (Warning)

**Severity**: Warning | **Threshold**: 5xx on SCIM endpoints | **For**: 10m

**Description**: SCIM provisioning endpoint is returning server errors, disrupting user lifecycle management.

**Investigation**:
1. Check SCIM endpoint logs:
   ```bash
   kubectl logs -n mereka-lms deploy/lms --tail=200 | grep -i "scim"
   ```
2. Verify SCIM bearer token is valid:
   ```bash
   kubectl get secret enterprise-sso-secrets -n mereka-lms -o jsonpath='{.data.SCIM_BEARER_TOKEN}' | base64 -d | head -c 8
   echo "... (token present)"
   ```
3. Check database for SCIM-related errors:
   ```bash
   kubectl logs -n mereka-lms deploy/lms --tail=500 | grep -E "IntegrityError|SCIM|provision"
   ```

**Resolution**:
- **Token expired/invalid**: Rotate in Infisical, wait for ExternalSecrets sync (1h) or force: `kubectl annotate externalsecret enterprise-sso-secrets -n mereka-lms force-sync=$(date +%s)`
- **Database errors**: Check for unique constraint violations (duplicate user provisioning)
- **Schema mismatch**: Verify SCIM payload format matches expected schema

**Escalation**: Notify affected tenant IT. Create P3 ticket if not resolved within 1 hour.

---

### EnterpriseIdPUnreachable (Warning)

**Severity**: Warning | **Threshold**: Metadata refresh failures | **For**: 30m

**Description**: SAML metadata from an enterprise IdP cannot be fetched. If the IdP rotates certificates before metadata is refreshed, SSO logins will break.

**Investigation**:
1. Check metadata fetch logs:
   ```bash
   kubectl logs -n mereka-lms deploy/lms --tail=200 | grep -iE "metadata|saml.*fetch|saml.*refresh"
   ```
2. Test IdP metadata URL reachability from the cluster:
   ```bash
   kubectl exec -n mereka-lms deploy/lms -- curl -sI <idp-metadata-url>
   ```
3. Check DNS resolution:
   ```bash
   kubectl exec -n mereka-lms deploy/lms -- nslookup <idp-hostname>
   ```

**Resolution**:
- **DNS failure**: Check CoreDNS logs, verify upstream DNS resolvers
- **IdP temporarily down**: No action if transient; monitor for recovery
- **Firewall/egress**: Check NetworkPolicy allows outbound to IdP
- **Certificate change**: If IdP already rotated, manually import new metadata XML

**Escalation**: Contact tenant IT to confirm IdP status. If >2 hours, consider switching to static metadata as fallback.

---

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

## SCIM Troubleshooting

### SCIM Endpoint Not Responding

```bash
# Test SCIM endpoint health
kubectl exec -n mereka-lms deploy/lms -- curl -s -o /dev/null -w "%{http_code}" \
  -H "Authorization: Bearer $(kubectl get secret enterprise-sso-secrets -n mereka-lms -o jsonpath='{.data.SCIM_BEARER_TOKEN}' | base64 -d)" \
  http://localhost:8000/scim/v2/ServiceProviderConfig
```

### SCIM User Provisioning Fails

1. Check that the SCIM bearer token matches what the IdP is sending
2. Verify user schema compatibility:
   - Required fields: `userName`, `emails[0].value`, `name.givenName`, `name.familyName`
   - `userName` must be unique across the platform
3. Check for duplicate users:
   ```bash
   kubectl exec -n mereka-lms deploy/lms -- python manage.py lms shell -c \
     "from django.contrib.auth.models import User; print(User.objects.filter(email='<email>').values('username','email','is_active'))"
   ```

### SCIM Deprovisioning (User Removal)

SCIM PATCH with `active=false` deactivates the user but preserves data:
```bash
# Verify user deactivation
kubectl exec -n mereka-lms deploy/lms -- python manage.py lms shell -c \
  "from django.contrib.auth.models import User; u = User.objects.get(username='<user>'); print(f'active={u.is_active}')"
```

## Session Debugging

### View Active Sessions for a User

```bash
kubectl exec -n mereka-lms deploy/lms -- python manage.py lms shell -c "
from django.contrib.sessions.models import Session
from django.contrib.auth.models import User
from django.utils import timezone
u = User.objects.get(username='<username>')
sessions = Session.objects.filter(expire_date__gte=timezone.now())
user_sessions = [s for s in sessions if s.get_decoded().get('_auth_user_id') == str(u.id)]
print(f'Active sessions: {len(user_sessions)}')
for s in user_sessions:
    print(f'  Key: {s.session_key[:8]}... Expires: {s.expire_date}')
"
```

### Clear All Sessions for a User

```bash
kubectl exec -n mereka-lms deploy/lms -- python manage.py lms shell -c "
from django.contrib.sessions.models import Session
from django.contrib.auth.models import User
from django.utils import timezone
u = User.objects.get(username='<username>')
sessions = Session.objects.filter(expire_date__gte=timezone.now())
count = 0
for s in sessions:
    if s.get_decoded().get('_auth_user_id') == str(u.id):
        s.delete()
        count += 1
print(f'Cleared {count} sessions')
"
```

### Redis Session Backend Health

```bash
# Check Redis session key count
kubectl exec -n mereka-lms deploy/redis -- redis-cli DBSIZE

# Check session TTLs
kubectl exec -n mereka-lms deploy/redis -- redis-cli --scan --pattern 'django.contrib.sessions*' | head -5 | \
  xargs -I {} kubectl exec -n mereka-lms deploy/redis -- redis-cli TTL {}
```

## Related Documentation

- `docs/reference/operations/AUTH_AND_PERMISSIONS.md` — Authentication and permissions overview
- `docs/policies/operations/AUTH_HARDENING_SPEC.md` — Auth hardening operational details
- `docs/ops/AUTH_ALERT_RUNBOOK.md` — Authentication alert response
- `docs/ops/runbooks/IN_CLUSTER_AUTH_VERIFICATION.md` — In-cluster auth verification
- `docs/operations/RFC_CLAIM_BASED_ROLE_SYNC.md` — Claim-based role sync RFC
- `specs/auth-sso-enterprise_spec.md` — Full specification (45 ACs)
