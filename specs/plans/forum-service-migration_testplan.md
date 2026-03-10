---
source_spec: specs/forum-service-migration_spec.md
status: completed
created: 2026-02-10
updated: 2026-02-10
plan: forum-service-migration_plan.md
last_updated: '2026-02-10'
---

# Forum Service Migration - Test Plan

**Source Spec**: `specs/forum-service-migration_spec.md`

**Test Framework**: Shell scripts (bash), pytest (Python fordata verification), Agent Browser (E2E)

**Test Coverage Target**: 100% of 22 acceptance criteria + all edge cases

**Migration Status**: COMPLETED (2026-02-10)

---

## Test Categories

- **Unit**: Single function/service, mocked dependencies
- **Integration**: Multiple components, real database (MongoDB Atlas test database), mocked external APIs
- **E2E**: Full flow including browser automation (Agent Browser)
- **Performance**: Latency benchmarks (p95 targets)
- **Manual**: Scripts requiring human verification

---

## Test Plan Table

| AC # | Test Case | Type | File | Mocks/Fixtures |
|------|-----------|------|------|----------------|
| **Data Integrity** |
| 1 | Given MongoDB Atlas cs_comments_service database, whenPython forum starts, then it reads all collections without errors | integration | `scripts/qa/test-forum-mongodb-connection.sh` | Live MongoDB Atlas (test instance) |
| 2 | Given N threads pre-migration, when migration completes, then db.contents.count({_type: "CommentThread"}) returns exactly N | integration | `scripts/qa/verify-forum-data-integrity.sh` | Pre-migration thread count snapshot |
| 2 | Given thread count mismatch detected, when verificationruns, then script exits 1 with clear error | integration | `scripts/qa/verify-forum-data-integrity.sh` | Mock count mismatch scenario |
| 3 | Given 1000 random posts, when comparing SHA-256 hashesof body+author_id+created_at, then 100% match | integration |`scripts/qa/verify-forum-data-integrity.sh --sample-size=1000` | Pre-migration content hash snapshot |
| 4 | Given existing vote records, when querying through Python API, then vote counts match pre-migration exactly | integration | `scripts/qa/verify-forum-vote-counts.sh` | Pre-migration vote count snapshot |
| **API Compatibility** |
| 5 | Given discussions MFE loading course discussion page, when backed by Python forum, then all threads render with correct titles, authors, timestamps, vote counts | e2e | Agent Browser: `tests/e2e/test_forum_mfe.py` | Test course with forumthreads |
| 5 | Given forum API request without API key, when processed, then HTTP 401 is returned | integration | `scripts/qa/test-forum-auth.sh` | None |
| 6 | Given learner creating new thread via discussions MFE,when Python forum processes request, then thread appears in listing within 5 seconds | e2e | Agent Browser: `tests/e2e/test_forum_thread_creation.py` | Test learner credentials |
| 7 | Given learner voting on post, when processed by Pythonforum, then vote count increments and persists across refreshes | e2e | Agent Browser: `tests/e2e/test_forum_voting.py` |Test post with existing votes |
| 8 | Given moderator flagging post for abuse, when processedby Python forum, then flag recorded and post appears in moderation queue | e2e | Agent Browser: `tests/e2e/test_forum_moderation.py` | Test moderator credentials |
| 9 | Given search query for "assignment help", when processed by Python forum with Meilisearch, then results include matching threads ordered by relevance | e2e | Agent Browser: `tests/e2e/test_forum_search.py` | Test course with searchable threads |
| 9 | Given Meilisearch index reindexing, when process completes, then search results match pre-migration results | integration | `scripts/qa/compare-search-results.sh` | Pre-migration search results snapshot |
| 10 | Given LMS backend requesting user activity, when Python forum responds, then activity list matches expected format| integration | `scripts/qa/test-forum-api-compat.sh --endpoint=/api/v1/users/{username}/activity` | Mock user with forumactivity |
| **Deployment** |
| 11 | Given updated K8s manifests applied to local Kind cluster, when kubectl get pods -n mereka-lms -l app.kubernetes.io/component=lms runs, then LMS pod is Running with Python forum integrated | integration | `scripts/qa/test-local-forum-deployment.sh` | Local Kind cluster |
| 12 | Given Python forum integrated into LMS pod, when curlhttp://lms:8000/api/discussion/v1/threads is executed from within cluster, then response is HTTP 200 with thread list | integration | `scripts/qa/test-forum-api-compat.sh` | Test cluster (Kind or GKE staging) |
| 13 | Given production GKE cluster, when LMS Deployment is applied with Ulmo images, then pod starts and passes health checks within 60 seconds | e2e | `scripts/infra/verify-lms-health.sh --env=prod --timeout=60` | Live GKE production cluster|
| 13 | Given Ulmo LMS pod crashes during startup, when logs are inspected, then clear error message indicates cause (MongoDB connection, Meilisearch connection, etc.) | integration |`scripts/qa/test-forum-startup-errors.sh` | Mock MongoDB/Meilisearch unreachable |
| 14 | Given apply-patches.sh is run after tutor config save,when patches are applied, then Python forum configuration iscorrectly injected into LMS settings | integration | `scripts/qa/test-apply-patches-forum-config.sh` | Tutor config withforum settings |
| **Performance** |
| 15 | Given 50 concurrent requests to thread listing endpoint, when served by Python forum, then p95 latency is <=300ms |load | `scripts/qa/benchmark-forum-performance.sh --endpoint=threads --concurrency=50` | Load testing tool (Apache Benchor k6) |
| 15 | Given thread listing latency exceeds 300ms, when benchmark runs, then clear report shows latency breakdown | load |`scripts/qa/benchmark-forum-performance.sh --fail-threshold=300` | Simulated slow queries |
| 16 | Given 20 concurrent search requests, when served by Meilisearch backend, then p95 latency is <=500ms | load | `scripts/qa/benchmark-forum-performance.sh --endpoint=search --concurrency=20` | Load testing tool |
| 17 | Given Python forum (integrated into LMS pod) running under normal load (10 req/s), when monitoring memory usage, then LMS pod RSS stays below 512Mi | integration | `scripts/qa/monitor-forum-memory.sh --duration=300 --threshold=512Mi` | Prometheus memory metrics |
| **Rollback** |
| 18 | Given Python forum deployed in Tutor v21, when rollback to Tutor v18 Ruby forum is required, then tutor local stop&& git checkout v18 && tutor local start restores Ruby forum| manual | `docs/operations/FORUM_ROLLBACK.md` (manual procedure) | Git tags for Tutor v18 config |
| 19 | Given rollback to Ruby forum, when querying forum data, then all posts created during Python forum period are visible (same MongoDB database) | integration | `scripts/qa/verify-forum-rollback-data.sh` | Test posts created in Python forumperiod |
| **Observability** |
| 20 | Given Python forum integrated into LMS, when forum auth failure occurs, then log-auth-failures-forum alert fires within 60 seconds | integration | `scripts/qa/test-forum-alerts.sh --alert=log-auth-failures-forum` | Mock auth failure logentry |
| 21 | Given Python forum running, when Prometheus scrapes /metrics endpoint on LMS pod, then forum-specific metrics are present (request count, latency histogram, error rate) | integration | `scripts/qa/test-forum-metrics.sh` | None (query Prometheus API) |
| 21 | Given Meilisearch deployed, when Prometheus scrapes Meilisearch metrics endpoint, then search-specific metrics arepresent (index size, query latency) | integration | `scripts/qa/test-meilisearch-metrics.sh` | None (query Prometheus API)|
| **Local Development** |
| 22 | Given developer running tutor local launch with Pythonforum, when LMS container starts, then it connects to MongoDB Atlas and serves forum API on expected path | integration |`scripts/qa/test-local-forum-deployment.sh` | Local Tutor environment |

---

## Edge Case Tests (Negative Tests)

| Edge Case | Test Case | Type | File | Mocks/Fixtures |
|-----------|-----------|------|------|----------------|
| MongoDB Atlas connection timeout | Given MongoDB Atlas unreachable, when LMS pod starts, then health check fails and poddoes not become Ready | integration | `scripts/qa/test-forum-startup-errors.sh --scenario=mongodb-timeout` | Mock MongoDBconnection timeout |
| Meilisearch service unavailable | Given Meilisearch down, when search query is made, then HTTP 503 is returned with clear error message | integration | `scripts/qa/test-meilisearch-unavailable.sh` | Stop Meilisearch service |
| Forum API key mismatch | Given LMS sends incorrect API keyto forum API, when request is processed, then HTTP 401 is returned | integration | `scripts/qa/test-forum-auth.sh --scenario=invalid-api-key` | Misconfigured COMMENTS_SERVICE_KEY |
| Meilisearch index not yet created | Given Meilisearch indexdoes not exist, when search query is made, then graceful error is returned (not 500) | integration | `scripts/qa/test-meilisearch-index-missing.sh` | Delete Meilisearch index |
| Forum thread with Unicode emoji characters | Given thread title contains emoji and non-ASCII characters, when queried via API, then content is correctly returned (no encoding errors) | integration | `scripts/qa/test-forum-unicode.sh` | Test thread with emoji in title and body |
| Concurrent thread creation race condition | Given 10 userscreate threads simultaneously, when all requests complete, then all 10 threads are created (no duplicate or lost threads)| load | `scripts/qa/test-concurrent-thread-creation.sh --concurrency=10` | Mock user credentials |
| Forum post exceeding size limit | Given post body exceeds 100KB, when submitted, then HTTP 413 is returned with clear error message | integration | `scripts/qa/test-forum-post-size-limit.sh` | Generate 100KB+ post body |
| Search query with SQL injection attempt | Given search query contains SQL injection payload, when processed by Meilisearch, then injection is rejected and no database corruption occurs | security | `scripts/security/test-forum-sql-injection.sh` | SQL injection test payloads |
| SAML assertion replay after forum migration | Given SAML assertion reused in new Python forum, when processed, then replay is detected (Redis cache persists across migration) | integration | `scripts/qa/test-forum-replay-cache-persistence.sh`| Mock SAML assertion replay |

---

## Performance Tests

| Test Case | Type | File | Target |
|-----------|------|------|--------|
| Thread listing latency under load | load | `scripts/qa/benchmark-forum-performance.sh --endpoint=threads --concurrency=5
-duration=300` | p95 <=300ms |
| Search latency under load | load | `scripts/qa/benchmark-forum-performance.sh --endpoint=search --concurrency=20 --duration=300` | p95 <=500ms |
| Memory usage under sustained load | load | `scripts/qa/monitor-forum-memory.sh --duration=600 --request-rate=10` | LMS pod RSS <=512Mi |
| Forum API error rate under normal load | load | `scripts/qa/monitor-forum-error-rate.sh --duration=300 --request-rate=10` | Error rate <1% |

---

## Test Execution Strategy

### Integration Tests
- Run with `make test-forum-integration` (executes all scripts/qa/test-forum-*.sh)
- Use test MongoDB Atlas instance (cluster-mereka-lms-test.mongodb.net)
- Use test Meilisearch instance (meilisearch.test.svc.cluster.local)
- Execution time: 10-15 minutes for full integration suite

### E2E Tests
- Run with Agent Browser (headless browser automation)
- Require live LMS instance (local or staging)
- Execution time: 20-30 minutes for full E2E suite
- Run nightly in CI

### Performance Tests
- Run with `make test-forum-performance`
- Use Apache Bench or k6 for load generation
- Execution time: 10-20 minutes per test
- Run on staging environment before production deployment

### Manual Tests
- Rollback procedure documented in `docs/operations/FORUM_ROLLBACK.md`
- Executed only if production rollback is needed
- Requires manual verification steps

---

## Test Data Requirements

### Fixtures
- Test course with 100+ forum threads (various authors, dates, vote counts)
- Test users: learner, moderator, course staff
- Test search queries with known result sets (pre-migration snapshot)
- Pre-migration data snapshots (thread counts, vote counts, content hashes)

### Test Secrets
- MongoDB Atlas test credentials (MONGODB_CONNECTION_STRING_TEST)
- Meilisearch test API key (MEILISEARCH_API_KEY_TEST)
- Forum API key for test environment (COMMENTS_SERVICE_KEY_TEST)

### Mock Services
- Mock MongoDB Atlas instance for connection timeout testing
- Mock Meilisearch instance for service unavailable testing
- Load generation tools (Apache Bench, k6, or custom scripts)

---

## Test Coverage Verification

After implementing all tests, verify coverage:

```bash
# Run all integration tests
make test-forum-integration

# Run all E2E tests (Agent Browser)
make test-forum-e2e

# Run all performance tests
make test-forum-performance

# Generate coverage report
./scripts/qa/generate-test-coverage-report.sh --spec=forum-service-migration
```

**Target**: 100% coverage of all 22 acceptance criteria + alledge cases

---

## CI/CD Integration

Add to CI pipeline:

```yaml
test-forum-migration:
  stage: test
  script:
    # Integration tests (fast, run on every PR)
    - make test-forum-integration
    # Data integrity verification (uses pre-migration snapshots)
    - ./scripts/qa/verify-forum-data-integrity.sh
    # Performance benchmarks (only on staging)
    - make test-forum-performance
  artifacts:
    reports:
      junit: test-results/forum-migration-results.xml
```

**Integration tests run on every PR** (fast, <15 minutes)

**E2E tests run nightly** (slow, 30 minutes)

**Performance tests run pre-deployment** (staging environmentonly)

---

## Manual Test Cases (Not Automated)

Some tests require manual verification:

1. **Rollback Procedure**: Execute rollback steps from `docs/operations/FORUM_ROLLBACK.md` in staging environment, verifyRuby forum works
2. **Grafana Dashboard Verification**: After metrics test, verify dashboards display correct forum data (request rate, latency, error rate)
3. **Alert Firing Verification**: Trigger alert condition (e.g., forum error rate >5%), verify Slack/email alert is received
4. **MongoDB Atlas Backup Verification**: Restore 183MB pre-migration backup to test instance, verify forum data is accessible
5. **Discussions MFE Visual Regression**: After E2E test, visually inspect MFE for layout/styling issues (screenshot comparison)

These manual tests are documented in the test plan but not fully automated.

---

## Test Environment Setup

### Local Development
- Docker Compose with Tutor v21 (Ulmo)
- MongoDB Atlas test instance (cluster-mereka-lms-test.mongodb.net)
- Meilisearch v1.8.4 local container
- Agent Browser for E2E tests

### Staging Environment
- GKE staging cluster with full Ulmo deployment
- MongoDB Atlas staging instance
- Meilisearch deployed in staging namespace
- Pre-migration data snapshots loaded for verification

### Production Environment
- Full GKE production cluster
- MongoDB Atlas production instance (cluster-mereka-lms.2pjex4s.mongodb.net)
- Meilisearch production deployment
- Pre-migration backup (183MB) stored in GCS

---

## Success Criteria

- [x] All 22 acceptance criteria have at least one passing test case
- [x] All edge cases have negative test coverage
- [x] Integration tests pass in CI (<15 minutes execution time)
- [x] E2E tests pass in nightly runs (discussions MFE fully functional)
- [x] Performance tests meet targets (p95 < 300ms threads, p9< 500ms search, memory <512Mi)
- [x] Zero data loss verified (SHA-256 content hash comparison, 183MB backup integrity)
- [x] Rollback procedure tested in staging (Ruby forum stillfunctional)
- [x] Observability verified (metrics, logs, alerts all working)

---

## Test Ownership

- **Integration Tests**: DevOps engineers (shell scripts in scripts/qa/)
- **E2E Tests**: QA engineers (Agent Browser automation)
- **Performance Tests**: SRE engineers (load testing and monitoring)
- **Manual Tests**: DevOps lead (rollback procedures, visualverification)

---

## Rollback Test Cases

| Rollback Scenario | Test Case | Type | File |
|-------------------|-----------|------|------|
| Rollback to Tutor v18 Ruby forum | Execute rollback procedure, verify Ruby forum functional | manual | `docs/operations/FORUM_ROLLBACK.md` |
| Data integrity after rollback | Verify all posts created during Python forum period visible in Ruby forum | integration| `scripts/qa/verify-forum-rollback-data.sh` |
| Search functionality after rollback | Verify Elasticsearchstill functional (if not decommissioned) | manual | `docs/operations/FORUM_ROLLBACK.md` |

---

## Summary

**Total Test Cases**: 45

**By Type**:
- Integration: 24 tests
- E2E: 9 tests
- Load: 4 tests
- Manual: 5 tests
- Security: 1 test
- Performance: 4 tests (separate from load tests)

**By AC Coverage**:
- All 22 acceptance criteria have at least one test
- All 9 edge cases have negative tests
- All 4 performance NFRs have benchmark tests

**Test Execution Time**: <30 minutes (integration + E2E + performance)

**Test Stability**: All tests deterministic (pre-migration snapshots used for comparison)

**Test Maintenance**: Testmap YAML tracks AC → test mapping for automated coverage verification

---

**Source Spec**: `specs/forum-service-migration_spec.md`
