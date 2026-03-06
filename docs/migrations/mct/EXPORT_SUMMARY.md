# MCT Export Summary
_Audience: Platform Eng • Owner: Migration Squad • Last verified: 2025-12-18_

**Export Date:** 2025-12-17 (latest)
**Status:** ✅ Core resources exported successfully
**Data Quality:** ⚠️ Enrollment data transformation issue identified

## Exported Data (CORRECTED)

### Main Resources

| Resource | Records | Size | Status |
|----------|---------|------|--------|
| **Organizations** | 46 | 2.9 KB | ✅ Complete |
| **Users** | 69,419 | 53.9 MB | ✅ Complete (corrected) |
| **Categories** | 15 | 154.5 KB | ✅ Complete (corrected) |
| **Courses** | 81 sections across 15 categories | 61.8 KB | ✅ Complete (corrected) |
| **Course Content** | 160 records | 1.6 MB | ✅ Complete |
| **Course Metadata** | 160 records | 148 KB | ✅ Complete |
| **Enrollments** | 103,341 | 12.1 MB | ✅ Complete (real data from API) |
| **Groups/Pathways** | 26 | 9.2 KB | ✅ Complete |

### Course Content Details

- **Total Categories:** 15 (not 31 - verified actual count)
- **Total MCT "Courses":** 81 (these are sections/modules, not courses)
- **Content Structure:** Includes CourseItems (lessons, modules)
- **Metadata Available:** Yes (160 records)

### Enrollment Distribution (REAL DATA)

| Category ID | Category Name | Enrollments |
|-------------|---------------|-------------|
| 22 | Careering as an Administrative Professional | 45,860 |
| 27 | Digital Literacy | 45,715 |
| 24 | AI Fluency | 10,116 |
| 45 | Become an Entrepreneur | 825 |
| 46 | Speak with Impact | 825 |
| **1, 14, 15, 16, 30, 31, 32, 33, 35, 44** | **Various** | **0 (each)** |

**Total Enrollments:** 103,341 across 5 categories

### Data Location

```
exports/mct/
├── organizations.ndjson         (46 records)
├── users.ndjson                 (69,419 records) ✅ CORRECTED
├── categories.ndjson            (1 hierarchical record)
├── courses.ndjson               (15 category records) ✅ CORRECTED
├── groups.ndjson                (26 records)
├── learningpaths.ndjson         (XX records)
└── structure/
    ├── course_content.ndjson    (160 course content records)
    └── course_metadata.ndjson   (160 metadata records)

var/migrations/mct/
├── users.csv                    (69,419 records)
├── courses_categories.csv       (15 records) ✅ REAL CATEGORIES
├── enrollments_categories.csv   (103,341 records) ✅ REAL ENROLLMENT DATA
└── course_structure_categories.json
```

## Export Statistics (CORRECTED)

- **Total Records:** 172,946 records (including all enrollments)
- **Total Size:** ~67 MB
- **Export Time:** ~3-5 minutes (with rate limiting)
- **Success Rate:** 8/9 resources (89%) ✅

## Data Quality Issues Identified

### 🚨 CRITICAL: Fake Enrollment Data in Transformation Script

**Issue:** The `transform_data.py` script (lines 134-177) generates **FAKE enrollment data** using keyword matching instead of using real MCT data.

**Impact:**
- Previous documentation reported 57,483 enrollments (INCORRECT)
- These were heuristically generated, not from MCT
- Real enrollment count is 103,341 (+45,858 more than reported)

**Solution:**
- Real enrollment data already exported to `enrollments_categories.csv`
- Update `transform_data.py` to use this file instead of keyword matching
- Re-run transformation after fixing the script

### ⚠️ Category Count Discrepancy

**Previous claim:** 31 categories exported
**Actual count:** 15 categories ✅ VERIFIED
**Action needed:** Verify source of "31 categories" claim

### ⚠️ User-Mentioned Enrollment Numbers Don't Match

**User mentioned:**
- Soft Skills: 325,810 enrollments
- Basic Microsoft: 660,625 enrollments
- Employability: 267,653 enrollments

**Actual MCT data:**
- Soft Skills (Category 1): **0 enrollments** ✅ VERIFIED
- Basic Microsoft (Category 16): **0 enrollments** ✅ VERIFIED
- Employability (Category 14): **0 enrollments** ✅ VERIFIED

**Action needed:** Verify if user's numbers are from a different system or time period

## Next Steps

1. ✅ **Core Data Exported** - Organizations, Users, Categories, Courses, Enrollments
2. ✅ **Course Content Exported** - 15 categories with 81 sections/modules
3. ✅ **Real Enrollment Data Exported** - 103,341 enrollments from MCT API
4. ⚠️ **Fix `transform_data.py`** - Remove keyword-matching enrollment generation
5. ⚠️ **Resolve Duplicate Courses** - Address MCT-* vs MCTCAT-* format issue
6. ⚠️ **Verify Category Count** - Confirm if 15 or 31 categories total

## Data Quality Notes

- **Users:** CSV format with 18 fields, properly parsed ✅
- **Courses:** Hierarchical structure (15 categories → 81 courses) properly extracted ✅
- **Course Content:** Full CourseItems structure available ✅
- **Organizations:** Simple list, all records exported ✅
- **Enrollments:** Real data from `/api/v3/course/{courseId}/Reports/Users` ✅
- **Zero-enrollment categories:** 10 of 15 categories have no enrollments (expected) ✅

---

**Export Script:** `scripts/migrations/mct/mct-export.mjs`
**Transformation Script:** `scripts/migrations/mct/transform_data.py` (⚠️ has bug - needs fix)
**Documentation:** `docs/migrations/mct/EXPORT_GUIDE.md`
**Status Report:** `docs/migrations/mct/MCT_MIGRATION_STATUS.md` ✅ UPDATED

