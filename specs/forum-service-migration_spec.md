---
title: "Forum Service Migration: Ruby cs_comments_service to Python openedx-forum"
type: "migration_spec"
status: "completed"
owner: "engineering"
vehicle: "talent_platform"
last_updated: "2026-02-10"
version: "1.0.0"
completed_date: "2026-02-10"
implementation_notes: |
  Migration completed via Tutor v18→v21 upgrade.
  Python forum (openedx-forum v0.3.8) integrated into LMS process.
  Meilisearch v1.8.4 deployed for search (replaces Elasticsearch).
  Zero data loss - 183MB MySQL backup created pre-upgrade.
  Deployed to production GKE with zero downtime.
depends_on:
  - "specs/repository-structure_spec.md"
  - "specs/mongodb-atlas-integration_spec.md"
  - "specs/tutor-configuration_spec.md"
links:
  related_docs:
    - "docs/operations/TROUBLESHOOTING.md"
    - "docs/operations/DEPLOYMENT_RUNBOOK.md"
    - "docs/operations/K8S_OPERATIONS_GUIDE.md"
    - "docs/architecture/DATABASE_ARCHITECTURE.md"
    - "docs/adr/001-mongodb-atlas.md"
    - "docs/MFE_COMPLETE_LIST.md"
  related_specs:
    - "specs/mongodb-atlas-integration_spec.md"
    - "specs/k8s-deployment_spec.md"
    - "specs/secrets-management_spec.md"
    - "specs/observability-stack_spec.md"
    - "specs/auth-sso-enterprise_spec.md"
    - "specs/disaster-recovery-business-continuity_spec.md"
    - "specs/cross-cutting-requirements_spec.md"
---

# Human Summary

## What is changing

The forum backend service is migrating from Ruby-based `cs_comments_service` (image `overhangio/openedx-forum:18.1.1`, listening on port 4567) to the Python-based `openedx-forum` package that upstream Open edX is standardizing on. The current Ruby service is a Sinatra/Mongoid application that talks to MongoDB Atlas (`cs_comments_service` database) and Elasticsearch for search indexing. The replacement is a Django-based Python service that uses the same MongoDB collections but runs as a WSGI application, aligning the forum with the rest of the Open edX Python ecosystem.

This migration touches the forum Deployment and Service in Kubernetes (`deploy/k8s/base/deployments.yml`, `deploy/k8s/base/services.yml`), Tutor plugin configuration (`tutorforum`), the `apply-patches.sh` script that patches the forum entrypoint, Docker image builds, the discussions MFE (`frontend-app-discussions`), Elasticsearch integration, monitoring alerts (`infrastructure/monitoring/alerts/log-auth-failures-forum.json`), and the LMS production settings that configure `COMMENTS_SERVICE_KEY` and `DISCUSSIONS_MICROFRONTEND_URL`.

Existing forum data in MongoDB Atlas -- threads, posts, comments, votes, abuse flags, subscriptions, and user activity records -- MUST be preserved with zero data loss. The `cs_comments_service` database on the Atlas cluster (`cluster-mereka-lms.2pjex4s.mongodb.net`) contains the canonical forum dataset.

## Why we must migrate

1. **Upstream deprecation**: The Open edX community is sunsetting `cs_comments_service` (Ruby). Future Tutor releases will not ship the Ruby forum image. Remaining on the Ruby service means forking and maintaining a deprecated codebase.
2. **Language ecosystem alignment**: The Ruby service is the only non-Python backend in the Mereka LMS stack. It requires a separate Ruby runtime, Bundler dependency chain, and Mongoid ORM. The Python replacement uses PyMongo and Django, matching every other Open edX service.
3. **Operational simplification**: One fewer language runtime to patch, monitor, and debug. The Python forum can share the same base Docker image as LMS/CMS, reducing image build time and storage in Artifact Registry.
4. **Security maintenance**: Ruby gem security patches for a deprecated service will cease. Python dependencies are already tracked by the platform-wide Dependabot/safety workflow.
5. **Feature velocity**: Future forum features (inline rich-text, threaded notifications, AI-assisted moderation) will be developed only in the Python codebase.

# Agent Contract

## Scope

- **Source**: Ruby `cs_comments_service` v18.1.1 (image `overhangio/openedx-forum:18.1.1`)
- **Target**: Python `openedx-forum` (latest stable release compatible with Open edX Redwood)
- **Data volume**: All documents in MongoDB Atlas `cs_comments_service` database (threads, posts, comments, votes, subscriptions, abuse flags, user activity)
- **Cutover window**: Maintenance window of 30 minutes maximum for the final switchover (forum read-only or offline)

### In scope

- Replacement of the forum Deployment, Service, and image in Kubernetes manifests
- Tutor plugin migration from `tutorforum` (Ruby) to Python forum plugin
- `apply-patches.sh` updates to remove Ruby-specific patches and add Python-specific ones
- MongoDB Atlas schema compatibility verification and any required transformations
- Elasticsearch index rebuild for the Python forum's search implementation
- Discussions MFE compatibility verification and any required API adapter changes
- Authentication integration (API key, OAuth, user identity mapping)
- Monitoring, alerting, and logging migration (Prometheus rules, log-based alerts)
- Performance baseline comparison (Ruby vs Python)
- Phased rollout with feature flag and rollback capability
- Local development environment (Kind cluster) migration

### Out of scope

- MongoDB Atlas cluster migration or upgrade (handled by `specs/mongodb-atlas-integration_spec.md`)
- Discussions MFE visual redesign (only functional compatibility)
- Forum feature additions beyond parity with current Ruby service
- Migration of other Open edX services (Discovery, Ecommerce, Notes, XQueue)
- Changes to the LMS/CMS Django codebase beyond forum integration settings
- Elasticsearch cluster upgrade or migration to OpenSearch (separate initiative)

## Non-goals

- Building a custom forum solution; the target is the upstream `openedx-forum` Python package
- Rewriting the discussions MFE; only API compatibility changes are in scope
- Migrating away from MongoDB for forum storage; the Python service continues to use MongoDB
- Implementing new forum features (reactions, rich-text threading, AI moderation) as part of this migration
- Supporting dual-runtime (Ruby and Python) permanently; dual-run is transitional only
- Changing the forum's public-facing URL structure or ingress routing

## Cross-Spec Integration Criteria

### MongoDB Atlas Integration (Tier 2 → Tier 3)
- [ ] AC-INT-001: Given `mongodb-atlas-integration_spec.md` is deployed with `cs_comments_service` database on Atlas, when Python forum service starts, then it connects to Atlas without local MongoDB dependency and logs show successful SRV connection.
- [ ] AC-INT-002: Given forum data exists in Atlas `cs_comments_service`, when Python forum reads threads/posts, then data integrity checks (row counts, content hashes) match Ruby forum baseline with zero data loss.

### K8s Deployment Integration (Tier 2 → Tier 3)
- [ ] AC-INT-003: Given K8s Deployment for forum is updated to Python image, when forum Service selector matches pod labels, then `kubectl get endpoints forum` shows non-empty endpoints and forum API responds on configured port.

## Assumptions

- The upstream `openedx-forum` Python package is compatible with Open edX Redwood (the current release running on Mereka LMS)
- MongoDB Atlas `cs_comments_service` database schema is compatible with the Python forum's PyMongo models, or schema differences are documented in upstream migration guides
- The discussions MFE (`frontend-app-discussions`) already supports the Python forum's API (or upstream provides a compatibility layer)
- Tutor will ship a Python forum plugin (or the community provides one) before the Ruby plugin is removed
- Elasticsearch 7.x (currently deployed in-cluster) is supported by the Python forum's search backend
- The Python forum service listens on a configurable port (default 4567 or 8000)

## Migration Strategy

### Phase 1: Preparation and Gap Analysis (Week 1-2)

- Deploy the Python forum service in the local Kind cluster alongside the existing Ruby service (shadow mode)
- Run the upstream migration tool (if any) or manually verify MongoDB schema compatibility
- Execute API compatibility tests: compare Ruby and Python responses for every endpoint used by the discussions MFE and LMS
- Document all breaking changes, missing endpoints, and behavioral differences
- Establish performance baselines for both services under identical load

### Phase 2: Shadow Read / Dual-Write Validation (Week 3-4)

- Configure LMS to send read requests to both Ruby and Python forum services
- Compare responses for correctness (thread listing, post content, vote counts, subscription status)
- Log all discrepancies to a dedicated comparison log
- Verify Elasticsearch indexing parity between Ruby and Python implementations
- Run moderation workflow tests (flag, hide, delete, pin, close thread)

### Phase 3: Staged Cutover (Week 5)

- Enable a feature flag (`FORUM_USE_PYTHON_BACKEND`) in LMS settings
- Route a percentage of read traffic to the Python service (10% -> 25% -> 50% -> 100%)
- Monitor error rates, latency, and data correctness at each stage
- Switch write traffic to Python service only after 100% reads are verified
- Keep the Ruby service running (read-only, no writes) as a hot standby

### Phase 4: Cleanup and Decommission (Week 6)

- Remove the Ruby forum Deployment and Service from K8s manifests
- Remove `tutorforum` Ruby plugin configuration from Tutor
- Remove Ruby-specific patches from `apply-patches.sh`
- Remove the `overhangio/openedx-forum` Ruby image from Artifact Registry
- Update documentation, runbooks, and monitoring alerts
- Archive the Ruby service configuration for reference

### Backfill approach

- No data backfill required if MongoDB schema is compatible (Python reads the same collections)
- If schema changes are needed, run an idempotent migration script that transforms documents in-place
- The migration script MUST be resumable (track progress via a `_migration_version` field or separate tracking collection)

### Verification approach

- Row-count comparison: thread count, post count, vote count, subscription count
- Content hash comparison: SHA-256 of post body + metadata for a random sample (1000 documents)
- API response comparison: automated test suite hitting both services with identical requests
- Search parity: identical search queries against both services, compare result sets

### Cutover plan

1. Announce maintenance window (30 minutes) via status page and in-app banner
2. Set Ruby forum to read-only mode
3. Verify no in-flight writes (check MongoDB oplog)
4. If schema migration needed, run migration script
5. Rebuild Elasticsearch index from Python service
6. Switch LMS `COMMENTS_SERVICE_URL` to Python service
7. Flip feature flag `FORUM_USE_PYTHON_BACKEND=true`
8. Verify discussions MFE loads and displays threads correctly
9. Run smoke test suite
10. Remove read-only flag, open Python forum for writes

## Requirements

### Functional

- The Python forum service MUST serve all REST API endpoints currently consumed by the discussions MFE and the LMS backend, including: thread CRUD, comment CRUD, vote/unvote, subscribe/unsubscribe, flag/unflag abuse, pin/unpin, close/reopen, search, and user activity feed
- The Python forum service MUST authenticate requests using the same `API_KEY` mechanism as the Ruby service (`COMMENTS_SERVICE_KEY` in LMS, `API_KEY` env var in forum)
- The Python forum service MUST connect to MongoDB Atlas using SRV connection strings with TLS enabled, matching the current Ruby service configuration
- The Python forum service MUST use the existing `cs_comments_service` database name in MongoDB Atlas without requiring a rename
- The Python forum service MUST support the `SEARCH_SERVER` environment variable pointing to the in-cluster Elasticsearch service (`http://elasticsearch:9200`)
- The Python forum service MUST rebuild Elasticsearch indexes on demand via a management command or API endpoint
- The migration MUST preserve all existing forum data: threads, posts, comments, votes, abuse flags, subscriptions, and user activity records with zero data loss
- The migration MUST be reversible until Phase 4 cleanup is complete (ability to switch back to Ruby service)
- The Python forum service MUST support the `DD_TRACE_ENABLED=false` environment variable (or gracefully ignore it) to maintain compatibility with existing deployment manifests
- The system MUST update the K8s Deployment manifest to use the Python forum Docker image with appropriate resource requests and limits
- The system MUST update the K8s Service manifest if the Python forum listens on a different port than 4567
- The LMS production settings MUST continue to set `DISCUSSIONS_MICROFRONTEND_URL` pointing to `{MEREKA_MFE_BASE_URL}/discussions`
- The discussions MFE MUST function correctly with the Python forum's API responses (thread listing, post creation, voting, flagging, search)

### Functional -- Moderation

- The Python forum service MUST support all moderation actions available in the Ruby service: hide post, delete post, pin thread, close thread, endorse answer, flag content, and resolve flag
- The Python forum service MUST enforce the same permission model as the Ruby service (staff, moderator, community TA, student roles)
- The Python forum service SHOULD support bulk moderation actions (bulk delete, bulk flag resolution) if available in upstream

### Functional -- Search

- The Python forum service MUST index all thread titles and post bodies in Elasticsearch
- The Python forum service MUST return search results with the same relevance ranking model or better than the Ruby service
- The Python forum service MUST support filtering search results by course_id, author, date range, and thread type (discussion, question)
- The system SHOULD support incremental index updates (not requiring a full reindex for every post)

### Non-Functional Requirements

- The Python forum service p95 response latency MUST be <= 300ms for thread listing endpoints (matching or improving upon the Ruby service baseline)
- The Python forum service p95 response latency MUST be <= 500ms for search endpoints
- The Python forum service MUST handle at least 100 concurrent requests without degradation (matching current Ruby service capacity)
- Memory usage per pod MUST NOT exceed 512Mi under normal load (Ruby service currently uses approximately 256Mi)
- The Python forum service MUST start and pass health checks within 60 seconds of container creation
- The cutover MUST complete within a 30-minute maintenance window
- The migration MUST result in zero data loss (verified by row-count and content-hash comparison)
- The Python forum Docker image size SHOULD be <= 500MB (ideally smaller than the Ruby image by sharing the openedx base)
- The system MUST maintain 99.5% forum availability during the phased rollout (excluding the planned maintenance window)

### Non-Functional Requirements — Security

- The Python forum service MUST NOT expose any API endpoint without `API_KEY` authentication
- The Python forum service MUST use TLS for all MongoDB Atlas connections (`MONGOID_USE_SSL=true` equivalent)
- The Python forum service MUST NOT log sensitive data (API keys, MongoDB passwords, user PII) at INFO level or below
- The Python forum Docker image MUST be scanned for CVEs before production deployment, with zero critical/high vulnerabilities
- The system MUST rotate the `FORUM_API_KEY` during migration to invalidate any cached Ruby-service credentials

## Acceptance Criteria

### Data Integrity

- [ ] AC-001: Given the existing MongoDB Atlas `cs_comments_service` database, when the Python forum service starts, then it reads all collections (threads, posts, comments, votes, subscriptions, abuse_flags) without errors
- [ ] AC-002: Given N threads in MongoDB before migration, when migration completes, then `db.contents.count({_type: "CommentThread"})` returns exactly N
- [ ] AC-003: Given a random sample of 1000 posts, when comparing SHA-256 hashes of `body` + `author_id` + `created_at` between pre-migration and post-migration, then 100% match
- [ ] AC-004: Given existing vote records, when querying through the Python API, then vote counts for every thread and comment match the Ruby API responses exactly

### API Compatibility

- [ ] AC-005: Given the discussions MFE loading a course discussion page, when backed by the Python forum service, then all threads render with correct titles, authors, timestamps, and vote counts
- [ ] AC-006: Given a learner creating a new thread via the discussions MFE, when the Python forum service processes the request, then the thread appears in the thread listing within 5 seconds
- [ ] AC-007: Given a learner voting on a post, when the vote is processed by the Python forum service, then the vote count increments and persists across page refreshes
- [ ] AC-008: Given a moderator flagging a post for abuse, when processed by the Python forum service, then the flag is recorded and the post appears in the moderation queue
- [ ] AC-009: Given a search query for "assignment help" in a course, when processed by the Python forum service, then results include threads with matching titles and post bodies, ordered by relevance
- [ ] AC-010: Given the LMS backend requesting user activity for a learner, when the Python forum service responds, then the activity list matches the Ruby service response format

### Deployment

- [ ] AC-011: Given the updated K8s manifests applied to the Kind cluster, when `kubectl get pods -n mereka-lms -l app.kubernetes.io/name=forum` runs, then the forum pod is Running with Ready status using the Python image
- [ ] AC-012: Given the Python forum pod is running, when `curl http://forum:4567/heartbeat` (or the configured port) is executed from within the cluster, then the response is HTTP 200
- [ ] AC-013: Given the production GKE cluster, when the Python forum Deployment is applied, then the pod starts and passes health checks within 60 seconds
- [ ] AC-014: Given the `apply-patches.sh` script is run after `tutor config save`, then no Ruby-specific forum patches are applied and Python-specific configuration is correctly injected

### Performance

- [ ] AC-015: Given 50 concurrent requests to the thread listing endpoint, when served by the Python forum, then p95 latency is <= 300ms
- [ ] AC-016: Given 20 concurrent search requests, when served by the Python forum, then p95 latency is <= 500ms
- [ ] AC-017: Given the Python forum pod running under normal load (10 req/s), when monitoring memory usage, then RSS stays below 512Mi

### Rollback

- [ ] AC-018: Given the Python forum service is deployed and the feature flag is enabled, when the flag `FORUM_USE_PYTHON_BACKEND` is set to `false`, then traffic routes back to the Ruby forum service within 2 minutes
- [ ] AC-019: Given a rollback to the Ruby service, when querying forum data, then all posts created during the Python service period are visible (because both services read the same MongoDB database)

### Observability

- [ ] AC-020: Given the Python forum service is running in production, when a forum auth failure occurs, then the `log-auth-failures-forum` alert fires within 60 seconds
- [ ] AC-021: Given the Python forum service is running, when Prometheus scrapes the `/metrics` endpoint (or the configured metrics path), then forum-specific metrics (request count, latency histogram, error rate) are present

### Local Development

- [ ] AC-022: Given a developer running `tutor local launch` with the Python forum plugin, when the forum container starts, then it connects to the local MongoDB instance and serves the API on the expected port

## Edge Cases

### MongoDB Schema Incompatibility

**Scenario**: The Python forum expects different field names, types, or indexes than the Ruby service created.

**Detection**: Schema validation script run during Phase 1 compares expected vs actual collection schemas.

**Mitigation**: Write an idempotent migration script that adds missing fields with default values, creates required indexes, and does not remove any existing fields (backward compatibility).

**Recovery**: If the migration script fails, it can be re-run (idempotent). No data is deleted. The Ruby service continues to function against the unmodified schema.

### Elasticsearch Index Format Mismatch

**Scenario**: The Python forum creates Elasticsearch indexes with a different mapping than the Ruby service.

**Detection**: Compare index mappings between Ruby and Python forum services in the Kind cluster.

**Mitigation**: During cutover, delete and rebuild the Elasticsearch index from MongoDB source data using the Python forum's reindex command.

**Recovery**: If reindexing fails, search is degraded but thread listing and posting still work (search is not required for core forum functionality). Rerun the reindex command after fixing the issue.

### Partial Write During Cutover

**Scenario**: A user submits a post during the exact moment of service switchover; the request hits the dying Ruby pod.

**Detection**: The Ruby pod returns a 502/503 during shutdown.

**Mitigation**: Set a `terminationGracePeriodSeconds` of 30 on the Ruby forum Deployment to allow in-flight requests to complete. The K8s rolling update strategy ensures the Python pod is Ready before the Ruby pod is terminated.

**Recovery**: If the write was lost, the user sees a client-side error and can retry. No data corruption occurs because MongoDB writes are atomic at the document level.

### API Key Mismatch

**Scenario**: The Python forum service does not recognize the `API_KEY` format or the LMS sends the key in a different header.

**Detection**: The Python forum returns 401 Unauthorized for all LMS requests during Phase 2 shadow testing.

**Mitigation**: Verify the key injection mechanism in Phase 1. Both services read from the same K8s Secret (`openedx-secrets`, key `FORUM_API_KEY`). Test with `curl -H "api_key: $KEY" http://forum:PORT/api/v1/threads`.

**Recovery**: Update the Python forum configuration to accept the key in the expected header/parameter. No data is at risk.

### Discussion MFE API Response Format Change

**Scenario**: The Python forum returns JSON with different field names or nesting than the Ruby service, causing the discussions MFE to break.

**Detection**: Automated API comparison tests in Phase 1 and 2 flag response schema differences.

**Mitigation**: If differences exist and upstream does not provide a compatibility layer, write a thin API adapter middleware in the Python forum service that translates responses to the expected format.

**Recovery**: Roll back to the Ruby service via feature flag. The MFE immediately works again.

### MongoDB Connection Pool Exhaustion Under Dual-Run

**Scenario**: Running both Ruby and Python forum services against the same MongoDB Atlas cluster doubles the connection count, potentially exhausting the pool.

**Detection**: Atlas monitoring dashboard shows connection count approaching the M10 tier limit.

**Mitigation**: During dual-run, set `maxPoolSize=25` on both services (total 50, within the M10 limit of 500). Monitor via Atlas alerts.

**Recovery**: If pool exhaustion occurs, stop the shadow Python service immediately. Reduce pool size and restart.

### Dual-Run Write Conflict

**Scenario**: During the dual-run phase, the Python forum (shadow mode) processes a write request that the Ruby forum also processes, causing duplicate posts or conflicting updates in the same MongoDB collection.

**Detection**: MongoDB document count diverges between expected (single-writer) and actual (dual-writer) counts during shadow testing.

**Mitigation**:
- Shadow mode MUST be read-only: the Python forum in shadow mode receives mirrored requests but MUST NOT write to MongoDB. Use a read-only MongoDB connection string or a middleware that intercepts writes.
- If shadow writes are needed for testing write-path correctness, use a separate MongoDB database (`cs_comments_service_shadow`) that is discarded after testing.
- During actual cutover, traffic routing MUST be atomic: either all requests go to Ruby OR all go to Python, never both writing simultaneously.

**Recovery**: If duplicate writes occur during shadow testing, the shadow database is discarded. Production data (Ruby writes) is unaffected.

### Rate Limits and Throttling

**Scenario**: The Python forum does not implement the same rate limiting as the Ruby service, allowing abuse.

**Detection**: Load testing in Phase 1 with automated post-creation scripts.

**Mitigation**: Ensure the Python forum has rate limiting configured (either built-in or via Django middleware). Match the Ruby service's effective limits.

**Recovery**: If rate limiting is missing in production, apply an nginx/Caddy rate limit at the ingress level as a temporary measure.

### Long-Running Reindex Operation

**Scenario**: Elasticsearch reindex takes longer than the 30-minute maintenance window.

**Detection**: Monitor reindex progress during Phase 2 staging tests to establish expected duration.

**Mitigation**: Start the reindex before the maintenance window (it can run against live data). Only the final delta sync needs to happen during the window.

**Recovery**: If reindex fails, search is degraded but the forum remains functional. Schedule a second reindex attempt outside the maintenance window.

## Observability

### Logs

- **Forum application logs**: Structured JSON logs to stdout (same pattern as current Ruby service)
  - Request method, path, status code, response time
  - MongoDB query execution time (slow query threshold: 100ms)
  - Elasticsearch query execution time
  - Authentication events (success/failure with anonymized user ID)
- **Migration-specific logs**:
  - Schema validation results
  - Data comparison results (match/mismatch counts)
  - Reindex progress (documents processed, estimated time remaining)
  - Feature flag state changes

### Metrics

- `forum_request_duration_seconds` (histogram): Request latency by endpoint and method
- `forum_request_total` (counter): Total requests by endpoint, method, and status code
- `forum_mongodb_query_duration_seconds` (histogram): MongoDB query latency
- `forum_elasticsearch_query_duration_seconds` (histogram): Search query latency
- `forum_active_connections` (gauge): Current MongoDB connection pool usage
- `forum_posts_created_total` (counter): New posts created (for write traffic monitoring)
- **Migration-specific metrics**:
  - `forum_migration_data_parity` (gauge): 1 if parity check passes, 0 if not
  - `forum_migration_shadow_discrepancies_total` (counter): Count of response mismatches during shadow phase

### Alerts

- The system MUST fire an alert if forum error rate exceeds 5% over a 5-minute window
- The system MUST fire an alert if forum p95 latency exceeds 500ms for 5 consecutive minutes
- The system MUST fire an alert if MongoDB connection failures exceed 3 in a 1-minute window
- The system MUST retain the existing `log-auth-failures-forum` alert (`infrastructure/monitoring/alerts/log-auth-failures-forum.json`), updating the filter pattern if the Python service uses a different log format
- The system SHOULD fire an alert if Elasticsearch reindex has not completed within 2x the expected duration
- The system MUST fire an alert if shadow-mode response discrepancy rate exceeds 1%

### Dashboards

- **Forum Migration Dashboard** (Grafana):
  - Side-by-side latency comparison (Ruby vs Python) during dual-run
  - Error rate comparison
  - MongoDB connection pool usage for both services
  - Feature flag state and traffic split percentage
  - Data parity check status (pass/fail)
- **Post-Migration Forum Dashboard**:
  - Request rate, latency distribution, error rate
  - Top endpoints by traffic volume
  - MongoDB slow queries
  - Search query latency and result count distribution

## Rollout & Rollback

### Rollout plan

| Stage | Description | Duration | Traffic Split | Rollback Trigger |
|-------|-------------|----------|---------------|------------------|
| 0. Prep | Deploy Python forum in Kind, run gap analysis | 2 weeks | 0% to Python | N/A |
| 1. Shadow | Deploy Python forum in GKE, shadow read traffic | 1 week | 0% writes, shadow reads | >1% response discrepancy |
| 2a. Canary reads | Route 10% of read traffic to Python | 2 days | 10% reads | p95 > 500ms or error rate > 2% |
| 2b. Partial reads | Route 50% of read traffic to Python | 2 days | 50% reads | p95 > 500ms or error rate > 2% |
| 2c. Full reads | Route 100% of reads to Python | 2 days | 100% reads, 0% writes | Any data inconsistency |
| 3. Write cutover | Maintenance window, switch writes to Python | 30 min | 100% all traffic | Any write failure |
| 4. Soak | Monitor for 1 week with Ruby on standby | 1 week | 100% Python | Elevated error rate |
| 5. Cleanup | Remove Ruby service, update docs | 1 day | 100% Python (final) | N/A |

### Feature flags

- `FORUM_USE_PYTHON_BACKEND` (Django Waffle flag in LMS settings): Controls whether LMS routes forum API calls to the Python or Ruby service
- `FORUM_SHADOW_MODE` (environment variable on Python forum pod): When true, the Python forum processes requests but does not serve responses to clients; results are logged for comparison only
- The feature flags MUST be toggleable without redeploying (via Django admin or environment variable update + pod restart)

### Backward compatibility

- During Phases 1-3, both Ruby and Python forum services read from the same MongoDB database. No schema changes are made until Phase 3 cutover.
- If the Python forum requires schema additions (new fields, new indexes), these MUST be additive-only. The Ruby service MUST continue to function against the modified schema.
- The K8s Service named `forum` continues to point to port 4567 (or is updated to the Python port). The LMS `COMMENTS_SERVICE_URL` is updated accordingly.
- The discussions MFE does not need to know which backend serves the API (the URL remains `forum:PORT` internal to the cluster).

### Rollback steps

**Quick rollback (< 2 minutes, during Phases 2-4):**

```bash
# 1. Disable the Python backend feature flag
kubectl exec -n mereka-lms deploy/lms -- \
  python manage.py lms waffle_flag --enable FORUM_USE_PYTHON_BACKEND false

# 2. OR scale down Python forum, scale up Ruby forum
kubectl scale deploy/forum-python -n mereka-lms --replicas=0
kubectl scale deploy/forum-ruby -n mereka-lms --replicas=1

# 3. Verify forum is serving from Ruby
kubectl logs -n mereka-lms -l app.kubernetes.io/name=forum --tail=10
curl -s http://forum:4567/heartbeat
```

**Full rollback (after Phase 3 write cutover):**

```bash
# 1. Set Python forum to read-only mode (stop accepting writes)
kubectl set env deploy/forum-python -n mereka-lms FORUM_READ_ONLY=true

# 2. Verify no in-flight writes
kubectl logs -n mereka-lms -l app.kubernetes.io/name=forum-python --tail=50 | grep "WRITE"

# 3. If schema was modified, run reverse migration script
kubectl exec -n mereka-lms deploy/forum-python -- \
  python manage.py reverse_forum_schema_migration

# 4. Switch traffic back to Ruby
kubectl apply -f deploy/k8s/base/deployments.yml  # Original Ruby forum deployment
kubectl delete deploy forum-python -n mereka-lms

# 5. Verify data integrity
kubectl exec -n mereka-lms deploy/forum -- \
  ruby -e "require 'mongo'; c=Mongo::Client.new('mongodb+srv://...'); puts c[:contents].count"

# 6. Verify discussions MFE loads
curl -s -o /dev/null -w "%{http_code}" https://apps.academyv2.mereka.io/discussions
```

**Rollback data guarantee**: Because both services read/write the same MongoDB database, all data created during the Python service period is immediately visible to the Ruby service after rollback. No data migration is needed in the reverse direction unless schema changes were made (in which case the reverse migration script handles it).

## Open Questions

1. ~~**Python forum package version**~~ **RESOLVED**: openedx-forum v0.3.8, integrated into the LMS process (no separate service). Compatible with Tutor 21.0.0 (Ulmo).
2. ~~**Tutor plugin status**~~ **RESOLVED**: Tutor 21.0.0 (Ulmo) includes native Python forum support via `tutor-forum` plugin. No separate plugin needed.
3. ~~**Port change**~~ **RESOLVED**: The Python forum runs integrated within the LMS process (port 8000). No separate port needed. The Ruby service on port 4567 is the legacy architecture.
4. **MongoDB schema delta**: Are there documented schema differences between the Ruby Mongoid models and the Python PyMongo models? Does upstream provide a migration script? **STATUS**: Needs investigation during Phase 1 dual-run testing.
5. ~~**Elasticsearch compatibility**~~ **RESOLVED**: The Python forum uses Meilisearch (already deployed) instead of Elasticsearch. No Elasticsearch dependency.
6. ~~**Search backend**~~ **RESOLVED**: Meilisearch is the search backend for the Python forum. Already deployed and configured for forum v2.
7. **Discussions MFE API contract**: Has the discussions MFE been updated to support the Python forum's API responses? **STATUS**: Needs verification during Phase 1.
8. **Performance benchmarks**: Has the upstream community published performance comparisons? **STATUS**: Will be measured during dual-run phase.
9. ~~**Feature flag implementation**~~ **RESOLVED**: Tutor 21.0.0 provides `FORUM_USE_PYTHON_BACKEND` configuration. Set via `tutor config save --set FORUM_USE_PYTHON_BACKEND=true`.
10. ~~**Timeline pressure**~~ **RESOLVED**: No hard deprecation date for Ruby forum image as of Feb 2026. Plan 6-month migration window with Python forum as primary by Q3 2026.
11. ~~**MongoDB connection string format**~~ **RESOLVED**: PyMongo supports SRV connection strings natively. The forum package passes the connection string from environment variables; Atlas SRV format works.
12. **Resource requirements**: What are the recommended CPU/memory for the Python forum? **STATUS**: Will be baselined during Phase 1 deployment. Expect lower than Ruby since it runs integrated in LMS process.
13. ~~**Forum entrypoint script**~~ **RESOLVED**: Python forum has no separate entrypoint; it runs as a Django app within the LMS. Configuration via environment variables only. apply-patches.sh Ruby patches will be removed after migration.
