# Access URLs & User Management
_Audience: Everyone • Last updated: 2026-02-06_

## 🌐 Environment URLs

Canonical hostname registry (prod + dev + kind-local):
- `docs/operations/OPENEDX_HOSTNAMES.md`

### Local Development

**LMS (Learning Management System)**
- **URL:** http://localhost
- **Admin Panel:** http://localhost/admin
- **Purpose:** Main learning platform where students access courses

**Preview (Alias Hostname)**
- **URL:** http://preview.localhost
- **Admin Panel:** http://preview.localhost/admin
- **Purpose:** Same LMS stack, extra hostname for preview/testing

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
- Use your local superuser credentials (often `admin` plus a locally set password).
- For GKE + VPS kind, use the shared Infisical secrets below.

---

### GKE Environment (academyv2.mereka.io)

**LMS (Learning Management System)**
- **URL:** https://academyv2.mereka.io
- **Admin Panel:** https://academyv2.mereka.io/admin
- **Purpose:** Main learning platform where students access courses

**Preview (Alias Hostname)**
- **URL:** https://preview.academyv2.mereka.io
- **Admin Panel:** https://preview.academyv2.mereka.io/admin
- **Purpose:** Same LMS stack, extra hostname for preview/testing

**Studio (Course Authoring)**
- **URL:** https://studio.academyv2.mereka.io
- **Purpose:** Create and manage courses
- **Login:** Same credentials as LMS

**Micro-Frontends (MFEs)**
- **Base URL:** https://apps.academyv2.mereka.io
- **Available MFEs:**
  - **Login/Auth:** https://apps.academyv2.mereka.io/authn/login
  - **Account:** https://apps.academyv2.mereka.io/account
  - **Profile:** https://apps.academyv2.mereka.io/profile
  - **Learning Dashboard:** https://apps.academyv2.mereka.io/learner-dashboard
  - **Learning:** https://apps.academyv2.mereka.io/learning
  - **Course Authoring:** https://apps.academyv2.mereka.io/course-authoring
  - **Gradebook:** https://apps.academyv2.mereka.io/gradebook
  - **Discussions:** https://apps.academyv2.mereka.io/discussions
  - **Communications:** https://apps.academyv2.mereka.io/communications
  - **Orders:** https://apps.academyv2.mereka.io/orders
  - **Payment:** https://apps.academyv2.mereka.io/payment
  - **ORA Grading:** https://apps.academyv2.mereka.io/ora-grading

**SSO / Authentik**
- **OIDC Issuer:** https://auth0.mereka.io/application/o/mereka-lms/
- **Note:** Shared Authentik instance for multiple projects.

**SSO Test Credentials (Optional)**
- **Infisical path:** `/shared/oauth`
- **Email secret:** `GOOGLE_IMPERSONATE_EMAIL`
- **Password secret:** `GOOGLE_IMPERSONATE_PASSWORD`

These are for verifying the **SSO login flow**. They are not the platform-admin mechanism.
Platform admins are enforced separately (see `docs/operations/ADMIN_LOGIN_GUIDE.md`).

**Authentik Admin Sync (if login fails)**
```bash
# Verify Authentik admin status (no secrets in logs)
./scripts/infra/ensure-authentik-admin.sh --verify

# Apply Authentik admin policy (no secrets in logs)
# - Gurpreet is superuser
# - Malasari is not
./scripts/infra/ensure-authentik-admin.sh --apply

# If you also need to reset passwords, do that separately via the Authentik UI.
```

**Other Services (GKE)**
- **Discovery:** https://discovery.academyv2.mereka.io
- **Ecommerce:** https://ecommerce.academyv2.mereka.io
- **Credentials:** https://credentials.academyv2.mereka.io (API-first, has Django admin)
  - **Admin:** https://credentials.academyv2.mereka.io/admin/
  - **Health:** https://credentials.academyv2.mereka.io/health/
  - **API:** https://credentials.academyv2.mereka.io/api/v2/ (401 without auth)
- **Notes API:** https://notes.academyv2.mereka.io (API only)
- **Forum:** https://forum.academyv2.mereka.io (also embedded in LMS)
  - **Health:** https://forum.academyv2.mereka.io/heartbeat (200)
- **Analytics (Superset):** ❌ NOT DEPLOYED
  - **Status:** Documented but not yet deployed to K8s
  - **Plan:** See [`docs/analytics/ASPECTS_K8S_DEPLOYMENT.md`](../analytics/ASPECTS_K8S_DEPLOYMENT.md)

---

### VPS Kind (academyv2.mereka.dev)

**LMS (Learning Management System)**
- **URL:** https://academyv2.mereka.dev
- **Admin Panel:** https://academyv2.mereka.dev/admin

**Preview (Alias Hostname)**
- **URL:** https://preview.academyv2.mereka.dev
- **Admin Panel:** https://preview.academyv2.mereka.dev/admin
- **Purpose:** Same LMS stack, extra hostname for preview/testing

**Studio (Course Authoring)**
- **URL:** https://studio.academyv2.mereka.dev

**Micro-Frontends (MFEs)**
- **Base URL:** https://apps.academyv2.mereka.dev
- **Available MFEs:**
  - **Login/Auth:** https://apps.academyv2.mereka.dev/authn/login
  - **Account:** https://apps.academyv2.mereka.dev/account
  - **Profile:** https://apps.academyv2.mereka.dev/profile
  - **Learning Dashboard:** https://apps.academyv2.mereka.dev/learner-dashboard
  - **Learning:** https://apps.academyv2.mereka.dev/learning
  - **Course Authoring:** https://apps.academyv2.mereka.dev/course-authoring
  - **Gradebook:** https://apps.academyv2.mereka.dev/gradebook
  - **Discussions:** https://apps.academyv2.mereka.dev/discussions
  - **Communications:** https://apps.academyv2.mereka.dev/communications
  - **Orders:** https://apps.academyv2.mereka.dev/orders
  - **Payment:** https://apps.academyv2.mereka.dev/payment
  - **ORA Grading:** https://apps.academyv2.mereka.dev/ora-grading

**Other Services (Dev)**
- **Discovery:** https://discovery.academyv2.mereka.dev
- **Ecommerce:** https://ecommerce.academyv2.mereka.dev
- **Credentials:** https://credentials.academyv2.mereka.dev (API-first, has Django admin)
  - **Admin:** https://credentials.academyv2.mereka.dev/admin/
  - **Health:** https://credentials.academyv2.mereka.dev/health/
  - **API:** https://credentials.academyv2.mereka.dev/api/v2/ (401 without auth)
- **Notes API:** https://notes.academyv2.mereka.dev
- **Forum:** https://forum.academyv2.mereka.dev
  - **Health:** https://forum.academyv2.mereka.dev/heartbeat (200)

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
- **Available MFEs:** Same as local

**Other Services (Production)**
- **Discovery:** https://discovery.academyv2.mereka.io (shared service)
- **Ecommerce:** https://ecommerce.academyv2.mereka.io (shared service)
- **Credentials:** https://credentials.academyv2.mereka.io (shared service)
- **Notes API:** https://notes.academyv2.mereka.io (shared service)

**Microsite Boundary Note:** `skillourfuture.academy.mereka.io` and `academy.biji-biji.com` are separate client sites with distinct branding, catalogs, and users. Treat them as independent tenants.

---

## User Management

### Platform Admins (Required)

The following humans must have full admin permissions across the Open edX ecosystem:
- `gurpreet@biji-biji.com`
- `malasari@mereka.my`

**What “full permissions” means (practical):**
- **LMS/CMS (Open edX):** `is_active=True`, `is_staff=True`, `is_superuser=True`
- **Studio course creation:** `CourseCreator(state=granted, all_organizations=True)`
- **Discovery/Credentials/Ecommerce admin:** `is_active=True`, `is_staff=True`, `is_superuser=True`

**Enforcement (idempotent, prod + dev):**
```bash
./scripts/infra/ensure-platform-admins.sh
```

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

### Admin Access For Discovery/Credentials/Ecommerce

These services have their own Django Admin sites:
- `https://discovery.academyv2.mereka.io/admin/`
- `https://credentials.academyv2.mereka.io/admin/`
- `https://ecommerce.academyv2.mereka.io/admin/`

Hardening behavior (expected):
- If you hit `/admin/` or `/admin/login/` while not logged in, you are redirected to the SSO entrypoint (`/login/`).
- After SSO, you land back on `/admin/`.

This is verified by:
```bash
./scripts/qa/verify-auth-surfaces.sh prod
```

### Common Admin Tasks

- **Users:** `/admin/auth/user/`
- **Courses:** `/admin/courseware/courses/`
- **Enrollments:** `/admin/student/courseenrollment/`
- **Organizations:** `/admin/organizations/organization/`

---

## Port Forwarding (For Debugging)

**Local:** Services run directly on localhost ports (no port-forwarding needed)

**Kubernetes (GKE/Kind):**
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
- **GKE/Kind:** All URLs use HTTPS (TLS certificates via Let's Encrypt)
- **GKE environment:** `academyv2.mereka.io`
- **VPS Kind environment:** `academyv2.mereka.dev`
- **Local development:** Use `*.localhost` domains (automatically resolves to 127.0.0.1)

---

## Health Check Workflow

Run the standard health check script (prod or dev):

```bash
./scripts/qa/public-health-check.sh prod
./scripts/qa/public-health-check.sh dev
```

Optional add-ons:

```bash
# Include TLS SAN validation + branding checks (prod only uses SAN checks)
CHECK_CERTS=1 CHECK_BRANDING=1 ./scripts/qa/public-health-check.sh prod
CHECK_BRANDING=1 ./scripts/qa/public-health-check.sh dev
```

VPS automation (installs cron for prod+dev checks, logs to `var/cron-public-health-check.log`):

```bash
./scripts/infra/setup-vps-health-cron.sh
```

**Key endpoints validated**
- LMS root: `/`
- Studio root: `/`
- MFE login: `/authn/login`
- Discovery: `/health/`
- Ecommerce: `/dashboard/` (verifies OAuth redirect path)
- Credentials: `/health/`
- Notes: `/`
- Forum: `/heartbeat`

---

## Quick Reference

### Main GKE Environment

| Service | Local | GKE |
|---------|-------|-----|
| LMS | http://localhost | https://academyv2.mereka.io |
| Studio | http://studio.localhost | https://studio.academyv2.mereka.io |
| MFE Base | http://apps.localhost | https://apps.academyv2.mereka.io |
| Discovery | http://discovery.localhost | https://discovery.academyv2.mereka.io |
| Ecommerce | http://ecommerce.localhost | https://ecommerce.academyv2.mereka.io |
| Credentials | - | https://credentials.academyv2.mereka.io |

### Skill Our Future (MCT) - GKE

| Service | URL |
|---------|-----|
| LMS | https://skillourfuture.academy.mereka.io |
| Studio | https://studio.academyv2.mereka.io (shared) |

### Biji-Biji Academy - GKE

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
