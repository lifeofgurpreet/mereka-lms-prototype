# MCT API Exploration Results
_Audience: Platform Eng • Owner: Migration Squad • Last verified: 2025-08-15_

**Based on:** Swagger API exploration + Working code analysis from `hubspot-webhook-mct/functions/index.js`

## API Version Comparison

### V1 (Most Comprehensive) ✅ **RECOMMENDED**
**33 API Sections** - Best for data migration

Key sections for migration:
- **User** - User management endpoints ✅ (verified: `/api/v1/users`)
- **UserEnrollment** - Enrollment operations
- **Category** - Category hierarchy
- **Courses** - Course catalog and content
- **Reports** - User/course reports and exports
- **ManageUser** - User CRUD operations
- **Organization** - Organization management ✅ (verified: `/api/v1/organization`)
- **Group** - Group management
- **Lesson** - Lesson content
- **Certificate** - Certificate generation
- **Analytics** - Analytics data
- **Export** - Data export endpoints

### V3 (Good Coverage)
**3 API Sections:**
- **AdminApi** - `/api/v3/admin/categoriesAndCourses` (hierarchical categories + courses)
- **Courses** - Course operations (similar to V4)
- **Reports** - User export endpoints (`/api/v3/Reports/Users`, `/api/v3/organization/{orgId}/reports/users`, etc.)

### V4 (Limited)
**1 API Section:**
- **Courses** - Course-specific operations only (no user management, no categories)

## Recommended Migration Strategy

**Use V1 API for comprehensive data export** - it has all the endpoints we need:
- User management ✅
- Enrollment data
- Categories
- Courses
- Reports/Exports

**Use V3 API as supplement** for:
- Hierarchical category/course structure (`/api/v3/admin/categoriesAndCourses`)
- User reports (`/api/v3/Reports/Users`)
- Course content details (`/api/v3/Courses/{courseId}/Content`)

## Key Endpoints Identified

### User Management (V1) ✅ Verified
- `GET /api/v1/users` - Get users (verified in `hubspot-webhook-mct`)
- `GET /api/v1/users?searchTerm={email}` - Lookup user by email (verified)
- `POST /api/v1/users?orgId={orgId}` - Create user (verified)
- `GET /api/v1/ManageUser` - User management operations
- `GET /api/v1/Reports/Users` - Export user data

### Organizations (V1) ✅ Verified
- `GET /api/v1/organization` - Get organizations (verified in `hubspot-webhook-mct`)

### Categories & Courses (V1 + V3)
- `GET /api/v1/Category` - Category operations
- `GET /api/v3/admin/categoriesAndCourses` - Hierarchical categories + courses (V3) ⭐
- `GET /api/v1/Courses` - Course catalog
- `GET /api/v3/Courses` - Get all registered courses for user (V3)

### Course Content (V3/V4)
- `GET /api/v3/Courses/{courseId}/Content` - Course content and metadata ⭐
- `GET /api/v3/Courses/{courseId}/Metadata` - Course metadata
- `GET /api/v3/Courses/{courseId}/Lesson` - Course lessons

### Enrollments (V1)
- `GET /api/v1/UserEnrollment` - Enrollment operations

### Reports (V1 + V3)
- `GET /api/v1/Reports/Users` - User export
- `GET /api/v3/Reports/Users` - User export (V3)
- `GET /api/v3/organization/{orgId}/reports/users` - Organization user export
- `GET /api/v3/course/{courseId}/Reports/Users` - Course user export

## Authentication Pattern (from working code)

**Service-to-Service Auth:**
- Token endpoint: `https://login.microsoft.com/${MCT_TENANT_ID}/oauth2/v2.0/token`
- Scope: `${MCT_API_URI}/.default`
- **Required headers:** `Authorization: Bearer <token>`, `ClientType: service`

See `hubspot-webhook-mct/functions/index.js` for working implementation.

## Data Models Identified

From V3/V4 Models section:
- `User` - User entity
- `CourseEntity` - Course information
- `CourseContent` - Course content structure
- `CourseContentItem` - Individual content items
- `CourseModule` - Course modules
- `CategoryEntity` - Category information
- `CourseModuleProgress` - Progress tracking
- `GroupInfo` - Group information

## Next Steps

1. ✅ **Export script created** - `tools/mct-export.mjs` with working auth pattern
2. ✅ **Endpoints verified** - Based on working code in `hubspot-webhook-mct`
3. **Test export** - Run with authentication credentials
4. **Export sample data** - Test with small dataset first
5. **Analyze data structure** - Review exported NDJSON files

