---
title: "CRED-020: Issuer Identity, Keys, and Rotation"
type: "feature_spec"
status: "approved"
owner: "engineering"
vehicle: "talent_platform"
last_updated: "2026-02-14"
version: "1.0.0"
depends_on:
  - "specs/verifiable-credentials-types_spec.md"
  - "specs/secrets-management_spec.md"
links:
  related_specs:
    - "specs/cross-cutting-requirements_spec.md"
    - "specs/verifiable-credentials-issuance_spec.md"
    - "specs/verifiable-credentials-verification_spec.md"
---

# CRED-020: Issuer Identity, Keys, and Rotation

## What we're building

The cryptographic identity layer for credential issuance. This defines how the Credentials Service identifies itself as an issuer, signs credentials, and enables long-term verification.

## Scope

`did:web` issuer identity, Ed25519/JWS signing, key storage in ExternalSecrets, key rotation procedure, and revocation strategy decision.

## Non-goals

- Automatic key rotation (manual only in v1)
- Credential revocation in v1 (no `credentialStatus` field)
- Hardware Security Module (HSM) integration (deferred)
- Multi-signature or threshold signing

## Requirements

### Issuer Identifier

- The system MUST use `did:web` as the issuer DID method
- The default issuer DID MUST be `did:web:credentials.academyv2.mereka.io`
- Per-tenant issuer DIDs SHOULD follow the pattern `did:web:credentials.academyv2.mereka.io:tenants:{enterprise_customer_uuid}`
- The DID Document MUST be served at `https://credentials.academyv2.mereka.io/.well-known/did.json` (for the default issuer)
- The DID Document MUST contain at least one `verificationMethod` with the issuer's public key

### Signing

- The system MUST use a single cryptosuite for v1: `Ed25519Signature2020` (preferred) or `JsonWebSignature2020`
- The chosen cryptosuite MUST be documented and locked in configuration
- Each issued VC MUST contain a `proof` object with: `type`, `created`, `verificationMethod`, `proofPurpose: "assertionMethod"`, `proofValue`
- Signing MUST happen server-side in the Credentials Service; private keys MUST NOT leave the service

### Key Storage

- Issuer signing private keys MUST be stored as K8s Secrets synced via ExternalSecrets from Infisical
- The secret MUST be named `credential-signing-keys` in the `mereka-lms` namespace
- Keys MUST be mounted as environment variables or files, NOT stored in the database
- The ExternalSecret MUST sync: `MEREKA_LMS_VC_SIGNING_PRIVATE_KEY` (Ed25519 private key, base64-encoded)

### Key Rotation

- The system MUST support key rotation without breaking verification of previously issued credentials
- On rotation: generate new keypair, update DID Document to list both old and new public keys, sign new credentials with the new key
- Old public keys MUST remain in the DID Document for at least 5 years after last use
- Key rotation MUST be triggered manually (not automatic) in v1
- Rotation procedure MUST be documented in an operational runbook

### Revocation Strategy

- v1: No credential revocation (issued credentials are permanent)
- The system MUST NOT include a `credentialStatus` field in v1 VCs
- v2 SHOULD implement `StatusList2021` for revocation
- This decision MUST be documented so verifiers know revocation is not supported in v1

---

## Acceptance Criteria

- [ ] AC-CRED-010: Given the Credentials Service, when `https://credentials.academyv2.mereka.io/.well-known/did.json` is requested, then a valid DID Document is returned with `id: "did:web:credentials.academyv2.mereka.io"`
- [ ] AC-CRED-011: Given a signing key is configured, when a VC is issued, then the `proof` object contains `type`, `created`, `verificationMethod` (referencing the DID Document), and `proofValue`
- [ ] AC-CRED-012: Given the signing private key is stored in Infisical, when ExternalSecrets syncs, then `credential-signing-keys` K8s Secret exists in `mereka-lms` namespace
- [ ] AC-CRED-013: Given a key rotation is performed, when the DID Document is fetched, then it contains both old and new public keys as `verificationMethod` entries
- [ ] AC-CRED-014: Given a VC signed with an old key, when a verifier resolves the `verificationMethod` from the DID Document, then the old public key is present and verification succeeds
- [ ] AC-CRED-015: Given a VC is issued in v1, when the VC JSON is inspected, then no `credentialStatus` field is present

---

## Edge Cases

- **DID Document endpoint unavailable**: Verifiers cache DID Documents; ensure CDN/caching headers (`Cache-Control: public, max-age=3600`)
- **Multiple tenants, one DID Document**: Each tenant gets a sub-path DID, but all resolve through the same Credentials Service
- **Key compromise**: Emergency procedure: rotate key immediately, update DID Document, issue advisory. Previously signed VCs remain valid (they were legitimately issued)

---

## Monorepo Location

| Component | Path |
|-----------|------|
| DID Document endpoint | Credentials Service (Django view) |
| Signing key secret | `deploy/k8s/base/secrets/external-secrets.yaml` |
| Key rotation runbook | `docs/operations/credential-key-rotation-runbook.md` |
