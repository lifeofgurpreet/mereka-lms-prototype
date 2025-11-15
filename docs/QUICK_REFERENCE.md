# Quick Reference Card
_For Daily Use • Last updated: 2025-11-12_

## 🚀 Start Your Day

```bash
cd /path/to/mereka.academy
source ops/tutor-env.sh
export TUTOR_ROOT="$(pwd)/tutor_env"
tutor local start -d
```

## 🔐 Login

**URLs:**
- LMS: http://localhost/login
- MFE: http://apps.localhost/authn/login
- Admin: http://localhost/admin
- Studio: http://studio.localhost

**Credentials:**
- Username: `admin`
- Password: `admin123`

## 🛠️ Common Tasks

### After Config Changes
```bash
tutor config save --set KEY=value
./ops/tutor/apply-patches.sh
tutor local restart
```

### Fix Admin Login
```bash
./tools/fix-admin-login.sh
```

### Check Parity
```bash
./tools/check-parity.sh
```

### Run Tests
```bash
./tools/comprehensive-test.sh
```

### View Logs
```bash
tutor local logs --tail=50 <service>
```

## 📊 Access Analytics

**Superset:** http://localhost:8088
```bash
grep SUPERSET_ADMIN tutor_env/config.yml  # Get credentials
```

## 🆘 Quick Fixes

**Too many login attempts:**
```bash
./tools/fix-admin-login.sh
```

**Config has cloud IPs:**
```bash
./tools/fix-parity.sh
```

**Services not starting:**
```bash
tutor local restart
docker ps --filter "name=tutor_local"
```

## 📚 Documentation

- **Setup:** `docs/LOCAL_DEVELOPMENT_GUIDE.md`
- **URLs:** `docs/ACCESS_URLS.md`
- **Admin:** `docs/ADMIN_LOGIN_GUIDE.md`
- **Analytics:** `docs/ANALYTICS_ACCESS.md`
- **Status:** `docs/OPERATIONAL_STATUS.md`

## ✅ Health Check

```bash
# Quick check
curl -I http://localhost
curl -I http://apps.localhost/authn/login

# Full check
./tools/comprehensive-test.sh
```

---
**Keep this handy!** 📌
