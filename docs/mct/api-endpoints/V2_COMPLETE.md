# MCT API V2 - Complete Endpoint Reference

**Source:** Swagger UI exploration  
**Date:** 2025-11-07  
**Total Sections:** 9  
**Total Endpoints:** 55  
**Base URL:** `https://learn.skillourfuture.org/api/v2`

---

## AdminApi

**Endpoints:** 10

### `GET /api/v2/admin/categoriesAndCourses`

Get hierarchical list of categories and courses that are accessible by the caller.

---

### `GET /api/v2/admin/globaladministrators`

Get list of organization administrators

---

### `POST /api/v2/admin/globaladministrators`

Add super administrators.

---

### `DELETE /api/v2/admin/globaladministrators`

Delete super administrators.

---

### `GET /api/v2/admin/analytics`

Get analytics reports filtered for categories or courses

---

### `GET /api/v2/admin/course/{courseId}/lessonAnalytics`

Get lesson analytics for course

---

### `GET /api/v2/admin/course/{courseId}/quizAnalytics`

Get quiz analytics for course

---

### `GET /api/v2/admin/category/{categoryId}/course/{courseId}/graphAnalytics`

Get analytics graph and course meta analytics for course

---

### `GET /api/v2/admin/course/{courseId}/learnerAnalytics`

Get learner analytics for course

---

### `GET /api/v2/admin/users`

Get paginated list of all users.

---

## Category

**Endpoints:** 9

### `POST /api/v2/Category`

Create a new category The request body has localized category data

---

### `PUT /api/v2/Category/{categoryId}`

Update an existing category

---

### `DELETE /api/v2/Category/{categoryId}`

Delete an existing category

---

### `POST /api/v2/Category/{categoryId}/Administrators`

Add category administrators

---

### `DELETE /api/v2/category/{categoryId}/administrator/{adminUserId}`

Remove category administrator.

---

### `POST /api/v2/Category/{categoryId}/Course`

Add a new course under a category

---

### `GET /api/v2/Category/Upload/SAS`

Get SAS token with file upload permission

---

### `POST /api/v2/Category/{categoryId}/Courses`

Bulk upload courses

---

### `GET /api/v2/category/administrators`

Get category administrators

---

## Courses

**Endpoints:** 15

### `GET /api/v2/Courses`

Get all self and auto-enrolled courses for the user when registration Status is null Get all registered courses for the user based on registration status

---

### `GET /api/v2/Course/{courseId}/users`

Search users in the course

---

### `GET /api/v2/Courses/{courseId}/Certificate`

Generate and get certificate URL for the course

---

### `PUT /api/v2/Courses/Status`

Update lesson completion status of the course

---

### `GET /api/v2/Courses/{courseId}/Lesson`

Get the course lesson(s) URL

---

### `GET /api/v2/Courses/{courseId}/Content`

Get the content of the course

---

### `GET /api/v2/Courses/{courseId}/Metadata`

Get the meta data for the course

---

### `GET /api/v2/Courses/{courseId}/administrators`

Get the course administrator(s)

---

### `DELETE /api/v2/courses/{courseId}/userProgress`

Delete progress of a user from a course. This is the new version of the API "api/v{version:apiVersion}/admin/deleteCourseUserProgress"

---

### `POST /api/v2/courses/{courseId}/users/completeprogress`

Marks a course as complete for the provided list of users

---

### `POST /api/v2/courses/{courseId}/completeprogress`

Marks course complete for user, if course is external course, for now it is just for MS learn courses.

---

### `GET /api/v2/courses/{courseId}/groups`

Get groups for a course

---

### `POST /api/v2/courses/{courseId}/lessons/importprogress`

Import progress of lessons

---

### `POST /api/v2/courses/{courseId}/studyBuddyLearnerBot`

Handles the POST request for studyBuddyLearnerBot endpoint

---

### `PUT /api/v2/courses/{courseId}/lessons/{lessonId}/progress`

Updates the video duration progress for a specific course item at a given progress time. TODO: Remove course ID from the path.

---

## Deployment

**Endpoints:** 1

### `GET /api/v2/deployment/info`

Get deployment information with Seprate App and DB Version

---

## Group

**Endpoints:** 1

### `GET /api/v2/admin/group/{groupId}/categoriesAndCourses`

Get hierarchical list of categories and courses for the Group Admin Category data is localized Changes 1. Returned courses will belong to categories which are in same organizations as the group identified by 'groupId'. 2. In case the deployment type is 'IsMultiOrgDeployment' and 'IsGlobalContentEnabled' content is enabled, response will also contain courses from common organization categories as well. 3. Only super admins, organization admins of the organization the selected group belong to, and group admin of the selected group can call this api.

---

## LearningPathAdmin

**Endpoints:** 4

### `GET /api/v2/learningpaths`

Get the list of learning paths for displaying to the administrator.

---

### `POST /api/v2/learningpath`

Add a learning path.

---

### `GET /api/v2/learningpath/{learningPathId}/administrators`

Get the list of Administrators of a learning path.

---

### `PUT /api/v2/learningpath/{learningPathId}/metadata`

Edit metadata of a learning path.

---

## Notification

**Endpoints:** 2

### `GET /api/v2/Groups/{groupId}/Notifications/GroupAnnouncement`

Get the group announcements created before a date

---

### `POST /api/v2/Groups/{groupId}/Notifications/GroupAnnouncement`

Send the group announcement

---

## Profile

**Endpoints:** 11

### `POST /api/v2/Profile/Picture`

Update profile picture

---

### `GET /api/v2/Profile`

Get user profile details

---

### `GET /api/v2/Profile/Role`

Get user role to decide whether to show the user a control to switch between learner and administrator views

---

### `GET /api/v2/Organizations/{organizationId}/UserProfiles/{userId}`

Gets user profile. User profile => List of ProfileFiledUnits or ProfileFields + their respective values.

---

### `POST /api/v2/Organizations/{organizationId}/UserProfiles/{userId}`

Update user profile. User profile => List of ProfileFiledUnits or ProfileFields + their respective values.

---

### `GET /api/v2/Organizations/{organizationId}/CustomProfileFields`

List custom ProfileFields.

---

### `POST /api/v2/Organizations/{organizationId}/CustomProfileFields`

Update custom profile.

---

### `GET /api/v2/Organizations/{organizationId}/CustomProfileFields/{mappingId}/Options`

List custom ProfileFields options.

---

### `GET /api/v2/Organizations/{organizationId}/CustomProfileFields/{mappingId}/OptionsFile`

Return custom profile field options values in a csv file.

---

### `GET /api/v2/Organizations/{organizationId}/CustomProfileFields/{mappingId}/Search`

Search custom ProfileFields options for a given term.

---

### `GET /api/v2/TextfieldDataType/{dataType}/StandardFormat`

Get data type standard formats and their validation regex.

---

## Reports

**Endpoints:** 2

### `GET /api/v2/Reports/Users`

Download user information for administrator.

---

### `POST /api/v2/Reports/SelectedUsers`

Download list of selected user in an organization.

---

## Key Differences from V1

1. **Profile Management:** V2 has extensive profile management endpoints (11 endpoints vs 3 in V1)
2. **UserProfiles:** `POST /api/v2/Organizations/{organizationId}/UserProfiles/{userId}` - This is the endpoint used in `hubspot-webhook-mct` ✅
3. **Custom Profile Fields:** V2 supports custom profile fields management
4. **Categories:** V2 supports localized category data
5. **Course Content:** `GET /api/v2/Courses/{courseId}/Content` - Direct content endpoint
6. **Fewer Sections:** V2 has 9 sections vs 33 in V1 (more focused)

---

**Next:** V3 API endpoints

