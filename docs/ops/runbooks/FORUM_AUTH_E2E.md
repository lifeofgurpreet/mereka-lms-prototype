# Forum Authentication End-to-End Flow
_Audience: Operators and developers • Owner: Platform Team • Last verified: 2026-03-12 • Status: active_

<!-- Last verified: 2026-02-13 -->

This document covers the complete authentication and discussion flow for the forum service in the Mereka Open edX ecosystem.

## Forum Architecture

### Components
- **Forum Service**: Python openedx-forum v0.3.8 (Django-based)
- **Search Backend**: Meilisearch (indexes posts/comments for search)
- **LMS Integration**: Forum embedded in LMS courseware via Django apps
- **Authentication**: API_KEY-based auth + session cookie integration

### Service Communication
```
User → LMS (authenticated) → Forum API (API_KEY header) → MongoDB (forum data)
                           ↘ Meilisearch (search index)
```

## API Key Injection

Forum service authenticates via `API_KEY` header injected by LMS:

**LMS Configuration** (`config.yml`):
```yaml
FORUM_API_KEY: "<secret-key>"
```

**Forum Service** (K8s secret):
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: forum-api-key
data:
  API_KEY: <base64-encoded-key>
```

**Verification**:
```bash
# Check LMS config
kubectl exec -it -n mereka-lms deploy/lms -- printenv FORUM_API_KEY

# Check forum service secret
kubectl get secret -n mereka-lms forum-api-key -o jsonpath='{.data.API_KEY}' | base64 -d
```

## Session Integration

Forum inherits user session from LMS:

1. User logs into LMS (via Authentik OIDC)
2. LMS creates Django session cookie
3. User navigates to forum within courseware
4. LMS passes session + API_KEY to forum service
5. Forum validates API_KEY and extracts user from session

**Session Cookie**: `sessionid` (shared across LMS and forum)

## End-to-End Flow

### Post Creation
1. User navigates to course discussion tab in LMS
2. LMS frontend loads forum UI (embedded React component)
3. User creates new thread/post
4. Request: `POST /api/discussion/threads`
   - Headers: `API_KEY`, `Cookie: sessionid=...`
   - Body: thread title, body, category
5. Forum service validates API_KEY
6. Forum extracts user from session
7. Post saved to MongoDB `cs_comments_service.contents` collection
8. Meilisearch index updated asynchronously

### Reply Flow
1. User views thread
2. Request: `GET /api/discussion/threads/{thread_id}`
   - Headers: `API_KEY`, `Cookie: sessionid=...`
3. Forum returns thread + comments
4. User submits reply
5. Request: `POST /api/discussion/threads/{thread_id}/comments`
6. Comment saved to MongoDB
7. Meilisearch index updated

### Moderation
1. Course staff/instructor views forum
2. Staff role determined by LMS session (CourseStaffRole/CourseInstructorRole)
3. Staff can:
   - Pin/unpin threads
   - Close threads
   - Delete posts/comments
   - Edit any post/comment
4. Moderation actions recorded in `abuse_flaggers` collection

### Search
1. User searches forum: `GET /api/discussion/search?q=<query>`
2. Forum service queries Meilisearch index
3. Results filtered by:
   - Course visibility
   - User permissions
   - Deleted/closed status
4. Results returned with highlights

## Troubleshooting

### Common Auth Failures

**Symptom**: "Not authenticated" when accessing forum

**Causes**:
1. API_KEY mismatch between LMS and forum service
2. Session cookie not passed (CORS issue)
3. User session expired

**Diagnosis**:
```bash
# 1. Verify API_KEY match
kubectl exec -it -n mereka-lms deploy/lms -- printenv FORUM_API_KEY
kubectl get secret -n mereka-lms forum-api-key -o jsonpath='{.data.API_KEY}' | base64 -d

# 2. Check forum logs for auth errors
kubectl logs -n mereka-lms -l app.kubernetes.io/name=forum --tail=50 | grep -i auth

# 3. Verify session cookie in browser dev tools
# Network tab → /api/discussion/ request → check Cookie header
```

**Fix**:
```bash
# Sync API_KEY from Infisical
./scripts/infra/sync-mereka-lms-secrets-to-gcpsm.sh

# Restart services
kubectl rollout restart -n mereka-lms deploy/lms deploy/forum
```

### API Key Mismatch

**Symptom**: Forum returns 401/403 errors

**Check**:
```bash
# Compare keys
LMS_KEY=$(kubectl exec -it -n mereka-lms deploy/lms -- printenv FORUM_API_KEY | tr -d '\r')
FORUM_KEY=$(kubectl get secret -n mereka-lms forum-api-key -o jsonpath='{.data.API_KEY}' | base64 -d)

if [ "$LMS_KEY" = "$FORUM_KEY" ]; then
  echo "Keys match ✓"
else
  echo "Keys mismatch ✗"
  echo "LMS:   $LMS_KEY"
  echo "Forum: $FORUM_KEY"
fi
```

### Session Cookie Issues

**Symptom**: Forum shows "anonymous user" despite LMS login

**Causes**:
1. CORS configuration blocking cookies
2. Session cookie domain mismatch
3. Secure cookie settings on HTTP

**Check CORS** (`config.yml`):
```yaml
CORS_ALLOW_CREDENTIALS: true
CSRF_TRUSTED_ORIGINS:
  - https://academyv2.mereka.io
  - https://apps.academyv2.mereka.io
```

**Check Session Domain**:
```bash
kubectl exec -it -n mereka-lms deploy/lms -- python manage.py lms shell

>>> from django.conf import settings
>>> settings.SESSION_COOKIE_DOMAIN
'.mereka.io'  # Should allow cross-subdomain
```

## Verification

Use the verification script to test the complete flow:

```bash
./scripts/qa/verify-forum-smoke.sh
```

**Note**: Script needs to be created to verify:
1. API_KEY configuration match
2. Session persistence across LMS and forum
3. Post creation flow
4. Reply submission
5. Moderation actions
6. Search functionality

**Manual Verification**:
1. Log into LMS
2. Navigate to course discussion tab
3. Create thread
4. Reply to thread
5. Search for post
6. (Staff only) Pin/close thread

## Related Documentation

- `docs/reference/operations/AUTH_AND_PERMISSIONS.md` - Authentication architecture
- `scripts/qa/verify-forum-service.sh` - Forum service verification
- `scripts/qa/verify-forum-moderation.sh` - Moderation flow verification
