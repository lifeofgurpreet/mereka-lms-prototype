# Admin Login Guide
_Last updated: 2025-11-12_

## 🔐 Admin Credentials

**Username:** `admin`  
**Password:** `admin123`  
**Email:** `admin@mereka.academy`

## 🌐 Login URLs

### Local Development

**Option 1: LMS Login (Legacy)**
- **URL:** http://localhost/login
- **Direct Admin Panel:** http://localhost/admin

**Option 2: MFE Login (Modern)**
- **URL:** http://apps.localhost/authn/login
- **Note:** This uses the modern micro-frontend interface

### Staging/Production

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

# 3. Reset admin password
docker exec tutor_local-lms-1 python /openedx/edx-platform/manage.py lms shell -c "from django.contrib.auth import get_user_model; u = get_user_model().objects.get(username='admin'); u.set_password('admin123'); u.is_active = True; u.is_staff = True; u.is_superuser = True; u.save(); print('Admin reset')"
```

### Automated Fix Script

```bash
./tools/fix-admin-login.sh
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

## 🔄 Create New Admin User

If admin user doesn't exist:

```bash
# Method 1: Using Django shell
docker exec tutor_local-lms-1 python /openedx/edx-platform/manage.py lms shell -c "
from django.contrib.auth import get_user_model
User = get_user_model()
u = User.objects.create_user('admin', 'admin@mereka.academy', 'admin123')
u.is_staff = True
u.is_superuser = True
u.is_active = True
u.save()
print('✅ Admin user created')
"

# Method 2: Using manage_user command
docker exec tutor_local-lms-1 python /openedx/edx-platform/manage.py lms manage_user --superuser --staff admin admin@mereka.academy
docker exec tutor_local-lms-1 python /openedx/edx-platform/manage.py lms shell -c "from django.contrib.auth import get_user_model; u = get_user_model().objects.get(username='admin'); u.set_password('admin123'); u.save()"
```

## 🎯 Access Points

### Admin Panel
- **Local:** http://localhost/admin
- **Staging:** https://academyv2.mereka.io/admin

### Studio (Course Authoring)
- **Local:** http://studio.localhost
- **Staging:** https://studio.academyv2.mereka.io

### Analytics (Superset)
- **Local:** http://localhost:8088
- **Default credentials:** admin/admin (may need to be configured)

## 📝 Notes

- **Cache Issues:** If login fails, clear cache first
- **Session Issues:** Clear sessions if "too many attempts" error persists
- **Password Reset:** Always reset password after clearing sessions
- **Browser:** Try incognito/private mode if issues persist
- **Cookies:** Clear browser cookies for localhost if needed

---

**Last Verified:** 2025-11-12  
**Status:** Admin login working ✅

