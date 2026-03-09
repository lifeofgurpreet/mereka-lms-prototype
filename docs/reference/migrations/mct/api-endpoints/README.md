# MCT API - Complete Reference Summary
_Audience: Platform Eng + Data • Owner: Migration Squad • Last verified: 2026-03-06 • Status: canonical_

**Date:** 2025-11-07  
**Source:** Swagger UI exploration

---

## API Version Comparison

| Version | Sections | Endpoints | Focus |
|---------|----------|-----------|-------|
| **V1** | 33 | 189 | Most comprehensive - all features |
| **V2** | 9 | 55 | Profile management, localized data |
| **V3** | 3 | 18 | Course content, reports, hierarchical data |
| **V4** | 1 | 12 | Minimal - course operations only |

**Total Unique Endpoints:** ~274 (with overlaps)

---

## Key Endpoints by Category

### Enrollment Data Sources ✅

**V1:**
- `GET /api/v1/Course/{courseId}/users` - Search users in course
- `GET /api/v1/courses/{courseId}/groups` - Get groups for course
- `GET /api/v1/Groups/{groupId}/learners` - Get learners for group
- `GET /api/v1/groups/{groupId}/courses/{courseId}/learners` - Learners for group + course

**V3:**
- `GET /api/v3/Course/{courseId}/users` - Search users in course ✅
- `GET /api/v3/course/{courseId}/Reports/Users` - **Course-specific user report** ✅
- `GET /api/v3/group/{groupId}/reports/users` - Group-specific user report ✅
- `GET /api/v3/organization/{orgId}/reports/users` - Organization user report ✅

**V4:**
- `GET /api/v4/Course/{courseId}/users` - Search users in course

**Recommendation:** Use `GET /api/v3/course/{courseId}/Reports/Users` for course enrollments!

---

### User Data

**V1:**
- `GET /api/v1/Reports/Users` - Download user information (CSV) ✅
- `GET /api/v1/admin/users` - Paginated list of all users
- `GET /api/v1/users` - Search users (requires searchTerm)

**V2:**
- `GET /api/v2/Reports/Users` - Download user information ✅
- `POST /api/v2/Reports/SelectedUsers` - Download selected users
- `GET /api/v2/Organizations/{organizationId}/UserProfiles/{userId}` - Get user profile ✅
- `POST /api/v2/Organizations/{organizationId}/UserProfiles/{userId}` - Update user profile ✅

**V3:**
- `GET /api/v3/Reports/Users` - Download user information ✅

---

### Course Content

**V1:**
- `GET /api/v1/Courses` - Get all courses (hierarchical)
- `GET /api/v1/Courses/{courseId}/Metadata` - Get course metadata

**V2:**
- `GET /api/v2/Courses/{courseId}/Content` - Get course content ✅
- `GET /api/v2/Courses/{courseId}/Metadata` - Get course metadata

**V3:**
- `GET /api/v3/admin/categoriesAndCourses` - Hierarchical categories and courses ✅
- `GET /api/v3/Courses/{courseId}/Content` - Get course content ✅
- `GET /api/v3/Courses/{courseId}/Metadata` - Get course metadata

**V4:**
- `GET /api/v4/Courses/{courseId}/Content` - Get course content ✅
- `GET /api/v4/Courses/{courseId}/Metadata` - Get course metadata

---

### Certificates

**V1:**
- `GET /api/v1/Certificates` - Get all certificates for a user
- `GET /api/v1/Certificate/Templates` - Get certificate templates
- `GET /api/v1/Courses/{courseId}/Certificate` - Generate certificate for course ✅

**V2:**
- `GET /api/v2/Courses/{courseId}/Certificate` - Generate certificate for course ✅

**V3:**
- `GET /api/v3/Courses/{courseId}/Certificate` - Generate certificate for course ✅

**V4:**
- `GET /api/v4/Courses/{courseId}/Certificate` - Generate certificate for course ✅

---

### Groups (Learning Pathways)

**V1:**
- `GET /api/v1/Groups` - Get groups belonging to administrator ✅
- `GET /api/v1/Groups/{groupId}/Rules` - Get group rules ✅
- `GET /api/v1/Groups/{groupId}/Courses` - Get categories and courses for group
- `GET /api/v1/learningpaths` - Get learning paths ✅
- `GET /api/v1/learningpath/{learningPathId}/users` - Get users of learning path ✅

**V2:**
- `GET /api/v2/admin/group/{groupId}/categoriesAndCourses` - Hierarchical data for group admin

**V3:**
- `GET /api/v3/courses/{courseId}/groups` - Get groups for course ✅

**V4:**
- `GET /api/v4/courses/{courseId}/groups` - Get groups for course ✅

---

## Migration Strategy Recommendations

### For Export Script (`mct-export.mjs`)

1. **Users:** Use `GET /api/v1/Reports/Users` (CSV) or `GET /api/v3/Reports/Users`
2. **Organizations:** Use `GET /api/v1/organization`
3. **Categories:** Use `GET /api/v1/Category` or `GET /api/v3/admin/categoriesAndCourses`
4. **Courses:** Use `GET /api/v1/Courses` (hierarchical) + `GET /api/v3/Courses/{courseId}/Content` for details
5. **Groups:** Use `GET /api/v1/Groups` + `GET /api/v1/Groups/{groupId}/Rules`
6. **Certificates:** Use `GET /api/v1/Certificates` + course-level `GET /api/v3/Courses/{courseId}/Certificate`
7. **Enrollments:** Use `GET /api/v3/course/{courseId}/Reports/Users` for each course ✅

---

## Documentation Files

- [V1_COMPLETE.md](V1_COMPLETE.md) - 189 endpoints across 33 sections
- [V2_COMPLETE.md](V2_COMPLETE.md) - 55 endpoints across 9 sections
- [V3_COMPLETE.md](V3_COMPLETE.md) - 18 endpoints across 3 sections
- [V4_COMPLETE.md](V4_COMPLETE.md) - 12 endpoints across 1 section

---

## Next Steps

1. ✅ Documented all V1 endpoints
2. ✅ Documented all V2 endpoints
3. ✅ Documented all V3 endpoints
4. ✅ Documented all V4 endpoints
5. ⏭️ Update export script to use correct enrollment endpoints
6. ⏭️ Test enrollment data extraction
