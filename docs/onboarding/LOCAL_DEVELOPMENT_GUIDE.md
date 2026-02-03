# Complete Local Development Guide
_For Coding Agents & Developers • Last updated: 2025-11-12_

This guide provides step-by-step instructions for setting up and working with the Mereka Academy Open edX platform locally. **Always work locally first** before touching cloud instances.

## 🎯 Quick Start (New Machine Setup)

### Prerequisites Check

```bash
# Check Docker
docker --version          # Should be 28+
docker compose version    # Should be v2.x

# Check Python
python3 --version        # Should be 3.12+
python3 -m venv --help   # Should work

# Check disk space (need at least 40GB free)
df -h .

# Check Docker Desktop resources (macOS)
# Settings → Resources → Advanced
# RAM: At least 12 GB
# Swap: 2-4 GB
```

### Step 1: Clone Repository

```bash
git clone <repository-url> mereka.academy
cd mereka.academy
```

### Step 2: Create Python Virtual Environment

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install --upgrade pip
pip install "tutor[full]==18.2.2" tutor-mfe==18.1.0
```

### Step 3: Configure Docker Desktop (macOS)

**Critical:** Configure Docker Desktop before building images:

1. Open Docker Desktop
2. Go to Settings → Resources → Advanced
3. Set:
   - **RAM:** 12 GB minimum (16 GB recommended)
   - **Swap:** 2-4 GB
   - **Disk image size:** 100 GB+
4. Click "Apply & Restart"

Verify:
```bash
docker info | grep "Total Memory"
```

### Step 4: Set Up Tutor Environment

```bash
# Source the environment helper (do this in every new shell)
source infrastructure/tutor/tutor-env.sh

# Verify Tutor is configured correctly
tutor config printroot
# Should show: /path/to/mereka.academy/tutor_env
```

### Step 5: Configure Local Services

**CRITICAL:** Always use local Docker service names, NOT cloud IPs:

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

# Apply patches (fixes MySQL config, MFE builds, etc.)
./infrastructure/tutor/apply-patches.sh
```

**Verify config is local:**
```bash
grep -E "MYSQL_HOST|MONGODB_HOST|REDIS_HOST" tutor_env/config.yml
# Should show: mysql, mongodb, redis (NOT cloud IPs like 10.97.0.2)
```

### Step 6: Build Images

```bash
# Build OpenEdX image (takes 20-30 minutes, needs 12GB+ RAM)
tutor images build openedx

# Build MFE image (takes 15-20 minutes)
tutor images build mfe
```

### Step 7: Initialize and Launch

```bash
# First-time launch (runs migrations, creates databases)
tutor local launch -I --skip-build

# Apply patches again after launch
./infrastructure/tutor/apply-patches.sh

# Restart services
tutor local restart
```

### Step 8: Create Admin User

```bash
export TUTOR_ROOT="$(pwd)/tutor_env"
source .venv/bin/activate

# Create admin user
docker exec tutor_local-lms-1 python /openedx/edx-platform/manage.py lms manage_user --superuser --staff admin admin@mereka.academy
docker exec tutor_local-lms-1 python /openedx/edx-platform/manage.py lms shell -c "from django.contrib.auth import get_user_model; u = get_user_model().objects.get(username='admin'); u.set_password('admin123'); u.is_staff = True; u.is_superuser = True; u.save(); print('✅ Admin user created')"
```

### Step 9: Verify Everything Works

```bash
# Check all containers are running
docker ps --filter "name=tutor_local" --format "{{.Names}}\t{{.Status}}" | grep -v "Up"

# Test URLs
curl -I http://localhost                    # LMS - should return 200 or 302
curl -I http://studio.localhost             # Studio - should return 200 or 302
curl -I http://apps.localhost/authn/login   # MFE Login - should return 200
curl -I http://localhost/admin              # Admin - should return 302 (redirects to login)

# Check logs for errors
tutor local logs --tail=20 lms | grep -i error
tutor local logs --tail=20 cms | grep -i error
```

## 🔄 Daily Workflow

### Starting Your Day

```bash
# 1. Navigate to repo
cd /path/to/mereka.academy

# 2. Source environment
source infrastructure/tutor/tutor-env.sh

# 3. Start services
tutor local start -d

# 4. Verify services are up
docker ps --filter "name=tutor_local" | wc -l
# Should show 24 containers
```

### Making Configuration Changes

**After ANY config change:**

```bash
export TUTOR_ROOT="$(pwd)/tutor_env"
source .venv/bin/activate

# 1. Save config
tutor config save --set KEY=value

# 2. ALWAYS apply patches
./infrastructure/tutor/apply-patches.sh

# 3. Restart affected services
tutor local restart lms cms mfe
```

### Stopping Services

```bash
tutor local stop
```

## 🚨 Common Issues & Fixes

### Issue: "Can't connect to MySQL server on 'mysql'"

**Symptoms:** LMS/CMS containers restarting, 500 errors

**Fix:**
```bash
# Check MySQL is running
docker ps --filter "name=mysql"

# Check config uses local service name
grep MYSQL_HOST tutor_env/config.yml
# Should show: MYSQL_HOST: mysql

# Restart MySQL
tutor local restart mysql
sleep 10
tutor local restart lms cms
```

### Issue: MFE Login Shows White Screen / Error

**Symptoms:** http://apps.localhost/authn/login shows error

**Fix:**
```bash
# 1. Check MFE config API
curl http://localhost/api/mfe_config/v1?mfe=authn
# Should return JSON, not 500

# 2. Rebuild MFE image if authn is missing
tutor images build mfe
tutor local restart mfe

# 3. Verify authn directory exists
docker exec tutor_local-mfe-1 ls -la /openedx/dist/authn
```

### Issue: Containers Keep Restarting

**Fix:**
```bash
# Check logs
tutor local logs --tail=50 <service-name>

# Common causes:
# - MySQL connection issues → Fix config, restart MySQL
# - Missing database users → Run: tutor local do init
# - Port conflicts → Check: lsof -i :8000
```

### Issue: Config Points to Cloud IPs

**Symptoms:** `grep MYSQL_HOST tutor_env/config.yml` shows `10.97.0.2` instead of `mysql`

**Fix:**
```bash
export TUTOR_ROOT="$(pwd)/tutor_env"
source .venv/bin/activate

tutor config save \
  --set MYSQL_HOST=mysql \
  --set MONGODB_HOST=mongodb \
  --set REDIS_HOST=redis

./infrastructure/tutor/apply-patches.sh
tutor local restart
```

### Issue: Docker Out of Space

**Fix:**
```bash
# Clean up unused Docker resources
./scripts/infra/docker-cleanup.sh --execute

# Or manually:
docker system prune -a --volumes
```

## 📋 Verification Checklist

Before starting work, verify:

- [ ] `TUTOR_ROOT` is set correctly
- [ ] Config uses local service names (`mysql`, `mongodb`, `redis`)
- [ ] All 24 containers are running: `docker ps --filter "name=tutor_local" | wc -l`
- [ ] LMS accessible: `curl -I http://localhost` returns 200/302
- [ ] Studio accessible: `curl -I http://studio.localhost` returns 200/302
- [ ] MFE login accessible: `curl -I http://apps.localhost/authn/login` returns 200
- [ ] No errors in logs: `tutor local logs --tail=20 lms | grep -i error`

## 🌐 Access URLs

Once everything is running:

- **LMS:** http://localhost
- **Studio:** http://studio.localhost
- **MFE Login:** http://apps.localhost/authn/login
- **Admin Panel:** http://localhost/admin
- **Account MFE:** http://apps.localhost/account
- **Profile MFE:** http://apps.localhost/profile
- **Discovery:** http://discovery.localhost
- **Ecommerce:** http://ecommerce.localhost

**Default Credentials:**
- Username: `admin`
- Password: `admin123`

## 🔧 Useful Commands

### Container Management
```bash
tutor local start -d          # Start all services
tutor local stop              # Stop all services
tutor local restart <service> # Restart specific service
tutor local dc ps             # List all containers
tutor local logs --tail=50 <service>  # View logs
```

### Database Operations
```bash
# Create user
docker exec tutor_local-lms-1 python /openedx/edx-platform/manage.py lms manage_user --superuser --staff <username> <email>

# Django shell
docker exec -it tutor_local-lms-1 python /openedx/edx-platform/manage.py lms shell

# Run migrations
tutor local do migrate
```

### Image Rebuilding
```bash
tutor images build openedx    # Rebuild LMS/Studio (20-30 min)
tutor images build mfe        # Rebuild MFEs (15-20 min)
```

### Clean Slate
```bash
# WARNING: Deletes all local data
tutor local stop
rm -rf tutor_env/data/*
tutor local launch -I --skip-build
./infrastructure/tutor/apply-patches.sh
```

## 📝 Important Notes

1. **Always set `TUTOR_ROOT`** before running Tutor commands:
   ```bash
   export TUTOR_ROOT="$(pwd)/tutor_env"
   ```

2. **Always run `./infrastructure/tutor/apply-patches.sh`** after:
   - `tutor config save`
   - Plugin changes
   - Tutor upgrades

3. **Never commit `tutor_env/config.yml`** - it contains secrets and is git-ignored

4. **Work locally first** - Verify everything works locally before deploying to cloud

5. **Check config regularly** - Ensure it uses local Docker services, not cloud IPs

## 🆘 Getting Help

If something doesn't work:

1. Check logs: `tutor local logs --tail=50 <service>`
2. Verify config: `grep -E "MYSQL_HOST|MONGODB_HOST" tutor_env/config.yml`
3. Check containers: `docker ps --filter "name=tutor_local"`
4. Review this guide's "Common Issues" section
5. Check `docs/operations/TROUBLESHOOTING.md` for more detailed troubleshooting

---

**Remember:** Local development is your sandbox. Experiment freely, but always verify locally before touching production!

