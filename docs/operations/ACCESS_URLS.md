# Access URLs & User Management
_Audience: Everyone • Last updated: 2025-12-29_

## 🌐 Environment URLs

### Local Development

**LMS (Learning Management System)**
- **URL:** http://localhost
- **Admin Panel:** http://localhost/admin
- **Purpose:** Main learning platform where students access courses

**Studio (Course Authoring)**
- **URL:** http://studio.localhost
- **Purpose:** Create and manage courses
- **Login:** Same credentials as LMS

**Micro-Frontends (MFEs)**
- **Base URL:** http://apps.localhost
- **Available MFEs:**
  - **Login/Auth:** http://apps.localhost/authn/login
  - **Account:** http://apps.localhost/account
  - **Profile:** http://apps.localhost/profile
  - **Learning Dashboard:** http://apps.localhost/learner-dashboard
  - **Learning:** http://apps.localhost/learning
  - **Course Authoring:** http://apps.localhost/course-authoring
  - **Gradebook:** http://apps.localhost/gradebook
  - **Discussions:** http://apps.localhost/discussions
  - **Communications:** http://apps.localhost/communications
  - **Orders:** http://apps.localhost/orders
  - **Payment:** http://apps.localhost/payment
  - **ORA Grading:** http://apps.localhost/ora-grading

**Other Services (Local)**
- **Discovery:** http://discovery.localhost
- **Ecommerce:** http://ecommerce.localhost
- **Notes API:** http://notes.localhost (API only, no UI)
- **XQueue:** http://xqueue.localhost
- **Forum:** Integrated into LMS courses

**Default Credentials (Local)**
- **Username:** `admin`
- **Password:** `admin123`

---

### GKE Environment (academyv2.mereka.io)

**LMS (Learning Management System)**
- **URL:** https://academyv2.mereka.io
- **Admin Panel:** https://academyv2.mereka.io/admin
- **Purpose:** Main learning platform where students access courses

**Studio (Course Authoring)**
- **URL:** https://studio.academyv2.mereka.io
- **Purpose:** Create and manage courses
- **Login:** Same credentials as LMS

**Micro-Frontends (MFEs)**
- **Base URL:** https://apps.academyv2.mereka.io
- **Available MFEs:** Same as local (authn, account, profile, learning, etc.)

**Other Services (GKE)** - Internal only, port-forward required
- **Discovery:** Internal (kubectl port-forward svc/discovery 8000:8000)
- **Ecommerce:** Internal (kubectl port-forward svc/ecommerce 8000:8000)
- **Credentials:** Internal (kubectl port-forward svc/credentials 8000:8000)
- **Notes API:** Internal (API only, no UI)
- **Forum:** Integrated into LMS courses
  - **Status:** ✅ Running (scaled to 1 replica)
  - **MongoDB:** ✅ Connected to MongoDB Atlas
  - **Elasticsearch:** ✅ Connected
  - **Access:** Forum discussions appear within course pages
- **Analytics (Superset):** ❌ NOT DEPLOYED
  - **Status:** Documented but not yet deployed to K8s
  - **Plan:** See [`docs/analytics/ASPECTS_K8S_DEPLOYMENT.md`](../analytics/ASPECTS_K8S_DEPLOYMENT.md)

---

### Skill Our Future (MCT Migration) - GKE

**LMS (Learning Management System)**
- **URL:** https://skillourfuture.academy.mereka.io
- **Admin Panel:** https://skillourfuture.academy.mereka.io/admin
- **Purpose:** Skill Our Future learning platform (MCT migration target)

**Studio (Course Authoring)**
- **URL:** https://studio.academyv2.mereka.io (shared with main GKE LMS)
- **Purpose:** Single Studio instance manages courses for all GKE LMS sites
- **Note:** Courses are organized by Organization (e.g., "SKILLOURFUTURE" org)

**Stats (as of 2025-12-29):**
- Users: 68,565+ imported from MCT
- Enrollments: 449,615+ MCT enrollments
- Courses: 30 MCT courses
- Programs: 13 learning pathways

---

### Production Microsite (Biji-Biji Academy)

**LMS (Learning Management System)**
- **URL:** https://academy.biji-biji.com ✅ LIVE
- **Admin Panel:** https://academy.biji-biji.com/admin
- **Purpose:** Main learning platform where students access courses

**Studio (Course Authoring)**
- **URL:** https://studio.academy.biji-biji.com
- **Purpose:** Create and manage courses

**Micro-Frontends (MFEs)**
- **Base URL:** https://apps.academy.biji-biji.com
- **Available MFEs:** Same as local/staging

**Other Services (Production)**
- **Discovery:** Internal only (port-forward required)
- **Ecommerce:** Internal only (port-forward required)
- **Credentials:** Internal only (port-forward required)
- **Notes API:** Internal only

---

## User Management

### Create Admin User

**Via Kubernetes (Staging/Production):**
```bash
kubectl exec -n mereka-lms deploy/lms -- python manage.py lms createsuperuser
```

**Via Local Tutor:**
```bash
# Method 1: Using tutor command
tutor local createuser --superuser --staff -p <password> <username> <email>

# Method 2: Direct Django command
docker exec tutor_local-lms-1 python /openedx/edx-platform/manage.py lms manage_user --superuser --staff <username> <email>
docker exec tutor_local-lms-1 python /openedx/edx-platform/manage.py lms shell -c "from django.contrib.auth import get_user_model; u = get_user_model().objects.get(username='<username>'); u.set_password('<password>'); u.is_staff = True; u.is_superuser = True; u.save()"
```

### Access Admin Panel

**Local:**
1. Go to: http://localhost/admin
2. Login with superuser credentials (`admin` / `admin123`)

**Staging:**
1. Go to: https://academyv2.mereka.io/admin
2. Login with superuser credentials

**Production:**
1. Go to: https://academy.mereka.io/admin (when ready)
2. Login with superuser credentials

### Current Admin Users (Staging)

**Verified:** 2025-11-12

The following admin users exist in staging:
- `gurpreet` (gurpreet@biji-biji.com) - Staff: ✅, Active: ✅
- `malasari` (malasari@mereka.my) - Staff: ✅, Active: ✅
- `discovery` (discovery@openedx) - Service account
- `ecommerce` (ecommerce@openedx) - Service account
- `notes` (notes@openedx) - Service account

**Note:** Admin credentials are stored securely. Contact infrastructure team for access.

### Common Admin Tasks

- **Users:** `/admin/auth/user/`
- **Courses:** `/admin/courseware/courses/`
- **Enrollments:** `/admin/student/courseenrollment/`
- **Organizations:** `/admin/organizations/organization/`

---

## Port Forwarding (For Debugging)

**Local:** Services run directly on localhost ports (no port-forwarding needed)

**Kubernetes (Staging/Production):**
```bash
# LMS
kubectl port-forward -n mereka-lms svc/lms 8000:8000

# CMS/Studio
kubectl port-forward -n mereka-lms svc/cms 8000:8000

# Forum
kubectl port-forward -n mereka-lms svc/forum 4567:4567

# Analytics (Superset) - See docs/analytics/ANALYTICS_CONSOLE_ACCESS.md
kubectl port-forward -n mereka-lms svc/superset 8088:8088
# Then access at: http://localhost:8088
# Default credentials: admin / admin
```

---

## Notes

- **Local:** All URLs use HTTP (no TLS needed)
- **Staging/Production:** All URLs use HTTPS (TLS certificates via Let's Encrypt)
- **Staging environment:** `academyv2.mereka.io`
- **Production environment:** `academy.mereka.io` (when ready)
- **Local development:** Use `*.localhost` domains (automatically resolves to 127.0.0.1)

---

## Quick Reference

### Main Staging Environment

| Service | Local | Staging |
|---------|-------|---------|
| LMS | http://localhost | https://academyv2.mereka.io |
| Studio | http://studio.localhost | https://studio.academyv2.mereka.io |
| MFE Base | http://apps.localhost | https://apps.academyv2.mereka.io |
| Discovery | http://discovery.localhost | https://discovery.academyv2.mereka.io |
| Ecommerce | http://ecommerce.localhost | https://ecommerce.academyv2.mereka.io |
| Credentials | - | https://credentials.academyv2.mereka.io |

### Skill Our Future (MCT) - Staging

| Service | URL |
|---------|-----|
| LMS | https://skillourfuture.academy.mereka.io |
| Studio | https://studio.academyv2.mereka.io (shared) |

### Biji-Biji Academy - Production

| Service | URL |
|---------|-----|
| LMS | https://academy.biji-biji.com |
| Studio | https://studio.academy.biji-biji.com |
| MFE Base | https://apps.academy.biji-biji.com |

### Internal Services (Port-forward required)

| Service | Port | Command | Status |
|---------|------|---------|--------|
| Discovery | 8000 | `kubectl port-forward -n mereka-lms svc/discovery 8000:8000` | ✅ Running |
| Ecommerce | 8000 | `kubectl port-forward -n mereka-lms svc/ecommerce 8000:8000` | ✅ Running |
| Credentials | 8000 | `kubectl port-forward -n mereka-lms svc/credentials 8000:8000` | ✅ Running |
| Forum | 4567 | `kubectl port-forward -n mereka-lms svc/forum 4567:4567` | ✅ Running |
| Notes | 8000 | `kubectl port-forward -n mereka-lms svc/notes 8000:8000` | ✅ Running |
| Analytics (Superset) | 8088 | `kubectl port-forward -n mereka-lms svc/superset 8088:8088` | ❌ Not deployed |
