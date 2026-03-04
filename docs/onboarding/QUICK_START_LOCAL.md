# Quick Start: Local Development Setup

<!-- Last verified: 2026-02-13 -->
_For Coding Agents • 5-minute setup guide_

## 🚀 Fast Setup (Copy-Paste Ready)

```bash
# 1. Clone and enter repo
cd /path/to/mereka.academy

# 2. Create Python environment
python3 -m venv .venv
source .venv/bin/activate
pip install --upgrade pip
pip install -r requirements-tutor.txt

# 3. Configure Docker Desktop (macOS)
# Open Docker Desktop → Settings → Resources → Advanced
# Set RAM: 12 GB, Swap: 2-4 GB, then Apply & Restart

# 4. Set up Tutor
source infrastructure/tutor/tutor-env.sh
export TUTOR_ROOT="$(pwd)/tutor_env"

# 5. Configure local services (IMPORTANT: use local Docker names)
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

# 6. Apply patches (fixes MySQL, MFE configs)
./infrastructure/tutor/apply-patches.sh

# 7. Build images (first time only, takes 30-45 min total)
tutor images build openedx
tutor images build mfe

# 8. Launch services
tutor local launch -I --skip-build
./infrastructure/tutor/apply-patches.sh
tutor local restart

# 9. Create admin user
docker exec tutor_local-lms-1 python /openedx/edx-platform/manage.py lms manage_user --superuser --staff admin admin@mereka.academy
docker exec tutor_local-lms-1 python /openedx/edx-platform/manage.py lms shell -c "from django.contrib.auth import get_user_model; u = get_user_model().objects.get(username='admin'); u.set_password('admin123'); u.is_staff = True; u.is_superuser = True; u.save(); print('✅ Admin created')"

# 10. Verify
curl -I http://localhost
curl -I http://apps.localhost/authn/login
```

## ✅ Verification Checklist

Run these to verify everything works:

```bash
# Check containers
docker ps --filter "name=tutor_local" | wc -l
# Should show: 24

# Check config is local (not cloud)
grep -E "MYSQL_HOST|MONGODB_HOST" tutor_env/config.yml
# Should show: mysql, mongodb (NOT 10.97.0.2)

# Test URLs
curl -I http://localhost                    # LMS
curl -I http://studio.localhost             # Studio  
curl -I http://apps.localhost/authn/login   # MFE Login
```

## 🔄 Daily Commands

```bash
# Start
source infrastructure/tutor/tutor-env.sh
export TUTOR_ROOT="$(pwd)/tutor_env"
tutor local start -d

# Stop
tutor local stop

# After config changes
tutor config save --set KEY=value
./infrastructure/tutor/apply-patches.sh  # CRITICAL!
tutor local restart
```

## 🆘 Common Issues

**"Can't connect to MySQL"**
```bash
grep MYSQL_HOST tutor_env/config.yml  # Should be "mysql"
tutor local restart mysql
sleep 10
tutor local restart lms cms
```

**"MFE login white screen"**
```bash
curl http://localhost/api/mfe_config/v1?mfe=authn  # Check API
tutor images build mfe  # Rebuild if needed
tutor local restart mfe
```

**Config shows cloud IPs**
```bash
tutor config save --set MYSQL_HOST=mysql --set MONGODB_HOST=mongodb
./infrastructure/tutor/apply-patches.sh
tutor local restart
```

## 📚 Full Documentation

- **Complete Guide:** `docs/onboarding/LOCAL_DEVELOPMENT_GUIDE.md`
- **Workflow:** `docs/onboarding/WORKFLOW_LOCAL.md`
- **Setup Details:** `docs/onboarding/LOCAL_SETUP.md`
- **Troubleshooting:** `docs/operations/TROUBLESHOOTING.md`

## 🌐 Access URLs

- LMS: http://localhost
- Studio: http://studio.localhost
- MFE Login: http://apps.localhost/authn/login
- Admin: http://localhost/admin
- Credentials: `admin` / `admin123`

---

**Remember:** Always verify config uses local Docker services (`mysql`, `mongodb`, `redis`) not cloud IPs!

