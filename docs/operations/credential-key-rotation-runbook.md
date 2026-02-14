# Credential Signing Key Rotation Runbook

**Spec**: `specs/verifiable-credentials-issuer_spec.md` (CRED-020)
**Acceptance Criteria**: AC-CRED-013, AC-CRED-014
**Last Updated**: 2026-02-14

## Overview

This runbook describes the procedure for rotating the Ed25519 signing key used to sign W3C Verifiable Credentials issued by the Mereka Academy Credentials Service.

Key rotation enables:
- **Security**: Limit blast radius of key compromise
- **Compliance**: Meet periodic key rotation requirements
- **Continuity**: Previously issued credentials remain verifiable

## Prerequisites

- Access to Infisical secrets manager (`https://secrets.mereka.io`)
- Access to GCP Secret Manager for the `mereka-lms` project
- `kubectl` access to the `mereka-lms` namespace
- OpenSSL or Python with `cryptography` library installed

## Key Rotation Schedule

- **Normal rotation**: Every 2 years
- **Emergency rotation**: Immediately upon suspected compromise
- **Historical key retention**: ≥5 years after last use (required for verification of old credentials)

## Procedure

### 1. Generate New Ed25519 Keypair

Generate a new Ed25519 keypair:

```bash
# Using OpenSSL
openssl genpkey -algorithm ED25519 -out private_key.pem
openssl pkey -in private_key.pem -pubout -out public_key.pem

# Convert private key to base64 (for Infisical/K8s)
openssl pkey -in private_key.pem -outform DER | tail -c 32 | base64 -w 0 > private_key_b64.txt

# Extract public key in base64
openssl pkey -in private_key.pem -pubout -outform DER | tail -c 32 | base64 -w 0 > public_key_b64.txt
```

**Alternative using Python**:

```python
from cryptography.hazmat.primitives.asymmetric import ed25519
from cryptography.hazmat.primitives import serialization
import base64

# Generate keypair
private_key = ed25519.Ed25519PrivateKey.generate()
public_key = private_key.public_key()

# Export private key (raw 32-byte seed)
private_bytes = private_key.private_bytes(
    encoding=serialization.Encoding.Raw,
    format=serialization.PrivateFormat.Raw,
    encryption_algorithm=serialization.NoEncryption()
)

# Export public key (raw 32 bytes)
public_bytes = public_key.public_bytes(
    encoding=serialization.Encoding.Raw,
    format=serialization.PublicFormat.Raw
)

# Base64 encode
private_b64 = base64.b64encode(private_bytes).decode('ascii')
public_b64 = base64.b64encode(public_bytes).decode('ascii')

print(f"Private key (base64): {private_b64}")
print(f"Public key (base64): {public_b64}")
```

**Security Note**: Store the new private key securely. Never commit it to version control.

### 2. Store New Private Key in Infisical

```bash
# Set Infisical context (must run from repo with .infisical.json)
cd /home/gurpreet/projects/k8s/mereka-lms

# Store new private key (base64-encoded)
INFISICAL=/home/gurpreet/projects/vps/infrastructure/scripts/infisical
NEW_PRIVATE_KEY_B64=$(cat private_key_b64.txt)

${INFISICAL} secrets set MEREKA_LMS_VC_SIGNING_PRIVATE_KEY="${NEW_PRIVATE_KEY_B64}" \
  --domain https://secrets.mereka.io/api --env prod --path /
```

**Verify the secret was stored**:

```bash
${INFISICAL} secrets get MEREKA_LMS_VC_SIGNING_PRIVATE_KEY \
  --domain https://secrets.mereka.io/api --env prod --path / --plain 2>/dev/null
```

### 3. Sync to GCP Secret Manager

```bash
# Store in GCP Secret Manager
echo -n "${NEW_PRIVATE_KEY_B64}" | gcloud secrets versions add MEREKA_LMS_VC_SIGNING_PRIVATE_KEY --data-file=-

# Verify
gcloud secrets versions access latest --secret=MEREKA_LMS_VC_SIGNING_PRIVATE_KEY
```

### 4. Update ExternalSecrets

The ExternalSecret is already configured to sync `MEREKA_LMS_VC_SIGNING_PRIVATE_KEY` from GCP Secret Manager to the `openedx-secrets` K8s Secret.

Verify the sync:

```bash
# Trigger immediate sync (optional - syncs automatically every 1h)
kubectl annotate externalsecret openedx-secrets -n mereka-lms \
  force-sync=$(date +%s) --overwrite

# Wait for sync
sleep 10

# Verify the secret is updated
kubectl get secret openedx-secrets -n mereka-lms -o jsonpath='{.data.VC_SIGNING_PRIVATE_KEY}' | base64 -d
```

### 5. Update DID Document with New Public Key

The DID document is auto-generated from the private key configured in the environment. However, for key rotation, we need to maintain **both** old and new public keys.

**Current limitation (v1)**: The `credentials_vc_issuer` app only includes the current key. For full key rotation support, we need to implement a key rotation registry.

**Workaround for v1**:
1. Before rotating, manually record the old public key
2. Update `credentials_vc_issuer/views.py` to include the old key in `_get_verification_methods()`
3. Rebuild and redeploy Credentials Service

**Proper implementation (v2)**:
- Store key rotation history in database or config file
- Load historical keys in `_get_verification_methods()`
- See `FUTURE_WORK.md` for enhancement ticket

### 6. Restart Credentials Service

Restart the Credentials Service to load the new private key:

```bash
# Production (K8s)
kubectl rollout restart deployment credentials -n mereka-lms

# Verify pods are running
kubectl get pods -n mereka-lms -l app.kubernetes.io/name=credentials

# Check logs for errors
kubectl logs -n mereka-lms -l app.kubernetes.io/name=credentials --tail=50
```

### 7. Verify DID Document

Test the DID document endpoint to ensure the new public key is present:

```bash
curl https://credentials.academyv2.mereka.io/.well-known/did.json | jq .

# Expected output should include:
# - "id": "did:web:credentials.academyv2.mereka.io"
# - "verificationMethod" array with the new public key
```

**For key rotation with old key retention**, the `verificationMethod` array should contain:
```json
{
  "verificationMethod": [
    {
      "id": "did:web:credentials.academyv2.mereka.io#key-1",
      "type": "Ed25519VerificationKey2020",
      "controller": "did:web:credentials.academyv2.mereka.io",
      "publicKeyBase64": "<old-public-key>"
    },
    {
      "id": "did:web:credentials.academyv2.mereka.io#key-2",
      "type": "Ed25519VerificationKey2020",
      "controller": "did:web:credentials.academyv2.mereka.io",
      "publicKeyBase64": "<new-public-key>"
    }
  ]
}
```

### 8. Update Signing Configuration

Update the `VERIFIABLE_CREDENTIALS.SIGNING_KEY_ID` setting to point to the new key:

```python
# In deploy/k8s/base/plugins/credentials/apps/credentials/settings/production.py
VERIFIABLE_CREDENTIALS = {
    "ISSUER_DID": f"did:web:{MEREKA_CREDENTIALS_DOMAIN}",
    "ISSUER_NAME": PLATFORM_NAME,
    "SIGNATURE_SUITE": "Ed25519Signature2020",
    "SIGNING_KEY_ID": f"did:web:{MEREKA_CREDENTIALS_DOMAIN}#key-2",  # ← Update this
    "DID_DOCUMENT_URL": f"{MEREKA_SCHEME}://{MEREKA_CREDENTIALS_DOMAIN}/.well-known/did.json",
    "REVOCATION_ENABLED": False,
}
```

Rebuild and redeploy the Credentials Service.

### 9. Test Credential Issuance

Issue a test verifiable credential and verify:

```bash
# Issue test credential (exact method depends on API implementation)
curl -X POST https://credentials.academyv2.mereka.io/api/v1/credentials/issue \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{
    "type": ["VerifiableCredential", "CourseCompletionCredential"],
    "credentialSubject": {
      "id": "did:example:test-learner",
      "achievement": "Test Course"
    }
  }'

# Verify the proof uses the new key
# The "proof.verificationMethod" should be "did:web:credentials.academyv2.mereka.io#key-2"
```

### 10. Document the Rotation

Record the key rotation in the key rotation log:

```bash
# Create entry in key rotation log
cat >> docs/operations/key-rotation-log.md <<EOF

## $(date -u +"%Y-%m-%d %H:%M:%S UTC")

- **Key ID**: key-2
- **Public Key (base64)**: $(cat public_key_b64.txt)
- **Reason**: Scheduled rotation / Emergency (key compromise)
- **Operator**: $(whoami)
- **Old Key ID**: key-1
- **Old Key Retirement Date**: $(date -u -d "+5 years" +"%Y-%m-%d")

EOF
```

## Emergency Rotation (Key Compromise)

If the signing key is compromised:

1. **Immediately** generate and deploy a new key following steps 1-6
2. Update the DID document to mark the old key as `revoked` (requires implementation)
3. Issue a security advisory to credential holders:
   - Credentials signed with the compromised key remain **valid** (they were legitimately issued)
   - Verifiers should check issuance date and apply risk-based policies
   - Re-issue critical credentials if needed
4. Investigate the compromise and document findings

## Rollback Procedure

If the new key causes issues:

1. Revert the Infisical/GCP secret to the previous version:
   ```bash
   # List versions
   gcloud secrets versions list MEREKA_LMS_VC_SIGNING_PRIVATE_KEY

   # Disable latest version
   gcloud secrets versions disable <version-number> --secret=MEREKA_LMS_VC_SIGNING_PRIVATE_KEY
   ```

2. Trigger ExternalSecrets sync and restart Credentials Service (steps 4, 6)

3. Verify the DID document and credential issuance

## Post-Rotation Verification Checklist

- [ ] New private key stored in Infisical and GCP Secret Manager
- [ ] ExternalSecrets synced the key to K8s
- [ ] Credentials Service pods restarted successfully
- [ ] DID document includes new public key
- [ ] Old public key remains in DID document (for existing credential verification)
- [ ] `SIGNING_KEY_ID` configuration updated to new key
- [ ] Test credential issued and verified successfully
- [ ] Key rotation documented in log
- [ ] Old private key securely destroyed (after grace period)

## Key Retirement

After **5 years** from the last credential issuance with an old key:

1. Remove the old public key from the DID document
2. Rebuild and redeploy Credentials Service
3. Update the key rotation log to mark the key as retired

**Warning**: Credentials signed with a retired key will fail verification. Ensure the grace period has passed.

## Troubleshooting

### DID document returns 500 error

**Symptoms**: `curl https://credentials.academyv2.mereka.io/.well-known/did.json` returns 500

**Causes**:
- Private key not configured in environment
- Invalid base64 encoding
- Missing cryptography library

**Debug**:
```bash
# Check logs
kubectl logs -n mereka-lms -l app.kubernetes.io/name=credentials --tail=100 | grep -i "vc_signing"

# Verify secret exists
kubectl get secret openedx-secrets -n mereka-lms -o jsonpath='{.data.VC_SIGNING_PRIVATE_KEY}'
```

### Credential verification fails after rotation

**Symptoms**: Verifiers report signature verification failures

**Causes**:
- Old public key removed from DID document too soon
- `verificationMethod` in credential doesn't match DID document

**Fix**:
- Re-add old public key to DID document
- Verify `proof.verificationMethod` in issued credentials matches a key in the DID document

## References

- **Spec**: `specs/verifiable-credentials-issuer_spec.md` (CRED-020)
- **DID Web Specification**: https://w3c-ccg.github.io/did-method-web/
- **Ed25519Signature2020**: https://w3c-ccg.github.io/lds-ed25519-2020/
- **Key Rotation Registry**: `FUTURE_WORK.md` (to be implemented)
