# MCT Export Summary
_Audience: Platform Eng • Owner: Migration Squad • Last verified: 2025-08-25_

**Export Date:** 2025-11-07  
**Status:** ✅ Core resources exported successfully

## Exported Data

### Main Resources

| Resource | Records | Size | Status |
|----------|---------|------|--------|
| **Organizations** | 46 | 2.9 KB | ✅ Complete |
| **Users** | 68,784 | 53.9 MB | ✅ Complete |
| **Categories** | 1 (hierarchical) | 154.5 KB | ✅ Complete |
| **Courses** | 14 categories | 61.8 KB | ✅ Complete |
| **Course Content** | 160 courses | 803 KB | ✅ Complete |
| **Course Metadata** | 160 courses | 74 KB | ✅ Complete |
| **Enrollments** | 0 | - | ❌ Endpoint not found (404) |
| **Reports** | 0 | - | ⚠️ Returns ZIP file (needs manual extraction) |

### Course Content Details

- **Total Courses with Content:** 160
- **Content Structure:** Includes CourseItems (lessons, modules)
- **Metadata Available:** Yes (160 records)

### Data Location

```
exports/mct/
├── organizations.ndjson      (46 records)
├── users.ndjson              (68,784 records)
├── categories.ndjson         (1 hierarchical record)
├── courses.ndjson            (14 category records)
└── structure/
    ├── course_content.ndjson (160 course content records)
    └── course_metadata.ndjson (160 metadata records)
```

## Export Statistics

- **Total Records:** 69,165 records
- **Total Size:** ~55 MB
- **Export Time:** ~2-3 minutes (with rate limiting)
- **Success Rate:** 6/8 resources (75%)

## Known Issues

1. **Enrollments Endpoint:** Returns 404 - endpoint may not exist or require different path
2. **Reports Endpoint:** Returns ZIP file - needs manual extraction or ZIP handling

## Next Steps

1. ✅ **Core Data Exported** - Organizations, Users, Categories, Courses
2. ✅ **Course Content Exported** - 160 courses with full structure
3. **Investigate Enrollments** - Check Swagger UI for correct endpoint
4. **Handle Reports ZIP** - Extract ZIP or skip (users already exported via Reports/Users)
5. **Data Analysis** - Review exported data structure for transformation

## Data Quality Notes

- **Users:** CSV format with 18 fields, properly parsed
- **Courses:** Hierarchical structure (categories → courses) properly extracted
- **Course Content:** Full CourseItems structure available
- **Organizations:** Simple list, all records exported

---

**Export Script:** `tools/mct-export.mjs`  
**Documentation:** `docs/migrations/mct/EXPORT_GUIDE.md`

