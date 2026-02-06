# Admin Login Guide
_Last updated: 2026-02-06_

## 🔐 Shared SSO Test Credentials (Source of Truth)

**Infisical path:** `/shared/oauth`  
**Email secret:** `GOOGLE_IMPERSONATE_EMAIL`  
**Password secret:** `GOOGLE_IMPERSONATE_PASSWORD`

Use these shared credentials for:
- **GKE production** (`academyv2.mereka.io`)
- **VPS kind dev** (`academyv2.mereka.dev`)
- **Authentik OIDC login** as an end-user (auth0.mereka.io)

Authentik **admin UI access** is separate from Open edX admin access and is restricted to Gurpreet
(see `docs/operations/AUTH_AND_PERMISSIONS.md`).

## ✅ Required Platform Admins

These humans must have full admin permissions across the Open edX ecosystem:
- `gurpreet@biji-biji.com`
- `malasari@mereka.my`

Notes:
- These are **your actual platform admin accounts** (full permissions everywhere in Open edX services).
- The shared credentials above are for **testing SSO flows** and are not a substitute for platform-admin access.

Enforce (prod + dev, idempotent):
```bash
./scripts/infra/ensure-platform-admins.sh
```

**Note:** Authentik handles authentication (OIDC). Open edX (and related services) handle authorization
(`is_staff`, `is_superuser`, `CourseCreator`). These permissions do not sync from Authentik by default.

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

## 🚨 Troubleshooting "Too Many Login Attempts"

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

## 🔄 Sync Admin User (GKE + Kind)

Use Infisical to pull the shared credentials and sync to LMS:

```bash
cd /home/gurpreet/projects/k8s/reka-slackbot
EMAIL=$(infisical secrets get GOOGLE_IMPERSONATE_EMAIL --domain https://secrets.mereka.io/api --env prod --path /shared/oauth --plain 2>/dev/null)
PASSWORD=$(infisical secrets get GOOGLE_IMPERSONATE_PASSWORD --domain https://secrets.mereka.io/api --env prod --path /shared/oauth --plain 2>/dev/null)

printf "%s\n%s\n" "$EMAIL" "$PASSWORD" | kubectl exec -i -n mereka-lms deploy/lms -- python manage.py lms shell --settings=tutor.production -c \
"import sys; from django.contrib.auth import get_user_model; User=get_user_model(); email=sys.stdin.readline().strip(); password=sys.stdin.readline().strip(); user=User.objects.filter(email=email).first() or User.objects.filter(username=email).first() or User.objects.create_user(username=email, email=email, password=password); user.set_password(password); user.is_active=True; user.is_staff=True; user.is_superuser=True; user.save(); print(f'✅ Admin synced: {user.username}')"
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

- **Cache Issues:** If login fails, clear cache first
- **Session Issues:** Clear sessions if "too many attempts" error persists
- **Password Reset:** Always reset password after clearing sessions
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
