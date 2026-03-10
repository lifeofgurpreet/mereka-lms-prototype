# MCT Pre-Migration Inventory

**Document Created:** 2025-12-17
**Source Platform:** Microsoft Community Training (learn.skillourfuture.org)
**Target Platform:** Open edX (skillourfuture.academy.mereka.io)
**Organization:** SKILLOURFUTURE

---

## CRITICAL: MCT → Open edX Structure Mapping

### Understanding MCT's Structure Workaround

**IMPORTANT CONTEXT**: MCT did not have a proper module/section feature within courses. The team used "Courses" as a **WORKAROUND** to create what are actually modules/sections within a single learning experience.

```
MCT Structure (as designed)          What they ACTUALLY represent      Open edX Structure
===========================          ===========================       ==================
Category (15 total)         →        ONE complete course      →        Course
  └── "Course" (81 total)   →          Sections/Modules        →          └── Section/Module
        └── Lesson          →            Individual lessons    →                └── Unit (with XBlocks)
```

### The Mapping in Plain English

1. **MCT "Category"** = **ONE Open edX Course** (15 total courses)
2. **MCT "Course"** = **Open edX Section/Module** (NOT a separate course - this was a structural workaround)
3. **MCT "Lesson"** = **Open edX Unit** (the actual learning content)

### Example: "Basic Microsoft" Category → ONE Open edX Course

```
MCT Platform:
─────────────────────────────────────────────────────────────────────
Category: "FOW (ENG) | Basic Microsoft Office for Everyone"
├── Course 270: "Module 0: Introduction to Digital Productivity"
├── Course 214: "Module 01: Designing a Document in Word"
├── Course 216: "Module 02: Designing an Excel Sheet"
├── Course 217: "Module 03: Getting started with OneNote"
├── Course 218: "Module 04: Connecting with Outlook"
├── Course 219: "Module 05: Creating a Powerpoint Presentation"
├── Course 237: "Module 06: Access Information Online"
├── Course 238: "Module 07: Participate Safely and Responsibly Online"
├── Course 239: "Module 08: Collaborating with Outlook"
├── Course 240: "Module 09: Collaborate Online in Word"
├── Course 241: "Module 10: Sharing Content with OneDrive"
└── Course 242: "Module 11: Using Chat, Video Calls, and Meetings"

Becomes → Open edX:
─────────────────────────────────────────────────────────────────────
Course: course-v1:SKILLOURFUTURE+BASIC-MICROSOFT+2025
├── Section: "Module 0: Introduction to Digital Productivity"
├── Section: "Module 01: Designing a Document in Word"
├── Section: "Module 02: Designing an Excel Sheet"
├── Section: "Module 03: Getting started with OneNote"
├── Section: "Module 04: Connecting with Outlook"
├── Section: "Module 05: Creating a Powerpoint Presentation"
├── Section: "Module 06: Access Information Online"
├── Section: "Module 07: Participate Safely and Responsibly Online"
├── Section: "Module 08: Collaborating with Outlook"
├── Section: "Module 09: Collaborate Online in Word"
├── Section: "Module 10: Sharing Content with OneDrive"
└── Section: "Module 11: Using Chat, Video Calls, and Meetings"
```

**KEY POINT**: The 12 MCT "Courses" above become 12 sections within a SINGLE Open edX course, NOT 12 separate courses.

### Migration Summary

**DO NOT create 81 separate courses. We are creating exactly 15 Open edX courses:**
- 15 MCT Categories → 15 Open edX Courses
- 81 MCT "Courses" → 81 Sections distributed across those 15 courses
- Each MCT lesson becomes a Unit within the corresponding section

---

## Current Status

### Infrastructure Ready
- [x] MongoDB Atlas connected: `cluster-mereka-lms.2pjex4s.mongodb.net`
- [x] LMS/CMS configured to use Atlas
- [x] Forum configured to use Atlas
- [x] ArgoCD selfHeal disabled (manual changes preserved)
- [ ] MongoDB Atlas: **0 courses** (empty, ready for import)

### Users Already Migrated
| Migration | Date | Users |
|-----------|------|-------|
| Kajabi | 2025-11-07 | 84,372 |
| MCT | 2025-11-10 | 64,022 |
| **Total** | | **149,132** unique users |

### Courses NOT Yet Imported
The MySQL CourseOverview table shows 14 MCT course entries, but MongoDB modulestore is **empty**.
Course content needs to be imported.

---

## 15 Courses to Create (from MCT Categories)

**Remember**: Each MCT "Course" listed below becomes a SECTION within the Open edX course, NOT a separate course.

### Course 1: AI Fluency
- **MCT Category ID:** 24
- **Open edX Course ID:** `course-v1:SKILLOURFUTURE+AI-FLUENCY+2025`
- **Number of Sections:** 2 (from 2 MCT "Courses")
- **Sections to create:**
  - Section: "Module 1: Introduction to AI and Responsible Use" (from MCT Course ID: 279, EN-US)
  - Section: "Nhap mon 1: Artificial Intelligence" (from MCT Course ID: 281, VI-VN)

### Course 2: Basic Microsoft
- **MCT Category ID:** 16
- **Open edX Course ID:** `course-v1:SKILLOURFUTURE+BASIC-MICROSOFT+2025`
- **Number of Sections:** 12 (from 12 MCT "Courses")
- **Sections to create:**
  - Section: "Module 0: Introduction to Digital Productivity" (from MCT Course ID: 270)
  - Section: "Module 01: Designing a Document in Word" (from MCT Course ID: 214)
  - Section: "Module 02: Designing an Excel Sheet" (from MCT Course ID: 216)
  - Section: "Module 03: Getting started with OneNote" (from MCT Course ID: 217)
  - Section: "Module 04: Connecting with Outlook" (from MCT Course ID: 218)
  - Section: "Module 05: Creating a Powerpoint Presentation" (from MCT Course ID: 219)
  - Section: "Module 06: Access Information Online" (from MCT Course ID: 237)
  - Section: "Module 07: Participate Safely and Responsibly Online" (from MCT Course ID: 238)
  - Section: "Module 08: Collaborating with Outlook" (from MCT Course ID: 239)
  - Section: "Module 09: Collaborate Online in Word" (from MCT Course ID: 240)
  - Section: "Module 10: Sharing Content with OneDrive" (from MCT Course ID: 241)
  - Section: "Module 11: Using Chat, Video Calls, and Meetings" (from MCT Course ID: 242)

### Course 3: Become an Entrepreneur
- **MCT Category ID:** 45
- **Open edX Course ID:** `course-v1:SKILLOURFUTURE+ENTREPRENEUR+2025`
- **Number of Sections:** 8 (from 8 MCT "Courses")
- **Sections to create:**
  - Section: "Course Intro: Entrepreneurial Myths & Mindset" (from MCT Course ID: 429)
  - Section: "Module 1: Start with What Matters - Problem Definition" (from MCT Course ID: 430)
  - Section: "Module 2: From Problems to Possibilities - Ideation" (from MCT Course ID: 431)
  - Section: "Module 3: Market Testing - Prototyping" (from MCT Course ID: 433)
  - Section: "Module 4: Storytelling & Business Model Canvas" (from MCT Course ID: 442)
  - Section: "Module 5: Building a Team" (from MCT Course ID: 441)
  - Section: "Module 6: Finding Support in Your Ecosystem" (from MCT Course ID: 447)
  - Section: "Wrap Up: Claim Your Certificate" (from MCT Course ID: 448)

### Course 4: Administrative Professional
- **MCT Category ID:** 22
- **Open edX Course ID:** `course-v1:SKILLOURFUTURE+ADMIN-PROFESSIONAL+2025`
- **Number of Sections:** 1 (from 1 MCT "Course")
- **Sections to create:**
  - Section: "Modul 4: Studi Kasus" (from MCT Course ID: 268, ID-ID)

### Course 5: Climate Education
- **MCT Category ID:** 30
- **Open edX Course ID:** `course-v1:SKILLOURFUTURE+CLIMATE-EDU+2025`
- **Number of Sections:** 1 (from 1 MCT "Course")
- **Sections to create:**
  - Section: "Growing your Youth-Led Climate Organization" (from MCT Course ID: 334)

### Course 6: Content Creation
- **MCT Category ID:** 44
- **Open edX Course ID:** `course-v1:SKILLOURFUTURE+CONTENT-CREATION+2025`
- **Number of Sections:** 1 (from 1 MCT "Course")
- **Sections to create:**
  - Section: "Content Creation for Green Skills" (from MCT Course ID: 419)

### Course 7: Digital Literacy
- **MCT Category ID:** 27
- **Open edX Course ID:** `course-v1:SKILLOURFUTURE+DIGITAL-LITERACY+2025`
- **Number of Sections:** 5 (from 5 MCT "Courses")
- **Sections to create:**
  - Section: "A podcast series - .future" (from MCT Course ID: 289)
  - Section: "Computer Security" (from MCT Course ID: 288)
  - Section: "Digital Literacy" (from MCT Course ID: 287)
  - Section: "Productivity Programmes" (from MCT Course ID: 297)
  - Section: "The animated guide to all things tech" (from MCT Course ID: 292)

### Course 8: Employability
- **MCT Category ID:** 14
- **Open edX Course ID:** `course-v1:SKILLOURFUTURE+EMPLOYABILITY+2025`
- **Number of Sections:** 7 (from 7 MCT "Courses")
- **Sections to create:**
  - Section: "Building a Standout CV" (from MCT Course ID: 225)
  - Section: "Digital Branding & Employability - Level 1" (from MCT Course ID: 224)
  - Section: "Green Jobs & Sustainability Careers" (from MCT Course ID: 227)
  - Section: "How to find your dream job" (from MCT Course ID: 282)
  - Section: "Mastering The Art of Interview" (from MCT Course ID: 226)
  - Section: "Personal Branding through LinkedIn" (from MCT Course ID: 273)
  - Section: "Xu huong viec lam xanh" (from MCT Course ID: 337, VI-VN)

### Course 9: Personal Branding (English)
- **MCT Category ID:** 32
- **Open edX Course ID:** `course-v1:SKILLOURFUTURE+PERSONAL-BRANDING-EN+2025`
- **Number of Sections:** 5 (from 5 MCT "Courses")
- **Sections to create:**
  - Section: "Module 1: Course Introduction" (from MCT Course ID: 357)
  - Section: "Module 2: Defining Who You Are" (from MCT Course ID: 359)
  - Section: "Module 3: Building Your Personal Brand" (from MCT Course ID: 360)
  - Section: "Module 4: Establishing Your Personal Brand" (from MCT Course ID: 361)
  - Section: "Module 5: Conclusion" (from MCT Course ID: 362)

### Course 10: Personal Finance
- **MCT Category ID:** 35
- **Open edX Course ID:** `course-v1:SKILLOURFUTURE+PERSONAL-FINANCE+2025`
- **Number of Sections:** 7 (from 7 MCT "Courses")
- **Sections to create:**
  - Section: "Module 1: Introduction" (from MCT Course ID: 372)
  - Section: "Module 2: Introduction to Personal Finance" (from MCT Course ID: 374)
  - Section: "Module 3: Income and Expenses" (from MCT Course ID: 376)
  - Section: "Module 4: Savings, Inflation, Insurance, Credit" (from MCT Course ID: 378)
  - Section: "Module 5: Investments" (from MCT Course ID: 377)
  - Section: "Module 6: Vision and Goal Setting" (from MCT Course ID: 379)
  - Section: "Module 7: Conclusion" (from MCT Course ID: 380)

### Course 11: Personal Branding (Indonesian)
- **MCT Category ID:** 33
- **Open edX Course ID:** `course-v1:SKILLOURFUTURE+PERSONAL-BRANDING-ID+2025`
- **Number of Sections:** 5 (from 5 MCT "Courses")
- **Sections to create:**
  - Section: "Modul 1: Pengenalan Kursus" (from MCT Course ID: 363)
  - Section: "Modul 2: Tentukan Siapa Dirimu" (from MCT Course ID: 364)
  - Section: "Modul 3: Bangun Personal Brand-mu" (from MCT Course ID: 365)
  - Section: "Modul 4: Membangun Personal Brand-mu" (from MCT Course ID: 366)
  - Section: "Modul 5: Kesimpulan" (from MCT Course ID: 367)

### Course 12: Mobile Literacy
- **MCT Category ID:** 15
- **Open edX Course ID:** `course-v1:SKILLOURFUTURE+MOBILE-LITERACY+2025`
- **Number of Sections:** 4 (from 4 MCT "Courses")
- **Sections to create:**
  - Section: "Apps, Websites & Technologies" (from MCT Course ID: 71)
  - Section: "Building Skills to Boost your Business" (from MCT Course ID: 133)
  - Section: "Learning and Discovering with your Mobile" (from MCT Course ID: 132)
  - Section: "Mobile Fundamentals" (from MCT Course ID: 70)

### Course 13: Soft Skills
- **MCT Category ID:** 1
- **Open edX Course ID:** `course-v1:SKILLOURFUTURE+SOFT-SKILLS+2025`
- **Number of Sections:** 7 (from 7 MCT "Courses")
- **Sections to create:**
  - Section: "[MV101] From Aspiring Mover to Mover Facilitator" (from MCT Course ID: 1)
  - Section: "Essential Facilitation Skills" (from MCT Course ID: 301)
  - Section: "Leadership in Action [LEVEL 1]" (from MCT Course ID: 8)
  - Section: "Leadership in Action [LEVEL 2]" (from MCT Course ID: 183)
  - Section: "Leadership in Action [LEVEL 3]" (from MCT Course ID: 185)
  - Section: "Storytelling - Tell Your Own Story" (from MCT Course ID: 187)
  - Section: "Wellbeing for Changemakers" (from MCT Course ID: 136)

### Course 14: Speak with Impact
- **MCT Category ID:** 46
- **Open edX Course ID:** `course-v1:SKILLOURFUTURE+SPEAK-IMPACT+2025`
- **Number of Sections:** 10 (from 10 MCT "Courses")
- **Sections to create:**
  - Section: "Module 0: Welcome" (from MCT Course ID: 434)
  - Section: "Module 1: Overcome Your Fear of Public Speaking" (from MCT Course ID: 435)
  - Section: "Module 2: The Secret to Impactful Communication" (from MCT Course ID: 437)
  - Section: "Module 3: Powerful Presentation Skills" (from MCT Course ID: 438)
  - Section: "Module 4: Master the Art of Storytelling" (from MCT Course ID: 439)
  - Section: "Module 5: Elevate your Stage Presence" (from MCT Course ID: 440)
  - Section: "Module 6: Own Your Voice as a Way of Life" (from MCT Course ID: 443)
  - Section: "Module 7: Public Speaking for Advocacy" (from MCT Course ID: 444)
  - Section: "Module 8: Public Speaking for Branding and Job Readiness" (from MCT Course ID: 445)
  - Section: "Module 9: Public Speaking for Young Entrepreneurs" (from MCT Course ID: 446)

### Course 15: Your Future in Green Jobs
- **MCT Category ID:** 31
- **Open edX Course ID:** `course-v1:SKILLOURFUTURE+GREEN-JOBS+2025`
- **Number of Sections:** 6 (from 6 MCT "Courses")
- **Sections to create:**
  - Section: "Module 1: Spot the Challenge" (from MCT Course ID: 345)
  - Section: "Module 2: Listen to Yourself" (from MCT Course ID: 346)
  - Section: "Module 3: Find Your Path" (from MCT Course ID: 347)
  - Section: "Module 4: Consider the Bigger Picture" (from MCT Course ID: 349)
  - Section: "Module 5: Unlock Your Inner Entrepreneur" (from MCT Course ID: 350)
  - Section: "Module 6: Build Your Green Career" (from MCT Course ID: 351)

---

## Summary Statistics

| Metric | Count | Notes |
|--------|-------|-------|
| **Open edX Courses to Create** | **15** | From 15 MCT Categories |
| **Open edX Sections to Create** | **81** | From 81 MCT "Courses" (workaround structure) |
| **MCT Lessons** | ~1,000+ | Each becomes an Open edX Unit |
| Users (already migrated) | 149,132 | Kajabi + MCT combined |
| Learning Paths | 13 | Will become Open edX Programs |

**CRITICAL REMINDER**: We are creating 15 courses, NOT 81. The 81 MCT "Courses" are distributed as sections across those 15 courses.

---

## Language Distribution

| Language | Sections |
|----------|----------|
| English (EN-US) | 73 |
| Vietnamese (VI-VN) | 3 |
| Indonesian (ID-ID) | 5 |

---

## Learning Paths → Open edX Programs

| MCT Learning Path | Open edX Program | Courses |
|-------------------|------------------|---------|
| Become An Entrepreneur | Entrepreneur Program | Course 3 |
| Speak with Impact | Communication Program | Course 14 |
| Employability | Career Readiness Program | Course 8 |
| Mastering Digital Tools | Digital Skills Program | Courses 2, 7 |
| Green Jobs Journey | Sustainability Program | Courses 5, 15 |

---

## Video Hosting

**Decision: Use Mux** (~$32/year)
- 100K free delivery minutes/month
- Automatic transcoding
- Built-in player

Videos currently on Azure Media Services (SAS tokens may expire).

---

## Authentication

**Decision: Social Login (Google/Microsoft)**
- Users migrated without passwords
- MCT users likely have Microsoft accounts

---

## Pre-Migration Checklist

- [x] MongoDB Atlas configured and connected
- [x] Users already migrated (149,132)
- [x] Structure mapping documented (Category→Course, Course→Section)
- [x] Video hosting decision made (Mux)
- [x] Learning paths mapped to Programs
- [x] ArgoCD/GitOps configuration updated for MongoDB Atlas
- [x] In-cluster MongoDB disabled in deploy/k8s/base/
- [ ] **WAITING FOR USER CONFIRMATION TO START MIGRATION**

---

## Files Reference

| File | Contents |
|------|----------|
| `exports/mct/courses.ndjson` | 15 categories with nested courses |
| `exports/mct/users.ndjson` | 69,419 user records |
| `exports/mct/learningpaths.ndjson` | 13 learning paths |
| `exports/mct/structure/course_content.ndjson` | Lesson content |

---

## Change Log

| Date | Change |
|------|--------|
| 2025-12-17 | Initial creation |
| 2025-12-17 | CORRECTED: Category=Course, Course=Section |
| 2025-12-17 | Added MongoDB Atlas status |
| 2025-12-17 | Clarified 15 courses to create, NOT 81 |
| 2025-12-17 | Updated ArgoCD/GitOps configuration for MongoDB Atlas |
| 2025-12-17 | Disabled in-cluster MongoDB in deploy/k8s/base/ |
