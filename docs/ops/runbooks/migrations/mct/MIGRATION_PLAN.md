# Microsoft Community Training → Open edX Migration Plan
_Audience: Platform Eng + Data • Owner: Migration Squad • Last verified: 2026-03-10_

> **Legacy note:** This doc predates the production/dev naming. References to the old environment label should be read as production (GKE); dev runs on kind.

## Overview

This document outlines the migration strategy for exporting data from **Skill Our Future** (hosted on Microsoft Community Training) and importing it into the Open edX platform. This migration runs in parallel with the Kajabi migration, both targeting the same Open edX deployment.

**Source Platform:** Microsoft Community Training (MCT)  
**Target Platform:** Open edX (via Tutor)  
**Organization:** SKILLOURFUTURE (already configured as microsite)

## API Discovery & Exploration Strategy

### 1. Access API Documentation

The MCT Swagger UI is available at:
- **Base URL:** `https://learn.skillourfuture.org/swagger/`
- **Versioned APIs:** V1, V2, V3, V4 (use V4 for latest features)
- **Status:** Requires authentication (401 response without credentials)

**Exploration Steps:**
1. **Log into MCT Portal:** First authenticate at `https://learn.skillourfuture.org` in a browser
2. **Access Swagger UI:** Navigate to `/swagger/index.html?urls.primaryName=V4` while logged in
3. **Review Endpoints:** Explore all available endpoints across V1-V4 versions
4. **Capture Token:** Open browser DevTools → Network tab → Find API requests → Extract Bearer token
5. **Test Endpoints:** Use Swagger UI "Try it out" feature or Postman/curl with captured token
6. **Document Findings:** Record endpoint paths, request/response formats, pagination, and rate limits
7. **Map Entities:** Map MCT data entities to Open edX equivalents (see table below)

### 2. Authentication Methods

**Based on working implementation in `hubspot-webhook-mct/functions/index.js`:**

**A. Service-to-Service Authentication** ✅ **RECOMMENDED** (Production-ready pattern)
- Uses Azure AD OAuth2 client credentials flow
- Token endpoint: `https://login.microsoft.com/${MCT_TENANT_ID}/oauth2/v2.0/token`
- Scope: `${MCT_API_URI}/.default`
- **Required headers for all API requests:**
  - `Authorization: Bearer <token>`
  - `ClientType: service` (required by MCT API)

**B. Token-Based Authentication** (Exploration only; do not rely on this for repeatable operator workflows)
- Obtain access token manually:
  1. Log into MCT portal (`https://learn.skillourfuture.org`) in a browser
  2. Open browser DevTools (F12) → Network tab
  3. Filter by "Fetch/XHR" requests
  4. Make any API call (e.g., load a course page)
  5. Inspect request headers only if you need to understand the interactive flow; do not persist copied tokens in docs, scripts, or shell history
  6. Copy the token value
- Useful for manual testing and Swagger UI exploration
- **Note:** Tokens expire; refresh by logging in again

**Environment Variables (from working code):**
```bash
# Base configuration
MCT_BASE_URL=learn.skillourfuture.org  # Domain only (no https://)
MCT_API_VERSION=v1  # Recommended: v1 (most comprehensive)

# Service-to-Service Auth (Option A - Recommended)
MCT_CLIENT_ID=<retrieve-from-secret-source>
MCT_CLIENT_SECRET=<your-secret>
MCT_TENANT_ID=<retrieve-from-secret-source>
MCT_API_URI=<retrieve-from-secret-source>

# OR Token-Based Auth (Option B - Testing only)
MCT_ACCESS_TOKEN=<bearer-token-from-browser>
```

**Verified Working Endpoints (from `hubspot-webhook-mct`):**
- `GET /api/v1/organization` - Get organizations (used for org mapping)
- `GET /api/v1/users?searchTerm={email}` - Lookup user by email
- `POST /api/v1/users?orgId={orgId}` - Create user
- `POST /api/v2/Organizations/{orgId}/UserProfiles/{userId}` - Update user profile

## MCT Data Entities (Expected)

Based on Microsoft Community Training architecture, the following entities likely need export:

| MCT Entity | Open edX Equivalent | Priority | Notes |
|------------|---------------------|----------|-------|
| **Users** | `auth_user` + `user_profile` | High | Learners, instructors, admins |
| **Categories** | `course_structures` (orgs) | High | Course organization hierarchy |
| **Courses** | `course_overviews` | High | Course catalog entries |
| **Course Content** | `courseware` (XBlocks) | High | Modules, lessons, videos, assessments |
| **Enrollments** | `student_courseenrollment` | High | User → Course relationships |
| **Progress** | `student_courseaccessrole` + custom tracking | Medium | Completion status, scores |
| **Certificates** | `certificates_generatedcertificate` | Medium | Achievement records |
| **Announcements** | `bulk_email` or custom | Low | Platform-wide messages |
| **Discussions** | `django_comment_client` | Low | Forum posts (if MCT has forums) |
| **Analytics** | Custom reports | Low | Export for archival |

### API Endpoints Identified (V1 + V3)

**User Management (V1):**
- `GET /api/v1/users` - Get users (verified in working code) ✅
- `GET /api/v1/users?searchTerm={email}` - Lookup user by email (verified) ✅
- `POST /api/v1/users?orgId={orgId}` - Create user (verified) ✅
- `GET /api/v1/ManageUser` - User management operations
- `GET /api/v1/Reports/Users` - Export user data

**Organizations (V1):**
- `GET /api/v1/organization` - Get organizations (verified in working code) ✅

**Categories & Courses (V1 + V3):**
- `GET /api/v1/Category` - Category operations (V1)
- `GET /api/v3/admin/categoriesAndCourses` - Hierarchical categories + courses (V3) ⭐
- `GET /api/v1/Courses` - Course catalog (V1)
- `GET /api/v3/Courses` - Get all registered courses for user (V3)

**Course Content (V3/V4):**
- `GET /api/v3/Courses/{courseId}/Content` - Course content and metadata ⭐
- `GET /api/v3/Courses/{courseId}/Metadata` - Course metadata
- `GET /api/v3/Courses/{courseId}/Lesson` - Course lessons
- `GET /api/v3/Courses/{courseId}/Certificate` - Certificate URL

**Enrollments (V1):**
- `GET /api/v1/UserEnrollment` - Enrollment operations

**Reports & Exports (V1 + V3):**
- `GET /api/v1/Reports/Users` - User export (V1)
- `GET /api/v3/Reports/Users` - User export (V3)
- `GET /api/v3/organization/{orgId}/reports/users` - Organization user export
- `GET /api/v3/course/{courseId}/Reports/Users` - Course user export

**Progress (V3/V4):**
- `PUT /api/v3/courses/{courseId}/lessons/{lessonId}/progress` - Update progress
- `POST /api/v3/courses/{courseId}/users/completeprogress` - Mark course complete

⭐ = Key endpoints for migration

## Migration Strategy

### Phase 1: API Exploration & Export Script Development

**1.1 Swagger UI Analysis**
- [ ] Log into MCT portal (`https://learn.skillourfuture.org`) in browser
- [ ] Access Swagger UI at `/swagger/index.html?urls.primaryName=V4` (while logged in)
- [ ] Compare V1, V2, V3, V4 endpoints - document endpoint differences
- [ ] Identify which version has the most complete coverage
- [ ] Document pagination parameters (`page`, `pageSize`, `skip`, `take`)
- [ ] Document filtering and query parameters
- [ ] Test rate limiting (observe `429` responses or headers)
- [ ] Capture authentication token from browser DevTools for testing
- [ ] Test sample endpoints using Swagger UI "Try it out" feature
- [ ] Document response structures (JSON schema)

**1.2 Export Script Development**
Create `scripts/migrations/mct/mct-export.mjs` (similar to `scripts/migrations/kajabi/kajabi-export.mjs`):

```javascript
// Planned structure:
- Authentication handler (Service-to-Service or Token-based)
- Resource exporters:
  * exportUsers()
  * exportCategories()
  * exportCourses()
  * exportCourseContent(courseId)
  * exportEnrollments()
  * exportProgress()
  * exportCertificates()
- NDJSON output to `exports/mct/`
- Pagination handling
- Rate limiting / retry logic
- Chunking support for large datasets
```

**1.3 Initial Data Export**
```bash
# Export all resources using service-to-service auth (recommended):
MCT_BASE_URL=learn.skillourfuture.org \
MCT_API_URI=<retrieve-from-secret-source> \
MCT_CLIENT_ID=<client-id> \
MCT_CLIENT_SECRET=<client-secret> \
MCT_TENANT_ID=<retrieve-from-secret-source> \
node scripts/migrations/mct/mct-export.mjs

# Export specific resources:
node scripts/migrations/mct/mct-export.mjs --resources users,courses,enrollments

# Export with pagination limits (for testing):
node scripts/migrations/mct/mct-export.mjs --resources users --start-page 1 --end-page 10
```

**Export Script Features:**
- ✅ Service-to-service authentication (matches `hubspot-webhook-mct` pattern)
- ✅ Automatic version fallback (V3 → V1 where needed)
- ✅ Organizations export (for org mapping)
- ✅ Course content details from V3 API
- ✅ Retry logic with exponential backoff
- ✅ Required `ClientType: service` header on all requests

### Phase 2: Data Transformation

**2.1 Transformation Script**
Create `scripts/migrations/mct/transform_data.py` (mirroring Kajabi pattern):

**Mappings:**

| MCT Field | Open edX Field | Transformation Notes |
|-----------|----------------|----------------------|
| `user.email` | `auth_user.email` | Direct mapping |
| `user.firstName` + `lastName` | `auth_user.first_name`, `last_name` | Concatenate if needed |
| `user.userId` | `auth_user.username` | Generate unique username if missing |
| `course.courseId` | `course_overviews.id` | Map to `course-v1:SKILLOURFUTURE+{slug}+{run}` |
| `course.title` | `course_overviews.display_name` | Direct mapping |
| `enrollment.userId` + `courseId` | `student_courseenrollment` | Create enrollment records |
| `progress.completionStatus` | Custom tracking table | May need custom XBlock for progress |

**2.2 Course Structure Transformation**
- MCT Categories → Open edX Course Organizations (`SKILLOURFUTURE`)
- MCT Courses → Open edX Course Runs
- MCT Modules → Open edX Course Sections
- MCT Lessons → Open edX Course Subsections/Units
- MCT Content Items → Open edX XBlocks (HTML, Video, Problem)

**2.3 Output Files** (similar to Kajabi):
```
scripts/migrations/mct/output/
├── users.csv                    # User import data
├── courses.csv                  # Course catalog metadata
├── enrollments.csv              # Enrollment mappings
├── course_structure.json        # Nested course content
├── course_summary.csv           # Module/lesson counts
└── openedx/
    ├── users_import.csv         # Open edX bulk user import
    └── enrollments_import.csv   # Open edX bulk enrollment
```

### Phase 3: Course Package Building

**3.1 Course Package Script**
Create `scripts/migrations/mct/build_course_packages.py`:

- Convert MCT course structure to Open edX OLX format
- Generate course tarballs (`course-v1:SKILLOURFUTURE+{slug}+{run}.tar.gz`)
- Handle media references (videos, PDFs may need download/upload)
- Create manifest CSV mapping MCT course IDs → Open edX course keys

**3.2 Media Migration**
- Identify media URLs in MCT content
- Download media files to `exports/mct/media/`
- Upload to Open edX media storage (S3/GCS) or Tutor's media volume
- Update course XML with new media URLs

### Phase 4: Import into Open edX

**4.1 User Import**
```bash
source infrastructure/tutor/tutor-env.sh
tutor local run lms bash -c "cat > /tmp/mct-users.csv" \
  < scripts/migrations/mct/output/openedx/users_import.csv
tutor local run lms ./manage.py lms importusers \
  /tmp/mct-users.csv --settings=tutor.production --send-email False
```

**4.2 Course Import**
```bash
# Via Studio UI (manual):
# Upload tarballs from scripts/migrations/mct/output/course_packages/

# OR automated:
python scripts/migrations/mct/import_courses_k8s.py \
  --manifest scripts/migrations/mct/output/course_packages/course_packages_manifest.csv \
  --packages-root scripts/migrations/mct/output/course_packages \
  --org SKILLOURFUTURE
```

**4.3 Enrollment Import**
```bash
tutor local run lms bash -c "cat > /tmp/mct-enrollments.csv" \
  < scripts/migrations/mct/output/openedx/enrollments_import.csv
tutor local run lms ./manage.py lms bulk_enroll \
  --csv /tmp/mct-enrollments.csv \
  --settings=tutor.production \
  --email-students False \
  --auto-enroll True
```

## Version Selection Strategy

**Recommendation: Use V1 API for comprehensive migration** ✅

**API Version Comparison:**

| Version | Sections | Best For | Recommendation |
|---------|----------|----------|----------------|
| **V1** | 33 sections | Complete data migration | ✅ **PRIMARY** - Has User, UserEnrollment, Category, Courses, Reports |
| **V3** | 3 sections | Category hierarchy, Reports | ✅ **SUPPLEMENT** - Use `/api/v3/admin/categoriesAndCourses` for hierarchical structure |
| **V4** | 1 section | Course operations only | ❌ Limited - No user management, no categories |

**Decision:**
- **V1** has the most comprehensive API with User, UserEnrollment, Category, Courses, Reports, and Export endpoints
- **V3** provides useful hierarchical category/course endpoint (`/api/v3/admin/categoriesAndCourses`)
- **V4** is too limited for migration (only course operations)

**Migration Strategy:**
- Use **V1** for user management, enrollments, categories, courses, and reports
- Use **V3** for hierarchical category structure and user reports
- Use **V3/V4** for course content details (Content, Metadata, Lesson endpoints)

## Data Quality Considerations

**1. User Data:**
- Email uniqueness (handle duplicates)
- Username generation (if MCT doesn't provide)
- Password handling (reset links vs. password hashes)
- Profile data (bio, avatar URLs)

**2. Course Data:**
- Course slug generation (URL-safe, unique)
- Course run dates (start/end)
- Course visibility (public/private)
- Prerequisites mapping

**3. Enrollment Data:**
- Enrollment dates (preserve original enrollment timestamps)
- Enrollment status (active/completed/dropped)
- Course access modes (audit/verified)

**4. Progress Data:**
- Completion percentages
- Assessment scores
- Time spent tracking
- Last accessed dates

## Testing Strategy

**1. Small Batch Test:**
- Export 10 users, 2 courses, 20 enrollments
- Transform and import into production Open edX (GKE)
- Validate data integrity

**2. Incremental Migration:**
- Export in chunks (e.g., 100 users at a time)
- Import incrementally
- Monitor for errors

**3. Validation Checklist:**
- [ ] All users can log in
- [ ] All courses appear in catalog
- [ ] Enrollments are correct
- [ ] Course content renders properly
- [ ] Media files are accessible
- [ ] Progress data preserved (if applicable)

## Parallel Migration Context

This MCT migration runs alongside the Kajabi migration. Considerations:

**Shared Resources:**
- Both target the same Open edX instance
- Both use `SKILLOURFUTURE` organization (or separate orgs if needed)
- Both share the same Tutor deployment

**Coordination:**
- Ensure no user email conflicts between MCT and Kajabi exports
- Coordinate course ID generation (different prefixes: `MCT-` vs `KAJ-`)
- Share transformation patterns where applicable

## Next Steps

1. **Immediate:**
   - [x] ✅ Export script created (`scripts/migrations/mct/mct-export.mjs`) with working authentication pattern
   - [x] ✅ API exploration documented (`docs/reference/migrations/mct/API_EXPLORATION.md`)
   - [x] ✅ Migration plan updated with verified endpoints
   - [ ] **Get authentication credentials** - Use existing service principal or create new one
   - [ ] **Test export script** - Run with small dataset (e.g., `--start-page 1 --end-page 1`)
   - [ ] **Verify export output** - Check NDJSON files in `exports/mct/`

2. **Short-term:**
   - [ ] Run full data export to `exports/mct/`
   - [ ] Analyze exported data structure
   - [ ] Build transformation scripts (`scripts/migrations/mct/transform_data.py`)
   - [ ] Map MCT user profile fields to Open edX user profile

3. **Medium-term:**
   - [ ] Build course package generator (MCT → Open edX OLX format)
   - [ ] Handle media migration (download/upload course assets)
   - [ ] Test import into production Open edX (GKE)
   - [ ] Validate data integrity and completeness

4. **Long-term:**
   - [ ] Full production migration
   - [ ] Data validation and cleanup
   - [ ] User communication and training
   - [ ] Progress/completion data migration (if applicable)

## References

- [Microsoft Community Training API Documentation](https://learn.microsoft.com/en-us/azure/industry/training-services/microsoft-community-training/ga-version/get-started/ga-version-migration/rest-api-documentation)
- **Working MCT Integration:** `hubspot-webhook-mct/functions/index.js` - Production code showing authentication and API usage patterns
- **📖 Complete Export Guide:** `docs/ops/runbooks/migrations/mct/EXPORT_GUIDE.md` - Comprehensive documentation for MCT export process
- Kajabi migration pattern: `docs/reference/migrations/kajabi/KAJABI_MIGRATION_NOTES.md`
- Kajabi transformation scripts: `scripts/migrations/kajabi/`
- Open edX bulk import commands: `docs/guides/onboarding/LOCAL_SETUP.md`
- MCT API exploration results: `docs/reference/migrations/mct/API_EXPLORATION.md`
