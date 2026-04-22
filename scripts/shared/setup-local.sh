#!/usr/bin/env bash
# One-Click Local Development Setup
# This script sets up everything needed for local development
set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║        One-Click Local Development Setup                     ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

# Step 1: Prerequisites Check
echo -e "${BLUE}Step 1: Checking prerequisites...${NC}"
if ! command -v docker &> /dev/null; then
    echo -e "${RED}❌ Docker not found. Please install Docker Desktop.${NC}"
    exit 1
fi
if ! docker info &> /dev/null; then
    echo -e "${RED}❌ Docker not running. Please start Docker Desktop.${NC}"
    exit 1
fi
if ! command -v python3 &> /dev/null; then
    echo -e "${RED}❌ Python 3 not found. Please install Python 3.12+.${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Prerequisites check passed${NC}"
echo ""

# Step 2: Python Environment
echo -e "${BLUE}Step 2: Setting up Python environment...${NC}"
if [ ! -d ".venv" ]; then
    python3 -m venv .venv
    echo -e "${GREEN}✅ Created virtual environment${NC}"
else
    echo -e "${YELLOW}⚠️  Virtual environment already exists${NC}"
fi

if [[ -f .venv/bin/activate ]]; then
    # shellcheck source=/dev/null
    source .venv/bin/activate
else
    echo -e "${RED}ERROR: .venv/bin/activate not found. Run 'python3 -m venv .venv' first.${NC}"
    exit 1
fi
pip install --upgrade pip --quiet
pip install -r requirements-tutor.txt --quiet
echo -e "${GREEN}✅ Python environment ready${NC}"
echo ""

# Step 3: Tutor Environment
echo -e "${BLUE}Step 3: Configuring Tutor environment...${NC}"
# shellcheck source=/dev/null
source infrastructure/tutor/tutor-env.sh
export TUTOR_ROOT="$REPO_ROOT/tutor_env"

if [ ! -f "tutor_env/config.yml" ]; then
    echo -e "${YELLOW}⚠️  Config file not found, creating from example...${NC}"
    mkdir -p tutor_env
    cp infrastructure/tutor/config.example.yml tutor_env/config.yml
fi

# Ensure local Docker services are configured
./scripts/infra/tutor-config-save.sh \
    --set LMS_HOST=localhost \
    --set CMS_HOST=studio.localhost \
    --set MFE_HOST=apps.localhost \
    --set DISCOVERY_HOST=discovery.localhost \
    --set ECOMMERCE_HOST=ecommerce.localhost \
    --set XQUEUE_HOST=xqueue.localhost \
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
    --set MFE_COMMON_VERSION=release/ulmo.2 \
    --set MYSQL_HOST=mysql \
    --set MONGODB_HOST=mongodb \
    --set REDIS_HOST=redis \
    --set MONGODB_PORT=27017 \
    --set MYSQL_PORT=3306 \
    --set MYSQL_ROOT_HOST=% \
    --set REDIS_PORT=6379 \
    --set ASPECTS_SUPERSET_DATABASE_HOST=clickhouse

echo -e "${GREEN}✅ Tutor configured${NC}"
echo ""

# Step 4: Build Images (if needed)
echo -e "${BLUE}Step 4: Checking Docker images...${NC}"
./scripts/infra/ensure-buildx-dependency-mirror.sh
source "$REPO_ROOT/scripts/infra/build-context-fingerprint.sh"
FORCE_LOCAL_IMAGE_BUILD="${FORCE_LOCAL_IMAGE_BUILD:-0}"

image_matches_context() {
    local image_ref="$1"
    local context_dir="$2"
    local expected_sha
    local actual_sha

    docker image inspect "$image_ref" >/dev/null 2>&1 || return 1
    expected_sha="$(mereka_build_context_fingerprint "$context_dir")"
    actual_sha="$(docker image inspect \
        --format '{{ index .Config.Labels "io.mereka.build-context-sha256" }}' \
        "$image_ref" 2>/dev/null || true)"

    [[ -n "$actual_sha" && "$actual_sha" == "$expected_sha" ]]
}

if [[ "$FORCE_LOCAL_IMAGE_BUILD" == "1" ]] || ! image_matches_context openedx:nightly tutor_env/env/build/openedx; then
    echo -e "${YELLOW}⚠️  OpenEdX image missing or stale. Building fast local image (this still takes time)...${NC}"
    ./scripts/infra/build-openedx-image.sh --local-defaults --build-profile fast
else
    echo -e "${GREEN}✅ OpenEdX image matches current rendered build context${NC}"
fi

if [[ "$FORCE_LOCAL_IMAGE_BUILD" == "1" ]] || ! image_matches_context openedx-mfe:nightly tutor_env/env/plugins/mfe/build/mfe; then
    echo -e "${YELLOW}⚠️  MFE image missing or stale. Building fast local image (this still takes time)...${NC}"
    ./scripts/infra/build-mfe-image.sh --local-defaults --build-profile fast
else
    echo -e "${GREEN}✅ MFE image matches current rendered build context${NC}"
fi
echo ""

# Step 5: Initialize Database
echo -e "${BLUE}Step 5: Initializing database...${NC}"
if [ ! -d "tutor_env/data/mysql" ]; then
    echo -e "${YELLOW}⚠️  Database not initialized. Running init (this takes 5-10 minutes)...${NC}"
    tutor local launch -I --skip-build
else
    echo -e "${GREEN}✅ Database exists${NC}"
fi
echo ""

# Step 6: Start Services
echo -e "${BLUE}Step 6: Starting services...${NC}"
tutor local start -d
sleep 10
echo -e "${GREEN}✅ Services started${NC}"
echo ""

# Step 7: Verify local bootstrap baseline
echo -e "${BLUE}Step 7: Verifying local bootstrap baseline...${NC}"
./scripts/infra/verify-local-bootstrap-readiness.sh
echo -e "${GREEN}✅ Local bootstrap baseline verified${NC}"
echo ""

# Step 8: Create Admin User
echo -e "${BLUE}Step 8: Setting up admin user...${NC}"
LOCAL_ADMIN_USERNAME="${LOCAL_ADMIN_USERNAME:-admin}"
LOCAL_ADMIN_EMAIL="${LOCAL_ADMIN_EMAIL:-admin@mereka.academy}"
LOCAL_ADMIN_CREDENTIALS_FILE="${LOCAL_ADMIN_CREDENTIALS_FILE:-tutor_env/local-admin-credentials.txt}"
if [[ -z "${LOCAL_ADMIN_PASSWORD:-}" ]]; then
    LOCAL_ADMIN_PASSWORD="$(python3 - <<'PY'
import secrets
print(secrets.token_urlsafe(24))
PY
)"
    mkdir -p "$(dirname "$LOCAL_ADMIN_CREDENTIALS_FILE")"
    umask 077
    {
        printf 'username=%s\n' "$LOCAL_ADMIN_USERNAME"
        printf 'email=%s\n' "$LOCAL_ADMIN_EMAIL"
        printf 'password=%s\n' "$LOCAL_ADMIN_PASSWORD"
    } > "$LOCAL_ADMIN_CREDENTIALS_FILE"
    echo -e "${YELLOW}⚠️  Generated local admin password in $LOCAL_ADMIN_CREDENTIALS_FILE${NC}"
else
    mkdir -p "$(dirname "$LOCAL_ADMIN_CREDENTIALS_FILE")"
    umask 077
    {
        printf 'username=%s\n' "$LOCAL_ADMIN_USERNAME"
        printf 'email=%s\n' "$LOCAL_ADMIN_EMAIL"
        printf 'password=%s\n' "$LOCAL_ADMIN_PASSWORD"
    } > "$LOCAL_ADMIN_CREDENTIALS_FILE"
fi
ADMIN_SETUP_LOG="$(mktemp)"
if docker exec \
  -e LOCAL_ADMIN_USERNAME="$LOCAL_ADMIN_USERNAME" \
  -e LOCAL_ADMIN_EMAIL="$LOCAL_ADMIN_EMAIL" \
  -e LOCAL_ADMIN_PASSWORD="$LOCAL_ADMIN_PASSWORD" \
  tutor_local-lms-1 python /openedx/edx-platform/manage.py lms shell -c "
import os
from django.contrib.auth import get_user_model
User = get_user_model()
username = os.environ['LOCAL_ADMIN_USERNAME']
email = os.environ['LOCAL_ADMIN_EMAIL']
password = os.environ['LOCAL_ADMIN_PASSWORD']
try:
    u = User.objects.get(username=username)
except User.DoesNotExist:
    u = User.objects.create_user(username, email, password)
u.email = email
u.set_password(password)
u.is_active = True
u.is_staff = True
u.is_superuser = True
u.save()
print('✅ Admin user ready')
" >"$ADMIN_SETUP_LOG" 2>&1; then
    grep -E "(Admin|✅)" "$ADMIN_SETUP_LOG" || cat "$ADMIN_SETUP_LOG"
else
    cat "$ADMIN_SETUP_LOG" >&2
    rm -f "$ADMIN_SETUP_LOG"
    exit 1
fi
rm -f "$ADMIN_SETUP_LOG"
echo ""

# Step 9: Verify Setup
echo -e "${BLUE}Step 9: Verifying setup...${NC}"
CONTAINERS=$(docker ps --filter "name=tutor_local" --format "{{.Names}}" | wc -l | tr -d ' ')
if [ "$CONTAINERS" -ge 20 ]; then
    echo -e "${GREEN}✅ Containers running: $CONTAINERS${NC}"
else
    echo -e "${YELLOW}⚠️  Only $CONTAINERS containers running (expected 20+)${NC}"
fi

LMS_STATUS="$(curl -sS -o /dev/null -w '%{http_code}' --max-time 15 http://localhost 2>/dev/null || true)"
if [[ " 200 302 " == *" ${LMS_STATUS:-000} "* ]]; then
    echo -e "${GREEN}✅ LMS accessible (HTTP ${LMS_STATUS})${NC}"
else
    echo -e "${RED}❌ LMS not accessible (HTTP ${LMS_STATUS:-000})${NC}"
fi

MFE_STATUS="$(curl -sS -o /dev/null -w '%{http_code}' --max-time 15 http://apps.localhost/authn/login 2>/dev/null || true)"
if [[ " 200 302 " == *" ${MFE_STATUS:-000} "* ]]; then
    echo -e "${GREEN}✅ MFE accessible (HTTP ${MFE_STATUS})${NC}"
else
    echo -e "${RED}❌ MFE not accessible (HTTP ${MFE_STATUS:-000})${NC}"
fi
echo ""

# Final Summary
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║        Setup Complete!                                       ║"
echo "╠══════════════════════════════════════════════════════════════╣"
echo "  📍 Access URLs:"
echo "    • LMS: http://localhost"
echo "    • Studio: http://studio.localhost"
echo "    • MFE Login: http://apps.localhost/authn/login"
echo "    • Admin: http://localhost/admin"
echo ""
echo "  🔐 Credentials:"
echo "    • Username: $LOCAL_ADMIN_USERNAME"
echo "    • Password file: $LOCAL_ADMIN_CREDENTIALS_FILE"
echo ""
echo "  🛠️  Next Steps:"
echo "    • Fast Open edX rebuild: ./scripts/infra/build-openedx-image.sh --local-defaults --build-profile fast"
echo "    • Fast MFE rebuild: ./scripts/infra/build-mfe-image.sh --local-defaults --build-profile fast"
echo "    • Strict local Open edX proof rebuild: ./scripts/infra/build-openedx-image.sh --local-defaults --build-profile proof --cache-mode none"
echo "    • Strict local MFE proof rebuild: ./scripts/infra/build-mfe-image.sh --local-defaults --build-profile proof --cache-mode none"
echo "      (CI proof class: build-benchmark.yml with benchmark_class=app-cache-cold)"
echo "    • Run: ./scripts/qa/comprehensive-test.sh"
echo "    • Read: docs/ops/quickref/README.md"
echo "    • Check: docs/status/readiness/README.md"
echo ""
echo "╚══════════════════════════════════════════════════════════════╝"
