# Admin Login Guide
_Last updated: 2026-02-06_

This document is intentionally conservative: it prioritizes **prod-safe verification** and avoids
“quick fixes” that mutate databases unless you explicitly intend to do that.

For how auth/permissions work (and what does not sync), see:
- `docs/operations/AUTH_AND_PERMISSIONS.md`

## ✅ Required Platform Admins (Authoritative)

These humans must have full admin permissions across the Open edX ecosystem:
- `gurpreet@biji-biji.com`
- `malasari@mereka.my`

Enforce (prod + dev, idempotent):
```bash
./scripts/infra/ensure-platform-admins.sh
```

## Production-Safe Verification (Recommended)

Verify without changing state:
```bash
./scripts/infra/ensure-platform-admins.sh --verify
CHECK_TIMEOUT_SECONDS=300 ./scripts/qa/verify-auth-hardening.sh --env both --mode all
CHECK_TIMEOUT_SECONDS=240 ./scripts/qa/audit-auth-access.sh --env both --mode all
```

Notes:
- These are the **real platform admin accounts** (staff/superuser everywhere in Open edX services, plus CMS CourseCreator).
- Authentik handles authentication (OIDC). Open edX and related services handle authorization (`is_staff`, `is_superuser`, `CourseCreator`).
- **Permissions do not sync from Authentik by default.** We enforce them via allowlist + scripts/runtime backstops.

## 🔐 Shared SSO Test Credentials (Optional)

**Infisical path:** `/shared/oauth`  
**Email secret:** `GOOGLE_IMPERSONATE_EMAIL`  
**Password secret:** `GOOGLE_IMPERSONATE_PASSWORD`

Use these shared credentials for:
- verifying the **SSO login flow** end-to-end (as a normal end-user)
- both **GKE production** (`academyv2.mereka.io`) and **VPS kind dev** (`academyv2.mereka.dev`)

Authentik **admin UI access** is separate from Open edX admin access and is restricted to Gurpreet
(see `docs/operations/AUTH_AND_PERMISSIONS.md`).

Important:
- The shared SSO test user is **not** the platform admin mechanism.
- Do not grant the shared test user `is_superuser` in production unless you explicitly want that.

## 🌐 Login URLs

### Local Development

**Option 1: LMS Login (Legacy)**
- **URL:** http://localhost/login
- **Direct Admin Panel:** http://localhost/admin

**Option 2: MFE Login (Modern)**
- **URL:** http://apps.localhost/authn/login
- **Note:** This uses the modern micro-frontend interface

### Production (GKE)

**LMS Login:**
- **URL:** https://academyv2.mereka.io/login
- **Direct Admin Panel:** https://academyv2.mereka.io/admin

**MFE Login (if configured):**
- **URL:** https://apps.academyv2.mereka.io/authn/login

## Production Remediation (Explicitly Mutates State)

These commands are idempotent and safe when used intentionally, but they **do write** to service databases/config.

```bash
# Ensure Gurpreet + Malasari are staff/superuser everywhere + CourseCreator in CMS (writes to DB)
./scripts/infra/ensure-platform-admins.sh

# Ensure Authentik admin policy (writes to Authentik DB)
CONFIRM_ENSURE_AUTHENTIK_ADMIN=ENSURE_AUTHENTIK_ADMIN ALLOW_PROD_APPLY=1 \
  ./scripts/infra/ensure-authentik-admin.sh --apply

# Ensure Authentik redirect URIs cover all LMS hostnames (writes to Authentik DB)
CONFIRM_ENSURE_AUTHENTIK_OIDC_REDIRECT_URIS=ENSURE_AUTHENTIK_OIDC_REDIRECT_URIS ALLOW_PROD_APPLY=1 \
  ./scripts/infra/ensure-authentik-oidc-redirect-uris.sh --apply
```

## How To Access Admin (Prod + Dev)

### LMS / CMS

1. Log in to the LMS via:
   - `https://academyv2.mereka.io/login` (prod)
   - `https://academyv2.mereka.dev/login` (dev)
2. Open Django admin:
   - `https://academyv2.mereka.io/admin` (prod)
   - `https://academyv2.mereka.dev/admin` (dev)

### Discovery / Credentials / Ecommerce

These services are hardened so `/admin/login/` redirects to SSO (`/login/`):

1. Start at the service login:
   - `https://discovery.academyv2.mereka.io/login/`
   - `https://credentials.academyv2.mereka.io/login/`
   - `https://ecommerce.academyv2.mereka.io/login/`
2. Then open Django admin:
   - `https://discovery.academyv2.mereka.io/admin/` (etc.)

If you get a 403 after SSO, your account is missing `is_staff` in that service. Fix with:
```bash
./scripts/infra/ensure-platform-admins.sh
```

## Local-Only Troubleshooting: "Too Many Login Attempts"

This section is **LOCAL DEV ONLY** (Tutor containers). Do not run these against production pods.

If you see "Failed login too many attempts" error:

### Quick Fix

```bash
# 1. Clear Django cache
docker exec tutor_local-lms-1 python /openedx/edx-platform/manage.py lms shell -c "from django.core.cache import cache; cache.clear(); print('Cache cleared')"

# 2. Clear all sessions
docker exec tutor_local-lms-1 python /openedx/edx-platform/manage.py lms shell -c "from django.contrib.sessions.models import Session; Session.objects.all().delete(); print('Sessions cleared')"

# 3. Reset admin password (local example)
docker exec tutor_local-lms-1 python /openedx/edx-platform/manage.py lms shell -c "from django.contrib.auth import get_user_model; u = get_user_model().objects.get(username='admin'); u.set_password('admin123'); u.is_active = True; u.is_staff = True; u.is_superuser = True; u.save(); print('Admin reset')"
```

### Automated Fix Script

```bash
./scripts/qa/fix-admin-login.sh
```

## 📋 Admin User Verification

Check if admin user exists and is configured correctly:

```bash
docker exec tutor_local-lms-1 python /openedx/edx-platform/manage.py lms shell -c "
from django.contrib.auth import get_user_model
u = get_user_model().objects.filter(username='admin').first()
if u:
    print('✅ Admin exists')
    print('  Active:', u.is_active)
    print('  Staff:', u.is_staff)
    print('  Superuser:', u.is_superuser)
else:
    print('❌ Admin user not found')
"
```

## 🎯 Access Points

### Admin Panel
- **Local:** http://localhost/admin
- **Production:** https://academyv2.mereka.io/admin

### Studio (Course Authoring)
- **Local:** http://studio.localhost
- **Production:** https://studio.academyv2.mereka.io

### Analytics (Superset)
- **Local:** http://localhost:8088
- **Default credentials:** stored separately from LMS (see analytics docs)

## 📝 Notes

- **Cache Issues (local):** If local login fails, clear cache first.
- **Session Issues (local):** Clear sessions if "too many attempts" error persists.
- **Password Reset (local):** Only reset local passwords if you explicitly need a local-admin backdoor.
- **Browser:** Try incognito/private mode if issues persist
- **Cookies:** Clear browser cookies for localhost if needed
- **Two login flows are expected:** Local username/password (native Open edX) + Authentik OIDC. Both should work; only disable local login if you explicitly want SSO-only.
- **Authentik redirect_uri errors:** Ensure the Authentik allowlist includes the OIDC callback for every LMS hostname
  that can start an OIDC flow (including aliases like Preview and tenant microsites).

  Canonical hostname list:
  - `docs/operations/OPENEDX_HOSTNAMES.md`

  Required callback format:
  - `https://<lms-host>/auth/complete/oidc/`

  Verify from your machine (no credentials):
  ```bash
  ./scripts/qa/verify-auth-surfaces.sh prod
  ./scripts/qa/verify-auth-surfaces.sh dev
  ```

  Verify/Auth fix (kubectl required, no secrets):
  ```bash
  ./scripts/infra/ensure-authentik-oidc-redirect-uris.sh --verify
  ./scripts/infra/ensure-authentik-oidc-redirect-uris.sh --apply
  ```

---

**Last Verified:** 2026-02-06  
**Status:** Admin login working ✅
