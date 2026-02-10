---
spec: badges-credentials-enterprise_spec.md
tier: 5
status: draft
test_framework: shell_verification + kubectl_check + smoke_test + manual_verification
---

# Test Plan: Badges & Credentials Enterprise Integration

**Source Spec**: `specs/badges-credentials-enterprise_spec.md`

---

## Test Framework

This project uses infrastructure-as-code testing patterns consistent with the rest of the `mereka-lms` repository:

| Test Type | Tool | Location |
|-----------|------|----------|
| `shell_verification` | Bash scripts (`set -euo pipefail`) | `scripts/qa/verify-*.sh` |
| `kubectl_check` | kubectl commands | Inline in scripts or documented in testmap |
| `smoke_test` | Bash scripts with curl/HTTP checks | `scripts/qa/smoke-test-*.sh` |
| `manual_verification` | Human checklist | Documented inline in this test plan |
| `load_test` | k6 or custom scripts | `scripts/qa/load-test-*.sh` |

---

## Test Matrix

### Badgr Server Deployment (AC-001 through AC-004)

| AC # | Test Case | Type | File | Mocks/Fixtures |
|------|-----------|------|------|----------------|
| AC-001 | Badgr Server deployment exists with READY replicas >= 1 | kubectl_check | `scripts/qa/verify-badgr-server-deployment.sh` | None (live cluster) |
| AC-001 | Deployment labels match convention (`app.kubernetes.io/name: badgr-server`) | kubectl_check | `scripts/qa/verify-badgr-server-deployment.sh` | None |
| AC-002 | Internal health check `http://badgr-server:8000/health/` returns HTTP 200 | smoke_test | `scripts/qa/verify-badgr-server-deployment.sh` | kubectl exec into pod |
| AC-003 | External health check `https://badges.academyv2.mereka.io/health/` returns HTTP 200 | smoke_test | `scripts/qa/verify-badgr-server-deployment.sh` | None (public endpoint) |
| AC-004 | Badgr worker deployment exists with READY replicas >= 1 | kubectl_check | `scripts/qa/verify-badgr-server-deployment.sh` | None |
| EC-infra-1 | Badgr Server scaled to zero does not affect LMS or credentials service | shell_verification | `scripts/qa/verify-badgr-server-deployment.sh` | Scale to 0 then check LMS health |
| EC-infra-2 | ExternalSecret `badge-secrets` syncs all 5 secrets successfully | kubectl_check | `scripts/qa/verify-badgr-server-deployment.sh` | None |

### Badge Issuance (AC-005 through AC-009)

| AC # | Test Case | Type | File | Mocks/Fixtures |
|------|-----------|------|------|----------------|
| AC-005 | Course completion triggers badge assertion within 60s; assertion is valid OB 2.0; email sent | smoke_test | `scripts/qa/smoke-test-badge-issuance.sh` | Test learner + test course with BadgeClass |
| AC-005 | Badge assertion contains all required OB 2.0 fields (@context, type, id, recipient, badge, issuedOn, verification) | shell_verification | `scripts/qa/smoke-test-badge-issuance.sh` | Parse assertion JSON with jq |
| AC-005 | Notification email contains badge name, image, issuer, claim link, LinkedIn share link | manual_verification | N/A | Check test learner inbox |
| AC-006 | Program completion triggers program badge assertion | smoke_test | `scripts/qa/smoke-test-badge-issuance.sh` | Test learner + test program with BadgeClass |
| AC-007 | Duplicate course completion does NOT create duplicate assertion | smoke_test | `scripts/qa/smoke-test-badge-issuance.sh` | Trigger same completion twice, check assertion count |
| AC-008 | Manual badge issuance via admin portal creates assertion and sends email | smoke_test | `scripts/qa/smoke-test-badge-issuance.sh` | Test admin + manual issuance API call |
| AC-009 | Bulk CSV with 1000 rows completes within 10 minutes; completion report available | smoke_test | `scripts/qa/smoke-test-badge-issuance.sh` | Generated CSV fixture |
| EC-issuance-1 | Issuance retry on Badgr Server unavailable (5 retries, exponential backoff, DLQ after exhaustion) | shell_verification | `scripts/qa/verify-badge-issuance-resilience.sh` | Scale Badgr to 0 during issuance |
| EC-issuance-2 | Reconciliation job catches missed badges (disable event bus, complete course, verify reconciliation) | shell_verification | `scripts/qa/verify-badge-issuance-resilience.sh` | Disable event consumer, trigger completion |
| EC-issuance-3 | Course completed before BadgeClass exists: no retroactive badge issuance | shell_verification | `scripts/qa/verify-badge-issuance-resilience.sh` | Complete course, then create BadgeClass |
| EC-issuance-4 | Bulk CSV with invalid row mid-file: valid rows process, error report for invalid rows | shell_verification | `scripts/qa/smoke-test-badge-issuance.sh` | CSV with intentional bad rows |

### Multi-Tenant Isolation (AC-010 through AC-013)

| AC # | Test Case | Type | File | Mocks/Fixtures |
|------|-----------|------|------|----------------|
| AC-010 | Admin A sees only tenant A's badge classes via enterprise API | shell_verification | `scripts/qa/verify-badge-tenant-isolation.sh` | Two test tenants + JWTs |
| AC-011 | Admin B accessing tenant A's assertions returns HTTP 403 | shell_verification | `scripts/qa/verify-badge-tenant-isolation.sh` | Cross-tenant API call |
| AC-012 | Badge assertion JSON shows tenant A's branding (issuer name, logo, URL), not Mereka Academy default | shell_verification | `scripts/qa/verify-badge-tenant-isolation.sh` | Parse assertion JSON issuer field |
| AC-013 | Learner in both tenants sees badges from both, labeled by issuer | manual_verification | N/A | Check portfolio page as dual-tenant learner |
| EC-tenant-1 | Deactivated tenant: badges remain verifiable, new issuance blocked | shell_verification | `scripts/qa/verify-badge-tenant-isolation.sh` | Deactivate test tenant |
| EC-tenant-2 | Issuer branding update: existing assertions reference issuer URL (latest branding), not snapshot | shell_verification | `scripts/qa/verify-badge-tenant-isolation.sh` | Update issuer logo, check assertion |
| EC-tenant-3 | Removed admin: pending bulk tasks complete, admin access immediately revoked | manual_verification | N/A | Remove admin mid-bulk-issuance |

### Public Verification (AC-014 through AC-017)

| AC # | Test Case | Type | File | Mocks/Fixtures |
|------|-----------|------|------|----------------|
| AC-014 | Valid assertion URL returns HTTP 200 with OB 2.0 JSON and `Content-Type: application/ld+json` | smoke_test | `scripts/qa/verify-badge-verification.sh` | Known valid assertion UID |
| AC-015 | Revoked assertion URL returns HTTP 404 with revocation metadata | smoke_test | `scripts/qa/verify-badge-verification.sh` | Known revoked assertion UID |
| AC-016 | CORS header `Access-Control-Allow-Origin: *` present in verification response | smoke_test | `scripts/qa/verify-badge-verification.sh` | OPTIONS request with Origin header |
| AC-017 | Signing public key endpoint returns PEM or JWK at `/.well-known/badgeclass-signing-key` | smoke_test | `scripts/qa/verify-badge-verification.sh` | GET request |
| EC-verify-1 | Expired badge: HTTP 200 with assertion + `X-Badge-Status: expired` header | smoke_test | `scripts/qa/verify-badge-verification.sh` | Badge with past expiration date |
| EC-verify-2 | High-traffic verification attack: 10,000 req/hr served from cache, not per-request DB query | load_test | `scripts/qa/load-test-badges.sh` | k6 or ab load generator |
| EC-verify-3 | Concurrent revocation + verification: no inconsistent state returned | shell_verification | `scripts/qa/verify-badge-verification.sh` | Parallel revocation + verification |
| EC-verify-4 | Non-existent assertion UID returns HTTP 404 | smoke_test | `scripts/qa/verify-badge-verification.sh` | Random UID |

### Badge Revocation (AC-018 through AC-020)

| AC # | Test Case | Type | File | Mocks/Fixtures |
|------|-----------|------|------|----------------|
| AC-018 | Single revocation: public URL returns 404 with metadata; portfolio shows "Revoked"; audit log created | smoke_test | `scripts/qa/verify-badge-revocation.sh` | Issue then revoke a test badge |
| AC-019 | Bulk revocation of 500 assertions completes within 5 minutes; revocation list updated | smoke_test | `scripts/qa/verify-badge-revocation.sh` | 500 pre-issued test badges |
| AC-020 | Blockchain-anchored revoked badge: UID in revocation list, on-chain anchor unchanged | shell_verification | `scripts/qa/verify-badge-revocation.sh` | Blockchain-anchored test badge |
| EC-revoke-1 | Revoked badge not re-issuable unless admin explicitly creates new assertion | shell_verification | `scripts/qa/verify-badge-revocation.sh` | Attempt re-issuance after revocation |
| EC-revoke-2 | Revocation reason required (empty reason rejected) | shell_verification | `scripts/qa/verify-badge-revocation.sh` | Revocation with empty reason |

### LinkedIn Integration (AC-021, AC-022)

| AC # | Test Case | Type | File | Mocks/Fixtures |
|------|-----------|------|------|----------------|
| AC-021 | "Add to LinkedIn" button redirects with correct parameters (name, org, dates, URL) | manual_verification | N/A | Click button, verify LinkedIn pre-fill |
| AC-021 | LinkedIn redirect URL contains correct query parameters | shell_verification | `scripts/qa/smoke-test-badge-portfolio.sh` | Parse portfolio HTML for LinkedIn URL |
| AC-022 | Public badge URL returns Open Graph metadata (og:title, og:description, og:image) | smoke_test | `scripts/qa/smoke-test-badge-portfolio.sh` | curl + parse HTML meta tags |

### Enterprise HR API (AC-023 through AC-025)

| AC # | Test Case | Type | File | Mocks/Fixtures |
|------|-----------|------|------|----------------|
| AC-023 | Enterprise API returns filtered, paginated assertions for tenant | shell_verification | `scripts/qa/verify-badge-enterprise-api.sh` | Test tenant JWT + pre-issued badges |
| AC-023 | API requires JWT with `enterprise_admin` role; unauthenticated request returns 401 | shell_verification | `scripts/qa/verify-badge-enterprise-api.sh` | Unauthenticated request |
| AC-024 | Webhook receives POST with `badge_issued` event within 60s of badge issuance | smoke_test | `scripts/qa/verify-badge-enterprise-api.sh` | Webhook receiver endpoint (httpbin/webhook.site) |
| AC-025 | Failed webhook delivery retries up to 5 times with exponential backoff | shell_verification | `scripts/qa/verify-badge-enterprise-api.sh` | Webhook URL returning 500 |
| EC-webhook-1 | Webhook URL targeting private IP range rejected (SSRF prevention) | shell_verification | `scripts/qa/verify-badge-enterprise-api.sh` | Attempt to register `http://10.0.0.1/hook` |
| EC-webhook-2 | After 10 consecutive failures, webhook auto-suspended; admin notified | shell_verification | `scripts/qa/verify-badge-enterprise-api.sh` | Persistently failing webhook |
| EC-webhook-3 | Webhook payload <= 64 KB; large payloads include API fetch URL instead | shell_verification | `scripts/qa/verify-badge-enterprise-api.sh` | Check payload size |

### Anti-Fraud (AC-026 through AC-028)

| AC # | Test Case | Type | File | Mocks/Fixtures |
|------|-----------|------|------|----------------|
| AC-026 | Assertion JSON `recipient.identity` contains SHA-256 hash, not plaintext email | shell_verification | `scripts/qa/verify-badge-verification.sh` | Parse assertion JSON |
| AC-027 | 101st request from same IP within 1 minute returns HTTP 429 with Retry-After | smoke_test | `scripts/qa/verify-badge-verification.sh` | Rapid-fire curl loop |
| AC-028 | 1000+ verification requests for single assertion within 1 hour triggers alert | shell_verification | `scripts/qa/verify-badge-verification.sh` | Simulate requests + check Alertmanager |
| EC-antifraud-1 | Signing keys stored in K8s Secrets, not in database or API response | kubectl_check | `scripts/qa/verify-badge-verification.sh` | Check K8s secret exists; verify no key in API |
| EC-antifraud-2 | Verification logs do not contain raw email or private key material | shell_verification | `scripts/qa/verify-badge-verification.sh` | Query Loki for sensitive patterns |

### Credential Analytics (AC-029, AC-030)

| AC # | Test Case | Type | File | Mocks/Fixtures |
|------|-----------|------|------|----------------|
| AC-029 | Admin portal analytics dashboard shows total issued, sharing rate, verification count, top badge classes | manual_verification | N/A | Visual inspection of dashboard |
| AC-029 | Analytics data scoped to requesting tenant only | shell_verification | `scripts/qa/verify-badge-enterprise-api.sh` | Compare analytics across two tenants |
| AC-030 | Enterprise API `/analytics/` endpoint returns aggregate metrics for tenant | shell_verification | `scripts/qa/verify-badge-enterprise-api.sh` | API call with tenant JWT |

### Observability (AC-031, AC-032)

| AC # | Test Case | Type | File | Mocks/Fixtures |
|------|-----------|------|------|----------------|
| AC-031 | Prometheus scrape of `/metrics` includes badge-specific metrics (issuance count, verification latency, queue depth) | shell_verification | `scripts/qa/verify-badge-observability.sh` | curl `/metrics` endpoint |
| AC-031 | Grafana dashboards load without errors | manual_verification | N/A | Visual inspection |
| AC-032 | Failed badge issuance log includes `enterprise_customer_uuid`, `badge_class_id`, `learner_user_id`, `error_type`, `correlation_id` | shell_verification | `scripts/qa/verify-badge-observability.sh` | Query Loki for structured log fields |
| AC-032 | Logs do not contain raw email addresses or private keys | shell_verification | `scripts/qa/verify-badge-observability.sh` | Loki query for sensitive patterns |

---

## Non-Functional Requirement Tests

### Performance

| NFR | Test Case | Type | File | Pass Criteria |
|-----|-----------|------|------|---------------|
| p95 badge issuance <= 60s | Issue 100 badges, measure p95 latency | load_test | `scripts/qa/load-test-badges.sh` | p95 < 60,000ms |
| p95 verification <= 200ms | 10,000 verification requests, measure p95 | load_test | `scripts/qa/load-test-badges.sh` | p95 < 200ms |
| p95 enterprise API <= 500ms | 1,000 API requests (100 items/page), measure p95 | load_test | `scripts/qa/load-test-badges.sh` | p95 < 500ms |
| Bulk 1000 badges <= 10 min | Upload 1000-row CSV, measure completion time | smoke_test | `scripts/qa/smoke-test-badge-issuance.sh` | Duration < 600s |
| p95 portfolio load <= 3s | Load portfolio for user with 50 badges | smoke_test | `scripts/qa/smoke-test-badge-portfolio.sh` | p95 < 3,000ms |
| Blockchain batch <= 30 min | Trigger batch, measure completion | smoke_test | `scripts/qa/verify-badge-blockchain-anchoring.sh` | Duration < 1,800s |

### Security

| Test Case | Type | File | Pass Criteria |
|-----------|------|------|---------------|
| Internal Badgr communication uses K8s DNS, not external URLs | shell_verification | `scripts/qa/verify-badgr-server-deployment.sh` | Config shows `http://badgr-server:8000` |
| Non-public Badgr API endpoints require JWT | smoke_test | `scripts/qa/verify-badge-enterprise-api.sh` | Unauthenticated returns 401 |
| Badge image upload rejects non-PNG/SVG and >1MB files | shell_verification | `scripts/qa/verify-badge-tenant-isolation.sh` | Upload .exe returns 400; >1MB returns 400 |
| Enterprise API enforces queryset-level tenant isolation | shell_verification | `scripts/qa/verify-badge-tenant-isolation.sh` | Cross-tenant query returns 403 |
| API rate limiting: 100 req/min per admin, 1000 req/min per service account | smoke_test | `scripts/qa/verify-badge-verification.sh` | 101st request returns 429 |

### Privacy

| Test Case | Type | File | Pass Criteria |
|-----------|------|------|---------------|
| Learner can make profile private (public URL returns 404) | smoke_test | `scripts/qa/smoke-test-badge-portfolio.sh` | POST privacy toggle; GET returns 404 |
| Assertion JSON hashes recipient email (no plaintext) | shell_verification | `scripts/qa/verify-badge-verification.sh` | `recipient.identity` matches SHA-256 pattern |
| DSC enforcement: badge data only for learners who granted consent | shell_verification | `scripts/qa/verify-badge-enterprise-api.sh` | Learner without DSC excluded from API |
| Verification logs retained max 90 days | manual_verification | N/A | Loki retention policy check |

---

## Test Execution Order

1. **Phase 0 tests**: Deployment, health checks, secrets sync (gate for Phase 1)
2. **Phase 1 tests**: Badge issuance, idempotency, OB 2.0 compliance (gate for Phase 2)
3. **Phase 2 tests**: Tenant isolation, branding, BadgeClass CRUD (gate for Phase 3/4)
4. **Phase 3 tests**: Portfolio, LinkedIn integration, social sharing (can run parallel with Phase 4)
5. **Phase 4 tests**: Enterprise API, webhooks, revocation, anti-fraud
6. **Phase 5 tests**: Blockchain anchoring, load tests, observability
7. **Cross-cutting**: Security tests, privacy tests, NFR performance tests (final gate)

---

## Test Scripts Inventory

| Script | Tests Covered | Phase |
|--------|--------------|-------|
| `scripts/qa/verify-badgr-server-deployment.sh` | AC-001, AC-002, AC-003, AC-004, backward compat | 0 |
| `scripts/qa/smoke-test-badge-issuance.sh` | AC-005, AC-006, AC-007, AC-008, AC-009 | 1 |
| `scripts/qa/verify-badge-issuance-resilience.sh` | Retry/DLQ, reconciliation, pre-BadgeClass completion | 1 |
| `scripts/qa/verify-badge-tenant-isolation.sh` | AC-010, AC-011, AC-012, AC-013, tenant edge cases | 2 |
| `scripts/qa/smoke-test-badge-portfolio.sh` | AC-021, AC-022, portfolio load, privacy | 3 |
| `scripts/qa/verify-badge-verification.sh` | AC-014, AC-015, AC-016, AC-017, AC-026, AC-027, AC-028 | 4 |
| `scripts/qa/verify-badge-revocation.sh` | AC-018, AC-019, AC-020, revocation edge cases | 4 |
| `scripts/qa/verify-badge-enterprise-api.sh` | AC-023, AC-024, AC-025, AC-029, AC-030, webhook edge cases | 4 |
| `scripts/qa/verify-badge-observability.sh` | AC-031, AC-032, log sanitization | 5 |
| `scripts/qa/verify-badge-blockchain-anchoring.sh` | AC-020 (blockchain aspect), anchoring edge cases | 5 |
| `scripts/qa/load-test-badges.sh` | NFR performance (issuance, verification, API) | 5 |
