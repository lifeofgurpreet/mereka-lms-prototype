# MCT API V1 - Complete Endpoint Reference
_Audience: Platform Eng + Data • Owner: Migration Squad • Last verified: 2025-11-07_

**Source:** Swagger UI exploration  
**Date:** 2025-11-07  
**Total Sections:** 33  
**Total Endpoints:** 189  
**Base URL:** `https://learn.skillourfuture.org/api/v1`

---

## AdminApi

**Endpoints:** 10

### `GET /api/v1/admin/globaladministrators`

Get list of organization administrators

---

### `DELETE /api/v1/admin/globaladministrators`

Delete super administrators.

---

### `GET /api/v1/admin/analytics`

Get analytics reports filtered for categories or courses

---

### `GET /api/v1/admin/course/{courseId}/lessonAnalytics`

Get lesson analytics for course

---

### `GET /api/v1/admin/course/{courseId}/quizAnalytics`

Get quiz analytics for course

---

### `GET /api/v1/admin/category/{categoryId}/course/{courseId}/graphAnalytics`

Get analytics graph and course meta analytics for course

---

### `GET /api/v1/admin/course/{courseId}/learnerAnalytics`

Get learner analytics for course

---

### `GET /api/v1/admin/users`

Get paginated list of all users.

---

### `POST /api/v1/organizations/Administrators`

Add super administrators.

---

### `DELETE /api/v1/organizations/Administrators`

Delete super administrators.

---

## Analytics

**Endpoints:** 3

### `GET /api/v1/Analytics/Course/{courseId}/Learner/{userId}`

Get course progress details for a learner

---

### `GET /api/v1/Analytics/Course/{courseId}/Quiz/{quizId}/Learner/{userId}`

Get quiz progress details report for a learner

---

### `GET /api/v1/Analytics/Learner/{userId}/ReportCard`

Get report card for a learner

---

## Bot

**Endpoints:** 1

### `POST /api/v1/qna`

Gets the generated questions and answers for a lesson

---

## Category

**Endpoints:** 10

### `POST /api/v1/Category`

Create a new category Category data is not localized

---

### `PUT /api/v1/Category/{categoryId}`

Update an existing category

---

### `DELETE /api/v1/Category/{categoryId}`

Delete an existing category

---

### `POST /api/v1/Category/{categoryId}/Administrators`

Add category administrators

---

### `DELETE /api/v1/Category/{categoryId}/Administrators`

Remove category administrators.

---

### `DELETE /api/v1/category/{categoryId}/administrator/{adminUserId}`

Remove category administrator.

---

### `POST /api/v1/Category/{categoryId}/Course`

Add a new course under a category

---

### `GET /api/v1/Category/Upload/SAS`

Get SAS token with file upload permission

---

### `POST /api/v1/Category/{categoryId}/Courses`

Bulk upload courses

---

### `GET /api/v1/category/administrators`

Get category administrators

---

## Certificate

**Endpoints:** 7

### `GET /api/v1/Certificate/Templates`

Get all Certificate Templates

---

### `GET /api/v1/Certificate/Template/{templateId}`

Get Certificate Template corresponding to provided identifier

---

### `PUT /api/v1/Certificate/Template/{templateId}`

Update a certificate template

---

### `DELETE /api/v1/Certificate/Template/{templateId}`

Delete a certificate template

---

### `POST /api/v1/Certificate/Template`

Add a new certificate template

---

### `POST /api/v1/Certificate/Template/Preview`

Get preview certificate

---

### `GET /api/v1/Certificates`

Get all certificates for a user

---

## ContentSync

**Endpoints:** 1

### `DELETE /api/v1/offline/synchronize/courses/{courseId}`

Publishes message to IoT Hub to delete course on edge devices.

---

## Courses

**Endpoints:** 15

### `GET /api/v1/Courses`

Get all self and auto-enrolled courses for the user when registration Status is null Get all registered courses for the user based on registration status

---

### `GET /api/v1/Course/{courseId}/users`

Search users in the course

---

### `GET /api/v1/Courses/{courseId}/Certificate`

Generate and get certificate URL for the course

---

### `PUT /api/v1/Courses/Status`

Update lesson completion status of the course

---

### `GET /api/v1/Courses/{courseId}/Lesson`

Get the course lesson(s) URL

---

### `GET /api/v1/Courses/{courseId}/Token`

Get token to access lesson's content

---

### `GET /api/v1/Courses/{courseId}/Metadata`

Get the meta data for the course

---

### `GET /api/v1/course/administrators`

Get the course administrator(s)

---

### `DELETE /api/v1/admin/deleteCourseUserProgress`

Delete progress of a user from a course.

---

### `POST /api/v1/courses/{courseId}/users/completeprogress`

Marks a course as complete for the provided list of users

---

### `POST /api/v1/courses/{courseId}/completeprogress`

Marks course complete for user, if course is external course, for now it is just for MS learn courses.

---

### `GET /api/v1/courses/{courseId}/groups`

Get groups for a course

---

### `POST /api/v1/courses/{courseId}/lessons/importprogress`

Import progress of lessons

---

### `POST /api/v1/courses/{courseId}/studyBuddyLearnerBot`

Handles the POST request for studyBuddyLearnerBot endpoint

---

### `PUT /api/v1/courses/{courseId}/lessons/{lessonId}/progress`

Updates the video duration progress for a specific course item at a given progress time. TODO: Remove course ID from the path.

---

## Deployment

**Endpoints:** 1

### `GET /api/v1/deployment/info`

Get deployment information

---

## EdgeDevice

**Endpoints:** 1

### `GET /api/v1/offline/devices`

Get paginated list of edge devices

---

## EditCourse

**Endpoints:** 24

### `GET /api/v1/EditCourse/{courseId}/uploadsprogress`

Get the upload and encoding status of all video lessons for a course

---

### `POST /api/v1/EditCourse/{courseId}/Lesson`

Add or update lesson to a course

---

### `POST /api/v1/EditCourse/{courseId}/CourseItems`

Bulk upload course items inside an already existing course

---

### `POST /api/v1/EditCourse/{courseId}/KC`

Add or update quiz to a course

---

### `DELETE /api/v1/EditCourse/{courseId}/CourseItem`

Remove lessons or quizes from a course

---

### `POST /api/v1/editCourse/{courseId}/lesson/{lessonId}/textTracks`

Add or update text tracks to a video lesson

---

### `DELETE /api/v1/editCourse/{courseId}/lesson/{lessonId}/textTracks`

Remove the text tracks from a video lesson

---

### `POST /api/v1/EditCourse/{courseId}/KC/{knowledgeCheckId}/Questions`

Add questions to a quiz

---

### `POST /api/v1/EditCourse/{courseId}/Question/{questionId}`

Add or update question to a quiz

---

### `POST /api/v1/EditCourse/Questions`

Import questions from csv

---

### `POST /api/v1/EditCourse/{courseId}/Publish`

Publish a course

---

### `GET /api/v1/EditCourse/{courseId}/content`

Get course item information along with their publish status

---

### `PUT /api/v1/EditCourse/{courseId}/ItemsOrder`

Update course items order

---

### `POST /api/v1/EditCourse/{courseId}/CourseMetadata`

Upload course metadata

---

### `GET /api/v1/EditCourse/{courseId}/ChildCourses`

Get all child courses.

---

### `DELETE /api/v1/EditCourse/{courseId}`

Delete a course

---

### `DELETE /api/v1/EditCourse/{courseId}/Users`

Remove users from course

---

### `POST /api/v1/EditCourse/{courseId}/Administrators`

Add course administrators

---

### `DELETE /api/v1/EditCourse/{courseId}/Administrators`

Remove specified users from list of administrators of a course

---

### `DELETE /api/v1/editCourse/{courseId}/administrator/{adminUserId}`

Remove specified user from list of administrators of a course

---

### `POST /api/v1/courses/{courseId}/summary`

Summarize the contents of provided course

---

### `GET /api/v1/courses/{courseId}/summary`

Get summary of contents for given course

---

### `POST /api/v1/courses/{courseId}/summary/pdf`

Generates PDF on the provided course summaries

---

## Export

**Endpoints:** 1

### `POST /api/v1/export/courses`

Download entire content for the specified courses

---

## ExternalAuthToken

**Endpoints:** 1

### `POST /api/v1/ExternalAuthToken/RefreshToken/{identityProvider}`

Gets a new access token and refresh token pair from the identity provider

---

## ExternalContent

**Endpoints:** 3

### `GET /api/v1/externalContent/contentProviders`

Get list of all content providers.

---

### `GET /api/v1/externalContent/contentProvider/{contentProviderId}/content`

Get external course by content provider Id.

---

### `GET /api/v1/externalContent/contentProvider/{contentProviderId}/search`

Search external course by search term.

---

## GlobalConfig

**Endpoints:** 2

### `GET /api/v1/globalSettings`

Get global config data.

---

### `PUT /api/v1/globalSettings`

Update global settings data.

---

## Group

**Endpoints:** 25

### `GET /api/v1/Groups`

Get the groups belonging to administrator

---

### `POST /api/v1/Groups`

Add the group

---

### `GET /api/v1/Groups/Search`

Get the groups belonging to administrator

---

### `GET /api/v1/Groups/{groupId}/learners`

Get learners performance data for specified group and provide optional search among those learners

---

### `GET /api/v1/groups/{groupId}/courses/{courseId}/learners`

Get learners performance data for specified group and course and provide optional search among those learners

---

### `PUT /api/v1/Groups/{groupId}`

Update the group

---

### `DELETE /api/v1/Groups/{groupId}`

Delete the group

---

### `DELETE /api/v1/Groups/{groupId}/Users`

Remove the users from a group

---

### `POST /api/v1/Groups/{groupId}/Users`

Add users to a group.

---

### `GET /api/v1/Groups/{groupId}/Administrators`

Get the group administrators

---

### `POST /api/v1/Groups/{groupId}/Administrators`

Add the group administrator

---

### `DELETE /api/v1/Groups/{groupId}/Administrators`

Remove administrators from a group

---

### `GET /api/v1/Groups/{groupId}/Courses`

Get the categories and courses Category data is not localized

---

### `POST /api/v1/Groups/{groupId}/Courses`

Add courses to group

---

### `DELETE /api/v1/Groups/{groupId}/Courses`

Remove courses from group

---

### `POST /api/v1/Groups/{groupId}/LearningPathCourses`

Add courses to group

---

### `GET /api/v1/Groups/{groupId}/Rules`

Get the group rules

---

### `POST /api/v1/Groups/{groupId}/Rules`

Update the group rules

---

### `GET /api/v1/Groups/SyncStatus`

Get groups synchronize status

---

### `POST /api/v1/Groups/Sync`

Synchronizes groups for administrator

---

### `GET /api/v1/Groups/{groupId}/Users/SyncStatus`

Get the group users synchronize status

---

### `POST /api/v1/Groups/{groupId}/Users/Sync`

Synchronizes users for a group

---

### `POST /api/v1/Groups/{groupId}/RestrictedCourses`

Adds the courses to restrictedCourseGroup.

---

### `DELETE /api/v1/Groups/{groupId}/RestrictedCourses`

Removes the courses from restrictedCourseGroup and courseGroup.

---

### `GET /api/v1/learningpath/courses`

Get all the learning paths and their courses assignable to the current group.

---

### `GET /api/v1/admin/group/{groupId}/categoriesAndCourses`

Get hierarchical list of categories and courses for the Group Admin

---

## LearningPathAdmin

**Endpoints:** 16

### `GET /api/v1/learningpaths`

Get the list of learning paths for displaying to the administrator.

---

### `POST /api/v1/learningpath`

Add a learning path.

---

### `GET /api/v1/learningpath/{learningPathId}/administrators`

Get the list of Administrators of a learning path.

---

### `POST /api/v1/learningpath/{learningPathId}/administrators`

Add a list of Administrators to a learning path.

---

### `DELETE /api/v1/learningpath/{learningPathId}/administrators`

Remove a list of Administrators of a learning path.

---

### `DELETE /api/v1/learningpath/{learningPathId}/administrator/{adminUserId}`

Remove an Administrator of a learning path.

---

### `PUT /api/v1/learningpath/{learningPathId}/metadata`

Edit metadata of a learning path.

---

### `DELETE /api/v1/learningpath/{learningPathId}`

Delete a learning path.

---

### `GET /api/v1/admin/learningpath/{learningPathId}/courses`

Get Courses of a learning path.

---

### `POST /api/v1/admin/learningpath/{learningPathId}/courses`

Update Courses of a learning path.

---

### `DELETE /api/v1/learningpath/{learningPathId}/users`

Remove a list of users from a learning path.

---

### `GET /api/v1/learningpath/{learningPathId}/users`

Get the users of the Learning Path.

---

### `POST /api/v1/learningpath/{learningPathId}/users`

Assign learning path to users.

---

### `GET /api/v1/learningpaths/{learningPathId}/groups`

Get groups for a learning path

---

### `DELETE /api/v1/learningpath/{learningPathId}/progress`

Delete progress of a user from a learning path

---

### `GET /api/v1/learningpath/{learningPathId}/categoriesAndCourses`

Get hierarchical list of categories and courses for the Learning Path

---

## LearningPathLearner

**Endpoints:** 2

### `GET /api/v1/learner/learningpath/{learningPathId}/courses`

Get Courses of a learning path.

---

### `GET /api/v1/learner/learningpath/{learningPathId}/Certificate`

Generate and get certificate URL for the learning path

---

## Lesson

**Endpoints:** 4

### `GET /api/v1/lessons/{lessonId}/forums`

Get lesson forum comments

---

### `POST /api/v1/lessons/{lessonId}/forums`

Submit lesson forum post

---

### `POST /api/v1/lessons/{lessonId}/sasurl`

Get valid blob URL given an expired blob URL

---

### `POST /api/v1/lessons/{lessonId}/media/sasurl`

Get valid media blob URL given an expired blob URL

---

## ManageUser

**Endpoints:** 3

### `POST /api/v1/offline/manage/addUser`

Add user with a random number and OTP

---

### `POST /api/v1/offline/manage/setPassword`

Allows admin to update user password.

---

### `POST /api/v1/offline/manage/resetPassword`

Allows learners to update their passwords.

---

## ManifestProxy

**Endpoints:** 5

### `GET /api/v1/Manifest/TopLevel`

Get top level HTTP Live Stream (HLS) playlist

---

### `GET /api/v1/Manifest/SecondLevel`

Get second level HTTP Live Stream (HLS) playlist

---

### `GET /api/v1/proxy/{playbackUrl}`

Update HLS manifest to add SAS tokens to fragments

---

### `GET /api/v1/Manifest/storage/{path}`

Gets the blob content from azure storage account.

---

### `GET /api/v1/Manifest/container/{containerName}`

Lists all blobs in the specified container.

---

## Notification

**Endpoints:** 5

### `GET /api/v1/Notifications`

Get all notifications for the current user

---

### `PUT /api/v1/Notifications`

Update the notification status of a particular notification for a user

---

### `GET /api/v1/Notifications/GroupAnnouncement`

Get the group announcements created before a date

---

### `POST /api/v1/Notifications/GroupAnnouncement`

Send the group announcement

---

### `GET /api/v1/Notifications/AsyncJobsProgress`

Get async job statuses by tracking IDs

---

## OfflineEdgeDeviceInfo

**Endpoints:** 2

### `GET /api/v1/space`

Get the space information for the offline Edge device

---

### `GET /api/v1/device/{deviceId}/space`

Get the space information for the offline Edge device

---

## OfflineLog

**Endpoints:** 1

### `GET /api/v1/logs/mct`

Get zip file containing MCT logs

---

## OfflinePendingCourseInfo

**Endpoints:** 1

### `GET /api/v1/device/{deviceId}/syncinfo`

Get details of the pending courses to be synced on the edge device

---

## Organization

**Endpoints:** 6

### `GET /api/v1/organization`

Get all organizations.

---

### `POST /api/v1/organization`

Create an Organization.

---

### `PUT /api/v1/organization/{orgId}`

Update organization.

---

### `DELETE /api/v1/organization/{orgId}`

Delete Organization.

---

### `GET /api/v1/organization/{organizationId}/config`

Get organization data.

---

### `PUT /api/v1/organization/{organizationId}/config`

Update organization data by identifier.

---

## OrganizationAdmin

**Endpoints:** 5

### `GET /api/v1/organizationadministrator`

Get all organization administrators.

---

### `POST /api/v1/organizationadministrator`

Create new Organization Admin.

---

### `PUT /api/v1/organizationadministrator`

Update organization admin.

---

### `DELETE /api/v1/organizationadministrator`

Delete organization Admin.

---

### `GET /api/v1/organizationadministrator/organizations`

Get organizations for current authenticated user.

---

## OTP

**Endpoints:** 2

### `POST /api/v1/otp`

Generate one time password

---

### `POST /api/v1/validate`

Validate one time password

---

## Profile

**Endpoints:** 3

### `POST /api/v1/Profile/Picture`

Update profile picture

---

### `PUT /api/v1/Profile`

Update user profile details

---

### `GET /api/v1/Profile/Role`

Get user role to decide whether to show the user a control to switch between learner and administrator views

---

## Quiz

**Endpoints:** 3

### `POST /api/v1/quizzes/{quizId}/answer`

Submit answers to quiz identified by the quiz id

---

### `POST /api/v1/quizzes/{quizId}/userImages`

Uploads user images for quiz

---

### `POST /api/v1/courses/{courseId}/quiz/importprogress`

Import progress of quizzes

---

## Reports

**Endpoints:** 7

### `GET /api/v1/Reports/Overview/Categories`

Download categories in overview analytics

---

### `GET /api/v1/Reports/Category/{categoryId}/Courses`

Download courses in category analytics

---

### `GET /api/v1/Reports/Course/{courseId}/Lessons`

Download lessons in course analytics

---

### `GET /api/v1/Reports/Course/{courseId}/Quizzes`

Download quizzes in course analytics

---

### `GET /api/v1/Reports/Course/{courseId}/Learners`

Download learners in course analytics

---

### `GET /api/v1/Reports/Learner/{userId}/ReportCard`

Download learner report card data

---

### `GET /api/v1/Reports/Users`

Download user information for administrator.

---

## Search

**Endpoints:** 2

### `GET /api/v1/content`

Get content items i.e. courses, categories and lessons that are most relevant to the provided search term

---

### `GET /api/v1/content/suggest`

Get suggested content item i.e. courses, categories and lesson suggestions that are most relevant to the provided search term

---

## User

**Endpoints:** 15

### `POST /api/v1/users/contact`

Update user's contact.

---

### `GET /api/v1/users`

Get list of users with email address, first name or last name matching the search term.

---

### `DELETE /api/v1/users`

Delete users with the Ids specified in the request body

---

### `POST /api/v1/users`

Add/Update users.

---

### `GET /api/v1/users/progress`

Get progress details for all users

---

### `POST /api/v1/users/progress`

Upload file containing progress details, validate data and import the same

---

### `PUT /api/v1/user/organization`

Update the Organization Identifier for the user.

---

### `GET /api/v1/users/{userId}/groups`

Get groups for the user.

---

### `GET /api/v1/users/{userId}/learningpaths`

Get learning paths for the user.

---

### `POST /api/v1/users/GetByContact`

Fetches details for the user with the given contact details.

---

### `POST /api/v1/users/VerifyByContact`

Fetches if the user with the given contact exists.

---

### `GET /api/v1/users/{contact}/migrated`

Check if the user is migrated

---

### `POST /api/v1/users/migrate`

Migrate user's contact from phone auth to email based

---

### `POST /api/v1/users/migrateContacts`

Migrate user contacts.

---

## UserEnrollment

**Endpoints:** 3

### `DELETE /api/v1/courses/{courseId}/users/{userId}/enrollments`

Endpoint for removing user enrollment from a course

---

### `DELETE /api/v1/learningpaths/{learningPathId}/users/{userId}/enrollments`

Endpoint for removing user enrollment from a learning path

---

### `POST /api/v1/courses/{courseId}/register`

Endpoint for enrolling the calling user to a course

---

## Key Findings

### Enrollment Endpoints Found! ✅

**UserEnrollment section:**
- `DELETE /api/v1/courses/{courseId}/users/{userId}/enrollments` - Remove enrollment from course
- `DELETE /api/v1/learningpaths/{learningPathId}/users/{userId}/enrollments` - Remove enrollment from learning path
- `POST /api/v1/courses/{courseId}/register` - Enroll user to course

**Also found:**
- `GET /api/v1/Course/{courseId}/users` - Search users in the course (shows enrollments!)
- `GET /api/v1/courses/{courseId}/groups` - Get groups for a course
- `GET /api/v1/Groups/{groupId}/learners` - Get learners performance data for group
- `GET /api/v1/groups/{groupId}/courses/{courseId}/learners` - Get learners for group + course

### Certificate Endpoints ✅

- `GET /api/v1/Certificates` - Get all certificates for a user
- `GET /api/v1/Certificate/Templates` - Get certificate templates
- `GET /api/v1/Courses/{courseId}/Certificate` - Generate certificate URL for course
- `GET /api/v1/learner/learningpath/{learningPathId}/Certificate` - Certificate for learning path

### Learning Paths ✅

- `GET /api/v1/learningpaths` - Get all learning paths
- `GET /api/v1/learningpath/{learningPathId}/users` - Get users of learning path
- `POST /api/v1/learningpath/{learningPathId}/users` - Assign learning path to users
- `GET /api/v1/admin/learningpath/{learningPathId}/courses` - Get courses of learning path

---

**Next:** Extract V2, V3, V4 endpoints
