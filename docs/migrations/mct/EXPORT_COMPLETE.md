# MCT Export - Complete Data Export ✅
_Audience: Platform Eng • Owner: Migration Squad • Last verified: 2025-08-25_

## Export Status: COMPLETE

**Date:** 2025-11-07  
**Script:** `tools/mct-export.mjs`  
**Status:** ✅ All available resources exported

---

## Exported Resources

### ✅ Successfully Exported

1. **Organizations** - 46 records (2.9 KB)
   - All countries/regions
   - Simple JSON structure

2. **Users** - 68,784 records (53.9 MB)
   - Complete user database
   - CSV format parsed to JSON
   - Includes "My groups" field (learning pathways)
   - 18 fields per user

3. **Categories** - 1 hierarchical record (154.5 KB)
   - Full category structure
   - Includes nested courses
   - V3 API endpoint

4. **Courses** - 14 category records → **80 unique courses**
   - Category structure with nested courses
   - 80 individual courses identified
   - Course content exported for all courses

5. **Course Content** - 160 records (1.6 MB)
   - Full CourseItems structure
   - Lessons, modules, content details
   - Per-course content export

6. **Course Metadata** - 160 records (148 KB)
   - Course metadata
   - Certificate settings
   - Learning flow types

7. **Groups (Learning Pathways)** - 26 records (9.2 KB) ⭐ **NEW**
   - Learning pathways/user groups
   - Includes rules and organization mapping
   - Examples: "Developer | Id", "Data Analyst | My", "Green Jobs Pathway"

8. **Certificates** - 0 records ⚠️
   - Top-level certificates endpoint returns empty
   - Course-level certificates may be available via `/api/v3/Courses/{courseId}/Certificate`
   - Certificate info may be in course metadata (`IsCertificateEnabled`)

### ⚠️ Partial/Issues

9. **Enrollments** - Endpoint returns 404
   - `/api/v1/UserEnrollment` not found
   - `/api/v1/UserEnrollments` (plural) also not found
   - **Note:** Enrollment data may be embedded in user records or require different endpoint
   - **Alternative:** Check if enrollments are in user CSV data or course reports

10. **Reports** - Returns ZIP file
    - `/api/v3/Reports/Users` returns ZIP
    - Users already exported via V1 Reports endpoint
    - ZIP contains same data (can extract if needed)

---

## Data Structure

### Users (68,784 records)
- Contact (email)
- First Name, Last Name
- **My groups** (learning pathways) ⭐
- Profile fields (gender, DOB, country, etc.)
- Consent, Source, Created Date
- University, Referral Partner

### Groups/Learning Pathways (26 records) ⭐ **NEW**
- GroupId, GroupName
- GroupDescription
- NumberOfUsers
- GroupType
- Rules (JSON query rules for auto-assignment)
- OrganizationId, OrganizationName

**Examples:**
- "Developer | Id" (Indonesia)
- "Data Analyst | My" (Malaysia)
- "Green Jobs Pathway"
- "Project Management | Id"
- Country-based groups (Vietnam, Philippines, etc.)

### Courses (80 courses with content)
- CourseId (ProductId)
- CourseName
- CategoryName
- CourseDescription
- CourseItems (lessons/modules)
- IsCertificateEnabled
- LearningFlowType

### Course Content Structure
Each course includes:
- CourseItems array (lessons, modules)
- Content metadata
- Learning flow configuration
- Certificate settings

---

## Export Statistics

- **Total Records:** 69,191
- **Total Size:** ~54 MB
- **Files Created:** 8 NDJSON files
- **Export Time:** ~3-5 minutes
- **Success Rate:** 7/10 resources (70%)

---

## Files Generated

```
exports/mct/
├── organizations.ndjson         46 records     2.9 KB
├── users.ndjson             68,784 records    53.9 MB
├── categories.ndjson            1 record    154.5 KB
├── courses.ndjson              14 records    61.8 KB
├── groups.ndjson               26 records     9.2 KB ⭐ NEW
└── structure/
    ├── course_content.ndjson  160 records     1.6 MB
    ├── course_metadata.ndjson 160 records     148 KB
    └── course_certificates.ndjson (if any) ⭐ NEW
```

---

## Key Findings

### ✅ What We Have
1. **All 80 courses** exported with full content
2. **Learning pathways/groups** exported (26 groups)
3. **User groups** data in users CSV ("My groups" field)
4. **Course structure** fully captured
5. **Organizations** mapped

### ⚠️ What's Missing or Needs Investigation
1. **Enrollments** - Endpoint doesn't exist
   - May need to extract from user data
   - Or use course-specific reports: `/api/v3/course/{courseId}/Reports/Users`
2. **Certificates** - Top-level endpoint empty
   - Check course-level certificates: `/api/v3/Courses/{courseId}/Certificate`
   - Certificate info may be in course metadata
3. **User-Course Relationships** - Need to derive from:
   - User "My groups" field
   - Course reports per course
   - Or extract from other user fields

---

## Next Steps

1. ✅ **Core Data Exported** - Organizations, Users, Categories, Courses, Groups
2. ✅ **Course Content Exported** - 80 courses with full structure
3. **Investigate Enrollments** - Try course-specific reports or extract from user data
4. **Check Course Certificates** - Verify course-level certificate endpoint
5. **Data Analysis** - Review exported data structure for transformation
6. **Build Transformation Scripts** - MCT → Open edX mapping

---

## Notes

- **Users endpoint:** Use `/api/v1/Reports/Users` (not `/api/v1/users`) for bulk export
- **Course structure:** Hierarchical - categories contain courses
- **Course IDs:** Use `ProductId` (not `courseId`) for content fetching
- **Groups endpoint:** `/api/v1/Groups` (plural, not singular)
- **CSV handling:** Reports endpoints return CSV - script handles automatically
- **ZIP files:** Some endpoints return ZIP - documented but not auto-extracted

---

**Ready for:** Data transformation and Open edX import preparation

**Missing Data:** Enrollments (need alternative approach), Certificates (check course-level)
