# MCT → Open edX Data Mapping
_Audience: Platform Eng • Owner: Migration Squad • Last verified: 2025-12-17_

## CRITICAL UNDERSTANDING: MCT Architecture Limitation

### The Core Issue: No Proper Module/Section Feature

**MCT did not have a proper module or section feature.** The MCT team worked around this limitation by:

1. Creating an MCT **Category** to represent the actual course/program
2. Creating multiple MCT **"Courses"** as a workaround to simulate modules/sections within that category
3. Adding **Lessons** to each "Course" to represent individual content items

### The Correct Mapping

| MCT Term | What It Actually Is | Open edX Equivalent | Correct Mapping |
|----------|---------------------|---------------------|-----------------|
| **Category** | A full course/program (e.g., "Basic Microsoft") | **Course** | ✅ **MCT Category → Open edX Course** |
| **Course** | A workaround for modules/sections within a category (e.g., "Module 0", "Module 1") | **Section (Chapter)** | ✅ **MCT Course → Open edX Section** |
| **Module** (CourseItem) | A grouping/topic (rarely used, nested under Course) | Subsection (Sequential) | ⚠️ **Rarely used in MCT** |
| **Lesson** (CourseItem) | Individual content item (video, PDF) | Unit (Vertical) + XBlock | ✅ **MCT Lesson → Open edX Unit** |
| **Group** | Learning pathway with auto-enrollment rules | Program/Collection | ⚠️ **Not yet implemented** |
| **Organization** | Country/Region/Institution | Organization | ✅ **All mapped to SKILLOURFUTURE** |

---

## Real-World Example: "Basic Microsoft"

### MCT Structure
```
Category ID 16: "Basic Microsoft"
├── Course ID 89: "Module 0 | Basic Microsoft Office"
│   ├── Lesson 1: "Introduction to Microsoft Office"
│   ├── Lesson 2: "Overview of Office Applications"
│   └── ...
├── Course ID 90: "Module 1 | Microsoft Word"
│   ├── Lesson 1: "Getting Started with Word"
│   ├── Lesson 2: "Creating Your First Document"
│   └── ...
├── Course ID 91: "Module 2 | Microsoft Excel"
├── Course ID 92: "Module 3 | Microsoft PowerPoint"
├── Course ID 93: "Module 4 | Microsoft Outlook"
├── Course ID 94: "Module 5 | Microsoft Teams"
├── Course ID 95: "Module 6 | OneDrive"
├── Course ID 96: "Module 7 | Microsoft Planner"
├── Course ID 97: "Module 8 | Microsoft Forms"
├── Course ID 98: "Module 9 | Microsoft To Do"
├── Course ID 99: "Module 10 | Microsoft Sway"
└── Course ID 100: "Module 11 | Microsoft OneNote"
```

### Open edX Structure (Correct Mapping)
```
Course: "Basic Microsoft" (course-v1:SKILLOURFUTURE+BASIC-MICROSOFT+2025)
├── Section: "Module 0 | Basic Microsoft Office"
│   ├── Unit: "Introduction to Microsoft Office"
│   │   └── Video XBlock or HTML XBlock
│   ├── Unit: "Overview of Office Applications"
│   └── ...
├── Section: "Module 1 | Microsoft Word"
│   ├── Unit: "Getting Started with Word"
│   ├── Unit: "Creating Your First Document"
│   └── ...
├── Section: "Module 2 | Microsoft Excel"
├── Section: "Module 3 | Microsoft PowerPoint"
├── Section: "Module 4 | Microsoft Outlook"
├── Section: "Module 5 | Microsoft Teams"
├── Section: "Module 6 | OneDrive"
├── Section: "Module 7 | Microsoft Planner"
├── Section: "Module 8 | Microsoft Forms"
├── Section: "Module 9 | Microsoft To Do"
├── Section: "Module 10 | Microsoft Sway"
└── Section: "Module 11 | Microsoft OneNote"
```

**Result:**
- **15 MCT Categories** → **15 Open edX Courses**
- **81 MCT "Courses"** → **81 Open edX Sections** (distributed across the 15 courses)
- **MCT Lessons** → **Open edX Units**

---

## Open edX Structure Hierarchy (For Reference)

Open edX has this hierarchy:

```
Course (course-v1:ORG+COURSE_NUMBER+RUN)
├── Chapter (Section) - Top-level grouping, maps to MCT "Course"
│   ├── Sequential (Subsection) - Learning sequence (optional grouping)
│   │   ├── Vertical (Unit) - Container for content, maps to MCT Lesson
│   │   │   ├── Video XBlock
│   │   │   ├── HTML XBlock
│   │   │   ├── Problem XBlock
│   │   │   └── ...
│   │   └── Vertical (another unit)
│   └── Sequential (another subsection)
└── Chapter (another section)
```

**Key Concepts:**
- **Course**: The top-level container (maps to MCT Category)
- **Chapter (Section)**: Top-level section within a course (maps to MCT "Course")
- **Sequential (Subsection)**: Optional grouping within a chapter (rarely used in MCT mapping)
- **Vertical (Unit)**: Container that holds XBlocks (maps to MCT Lesson)
- **XBlock**: Individual content items (video, HTML, problem, etc.)

---

## Current Transformation Logic

### Simplified Mapping
```
MCT Category (e.g., "Basic Microsoft")
  → Open edX Course (course-v1:SKILLOURFUTURE+BASIC-MICROSOFT+2025)

MCT Course (e.g., "Module 1 | Microsoft Word")
  → Open edX Section/Chapter

MCT Lesson (e.g., "Getting Started with Word")
  → Open edX Unit/Vertical
    → XBlock (Video or HTML with embedded content)
```

### Course ID Generation
- **Format**: `course-v1:SKILLOURFUTURE+{SLUG}+{YEAR}`
- **Slug Generation**: Category name normalized (uppercase, spaces to hyphens)
- **Example**: "Basic Microsoft" → `BASIC-MICROSOFT`

### Section Ordering
- Sections are ordered by MCT Course ID or by parsing "Module N" from course names
- Preserves the intended learning sequence

### Content Type Mapping
| MCT Lesson Type | Open edX XBlock |
|----------------|----------------|
| Video URL | Video XBlock (embedded player) |
| PDF URL | HTML XBlock (iframe or download link) |
| HTML Content | HTML XBlock |
| External Link | HTML XBlock (link) |

---

## Statistics from Production

Based on actual MCT data:

| Metric | Count | Notes |
|--------|-------|-------|
| **MCT Categories** | 15 | Actual courses in Open edX |
| **MCT "Courses"** | 81 | Sections distributed across 15 courses |
| **MCT Lessons** | ~500+ | Units/content items |
| **Average Sections per Course** | 5.4 | Range: 1-12 sections |

### Course Examples

1. **Basic Microsoft** (Category ID 16)
   - 12 MCT "Courses" (Module 0-11)
   - 1 Open edX Course with 12 Sections

2. **AI Fluency** (Category ID 22)
   - 8 MCT "Courses" (Module 1-8)
   - 1 Open edX Course with 8 Sections

3. **Python Programming** (Category ID 18)
   - 6 MCT "Courses"
   - 1 Open edX Course with 6 Sections

---

## Learning Pathways & Groups

**MCT Groups** were used for learning pathways with auto-enrollment rules.

**Challenge**: Open edX does NOT have built-in learning pathway features.

### Options for Implementation

1. **Programs** (requires additional setup)
   - Group multiple courses into a program
   - Requires `edx-platform` Programs feature or plugin
   - Best for formal learning pathways

2. **Course Tags/Categories**
   - Tag courses with pathway identifiers
   - Users can filter/browse by tags
   - Simplest approach

3. **Custom Enrollment Rules**
   - Use Django management commands to auto-enroll users
   - Based on user profile fields or group membership
   - Most similar to MCT's approach

**Current Status**: Not yet implemented. All users have access to all courses. Enrollment rules can be added later if needed.

---

## Migration Implementation Status

✅ **Completed**:
- Category → Course mapping
- Course → Section mapping
- Lesson → Unit mapping
- Content type detection and XBlock generation
- Course slug and ID generation
- Section ordering preservation

⚠️ **Pending**:
- Learning pathway/group mapping
- Certificate configuration
- Progress tracking verification
- User enrollment synchronization

🔍 **Verified**:
- 15 courses successfully created in Open edX
- 81 sections distributed correctly
- Content structure preserved
- URLs and media files accessible

---

## Next Steps

1. ✅ **Mapping strategy confirmed** (Category → Course, Course → Section, Lesson → Unit)
2. ⬜ **Implement learning pathway support** (if required)
3. ⬜ **Verify all content is accessible** in Open edX
4. ⬜ **Synchronize user enrollments** from MCT to Open edX
5. ⬜ **Test certificate generation** for completed courses


