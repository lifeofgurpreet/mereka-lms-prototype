#!/usr/bin/env bash
# Check parity between local and production environments
set -euo pipefail

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║        Local/Production Parity Check                         ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Check if local environment is running
if ! docker ps --filter "name=tutor_local" --format "{{.Names}}" | grep -q "tutor_local"; then
    echo -e "${RED}❌ Local environment not running${NC}"
    echo "   Run: tutor local start -d"
    exit 1
fi

echo "=== Services Parity ==="
LOCAL_CONTAINERS=$(docker ps --filter "name=tutor_local" --format "{{.Names}}" | wc -l | tr -d ' ')
echo "Local containers running: ${LOCAL_CONTAINERS}"
echo "Expected: 23–24"
if [ "$LOCAL_CONTAINERS" -ge 23 ] && [ "$LOCAL_CONTAINERS" -le 24 ]; then
    echo -e "${GREEN}✅ Container count within expected range (init jobs may exit)${NC}"
else
    echo -e "${YELLOW}⚠️  Container count mismatch${NC}"
fi
echo ""

echo "=== MFEs Parity ==="
if docker exec tutor_local-mfe-1 ls /openedx/dist/ >/dev/null 2>&1; then
    LOCAL_MFES=$(docker exec tutor_local-mfe-1 ls -la /openedx/dist/ 2>/dev/null | grep "^d" | awk '{print $NF}' | grep -v "^\.$" | grep -v "^\.\.$" | sort)
    MFE_COUNT=$(echo "$LOCAL_MFES" | wc -l | tr -d ' ')
    echo "Local MFEs found: ${MFE_COUNT}"
    echo "$LOCAL_MFES" | sed 's/^/  - /'
    echo ""
    echo "Expected MFEs:"
    echo "  - authn, account, profile, learning, learner-dashboard"
    echo "  - course-authoring, gradebook, discussions"
    echo "  - communications, orders, payment, ora-grading"
else
    echo -e "${RED}❌ Cannot access MFE container${NC}"
fi
echo ""

echo "=== Configuration Parity ==="
if [ -f "tutor_env/config.yml" ]; then
    echo "Open edX Version:"
    grep -E "OPENEDX.*VERSION" tutor_env/config.yml | head -3 | sed 's/^/  /' || echo "  Not found"
    echo ""
    echo "Plugins:"
    grep -A 5 "PLUGINS:" tutor_env/config.yml | head -10 | sed 's/^/  /' || echo "  Not found"
    echo ""
    echo "Database Hosts (should be local Docker services):"
    grep -E "MYSQL_HOST|MONGODB_HOST|REDIS_HOST" tutor_env/config.yml | sed 's/^/  /' || echo "  Not found"
    echo ""
    if grep -q "10\.97\.0\." tutor_env/config.yml; then
        echo -e "${RED}❌ Config contains cloud IPs (should use local Docker services)${NC}"
        echo "   Run: tutor config save --set MYSQL_HOST=mysql --set MONGODB_HOST=mongodb"
    else
        echo -e "${GREEN}✅ Config uses local Docker services${NC}"
    fi
else
    echo -e "${RED}❌ Config file not found${NC}"
fi
echo ""

echo "=== Service Health ==="
SERVICES=("lms" "cms" "mfe" "mysql" "mongodb" "redis")
for service in "${SERVICES[@]}"; do
    if docker ps --filter "name=tutor_local-${service}" --format "{{.Status}}" | grep -q "Up"; then
        echo -e "${GREEN}✅ ${service}${NC}"
    else
        echo -e "${RED}❌ ${service}${NC}"
    fi
done
echo ""

echo "=== URL Accessibility ==="
URLS=("http://localhost" "http://studio.localhost" "http://apps.localhost/authn/login")
for url in "${URLS[@]}"; do
    if curl -s -o /dev/null -w "%{http_code}" "$url" | grep -q "200\|302"; then
        echo -e "${GREEN}✅ ${url}${NC}"
    else
        echo -e "${RED}❌ ${url}${NC}"
    fi
done
echo ""

echo "=== MFE Config API ==="
if curl -s "http://localhost/api/mfe_config/v1?mfe=authn" | grep -q "BASE_URL"; then
    echo -e "${GREEN}✅ MFE Config API working${NC}"
else
    echo -e "${RED}❌ MFE Config API not working${NC}"
fi
echo ""

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║        Parity Check Complete                                  ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
echo "For detailed parity strategy, see: docs/LOCAL_PRODUCTION_PARITY.md"

