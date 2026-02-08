# MCT Platform Integration Spec

_Last verified: 2026-02-08 | Owner: Platform Eng_

## Status: RE-MIGRATION REQUIRED

**Verified 2026-02-08 via kubectl exec into LMS pod**: The `mereka-lms` Open edX instance is **empty**. Zero courses, zero programs, zero learner users, zero enrollments. The instance was intentionally rebuilt/reset.

All MCT source data is fully exported and mapped (30 categories, 178 courses, 833 lessons, 503 Mux videos, 2.3M enrollments). The data pipeline and mapping files are ready. A fresh migration into the current Open edX instance is needed.

**Decision**: Use **Scheme A** (category-level courses) with **Learning Path API** for Programs.

---

## 1. Authentication

### Azure AD Service-to-Service (OAuth2 Client Credentials)

| Parameter | Value | Notes |
|-----------|-------|-------|
| Token endpoint | `https://login.microsoft.com/{tenant_id}/oauth2/v2.0/token` | |
| Tenant ID | `b1aab053-6242-46ec-9cf8-bd02e63dd2da` | BBI Azure AD |
| Client ID | `caa4dce3-e49c-4c09-9160-031d51bfd2a9` | **SOF S2S-Client** (the ONLY whitelisted client) |
| API URI / Scope | `api://bf8331fd-17ed-4bcf-af5f-599db14ff4f4/.default` | UNDP App Registration (audience) |
| Grant type | `client_credentials` | |
| Secret expiry | **2026-08-07** | Stored in Infisical |

### CRITICAL: ServiceApplicationIds Whitelist

MCT's Azure App Service has a `ServiceApplicationIds` setting that whitelists which client app IDs can call the API. **Only `caa4dce3` (SOF S2S-Client) is whitelisted.** The UNDP S2S-Client (`f16cdc2f`) will always get HTTP 401.

### Required HTTP Headers

| Header | Value | Purpose |
|--------|-------|---------|
| `Authorization` | `Bearer {token}` | OAuth2 access token |
| `Accept` | `application/json` | Response format |
| `ClientType` | `service` | **Required** — without this, API returns 401 |

### Secrets Location

All credentials stored in Infisical (`secrets.mereka.io`):
- **MCT**: `/mereka-lms/mct/` (6 secrets: MCT_CLIENT_ID, MCT_CLIENT_SECRET, MCT_TENANT_ID, MCT_API_URI, MCT_BASE_URL, MCT_SECRET_EXPIRES)
- **Mux**: `/mereka-lms/mux/` (3 secrets: MUX_TOKEN_ID, MUX_TOKEN_SECRET, MUX_ENV_ID)

---

## 2. API Endpoints (Verified Working)

Base URL: `https://learn.skillourfuture.org`

### Catalog & Content

| Endpoint | Method | Returns | Volume |
|----------|--------|---------|--------|
| `/api/v1/organization` | GET | JSON array | 46 orgs |
| `/api/v1/Courses` | GET | JSON (Categories > Courses) | 15 categories, 81 courses |
| `/api/v2/Courses` | GET | JSON (same structure, localized) | 15 categories, 81 courses |
| `/api/v3/admin/categoriesAndCourses` | GET | JSON (Offers, CourseItems, Restricted) | 31 offers, 178 course items |
| `/api/v1/Groups` | GET | JSON array | 27 groups |

### Learning Paths

| Endpoint | Method | Returns | Notes |
|----------|--------|---------|-------|
| `/api/v1/learningpaths` | GET | JSON array (metadata) | 13 paths — names, descriptions, logos, cert status |
| `/api/v2/learningpaths` | GET | JSON (localized metadata) | Same 13 paths with localization |
| **`/api/v1/admin/learningpath/{id}/courses`** | **GET** | **JSON array (LP course composition)** | **THE KEY ENDPOINT** — returns courses assigned to an LP |
| `/api/v1/learner/learningpath/{id}/courses` | GET | JSON (learner view) | Only works for LPs with enrolled learners |

### Users & Enrollments

| Endpoint | Method | Returns | Volume |
|----------|--------|---------|--------|
| `/api/v1/admin/users?skip={n}&take={m}` | GET | JSON (UserDetails, paginated) | **705,610 users** |
| `/api/v1/Reports/Users` | GET | CSV (demographics) | **71,013 rows**, 19 MB |
| `/api/v1/Reports/Course/{courseId}/Learners` | GET | CSV (per-course enrollments) | **2,305,395 total** across 178 courses |
| `/api/v1/Certificates` | GET | JSON | **Always empty** (no certs configured) |

### Analytics (Admin)

| Endpoint | Method | Returns | Notes |
|----------|--------|---------|-------|
| `/api/v1/admin/analytics` | GET | JSON model | Categories (30), TopModules, LearnersEnrolledOverTime (1042 data points), CourseEnrollmentsAndCompletions (834 data points) |

### API Gotchas

1. **v1 Courses vs v3 CourseItems**: v1 returns 81 courses under 15 categories. v3 returns 178 CourseItems under 31 offers. **Use v3 for the full catalog.**
2. **Admin users pagination**: Default `take` is 100. Use `take=1000` for efficiency. Token refresh every ~50 pages.
3. **Certificates always empty**: The endpoint works but MCT has no certificates configured.
4. **Enrollment CSVs**: Use v3 CourseItems for course IDs, then hit `/api/v1/Reports/Course/{id}/Learners` per course. Generic enrollment endpoints return 404.
5. **CRITICAL — Singular vs plural in LP URLs**: The listing endpoint uses plural `/api/v1/learningpaths` but the detail endpoint uses **singular** `/api/v1/admin/learningpath/{id}/courses`. Using plural for detail returns 404.
6. **Misleading endpoint**: `/api/v1/learningpath/{id}/categoriesAndCourses` returns ALL organization categories, NOT LP-specific ones. Do NOT use for LP mapping.
7. **`learningPathId` query param ignored**: `/api/v3/admin/categoriesAndCourses?learningPathId={id}` returns ALL categories regardless of the LP ID parameter.

---

## 3. Data Volumes (Verified 2026-02-07)

| Data Set | Count | Size | Source |
|----------|-------|------|--------|
| Admin users (structured) | 705,610 | 208 MB | v1/admin/users (paginated) |
| Demographics (CSV) | 71,013 rows | 19 MB | v1/Reports/Users |
| Courses (v3 catalog) | 178 | 209 KB | v3/admin/categoriesAndCourses |
| Categories/Offers | 31 | (in catalog) | v3/admin/categoriesAndCourses |
| Enrollment records | 2,305,395 | 238 MB | Per-course CSVs |
| Organizations | 46 | 4 KB | v1/organization |
| Groups | 27 | 11 KB | v1/Groups |
| Learning paths | 13 | 7 KB | v1/learningpaths |
| Mux videos | 503 (500 ready, 3 errored) | N/A | Mux API |

### Mux Video Status

- 503 videos uploaded from MCT Azure Blob Storage to Mux
- 500 ready and serving (HLS playback via `stream.mux.com/{playback_id}.m3u8`)
- 3 errored: Financial Planning lessons 2610, 2611, 2612 (source Azure blob URLs expired before Mux could download)
- Mux environment: `d2pf0l73ablr4ghl1b607jpa2`

---

## 4. MCT-to-OpenEdX Terminology Mapping

| MCT Term | What It Actually Is | Open edX Equivalent |
|----------|---------------------|---------------------|
| **Category** | A full course (e.g., "Basic Microsoft") | **Course** (`course-v1:SKILLOURFUTURE+{SLUG}+2024`) |
| **Course** | A module/section within a category | **Section (Chapter)** |
| **Lesson** (CourseItem) | Individual content item (video, PDF, etc.) | **Unit (Vertical)** + XBlock |
| **Learning Path** | A bundle of categories (courses) | **Program** |
| **Group** | Organization unit with auto-enrollment rules | No direct equivalent (manual enrollment) |
| **Organization** | Country/Region/Institution | All mapped to `SKILLOURFUTURE` org |

### Content Type Mapping

| MCT FileType | Open edX XBlock |
|--------------|----------------|
| Video (PlaybackUrl) | `video` XBlock with Mux HLS URL |
| PDF (AuxPdfUrl) | `html` XBlock with embedded viewer |
| HTML content | `html` XBlock |
| SCORM/external link | `html` XBlock with iframe |

### Course ID Format (Scheme A — Decided)

```
course-v1:SKILLOURFUTURE+MCT-CAT-{category_id}+2024
```

Each MCT **category** becomes one Open edX **course**. MCT courses (modules) become sections/chapters within.

---

## 5. Learning Path API Discovery

### The Key Finding

The MCT API uses **SINGULAR** `learningpath` in detail URLs, NOT plural `learningpaths`. All previous attempts to map learning paths to courses failed because they used the plural form.

```
WRONG:  GET /api/v1/learningpaths/{id}/courses     → 404
RIGHT:  GET /api/v1/admin/learningpath/{id}/courses → 200
```

### Response Format

```json
[
  {
    "MappingId": 123,
    "CourseName": "Module 1: No Name",
    "CourseId": 102,
    "CategoryName": "Pursuing a career in Project Management",
    "CategoryId": 17,
    "NumPublishedLessons": 5,
    "NumPublishedQuizes": 0,
    "Priority": 1
  }
]
```

### Endpoints That Don't Work for LP Mapping

| Endpoint | Issue |
|----------|-------|
| `GET /api/v1/learningpaths/{id}/courses` | **404** — uses plural, wrong |
| `GET /api/v1/learningpaths/{id}/categories` | **404** — uses plural, wrong |
| `GET /api/v1/learningpath/{id}/categoriesAndCourses` | Returns ALL categories, not LP-specific |
| `GET /api/v3/admin/categoriesAndCourses?learningPathId={id}` | Ignores the parameter |
| `GET /api/v2/learningpaths/{id}` | No detail endpoint in v2 |

---

## 6. Complete Learning Path → Category → Course Mapping

### Summary

| LP ID | Name | Categories | Courses | Certificate | Status |
|-------|------|------------|---------|-------------|--------|
| 13 | Project Manager | 5 | 28 | Yes | **Active** |
| 14 | Data Analyst | 5 | 29 | Yes | **Active** |
| 15 | Developer | 5 | 31 | Yes | **Active** |
| 16 | Administrative Professional | 5 | 28 | Yes | **Active** |
| 17 | Digital Marketer | 5 | 28 | Yes | **Active** |
| 19 | X - Certification QA Testing | 0 | 0 | No | Empty/Test |
| 20 | QA Testing Certificate \| Common | 0 | 0 | No | Empty/Test |
| 21 | Mastering Digital Tools | 0 | 0 | No | Empty (LP 21 empty, but Cat 28 has content) |
| 22 | TEST Virtual Assistant | 0 | 0 | No | Empty/Test |
| 23 | Embark on a Green Jobs Journey | 1 | 6 | No | **Active** |
| 24 | Employability | 0 | 0 | No | Empty (LP 24 empty, but Cat 14 has content) |
| 25 | Speak with Impact | 1 | 10 | No | **Active** |
| 26 | Become An Entrepreneur | 1 | 7 | No | **Active** |

**8 active learning paths** → Open edX Programs. 5 empty/test learning paths to skip.

### Career Track Learning Paths (LPs 13-17)

These 5 career-track learning paths share **4 common foundation categories**:

| Foundation Category | Cat ID | Courses | Lessons |
|---------------------|--------|---------|---------|
| Basic Microsoft | 16 | 12 | 136 |
| Soft Skills | 1 | 6 | 44 |
| Employability | 14 | 5 | varies |
| AI Fluency | 24 | 1 | 12 |

Each career track adds its **specialty category** on top:

| Learning Path | Specialty Category | Cat ID | Specialty Courses |
|---------------|--------------------|--------|-------------------|
| Project Manager | Pursuing a career in Project Management | 17 | 4 |
| Data Analyst | Pursuing a career in Data Analytics | 19 | 5 |
| Developer | Developer | 20 | 7 |
| Administrative Professional | Careering as an Administrative Professional | 22 | 4 |
| Digital Marketer | Digital Marketing Strategies | 21 | 4 |

**Open edX Programs mapping**: Each career-track Program will contain **5 category-level courses** (1 specialty + 4 foundation).

### Standalone Learning Paths (LPs 23, 25, 26)

| Learning Path | Category | Cat ID | Courses |
|---------------|----------|--------|---------|
| Embark on a Green Jobs Journey | Your Future in Green Jobs | 31 | 6 |
| Speak with Impact | Speak with Impact | 46 | 10 |
| Become An Entrepreneur | Become an Entrepreneur | 45 | 7 |

**Open edX Programs mapping**: Each standalone Program contains **1 category-level course**.

### Detailed Course Listing by Learning Path

#### LP 13: Project Manager (5 categories, 28 courses)

**Specialty — Cat 17: Pursuing a career in Project Management**
| Course ID | Name | Lessons | Quizzes |
|-----------|------|---------|---------|
| 102 | Module 1: No Name | 5 | 0 |
| 103 | Module 2: Getting Started with Lists | 7 | 0 |
| 106 | Module 3: Using Microsoft Planner | 6 | 0 |
| 107 | Module 4: Staying Organized with Microsoft Project | 6 | 0 |

+ Foundation categories: Basic Microsoft (12), Soft Skills (6), AI Fluency (1), Employability (5)

#### LP 14: Data Analyst (5 categories, 29 courses)

**Specialty — Cat 19: Pursuing a career in Data Analytics**
| Course ID | Name | Lessons | Quizzes |
|-----------|------|---------|---------|
| 149 | Module 1: Start a career in Data Analytics | 5 | 0 |
| 151 | Module 2: Starting Forms | 6 | 0 |
| 153 | Module 3: Building Processes with Power Automate | 4 | 0 |
| 155 | Module 4: Data Analysis in Excel | 4 | 0 |
| 157 | Module 5: Utilizing Power BI Desktop | 6 | 0 |

+ Foundation categories: Basic Microsoft (12), Soft Skills (6), AI Fluency (1), Employability (5)

#### LP 15: Developer (5 categories, 31 courses)

**Specialty — Cat 20: Developer**
| Course ID | Name | Lessons | Quizzes |
|-----------|------|---------|---------|
| 159 | Module 1: Get started with web development using VS Code | varies | 0 |
| 161 | Module 2: Describe cloud computing | varies | 0 |
| 162 | Module 3: Build your first HTML webpage | varies | 0 |
| 163 | Module 4: Use CSS styles in a webpage | varies | 0 |
| 164 | Module 5: JavaScript arrays and loops | varies | 0 |
| 165 | Module 6: Learning Data Engineering Foundation | varies | 0 |
| 166 | Module 7: SQL Programming | varies | 0 |
| 271 | Module 8: iOS App Development | varies | 0 |

+ Foundation categories: Basic Microsoft (12), Soft Skills (6), AI Fluency (1), Employability (5)

#### LP 16: Administrative Professional (5 categories, 28 courses)

**Specialty — Cat 22: Careering as an Administrative Professional**
| Course ID | Name | Lessons | Quizzes |
|-----------|------|---------|---------|
| 172 | Module 1: Career Opportunities in Administrative Professional Field | 7 | 0 |
| 174 | Module 2: Basic Competency in Administrative Professional | 3 | 0 |
| 175 | Module 3: Enhance skills in Administrative Professional | 5 | 0 |
| 268 | Modul 4: Studi Kasus | 2 | 0 |

+ Foundation categories: Basic Microsoft (12), Soft Skills (6), AI Fluency (1), Employability (5)

#### LP 17: Digital Marketer (5 categories, 28 courses)

**Specialty — Cat 21: Digital Marketing Strategies**
| Course ID | Name | Lessons | Quizzes |
|-----------|------|---------|---------|
| 167 | Module 1: Recognize the Importance of Digital Marketing | 1 | 0 |
| 168 | Module 2: Determining Marketing Channels | 4 | 0 |
| 169 | Module 3: Creating a Simple Dashboard & Report Using Ms. Excel | 3 | 0 |
| 267 | Studi Kasus | 2 | 0 |

+ Foundation categories: Basic Microsoft (12), Soft Skills (6), AI Fluency (1), Employability (5)

#### LP 23: Embark on a Green Jobs Journey (1 category, 6 courses)

**Cat 31: Your Future in Green Jobs**
| Course ID | Name | Lessons | Quizzes |
|-----------|------|---------|---------|
| 288 | Module 1: Spot the Challenge | varies | 0 |
| 289 | Module 2: Listen to Yourself | varies | 0 |
| 290 | Module 3: Find Your Path | varies | 0 |
| 291 | Module 4: Consider the Bigger Picture | varies | 0 |
| 292 | Module 5: Unlock Your Inner Entrepreneur | varies | 0 |
| 293 | Module 6: Build Your Green Career | varies | 0 |

#### LP 25: Speak with Impact (1 category, 10 courses)

**Cat 46: Speak with Impact**
| Course ID | Name | Lessons | Quizzes |
|-----------|------|---------|---------|
| 302 | Module 0: Welcome - this is not your typical course | varies | 0 |
| 303 | Module 1: Overcome Your Fear of Public Speaking | varies | 0 |
| 304 | Module 2: The Secret to Impactful Communication | varies | 0 |
| 305 | Module 3: Powerful Presentation Skills | varies | 0 |
| 306 | Module 4: Master the Art of Storytelling | varies | 0 |
| 307 | Module 5: Elevate your Stage Presence | varies | 0 |
| 308 | Module 6: Own Your Voice as a Way of Life | varies | 0 |
| 309 | Module 7: Public Speaking for Advocacy | varies | 0 |
| 310 | Module 8: Public Speaking for Branding and Job Readiness | varies | 0 |
| 311 | Module 9: Public Speaking for Young Entrepreneurs | varies | 0 |

#### LP 26: Become An Entrepreneur (1 category, 7 courses)

**Cat 45: Become an Entrepreneur**
| Course ID | Name | Lessons | Quizzes |
|-----------|------|---------|---------|
| 294 | Course Intro: Entrepreneurial Myths & Entrepreneurial Mindset | varies | 0 |
| 295 | Module 1: Start with What Matters - Problem Definition | varies | 0 |
| 296 | Module 2: From Problems to Possibilities - Ideation | varies | 0 |
| 297 | Module 3: Market Testing for Your Idea - Prototyping | varies | 0 |
| 298 | Module 4: Storytelling Your Prototype and Build Your BMC | varies | 0 |
| 299 | Module 5: Building a Team That Can Build the Dream | varies | 0 |
| 300 | Module 6: Finding Available Support in Your Ecosystem | varies | 0 |

---

## 7. Groups & Auto-Enrollment Rules

MCT Groups define auto-enrollment rules based on user profile answers. 27 groups total.

### Career-Track Groups (auto-enroll by learning pathway choice + country)

| Group | Organization | Pathway Filter | Country Filter |
|-------|-------------|----------------|----------------|
| Project Management \| Id | Indonesia | Project manager, Explore all | Indonesia |
| Project Management \| My | Malaysia | Project Manager | — |
| Data Analyst \| Id | Indonesia | Data analyst, Explore all | — |
| Data Analyst \| My | Malaysia | Data Analyst | — |
| Developer \| Id | Indonesia | Developer, Explore all | — |
| Developer \| My | Malaysia | Developer | — |
| Administrative Professional \| Id | Indonesia | Administrative Professional, Explore all | — |
| Administrative Professional \| My | Malaysia | Administrative Professional | — |
| Digital Marketer \| Id | Indonesia | Digital Marketer, Explore all | Indonesia |
| Digital Marketer \| My | Malaysia | Digital Marketer | — |
| Administrative Professional \| Th | Thailand | Administrative Professional | — |

### Special-Program Groups

| Group | Pathway Filter |
|-------|----------------|
| Green Jobs Pathway | Green Jobs, Explore all, Employability, Other |
| Speak with Impact | Explore all |
| Become an Entrepreneur | Explore all |

### Country/Institution Groups (no pathway filter)

Vietnam, Philippines, Japan, China, Pakistan + 5 Indonesian university groups + Movers Team

### Open edX Implication

Groups can be approximated by:
1. Bulk enrollment scripts (for initial migration)
2. Authentik SSO with group-based auto-enrollment rules (for ongoing)

---

## 8. Categories Without Learning Paths (19 of 30)

These categories have content but are NOT part of any learning path. They will become standalone courses in Open edX without Program membership.

| Cat ID | Name | Courses | Published Lessons | Notes |
|--------|------|---------|-------------------|-------|
| 1 | Soft Skills | 8 | 44 | Shared in career tracks but also standalone |
| 4 | X - Productivity with Microsoft 365 (Bahasa) | 8 | 41 | Indonesian version |
| 15 | Mobile Literacy | 4 | 21 | |
| 16 | Basic Microsoft | 18 | 136 | Shared in career tracks but also standalone |
| 24 | AI Fluency | 3 | 28 | Shared in career tracks but also standalone |
| 27 | Digital Literacy | 6 | 86 | |
| 28 | [VN] Mastering Digital Tools | 9 | varies | Vietnamese content |
| 29 | TEST Virtual Assistant | 2 | varies | Test category |
| 30 | Climate Education | 1 | 7 | |
| 32 | FOW (ENG) Personal Branding | 5 | 23 | |
| 33 | FOW (IND) Personal Branding | 5 | 22 | Indonesian version of 32 |
| 34 | FOW (ENG) Personal Well-being | 5 | 1 | Minimal content |
| 35 | FOW (ENG) Personal Finance | 7 | 19 | |
| 36 | FOW (ENG) Managing Your First Client | 7 | **0** | No content uploaded |
| 37 | FOW (ENG) Freelancing 101 | 6 | **0** | No content uploaded |
| 38 | FOW (ENG) Skills Profiling | 6 | **0** | No content uploaded |
| 39 | FOW (ENG) Securing Your First Client | 6 | **0** | No content uploaded |
| 40 | FOW (ENG) Securing Your First Job | 6 | **0** | No content uploaded |
| 41 | FOW (ENG) Thriving In Your Job | 6 | **0** | No content uploaded |
| 44 | Content Creation | 1 | 6 | |
| 47 | Gaming Garage with HP | 1 | 2 | |

**Note**: Categories 1, 16, 14, and 24 appear in career-track learning paths as "foundation" categories BUT also exist independently. Courses within them are shared across multiple Programs.

**Note**: FOW categories 36-41 have **0 published lessons** — no content was uploaded in MCT. These can be created as placeholder courses or skipped entirely.

---

## 9. Certificates & Quizzes

### MCT Certificate Status

- **API endpoint**: `GET /api/v1/Certificates` — returns `{"courseCertificates": [], "learningPathCertificates": []}`
- **Learning path certificate flags**: LPs 13-17 (career tracks) have `certificateStatus: 1` (enabled). All other LPs have `certificateStatus: 0`.
- **73 courses** have `IsCertificate=true` with **11 unique template IDs** (1, 2, 3, 6, 8, 9, 10, 11, 13, 14)
- **Certificate endpoint for learners**: `GET /api/v1/learner/learningpath/{id}/Certificate` — returns LP certificate data (only if learner has completed the LP).
- **No certificate templates exported**: 116+ endpoints tested — MCT stores certificates internally; no exportable templates found via API.
- **Certificate issuance can be derived**: Cross-reference `IsCertificate=true` courses with enrollments at 100% completion.

### Quiz Data (COMPLETE — Ready for Migration)

- **510 quiz questions** with full answers in `course_content.ndjson` (118 quizzes across 20+ courses)
- **106 Exam-type** quizzes and **12 Practice-type** quizzes
- Per quiz: QuizData (Id, Title, QuizType, TotalScore, PassingPercent, NumOfAttempts, IsSurvey, IsShuffleQuestions)
- Per question: QuestionTypeId (1=single choice, 2=multiple choice), QuestionContent (HTML), AnswerOptions, Answer (correct answers), UserAnswerExplanation
- Ready for conversion to Open edX Problem Builder format
- **No per-user quiz results available** — only Average Score in enrollment CSVs

### Open edX Certificate Approach

Certificates must be **configured from scratch** in Open edX:
1. Enable certificates in CMS for each course
2. Design certificate templates (HTML) — may need to screenshot from MCT admin UI for reference
3. Set completion requirements per course
4. For Programs: use Open edX Program Certificates (requires Discovery + Credentials services)

---

## 10. User Profiles & Demographics

### Demographics CSV Fields (71,013 active learners)

```
Contact                    # Phone number (primary identifier in MCT)
First Name
Last Name
My groups                  # Comma-separated group memberships
Nickname
When were you born?        # Date of birth
Gender
Do you consider yourself... # Marginalized/disadvantaged group (free text)
Which Country are you from?
Which city are you from?
Which province are you from?
University                 # Institution name
Source                     # How they found the platform
Consent                    # Data consent flag
Referral Partner
Linkedin Profile Link
Which learning pathway are you interested in?
```

### Admin Users API Fields (705,610 total users)

Each user in `UserDetails` array has:
- Identity fields (Contact/phone, Name)
- Profile fields (structured same as demographics)
- Group memberships
- Enrollment status per course
- Last active date

### User Count Discrepancy

| Source | Count | What It Includes |
|--------|-------|-----------------|
| Demographics CSV (`/api/v1/Reports/Users`) | 71,013 | Active learners with profile data |
| Admin Users API (`/api/v1/admin/users`) | 705,610 | ALL registered users (including inactive, test, no-profile) |

**For migration**: Use the demographics CSV (71K users). Admin users API has too many ghost/inactive records.

### Authentication in Open edX

- **Method**: SSO via Authentik (OIDC)
- **No password migration**: Users will authenticate through Authentik, not with MCT passwords
- **User matching**: Match by email or phone number during enrollment import

---

## 11. Export Pipeline & Data Inventory

### Export Scripts Location

```
VPS: ~/projects/mereka-lms/
  scripts/migrations/mct/mct_export.py   # Python export (current)
  scripts/migrations/mct/mct-export.mjs  # Node.js export (legacy, still works)
```

### Usage

```bash
cd ~/projects/mereka-lms

# Full export (all 11 resources):
infisical run --env prod --path /mereka-lms/mct -- \
  python3 scripts/migrations/mct/mct_export.py

# Delta export (users + enrollments only):
infisical run --env prod --path /mereka-lms/mct -- \
  python3 scripts/migrations/mct/mct_export.py --delta

# Specific resources:
infisical run --env prod --path /mereka-lms/mct -- \
  python3 scripts/migrations/mct/mct_export.py --resources admin_users,enrollments
```

### Available Resources

`organizations`, `courses_v1`, `courses_v2`, `courses_v3`, `groups`, `learningpaths_v1`, `learningpaths_v2`, `certificates`, `admin_users`, `reports_users`, `enrollments`

### Exported Data Inventory (on VPS)

```
~/projects/mereka-lms/exports/mct/
├── raw_api/
│   ├── admin_users.json                    # 208 MB, 705,610 users
│   ├── reports_users.csv                   # 19 MB, 71,013 rows
│   ├── categories_and_courses_v3.json      # 209 KB, 31 offers, 178 course items
│   ├── courses_v1.json                     # 15 categories, 81 courses
│   ├── courses_v2.json                     # Localized version
│   ├── organizations.json                  # 46 organizations
│   ├── groups.json                         # 27 groups
│   ├── learningpaths_v1.json               # 13 learning paths (metadata)
│   ├── learningpaths_v2.json               # Localized version
│   └── certificates.json                   # Always empty
├── enrollments_by_course/                  # 178 CSVs
│   ├── course_*.csv                        # Per-course enrollment records
│   └── (total: 2,305,395 enrollment records)
├── courses.ndjson                          # 178 records (original Dec 2025 export)
├── enrollments.ndjson                      # 2,303,026 records
├── users.ndjson                            # 69,419 records
├── learningpaths.ndjson                    # 13 records
├── groups.ndjson                           # 27 records
├── organizations.ndjson                    # 46 records
├── structure/
│   ├── course_content.ndjson               # 356 records
│   └── course_metadata.ndjson              # 356 records
├── video_mapping_openedx.json              # 30 categories → 503 Mux videos
├── complete_lesson_mapping.json            # 30 categories → 833 lessons
├── mux_upload_complete.json                # 503 Mux asset/playback IDs
└── last_export.json                        # Export manifest
```

### Admin Analytics Data (NEW — exported 2026-02-08)

Endpoint: `GET /api/v1/admin/analytics` — saved to `raw_api/admin_analytics.json` (180 KB)

**Platform-wide metrics**:
- 30 categories, 227 courses, 1,647 lessons, 78 quizzes
- 71,011 enrolled learners, 24,906 course completions
- Daily enrollment time series: 2023-04-03 to 2026-02-07 (1,042 data points)
- Daily completion time series: 2023-04-17 to 2026-02-08 (834 data points)

**Per-category enrollment and completion stats** (top 15):

| Cat ID | Category | Enrollments | Completions | Completion % |
|--------|----------|-------------|-------------|-------------|
| 16 | Basic Microsoft | 661,207 | 10,565 | 1.6% |
| 1 | Soft Skills | 325,910 | 3,121 | 0.96% |
| 20 | Developer | 278,446 | 1,201 | 0.43% |
| 14 | Employability | 267,949 | 2,935 | 1.1% |
| 21 | Digital Marketing | 254,322 | 732 | 0.29% |
| 19 | Data Analytics | 207,630 | 1,293 | 0.62% |
| 17 | Project Management | 170,076 | 1,118 | 0.66% |
| 22 | Admin Professional | 138,001 | 619 | 0.45% |
| 24 | AI Fluency | 52,224 | 1,090 | 2.09% |
| 46 | Speak with Impact | 8,633 | 111 | 1.29% |
| 31 | Green Jobs | 5,401 | 221 | 4.09% |
| 28 | [VN] Digital Tools | 2,620 | 239 | 9.12% |
| 27 | Digital Literacy | 1,041 | 323 | 31.0% |
| 45 | Become Entrepreneur | 705 | 322 | 45.7% |
| 15 | Mobile Literacy | 504 | 273 | 54.2% |

**Note**: FOW categories 36-41 and TEST Virtual Assistant (29) have 0 enrollments.

### Data NOT Yet Exported

- **Learning path course composition**: Need to export via `/api/v1/admin/learningpath/{id}/courses` for each LP
- **Individual lesson content**: Actual video URLs, PDF URLs, HTML content per lesson

---

## 12. Data Field Reference

### course_content.ndjson (per course)

```
Top-level: courseId, categoryId, categoryName, courseName, courseDescription,
           CourseItems[], LearningFlowType, IsCertificateEnabled

CourseItem: CourseItemId, ItemType, DisplayOrder, Data{}, CompletionPercentage,
            IsPublished, VideoProgressDuration, Uuid

CourseItem.Data: Id, Title, Description, Url, ThumbnailUrl, DownloadUrl,
                 PlaybackUrl, TotalDuration, Tags, FileType, VideoTextTracks,
                 AuxPdfUrl, AuxPptUrl, AuxVideoUrl, AuxWordUrl, AuxZipUrl
```

### users.ndjson (demographics)

```
Contact, First Name, Last Name, Nickname, Gender, Source, University,
Consent, My groups, Referral Partner, Linkedin Profile Link,
Which Country are you from?, Which city are you from?,
Which province are you from?, When were you born?,
Which learning pathway are you interested in?,
Do you consider yourself to be part of a marginalised...
```

### enrollments.ndjson (per enrollment)

```
Contact, Name, Course, courseId, Course Completion Percentage,
Lessons Completed, Quizzes Completed, Average Score
```

### Admin analytics model keys

```
Categories (30), Courses, TopModulesByEnrollment (4), TopModulesByCompletion (4),
ModulesWithNoEnrollment, ModulesWithZeroCompletion, LearnersEnrolledOverTime (1042),
CourseEnrollmentsAndCompletionsOverTime (834), ModulesNotCompletedList (99),
ModulesWithNoEnrollmentsList (99)
```

---

## 13. Course Key History & Naming Inconsistency

Three different naming conventions were used across migration scripts. This caused duplicate courses and required cleanup scripts.

| Convention | Example | Used by |
|------------|---------|---------|
| `MCT-{course_id}+course` | `MCT-22+course` | `build_course_packages.py` (early approach) |
| `MCTCAT-{category_id}+RUN-{id}` | `MCTCAT-24+RUN-24` | `build_category_packages.py` (canonical) |
| `MCT-{category_id}+course` | `MCT-24+course` | `build_courses_with_mux.py`, `video_mapping_openedx.json` |

### Previous Impact (now moot — instance is empty)

- Duplicate courses were created in Open edX
- `cleanup_duplicate_courses.py` deleted old-format courses
- `migrate_mct22_enrollments.py` moved 45,684 enrollments from empty `MCT-22+course` to `MCT-22+RUN-22`

### Course Key Scheme for Re-Migration (DECIDED: Scheme A)

**Scheme A — Category-Level Courses** (30 courses):

```
course-v1:SKILLOURFUTURE+MCT-CAT-{category_id}+2024
```

Examples:
- `course-v1:SKILLOURFUTURE+MCT-CAT-16+2024` (Basic Microsoft)
- `course-v1:SKILLOURFUTURE+MCT-CAT-45+2024` (Become an Entrepreneur)

Each MCT category becomes 1 Open edX course. MCT "courses" (modules) become sections within.

### Program Keys (from Learning Path API)

8 Programs to create:

| Program | Course Keys (category-level) |
|---------|------------------------------|
| Project Manager (LP 13) | MCT-CAT-17, MCT-CAT-16, MCT-CAT-1, MCT-CAT-24, MCT-CAT-14 |
| Data Analyst (LP 14) | MCT-CAT-19, MCT-CAT-16, MCT-CAT-1, MCT-CAT-24, MCT-CAT-14 |
| Developer (LP 15) | MCT-CAT-20, MCT-CAT-16, MCT-CAT-1, MCT-CAT-14, MCT-CAT-24 |
| Admin Professional (LP 16) | MCT-CAT-22, MCT-CAT-16, MCT-CAT-1, MCT-CAT-24, MCT-CAT-14 |
| Digital Marketer (LP 17) | MCT-CAT-16, MCT-CAT-1, MCT-CAT-14, MCT-CAT-24, MCT-CAT-21 |
| Green Jobs Journey (LP 23) | MCT-CAT-31 |
| Speak with Impact (LP 25) | MCT-CAT-46 |
| Become An Entrepreneur (LP 26) | MCT-CAT-45 |

---

## 14. Script Status Matrix

| Script | Lines | Status | Purpose |
|--------|-------|--------|---------|
| `mct_export.py` | 326 | **Active** | Data export pipeline (Infisical) |
| `mct-export.mjs` | 937 | Legacy | JS export (still works, superseded) |
| `transform_data.py` | 651 | **Active** | MCT NDJSON -> OpenEdX CSV/JSON |
| `build_category_packages.py` | 416 | **Active** | OLX packages (Category=Course) |
| `build_courses_with_mux.py` | 270 | **Active** | OLX with Mux video XBlocks |
| `build_course_packages.py` | 404 | Superseded | OLX (1:1 course mapping, wrong) |
| `create_video_mapping.py` | 156 | **Active** | Joins MCT lessons with Mux |
| `upload_videos_to_mux.py` | 237 | Done | Mux upload (503 complete) |
| `openedx_bulk_import_mct.py` | 382 | **Active** | Bulk user+enrollment import |
| `import_with_verification.py` | 224 | **Active** | Course import with verification |
| `link_courses_to_programs.py` | 308 | **Needs Update** | Currently uses Scheme B keys; must update to Scheme A with LP API data |
| `validate_course_content.py` | 157 | **Active** | Post-import validation |
| `cleanup_duplicate_courses.py` | 269 | Done | No longer needed (instance empty) |
| `migrate_mct22_enrollments.py` | 207 | Done | No longer needed |
| `download_thumbnails.py` | 157 | **Broken** | Wrong path (/home/dev/ not /home/gurpreet/) |
| `create_programs*.py` (5 files) | ~1000 | Superseded | Multiple program creation iterations |
| `fix_mux_titles.py` | 100 | Done | One-time Mux title fix |

---

## 15. Live Open edX Instance State (Verified 2026-02-08)

Queried via `kubectl exec` into the LMS pod in `mereka-lms` namespace.

| Entity | Expected (per migration docs) | **Actual (live)** |
|--------|-------------------------------|-------------------|
| Courses (modulestore) | 30 | **0** |
| Programs (Discovery) | 13 | **0** |
| Users | 68,565 | **7** (test/admin only) |
| Enrollments | 621,430 | **1** (test health-check) |

### Users in the system

| Username | Email | Staff | Superuser |
|----------|-------|-------|-----------|
| login_service_user | login_service_user@fake.email | No | No |
| oidc-test-* (x2) | oidc-test-*@mereka.io | No | No |
| authentik_test | authentik_test@mereka.io | Yes | No |
| admin | admin@mereka.io | Yes | Yes |
| gurpreet@biji-biji.com | gurpreet@biji-biji.com | Yes | Yes |
| malasari@mereka.my | malasari@mereka.my | Yes | Yes |

### Infrastructure (running)

Full Tutor-deployed stack with 25 pods: 2 LMS replicas + 2 workers, CMS + worker, Discovery, Credentials, Ecommerce + worker, MFE, MySQL, Redis, Elasticsearch, Forum, Notes, SMTP, Caddy, xqueue, 3 promtail pods.

---

## 16. Known Issues and Gaps

1. **3 Mux video errors**: Financial Planning lessons 2610, 2611, 2612 need re-upload from a valid source URL.
2. **Certificates from scratch**: MCT has no exportable certificate templates. Must design new ones in Open edX. 73 courses have `IsCertificate=true` with 11 unique template IDs — may need to screenshot from MCT admin UI.
3. **User count discrepancy**: Demographics CSV has 71,013 rows. Admin users API returns 705,610 (all show `IsActive=false`). Use demographics for migration.
4. **Client secret expires 2026-08-07**: Must rotate before expiry. `az ad app credential reset --id caa4dce3-e49c-4c09-9160-031d51bfd2a9`
5. **No incremental/delta API**: MCT has no "modified since" filter. Delta exports re-download all data.
6. **FOW categories (36-41) have 0 lessons AND 0 enrollments**: No content uploaded in MCT. Recommend skipping these in migration.
7. **`link_courses_to_programs.py` needs rewrite**: Currently uses Scheme B (individual course keys) with 1:1 LP→Category mapping. Must update to Scheme A with multi-category LP composition from API.
8. **CRITICAL: Old mapping was WRONG**: The previous `link_courses_to_programs.py` mapped each Learning Path to **one** category only (inferred by name matching). The LP API reveals career-track LPs actually contain **5 categories each** (specialty + 4 foundation). The old mapping missed 80% of the courses in career-track Programs.
9. **LP course composition not yet exported**: Need to run export script hitting `/api/v1/admin/learningpath/{id}/courses` for all 13 LPs and save to `raw_api/`.
10. **Vietnamese content**: Category 28 (Mastering Digital Tools) is in Vietnamese. Course key slugs will have transliterated names.
11. **No enrollment timestamps**: Only aggregate time series available (from admin analytics), not per-user enrollment dates.
12. **No per-user quiz results**: Only Average Score in enrollment CSVs. 510 quiz questions are ready for migration but individual attempt history is not available.
13. **API surface fully mapped**: 116+ endpoints tested — no additional data available via MCT API.

---

## 17. Re-Migration Plan

### Pre-Migration Checklist

1. [x] Export all MCT data (courses, users, enrollments, videos)
2. [x] Map MCT learning paths to categories via API
3. [x] Verify Open edX instance is ready (empty, Tutor deployed)
4. [x] Decide on course key scheme (Scheme A — category-level)
5. [ ] Export learning path course composition to `raw_api/`
6. [ ] Update `link_courses_to_programs.py` with Scheme A keys + LP API data
7. [ ] Build OLX packages with Scheme A keys
8. [ ] Fix `download_thumbnails.py` path issue

### Migration Steps

1. Build 30 OLX packages (one per category) with Scheme A keys
2. Import courses into CMS via `import_with_verification.py`
3. Import 71K users from demographics CSV via `openedx_bulk_import_mct.py`
4. Create 8 Programs in Discovery (from LP API data)
5. Link courses to Programs (updated `link_courses_to_programs.py`)
6. Import enrollments (map course IDs to Scheme A keys)
7. Validate via `validate_course_content.py`
8. Verify Mux video playback in Video XBlocks
9. Configure Authentik SSO for user login
10. Set up certificate templates (if needed)

### Post-Migration Validation

- [ ] All 30 courses visible in LMS
- [ ] 8 Programs visible with correct course composition
- [ ] Mux videos play in at least 3 sample courses
- [ ] Sample user can log in via Authentik SSO
- [ ] Enrollment counts match expected numbers
- [ ] Certificate generation works for career-track courses

---

## 18. Related Documents

| Document | Path | Status |
|----------|------|--------|
| Migration status | `docs/migrations/mct/MCT_MIGRATION_STATUS.md` | Needs update (instance rebuilt) |
| OpenEdX mapping | `docs/migrations/mct/MCT_TO_OPENEDX_MAPPING.md` | Needs update (Scheme A + LP API) |
| API reference | `docs/migrations/mct/API_COMPLETE_REFERENCE.md` | Needs update (add LP endpoints) |
| Export guide | `docs/migrations/mct/EXPORT_GUIDE.md` | Updated 2026-02-08 |
| Video migration | `docs/migrations/mct/VIDEO_MIGRATION.md` | Updated 2026-02-08 |
| Data model | `docs/migrations/mct/DATA_MODEL_COMPLETE.md` | Needs count updates |
| Secrets management | `specs/secrets-management.md` | Current |
| LP research data | `/tmp/mct-learning-path-research.json` | Move to exports/mct/ |
