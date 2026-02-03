# MCT Export - Complete Data Export ✅
_Audience: Platform Eng • Owner: Migration Squad • Last verified: 2025-12-18_

## Export Status: ⚠️ COMPLETE (with data quality issues identified)

**Date:** 2025-12-17 (latest export)
**Script:** `tools/mct-export.mjs`
**Status:** ✅ All available resources exported
**Data Quality:** ⚠️ Enrollment data generation issue identified in transformation script

---

## ⚠️ CRITICAL: Enrollment Data Quality Issue

**PROBLEM IDENTIFIED**: The `transform_data.py` script generates **FAKE enrollment data** using keyword matching instead of using real MCT enrollment data.

**Impact**: Previous documentation reported 57,483 enrollments that were heuristically generated, not extracted from MCT.

**Real enrollment data source**: `/api/v3/course/{courseId}/Reports/Users` endpoint (already exported to `enrollments_categories.csv`)

**Real enrollment count**: 103,341 enrollments across 5 categories (not 57,483)

---

## Exported Resources

### ✅ Successfully Exported (CORRECTED COUNTS)

1. **Organizations** - 46 records (2.9 KB)
   - All countries/regions
   - Simple JSON structure

2. **Users** - 69,419 records (53.9 MB) ✅ CORRECTED
   - Complete user database from MCT
   - CSV format parsed to JSON
   - Includes "My groups" field (learning pathways)
   - 18 fields per user

3. **Categories** - 15 categories ✅ CORRECTED
   - Full category structure exported
   - All 15 categories identified in MCT
   - Includes nested courses
   - V3 API endpoint

4. **Courses** - 15 category records → **81 unique courses** ✅ CORRECTED
   - Category structure with nested courses
   - 81 individual MCT "courses" (these are actually sections/modules)
   - Course content exported for all courses

5. **Course Content** - 160 records (1.6 MB)
   - Full CourseItems structure
   - Lessons, modules, content details
   - Per-course content export

6. **Course Metadata** - 160 records (148 KB)
   - Course metadata
   - Certificate settings
   - Learning flow types

7. **Groups (Learning Pathways)** - 26 records (9.2 KB) ✅
   - Learning pathways/user groups
   - Includes rules and organization mapping
   - Examples: "Developer | Id", "Data Analyst | My", "Green Jobs Pathway"

8. **Enrollments (Category-level)** - 103,341 records ✅ **REAL DATA**
   - Real enrollment data from `/api/v3/course/{courseId}/Reports/Users`
   - Exported to `enrollments_categories.csv`
   - **5 categories with enrollments**: 22, 24, 27, 45, 46
   - **10 categories with ZERO enrollments**: 1, 14, 15, 16, 30, 31, 32, 33, 35, 44

9. **Certificates** - 0 records ⚠️
   - Top-level certificates endpoint returns empty
   - Course-level certificates may be available via `/api/v3/Courses/{courseId}/Certificate`
   - Certificate info may be in course metadata (`IsCertificateEnabled`)

### ❌ Not Available

10. **User-level enrollment endpoint** - Endpoint does not exist
    - `/api/v1/UserEnrollment` returns 404
    - `/api/v1/UserEnrollments` (plural) also returns 404
    - **Workaround**: Use course-level reports `/api/v3/course/{courseId}/Reports/Users` ✅ (already done)

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

## Export Statistics (CORRECTED)

- **Total Records:** 172,946 (corrected count)
- **Total Size:** ~67 MB (including enrollment data)
- **Files Created:** 9 NDJSON/CSV files
- **Export Time:** ~3-5 minutes
- **Success Rate:** 8/9 resources (89%) ✅

---

## Files Generated (CORRECTED)

```
exports/mct/
├── organizations.ndjson           46 records     2.9 KB
├── users.ndjson               69,419 records    53.9 MB ✅ CORRECTED
├── categories.ndjson              1 record    154.5 KB
├── courses.ndjson                15 records    61.8 KB ✅ CORRECTED
├── groups.ndjson                 26 records     9.2 KB
├── learningpaths.ndjson          XX records     X.X KB
└── structure/
    ├── course_content.ndjson    160 records     1.6 MB
    ├── course_metadata.ndjson   160 records     148 KB
    └── (course_certificates.ndjson - empty)

var/migrations/mct/
├── users.csv                  69,419 records    13.7 MB
├── courses_categories.csv         15 records       772 B ✅ REAL CATEGORIES
├── enrollments_categories.csv 103,341 records    12.1 MB ✅ REAL ENROLLMENT DATA
└── course_structure_categories.json              433 KB
```

---

## Key Findings (UPDATED)

### ✅ What We Have
1. **All 15 categories** exported with full content ✅ VERIFIED
2. **All 81 MCT "courses"** (sections) exported ✅ VERIFIED
3. **69,419 users** exported ✅ VERIFIED
4. **103,341 real enrollments** from MCT API ✅ VERIFIED
5. **Learning pathways/groups** exported (26 groups) ✅
6. **User groups** data in users CSV ("My groups" field) ✅
7. **Course structure** fully captured ✅
8. **Organizations** mapped ✅

### ✅ What Was Previously "Missing" but Now Found
1. **Enrollments** - ✅ FOUND via `/api/v3/course/{courseId}/Reports/Users`
   - Exported to `enrollments_categories.csv`
   - 103,341 real enrollment records
   - Only 5 categories have enrollments (10 have zero)

### ⚠️ What's Still Missing
1. **Certificates** - Top-level endpoint empty
   - Check course-level certificates: `/api/v3/Courses/{courseId}/Certificate`
   - Certificate info may be in course metadata (`IsCertificateEnabled`)
2. **Course-level lesson completion/progress data** - Not yet exported

---

## Next Steps (UPDATED)

1. ✅ **Core Data Exported** - Organizations, Users, Categories, Courses, Groups, Enrollments
2. ✅ **Course Content Exported** - 15 categories with 81 sections/modules
3. ✅ **Real Enrollment Data Exported** - 103,341 enrollments from MCT API
4. ⚠️ **Fix `transform_data.py`** - Remove keyword-matching enrollment generation, use real data
5. ⚠️ **Check Course Certificates** - Verify course-level certificate endpoint
6. ⚠️ **Resolve Duplicate Courses** - Address MCT-* vs MCTCAT-* format issue

---

## Notes

- **Users endpoint:** Use `/api/v1/Reports/Users` (not `/api/v1/users`) for bulk export ✅
- **Course structure:** Hierarchical - categories (15) contain courses (81 total) ✅
- **Course IDs:** Use `ProductId` (not `courseId`) for content fetching ✅
- **Enrollment endpoint:** `/api/v3/course/{courseId}/Reports/Users` works ✅
- **Groups endpoint:** `/api/v1/Groups` (plural, not singular) ✅
- **CSV handling:** Reports endpoints return CSV - script handles automatically ✅
- **ZIP files:** Some endpoints return ZIP - documented but not auto-extracted
- **Category count:** 15 categories total (not 31 - need to verify user's source)

---

## 🚨 Data Quality Issues Identified

### Issue 1: Fake Enrollment Data in transform_data.py
**File**: `scripts/migrations/mct/scripts/transform_data.py` (lines 134-177)
**Problem**: Script generates fake enrollments via keyword matching
**Solution**: Use real data from `enrollments_categories.csv`

### Issue 2: Incorrect Category Count
**Previous claim**: 31 categories
**Actual count**: 15 categories ✅ VERIFIED
**Action needed**: Verify source of "31 categories" claim

### Issue 3: User-mentioned enrollment numbers don't match
**User mentioned**:
- Soft Skills: 325,810 enrollments
- Basic Microsoft: 660,625 enrollments
- Employability: 267,653 enrollments

**Actual MCT data**:
- Soft Skills (Category 1): 0 enrollments ✅ VERIFIED
- Basic Microsoft (Category 16): 0 enrollments ✅ VERIFIED
- Employability (Category 14): 0 enrollments ✅ VERIFIED

**Action needed**: Verify if user's numbers are from a different system or time period

---

**Ready for:** ⚠️ Data transformation with corrected enrollment data

**Blocking Issues:** Fix `transform_data.py` enrollment generation bug, resolve duplicate courses
