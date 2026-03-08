# MCT API V4 - Complete Endpoint Reference
_Audience: Platform Eng + Data • Owner: Migration Squad • Last verified: 2025-11-07_

**Source:** Swagger UI exploration  
**Date:** 2025-11-07  
**Total Sections:** 1  
**Total Endpoints:** 12  
**Base URL:** `https://learn.skillourfuture.org/api/v4`

---

## Courses

**Endpoints:** 12

### `GET /api/v4/Course/{courseId}/users`

Search users in the course

---

### `GET /api/v4/Courses/{courseId}/Certificate`

Generate and get certificate URL for the course

---

### `PUT /api/v4/Courses/Status`

Update lesson completion status of the course

---

### `GET /api/v4/Courses/{courseId}/Lesson`

Get the course lesson(s) URL

---

### `GET /api/v4/Courses/{courseId}/Content`

Gets course content and relevant metadata for the specified course identifier.

---

### `GET /api/v4/Courses/{courseId}/Metadata`

Get the meta data for the course

---

### `POST /api/v4/courses/{courseId}/users/completeprogress`

Marks a course as complete for the provided list of users

---

### `POST /api/v4/courses/{courseId}/completeprogress`

Marks course complete for user, if course is external course, for now it is just for MS learn courses.

---

### `GET /api/v4/courses/{courseId}/groups`

Get groups for a course

---

### `POST /api/v4/courses/{courseId}/lessons/importprogress`

Import progress of lessons

---

### `POST /api/v4/courses/{courseId}/studyBuddyLearnerBot`

Handles the POST request for studyBuddyLearnerBot endpoint

---

### `PUT /api/v4/courses/{courseId}/lessons/{lessonId}/progress`

Updates the video duration progress for a specific course item at a given progress time. TODO: Remove course ID from the path.

---

## Key Notes

- **V4 is the most limited version** - Only Courses section, no AdminApi, Reports, or other sections
- **Course-focused:** All endpoints are related to course operations
- **Similar to V3:** Most endpoints mirror V3 Courses section
- **No enrollment endpoints:** Unlike V3, V4 doesn't have Reports section for enrollment data

---

**Summary:** V4 is a minimal, course-focused API version with 12 endpoints.
