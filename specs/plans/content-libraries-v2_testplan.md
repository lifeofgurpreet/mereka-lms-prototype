---
source_spec: specs/content-libraries-v2_spec.md
status: ready
created: 2026-02-10
updated: 2026-02-10
plan: content-libraries-v2_plan.md
last_updated: '2026-02-10'
---

# Content Libraries v2 Management & Enterprise Usage - Test Plan

**Source Spec**: `specs/content-libraries-v2_spec.md`

**Test Framework**: pytest (Python) for backend, Playwright for E2E browser automation

**Test Coverage Target**: 100% of 33 acceptance criteria + all edge cases from spec

---

## Test Categories

- **Unit**: Single function/class, mocked dependencies
- **Integration**: Multiple components, test database, mockedexternal services (search, Blockstore)
- **E2E**: Full flow including Studio UI, real Blockstore, test course structure
- **Load**: Performance testing (100 libraries, 1,000 components per library, 100 concurrent users)
- **Security**: OWASP Top 10, cross-tenant isolation bypass attempts, permission escalation

---

## Test Plan Table

| AC # | Test Case | Type | File | Mocks/Fixtures |
|------|-----------|------|------|----------------|
| 1 | Given user with CONTENT_LIBRARY_CREATOR permission andorg "Mereka", when POST /api/libraries/v2/ with valid payload, then library created with key lib:Mereka:compliance-2026 |integration | `tests/integration/test_library_lifecycle.py` |Test DB, Fixture: user with permission |
| 2 | Given library lib:Mereka:compliance-2026 exists, when same POST repeated, then HTTP 400 with "slug already in use" |integration | `tests/integration/test_library_lifecycle.py`| Test DB, Fixture: existing library |
| 3 | Given library with 5 components, when Library Admin calls DELETE, then library soft-deleted and can be restored within 30 days | integration | `tests/integration/test_library_lifecycle.py` | Test DB, Fixture: library with components |
| 4 | Given library lib:Mereka:compliance-2026, when LibraryAuthor calls POST /blocks/ with {"block_type": "html"}, thenHTML component added and has_unpublished_changes=true | integration | `tests/integration/test_component_authoring.py` | Test DB, Mock Blockstore |
| 5 | Given library with 10 components, when component content edited via OLX endpoint, then content updated in draft andhas_unpublished_changes=true | integration | `tests/integration/test_component_authoring.py` | Test DB, Mock Blockstore |
| 6 | Given library, when problem and video components added,then both coexist (mixed-type library) | unit | `tests/unit/test_component_authoring.py` | Test DB |
| 7 | Given library, when unsupported XBlock type added, thenHTTP 400 with "XBlock type not installed" | unit | `tests/unit/test_component_authoring.py` | None |
| 8 | Given library with unpublished drafts, when Library Admin calls POST /commit/, then drafts committed, has_unpublished_changes=false, version record created | integration | `tests/integration/test_versioning.py` | Test DB, Mock Blockstore|
| 9 | Given library with no unpublished changes, when POST /commit/, then HTTP 200 with "No changes to publish" and no newversion | integration | `tests/integration/test_versioning.py` | Test DB |
| 10 | Given library with 3 versions, when revert to version2, then content reverts and has_unpublished_changes=true (staged as draft) | integration | `tests/integration/test_versioning.py` | Test DB, Mock Blockstore history |
| 11 | Given library with published component "quiz-1", whencourse views component, then published version shown (not draft) | e2e | `tests/e2e/test_library_course_integration.py` |Test course, Test DB |
| 12 | Given library with 20 published problems, when library_content XBlock with max_count=5 added to course, then each learner sees 5 random problems | e2e | `tests/e2e/test_library_course_integration.py` | Test course, Test DB |
| 13 | Given library_v2_ref block pointing to "quiz-1", whenlibrary author updates and publishes "quiz-1", then Studio shows "Library content has updates available" | e2e | `tests/e2e/test_library_course_integration.py` | Test course, Test DB|
| 14 | Given notification from AC-13, when course author clicks "Update from library", then course receives latest published version | e2e | `tests/e2e/test_library_course_integration.py` | Test course, Test DB |
| 15 | Given library deleted after course synced content, then course retains last-synced copy and functions without errors | e2e | `tests/e2e/test_library_course_integration.py` | Test course, Test DB |
| 16 | Given user in org "Acme", when GET /api/libraries/v2/,then only Acme libraries and public libraries returned | integration | `tests/integration/test_library_access_control.py`| Test DB, Fixtures: multi-org libraries |
| 17 | Given user in org "Acme", when GET /api/libraries/v2/lib:Beta:internal-training/, then HTTP 403 | integration | `tests/integration/test_library_access_control.py` | Test DB, Fixtures: cross-org access |
| 18 | Given Library Admin, when POST /team/ with {"username": "author1", "access_level": "author"}, then author1 grantedaccess and audit log created | integration | `tests/integration/test_library_access_control.py` | Test DB |
| 19 | Given Library Author, when DELETE /api/libraries/v2/{library_key}/, then HTTP 403 (authors cannot delete) | unit |`tests/unit/test_library_rbac.py` | Test DB |
| 20 | Given enterprise tenants Acme and Beta, when Acme admin creates lib:AcmeCorp:acme-training, then Beta users do NOTsee it in GET /api/libraries/v2/ | integration | `tests/integration/test_tenant_isolation.py` | Test DB, Fixtures: multi-tenant orgs |
| 21 | Given platform library lib:Mereka:shared-templates with allow_public_read=true, when any tenant user calls GET /api/libraries/v2/, then library appears (read-only) | integration | `tests/integration/test_tenant_isolation.py` | Test DB, Fixture: public library |
| 22 | Given Beta user, when attempting to add component fromlib:AcmeCorp:acme-training to course, then operation deniedand security event logged | security | `tests/security/test_tenant_isolation_bypass.py` | Test DB, Mock security logger |
| 23 | Given 50 libraries across 5 orgs, when user from "Mereka" searches "compliance", then only Mereka libraries (and public) with "compliance" returned | integration | `tests/integration/test_library_search.py` | Test DB, Mock search index |
| 24 | Given library with 100 components, when GET /blocks/?page_size=20&page=3, then components 41-60 returned with pagination metadata | integration | `tests/integration/test_library_search.py` | Test DB |
| 25 | Given component tagged "assessments > multiple-choice", when search for "assessments" tag, then library with that component appears | integration | `tests/integration/test_library_search.py` | Test DB, Mock search index |
| 26 | Given library referenced by 3 courses, when GET /links/, then response lists 3 courses with course keys and component references | integration | `tests/integration/test_library_analytics.py` | Test DB, Fixtures: course references |
| 27 | Given learner completes problem from lib:Mereka:compliance-2026, when xAPI event emitted, then event context includes library_key | integration | `tests/integration/test_library_analytics.py` | Mock xAPI event pipeline |
| 28 | Given library with 50 components, when GET /export/, then valid tar.gz OLX archive returned with all content and metadata | integration | `tests/integration/test_library_backup.py` | Test DB, Mock Blockstore |
| 29 | Given OLX archive from AC-28, when POST /import/ witharchive and new slug, then new library created with identicalcontent | integration | `tests/integration/test_library_backup.py` | Test DB |
| 30 | Given OLX archive with unsupported XBlock type, when import attempted, then HTTP 400 with "XBlock type not installed" | unit | `tests/unit/test_library_import_validation.py` |Fixture: OLX with custom XBlock |
| 31 | Given 100 libraries in org "Mereka", when GET /api/libraries/v2/?org=Mereka, then response within 500ms at p95 | load | `tests/performance/test_library_listing_perf.py` | TestDB with 100 libraries |
| 32 | Given library with 1,000 components, when GET /blocks/?page_size=50, then first page within 1000ms at p95 | load |`tests/performance/test_component_listing_perf.py` | Test DBwith large library |
| 33 | Given library with 500 components, when POST /commit/,then operation completes within 30 seconds | load | `tests/performance/test_publish_perf.py` | Test DB, Mock Blockstore |

---

## Edge Case Tests (Negative Tests)

| Edge Case | Test Case | Type | File | Mocks/Fixtures |
|-----------|-----------|------|------|----------------|
| Invalid XBlock OLX | Given Library Author uploads invalid OLX, when component content updated, then HTTP 400 with descriptive error and component unchanged | unit | `tests/unit/test_component_validation.py` | Invalid OLX fixture |
| XBlock type uninstalled after component creation | Given component of uninstalled XBlock type, when library listing rendered, then component shows "unsupported type" and editing disabled | integration | `tests/integration/test_unsupported_xblock.py` | Test DB, Uninstalled XBlock mock |
| Maximum component limit | Given library approaching 10,000components, when adding component exceeds limit, then HTTP 40with "Component limit exceeded" | unit | `tests/unit/test_component_limit.py` | Fixture: library with max components |
| Concurrent publish attempts | Given two Library Admins publish same library simultaneously, when processed, then operations serialized (first succeeds, second is no-op) | load | `tests/load/test_concurrent_publish.py` | Concurrent requests to/commit/ |
| Revert to deleted component state | Given library revertedto version with deleted component, when revert processed, then component restored from version history | integration | `tests/integration/test_versioning.py` | Test DB with version history |
| Orphaned drafts across restarts | Given Library Author creates drafts, when system restarts before publish, then draftspersist in Blockstore | integration | `tests/integration/test_draft_persistence.py` | Test DB, Mock system restart |
| Library deleted during sync | Given library deleted while course syncing content, when sync in progress, then sync failsgracefully with "Library no longer available" and no coursecorruption | e2e | `tests/e2e/test_sync_failure.py` | Test course, Simulated library deletion |
| Library component type mismatch | Given library_content XBlock referencing library with incompatible component types, when randomized selection, then incompatible components skippedand warning logged | integration | `tests/integration/test_component_type_mismatch.py` | Test course, Library with mixedtypes |
| Empty library referenced | Given course references librarywith zero published components, when library_content renders,then "This library has no published content" shown to authors, empty for learners | e2e | `tests/e2e/test_empty_library_reference.py` | Test course, Empty library |
| Circular references | Given attempt to add library_contentXBlock as component within library, when POST /blocks/ with block_type=library_content, then HTTP 400 "Cannot nest libraries" | unit | `tests/unit/test_circular_reference.py` | None |
| Organization removal | Given user removed from organization, when next API call made, then access denied to organization's libraries (HTTP 403) | integration | `tests/integration/test_org_membership_change.py` | Test DB, Mock org membership removal |
| Library admin removes themselves (last admin) | Given lastLibrary Admin attempts self-removal, when DELETE /team/{username}/, then HTTP 400 "Cannot remove last admin" | unit | `tests/unit/test_last_admin_prevention.py` | Fixture: library with single admin |
| Public library with enterprise content | Given library withallow_public_read=true contains enterprise-branded assets, when flag set, then operation allowed but warning logged | unit | `tests/unit/test_public_library_warning.py` | Fixture: library with enterprise content |
| Organization mapped to multiple tenants | Given org mappedto multiple EnterpriseCustomer records, when library created,then organization used as access boundary (not enterprise UUID) | integration | `tests/integration/test_multi_tenant_org.py` | Test DB with multi-tenant org |
| Tenant offboarding with libraries | Given tenant offboarded, when grace period expires, then library metadata removed and Blockstore bundles deleted | integration | `tests/integration/test_tenant_offboarding.py` | Test DB, Mock offboarding workflow |
| Shared course with tenant-scoped library | Given course shared across tenants references tenant A's library, when tenantB learners access course, then they see last-synced content(no direct library access) | e2e | `tests/e2e/test_shared_course_library.py` | Test course, Multi-tenant setup |
| Large archive import (>500MB) | Given OLX archive >500MB, when POST /import/, then HTTP 202 with task ID for async processing | integration | `tests/integration/test_large_import.py` | Large OLX fixture |
| Duplicate slug on import | Given import with existing slugin target org, when POST /import/, then HTTP 409 "Library with slug already exists" | unit | `tests/unit/test_import_duplicate_slug.py` | Fixture: existing library |
| Version history on import | Given imported library, when version history queried, then starts at version 1 (original history not transferred) | integration | `tests/integration/test_import_version_reset.py` | Test DB |
| Retry idempotency for publish | Given publish operation fails, when retried, then no duplicate version entries created |integration | `tests/integration/test_publish_retry.py` | Mock Blockstore failure |
| Export operation resumable | Given export download interrupted, when re-requested, then export archive returned (cachedfor 1 hour) | integration | `tests/integration/test_export_resume.py` | Mock network interruption |
| Search re-indexing retry | Given search service unavailableduring publish, when publish completes, then re-index retries 3 times with exponential backoff (1s, 4s, 16s) | integration | `tests/integration/test_search_index_retry.py` | Mock search service failure |
| Rate limit on mutation endpoints | Given 61 mutation requests in 1 minute, when 61st request made, then HTTP 429 "Rate limit exceeded" | load | `tests/load/test_mutation_rate_limit.py` | Concurrent rapid requests |
| Rate limit on read endpoints | Given 301 read requests in 1minute, when 301st request made, then HTTP 429 | load | `tests/load/test_read_rate_limit.py` | Concurrent rapid requests|
| Rate limit on export endpoints | Given 6 export requests inminute, when 6th request made, then HTTP 429 | load | `tests/load/test_export_rate_limit.py` | Rapid export requests |

---

## Security Tests

| Test Case | Type | File | Mocks/Fixtures |
|-----------|------|------|----------------|
| Cross-tenant isolation: JWT manipulation | Given JWT for Tenant A, when token modified to claim Tenant B org, then access denied and security event logged | security | `tests/security/test_jwt_manipulation.py` | Malformed JWT fixtures |
| Cross-tenant isolation: API parameter tampering | Given APIrequest with ?org=TenantB, when user belongs to Tenant A, then org filter ignored and only Tenant A libraries returned |security | `tests/security/test_api_parameter_tampering.py` |Test DB, Multi-tenant setup |
| Direct Blockstore bundle URL access | Given direct Blockstore bundle URL, when accessed without passing through libraryaccess control, then HTTP 403 | security | `tests/security/test_blockstore_direct_access.py` | Mock Blockstore URL |
| Permission escalation: Reader to Author | Given Library Reader, when POST /blocks/ attempted, then HTTP 403 | security |`tests/security/test_permission_escalation.py` | Test DB, Fixture: reader role |
| Permission escalation: Author to Admin | Given Library Author, when POST /team/ attempted, then HTTP 403 | security | `tests/security/test_permission_escalation.py` | Test DB, Fixture: author role |
| CSRF protection on mutation endpoints | Given POST /blocks/without CSRF token, when request made, then HTTP 403 | security | `tests/security/test_csrf_protection.py` | Missing CSRFtoken |
| Unauthenticated access to any endpoint | Given no auth header, when GET /api/libraries/v2/ called, then HTTP 401 | security | `tests/security/test_unauthenticated_access.py` | No auth header |
| Export archive contains credentials | Given library exported, when archive inspected, then no API keys, credentials, secrets found | security | `tests/security/test_export_data_leakage.py` | Exported OLX archive |
| Export archive contains user PII | Given library exported,when archive inspected, then no user emails, usernames beyondcomponent content | security | `tests/security/test_export_pii_leakage.py` | Exported OLX archive |
| Export archive GCS access control | Given export archived in GCS, when public URL attempted, then HTTP 403 (not publiclyreadable) | security | `tests/security/test_export_gcs_permissions.py` | GCS bucket permissions |

---

## Performance Tests

| Test Case | Type | File | Target |
|-----------|------|------|--------|
| Library listing performance | Given 100 libraries in org, when GET /api/libraries/v2/?org=Mereka, then p95 <= 500ms | load | `tests/performance/test_library_listing_perf.py` | 500msp95 |
| Component listing performance | Given library with 1,000 components, when GET /blocks/?page_size=50, then p95 <= 1000ms| load | `tests/performance/test_component_listing_perf.py` |1000ms p95 |
| Search query performance | Given 50,000 components across all libraries, when search query made, then p95 <= 2000ms | load | `tests/performance/test_library_search_perf.py` | 2000msp95 |
| Publish operation performance | Given library with 500 components, when POST /commit/, then completes <= 30 seconds | load | `tests/performance/test_publish_perf.py` | 30 seconds |
| Export operation performance | Given library with 1,000 components, when GET /export/, then completes <= 60 seconds | load | `tests/performance/test_export_perf.py` | 60 seconds |
| library_content XBlock render performance | Given library_content XBlock with max_count=5, when learner views course unit, then renders <= 500ms p95 (after cache) | load | `tests/performance/test_library_content_render_perf.py` | 500ms p95 |
| Course sync performance | Given course with 50 library references, when "Update from library" clicked, then completes <=seconds | load | `tests/performance/test_sync_perf.py` |seconds |
| Concurrent library creation | Given 100 concurrent POST /api/libraries/v2/ requests, when processed, then all succeed without database deadlocks | load | `tests/load/test_concurrent_creation.py` | No deadlocks |
| Concurrent publish operations | Given 50 concurrent POST /commit/ requests on different libraries, when processed, thenall succeed within target times | load | `tests/load/test_concurrent_publish.py` | 30 seconds per library |
| Search index update latency | Given library published, whensearch index updated, then indexed within 60 seconds | load| `tests/performance/test_search_index_lag.py` | 60 seconds |

---

## E2E Workflow Tests

| Workflow | Test Case | Type | File |
|----------|-----------|------|------|
| Library authoring workflow | Create library → Add components → Edit content → Publish → View in course preview | e2e | `tests/e2e/test_library_authoring.py` |
| Cross-course reuse workflow | Create library → Publish components → Add library_content to course → Verify learner seesrandomized content | e2e | `tests/e2e/test_library_course_integration.py` |
| Library update propagation | Update library component → Publish → Course shows "Updates available" → Sync → Verify updated content in course | e2e | `tests/e2e/test_library_update_flow.py` |
| Multi-tenant isolation workflow | Tenant A creates library→ Tenant B cannot see or access → Platform admin can see both| e2e | `tests/e2e/test_tenant_library_isolation.py` |
| Library team management | Admin grants Author access → Author adds component → Admin reviews and publishes → Reader views but cannot edit | e2e | `tests/e2e/test_library_team_workflow.py` |
| Library backup and restore | Export library → Delete library → Import from export → Verify content restored | e2e | `tests/e2e/test_library_backup_restore.py` |
| Library search and discovery | Create libraries with tags →Search by tag → Filter by org → Sort by date → Paginate results | e2e | `tests/e2e/test_library_search_workflow.py` |
| Library analytics | Create library → Reference in courses →Generate usage report → Verify metrics | e2e | `tests/e2e/test_library_analytics_workflow.py` |

---

## Test Environment Setup

### Test Database
- Separate PostgreSQL/MySQL test DB instance
- Fixtures: organizations, users, permissions, libraries, components
- Cleanup after each test run

### Mock Services
- **Blockstore**: Mock bundle storage, versioning, commit operations
- **Search Index**: Mock Meilisearch/Elasticsearch indexing and queries
- **xAPI Event Pipeline**: Mock event emission and enrichment
- **ClickHouse Analytics**: Mock analytics queries
- **GCS Storage**: Mock bucket operations for export/import
- **LMS Course Structure**: Mock course unit creation and content reference

### Test Data
- **Organizations**: Mereka (platform), AcmeCorp (Tenant A),BetaCorp (Tenant B)
- **Users**: Platform admin, Tenant A admin, Tenant B admin,Library authors, Library readers
- **Libraries**: Platform library (public), Tenant A library(private), Tenant B library (private)
- **Components**: HTML, problem, video, drag-and-drop-v2, openassessment, discussion types

### CI/CD Integration
- Run unit tests on every PR (required)
- Run integration tests on every PR (required)
- Run E2E tests on every merge to main (required)
- Run load tests nightly against staging (optional, gated byflag)
- Run security tests weekly (required)

### Test Coverage Requirements
- Unit test coverage >= 80%
- Integration test coverage >= 70%
- E2E coverage: all critical user workflows
- Security coverage: all OWASP Top 10 categories
- Performance coverage: all NFR thresholds from spec

---

## Test Execution Strategy

### Phase 1: Unit Tests (Week 1-2)
- Focus: Library creation, component authoring, RBAC, validation
- Run locally during development
- Fast feedback loop (<2 minutes total)

### Phase 2: Integration Tests (Week 3-4)
- Focus: Library lifecycle, versioning, search, analytics, backup
- Run in CI on PR
- Moderate runtime (~10 minutes total)

### Phase 3: E2E Tests (Week 5-6)
- Focus: Studio UI workflows, cross-course reuse, multi-tenant isolation
- Run in CI on merge to main
- Longer runtime (~30 minutes total)
- Use Playwright for browser automation

### Phase 4: Load Tests (Week 7-8)
- Focus: Performance benchmarks, concurrent operations, ratelimits
- Run nightly against staging environment
- Report results to performance dashboard

### Phase 5: Security Tests (Week 9-10)
- Focus: Cross-tenant isolation, permission escalation, dataleakage
- Run weekly in CI
- Manual penetration testing by security team

### Regression Testing
- Full test suite (unit + integration + E2E) on every releasecandidate
- Performance regression tests on every major version bump
- Security regression tests quarterly

---

## Test Maintenance

- Update tests when spec acceptance criteria change
- Archive obsolete tests when features are deprecated
- Review test coverage quarterly
- Refactor flaky tests immediately
- Document test data fixtures in `tests/README.md`

---

## Test Reporting

- Publish test results to CI dashboard (GitHub Actions, GitLab CI)
- Export coverage reports to Codecov or Coveralls
- Alert on test failures in Slack #mereka-lms-ci
- Weekly test health report to engineering team

---

## Summary

**Total Test Cases**: 33 acceptance criteria + 30 edge cases+ 10 security tests + 10 performance tests + 8 E2E workflows= 91 test cases

**Test Distribution**:
- Unit: 15 tests
- Integration: 35 tests
- E2E: 16 tests
- Load: 15 tests
- Security: 10 tests

**Estimated Test Development Time**: 10 weeks (parallel to build tasks)

**Critical Test Areas**:
- Multi-tenant isolation (security-critical)
- Cross-course reuse sync logic (data consistency)
- Performance at scale (50,000 components)
- Backup and recovery (data integrity)
