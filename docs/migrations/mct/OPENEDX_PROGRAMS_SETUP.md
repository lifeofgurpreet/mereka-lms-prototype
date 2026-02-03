# Open edX Programs Setup for Learning Paths

**Purpose:** Map MCT Learning Paths to Open edX Programs
**Target:** skillourfuture.academy.mereka.io

---

## What are Programs?

Open edX **Programs** are collections of related courses that learners complete to earn credentials. They map directly to MCT's "Learning Paths".

### Key Features
- Group multiple courses into a structured learning journey
- Issue program certificates upon completion
- Track learner progress across courses
- Display in catalog with custom branding

---

## Architecture Requirements

Programs require two services beyond LMS/CMS:

```
┌─────────────┐     ┌─────────────────┐     ┌──────────────────┐
│    LMS      │────▶│    Discovery    │────▶│   Credentials    │
│             │     │ (course-discovery)   │  (credentials)    │
└─────────────┘     └─────────────────┘     └──────────────────┘
                           │                        │
                           ▼                        ▼
                    Course Catalog           Program Certificates
                    Program Catalog          Course Certificates
```

### Service Status Check

| Service | Required | Current Status |
|---------|----------|----------------|
| LMS | Yes | Running |
| Discovery | Yes | Check: `kubectl get pods -n mereka-lms -l app=discovery` |
| Credentials | For certificates | Check: `kubectl get pods -n mereka-lms -l app=credentials` |

---

## Setup Steps

### Step 1: Verify Discovery Service

Discovery service powers the course catalog and program management.

```bash
# Check if Discovery is running
kubectl get pods -n mereka-lms | grep discovery

# Check Discovery URL
curl -I https://discovery.academyv2.mereka.io/health/
```

If not running, enable in Tutor:
```bash
tutor plugins enable discovery
tutor config save
./infrastructure/tutor/apply-patches.sh
tutor k8s launch
```

### Step 2: Verify Credentials Service

Credentials service issues program certificates.

```bash
# Check if Credentials is running
kubectl get pods -n mereka-lms | grep credentials

# Check Credentials URL
curl -I https://credentials.academyv2.mereka.io/health/
```

If not running:
```bash
tutor plugins enable credentials
tutor config save
./infrastructure/tutor/apply-patches.sh
tutor k8s launch
```

### Step 3: Configure Program via Django Admin

Programs are configured in **Discovery Admin**, not LMS Admin.

1. Access Discovery Admin:
   ```
   https://discovery.academyv2.mereka.io/admin/
   ```
   (Use LMS superuser credentials)

2. Navigate to: **Course Metadata → Programs**

3. Create Program:
   - **Title**: e.g., "Become An Entrepreneur"
   - **Subtitle**: Brief description
   - **Type**: MicroMasters, Professional Certificate, or XSeries
   - **Status**: Active
   - **Marketing Slug**: URL-friendly name (e.g., `entrepreneur`)
   - **Partner**: SKILLOURFUTURE organization

4. Add Courses to Program:
   - In the Program edit page, add courses via "Courses" section
   - Order courses for recommended learning sequence

### Step 4: Sync Programs to LMS

After creating programs in Discovery:

```bash
# SSH into LMS pod
kubectl exec -it -n mereka-lms $(kubectl get pods -n mereka-lms -l app=lms -o jsonpath='{.items[0].metadata.name}') -- bash

# Run management command to sync programs
./manage.py lms refresh_course_metadata
```

---

## Programs for MCT Learning Paths

### Program 1: Become An Entrepreneur
**MCT LP ID:** 26

| Course Order | Course |
|--------------|--------|
| 1 | Become an Entrepreneur (SKILLOURFUTURE+ENTREPRENEUR) |

### Program 2: Speak with Impact
**MCT LP ID:** 25

| Course Order | Course |
|--------------|--------|
| 1 | Speak with Impact (SKILLOURFUTURE+SPEAK-IMPACT) |

### Program 3: Embark on a Green Jobs Journey
**MCT LP ID:** 23

| Course Order | Course |
|--------------|--------|
| 1 | Your Future in Green Jobs (SKILLOURFUTURE+GREEN-JOBS) |
| 2 | Climate Education (SKILLOURFUTURE+CLIMATE-EDU) |

### Program 4: Employability
**MCT LP ID:** 24

| Course Order | Course |
|--------------|--------|
| 1 | Employability (SKILLOURFUTURE+EMPLOYABILITY) |

### Program 5: Mastering Digital Tools
**MCT LP ID:** 21

| Course Order | Course |
|--------------|--------|
| 1 | Basic Microsoft (SKILLOURFUTURE+BASIC-MICROSOFT) |
| 2 | Digital Literacy (SKILLOURFUTURE+DIGITAL-LITERACY) |

### Program 6: Administrative Professional
**MCT LP ID:** 16

| Course Order | Course |
|--------------|--------|
| 1 | Careering as Admin Professional (SKILLOURFUTURE+ADMIN-PROFESSIONAL) |

### Programs Requiring Course Mapping Investigation
- Project Manager (LP 13)
- Data Analyst (LP 14)
- Developer (LP 15)
- Digital Marketer (LP 17)
- QA Testing Certificate (LP 19, 20)
- Virtual Assistant (LP 22 - TEST)

---

## Program Types in Open edX

| Type | Description | Use Case |
|------|-------------|----------|
| **MicroMasters** | University-level credential | Academic pathways |
| **Professional Certificate** | Industry-recognized credential | Job readiness |
| **XSeries** | Course sequence on a topic | General learning |

**Recommendation:** Use "Professional Certificate" for most MCT learning paths as they're career-focused.

---

## Program Certificates

### Enable Certificates

1. In Discovery Admin → Programs → Edit Program:
   - Check "Enable certificate"
   - Upload certificate image template

2. Configure certificate template:
   - In Credentials Admin: https://credentials.academyv2.mereka.io/admin/
   - Navigate to Credentials → Program Certificates
   - Design template with organization branding

### Certificate Requirements

Learners receive program certificate when:
- All required courses in program are completed
- Each course certificate is earned
- Program is marked as "Active"

---

## API Reference

### List Programs
```bash
curl https://discovery.academyv2.mereka.io/api/v1/programs/ \
  -H "Authorization: JWT <token>"
```

### Get Program Details
```bash
curl https://discovery.academyv2.mereka.io/api/v1/programs/<uuid>/ \
  -H "Authorization: JWT <token>"
```

### Enroll User in Program
Programs don't have direct enrollment - users enroll in individual courses. Program progress is calculated from course enrollments.

---

## Troubleshooting

### Programs Not Showing in LMS

1. Check Discovery sync:
   ```bash
   kubectl exec -it -n mereka-lms <lms-pod> -- ./manage.py lms refresh_course_metadata
   ```

2. Verify program status is "Active" in Discovery Admin

3. Check site configuration includes program display:
   ```python
   # In LMS Django Admin → Site Configurations
   # Ensure ENABLE_PROGRAMS = True
   ```

### Certificate Not Issued

1. Verify Credentials service is running
2. Check course certificates are enabled for all courses in program
3. Verify learner completed all required courses
4. Run certificate generation:
   ```bash
   kubectl exec -it -n mereka-lms <credentials-pod> -- ./manage.py generate_program_certificates
   ```

---

## Migration Checklist

- [ ] Verify Discovery service is running
- [ ] Verify Credentials service is running (if certificates needed)
- [ ] Create programs in Discovery Admin for each learning path
- [ ] Add courses to each program in correct order
- [ ] Set program type (Professional Certificate recommended)
- [ ] Enable program certificates
- [ ] Sync programs to LMS
- [ ] Test program display on frontend
- [ ] Test certificate generation

---

## References

- [Open edX Programs Documentation](https://edx.readthedocs.io/projects/edx-installing-configuring-and-running/en/latest/configuration/programs/)
- [Discovery Service API](https://course-discovery.readthedocs.io/)
- [Credentials Service](https://credentials.readthedocs.io/)
