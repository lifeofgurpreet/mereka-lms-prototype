---
title: 'CRED-030: Issuance Flows'
type: feature_spec
status: approved
owner: engineering
vehicle: talent_platform
last_updated: '2026-02-14'
version: 1.0.0
depends_on:
- specs/verifiable-credentials-types_spec.md
- specs/verifiable-credentials-issuer_spec.md
links:
  related_specs:
  - specs/cross-cutting-requirements_spec.md
  - specs/verifiable-credentials-verification_spec.md
id: SPEC-VC-ISSUANCE-001
spec_class: integration
created: '2026-02-10'
last_reviewed: '2026-03-09'
review_due: '2026-06-09'
domain: auth
normativity: normative
supersedes: []
superseded_by: null
verification_sources: []
interfaces:
- api:credentials-issuance
- worker:credentials-jobs
tags:
- auth.verifiable-credentials
- auth.issuance
- platform.credentials
summary: Defines the normative issuance flow for verifiable credentials, including
  issuance requests, signing, persistence, delivery, and operational guarantees on
  Mereka LMS.
---

# CRED-030: Issuance Flows (UX + API)

## What we're building

The end-to-end flow from "learner earns credential" to "credential stored in wallet and shareable." This covers the Credentials Service issuance pipeline, the Learner Record MFE integration, and the Learner Credential Wallet (LCW) QR claim flow.

## Scope

Credential issuance pipeline, claim token lifecycle, Learner Record MFE integration, LinkedIn sharing, and OpenID4VCI readiness groundwork.

## Non-goals

- Credential revocation (deferred to v2)
- Blockchain or decentralised storage
- Native mobile wallet SDK integration (separate spec)
- Bulk credential import from external systems

## Requirements

### Issuance Pipeline

- When a learner completes a program or course, the LMS MUST emit a credential event
- The Credentials Service MUST consume the event and generate an OBv3 AchievementCredential VC
- The VC MUST be signed using the issuer's private key (per CRED-020)
- The signed VC MUST be stored in the Credentials Service database
- Issuance p95 latency MUST be <= 30 seconds from event to stored VC

### Learner Claim Flow

The primary claim flow uses the Learner Record MFE (or LMS profile):

1. Learner views their credentials in the Learner Record MFE at `https://apps.academyv2.mereka.io/learner-record/`
2. Learner sees earned credentials with a "Get Verifiable Credential" button
3. Clicking the button generates a QR code or deep link
4. Learner scans QR with Learner Credential Wallet (LCW) mobile app
5. LCW fetches the VC from the Credentials Service via a short-lived claim token
6. LCW stores the VC successfully

### Claim Token Security

- Claim tokens MUST be short-lived (max 10 minutes TTL)
- Claim tokens MUST be single-use (consumed on first successful fetch)
- Claim tokens MUST be bound to a specific credential and learner
- Claim tokens MUST include a nonce for replay protection
- The claim endpoint MUST validate the `audience` claim matches the requesting wallet

### CORS and Callbacks

- The Credentials Service MUST allow CORS from the LCW app origins
- Callback URLs for wallet integration MUST be configurable per deployment
- The issuance endpoint MUST support `application/ld+json` content type

### LinkedIn Sharing

- Each credential MUST have a shareable public URL
- The public URL page MUST include Open Graph metadata (title, description, image)
- The page MUST include an "Add to LinkedIn" button using LinkedIn's certification URL parameter method (no API key required)
- LinkedIn sharing URL format: `https://www.linkedin.com/profile/add?startTask=CERTIFICATION_NAME&name={name}&organizationName={issuer}&issueYear={year}&issueMonth={month}&certUrl={url}`

### Rate Limits

- Credential issuance: 100 requests/minute per service (internal)
- Claim token generation: 10 requests/minute per learner
- Public credential view: 1000 requests/minute per IP

### OpenID4VCI Readiness (v2)

- The issuance flow MUST NOT block future OpenID4VCI adoption
- Claim tokens SHOULD be designed to be replaceable with OID4VCI authorization codes
- The credential endpoint SHOULD follow RESTful patterns compatible with OID4VCI credential endpoint semantics

---

## Acceptance Criteria

- [ ] AC-CRED-020: Given a learner completes a program, when the credential event is processed, then a signed OBv3 VC is stored in the Credentials Service within 30 seconds
- [ ] AC-CRED-021: Given a learner views the Learner Record MFE, when they have earned credentials, then a "Get Verifiable Credential" button is visible for each eligible credential
- [ ] AC-CRED-022: Given a learner clicks "Get Verifiable Credential", when a QR code is displayed, then scanning it with LCW successfully stores the VC in the wallet
- [ ] AC-CRED-023: Given a claim token is generated, when it is used after 10 minutes, then the Credentials Service returns HTTP 401 (expired)
- [ ] AC-CRED-024: Given a claim token is used once, when it is used a second time, then the Credentials Service returns HTTP 401 (consumed)
- [ ] AC-CRED-025: Given a credential public URL, when opened in a browser, then the page displays credential details with Open Graph metadata and an "Add to LinkedIn" button
- [ ] AC-CRED-026: Given a learner clicks "Add to LinkedIn", when redirected to LinkedIn, then the certification form is pre-populated with credential name, issuer, date, and URL
- [ ] AC-CRED-027: Given the QR flow, when LCW scans the code but the Credentials Service is temporarily unavailable, then LCW shows a retry prompt (not a crash)

---

## Edge Cases

- **QR scan stuck at storage step**: Known Open edX issue (Jan 2026 forum thread). The e2e test suite MUST include a test for this failure mode. Mitigation: implement a polling fallback if the wallet callback doesn't complete within 30 seconds
- **Learner has no wallet app**: Show a "Download LCW" link alongside the QR code, and offer a direct JSON download as fallback
- **Multiple credentials for same achievement**: Idempotent — return existing VC, don't create duplicate
- **Credential issued before Learner Record MFE deployed**: VC is stored server-side; learner can claim it when MFE is available

---

## Monorepo Location

| Component | Path |
|-----------|------|
| Credentials Service settings | `deploy/k8s/base/plugins/credentials/apps/credentials/settings/production.py` |
| LMS VC feature config | `deploy/k8s/base/apps/openedx/settings/lms/production.py` |
| Learner Record MFE | Tutor MFE plugin (frontend-app-learner-record) |
