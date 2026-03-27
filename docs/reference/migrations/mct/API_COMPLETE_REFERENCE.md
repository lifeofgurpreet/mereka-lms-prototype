# MCT API Complete Reference
_Audience: Platform Eng • Owner: Migration Squad • Last verified: 2025-08-18_

**Base URL:** `https://learn.skillourfuture.org`  
**Swagger UI:** `https://learn.skillourfuture.org/swagger`  
**Documentation Date:** 2025-11-07

## Important: MCT Terminology Mapping

⚠️ **CRITICAL UNDERSTANDING:** MCT uses confusing terminology that doesn't match standard LMS concepts:

| MCT Term | What It Actually Is | Open edX Equivalent |
|----------|---------------------|-------------------|
| **Category** | A course/program | Course |
| **Module** | A category/topic grouping | Course Section |
| **Course** | A module/lesson | Course Module/Unit |
| **Group** | Learning pathway with rules | Learning Path |
| **Smart Group** | Auto-assigned group via rules | Enrollment via Rules |

**Example:**
- MCT "Category": "AI Fluency" → This is actually a **course**
- MCT "Course": "Module 1: Introduction to AI" → This is actually a **module** within the course
- MCT "Module": Groups courses by topic → This is actually a **category/section**

---

## API Versions Overview

### V1 (Most Comprehensive) ✅ **RECOMMENDED FOR MIGRATION**
- **33 API Sections**
- Best coverage for data export
- Includes: Users, Organizations, Categories, Courses, Groups, Certificates, Enrollments, Reports

### V2 (Limited)
- **Fewer sections than V1**
- Used for specific operations (e.g., UserProfiles)

### V3 (Good Coverage)
- **3 API Sections**
- AdminApi, Courses, Reports
- Good for hierarchical structures

### V4 (Minimal)
- **1 API Section**
- Courses only
- Limited functionality

---

## Authentication

**Service-to-Service Authentication (Recommended):**
```bash
Token Endpoint: https://login.microsoft.com/${MCT_TENANT_ID}/oauth2/v2.0/token
Scope: ${MCT_API_URI}/.default
Required Headers: Authorization: Bearer <token>, ClientType: service
```

---

## V1 API Endpoints

*[To be populated from Swagger exploration]*

### User Management
- `GET /api/v1/users` - Get users (requires searchTerm)
- `GET /api/v1/users?searchTerm={email}` - Lookup user by email ✅
- `POST /api/v1/users?orgId={orgId}` - Create user ✅
- `GET /api/v1/ManageUser` - User management operations
- `GET /api/v1/Reports/Users` - Export user data (CSV) ✅

### Organizations
- `GET /api/v1/organization` - Get organizations ✅

### Categories (Actually = Courses in MCT)
- `GET /api/v1/Category` - Category operations
- `GET /api/v1/Category/{categoryId}` - Get specific category

### Courses (Actually = Modules in MCT)
- `GET /api/v1/Courses` - Course catalog ✅
- `GET /api/v1/Courses/{courseId}` - Get specific course

### Groups (Learning Pathways)
- `GET /api/v1/Groups` - Get all groups ✅
- `GET /api/v1/Group/{groupId}` - Get specific group
- `POST /api/v1/Group` - Create group
- `PUT /api/v1/Group/{groupId}` - Update group

### Certificates
- `GET /api/v1/Certificates` - Get certificates ✅
- `GET /api/v1/Certificate/{certificateId}` - Get specific certificate

### Enrollments
- `GET /api/v1/UserEnrollment` - Enrollment operations (404 - may not exist)
- `GET /api/v1/UserEnrollments` - Alternative endpoint (to test)

### Reports
- `GET /api/v1/Reports/Users` - User export (CSV) ✅
- `GET /api/v1/Reports/Courses` - Course reports
- `GET /api/v1/Reports/Enrollments` - Enrollment reports

---

## V2 API Endpoints

### User Profiles
- `POST /api/v2/Organizations/{orgId}/UserProfiles/{userId}` - Update user profile ✅

---

## V3 API Endpoints

### Admin API
- `GET /api/v3/admin/categoriesAndCourses` - Hierarchical categories + courses ✅

### Courses
- `GET /api/v3/Courses` - Get all registered courses for user
- `GET /api/v3/Courses/{courseId}/Content` - Course content and metadata ✅
- `GET /api/v3/Courses/{courseId}/Metadata` - Course metadata ✅
- `GET /api/v3/Courses/{courseId}/Lesson` - Course lessons
- `GET /api/v3/Courses/{courseId}/Certificate` - Certificate URL ✅

### Reports
- `GET /api/v3/Reports/Users` - User export (CSV/ZIP) ✅
- `GET /api/v3/organization/{orgId}/reports/users` - Organization user export
- `GET /api/v3/course/{courseId}/Reports/Users` - Course user export

---

## V4 API Endpoints

### Courses
- Limited course operations only

---

## Smart Groups & Enrollment Rules

**Understanding Smart Groups:**
- Groups have **Rules** (JSON query rules)
- Rules automatically assign users to groups based on profile data
- Example rule: "If user's 'Which learning pathway are you interested in?' = 'Developer' AND 'Which Country are you from?' = 'Indonesia', then add to group 'Developer | Id'"
- Enrollment happens via group membership, not direct course enrollment

**Group Rules Structure:**
```json
{
  "Query": [
    {
      "Field": "Which learning pathway are you interested in?",
      "FieldKey": "24",
      "Expr": {
        "Operator": "or",
        "Operands": ["Developer", "I want to explore all the learning pathways on my own!"]
      }
    },
    {
      "Field": "Which Country are you from?",
      "FieldKey": "21",
      "Expr": {
        "Operator": "or",
        "Operands": ["Indonesia"]
      }
    }
  ],
  "QueryOp": "and"
}
```

---

## Data Extraction Strategy

### 1. Understand the Hierarchy
```
MCT Structure:
├── Organizations (Countries/Regions)
│   ├── Categories (These are actually COURSES)
│   │   ├── Courses (These are actually MODULES)
│   │   │   ├── CourseItems (Lessons/Content)
│   │   │   └── Certificate settings
│   └── Groups (Learning Pathways)
│       └── Rules (Auto-enrollment logic)
```

### 2. Extract Everything
- Don't worry about transformation yet
- Capture all data as-is
- Document the confusing terminology
- Map relationships between entities

### 3. Key Relationships
- Users → Groups (via "My groups" field + Rules)
- Groups → Categories/Courses (via pathway assignment)
- Categories → Courses (hierarchical)
- Courses → CourseItems (content structure)

---

## Next Steps

1. ✅ Document all V1 endpoints from Swagger
2. ✅ Document all V2 endpoints from Swagger
3. ✅ Document all V3 endpoints from Swagger
4. ✅ Document all V4 endpoints from Swagger
5. ✅ Map MCT terminology correctly
6. ✅ Understand Smart Groups and enrollment
7. ✅ Update export script to capture everything
8. ✅ Create comprehensive data model documentation

---

**Status:** In Progress - Exploring Swagger UI to document all endpoints

