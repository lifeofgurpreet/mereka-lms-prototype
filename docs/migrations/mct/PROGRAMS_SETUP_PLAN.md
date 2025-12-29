# MCT Learning Pathways to Open edX Programs - Setup Plan

**Document Version:** 1.0
**Date:** 2025-12-18
**Status:** Planning Phase
**Target Environment:** staging.academy.mereka.io

---

## Executive Summary

This document outlines the complete plan for migrating 13 MCT Learning Pathways to Open edX Programs. Programs are collections of related courses that learners complete to earn credentials. The migration will enable structured learning journeys and program-level certificates in Open edX.

**Key Statistics:**
- **Total Learning Pathways:** 13
- **Total Courses to Map:** 69 courses across all pathways
- **Pathways with Certificates:** 10 (77%)
- **Pathways Requiring Order:** 3 (23%)
- **Pathways Needing Investigation:** 2 (QA Testing pathways)

---

## Table of Contents

1. [Prerequisites and Architecture](#prerequisites-and-architecture)
2. [Learning Pathway Inventory](#learning-pathway-inventory)
3. [Program Type Recommendations](#program-type-recommendations)
4. [Detailed Program Mappings](#detailed-program-mappings)
5. [Implementation Steps](#implementation-steps)
6. [API Integration Guide](#api-integration-guide)
7. [Certificate Configuration](#certificate-configuration)
8. [Troubleshooting](#troubleshooting)
9. [Verification Checklist](#verification-checklist)

---

## Prerequisites and Architecture

### Required Services

| Service | Purpose | Status Check Command |
|---------|---------|---------------------|
| **LMS** | Core learning platform | `kubectl get pods -n mereka-lms -l app=lms` |
| **Discovery** | Course catalog & program management | `kubectl get pods -n mereka-lms -l app=discovery` |
| **Credentials** | Certificate issuance | `kubectl get pods -n mereka-lms -l app=credentials` |

### Service Architecture

```
┌─────────────┐     ┌─────────────────┐     ┌──────────────────┐
│    LMS      │────▶│   Discovery     │────▶│  Credentials     │
│  Courses    │     │  - Programs     │     │  - Program Certs │
│  Enrollments│     │  - Catalog      │     │  - Course Certs  │
└─────────────┘     └─────────────────┘     └──────────────────┘
      │                     │                        │
      ▼                     ▼                        ▼
   User Data          Program Metadata        Certificate Awards
```

### Enable Services (If Not Running)

```bash
# Enable Discovery service
tutor plugins enable discovery
tutor config save
./infrastructure/tutor/apply-patches.sh
tutor k8s launch

# Enable Credentials service (for certificates)
tutor plugins enable credentials
tutor config save
./infrastructure/tutor/apply-patches.sh
tutor k8s launch

# Verify services are running
kubectl get pods -n mereka-lms | grep -E "discovery|credentials"
```

---

## Learning Pathway Inventory

### Summary Table

| LP ID | Name | Organization | Courses | Certificate | Order Required | Priority |
|-------|------|-------------|---------|-------------|----------------|----------|
| 26 | Become An Entrepreneur | Default | 8 | Yes | Yes | High |
| 25 | Speak with Impact | Default | 10 | Yes | Yes | High |
| 23 | Embark on a Green Jobs Journey | Default | 7 | Yes | Yes | High |
| 24 | Employability | Default | 7 | No | No | Medium |
| 15 | Developer | Default | 8 | Yes | No | High |
| 16 | Administrative Professional | Default | 4 | Yes | No | High |
| 17 | Digital Marketer | Default | 5 | Yes | No | High |
| 13 | Project Manager | Default | 4 | Yes | No | High |
| 14 | Data Analyst | Default | 5 | Yes | No | High |
| 21 | Mastering Digital Tools | Vietnam | 9 | No | No | Medium |
| 22 | TEST Virtual Assistant | Philippines | 2 | No | No | Low (Test) |
| 19 | X - Certification QA Testing | Indonesia | 0 | Yes | No | Low (Needs mapping) |
| 20 | QA Testing Certificate \| Common | Default | 0 | Yes | No | Low (Needs mapping) |

### Pathways by Certificate Status

**Certificate Enabled (10):**
- Become An Entrepreneur
- Speak with Impact
- Embark on a Green Jobs Journey
- Developer
- Administrative Professional
- Digital Marketer
- Project Manager
- Data Analyst
- X - Certification QA Testing
- QA Testing Certificate | Common

**Certificate Disabled (3):**
- Employability
- Mastering Digital Tools
- TEST Virtual Assistant

### Pathways with Order Restrictions

These pathways require courses to be completed in sequence:

1. **Become An Entrepreneur** (LP 26)
2. **Speak with Impact** (LP 25)
3. **Embark on a Green Jobs Journey** (LP 23)

---

## Program Type Recommendations

Open edX supports multiple program types. Based on MCT's learning pathway goals:

| Program Type | Description | Recommended For |
|--------------|-------------|-----------------|
| **Professional Certificate** | Industry-recognized credential for job readiness | Most career-focused pathways (Project Manager, Developer, Data Analyst, Digital Marketer, Admin Professional) |
| **MicroMasters** | University-level credential | Academic partnerships (if applicable) |
| **XSeries** | General course sequence on a topic | Skill development (Employability, Mastering Digital Tools) |
| **Certificate** | Basic completion credential | Test/pilot programs (Virtual Assistant) |

### Recommended Mappings

| Learning Pathway | Recommended Program Type | Rationale |
|------------------|-------------------------|-----------|
| Become An Entrepreneur | Professional Certificate | Career readiness focus |
| Speak with Impact | Professional Certificate | Professional skill development |
| Embark on a Green Jobs Journey | Professional Certificate | Career pathway in green sector |
| Developer | Professional Certificate | Technical job preparation |
| Administrative Professional | Professional Certificate | Career-specific training |
| Digital Marketer | Professional Certificate | Career pathway |
| Project Manager | Professional Certificate | Professional credential |
| Data Analyst | Professional Certificate | Technical career path |
| Employability | XSeries | General skill development |
| Mastering Digital Tools | XSeries | Digital literacy sequence |
| TEST Virtual Assistant | Certificate | Test/pilot program |

---

## Detailed Program Mappings

### Program 1: Become An Entrepreneur

**MCT Learning Path ID:** 26
**Program Type:** Professional Certificate
**Certificate:** Enabled
**Order Restriction:** Yes (courses must be taken in sequence)
**Total Courses:** 8

#### Course Sequence

| Order | Course Name | MCT Course ID | Open edX Course Key | Lessons |
|-------|-------------|---------------|-------------------|---------|
| 1 | Course Intro: Entrepreneurial Myths & Entrepreneurial Mindset | TBD | SKILLOURFUTURE+ENTREPRENEUR-INTRO | 5 |
| 2 | Module 1: Start with What Matters - Problem Definition | TBD | SKILLOURFUTURE+ENTREPRENEUR-M1 | 14 |
| 3 | Module 2: From Problems to Possibilities - Ideation | TBD | SKILLOURFUTURE+ENTREPRENEUR-M2 | 20 |
| 4 | Module 3: Market Testing for Your Idea - Prototyping | TBD | SKILLOURFUTURE+ENTREPRENEUR-M3 | 16 |
| 5 | Module 4: Storytelling Your Prototype and Build Your Business Model Canvas | TBD | SKILLOURFUTURE+ENTREPRENEUR-M4 | 13 |
| 6 | Module 5: Building a Team That Can Build the Dream | TBD | SKILLOURFUTURE+ENTREPRENEUR-M5 | 13 |
| 7 | Module 6: Finding Available Support in Your Ecosystem | TBD | SKILLOURFUTURE+ENTREPRENEUR-M6 | 12 |
| 8 | Wrap Up: Claim Your Course Certificate | TBD | SKILLOURFUTURE+ENTREPRENEUR-WRAP | 1 |

#### Program Configuration

```json
{
  "title": "Become An Entrepreneur",
  "subtitle": "Master entrepreneurship from problem definition to ecosystem support",
  "type": "Professional Certificate",
  "status": "active",
  "marketing_slug": "become-entrepreneur",
  "partner": "SKILLOURFUTURE",
  "overview": "This program equips learners with comprehensive entrepreneurship skills, from identifying problems and ideation to prototyping, team building, and ecosystem support.",
  "certificate_enabled": true,
  "order_restriction_enabled": true,
  "certificate_template_id": 2
}
```

---

### Program 2: Speak with Impact

**MCT Learning Path ID:** 25
**Program Type:** Professional Certificate
**Certificate:** Enabled
**Order Restriction:** Yes
**Total Courses:** 10

#### Course Sequence

| Order | Course Name | MCT Course ID | Open edX Course Key | Lessons |
|-------|-------------|---------------|-------------------|---------|
| 1 | Module 0: Welcome - this is not your typical course | TBD | SKILLOURFUTURE+SPEAK-IMPACT-M0 | 3 |
| 2 | Module 1: Overcome Your Fear of Public Speaking | TBD | SKILLOURFUTURE+SPEAK-IMPACT-M1 | 5 |
| 3 | Module 2: The Secret to Impactful Communication | TBD | SKILLOURFUTURE+SPEAK-IMPACT-M2 | 2 |
| 4 | Module 3: Powerful Presentation Skills | TBD | SKILLOURFUTURE+SPEAK-IMPACT-M3 | 2 |
| 5 | Module 4: Master the Art of Storytelling | TBD | SKILLOURFUTURE+SPEAK-IMPACT-M4 | 4 |
| 6 | Module 5: Elevate your Stage Presence | TBD | SKILLOURFUTURE+SPEAK-IMPACT-M5 | 2 |
| 7 | Module 6: Own Your Voice as a Way of Life | TBD | SKILLOURFUTURE+SPEAK-IMPACT-M6 | 3 |
| 8 | Module 7: Public Speaking for Advocacy | TBD | SKILLOURFUTURE+SPEAK-IMPACT-M7 | 2 |
| 9 | Module 8: Public Speaking for Branding and Job Readiness | TBD | SKILLOURFUTURE+SPEAK-IMPACT-M8 | 2 |
| 10 | Module 9: Public Speaking for Young Entrepreneurs | TBD | SKILLOURFUTURE+SPEAK-IMPACT-M9 | 2 |

#### Program Configuration

```json
{
  "title": "Speak with Impact",
  "subtitle": "Master public speaking, storytelling, and impactful communication",
  "type": "Professional Certificate",
  "status": "active",
  "marketing_slug": "speak-with-impact",
  "partner": "SKILLOURFUTURE",
  "overview": "This course empowers you to lead with clarity, confidence, and purpose by mastering public speaking and storytelling as your most powerful tools.",
  "certificate_enabled": true,
  "order_restriction_enabled": true,
  "certificate_template_id": 2
}
```

---

### Program 3: Embark on a Green Jobs Journey

**MCT Learning Path ID:** 23
**Program Type:** Professional Certificate
**Certificate:** Enabled
**Order Restriction:** Yes
**Total Courses:** 7

#### Course Sequence

| Order | Course Name | MCT Course ID | Open edX Course Key | Lessons |
|-------|-------------|---------------|-------------------|---------|
| 1 | Module 1: Spot the Challenge | TBD | SKILLOURFUTURE+GREEN-JOBS-M1 | 20 |
| 2 | Module 2: Listen to Yourself | TBD | SKILLOURFUTURE+GREEN-JOBS-M2 | 11 |
| 3 | Module 3: Find Your Path | TBD | SKILLOURFUTURE+GREEN-JOBS-M3 | 9 |
| 4 | Module 4: Consider the Bigger Picture | TBD | SKILLOURFUTURE+GREEN-JOBS-M4 | 10 |
| 5 | Module 5: Unlock Your Inner Entrepreneur | TBD | SKILLOURFUTURE+GREEN-JOBS-M5 | 9 |
| 6 | Module 6: Build Your Green Career | TBD | SKILLOURFUTURE+GREEN-JOBS-M6 | 12 |
| 7 | (chinese) Your Future in Green Jobs | TBD | SKILLOURFUTURE+GREEN-JOBS-ZH | 0 |

**Note:** Course 7 appears to be a localized version (Chinese). Consider making it optional or creating a separate program variant.

#### Program Configuration

```json
{
  "title": "Embark on a Green Jobs Journey",
  "subtitle": "Discover career opportunities in sustainability and green sectors",
  "type": "Professional Certificate",
  "status": "active",
  "marketing_slug": "green-jobs-journey",
  "partner": "SKILLOURFUTURE",
  "overview": "Explore the world of green jobs and sustainability careers, from understanding environmental challenges to building your green career path.",
  "certificate_enabled": true,
  "order_restriction_enabled": true,
  "certificate_template_id": 11
}
```

---

### Program 4: Developer

**MCT Learning Path ID:** 15
**Program Type:** Professional Certificate
**Certificate:** Enabled
**Order Restriction:** No
**Total Courses:** 8

#### Course List

| Course Name | MCT Course ID | Open edX Course Key | Lessons |
|-------------|---------------|-------------------|---------|
| Module 1: Get started with web development using Visual Studio Code | TBD | SKILLOURFUTURE+DEV-M1-VSCODE | 1 |
| Module 2: Describe cloud computing | TBD | SKILLOURFUTURE+DEV-M2-CLOUD | 1 |
| Module 3: Build your first HTML webpage | TBD | SKILLOURFUTURE+DEV-M3-HTML | 1 |
| Module 4: Use CSS styles in a webpage | TBD | SKILLOURFUTURE+DEV-M4-CSS | 1 |
| Module 5: JavaScript arrays and loops | TBD | SKILLOURFUTURE+DEV-M5-JS | 1 |
| Module 6: Learning Data Engineering Foundation | TBD | SKILLOURFUTURE+DEV-M6-DATA | 1 |
| Module 7: SQL Programming | TBD | SKILLOURFUTURE+DEV-M7-SQL | 1 |
| Module 8: iOS App Development | TBD | SKILLOURFUTURE+DEV-M8-IOS | 0 |

**Note:** Module 8 has 0 lessons - verify if course is complete before including in program.

#### Program Configuration

```json
{
  "title": "Developer Career Path",
  "subtitle": "Core concepts and structure of programming languages",
  "type": "Professional Certificate",
  "status": "active",
  "marketing_slug": "developer",
  "partner": "SKILLOURFUTURE",
  "overview": "Learn core concepts and structure of programming languages including web development, cloud computing, databases, and mobile app development.",
  "certificate_enabled": true,
  "order_restriction_enabled": false,
  "certificate_template_id": 2
}
```

---

### Program 5: Data Analyst

**MCT Learning Path ID:** 14
**Program Type:** Professional Certificate
**Certificate:** Enabled
**Order Restriction:** No
**Total Courses:** 5

#### Course List

| Course Name | MCT Course ID | Open edX Course Key | Lessons |
|-------------|---------------|-------------------|---------|
| Module 1: Start a career in the field of Data Analytics | TBD | SKILLOURFUTURE+DATA-M1-CAREER | 5 |
| Module 2: Starting Forms | TBD | SKILLOURFUTURE+DATA-M2-FORMS | 6 |
| Module 3: Building Processes with Power Automate | TBD | SKILLOURFUTURE+DATA-M3-AUTOMATE | 4 |
| Module 4: Data Analysis in Excel | TBD | SKILLOURFUTURE+DATA-M4-EXCEL | 4 |
| Module 5: Utilizing Power BI Desktop | TBD | SKILLOURFUTURE+DATA-M5-POWERBI | 6 |

#### Program Configuration

```json
{
  "title": "Data Analyst Career Path",
  "subtitle": "Foundational concepts and tools for data analytics",
  "type": "Professional Certificate",
  "status": "active",
  "marketing_slug": "data-analyst",
  "partner": "SKILLOURFUTURE",
  "overview": "Master foundational concepts used in data analysis and practice using software tools for data analytics and data visualization.",
  "certificate_enabled": true,
  "order_restriction_enabled": false,
  "certificate_template_id": 2
}
```

---

### Program 6: Project Manager

**MCT Learning Path ID:** 13
**Program Type:** Professional Certificate
**Certificate:** Enabled
**Order Restriction:** No
**Total Courses:** 4

#### Course List

| Course Name | MCT Course ID | Open edX Course Key | Lessons |
|-------------|---------------|-------------------|---------|
| Module 1: No Name | TBD | SKILLOURFUTURE+PM-M1-INTRO | 5 |
| Module 2: Getting Started with Lists | TBD | SKILLOURFUTURE+PM-M2-LISTS | 7 |
| Module 3: Using Microsoft Planner | TBD | SKILLOURFUTURE+PM-M3-PLANNER | 6 |
| Module 4: Staying Organized with Microsoft Project | TBD | SKILLOURFUTURE+PM-M4-PROJECT | 6 |

**Note:** Module 1 needs a proper name. Original description: "How to manage projects effectively with scheduling, budgeting, and communication, and explore PM tools in Microsoft 365."

#### Program Configuration

```json
{
  "title": "Project Manager Career Path",
  "subtitle": "Project management with Microsoft 365 tools",
  "type": "Professional Certificate",
  "status": "active",
  "marketing_slug": "project-manager",
  "partner": "SKILLOURFUTURE",
  "overview": "Learn how to manage projects effectively with scheduling, budgeting, and communication, and explore PM tools in Microsoft 365.",
  "certificate_enabled": true,
  "order_restriction_enabled": false,
  "certificate_template_id": 2
}
```

---

### Program 7: Digital Marketer

**MCT Learning Path ID:** 17
**Program Type:** Professional Certificate
**Certificate:** Enabled
**Order Restriction:** No
**Total Courses:** 5

#### Course List

| Course Name | MCT Course ID | Open edX Course Key | Lessons |
|-------------|---------------|-------------------|---------|
| Module 1: Recognize the Importance of Digital Marketing | TBD | SKILLOURFUTURE+DIGI-MKT-M1 | 1 |
| Module 2: Determining Marketing Channels | TBD | SKILLOURFUTURE+DIGI-MKT-M2 | 4 |
| Module 3: Creating a Simple Dashboard & Report Using Ms. Excel | TBD | SKILLOURFUTURE+DIGI-MKT-M3 | 3 |
| Quiz | TBD | SKILLOURFUTURE+DIGI-MKT-QUIZ | 0 |
| Studi Kasus | TBD | SKILLOURFUTURE+DIGI-MKT-CASE | 2 |

**Note:** "Quiz" and "Studi Kasus" (Case Study in Indonesian) need proper module naming.

#### Program Configuration

```json
{
  "title": "Digital Marketer Career Path",
  "subtitle": "Digital marketing strategies for business growth",
  "type": "Professional Certificate",
  "status": "active",
  "marketing_slug": "digital-marketer",
  "partner": "SKILLOURFUTURE",
  "overview": "Learn how to utilize marketing channels, content making, and report writing for digital marketing success.",
  "certificate_enabled": true,
  "order_restriction_enabled": false,
  "certificate_template_id": 2
}
```

---

### Program 8: Administrative Professional

**MCT Learning Path ID:** 16
**Program Type:** Professional Certificate
**Certificate:** Enabled
**Order Restriction:** No
**Total Courses:** 4

#### Course List

| Course Name | MCT Course ID | Open edX Course Key | Lessons |
|-------------|---------------|-------------------|---------|
| Module 1: Career Opportunities in the Administrative Professional Field | TBD | SKILLOURFUTURE+ADMIN-M1-CAREER | 7 |
| Module 2: Basic Competency in the field of Administrative Professional | TBD | SKILLOURFUTURE+ADMIN-M2-BASIC | 3 |
| Module 3: Enhance skills in Administrative Professional | TBD | SKILLOURFUTURE+ADMIN-M3-ENHANCE | 5 |
| Modul 4: Studi Kasus | TBD | SKILLOURFUTURE+ADMIN-M4-CASE | 2 |

**Note:** Module 4 is in Indonesian ("Studi Kasus" = Case Study). Consider standardizing course names.

#### Program Configuration

```json
{
  "title": "Administrative Professional Career Path",
  "subtitle": "Essential skills for administrative roles",
  "type": "Professional Certificate",
  "status": "active",
  "marketing_slug": "administrative-professional",
  "partner": "SKILLOURFUTURE",
  "overview": "Develop essential skills needed for administrative roles, including communication, writing, time management, and must-have software skills.",
  "certificate_enabled": true,
  "order_restriction_enabled": false,
  "certificate_template_id": 2
}
```

---

### Program 9: Employability

**MCT Learning Path ID:** 24
**Program Type:** XSeries
**Certificate:** Disabled (consider enabling)
**Order Restriction:** No
**Total Courses:** 7

#### Course List

| Course Name | MCT Course ID | Open edX Course Key | Lessons |
|-------------|---------------|-------------------|---------|
| Building a Standout CV for Career Success | TBD | SKILLOURFUTURE+EMPLOY-CV | 3 |
| Digital Branding & Employability - Level 1 | TBD | SKILLOURFUTURE+EMPLOY-BRANDING | 6 |
| Green Jobs & Sustainability Careers [Level 1] | TBD | SKILLOURFUTURE+EMPLOY-GREEN | 9 |
| How to find your dream job | TBD | SKILLOURFUTURE+EMPLOY-DREAMJOB | 5 |
| Mastering The Art of Interview | TBD | SKILLOURFUTURE+EMPLOY-INTERVIEW | 3 |
| Personal Branding through LinkedIn | TBD | SKILLOURFUTURE+EMPLOY-LINKEDIN | 3 |
| Xu hướng việc làm xanh dành cho thanh niên | TBD | SKILLOURFUTURE+EMPLOY-GREEN-VN | 4 |

**Note:** Last course is in Vietnamese. Consider creating separate program variant or making it optional.

#### Program Configuration

```json
{
  "title": "Employability Skills",
  "subtitle": "Essential skills for career success",
  "type": "XSeries",
  "status": "active",
  "marketing_slug": "employability",
  "partner": "SKILLOURFUTURE",
  "overview": "Build essential employability skills including CV writing, interview preparation, personal branding, and job search strategies.",
  "certificate_enabled": false,
  "order_restriction_enabled": false
}
```

**Recommendation:** Consider enabling certificates for this program as it's valuable for learners.

---

### Program 10: Mastering Digital Tools

**MCT Learning Path ID:** 21
**Program Type:** XSeries
**Certificate:** Disabled
**Organization:** Vietnam
**Total Courses:** 9

#### Course List (Vietnamese)

| Course Name | MCT Course ID | Open edX Course Key | Lessons |
|-------------|---------------|-------------------|---------|
| Khóa học 1 - Làm việc với máy tính | TBD | SKILLOURFUTURE+VN-DIGITAL-M1 | 16 |
| Khóa học 2 - Truy cập thông tin trực tuyến | TBD | SKILLOURFUTURE+VN-DIGITAL-M2 | 10 |
| Khóa học 3 - Giao tiếp trực tuyến | TBD | SKILLOURFUTURE+VN-DIGITAL-M3 | 11 |
| Khóa học 4 - Tham gia an toàn và có trách nhiệm trên mạng | TBD | SKILLOURFUTURE+VN-DIGITAL-M4 | 7 |
| Khóa học 5 - Tạo nội dung kỹ thuật số | TBD | SKILLOURFUTURE+VN-DIGITAL-M5 | 23 |
| Khóa học 6 - Cộng tác và quản lý nội dung kỹ thuật số | TBD | SKILLOURFUTURE+VN-DIGITAL-M6 | 16 |
| Khung đánh giá năng lực số cho thanh thiếu niên tại Việt Nam hiện nay | TBD | SKILLOURFUTURE+VN-DIGITAL-M7 | 1 |
| Tạo trang web với ứng dụng Wix | TBD | SKILLOURFUTURE+VN-DIGITAL-M8 | 3 |
| Thiết kế hình ảnh với công cụ Canva | TBD | SKILLOURFUTURE+VN-DIGITAL-M9 | 2 |

#### Program Configuration

```json
{
  "title": "Mastering Digital Tools (Vietnam)",
  "subtitle": "Thu hẹp khoảng cách số - Bridging the digital divide",
  "type": "XSeries",
  "status": "active",
  "marketing_slug": "mastering-digital-tools-vn",
  "partner": "SKILLOURFUTURE",
  "overview": "Comprehensive digital literacy program covering computer basics, online communication, digital content creation, and digital tool mastery.",
  "certificate_enabled": false,
  "order_restriction_enabled": false
}
```

**Note:** This is a Vietnam-specific program with all courses in Vietnamese. Keep separate from other programs.

---

### Program 11: TEST Virtual Assistant

**MCT Learning Path ID:** 22
**Program Type:** Certificate
**Certificate:** Disabled
**Organization:** Philippines
**Total Courses:** 2

#### Course List

| Course Name | MCT Course ID | Open edX Course Key | Lessons |
|-------------|---------------|-------------------|---------|
| Module 1: What is Virtual Assistant? | TBD | SKILLOURFUTURE+PH-VA-M1 | 0 |
| TEST COURSE | TBD | SKILLOURFUTURE+PH-VA-TEST | 0 |

**Status:** This appears to be a test/pilot program with incomplete courses (0 lessons each).

#### Program Configuration

```json
{
  "title": "TEST Virtual Assistant (Philippines)",
  "subtitle": "Pilot program - Virtual assistant training",
  "type": "Certificate",
  "status": "draft",
  "marketing_slug": "test-virtual-assistant",
  "partner": "SKILLOURFUTURE",
  "overview": "Test program for virtual assistant training.",
  "certificate_enabled": false,
  "order_restriction_enabled": false
}
```

**Recommendation:** Keep in draft status until courses are complete.

---

### Programs Requiring Investigation

#### Program 12: X - Certification QA Testing (Indonesia)

**MCT Learning Path ID:** 19
**Organization:** Indonesia
**Certificate:** Enabled
**Total Courses:** 0 (No courses mapped)

**Status:** No courses found in categories matching this learning pathway.

**Investigation Required:**
1. Check if this pathway has courses under different category names
2. Verify if courses exist in MCT but weren't exported
3. Determine if this is an inactive/deprecated pathway
4. Check if courses need to be created from scratch

#### Program 13: QA Testing Certificate | Common

**MCT Learning Path ID:** 20
**Organization:** Default
**Certificate:** Enabled
**Total Courses:** 0 (No courses mapped)

**Status:** No courses found in categories matching this learning pathway.

**Investigation Required:**
1. Same as Program 12
2. Determine relationship between Indonesia-specific (LP 19) and Common (LP 20) QA Testing pathways
3. Check if they share courses or are completely separate

---

## Implementation Steps

### Phase 1: Service Verification (Week 1)

#### Step 1.1: Check Discovery Service

```bash
# Check if Discovery pod is running
kubectl get pods -n mereka-lms | grep discovery

# Check Discovery URL accessibility
curl -I https://discovery.staging.academy.mereka.io/health/

# Check Discovery admin access
# Navigate to: https://discovery.staging.academy.mereka.io/admin/
# Login with LMS superuser credentials
```

**Expected Result:** Discovery service is running and admin interface is accessible.

#### Step 1.2: Check Credentials Service

```bash
# Check if Credentials pod is running
kubectl get pods -n mereka-lms | grep credentials

# Check Credentials URL accessibility
curl -I https://credentials.staging.academy.mereka.io/health/

# Check Credentials admin access
# Navigate to: https://credentials.staging.academy.mereka.io/admin/
```

**Expected Result:** Credentials service is running and admin interface is accessible.

#### Step 1.3: Verify OAuth2 Configuration

```bash
# Access LMS admin
# Navigate to: https://staging.academy.mereka.io/admin/oauth2_provider/application/

# Check for Discovery OAuth2 application
# Expected: Application named "discovery" with proper redirect URLs
```

**If OAuth2 is not configured:**

1. Create new OAuth2 application at `/admin/oauth2_provider/application/`
2. Set name: "discovery"
3. Set URL: `https://discovery.staging.academy.mereka.io`
4. Set Redirect URL: `https://discovery.staging.academy.mereka.io/complete/edx-oauth2/`
5. Client type: Confidential (Web applications)
6. Authorization grant type: Authorization code
7. Save and note Client ID and Client Secret

---

### Phase 2: Course Verification (Week 1-2)

#### Step 2.1: Verify Imported Courses

```bash
# Access LMS Studio
# Navigate to: https://studio.staging.academy.mereka.io

# Check that all MCT courses have been imported
# Expected: 178 courses from MCT
```

#### Step 2.2: Map MCT Course IDs to Open edX Course Keys

Create a mapping file that links:
- MCT Course ID → Open edX Course Key
- MCT Course Name → Open edX Course Name

```bash
# Generate course mapping
kubectl exec -it -n mereka-lms $(kubectl get pods -n mereka-lms -l app=lms -o jsonpath='{.items[0].metadata.name}') -- bash -c "
./manage.py lms shell -c \"
from opaque_keys.edx.keys import CourseKey
from xmodule.modulestore.django import modulestore

store = modulestore()
courses = store.get_courses()

for course in courses:
    print(f'{course.id},{course.display_name}')
\" > /tmp/openedx_courses.csv
"

# Copy to local
kubectl cp mereka-lms/<lms-pod>:/tmp/openedx_courses.csv ./openedx_courses.csv
```

#### Step 2.3: Update Programs Mapping JSON

Update `/var/migrations/mct/programs_mapping.json` with actual Open edX course keys.

---

### Phase 3: Program Creation (Week 2-3)

#### Step 3.1: Create Partner Organization (If Not Exists)

```bash
# Access Discovery Admin
# Navigate to: https://discovery.staging.academy.mereka.io/admin/core/partner/

# Check if SKILLOURFUTURE partner exists
# If not, create:
#   - Short Code: skillourfuture
#   - Name: SKILLOURFUTURE
#   - Courses API URL: https://staging.academy.mereka.io/api/courses/v1/
#   - LMS URL: https://staging.academy.mereka.io
#   - Studio URL: https://studio.staging.academy.mereka.io
```

#### Step 3.2: Create Program Types (If Not Exists)

```bash
# Access Discovery Admin
# Navigate to: https://discovery.staging.academy.mereka.io/admin/course_metadata/programtype/

# Verify these program types exist:
# - Professional Certificate
# - XSeries
# - Certificate
# - MicroMasters (optional)
```

#### Step 3.3: Create Programs via Admin UI

For each program in priority order:

1. Navigate to: `https://discovery.staging.academy.mereka.io/admin/course_metadata/program/add/`

2. Fill in program details:
   - **Title**: Program name (e.g., "Become An Entrepreneur")
   - **Subtitle**: Brief description
   - **Type**: Select appropriate program type
   - **Status**: Active
   - **Marketing Slug**: URL-friendly slug (e.g., "become-entrepreneur")
   - **Partner**: SKILLOURFUTURE
   - **Overview**: Full program description
   - **Banner Image**: Upload program banner (use MCT logo if available)
   - **Card Image**: Upload card image for catalog display

3. Add courses:
   - In "Courses" section, add courses via "+" button
   - Select courses in the correct order
   - For programs with order restrictions, enable "Order Matters"

4. Configure certificate:
   - Check "Certificate Enabled" if applicable
   - Set certificate template ID (from MCT mapping)

5. Save program

#### Step 3.4: Automate Program Creation (Optional)

For bulk creation, use Discovery API:

```python
# See API Integration Guide section below
```

---

### Phase 4: Certificate Configuration (Week 3-4)

#### Step 4.1: Create Certificate Templates

```bash
# Access Credentials Admin
# Navigate to: https://credentials.staging.academy.mereka.io/admin/credentials/programcertificate/

# For each program with certificates enabled:
# 1. Click "Add Program Certificate"
# 2. Set Program UUID (from Discovery)
# 3. Select Certificate Template
# 4. Set Active = True
# 5. Add Signatories
```

#### Step 4.2: Configure Certificate Template Design

```bash
# Navigate to: https://credentials.staging.academy.mereka.io/admin/credentials/certificatetemplate/

# Create/Edit template:
# - Upload organization logo
# - Set border color
# - Configure certificate text
# - Add signature images
```

#### Step 4.3: Test Certificate Generation

```bash
# SSH into Credentials pod
kubectl exec -it -n mereka-lms $(kubectl get pods -n mereka-lms -l app=credentials -o jsonpath='{.items[0].metadata.name}') -- bash

# Generate test certificate
./manage.py generate_program_certificates --program-uuid <PROGRAM_UUID> --user <TEST_USER_EMAIL>
```

---

### Phase 5: LMS Integration (Week 4)

#### Step 5.1: Sync Programs to LMS

```bash
# SSH into LMS pod
kubectl exec -it -n mereka-lms $(kubectl get pods -n mereka-lms -l app=lms -o jsonpath='{.items[0].metadata.name}') -- bash

# Sync program metadata
./manage.py lms refresh_course_metadata --partner_code skillourfuture

# Verify programs are synced
./manage.py lms shell -c "
from openedx.core.djangoapps.catalog.models import CatalogIntegration
from openedx.core.djangoapps.programs.utils import get_programs

programs = get_programs()
print(f'Total programs: {len(programs)}')
for p in programs:
    print(f'  - {p[\"title\"]} ({p[\"uuid\"]})')
"
```

#### Step 5.2: Enable Programs Display

```bash
# Access LMS Django Admin
# Navigate to: https://staging.academy.mereka.io/admin/site_configuration/siteconfiguration/

# Find site configuration for staging.academy.mereka.io
# Add to "values" JSON:
{
  "ENABLE_PROGRAMS": true,
  "ENABLE_PROGRAM_CERTIFICATES": true
}

# Save configuration
```

#### Step 5.3: Verify Frontend Display

```bash
# Navigate to: https://staging.academy.mereka.io/programs

# Verify:
# 1. Programs page loads
# 2. All programs are listed
# 3. Program cards show correct images and descriptions
# 4. Clicking program shows correct courses
```

---

### Phase 6: Testing (Week 5)

#### Step 6.1: Test Program Enrollment

1. Create test user account
2. Enroll in all courses of a program
3. Verify program progress displays correctly
4. Complete all courses
5. Verify certificate is generated

#### Step 6.2: Test Order Restrictions

For programs with order restrictions (LP 23, 25, 26):

1. Attempt to enroll in Module 3 before Module 1
2. Verify restriction message displays
3. Complete modules in order
4. Verify next module unlocks

#### Step 6.3: Test Certificate Generation

```bash
# Test certificate generation for completed programs
kubectl exec -it -n mereka-lms $(kubectl get pods -n mereka-lms -l app=credentials -o jsonpath='{.items[0].metadata.name}') -- bash

./manage.py generate_program_certificates --dry-run

# Generate actual certificates
./manage.py generate_program_certificates
```

---

## API Integration Guide

### Authentication

Discovery API requires JWT authentication:

```python
import requests
from datetime import datetime, timedelta
import jwt

# Get JWT token from LMS
def get_jwt_token(lms_url, username, password):
    """Get JWT token for API authentication"""
    # Login to get session
    session = requests.Session()
    login_url = f"{lms_url}/user_api/v1/account/login_session/"

    response = session.post(login_url, json={
        "email": username,
        "password": password
    })

    if response.status_code == 200:
        # Get access token
        token_url = f"{lms_url}/oauth2/access_token"
        token_response = session.post(token_url, data={
            "grant_type": "password",
            "client_id": "<CLIENT_ID>",
            "client_secret": "<CLIENT_SECRET>",
            "username": username,
            "password": password
        })
        return token_response.json()["access_token"]
    return None

# Example usage
token = get_jwt_token(
    "https://staging.academy.mereka.io",
    "admin@example.com",
    "password"
)
```

### List Programs

```python
def list_programs(discovery_url, token):
    """List all programs"""
    headers = {"Authorization": f"JWT {token}"}
    response = requests.get(
        f"{discovery_url}/api/v1/programs/",
        headers=headers
    )
    return response.json()

# Example
programs = list_programs(
    "https://discovery.staging.academy.mereka.io",
    token
)
print(f"Total programs: {programs['count']}")
```

### Create Program

```python
def create_program(discovery_url, token, program_data):
    """Create a new program"""
    headers = {
        "Authorization": f"JWT {token}",
        "Content-Type": "application/json"
    }

    response = requests.post(
        f"{discovery_url}/api/v1/programs/",
        headers=headers,
        json=program_data
    )

    if response.status_code == 201:
        return response.json()
    else:
        raise Exception(f"Failed to create program: {response.text}")

# Example program data
program_data = {
    "title": "Become An Entrepreneur",
    "subtitle": "Master entrepreneurship from problem definition to ecosystem support",
    "type": "Professional Certificate",
    "status": "active",
    "marketing_slug": "become-entrepreneur",
    "partner": "skillourfuture",
    "overview": "This program equips learners with comprehensive entrepreneurship skills...",
    "courses": [
        "course-v1:SKILLOURFUTURE+ENTREPRENEUR-INTRO+2024",
        "course-v1:SKILLOURFUTURE+ENTREPRENEUR-M1+2024",
        # ... more courses
    ],
    "certificate": {
        "enabled": True,
        "template_id": 2
    }
}

program = create_program(
    "https://discovery.staging.academy.mereka.io",
    token,
    program_data
)
```

### Add Courses to Program

```python
def add_courses_to_program(discovery_url, token, program_uuid, course_keys):
    """Add courses to an existing program"""
    headers = {
        "Authorization": f"JWT {token}",
        "Content-Type": "application/json"
    }

    for order, course_key in enumerate(course_keys, start=1):
        response = requests.post(
            f"{discovery_url}/api/v1/programs/{program_uuid}/courses/",
            headers=headers,
            json={
                "course_key": course_key,
                "position": order
            }
        )

        if response.status_code != 201:
            print(f"Failed to add course {course_key}: {response.text}")

    return True

# Example
add_courses_to_program(
    "https://discovery.staging.academy.mereka.io",
    token,
    "12345678-1234-1234-1234-123456789abc",
    [
        "course-v1:SKILLOURFUTURE+ENTREPRENEUR-INTRO+2024",
        "course-v1:SKILLOURFUTURE+ENTREPRENEUR-M1+2024",
    ]
)
```

### Bulk Program Creation Script

```python
#!/usr/bin/env python3
"""
Bulk create Open edX Programs from MCT Learning Pathways mapping
"""

import json
import requests
from pathlib import Path

# Load mapping
with open('/home/dev/code/mereka-lms/var/migrations/mct/programs_mapping.json') as f:
    mapping = json.load(f)

# Configuration
DISCOVERY_URL = "https://discovery.staging.academy.mereka.io"
LMS_URL = "https://staging.academy.mereka.io"
USERNAME = "admin@example.com"
PASSWORD = "password"

# Get auth token
token = get_jwt_token(LMS_URL, USERNAME, PASSWORD)

# Create each program
for lp_id, lp_data in mapping['learning_paths'].items():
    print(f"Creating program: {lp_data['name']}")

    # Prepare program data
    program_data = {
        "title": lp_data['name'],
        "subtitle": lp_data['description'][:255] if lp_data['description'] else "",
        "type": determine_program_type(lp_data),
        "status": "active" if lp_data['course_count'] > 0 else "draft",
        "marketing_slug": create_slug(lp_data['name']),
        "partner": "skillourfuture",
        "overview": lp_data['description'] or "Learning pathway description",
        "certificate": {
            "enabled": lp_data['certificate_status'] == 1,
            "template_id": lp_data.get('certificate_template_id', 2)
        }
    }

    # Create program
    try:
        program = create_program(DISCOVERY_URL, token, program_data)
        print(f"  ✓ Created program UUID: {program['uuid']}")

        # Add courses
        if lp_data['courses']:
            course_keys = get_course_keys(lp_data['courses'])
            add_courses_to_program(DISCOVERY_URL, token, program['uuid'], course_keys)
            print(f"  ✓ Added {len(course_keys)} courses")
    except Exception as e:
        print(f"  ✗ Failed: {e}")

print("\n✓ Program creation complete")
```

---

## Certificate Configuration

### Certificate Templates

Open edX Credentials service supports customizable certificate templates. Each program can have its own template or share a common template.

#### MCT Certificate Template Mapping

| MCT Template ID | Program Type | Description |
|----------------|--------------|-------------|
| 2 | Professional Certificate | Standard professional credential |
| 5 | Professional Certificate | Indonesia-specific |
| 11 | Professional Certificate | Green Jobs specific |

#### Template Elements

1. **Organization Logo**: SKILLOURFUTURE/Mereka Academy logo
2. **Certificate Border**: Custom border design
3. **Signatory Signatures**: 1-3 signatories with titles
4. **Certificate Text**: Customizable text including:
   - Learner name
   - Program title
   - Completion date
   - Organization name
5. **Verification URL**: QR code or URL for certificate verification

#### Creating Custom Template

```bash
# Access Credentials Admin
# Navigate to: https://credentials.staging.academy.mereka.io/admin/credentials/certificatetemplate/

# Click "Add Certificate Template"
# Configure:
#   - Name: Professional Certificate - SKILLOURFUTURE
#   - Organization logo: Upload logo.png
#   - Border color: #0066CC (example)
#   - Certificate heading: "Certificate of Completion"
#   - Title: "Professional Certificate"
#   - Description: "This is to certify that {user_full_name} has successfully completed..."
```

---

### Certificate Signatories

Configure who signs program certificates:

```bash
# Navigate to: https://credentials.staging.academy.mereka.io/admin/credentials/signatory/

# Add signatory:
#   - Name: Dr. Jane Doe
#   - Title: Director, SKILLOURFUTURE
#   - Organization: SKILLOURFUTURE
#   - Signature image: Upload signature.png
```

---

### Certificate Generation Workflow

1. **Learner completes all courses** in program
2. **Course certificates issued** for each completed course
3. **Credentials service detects** program completion
4. **Program certificate generated** automatically
5. **Email notification sent** to learner
6. **Certificate available** at `/credentials/programs/<UUID>/`

#### Manual Certificate Generation

```bash
# Generate certificates for all eligible learners
kubectl exec -it -n mereka-lms <credentials-pod> -- bash
./manage.py generate_program_certificates

# Generate for specific program
./manage.py generate_program_certificates --program-uuid <UUID>

# Generate for specific user
./manage.py generate_program_certificates --user <email>

# Dry run to see who would receive certificates
./manage.py generate_program_certificates --dry-run
```

---

## Troubleshooting

### Programs Not Visible in LMS

**Symptoms:**
- Programs page shows no programs
- Program navigation menu missing

**Diagnosis:**

```bash
# 1. Check if programs are synced
kubectl exec -it -n mereka-lms <lms-pod> -- bash
./manage.py lms shell -c "
from openedx.core.djangoapps.programs.utils import get_programs
programs = get_programs()
print(f'Programs count: {len(programs)}')
"

# 2. Check site configuration
# Navigate to: https://staging.academy.mereka.io/admin/site_configuration/siteconfiguration/
# Verify ENABLE_PROGRAMS = true
```

**Solution:**

```bash
# Sync programs from Discovery
kubectl exec -it -n mereka-lms <lms-pod> -- bash
./manage.py lms refresh_course_metadata

# Enable in site configuration
# Add to site configuration values JSON:
{
  "ENABLE_PROGRAMS": true,
  "ENABLE_PROGRAM_CERTIFICATES": true
}
```

---

### Discovery Service Not Accessible

**Symptoms:**
- Cannot access Discovery admin
- API returns 502/504 errors

**Diagnosis:**

```bash
# Check Discovery pod status
kubectl get pods -n mereka-lms | grep discovery

# Check Discovery logs
kubectl logs -n mereka-lms -l app=discovery --tail=100

# Check Discovery service endpoints
kubectl get endpoints -n mereka-lms discovery
```

**Solution:**

```bash
# Restart Discovery pod
kubectl rollout restart deployment/discovery -n mereka-lms

# Check if Discovery plugin is enabled
tutor plugins list

# Enable if not active
tutor plugins enable discovery
tutor config save
./infrastructure/tutor/apply-patches.sh
tutor k8s launch
```

---

### Certificates Not Generated

**Symptoms:**
- Learner completed program but no certificate
- Certificate page shows 404

**Diagnosis:**

```bash
# Check Credentials service status
kubectl get pods -n mereka-lms | grep credentials

# Check certificate configuration
kubectl exec -it -n mereka-lms <credentials-pod> -- bash
./manage.py shell -c "
from credentials.apps.credentials.models import ProgramCertificate
certs = ProgramCertificate.objects.all()
print(f'Total certificate configs: {certs.count()}')
for cert in certs:
    print(f'  Program UUID: {cert.program_uuid}, Active: {cert.is_active}')
"
```

**Solution:**

```bash
# Ensure certificate configuration exists
# Navigate to: https://credentials.staging.academy.mereka.io/admin/credentials/programcertificate/
# Add configuration for program if missing

# Run certificate generation
kubectl exec -it -n mereka-lms <credentials-pod> -- bash
./manage.py generate_program_certificates --program-uuid <UUID>

# Check logs for errors
kubectl logs -n mereka-lms -l app=credentials --tail=100
```

---

### OAuth2 Authentication Errors

**Symptoms:**
- Discovery API returns 401 Unauthorized
- Cannot login to Discovery admin

**Diagnosis:**

```bash
# Check OAuth2 applications
# Navigate to: https://staging.academy.mereka.io/admin/oauth2_provider/application/
# Verify "discovery" application exists with correct redirect URLs
```

**Solution:**

```bash
# Create OAuth2 application if missing:
# 1. Navigate to: https://staging.academy.mereka.io/admin/oauth2_provider/application/add/
# 2. Name: discovery
# 3. Redirect URIs: https://discovery.staging.academy.mereka.io/complete/edx-oauth2/
# 4. Client type: Confidential
# 5. Authorization grant type: Authorization code
# 6. Save

# Update Discovery settings with OAuth credentials
# (Usually configured automatically by Tutor)
```

---

### Course Not Found When Adding to Program

**Symptoms:**
- Course dropdown in Discovery admin is empty
- API returns "Course not found"

**Diagnosis:**

```bash
# Check if courses are synced to Discovery
kubectl exec -it -n mereka-lms <discovery-pod> -- bash
./manage.py shell -c "
from course_discovery.apps.course_metadata.models import Course
courses = Course.objects.all()
print(f'Total courses in Discovery: {courses.count()}')
"
```

**Solution:**

```bash
# Sync courses from LMS to Discovery
kubectl exec -it -n mereka-lms <discovery-pod> -- bash
./manage.py refresh_course_metadata --partner_code skillourfuture

# If courses still not appearing, check partner configuration
./manage.py shell -c "
from course_discovery.apps.core.models import Partner
partners = Partner.objects.all()
for p in partners:
    print(f'{p.short_code}: {p.lms_url}')
"
```

---

## Verification Checklist

### Pre-Implementation Verification

- [ ] Discovery service is running and accessible
- [ ] Credentials service is running and accessible
- [ ] OAuth2 is configured for Discovery
- [ ] Partner organization "SKILLOURFUTURE" exists in Discovery
- [ ] All MCT courses are imported to Open edX
- [ ] Course mapping (MCT ID → Open edX Course Key) is complete
- [ ] Programs mapping JSON is updated with actual course keys

### Program Creation Verification

For each program:

- [ ] Program created in Discovery admin
- [ ] Program type is correct (Professional Certificate/XSeries)
- [ ] Program status is "Active"
- [ ] Marketing slug is URL-friendly and unique
- [ ] All courses are added to program
- [ ] Course order is correct (especially for ordered programs)
- [ ] Banner image and card image are uploaded
- [ ] Program description is complete

### Certificate Configuration Verification

For programs with certificates:

- [ ] Certificate template exists in Credentials
- [ ] Program certificate configuration created
- [ ] Certificate is marked as "Active"
- [ ] Signatories are configured
- [ ] Certificate template includes organization logo
- [ ] Certificate text is customized appropriately

### LMS Integration Verification

- [ ] Programs synced to LMS (`refresh_course_metadata` run)
- [ ] Site configuration has `ENABLE_PROGRAMS: true`
- [ ] Site configuration has `ENABLE_PROGRAM_CERTIFICATES: true`
- [ ] Programs page loads: `https://staging.academy.mereka.io/programs`
- [ ] All programs visible in programs catalog
- [ ] Program detail pages load correctly
- [ ] Course lists on program pages are accurate

### End-to-End Testing

- [ ] Test user can view program catalog
- [ ] Test user can enroll in program courses
- [ ] Program progress displays correctly
- [ ] For ordered programs: next course unlocks after completion
- [ ] Completing all courses triggers certificate generation
- [ ] Certificate displays correctly
- [ ] Certificate PDF downloads successfully
- [ ] Certificate verification URL works

### Performance and Monitoring

- [ ] Discovery service logs show no errors
- [ ] Credentials service logs show no errors
- [ ] Program pages load within 3 seconds
- [ ] Certificate generation completes within 5 minutes
- [ ] API endpoints respond within 500ms

---

## References

### Documentation

- [Open edX Discovery Service Documentation](https://edx-discovery.readthedocs.io/)
- [Open edX Credentials Service Documentation](https://credentials.readthedocs.io/)
- [Enabling Programs in Open edX Discussion](https://discuss.openedx.org/t/enabling-programs-in-open-edx/7167)
- [Setup Discovery Sandbox Wiki](https://openedx.atlassian.net/wiki/spaces/SUST/pages/956039272/Setup+Discovery+Sandbox)
- [Course Discovery GitHub Repository](https://github.com/openedx/course-discovery)
- [Credentials GitHub Repository](https://github.com/openedx/credentials)

### Related Project Documentation

- `/docs/migrations/mct/OPENEDX_PROGRAMS_SETUP.md` - Original setup notes
- `/docs/migrations/mct/MCT_TO_OPENEDX_MAPPING.md` - MCT to Open edX mapping
- `/var/migrations/mct/programs_mapping.json` - Programs mapping data

### API Endpoints

- **Discovery API Base**: `https://discovery.staging.academy.mereka.io/api/v1/`
- **Programs Endpoint**: `/api/v1/programs/`
- **Courses Endpoint**: `/api/v1/courses/`
- **Credentials API Base**: `https://credentials.staging.academy.mereka.io/api/v1/`

---

## Appendix A: Program Priority Matrix

Implementation priority based on:
- Certificate enabled (higher priority)
- Order restrictions (higher complexity)
- Course count (completeness)
- Organization importance (Default org is primary)

| Priority | Program | LP ID | Rationale |
|----------|---------|-------|-----------|
| 1 | Become An Entrepreneur | 26 | High profile, ordered, certificates |
| 2 | Speak with Impact | 25 | High profile, ordered, certificates |
| 3 | Embark on a Green Jobs Journey | 23 | Strategic initiative, ordered, certificates |
| 4 | Developer | 15 | High demand, certificates |
| 5 | Data Analyst | 14 | High demand, certificates |
| 6 | Project Manager | 13 | Professional credential, certificates |
| 7 | Digital Marketer | 17 | Professional credential, certificates |
| 8 | Administrative Professional | 16 | Professional credential, certificates |
| 9 | Employability | 24 | General skills (consider enabling certs) |
| 10 | Mastering Digital Tools | 21 | Vietnam-specific, no certs |
| 11 | TEST Virtual Assistant | 22 | Test program, incomplete |
| 12 | QA Testing (both) | 19, 20 | Needs investigation |

---

## Appendix B: Estimated Timeline

| Phase | Duration | Key Deliverables |
|-------|----------|------------------|
| Service Verification | 1 week | Discovery & Credentials running |
| Course Verification | 1 week | Course mapping complete |
| Program Creation | 2 weeks | All programs created |
| Certificate Config | 1 week | Certificate templates configured |
| LMS Integration | 1 week | Programs visible in LMS |
| Testing | 1 week | All verification tests passed |
| **Total** | **7 weeks** | Production-ready programs |

**Fast Track (Priority programs only):** 3-4 weeks

---

## Appendix C: Rollback Plan

If issues occur during implementation:

### Rollback Step 1: Disable Programs Display

```bash
# Disable programs in site configuration
# Navigate to: https://staging.academy.mereka.io/admin/site_configuration/siteconfiguration/
# Set: ENABLE_PROGRAMS: false
```

### Rollback Step 2: Deactivate Programs

```bash
# Set all programs to inactive in Discovery admin
# Navigate to: https://discovery.staging.academy.mereka.io/admin/course_metadata/program/
# Bulk action: Set status to "Unpublished"
```

### Rollback Step 3: Disable Services (if necessary)

```bash
# Disable Discovery service
tutor plugins disable discovery
tutor config save
tutor k8s restart

# Disable Credentials service
tutor plugins disable credentials
tutor config save
tutor k8s restart
```

**Note:** Disabling services will not delete data. Programs and certificates can be re-enabled later.

---

## Change Log

| Date | Version | Changes | Author |
|------|---------|---------|--------|
| 2025-12-18 | 1.0 | Initial setup plan created | AI Assistant |

---

**END OF DOCUMENT**
