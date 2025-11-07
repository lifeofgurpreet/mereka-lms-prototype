# MCT Data Model & Terminology - Complete Understanding

**Critical:** MCT uses confusing terminology that doesn't match standard LMS concepts. This document maps the actual structure.

---

## ⚠️ TERMINOLOGY MAPPING (CRITICAL)

| MCT Term | What It Actually Is | Standard LMS Term | Open edX Equivalent |
|----------|-------------------|-------------------|---------------------|
| **Category** | A full course/program | Course | Course |
| **Course** | A module/unit within a category | Module/Unit | Course Section/Unit |
| **Module** | A grouping/topic (rarely used) | Category/Topic | Course Section |
| **Group** | Learning pathway with auto-enrollment rules | Learning Path | Learning Path |
| **Smart Group** | Group with rules that auto-assign users | Enrollment Rules | Enrollment via Rules |
| **CourseItem** | Individual lesson/content item | Lesson/Content | XBlock/Component |
| **Organization** | Country/Region/Institution | Organization | Organization |

### Example Structure:

```
MCT Structure:
├── Organization: "Indonesia" (orgId: 6)
│   ├── Category: "AI Fluency" (CategoryId: 24) ← THIS IS ACTUALLY A COURSE
│   │   ├── Course: "Module 1: Introduction to AI" (ProductId: 279) ← THIS IS A MODULE
│   │   │   ├── CourseItem: "What is artificial intelligence?" (Lesson - Video)
│   │   │   ├── CourseItem: "Common AI Subsets" (Lesson - Video)
│   │   │   ├── CourseItem: "Lesson Plan" (Lesson - PDF)
│   │   │   └── CourseItem: Certificate (if enabled)
│   │   └── Course: "Nhập môn 1: Artificial Intelligence" (ProductId: 281)
│   └── Group: "Developer | Id" (GroupId: 15) ← LEARNING PATHWAY
│       └── Rules: Auto-assign users based on profile data
```

---

## Data Structure Analysis

### 1. Organizations (46 records)

**Endpoint:** `GET /api/v1/organization`

**Structure:**
```json
{
  "id": 6,
  "name": "Indonesia",
  "description": null
}
```

**Purpose:** Countries/regions/institutions that users belong to.

---

### 2. Categories (1 hierarchical record)

**Endpoint:** `GET /api/v3/admin/categoriesAndCourses` (V3) or `GET /api/v1/Category` (V1)

**⚠️ IMPORTANT:** In MCT, "Category" = **COURSE** in standard terminology.

**Structure:**
```json
{
  "categories": [
    {
      "CategoryId": 24,
      "CategoryName": "AI Fluency",
      "CategoryDescription": null,
      "CategoryImage": "",
      "Courses": [
        {
          "ProductId": 279,
          "CourseName": "Module 1: Introduction to AI",
          "ContentLanguage": "EN-US",
          "CourseDescription": "...",
          "CourseImage": "...",
          "IsRegistered": false
        }
      ]
    }
  ]
}
```

**Key Fields:**
- `CategoryId` - Unique identifier for the category (which is actually a course)
- `CategoryName` - Name of the category/course
- `Courses` - Array of modules/units within this category

---

### 3. Courses (14 category records → 80 unique courses)

**Endpoint:** `GET /api/v1/Courses` or `GET /api/v3/Courses`

**⚠️ IMPORTANT:** In MCT, "Course" = **MODULE/UNIT** in standard terminology.

**Structure (from categories):**
```json
{
  "CategoryId": 24,
  "CategoryName": "AI Fluency",
  "Courses": [
    {
      "ProductId": 279,  // ← Use this for content fetching
      "CourseName": "Module 1: Introduction to AI",
      "ContentLanguage": "EN-US",
      "CourseDescription": "...",
      "CourseImage": "...",
      "IsRegistered": false,
      "CompletionPercentage": 0,
      "CourseItemCount": 0
    }
  ]
}
```

**Key Fields:**
- `ProductId` - **Use this** to fetch course content (not `courseId`)
- `CourseName` - Name of the module/unit
- `ContentLanguage` - Language code (EN-US, VI-VN, ID-ID, etc.)
- `ParentCourseId` - Sometimes present, links to parent course

---

### 4. Course Content (160 records)

**Endpoint:** `GET /api/v3/Courses/{ProductId}/Content`

**Structure:**
```json
{
  "courseId": 279,
  "categoryId": 24,
  "categoryName": "AI Fluency",
  "CourseItems": [
    {
      "CourseItemId": 2304,
      "ItemType": "Lesson",
      "DisplayOrder": 1,
      "Data": {
        "Id": 2257,
        "Title": "What is artificial intelligence?",
        "FileType": "Video",
        "DownloadUrl": "...",
        "PlaybackUrl": "...",
        "VideoTextTracks": "...",  // Subtitles/captions
        "ThumbnailUrl": "...",
        "Uuid": "..."
      },
      "CompletionPercentage": 0,
      "IsPublished": true,
      "VideoProgressDuration": 0,
      "Uuid": "..."
    },
    {
      "CourseItemId": 0,
      "ItemType": "Certificate",
      "DisplayOrder": 0,
      "Data": {
        "Availability": "CompletionStatus",
        "URL": null
      }
    }
  ],
  "courseName": "Module 1: Introduction to AI",
  "courseDescription": "...",
  "LearningFlowType": true,
  "IsCertificateEnabled": false
}
```

**CourseItem Types:**
- `Lesson` - Individual content items (videos, PDFs, etc.)
- `Certificate` - Certificate item (if course has certificates enabled)

**Data.FileType:**
- `Video` - Video content with playback URLs
- `pdf` - PDF documents
- Other types may exist

---

### 5. Groups / Learning Pathways (26 records)

**Endpoint:** `GET /api/v1/Groups`

**⚠️ IMPORTANT:** Groups are learning pathways with auto-enrollment rules.

**Structure:**
```json
{
  "GroupId": 15,
  "GroupName": "Developer | Id",
  "GroupDescription": null,
  "NumberOfUsers": 0,
  "GroupType": "Default",
  "Rules": "{\"Query\":[{\"Field\":\"Which learning pathway are you interested in?\",\"FieldKey\":\"24\",\"Expr\":{\"Operator\":\"or\",\"Operands\":[\"Developer\",\"I want to explore all the learning pathways on my own!\"]}},{\"Field\":\"Which Country are you from?\",\"FieldKey\":\"21\",\"Expr\":{\"Operator\":\"or\",\"Operands\":[\"Indonesia\"]}}],\"QueryOp\":\"and\"}",
  "RulesObj": null,
  "OrganizationId": 6,
  "OrganizationName": "Indonesia"
}
```

**Rules Structure (parsed):**
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

**How Enrollment Works:**
1. User fills out profile form with fields like "Which learning pathway are you interested in?"
2. Groups have Rules that query user profile data
3. If user matches Rules, they're automatically added to the Group
4. Groups may grant access to specific Categories/Courses

**Group Naming Pattern:**
- `"{Pathway} | {CountryCode}"` - e.g., "Developer | Id" (Indonesia)
- `"{Pathway} | My"` - e.g., "Developer | My" (Malaysia)
- Country-based: "Vietnam", "Philippines"
- University-based: "[IDN] Universitas Sulawesi Barat"
- Pathway-based: "Green Jobs Pathway", "Speak with Impact"

---

### 6. Users (68,784 records)

**Endpoint:** `GET /api/v1/Reports/Users` (CSV format)

**Structure (parsed from CSV):**
```json
{
  "Contact": "user@example.com",
  "First Name": "John",
  "Last Name": "Doe",
  "My groups": "Developer | Id;Data Analyst | Id",  // ← Groups user belongs to
  "Nickname": "Johnny",
  "When were you born?": "15/01/2000",
  "Gender": "Man",
  "Which Country are you from?": "Indonesia",
  "Which learning pathway are you interested in?": "Developer;Data Analyst",
  "Consent": "true",
  "Source": "Email",
  "Created Date (Hubspot)": "05/01/2025 05:56:42",
  "University": "Universitas Indonesia",
  "Referral Partner": "Biji Biji"
}
```

**Key Fields:**
- `My groups` - Semicolon-separated list of group names user belongs to
- `Which learning pathway are you interested in?` - Used by Group Rules for auto-enrollment
- `Which Country are you from?` - Used by Group Rules
- Profile fields are stored as form field names (not normalized)

**Enrollment Relationship:**
- Users are enrolled via **Groups**, not direct course enrollment
- `My groups` field shows which learning pathways user belongs to
- Groups have Rules that auto-assign users based on profile data

---

### 7. Course Metadata (160 records)

**Endpoint:** `GET /api/v3/Courses/{ProductId}/Metadata`

**Structure:**
```json
{
  "courseId": 279,
  "categoryId": 24,
  "categoryName": "AI Fluency",
  "CourseItems": ["What is artificial intelligence?", "Common AI Subsets", ...],
  "ImportContentType": 3,
  "ImportContentURL": "",
  "CourseName": "Module 1: Introduction to AI",
  "CourseDescription": "...",
  "ProductId": 279,
  "CourseImage": "...",
  "IsRegistered": false,
  "FeedbackFormURL": null
}
```

---

## Enrollment Model

**⚠️ CRITICAL UNDERSTANDING:**

MCT doesn't have traditional "enrollments" table. Instead:

1. **Users** belong to **Groups** (via `My groups` field)
2. **Groups** have **Rules** that auto-assign users based on profile data
3. **Groups** may grant access to **Categories** (courses) or **Courses** (modules)
4. Enrollment happens through group membership, not direct course enrollment

**To find enrollments:**
1. Check user's `My groups` field
2. Match groups to categories/courses they grant access to
3. Or use course-specific reports: `/api/v3/course/{courseId}/Reports/Users`

---

## Certificate Model

**Certificate Information:**
- Stored in course metadata: `IsCertificateEnabled`
- Certificate item in CourseItems: `{"ItemType": "Certificate", ...}`
- May have URL: `/api/v3/Courses/{courseId}/Certificate`
- Top-level endpoint `/api/v1/Certificates` returns empty (may need different approach)

---

## Data Extraction Strategy

### Phase 1: Extract Everything As-Is ✅

**Completed:**
- ✅ Organizations (46)
- ✅ Users (68,784)
- ✅ Categories (1 hierarchical)
- ✅ Courses (80 unique)
- ✅ Course Content (160)
- ✅ Course Metadata (160)
- ✅ Groups (26)

**Still Needed:**
- ⚠️ Enrollments (via groups + course reports)
- ⚠️ Certificates (course-level)

### Phase 2: Understand Relationships

**Key Relationships:**
1. **Organization → Groups** - Groups belong to organizations
2. **Groups → Users** - Users belong to groups (via `My groups` + Rules)
3. **Groups → Categories** - Groups may grant access to categories
4. **Categories → Courses** - Categories contain courses (modules)
5. **Courses → CourseItems** - Courses contain content items

### Phase 3: Map to Open edX (Later)

**Don't worry about transformation yet** - just extract and understand the data structure first.

---

## API Endpoints Summary

### V1 Endpoints (Most Comprehensive)

**User Management:**
- `GET /api/v1/users?searchTerm={email}` - Lookup user
- `POST /api/v1/users?orgId={orgId}` - Create user
- `GET /api/v1/Reports/Users` - Export users (CSV)

**Organizations:**
- `GET /api/v1/organization` - Get all organizations

**Categories (Actually = Courses):**
- `GET /api/v1/Category` - Get categories

**Courses (Actually = Modules):**
- `GET /api/v1/Courses` - Get courses (returns categories with nested courses)

**Groups (Learning Pathways):**
- `GET /api/v1/Groups` - Get all groups

**Certificates:**
- `GET /api/v1/Certificates` - Get certificates (returns empty)

**Enrollments:**
- `GET /api/v1/UserEnrollment` - Not found (404)

### V2 Endpoints

**User Profiles:**
- `POST /api/v2/Organizations/{orgId}/UserProfiles/{userId}` - Update user profile

### V3 Endpoints

**Admin:**
- `GET /api/v3/admin/categoriesAndCourses` - Hierarchical categories + courses

**Courses:**
- `GET /api/v3/Courses/{courseId}/Content` - Course content
- `GET /api/v3/Courses/{courseId}/Metadata` - Course metadata
- `GET /api/v3/Courses/{courseId}/Certificate` - Certificate URL

**Reports:**
- `GET /api/v3/Reports/Users` - User export (returns ZIP)
- `GET /api/v3/course/{courseId}/Reports/Users` - Course user export

---

## Next Steps

1. ✅ **Extract all data** - DONE
2. ✅ **Understand terminology** - DONE
3. **Document all API endpoints** - Need Swagger UI access
4. **Map enrollment relationships** - Via groups + course reports
5. **Extract certificate data** - Course-level certificates
6. **Create data model diagram** - Visual representation
7. **Build transformation scripts** - MCT → Open edX (later)

---

**Status:** Data extraction complete. Focus on understanding structure before transformation.

