# Data Sources Explained
_Understanding Kajabi vs MCT Course Data • Last updated: 2025-11-12_

## 🎓 Course Data Sources

### 1. MCT (Microsoft Community Training) Courses

**What:** Courses migrated from Microsoft Community Training platform  
**Status:** ✅ Data imported to local MySQL  
**Location:** MySQL `student_courseenrollment` table

**Evidence:**
```sql
-- 137,468 enrollments across 74 courses
-- Course IDs format: course-v1:MEREKA+MEKA-{number}+RUN-{number}
-- Example: course-v1:MEREKA+MEKA-2148875088+RUN-2148875088
```

**Data Present:**
- ✅ User enrollments (137,468 enrollments)
- ✅ User accounts (84,379 users)
- ❌ Course content (not in modulestore)
- ❌ Course structure (not in MongoDB)

**Next Step:** Need course export tarballs from MCT production to import actual content

### 2. Kajabi Courses

**What:** Courses from Kajabi platform  
**Status:** ❓ Not yet migrated to Open edX  
**Location:** Unknown - likely need API export

**Evidence:**
```sql
-- No Kajabi-specific tables found
-- No Kajabi course IDs in enrollments
```

**Data Present:**
- ❌ Not imported yet

**Next Step:** Kajabi course import pipeline (see `docs/migrations/kajabi/`)

## 🗄️ Open edX Data Architecture

### MongoDB (`openedx` database)
**Purpose:** Course content and structure

**Collections:**
- `modulestore.structures` - Course outline (chapters, sections)
- `modulestore.definitions` - XBlock content (videos, problems, HTML)
- `modulestore.active_versions` - Published vs draft versions

**Current Status:**
- 10 skeleton courses created locally
- No real content yet (awaiting imports)

### MongoDB (`cs_comments_service` database)
**Purpose:** Forum discussions only

### MySQL (`openedx` database)
**Purpose:** Course metadata, user data, enrollments

**Key Tables:**
- `auth_user` - 84,379 users
- `student_courseenrollment` - 137,468 enrollments
- `course_overviews_courseoverview` - 5 course metadata records
- `organizations_organization` - BIJIBIJI, SKILLOURFUTURE

## 📊 Current Data Summary

| Data Type | Source | Count | Has Content |
|-----------|--------|-------|-------------|
| Users | MCT | 84,379 | ✅ |
| Enrollments | MCT | 137,468 | ✅ |
| Course IDs | MCT | 74 unique | Metadata only |
| Course Content | MCT | 0 | ❌ Need tarballs |
| Course Overviews | Local | 5 | Skeleton only |
| Kajabi Courses | Kajabi | Unknown | ❌ Not imported |

## 🔍 Where to View Courses

### Studio (Course Authoring)
**URL:** http://studio.localhost  
**Login:** admin / admin123  
**Shows:** Empty skeleton courses

### LMS (Student View)
**URL:** http://localhost  
**Login:** admin / admin123  
**Shows:** Enrolled courses (but empty content)

### Course List API
**URL:** http://localhost/api/courses/v1/courses/  
**Shows:** Published courses with metadata

### Discovery (Catalog)
**URL:** http://discovery.localhost  
**Shows:** Course catalog

## 🚀 Next Steps to Get Real Content

### Option 1: Export from Production MCT Courses (Recommended)
```bash
# On production/staging
tutor k8s exec cms -- python manage.py cms export /tmp <course_id>

# Download tarball
kubectl cp mereka-lms/cms-pod:/tmp/course.tar.gz ./course.tar.gz

# Import locally
tutor local exec cms -- python manage.py cms import /tmp /tmp/course
```

### Option 2: Create Sample Content Locally
```bash
# Access Studio
open http://studio.localhost

# Login as admin
# Create course → Add units → Add components
```

### Option 3: Import Kajabi Courses
See `docs/migrations/kajabi/` for Kajabi import pipeline

## 📝 Key Takeaways

1. **MCT enrollments exist** but courses have no content yet
2. **Course structure** lives in MongoDB, **metadata** in MySQL
3. **Forums** use separate MongoDB database
4. Need **course export tarballs** to get actual content
5. **Kajabi courses** not imported yet (different pipeline)

---

**To test with real content:** Export 5 courses from production and import locally



