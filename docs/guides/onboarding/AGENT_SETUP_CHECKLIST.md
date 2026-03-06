# Agent Setup Checklist

_Audience: Agent Operators • Owner: Platform Team • Last verified: 2026-03-06 • Status: supporting_

## ✅ Pre-Flight Checklist

Before starting, verify:
- [ ] Docker Desktop installed and running
- [ ] Docker Desktop configured: 12 GB+ RAM, 2-4 GB swap
- [ ] Python 3.12+ installed
- [ ] At least 40 GB free disk space
- [ ] Git repository cloned

## 📋 Setup Steps (In Order)

### 1. Python Environment
```bash
cd /path/to/mereka.academy
python3 -m venv .venv
source .venv/bin/activate
pip install --upgrade pip
pip install -r requirements-tutor.txt
```

### 2. Docker Desktop Configuration
**macOS:**
1. Open Docker Desktop
2. Settings → Resources → Advanced
3. Set RAM: 12 GB minimum
4. Set Swap: 2-4 GB
5. Click "Apply & Restart"

**Verify:**
```bash
docker info | grep "Total Memory"
```

### 3. Tutor Environment Setup
```bash
source infrastructure/tutor/tutor-env.sh
export TUTOR_ROOT="$(pwd)/tutor_env"
tutor config printroot  # Should show tutor_env path
```

### 4. Configure Local Services
**CRITICAL:** Must use local Docker service names:

```bash
export TUTOR_ROOT="$(pwd)/tutor_env"
source .venv/bin/activate

tutor config save \
  --set LMS_HOST=localhost \
  --set CMS_HOST=studio.localhost \
  --set MFE_HOST=apps.localhost \
  --set MYSQL_HOST=mysql \
  --set MONGODB_HOST=mongodb \
  --set REDIS_HOST=redis \
  --set MONGODB_PORT=27017 \
  --set MYSQL_PORT=3306 \
  --set REDIS_PORT=6379

# ALWAYS run patches after config save
./infrastructure/tutor/apply-patches.sh
```

**Verify config:**
```bash
grep -E "MYSQL_HOST|MONGODB_HOST|REDIS_HOST" tutor_env/config.yml
# Should show: mysql, mongodb, redis (NOT cloud IPs like 10.97.0.2)
```

### 5. Build Images
```bash
# OpenEdX image (20-30 minutes, needs 12GB+ RAM)
tutor images build openedx

# MFE image (15-20 minutes)
tutor images build mfe
```

### 6. Initialize and Launch
```bash
# First-time launch (runs migrations, creates databases)
tutor local launch -I --skip-build

# Apply patches again
./infrastructure/tutor/apply-patches.sh

# Restart services
tutor local restart
```

### 7. Create Admin User
```bash
docker exec tutor_local-lms-1 python /openedx/edx-platform/manage.py lms manage_user --superuser --staff admin admin@mereka.academy
docker exec tutor_local-lms-1 python /openedx/edx-platform/manage.py lms shell -c "from django.contrib.auth import get_user_model; u = get_user_model().objects.get(username='admin'); u.set_password('admin123'); u.is_staff = True; u.is_superuser = True; u.save(); print('✅ Admin created')"
```

## ✅ Verification Steps

Run these to confirm everything works:

```bash
# 1. Check containers (should be 24)
docker ps --filter "name=tutor_local" | wc -l

# 2. Check config uses local services
grep MYSQL_HOST tutor_env/config.yml
# Should show: MYSQL_HOST: mysql

# 3. Test LMS
curl -I http://localhost
# Should return: HTTP/1.1 200 OK or 302 Found

# 4. Test Studio
curl -I http://studio.localhost
# Should return: HTTP/1.1 200 OK or 302 Found

# 5. Test MFE Login
curl -I http://apps.localhost/authn/login
# Should return: HTTP/1.1 200 OK

# 6. Check for errors
tutor local logs --tail=20 lms | grep -i error
# Should be empty or show only warnings
```

## 🚨 Common First-Time Issues

### Issue: "Python virtualenv not found"
**Fix:** Make sure you're in the repo root and `.venv` exists:
```bash
ls -la .venv
python3 -m venv .venv  # If missing
```

### Issue: "Tutor command not found"
**Fix:** Activate venv:
```bash
source .venv/bin/activate
source infrastructure/tutor/tutor-env.sh
```

### Issue: Config shows cloud IPs
**Fix:** Reconfigure immediately:
```bash
export TUTOR_ROOT="$(pwd)/tutor_env"
tutor config save --set MYSQL_HOST=mysql --set MONGODB_HOST=mongodb
./infrastructure/tutor/apply-patches.sh
tutor local restart
```

### Issue: Docker out of memory during build
**Fix:** Increase Docker Desktop RAM to 16 GB and retry

### Issue: MySQL connection errors
**Fix:** Wait for MySQL to fully start (30 seconds), then:
```bash
tutor local restart mysql
sleep 15
tutor local restart lms cms
```

## 📚 Next Steps

Once setup is complete:
1. Read `docs/guides/onboarding/LOCAL_DEVELOPMENT_GUIDE.md` for detailed workflows
2. Bookmark `docs/guides/onboarding/QUICK_START_LOCAL.md` for daily reference
3. Review `AGENTS.md` for coding guidelines

## 🔗 Quick Links

- **Complete Guide:** `docs/guides/onboarding/LOCAL_DEVELOPMENT_GUIDE.md`
- **Quick Reference:** `docs/guides/onboarding/QUICK_START_LOCAL.md`
- **Daily Workflow:** `docs/guides/onboarding/WORKFLOW_LOCAL.md`
- **Access Info:** `docs/ops/quickref/local-access-info.md`

---

**Setup Time:** ~45-60 minutes (mostly waiting for image builds)  
**Status:** Ready for development once all checks pass ✅

