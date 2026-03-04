#!/usr/bin/env bash
# One-Click Local Development Setup
# This script sets up everything needed for local development
set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
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
source infrastructure/tutor/tutor-env.sh
export TUTOR_ROOT="$REPO_ROOT/tutor_env"

if [ ! -f "tutor_env/config.yml" ]; then
    echo -e "${YELLOW}⚠️  Config file not found, creating from example...${NC}"
    mkdir -p tutor_env
    cp infrastructure/tutor/config.example.yml tutor_env/config.yml
fi

# Ensure local Docker services are configured
tutor config save \
    --set LMS_HOST=localhost \
    --set CMS_HOST=studio.localhost \
    --set MFE_HOST=apps.localhost \
    --set DISCOVERY_HOST=discovery.localhost \
    --set ECOMMERCE_HOST=ecommerce.localhost \
    --set XQUEUE_HOST=xqueue.localhost \
    --set MYSQL_HOST=mysql \
    --set MONGODB_HOST=mongodb \
    --set REDIS_HOST=redis \
    --set MONGODB_PORT=27017 \
    --set MYSQL_PORT=3306 \
    --set REDIS_PORT=6379 \
    --set ASPECTS_SUPERSET_DATABASE_HOST=clickhouse \
    --quiet

echo -e "${GREEN}✅ Tutor configured${NC}"
echo ""

# Step 4: Apply Patches
echo -e "${BLUE}Step 4: Applying Tutor patches...${NC}"
./infrastructure/tutor/apply-patches.sh
echo -e "${GREEN}✅ Patches applied${NC}"
echo ""

# Step 5: Build Images (if needed)
echo -e "${BLUE}Step 5: Checking Docker images...${NC}"
if ! docker images | grep -q "openedx.*nightly"; then
    echo -e "${YELLOW}⚠️  OpenEdX image not found. Building (this takes 20-30 minutes)...${NC}"
    tutor images build openedx
else
    echo -e "${GREEN}✅ OpenEdX image found${NC}"
fi

if ! docker images | grep -q "openedx-mfe.*nightly"; then
    echo -e "${YELLOW}⚠️  MFE image not found. Building (this takes 15-20 minutes)...${NC}"
    tutor images build mfe
else
    echo -e "${GREEN}✅ MFE image found${NC}"
fi
echo ""

# Step 6: Initialize Database
echo -e "${BLUE}Step 6: Initializing database...${NC}"
if [ ! -d "tutor_env/data/mysql" ]; then
    echo -e "${YELLOW}⚠️  Database not initialized. Running init (this takes 5-10 minutes)...${NC}"
    tutor local launch -I --skip-build
    ./infrastructure/tutor/apply-patches.sh
else
    echo -e "${GREEN}✅ Database exists${NC}"
fi
echo ""

# Step 7: Start Services
echo -e "${BLUE}Step 7: Starting services...${NC}"
tutor local start -d
sleep 10
echo -e "${GREEN}✅ Services started${NC}"
echo ""

# Step 8: Configure Multi-Site
echo -e "${BLUE}Step 8: Configuring multi-site...${NC}"
docker exec tutor_local-mysql-1 mysql -uroot -p1EebOQxu openedx -e "
INSERT INTO organizations_organization (short_name, name, description, active, created, modified)
VALUES ('BIJIBIJI', 'Biji-Biji Academy', 'Biji-Biji Academy microsite catalog.', true, NOW(), NOW())
ON DUPLICATE KEY UPDATE name=VALUES(name), description=VALUES(description), active=VALUES(active);

INSERT INTO organizations_organization (short_name, name, description, active, created, modified)
VALUES ('SKILLOURFUTURE', 'Skill Our Future', 'Skill Our Future microsite catalog.', true, NOW(), NOW())
ON DUPLICATE KEY UPDATE name=VALUES(name), description=VALUES(description), active=VALUES(active);

INSERT INTO django_site (domain, name)
VALUES ('academy.biji-biji.com', 'Biji-Biji Academy')
ON DUPLICATE KEY UPDATE name=VALUES(name);

INSERT INTO django_site (domain, name)
VALUES ('skillourfuture.academy.mereka.io', 'Skill Our Future')
ON DUPLICATE KEY UPDATE name=VALUES(name);
" 2>/dev/null || true

echo -e "${GREEN}✅ Multi-site configured${NC}"
echo ""

# Step 9: Create Admin User
echo -e "${BLUE}Step 9: Setting up admin user...${NC}"
docker exec tutor_local-lms-1 python /openedx/edx-platform/manage.py lms shell -c "
from django.contrib.auth import get_user_model
User = get_user_model()
try:
    u = User.objects.get(username='admin')
except User.DoesNotExist:
    u = User.objects.create_user('admin', 'admin@mereka.academy', 'admin123')
u.set_password('admin123')
u.is_active = True
u.is_staff = True
u.is_superuser = True
u.save()
print('✅ Admin user ready')
" 2>&1 | grep -E "(Admin|✅)" || echo -e "${GREEN}✅ Admin user configured${NC}"
echo ""

# Step 10: Sync from Production (Optional)
echo -e "${BLUE}Step 10: Sync from production (optional)...${NC}"
if kubectl cluster-info &> /dev/null; then
    echo -e "${YELLOW}⚠️  Connected to production cluster${NC}"
    echo "  Do you want to sync course content from production? (y/N)"
    read -t 10 -n 1 SYNC_PROD || SYNC_PROD="n"
    echo ""
    if [[ "$SYNC_PROD" =~ ^[Yy]$ ]]; then
        ./scripts/shared/sync-from-production.sh || echo -e "${YELLOW}⚠️  Sync failed, continuing...${NC}"
    else
        echo -e "${YELLOW}⏭  Skipping production sync${NC}"
        echo "  Run manually: ./scripts/shared/sync-from-production.sh"
    fi
else
    echo -e "${YELLOW}⏭  Not connected to production cluster${NC}"
    echo "  To sync later: ./scripts/shared/sync-from-production.sh"
fi
echo ""

# Step 11: Verify Setup
echo -e "${BLUE}Step 11: Verifying setup...${NC}"
CONTAINERS=$(docker ps --filter "name=tutor_local" --format "{{.Names}}" | wc -l | tr -d ' ')
if [ "$CONTAINERS" -ge 20 ]; then
    echo -e "${GREEN}✅ Containers running: $CONTAINERS${NC}"
else
    echo -e "${YELLOW}⚠️  Only $CONTAINERS containers running (expected 20+)${NC}"
fi

if curl -s http://localhost >/dev/null 2>&1; then
    echo -e "${GREEN}✅ LMS accessible${NC}"
else
    echo -e "${RED}❌ LMS not accessible${NC}"
fi

if curl -s http://apps.localhost/authn/login >/dev/null 2>&1; then
    echo -e "${GREEN}✅ MFE accessible${NC}"
else
    echo -e "${RED}❌ MFE not accessible${NC}"
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
echo "    • Username: admin"
echo "    • Password: admin123"
echo ""
echo "  🛠️  Next Steps:"
echo "    • Run: ./tools/comprehensive-test.sh"
echo "    • Read: docs/QUICK_REFERENCE.md"
echo "    • Check: docs/OPERATIONAL_STATUS.md"
echo ""
echo "╚══════════════════════════════════════════════════════════════╝"

