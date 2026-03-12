# Verifiable Credential Verification Failure Runbook
_Audience: Operators and developers • Owner: Platform Team • Last verified: 2026-03-12 • Status: active_

**Spec**: `specs/verifiable-credentials-verification_spec.md` (CRED-040)
**Alerts**: `VCVerificationEndpointDown`, `VCDIDDocumentUnavailable`, `VCClaimTokenExpiryHigh`
**Severity**: Critical (external verifiers unable to validate credentials)

---

## Overview

Diagnose and resolve failures in the VC verification pipeline, including DID Document unavailability, signature verification failures, and claim token redemption issues.

**Key Distinction**:
- **Issuance failures** (covered in `credential-issuance-failure-runbook.md`): Learners can't receive VCs
- **Verification failures** (this runbook): Learners have VCs, but external verifiers can't validate them

---

## Quick Diagnostic (5-Minute Triage)

```bash
# 1. Check verification endpoint availability
curl -I https://credentials.academyv2.mereka.io/api/verifiable-credentials/verify

# Expected: HTTP 200 OK

# 2. Check DID Document endpoint
curl -s https://credentials.academyv2.mereka.io/.well-known/did.json | jq

# Expected: Valid JSON with verificationMethod array

# 3. Check verification error rate
kubectl exec -it deployment/prometheus -n monitoring -- \
  promtool query instant http://localhost:9090 \
  'rate(credentials_vc_verification_requests_total{namespace="mereka-lms", result=~"fail|error"}[5m])'

# 4. Check DID Document cache hit rate
kubectl exec -it deployment/redis -n mereka-lms -- \
  redis-cli GET "did:web:credentials.academyv2.mereka.io"

# 5. Check recent verification logs
kubectl logs -n mereka-lms -l app.kubernetes.io/name=credentials --tail=100 | grep verification
```

---

## Common Failure Modes

### 1. DID Document Endpoint Down

**Symptoms**:
- `VCDIDDocumentUnavailable` alert firing
- External verifiers report: "DID Document not found"
- Verification requests return `500` with "DID resolution failed"

**Diagnosis**:
```bash
# Check DID Document endpoint directly
curl -v https://credentials.academyv2.mereka.io/.well-known/did.json

# Common failure: 404 Not Found
# Check Caddy routing
kubectl get ingress -n mereka-lms credentials -o yaml | grep -A5 "well-known"

# Check if DID Document file exists
kubectl exec -it deployment/credentials -n mereka-lms -- \
  cat /app/credentials/static/.well-known/did.json

# Check nginx/caddy logs for 404s
kubectl logs -n mereka-lms -l app.kubernetes.io/name=caddy --tail=50 | grep "well-known"
```

**Fix**:
```bash
# Regenerate DID Document
kubectl exec -it deployment/credentials -n mereka-lms -- \
  python manage.py generate_did_document \
  --issuer-url "https://credentials.academyv2.mereka.io" \
  --output /app/credentials/static/.well-known/did.json

# Verify file created
kubectl exec -it deployment/credentials -n mereka-lms -- \
  cat /app/credentials/static/.well-known/did.json | jq '.verificationMethod'

# Restart pods to pick up new static file
kubectl rollout restart deployment/credentials -n mereka-lms

# Verify endpoint
curl -s https://credentials.academyv2.mereka.io/.well-known/did.json | jq '.id'
# Expected: "did:web:credentials.academyv2.mereka.io"
```

**If still failing**:
```bash
# Check Ingress/Service routing
kubectl describe ingress credentials -n mereka-lms

# Verify Service exposes correct port
kubectl get svc credentials -n mereka-lms -o yaml | grep -A3 "ports:"

# Test from inside cluster
kubectl run curl-test --image=curlimages/curl -it --rm -- \
  curl -s http://credentials:8000/.well-known/did.json | jq
```

---

### 2. Signature Verification Failure

**Symptoms**:
- Verifier reports: "Invalid signature"
- Verification requests return `400` with "Signature validation failed"
- `credentials_vc_verification_requests_total{result="fail"}` increasing

**Diagnosis**:
```bash
# Test verification with a known-good credential
kubectl exec -it deployment/credentials -n mereka-lms -- \
  python manage.py verify_credential \
  --uuid "KNOWN_GOOD_CREDENTIAL_UUID" \
  --verbose

# Check if public key in DID Document matches credential's proof
curl -s https://credentials.academyv2.mereka.io/.well-known/did.json | \
  jq '.verificationMethod[] | select(.id | contains("key-1")) | .publicKeyBase58'

# Compare with credential proof
kubectl exec -it deployment/credentials -n mereka-lms -- \
  python manage.py shell -c "
from credentials.apps.verifiable_credentials.models import IssuedCredential
vc = IssuedCredential.objects.get(uuid='CREDENTIAL_UUID')
print(vc.credential_json['proof']['verificationMethod'])
"
```

**Common Causes**:
1. **Key rotation**: Credential signed with old key, but old key removed from DID Document
   - **Fix**: Re-add old verification method (see `credential-key-rotation-runbook.md` Step 2)

2. **DID mismatch**: Credential's `issuer` doesn't match DID Document `id`
   - **Fix**: Regenerate DID Document with correct issuer URL

3. **Corrupted credential**: VC JSON malformed or tampered with
   - **Fix**: Re-issue credential (cannot repair signed VCs)

**Fix (Re-add old key to DID Document)**:
```bash
# Find the key ID used in the credential
CREDENTIAL_KEY_ID=$(kubectl exec -it deployment/credentials -n mereka-lms -- \
  python manage.py shell -c "
from credentials.apps.verifiable_credentials.models import IssuedCredential
vc = IssuedCredential.objects.get(uuid='CREDENTIAL_UUID')
print(vc.credential_json['proof']['verificationMethod'].split('#')[-1])
")

# Retrieve old public key from backup
# (Keys should be backed up during rotation per credential-key-rotation-runbook.md)
OLD_PUBLIC_KEY="..."  # Retrieve from Infisical or key rotation log

# Add old key back to DID Document
kubectl exec -it deployment/credentials -n mereka-lms -- \
  python manage.py add_verification_method \
  --kid "$CREDENTIAL_KEY_ID" \
  --public-key "$OLD_PUBLIC_KEY"

# Clear DID Document cache
kubectl exec -it deployment/redis -n mereka-lms -- \
  redis-cli DEL "did:web:credentials.academyv2.mereka.io"

# Verify credential now validates
kubectl exec -it deployment/credentials -n mereka-lms -- \
  python manage.py verify_credential --uuid "CREDENTIAL_UUID"
```

---

### 3. DID Document Cache Issues

**Symptoms**:
- Intermittent verification failures
- Some credentials verify, others fail with same key
- `VCVerificationEndpointDown` alert firing intermittently

**Diagnosis**:
```bash
# Check Redis cache status
kubectl exec -it deployment/redis -n mereka-lms -- \
  redis-cli INFO keyspace

# Check DID Document TTL in cache
kubectl exec -it deployment/redis -n mereka-lms -- \
  redis-cli TTL "did:web:credentials.academyv2.mereka.io"

# Check if cache value matches live DID Document
kubectl exec -it deployment/redis -n mereka-lms -- \
  redis-cli GET "did:web:credentials.academyv2.mereka.io" | \
  jq '.verificationMethod | length'

curl -s https://credentials.academyv2.mereka.io/.well-known/did.json | \
  jq '.verificationMethod | length'

# Values should match
```

**Fix**:
```bash
# Clear DID Document cache
kubectl exec -it deployment/redis -n mereka-lms -- \
  redis-cli DEL "did:web:credentials.academyv2.mereka.io"

# Warm cache by fetching DID Document
curl -s https://credentials.academyv2.mereka.io/.well-known/did.json > /dev/null

# Verify cache repopulated
kubectl exec -it deployment/redis -n mereka-lms -- \
  redis-cli EXISTS "did:web:credentials.academyv2.mereka.io"
# Expected: 1 (exists)

# If cache repeatedly becomes stale:
# Increase DID Document cache TTL
kubectl set env deployment/credentials -n mereka-lms \
  DID_DOCUMENT_CACHE_TTL=86400  # 24 hours
```

---

### 4. Claim Token Expiry Issues

**Symptoms**:
- `VCClaimTokenExpiryHigh` alert firing
- Learners report: "Your claim link has expired"
- High ratio of expired/generated tokens (>50%)

**Diagnosis**:
```bash
# Check token expiry rate
kubectl exec -it deployment/prometheus -n monitoring -- \
  promtool query instant http://localhost:9090 \
  'sum(rate(credentials_vc_claim_tokens_expired_total{namespace="mereka-lms"}[1h])) / sum(rate(credentials_vc_claim_tokens_generated_total{namespace="mereka-lms"}[1h]))'

# Check token expiry time in settings
kubectl exec -it deployment/credentials -n mereka-lms -- \
  python manage.py shell -c "from django.conf import settings; print(settings.VC_CLAIM_TOKEN_EXPIRY_MINUTES)"

# Expected: 10 (default per CRED-030)

# Check recent token expirations
kubectl exec -it deployment/credentials -n mereka-lms -- \
  python manage.py shell -c "
from credentials.apps.verifiable_credentials.models import ClaimToken
from django.utils import timezone
from datetime import timedelta

expired = ClaimToken.objects.filter(
    expires_at__lt=timezone.now(),
    redeemed_at__isnull=True
).count()

print(f'Expired unused tokens: {expired}')
"
```

**Common Causes**:
1. **Email delivery delays**: Token email arrives after 10-minute expiry
2. **Poor UX**: Learners don't understand claim flow
3. **Mobile app issues**: Deep link not working

**Fix (Short-term)**:
```bash
# Extend token expiry time
kubectl set env deployment/credentials -n mereka-lms \
  VC_CLAIM_TOKEN_EXPIRY_MINUTES=30

# Restart to apply
kubectl rollout restart deployment/credentials -n mereka-lms

# Re-issue expired tokens for recent learners
kubectl exec -it deployment/credentials -n mereka-lms -- \
  python manage.py reissue_expired_tokens \
  --days-back 7
```

**Fix (Long-term)**:
- Investigate email delivery latency (check SMTP logs)
- A/B test UX improvements (clearer claim page instructions)
- Add claim flow to mobile app onboarding

---

### 5. External Verifier Integration Issues

**Symptoms**:
- Specific verifier (e.g., LinkedIn, BadgeCheck) reports invalid VC
- Verification works via our `/verify` endpoint but fails externally
- Verifier-specific error messages

**Diagnosis**:
```bash
# Validate credential against OBv3 JSON-LD context
kubectl exec -it deployment/credentials -n mereka-lms -- \
  python manage.py validate_vc_jsonld \
  --uuid "CREDENTIAL_UUID"

# Check VC contains required OBv3 fields
kubectl exec -it deployment/credentials -n mereka-lms -- \
  python manage.py shell -c "
from credentials.apps.verifiable_credentials.models import IssuedCredential
vc = IssuedCredential.objects.get(uuid='CREDENTIAL_UUID')
required_fields = ['@context', 'type', 'issuer', 'credentialSubject', 'issuanceDate', 'proof']
missing = [f for f in required_fields if f not in vc.credential_json]
print(f'Missing fields: {missing}')
"

# Test with external validator (BadgeCheck)
# URL: https://badgecheck.io/
# Upload credential JSON and review validation report
```

**Fix**:
```bash
# If @context incorrect, update VC template
kubectl exec -it deployment/credentials -n mereka-lms -- \
  python manage.py update_vc_context \
  --context-url "https://www.w3.org/ns/credentials/v2"

# Re-issue affected credentials
kubectl exec -it deployment/credentials -n mereka-lms -- \
  python manage.py reissue_credentials \
  --issued-before "2026-02-14" \
  --reason "Update @context for OBv3 compliance"
```

---

## Verification After Fix

```bash
# 1. Test DID Document endpoint
curl -s https://credentials.academyv2.mereka.io/.well-known/did.json | \
  jq '.verificationMethod | length'
# Expected: ≥1

# 2. Test verification endpoint
curl -X POST https://credentials.academyv2.mereka.io/api/verifiable-credentials/verify \
  -H "Content-Type: application/json" \
  -d '{"credentialUuid": "TEST_CREDENTIAL_UUID"}'
# Expected: {"valid": true, ...}

# 3. Check metrics recovered
kubectl exec -it deployment/prometheus -n monitoring -- \
  promtool query instant http://localhost:9090 \
  'rate(credentials_vc_verification_requests_total{namespace="mereka-lms", result="pass"}[5m])'
# Expected: >0 (successful verifications)

# 4. Check Grafana dashboard
# URL: https://grafana.mereka.io/d/credentials-vc
# Panel: "Verification" should show pass rate ≥99%
```

---

## Escalation

If issue persists:

1. **Capture diagnostic bundle**:
   ```bash
   curl -s https://credentials.academyv2.mereka.io/.well-known/did.json > /tmp/did-document.json
   kubectl logs -n mereka-lms -l app.kubernetes.io/name=credentials --tail=500 > /tmp/credentials-logs.txt
   kubectl exec -it deployment/credentials -n mereka-lms -- python manage.py verify_credential --uuid "CREDENTIAL_UUID" --verbose > /tmp/verify-output.txt
   ```

2. **Contact platform engineering** with:
   - Alert name and timestamp
   - Diagnostic bundle (DID Document, logs, verify output)
   - Steps already attempted from this runbook

3. **Create incident ticket**: `ops-incident-vc-verification-YYYYMMDD`

---

## Prevention

- **Monitor**: Set up PagerDuty routing for `VCVerificationEndpointDown` (critical severity)
- **Test**: Run `./scripts/qa/verify-credentials-verification.sh` before each release
- **Backup**: Keep old verification methods in DID Document for 5 years (per CRED-020)
- **Cache**: Pre-warm DID Document cache after deployment

---

## References

- CRED-040: Verification & Validation Flow
- CRED-020: Issuer Profile & DID Management (key rotation, DID Document structure)
- CRED-050: Ops & Reliability (this spec)
- W3C VC Data Model: https://www.w3.org/TR/vc-data-model-2.0/
- DID Web Method: https://w3c-ccg.github.io/did-method-web/
