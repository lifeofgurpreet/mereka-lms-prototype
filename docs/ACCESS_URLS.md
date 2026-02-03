# Access URLs & User Management
_Audience: Everyone • Last updated: 2025-11-12_

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

### GKE Production Environment

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

**Other Services (GKE)**
- **Discovery:** https://discovery.academyv2.mereka.io
- **Ecommerce:** https://ecommerce.academyv2.mereka.io
- **Notes API:** https://notes.academyv2.mereka.io (API only, no UI)
- **Forum:** Integrated into LMS courses
  - **Status:** ✅ Running (scaled to 1 replica)
  - **MongoDB:** ✅ Connected to MongoDB Atlas
  - **Elasticsearch:** ✅ Connected
  - **Access:** Forum discussions appear within course pages
- **Analytics (Superset):** 
  - **Status:** ✅ Running
  - **Via Port-Forward:** `kubectl port-forward -n mereka-lms svc/superset 8088:8088` → http://localhost:8088
  - **Via Ingress (once DNS configured):** https://analytics.academyv2.mereka.io
  - **LoadBalancer IP:** `34.126.186.80` (for DNS A record)
  - **Default Credentials:** `admin` / `admin`
  - **Full Guide:** [`docs/analytics/ANALYTICS_CONSOLE_ACCESS.md`](analytics/ANALYTICS_CONSOLE_ACCESS.md)

---

### VPS Kind Development Environment

**LMS (Learning Management System)**
- **URL:** https://academyv2.mereka.dev
- **Admin Panel:** https://academyv2.mereka.dev/admin
- **Purpose:** Dev environment on VPS kind cluster

**Studio (Course Authoring)**
- **URL:** https://studio.academyv2.mereka.dev
- **Purpose:** Create and manage courses

**Micro-Frontends (MFEs)**
- **Base URL:** https://apps.academyv2.mereka.dev
- **Available MFEs:** Same as local

**Other Services (VPS Kind)**
- **Discovery:** https://discovery.academyv2.mereka.dev
- **Ecommerce:** https://ecommerce.academyv2.mereka.dev
- **Notes API:** https://notes.academyv2.mereka.dev (API only, no UI)

---

## User Management

### Create Admin User

**Via Kubernetes (GKE/Kind):**
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

**GKE (Production):**
1. Go to: https://academyv2.mereka.io/admin
2. Login with superuser credentials

**VPS Kind (Dev):**
1. Go to: https://academyv2.mereka.dev/admin
2. Login with superuser credentials

### Current Admin Users (GKE)

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

| Service | Local | Staging | Production |
|---------|-------|---------|------------|
| LMS | http://localhost | https://academyv2.mereka.io | https://academy.mereka.io |
| Studio | http://studio.localhost | https://studio.academyv2.mereka.io | https://studio.academy.mereka.io |
| MFE Base | http://apps.localhost | https://apps.academyv2.mereka.io | https://apps.academy.mereka.io |
| Discovery | http://discovery.localhost | https://discovery.academyv2.mereka.io | https://discovery.academy.mereka.io |
| Ecommerce | http://ecommerce.localhost | https://ecommerce.academyv2.mereka.io | https://ecommerce.academy.mereka.io |
| Analytics (Superset) | Port-forward: http://localhost:8088 | Port-forward: http://localhost:8088<br>Or: https://analytics.academyv2.mereka.io (once DNS configured) | TBD |
