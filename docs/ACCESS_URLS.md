# Access URLs & User Management
_Audience: Everyone • Last updated: 2025-11-11_

## Main URLs

### LMS (Learning Management System)
- **URL:** https://staging.academy.mereka.io
- **Purpose:** Main learning platform where students access courses
- **Admin Panel:** https://staging.academy.mereka.io/admin

### Studio (Course Authoring)
- **URL:** https://studio.staging.academy.mereka.io
- **Purpose:** Create and manage courses
- **Login:** Same credentials as LMS

### Micro-Frontends (MFEs)
- **URL:** https://apps.staging.academy.mereka.io
- **Purpose:** Modern UI components (profile, account, etc.)

### Forum
- **Integrated into LMS:** https://staging.academy.mereka.io/courses/{course-id}/discussion/forum/
- **Direct service (internal):** Port-forward to `svc/forum:4567`
- **Note:** Forum is part of courses, not a standalone service

### Other Services
- **Discovery:** https://discovery.staging.academy.mereka.io (if configured)
- **Ecommerce:** https://ecommerce.staging.academy.mereka.io (if configured)
- **Notes API:** https://notes.staging.academy.mereka.io (API only, no UI)

---

## User Management

### Create Admin User

**Via Kubernetes:**
```bash
kubectl exec -n mereka-lms deploy/lms -- python manage.py lms createsuperuser
```

**Via Local Tutor:**
```bash
tutor local createuser --superuser --staff -p <password> <username> <email>
```

### Access Admin Panel

1. Go to: https://staging.academy.mereka.io/admin
2. Login with superuser credentials
3. Manage users, courses, enrollments, etc.

### Common Admin Tasks

- **Users:** `/admin/auth/user/`
- **Courses:** `/admin/courseware/courses/`
- **Enrollments:** `/admin/student/courseenrollment/`
- **Organizations:** `/admin/organizations/organization/`

---

## Port Forwarding (For Debugging)

```bash
# LMS
kubectl port-forward -n mereka-lms svc/lms 8000:8000

# CMS/Studio
kubectl port-forward -n mereka-lms svc/cms 8000:8000

# Forum
kubectl port-forward -n mereka-lms svc/forum 4567:4567
```

---

## Notes

- All URLs use HTTPS (TLS certificates via Let's Encrypt)
- Staging environment: `staging.academy.mereka.io`
- Production will use: `academy.mereka.io` (when ready)


