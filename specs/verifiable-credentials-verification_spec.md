---
title: "CRED-040: Verification"
type: "feature_spec"
status: "approved"
owner: "engineering"
vehicle: "talent_platform"
last_updated: "2026-02-14"
version: "1.0.0"
depends_on:
  - "specs/verifiable-credentials-types_spec.md"
  - "specs/verifiable-credentials-issuer_spec.md"
  - "specs/verifiable-credentials-issuance_spec.md"
links:
  related_specs:
    - "specs/cross-cutting-requirements_spec.md"
    - "specs/verifiable-credentials-ops_spec.md"
---

# CRED-040: Verification

## What we're building

A public verification endpoint that allows anyone — employers, universities, LinkedIn, or any OBv3-compliant verifier — to independently verify that a credential was issued by Mereka Academy and has not been tampered with. No login required. No vendor API key.

## Scope

Public verification endpoint, per-step verification checks (schema, issuer, signature, expiration, revocation), public credential page with Open Graph metadata, DID Document caching, and rate limiting.

## Non-goals

- Revocation checking in v1 (always returns "not_applicable")
- Authenticating verifiers (endpoint is fully public)
- Trusted verifier registry
- Cross-platform credential translation (OBv3 only)

## Requirements

### Public Verification Endpoint

- The Credentials Service MUST expose a public verification endpoint at `https://credentials.academyv2.mereka.io/verify/`
- The endpoint MUST accept a credential UUID as path parameter: `/verify/{credential_uuid}/`
- The endpoint MUST also accept a full VC JSON body via POST for arbitrary VC verification
- The endpoint MUST return a structured verification result (pass/fail with reasons)
- The endpoint MUST NOT require authentication (public access)

### Verification Steps

When verifying a credential, the system MUST perform these checks in order:

1. **Schema validation**: VC JSON conforms to W3C VC Data Model 2.0 and OBv3 context
2. **Issuer resolution**: Resolve the `issuer` DID to a DID Document (via `did:web` resolution)
3. **Key lookup**: Extract the `verificationMethod` from the DID Document
4. **Signature verification**: Verify the `proof.proofValue` using the issuer's public key
5. **Expiration check**: If `expirationDate` exists, verify it has not passed
6. **Revocation check**: v1 always returns "not revoked" (no revocation support). v2 will check StatusList2021

### Verification Response Format

The response MUST follow this structure:

```json
{
  "verified": true,
  "checks": [
    {"check": "schema", "status": "pass"},
    {"check": "issuer", "status": "pass", "issuer": "did:web:credentials.academyv2.mereka.io"},
    {"check": "signature", "status": "pass"},
    {"check": "expiration", "status": "pass"},
    {"check": "revocation", "status": "not_applicable"}
  ],
  "credential": {
    "id": "urn:uuid:...",
    "type": ["VerifiableCredential", "AchievementCredential"],
    "issuer": "did:web:credentials.academyv2.mereka.io",
    "issuanceDate": "2026-01-15T00:00:00Z",
    "credentialSubject": {
      "achievement": {
        "name": "..."
      }
    }
  }
}
```

On failure:
```json
{
  "verified": false,
  "checks": [
    {"check": "schema", "status": "pass"},
    {"check": "issuer", "status": "pass"},
    {"check": "signature", "status": "fail", "reason": "Signature does not match issuer's public key"}
  ]
}
```

### Public Credential Page

- Each credential MUST have a human-readable public page at `https://credentials.academyv2.mereka.io/credentials/{credential_uuid}/`
- The page MUST display: credential name, issuer, recipient (anonymized), issuance date, verification status badge
- The page MUST include a "Verify" button that triggers real-time verification
- The page MUST include Open Graph meta tags for social sharing (`og:title`, `og:description`, `og:image`, `og:url`)
- The page MUST include a "Download JSON" link to get the raw VC JSON

### DID Document Caching

- The verification service MUST cache resolved DID Documents
- Cache TTL MUST be configurable (default: 1 hour)
- Cache MUST be invalidated when a key rotation is detected (new `verificationMethod` ID)
- The DID Document endpoint MUST set `Cache-Control: public, max-age=3600`

### Content-Type and CORS

- The verification endpoint MUST accept `application/json` and `application/ld+json`
- The verification endpoint MUST return `application/json` by default
- CORS MUST be enabled for all origins (public endpoint)
- The public credential page MUST serve standard `text/html`

### Rate Limits

- Public verification: 100 requests/minute per IP
- Public credential page: 1000 requests/minute per IP
- Raw VC JSON download: 100 requests/minute per IP

---

## Acceptance Criteria

- [ ] AC-CRED-030: Given a valid credential UUID, when `GET /verify/{uuid}/` is called, then the response contains `"verified": true` with all checks passing
- [ ] AC-CRED-031: Given a VC with a tampered `proofValue`, when `POST /verify/` is called with the modified JSON, then the response contains `"verified": false` with `"check": "signature", "status": "fail"`
- [ ] AC-CRED-032: Given a credential UUID, when `GET /credentials/{uuid}/` is called in a browser, then a human-readable page displays credential details with a verification status badge
- [ ] AC-CRED-033: Given a credential public page URL, when shared on LinkedIn or social media, then the platform renders a rich preview using Open Graph metadata
- [ ] AC-CRED-034: Given the DID Document was previously resolved, when verification is called again within 1 hour, then the cached DID Document is used (no network request)
- [ ] AC-CRED-035: Given a credential with an `expirationDate` in the past, when verified, then the response contains `"check": "expiration", "status": "fail"`
- [ ] AC-CRED-036: Given the verification endpoint, when more than 100 requests/minute are made from a single IP, then HTTP 429 is returned
- [ ] AC-CRED-037: Given any valid credential, when `GET /credentials/{uuid}/?format=json` is called, then the raw VC JSON is returned with `Content-Type: application/ld+json`

---

## Edge Cases

- **DID Document unreachable during verification**: Return `"check": "issuer", "status": "fail", "reason": "Could not resolve issuer DID"` — do not silently skip
- **Credential exists in DB but was never signed**: Return `"verified": false, "reason": "Credential has no proof"` — this indicates a pipeline bug
- **VC JSON from another issuer submitted for verification**: Attempt to verify normally. If the DID resolves and the signature is valid, return pass. The verifier decides trust, not us
- **Expired DID Document cache + key rotation**: Cache miss triggers fresh resolution. If the old key is no longer in the DID Document, verification of old credentials fails — this is why old keys MUST remain for 5 years (per CRED-020)

---

## Monorepo Location

| Component | Path |
|-----------|------|
| Verification endpoint | Credentials Service (Django view) |
| Public credential page | Credentials Service (Django template) |
| DID Document cache | Credentials Service (Django cache framework / Redis) |
| Verification tests | `scripts/qa/verify-credentials-verification.sh` |
