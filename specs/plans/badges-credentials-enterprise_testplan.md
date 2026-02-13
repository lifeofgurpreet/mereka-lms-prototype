---
title: "Badges & Credentials Enterprise Integration Test Plan"
spec: "badges-credentials-enterprise_spec.md"
last_updated: "2026-02-13"
---

# Badges & Credentials Enterprise Integration Test Plan

## Test Strategy

This test plan covers the self-hosted Badgr Server deployment, OpenBadges 2.0/3.0 compliance, multi-tenant badge management, and enterprise HR integrations. Testing emphasizes tenant isolation, cryptographic verification, and external API interoperability.

## Test Matrix

| AC ID | Description | Method | Priority | Automation |
|-------|-------------|--------|----------|------------|
| AC-001 | Badgr Server deployment exists with READY replicas >= 1 | integration | P0 | automated |
| AC-002 | Badgr Server health check returns HTTP 200 internally | integration | P0 | automated |
| AC-003 | Badgr Server externally accessible at badges.academyv2.mereka.io | integration | P0 | automated |
| AC-004 | Badgr worker deployment exists with READY replicas >= 1 | integration | P0 | automated |
| AC-005 | Domain uses DNS-only Cloudflare mode with Let's Encrypt SSL | manual | P0 | manual |
| AC-006 | Badge issued within 60s of COURSE_COMPLETION event | integration | P0 | automated |
| AC-007 | Badge issued on PROGRAM_COMPLETION event | integration | P0 | automated |
| AC-008 | Duplicate badge issuance is idempotent | integration | P0 | automated |
| AC-009 | Manual badge issuance via admin portal | e2e | P1 | semi |
| AC-010 | Bulk badge issuance completes within 10 min for 1000 badges | e2e | P1 | automated |
| AC-011 | Tenant A cannot access tenant B's badge classes | integration | P0 | automated |
| AC-012 | Cross-tenant API access returns HTTP 403 | integration | P0 | automated |
| AC-013 | Badge assertion reflects tenant A's branding | integration | P0 | automated |
| AC-014 | Dual-tenant learner sees both badge sets labeled by issuer | e2e | P1 | semi |
| AC-015 | Public verification endpoint returns HTTP 200 with valid JSON | integration | P0 | automated |
| AC-016 | Revoked badge returns HTTP 404 with revocation metadata | integration | P0 | automated |
| AC-017 | CORS headers present on verification endpoint | integration | P0 | automated |
| AC-018 | Public signing key accessible | integration | P0 | automated |
| AC-019 | Badge revocation reflects in public endpoint and portfolio | integration | P1 | automated |
| AC-020 | Bulk revocation of 500 assertions completes within 5 min | integration | P1 | automated |
| AC-021 | Blockchain-anchored badge revocation updates revocation list | integration | P2 | automated |
| AC-022 | LinkedIn Add to Profile button pre-populates fields | e2e | P1 | manual |
| AC-023 | Public badge URL renders Open Graph metadata | integration | P1 | automated |
| AC-024 | Enterprise API filters assertions by date and badge class | integration | P1 | automated |
| AC-025 | Webhook delivery within 60s of badge issuance | integration | P1 | automated |
| AC-026 | Webhook retries with exponential backoff on failure | integration | P1 | automated |
| AC-027 | Badge recipient identity is SHA-256 hashed | integration | P0 | automated |
| AC-028 | Rate limiting triggers HTTP 429 after 100 requests/min/IP | integration | P1 | automated |
| AC-029 | Anomaly alert fires for >1000 verifications/hour | monitoring | P1 | automated |
| AC-030 | Analytics dashboard shows per-tenant metrics only | e2e | P1 | semi |
| AC-031 | Enterprise API analytics endpoint returns tenant-scoped data | integration | P1 | automated |
| AC-032 | Prometheus metrics exposed for badge operations | integration | P0 | automated |
| AC-033 | Badge issuance failure logs include correlation_id | integration | P1 | automated |

## Unit Tests

- OpenBadges 2.0 assertion schema validation
- BadgeClass field validation (name, description, image, criteria)
- Issuer Profile required fields validation
- SHA-256 email hashing with salt
- JIT badge template validation (image format, dimensions, file size)
- Transaction idempotency key generation
- SAML attribute mapping logic
- Webhook URL validation (HTTPS, no private IPs)
- Badge expiration date calculations
- Revocation reason validation
- Blockchain anchoring Merkle tree construction
- Tenant isolation queryset filters

## Integration Tests

- Badgr Server K8s deployment readiness and health checks
- COURSE_COMPLETION event → badge issuance pipeline (end-to-end)
- PROGRAM_COMPLETION event → badge issuance pipeline
- Manual badge issuance via admin portal API
- Bulk badge issuance CSV processing (happy path + validation errors)
- Badge issuance idempotency (duplicate detection)
- Multi-tenant badge class isolation (cannot access other tenant's classes)
- Multi-tenant assertion isolation (API returns only own tenant's badges)
- Public verification endpoint (valid, revoked, expired, not_found)
- CORS headers on verification endpoint
- Public signing key endpoint accessibility
- Badge revocation flow (admin UI → assertion status → verification response)
- Bulk badge revocation (500 assertions)
- Blockchain anchoring batch creation and transaction submission
- Enterprise HR API assertion list endpoint (pagination, filtering)
- Enterprise HR API webhook registration and delivery
- Webhook retry logic (exponential backoff, dead letter queue)
- Webhook payload signing (HMAC verification)
- Rate limiting on verification endpoint (per-IP)
- Anomalous verification pattern detection (>1000 requests/hour)
- Badge analytics aggregation (issuance, sharing, verification counts)
- Prometheus metrics scraping (/metrics endpoint)
- Badgr Server to Cloud SQL connection
- Badgr Server to Redis connection (cache + Celery broker)
- Badge template image upload to GCS bucket
- Badge assertion email notification delivery

## E2E Tests

- Learner completes course → receives badge email → views in portfolio → shares to LinkedIn
- Enterprise admin creates badge template → associates with course → learner completes → badge issued
- Enterprise admin manually awards badge → learner receives notification → activates → public verification succeeds
- Enterprise admin bulk-assigns 1000 badges via CSV → all learners notified → bulk activation
- Learner views credential portfolio with badges from multiple enterprise tenants
- Enterprise admin revokes badge → learner sees "Revoked" status → public verification returns 404
- Third-party verifier accesses public assertion URL → validates signature → confirms authenticity
- Enterprise HR system registers webhook → badge issued → webhook fires → HR system receives payload
- Blockchain anchoring enabled → badge issued → anchoring batch processed → on-chain transaction confirmed
- Badge expiration policy enforced → expired badge shows in portfolio with "Expired" status
- Admin portal analytics dashboard loads → shows tenant-specific badge metrics

## Manual Verification

- DNS-only Cloudflare mode for badges.academyv2.mereka.io (gray cloud icon)
- Let's Encrypt certificate validity (not Cloudflare Universal SSL)
- LinkedIn "Add to Profile" button behavior (opens LinkedIn with pre-populated fields)
- Social sharing buttons (Twitter/X, Facebook, copy link) functionality
- Badge image rendering in learner portfolio (visual inspection)
- Badge assertion JSON-LD compliance (validate with IMS Open Badges Validator)
- Public badge profile page privacy controls (opt-in/opt-out)
- Multi-tenant branding verification (badge displays correct tenant logo/colors)
- Badge template designer UX (admin portal visual inspection)
- Blockchain anchoring cost tracking (actual gas fees vs estimates)
- Break-glass procedure for Badgr Server admin access (documented runbook test)
- Badge reconciliation job effectiveness (manual completion → reconciliation catches up)

## Monitoring Verification

- Alert fires when Badgr Server health check fails for >3 consecutive checks
- Alert fires when badge_issuance_queue_depth exceeds 1000 for 10 minutes
- Alert fires when blockchain_anchor failures exceed 3 in 1 hour
- Warning fires when badge_issuance p95 latency exceeds 120 seconds for 15 minutes
- Warning fires when verification rate_limited count exceeds 100 in 5 minutes
- Warning fires when webhook delivery failure rate exceeds 20% for 1 hour
- Warning fires when blockchain anchoring daily cost exceeds $50
- Info alert when badge sharing rate is zero for 30 days for any tenant
- Grafana dashboard "Badge Operations" displays expected panels
- Grafana dashboard "Badge Analytics" displays per-tenant metrics
- Grafana dashboard "Blockchain Anchoring" displays cost and success rate
- Grafana dashboard "Webhook Health" displays delivery success rate
- Prometheus scrapes badge-specific metrics (issuance_total, verification_requests_total)
