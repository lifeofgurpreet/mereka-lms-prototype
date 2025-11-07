# MCT API V3 - Complete Endpoint Reference

**Source:** Swagger UI exploration  
**Date:** 2025-11-07  
**Total Sections:** 3  
**Total Endpoints:** 18  
**Base URL:** `https://learn.skillourfuture.org/api/v3`

---

## AdminApi

**Endpoints:** 1

### `GET /api/v3/admin/categoriesAndCourses`

Get hierarchical list of categories and courses that are accessible by the caller Category data is localized

---

## Courses

**Endpoints:** 13

### `GET /api/v3/Courses`

Get all registered courses for the user

---

### `GET /api/v3/Course/{courseId}/users`

Search users in the course

---

### `GET /api/v3/Courses/{courseId}/Certificate`

Generate and get certificate URL for the course

---

### `PUT /api/v3/Courses/Status`

Update lesson completion status of the course

---

### `GET /api/v3/Courses/{courseId}/Lesson`

Get the course lesson(s) URL

---

### `GET /api/v3/Courses/{courseId}/Content`

Gets course content and relevant metadata for the specified course identifier.

---

### `GET /api/v3/Courses/{courseId}/Metadata`

Get the meta data for the course

---

### `POST /api/v3/courses/{courseId}/users/completeprogress`

Marks a course as complete for the provided list of users

---

### `POST /api/v3/courses/{courseId}/completeprogress`

Marks course complete for user, if course is external course, for now it is just for MS learn courses.

---

### `GET /api/v3/courses/{courseId}/groups`

Get groups for a course

---

### `POST /api/v3/courses/{courseId}/lessons/importprogress`

Import progress of lessons

---

### `POST /api/v3/courses/{courseId}/studyBuddyLearnerBot`

Handles the POST request for studyBuddyLearnerBot endpoint

---

### `PUT /api/v3/courses/{courseId}/lessons/{lessonId}/progress`

Updates the video duration progress for a specific course item at a given progress time. TODO: Remove course ID from the path.

---

## Reports

**Endpoints:** 4

### `GET /api/v3/organization/{orgId}/reports/users`

Download user information for administrator.

---

### `GET /api/v3/group/{groupId}/reports/users`

Download user information for administrator.

---

### `GET /api/v3/course/{courseId}/Reports/Users`

Download user information for administrator.

---

### `GET /api/v3/Reports/Users`

Download user information for administrator.

---

## Key Findings

### Enrollment Data Sources ✅

**Found multiple ways to get enrollment data:**

1. **Course-specific user reports:**
   - `GET /api/v3/course/{courseId}/Reports/Users` - Users enrolled in specific course ✅
   - `GET /api/v3/Course/{courseId}/users` - Search users in the course ✅

2. **Group-specific user reports:**
   - `GET /api/v3/group/{groupId}/reports/users` - Users in specific group ✅
   - `GET /api/v3/courses/{courseId}/groups` - Groups for a course ✅

3. **Organization-specific user reports:**
   - `GET /api/v3/organization/{orgId}/reports/users` - Users in organization ✅

**Strategy:** Use course-specific reports to get enrollments per course!

---

**Next:** V4 API endpoints

