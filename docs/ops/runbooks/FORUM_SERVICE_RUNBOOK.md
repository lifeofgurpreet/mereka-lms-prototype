# Forum Service Runbook
_Audience: Platform Eng + SRE • Owner: Engineering Lead • Last updated: 2026-02-10_

This runbook covers operational procedures for the Python-based forum service (openedx-forum v0.3.8), integrated into the LMS process. The forum uses MongoDB Atlas for storage and Meilisearch for search indexing.

> **Spec**: `specs/forum-service-migration_spec.md`
> **Testmap**: `specs/_generated/testmaps/forum-service-migration_spec.testmap.yml`
> **ADR**: `docs/adr/007-forum-migration-ruby-to-python.md`

## Architecture

- Forum runs as part of the LMS Django process (no separate container)
- Storage: MongoDB Atlas (`cs_comments_service` database)
- Search: Meilisearch (deployed as a separate pod in the cluster)
- Connection: `pymongo[srv]` for Atlas SRV connections

## Prerequisites

- Access to MongoDB Atlas console (`cluster-mereka-lms.2pjex4s.mongodb.net`)
- Access to production GKE cluster
- LMS admin credentials

---

## Thread Count Verification

### Procedure
1. Connect to MongoDB Atlas and count documents:
   ```bash
   # Via Atlas Data Explorer or mongosh
   use cs_comments_service
   db.contents.countDocuments({_type: "CommentThread"})
   ```
2. Compare with pre-migration snapshot count
3. Verify counts match within acceptable tolerance (< 0.1% difference)

### Acceptance
- Thread count matches pre-migration snapshot
- No orphaned threads (threads without a course_id)

---

## Content Hash Verification

### Procedure
1. Sample 100 random threads from Atlas
2. Compute stable content hashes (body + author_id + created_at)
3. Compare hashes with pre-migration reference hashes

### Acceptance
- All sampled content hashes match pre-migration references
- No data corruption detected in body text

---

## Vote Count Verification

### Procedure
1. Query vote aggregates from Atlas:
   ```bash
   db.contents.aggregate([
     {$group: {_id: null, totalVotes: {$sum: "$votes.count"}}}
   ])
   ```
2. Compare with pre-migration vote totals
3. Spot-check 10 individual threads for vote accuracy

### Acceptance
- Aggregate vote counts match pre-migration totals
- Individual thread vote counts are accurate

---

## Thread CRUD Operations

### Procedure
1. Log in to LMS as a test user enrolled in a course with forums enabled
2. Create a new thread, verify it appears
3. Edit the thread body, verify changes persist
4. Reply to the thread, verify reply appears
5. Delete the thread (as admin), verify removal

### Acceptance
- All CRUD operations complete without errors
- Changes are immediately visible to other users
- Deleted content is not retrievable via API

---

## Vote Persistence Testing

### Procedure
1. Log in as test user, navigate to a forum thread
2. Upvote a thread, verify vote count increments
3. Refresh page, verify vote persists
4. Remove vote, verify count decrements

### Acceptance
- Votes persist across page refreshes
- Vote counts update in real-time
- Users cannot vote on their own threads

---

## Moderation Queue Verification

### Procedure
1. Log in as regular user, flag a thread as abusive
2. Log in as moderator, check moderation queue
3. Verify flagged thread appears in queue
4. Take moderation action (approve/remove)

### Acceptance
- Flagged content appears in moderator queue
- Moderation actions are applied immediately
- Flagging user receives no notification about moderation outcome

---

## Meilisearch Index Verification

### Procedure
1. Check Meilisearch index status:
   ```bash
   kubectl exec -n mereka-lms deploy/meilisearch -- curl -s localhost:7700/indexes | jq .
   ```
2. Verify document count matches MongoDB thread count
3. Test search with known thread title

### Acceptance
- Meilisearch index exists and is healthy
- Document count within 5% of MongoDB thread count
- Search returns relevant results for known queries

---

## Production Health Check

### Procedure
1. Verify LMS pod is running with forum endpoints available:
   ```bash
   kubectl exec -n mereka-lms deploy/lms -- curl -s localhost:8000/api/discussion/v1/courses/ | head -c 200
   ```
2. Check LMS startup logs for forum initialization:
   ```bash
   kubectl logs -n mereka-lms -l app.kubernetes.io/name=lms --tail=50 | grep -i forum
   ```

### Acceptance
- Forum API endpoints respond with 200 status
- LMS startup logs show successful forum initialization
- No forum-related errors in recent logs

---

## Performance Testing

### Procedure
1. Generate concurrent load against forum endpoints (10-50 concurrent users)
2. Measure response times for:
   - Thread list: target < 500ms p95
   - Thread detail: target < 300ms p95
   - Search: target < 1000ms p95
3. Monitor MongoDB Atlas metrics during load

### Acceptance
- Response times within targets under load
- No connection pool exhaustion
- Atlas metrics show healthy connection count

---

## Rollback Procedure

### Procedure
1. Review rollback documentation in the migration plan
2. Verify Velero backup exists from before migration
3. Document the rollback steps:
   - Scale down LMS pods
   - Restore from pre-migration backup (if needed)
   - Redeploy with Ruby forum configuration
   - Verify service restoration

### Acceptance
- Rollback procedure is documented and reviewed
- Pre-migration backup exists and is restorable
- Rollback can be completed within the RTO (4 hours)

---

## Rollback Data Integrity

### Procedure
1. In a test environment, perform rollback
2. Verify all forum data is accessible after rollback
3. Verify no data loss from the migration period

### Acceptance
- All pre-migration data accessible after rollback
- Data created during Python forum period is preserved where possible
- Rollback process does not corrupt existing data

---

## Observability Verification

### Procedure
1. Access Grafana forum dashboard
2. Verify metrics are being collected:
   - Forum API request rate and latency
   - MongoDB connection pool usage
   - Meilisearch index health
   - Error rates per endpoint
3. Verify alerts are configured for:
   - Forum API error rate > 5%
   - MongoDB connection failures
   - Meilisearch unavailability

### Acceptance
- Dashboard loads with recent data points
- All listed metrics have data for the past 24 hours
- Alert rules exist and have been tested

---

## Edge Case Testing

### MongoDB Connection Failure
1. Simulate Atlas connection failure (e.g., rotate credentials)
2. Verify LMS continues serving non-forum pages
3. Verify forum endpoints return appropriate error messages

### Meilisearch Unavailability
1. Scale down Meilisearch deployment
2. Verify forum browse/read operations still work (degraded search)
3. Verify search returns a user-friendly error

### Invalid API Credentials
1. Manipulate K8s secrets to use invalid forum API key
2. Verify proper 401/403 error responses
3. Verify no sensitive information leaked in error messages

### Missing Meilisearch Index
1. Delete Meilisearch index via API
2. Verify index is recreated on next reindex operation
3. Verify search returns empty results (not errors) during reindex

### Unicode and Special Characters
1. Create threads with Unicode emoji, RTL text, and special characters
2. Verify content renders correctly
3. Verify search indexes handle Unicode properly

### Concurrent Thread Creation
1. Simulate concurrent thread creation (race conditions)
2. Verify no duplicate threads are created
3. Verify thread ordering is consistent

### Thread Size Limits
1. Create thread with maximum body size
2. Verify size limit is enforced
3. Verify appropriate error message for oversized content

### Search Input Sanitization
1. Test search with XSS payloads
2. Verify input is sanitized
3. Verify no script execution in search results

### SSO and Forum Permissions
1. Verify SSO-authenticated users can access forums
2. Verify course enrollment gates forum access
3. Covered in detail by auth-sso-enterprise spec
