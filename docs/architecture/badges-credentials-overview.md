# Badges & Credentials Architecture Overview
_Audience: Engineering + Architecture • Last updated: 2026-02-10_

## System Overview

The Badges & Credentials system integrates self-hosted Badgr Server with the existing Open edX credentials service to issue OpenBadges 2.0/3.0 compliant digital badges. Badges are automatically issued upon course/program completion, verifiable by any OpenBadges-compliant verifier, and shareable to LinkedIn and professional networks. The system supports multi-tenant badge template management, external verification, and optional blockchain anchoring.

**Key differentiator**: Self-hosted Badgr Server eliminates per-badge SaaS fees while maintaining industry-standard compliance and interoperability.

---

## Component Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                      LMS (Open edX)                             │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │ Course Completion Events → Event Bus (Redis Streams)     │   │
│  └────────────────────┬─────────────────────────────────────┘   │
└───────────────────────┼─────────────────────────────────────────┘
                        │
                        ▼
         ┌──────────────────────────────┐
         │   Credentials Service        │
         │   (Django + Celery)          │
         │   - Certificate generation   │
         │   - Badge issuance trigger   │
         └──────────┬───────────────────┘
                    │
                    ▼
         ┌──────────────────────────────┐
         │     Badgr Server             │
         │   (Self-hosted, K8s pod)     │
         │   - Badge issuance           │
         │   - OpenBadges assertions    │
         │   - Verification endpoint    │
         │   - Blockchain anchoring     │
         └──────────┬───────────────────┘
                    │
                    ▼
         ┌──────────────────────────────┐
         │   PostgreSQL (Badgr DB)      │
         │   - Badge classes (templates)│
         │   - Issuers (per-tenant)     │
         │   - Assertions (issued badges)│
         └──────────────────────────────┘

         External Integrations:
         ┌──────────────┐   ┌──────────────┐   ┌──────────────┐
         │   LinkedIn   │   │  Blockchain  │   │  Enterprise  │
         │   Sharing    │   │  Anchoring   │   │  HR Systems  │
         │   (OAuth)    │   │  (Optional)  │   │  (REST API)  │
         └──────────────┘   └──────────────┘   └──────────────┘
```

---

## Data Flow

### Badge Issuance Flow
1. **Trigger**: Learner completes course (grade ≥ passing threshold)
2. **Event**: LMS emits `COURSE_GRADE_PASSED` event to Redis Streams
3. **Listener**: Credentials service Celery worker consumes event
4. **Check**: Worker checks if course has associated badge class
5. **Issue**: Worker calls Badgr Server API: `POST /v2/issuers/{issuer-id}/badgeclasses/{badge-id}/assertions`
6. **Assertion**: Badgr creates OpenBadges 2.0 assertion (JSON-LD document)
7. **Sign**: Badgr signs assertion with issuer's private key
8. **Store**: Assertion stored in PostgreSQL with unique assertion ID
9. **Notify**: Credentials service sends email to learner with badge URL
10. **Display**: Badge appears on learner's profile and portfolio page

### Verification Flow
1. **Verifier** accesses badge URL: `https://badges.academyv2.mereka.io/public/assertions/{assertion-id}`
2. **Badgr** returns OpenBadges 2.0 JSON-LD assertion (unauthenticated endpoint)
3. **Verifier** validates signature using issuer's public key
4. **Verifier** checks revocation list (if badge is revoked, status is `revoked`)
5. **Blockchain** (optional): Verifier checks blockchain anchor for tamper-evidence

---

## Integration Points

### Open edX Credentials Service
- **Connection**: Internal HTTP (`http://credentials:8000`)
- **Authentication**: OAuth2 service-to-service with JWT
- **APIs Used**:
  - `POST /credentials/api/v1/credentials/` - Trigger badge issuance
  - `GET /credentials/api/v1/credentials/{uuid}/` - Check badge status

### Badgr Server
- **Connection**: Internal HTTP (`http://badgr:8000`)
- **Authentication**: Badgr API token (stored in Infisical → ExternalSecret)
- **APIs Used**:
  - `POST /v2/issuers/{issuer-id}/badgeclasses/` - Create badge template
  - `POST /v2/issuers/{issuer-id}/badgeclasses/{badge-id}/assertions` - Issue badge
  - `DELETE /v2/issuers/{issuer-id}/badgeclasses/{badge-id}/assertions/{assertion-id}` - Revoke badge
  - `GET /public/assertions/{assertion-id}` - Public verification (no auth)

### LinkedIn Integration
- **Flow**: OAuth 2.0 authorization code grant
- **Scopes**: `w_member_social` (add certification to profile)
- **API**: `POST /v2/shares` with OpenBadges metadata

### Enterprise HR Systems
- **Endpoint**: `GET /api/enterprise/v1/badges/?enterprise_customer_uuid={uuid}`
- **Authentication**: OAuth2 client credentials (per tenant)
- **Response**: JSON array of issued badges with assertion URLs

---

## Key Design Decisions

### 1. Self-Hosted Badgr vs. SaaS (Credly, Accredible)
**Decision**: Self-hosted Badgr Server on GKE

**Rationale**:
- **Cost**: SaaS fees scale linearly with badge issuance (e.g., $1-3 per badge). At 10,000 badges/year, cost is $10k-30k/year recurring.
- **Control**: Self-hosting allows full customization, no vendor lock-in, no data sovereignty concerns.
- **Compliance**: OpenBadges standard ensures interoperability -- badges are verifiable by any OpenBadges-compliant verifier regardless of hosting.

**Trade-offs**:
- Maintenance burden (patching, scaling, monitoring) falls on platform team.
- No Badgr SaaS features like badge marketplace or discovery engine (not required for enterprise use case).

### 2. Integration Point: Credentials Service vs. Direct LMS
**Decision**: Trigger badge issuance from Credentials service, not directly from LMS

**Rationale**:
- **Separation of concerns**: Credentials service already handles certificate generation and learner portfolio.
- **Consistency**: Badges and certificates follow the same issuance pipeline.
- **Event-driven**: Credentials service already subscribes to grade events via Redis Streams.

**Trade-offs**:
- Adds one hop to latency (LMS → Credentials → Badgr vs. LMS → Badgr).
- Acceptable because badge issuance is async (Celery worker processes events in background).

### 3. Multi-Tenancy: Per-Tenant Issuers vs. Shared Issuer
**Decision**: Per-tenant Badgr issuer profiles

**Rationale**:
- **Branding**: Enterprise clients want badges to display their logo/name, not Mereka Academy's.
- **Trust**: Badge verifiers see the tenant organization as the issuer, increasing credibility.
- **Isolation**: Per-tenant issuers prevent cross-tenant badge template leakage.

**Trade-offs**:
- Requires provisioning issuer profile during tenant onboarding.
- Badgr Server must manage multiple issuer signing keys (one per tenant).

### 4. Blockchain Anchoring: Opt-In vs. Mandatory
**Decision**: Blockchain anchoring is optional per tenant

**Rationale**:
- **Cost**: Blockchain transactions incur gas fees (e.g., Ethereum mainnet).
- **Use case**: High-stakes credentials (compliance certifications) benefit from tamper-evidence; general course badges do not.
- **Future-proof**: Opt-in allows experimentation without committing all badges to blockchain.

**Trade-offs**:
- Two verification paths (with/without blockchain) adds complexity.
- Blockchain anchoring is not instant (depends on block confirmation times).

---

## Related Specs and ADRs
- **Spec**: `specs/badges-credentials-enterprise_spec.md`
- **Runbook**: `docs/runbooks/badges-credentials-runbook.md`
- **Operations**: `docs/operations/BADGES_CREDENTIALS_RUNBOOK.md`
- **Multi-Tenancy**: `specs/multi-tenancy-architecture_spec.md`
- **Secrets Management**: `specs/secrets-management_spec.md`
- **K8s Deployment**: `specs/k8s-deployment_spec.md`
