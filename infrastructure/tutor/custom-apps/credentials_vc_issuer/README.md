# Credentials VC Issuer

Django app for serving the DID (Decentralized Identifier) document for the Open edX Credentials Service.

## Purpose

This app provides the issuer identity infrastructure for W3C Verifiable Credentials, enabling:

1. **DID Resolution**: Serves the DID document at `/.well-known/did.json`
2. **Public Key Distribution**: Exposes the issuer's Ed25519 public key for verification
3. **Key Rotation Support**: Maintains historical keys in the DID document

## Specification

- **Spec**: `specs/verifiable-credentials-issuer_spec.md` (CRED-020)
- **Acceptance Criteria**: AC-CRED-010, AC-CRED-011, AC-CRED-013, AC-CRED-014

## DID Method

Uses `did:web` method with the pattern:
```
did:web:credentials.academyv2.mereka.io
```

The DID document is served at:
```
https://credentials.academyv2.mereka.io/.well-known/did.json
```

## Configuration

The app reads configuration from `settings.VERIFIABLE_CREDENTIALS`:

```python
VERIFIABLE_CREDENTIALS = {
    "ISSUER_DID": "did:web:credentials.academyv2.mereka.io",
    "ISSUER_NAME": "Mereka Academy",
    "SIGNATURE_SUITE": "Ed25519Signature2020",
    "SIGNING_KEY_ID": "did:web:credentials.academyv2.mereka.io#key-1",
}
```

## Key Management

- **Private Key**: Loaded from `VC_SIGNING_PRIVATE_KEY` environment variable (base64-encoded)
- **Public Key**: Derived automatically from the private key
- **Storage**: Keys synced from Infisical → GCP Secret Manager → K8s Secrets

## Key Rotation

When rotating keys:

1. Generate new Ed25519 keypair
2. Store new private key in Infisical as `MEREKA_LMS_VC_SIGNING_PRIVATE_KEY`
3. Update DID document to include both old and new public keys
4. New credentials signed with new key
5. Old public keys remain in DID document for ≥5 years

See `docs/operations/credential-key-rotation-runbook.md` for detailed procedure.

## URL Routing

The app is mounted at the root of the Credentials Service:

```python
urlpatterns = [
    path('', include('credentials_vc_issuer.urls')),
    # ... other patterns
]
```

This enables the /.well-known/did.json endpoint.

## Caching

The DID document endpoint sets cache headers:
```
Cache-Control: public, max-age=3600
```

Verifiers are expected to cache DID documents to reduce load on the issuer endpoint.

## Testing

Verify the DID document endpoint:

```bash
curl https://credentials.academyv2.mereka.io/.well-known/did.json | jq
```

Expected response:
```json
{
  "@context": [
    "https://www.w3.org/ns/did/v1",
    "https://w3id.org/security/suites/ed25519-2020/v1"
  ],
  "id": "did:web:credentials.academyv2.mereka.io",
  "verificationMethod": [
    {
      "id": "did:web:credentials.academyv2.mereka.io#key-1",
      "type": "Ed25519VerificationKey2020",
      "controller": "did:web:credentials.academyv2.mereka.io",
      "publicKeyBase64": "..."
    }
  ],
  "assertionMethod": [
    "did:web:credentials.academyv2.mereka.io#key-1"
  ]
}
```

## Dependencies

- Django ≥3.2
- Python ≥3.11
- `cryptography` library (for Ed25519 key operations)
