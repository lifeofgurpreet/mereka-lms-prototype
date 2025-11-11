# MCT → Open edX Data Mapping
_Audience: Platform Eng • Owner: Migration Squad • Last verified: 2025-08-31_

## Current Mapping Strategy

### ⚠️ CRITICAL: MCT Terminology is Confusing

MCT uses non-standard terminology. Here's what things actually are:

| MCT Term | What It Actually Is | Open edX Equivalent | Our Current Mapping |
|----------|---------------------|---------------------|---------------------|
| **Category** | A full course/program (e.g., "AI Fluency") | Course | ❌ **IGNORED** - Used as metadata only |
| **Course** | A module/unit within a category (e.g., "Module 1: Introduction to AI") | Course | ✅ **Mapped to Open edX Course** |
| **Module** (CourseItem) | A grouping/topic (rarely used) | Chapter | ⚠️ **Most courses don't have this** |
| **Lesson** (CourseItem) | Individual content item (video, PDF) | Sequential + Vertical + XBlock | ✅ **Mapped correctly** |
| **Group** | Learning pathway with auto-enrollment rules | ❌ **No direct equivalent** | ⚠️ **Mapped to enrollments heuristically** |
| **Organization** | Country/Region/Institution | Organization | ❌ **All mapped to SKILLOURFUTURE** |

---

## Current Structure Mapping

### What We're Building:

```
Open edX Course Structure:
├── Course: "Module 1: Introduction to AI" (course-v1:SKILLOURFUTURE+MCT-279+RUN-279)
│   ├── Chapter: "Course Content" (default module, since most MCT courses don't have explicit modules)
│   │   ├── Sequential: "What is artificial intelligence?" (lesson 1)
│   │   │   └── Vertical: (unit)
│   │   │       └── Video XBlock: (video content)
│   │   ├── Sequential: "Common AI Subsets" (lesson 2)
│   │   │   └── Vertical: (unit)
│   │   │       └── Video XBlock: (video content)
│   │   └── Sequential: "Lesson Plan" (lesson 3)
│   │       └── Vertical: (unit)
│   │           └── HTML XBlock: (PDF link)
```

### Issues with Current Mapping:

1. **Categories Are Ignored**
   - MCT Categories (like "AI Fluency") are actually full courses/programs
   - We're treating each MCT "Course" as a separate Open edX course
   - **Question:** Should Categories be separate Open edX courses instead?

2. **Modules Are Mostly Missing**
   - Most MCT courses don't have explicit Module CourseItems
   - We create a default "Course Content" module for all lessons
   - **Question:** Should we create modules based on Category grouping?

3. **Learning Pathways Not Handled**
   - MCT Groups (like "Developer | Id") are learning pathways
   - Open edX doesn't have built-in learning pathways
   - We're mapping pathways to enrollments heuristically
   - **Question:** How should we handle learning pathways in Open edX?

---

## Open edX Structure Hierarchy

Open edX has this hierarchy:

```
Course (course-v1:ORG+NUMBER+RUN)
├── Chapter (Section) - Top-level grouping
│   ├── Sequential (Subsection) - Learning sequence
│   │   ├── Vertical (Unit) - Container for content
│   │   │   ├── Video XBlock
│   │   │   ├── HTML XBlock
│   │   │   ├── Problem XBlock
│   │   │   └── ...
│   │   └── Vertical (another unit)
│   └── Sequential (another subsection)
└── Chapter (another section)
```

**Key Concepts:**
- **Chapter**: Top-level section (like "Week 1", "Module 1")
- **Sequential**: A subsection within a chapter (like "Lesson 1", "Assignment 1")
- **Vertical**: A unit/container that holds XBlocks
- **XBlock**: Individual content items (video, HTML, problem, etc.)

---

## Learning Pathways in Open edX

**Open edX does NOT have built-in learning pathways.**

Options:
1. **Programs** (requires `edx-platform` Programs feature or `edx-programs` plugin)
   - Can group multiple courses into a program
   - Requires additional setup

2. **Course Tags/Categories**
   - Use course tags to group related courses
   - Users can filter by tags

3. **Custom Enrollment Rules**
   - Use Django management commands to auto-enroll users based on profile data
   - Similar to MCT's Group Rules

4. **Separate Course Collections**
   - Create separate course runs for different pathways
   - More complex but gives full control

**Current Approach:** We're mapping pathways to enrollments heuristically (if user is in "Developer | Id" pathway, enroll them in developer-related courses).

---

## Recommendations

### Option 1: Keep Current Mapping (Simplest)
- ✅ Each MCT "Course" → One Open edX Course
- ✅ Ignore Categories (use as metadata/tags)
- ✅ Create default "Course Content" module for courses without explicit modules
- ⚠️ Learning pathways → Heuristic enrollments

**Pros:** Simple, works immediately  
**Cons:** Loses Category grouping, pathways not properly represented

### Option 2: Categories as Courses (More Accurate)
- ✅ Each MCT "Category" → One Open edX Course
- ✅ MCT "Courses" → Open edX Chapters
- ✅ MCT "Lessons" → Open edX Sequentials
- ⚠️ More complex transformation

**Pros:** Preserves MCT structure better  
**Cons:** Requires reworking transformation scripts

### Option 3: Hybrid Approach
- ✅ Categories → Course Tags/Categories
- ✅ MCT "Courses" → Open edX Courses
- ✅ Use course tags to group related courses
- ✅ Learning pathways → Program enrollments (if Programs plugin available)

**Pros:** Best of both worlds  
**Cons:** Requires Programs plugin setup

---

## Questions to Answer

1. **Should Categories be separate courses?**
   - Current: No, Categories are metadata
   - Alternative: Yes, Categories are courses, MCT "Courses" are chapters

2. **How should we handle learning pathways?**
   - Current: Heuristic enrollments
   - Alternative: Programs plugin, course tags, or custom enrollment rules

3. **What about modules?**
   - Current: Default "Course Content" module if none exist
   - Alternative: Create modules based on Category grouping

4. **Should Organizations map to Open edX Organizations?**
   - Current: All mapped to SKILLOURFUTURE
   - Alternative: Create separate orgs per MCT Organization

---

## Next Steps

1. **Decide on mapping strategy** (Option 1, 2, or 3)
2. **Update transformation scripts** if needed
3. **Handle learning pathways** appropriately
4. **Test with sample courses** before full import


