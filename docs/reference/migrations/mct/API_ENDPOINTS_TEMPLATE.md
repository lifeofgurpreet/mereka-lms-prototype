# MCT API Endpoints - Swagger Documentation Template
_Audience: Platform Eng + Data • Owner: Migration Squad • Last verified: 2025-08-31_

**Instructions:** Fill in endpoints as you explore Swagger UI for each version.

---

## V1 API Endpoints

### User Management
- [ ] `GET /api/v1/users` - 
- [ ] `GET /api/v1/users?searchTerm={email}` - ✅ Verified
- [ ] `POST /api/v1/users?orgId={orgId}` - ✅ Verified
- [ ] `PUT /api/v1/users/{userId}` - 
- [ ] `DELETE /api/v1/users/{userId}` - 
- [ ] `GET /api/v1/ManageUser` - 
- [ ] `GET /api/v1/Reports/Users` - ✅ Verified (CSV)

### Organizations
- [ ] `GET /api/v1/organization` - ✅ Verified
- [ ] `GET /api/v1/organization/{orgId}` - 
- [ ] `POST /api/v1/organization` - 
- [ ] `PUT /api/v1/organization/{orgId}` - 
- [ ] `DELETE /api/v1/organization/{orgId}` - 

### Categories (Actually = Courses)
- [ ] `GET /api/v1/Category` - ✅ Verified
- [ ] `GET /api/v1/Category/{categoryId}` - 
- [ ] `POST /api/v1/Category` - 
- [ ] `PUT /api/v1/Category/{categoryId}` - 
- [ ] `DELETE /api/v1/Category/{categoryId}` - 

### Courses (Actually = Modules)
- [ ] `GET /api/v1/Courses` - ✅ Verified
- [ ] `GET /api/v1/Courses/{courseId}` - 
- [ ] `POST /api/v1/Courses` - 
- [ ] `PUT /api/v1/Courses/{courseId}` - 
- [ ] `DELETE /api/v1/Courses/{courseId}` - 

### Groups (Learning Pathways)
- [ ] `GET /api/v1/Groups` - ✅ Verified
- [ ] `GET /api/v1/Group/{groupId}` - 
- [ ] `POST /api/v1/Group` - 
- [ ] `PUT /api/v1/Group/{groupId}` - 
- [ ] `DELETE /api/v1/Group/{groupId}` - 

### Certificates
- [ ] `GET /api/v1/Certificates` - ✅ Verified (empty)
- [ ] `GET /api/v1/Certificate/{certificateId}` - 
- [ ] `POST /api/v1/Certificate` - 
- [ ] `PUT /api/v1/Certificate/{certificateId}` - 
- [ ] `DELETE /api/v1/Certificate/{certificateId}` - 

### Enrollments
- [ ] `GET /api/v1/UserEnrollment` - ❌ 404
- [ ] `GET /api/v1/UserEnrollments` - 
- [ ] `GET /api/v1/Enrollment` - 
- [ ] `POST /api/v1/UserEnrollment` - 
- [ ] `PUT /api/v1/UserEnrollment/{enrollmentId}` - 
- [ ] `DELETE /api/v1/UserEnrollment/{enrollmentId}` - 

### Reports
- [ ] `GET /api/v1/Reports/Users` - ✅ Verified (CSV)
- [ ] `GET /api/v1/Reports/Courses` - 
- [ ] `GET /api/v1/Reports/Enrollments` - 
- [ ] `GET /api/v1/Reports/Certificates` - 
- [ ] `GET /api/v1/Reports/Groups` - 

### Lessons
- [ ] `GET /api/v1/Lesson` - 
- [ ] `GET /api/v1/Lesson/{lessonId}` - 
- [ ] `POST /api/v1/Lesson` - 
- [ ] `PUT /api/v1/Lesson/{lessonId}` - 
- [ ] `DELETE /api/v1/Lesson/{lessonId}` - 

### Analytics
- [ ] `GET /api/v1/Analytics` - 
- [ ] `GET /api/v1/Analytics/Users` - 
- [ ] `GET /api/v1/Analytics/Courses` - 
- [ ] `GET /api/v1/Analytics/Enrollments` - 

### Export
- [ ] `GET /api/v1/Export` - 
- [ ] `POST /api/v1/Export` - 

### Other V1 Endpoints
- [ ] Add any other endpoints you find...

---

## V2 API Endpoints

### User Profiles
- [ ] `POST /api/v2/Organizations/{orgId}/UserProfiles/{userId}` - ✅ Verified
- [ ] `GET /api/v2/Organizations/{orgId}/UserProfiles/{userId}` - 
- [ ] `PUT /api/v2/Organizations/{orgId}/UserProfiles/{userId}` - 
- [ ] `DELETE /api/v2/Organizations/{orgId}/UserProfiles/{userId}` - 

### Other V2 Endpoints
- [ ] Add any other endpoints you find...

---

## V3 API Endpoints

### Admin API
- [ ] `GET /api/v3/admin/categoriesAndCourses` - ✅ Verified
- [ ] `GET /api/v3/admin/...` - Add other admin endpoints

### Courses
- [ ] `GET /api/v3/Courses` - 
- [ ] `GET /api/v3/Courses/{courseId}` - 
- [ ] `GET /api/v3/Courses/{courseId}/Content` - ✅ Verified
- [ ] `GET /api/v3/Courses/{courseId}/Metadata` - ✅ Verified
- [ ] `GET /api/v3/Courses/{courseId}/Lesson` - 
- [ ] `GET /api/v3/Courses/{courseId}/Certificate` - ✅ Verified
- [ ] `POST /api/v3/Courses/{courseId}/users/completeprogress` - 
- [ ] `PUT /api/v3/courses/{courseId}/lessons/{lessonId}/progress` - 

### Reports
- [ ] `GET /api/v3/Reports/Users` - ✅ Verified (ZIP)
- [ ] `GET /api/v3/organization/{orgId}/reports/users` - 
- [ ] `GET /api/v3/course/{courseId}/Reports/Users` - 

### Other V3 Endpoints
- [ ] Add any other endpoints you find...

---

## V4 API Endpoints

### Courses
- [ ] `GET /api/v4/Courses` - 
- [ ] `GET /api/v4/Courses/{courseId}` - 
- [ ] Add other V4 endpoints...

---

## Documentation Format

For each endpoint, document:

```markdown
### `METHOD /api/vX/path`

**Summary:** Brief description

**Parameters:**
- `param1` (query/path/body): Description [Required/Optional]

**Request Body:** (if applicable)
```json
{
  "field": "example"
}
```

**Response:** (example)
```json
{
  "field": "value"
}
```

**Notes:**
- Any special behavior
- Rate limits
- Authentication requirements
```

---

## Quick Reference

**Base URL:** `https://learn.skillourfuture.org`

**Authentication:**
- Header: `Authorization: Bearer <token>`
- Header: `ClientType: service`

**Response Formats:**
- JSON (most endpoints)
- CSV (`/api/v1/Reports/Users`)
- ZIP (`/api/v3/Reports/Users`)

**Pagination:**
- Parameters: `page`, `pageSize`
- Default: `pageSize=100`

---

**Status:** Template ready - Fill in as you explore Swagger UI
