---
title: "CRED-010: Credential Types & Mapping"
type: "feature_spec"
status: "approved"
owner: "engineering"
vehicle: "talent_platform"
last_updated: "2026-02-14"
version: "1.0.0"
depends_on:
  - "specs/enterprise-microservices_spec.md"
  - "specs/multi-tenancy-architecture_spec.md"
links:
  supersedes:
    - "specs/archive/badges-credentials-enterprise_spec.md.SUPERSEDED"
  related_specs:
    - "specs/cross-cutting-requirements_spec.md"
    - "specs/verifiable-credentials-issuer_spec.md"
    - "specs/verifiable-credentials-issuance_spec.md"
    - "specs/verifiable-credentials-verification_spec.md"
    - "specs/verifiable-credentials-ops_spec.md"
---

# CRED-010: Credential Types & Mapping

## What we're building

A standards-first digital credentials system using the existing Open edX Credentials Service (already deployed at `credentials.academyv2.mereka.io` as `openedx-credentials:21.0.0`) with the optional `verifiable_credentials` Django app enabled. Credentials are issued as W3C Verifiable Credentials (VC 2.0) conforming to Open Badges v3.0 (AchievementCredential).

No vendor fees. No Badgr. No Credly. Self-issued, self-hosted, standards-compliant.

## Why

- Open Badges v3.0 aligns with W3C VC Data Model — portable, cryptographically verifiable
- The Credentials Service already runs in our cluster — we enable a feature, not deploy a new service
- Enterprise clients need proof of learning outcomes that works outside our platform
- Learners can share credentials to wallets, LinkedIn, and any OBv3-compliant verifier

## Scope

### In scope
- Enable `verifiable_credentials` app in Credentials Service
- Define credential types: Program Credential, Course Certificate
- Map Open edX achievements to OBv3 AchievementCredential fields
- Multi-tenant issuer profiles per `EnterpriseCustomer`
- Learner Credential Wallet (LCW) storage flow

### Out of scope
- Blockchain anchoring (defer to v2)
- Micro-credentials / stackable credential pathways
- Badge marketplace / cross-tenant badge discovery
- Gamification (points, leaderboards)
- Mobile app credential display (separate spec)

## Non-goals

- Blockchain anchoring or decentralised ledger integration
- Revocation support (deferred to v2 via StatusList2021)
- Badge marketplace or cross-tenant discovery
- Gamification (points, leaderboards)
- Mobile app credential display UI

---

## Requirements

### Credential Types

- The system MUST support **Program Credentials**: issued when a learner completes all courses in a program
- The system MUST support **Course Certificates**: issued when a learner completes a course with a passing grade
- Both types MUST be issued as OBv3 `AchievementCredential` (a W3C Verifiable Credential)
- The system SHOULD support custom `AchievementCredential` types for enterprise-defined skills/competencies (v2)

### Achievement-to-OBv3 Mapping

Each credential MUST map Open edX data to the following OBv3 fields:

| OBv3 Field | Source |
|------------|--------|
| `type` | `["VerifiableCredential", "AchievementCredential"]` |
| `issuer` | Per-tenant Issuer Profile (see CRED-020) |
| `credentialSubject.achievement.name` | Course/Program display name |
| `credentialSubject.achievement.description` | Course/Program short description |
| `credentialSubject.achievement.criteria.narrative` | Completion requirements text |
| `credentialSubject.achievement.image` | Course/Program card image URL |
| `credentialSubject.achievement.achievementType` | `"Certificate"` or `"Badge"` |
| `credentialSubject.identifier` | Learner anonymous user ID (not email) |
| `issuanceDate` | Completion timestamp (ISO 8601) |
| `expirationDate` | Optional, per credential type config |
| `evidence` | Link to learner's grade report or portfolio |

### Recipient Binding

- Credentials MUST bind to the learner using a privacy-preserving identifier
- The `credentialSubject.identifier` MUST use an opaque user ID, NOT raw email
- If the credential is shared publicly, the recipient's email MUST NOT appear in the VC JSON
- The system MUST support DID-based subject identifiers when the learner has a DID (v2)

### Multi-Tenant Credential Branding

- Each `EnterpriseCustomer` MUST have its own Issuer Profile (name, logo, URL)
- Credentials issued for tenant learners MUST use the tenant's Issuer Profile
- A "Mereka Academy" default Issuer Profile MUST exist for non-enterprise learners
- Tenant isolation: credentials issued under tenant A's issuer MUST NOT be editable by tenant B

### Feature Flags

- `ENABLE_VERIFIABLE_CREDENTIALS` — gate VC issuance pipeline (default: off)
- `ENABLE_LEARNER_CREDENTIAL_WALLET` — gate LCW storage flow (default: off)
- Feature flags MUST be settable via LMS Django admin

---

## Acceptance Criteria

- [ ] AC-CRED-001: Given the Credentials Service is running, when the `verifiable_credentials` app is enabled in settings, then `django.apps.get_app_config('verifiable_credentials')` succeeds
- [ ] AC-CRED-002: Given a learner completes a program, when a Program Credential is issued, then the VC JSON contains `type: ["VerifiableCredential", "AchievementCredential"]` and valid OBv3 fields
- [ ] AC-CRED-003: Given a learner completes a course, when a Course Certificate is issued, then the VC JSON maps course name, description, and criteria correctly
- [ ] AC-CRED-004: Given a credential is issued, when the VC JSON is inspected, then the `credentialSubject.identifier` contains an opaque user ID, NOT a raw email address
- [ ] AC-CRED-005: Given enterprise tenant A and B, when credentials are issued for their respective learners, then each credential's `issuer` field references the correct tenant's Issuer Profile
- [ ] AC-CRED-006: Given the `ENABLE_VERIFIABLE_CREDENTIALS` flag is off, when a course is completed, then no VC is issued (only traditional certificate)
- [ ] AC-CRED-007: Given the Mereka Academy default Issuer Profile, when a non-enterprise learner earns a credential, then the issuer name is "Mereka Academy" with the correct logo URL
- [ ] AC-CRED-008: Given a credential VC JSON, when validated against the OBv3 JSON-LD context, then validation passes with zero errors

---

## Edge Cases

- **Course completed before VC feature enabled**: No retroactive VC issuance unless admin triggers backfill
- **Learner in multiple tenants**: Credential uses the issuer of the organization that owns the course enrollment
- **Course with no description**: `achievement.description` defaults to "Completed [course name]"
- **Credential type not configured for course**: Fall back to traditional certificate only

---

## Monorepo Location

| Component | Path |
|-----------|------|
| Credentials settings | `deploy/k8s/base/plugins/credentials/apps/credentials/settings/production.py` |
| VC feature flag config | `deploy/k8s/base/apps/openedx/settings/lms/production.py` |
| Issuer profile config | Credentials Service Django admin |
| Credential type mapping | Credentials Service configuration |
