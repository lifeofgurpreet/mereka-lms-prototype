# OpenEdX Analytics Guide
_Audience: Platform Eng • Owner: Data/Analytics • Last verified: 2025-07-25_

This guide explains how to access course analytics in OpenEdX, including enrollments, completions, and certificates through the built-in UI and APIs.

## Quick Start: Which Analytics Tool Should I Use?

| Need | Solution | Documentation |
|------|----------|---------------|
| **Per-course analytics only** | Instructor Dashboard | Built-in, see below |
| **Platform-wide analytics** (all courses) | **Aspects Analytics** ⭐ | [`docs/concepts/analytics/ASPECTS_ANALYTICS.md`](ASPECTS_ANALYTICS.md) |
| **Third-party analytics** (if Aspects doesn't meet needs) | Panorama Analytics | [`docs/concepts/analytics/PANORAMA_ANALYTICS.md`](PANORAMA_ANALYTICS.md) |

**Recommendation**: If you need platform-wide analytics (enrollments across all courses, completion rates, certificates issued platform-wide), install **Aspects Analytics**. It's free, native to OpenEdX, and provides comprehensive platform-wide dashboards.

## Built-in Analytics UI

OpenEdX provides several user interfaces for accessing course analytics:

### 1. Instructor Dashboard (Built-in)

The **Instructor Dashboard** is available in every course and provides direct access to enrollment and completion data.

#### Accessing the Instructor Dashboard

1. **Log into the LMS** (e.g., `https://academyv2.mereka.io` or `http://localhost`)
2. **Navigate to a course** you have instructor access to
3. **Click on "Instructor"** in the course navigation menu (top navigation bar)
4. **Select "Data Download"** from the instructor dashboard menu

#### Available Reports

From the Instructor Dashboard → Data Download section, you can download:

- **Enrollment Report** - CSV with all enrolled students and enrollment dates
- **Grade Report** - Student scores and completion statuses
- **Activity Report** - Login frequencies and course interactions
- **Discussion Report** - Forum engagement data
- **Problem Grade Report** - Individual problem/assessment scores
- **Student Profile Information** - User profile data for enrolled students

#### Viewing Certificates

To see certificates issued for a course:

1. Go to **Instructor Dashboard** → **Student Admin**
2. Click **"Certificates"** or **"Generate Certificates"**
3. View list of certificates issued and their status

### 2. Aspects Analytics (Platform-Wide) ⭐ **RECOMMENDED**

**Aspects** is OpenEdX's **native analytics system** that provides **platform-wide analytics** across all courses, not just per-course data.

#### Why Aspects?

- ✅ **Platform-wide analytics** - See all courses, enrollments, completions in one place
- ✅ **Free and open-source** - No licensing fees
- ✅ **Native integration** - Built by OpenEdX team
- ✅ **Privacy-conscious** - De-identifies learner data by default
- ✅ **Powerful visualizations** - Uses Apache Superset for advanced dashboards

#### Accessing Aspects

**From LMS Instructor Dashboard**:
- Navigate to any course → Instructor Dashboard
- Look for **"Reports"** link (added by Aspects)
- Access course-level or platform-wide dashboards

**From Superset Dashboard**:
- Direct access: `http://aspects-superset.localhost` (local) or configured domain
- Single sign-on with LMS credentials
- Platform-wide dashboards and custom reports

**From Studio**:
- Analytics sidebar when editing course content
- In-context metrics for specific content sections

#### Installation

See **[`docs/concepts/analytics/ASPECTS_ANALYTICS.md`](ASPECTS_ANALYTICS.md)** for complete installation instructions.

**Quick install**:
```bash
source infrastructure/tutor/tutor-env.sh
pip install tutor-contrib-aspects
tutor plugins enable aspects
tutor config save
tutor images build openedx aspects aspects-superset
tutor local do init
tutor local start -d
```

#### Features

- **Platform Overview Dashboard**: All courses, enrollments, completions
- **Course Dashboards**: Per-course analytics
- **At-Risk Learners**: Identify learners who may not complete
- **Individual Learner Dashboards**: Detailed activity per learner
- **Custom Reports**: Create your own dashboards and visualizations
- **Real-time Data**: Near real-time updates

### 3. Panorama Analytics (Third-Party)

**Panorama** is a third-party analytics plugin that provides enhanced dashboards with embedded analytics directly in OpenEdX.

#### Accessing Panorama

- Look for **"Analytics"** or **"Panorama"** link in the LMS header
- Access via instructor dashboard if integrated
- May be available at a custom route

#### Features

- **Platform-wide analytics** across all courses
- **Administrator dashboards** for enrollments, grades, certificates
- **Student dashboards** for personal progress
- **Enhanced visualization** and reporting
- **Role-based access** control

#### Installation

See **[`docs/concepts/analytics/PANORAMA_ANALYTICS.md`](PANORAMA_ANALYTICS.md)** for installation details.

**Note**: Panorama requires separate installation and may have licensing costs. Check with provider.

## Quick Access URLs

### Local Development
- LMS: `http://localhost`
- Studio: `http://studio.localhost`
- Instructor Dashboard: `http://localhost/courses/{course-id}/instructor`

### Production
- LMS: `https://academyv2.mereka.io`
- Studio: `https://studio.academyv2.mereka.io`
- Instructor Dashboard: `https://academyv2.mereka.io/courses/{course-id}/instructor`

## Permissions Required

To access analytics, you need:

- **Instructor role** for a specific course (to see that course's analytics)
- **Staff role** for platform-wide analytics (if available)
- **Superuser** for full administrative access

### Granting Instructor Access

If you need instructor access to a course:

```bash
# Via Django shell
tutor local run lms ./manage.py lms shell

# Then in Python:
from django.contrib.auth import get_user_model
from common.djangoapps.student.models import CourseAccessRole
from opaque_keys.edx.keys import CourseKey

User = get_user_model()
user = User.objects.get(email='your-email@example.com')
course_key = CourseKey.from_string('course-v1:org+course+run')

CourseAccessRole.objects.get_or_create(
    user=user,
    course_id=course_key,
    role='instructor'
)
```

## Programmatic Access (APIs)

For automated access or custom integrations, OpenEdX also provides APIs:

### Enrollment API
```
GET /api/courses/v1/courses/{course_id}/enrollment
```

### Certificates API
```
GET /api/certificates/v0/certificates/{username}/courses/{course_id}
```

### Course Analytics API (if Aspects enabled)
```
GET /api/analytics/v0/courses/{course_id}/enrollment/
```

## Troubleshooting

### Can't See Instructor Dashboard

1. **Check permissions**: Ensure you have instructor role for the course
2. **Check course access**: Make sure you're enrolled in the course
3. **Check URL**: Navigate directly to `/courses/{course-id}/instructor`

### Reports Not Generating

1. **Check course has students**: Reports only generate if there are enrollments
2. **Check permissions**: Some reports require staff privileges
3. **Check logs**: `tutor local logs lms --tail=100` for errors

### Missing Analytics Features

- **Aspects/Panorama**: May need to be installed separately
- **Advanced reports**: May require additional plugins or configuration
- **Real-time data**: Some analytics may have processing delays

## Database Queries (Advanced)

For advanced queries or custom reports, you can also query the database directly:

### Quick Reference

### Local Environment
```bash
source infrastructure/tutor/tutor-env.sh
tutor local run lms ./manage.py lms shell
```

### Kubernetes/Production
```bash
kubectl exec -n mereka-lms deploy/lms -- \
  ./manage.py lms shell -c '...' --settings=tutor.production
```

## Core Django Models

OpenEdX stores analytics data in these Django models:

- **Enrollments**: `common.djangoapps.student.models.CourseEnrollment`
- **Certificates**: `lms.djangoapps.certificates.models.GeneratedCertificate`
- **Course Completions**: `completion.models.BlockCompletion` (if completion tracking enabled)
- **Course Overviews**: `openedx.core.djangoapps.content.course_overviews.models.CourseOverview`

## Basic Analytics Queries

### 1. Total Enrollments per Course

```python
from common.djangoapps.student.models import CourseEnrollment
from openedx.core.djangoapps.content.course_overviews.models import CourseOverview
from django.db.models import Count

# Get enrollment counts per course
enrollments = CourseEnrollment.objects.values('course_id').annotate(
    count=Count('id')
).order_by('-count')

for item in enrollments[:10]:  # Top 10 courses
    try:
        course = CourseOverview.get_from_id(item['course_id'])
        print(f"{course.display_name}: {item['count']} enrollments")
    except:
        print(f"{item['course_id']}: {item['count']} enrollments")
```

### 2. Active vs Inactive Enrollments

```python
from common.djangoapps.student.models import CourseEnrollment

total = CourseEnrollment.objects.count()
active = CourseEnrollment.objects.filter(is_active=True).count()
inactive = total - active

print(f"Total enrollments: {total}")
print(f"Active: {active} ({active/total*100:.1f}%)")
print(f"Inactive: {inactive} ({inactive/total*100:.1f}%)")
```

### 3. Certificates Issued

```python
from lms.djangoapps.certificates.models import GeneratedCertificate

# Total certificates
total_certs = GeneratedCertificate.objects.count()
print(f"Total certificates issued: {total_certs}")

# Certificates per course
from django.db.models import Count
certs_by_course = GeneratedCertificate.objects.filter(
    status='downloadable'
).values('course_id').annotate(
    count=Count('id')
).order_by('-count')

for item in certs_by_course[:10]:
    print(f"{item['course_id']}: {item['count']} certificates")
```

### 4. Course Completion Statistics

```python
from common.djangoapps.student.models import CourseEnrollment
from lms.djangoapps.certificates.models import GeneratedCertificate
from openedx.core.djangoapps.content.course_overviews.models import CourseOverview

# For a specific course
course_id = "course-v1:org+course+run"  # Replace with actual course ID

enrollments = CourseEnrollment.objects.filter(course_id=course_id, is_active=True)
total_enrolled = enrollments.count()

certificates = GeneratedCertificate.objects.filter(
    course_id=course_id,
    status='downloadable'
)
completed = certificates.count()

completion_rate = (completed / total_enrolled * 100) if total_enrolled > 0 else 0

print(f"Course: {course_id}")
print(f"Total enrolled: {total_enrolled}")
print(f"Completed: {completed}")
print(f"Completion rate: {completion_rate:.1f}%")
```

### 5. Enrollment Trends Over Time

```python
from common.djangoapps.student.models import CourseEnrollment
from django.db.models import Count
from django.utils import timezone
from datetime import timedelta

# Enrollments in the last 30 days
thirty_days_ago = timezone.now() - timedelta(days=30)
recent_enrollments = CourseEnrollment.objects.filter(
    created__gte=thirty_days_ago
).extra(
    select={'day': 'DATE(created)'}
).values('day').annotate(
    count=Count('id')
).order_by('day')

for item in recent_enrollments:
    print(f"{item['day']}: {item['count']} enrollments")
```

## Using the Analytics Script

A Python script is available at `scripts/analytics/openedx-analytics.py` that provides a command-line interface for common analytics queries.

### Usage Examples

```bash
# Get summary statistics
tutor local run lms python /path/to/scripts/analytics/openedx-analytics.py --summary

# Get enrollments for a specific course
tutor local run lms python /path/to/scripts/analytics/openedx-analytics.py \
  --course "course-v1:org+course+run" --enrollments

# Get completion statistics
tutor local run lms python /path/to/scripts/analytics/openedx-analytics.py \
  --course "course-v1:org+course+run" --completions

# Export all course analytics to CSV
tutor local run lms python /path/to/scripts/analytics/openedx-analytics.py \
  --export-csv /tmp/analytics.csv
```

## Advanced Queries

### Enrollment by Mode (Audit vs Verified)

```python
from common.djangoapps.student.models import CourseEnrollment
from django.db.models import Count

modes = CourseEnrollment.objects.values('mode').annotate(
    count=Count('id')
).order_by('-count')

for mode in modes:
    print(f"{mode['mode']}: {mode['count']} enrollments")
```

### Certificate Status Breakdown

```python
from lms.djangoapps.certificates.models import GeneratedCertificate
from django.db.models import Count

statuses = GeneratedCertificate.objects.values('status').annotate(
    count=Count('id')
).order_by('-count')

for status in statuses:
    print(f"{status['status']}: {status['count']} certificates")
```

### User Progress Tracking

```python
from common.djangoapps.student.models import CourseEnrollment
from lms.djangoapps.certificates.models import GeneratedCertificate

# Users who enrolled but haven't completed
course_id = "course-v1:org+course+run"

enrolled_users = set(
    CourseEnrollment.objects.filter(
        course_id=course_id,
        is_active=True
    ).values_list('user_id', flat=True)
)

certified_users = set(
    GeneratedCertificate.objects.filter(
        course_id=course_id,
        status='downloadable'
    ).values_list('user_id', flat=True)
)

in_progress = enrolled_users - certified_users
print(f"Users in progress: {len(in_progress)}")
print(f"Users completed: {len(certified_users)}")
```

## Database Direct Queries (Alternative)

If you need to query the database directly:

### MySQL Access

```bash
# Local
tutor local run mysql mysql -u openedx openedx

# Kubernetes
kubectl exec -n mereka-lms deploy/mysql -- mysql -u openedx openedx
```

### Useful SQL Queries

```sql
-- Total enrollments per course
SELECT course_id, COUNT(*) as enrollments
FROM student_courseenrollment
WHERE is_active = 1
GROUP BY course_id
ORDER BY enrollments DESC
LIMIT 10;

-- Certificates issued per course
SELECT course_id, COUNT(*) as certificates
FROM certificates_generatedcertificate
WHERE status = 'downloadable'
GROUP BY course_id
ORDER BY certificates DESC;

-- Enrollment trends (last 30 days)
SELECT DATE(created) as date, COUNT(*) as enrollments
FROM student_courseenrollment
WHERE created >= DATE_SUB(NOW(), INTERVAL 30 DAY)
GROUP BY DATE(created)
ORDER BY date;
```

## Integration with Monitoring

For production monitoring, consider:

1. **Scheduled Reports**: Use the analytics script in a cron job or Kubernetes CronJob
2. **Dashboard Integration**: Export data to your monitoring stack (Grafana, Data Studio, etc.)
3. **Alerting**: Set up alerts for completion rate drops or enrollment anomalies

See `docs/ops/monitoring/MONITORING.md` for infrastructure monitoring setup.

## Troubleshooting

### Common Issues

1. **Import Errors**: Ensure you're running commands inside the LMS container with proper Django settings
2. **Missing Data**: Some analytics require completion tracking to be enabled in course settings
3. **Performance**: For large datasets, use `.values()` and `.annotate()` instead of loading full objects

### Getting Course IDs

```python
from openedx.core.djangoapps.content.course_overviews.models import CourseOverview

# List all courses
courses = CourseOverview.get_all_courses()
for course in courses[:10]:
    print(f"{course.id}: {course.display_name}")
```

## References

- [OpenEdX Student Models Documentation](https://github.com/openedx/edx-platform/tree/master/common/djangoapps/student)
- [OpenEdX Certificates Documentation](https://github.com/openedx/edx-platform/tree/master/lms/djangoapps/certificates)
- Django ORM Query Reference: https://docs.djangoproject.com/en/stable/topics/db/queries/
