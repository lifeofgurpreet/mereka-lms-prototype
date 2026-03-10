---
source_spec: specs/content-libraries-v2_spec.md
status: ready
created: 2026-02-10
updated: 2026-02-10
spec: content-libraries-v2_spec.md
last_updated: '2026-02-10'
---

# Content Libraries v2 Management & Enterprise Usage - Implementation Plan

**Source Spec**: `specs/content-libraries-v2_spec.md`

**Spec Summary**: 33 Acceptance Criteria spanning library lifecycle, component authoring, versioning, cross-course reuse,access controls, multi-tenant isolation, search, analytics, backup, recovery, and performance optimization for Content Libraries v2 on Mereka Academy platform.

---

## Task Categories

Tasks are grouped by category and ordered by dependency. Eachtask includes:
- **Complexity**: S (<2h), M (2-8h), L (>8h)
- **AC Mapping**: Which acceptance criteria this task addresses
- **File Path**: Where the work happens
- **Dependencies**: Prerequisites (or "None" if independent)

---

## Build Tasks

### Infrastructure & Configuration

- [ ] **[M]** Verify Blockstore integration and storage backend configuration (`deploy/k8s/base/apps/openedx/settings/lms/production.py`, `deploy/k8s/base/apps/openedx/settings/cms/production.py`) | AC: #31 | Depends: None
  - Confirm `openedx.core.djangoapps.content_libraries` is enabled (already present at line 305-306)
  - Verify Blockstore Django app is configured in INSTALLED_APPS
  - Verify Blockstore storage backend points to GCS bucket `lms-blockstore` for production
  - Verify local filesystem path for development
  - Document current Blockstore configuration in `docs/concepts/architecture/content-libraries-overview.md`

- [ ] **[M]** Configure Content Libraries v2 REST API routes(`deploy/k8s/base/apps/openedx/urls/lms.py`, `deploy/k8s/base/apps/openedx/urls/cms.py`) | AC: #1 | Depends: Blockstore verification
  - Verify `/api/libraries/v2/` routes are exposed
  - Verify authentication middleware (session-based and OAuthJWT)
  - Verify CSRF protection on mutation endpoints
  - Test API discovery via `GET /api/libraries/v2/` (list libraries)

- [ ] **[M]** Configure search indexing for library content (`infrastructure/tutor/apply-patches.sh`, `deploy/k8s/base/apps/openedx/settings/common.py`) | AC: #23, #24, #25 | Depends:None
  - Identify search engine deployed (Meilisearch or Elasticsearch)
  - Add library content index configuration to CMS settings
  - Configure index mapping for library titles, descriptions,component content
  - Add feature flag `CONTENT_LIBRARIES_SEARCH_ENABLED` (default: off)
  - Document search configuration in `docs/concepts/architecture/content-libraries-overview.md`

- [ ] **[S]** Add Content Libraries v2 feature flags to Django settings (`deploy/k8s/base/apps/openedx/settings/common.py`) | AC: All | Depends: None
  - `CONTENT_LIBRARIES_V2_ENABLED` (default: on) -- master gate for UI in Studio
  - `CONTENT_LIBRARIES_SEARCH_ENABLED` (default: off) -- search indexing
  - `CONTENT_LIBRARIES_ANALYTICS_ENABLED` (default: off) -- usage tracking
  - `CONTENT_LIBRARIES_BULK_IMPORT_ENABLED` (default: off) --bulk import tools
  - `CONTENT_LIBRARIES_PUBLIC_READ_ENABLED` (default: off) --allow_public_read feature
  - Document flags in `docs/runbooks/operations/TROUBLESHOOTING.md`

### Library Lifecycle Management

- [ ] **[M]** Verify library creation API endpoint (`POST /api/libraries/v2/`) | AC: #1, #2 | Depends: API routes
  - Test library creation via API with valid payload
  - Verify `library_key` format: `lib:{org}:{slug}`
  - Verify unique constraint on slug per organization
  - Verify organization association
  - Verify default metadata: `has_unpublished_changes: false`, `allow_public_read: false`
  - Return HTTP 400 on duplicate slug

- [ ] **[M]** Implement library soft-deletion logic (`infrastructure/tutor/custom-apps/library-management/`) | AC: #3 | Depends: Library creation
  - Extend library model with `deleted_at` timestamp and `deletion_scheduled_at` fields
  - Override `DELETE /api/libraries/v2/{library_key}/` to setdeletion timestamp (30-day grace period)
  - Create management command `./manage.py purge_deleted_libraries` for permanent removal after 30 days
  - Add library restore endpoint `POST /api/libraries/v2/{library_key}/restore/`
  - Document soft-deletion policy in runbook

- [ ] **[S]** Implement library archival state | AC: #1 | Depends: Soft-deletion
  - Add `archived` boolean field to library model
  - Add `PATCH /api/libraries/v2/{library_key}/` endpoint totoggle `archived` state
  - Exclude archived libraries from default listing queries (require `?include_archived=true`)
  - Update Studio UI to show archived badge on library cards

### Component-Based Authoring

- [ ] **[M]** Verify XBlock component addition to libraries (`POST /api/libraries/v2/{library_key}/blocks/`) | AC: #4, #6,#7 | Depends: Library creation
  - Test adding core XBlock types: `html`, `problem`, `video`, `drag-and-drop-v2`, `openassessment`, `discussion`
  - Verify each component gets unique `usage_key` within library namespace
  - Verify `has_unpublished_changes` flag is set to `true` after adding component
  - Test adding unsupported XBlock type returns HTTP 400 withclear error message
  - Verify component count is updated in library metadata

- [ ] **[M]** Verify component editing via Studio (`infrastructure/tutor/themes/`, `frontend-app-authoring` integration) |AC: #5 | Depends: Component addition
  - Test editing HTML component content via Studio modal
  - Test editing problem component settings (max attempts, randomization)
  - Test editing video component (video ID, transcripts)
  - Verify OLX update endpoint handles invalid content gracefully (validation errors)
  - Verify draft changes persist across Studio sessions

- [ ] **[M]** Verify component removal from libraries (`DELETE /api/libraries/v2/{library_key}/blocks/{usage_key}/`) | AC:#5 | Depends: Component addition
  - Test component deletion via API
  - Verify removal does NOT cascade to courses that synced the component (courses retain copy)
  - Verify component count is decremented in library metadata
  - Test deleting already-deleted component returns HTTP 404

- [ ] **[S]** Verify component reordering within libraries |AC: #5 | Depends: Component addition
  - Test `PATCH /api/libraries/v2/{library_key}/blocks/{usage_key}/` with `order` parameter
  - Verify order persists across API calls and Studio views
  - Verify ordering is for organizational purposes only (doesnot affect course rendering)

### Versioning and Publishing

- [ ] **[L]** Verify draft/published lifecycle implementation| AC: #8, #9, #10, #11 | Depends: Component authoring
  - Test draft changes: add component, edit content, verify `has_unpublished_changes: true`
  - Test publish: `POST /api/libraries/v2/{library_key}/commit/` with change summary
  - Verify all draft changes are committed atomically (Blockstore bundle commit)
  - Verify `has_unpublished_changes` resets to `false` afterpublish
  - Verify publish event is logged with timestamp, user, change summary
  - Test idempotency: publishing with no draft changes returns success with "No changes to publish" message
  - Verify courses see only published version of components (not drafts)

- [ ] **[M]** Verify version history and rollback | AC: #10 |Depends: Publishing
  - Test version history endpoint: `GET /api/libraries/v2/{library_key}/history/`
  - Verify at least last 50 versions are retained
  - Test revert endpoint: `POST /api/libraries/v2/{library_key}/revert/` with `version` parameter
  - Verify revert stages changes as draft (requires re-publish)
  - Test reverting to version where a component existed but is now deleted (restores component)

- [ ] **[M]** Verify draft vs published diff view | AC: #10 |Depends: Publishing
  - Test diff endpoint: `GET /api/libraries/v2/{library_key}/diff/`
  - Verify diff shows added, modified, deleted components
  - Verify authoring MFE renders diff correctly
  - Test diff with no draft changes returns empty diff

### Cross-Course Content Reuse

- [ ] **[L]** Verify `library_content` XBlock integration (randomized selection) | AC: #12 | Depends: Publishing
  - Test adding `library_content` XBlock to course unit via Studio
  - Configure `source_library_id=lib:Mereka:compliance-2026`and `max_count=5`
  - Verify learner sees 5 randomly selected components from library
  - Verify randomization is per-learner (different learners see different selections)
  - Test with library containing 20+ components
  - Verify learner sees only published components (not drafts)

- [ ] **[M]** Verify `library_v2_ref` XBlock integration (fixed reference) | AC: #12 | Depends: Publishing
  - Test embedding specific library component in course unit
  - Verify component renders correctly for learners
  - Verify reference points to published version
  - Test with different component types: `html`, `problem`, `video`

- [ ] **[L]** Implement "sync from library" action in Studio| AC: #13, #14, #15 | Depends: Library content reuse
  - Add "Update from library" button to Studio course unit UIfor `library_content` and `library_v2_ref` blocks
  - Implement sync logic: pull latest published version fromlibrary, update course content
  - Display notification badge when newer published versionsare available
  - Verify sync is opt-in (no automatic updates)
  - Test sync with library containing updated components
  - Verify sync preserves course-specific overrides (if any)
  - Test sync with deleted library: retain last-synced copy,show warning

- [ ] **[M]** Implement library reference tracking | AC: #14| Depends: Sync action
  - Add database table `LibraryReference` with fields: `library_key`, `course_key`, `usage_key`, `component_usage_key`, `last_synced_at`
  - Track references on `library_content` and `library_v2_ref` block creation
  - Expose reference count via API: `GET /api/libraries/v2/{library_key}/links/`
  - Display "Used in N courses" badge in Studio library listing
  - Test deleting library with active references (warn but allow, courses retain copies)

### Library Access Controls and Permissions

- [ ] **[M]** Verify role-based access control implementation| AC: #16, #17, #18, #19 | Depends: Library creation
  - Test Library Admin role: full control (create, edit, delete, publish, manage permissions)
  - Test Library Author role: add and edit components, publish (if allowed by settings), cannot delete library or manage permissions
  - Test Library Reader role: view library contents, copy/reference to courses, cannot edit
  - Verify library creator is automatically assigned LibraryAdmin role
  - Test permission enforcement at API level (not just UI)

- [ ] **[M]** Verify library creation permission enforcement| AC: #16 | Depends: RBAC
  - Test user without `CONTENT_LIBRARY_CREATOR` Django permission cannot create libraries (HTTP 403)
  - Test staff/superuser can create libraries regardless of permission
  - Test organization membership check: user must be member of target organization to create library there

- [ ] **[M]** Verify organization-based library visibility |AC: #16 | Depends: RBAC
  - Test user sees only libraries from organizations they belong to
  - Test `allow_public_read` flag: public libraries visible to all authenticated users
  - Test unauthenticated user cannot access any library API endpoints (HTTP 401)
  - Test user from Org A cannot see libraries from Org B (unless public)

- [ ] **[M]** Implement library team management endpoints | AC: #17, #18 | Depends: RBAC
  - Test granting access: `POST /api/libraries/v2/{library_key}/team/` with `{"username": "user1", "access_level": "author"}`
  - Test revoking access: `DELETE /api/libraries/v2/{library_key}/team/{username}/`
  - Test changing role: `PATCH /api/libraries/v2/{library_key}/team/{username}/` with new `access_level`
  - Verify all permission changes are logged to audit log
  - Test preventing removal of last Library Admin (HTTP 400)

### Multi-Tenant Library Management

- [ ] **[L]** Implement tenant-scoped library isolation | AC:#20, #21, #22 | Depends: RBAC, Organization visibility
  - Verify enterprise customer organization mapping (per `specs/multi-tenancy-architecture_spec.md`)
  - Test user authenticated under Tenant A context can only see Tenant A's organization libraries
  - Test cross-tenant isolation: Tenant A user calling `GET /api/libraries/v2/lib:TenantB:training/` returns HTTP 403
  - Log cross-tenant access attempts as security events
  - Verify isolation applies to all API endpoints (list, detail, create, edit, team management)

- [ ] **[M]** Implement platform-global library scope | AC: #| Depends: Tenant isolation
  - Create "Mereka" organization for platform-operated libraries
  - Test `allow_public_read` on platform libraries makes themvisible to all tenants
  - Verify public libraries are read-only for non-admin users
  - Test tenant users can reference public library content incourses

- [ ] **[M]** Implement shared library catalogs | AC: #20 | Depends: Tenant isolation
  - Design `SharedLibraryCatalog` model with `library_key`, `target_org`, `granted_by_user`
  - Add endpoint: `POST /admin/api/v1/libraries/{library_key}/share/` with `{"target_organization": "AcmeCorp"}`
  - Verify shared libraries appear in target organization's library listings
  - Verify share grants are logged for audit purposes

- [ ] **[M]** Integrate library visibility into enterprise catalog | AC: #20 | Depends: Shared catalogs
  - Extend enterprise catalog query (`/api/v1/enterprise-catalogs/`) to include library availability
  - Add `available_libraries` field to enterprise catalog APIresponse
  - Verify enterprise admins can discover which libraries their organization has access to
  - Test filtering by `library_type`, `tag`, date ranges

### Content Search, Discovery, and Categorization

- [ ] **[L]** Implement library content search indexing | AC:#23, #24, #25 | Depends: Search configuration
  - Configure search index schema for libraries: `library_key`, `title`, `description`, `org`, `tags`, `component_content`
  - Implement indexing on library publish: re-index library on `POST /commit/`
  - Implement incremental indexing (not full re-index)
  - Test search query: `GET /api/libraries/v2/?search=compliance`
  - Verify search respects access controls (users don't see libraries they lack permission to view)

- [ ] **[M]** Implement library listing filters and sorting |AC: #24, #25 | Depends: Search indexing
  - Test filtering by: `?org=Mereka`, `?library_type=complex`, `?tag=assessments`, `?created_after=2026-01-01`, `?modified_after=2026-01-01`
  - Test sorting by: `?sort=title`, `?sort=-date_created`, `?sort=-date_modified`, `?sort=-component_count`
  - Test pagination: `?page_size=20&page=2`
  - Verify default page size is 20 items

- [ ] **[M]** Implement content tagging integration | AC: #23, #25 | Depends: Search indexing
  - Integrate with Open edX content tagging system (Redwood feature)
  - Test tagging libraries with taxonomy-based tags: `POST /api/libraries/v2/{library_key}/tags/`
  - Test tagging individual components: `POST /api/libraries/v2/{library_key}/blocks/{usage_key}/tags/`
  - Test tag-based filtering in search
  - Verify tag metadata is indexed for search

- [ ] **[S]** Implement within-library component search | AC:#25 | Depends: Search indexing
  - Add search parameter to component listing: `GET /api/libraries/v2/{library_key}/blocks/?search=quiz`
  - Verify search queries component content, titles, tags
  - Test pagination of search results within library

### Library Analytics and Usage Tracking

- [ ] **[M]** Implement library usage tracking | AC: #26, #27| Depends: Reference tracking
  - Track course references in `LibraryReference` table (already implemented in reference tracking task)
  - Implement usage data endpoint: `GET /api/libraries/v2/{library_key}/links/`
  - Return list of courses with: `course_key`, `course_title`, `component_usage_keys`, `last_synced_at`
  - Implement component-level usage: count references per component
  - Display usage count in Studio library component listing

- [ ] **[M]** Integrate library usage into analytics pipeline| AC: #26, #27 | Depends: Usage tracking
  - Extend xAPI event context to include `library_key` for library-sourced content
  - Modify problem, video, discussion XBlock event emitters to check if content is sourced from library
  - Add `library_key` to event context if applicable
  - Test event enrichment with library context
  - Add feature flag `CONTENT_LIBRARIES_ANALYTICS_ENABLED` gate

- [ ] **[M]** Implement library usage report generation | AC:#26 | Depends: Usage tracking
  - Create management command `./manage.py generate_library_usage_report`
  - Output CSV with: `library_key`, `title`, `component_count`, `total_references`, `courses_referencing`, `most_referenced_component`, `orphaned`
  - Filter by organization for tenant-scoped reports
  - Implement scheduled job (cron) for monthly reports
  - Store reports in GCS bucket for long-term access

- [ ] **[M]** Implement learner interaction metrics for library components | AC: #26 | Depends: Analytics integration
  - Query ClickHouse analytics DB for library-sourced contentevents
  - Aggregate completion rates, assessment scores per librarycomponent
  - Expose aggregated metrics via API: `GET /api/libraries/v2/{library_key}/analytics/`
  - Scope visibility to user's organization
  - Test with sample xAPI events containing `library_key` context

### Backup, Recovery, and Disaster Recovery

- [ ] **[M]** Verify library metadata backup via Cloud SQL |AC: #28 | Depends: None
  - Verify library metadata tables are included in Cloud SQLbackup schedule
  - Document backup schedule in `docs/runbooks/operations/TROUBLESHOOTING.md`
  - Test metadata restore from Cloud SQL backup (staging environment)

- [ ] **[M]** Verify Blockstore content bundle backup | AC: #| Depends: Blockstore verification
  - Verify GCS bucket versioning is enabled for `lms-blockstore` bucket
  - Test Blockstore bundle restore from GCS versioned object
  - Document Blockstore backup strategy in disaster recoveryspec

- [ ] **[L]** Verify library export/import functionality | AC: #28, #29, #30 | Depends: None
  - Test export: `GET /api/libraries/v2/{library_key}/export/` returns valid tar.gz OLX archive
  - Verify export includes all component content, metadata, version history
  - Test import: `POST /api/libraries/v2/import/` with OLX archive creates new library
  - Test import with existing slug returns HTTP 409
  - Test import with unsupported XBlock type returns HTTP 400with clear error listing missing types
  - Verify import preserves component content and metadata but creates clean version history (version 1)

- [ ] **[M]** Implement per-library scheduled export | AC: #2| Depends: Export/import
  - Create management command `./manage.py export_critical_libraries` with `--library-keys` parameter
  - Store exports in GCS bucket `lms-library-backups` with timestamped filenames
  - Implement cron job for daily exports of critical libraries
  - Document export schedule and storage location in runbook

- [ ] **[M]** Verify library disaster recovery RTO/RPO | AC:#28 | Depends: Backup verification
  - Test full library restore from Cloud SQL + GCS backup (staging environment)
  - Measure recovery time and verify it meets platform RTO
  - Verify all component content, version history, permissions are restored correctly
  - Document recovery procedure in `docs/operations/disaster-recovery-library-content.md`

### Content Quality Assurance and Review Workflows

- [ ] **[M]** Implement restricted publish permissions | AC:#8, #10 | Depends: Publishing, RBAC
  - Add `restrict_publish_to_admins` boolean field to librarymodel
  - When enabled, only Library Admins can publish (Library Authors can only create drafts)
  - Test workflow: Author creates/edits components (draft), Admin reviews and publishes
  - Display "Pending review" badge in Studio for libraries with unpublished changes when `restrict_publish_to_admins=true`

- [ ] **[M]** Implement preview mode for draft content | AC:#10 | Depends: Draft/published lifecycle
  - Add `?draft=true` parameter to library component rendering endpoint
  - Verify preview is restricted to Library Admins and Authors
  - Test preview in Studio authoring MFE
  - Display "Draft preview" banner when viewing draft content

- [ ] **[S]** Implement publish accountability logging | AC:#8 | Depends: Publishing
  - Extend publish event log with: `library_key`, `version_number`, `publisher_user_id`, `publisher_username`, `change_summary`, `component_count`, `timestamp`
  - Display publish history in Studio library settings page
  - Test querying publish audit log

### Library Migration, Export, and Import

- [ ] **[M]** Verify bulk library creation tooling | AC: #30| Depends: Library creation, Export/import
  - Create management command `./manage.py create_libraries_from_csv` with CSV format: `org,slug,title,description,library_type`
  - Test creating 10 libraries from CSV
  - Verify error handling for invalid org or duplicate slugs
  - Document CSV format in `docs/operations/library-bulk-operations.md`
  - Add feature flag `CONTENT_LIBRARIES_BULK_IMPORT_ENABLED`gate

- [ ] **[M]** Implement library migration between organizations | AC: #30 | Depends: Export/import
  - Document migration procedure: export from source org, update `org` in metadata, import to target org
  - Test migrating library from Tenant A to Tenant B
  - Verify permissions are reset (new org's admins take ownership)
  - Verify content and version history are preserved
  - Document in `docs/operations/library-bulk-operations.md`

---

## Test Tasks

### Unit Tests

- [ ] **[M]** Write unit tests for library creation validation (`tests/unit/test_library_creation.py`) | AC: #1, #2 | Depends: Library creation
  - Test `library_key` format validation
  - Test unique slug constraint per organization
  - Test invalid organization returns error
  - Test default metadata values

- [ ] **[M]** Write unit tests for component authoring validation (`tests/unit/test_component_authoring.py`) | AC: #4, #6,#7 | Depends: Component authoring
  - Test adding supported XBlock types
  - Test adding unsupported XBlock type returns error
  - Test invalid OLX content validation
  - Test component count updates

- [ ] **[M]** Write unit tests for RBAC enforcement (`tests/unit/test_library_rbac.py`) | AC: #16, #17, #18, #19 | Depends: RBAC
  - Test role permissions (Admin, Author, Reader)
  - Test permission checks return correct HTTP status codes
  - Test last admin removal prevention

- [ ] **[M]** Write unit tests for tenant isolation (`tests/unit/test_tenant_isolation.py`) | AC: #20, #21, #22 | Depends:Tenant isolation
  - Test organization membership filtering
  - Test cross-tenant access denial
  - Test public library visibility

### Integration Tests

- [ ] **[L]** Write integration tests for library lifecycle (`tests/integration/test_library_lifecycle.py`) | AC: #1, #2,#3 | Depends: Library lifecycle
  - Test create → edit metadata → soft-delete → restore flow
  - Test soft-deletion grace period enforcement
  - Test permanent deletion after 30 days
  - Use test database (not production)

- [ ] **[L]** Write integration tests for versioning and publishing (`tests/integration/test_versioning.py`) | AC: #8, #9,#10, #11 | Depends: Versioning
  - Test draft → publish → revert flow
  - Test version history retention (50 versions)
  - Test concurrent publish attempts (Blockstore optimistic concurrency)
  - Mock Blockstore API

- [ ] **[L]** Write integration tests for cross-course reuse(`tests/integration/test_library_reuse.py`) | AC: #12, #13, #14, #15 | Depends: Cross-course reuse
  - Test `library_content` XBlock randomized selection
  - Test `library_v2_ref` XBlock fixed reference
  - Test sync from library updates course content
  - Test deleted library does not break course
  - Mock LMS course structure API

- [ ] **[L]** Write integration tests for search and discovery (`tests/integration/test_library_search.py`) | AC: #23, #24, #25 | Depends: Search
  - Test full-text search across library content
  - Test filtering by organization, library type, tags, dates
  - Test pagination and sorting
  - Test search respects access controls
  - Mock search index (Meilisearch or Elasticsearch)

- [ ] **[L]** Write integration tests for analytics tracking(`tests/integration/test_library_analytics.py`) | AC: #26, #2| Depends: Analytics
  - Test library reference tracking
  - Test xAPI event enrichment with `library_key`
  - Test usage report generation
  - Mock ClickHouse analytics DB

- [ ] **[L]** Write integration tests for backup and recovery(`tests/integration/test_library_backup.py`) | AC: #28, #29,#30 | Depends: Backup
  - Test library export to OLX archive
  - Test library import from OLX archive
  - Test import validation (unsupported XBlock types)
  - Test export/import round-trip preserves content

### E2E Tests

- [ ] **[L]** Write E2E tests for library authoring workflow(`tests/e2e/test_library_authoring.py`) | AC: #1, #4, #5, #8| Depends: All build tasks
  - Test creating library via Studio UI
  - Test adding and editing components via Studio
  - Test publishing library via Studio
  - Test viewing published version in course preview
  - Use Playwright or Selenium for browser automation

- [ ] **[L]** Write E2E tests for cross-course reuse workflow(`tests/e2e/test_library_course_integration.py`) | AC: #12,#13, #14 | Depends: Cross-course reuse
  - Test adding `library_content` XBlock to course via Studio
  - Test learner sees randomized library components
  - Test "Update from library" action updates course content
  - Use test course with library references

- [ ] **[L]** Write E2E tests for multi-tenant isolation (`tests/e2e/test_tenant_library_isolation.py`) | AC: #20, #21, #2| Depends: Tenant isolation
  - Test Tenant A admin creates library
  - Test Tenant B admin cannot see or access Tenant A's library
  - Test platform admin can see all libraries
  - Use test enterprise customers and organizations

### Performance Tests

- [ ] **[M]** Write performance tests for library listing (`tests/performance/test_library_listing_perf.py`) | AC: #31 | Depends: Library listing
  - Test listing 100 libraries returns within 500ms at p95
  - Use locust or pytest-benchmark
  - Run against staging environment with realistic data volume

- [ ] **[M]** Write performance tests for component listing (`tests/performance/test_component_listing_perf.py`) | AC: #32| Depends: Component listing
  - Test listing 1,000 components returns within 1000ms at p95
  - Test pagination performance
  - Run against staging with large test library

- [ ] **[M]** Write performance tests for search queries (`tests/performance/test_library_search_perf.py`) | AC: #23 | Depends: Search
  - Test search across 50,000 components returns within 2000ms at p95
  - Test search query latency under load (100 concurrent users)
  - Run against staging with full search index

- [ ] **[M]** Write performance tests for publishing (`tests/performance/test_publish_perf.py`) | AC: #33 | Depends: Publishing
  - Test publishing library with 500 components completes within 30 seconds
  - Test publishing library with 1,000 components (load limit)
  - Measure Blockstore commit latency

- [ ] **[M]** Write performance tests for export (`tests/performance/test_export_perf.py`) | AC: #28 | Depends: Export
  - Test exporting library with 1,000 components completes within 60 seconds
  - Test export archive size and compression
  - Run against staging

### Security Tests

- [ ] **[M]** Write security tests for cross-tenant isolation(`tests/security/test_tenant_isolation_bypass.py`) | AC: #20, #21, #22 | Depends: Tenant isolation
  - Test JWT manipulation attempts to access other tenant's libraries
  - Test API parameter tampering (e.g., changing `org` in request)
  - Test direct Blockstore bundle URL access without access control
  - Verify all cross-tenant access attempts are logged as security events

- [ ] **[M]** Write security tests for permission enforcement(`tests/security/test_library_permissions.py`) | AC: #16, #17, #18, #19 | Depends: RBAC
  - Test Library Reader cannot edit components (HTTP 403)
  - Test Library Author cannot delete library (HTTP 403)
  - Test unauthenticated user cannot access any library API endpoints (HTTP 401)
  - Test CSRF protection on mutation endpoints

- [ ] **[M]** Write security tests for export data leakage (`tests/security/test_export_data_leakage.py`) | AC: #28 | Depends: Export
  - Verify export archives do not contain embedded credentials, API keys
  - Verify export does not contain user PII beyond what's incomponent content
  - Test export archives are access-controlled (not publiclyreadable in GCS)

---

## Observability Tasks

### Metrics

- [ ] **[M]** Implement Prometheus metrics for library operations (`infrastructure/tutor/custom-apps/library-management/metrics.py`) | AC: All | Depends: Build tasks
  - `content_library_count` (gauge, labels: `organization`, `library_type`) -- total libraries per organization
  - `content_library_component_count` (gauge, labels: `organization`, `library_key`) -- components per library
  - `content_library_api_requests_total` (counter, labels: `endpoint`, `method`, `status_code`, `organization`) -- API traffic
  - `content_library_api_latency_seconds` (histogram, labels:`endpoint`, `method`, `organization`) -- API latency
  - `content_library_publish_duration_seconds` (histogram, labels: `organization`) -- publish operation duration
  - `content_library_publish_total` (counter, labels: `organization`, `outcome`) -- publish events (success/failure)
  - `content_library_export_size_bytes` (histogram, labels: `organization`) -- export archive sizes
  - `content_library_import_total` (counter, labels: `organization`, `outcome`) -- import events
  - `content_library_sync_total` (counter, labels: `organization`, `outcome`) -- course sync events
  - `content_library_search_index_lag_seconds` (gauge) -- time since last successful search index update
  - `content_library_cross_tenant_denial_total` (counter, labels: `requesting_org`, `target_org`) -- cross-tenant access denials
  - `content_library_references_total` (gauge, labels: `library_key`) -- number of courses referencing each library

- [ ] **[M]** Expose Prometheus metrics endpoint (`/metrics/`) | AC: All | Depends: Metrics implementation
  - Verify metrics endpoint is accessible from Prometheus scraper
  - Test metrics are updated in real-time
  - Document metrics in `docs/concepts/architecture/content-libraries-overview.md`

### Logging

- [ ] **[M]** Implement structured logging for library operations (`infrastructure/tutor/custom-apps/library-management/logging.py`) | AC: All | Depends: Build tasks
  - Library lifecycle events: `library_key`, `organization`,`actor_user_id`, `action`, `timestamp`, `outcome`
  - Component authoring events: `library_key`, `component_usage_key`, `block_type`, `actor_user_id`, `action`, `timestamp`
  - Publish events: `library_key`, `version_number`, `component_count`, `actor_user_id`, `timestamp`, `duration_ms`
  - Access control events: `library_key`, `target_user_id_hash`, `role`, `actor_user_id`, `action`, `timestamp`
  - Cross-tenant access denials: `requesting_user_id_hash`, `requesting_org`, `target_library_key`, `target_org`, `endpoint`, `timestamp`
  - Import/export events: `library_key`, `archive_size_bytes`, `component_count`, `actor_user_id`, `action`, `timestamp`,`outcome`
  - DO NOT log raw library content (OLX), user emails, authentication tokens

- [ ] **[S]** Configure log aggregation for library logs | AC: All | Depends: Logging implementation
  - Verify library logs are shipped to Loki (per `specs/observability-stack_spec.md`)
  - Test log queries in Grafana
  - Document log queries in runbook

### Alerts

- [ ] **[M]** Configure Prometheus alerts for library operations (`infrastructure/monitoring/prometheus-rules/content-libraries.yml`) | AC: All | Depends: Metrics
  - **Critical**: `content_library_cross_tenant_denial_total`rate > 10 in 5 minutes from the same user -- potential unauthorized access attempt
  - **Critical**: `content_library_publish_total{outcome="failure"}` > 5 in 10 minutes -- Blockstore or database issue affecting content publishing
  - **Warning**: `content_library_search_index_lag_seconds` >
- search index more than 1 hour behind publish events
  - **Warning**: `content_library_api_latency_seconds` p95 >2x threshold for any endpoint sustained for 15 minutes -- performance degradation
  - **Info**: `content_library_count` changes -- new librarycreated or library deleted (operational awareness)
  - **Info**: `content_library_export_size_bytes` > 100MB --large export (potential storage impact)

- [ ] **[S]** Configure alert routing to Slack/PagerDuty | AC: All | Depends: Alerts
  - Route Critical alerts to on-call PagerDuty
  - Route Warning alerts to Slack #mereka-lms-alerts
  - Route Info alerts to Slack #mereka-lms-ops
  - Document alert response procedures in runbook

### Dashboards

- [ ] **[M]** Create Grafana dashboards for library operations (`infrastructure/monitoring/grafana-dashboards/content-libraries.json`) | AC: All | Depends: Metrics
  - **Content Libraries Overview**: Total libraries (by organization), total components, publish frequency trend, most active libraries (by publish count and component count), libraries with stale search indexes
  - **Library Performance**: API latency by endpoint (p50, p95, p99), publish duration trend, export/import throughput, search query latency
  - **Library Usage**: Top referenced libraries (by course count), orphaned libraries (zero references), component-level usage heat map, sync frequency per course
  - **Library Security**: Cross-tenant denial log, permissionchange audit trail, rate limit hits by user
  - **Tenant Library Health**: Per-tenant library count, component count, publish activity, storage consumption (Blockstore bundle sizes)

- [ ] **[S]** Document dashboard usage in runbook | AC: All |Depends: Dashboards
  - Add screenshots of dashboards to `docs/operations/content-libraries-runbook.md`
  - Document key metrics to monitor
  - Document alert thresholds

---

## Docs Tasks

### Architecture Documentation

- [ ] **[M]** Write Content Libraries v2 architecture overview (`docs/concepts/architecture/content-libraries-overview.md`) | AC: All | Depends: Build tasks
  - System architecture diagram (Blockstore, LMS/CMS, Studio,authoring MFE, search index)
  - Data flow: component authoring → draft → publish → coursereference → learner view
  - Blockstore integration: bundle storage, versioning, GCS backend
  - Multi-tenant isolation model
  - Search indexing architecture
  - Analytics integration
  - Document all feature flags

- [ ] **[M]** Update disaster recovery spec with library content backup (`specs/disaster-recovery-business-continuity_spec.md`) | AC: #28 | Depends: Backup tasks
  - Add Content Libraries v2 to backup checklist
  - Document library metadata backup (Cloud SQL)
  - Document Blockstore content backup (GCS versioning)
  - Document library restore procedure
  - Add RTO/RPO targets for library content

### Operational Documentation

- [ ] **[L]** Write Content Libraries v2 runbook (`docs/operations/content-libraries-runbook.md`) | AC: All | Depends: Allbuild tasks
  - Library lifecycle operations: create, edit, delete, restore
  - Publishing workflow: draft changes, review, publish, rollback
  - Access control management: grant/revoke permissions, manage teams
  - Multi-tenant operations: create tenant-scoped libraries,share catalogs
  - Search operations: re-index library content, troubleshootsearch issues
  - Backup and recovery: export library, import library, restore from backup
  - Performance tuning: optimize large libraries, tune searchindex
  - Troubleshooting common issues: publish failures, sync errors, access denials
  - Monitoring and alerting: key metrics, alert response procedures

- [ ] **[M]** Update troubleshooting guide with library-specific issues (`docs/runbooks/operations/TROUBLESHOOTING.md`) | AC: All |Depends: Runbook
  - Issue: Library not visible in Studio → Check organizationmembership, feature flag
  - Issue: Component not rendering in course → Check publishstatus, XBlock type installed
  - Issue: Sync from library fails → Check library exists, check permissions
  - Issue: Search not returning results → Check search indexstatus, re-index
  - Issue: Cross-tenant access denial → Check organization membership, security log
  - Issue: Publish operation times out → Check Blockstore storage, check database connectivity

### User Documentation

- [ ] **[L]** Write Content Libraries v2 user guide (`docs/user-guides/content-libraries-user-guide.md`) | AC: All | Depends: Build tasks
  - Audience: Content authors, enterprise admins
  - Creating and configuring libraries
  - Adding and editing components
  - Publishing and versioning
  - Sharing libraries across courses
  - Managing library teams and permissions
  - Searching and discovering library content
  - Best practices for library organization
  - Screenshots of Studio UI

- [ ] **[M]** Write enterprise onboarding guide for libraries(`docs/enterprise/library-onboarding-guide.md`) | AC: All |Depends: User guide
  - Setting up tenant-scoped libraries
  - Bulk library creation for enterprise clients
  - Configuring shared library catalogs
  - Training content authors on library workflows
  - Analytics and usage tracking for enterprise libraries

---

## Rollout Tasks

### Phase 0: Verification and Baseline (Week 1)

- [ ] **[S]** Verify Content Libraries v2 Django app is enabled | AC: All | Depends: None
  - Check `deploy/k8s/base/apps/openedx/settings/lms/production.py` line 305-306
  - Check `deploy/k8s/base/apps/openedx/settings/cms/production.py` for same configuration
  - Document current configuration

- [ ] **[M]** Verify Blockstore is integrated and functional| AC: All | Depends: None
  - Test creating a library via Django admin or management command
  - Verify Blockstore storage backend (GCS or filesystem)
  - Test reading and writing Blockstore bundles
  - Document Blockstore configuration

- [ ] **[M]** Verify authoring MFE includes Content Librariesv2 views | AC: All | Depends: None
  - Check `frontend-app-authoring` MFE build configuration
  - Test accessing library management UI in Studio
  - Screenshot library views for documentation

- [ ] **[M]** Establish baseline metrics | AC: All | Depends:Observability tasks
  - Document current library count (if any)
  - Verify API endpoints respond: `GET /api/libraries/v2/`
  - Enable library observability metrics and logging
  - Create baseline Grafana dashboards

- [ ] **[M]** Verify GCS bucket for Blockstore storage | AC:All | Depends: None
  - Check `lms-blockstore` bucket exists and is accessible
  - Verify bucket permissions (LMS/CMS service account can read/write)
  - Verify GCS versioning is enabled for backup
  - Document bucket configuration

### Phase 1: Platform Operator Libraries (Week 2-3)

- [ ] **[M]** Create first production library | AC: #1 | Depends: Phase 0
  - Create `lib:Mereka:platform-templates` owned by Mereka organization
  - Populate with 10-20 commonly reused components (HTML templates, standard problem types, branding blocks)
  - Test library CRUD operations via Studio and API

- [ ] **[M]** Verify draft/publish workflow | AC: #8 | Depends: First library
  - Create component, edit content, publish
  - Verify published version in course preview
  - Test rollback to previous version

- [ ] **[M]** Verify cross-course reuse | AC: #12 | Depends:Draft/publish
  - Add `library_content` XBlock to test course
  - Verify randomized selection works for learners
  - Test "Update from library" action

- [ ] **[M]** Verify library export and import | AC: #28, #29| Depends: First library
  - Export library to OLX archive
  - Import archive to create duplicate library
  - Verify content is identical

- [ ] **[M]** Run library performance benchmarks | AC: #31, #32, #33 | Depends: First library
  - Baseline response times for listing, component loading, publish
  - Document baseline metrics for comparison

- [ ] **[M]** Enable search indexing for library content | AC: #23 | Depends: First library
  - Set `CONTENT_LIBRARIES_SEARCH_ENABLED=true`
  - Re-index library content
  - Test search queries
  - Monitor search index lag metric

### Phase 2: Single-Tenant Enterprise Libraries (Week 4-5)

- [ ] **[M]** Create library for first enterprise tenant | AC: #20 | Depends: Phase 1
  - Identify first enterprise tenant organization
  - Create tenant-scoped library via API
  - Populate with tenant-specific content

- [ ] **[M]** Verify organization-based access controls | AC:#16, #20 | Depends: Tenant library
  - Test tenant users see their libraries
  - Test tenant users do NOT see Mereka-internal libraries
  - Test cross-tenant isolation

- [ ] **[M]** Verify cross-tenant isolation | AC: #21, #22 |Depends: Tenant library
  - Create library for second tenant
  - Test second tenant users cannot access first tenant's library
  - Monitor cross-tenant denial security events

- [ ] **[M]** Enable `allow_public_read` on platform library| AC: #20 | Depends: Phase 1, Tenant library
  - Set `allow_public_read=true` on `lib:Mereka:platform-templates`
  - Set `CONTENT_LIBRARIES_PUBLIC_READ_ENABLED=true`
  - Verify tenants can reference it in courses
  - Test public library is read-only for non-admins

- [ ] **[M]** Verify library-sourced content in tenant courses | AC: #12, #13 | Depends: Tenant library
  - Test adding tenant library content to tenant course
  - Test learner sees content correctly
  - Test sync from library updates course

- [ ] **[M]** Train enterprise content authors on library workflows | AC: All | Depends: User documentation
  - Deliver user guide to first enterprise tenant
  - Conduct training session (record for future use)
  - Collect feedback for user guide improvements

### Phase 3: Multi-Tenant Scale and Analytics (Week 6-8)

- [ ] **[M]** Create libraries for all active enterprise tenants | AC: #20 | Depends: Phase 2
  - Bulk create libraries using `./manage.py create_libraries_from_csv`
  - Verify each tenant can access their libraries
  - Verify cross-tenant isolation at scale

- [ ] **[M]** Enable library usage tracking | AC: #26 | Depends: Phase 2
  - Set `CONTENT_LIBRARIES_ANALYTICS_ENABLED=true`
  - Test library reference counting
  - Test usage data API endpoint

- [ ] **[M]** Enable xAPI event tagging with library_key | AC: #27 | Depends: Usage tracking
  - Verify xAPI events include `library_key` context for library-sourced content
  - Test event enrichment with sample library content in course
  - Verify events flow to ClickHouse analytics DB

- [ ] **[L]** Build library analytics dashboard | AC: #26 | Depends: Usage tracking
  - Create Superset dashboard for per-tenant library usage
  - Include: library count, component count, most-referencedlibraries, usage trends
  - Scope dashboard to tenant organization
  - Train enterprise admins on dashboard usage

- [ ] **[L]** Load test with 100 libraries and 5,000 components | AC: #31, #32 | Depends: Phase 2
  - Create 100 test libraries across 10 organizations
  - Populate with total 5,000 components
  - Run performance tests
  - Verify API latency meets NFR thresholds
  - Tune pagination, caching as needed

- [ ] **[M]** Tune search index and caching | AC: #23 | Depends: Load test
  - Optimize search index schema based on load test results
  - Tune pagination settings
  - Enable API response caching (Redis)
  - Re-run performance tests to verify improvements

- [ ] **[M]** Enable nightly library backup exports | AC: #28| Depends: Phase 1
  - Configure cron job for `./manage.py export_critical_libraries`
  - Store exports in GCS bucket `lms-library-backups`
  - Test restore from backup export

### Phase 4: Advanced Workflows and Hardening (Week 9-12)

- [ ] **[M]** Implement bulk library creation tooling | AC: #| Depends: Phase 3
  - Finalize `./manage.py create_libraries_from_csv` command
  - Document CSV format and usage
  - Test with enterprise onboarding scenario (10+ libraries)

- [ ] **[M]** Implement library usage report generation | AC:#26 | Depends: Phase 3
  - Finalize `./manage.py generate_library_usage_report` command
  - Generate first monthly report
  - Store report in GCS bucket
  - Share report with product team

- [ ] **[M]** Enable all observability alerts | AC: All | Depends: Phase 3
  - Enable Critical and Warning alerts
  - Test alert routing to PagerDuty and Slack
  - Document alert response procedures in runbook

- [ ] **[L]** Load test with 500 libraries and 50,000 components | AC: All | Depends: Phase 3
  - Create 500 test libraries across 50 organizations
  - Populate with total 50,000 components
  - Run performance tests
  - Verify API latency, search performance, publish durationmeet NFR thresholds
  - Document load test results

- [ ] **[M]** Document library disaster recovery runbook | AC: #28 | Depends: Phase 1
  - Finalize `docs/operations/disaster-recovery-library-content.md`
  - Include: backup verification, restore procedures, RTO/RPOtargets
  - Test disaster recovery procedure in staging environment

- [ ] **[M]** Conduct security review of library access control | AC: #16, #20, #21, #22 | Depends: Phase 3
  - Review RBAC implementation with security team
  - Review multi-tenant isolation with security team
  - Penetration testing for cross-tenant access attempts
  - Address findings before Phase 4 completion

- [ ] **[M]** Run cross-tenant isolation verification | AC: #20, #21, #22 | Depends: Phase 3
  - Extend `scripts/qa/verify-tenant-isolation.sh` to includelibrary endpoints
  - Run full tenant isolation test suite
  - Verify zero cross-tenant leakage
  - Document test results

---

## Rollback Tasks

### Disable Library UI in Studio

- [ ] **[S]** Set `CONTENT_LIBRARIES_V2_ENABLED=false` in Studio/CMS settings | AC: All | Depends: None
  - Library management UI is hidden from Studio
  - Existing libraries and content are preserved in Blockstore
  - Courses referencing library content continue to function
  - Re-enable when issues are resolved

### Disable Library Search Indexing

- [ ] **[S]** Set `CONTENT_LIBRARIES_SEARCH_ENABLED=false` |AC: #23, #24, #25 | Depends: None
  - Library search returns no results
  - Library listing still works via database queries
  - Search index data is preserved
  - Re-enable when search service issues are resolved

### Disable Library Analytics

- [ ] **[S]** Set `CONTENT_LIBRARIES_ANALYTICS_ENABLED=false`| AC: #26, #27 | Depends: None
  - New xAPI events no longer include `library_key` context
  - Existing analytics data is preserved in ClickHouse
  - Re-enable when analytics pipeline issues are resolved

### Emergency: Blockstore Data Corruption

- [ ] **[L]** Restore Blockstore from GCS backup | AC: #28 |Depends: None
  - Stop all CMS workers to prevent further writes
  - Identify affected library(ies) from error logs
  - Restore Blockstore GCS bucket from latest snapshot (GCS versioning)
  - Restore library metadata from Cloud SQL backup if needed
  - Re-index restored libraries in search index
  - Restart CMS workers
  - Verify restored libraries via API
  - File P0 incident report with root cause analysis

### Emergency: Cross-Tenant Library Leakage

- [ ] **[M]** Disable public library access and patch bypass| AC: #20, #21, #22 | Depends: None
  - Immediately disable `CONTENT_LIBRARIES_PUBLIC_READ_ENABLED`
  - Review access logs for affected time window
  - Identify and patch access control bypass
  - Re-enable public read after fix verification
  - Notify affected tenants per incident response policy
  - Run cross-tenant isolation tests for library endpoints

---

## Summary

**Total Tasks**: 137 tasks across Build (49), Test (18), Observability (8), Docs (6), Rollout (30), Rollback (8)

**Estimated Duration**: 12 weeks (Phases 0-4)

**Critical Path**:
1. Infrastructure & Configuration → Library Lifecycle → Component Authoring → Versioning → Cross-Course Reuse → Multi-Tenant Isolation → Search → Analytics → Backup → Performance Tuning

**Highest Risk Areas**:
- Multi-tenant isolation enforcement (security-critical)
- Blockstore storage backend configuration and backup (data integrity)
- Search index performance at scale (50,000+ components)
- Cross-course reuse sync logic (data consistency)

**Dependencies**:
- Specs: `multi-tenancy-architecture_spec.md`, `observability-stack_spec.md`, `disaster-recovery-business-continuity_spec.md`
- Infrastructure: GCS bucket `lms-blockstore`, search engine(Meilisearch or Elasticsearch), Cloud SQL backups
- Upstream: Open edX Redwood release, `frontend-app-authoring` MFE, Blockstore Django app
