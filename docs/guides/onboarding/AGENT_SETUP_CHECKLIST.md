# Agent Setup Checklist

_Audience: Agent Operators • Owner: Platform Team • Last verified: 2026-04-22 • Status: supporting_

## ✅ Pre-Flight Checklist

Before starting, verify:
- [ ] Docker Desktop installed and running
- [ ] Docker Desktop configured: 12 GB+ RAM, 2-4 GB swap
- [ ] Python 3.12+ installed
- [ ] At least 40 GB free disk space
- [ ] Git repository cloned
- [ ] Submodules initialized with `git submodule update --init --recursive`

## 📋 Setup Steps (In Order)

### Recommended Path

Use the repo-owned setup script unless you are debugging one specific phase:

```bash
cd /path/to/mereka-lms
git submodule update --init --recursive
./scripts/qa/verify-cold-start-onboarding-contract.sh
./scripts/shared/setup-local.sh
./scripts/infra/verify-local-bootstrap-readiness.sh
```

The setup script creates or reuses `.venv`, renders Tutor through the canonical
wrapper, prepares the rendered build contexts, builds `openedx:nightly` and
`openedx-mfe:nightly` when their build-context labels are stale, launches the
local Tutor stack, verifies readiness, and creates a local-only admin user.
If `LOCAL_ADMIN_PASSWORD` is unset, generated credentials are written to
`tutor_env/local-admin-credentials.txt`.

### 1. Python Environment
```bash
cd /path/to/mereka-lms
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
**CRITICAL:** Must use the canonical wrapper and local Docker service names:

```bash
export TUTOR_ROOT="$(pwd)/tutor_env"
source .venv/bin/activate

./scripts/infra/tutor-config-save.sh \
  --set LMS_HOST=localhost \
  --set CMS_HOST=studio.localhost \
  --set MFE_HOST=apps.localhost \
  --set RUN_MONGODB=true \
  --set RUN_MYSQL=true \
  --set RUN_REDIS=true \
  --set RUN_MEILISEARCH=true \
  --set RUN_SMTP=true \
  --set DOCKER_REGISTRY=mirror.gcr.io/ \
  --set DOCKER_IMAGE_OPENEDX=openedx:nightly \
  --set MFE_DOCKER_IMAGE=openedx-mfe:nightly \
  --set DOCKER_IMAGE_CADDY=mirror.gcr.io/library/caddy:2.7.4 \
  --set DOCKER_IMAGE_MEILISEARCH=mirror.gcr.io/getmeili/meilisearch:v1.8.4 \
  --set DOCKER_IMAGE_MONGODB=mirror.gcr.io/library/mongo:7.0.28 \
  --set DOCKER_IMAGE_MYSQL=mirror.gcr.io/library/mysql:8.4.0 \
  --set DOCKER_IMAGE_REDIS=mirror.gcr.io/library/redis:7.4.5 \
  --set DOCKER_IMAGE_SMTP=mirror.gcr.io/devture/exim-relay:4.96-r1-0 \
  --set OPENEDX_COMMON_VERSION=release/ulmo \
  --set OPENEDX_LMS_VERSION=release/ulmo \
  --set OPENEDX_CMS_VERSION=release/ulmo \
  --set MFE_COMMON_VERSION=release/ulmo.2 \
  --set MYSQL_HOST=mysql \
  --set MONGODB_HOST=mongodb \
  --set REDIS_HOST=redis \
  --set MONGODB_PORT=27017 \
  --set MYSQL_PORT=3306 \
  --set MYSQL_ROOT_HOST=% \
  --set REDIS_PORT=6379
```

**Verify config:**
```bash
grep -E "MYSQL_HOST|MONGODB_HOST|REDIS_HOST" tutor_env/config.yml
# Should show: mysql, mongodb, redis (NOT cloud IPs like 10.97.0.2)
```

### 5. Build Images
```bash
./scripts/infra/prepare-tutor-build-context.sh --target all
./scripts/infra/ensure-buildx-dependency-mirror.sh

# OpenEdX image (20-30 minutes, needs 12GB+ RAM)
./scripts/infra/build-openedx-image.sh --local-defaults --build-profile fast

# MFE image (15-20 minutes)
./scripts/infra/build-mfe-image.sh --local-defaults --build-profile fast
```

### 6. Initialize and Launch
```bash
# First-time launch (runs migrations, creates databases)
tutor local launch -I --skip-build

# Bring the stack up after first-launch init
make tutor-start
```

### 7. Local Admin Fallback

`./scripts/shared/setup-local.sh` already creates or refreshes a local admin
user. If `LOCAL_ADMIN_PASSWORD` is unset, it writes generated credentials to
`tutor_env/local-admin-credentials.txt`. Only run the command below if that
file is missing, or if you deliberately want to rotate the local-only password.

```bash
export LOCAL_ADMIN_PASSWORD='<choose-a-local-only-password>'
docker exec \
  -e LOCAL_ADMIN_USERNAME=admin \
  -e LOCAL_ADMIN_EMAIL=admin@mereka.academy \
  -e LOCAL_ADMIN_PASSWORD="$LOCAL_ADMIN_PASSWORD" \
  tutor_local-lms-1 python /openedx/edx-platform/manage.py lms shell -c "
import os
from django.contrib.auth import get_user_model
User = get_user_model()
username = os.environ['LOCAL_ADMIN_USERNAME']
email = os.environ['LOCAL_ADMIN_EMAIL']
password = os.environ['LOCAL_ADMIN_PASSWORD']
try:
    user = User.objects.get(username=username)
except User.DoesNotExist:
    user = User.objects.create_user(username, email, password)
user.email = email
user.set_password(password)
user.is_active = True
user.is_staff = True
user.is_superuser = True
user.save()
print('Local admin ready')
"
```

## ✅ Verification Steps

Run these to confirm everything works:

```bash
# 1. Check containers
docker ps --filter "name=tutor_local" | wc -l
# Expect 20+ containers on a full local stack; trust
# ./scripts/infra/verify-local-bootstrap-readiness.sh over a magic count.

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
# Should return: HTTP/1.1 200 OK or 302 Found

# 6. Run the canonical readiness verifier
./scripts/infra/verify-local-bootstrap-readiness.sh

# 7. Check for errors
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
./scripts/infra/tutor-config-save.sh \
  --set MYSQL_HOST=mysql \
  --set MONGODB_HOST=mongodb \
  --set REDIS_HOST=redis \
  --set RUN_MONGODB=true \
  --set DOCKER_IMAGE_OPENEDX=openedx:nightly \
  --set MFE_DOCKER_IMAGE=openedx-mfe:nightly
make tutor-restart
```

### Issue: Docker out of memory during build
**Fix:** Increase Docker Desktop RAM to 16 GB and retry

### Issue: MySQL connection errors
**Fix:** Wait for MySQL to fully start (30 seconds), then:
```bash
tutor local restart mysql
sleep 15
tutor local restart lms cms
./scripts/infra/verify-local-bootstrap-readiness.sh
```

## 📚 Next Steps

Once setup is complete:
1. Read `docs/guides/onboarding/LOCAL_SETUP.md` for the full canonical setup
2. Bookmark `docs/guides/onboarding/QUICK_START_LOCAL.md` for fast restarts
3. Use `docs/guides/onboarding/WORKFLOW_LOCAL.md` for day-to-day work
4. Review `AGENTS.md` for coding guidelines

## 🔗 Quick Links

- **Complete Guide:** `docs/guides/onboarding/LOCAL_SETUP.md`
- **Quick Reference:** `docs/guides/onboarding/QUICK_START_LOCAL.md`
- **Daily Workflow:** `docs/guides/onboarding/WORKFLOW_LOCAL.md`
- **Access Info:** `docs/ops/quickref/access-urls.md`

---

**Setup Time:** ~45-60 minutes on a warm, well-resourced machine; first boot can take longer.
**Status:** Ready for development once `verify-local-bootstrap-readiness.sh` passes.
